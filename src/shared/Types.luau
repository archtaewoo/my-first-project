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
	lastSaved: number, -- 마지막 저장 시각 (os.time())
}

export type InventorySyncPayload = {
	inventory: { [string]: number },
	codex: { [string]: CodexEntry },
	stats: { [string]: number },
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
