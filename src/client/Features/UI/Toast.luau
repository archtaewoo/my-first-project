--!strict
-- 화면 하단 알림 토스트. 공통 Theme 색상을 쓴다(모바일 Scale 기반 크기는 그대로).

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage:WaitForChild("Features"):WaitForChild("UI"):WaitForChild("Theme"))

local Toast = {}

local SHOW_DURATION = 2.4
local FADE_DURATION = 0.35

local container: Frame? = nil

function Toast.Init(playerGui: PlayerGui)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ToastGui"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local frame = Instance.new("Frame")
	frame.Name = "ToastContainer"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -60)
	frame.Size = UDim2.new(0.9, 0, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.BackgroundTransparency = 1
	frame.Parent = screenGui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame

	container = frame
	screenGui.Parent = playerGui
end

function Toast.Show(text: string, accent: boolean?)
	if not container then
		warn("[Toast] Init이 먼저 호출되어야 합니다")
		return
	end

	local card = Instance.new("Frame")
	card.Name = "Toast"
	card.AutomaticSize = Enum.AutomaticSize.XY
	card.BackgroundColor3 = if accent then Theme.Color.AccentWarm else Theme.Color.Panel
	card.BackgroundTransparency = 1
	card.Size = UDim2.new(0, 0, 0, 0)
	card.Parent = container

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.Corner.Card
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Color.Border
	stroke.Thickness = Theme.Stroke.Card
	stroke.Transparency = 1
	stroke.Parent = card

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 20)
	padding.PaddingRight = UDim.new(0, 20)
	padding.Parent = card

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.Font = Theme.Font.Body
	label.TextColor3 = if accent then Theme.Color.TextOnAccent else Theme.Color.Text
	label.TextTransparency = 1
	label.TextSize = 20
	label.Text = text
	label.Parent = card

	local fadeIn = TweenService:Create(card, TweenInfo.new(FADE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.05,
	})
	local fadeInStroke = TweenService:Create(stroke, TweenInfo.new(FADE_DURATION), { Transparency = 0.2 })
	local fadeInText = TweenService:Create(label, TweenInfo.new(FADE_DURATION), { TextTransparency = 0 })

	fadeIn:Play()
	fadeInStroke:Play()
	fadeInText:Play()

	task.delay(SHOW_DURATION, function()
		if not card.Parent then
			return
		end
		local fadeOut = TweenService:Create(card, TweenInfo.new(FADE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			BackgroundTransparency = 1,
		})
		local fadeOutStroke = TweenService:Create(stroke, TweenInfo.new(FADE_DURATION), { Transparency = 1 })
		local fadeOutText = TweenService:Create(label, TweenInfo.new(FADE_DURATION), { TextTransparency = 1 })
		fadeOut:Play()
		fadeOutStroke:Play()
		fadeOutText:Play()
		fadeOut.Completed:Connect(function()
			card:Destroy()
		end)
	end)
end

return Toast
