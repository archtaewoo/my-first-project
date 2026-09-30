--!strict
-- 말 돌봄: 먹이/물/빗질 지점에서 상호작용하면 대상 말의 애정도가 오른다.
-- BrushStorage는 빗을 "보관하는 곳"이지 돌보는 지점이 아니라고 보고, 애정도는 안 올리고
-- 짧은 안내만 준다(Brush만 실제로 애정도를 올린다).
--
-- 식별: HorseCare/CustomHorse 둘 다 태그로 찾는다. 이 환경에서 태그가 저장 중 사라진 적이
-- 있어서, 태그가 비어있으면 다시 달아주되 Type/Stall/HorseId 같은 속성값을 항상 우선 신뢰한다.
-- 대상 말은 HorseCare.Stall 속성으로 정하고(0이면 공유 지점 — 그 지점에서 가장 가까운 말).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HorseCareConfig = require(ReplicatedStorage:WaitForChild("Features"):WaitForChild("HorseCareConfig"))
local Remotes = require(ReplicatedStorage:WaitForChild("Features"):WaitForChild("Remotes"))

local PlayerData = require(script.Parent.PlayerData)

local HORSE_CARE_TAG = "HorseCare"
local CUSTOM_HORSE_TAG = "CustomHorse"
local PROMPT_HOLD_DURATION = 0.4
local PROMPT_MAX_DISTANCE = 10

local ACTION_TEXT: { [string]: string } = {
	Food = "먹이 주기",
	Water = "물 주기",
	Brush = "빗질하기",
	BrushStorage = "빗 챙기기",
}

local HorseCareService = {}

type HorseInfo = {
	horseId: string,
	horseName: string,
	stall: number,
	anchor: BasePart,
}

type CareSpot = {
	careType: string,
	stall: number,
	anchor: BasePart,
}

local horsesByStall: { [number]: HorseInfo } = {}
local allHorses: { HorseInfo } = {}

-- [player][horseId..":"..careType] = 마지막 사용 시각(os.time())
local cooldowns: { [Player]: { [string]: number } } = {}

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

local function collectHorses()
	horsesByStall = {}
	allHorses = {}

	for _, instance in CollectionService:GetTagged(CUSTOM_HORSE_TAG) do
		local stallRaw = instance:GetAttribute("Stall")
		local horseIdRaw = instance:GetAttribute("HorseId")
		if type(stallRaw) ~= "number" or type(horseIdRaw) ~= "string" then
			warn(`[HorseCareService] {instance:GetFullName()} 에 Stall 또는 HorseId 속성이 없어 건너뜁니다`)
			continue
		end

		local anchor = findAnchorPart(instance)
		if not anchor then
			warn(`[HorseCareService] {instance:GetFullName()} 에서 BasePart를 찾지 못해 건너뜁니다`)
			continue
		end

		local horseNameRaw = instance:GetAttribute("HorseName")
		local horseName = if type(horseNameRaw) == "string" then horseNameRaw else horseIdRaw

		local info: HorseInfo = {
			horseId = horseIdRaw,
			horseName = horseName,
			stall = stallRaw,
			anchor = anchor,
		}
		horsesByStall[stallRaw] = info
		table.insert(allHorses, info)
	end
end

local function nearestHorseTo(position: Vector3): HorseInfo?
	local closest: HorseInfo? = nil
	local closestDistance = math.huge
	for _, horse in allHorses do
		local distance = (horse.anchor.Position - position).Magnitude
		if distance < closestDistance then
			closestDistance = distance
			closest = horse
		end
	end
	return closest
end

local function resolveTargetHorse(spotStall: number, spotPosition: Vector3): HorseInfo?
	if spotStall ~= 0 then
		return horsesByStall[spotStall]
	end
	return nearestHorseTo(spotPosition)
end

