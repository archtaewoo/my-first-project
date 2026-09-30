--!strict
-- 수레(Workspace.Forest.HorseCart)를 말 뒤에 실제로 붙인다.
--
-- 말 리그(HorseRig/HorseConfig)는 절대 건드리지 않는다 — 여기서는 HorseRig가 공개한
-- getFrame/getSpec/getRoot만 읽기 전용으로 가져다 쓴다.
--
-- 붙이는 방식: WeldConstraint 같은 물리 제약 대신, 매 Heartbeat마다 수레 전체를
-- Model:PivotTo()로 원하는 위치에 정확히 옮긴다. 43개 파트를 물리로 얽으면 애니메이션
-- 중인 말과 부딪히며 떨리거나 튕기는 문제가 생길 수 있는데, 이 환경에서는 Studio로 직접
-- 확인할 수 없어 그런 예측 불가능한 흔들림을 감수할 수 없다. PivotTo 방식은 항상 결정적이고,
-- 시각적으로는 수레가 말 뒤에 단단히 고정되어 따라가는 것과 동일하게 보인다.
--
-- 식별: CartId 속성을 신뢰하고(맵에 이미 CartId="MainCart"로 지어져 있음), "Cart" 태그는
-- 참고용으로만 달아둔다(태그가 저장 중 사라져도 CartId 속성과 HitchPoint 자식으로 다시 찾을 수 있게).

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Features"):WaitForChild("Remotes"))
local HorseConfig = require(ReplicatedStorage:WaitForChild("HorseConfig"))
local HorseRig = require(ReplicatedStorage:WaitForChild("HorseRig"))

local PlayerData = require(script.Parent.PlayerData)

local CART_TAG = "Cart"
local CART_BASIC_UPGRADE_ID = "cart_basic"
local CART_LARGE_UPGRADE_ID = "cart_large"
local PROMPT_HOLD_DURATION = 0.4
local PROMPT_MAX_DISTANCE = 10
local HORSE_SEARCH_RADIUS = 40 -- 카트에서 이 거리(스터드) 안의 말 중 가장 가까운 말에 붙는다
local HITCH_CLEARANCE = 1.2 -- 말 뒷다리와 수레 끌채 사이 여유 공간(스터드)
local HITCH_HEIGHT = 1.8 -- 지면 기준 부착 높이(끌채가 자연스럽게 이어지는 높이)

local CartService = {}

type CartState = {
	instance: Model,
	hitchPoint: BasePart,
	prompt: ProximityPrompt,
	hitchRelative: CFrame, -- HitchPoint를 카트 피벗 기준 로컬 좌표로 - 강체이므로 항상 고정
	originalAnchored: { [BasePart]: boolean },
	hitchedHorse: Model?,
	followConn: RBXScriptConnection?,
}

local states: { [Instance]: CartState } = {}

-- 말 프레임(HorseRig.getFrame) 기준으로, 몸통 뒤쪽에 끌채가 이어질 지점을 계산한다.
-- colliderSize.Z/2 만큼이 말 몸통의 절반 길이이므로, 거기에 여유 공간을 더해 뒤쪽 지점을 잡는다.
local function computeHitchTarget(horse: Model): CFrame?
	local spec = HorseRig.getSpec(horse)
	local frame = HorseRig.getFrame(horse)
	if not spec or not frame then
		return nil
	end
	local rearZ = spec.colliderCenter.Z + spec.colliderSize.Z / 2 + HITCH_CLEARANCE
	return frame * CFrame.new(0, HITCH_HEIGHT, rearZ)
end

local function findNearestHorse(position: Vector3): Model?
	local nearest: Model? = nil
	local nearestDistance = HORSE_SEARCH_RADIUS

	for _, instance in CollectionService:GetTagged(HorseConfig.TAG) do
		if not instance:IsA("Model") then
			continue
		end
		local root = HorseRig.getRoot(instance)
		if not root then
			continue
		end
		local distance = (root.Position - position).Magnitude
		if distance <= nearestDistance then
			nearest = instance
			nearestDistance = distance
		end
	end

	return nearest
end

local function updatePromptText(state: CartState)
	state.prompt.ActionText = if state.hitchedHorse then "수레 분리하기" else "수레 연결하기"
end

local function stopFollowing(state: CartState)
	if state.followConn then
		state.followConn:Disconnect()
		state.followConn = nil
	end
	for part, wasAnchored in state.originalAnchored do
		part.Anchored = wasAnchored
	end
	state.originalAnchored = {}
	state.hitchedHorse = nil
