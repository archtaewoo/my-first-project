-- Horse customiser (client): a small colour-palette menu that opens from the horse's "꾸미기" prompt.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remote = ReplicatedStorage:WaitForChild("HorseCustomize")
local player = Players.LocalPlayer

local COATS = {
	{"밤색", Color3.fromRGB(140, 84, 52)}, {"갈색", Color3.fromRGB(98, 64, 42)}, {"흑색", Color3.fromRGB(38, 34, 34)},
	{"백색", Color3.fromRGB(238, 234, 226)}, {"회색", Color3.fromRGB(150, 152, 158)}, {"팔로미노", Color3.fromRGB(222, 184, 112)},
	{"크림", Color3.fromRGB(234, 216, 180)}, {"황토", Color3.fromRGB(180, 146, 98)}, {"회갈", Color3.fromRGB(110, 96, 88)}, {"분홍", Color3.fromRGB(236, 170, 190)},
}
local MANES = {
	{"검정", Color3.fromRGB(30, 26, 26)}, {"갈색", Color3.fromRGB(84, 58, 40)}, {"금색", Color3.fromRGB(232, 204, 140)}, {"백색", Color3.fromRGB(240, 236, 228)},
	{"적갈", Color3.fromRGB(150, 62, 44)}, {"회색", Color3.fromRGB(140, 140, 146)}, {"분홍", Color3.fromRGB(236, 150, 190)}, {"하늘", Color3.fromRGB(110, 160, 220)},
}
local HOOFS = {
	{"검정", Color3.fromRGB(28, 26, 26)}, {"갈색", Color3.fromRGB(100, 72, 52)}, {"회색", Color3.fromRGB(120, 120, 124)}, {"금색", Color3.fromRGB(190, 160, 90)},
}
local SADDLES = {
	{"가죽", Color3.fromRGB(120, 76, 48)}, {"검정", Color3.fromRGB(44, 38, 36)}, {"빨강", Color3.fromRGB(170, 50, 46)},
	{"남색", Color3.fromRGB(50, 72, 120)}, {"초록", Color3.fromRGB(60, 104, 70)}, {"흰색", Color3.fromRGB(232, 228, 220)},
}

local gui, current
local function send(data) if current then remote:FireServer(current, data) end end

local function closeMenu()
	if gui then gui:Destroy() gui = nil end
	current = nil
end

local function make(className, props, parent)
	local o = Instance.new(className)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end