local function onCareTriggered(spot: CareSpot, player: Player)
	if spot.careType == "BrushStorage" then
		-- 보관함은 애정도를 올리지 않는다. 실제 손질은 Brush 지점에서 한다.
		return
	end

	local horse = resolveTargetHorse(spot.stall, spot.anchor.Position)
	if not horse then
		return
	end

	local key = `{horse.horseId}:{spot.careType}`
	local playerCooldowns = cooldowns[player]
	if not playerCooldowns then
		playerCooldowns = {}
		cooldowns[player] = playerCooldowns
	end

	local cooldownSeconds = HorseCareConfig.CooldownFor(spot.careType)
	local lastUsed = playerCooldowns[key]
	local now = os.time()
	if lastUsed and now - lastUsed < cooldownSeconds then
		return -- 아직 쉬는 시간 — 에러 문구로 스트레스 주지 않고 조용히 무시
	end
	playerCooldowns[key] = now

	local previousAmount = PlayerData.GetHorseAffinity(player, horse.horseId)
	local gain = HorseCareConfig.AffinityGainFor(spot.careType)
	local ok, newAmount = PlayerData.AddHorseAffinity(player, horse.horseId, gain)
	if not ok then
		return
	end

	local previousTier = HorseCareConfig.TierFor(previousAmount)
	local newTier = HorseCareConfig.TierFor(newAmount)

	Remotes.GetEvent("HorseCareResult"):FireClient(player, {
		horseId = horse.horseId,
		horseName = horse.horseName,
		careType = spot.careType,
		newAmount = newAmount,
		tierLabel = newTier.label,
		tierUp = newTier.label ~= previousTier.label,
	})
end

local function setupCareSpot(instance: Instance)
	local typeRaw = instance:GetAttribute("Type")
	if type(typeRaw) ~= "string" or not ACTION_TEXT[typeRaw] then
		warn(`[HorseCareService] {instance:GetFullName()} 의 Type 속성이 없거나 알 수 없는 값입니다`)
		return
	end
	local careType = typeRaw :: string

	local stallRaw = instance:GetAttribute("Stall")
	local stall = if type(stallRaw) == "number" then stallRaw else 0

	if not CollectionService:HasTag(instance, HORSE_CARE_TAG) then
		CollectionService:AddTag(instance, HORSE_CARE_TAG)
	end

	local anchor = findAnchorPart(instance)
	if not anchor then
		warn(`[HorseCareService] {instance:GetFullName()} 에서 BasePart를 찾지 못해 건너뜁니다`)
		return
	end

	local spot: CareSpot = { careType = careType, stall = stall, anchor = anchor }

	local existingPrompt = anchor:FindFirstChildOfClass("ProximityPrompt") :: ProximityPrompt?
	local prompt: ProximityPrompt
	if existingPrompt then
		prompt = existingPrompt
	else
		prompt = Instance.new("ProximityPrompt")
		prompt.Parent = anchor
	end
	prompt.ActionText = ACTION_TEXT[careType]
	prompt.ObjectText = "말 돌보기"
	prompt.HoldDuration = PROMPT_HOLD_DURATION
	prompt.MaxActivationDistance = PROMPT_MAX_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Enabled = true
	prompt.Triggered:Connect(function(player)
		onCareTriggered(spot, player)
	end)
end

function HorseCareService.Init()
	collectHorses()
	if #allHorses == 0 then
		warn("[HorseCareService] \"CustomHorse\" 태그가 달린 말을 하나도 찾지 못했습니다.")
	end

	local spots = CollectionService:GetTagged(HORSE_CARE_TAG)
	if #spots == 0 then
		warn(`[HorseCareService] "{HORSE_CARE_TAG}" 태그가 달린 오브젝트를 하나도 찾지 못했습니다 — 18곳에 태그를 다시 달아주세요.`)
	end

	for _, instance in spots do
		setupCareSpot(instance)
	end
	CollectionService:GetInstanceAddedSignal(HORSE_CARE_TAG):Connect(setupCareSpot)

	Players.PlayerRemoving:Connect(function(player)
		cooldowns[player] = nil
	end)

	print(`[HorseCareService] 초기화 완료 - 말 {#allHorses}마리, 돌봄 지점 {#spots}개`)
end

return HorseCareService
