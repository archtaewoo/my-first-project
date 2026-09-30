--!strict
-- 낚시. 캐스팅 → (서버가 정하는) 기다림 → 입질 → 반응 타이밍 판정까지 전부 서버가 시간을 직접
-- 재서 결정한다. 클라이언트는 "지금 눌렀다"는 신호만 보내고, 성공/실패는 서버 시계 기준으로 정해진다.
--
-- 식별: FishingSpot 태그로 찾고, Zone/CastTarget/DisplayName 속성을 신뢰한다(태그가 사라진 적이
-- 있어서 없으면 크게 경고한다 — Market과 달리 좌표 단서가 없어 코드로 자동 복구할 수 없다).

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemDatabase = require(ReplicatedStorage:WaitForChild("Features"):WaitForChild("ItemDatabase"))
local FishingConfig = require(ReplicatedStorage:WaitForChild("Features"):WaitForChild("FishingConfig"))
local Remotes = require(ReplicatedStorage:WaitForChild("Features"):WaitForChild("Remotes"))

local PlayerData = require(script.Parent.PlayerData)

local FISHING_SPOT_TAG = "FishingSpot"
local PROMPT_ACTION_TEXT = "낚시하기"
local PROMPT_HOLD_DURATION = 0.3
local PROMPT_MAX_DISTANCE = 12
local ROD_TIER2 = "rod_tier2"
local ROD_TIER3 = "rod_tier3"

local FishingService = {}

type FishState = "Idle" | "Waiting" | "Biting"

type PlayerFishingState = {
	state: FishState,
	generation: number,
	zone: string?,
	biteDeadline: number?,
	timeoutThread: thread?,
	bobber: BasePart?,
	bobberConn: RBXScriptConnection?,
}

type SpotInfo = {
	zone: string?,
	castTarget: Vector3?,
	displayName: string,
}

local states: { [Player]: PlayerFishingState } = {}

local function getOrCreateState(player: Player): PlayerFishingState
	local existing = states[player]
	if existing then
		return existing
	end
	local fresh: PlayerFishingState = {
		state = "Idle",
		generation = 0,
		zone = nil,
		biteDeadline = nil,
		timeoutThread = nil,
		bobber = nil,
		bobberConn = nil,
	}
	states[player] = fresh
	return fresh
end

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

-- ===== 찌(bobber) 이펙트 — 없어도 게임은 동작하지만, 있으면 훨씬 덜 심심하다 =====

local function createBobber(castTarget: Vector3): BasePart
	local bobber = Instance.new("Part")
	bobber.Name = "FishingBobber"
	bobber.Shape = Enum.PartType.Ball
	bobber.Size = Vector3.new(0.6, 0.6, 0.6)
	bobber.Color = Color3.fromRGB(196, 74, 58)
	bobber.Material = Enum.Material.Plastic
	bobber.Anchored = true
	bobber.CanCollide = false
	bobber.CanQuery = false
	bobber.Position = castTarget + Vector3.new(0, 0.3, 0)
	bobber.Parent = Workspace
	return bobber
end

local function startBobber(pState: PlayerFishingState, castTarget: Vector3)
	local bobber = createBobber(castTarget)
	local basePosition = bobber.Position
	local startTime = os.clock()

	pState.bobber = bobber
	pState.bobberConn = RunService.Heartbeat:Connect(function()
		local amplitude = if pState.state == "Biting" then 0.22 else 0.08
		local t = os.clock() - startTime
		bobber.Position = basePosition + Vector3.new(0, math.sin(t * 3) * amplitude, 0)
	end)
end

local function stopBobber(pState: PlayerFishingState)
	if pState.bobberConn then
		pState.bobberConn:Disconnect()
		pState.bobberConn = nil
	end
	if pState.bobber then
		pState.bobber:Destroy()
		pState.bobber = nil
	end
end

-- ===== 확률/보정 =====

local function bestRodUpgrade(player: Player): string?
	if PlayerData.HasUpgrade(player, ROD_TIER3) then
		return ROD_TIER3
	end
	if PlayerData.HasUpgrade(player, ROD_TIER2) then
		return ROD_TIER2
	end
	return nil
end

