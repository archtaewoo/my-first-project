--!strict
-- 목록 항목 카드. [아이콘 슬롯] + 이름 + 보조 텍스트(수량/설명) 한 줄, 필요하면 오른쪽에
-- 초록색 액션 버튼(구매/수락/요리하기 등)까지 - 상점/퀘스트/도감/모닥불 목록이 전부 이 모양을 쓴다.
-- progressBar는 선택 사항이라 ProgressBar 컴포넌트를 직접 붙이고 싶으면 frame을 받아 추가하면 된다.

local Theme = require(script.Parent.Parent:WaitForChild("Theme"))

local ItemCard = {}

export type ItemCardProps = {
	parent: Instance,
	title: string,
	subText: string?,
	iconColor: Color3?,
	iconText: string?, -- 아이콘 자리에 짧은 글자(머릿글자 등)만 넣고 싶을 때
	locked: boolean?, -- true면 어둡게, 이름 대신 "???" 처리는 호출부가 title로 넘겨서 결정
	actionText: string?, -- 있으면 오른쪽에 녹색 액션 버튼 생성
	layoutOrder: number?,
	height: number?,
}

export type Card = {
	frame: Frame,
	iconSlot: Frame,
	nameLabel: TextLabel,
	subLabel: TextLabel,
	actionButton: TextButton?,
}

function ItemCard.new(props: ItemCardProps): Card
	local locked = props.locked == true

	local frame = Instance.new("Frame")
	frame.Name = "Card"
	frame.LayoutOrder = props.layoutOrder or 0
	frame.Size = UDim2.new(1, 0, 0, props.height or 78)
	frame.BackgroundColor3 = if locked then Theme.Color.Locked else Theme.Color.PanelLight
	frame.Parent = props.parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.Corner.Card
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Color.Border
	stroke.Thickness = Theme.Stroke.Card
	stroke.Parent = frame

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.Parent = frame

	local iconSlot = Instance.new("Frame")
	iconSlot.Name = "IconSlot"
	iconSlot.AnchorPoint = Vector2.new(0, 0.5)
	iconSlot.Position = UDim2.new(0, 0, 0.5, 0)
	iconSlot.Size = UDim2.new(0, 56, 0, 56)
	iconSlot.BackgroundColor3 = props.iconColor or Theme.Color.Panel
	iconSlot.Parent = frame

	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = Theme.Corner.Button
	iconCorner.Parent = iconSlot

	local iconStroke = Instance.new("UIStroke")
	iconStroke.Color = Theme.Color.Border
	iconStroke.Thickness = Theme.Stroke.Card
	iconStroke.Parent = iconSlot

	if props.iconText then
		local iconLabel = Instance.new("TextLabel")
		iconLabel.Name = "IconText"
		iconLabel.BackgroundTransparency = 1
		iconLabel.Size = UDim2.new(1, -6, 1, -6)
		iconLabel.Position = UDim2.new(0, 3, 0, 3)
		iconLabel.Font = Theme.Font.Heading
		iconLabel.TextColor3 = Theme.Color.Text
		iconLabel.TextScaled = true
		iconLabel.Text = props.iconText
		iconLabel.Parent = iconSlot
	end

	local actionButton: TextButton? = nil
	local rightInset = 0
	if props.actionText then
		local button = Instance.new("TextButton")
		button.Name = "ActionButton"
		button.AnchorPoint = Vector2.new(1, 0.5)
		button.Position = UDim2.new(1, 0, 0.5, 0)
		button.Size = UDim2.new(0, 88, 0, math.max(40, Theme.Layout.MinTouchTarget))
		button.BackgroundColor3 = Theme.Color.AccentGreen
		button.AutoButtonColor = true
		button.Font = Theme.Font.Heading
		button.TextColor3 = Theme.Color.TextOnAccent
		button.TextScaled = true
		button.Text = props.actionText
		button.Parent = frame

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = Theme.Corner.Button
		btnCorner.Parent = button

		local btnStroke = Instance.new("UIStroke")
		btnStroke.Color = Theme.Color.AccentGreenDark
		btnStroke.Thickness = Theme.Stroke.Button
		btnStroke.Parent = button

		actionButton = button
		rightInset = 98
	end

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.BackgroundTransparency = 1
	nameLabel.Position = UDim2.new(0, 66, 0, 0)
	nameLabel.Size = UDim2.new(1, -66 - rightInset, 0.55, 0)
	nameLabel.Font = Theme.Font.Heading
	nameLabel.TextColor3 = if locked then Theme.Color.LockedText else Theme.Color.Text
	nameLabel.TextScaled = true
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Text = props.title
	nameLabel.Parent = frame

	local subLabel = Instance.new("TextLabel")
	subLabel.Name = "SubText"
	subLabel.BackgroundTransparency = 1
	subLabel.Position = UDim2.new(0, 66, 0.55, 0)
	subLabel.Size = UDim2.new(1, -66 - rightInset, 0.45, 0)
	subLabel.Font = Theme.Font.BodyLight
	subLabel.TextColor3 = Theme.Color.TextMuted
	subLabel.TextScaled = true
	subLabel.TextWrapped = true
	subLabel.TextXAlignment = Enum.TextXAlignment.Left
	subLabel.Text = props.subText or ""
	subLabel.Parent = frame

	return {
		frame = frame,
		iconSlot = iconSlot,
		nameLabel = nameLabel,
		subLabel = subLabel,
		actionButton = actionButton,
	}
end

return ItemCard
