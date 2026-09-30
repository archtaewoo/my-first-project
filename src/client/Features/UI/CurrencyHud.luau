--!strict
-- 화면 오른쪽 위에 항상 떠 있는 도토리 개수 표시. 값이 바뀌면 숫자가 스르륵 세어지듯 갱신된다.

local RunService = game:GetService("RunService")

local CurrencyHud = {}

local COLOR_BG = Color3.fromRGB(63, 45, 30)
local COLOR_TEXT = Color3.fromRGB(248, 238, 220)
local COLOR_ACCENT = Color3.fromRGB(196, 160, 112)

local COUNT_UP_DURATION = 0.4

local countLabel: TextLabel? = nil
local displayedAmount = 0
local targetAmount = 0
local tweenConnection: RBXScriptConnection? = nil

local function renderAmount(amount: number)
	if countLabel then
		countLabel.Text = `도토리 {amount}`
	end
end

function CurrencyHud.Init(playerGui: PlayerGui)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CurrencyHudGui"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true

	local card = Instance.new("Frame")
	card.Name = "CurrencyCard"
	card.AnchorPoint = Vector2.new(1, 0)
	card.Position = UDim2.new(1, -16, 0, 16)
	card.Size = UDim2.new(0, 150, 0, 44)
	card.BackgroundColor3 = COLOR_BG
	card.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = COLOR_ACCENT
	stroke.Thickness = 1.5
	stroke.Parent = card

	local icon = Instance.new("Frame")
	icon.Name = "AcornIcon"
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, 10, 0.5, 0)
	icon.Size = UDim2.new(0, 22, 0, 22)
	icon.BackgroundColor3 = COLOR_ACCENT
	icon.Parent = card

	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(1, 0)
	iconCorner.Parent = icon

	local label = Instance.new("TextLabel")
	label.Name = "Count"
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0, 0.5)
	label.Position = UDim2.new(0, 40, 0.5, 0)
	label.Size = UDim2.new(1, -50, 1, 0)
	label.Font = Enum.Font.GothamMedium
	label.TextColor3 = COLOR_TEXT
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = "도토리 0"
	label.Parent = card

	countLabel = label
	screenGui.Parent = playerGui
end

function CurrencyHud.Set(amount: number)
	targetAmount = amount

	if tweenConnection then
		tweenConnection:Disconnect()
		tweenConnection = nil
	end

	local startAmount = displayedAmount
	local startTime = os.clock()

	if startAmount == targetAmount then
		renderAmount(targetAmount)
		return
	end

	tweenConnection = RunService.RenderStepped:Connect(function()
		local t = math.clamp((os.clock() - startTime) / COUNT_UP_DURATION, 0, 1)
		local eased = 1 - (1 - t) * (1 - t)
		displayedAmount = math.floor(startAmount + (targetAmount - startAmount) * eased + 0.5)
		renderAmount(displayedAmount)
		if t >= 1 and tweenConnection then
			tweenConnection:Disconnect()
			tweenConnection = nil
		end
	end)
end

return CurrencyHud
