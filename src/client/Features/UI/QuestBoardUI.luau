--!strict
-- 퀘스트 게시판 창. 읽기 전용 — 누르는 버튼 없이 현재 진행 상황만 보여준다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage:WaitForChild("Features"):WaitForChild("Types"))

local QuestBoardUI = {}

local COLOR_BG = Color3.fromRGB(45, 32, 22)
local COLOR_PANEL = Color3.fromRGB(63, 45, 30)
local COLOR_CARD = Color3.fromRGB(77, 56, 38)
local COLOR_CARD_DONE = Color3.fromRGB(70, 86, 58)
local COLOR_TEXT = Color3.fromRGB(248, 238, 220)
local COLOR_TEXT_MUTED = Color3.fromRGB(178, 156, 130)
local COLOR_ACCENT = Color3.fromRGB(196, 160, 112)

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

local function renderList()
	clearList()
	local list = listFrame
	if not list then
		return
	end

	for _, quest in currentQuests do
		local row = Instance.new("Frame")
		row.BackgroundColor3 = if quest.completed then COLOR_CARD_DONE else COLOR_CARD
		row.Size = UDim2.new(1, 0, 0, 74)
		row.Parent = list

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = row

		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 14)
		padding.PaddingRight = UDim.new(0, 14)
		padding.PaddingTop = UDim.new(0, 8)
		padding.PaddingBottom = UDim.new(0, 8)
		padding.Parent = row

		local nameLabel = Instance.new("TextLabel")
		nameLabel.BackgroundTransparency = 1
		nameLabel.Size = UDim2.new(0.72, 0, 0.5, 0)
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextColor3 = COLOR_TEXT
		nameLabel.TextScaled = true
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Text = `[{quest.kindLabel}] {quest.displayName}`
		nameLabel.Parent = row

		local hintLabel = Instance.new("TextLabel")
		hintLabel.BackgroundTransparency = 1
		hintLabel.Position = UDim2.new(0, 0, 0.5, 0)
		hintLabel.Size = UDim2.new(0.72, 0, 0.5, 0)
		hintLabel.Font = Enum.Font.Gotham
		hintLabel.TextColor3 = COLOR_TEXT_MUTED
		hintLabel.TextScaled = true
		hintLabel.TextXAlignment = Enum.TextXAlignment.Left
		hintLabel.TextWrapped = true
		hintLabel.Text = quest.hint
		hintLabel.Parent = row

		local statusLabel = Instance.new("TextLabel")
		statusLabel.AnchorPoint = Vector2.new(1, 0.5)
		statusLabel.Position = UDim2.new(1, 0, 0.5, 0)
		statusLabel.Size = UDim2.new(0.24, 0, 0.6, 0)
		statusLabel.BackgroundTransparency = 1
		statusLabel.Font = Enum.Font.GothamBold
		statusLabel.TextColor3 = if quest.completed then COLOR_ACCENT else COLOR_TEXT
		statusLabel.TextScaled = true
		statusLabel.Text = if quest.completed then "완료!" else `{quest.progress}/{quest.target}`
		statusLabel.Parent = row
	end

	if #currentQuests == 0 then
		local emptyLabel = Instance.new("TextLabel")
		emptyLabel.BackgroundTransparency = 1
		emptyLabel.Size = UDim2.new(1, 0, 0, 60)
		emptyLabel.Font = Enum.Font.Gotham
		emptyLabel.TextColor3 = COLOR_TEXT_MUTED
		emptyLabel.TextScaled = true
		emptyLabel.Text = "게시된 퀘스트가 없어요."
		emptyLabel.Parent = list
	end
end

function QuestBoardUI.Init(playerGui: PlayerGui)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "QuestBoardGui"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Enabled = false

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.new(0.5, 0, 0.5, 0)
	panel.Size = UDim2.new(0.85, 0, 0.78, 0)
	panel.BackgroundColor3 = COLOR_BG
	panel.Parent = screenGui

	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 16)
	panelCorner.Parent = panel

	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = COLOR_ACCENT
	panelStroke.Thickness = 2
	panelStroke.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.new(0, 20, 0, 8)
	title.Size = UDim2.new(1, -60, 0, 40)
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = COLOR_TEXT
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "퀘스트 게시판"
	title.Parent = panel

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -12, 0, 12)
	closeButton.Size = UDim2.new(0, 36, 0, 36)
	closeButton.BackgroundColor3 = COLOR_PANEL
	closeButton.TextColor3 = COLOR_TEXT
	closeButton.Font = Enum.Font.GothamBold
	closeButton.TextScaled = true
	closeButton.Text = "X"
	closeButton.Parent = panel

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(1, 0)
	closeCorner.Parent = closeButton

	closeButton.Activated:Connect(function()
		QuestBoardUI.Close()
	end)

	local scroller = Instance.new("ScrollingFrame")
	scroller.Name = "List"
	scroller.BackgroundTransparency = 1
	scroller.Position = UDim2.new(0, 20, 0, 60)
	scroller.Size = UDim2.new(1, -40, 1, -80)
	scroller.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroller.ScrollBarThickness = 6
	scroller.Parent = panel

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
