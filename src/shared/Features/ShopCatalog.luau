--!strict
-- 시장 상점 11곳(건물 5 + 좌판 6)의 판매 목록과 "채집한 아이템 팔기" 시세를 정의한다.
-- 여기 있는 가격/설명이 유일한 진실이며, 서버가 이 표를 기준으로 모든 구매·판매를 검증한다.

local Types = require(script.Parent.Types)

export type ShopId =
	"stall_produce"
	| "stall_flowers"
	| "stall_fishing"
	| "stall_horsegoods"
	| "stall_food"
	| "stall_general"
	| "building_bakery"
	| "building_warehouse"
	| "building_smithy"
	| "building_wellhut"
	| "building_toyshop"

export type ListingKind = "BuyItem" | "BuyUpgrade"

export type Listing = {
	id: string, -- BuyItem: ItemDatabase의 ItemId / BuyUpgrade: 아래 UpgradeId
	kind: ListingKind,
	displayName: string,
	description: string,
	price: number,
	currencyId: string,
	requires: string?, -- BuyUpgrade일 때, 먼저 가지고 있어야 하는 UpgradeId (없으면 nil)
}

export type ShopDefinition = {
	id: ShopId,
	displayName: string,
	greeting: string,
	listings: { Listing },
}

local CURRENCY_ACORN = "acorn"

-- 채집한 아이템(버섯/꽃/물고기)을 팔 때 희귀도별 가격. 음식은 팔지 않는다(요리 재료로 쓰도록).
local SELL_PRICE_BY_RARITY: { [Types.Rarity]: number } = {
	Common = 2,
	Uncommon = 5,
	Rare = 12,
	Legendary = 30,
}

local SELLABLE_KINDS: { [Types.ItemKind]: boolean } = {
	Mushroom = true,
	Flower = true,
	Fish = true,
	Food = false,
}

