--!strict
-- 리본/배너 모양 창 제목. 가운데 판 양옆에 살짝 기울어진 "날개"를 붙여 리본처럼 보이게 하고,
-- 패널 윗변에 살짝 걸치도록(Y가 음수) 배치해서 "창 위에 얹힌 명패" 느낌을 낸다.
-- 글씨 테두리는 UIStroke가 아니라 TextLabel의 TextStroke 속성으로 넣는다 (UIStroke는
-- 인스턴스 테두리만 그리고, 글자 윤곽선은 그리지 않는다).

local Theme = require(script.Parent.Parent:WaitForChild("Theme"))

local BannerHeader = {}

export type BannerHeaderProps = {
	parent: Instance,
	text: string,
}

function BannerHeader.new(props: BannerHeaderProps): TextLabel
	local banner = Instance.new("Frame")
	banner.Name = "Banner"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, -16)
	banner.Size = UDim2.new(0.7, 0, 0, 52)
	banner.BackgroundColor3 = Theme.Color.AccentWarm
	banner.BorderSizePixel = 0
	banner.ZIndex = 4
	banner.Parent = props.parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = banner

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Color.Border
	stroke.Thickness = Theme.Stroke.Panel
	stroke.Parent = banner

	local function makeWing(onRight: boolean)
		local wing = Instance.new("Frame")
		wing.Name = if onRight then "WingRight" else "WingLeft"
		wing.AnchorPoint = Vector2.new(if onRight then 0 else 1, 0.5)
		wing.Position = UDim2.new(if onRight then 1 else 0, 0, 0.5, 0)
		wing.Size = UDim2.new(0, 20, 0, 36)
		wing.Rotation = if onRight then 12 else -12
		wing.BackgroundColor3 = Theme.Color.AccentWarm
		wing.BorderSizePixel = 0
		wing.ZIndex = 3
		wing.Parent = banner

		local wingCorner = Instance.new("UICorner")
		wingCorner.CornerRadius = UDim.new(0, 4)
		wingCorner.Parent = wing

		local wingStroke = Instance.new("UIStroke")
		wingStroke.Color = Theme.Color.Border
		wingStroke.Thickness = Theme.Stroke.Card
		wingStroke.Parent = wing
	end
	makeWing(false)
	makeWing(true)

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -20, 1, -10)
	title.Position = UDim2.new(0, 10, 0, 5)
	title.Font = Theme.Font.Title
	title.TextColor3 = Theme.Color.Text
	title.TextStrokeColor3 = Theme.Color.Border
	title.TextStrokeTransparency = 0
	title.TextScaled = true
	title.Text = props.text
	title.ZIndex = 5
	title.Parent = banner

	return title
end

return BannerHeader
