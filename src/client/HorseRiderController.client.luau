--!strict
-- 말 조작(운전자)과 탑승 HUD. 운전자 클라이언트가 말의 네트워크 소유자라서 여기서 물리 목표값을 정한다.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HorseConfig = require(ReplicatedStorage:WaitForChild("HorseConfig"))
local HorseRig = require(ReplicatedStorage:WaitForChild("HorseRig"))
local remote = ReplicatedStorage:WaitForChild(HorseConfig.REMOTE_NAME) :: RemoteEvent

local player = Players.LocalPlayer
local Speed = HorseConfig.Speed

local COLORS = {
	panel = Color3.fromRGB(44, 34, 28),
	stroke = Color3.fromRGB(196, 160, 110),
	text = Color3.fromRGB(246, 236, 214),
	button = Color3.fromRGB(110, 90, 70),
	active = Color3.fromRGB(96, 122, 84),
	danger = Color3.fromRGB(150, 60, 50),
}

type Ride = {
	horse: Model,
	seat: BasePart,
	humanoid: Humanoid,
	driver: boolean,
	connections: { RBXScriptConnection },
	gui: ScreenGui,
	gaitLabel: TextLabel,
	gallopButton: TextButton?,
	walkButton: TextButton?,
	rideTrack: AnimationTrack?,
	speed: number,
	yaw: number,
	pitch: number,
	gallop: boolean,
	walk: boolean,
	jumpQueued: boolean,
	vy: number,
	airborne: boolean,
	jumpCooldown: number,
	debugStart: number?,
	stuckTime: number,
}

local ride: Ride? = nil

local function moveToward(current: number, target: number, maxDelta: number): number
	if math.abs(target - current) <= maxDelta then
		return target
	end
	return current + math.sign(target - current) * maxDelta
end

local function gaitName(speed: number): string
	local s = math.abs(speed)
	local t = HorseConfig.GaitThreshold
	if s < t.Walk then
		return "서 있음"
	elseif speed < 0 then
		return "뒤로"
	elseif s < t.Trot then
		return "걷기"
	elseif s < t.Gallop then
		return "속보"
	end
	return "질주"
end

local function refreshToggles(r: Ride)
	if r.gallopButton then
		r.gallopButton.BackgroundColor3 = if r.gallop then COLORS.active else COLORS.button
	end
	if r.walkButton then
		r.walkButton.BackgroundColor3 = if r.walk then COLORS.active else COLORS.button
	end
end

local function makeButton(parent: Instance, text: string, color: Color3, order: number, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(96, 48)
	b.BackgroundColor3 = color
	b.Text = text
	b.Font = Enum.Font.GothamBold
	b.TextSize = 16
	b.TextColor3 = COLORS.text
	b.LayoutOrder = order
	b.AutoButtonColor = true
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = b
	b.Activated:Connect(onClick)
	b.Parent = parent
	return b
end

local function buildHud(r: Ride)
	local gui = Instance.new("ScreenGui")
	gui.Name = "HorseRideHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	r.gui = gui

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -16)
	panel.Size = UDim2.fromOffset(0, 0)
	panel.AutomaticSize = Enum.AutomaticSize.XY
	panel.BackgroundColor3 = COLORS.panel
	panel.BackgroundTransparency = 0.1
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = COLORS.stroke
	stroke.Thickness = 2
	stroke.Parent = panel
	local padding = Instance.new("UIPadding")
	for _, side in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
		(padding :: any)[side] = UDim.new(0, 10)
	end
	padding.Parent = panel
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = panel

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromOffset(0, 24)
	title.AutomaticSize = Enum.AutomaticSize.X
	title.Font = Enum.Font.GothamBold
	title.TextSize = 18
	title.TextColor3 = COLORS.text
	title.LayoutOrder = 1
	local name = tostring(r.horse:GetAttribute("HorseName") or "말")
	title.Text = if r.driver then name .. " · 서 있음" else name .. " · 뒷자리"
	title.Parent = panel
	r.gaitLabel = title

	local hint = Instance.new("TextLabel")
	hint.BackgroundTransparency = 1
	hint.Size = UDim2.fromOffset(0, 18)
	hint.AutomaticSize = Enum.AutomaticSize.X
	hint.Font = Enum.Font.Gotham
	hint.TextSize = 13
	hint.TextColor3 = COLORS.text
	hint.TextTransparency = 0.25
	hint.LayoutOrder = 2
	hint.Text = if r.driver
		then "W/S 이동 · A/D 회전 · Shift 질주 · Ctrl 걷기 · Space 점프 · X 내리기 · Z 마구간으로"
		else "X 내리기"
	hint.Parent = panel

	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromOffset(0, 48)
	row.AutomaticSize = Enum.AutomaticSize.X
	row.LayoutOrder = 3
	row.Parent = panel
	local rowList = Instance.new("UIListLayout")
	rowList.FillDirection = Enum.FillDirection.Horizontal
	rowList.Padding = UDim.new(0, 8)
	rowList.SortOrder = Enum.SortOrder.LayoutOrder
	rowList.Parent = row

	if r.driver then
		r.gallopButton = makeButton(row, "질주", COLORS.button, 1, function()
			r.gallop = not r.gallop
			refreshToggles(r)
		end)
		r.walkButton = makeButton(row, "걷기", COLORS.button, 2, function()
			r.walk = not r.walk
			refreshToggles(r)
		end)
	end
	makeButton(row, "내리기", COLORS.danger, 3, function()
		remote:FireServer("Dismount", false)
	end)
	if r.driver then
		makeButton(row, "마구간으로", COLORS.button, 4, function()
			remote:FireServer("Dismount", true)
		end)
	end
	gui.Parent = player:WaitForChild("PlayerGui")
