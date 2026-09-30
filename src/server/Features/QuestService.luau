--!strict
-- 퀘스트: QuestPoint 9곳(방문형 — 맵에 있는 QuestId/DisplayName/Hint/Radius를 그대로 읽어서
-- 쓴다) + QuestCatalog에 고정 정의된 수집형 퀘스트. 게시판(Workspace.Forest.Market.Props.
-- Zone1.NoticeBoard)에서 전체 현황을 볼 수 있다. 이 오브젝트엔 아직 태그·속성이 없어서
-- "QuestBoard" 태그를 새로 달아 쓴다(맵 오브젝트 자체는 그대로 두고 태그만 추가).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemDatabase = require(ReplicatedStorage:WaitForChild("Features"):WaitForChild("ItemDatabase"))
local QuestCatalog = require(ReplicatedStorage:WaitForChild("Features"):WaitForChild("QuestCatalog"))
local ShopCatalog = require(ReplicatedStorage:WaitForChild("Features"):WaitForChild("ShopCatalog"))
local Remotes = require(ReplicatedStorage:WaitForChild("Features"):WaitForChild("Remotes"))
local Types = require(ReplicatedStorage:WaitForChild("Features"):WaitForChild("Types"))

local PlayerData = require(script.Parent.PlayerData)

local QUEST_POINT_TAG = "QuestPoint"
local QUEST_BOARD_TAG = "QuestBoard"
local VISIT_CHECK_INTERVAL = 1
local DEFAULT_RADIUS = 10
local BOARD_PATH = { "Forest", "Market", "Props", "Zone1", "NoticeBoard" }

local QuestService = {}

type VisitPoint = {
	questId: string,
	displayName: string,
	hint: string,
	radius: number,
	anchor: BasePart,
}

local visitPoints: { VisitPoint } = {}

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

local function findByPath(root: Instance, path: { string }): Instance?
	local current: Instance = root
	for _, name in path do
		local nextInstance = current:FindFirstChild(name)
		if not nextInstance then
			return nil
		end
		current = nextInstance
	end
	return current
end

local function questDisplayName(questId: string): string
	for _, point in visitPoints do
		if point.questId == questId then
			return point.displayName
		end
	end
	local collectDef = QuestCatalog.GetCollectQuest(questId)
	if collectDef then
		return collectDef.displayName
	end
	return questId
end

local function notifyQuestProgress(player: Player, questId: string, progress: number, target: number, completed: boolean, rewardAcorns: number)
	Remotes.GetEvent("QuestProgress"):FireClient(player, {
		questId = questId,
		displayName = questDisplayName(questId),
		progress = progress,
		target = target,
		completed = completed,
		rewardAcorns = rewardAcorns,
	})
end

local function completeVisitQuest(player: Player, point: VisitPoint)
	local current = PlayerData.GetQuestProgress(player, point.questId)
	if current.completed then
		return
	end
	PlayerData.SetQuestProgress(player, point.questId, 1, true)
	PlayerData.AddCurrency(player, ShopCatalog.CURRENCY_ACORN, QuestCatalog.VISIT_REWARD_ACORNS)
	notifyQuestProgress(player, point.questId, 1, 1, true, QuestCatalog.VISIT_REWARD_ACORNS)
end

local function checkVisits()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if not character then
			continue
		end
		local root = character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			continue
		end

		for _, point in visitPoints do
			local current = PlayerData.GetQuestProgress(player, point.questId)
			if current.completed then
				continue
			end
			local distance = (root.Position - point.anchor.Position).Magnitude
			if distance <= point.radius then
				completeVisitQuest(player, point)
			end
		end
	end
end

local function onItemAdded(player: Player, itemId: string, _newCount: number)
	local def = ItemDatabase.Get(itemId)
	if not def then
		return
	end

	for _, quest in QuestCatalog.GetCollectQuests() do
		if quest.kind ~= def.kind then
			continue
		end

		local current = PlayerData.GetQuestProgress(player, quest.id)
		if current.completed then
			continue
		end

		local newProgress = math.min(current.progress + 1, quest.target)
		local completed = newProgress >= quest.target
		PlayerData.SetQuestProgress(player, quest.id, newProgress, completed)

		local reward = 0
		if completed then
			reward = quest.rewardAcorns
			PlayerData.AddCurrency(player, ShopCatalog.CURRENCY_ACORN, reward)
		end

		notifyQuestProgress(player, quest.id, newProgress, quest.target, completed, reward)
	end
