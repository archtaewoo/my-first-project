--!strict
-- 수집형 퀘스트 고정 정의. 방문형 퀘스트는 QuestPoint 9곳의 QuestId/DisplayName/Hint를
-- 그대로 읽어서 쓰므로(QuestService 참고) 여기엔 없다.

export type CollectQuestDef = {
	id: string,
	displayName: string,
	hint: string,
	kind: string, -- Types.ItemKind 값과 맞춰서 쓴다(순환 require를 피하려 plain string으로 둠)
	target: number,
	rewardAcorns: number,
}

local COLLECT_QUESTS: { CollectQuestDef } = {
	{
		id = "collect_mushrooms",
		displayName = "버섯 채집가",
		hint = "숲에서 버섯을 10개 모아보세요.",
		kind = "Mushroom",
		target = 10,
		rewardAcorns = 20,
	},
	{
		id = "collect_flowers",
		displayName = "꽃다발 모으기",
		hint = "예쁜 꽃을 10송이 모아보세요.",
		kind = "Flower",
		target = 10,
		rewardAcorns = 20,
	},
	{
		id = "collect_fish",
		displayName = "손맛 좀 아는 사람",
		hint = "물고기를 5마리 낚아보세요.",
		kind = "Fish",
		target = 5,
		rewardAcorns = 30,
	},
}

local QuestCatalog = {}

QuestCatalog.VISIT_REWARD_ACORNS = 10

function QuestCatalog.GetCollectQuests(): { CollectQuestDef }
	return COLLECT_QUESTS
end

function QuestCatalog.GetCollectQuest(id: string): CollectQuestDef?
	for _, def in COLLECT_QUESTS do
		if def.id == id then
			return def
		end
	end
	return nil
end

return QuestCatalog
