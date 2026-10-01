--!strict
-- 창 오른쪽 위 닫기 버튼. 동글동글한 사각 버튼 + X. 모바일 터치를 고려해 40x40 이상으로 둔다.

local Theme = require(script.Parent.Parent:WaitForChild("Theme"))

local CloseButton = {}

export type CloseButtonProps = {
	parent: Instance,
}

function CloseButton.new(props: CloseButtonProps): TextButton
	local button = Instance.new("TextButton")
	button.Name = "CloseButton"
	button.AnchorPoint = Vector2.new(1, 0)
	button.Position = UDim2.new(1, -14, 0, 14)
	button.Size = UDim2.new(0, 42, 0, 42)
	button.BackgroundColor3 = Theme.Color.Panel
	button.AutoButtonColor = true
	button.Font = Theme.Font.Heading
	button.TextColor3 = Theme.Color.Text
	button.TextScaled = true
	button.Text = "X"
	button.ZIndex = 6
	button.Parent = props.parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.Corner.Button
	corner.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Color.Border
	stroke.Thickness = Theme.Stroke.Button
	stroke.Parent = button

	return button
end

return CloseButton
