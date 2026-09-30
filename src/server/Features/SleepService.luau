--!strict
-- 같이 자기: 같은 잠자리에서 서로 다른 두 플레이어가 함께해야 밤에서 아침으로 넘어간다.
-- 시간 전환은 Lighting.ClockTime을 직접 바꾼다 — 낮/밤 자동 순환(다음 작업)은 아직 없어서,
-- 여기서 아침으로 맞춘 뒤로는 따로 흐르지 않고 그 시각에 멈춰 있는다.
-- 실패 요소 없음: 혼자 기다리다 시간이 지나도 조용히 취소될 뿐, 벌칙은 없다.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Features"):WaitForChild("Remotes"))

local SLEEP_SPOT_TAG = "SleepSpot"
local PROMPT_ACTION_TEXT = "같이 자기"
local PROMPT_HOLD_DURATION = 0.4
local PROMPT_MAX_DISTANCE = 10
local WAIT_SECONDS = 30
local MORNING_CLOCK_TIME = 7
local TRANSITION_SECONDS = 4

local SleepService = {}

type SpotState = {
	displayName: string,
	waitingPlayer: Player?,
	generation: number,
}

local states: { [Instance]: SpotState } = {}

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

local function sendMessage(player: Player, message: string)
	Remotes.GetEvent("SleepMessage"):FireClient(player, message)
end

local function bringMorning()
	local tween = TweenService:Create(Lighting, TweenInfo.new(TRANSITION_SECONDS, Enum.EasingStyle.Sine), {
		ClockTime = MORNING_CLOCK_TIME,
	})
	tween:Play()
end

local function onSpotTriggered(state: SpotState, player: Player)
	local waiting = state.waitingPlayer

	if not waiting then
		state.waitingPlayer = player
		state.generation += 1
		local myGeneration = state.generation

		sendMessage(player, `{state.displayName}에서 함께할 사람을 기다리는 중...`)

		task.delay(WAIT_SECONDS, function()
			if state.generation ~= myGeneration or state.waitingPlayer ~= player then
				return
			end
			state.waitingPlayer = nil
			sendMessage(player, "아무도 오지 않아서 오늘 밤은 그냥 있기로 했어요.")
		end)
		return
	end

	if waiting == player then
		-- 같은 사람이 다시 누르면 기다리기를 취소한다.
		state.waitingPlayer = nil
		state.generation += 1
		sendMessage(player, "기다리기를 그만뒀어요.")
		return
	end

	-- 다른 플레이어가 함께해줬다 — 성사!
	state.waitingPlayer = nil
	state.generation += 1
	sendMessage(waiting, "좋은 아침이에요!")
	sendMessage(player, "좋은 아침이에요!")
	bringMorning()
end

local function setupSpot(instance: Instance)
	local displayNameRaw = instance:GetAttribute("DisplayName")
	local displayName = if type(displayNameRaw) == "string" then displayNameRaw else "잠자리"

	local anchor = findAnchorPart(instance)
	if not anchor then
		warn(`[SleepService] {instance:GetFullName()} 에서 BasePart를 찾지 못해 건너뜁니다`)
		return
	end

	local state: SpotState = { displayName = displayName, waitingPlayer = nil, generation = 0 }
	states[instance] = state

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
		onSpotTriggered(state, player)
	end)

	instance.Destroying:Connect(function()
		states[instance] = nil
	end)
end

function SleepService.Init()
	local spots = CollectionService:GetTagged(SLEEP_SPOT_TAG)
	if #spots == 0 then
		warn(`[SleepService] "{SLEEP_SPOT_TAG}" 태그가 달린 오브젝트를 하나도 찾지 못했습니다 — 3곳(텐트2+오두막)에 태그를 다시 달아주세요.`)
	end
	for _, instance in spots do
		setupSpot(instance)
	end
	CollectionService:GetInstanceAddedSignal(SLEEP_SPOT_TAG):Connect(setupSpot)

	print(`[SleepService] 초기화 완료 - 잠자리 {#spots}곳`)
end

return SleepService
