--!strict
-- 상점 창. ProximityPrompt로 상점을 열면 뜬다. 구매/판매 두 탭.
-- 실제 서버 호출과 성공/실패 처리는 Main.client.luau가 콜백으로 넘겨준 함수가 담당한다 —
-- 이 모듈은 오직 화면을 그리고 클릭을 전달하는 역할만 한다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemDatabase = require(ReplicatedStorage:WaitForChild("Features"):WaitForChild("ItemDatabase"))
local ShopCatalog = require(ReplicatedStorage:WaitForChild("Features"):WaitForChild("ShopCatalog"))
local Types = require(ReplicatedStorage:WaitForChild("Features"):WaitForChild("Types"))

local ShopUI = {}

export type Callbacks = {
	OnPurchase: (shopId: string, listingId: string) -> (),
	OnSell: (itemId: string, quantity: number) -> (),
}

local COLOR_BG = Color3.fromRGB(45, 32, 22)
local COLOR_PANEL = Color3.fromRGB(63, 45, 30)
local COLOR_CARD = Color3.fromRGB(77, 56, 38)
local COLOR_TEXT = Color3.fromRGB(248, 238, 220)
local COLOR_TEXT_MUTED = Color3.fromRGB(178, 156, 130)
local COLOR_ACCENT = Color3.fromRGB(196, 160, 112)
local COLOR_BUTTON = Color3.fromRGB(150, 108, 63)
local COLOR_BUTTON_DISABLED = Color3.fromRGB(70, 60, 50)

local RARITY_LABEL: { [Types.Rarity]: string } = {
	Common = "일반",
	Uncommon = "고급",
	Rare = "희귀",
	Legendary = "전설",
}

local screenGuiRef: ScreenGui? = nil
local panelRef: Frame? = nil
local greetingLabel: TextLabel? = nil
local currencyLabel: TextLabel? = nil
local listFrame: ScrollingFrame? = nil
local buyTabButton: TextButton? = nil
local sellTabButton: TextButton? = nil

local callbacksRef: Callbacks? = nil
local currentPayload: Types.OpenShopPayload? = nil
local inventoryCache: { [string]: number } = {}
local currencyAmount = 0
local currentTab: "Buy" | "Sell" = "Buy"
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
	local buyButton = buyTabButton
	local sellButton = sellTabButton
	if not buyButton or not sellButton then
		return
	end
	if currentTab == "Buy" then
		buyButton.BackgroundColor3 = COLOR_ACCENT
		buyButton.TextColor3 = COLOR_BG
		sellButton.BackgroundColor3 = COLOR_PANEL
		sellButton.TextColor3 = COLOR_TEXT
	else
		sellButton.BackgroundColor3 = COLOR_ACCENT
		sellButton.TextColor3 = COLOR_BG
		buyButton.BackgroundColor3 = COLOR_PANEL
		buyButton.TextColor3 = COLOR_TEXT
	end
end

local function buildRow(parent: Instance): (Frame, TextButton)
	local row = Instance.new("Frame")
	row.BackgroundColor3 = COLOR_CARD
	row.Size = UDim2.new(1, 0, 0, 76)
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
	nameLabel.Size = UDim2.new(0.62, 0, 0.5, 0)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextColor3 = COLOR_TEXT
	nameLabel.TextScaled = true
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = row

	local descLabel = Instance.new("TextLabel")
	descLabel.Name = "Description"
	descLabel.BackgroundTransparency = 1
	descLabel.Position = UDim2.new(0, 0, 0.5, 0)
	descLabel.Size = UDim2.new(0.62, 0, 0.5, 0)
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

