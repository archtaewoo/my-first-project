--!strict
-- 낚시 확률/타이밍 설정. 서버(FishingService)가 이 표만 보고 판정하며,
-- 클라이언트는 결과를 통보받을 뿐 아무 값도 결정하지 않는다.

export type WeightedFish = { itemId: string, weight: number }
export type RodBonus = { extraWindow: number, rareBoost: number }

-- Zone 속성값을 못 찾거나 모르는 값이면 이 기본표를 쓴다.
local DEFAULT_WEIGHTS: { WeightedFish } = {
	{ itemId = "fish_bass", weight = 40 },
	{ itemId = "fish_trout", weight = 30 },
	{ itemId = "fish_carp", weight = 15 },
	{ itemId = "fish_catfish", weight = 10 },
	{ itemId = "fish_salmon", weight = 4 },
	{ itemId = "fish_eel", weight = 1 },
}

-- 부두(Dock)는 물이 깊어 귀한 물고기가 조금 더 잘 잡히고,
-- 호숫가(Lakeshore)는 얕아서 흔한 물고기 위주로 잡힌다.
local ZONE_WEIGHTS: { [string]: { WeightedFish } } = {
	Dock = {
		{ itemId = "fish_bass", weight = 30 },
		{ itemId = "fish_trout", weight = 25 },
		{ itemId = "fish_carp", weight = 18 },
		{ itemId = "fish_catfish", weight = 15 },
		{ itemId = "fish_salmon", weight = 9 },
		{ itemId = "fish_eel", weight = 3 },
	},
	Lakeshore = {
		{ itemId = "fish_bass", weight = 50 },
		{ itemId = "fish_trout", weight = 32 },
		{ itemId = "fish_carp", weight = 12 },
		{ itemId = "fish_catfish", weight = 5 },
		{ itemId = "fish_salmon", weight = 1 },
	},
}

-- 상점(stall_fishing)에서 산 낚싯대 업그레이드에 따라 반응 판정 시간을 조금 더 주고,
-- 희귀 물고기(Rare/Legendary) 확률에 곱해줄 배율. 두 등급을 다 가지고 있으면 더 높은 쪽만 적용한다.
local ROD_TIER_BONUS: { [string]: RodBonus } = {
	rod_tier2 = { extraWindow = 0.25, rareBoost = 1.3 },
	rod_tier3 = { extraWindow = 0.5, rareBoost = 1.7 },
}

local BAIT_UPGRADE_ID = "bait_premium"
local BAIT_RARE_BOOST = 1.25

local FishingConfig = {}

FishingConfig.CAST_WAIT_MIN = 5
FishingConfig.CAST_WAIT_MAX = 12
FishingConfig.BITE_REACTION_WINDOW = 1.2 -- 기본 반응 허용 시간(초)
FishingConfig.NETWORK_TOLERANCE = 0.35 -- 지연 보정으로 항상 더해주는 여유 시간(초)
FishingConfig.BAIT_UPGRADE_ID = BAIT_UPGRADE_ID

function FishingConfig.WeightsForZone(zone: string?): { WeightedFish }
	if zone and ZONE_WEIGHTS[zone] then
		return ZONE_WEIGHTS[zone]
	end
	return DEFAULT_WEIGHTS
end

function FishingConfig.RodBonusFor(upgradeId: string?): RodBonus?
	if not upgradeId then
		return nil
	end
	return ROD_TIER_BONUS[upgradeId]
end

function FishingConfig.BaitRareBoost(): number
	return BAIT_RARE_BOOST
end

return FishingConfig
