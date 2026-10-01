--!strict
-- 상점 창. ProximityPrompt로 상점을 열면 뜬다. 구매/판매 두 탭.
-- 실제 서버 호출과 성공/실패 처리는 Main.client.luau가 콜백으로 넘겨준 함수가 담당한다 —
-- 이 모듈은 오직 화면을 그리고 클릭을 전달하는 역할만 한다.
--
-- 공통 디자인 틀(Theme/Components)로 조립한다 - 데이터 흐름(Init/Open/Close/IsOpen/
-- SetInventory/SetCurrency/MarkOwned)은 전과 동일하고 겉모습만 바뀌었다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemDatabase = require(ReplicatedStorage:WaitForChild("Features"):WaitForChild("ItemDatabase"))
local ShopCatalog = require(ReplicatedStorage:WaitForChild("Features"):WaitForChild("ShopCatalog"))
local Types = require(ReplicatedStorage:WaitForChild("Features"):WaitForChild("Types"))

local UIFolder = ReplicatedStorage:WaitForChild("Features"):WaitForChild("UI")
local Theme = require(UIFolder:WaitForChild("Theme"))
local Components = UIFolder:WaitForChild("Components")
local PanelFrame = require(Components:WaitForChild("PanelFrame"))
local TabButton = require(Components:WaitForChild("TabButton"))
local ItemCard = require(Components:WaitForChild("ItemCard"))

local ShopUI = {}

export type Callbacks = {
	OnPurchase: (shopId: string, listingId: string) -> (),
	OnSell: (itemId: string, quantity: number) -> (),
}

local RARITY_LABEL: { [Types.Rarity]: string } = {
	Common = "일반",
	Uncommon = "고급",
	Rare = "희귀",
	Legendary = "전설",
}

local screenGuiRef: ScreenGui? = nil
local titleLabelRef: TextLabel? = nil
local greetingLabel: TextLabel? = nil
local currencyLabel: TextLabel? = nil
local listFrame: ScrollingFrame? = nil
local buyTab: TabButton.Tab? = nil
local sellTab: TabButton.Tab? = nil

local callbacksRef: Callbacks? = nil
local currentPayload: Types.OpenShopPayload? = nil
local inventoryCache: { [string]: number } = {}
local currencyAmount = 0
local currentTab: "Buy" | "Sell" = "Buy"
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
	if buyTab then
		buyTab.setSelected(currentTab == "Buy")
	end
	if sellTab then
		sellTab.setSelected(currentTab == "Sell")
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

