--!strict
-- 인벤토리/도감 창. B키 또는 모바일 버튼으로 열고 닫는다.
-- 종류별 탭, 아직 못 얻은 아이템은 ??? 로 표시한다.

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemDatabase = require(ReplicatedStorage:WaitForChild("Features"):WaitForChild("ItemDatabase"))
local Types = require(ReplicatedStorage:WaitForChild("Features"):WaitForChild("Types"))

local CodexUI = {}

local COLOR_BG = Color3.fromRGB(45, 32, 22)
local COLOR_PANEL = Color3.fromRGB(63, 45, 30)
local COLOR_CELL = Color3.fromRGB(77, 56, 38)
local COLOR_CELL_LOCKED = Color3.fromRGB(55, 40, 28)
local COLOR_TEXT = Color3.fromRGB(248, 238, 220)
local COLOR_TEXT_MUTED = Color3.fromRGB(178, 156, 130)
local COLOR_ACCENT = Color3.fromRGB(196, 160, 112)

local RARITY_COLORS: { [Types.Rarity]: Color3 } = {
	Common = Color3.fromRGB(168, 148, 122),
	Uncommon = Color3.fromRGB(120, 168, 110),
	Rare = Color3.fromRGB(102, 150, 196),
	Legendary = Color3.fromRGB(206, 168, 92),
}

local KIND_ORDER: { Types.ItemKind } = { "Fish", "Mushroom", "Flower", "Food" }
local KIND_LABEL: { [Types.ItemKind]: string } = {
	Fish = "물고기",
	Mushroom = "버섯",
	Flower = "꽃",
	Food = "음식",
}

local gridFrame: ScrollingFrame? = nil
local screenGuiRef: ScreenGui? = nil
local capacityLabelRef: TextLabel? = nil
local tabButtons: { [Types.ItemKind]: TextButton } = {}
local cellCountLabels: { [string]: TextLabel } = {}
local currentKind: Types.ItemKind = "Fish"
local isOpen = false

local inventoryData: { [string]: number } = {}
local codexData: { [string]: any } = {}

local function setActiveTabVisual(kind: Types.ItemKind)
	for tabKind, button in tabButtons do
		if tabKind == kind then
			button.BackgroundColor3 = COLOR_ACCENT
			button.TextColor3 = COLOR_BG
		else
			button.BackgroundColor3 = COLOR_PANEL
			button.TextColor3 = COLOR_TEXT
		end
	end
end

local function buildCell(def: Types.ItemDefinition, parent: Instance)
	local discovered = codexData[def.id] ~= nil

	local cell = Instance.new("Frame")
	cell.Name = def.id
	cell.BackgroundColor3 = discovered and COLOR_CELL or COLOR_CELL_LOCKED
	cell.Size = UDim2.new(0, 0, 0, 0) -- UIGridLayout이 실제 크기를 지정

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = cell

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = discovered and RARITY_COLORS[def.rarity] or COLOR_TEXT_MUTED
	stroke.Parent = cell

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.new(1, -10, 0.6, 0)
	nameLabel.Position = UDim2.new(0, 5, 0.08, 0)
	nameLabel.Font = Enum.Font.GothamMedium
	nameLabel.TextColor3 = discovered and COLOR_TEXT or COLOR_TEXT_MUTED
	nameLabel.TextScaled = true
	nameLabel.Text = discovered and def.displayName or "???"
	nameLabel.Parent = cell

	local countLabel = Instance.new("TextLabel")
	countLabel.Name = "Count"
	countLabel.BackgroundTransparency = 1
	countLabel.Size = UDim2.new(1, -10, 0.3, 0)
	countLabel.Position = UDim2.new(0, 5, 0.68, 0)
	countLabel.Font = Enum.Font.Gotham
	countLabel.TextColor3 = COLOR_TEXT_MUTED
	countLabel.TextScaled = true
	local count = inventoryData[def.id] or 0
	countLabel.Text = discovered and (`보유 {count}`) or ""
	countLabel.Parent = cell

	cellCountLabels[def.id] = countLabel
	cell.Parent = parent
end

local function refreshGrid()
	local grid = gridFrame
	if not grid then
		return
	end
	for _, child in grid:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	cellCountLabels = {}

	for _, def in ItemDatabase.GetByKind(currentKind) do
		buildCell(def, grid)
	end
end

local function selectTab(kind: Types.ItemKind)
	currentKind = kind
	setActiveTabVisual(kind)
	refreshGrid()
end

