--!strict
-- 시장(건물 5곳 + 좌판 6곳)을 관리한다: 태그/속성 점검, ProximityPrompt 부착,
-- 상점 열기·구매·판매를 전부 서버에서 검증한다. 클라이언트가 보내는 가격/재고는 절대 신뢰하지 않는다.
--
-- 식별 원칙(이 환경에서 CollectionService 태그가 저장 과정 중 사라진 적이 있어서):
--   태그는 참고용, 속성(Attribute)이 우선. Stall은 자식 "VendorAnchor"의 StallType 속성을
--   신뢰하고, 태그가 비어있으면 다시 달아준다. Building은 아직 태그·속성이 전혀 없으므로,
--   서버 시작 시 한 번만 모델 이름 -> BuildingType 속성으로 부트스트랩한다.

local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ShopCatalog = require(ReplicatedStorage:WaitForChild("Features"):WaitForChild("ShopCatalog"))
local ItemDatabase = require(ReplicatedStorage:WaitForChild("Features"):WaitForChild("ItemDatabase"))
local Remotes = require(ReplicatedStorage:WaitForChild("Features"):WaitForChild("Remotes"))

local PlayerData = require(script.Parent.PlayerData)

local MARKET_BUILDING_TAG = "MarketBuilding"
local MARKET_STALL_TAG = "MarketStall"
local PROMPT_ACTION_TEXT = "상점 열기"
local PROMPT_HOLD_DURATION = 0.4
local PROMPT_MAX_DISTANCE = 10
local MAX_SELL_QUANTITY = 999

local KNOWN_BUILDING_TYPES: { [string]: boolean } = {
	Bakery = true,
	Warehouse = true,
	Smithy = true,
	WellHut = true,
	ToyShop = true,
}

local MarketService = {}

local function findAnchorPart(instance: Instance): BasePart?
	if instance:IsA("BasePart") then
		return instance
	end
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") then
			return descendant
		end
	end
	return nil
end

local function setupPrompt(anchor: BasePart, shopDef: ShopCatalog.ShopDefinition, onTrigger: (Player) -> ())
	local existingPrompt = anchor:FindFirstChildOfClass("ProximityPrompt") :: ProximityPrompt?
	local prompt: ProximityPrompt
	if existingPrompt then
		prompt = existingPrompt
	else
		prompt = Instance.new("ProximityPrompt")
		prompt.Parent = anchor
	end
	prompt.ActionText = PROMPT_ACTION_TEXT
	prompt.ObjectText = shopDef.displayName
	prompt.HoldDuration = PROMPT_HOLD_DURATION
	prompt.MaxActivationDistance = PROMPT_MAX_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Enabled = true
	prompt.Triggered:Connect(onTrigger)
end

local function resolveListings(player: Player, shopDef: ShopCatalog.ShopDefinition)
	local views = {}
	for _, listing in shopDef.listings do
		local alreadyOwned = false
		if listing.kind == "BuyUpgrade" then
			alreadyOwned = PlayerData.HasUpgrade(player, listing.id)
		end
		table.insert(views, {
			id = listing.id,
			kind = listing.kind,
			displayName = listing.displayName,
			description = listing.description,
			price = listing.price,
			currencyId = listing.currencyId,
			alreadyOwned = alreadyOwned,
		})
	end
	return views
end

local function onShopTriggered(shopId: ShopCatalog.ShopId, player: Player)
	local shopDef = ShopCatalog.Get(shopId)
	if not shopDef then
		return
	end
	Remotes.GetEvent("OpenShop"):FireClient(player, {
		shopId = shopId,
		shopDisplayName = shopDef.displayName,
		greeting = shopDef.greeting,
		listings = resolveListings(player, shopDef),
	})
end

