--!strict
-- 말 꾸미기 메뉴(클라이언트). 말의 "꾸미기" 프롬프트로 열리는 색상 팔레트 창.
-- 공통 디자인 틀(Theme/Components)로 다시 그렸다 - 서버로 보내는 속성/리모트 호출
-- (HorseCustomize RemoteEvent, 받는 쪽 서버 스크립트)은 그대로 유지했다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remote = ReplicatedStorage:WaitForChild("HorseCustomize") :: RemoteEvent
local player = Players.LocalPlayer

local UIFolder = ReplicatedStorage:WaitForChild("Features"):WaitForChild("UI")
local Theme = require(UIFolder:WaitForChild("Theme"))
local Components = UIFolder:WaitForChild("Components")
local PanelFrame = require(Components:WaitForChild("PanelFrame"))

type Swatch = { string | Color3 }

local COATS: { Swatch } = {
	{ "밤색", Color3.fromRGB(140, 84, 52) }, { "갈색", Color3.fromRGB(98, 64, 42) }, { "흑색", Color3.fromRGB(38, 34, 34) },
	{ "백색", Color3.fromRGB(238, 234, 226) }, { "회색", Color3.fromRGB(150, 152, 158) }, { "팔로미노", Color3.fromRGB(222, 184, 112) },
	{ "크림", Color3.fromRGB(234, 216, 180) }, { "황토", Color3.fromRGB(180, 146, 98) }, { "회갈", Color3.fromRGB(110, 96, 88) }, { "분홍", Color3.fromRGB(236, 170, 190) },
}
local MANES: { Swatch } = {
	{ "검정", Color3.fromRGB(30, 26, 26) }, { "갈색", Color3.fromRGB(84, 58, 40) }, { "금색", Color3.fromRGB(232, 204, 140) }, { "백색", Color3.fromRGB(240, 236, 228) },
	{ "적갈", Color3.fromRGB(150, 62, 44) }, { "회색", Color3.fromRGB(140, 140, 146) }, { "분홍", Color3.fromRGB(236, 150, 190) }, { "하늘", Color3.fromRGB(110, 160, 220) },
}
local HOOFS: { Swatch } = {
	{ "검정", Color3.fromRGB(28, 26, 26) }, { "갈색", Color3.fromRGB(100, 72, 52) }, { "회색", Color3.fromRGB(120, 120, 124) }, { "금색", Color3.fromRGB(190, 160, 90) },
}
local SADDLES: { Swatch } = {
	{ "가죽", Color3.fromRGB(120, 76, 48) }, { "검정", Color3.fromRGB(44, 38, 36) }, { "빨강", Color3.fromRGB(170, 50, 46) },
	{ "남색", Color3.fromRGB(50, 72, 120) }, { "초록", Color3.fromRGB(60, 104, 70) }, { "흰색", Color3.fromRGB(232, 228, 220) },
}

local gui: ScreenGui? = nil
local current: Model? = nil

local function send(data: { [string]: any })
	if current then
		remote:FireServer(current, data)
	end
end

local function closeMenu()
	if gui then
		gui:Destroy()
		gui = nil
	end
	current = nil
end

local function makeSection(parent: Instance, title: string, order: number): Frame
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.BackgroundTransparency = 1
	frame.LayoutOrder = order
	frame.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 22)
	label.BackgroundTransparency = 1
	label.Text = title
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Font = Theme.Font.Heading
	label.TextSize = 16
	label.TextColor3 = Theme.Color.Text
	label.LayoutOrder = 1
	label.Parent = frame

	return frame
end

