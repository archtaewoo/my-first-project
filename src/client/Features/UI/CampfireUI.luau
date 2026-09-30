--!strict
-- 모닥불 창. 요리 탭(레시피로 재료 소모해 음식 만들기)과 먹기 탭(가진 음식으로 버프 받기).
-- 서버 호출과 성공/실패 처리는 Main.client.luau가 콜백으로 넘겨준다 — 이 모듈은 화면만 그린다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemDatabase = require(ReplicatedStorage:WaitForChild("Features"):WaitForChild("ItemDatabase"))
local Types = require(ReplicatedStorage:WaitForChild("Features"):WaitForChild("Types"))

local CampfireUI = {}

export type Callbacks = {
	OnCook: (recipeId: string) -> (),
	OnEat: (itemId: string) -> (),
}

local COLOR_BG = Color3.fromRGB(45, 32, 22)
local COLOR_PANEL = Color3.fromRGB(63, 45, 30)
local COLOR_CARD = Color3.fromRGB(77, 56, 38)
local COLOR_TEXT = Color3.fromRGB(248, 238, 220)
local COLOR_TEXT_MUTED = Color3.fromRGB(178, 156, 130)
local COLOR_ACCENT = Color3.fromRGB(196, 160, 112)
local COLOR_BUTTON = Color3.fromRGB(150, 108, 63)
local COLOR_BUTTON_DISABLED = Color3.fromRGB(70, 60, 50)

local screenGuiRef: ScreenGui? = nil
local listFrame: ScrollingFrame? = nil
local cookTabButton: TextButton? = nil
local eatTabButton: TextButton? = nil

local callbacksRef: Callbacks? = nil
local currentPayload: Types.OpenCampfirePayload? = nil
local inventoryCache: { [string]: number } = {}
local currentTab: "Cook" | "Eat" = "Cook"
local isOpen = false

local function clearList()
	local list = listFrame
	if not list then
		return
	end
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
end

local function setActiveTabVisual()
	local cookButton = cookTabButton
	local eatButton = eatTabButton
	if not cookButton or not eatButton then
		return
	end
	if currentTab == "Cook" then
		cookButton.BackgroundColor3 = COLOR_ACCENT
		cookButton.TextColor3 = COLOR_BG
		eatButton.BackgroundColor3 = COLOR_PANEL
		eatButton.TextColor3 = COLOR_TEXT
	else
		eatButton.BackgroundColor3 = COLOR_ACCENT
		eatButton.TextColor3 = COLOR_BG
		cookButton.BackgroundColor3 = COLOR_PANEL
		cookButton.TextColor3 = COLOR_TEXT
	end
end

local function buildRow(parent: Instance): (Frame, TextButton)
	local row = Instance.new("Frame")
	row.BackgroundColor3 = COLOR_CARD
	row.Size = UDim2.new(1, 0, 0, 80)
	row.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = row

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 14)
	padding.PaddingRight = UDim.new(0, 14)
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.Parent = row

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.new(0.62, 0, 0.45, 0)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextColor3 = COLOR_TEXT
	nameLabel.TextScaled = true
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = row

	local descLabel = Instance.new("TextLabel")
	descLabel.Name = "Description"
	descLabel.BackgroundTransparency = 1
	descLabel.Position = UDim2.new(0, 0, 0.45, 0)
	descLabel.Size = UDim2.new(0.62, 0, 0.55, 0)
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextColor3 = COLOR_TEXT_MUTED
	descLabel.TextScaled = true
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextWrapped = true
	descLabel.Parent = row

	local button = Instance.new("TextButton")
	button.Name = "ActionButton"
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, 0, 0.5, 0)
	button.Size = UDim2.new(0.32, 0, 0.7, 0)
	button.BackgroundColor3 = COLOR_BUTTON
	button.TextColor3 = COLOR_TEXT
	button.Font = Enum.Font.GothamBold
	button.TextScaled = true
	button.Parent = row

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 8)
	buttonCorner.Parent = button

	return row, button