end

local function startFollowing(state: CartState, horse: Model)
	state.hitchedHorse = horse

	for _, part in state.instance:GetDescendants() do
		if part:IsA("BasePart") then
			state.originalAnchored[part] = part.Anchored
			part.Anchored = true
		end
	end

	state.followConn = RunService.Heartbeat:Connect(function()
		local horseInstance = state.hitchedHorse
		if not horseInstance or not horseInstance.Parent then
			stopFollowing(state)
			updatePromptText(state)
			return
		end

		local targetHitchCFrame = computeHitchTarget(horseInstance)
		if not targetHitchCFrame then
			return
		end

		local desiredPivot = targetHitchCFrame * state.hitchRelative:Inverse()
		state.instance:PivotTo(desiredPivot)
	end)
end

local function onCartTriggered(state: CartState, player: Player)
	if state.hitchedHorse then
		stopFollowing(state)
		updatePromptText(state)
		Remotes.GetEvent("SimpleMessage"):FireClient(player, "수레를 분리했어요.")
		return
	end

	local hasCart = PlayerData.HasUpgrade(player, CART_BASIC_UPGRADE_ID) or PlayerData.HasUpgrade(player, CART_LARGE_UPGRADE_ID)
	if not hasCart then
		Remotes.GetEvent("SimpleMessage"):FireClient(player, "수레가 아직 없어요. 시장에서 먼저 구입해 주세요.")
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end

	local horse = findNearestHorse(root.Position)
	if not horse then
		Remotes.GetEvent("SimpleMessage"):FireClient(player, "근처에 말이 없어요. 말을 가까이 데려와 주세요.")
		return
	end

	startFollowing(state, horse)
	updatePromptText(state)
	Remotes.GetEvent("SimpleMessage"):FireClient(player, "수레를 연결했어요!")
end

local function setupCart(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	if states[instance] then
		return
	end

	local cartIdRaw = instance:GetAttribute("CartId")
	if type(cartIdRaw) ~= "string" then
		warn(`[CartService] {instance:GetFullName()} 에 CartId 속성이 없어 건너뜁니다`)
		return
	end

	if not CollectionService:HasTag(instance, CART_TAG) then
		CollectionService:AddTag(instance, CART_TAG)
	end

	local hitchPoint = instance:FindFirstChild("HitchPoint")
	if not hitchPoint or not hitchPoint:IsA("BasePart") then
		warn(`[CartService] {instance:GetFullName()} 에서 HitchPoint 파트를 찾지 못해 건너뜁니다`)
		return
	end

	local promptAnchor: BasePart = hitchPoint :: BasePart

	local existingPrompt = promptAnchor:FindFirstChildOfClass("ProximityPrompt") :: ProximityPrompt?
	local prompt: ProximityPrompt
	if existingPrompt then
		prompt = existingPrompt
	else
		prompt = Instance.new("ProximityPrompt")
		prompt.Parent = promptAnchor
	end
	prompt.ActionText = "수레 연결하기"
	prompt.ObjectText = "수레"
	prompt.HoldDuration = PROMPT_HOLD_DURATION
	prompt.MaxActivationDistance = PROMPT_MAX_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Enabled = true

	local pivot = instance:GetPivot()
	local hitchRelative = pivot:ToObjectSpace(hitchPoint.CFrame)

	local state: CartState = {
		instance = instance,
		hitchPoint = hitchPoint :: BasePart,
		prompt = prompt,
		hitchRelative = hitchRelative,
		originalAnchored = {},
		hitchedHorse = nil,
		followConn = nil,
	}
	states[instance] = state

	prompt.Triggered:Connect(function(player)
		onCartTriggered(state, player)
	end)

	instance.Destroying:Connect(function()
		stopFollowing(state)
		states[instance] = nil
	end)
end

function CartService.Init()
	local forest = Workspace:FindFirstChild("Forest")
	local knownCart = forest and forest:FindFirstChild("HorseCart")
	if knownCart then
		setupCart(knownCart)
	else
		warn("[CartService] Workspace.Forest.HorseCart 를 찾지 못했습니다 — 수레 기능을 건너뜁니다")
	end

	for _, instance in CollectionService:GetTagged(CART_TAG) do
		setupCart(instance)
	end
	CollectionService:GetInstanceAddedSignal(CART_TAG):Connect(setupCart)

	local count = 0
	for _ in states do
		count += 1
	end
	print(`[CartService] 초기화 완료 - 수레 {count}대 처리`)
end

return CartService
