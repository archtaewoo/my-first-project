--!strict
-- 모닥불 창. 요리 탭(레시피로 재료 소모해 음식 만들기)과 먹기 탭(가진 음식으로 버프 받기).
-- 서버 호출과 성공/실패 처리는 Main.client.luau가 콜백으로 넘겨준다 — 이 모듈은 화면만 그린다.
--
-- 공통 디자인 틀(Theme/Components)로 조립한다 - 데이터 흐름(Init/Open/Close/IsOpen/
-- SetInventory/RefreshAfterCook)은 전과 동일하고 겉모습만 바뀌었다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemDatabase = require(ReplicatedStorage:WaitForChild("Features"):WaitForChild("ItemDatabase"))
local Types = require(ReplicatedStorage:WaitForChild("Features"):WaitForChild("Types"))

local UIFolder = ReplicatedStorage:WaitForChild("Features"):WaitForChild("UI")
local Theme = require(UIFolder:WaitForChild("Theme"))
local Components = UIFolder:WaitForChild("Components")
local PanelFrame = require(Components:WaitForChild("PanelFrame"))
local TabButton = require(Components:WaitForChild("TabButton"))
local ItemCard = require(Components:WaitForChild("ItemCard"))

local CampfireUI = {}

export type Callbacks = {
	OnCook: (recipeId: string) -> (),
	OnEat: (itemId: string) -> (),
}

local screenGuiRef: ScreenGui? = nil
local listFrame: ScrollingFrame? = nil
local cookTab: TabButton.Tab? = nil
local eatTab: TabButton.Tab? = nil

local callbacksRef: Callbacks? = nil
local currentPayload: Types.OpenCampfirePayload? = nil
local inventoryCache: { [string]: number } = {}
local currentTab: "Cook" | "Eat" = "Cook"
local isOpen = false

local function firstGlyph(text: string): string
	local stop = utf8.offset(text, 2)
	if not stop then
		return text
	end
	return string.sub(text, 1, stop - 1)
end

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
	if cookTab then
		cookTab.setSelected(currentTab == "Cook")
	end
	if eatTab then
		eatTab.setSelected(currentTab == "Eat")
	end
end

local function showEmpty(parent: Instance, text: string)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 60)
	label.Font = Theme.Font.BodyLight
	label.TextColor3 = Theme.Color.TextMuted
	label.TextScaled = true
	label.TextWrapped = true
	label.Text = text
	label.Parent = parent
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

	for order, recipe in payload.recipes do
		local card = ItemCard.new({
			parent = list,
			layoutOrder = order,
			title = recipe.displayName,
			subText = `{recipe.description} (필요: {ingredientSummary(recipe)})`,
			iconText = firstGlyph(recipe.displayName),
			actionText = if recipe.craftable then "요리하기" else "재료 부족",
			height = 84,
		})

		local button = card.actionButton
		if button then
			if recipe.craftable then
				button.Activated:Connect(function()
					if callbacksRef then
						callbacksRef.OnCook(recipe.id)
					end
				end)
			else
				button.AutoButtonColor = false
				button.BackgroundColor3 = Theme.Color.Locked
				button.TextColor3 = Theme.Color.LockedText
			end
		end
	end
end

local function renderEatTab()
	clearList()
	local list = listFrame
	if not list then
		return
	end

	local order = 0
	for itemId, count in inventoryCache do
		if count <= 0 then
			continue
		end
		local def = ItemDatabase.Get(itemId)
		if not def or def.kind ~= "Food" then
			continue
		end

		order += 1
		local card = ItemCard.new({
			parent = list,
			layoutOrder = order,
			title = `{def.displayName} ({count}개 보유)`,
			subText = "먹으면 잠시 발걸음이 가벼워져요.",
			iconText = firstGlyph(def.displayName),
			actionText = "먹기",
			height = 80,
		})

		local button = card.actionButton
		if button then
			button.Activated:Connect(function()
				if callbacksRef then
					callbacksRef.OnEat(itemId)
				end
			end)
		end
	end

	if order == 0 then
		showEmpty(list, "먹을 음식이 없어요. 요리 탭에서 만들어 보세요!")
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

	local panel = PanelFrame.new({
		parent = screenGui,
		title = "모닥불",
		onClose = function()
			CampfireUI.Close()
		end,
	})

	local tabBar = Instance.new("Frame")
	tabBar.Name = "TabBar"
	tabBar.BackgroundTransparency = 1
	tabBar.Size = UDim2.new(1, 0, 0, 44)
	tabBar.Parent = panel.body

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 8)
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Parent = tabBar

	local cook = TabButton.new({ parent = tabBar, text = "요리", layoutOrder = 1, width = 100 })
	cook.button.Activated:Connect(function()
		selectTab("Cook")
	end)
	cookTab = cook

	local eat = TabButton.new({ parent = tabBar, text = "먹기", layoutOrder = 2, width = 100 })
	eat.button.Activated:Connect(function()
		selectTab("Eat")
	end)
	eatTab = eat

	local scroller = Instance.new("ScrollingFrame")
	scroller.Name = "List"
	scroller.BackgroundTransparency = 1
	scroller.Position = UDim2.new(0, 0, 0, 56)
	scroller.Size = UDim2.new(1, 0, 1, -56)
	scroller.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroller.ScrollBarThickness = 6
	scroller.ScrollBarImageColor3 = Theme.Color.Accent
	scroller.Parent = panel.body

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 10)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = scroller

	listFrame = scroller

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