local function makeSwatches(parent: Instance, list: { Swatch }, key: string)
	local grid = Instance.new("Frame")
	grid.Size = UDim2.new(1, 0, 0, 0)
	grid.AutomaticSize = Enum.AutomaticSize.Y
	grid.BackgroundTransparency = 1
	grid.LayoutOrder = 2
	grid.Parent = parent

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.fromOffset(60, 46)
	gridLayout.CellPadding = UDim2.fromOffset(6, 6)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid

	for i, item in list do
		local labelText = item[1] :: string
		local color = item[2] :: Color3

		local button = Instance.new("TextButton")
		button.BackgroundColor3 = color
		button.Text = labelText
		button.Font = Theme.Font.Body
		button.TextSize = 12
		button.AutoButtonColor = true
		button.LayoutOrder = i
		button.TextColor3 = if (color.R + color.G + color.B) > 1.9 then Theme.Color.TextOnAccent else Theme.Color.Text
		button.TextWrapped = true
		button.Parent = grid

		local corner = Instance.new("UICorner")
		corner.CornerRadius = Theme.Corner.Button
		corner.Parent = button

		local stroke = Instance.new("UIStroke")
		stroke.Color = Theme.Color.Border
		stroke.Thickness = Theme.Stroke.Button
		stroke.Parent = button

		button.Activated:Connect(function()
			send({ [key] = color })
		end)
	end
end

local function makeToggle(parent: Instance, label: string, attr: string, order: number)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, 0, 0, math.max(36, Theme.Layout.MinTouchTarget))
	button.BackgroundColor3 = Theme.Color.Panel
	button.Font = Theme.Font.Body
	button.TextSize = 15
	button.TextColor3 = Theme.Color.Text
	button.LayoutOrder = order
	button.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.Corner.Button
	corner.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Color.Border
	stroke.Thickness = Theme.Stroke.Button
	stroke.Parent = button

	local function refresh()
		local horse = current
		local on: boolean
		if horse then
			local raw = horse:GetAttribute(attr)
			on = if attr == "TackOn" then raw ~= false else raw == true
		else
			on = false
		end
		button.Text = `{label} : {if on then "켜짐" else "꺼짐"}`
		button.BackgroundColor3 = if on then Theme.Color.AccentGreen else Theme.Color.Panel
		button.TextColor3 = if on then Theme.Color.TextOnAccent else Theme.Color.Text
	end

	button.Activated:Connect(function()
		local horse = current
		if not horse then
			return
		end
		local raw = horse:GetAttribute(attr)
		local on = if attr == "TackOn" then raw ~= false else raw == true
		send({ [attr] = not on })
		task.delay(0.15, refresh)
	end)
	refresh()
end