end

local function characterList(): { Instance }
	local list: { Instance } = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	return list
end

local function step(r: Ride, dt: number)
	local spec = HorseRig.getSpec(r.horse)
	local root = HorseRig.getRoot(r.horse)
	local collider = r.horse:FindFirstChild("HorseCollider")
	if not spec or not root or not collider or not collider:IsA("BasePart") or root.Anchored then
		return
	end
	local linearVelocity = collider:FindFirstChild("HorseDrive")
	local align = collider:FindFirstChild("HorseAlign")
	if not linearVelocity or not linearVelocity:IsA("LinearVelocity") or not align or not align:IsA("AlignOrientation") then
		return
	end
	local seat = r.seat :: VehicleSeat
	local throttle, steer = seat.ThrottleFloat, seat.SteerFloat
	local frame = root.CFrame * spec.frameOffset
	local exclude = characterList()
	table.insert(exclude, r.horse)

	local target = 0
	if throttle > 0.05 then
		if r.gallop then
			target = Speed.Gallop
		elseif r.walk or throttle < 0.6 then
			target = Speed.Walk
		else
			target = Speed.Trot
		end
	elseif throttle < -0.05 then
		target = -Speed.Reverse
	end

	local forward = Vector3.new(-math.sin(r.yaw), 0, -math.cos(r.yaw))
	if target ~= 0 then
		local direction = if target > 0 then forward else -forward
		local blocked, slow = HorseRig.probe(frame.Position, direction, 4.5 + math.abs(r.speed) * 0.3, exclude)
		if blocked then
			target = 0
		elseif slow then
			target *= Speed.ShallowWaterFactor
		end
	end

	-- 벽이나 나무에 막혀 실제로 못 가고 있으면 속도를 실제 값으로 낮춘다
	local velocity = collider.AssemblyLinearVelocity
	local actual = velocity:Dot(forward)
	if math.abs(r.speed) > 3 and math.abs(actual) < math.abs(r.speed) * 0.35 then
		r.stuckTime += dt
	else
		r.stuckTime = 0
	end
	if r.stuckTime > 0.3 then
		r.speed = actual
		r.stuckTime = 0
	end

	local speeding = math.abs(target) > math.abs(r.speed) and target * r.speed >= 0
	r.speed = moveToward(r.speed, target, (if speeding then Speed.Accel else Speed.Brake) * dt)

	local t = math.clamp(math.abs(r.speed) / Speed.Gallop, 0, 1)
	local turnRate = HorseConfig.TurnRateStand + (HorseConfig.TurnRateGallop - HorseConfig.TurnRateStand) * t
	r.yaw -= steer * turnRate * dt

	local groundParams = HorseRig.groundParams(exclude, true)
	local down = Vector3.new(0, -(spec.colliderCenter.Y + 6), 0)
	local function groundAt(offsetZ: number): number?
		local origin = (frame * CFrame.new(0, spec.colliderCenter.Y, offsetZ)).Position
		local hit = workspace:Raycast(origin, down, groundParams)
		return if hit then hit.Position.Y else nil
	end
	local centerY, frontY, backY = groundAt(0), groundAt(-2.8), groundAt(2.8)

	-- 수직 속도는 측정값이 아니라 컨트롤러 상태 r.vy로 적분한다(측정값은 물리가 따라오기 전이라 늦다).
	-- 상승 중(r.vy > 0)에는 접지 판정을 하지 않는다.
	local originY = frame.Position.Y
	local grounded = r.vy <= 0 and centerY ~= nil and originY - centerY <= HorseConfig.GroundSnap
	r.jumpCooldown = math.max(r.jumpCooldown - dt, 0)
	local vy: number
	local forceVertical = false -- 불연속(도약/착지)에서는 힘 제한 때문에 늦지 않게 속도를 직접 넣는다
	if grounded and r.jumpQueued and r.jumpCooldown <= 0 then
		r.vy = HorseConfig.JumpVelocity
		r.jumpCooldown = HorseConfig.JumpCooldown
		grounded = false
		vy = r.vy
		forceVertical = true
		if HorseConfig.Debug then
			r.debugStart = os.clock()
		end
	elseif grounded and centerY then
		if r.airborne then
			forceVertical = true -- 착지 프레임: 남은 낙하 속도를 없앤다
		end
		r.vy = 0
		vy = math.clamp((centerY - originY) * 12, -30, 40)
	else
		r.vy = math.max(r.vy - workspace.Gravity * dt, -150)
		vy = r.vy
		if centerY and r.vy < 0 and originY + r.vy * dt < centerY then
			vy = (centerY - originY) / dt -- 다음 프레임에 지면 아래로 내려가지 않게 제한
			forceVertical = true
		end
	end
	r.airborne = not grounded
	r.jumpQueued = false

	local maxPitch = math.rad(HorseConfig.MaxPitchDeg)
	local targetPitch = 0
	if grounded and frontY and backY then
		targetPitch = math.clamp(math.atan2(frontY - backY, 5.6), -maxPitch, maxPitch)
	end
	r.pitch += (targetPitch - r.pitch) * math.min(1, dt * 6)

	local horizontal = forward * r.speed
	local pos = frame.Position
	local fromCenter = Vector3.new(pos.X - HorseConfig.BASIN_CENTER.X, 0, pos.Z - HorseConfig.BASIN_CENTER.Y)
	if fromCenter.Magnitude > HorseConfig.WALK_RADIUS then
		horizontal = -fromCenter.Unit * 8
	end

	local mass = collider.AssemblyMass
	linearVelocity.MaxAxesForce = Vector3.new(mass * 150, mass * (workspace.Gravity + 300), mass * 150)
	linearVelocity.VectorVelocity = horizontal + Vector3.new(0, vy, 0)
	if forceVertical then
		-- horizontal은 이번 프레임 목표 속도다. 여기서 예전 velocity.X/Z를 쓰면 도약/착지 순간
		-- 수평 속도가 지난 프레임 값으로 되돌아가 버린다.
		collider.AssemblyLinearVelocity = horizontal + Vector3.new(0, vy, 0)
	end
	align.CFrame = CFrame.Angles(0, r.yaw, 0) * CFrame.Angles(r.pitch, 0, 0)

	local debugStart = r.debugStart
	if debugStart then
		local elapsed = os.clock() - debugStart
		if elapsed > 1 then
			r.debugStart = nil
		else
			print(("[HorseJump] t=%.3f r.vy=%.2f 측정vy=%.2f 명령vy=%.2f originY=%.2f groundY=%s grounded=%s"):format(
				elapsed, r.vy, velocity.Y, vy, originY, if centerY then ("%.2f"):format(centerY) else "nil", tostring(grounded)
			))
		end
	end

	local name = tostring(r.horse:GetAttribute("HorseName") or "말")
	r.gaitLabel.Text = name .. " · " .. gaitName(r.speed)
