--!strict
-- 화면 왼쪽 위에 항상 떠 있는 시간대/날씨 표시. Lighting 속성은 서버에서 자동으로
-- 복제되므로 별도 RemoteEvent 없이 여기서 직접 읽기만 한다.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DayNightConfig = require(ReplicatedStorage:WaitForChild("Features"):WaitForChild("DayNightConfig"))

local TimeOfDayHud = {}

local COLOR_BG = Color3.fromRGB(63, 45, 30)
local COLOR_TEXT = Color3.fromRGB(248, 238, 220)
local COLOR_ACCENT = Color3.fromRGB(196, 160, 112)

local WEATHER_LABEL_FALLBACK = "맑음"

local label: TextLabel? = nil

local function refresh()
	local textLabel = label
	if not textLabel then
		return
	end

	local timeLabel = DayNightConfig.LabelForClockTime(Lighting.ClockTime)

	local weatherLabel = WEATHER_LABEL_FALLBACK
	local weatherIdRaw = Lighting:GetAttribute("WeatherState")
	if type(weatherIdRaw) == "string" then
		local preset = DayNightConfig.WeatherPreset(weatherIdRaw)
		if preset then
			weatherLabel = preset.label
		end
	end

	textLabel.Text = `{timeLabel} · {weatherLabel}`
end

function TimeOfDayHud.Init(playerGui: PlayerGui)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "TimeOfDayHudGui"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true

	local card = Instance.new("Frame")
	card.Name = "TimeCard"
	card.AnchorPoint = Vector2.new(0, 0)
	card.Position = UDim2.new(0, 16, 0, 16)
	card.Size = UDim2.new(0, 150, 0, 40)
	card.BackgroundColor3 = COLOR_BG
	card.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = COLOR_ACCENT
	stroke.Thickness = 1.5
	stroke.Parent = card

	local textLabel = Instance.new("TextLabel")
	textLabel.Name = "Label"
	textLabel.BackgroundTransparency = 1
	textLabel.Size = UDim2.new(1, -16, 1, -8)
	textLabel.Position = UDim2.new(0, 8, 0, 4)
	textLabel.Font = Enum.Font.GothamMedium
	textLabel.TextColor3 = COLOR_TEXT
	textLabel.TextScaled = true
	textLabel.Parent = card

	label = textLabel

	Lighting:GetPropertyChangedSignal("ClockTime"):Connect(refresh)
	Lighting:GetAttributeChangedSignal("WeatherState"):Connect(refresh)
	refresh()

	screenGui.Parent = playerGui
end

return TimeOfDayHud
