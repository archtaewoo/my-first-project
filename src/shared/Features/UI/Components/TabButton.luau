--!strict
-- 알약 모양 탭/카테고리 버튼. 선택되면 배경이 주황 포인트색으로 진해진다.

local Theme = require(script.Parent.Parent:WaitForChild("Theme"))

local TabButton = {}

export type TabButtonProps = {
	parent: Instance,
	text: string,
	layoutOrder: number?,
	width: number?,
}

export type Tab = {
	button: TextButton,
	setSelected: (selected: boolean) -> (),
}

function TabButton.new(props: TabButtonProps): Tab
	local button = Instance.new("TextButton")
	button.Name = props.text
	button.LayoutOrder = props.layoutOrder or 0
	button.Size = UDim2.new(0, props.width or math.max(96, Theme.Layout.MinTouchTarget * 2), 1, 0)
	button.BackgroundColor3 = Theme.Color.Panel
	button.AutoButtonColor = true
	button.Font = Theme.Font.Body
	button.TextColor3 = Theme.Color.Text
	button.TextScaled = true
	button.Text = props.text
	button.Parent = props.parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.Corner.Pill
	corner.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Color.Border
	stroke.Thickness = Theme.Stroke.Button
	stroke.Parent = button

	local function setSelected(selected: boolean)
		button.BackgroundColor3 = if selected then Theme.Color.AccentWarm else Theme.Color.Panel
		button.TextColor3 = if selected then Theme.Color.TextOnAccent else Theme.Color.Text
	end

	return { button = button, setSelected = setSelected }
end

return TabButton
