--!strict
-- 클라이언트 진입점. 서버가 보낸 데이터를 받아 표시만 한다 (읽기 전용).
-- 서버로 보내는 요청은 Purchase/Sell RemoteFunction 뿐이고, 결과는 항상 서버가 검증해 돌려준다.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Features"):WaitForChild("Remotes"))
local ItemDatabase = require(ReplicatedStorage:WaitForChild("Features"):WaitForChild("ItemDatabase"))
local ShopCatalog = require(ReplicatedStorage:WaitForChild("Features"):WaitForChild("ShopCatalog"))
local Types = require(ReplicatedStorage:WaitForChild("Features"):WaitForChild("Types"))

local Toast = require(script.Parent.UI.Toast)
local CodexUI = require(script.Parent.UI.CodexUI)
local ShopUI = require(script.Parent.UI.ShopUI)
local CurrencyHud = require(script.Parent.UI.CurrencyHud)
local FishingUI = require(script.Parent.UI.FishingUI)
local CampfireUI = require(script.Parent.UI.CampfireUI)
local SFX = require(script.Parent.SFX)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

-- 한국어 마지막 글자에 받침이 있는지 본다 (조사 고르는 데 씀).
local function hasBatchim(korean: string): boolean
	local lastCharStart = utf8.offset(korean, -1)
	if not lastCharStart then
		return false
	end
	local ok, codepoint = pcall(utf8.codepoint, korean, lastCharStart)
	if not ok or codepoint < 0xAC00 or codepoint > 0xD7A3 then
		return false
	end
	return (codepoint - 0xAC00) % 28 ~= 0
end

-- "을"/"를" (예: "버섯을", "꽃을")
local function withEul(korean: string): string
	return korean .. (hasBatchim(korean) and "을" or "를")
end

-- "과"/"와" (예: "루비와", "설탕과") — 말 이름과 "가까워졌어요"를 이을 때 쓴다.
local function withGwa(korean: string): string
	return korean .. (hasBatchim(korean) and "과" or "와")
end

local inventoryCache: { [string]: number } = {}
local codexCache: { [string]: any } = {}
local currencyCache: { [string]: number } = {}
local horseAffinityCache: { [string]: number } = {}

local ACORN = ShopCatalog.CURRENCY_ACORN

local PURCHASE_FAILURE_MESSAGE: { [string]: string } = {
	invalid_request = "요청이 이상해요. 다시 시도해주세요.",
	unknown_shop = "그 상점을 찾을 수 없어요.",
	unknown_listing = "이 상점에서 팔지 않는 물건이에요.",
	already_owned = "이미 가지고 있어요.",
	missing_requirement = "먼저 다른 걸 갖추고 와야 해요.",
	not_enough_currency = "도토리가 부족해요.",
	purchase_failed = "지금은 살 수 없어요.",
}

local SELL_FAILURE_MESSAGE: { [string]: string } = {
	invalid_request = "요청이 이상해요. 다시 시도해주세요.",
	invalid_quantity = "개수가 이상해요.",
	unknown_item = "팔 수 없는 물건이에요.",
	not_sellable = "이 아이템은 팔 수 없어요.",
	not_enough_inventory = "가지고 있는 개수보다 많아요.",
	sell_failed = "지금은 팔 수 없어요.",
}

local COOK_FAILURE_MESSAGE: { [string]: string } = {
	invalid_request = "요청이 이상해요. 다시 시도해주세요.",
	unknown_recipe = "그런 레시피는 없어요.",
	missing_ingredients = "재료가 부족해요.",
	cook_failed = "지금은 요리할 수 없어요.",
}

local EAT_FAILURE_MESSAGE: { [string]: string } = {
	invalid_request = "요청이 이상해요. 다시 시도해주세요.",
	not_food = "먹을 수 없는 물건이에요.",
	not_enough_inventory = "가지고 있는 음식이 아니에요.",
	eat_failed = "지금은 먹을 수 없어요.",
}

-- ===== UI 초기화 =====

Toast.Init(playerGui)
CodexUI.Init(playerGui)
CurrencyHud.Init(playerGui)

local purchaseFunction = Remotes.GetFunction("Purchase")
local sellFunction = Remotes.GetFunction("Sell")

local function onPurchaseClicked(shopId: string, listingId: string)
	local ok, reasonCode = purchaseFunction:InvokeServer(shopId, listingId)
	if ok then
		SFX.Play("Purchase")
		ShopUI.MarkOwned(listingId)
		Toast.Show("구매했어요!")
	else
		SFX.Play("PurchaseError")
		local message = (type(reasonCode) == "string" and PURCHASE_FAILURE_MESSAGE[reasonCode]) or "구매하지 못했어요."
		Toast.Show(message, true)
	end
end

local function onSellClicked(itemId: string, quantity: number)
	local ok, reasonCode, totalEarned = sellFunction:InvokeServer(itemId, quantity)
	if ok then
		SFX.Play("Sell")
		local earned = type(totalEarned) == "number" and totalEarned or 0
		Toast.Show(`도토리 {earned}개를 받았어요!`)
	else
		SFX.Play("PurchaseError")
		local message = (type(reasonCode) == "string" and SELL_FAILURE_MESSAGE[reasonCode]) or "팔지 못했어요."
		Toast.Show(message, true)
	end
end

ShopUI.Init(playerGui, {
	OnPurchase = onPurchaseClicked,
	OnSell = onSellClicked,
})

local reactToBiteFunction = Remotes.GetFunction("ReactToBite")

local function onFishingReact()
	-- 서버가 실제 성공/실패를 FishingResult로 알려준다. 여기서는 "눌렀다"는 것만 서버에 전달한다.
	reactToBiteFunction:InvokeServer()