end

local function ingredientSummary(recipe: Types.RecipeListingView): string
	local parts: { string } = {}
	for _, ingredient in recipe.ingredients do
		table.insert(parts, `{ingredient.displayName} {ingredient.owned}/{ingredient.needed}`)
	end
	return table.concat(parts, ", ")
end

local function renderCookTab()
	clearList()
	local list = listFrame
	local payload = currentPayload
	if not list or not payload then
		return
	end

	for _, recipe in payload.recipes do
		local row, button = buildRow(list)
		local nameLabel = row:FindFirstChild("Name") :: TextLabel
		local descLabel = row:FindFirstChild("Description") :: TextLabel
		nameLabel.Text = recipe.displayName
		descLabel.Text = `{recipe.description} (필요: {ingredientSummary(recipe)})`

		if recipe.craftable then
			button.Text = "요리하기"
			button.BackgroundColor3 = COLOR_BUTTON
			button.AutoButtonColor = true
			button.Activated:Connect(function()
				if callbacksRef then
					callbacksRef.OnCook(recipe.id)
				end
			end)
		else
			button.Text = "재료 부족"
			button.BackgroundColor3 = COLOR_BUTTON_DISABLED
			button.AutoButtonColor = false
		end
	end
end

local function renderEatTab()
	clearList()
	local list = listFrame
	if not list then
		return
	end

	local rows = 0
	for itemId, count in inventoryCache do
		if count <= 0 then
			continue
		end
		local def = ItemDatabase.Get(itemId)
		if not def or def.kind ~= "Food" then
			continue
		end

		rows += 1
		local row, button = buildRow(list)
		local nameLabel = row:FindFirstChild("Name") :: TextLabel
		local descLabel = row:FindFirstChild("Description") :: TextLabel
		nameLabel.Text = `{def.displayName} ({count}개 보유)`
		descLabel.Text = "먹으면 잠시 발걸음이 가벼워져요."

		button.Text = "먹기"
		button.Activated:Connect(function()
			if callbacksRef then
				callbacksRef.OnEat(itemId)
			end
		end)
	end

	if rows == 0 then
		local emptyLabel = Instance.new("TextLabel")
		emptyLabel.BackgroundTransparency = 1
		emptyLabel.Size = UDim2.new(1, 0, 0, 60)
		emptyLabel.Font = Enum.Font.Gotham
		emptyLabel.TextColor3 = COLOR_TEXT_MUTED
		emptyLabel.TextScaled = true
		emptyLabel.Text = "먹을 음식이 없어요. 요리 탭에서 만들어 보세요!"
		emptyLabel.Parent = list
	end
end

local function refreshCurrentTab()
	if not isOpen then
		return
	end
	if currentTab == "Cook" then
		renderCookTab()
	else
		renderEatTab()
	end
end

local function selectTab(tab: "Cook" | "Eat")
	currentTab = tab
	setActiveTabVisual()
	refreshCurrentTab()
end

