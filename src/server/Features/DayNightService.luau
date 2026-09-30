--!strict
-- 낮/밤 사이클 + 날씨. Lighting.ClockTime과 몇몇 Lighting/Atmosphere 속성만 바꾼다 —
-- 이 값들은 원래 서버 -> 클라이언트로 자동 복제되는 서비스라서 별도 RemoteEvent가 필요 없다.
--
-- NightLight 태그(123개, 오두막·캠핑장·마구간·시장·부두·전망대·정자·북쪽 길·창고·승마장의
-- 기존 랜턴/가로등)의 PointLight.Brightness/Range를 BaseBrightness/BaseRange <-> 0으로
-- 부드럽게 트윈해서 밤/새벽 전환을 연출한다. 새 조명 소품은 만들지 않는다.

local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DayNightConfig = require(ReplicatedStorage:WaitForChild("Features"):WaitForChild("DayNightConfig"))

local NIGHT_LIGHT_TAG = "NightLight"

local DayNightService = {}

local currentWeather: DayNightConfig.WeatherId = "Clear"
local wasNight = false

local function applyWeather(id: DayNightConfig.WeatherId, instant: boolean)
	local preset = DayNightConfig.WeatherPreset(id)
	if not preset then
		return
	end
	currentWeather = id
	Lighting:SetAttribute("WeatherState", id)

	local duration = if instant then 0 else DayNightConfig.WEATHER_TRANSITION_SECONDS

	if duration <= 0 then
		Lighting.Brightness = preset.brightness
		Lighting.Ambient = preset.ambient
		Lighting.ColorShift_Top = preset.colorShiftTop
		Lighting.ColorShift_Bottom = preset.colorShiftBottom
	else
		TweenService:Create(Lighting, TweenInfo.new(duration, Enum.EasingStyle.Sine), {
			Brightness = preset.brightness,
			Ambient = preset.ambient,
			ColorShift_Top = preset.colorShiftTop,
			ColorShift_Bottom = preset.colorShiftBottom,
		}):Play()
	end

	-- 맵에 Atmosphere가 이미 설정돼 있으면 그 위에 얹고, 없으면 새로 만들지 않는다
	-- (조명 아티스트가 일부러 안 둔 걸 수도 있어서 — 스크립트로 맵 설정을 새로 만들지 않는다).
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") :: Atmosphere?
	if atmosphere then
		if duration <= 0 then
			atmosphere.Density = preset.atmosphereDensity
			atmosphere.Haze = preset.atmosphereHaze
			atmosphere.Glare = preset.atmosphereGlare
		else
			TweenService:Create(atmosphere, TweenInfo.new(duration, Enum.EasingStyle.Sine), {
				Density = preset.atmosphereDensity,
				Haze = preset.atmosphereHaze,
				Glare = preset.atmosphereGlare,
			}):Play()
		end
	end
end

local function setNightLightsOn(on: boolean)
	local duration = DayNightConfig.NIGHT_LIGHT_TRANSITION_SECONDS
	for _, instance in CollectionService:GetTagged(NIGHT_LIGHT_TAG) do
		if not instance:IsA("BasePart") then
			continue
		end
		local light = instance:FindFirstChildOfClass("PointLight")
		if not light then
			continue
		end

		local baseBrightnessRaw = instance:GetAttribute("BaseBrightness")
		local baseRangeRaw = instance:GetAttribute("BaseRange")
		local baseBrightness = if type(baseBrightnessRaw) == "number" then baseBrightnessRaw else light.Brightness
		local baseRange = if type(baseRangeRaw) == "number" then baseRangeRaw else light.Range

		local targetBrightness = if on then baseBrightness else 0
		local targetRange = if on then baseRange else 0

		TweenService:Create(light, TweenInfo.new(duration, Enum.EasingStyle.Sine), {
			Brightness = targetBrightness,
			Range = targetRange,
		}):Play()
	end
end

function DayNightService.Init()
	local lightCount = #CollectionService:GetTagged(NIGHT_LIGHT_TAG)
	if lightCount == 0 then
		warn(`[DayNightService] "{NIGHT_LIGHT_TAG}" 태그가 달린 오브젝트를 하나도 찾지 못했습니다 — 123개에 태그를 다시 달아주세요.`)
	end

	-- 서버가 막 켜졌을 때도 지금 시각/날씨에 맞는 상태로 바로 맞춘다(트윈 없이 즉시).
	wasNight = DayNightConfig.IsNight(Lighting.ClockTime)
	setNightLightsOn(wasNight)
	applyWeather(DayNightConfig.RollWeather(), true)

	RunService.Heartbeat:Connect(function(dt: number)
		local rate = 24 / DayNightConfig.FULL_DAY_SECONDS
		Lighting.ClockTime = (Lighting.ClockTime + dt * rate) % 24
	end)

	task.spawn(function()
		while true do
			task.wait(DayNightConfig.NIGHT_LIGHT_CHECK_INTERVAL)
			local isNight = DayNightConfig.IsNight(Lighting.ClockTime)
			if isNight ~= wasNight then
				wasNight = isNight
				setNightLightsOn(isNight)
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(DayNightConfig.WEATHER_CHECK_INTERVAL)
			local nextWeather: DayNightConfig.WeatherId = DayNightConfig.RollWeather()
			if nextWeather ~= currentWeather then
				applyWeather(nextWeather, false)
			end
		end
	end)

	print(`[DayNightService] 초기화 완료 - 야간 조명 {lightCount}개, 하루 {DayNightConfig.FULL_DAY_SECONDS}초`)
end

-- 다른 서버 스크립트(SleepService 등)가 시간을 즉시 건너뛸 때 쓴다. Tween을 쓰지 않는다 —
-- 위 Heartbeat 루프가 매 프레임 ClockTime을 갱신하므로, 여러 프레임에 걸친 트윈과 경합하면
-- 서로 값을 덮어써서 뚝뚝 끊기게 된다. 한 번에 값을 정하고 다음 프레임부터 다시 자연스럽게 흐르게 한다.
function DayNightService.SkipTo(clockTime: number)
	Lighting.ClockTime = clockTime % 24
	local isNight = DayNightConfig.IsNight(Lighting.ClockTime)
	if isNight ~= wasNight then
		wasNight = isNight
		setNightLightsOn(isNight)
	end
end

return DayNightService
