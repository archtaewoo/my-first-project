--!strict
-- 창 배경 패널 한 벌: 둥근 모서리 + 두꺼운 테두리 패널, 위에 걸친 리본 제목(BannerHeader),
-- 오른쪽 위 닫기 버튼(CloseButton)까지 한 번에 조립해서 내준다.
-- 모든 창(도감/상점/퀘스트 게시판/모닥불/말 꾸미기)이 매번 똑같은 배경+제목+닫기버튼을
-- 손으로 다시 짜지 않고 이것부터 만들고 시작하게 하기 위한 조립 컴포넌트.

local Theme = require(script.Parent.Parent:WaitForChild("Theme"))
local BannerHeader = require(script.Parent:WaitForChild("BannerHeader"))
local CloseButton = require(script.Parent:WaitForChild("CloseButton"))

local PanelFrame = {}

export type PanelFrameProps = {
	parent: Instance, -- ScreenGui
	title: string,
	widthScale: number?,
	heightScale: number?,
	onClose: (() -> ())?,
}

export type Panel = {
	root: Frame, -- 패널 전체(배경+테두리). 창을 통째로 숨기고 싶으면 root.Visible을 쓴다
	body: Frame, -- 리본 제목 아래, 실제 콘텐츠(탭바/목록 등)를 붙이는 빈 영역
	titleLabel: TextLabel,
	closeButton: TextButton,
}

function PanelFrame.new(props: PanelFrameProps): Panel
	local root = Instance.new("Frame")
	root.Name = "Panel"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.new(0.5, 0, 0.5, 0)
	root.Size = UDim2.new(props.widthScale or Theme.Layout.PanelWidthScale, 0, props.heightScale or Theme.Layout.PanelHeightScale, 0)
	root.BackgroundColor3 = Theme.Color.Background
	root.BorderSizePixel = 0
	root.Parent = props.parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.Corner.Panel
	corner.Parent = root

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Color.Border
	stroke.Thickness = Theme.Stroke.Panel
	stroke.Parent = root

	local titleLabel = BannerHeader.new({ parent = root, text = props.title })

	local closeButton = CloseButton.new({ parent = root })
	if props.onClose then
		closeButton.Activated:Connect(props.onClose)
	end

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.new(0, 20, 0, 50)
	body.Size = UDim2.new(1, -40, 1, -70)
	body.Parent = root

	return {
		root = root,
		body = body,
		titleLabel = titleLabel,
		closeButton = closeButton,
	}
end

return PanelFrame