local function renderBuyTab()
	clearList()
	local list = listFrame
	local payload = currentPayload
	if not list or not payload then
		return
	end

	if #payload.listings == 0 then
		showEmpty(list, "이 상점은 판매만 받아요 — 팔 물건이 있으면 판매 탭을 열어보세요.")
		return
	end

	for order, listing in payload.listings do
		local actionText: string
		local enabled: boolean
		if listing.alreadyOwned then
			actionText, enabled = "보유 중", false
		else
			local affordable = currencyAmount >= listing.price
			actionText = if affordable then "구매" else "도토리 부족"
			enabled = affordable
		end

		local card = ItemCard.new({
			parent = list,
			layoutOrder = order,
			title = `{listing.displayName} · {listing.price} 도토리`,
			subText = listing.description,
			iconText = firstGlyph(listing.displayName),
			actionText = actionText,
			height = 80,
		})

		local button = card.actionButton
		if button then
			if enabled then
				button.Activated:Connect(function()
					if callbacksRef then
						callbacksRef.OnPurchase(payload.shopId, listing.id)
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

local function renderSellTab()
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
		if not def or not ShopCatalog.IsSellable(def.kind) then
			continue
		end

		order += 1
		local unitPrice = ShopCatalog.SellPriceFor(def.rarity)
		local card = ItemCard.new({
			parent = list,
			layoutOrder = order,
			title = `{def.displayName} ({count}개 보유)`,
			subText = `{RARITY_LABEL[def.rarity]} · 개당 {unitPrice} 도토리`,
			iconColor = Theme.Rarity[def.rarity],
			iconText = firstGlyph(def.displayName),
			actionText = "1개 팔기",
			height = 80,
		})

		local button = card.actionButton
		if button then
			button.Activated:Connect(function()
				if callbacksRef then
					callbacksRef.OnSell(itemId, 1)
				end
			end)
		end
	end

	if order == 0 then
		showEmpty(list, "팔 수 있는 물건이 아직 없어요. 숲에서 버섯이나 꽃을 모아 와 보세요!")
	end
end

local function refreshCurrentTab()
	if not isOpen then
		return
	end
	if currentTab == "Buy" then
		renderBuyTab()
	else
		renderSellTab()
	end
end

local function selectTab(tab: "Buy" | "Sell")
	currentTab = tab
	setActiveTabVisual()
	refreshCurrentTab()
end

function ShopUI.Init(playerGui: PlayerGui, callbacks: Callbacks)
	callbacksRef = callbacks

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ShopGui"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Enabled = false

	local panel = PanelFrame.new({
		parent = screenGui,
		title = "상점",
		onClose = function()
			ShopUI.Close()
		end,
	})
	titleLabelRef = panel.titleLabel

	local greeting = Instance.new("TextLabel")
	greeting.Name = "Greeting"
	greeting.BackgroundTransparency = 1
	greeting.Size = UDim2.new(1, 0, 0, 24)
	greeting.Font = Theme.Font.BodyLight
	greeting.TextColor3 = Theme.Color.TextMuted
	greeting.TextScaled = true
	greeting.TextXAlignment = Enum.TextXAlignment.Left
	greeting.Parent = panel.body

	local currency = Instance.new("TextLabel")
	currency.Name = "Currency"
	currency.BackgroundTransparency = 1
	currency.Position = UDim2.new(0, 0, 0, 26)
	currency.Size = UDim2.new(1, 0, 0, 22)
	currency.Font = Theme.Font.Heading
	currency.TextColor3 = Theme.Color.Accent
	currency.TextScaled = true
	currency.TextXAlignment = Enum.TextXAlignment.Left
	currency.Parent = panel.body

	local tabBar = Instance.new("Frame")
	tabBar.Name = "TabBar"
	tabBar.BackgroundTransparency = 1
	tabBar.Position = UDim2.new(0, 0, 0, 56)
	tabBar.Size = UDim2.new(1, 0, 0, 44)
	tabBar.Parent = panel.body

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 8)
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Parent = tabBar

	local buy = TabButton.new({ parent = tabBar, text = "구매", layoutOrder = 1, width = 100 })
	buy.button.Activated:Connect(function()
		selectTab("Buy")
	end)
	buyTab = buy

	local sell = TabButton.new({ parent = tabBar, text = "판매", layoutOrder = 2, width = 100 })
	sell.button.Activated:Connect(function()
		selectTab("Sell")
	end)
	sellTab = sell

	local scroller = Instance.new("ScrollingFrame")
	scroller.Name = "List"
	scroller.BackgroundTransparency = 1
	scroller.Position = UDim2.new(0, 0, 0, 108)
	scroller.Size = UDim2.new(1, 0, 1, -108)
	scroller.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroller.ScrollBarThickness = 6
	scroller.ScrollBarImageColor3 = Theme.Color.Accent
	scroller.Parent = panel.body

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 10)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = scroller

	greetingLabel = greeting
	currencyLabel = currency
	listFrame = scroller

	screenGuiRef = screenGui
	screenGui.Parent = playerGui
end

function ShopUI.Open(payload: Types.OpenShopPayload)
	currentPayload = payload
	currentTab = "Buy"
	isOpen = true

	if titleLabelRef then
		titleLabelRef.Text = payload.shopDisplayName
	end
	if greetingLabel then
		greetingLabel.Text = payload.greeting
	end
	if currencyLabel then
		currencyLabel.Text = `보유: {currencyAmount} 도토리`
	end

	setActiveTabVisual()
	renderBuyTab()

	if screenGuiRef then
		screenGuiRef.Enabled = true
	end
end

function ShopUI.Close()
	isOpen = false
	currentPayload = nil
	if screenGuiRef then
		screenGuiRef.Enabled = false
	end
end

function ShopUI.IsOpen(): boolean
	return isOpen
end

function ShopUI.SetInventory(inventory: { [string]: number })
	inventoryCache = inventory
	if isOpen and currentTab == "Sell" then
		renderSellTab()
	end
end

function ShopUI.SetCurrency(amount: number)
	currencyAmount = amount
	if currencyLabel and isOpen then
		currencyLabel.Text = `보유: {amount} 도토리`
	end
	if isOpen and currentTab == "Buy" then
		renderBuyTab()
	end
end

-- 구매 직후 alreadyOwned를 서버 재조회 없이 즉시 반영해서 버튼이 바로 "보유 중"으로 바뀌게 한다.
function ShopUI.MarkOwned(listingId: string)
	local payload = currentPayload
	if not payload then
		return
	end
	for _, listing in payload.listings do
		if listing.id == listingId then
			listing.alreadyOwned = true
		end
	end
	if isOpen and currentTab == "Buy" then
		renderBuyTab()
	end
end

return ShopUI
