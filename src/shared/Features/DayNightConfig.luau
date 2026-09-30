--!strict
-- 낮/밤 사이클 + 날씨 설정. 서버(DayNightService)가 유일한 진실 소스이고,
-- 클라이언트(TimeOfDayHud)는 Lighting의 값을 읽어서 이 표로 라벨만 붙인다.

export type WeatherId = "Clear" | "Cloudy" | "Rain"

export type WeatherPreset = {
	label: string,
	brightness: number,
	ambient: Color3,
	colorShiftTop: Color3,
	colorShiftBottom: Color3,
	atmosphereDensity: number,
	atmosphereHaze: number,
	atmosphereGlare: number,
}

local WEATHER_PRESETS: { [WeatherId]: WeatherPreset } = {
	Clear = {
		label = "맑음",
		brightness = 2,
		ambient = Color3.fromRGB(140, 140, 150),
		colorShiftTop = Color3.fromRGB(255, 255, 255),
		colorShiftBottom = Color3.fromRGB(255, 255, 255),
		atmosphereDensity = 0.3,
		atmosphereHaze = 1.2,
		atmosphereGlare = 0.2,
	},
	Cloudy = {
		label = "흐림",
		brightness = 1.4,
		ambient = Color3.fromRGB(120, 120, 130),
		colorShiftTop = Color3.fromRGB(200, 200, 210),
		colorShiftBottom = Color3.fromRGB(200, 200, 210),
		atmosphereDensity = 0.45,
		atmosphereHaze = 2.5,
		atmosphereGlare = 0.1,
	},
	Rain = {
		label = "비",
		brightness = 1,
		ambient = Color3.fromRGB(90, 95, 105),
		colorShiftTop = Color3.fromRGB(150, 160, 175),
		colorShiftBottom = Color3.fromRGB(150, 160, 175),
		atmosphereDensity = 0.6,
		atmosphereHaze = 4,
		atmosphereGlare = 0,
	},
}

local WEATHER_WEIGHTS: { [WeatherId]: number } = {
	Clear = 70,
	Cloudy = 25,
	Rain = 5,
}

local WEATHER_ORDER: { WeatherId } = { "Clear", "Cloudy", "Rain" }

local DayNightConfig = {}

DayNightConfig.FULL_DAY_SECONDS = 2400 -- 실제 40분 = 게임 속 하루 (느린 사이클)
DayNightConfig.NIGHT_START = 19 -- 저녁 7시부터
DayNightConfig.NIGHT_END = 6 -- 새벽 6시까지
DayNightConfig.WEATHER_CHECK_INTERVAL = 600 -- 10분마다 날씨를 다시 굴림
DayNightConfig.WEATHER_TRANSITION_SECONDS = 20
DayNightConfig.NIGHT_LIGHT_CHECK_INTERVAL = 15
DayNightConfig.NIGHT_LIGHT_TRANSITION_SECONDS = 20

function DayNightConfig.IsNight(clockTime: number): boolean
	local start = DayNightConfig.NIGHT_START
	local stop = DayNightConfig.NIGHT_END
	if start > stop then
		return clockTime >= start or clockTime < stop
	end
	return clockTime >= start and clockTime < stop
end

function DayNightConfig.LabelForClockTime(clockTime: number): string
	if clockTime >= 5 and clockTime < 11 then
		return "아침"
	elseif clockTime >= 11 and clockTime < 17 then
		return "낮"
	elseif clockTime >= 17 and clockTime < 19 then
		return "저녁"
	end
	return "밤"
end

function DayNightConfig.WeatherPreset(id: string): WeatherPreset?
	return WEATHER_PRESETS[id :: WeatherId]
end

function DayNightConfig.RollWeather(): WeatherId
	local total = 0
	for _, id: WeatherId in WEATHER_ORDER do
		total += WEATHER_WEIGHTS[id]
	end

	local roll = math.random() * total
	local cumulative = 0
	for _, id: WeatherId in WEATHER_ORDER do
		cumulative += WEATHER_WEIGHTS[id]
		if roll <= cumulative then
			return id
		end
	end
	return "Clear"
end

return DayNightConfig