function CodexUI.Init(playerGui: PlayerGui)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CodexGui"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Enabled = false

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.new(0.5, 0, 0.5, 0)
	frame.Size = UDim2.new(0.85, 0, 0.75, 0)
	frame.BackgroundColor3 = COLOR_BG
	frame.Parent = screenGui

	local frameCorner = Instance.new("UICorner")
	frameCorner.CornerRadius = UDim.new(0, 16)
	frameCorner.Parent = frame

	local frameStroke = Instance.new("UIStroke")
	frameStroke.Color = COLOR_ACCENT
	frameStroke.Thickness = 2
	frameStroke.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -60, 0, 44)
	title.Position = UDim2.new(0, 20, 0, 8)
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = COLOR_TEXT
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "도감 & 인벤토리"
	title.Parent = frame

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -12, 0, 12)
	closeButton.Size = UDim2.new(0, 36, 0, 36)
	closeButton.BackgroundColor3 = COLOR_PANEL
	closeButton.TextColor3 = COLOR_TEXT
	closeButton.Font = Enum.Font.GothamBold
	closeButton.TextScaled = true
	closeButton.Text = "X"
	closeButton.Parent = frame

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(1, 0)
	closeCorner.Parent = closeButton

	closeButton.Activated:Connect(function()
		CodexUI.SetOpen(false)
	end)

	local tabBar = Instance.new("Frame")
	tabBar.Name = "TabBar"
	tabBar.BackgroundTransparency = 1
	tabBar.Size = UDim2.new(1, -40, 0, 40)
	tabBar.Position = UDim2.new(0, 20, 0, 56)
	tabBar.Parent = frame

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 8)
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Parent = tabBar

	local capacityLabel = Instance.new("TextLabel")
	capacityLabel.Name = "CapacityLabel"
	capacityLabel.AnchorPoint = Vector2.new(1, 0.5)
	capacityLabel.Position = UDim2.new(1, -20, 0, 76)
	capacityLabel.Size = UDim2.new(0, 150, 0, 30)
	capacityLabel.BackgroundTransparency = 1
	capacityLabel.Font = Enum.Font.GothamBold
	capacityLabel.TextColor3 = COLOR_ACCENT
	capacityLabel.TextScaled = true
	capacityLabel.TextXAlignment = Enum.TextXAlignment.Right
	capacityLabel.Text = "가방 0/50"
	capacityLabel.Parent = frame
	capacityLabelRef = capacityLabel

	for i, kind: Types.ItemKind in KIND_ORDER do
		local button = Instance.new("TextButton")
		button.Name = kind
		button.LayoutOrder = i
		button.Size = UDim2.new(0, 90, 1, 0)
		button.BackgroundColor3 = COLOR_PANEL
		button.TextColor3 = COLOR_TEXT
		button.Font = Enum.Font.GothamMedium
		button.TextScaled = true
		button.Text = KIND_LABEL[kind]
		button.Parent = tabBar

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 10)
		btnCorner.Parent = button

		button.Activated:Connect(function()
			selectTab(kind)
		end)

		tabButtons[kind] = button
	end

	local scroller = Instance.new("ScrollingFrame")
	scroller.Name = "Scroller"
	scroller.BackgroundTransparency = 1
	scroller.Position = UDim2.new(0, 20, 0, 106)
	scroller.Size = UDim2.new(1, -40, 1, -126)
	scroller.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroller.ScrollBarThickness = 6
	scroller.Parent = frame

	local grid = Instance.new("UIGridLayout")
	grid.CellPadding = UDim2.new(0, 10, 0, 10)
	grid.CellSize = UDim2.new(0, 140, 0, 90)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = scroller

	gridFrame = scroller

	-- 모바일 전용 토글 버튼
	if UserInputService.TouchEnabled then
		local mobileButton = Instance.new("TextButton")
		mobileButton.Name = "CodexToggleButton"
		mobileButton.AnchorPoint = Vector2.new(1, 1)
		mobileButton.Position = UDim2.new(1, -16, 1, -100)
		mobileButton.Size = UDim2.new(0, 56, 0, 56)
		mobileButton.BackgroundColor3 = COLOR_PANEL
		mobileButton.TextColor3 = COLOR_TEXT
		mobileButton.Font = Enum.Font.GothamBold
		mobileButton.TextScaled = true
		mobileButton.Text = "도감"
		mobileButton.Parent = screenGui

		local mobileCorner = Instance.new("UICorner")
		mobileCorner.CornerRadius = UDim.new(1, 0)
		mobileCorner.Parent = mobileButton

		mobileButton.Activated:Connect(function()
			CodexUI.Toggle()
		end)
	end

	selectTab("Fish")
	screenGuiRef = screenGui
	screenGui.Parent = playerGui
end

function CodexUI.SetData(inventory: { [string]: number }, codex: { [string]: any })
	inventoryData = inventory
	codexData = codex
	refreshGrid()
end

function CodexUI.UpdateItem(itemId: string, newCount: number)
	inventoryData[itemId] = newCount
	if not codexData[itemId] then
		codexData[itemId] = { firstSeenAt = os.time(), count = newCount }
	end
	if currentKind then
		local def = ItemDatabase.Get(itemId)
		if def and def.kind == currentKind then
			refreshGrid()
		end
	end
end

function CodexUI.SetCapacity(total: number, capacity: number)
	local label = capacityLabelRef
	if not label then
		return
	end
	label.Text = `가방 {total}/{capacity}`
	label.TextColor3 = if total >= capacity then Color3.fromRGB(196, 120, 100) else COLOR_ACCENT
end

function CodexUI.SetOpen(open: boolean)
	isOpen = open
	if screenGuiRef then
		screenGuiRef.Enabled = open
	end
	if open then
		refreshGrid()
	end
end

function CodexUI.Toggle()
	CodexUI.SetOpen(not isOpen)
end

return CodexUI
