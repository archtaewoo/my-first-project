--!strict
-- 퀘스트 게시판 창. 읽기 전용 — 누르는 버튼 없이 현재 진행 상황만 보여준다.
--
-- 공통 디자인 틀(Theme/Components)로 조립한다 - 데이터 흐름(Init/Open/Close/IsOpen/
-- UpdateQuest)은 전과 동일하고 겉모습만 바뀌었다. 오른쪽의 "완료!"/"n/목표" 표시는
-- ItemCard의 액션 버튼 자리를 누를 수 없는 상태 칩으로 재사용한 것이다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage:WaitForChild("Features"):WaitForChild("Types"))

local UIFolder = ReplicatedStorage:WaitForChild("Features"):WaitForChild("UI")
local Theme = require(UIFolder:WaitForChild("Theme"))
local Components = UIFolder:WaitForChild("Components")
local PanelFrame = require(Components:WaitForChild("PanelFrame"))
local ItemCard = require(Components:WaitForChild("ItemCard"))

local QuestBoardUI = {}

local screenGuiRef: ScreenGui? = nil
local listFrame: ScrollingFrame? = nil
local isOpen = false
local currentQuests: { Types.QuestListingView } = {}

local function clearList()
	local list = listFrame
	if not list then
		return
	end
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
end

local function showEmpty(parent: Instance)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 60)
	label.Font = Theme.Font.BodyLight
	label.TextColor3 = Theme.Color.TextMuted
	label.TextScaled = true
	label.Text = "게시된 퀘스트가 없어요."
	label.Parent = parent
end

local function renderList()
	clearList()
	local list = listFrame
	if not list then
		return
	end

	for order, quest in currentQuests do
		local statusText: string
		local statusColor: Color3
		if quest.completed then
			statusText, statusColor = "완료!", Theme.Color.AccentGreen
		else
			statusText, statusColor = `{quest.progress}/{quest.target}`, Theme.Color.Panel
		end

		local card = ItemCard.new({
			parent = list,
			layoutOrder = order,
			title = `[{quest.kindLabel}] {quest.displayName}`,
			subText = quest.hint,
			iconText = quest.kindLabel,
			actionText = statusText,
			height = 78,
		})

		-- 읽기 전용 표시라 액션 버튼을 누를 수 없는 상태 칩으로 바꿔 쓴다.
		local statusChip = card.actionButton
		if statusChip then
			statusChip.Active = false
			statusChip.AutoButtonColor = false
			statusChip.BackgroundColor3 = statusColor
			statusChip.TextColor3 = if quest.completed then Theme.Color.TextOnAccent else Theme.Color.Text
		end
	end

	if #currentQuests == 0 then
		showEmpty(list)
	end
end

function QuestBoardUI.Init(playerGui: PlayerGui)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "QuestBoardGui"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Enabled = false

	local panel = PanelFrame.new({
		parent = screenGui,
		title = "퀘스트 게시판",
		onClose = function()
			QuestBoardUI.Close()
		end,
	})

	local scroller = Instance.new("ScrollingFrame")
	scroller.Name = "List"
	scroller.BackgroundTransparency = 1
	scroller.Size = UDim2.new(1, 0, 1, 0)
	scroller.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroller.ScrollBarThickness = 6
	scroller.ScrollBarImageColor3 = Theme.Color.Accent
	scroller.Parent = panel.body

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 10)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = scroller

	listFrame = scroller
	screenGuiRef = screenGui
	screenGui.Parent = playerGui
end

function QuestBoardUI.Open(payload: Types.OpenQuestBoardPayload)
	currentQuests = payload.quests
	isOpen = true
	renderList()
	if screenGuiRef then
		screenGuiRef.Enabled = true
	end
end

function QuestBoardUI.Close()
	isOpen = false
	if screenGuiRef then
		screenGuiRef.Enabled = false
	end
end

function QuestBoardUI.IsOpen(): boolean
	return isOpen
end

-- 진행/완료 알림이 왔을 때 창이 열려 있으면 해당 항목만 바로 갱신한다.
function QuestBoardUI.UpdateQuest(payload: Types.QuestProgressPayload)
	for _, quest in currentQuests do
		if quest.id == payload.questId then
			quest.progress = payload.progress
			quest.target = payload.target
			quest.completed = payload.completed
		end
	end
	if isOpen then
		renderList()
	end
end

return QuestBoardUI
