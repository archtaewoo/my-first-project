--!strict
-- 공통 UI 디자인 토큰. 모든 창(도감/상점/퀘스트 게시판/모닥불/말 꾸미기 등)이 제각각 색을
-- 정하지 않고 여기 값만 가져다 쓴다 — 창마다 톤이 조금씩 달라지는 걸 막기 위한 단일 기준.
--
-- 톤: 갈색·크림 나무 톤. 맵 시장 간판에 이미 쓰이고 있는 색감(짙은 나무 테두리, 베이지 글씨,
-- 금빛 포인트)을 UI까지 그대로 확장했다. 보라색 판타지 톤은 쓰지 않는다.

local Theme = {}

Theme.Color = {
	-- 배경/패널 (어두운 나무 -> 밝은 나무 순)
	Background = Color3.fromRGB(45, 32, 22), -- 창 전체 배경
	Panel = Color3.fromRGB(63, 45, 30), -- 탭바/보조 버튼/슬롯 바탕
	PanelLight = Color3.fromRGB(77, 56, 38), -- 카드/셀 바탕
	PanelLightDone = Color3.fromRGB(70, 86, 58), -- 완료/소유 상태 카드(은은한 초록 끼얹음)

	-- 테두리/포인트
	Border = Color3.fromRGB(93, 66, 42), -- 패널·카드 공통 테두리(짙은 나무)
	Accent = Color3.fromRGB(196, 160, 112), -- 포인트(금빛 베이지) - 선택된 탭, 강조 텍스트
	AccentWarm = Color3.fromRGB(214, 140, 74), -- 포인트(주황) - 배너, 선택된 탭 배경
	AccentWarmDark = Color3.fromRGB(168, 104, 54), -- 주황 버튼 테두리
	AccentGreen = Color3.fromRGB(122, 168, 94), -- 긍정 액션(받기/구매/완료) 버튼
	AccentGreenDark = Color3.fromRGB(90, 130, 66), -- 초록 버튼 테두리
	AccentRose = Color3.fromRGB(196, 120, 100), -- 경고/가득 참 표시(펀치력 약하게)

	-- 텍스트
	Text = Color3.fromRGB(248, 238, 220),
	TextMuted = Color3.fromRGB(178, 156, 130),
	TextOnAccent = Color3.fromRGB(45, 32, 22), -- 밝은 버튼 위에 올라가는 글씨(배경색 재사용)

	-- 잠김/비활성
	Locked = Color3.fromRGB(55, 40, 28),
	LockedText = Color3.fromRGB(178, 156, 130),
}

-- 희귀도별 색 (CodexUI 등에서 공용으로 쓴다)
Theme.Rarity = {
	Common = Color3.fromRGB(168, 148, 122),
	Uncommon = Color3.fromRGB(120, 168, 110),
	Rare = Color3.fromRGB(102, 150, 196),
	Legendary = Color3.fromRGB(206, 168, 92),
}

Theme.Corner = {
	Panel = UDim.new(0, 20),
	Card = UDim.new(0, 12),
	Button = UDim.new(0, 10),
	Pill = UDim.new(1, 0), -- 알약 모양(탭 버튼)
	Round = UDim.new(1, 0), -- 완전 동그라미(닫기 버튼, 아이콘 슬롯 등에 선택적으로)
}

Theme.Stroke = {
	Panel = 3,
	Card = 2,
	Button = 2,
}

Theme.Font = {
	Title = Enum.Font.FredokaOne, -- 두껍고 둥글둥글한 글씨 - 리본 배너 제목 전용
	Heading = Enum.Font.GothamBold,
	Body = Enum.Font.GothamMedium,
	BodyLight = Enum.Font.Gotham,
}

-- 모바일에서도 버튼이 너무 작아지지 않도록 하는 최소 기준(픽셀).
-- 터치 대상 권장 최소 크기(약 44px)를 따른다.
Theme.Layout = {
	MinTouchTarget = 44,
	PanelWidthScale = 0.88,
	PanelHeightScale = 0.8,
}

return Theme