local function section(parent, title, order)
	local f = make("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order}, parent)
	make("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, f)
	make("TextLabel", {Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, Text = title, TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = Color3.fromRGB(240, 232, 214), LayoutOrder = 1}, f)
	return f
end

local function swatches(parent, list, key)
	local grid = make("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 2}, parent)
	make("UIGridLayout", {CellSize = UDim2.fromOffset(58, 44), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder}, grid)
	for i, item in ipairs(list) do
		local b = make("TextButton", {BackgroundColor3 = item[2], Text = item[1], Font = Enum.Font.GothamMedium, TextSize = 12, AutoButtonColor = true, LayoutOrder = i,
			TextColor3 = (item[2].R + item[2].G + item[2].B > 1.9) and Color3.fromRGB(40, 32, 28) or Color3.fromRGB(245, 240, 230), TextWrapped = true}, grid)
		make("UICorner", {CornerRadius = UDim.new(0, 8)}, b)
		make("UIStroke", {Color = Color3.fromRGB(20, 16, 14), Thickness = 1.5, Transparency = 0.3}, b)
		b.Activated:Connect(function() send({[key] = item[2]}) end)
	end
end

local function toggle(parent, label, attr, order)
	local b = make("TextButton", {Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = Color3.fromRGB(74, 58, 46), Font = Enum.Font.GothamMedium, TextSize = 15,
		TextColor3 = Color3.fromRGB(240, 232, 214), LayoutOrder = order}, parent)
	make("UICorner", {CornerRadius = UDim.new(0, 8)}, b)
	local function refresh()
		local on = current and current:GetAttribute(attr)
		if attr == "TackOn" then on = (on ~= false) end
		b.Text = label .. " : " .. (on and "켜짐" or "꺼짐")
		b.BackgroundColor3 = on and Color3.fromRGB(96, 122, 84) or Color3.fromRGB(74, 58, 46)
	end
	b.Activated:Connect(function()
		local on = current:GetAttribute(attr)
		if attr == "TackOn" then on = (on ~= false) end
		send({[attr] = not on})
		task.delay(0.15, refresh)
	end)
	refresh()
end

local function openMenu(horse)
	closeMenu()
	current = horse
	gui = make("ScreenGui", {Name = "HorseCustomizerGui", ResetOnSpawn = false, IgnoreGuiInset = true}, player:WaitForChild("PlayerGui"))
	local panel = make("Frame", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -20, 0.5, 0), Size = UDim2.fromOffset(330, 520),
		BackgroundColor3 = Color3.fromRGB(44, 34, 28), BackgroundTransparency = 0.05}, gui)
	make("UICorner", {CornerRadius = UDim.new(0, 14)}, panel)
	make("UIStroke", {Color = Color3.fromRGB(196, 160, 110), Thickness = 2}, panel)
	make("TextLabel", {Size = UDim2.new(1, -60, 0, 40), Position = UDim2.fromOffset(16, 6), BackgroundTransparency = 1, Text = "말 꾸미기", TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBold, TextSize = 22, TextColor3 = Color3.fromRGB(246, 236, 214)}, panel)
	local close = make("TextButton", {Size = UDim2.fromOffset(34, 34), Position = UDim2.new(1, -44, 0, 8), BackgroundColor3 = Color3.fromRGB(150, 60, 50), Text = "X",
		Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = Color3.new(1, 1, 1)}, panel)
	make("UICorner", {CornerRadius = UDim.new(0, 8)}, close)
	close.Activated:Connect(closeMenu)

	local scroll = make("ScrollingFrame", {Position = UDim2.fromOffset(12, 52), Size = UDim2.new(1, -24, 1, -110), BackgroundTransparency = 1, ScrollBarThickness = 5,
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), BorderSizePixel = 0}, panel)
	make("UIListLayout", {Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder}, scroll)

	-- name
	local nameSec = section(scroll, "이름", 1)
	local box = make("TextBox", {Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = Color3.fromRGB(70, 56, 46), Text = horse:GetAttribute("HorseName") or "", PlaceholderText = "이름 (최대 12자)",
		Font = Enum.Font.GothamMedium, TextSize = 16, TextColor3 = Color3.fromRGB(246, 236, 214), ClearTextOnFocus = false, LayoutOrder = 2}, nameSec)
	make("UICorner", {CornerRadius = UDim.new(0, 8)}, box)
	box.FocusLost:Connect(function() send({HorseName = box.Text}) end)

	swatches(section(scroll, "털 색", 2), COATS, "CoatColor")
	swatches(section(scroll, "갈기와 꼬리", 3), MANES, "ManeColor")
	swatches(section(scroll, "발굽", 4), HOOFS, "HoofColor")
	local opt = section(scroll, "장식", 5)
	toggle(opt, "흰 양말", "Socks", 2)
	toggle(opt, "안장", "TackOn", 3)
	swatches(section(scroll, "안장 색", 6), SADDLES, "SaddleColor")

	local reset = make("TextButton", {Size = UDim2.new(0.48, 0, 0, 40), Position = UDim2.new(0, 12, 1, -50), BackgroundColor3 = Color3.fromRGB(110, 90, 70), Text = "처음으로",
		Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = Color3.fromRGB(246, 236, 214)}, panel)
	make("UICorner", {CornerRadius = UDim.new(0, 10)}, reset)
	reset.Activated:Connect(function() send({Reset = true}) task.delay(0.2, function() if box.Parent then box.Text = horse:GetAttribute("HorseName") or "" end end) end)
	local rnd = make("TextButton", {Size = UDim2.new(0.48, 0, 0, 40), Position = UDim2.new(0.52, -12, 1, -50), BackgroundColor3 = Color3.fromRGB(84, 110, 96), Text = "랜덤",
		Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = Color3.fromRGB(246, 236, 214)}, panel)
	make("UICorner", {CornerRadius = UDim.new(0, 10)}, rnd)
	rnd.Activated:Connect(function()
		send({CoatColor = COATS[math.random(#COATS)][2], ManeColor = MANES[math.random(#MANES)][2], HoofColor = HOOFS[math.random(#HOOFS)][2], SaddleColor = SADDLES[math.random(#SADDLES)][2], Socks = math.random() < 0.4})
	end)
end

remote.OnClientEvent:Connect(function(kind, horse)
	if kind == "open" and typeof(horse) == "Instance" then openMenu(horse) end
end)

-- close the menu if the player walks away
task.spawn(function()
	while true do
		task.wait(0.5)
		if gui and current then
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local a = current:FindFirstChild("HumanoidRootPart", true) or current:FindFirstChild("Cube", true)
			if not hrp or not a or (hrp.Position - a.Position).Magnitude > 40 then closeMenu() end
		end
	end
end)
