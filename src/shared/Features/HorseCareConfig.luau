--!strict
-- 말 돌봄 수치 설정. 서버(HorseCareService)만 이 값을 보고 애정도를 올린다.

export type CareType = "Food" | "Water" | "Brush" | "BrushStorage"

export type AffinityTier = {
	threshold: number,
	label: string,
	description: string,
}

local AFFINITY_GAIN: { [string]: number } = {
	Food = 3,
	Water = 3,
	Brush = 5,
}

-- 스팸 방지용 쿨다운(초). 같은 플레이어가 같은 말에게 같은 종류의 돌봄을 다시 할 수 있을 때까지.
local COOLDOWN_SECONDS: { [string]: number } = {
	Food = 60,
	Water = 60,
	Brush = 90,
}

-- 높은 임계값부터 적어둔다 — TierFor가 위에서부터 훑어서 처음 맞는 걸 고른다.
local TIERS: { AffinityTier } = {
	{ threshold = 100, label = "단짝", description = "떼려야 뗄 수 없는 사이가 됐어요." },
	{ threshold = 50, label = "각별함", description = "손길을 반기고 잘 따라와요." },
	{ threshold = 20, label = "친근함", description = "이제 곁에 가도 편하게 있어줘요." },
	{ threshold = 0, label = "낯가림", description = "아직은 조금 서먹해요." },
}

local HorseCareConfig = {}

function HorseCareConfig.AffinityGainFor(careType: string): number
	return AFFINITY_GAIN[careType] or 0
end

function HorseCareConfig.CooldownFor(careType: string): number
	return COOLDOWN_SECONDS[careType] or 60
end

function HorseCareConfig.TierFor(affinity: number): AffinityTier
	for _, tier in TIERS do
		if affinity >= tier.threshold then
			return tier
		end
	end
	return TIERS[#TIERS]
end

return HorseCareConfig
