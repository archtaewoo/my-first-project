--!strict
-- 알약 모양 진행바. 퀘스트 진행도, 말 애정도 등 "n/목표" 류 표시에 쓴다.

local Theme = require(script.Parent.Parent:WaitForChild("Theme"))

local ProgressBar = {}

export type ProgressBarProps = {
	parent: Instance,
	position: UDim2?,
	size: UDim2?,
	fillColor: Color3?,
}

export type Bar = {
	frame: Frame,
	fill: Frame,
	setProgress: (ratio: number) -> (),
}

function ProgressBar.new(props: ProgressBarProps): Bar
	local frame = Instance.new("Frame")
	frame.Name = "ProgressBar"
	frame.Position = props.position or UDim2.new(0, 0, 1, -10)
	frame.Size = props.size or UDim2.new(1, 0, 0, 10)
	frame.BackgroundColor3 = Theme.Color.Panel
	frame.Parent = props.parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Color.Border
	stroke.Thickness = 1.5
	stroke.Parent = frame

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = props.fillColor or Theme.Color.AccentGreen
	fill.BorderSizePixel = 0
	fill.Parent = frame

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill

	local function setProgress(ratio: number)
		local clamped = math.clamp(ratio, 0, 1)
		fill.Size = UDim2.new(clamped, 0, 1, 0)
	end

	return { frame = frame, fill = fill, setProgress = setProgress }
end

return ProgressBar