end

local function stopRide()
	local r = ride
	if not r then
		return
	end
	ride = nil
	for _, c in r.connections do
		c:Disconnect()
	end
	for _, action in { "HorseGallop", "HorseWalk", "HorseDismount", "HorseSendHome" } do
		ContextActionService:UnbindAction(action)
	end
	if r.rideTrack then
		r.rideTrack:Stop()
	end
	r.gui:Destroy()
	r.humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
end

local function startRide(humanoid: Humanoid, seat: BasePart, horse: Model)
	local driver = seat:GetAttribute(HorseConfig.SEAT_ATTRIBUTE) == "Driver" and seat:IsA("VehicleSeat")
	local frame = HorseRig.getFrame(horse)
	local look = if frame then HorseRig.flatLook(frame) else Vector3.new(0, 0, -1)
	local r: Ride = {
		horse = horse,
		seat = seat,
		humanoid = humanoid,
		driver = driver,
		connections = {},
		gui = nil :: any,
		gaitLabel = nil :: any,
		gallopButton = nil,
		walkButton = nil,
		rideTrack = nil,
		speed = 0,
		yaw = math.atan2(-look.X, -look.Z),
		pitch = 0,
		gallop = false,
		walk = false,
		jumpQueued = false,
		vy = 0,
		airborne = false,
		jumpCooldown = 0,
		debugStart = nil,
		stuckTime = 0,
	}
	ride = r
	buildHud(r)

	-- 앉아 있는 동안 점프 상태를 막아 Space가 하차 대신 말 점프가 되게 한다
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	table.insert(r.connections, humanoid:GetPropertyChangedSignal("Jump"):Connect(function()
		if humanoid.Jump and r.driver then
			r.jumpQueued = true
		end
	end))

	local animationId = HorseConfig.RideAnimationId
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animationId and animator then
		local animation = Instance.new("Animation")
		animation.AnimationId = animationId
		local track = animator:LoadAnimation(animation)
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = true
		track:Play()
		r.rideTrack = track
	end

	local high = Enum.ContextActionPriority.High.Value
	ContextActionService:BindActionAtPriority("HorseDismount", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			remote:FireServer("Dismount", false)
		end
		return Enum.ContextActionResult.Sink
	end, false, high, Enum.KeyCode.X, Enum.KeyCode.ButtonB)

	if driver then
		ContextActionService:BindActionAtPriority("HorseGallop", function(_, inputState)
			r.gallop = inputState == Enum.UserInputState.Begin
			refreshToggles(r)
			return Enum.ContextActionResult.Sink
		end, false, high, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonL3, Enum.KeyCode.ButtonR2)
		ContextActionService:BindActionAtPriority("HorseWalk", function(_, inputState)
			if inputState == Enum.UserInputState.Begin then
				r.walk = not r.walk
				refreshToggles(r)
			end
			return Enum.ContextActionResult.Sink
		end, false, high, Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonL1)
		ContextActionService:BindActionAtPriority("HorseSendHome", function(_, inputState)
			if inputState == Enum.UserInputState.Begin then
				remote:FireServer("Dismount", true)
			end
			return Enum.ContextActionResult.Sink
		end, false, high, Enum.KeyCode.Z)
		table.insert(r.connections, RunService.PreSimulation:Connect(function(dt)
			step(r, dt)
		end))
	end
end

local function onCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Seated:Connect(function(active: boolean, seatPart: BasePart?)
		stopRide()
		if active and seatPart and seatPart:GetAttribute(HorseConfig.SEAT_ATTRIBUTE) then
			local horse = HorseRig.findHorseFromPart(seatPart)
			if horse then
				startRide(humanoid, seatPart, horse)
			end
		end
	end)
	humanoid.Died:Connect(stopRide)
end

player.CharacterAdded:Connect(onCharacter)
player.CharacterRemoving:Connect(stopRide)
if player.Character then
	task.spawn(onCharacter, player.Character)
end
