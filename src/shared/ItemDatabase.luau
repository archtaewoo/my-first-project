--!strict
-- 아이템 정의 테이블. 나중에 종류를 늘릴 때는 아래 표에 줄만 추가하면 된다.
-- ItemId는 맵 태그(Collectible.ItemId)와 반드시 동일한 문자열을 써야 한다.

local Types = require(script.Parent.Types)

type ItemDefinition = Types.ItemDefinition

local items: { [string]: ItemDefinition } = {
	-- 물고기 (낚시 기능에서 사용 예정)
	fish_bass = {
		id = "fish_bass",
		kind = "Fish",
		displayName = "배스",
		rarity = "Common",
		description = "호수 어디서나 흔히 볼 수 있는 물고기예요.",
	},
	fish_trout = {
		id = "fish_trout",
		kind = "Fish",
		displayName = "송어",
		rarity = "Common",
		description = "맑은 물을 좋아하는 은빛 물고기예요.",
	},
	fish_carp = {
		id = "fish_carp",
		kind = "Fish",
		displayName = "잉어",
		rarity = "Uncommon",
		description = "느긋하게 헤엄치는 커다란 물고기예요.",
	},
	fish_catfish = {
		id = "fish_catfish",
		kind = "Fish",
		displayName = "메기",
		rarity = "Uncommon",
		description = "호수 바닥 근처에 숨어 지내요.",
	},
	fish_salmon = {
		id = "fish_salmon",
		kind = "Fish",
		displayName = "연어",
		rarity = "Rare",
		description = "가끔씩만 모습을 드러내는 귀한 물고기예요.",
	},
	fish_eel = {
		id = "fish_eel",
		kind = "Fish",
		displayName = "장어",
		rarity = "Legendary",
		description = "운이 아주 좋아야 만날 수 있어요.",
	},

	-- 버섯 (총 224개, 태그: Collectible)
	mushroom_white = {
		id = "mushroom_white",
		kind = "Mushroom",
		displayName = "흰 버섯",
		rarity = "Common",
		description = "숲 곳곳에서 쉽게 눈에 띄는 버섯이에요.",
	},
	mushroom_yellow = {
		id = "mushroom_yellow",
		kind = "Mushroom",
		displayName = "노란 버섯",
		rarity = "Common",
		description = "햇살 같은 색을 가진 버섯이에요.",
	},
	mushroom_gold = {
		id = "mushroom_gold",
		kind = "Mushroom",
		displayName = "황금 버섯",
		rarity = "Rare",
		description = "은은하게 반짝이는 귀한 버섯이에요.",
	},
	mushroom_rust = {
		id = "mushroom_rust",
		kind = "Mushroom",
		displayName = "녹슨빛 버섯",
		rarity = "Uncommon",
		description = "붉은 기가 도는 독특한 버섯이에요.",
	},

	-- 꽃 (총 251송이, 태그: Collectible)
	flower_sunflower = {
		id = "flower_sunflower",
		kind = "Flower",
		displayName = "해바라기",
		rarity = "Common",
		description = "해를 향해 활짝 웃는 꽃이에요.",
	},
	flower_rosehip = {
		id = "flower_rosehip",
		kind = "Flower",
		displayName = "찔레꽃",
		rarity = "Common",
		description = "소박하고 은은한 향이 나는 꽃이에요.",
	},
	flower_crownbeard = {
		id = "flower_crownbeard",
		kind = "Flower",
		displayName = "크라운비어드",
		rarity = "Uncommon",
		description = "노란 왕관 모양 꽃잎이 인상적이에요.",
	},
	flower_hydrangea = {
		id = "flower_hydrangea",
		kind = "Flower",
		displayName = "수국",
		rarity = "Uncommon",
		description = "탐스럽게 뭉쳐 피는 꽃이에요.",
	},
	flower_kale = {
		id = "flower_kale",
		kind = "Flower",
		displayName = "꽃케일",
		rarity = "Rare",
		description = "잎 모양이 꽃처럼 화려해요.",
	},

	-- 음식 (모닥불 요리 기능에서 사용 예정)
	food_grilled_fish = {
		id = "food_grilled_fish",
		kind = "Food",
		displayName = "구운 생선",
		rarity = "Common",
		description = "모닥불에 노릇하게 구운 생선이에요.",
	},
	food_mushroom_stew = {
		id = "food_mushroom_stew",
		kind = "Food",
		displayName = "버섯 스튜",
		rarity = "Common",
		description = "버섯을 듬뿍 넣고 끓인 따뜻한 스튜예요.",
	},
	food_flower_tea = {
		id = "food_flower_tea",
		kind = "Food",
		displayName = "꽃차",
		rarity = "Uncommon",
		description = "꽃잎을 우려낸 향긋한 차예요.",
	},
	food_berry_pie = {
		id = "food_berry_pie",
		kind = "Food",
		displayName = "베리 파이",
		rarity = "Rare",
		description = "숲에서 얻은 재료로 정성껏 구운 파이예요.",
	},
}

local ItemDatabase = {}

function ItemDatabase.Get(itemId: string): ItemDefinition?
	return items[itemId]
end

function ItemDatabase.GetAll(): { [string]: ItemDefinition }
	return items
end

function ItemDatabase.GetByKind(kind: Types.ItemKind): { ItemDefinition }
	local result: { ItemDefinition } = {}
	for _, def in items do
		if def.kind == kind then
			table.insert(result, def)
		end
	end
	return result
end

function ItemDatabase.Exists(itemId: string): boolean
	return items[itemId] ~= nil
end

return ItemDatabase