local function renderBuyTab()
	clearList()
	local list = listFrame
	local payload = currentPayload
	if not list or not payload then
		return
	end

	if #payload.listings == 0 then
		local emptyLabel = Instance.new("TextLabel")
		emptyLabel.BackgroundTransparency = 1
		emptyLabel.Size = UDim2.new(1, 0, 0, 60)
		emptyLabel.Font = Enum.Font.Gotham
		emptyLabel.TextColor3 = COLOR_TEXT_MUTED
		emptyLabel.TextScaled = true
		emptyLabel.Text = "이 상점은 판매만 받아요 — 팔 물건이 있으면 판매 탭을 열어보세요."
		emptyLabel.Parent = list
		return
	end

	for _, listing in payload.listings do
		local row, button = buildRow(list)
		local nameLabel = row:FindFirstChild("Name") :: TextLabel
		local descLabel = row:FindFirstChild("Description") :: TextLabel
		nameLabel.Text = `{listing.displayName} · {listing.price} 도토리`
		descLabel.Text = listing.description

		if listing.alreadyOwned then
			button.Text = "보유 중"
			button.BackgroundColor3 = COLOR_BUTTON_DISABLED
			button.AutoButtonColor = false
		else
			local affordable = currencyAmount >= listing.price
			button.Text = affordable and "구매" or "도토리 부족"
			button.BackgroundColor3 = affordable and COLOR_BUTTON or COLOR_BUTTON_DISABLED
			button.AutoButtonColor = affordable
			if affordable then
				button.Activated:Connect(function()
					if callbacksRef then
						callbacksRef.OnPurchase(payload.shopId, listing.id)
					end
				end)
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

	local rows = 0
	for itemId, count in inventoryCache do
		if count <= 0 then
			continue
		end
		local def = ItemDatabase.Get(itemId)
		if not def or not ShopCatalog.IsSellable(def.kind) then
			continue
		end

		rows += 1
		local unitPrice = ShopCatalog.SellPriceFor(def.rarity)
		local row, button = buildRow(list)
		local nameLabel = row:FindFirstChild("Name") :: TextLabel
		local descLabel = row:FindFirstChild("Description") :: TextLabel
		nameLabel.Text = `{def.displayName} ({count}개 보유)`
		descLabel.Text = `{RARITY_LABEL[def.rarity]} · 개당 {unitPrice} 도토리`

		button.Text = "1개 팔기"
		button.Activated:Connect(function()
			if callbacksRef then
				callbacksRef.OnSell(itemId, 1)
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
		emptyLabel.Text = "팔 수 있는 물건이 아직 없어요. 숲에서 버섯이나 꽃을 모아 와 보세요!"
		emptyLabel.Parent = list
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
	title.Size = UDim2.new(1, -60, 0, 32)
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = COLOR_TEXT
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "상점"
	title.Parent = panel

	local greeting = Instance.new("TextLabel")
	greeting.Name = "Greeting"
	greeting.BackgroundTransparency = 1
	greeting.Position = UDim2.new(0, 20, 0, 40)
	greeting.Size = UDim2.new(1, -60, 0, 26)
	greeting.Font = Enum.Font.Gotham
	greeting.TextColor3 = COLOR_TEXT_MUTED
	greeting.TextScaled = true
	greeting.TextXAlignment = Enum.TextXAlignment.Left
	greeting.Parent = panel

	local currency = Instance.new("TextLabel")
	currency.Name = "Currency"
	currency.BackgroundTransparency = 1
	currency.Position = UDim2.new(0, 20, 0, 66)
	currency.Size = UDim2.new(1, -60, 0, 22)
	currency.Font = Enum.Font.GothamMedium
	currency.TextColor3 = COLOR_ACCENT
	currency.TextScaled = true
	currency.TextXAlignment = Enum.TextXAlignment.Left
	currency.Parent = panel

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
		ShopUI.Close()
	end)

	local tabBar = Instance.new("Frame")
	tabBar.Name = "TabBar"
	tabBar.BackgroundTransparency = 1
	tabBar.Position = UDim2.new(0, 20, 0, 96)
	tabBar.Size = UDim2.new(1, -40, 0, 40)
	tabBar.Parent = panel

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 8)
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Parent = tabBar

	local buyButton = Instance.new("TextButton")
	buyButton.Name = "BuyTab"
	buyButton.Size = UDim2.new(0, 100, 1, 0)
	buyButton.BackgroundColor3 = COLOR_PANEL
	buyButton.TextColor3 = COLOR_TEXT
	buyButton.Font = Enum.Font.GothamMedium
	buyButton.TextScaled = true
	buyButton.Text = "구매"
	buyButton.Parent = tabBar
	local buyCorner = Instance.new("UICorner")
	buyCorner.CornerRadius = UDim.new(0, 10)
	buyCorner.Parent = buyButton
	buyButton.Activated:Connect(function()
		selectTab("Buy")
	end)

	local sellButton = Instance.new("TextButton")
	sellButton.Name = "SellTab"
	sellButton.LayoutOrder = 2
	sellButton.Size = UDim2.new(0, 100, 1, 0)
	sellButton.BackgroundColor3 = COLOR_PANEL
	sellButton.TextColor3 = COLOR_TEXT
	sellButton.Font = Enum.Font.GothamMedium
	sellButton.TextScaled = true
	sellButton.Text = "판매"
	sellButton.Parent = tabBar
	local sellCorner = Instance.new("UICorner")
	sellCorner.CornerRadius = UDim.new(0, 10)
	sellCorner.Parent = sellButton
	sellButton.Activated:Connect(function()
		selectTab("Sell")
	end)

	local scroller = Instance.new("ScrollingFrame")
	scroller.Name = "List"
	scroller.BackgroundTransparency = 1
	scroller.Position = UDim2.new(0, 20, 0, 146)
	scroller.Size = UDim2.new(1, -40, 1, -166)
	scroller.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroller.ScrollBarThickness = 6
	scroller.Parent = panel

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 10)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = scroller

	panelRef = panel
	greetingLabel = greeting
	currencyLabel = currency
	listFrame = scroller
	buyTabButton = buyButton
	sellTabButton = sellButton

	screenGuiRef = screenGui
	screenGui.Parent = playerGui
end

function ShopUI.Open(payload: Types.OpenShopPayload)
	currentPayload = payload
	currentTab = "Buy"
	isOpen = true

	local panel = panelRef
	if panel then
		local title = panel:FindFirstChild("Title") :: TextLabel?
		if title then
			title.Text = payload.shopDisplayName
		end
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