local function setupBuilding(instance: Instance)
	local rawType = instance:GetAttribute("BuildingType")
	local buildingType: string
	if type(rawType) == "string" then
		buildingType = rawType
	elseif KNOWN_BUILDING_TYPES[instance.Name] then
		-- 처음 보는(속성 없는) 건물이면 고정된 5개 이름 중 하나일 때만 1회성으로 채워 넣는다.
		instance:SetAttribute("BuildingType", instance.Name)
		buildingType = instance.Name
	else
		warn(`[MarketService] {instance:GetFullName()} 의 이름이 알려진 건물 종류(Bakery/Warehouse/Smithy/WellHut/ToyShop)와 다릅니다`)
		return
	end

	if not CollectionService:HasTag(instance, MARKET_BUILDING_TAG) then
		CollectionService:AddTag(instance, MARKET_BUILDING_TAG)
	end

	local maybeShopId: ShopCatalog.ShopId? = ShopCatalog.ShopIdForBuildingType(buildingType)
	if not maybeShopId then
		warn(`[MarketService] {instance:GetFullName()} 의 BuildingType({buildingType})에 대응하는 상점 정의가 없습니다`)
		return
	end
	-- 새 로컬 변수로 다시 받아둔다: nil 체크로 좁혀진 타입이 아래 클로저 안에서도
	-- 그대로 유지되도록 하기 위해서다 (클로저 안에서는 원래 변수의 좁혀지기 전 타입으로
	-- 되돌아가는 경우가 있다).
	local shopId: ShopCatalog.ShopId = maybeShopId

	local shopDef = ShopCatalog.Get(shopId)
	if not shopDef then
		return
	end

	local anchor = findAnchorPart(instance)
	if not anchor then
		warn(`[MarketService] {instance:GetFullName()} 에서 BasePart를 찾지 못해 건너뜁니다`)
		return
	end

	setupPrompt(anchor, shopDef, function(player)
		onShopTriggered(shopId, player)
	end)
end

local function setupStall(instance: Instance)
	local vendorAnchor = instance:FindFirstChild("VendorAnchor")
	if not vendorAnchor then
		warn(`[MarketService] {instance:GetFullName()} 에 VendorAnchor 자식이 없어 건너뜁니다`)
		return
	end

	local rawType = vendorAnchor:GetAttribute("StallType")
	if type(rawType) ~= "string" then
		warn(`[MarketService] {instance:GetFullName()}.VendorAnchor 에 StallType 속성이 없어 건너뜁니다`)
		return
	end
	local stallType = rawType :: string

	-- 태그가 저장 과정에서 사라진 적이 있으니, 없으면 다시 달아준다. 속성(StallType)은 이미 있으니
	-- 그 값을 그대로 신뢰하고 태그만 보정한다.
	if not CollectionService:HasTag(instance, MARKET_STALL_TAG) then
		CollectionService:AddTag(instance, MARKET_STALL_TAG)
	end

	local maybeShopId: ShopCatalog.ShopId? = ShopCatalog.ShopIdForStallType(stallType)
	if not maybeShopId then
		warn(`[MarketService] {instance:GetFullName()} 의 StallType({stallType})에 대응하는 상점 정의가 없습니다`)
		return
	end
	local shopId: ShopCatalog.ShopId = maybeShopId

	local shopDef = ShopCatalog.Get(shopId)
	if not shopDef then
		return
	end

	local anchor: BasePart?
	if vendorAnchor:IsA("BasePart") then
		anchor = vendorAnchor
	else
		anchor = findAnchorPart(instance)
	end
	if not anchor then
		warn(`[MarketService] {instance:GetFullName()} 에서 BasePart를 찾지 못해 건너뜁니다`)
		return
	end

	setupPrompt(anchor, shopDef, function(player)
		onShopTriggered(shopId, player)
	end)
end

-- ===== 구매/판매 검증 (RemoteFunction) =====
-- 반환하는 첫 값은 성공 여부, 두 번째는 사유 코드 문자열이다. 실제 한국어 문구는
-- 클라이언트(ShopUI)가 사유 코드를 보고 고른다 — 서버가 조사(을/를 등)까지 신경 쓰지 않아도 되게.

