--!strict
-- 모닥불 요리 + 먹기. 재료 소모/결과 지급/버프는 전부 서버가 검증하고 직접 적용한다.
--
-- CanCook 속성이 명시적으로 false인 모닥불은 요리 지점이 아니라고 보고 건너뛴다.
-- Lit(불이 붙어있는지)은 이번 범위(불 붙이기 기능이 아직 없음)에서는 가리지 않는다 —
-- 계속 꺼진 채로 고정돼 있다면 요리가 영영 막힐 수 있어서다.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemDatabase = require(ReplicatedStorage:WaitForChild("Features"):WaitForChild("ItemDatabase"))
local RecipeCatalog = require(ReplicatedStorage:WaitForChild("Features"):WaitForChild("RecipeCatalog"))
local Remotes = require(ReplicatedStorage:WaitForChild("Features"):WaitForChild("Remotes"))

local PlayerData = require(script.Parent.PlayerData)

local CAMPFIRE_TAG = "Campfire"
local PROMPT_ACTION_TEXT = "요리하기"
local PROMPT_HOLD_DURATION = 0.4
local PROMPT_MAX_DISTANCE = 10

local CampfireService = {}

type EatBuff = {
	expiresAt: number,
	originalSpeed: number,
}

-- 먹기 버프는 플레이어별로 하나만 유지한다(다시 먹으면 시간만 연장, 배속 중첩은 안 시킴).
local activeBuffs: { [Player]: EatBuff } = {}

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

local function buildRecipeViews(player: Player)
	local views = {}
	for _, recipe in RecipeCatalog.GetAllInOrder() do
		local ingredientViews = {}
		local craftable = true
		for itemId, needed in recipe.ingredients do
			local owned = PlayerData.GetItemCount(player, itemId)
			if owned < needed then
				craftable = false
			end
			local def = ItemDatabase.Get(itemId)
			table.insert(ingredientViews, {
				itemId = itemId,
				displayName = if def then def.displayName else itemId,
				needed = needed,
				owned = owned,
			})
		end
		table.insert(views, {
			id = recipe.id,
			displayName = recipe.displayName,
			description = recipe.description,
			ingredients = ingredientViews,
			craftable = craftable,
		})
	end
	return views
end

local function onCampfireTriggered(player: Player)
	Remotes.GetEvent("OpenCampfire"):FireClient(player, {
		recipes = buildRecipeViews(player),
	})
end

local function setupCampfire(instance: Instance)
	local canCookRaw = instance:GetAttribute("CanCook")
	if canCookRaw == false then
		return -- 이 모닥불은 요리 지점이 아니다(장식용 등)
	end

	local anchor = findAnchorPart(instance)
	if not anchor then
		warn(`[CampfireService] {instance:GetFullName()} 에서 BasePart를 찾지 못해 건너뜁니다`)
		return
	end

	local existingPrompt = anchor:FindFirstChildOfClass("ProximityPrompt") :: ProximityPrompt?
	local prompt: ProximityPrompt
	if existingPrompt then
		prompt = existingPrompt
	else
		prompt = Instance.new("ProximityPrompt")
		prompt.Parent = anchor
	end
	prompt.ActionText = PROMPT_ACTION_TEXT
	prompt.ObjectText = "모닥불"
	prompt.HoldDuration = PROMPT_HOLD_DURATION
	prompt.MaxActivationDistance = PROMPT_MAX_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Enabled = true
	prompt.Triggered:Connect(onCampfireTriggered)
end

-- ===== 요리/먹기 검증 (RemoteFunction) =====

local function onCookInvoked(player: Player, recipeIdArg: unknown): (boolean, string)
	if type(recipeIdArg) ~= "string" then
		return false, "invalid_request"
	end
	local recipe = RecipeCatalog.Get(recipeIdArg)
	if not recipe then
		return false, "unknown_recipe"
	end

	for itemId, needed in recipe.ingredients do
		if not PlayerData.HasItem(player, itemId, needed) then
			return false, "missing_ingredients"
		end
	end

	for itemId, needed in recipe.ingredients do
		local removedOk = PlayerData.RemoveItem(player, itemId, needed)
		if not removedOk then
			return false, "cook_failed"
		end
	end

	local addedOk = PlayerData.AddItem(player, recipe.resultItemId, 1)
	if not addedOk then
		-- 롤백: 이미 소모한 재료를 되돌려준다.
		for itemId, needed in recipe.ingredients do
			PlayerData.AddItem(player, itemId, needed)
		end
		return false, "cook_failed"
	end

	return true, "ok"
end

local function applyEatBuff(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local existing = activeBuffs[player]
	if existing then
		existing.expiresAt = os.clock() + RecipeCatalog.EAT_BUFF_DURATION
		return
	end

	activeBuffs[player] = {
		expiresAt = os.clock() + RecipeCatalog.EAT_BUFF_DURATION,
		originalSpeed = humanoid.WalkSpeed,
	}
	humanoid.WalkSpeed += RecipeCatalog.EAT_WALKSPEED_BONUS
end

local function onEatInvoked(player: Player, itemIdArg: unknown): (boolean, string)
	if type(itemIdArg) ~= "string" then
		return false, "invalid_request"
	end
	local itemId = itemIdArg :: string

	local def = ItemDatabase.Get(itemId)
	if not def or def.kind ~= "Food" then
		return false, "not_food"
	end
	if not PlayerData.HasItem(player, itemId, 1) then
		return false, "not_enough_inventory"
	end

	local removedOk = PlayerData.RemoveItem(player, itemId, 1)
	if not removedOk then
		return false, "eat_failed"
	end

	applyEatBuff(player)
	return true, "ok"
end

local function revertExpiredBuffs()
	local now = os.clock()
	for player, buff in activeBuffs do
		if now >= buff.expiresAt then
			activeBuffs[player] = nil
			local character = player.Character
			if character then
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid.WalkSpeed = buff.originalSpeed
				end
			end
		end
	end
end

function CampfireService.Init()
	local spots = CollectionService:GetTagged(CAMPFIRE_TAG)
	if #spots == 0 then
		warn(`[CampfireService] "{CAMPFIRE_TAG}" 태그가 달린 오브젝트를 하나도 찾지 못했습니다 — 3곳에 태그를 다시 달아주세요.`)
	end
	for _, instance in spots do
		setupCampfire(instance)
	end
	CollectionService:GetInstanceAddedSignal(CAMPFIRE_TAG):Connect(setupCampfire)

	Remotes.GetFunction("Cook").OnServerInvoke = onCookInvoked
	Remotes.GetFunction("Eat").OnServerInvoke = onEatInvoked

	task.spawn(function()
		while true do
			task.wait(5)
			revertExpiredBuffs()
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		activeBuffs[player] = nil
	end)

	print(`[CampfireService] 초기화 완료 - 모닥불 {#spots}개 처리`)
end

return CampfireService
