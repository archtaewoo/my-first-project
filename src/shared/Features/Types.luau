--!strict
-- 공용 타입 정의. 서버/클라이언트가 함께 require 한다.

export type ItemKind = "Fish" | "Mushroom" | "Flower" | "Food"

export type Rarity = "Common" | "Uncommon" | "Rare" | "Legendary"

export type ItemDefinition = {
	id: string,
	kind: ItemKind,
	displayName: string,
	rarity: Rarity,
	description: string,
}

export type CodexEntry = {
	firstSeenAt: number, -- os.time() 기준 최초 획득 시각
	count: number, -- 누적 획득 횟수
}

export type QuestProgress = {
	progress: number,
	completed: boolean,
}

export type PlayerData = {
	version: number,
	inventory: { [string]: number }, -- ItemId -> 개수
	codex: { [string]: CodexEntry }, -- ItemId -> 도감 기록
	quests: { [string]: QuestProgress }, -- QuestId -> 진행도
	horseAffinity: { [string]: number }, -- HorseId -> 애정도
	stats: { [string]: number }, -- 예: itemsCollected, fishCaught 등 범용 카운터
	currency: { [string]: number }, -- CurrencyId(예: "acorn") -> 보유량
	upgrades: { [string]: boolean }, -- UpgradeId -> 보유 여부 (수레/장식/도구 등급 등 1회성 구매)
	lastSaved: number, -- 마지막 저장 시각 (os.time())
}

export type InventorySyncPayload = {
	inventory: { [string]: number },
	codex: { [string]: CodexEntry },
	stats: { [string]: number },
	currency: { [string]: number },
	upgrades: { [string]: boolean },
}

export type CurrencyChangedPayload = {
	currencyId: string,
	newAmount: number,
	delta: number,
}

-- 상점 목록에 실제로 뜨는 구매 항목 하나 (클라이언트는 이 정보로만 그린다)
export type ShopListingView = {
	id: string, -- BuyItem이면 ItemId, BuyUpgrade면 UpgradeId
	kind: "BuyItem" | "BuyUpgrade",
	displayName: string,
	description: string,
	price: number,
	currencyId: string,
	alreadyOwned: boolean, -- BuyUpgrade인데 이미 가지고 있으면 true (구매 버튼 비활성화용)
}

export type OpenShopPayload = {
	shopId: string,
	shopDisplayName: string,
	greeting: string,
	listings: { ShopListingView },
}

export type InventoryDeltaPayload = {
	itemId: string,
	newCount: number,
	delta: number,
}

export type ItemAddedPayload = {
	itemId: string,
	amount: number,
	newCount: number,
	isNewDiscovery: boolean,
}

return {}
