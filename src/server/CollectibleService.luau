--!strict
-- Collectible 태그가 붙은 버섯/꽃을 ProximityPrompt로 채집한다.
-- 월드 공유: 먼저 줍는 사람이 가져가고, 10분 뒤(서버 시간 기준) 다시 나타난다.
-- 이름으로 오브젝트를 찾지 않는다 — CollectionService 태그만 사용한다.

local CollectionService = game:GetService("CollectionService")

local PlayerData = require(script.Parent.PlayerData)

local TAG = "Collectible"
local RESPAWN_SECONDS = 600 -- 10분
local PROMPT_HOLD_DURATION = 0.5
local PROMPT_MAX_DISTANCE = 8

local CollectibleService = {}

type CollectibleState = {
	instance: Instance,
	prompt: ProximityPrompt,
	parts: { BasePart },
	originalTransparency: { [BasePart]: number },
	originalCanCollide: { [BasePart]: boolean },
	available: boolean,
	respawnAt: number,
}

local states: { [Instance]: CollectibleState } = {}

local function collectParts(instance: Instance): { BasePart }
	local parts: { BasePart } = {}
	if instance:IsA("BasePart") then
		table.insert(parts, instance)
	end
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	return parts
end

local function findAnchorPart(instance: Instance): BasePart?
	if instance:IsA("BasePart") then
		return instance
	end
	if instance:IsA("Model") then
		local model = instance :: Model
		if model.PrimaryPart then
			return model.PrimaryPart
		end
	end
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") then
			return descendant
		end
	end
	return nil
end

local function setHidden(state: CollectibleState, hidden: boolean)
	for _, part in state.parts do
		if hidden then
			part.Transparency = 1
			part.CanCollide = false
		else
			part.Transparency = state.originalTransparency[part] or 0
			part.CanCollide = if state.originalCanCollide[part] == nil then true else state.originalCanCollide[part]
		end
	end
	state.prompt.Enabled = not hidden
end

local function onTriggered(state: CollectibleState, player: Player)
	if not state.available then
		return -- 이미 다른 사람이 가져갔거나 아직 재생성 전
	end

	local itemId = state.instance:GetAttribute("ItemId")
	if type(itemId) ~= "string" then
		warn(`[CollectibleService] {state.instance:GetFullName()} 에 ItemId 속성이 없습니다`)
		return
	end

	state.available = false
	state.respawnAt = os.time() + RESPAWN_SECONDS
	setHidden(state, true)

	PlayerData.AddItem(player, itemId, 1)
end

local function setupCollectible(instance: Instance)
	if states[instance] then
		return
	end

	local kind = instance:GetAttribute("Kind")
	local itemId = instance:GetAttribute("ItemId")
	local displayName = instance:GetAttribute("DisplayName")
	if type(itemId) ~= "string" then
		warn(`[CollectibleService] {instance:GetFullName()} 에 ItemId 속성이 없어 건너뜁니다`)
		return
	end

	local anchor = findAnchorPart(instance)
	if not anchor then
		warn(`[CollectibleService] {instance:GetFullName()} 에서 BasePart를 찾지 못해 건너뜁니다`)
		return
	end

	local parts = collectParts(instance)
	local originalTransparency: { [BasePart]: number } = {}
	local originalCanCollide: { [BasePart]: boolean } = {}
	for _, part in parts do
		originalTransparency[part] = part.Transparency
		originalCanCollide[part] = part.CanCollide
	end

	local prompt = anchor:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Parent = anchor
	end
	prompt.ActionText = "줍기"
	prompt.ObjectText = (type(displayName) == "string" and displayName) or (type(kind) == "string" and kind) or "채집"
	prompt.HoldDuration = PROMPT_HOLD_DURATION
	prompt.MaxActivationDistance = PROMPT_MAX_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Enabled = true

	local state: CollectibleState = {
		instance = instance,
		prompt = prompt,
		parts = parts,
		originalTransparency = originalTransparency,
		originalCanCollide = originalCanCollide,
		available = true,
		respawnAt = 0,
	}
	states[instance] = state

	prompt.Triggered:Connect(function(player)
		onTriggered(state, player)
	end)

	instance.Destroying:Connect(function()
		states[instance] = nil
	end)
end

-- 10분 복구는 task.delay가 아니라 os.time() 대비 주기적 스캔으로 처리한다 (서버 시간 기준, 서버 랙에 덜 민감).
local function respawnHeartbeat()
	while true do
		task.wait(15)
		local now = os.time()
		for _, state in states do
			if not state.available and now >= state.respawnAt then
				state.available = true
				setHidden(state, false)
			end
		end
	end
end

function CollectibleService.Init()
	for _, instance in CollectionService:GetTagged(TAG) do
		setupCollectible(instance)
	end

	CollectionService:GetInstanceAddedSignal(TAG):Connect(setupCollectible)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(instance)
		states[instance] = nil
	end)

	task.spawn(respawnHeartbeat)

	print(`[CollectibleService] 초기화 완료 - Collectible {#CollectionService:GetTagged(TAG)}개 등록`)
end

return CollectibleService
