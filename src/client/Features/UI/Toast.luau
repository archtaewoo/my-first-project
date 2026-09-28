--!strict
-- 화면 하단 알림 토스트. 갈색 톤, 모바일 대응(Scale 기반 크기).

local TweenService = game:GetService("TweenService")

local Toast = {}

local COLOR_BG = Color3.fromRGB(59, 42, 28) -- 짙은 갈색
local COLOR_BG_ACCENT = Color3.fromRGB(122, 84, 46) -- 발견 알림용 강조 갈색
local COLOR_TEXT = Color3.fromRGB(250, 240, 224) -- 크림색 텍스트
local COLOR_STROKE = Color3.fromRGB(196, 160, 112)

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
	card.BackgroundColor3 = accent and COLOR_BG_ACCENT or COLOR_BG
	card.BackgroundTransparency = 1
	card.Size = UDim2.new(0, 0, 0, 0)
	card.Parent = container

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = COLOR_STROKE
	stroke.Thickness = 1.5
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
	label.Font = Enum.Font.GothamMedium
	label.TextColor3 = COLOR_TEXT
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