end

local function setupQuestPoint(instance: Instance)
	local questIdRaw = instance:GetAttribute("QuestId")
	if type(questIdRaw) ~= "string" then
		warn(`[QuestService] {instance:GetFullName()} 에 QuestId 속성이 없어 건너뜁니다`)
		return
	end
	local questId = questIdRaw :: string

	local displayNameRaw = instance:GetAttribute("DisplayName")
	local displayName = if type(displayNameRaw) == "string" then displayNameRaw else questId

	local hintRaw = instance:GetAttribute("Hint")
	local hint = if type(hintRaw) == "string" then hintRaw else ""

	local radiusRaw = instance:GetAttribute("Radius")
	local radius = if type(radiusRaw) == "number" then radiusRaw else DEFAULT_RADIUS

	local anchor = findAnchorPart(instance)
	if not anchor then
		warn(`[QuestService] {instance:GetFullName()} 에서 BasePart를 찾지 못해 건너뜁니다`)
		return
	end

	table.insert(visitPoints, {
		questId = questId,
		displayName = displayName,
		hint = hint,
		radius = radius,
		anchor = anchor,
	})
end

local function buildQuestListing(player: Player): { Types.QuestListingView }
	local views = {}

	for _, point in visitPoints do
		local current = PlayerData.GetQuestProgress(player, point.questId)
		table.insert(views, {
			id = point.questId,
			displayName = point.displayName,
			hint = point.hint,
			kindLabel = "방문",
			progress = if current.completed then 1 else 0,
			target = 1,
			completed = current.completed,
		})
	end

	for _, quest in QuestCatalog.GetCollectQuests() do
		local current = PlayerData.GetQuestProgress(player, quest.id)
		table.insert(views, {
			id = quest.id,
			displayName = quest.displayName,
			hint = quest.hint,
			kindLabel = "수집",
			progress = current.progress,
			target = quest.target,
			completed = current.completed,
		})
	end

	return views
end

local function onBoardTriggered(player: Player)
	Remotes.GetEvent("OpenQuestBoard"):FireClient(player, {
		quests = buildQuestListing(player),
	})
end

local function setupBoard()
	local noticeBoard = findByPath(Workspace, BOARD_PATH)
	if not noticeBoard then
		warn(`[QuestService] Workspace.{table.concat(BOARD_PATH, ".")} 를 찾지 못해 게시판을 건너뜁니다`)
		return
	end

	if not CollectionService:HasTag(noticeBoard, QUEST_BOARD_TAG) then
		CollectionService:AddTag(noticeBoard, QUEST_BOARD_TAG)
	end

	local boardPart = noticeBoard:FindFirstChild("Board")
	local anchor: BasePart?
	if boardPart and boardPart:IsA("BasePart") then
		anchor = boardPart
	else
		anchor = findAnchorPart(noticeBoard)
	end
	if not anchor then
		warn("[QuestService] NoticeBoard에서 BasePart를 찾지 못해 게시판을 건너뜁니다")
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
	prompt.ActionText = "게시판 보기"
	prompt.ObjectText = "퀘스트 게시판"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Enabled = true
	prompt.Triggered:Connect(onBoardTriggered)
end

function QuestService.Init()
	local points = CollectionService:GetTagged(QUEST_POINT_TAG)
	if #points == 0 then
		warn(`[QuestService] "{QUEST_POINT_TAG}" 태그가 달린 오브젝트를 하나도 찾지 못했습니다 — 9곳에 태그를 다시 달아주세요.`)
	end
	for _, instance in points do
		setupQuestPoint(instance)
	end
	CollectionService:GetInstanceAddedSignal(QUEST_POINT_TAG):Connect(setupQuestPoint)

	setupBoard()

	PlayerData.OnItemAdded(onItemAdded)

	task.spawn(function()
		while true do
			task.wait(VISIT_CHECK_INTERVAL)
			checkVisits()
		end
	end)

	print(`[QuestService] 초기화 완료 - 방문 퀘스트 {#visitPoints}개, 수집 퀘스트 {#QuestCatalog.GetCollectQuests()}개`)
end

return QuestService