function CampfireUI.Init(playerGui: PlayerGui, callbacks: Callbacks)
	callbacksRef = callbacks

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CampfireGui"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Enabled = false

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.new(0.5, 0, 0.5, 0)
	panel.Size = UDim2.new(0.85, 0, 0.78, 0)
	panel.BackgroundColor3 = COLOR_BG
	panel.Parent = screenGui

	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 16)
	panelCorner.Parent = panel

	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = COLOR_ACCENT
	panelStroke.Thickness = 2
	panelStroke.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.new(0, 20, 0, 8)
	title.Size = UDim2.new(1, -60, 0, 40)
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = COLOR_TEXT
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "모닥불"
	title.Parent = panel

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
	closeButton.Parent = panel

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(1, 0)
	closeCorner.Parent = closeButton

	closeButton.Activated:Connect(function()
		CampfireUI.Close()
	end)

	local tabBar = Instance.new("Frame")
	tabBar.Name = "TabBar"
	tabBar.BackgroundTransparency = 1
	tabBar.Position = UDim2.new(0, 20, 0, 60)
	tabBar.Size = UDim2.new(1, -40, 0, 40)
	tabBar.Parent = panel

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 8)
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Parent = tabBar

	local cookButton = Instance.new("TextButton")
	cookButton.Name = "CookTab"
	cookButton.Size = UDim2.new(0, 100, 1, 0)
	cookButton.BackgroundColor3 = COLOR_PANEL
	cookButton.TextColor3 = COLOR_TEXT
	cookButton.Font = Enum.Font.GothamMedium
	cookButton.TextScaled = true
	cookButton.Text = "요리"
	cookButton.Parent = tabBar
	local cookCorner = Instance.new("UICorner")
	cookCorner.CornerRadius = UDim.new(0, 10)
	cookCorner.Parent = cookButton
	cookButton.Activated:Connect(function()
		selectTab("Cook")
	end)

	local eatButton = Instance.new("TextButton")
	eatButton.Name = "EatTab"
	eatButton.LayoutOrder = 2
	eatButton.Size = UDim2.new(0, 100, 1, 0)
	eatButton.BackgroundColor3 = COLOR_PANEL
	eatButton.TextColor3 = COLOR_TEXT
	eatButton.Font = Enum.Font.GothamMedium
	eatButton.TextScaled = true
	eatButton.Text = "먹기"
	eatButton.Parent = tabBar
	local eatCorner = Instance.new("UICorner")
	eatCorner.CornerRadius = UDim.new(0, 10)
	eatCorner.Parent = eatButton
	eatButton.Activated:Connect(function()
		selectTab("Eat")
	end)

	local scroller = Instance.new("ScrollingFrame")
	scroller.Name = "List"
	scroller.BackgroundTransparency = 1
	scroller.Position = UDim2.new(0, 20, 0, 110)
	scroller.Size = UDim2.new(1, -40, 1, -130)
	scroller.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroller.ScrollBarThickness = 6
	scroller.Parent = panel

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 10)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = scroller

	listFrame = scroller
	cookTabButton = cookButton
	eatTabButton = eatButton

	screenGuiRef = screenGui
	screenGui.Parent = playerGui
end

function CampfireUI.Open(payload: Types.OpenCampfirePayload)
	currentPayload = payload
	currentTab = "Cook"
	isOpen = true

	setActiveTabVisual()
	renderCookTab()

	if screenGuiRef then
		screenGuiRef.Enabled = true
	end
end

function CampfireUI.Close()
	isOpen = false
	currentPayload = nil
	if screenGuiRef then
		screenGuiRef.Enabled = false
	end
end

function CampfireUI.IsOpen(): boolean
	return isOpen
end

function CampfireUI.SetInventory(inventory: { [string]: number })
	inventoryCache = inventory
	if isOpen and currentTab == "Eat" then
		renderEatTab()
	end
end

-- 요리 성공 직후 서버 재조회 없이 즉시 반영: 방금 쓴 재료 개수를 화면에서 먼저 줄여 보여준다.
-- (실제 정확한 값은 곧 InventoryDelta로 뒤따라온다.)
function CampfireUI.RefreshAfterCook()
	if isOpen and currentTab == "Cook" then
		-- currentPayload의 craftable 판정은 서버가 다시 열어줄 때 갱신되므로,
		-- 여기서는 재료 표시만 최신 inventoryCache 기준으로 다시 계산해 보여준다.
		local payload = currentPayload
		if not payload then
			return
		end
		for _, recipe in payload.recipes do
			local craftable = true
			for _, ingredient in recipe.ingredients do
				ingredient.owned = inventoryCache[ingredient.itemId] or 0
				if ingredient.owned < ingredient.needed then
					craftable = false
				end
			end
			recipe.craftable = craftable
		end
		renderCookTab()
	end
end

return CampfireUI