local function pickFish(zone: string?, rareMultiplier: number): string?
	local weights = FishingConfig.WeightsForZone(zone)
	local total = 0
	local adjusted: { { itemId: string, weight: number } } = {}
	for _, w in weights do
		local weight = w.weight
		local def = ItemDatabase.Get(w.itemId)
		if def and (def.rarity == "Rare" or def.rarity == "Legendary") then
			weight *= rareMultiplier
		end
		total += weight
		table.insert(adjusted, { itemId = w.itemId, weight = weight })
	end
	if total <= 0 then
		return nil
	end

	local roll = math.random() * total
	local cumulative = 0
	for _, w in adjusted do
		cumulative += w.weight
		if roll <= cumulative then
			return w.itemId
		end
	end
	return adjusted[#adjusted] and adjusted[#adjusted].itemId or nil
end

-- ===== 판정 결과 처리 =====

local function resolveMiss(player: Player, pState: PlayerFishingState)
	pState.state = "Idle"
	pState.biteDeadline = nil
	stopBobber(pState)
	Remotes.GetEvent("FishingResult"):FireClient(player, { success = false })
end

local function resolveSuccess(player: Player, pState: PlayerFishingState)
	pState.state = "Idle"
	pState.biteDeadline = nil
	stopBobber(pState)

	local rodBonus = FishingConfig.RodBonusFor(bestRodUpgrade(player))
	local rareMultiplier = if rodBonus then rodBonus.rareBoost else 1
	if PlayerData.HasUpgrade(player, FishingConfig.BAIT_UPGRADE_ID) then
		rareMultiplier *= FishingConfig.BaitRareBoost()
	end

	local fishId = pickFish(pState.zone, rareMultiplier)
	if fishId then
		PlayerData.AddItem(player, fishId, 1)
	end

	Remotes.GetEvent("FishingResult"):FireClient(player, { success = fishId ~= nil })
end

local function beginBiting(player: Player, pState: PlayerFishingState, myGeneration: number)
	pState.state = "Biting"

	local rodBonus = FishingConfig.RodBonusFor(bestRodUpgrade(player))
	local extraWindow = if rodBonus then rodBonus.extraWindow else 0
	local window = FishingConfig.BITE_REACTION_WINDOW + extraWindow
	local tolerantWindow = window + FishingConfig.NETWORK_TOLERANCE

	pState.biteDeadline = os.clock() + tolerantWindow

	Remotes.GetEvent("FishingBite"):FireClient(player, {})

	pState.timeoutThread = task.delay(tolerantWindow, function()
		if pState.generation ~= myGeneration or pState.state ~= "Biting" then
			return
		end
		resolveMiss(player, pState)
	end)
end

local function onSpotTriggered(spot: SpotInfo, player: Player)
	local pState = getOrCreateState(player)
	if pState.state ~= "Idle" then
		return
	end

	pState.generation += 1
	local myGeneration = pState.generation
	pState.state = "Waiting"
	pState.zone = spot.zone

	Remotes.GetEvent("FishingCastStarted"):FireClient(player, {
		spotDisplayName = spot.displayName,
	})

	local castTarget = spot.castTarget
	if castTarget then
		startBobber(pState, castTarget)
	end

	local waitSeconds = FishingConfig.CAST_WAIT_MIN + math.random() * (FishingConfig.CAST_WAIT_MAX - FishingConfig.CAST_WAIT_MIN)
	task.delay(waitSeconds, function()
		if pState.generation ~= myGeneration then
			return
		end
		beginBiting(player, pState, myGeneration)
	end)
end

local function onReactToBite(player: Player): boolean
	local pState = states[player]
	if not pState or pState.state ~= "Biting" then
		return false
	end

	if pState.timeoutThread then
		task.cancel(pState.timeoutThread)
		pState.timeoutThread = nil
	end

	local deadline = pState.biteDeadline
	local inTime = deadline ~= nil and os.clock() <= deadline

	if inTime then
		resolveSuccess(player, pState)
	else
		resolveMiss(player, pState)
	end

	return true
end

local function setupSpot(instance: Instance)
	local zoneRaw = instance:GetAttribute("Zone")
	local zone: string? = if type(zoneRaw) == "string" then zoneRaw else nil
	if not zone then
		warn(`[FishingService] {instance:GetFullName()} 에 Zone 속성이 없습니다 - 기본 확률표를 사용합니다`)
	end

	local castTargetRaw = instance:GetAttribute("CastTarget")
	local castTarget: Vector3? = if typeof(castTargetRaw) == "Vector3" then castTargetRaw else nil
	if not castTarget then
		warn(`[FishingService] {instance:GetFullName()} 에 CastTarget 속성이 없어 찌 이펙트를 생략합니다`)
	end

	local displayNameRaw = instance:GetAttribute("DisplayName")
	local displayName = if type(displayNameRaw) == "string" then displayNameRaw else "낚시터"

	local anchor = findAnchorPart(instance)
	if not anchor then
		warn(`[FishingService] {instance:GetFullName()} 에서 BasePart를 찾지 못해 건너뜁니다`)
		return
	end

	local spot: SpotInfo = { zone = zone, castTarget = castTarget, displayName = displayName }

	local existingPrompt = anchor:FindFirstChildOfClass("ProximityPrompt") :: ProximityPrompt?
	local prompt: ProximityPrompt
	if existingPrompt then
		prompt = existingPrompt
	else
		prompt = Instance.new("ProximityPrompt")
		prompt.Parent = anchor
	end
	prompt.ActionText = PROMPT_ACTION_TEXT
	prompt.ObjectText = displayName
	prompt.HoldDuration = PROMPT_HOLD_DURATION
	prompt.MaxActivationDistance = PROMPT_MAX_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Enabled = true
	prompt.Triggered:Connect(function(player)
		onSpotTriggered(spot, player)
	end)
end

function FishingService.Init()
	local spots = CollectionService:GetTagged(FISHING_SPOT_TAG)
	if #spots == 0 then
		warn(`[FishingService] "{FISHING_SPOT_TAG}" 태그가 달린 오브젝트를 하나도 찾지 못했습니다 — 스튜디오에서 낚시터 5곳(부두3+호숫가2)에 태그를 다시 달아주세요. 좌표 정보가 없어 코드로는 자동 복구할 수 없습니다.`)
	end

	for _, instance in spots do
		setupSpot(instance)
	end
	CollectionService:GetInstanceAddedSignal(FISHING_SPOT_TAG):Connect(setupSpot)

	Remotes.GetFunction("ReactToBite").OnServerInvoke = onReactToBite

	Players.PlayerRemoving:Connect(function(player)
		local pState = states[player]
		if pState then
			if pState.timeoutThread then
				task.cancel(pState.timeoutThread)
			end
			stopBobber(pState)
			states[player] = nil
		end
	end)

	print(`[FishingService] 초기화 완료 - 낚시터 {#spots}개 등록`)
end

return FishingService
