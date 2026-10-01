--!strict
-- 인벤토리/도감 창. B키 또는 모바일 버튼으로 열고 닫는다.
-- 종류별 탭, 아직 못 얻은 아이템은 ??? 로 표시한다.
--
-- 공통 디자인 틀(Theme/Components)로 조립한다 - 데이터 흐름(Init/SetData/UpdateItem/
-- SetCapacity/SetOpen/Toggle)은 전과 동일하고 겉모습만 바뀌었다.

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemDatabase = require(ReplicatedStorage:WaitForChild("Features"):WaitForChild("ItemDatabase"))
local Types = require(ReplicatedStorage:WaitForChild("Features"):WaitForChild("Types"))

local UIFolder = ReplicatedStorage:WaitForChild("Features"):WaitForChild("UI")
local Theme = require(UIFolder:WaitForChild("Theme"))
local Components = UIFolder:WaitForChild("Components")
local PanelFrame = require(Components:WaitForChild("PanelFrame"))
local TabButton = require(Components:WaitForChild("TabButton"))
local ItemCard = require(Components:WaitForChild("ItemCard"))

local CodexUI = {}

local KIND_ORDER: { Types.ItemKind } = { "Fish", "Mushroom", "Flower", "Food" }
local KIND_LABEL: { [Types.ItemKind]: string } = {
	Fish = "물고기",
	Mushroom = "버섯",
	Flower = "꽃",
	Food = "음식",
}
local KIND_ICON_TEXT: { [Types.ItemKind]: string } = {
	Fish = "물",
	Mushroom = "버",
	Flower = "꽃",
	Food = "음",
}

local listFrame: ScrollingFrame? = nil
local screenGuiRef: ScreenGui? = nil
local capacityLabelRef: TextLabel? = nil
local tabs: { [Types.ItemKind]: TabButton.Tab } = {}
local currentKind: Types.ItemKind = "Fish"
local isOpen = false

local inventoryData: { [string]: number } = {}
local codexData: { [string]: any } = {}

local function setActiveTabVisual(kind: Types.ItemKind)
	for tabKind, tab in tabs do
		tab.setSelected(tabKind == kind)
	end
end

local function buildCard(def: Types.ItemDefinition, parent: Instance, layoutOrder: number)
	local discovered = codexData[def.id] ~= nil
	local count = inventoryData[def.id] or 0

	ItemCard.new({
		parent = parent,
		layoutOrder = layoutOrder,
		title = if discovered then def.displayName else "???",
		subText = if discovered then `보유 {count}개` else "아직 발견하지 못했어요",
		iconColor = if discovered then Theme.Rarity[def.rarity] else Theme.Color.Locked,
		iconText = if discovered then KIND_ICON_TEXT[def.kind] else "?",
		locked = not discovered,
		height = 72,
	})
end

local function refreshList()
	local list = listFrame
	if not list then
		return
	end
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local order = 0
	for _, def in ItemDatabase.GetByKind(currentKind) do
		order += 1
		buildCard(def, list, order)
	end
end

local function selectTab(kind: Types.ItemKind)
	currentKind = kind
	setActiveTabVisual(kind)
	refreshList()
end

function CodexUI.Init(playerGui: PlayerGui)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CodexGui"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Enabled = false

	local panel = PanelFrame.new({
		parent = screenGui,
		title = "도감 & 인벤토리",
		onClose = function()
			CodexUI.SetOpen(false)
		end,
	})

	local capacityLabel = Instance.new("TextLabel")
	capacityLabel.Name = "CapacityLabel"
	capacityLabel.BackgroundTransparency = 1
	capacityLabel.Size = UDim2.new(1, 0, 0, 22)
	capacityLabel.Font = Theme.Font.Heading
	capacityLabel.TextColor3 = Theme.Color.Accent
	capacityLabel.TextScaled = true
	capacityLabel.TextXAlignment = Enum.TextXAlignment.Right
	capacityLabel.Text = "가방 0/50"
	capacityLabel.Parent = panel.body
	capacityLabelRef = capacityLabel

	local tabBar = Instance.new("Frame")
	tabBar.Name = "TabBar"
	tabBar.BackgroundTransparency = 1
	tabBar.Position = UDim2.new(0, 0, 0, 30)
	tabBar.Size = UDim2.new(1, 0, 0, 44)
	tabBar.Parent = panel.body

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 8)
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Parent = tabBar

	for i, kind: Types.ItemKind in KIND_ORDER do
		local tab = TabButton.new({
			parent = tabBar,
			text = KIND_LABEL[kind],
			layoutOrder = i,
			width = 84,
		})
		tab.button.Activated:Connect(function()
			selectTab(kind)
		end)
		tabs[kind] = tab
	end

	local scroller = Instance.new("ScrollingFrame")
	scroller.Name = "List"
	scroller.BackgroundTransparency = 1
	scroller.Position = UDim2.new(0, 0, 0, 82)
	scroller.Size = UDim2.new(1, 0, 1, -82)
	scroller.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroller.ScrollBarThickness = 6
	scroller.ScrollBarImageColor3 = Theme.Color.Accent
	scroller.Parent = panel.body

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 8)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = scroller

	listFrame = scroller
	screenGuiRef = screenGui

	-- 모바일 전용 토글 버튼
	if UserInputService.TouchEnabled then
		local mobileButton = Instance.new("TextButton")
		mobileButton.Name = "CodexToggleButton"
		mobileButton.AnchorPoint = Vector2.new(1, 1)
		mobileButton.Position = UDim2.new(1, -16, 1, -100)
		mobileButton.Size = UDim2.new(0, 56, 0, 56)
		mobileButton.BackgroundColor3 = Theme.Color.Panel
		mobileButton.TextColor3 = Theme.Color.Text
		mobileButton.Font = Theme.Font.Heading
		mobileButton.TextScaled = true
		mobileButton.Text = "도감"
		mobileButton.Parent = screenGui

		local mobileCorner = Instance.new("UICorner")
		mobileCorner.CornerRadius = Theme.Corner.Round
		mobileCorner.Parent = mobileButton

		local mobileStroke = Instance.new("UIStroke")
		mobileStroke.Color = Theme.Color.Border
		mobileStroke.Thickness = Theme.Stroke.Button
		mobileStroke.Parent = mobileButton

		mobileButton.Activated:Connect(function()
			CodexUI.Toggle()
		end)
	end

	selectTab("Fish")
	screenGui.Parent = playerGui
end

function CodexUI.SetData(inventory: { [string]: number }, codex: { [string]: any })
	inventoryData = inventory
	codexData = codex
	refreshList()
end

function CodexUI.UpdateItem(itemId: string, newCount: number)
	inventoryData[itemId] = newCount
	if not codexData[itemId] then
		codexData[itemId] = { firstSeenAt = os.time(), count = newCount }
	end
	local def = ItemDatabase.Get(itemId)
	if def and def.kind == currentKind then
		refreshList()
	end
end

function CodexUI.SetCapacity(total: number, capacity: number)
	local label = capacityLabelRef
	if not label then
		return
	end
	label.Text = `가방 {total}/{capacity}`
	label.TextColor3 = if total >= capacity then Theme.Color.AccentRose else Theme.Color.Accent
end

function CodexUI.SetOpen(open: boolean)
	isOpen = open
	if screenGuiRef then
		screenGuiRef.Enabled = open
	end
	if open then
		refreshList()
	end
end

function CodexUI.Toggle()
	CodexUI.SetOpen(not isOpen)
end

return CodexUI