local function onPurchaseInvoked(player: Player, shopIdArg: unknown, listingIdArg: unknown): (boolean, string)
	if type(shopIdArg) ~= "string" or type(listingIdArg) ~= "string" then
		return false, "invalid_request"
	end

	local shopDef = ShopCatalog.Get(shopIdArg)
	if not shopDef then
		return false, "unknown_shop"
	end

	local listing: ShopCatalog.Listing? = nil
	for _, candidate in shopDef.listings do
		if candidate.id == listingIdArg then
			listing = candidate
			break
		end
	end
	if not listing then
		return false, "unknown_listing"
	end

	if listing.kind == "BuyUpgrade" then
		if PlayerData.HasUpgrade(player, listing.id) then
			return false, "already_owned"
		end
		if listing.requires and not PlayerData.HasUpgrade(player, listing.requires :: string) then
			return false, "missing_requirement"
		end
	end

	if not PlayerData.HasCurrency(player, listing.currencyId, listing.price) then
		return false, "not_enough_currency"
	end

	local paidOk = PlayerData.RemoveCurrency(player, listing.currencyId, listing.price)
	if not paidOk then
		return false, "purchase_failed"
	end

	if listing.kind == "BuyItem" then
		local addedOk = PlayerData.AddItem(player, listing.id, 1)
		if not addedOk then
			PlayerData.AddCurrency(player, listing.currencyId, listing.price) -- 롤백
			return false, "purchase_failed"
		end
	else
		local grantedOk = PlayerData.GrantUpgrade(player, listing.id)
		if not grantedOk then
			PlayerData.AddCurrency(player, listing.currencyId, listing.price) -- 롤백
			return false, "already_owned"
		end
	end

	return true, "ok"
end

local function onSellInvoked(player: Player, itemIdArg: unknown, quantityArg: unknown): (boolean, string, number)
	if type(itemIdArg) ~= "string" then
		return false, "invalid_request", 0
	end
	local itemId = itemIdArg :: string

	local quantity = 1
	if type(quantityArg) == "number" then
		quantity = math.floor(quantityArg)
	end
	if quantity <= 0 then
		return false, "invalid_quantity", 0
	end
	quantity = math.min(quantity, MAX_SELL_QUANTITY)

	local def = ItemDatabase.Get(itemId)
	if not def then
		return false, "unknown_item", 0
	end
	if not ShopCatalog.IsSellable(def.kind) then
		return false, "not_sellable", 0
	end
	if not PlayerData.HasItem(player, itemId, quantity) then
		return false, "not_enough_inventory", 0
	end

	local removedOk = PlayerData.RemoveItem(player, itemId, quantity)
	if not removedOk then
		return false, "sell_failed", 0
	end

	local unitPrice = ShopCatalog.SellPriceFor(def.rarity)
	local total = unitPrice * quantity
	local addedOk = PlayerData.AddCurrency(player, ShopCatalog.SellCurrencyId(), total)
	if not addedOk then
		PlayerData.AddItem(player, itemId, quantity) -- 롤백
		return false, "sell_failed", 0
	end

	return true, "ok", total
end

function MarketService.Init()
	local forest = Workspace:FindFirstChild("Forest")
	if not forest then
		warn("[MarketService] Workspace.Forest를 찾지 못해 시장 기능을 건너뜁니다")
		return
	end
	local marketRoot = forest:FindFirstChild("Market")
	if not marketRoot then
		warn("[MarketService] Workspace.Forest.Market을 찾지 못해 시장 기능을 건너뜁니다")
		return
	end

	local buildingCount = 0
	local buildings = marketRoot:FindFirstChild("Buildings")
	if buildings then
		for _, child in buildings:GetChildren() do
			setupBuilding(child)
			buildingCount += 1
		end
	else
		warn("[MarketService] Market.Buildings 폴더를 찾지 못했습니다")
	end

	local stallCount = 0
	local stalls = marketRoot:FindFirstChild("Stalls")
	if stalls then
		for _, child in stalls:GetChildren() do
			setupStall(child)
			stallCount += 1
		end
	else
		warn("[MarketService] Market.Stalls 폴더를 찾지 못했습니다")
	end

	Remotes.GetFunction("Purchase").OnServerInvoke = onPurchaseInvoked
	Remotes.GetFunction("Sell").OnServerInvoke = onSellInvoked

	print(`[MarketService] 초기화 완료 - 건물 {buildingCount}개, 좌판 {stallCount}개 처리`)
end

return MarketService