local shops: { [ShopId]: ShopDefinition } = {
	stall_produce = {
		id = "stall_produce",
		displayName = "농산물 좌판",
		greeting = "오늘 캐 온 버섯 좀 보여주실래요?",
		listings = {},
	},
	stall_flowers = {
		id = "stall_flowers",
		displayName = "꽃 좌판",
		greeting = "향긋하네요! 파실 꽃이 있으신가요?",
		listings = {},
	},
	stall_fishing = {
		id = "stall_fishing",
		displayName = "낚시 좌판",
		greeting = "물고기 팔러 오셨어요, 아니면 장비 보러 오셨어요?",
		listings = {
			{
				id = "rod_tier2",
				kind = "BuyUpgrade",
				displayName = "은빛 낚싯대",
				description = "손맛이 더 잘 느껴지는 낚싯대예요.",
				price = 40,
				currencyId = CURRENCY_ACORN,
			},
			{
				id = "rod_tier3",
				kind = "BuyUpgrade",
				displayName = "금빛 낚싯대",
				description = "귀한 물고기도 놓치지 않게 도와줘요.",
				price = 120,
				currencyId = CURRENCY_ACORN,
				requires = "rod_tier2",
			},
		},
	},
	stall_horsegoods = {
		id = "stall_horsegoods",
		displayName = "말 용품 좌판",
		greeting = "우리 아이한테 잘 어울리는 걸 찾아보세요.",
		listings = {
			{
				id = "horse_deco_ribbon",
				kind = "BuyUpgrade",
				displayName = "리본 장식",
				description = "갈기에 달아주면 상큼해 보여요.",
				price = 25,
				currencyId = CURRENCY_ACORN,
			},
			{
				id = "horse_deco_flowercrown",
				kind = "BuyUpgrade",
				displayName = "꽃관 장식",
				description = "작은 들꽃을 엮어 만든 장식이에요.",
				price = 45,
				currencyId = CURRENCY_ACORN,
			},
		},
	},
	stall_food = {
		id = "stall_food",
		displayName = "먹거리 좌판",
		greeting = "출출하시죠? 바로 드실 수 있는 것들이에요.",
		listings = {
			{
				id = "food_grilled_fish",
				kind = "BuyItem",
				displayName = "구운 생선",
				description = "모닥불에 노릇하게 구운 생선이에요.",
				price = 6,
				currencyId = CURRENCY_ACORN,
			},
			{
				id = "food_mushroom_stew",
				kind = "BuyItem",
				displayName = "버섯 스튜",
				description = "버섯을 듬뿍 넣고 끓인 따뜻한 스튜예요.",
				price = 8,
				currencyId = CURRENCY_ACORN,
			},
			{
				id = "food_flower_tea",
				kind = "BuyItem",
				displayName = "꽃차",
				description = "꽃잎을 우려낸 향긋한 차예요.",
				price = 5,
				currencyId = CURRENCY_ACORN,
			},
			{
				id = "food_berry_pie",
				kind = "BuyItem",
				displayName = "베리 파이",
				description = "숲에서 얻은 재료로 정성껏 구운 파이예요.",
				price = 10,
				currencyId = CURRENCY_ACORN,
			},
		},
	},
	stall_general = {
		id = "stall_general",
		displayName = "잡화 좌판",
		greeting = "필요하신 게 있으면 편하게 물어보세요.",
		listings = {
			{
				id = "cart_basic",
				kind = "BuyUpgrade",
				displayName = "기본 수레",
				description = "말 뒤에 달면 짐을 더 넉넉하게 실을 수 있어요.",
				price = 80,
				currencyId = CURRENCY_ACORN,
			},
		},
	},

	building_bakery = {
		id = "building_bakery",
		displayName = "빵집",
		greeting = "방금 나온 따끈한 빵이에요, 하나 드셔보세요.",
		listings = {
			{
				id = "food_honey_bread",
				kind = "BuyItem",
				displayName = "꿀빵",
				description = "빵집에서 갓 구워낸, 꿀이 촉촉하게 밴 빵이에요.",
				price = 9,
				currencyId = CURRENCY_ACORN,
			},
		},
	},
	building_warehouse = {
		id = "building_warehouse",
		displayName = "창고",
		greeting = "짐이 늘었다면 수레를 더 키워보는 건 어때요?",
		listings = {
			{
				id = "cart_large",
				kind = "BuyUpgrade",
				displayName = "대형 수레",
				description = "기본 수레보다 훨씬 많은 짐을 실을 수 있어요.",
				price = 200,
				currencyId = CURRENCY_ACORN,
				requires = "cart_basic",
			},
		},
	},
	building_smithy = {
		id = "building_smithy",
		displayName = "대장간",
		greeting = "튼튼한 도구가 필요하신가요?",
		listings = {
			{
				id = "brush_deluxe",
				kind = "BuyUpgrade",
				displayName = "고급 빗",
				description = "말이 훨씬 편안해하는 부드러운 빗이에요.",
				price = 35,
				currencyId = CURRENCY_ACORN,
			},
		},
	},
	building_wellhut = {
		id = "building_wellhut",
		displayName = "우물집",
		greeting = "맑은 물이 필요하면 들르세요.",
		listings = {
			{
				id = "bait_premium",
				kind = "BuyUpgrade",
				displayName = "고급 미끼",
				description = "물고기들이 유독 좋아하는 특별한 미끼예요.",
				price = 20,
				currencyId = CURRENCY_ACORN,
			},
		},
	},
	building_toyshop = {
		id = "building_toyshop",
		displayName = "장난감 가게",
		greeting = "구경하고 가세요, 다 귀여운 것들이에요.",
		listings = {
			{
				id = "horse_deco_bell",
				kind = "BuyUpgrade",
				displayName = "방울 장식",
				description = "걸을 때마다 딸랑딸랑 소리가 나요.",
				price = 15,
				currencyId = CURRENCY_ACORN,
			},
		},
	},
}

local stallTypeToShopId: { [string]: ShopId } = {
	Produce = "stall_produce",
	Flowers = "stall_flowers",
	Fishing = "stall_fishing",
	HorseGoods = "stall_horsegoods",
	Food = "stall_food",
	General = "stall_general",
}

local buildingTypeToShopId: { [string]: ShopId } = {
	Bakery = "building_bakery",
	Warehouse = "building_warehouse",
	Smithy = "building_smithy",
	WellHut = "building_wellhut",
	ToyShop = "building_toyshop",
}

local ShopCatalog = {}

ShopCatalog.CURRENCY_ACORN = CURRENCY_ACORN
ShopCatalog.STARTING_ACORNS = 20

function ShopCatalog.Get(shopId: string): ShopDefinition?
	return shops[shopId :: ShopId]
end

function ShopCatalog.ShopIdForStallType(stallType: string): ShopId?
	return stallTypeToShopId[stallType]
end

function ShopCatalog.ShopIdForBuildingType(buildingType: string): ShopId?
	return buildingTypeToShopId[buildingType]
end

function ShopCatalog.IsSellable(kind: Types.ItemKind): boolean
	return SELLABLE_KINDS[kind] == true
end

function ShopCatalog.SellPriceFor(rarity: Types.Rarity): number
	return SELL_PRICE_BY_RARITY[rarity] or 0
end

function ShopCatalog.SellCurrencyId(): string
	return CURRENCY_ACORN
end

return ShopCatalog
