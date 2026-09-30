--!strict
-- 낚시 상태 표시. 기다리는 동안 안내 문구, 입질이 오면 크게 반응 버튼을 띄운다.
-- 성공/실패 판정은 전부 서버가 하고, 이 모듈은 결과를 받아 화면만 갱신한다.

local TweenService = game:GetService("TweenService")

local FishingUI = {}

export type Callbacks = {
	OnReact: () -> (),
}

local COLOR_BG = Color3.fromRGB(59, 42, 28)
local COLOR_BG_BITE = Color3.fromRGB(150, 60, 42)
local COLOR_TEXT = Color3.fromRGB(250, 240, 224)
local COLOR_STROKE = Color3.fromRGB(196, 160, 112)

local cardRef: Frame? = nil
local statusLabel: TextLabel? = nil
local pulseTween: Tween? = nil

local isBiting = false
local callbacksRef: Callbacks? = nil

local function stopPulse()
	if pulseTween then
		pulseTween:Cancel()
		pulseTween = nil
	end
end

local function hideCard()
	local card = cardRef
	if card then
		card.Visible = false
	end
	stopPulse()
end

function FishingUI.Init(playerGui: PlayerGui, callbacks: Callbacks)
	callbacksRef = callbacks

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "FishingGui"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true

	local card = Instance.new("Frame")
	card.Name = "FishingCard"
	card.AnchorPoint = Vector2.new(0.5, 1)
	card.Position = UDim2.new(0.5, 0, 1, -150)
	card.Size = UDim2.new(0, 260, 0, 64)
	card.BackgroundColor3 = COLOR_BG
	card.Visible = false
	card.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = COLOR_STROKE
	stroke.Thickness = 1.5
	stroke.Parent = card

	local label = Instance.new("TextLabel")
	label.Name = "Status"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -20, 1, -16)
	label.Position = UDim2.new(0, 10, 0, 8)
	label.Font = Enum.Font.GothamMedium
	label.TextColor3 = COLOR_TEXT
	label.TextScaled = true
	label.TextWrapped = true
	label.Text = ""
	label.Parent = card

	local button = Instance.new("TextButton")
	button.Name = "ReactButton"
	button.BackgroundTransparency = 1
	button.Size = UDim2.new(1, 0, 1, 0)
	button.Text = ""
	button.AutoButtonColor = false
	button.Parent = card
	button.Activated:Connect(function()
		if isBiting and callbacksRef then
			callbacksRef.OnReact()
		end
	end)

	cardRef = card
	statusLabel = label

	screenGui.Parent = playerGui
end

function FishingUI.ShowCasting(spotDisplayName: string)
	isBiting = false
	local card = cardRef
	local label = statusLabel
	if not card or not label then
		return
	end
	stopPulse()
	card.BackgroundColor3 = COLOR_BG
	card.Visible = true
	label.Text = `{spotDisplayName}에서 기다리는 중...`
end

function FishingUI.ShowBite()
	isBiting = true
	local card = cardRef
	local label = statusLabel
	if not card or not label then
		return
	end
	card.BackgroundColor3 = COLOR_BG_BITE
	card.Visible = true
	label.Text = "지금이야! 눌러요!"

	stopPulse()
	card.Size = UDim2.new(0, 260, 0, 64)
	local tween = TweenService:Create(
		card,
		TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Size = UDim2.new(0, 284, 0, 70) }
	)
	pulseTween = tween
	tween:Play()
end

function FishingUI.ShowResult(success: boolean)
	isBiting = false
	local label = statusLabel
	local card = cardRef
	if label and card then
		card.BackgroundColor3 = COLOR_BG
		label.Text = success and "손맛 좋았어요!" or "아깝다, 놓쳤어요."
	end
	stopPulse()
	task.delay(1.4, function()
		if not isBiting then
			hideCard()
		end
	end)
end

function FishingUI.IsBiting(): boolean
	return isBiting
end

return FishingUI