end

FishingUI.Init(playerGui, {
	OnReact = onFishingReact,
})

local cookFunction = Remotes.GetFunction("Cook")
local eatFunction = Remotes.GetFunction("Eat")

local function onCookClicked(recipeId: string)
	local ok, reasonCode = cookFunction:InvokeServer(recipeId)
	if ok then
		SFX.Play("Purchase")
		Toast.Show("맛있게 완성했어요!")
		CampfireUI.RefreshAfterCook()
	else
		SFX.Play("PurchaseError")
		local message = (type(reasonCode) == "string" and COOK_FAILURE_MESSAGE[reasonCode]) or "요리하지 못했어요."
		Toast.Show(message, true)
	end
end

local function onEatClicked(itemId: string)
	local ok, reasonCode = eatFunction:InvokeServer(itemId)
	if ok then
		SFX.Play("Sell")
		Toast.Show("든든해요! 발걸음이 조금 가벼워졌어요.")
	else
		SFX.Play("PurchaseError")
		local message = (type(reasonCode) == "string" and EAT_FAILURE_MESSAGE[reasonCode]) or "먹지 못했어요."
		Toast.Show(message, true)
	end
end

CampfireUI.Init(playerGui, {
	OnCook = onCookClicked,
	OnEat = onEatClicked,
})

-- ===== 서버 이벤트 수신 =====

local inventorySync = Remotes.Get("InventorySync")
local inventoryDelta = Remotes.Get("InventoryDelta")
local itemAdded = Remotes.Get("ItemAdded")
local currencyChanged = Remotes.GetEvent("CurrencyChanged")
local openShop = Remotes.GetEvent("OpenShop")
local fishingCastStarted = Remotes.GetEvent("FishingCastStarted")
local fishingBite = Remotes.GetEvent("FishingBite")
local fishingResult = Remotes.GetEvent("FishingResult")
local affinityChanged = Remotes.GetEvent("AffinityChanged")
local horseCareResult = Remotes.GetEvent("HorseCareResult")
local openCampfire = Remotes.GetEvent("OpenCampfire")
local sleepMessage = Remotes.GetEvent("SleepMessage")

inventorySync.OnClientEvent:Connect(function(payload: Types.InventorySyncPayload)
	inventoryCache = payload.inventory
	codexCache = payload.codex
	currencyCache = payload.currency
	horseAffinityCache = payload.horseAffinity
	CodexUI.SetData(inventoryCache, codexCache)
	ShopUI.SetInventory(inventoryCache)
	CampfireUI.SetInventory(inventoryCache)
	CurrencyHud.Set(currencyCache[ACORN] or 0)
	ShopUI.SetCurrency(currencyCache[ACORN] or 0)
end)

inventoryDelta.OnClientEvent:Connect(function(payload: Types.InventoryDeltaPayload)
	inventoryCache[payload.itemId] = payload.newCount
	CodexUI.UpdateItem(payload.itemId, payload.newCount)
	ShopUI.SetInventory(inventoryCache)
	CampfireUI.SetInventory(inventoryCache)
end)

itemAdded.OnClientEvent:Connect(function(payload: Types.ItemAddedPayload)
	local def = ItemDatabase.Get(payload.itemId)
	local displayName = def and def.displayName or payload.itemId

	Toast.Show(`{withEul(displayName)} 얻었어요 +{payload.amount}`)
	if payload.isNewDiscovery then
		Toast.Show("새로 발견했어요!", true)
	end
end)

currencyChanged.OnClientEvent:Connect(function(payload: Types.CurrencyChangedPayload)
	currencyCache[payload.currencyId] = payload.newAmount
	if payload.currencyId == ACORN then
		CurrencyHud.Set(payload.newAmount)
		ShopUI.SetCurrency(payload.newAmount)
	end
end)

openShop.OnClientEvent:Connect(function(payload: Types.OpenShopPayload)
	CodexUI.SetOpen(false)
	CampfireUI.Close()
	SFX.Play("ShopOpen")
	ShopUI.Open(payload)
end)

openCampfire.OnClientEvent:Connect(function(payload: Types.OpenCampfirePayload)
	CodexUI.SetOpen(false)
	ShopUI.Close()
	SFX.Play("ShopOpen")
	CampfireUI.Open(payload)
end)

sleepMessage.OnClientEvent:Connect(function(message: string)
	Toast.Show(message)
end)

fishingCastStarted.OnClientEvent:Connect(function(payload: Types.FishingCastStartedPayload)
	FishingUI.ShowCasting(payload.spotDisplayName)
end)

fishingBite.OnClientEvent:Connect(function()
	SFX.Play("FishingBite")
	FishingUI.ShowBite()
end)

fishingResult.OnClientEvent:Connect(function(payload: Types.FishingResultPayload)
	if payload.success then
		SFX.Play("FishingCatch")
	else
		SFX.Play("FishingMiss")
	end
	FishingUI.ShowResult(payload.success)
end)

affinityChanged.OnClientEvent:Connect(function(payload: Types.AffinityChangedPayload)
	horseAffinityCache[payload.horseId] = payload.newAmount
end)

horseCareResult.OnClientEvent:Connect(function(payload: Types.HorseCareResultPayload)
	SFX.Play("HorseCare")
	Toast.Show(`{withGwa(payload.horseName)} 조금 더 가까워졌어요!`)
	if payload.tierUp then
		Toast.Show(`이제 "{payload.tierLabel}" 사이예요!`, true)
	end
end)

-- ===== 입력 =====

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.B then
		if ShopUI.IsOpen() then
			ShopUI.Close()
		end
		if CampfireUI.IsOpen() then
			CampfireUI.Close()
		end
		CodexUI.Toggle()
	end
end)