local function openMenu(horse: Model)
	closeMenu()
	current = horse

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "HorseCustomizerGui"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = player:WaitForChild("PlayerGui")
	gui = screenGui

	local panel = PanelFrame.new({
		parent = screenGui,
		title = "말 꾸미기",
		onClose = closeMenu,
	})
	-- 다른 창과 달리 화면 오른쪽 가장자리에 붙는 고정 크기 패널이라, 가운데 비율 배치 대신
	-- 생성 직후 위치·크기를 다시 잡는다.
	panel.root.AnchorPoint = Vector2.new(1, 0.5)
	panel.root.Position = UDim2.new(1, -20, 0.5, 0)
	panel.root.Size = UDim2.fromOffset(340, 560)

	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.Size = UDim2.new(1, 0, 1, -50)
	scroll.ScrollBarThickness = 5
	scroll.ScrollBarImageColor3 = Theme.Color.Accent
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.BorderSizePixel = 0
	scroll.Parent = panel.body

	local scrollLayout = Instance.new("UIListLayout")
	scrollLayout.Padding = UDim.new(0, 12)
	scrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
	scrollLayout.Parent = scroll

	local nameSection = makeSection(scroll, "이름", 1)
	local nameBox = Instance.new("TextBox")
	nameBox.Size = UDim2.new(1, 0, 0, 36)
	nameBox.BackgroundColor3 = Theme.Color.Panel
	nameBox.Text = (horse:GetAttribute("HorseName") :: string?) or ""
	nameBox.PlaceholderText = "이름 (최대 12자)"
	nameBox.Font = Theme.Font.Body
	nameBox.TextSize = 16
	nameBox.TextColor3 = Theme.Color.Text
	nameBox.ClearTextOnFocus = false
	nameBox.LayoutOrder = 2
	nameBox.Parent = nameSection
	local nameBoxCorner = Instance.new("UICorner")
	nameBoxCorner.CornerRadius = Theme.Corner.Button
	nameBoxCorner.Parent = nameBox
	nameBox.FocusLost:Connect(function()
		send({ HorseName = nameBox.Text })
	end)

	makeSwatches(makeSection(scroll, "털 색", 2), COATS, "CoatColor")
	makeSwatches(makeSection(scroll, "갈기와 꼬리", 3), MANES, "ManeColor")
	makeSwatches(makeSection(scroll, "발굽", 4), HOOFS, "HoofColor")

	local optionSection = makeSection(scroll, "장식", 5)
	makeToggle(optionSection, "흰 양말", "Socks", 2)
	makeToggle(optionSection, "안장", "TackOn", 3)

	makeSwatches(makeSection(scroll, "안장 색", 6), SADDLES, "SaddleColor")

	local footer = Instance.new("Frame")
	footer.BackgroundTransparency = 1
	footer.Position = UDim2.new(0, 0, 1, -44)
	footer.Size = UDim2.new(1, 0, 0, 40)
	footer.Parent = panel.body

	local resetButton = Instance.new("TextButton")
	resetButton.Size = UDim2.new(0.48, 0, 1, 0)
	resetButton.BackgroundColor3 = Theme.Color.Panel
	resetButton.Text = "처음으로"
	resetButton.Font = Theme.Font.Heading
	resetButton.TextSize = 15
	resetButton.TextColor3 = Theme.Color.Text
	resetButton.Parent = footer
	local resetCorner = Instance.new("UICorner")
	resetCorner.CornerRadius = Theme.Corner.Button
	resetCorner.Parent = resetButton
	local resetStroke = Instance.new("UIStroke")
	resetStroke.Color = Theme.Color.Border
	resetStroke.Thickness = Theme.Stroke.Button
	resetStroke.Parent = resetButton
	resetButton.Activated:Connect(function()
		send({ Reset = true })
		task.delay(0.2, function()
			if nameBox.Parent then
				nameBox.Text = (horse:GetAttribute("HorseName") :: string?) or ""
			end
		end)
	end)

	local randomButton = Instance.new("TextButton")
	randomButton.AnchorPoint = Vector2.new(1, 0)
	randomButton.Position = UDim2.new(1, 0, 0, 0)
	randomButton.Size = UDim2.new(0.48, 0, 1, 0)
	randomButton.BackgroundColor3 = Theme.Color.AccentGreen
	randomButton.Text = "랜덤"
	randomButton.Font = Theme.Font.Heading
	randomButton.TextSize = 15
	randomButton.TextColor3 = Theme.Color.TextOnAccent
	randomButton.Parent = footer
	local randomCorner = Instance.new("UICorner")
	randomCorner.CornerRadius = Theme.Corner.Button
	randomCorner.Parent = randomButton
	local randomStroke = Instance.new("UIStroke")
	randomStroke.Color = Theme.Color.AccentGreenDark
	randomStroke.Thickness = Theme.Stroke.Button
	randomStroke.Parent = randomButton
	randomButton.Activated:Connect(function()
		send({
			CoatColor = (COATS[math.random(#COATS)][2] :: Color3),
			ManeColor = (MANES[math.random(#MANES)][2] :: Color3),
			HoofColor = (HOOFS[math.random(#HOOFS)][2] :: Color3),
			SaddleColor = (SADDLES[math.random(#SADDLES)][2] :: Color3),
			Socks = math.random() < 0.4,
		})
	end)
end

remote.OnClientEvent:Connect(function(kind: unknown, horse: unknown)
	if kind == "open" and typeof(horse) == "Instance" and horse:IsA("Model") then
		openMenu(horse)
	end
end)

-- 플레이어가 멀어지면 메뉴를 닫는다
task.spawn(function()
	while true do
		task.wait(0.5)
		if gui and current then
			local character = player.Character
			local hrpInstance = character and character:FindFirstChild("HumanoidRootPart")
			local anchorInstance = current:FindFirstChild("HumanoidRootPart", true) or current:FindFirstChild("Cube", true)
			local hrp = if hrpInstance and hrpInstance:IsA("BasePart") then hrpInstance else nil
			local anchor = if anchorInstance and anchorInstance:IsA("BasePart") then anchorInstance else nil
			if not hrp or not anchor or (hrp.Position - anchor.Position).Magnitude > 40 then
				closeMenu()
			end
		end
	end
end)
