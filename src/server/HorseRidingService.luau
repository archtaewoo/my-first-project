--!strict
-- 말 타기 서버 로직. 맵 오브젝트는 옮기거나 지우지 않고, 말 모델 안에 충돌체/좌석/프롬프트만 추가한다.
local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HorseConfig = require(ReplicatedStorage:WaitForChild("HorseConfig"))
local HorseRig = require(ReplicatedStorage:WaitForChild("HorseRig"))

type State = {
	horse: Model,
	spec: HorseConfig.RigSpec,
	root: BasePart,
	collider: Part,
	driverSeat: VehicleSeat,
	passengerSeat: Seat?,
	prompt: ProximityPrompt,
	linearVelocity: LinearVelocity,
	align: AlignOrientation,
	parts: { BasePart },
	homeRoot: CFrame,
	occupants: { [BasePart]: Humanoid },
	active: boolean,
	driver: Player?,
	busy: boolean,
	lastValid: CFrame,
	lastCheckPos: Vector3,
	lastCheckTime: number,
	strikes: number,
	parkedAt: number,
}

local Service = {}

local states: { [Model]: State } = {}
local stateBySeat: { [BasePart]: State } = {}
local riderGroups: { [BasePart]: string } = {}
local started = false

local function characterList(): { Instance }
	local list: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	return list
end

local function excludeFor(state: State): { Instance }
	local list = characterList()
	table.insert(list, state.horse)
	return list
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
end

-- 관절로 루트에 이어지지 않은 파트(초코의 안장/고삐 등)를 가장 가까운 연결 파트에 붙인다.
local function weldLooseParts(horse: Model, root: BasePart)
	local connected: { [BasePart]: boolean } = { [root] = true }
	local queue: { BasePart } = { root }
	while #queue > 0 do
		local part = table.remove(queue) :: BasePart
		for _, joint in part:GetJoints() do
			local a: BasePart?, b: BasePart? = nil, nil
			if joint:IsA("JointInstance") then
				a, b = joint.Part0, joint.Part1
			elseif joint:IsA("WeldConstraint") then
				a, b = joint.Part0, joint.Part1
			end
			for _, other in { a, b } do
				if other and not connected[other] and other:IsDescendantOf(horse) then
					connected[other] = true
					table.insert(queue, other)
				end
			end
		end
	end
	for _, d in horse:GetDescendants() do
		if d:IsA("BasePart") and not connected[d] then
			local best: BasePart = root
			local bestDist = math.huge
			for p in connected do
				local dist = (p.Position - d.Position).Magnitude
				if dist < bestDist then
					best, bestDist = p, dist
				end
			end
			weld(d, best)
		end
	end
end

-- 스킨드 말에는 소리가 없어 초코의 Sound를 복제한다(맵에 이미 있는 에셋 ID만 사용).
local function ensureSounds(root: BasePart)
	if root:FindFirstChild("Trot") then
		return
	end
	for _, other in CollectionService:GetTagged(HorseConfig.TAG) do
		if other:IsA("Model") and other:GetAttribute("Kind") == "Rigged" then
			local templateRoot = HorseRig.getRoot(other)
			if templateRoot then
				for _, name in HorseConfig.SoundNames do
					local template = templateRoot:FindFirstChild(name)
					if template and template:IsA("Sound") then
						template:Clone().Parent = root
					end
				end
				return
			end
		end
	end
end

local function playSound(state: State, name: string)
	local sound = state.root:FindFirstChild(name)
	if sound and sound:IsA("Sound") then
		sound:Play()
	end
end

local function setupCollisionGroups()
	for _, name in { HorseConfig.CollisionGroupHorse, HorseConfig.CollisionGroupRider } do
		if not PhysicsService:IsCollisionGroupRegistered(name) then
			PhysicsService:RegisterCollisionGroup(name)
		end
	end
	local rider = HorseConfig.CollisionGroupRider
	PhysicsService:CollisionGroupSetCollidable(rider, "Default", false)
	PhysicsService:CollisionGroupSetCollidable(rider, HorseConfig.CollisionGroupHorse, false)
	PhysicsService:CollisionGroupSetCollidable(rider, rider, false)
end

local function setRiderCollision(character: Instance, riding: boolean)
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			if riding then
				if riderGroups[d] == nil then
					riderGroups[d] = d.CollisionGroup
				end
				d.CollisionGroup = HorseConfig.CollisionGroupRider
			elseif riderGroups[d] ~= nil then
				d.CollisionGroup = riderGroups[d]
				riderGroups[d] = nil
			end
		end
	end
end

-- 루트만 고정한다. 나머지는 관절로 매달려 있어야 Motor6D 애니메이션이 서 있을 때도 보인다.
-- (forest.rbxl의 Motor6D C0/C1이 현재 파트 위치와 오차 0으로 일치함을 확인함)
local function setAnchored(state: State, anchored: boolean)
	for _, part in state.parts do
		part.Anchored = anchored and part == state.root
	end
end

-- 루트가 target 프레임에 오도록 모델 전체를 옮긴다
local function moveFrameTo(state: State, targetFrame: CFrame)
	local targetRoot = targetFrame * state.spec.frameOffset:Inverse()
	local delta = targetRoot * state.root.CFrame:Inverse()
	state.horse:PivotTo(delta * state.horse:GetPivot())
end

local function uprightFrameAtGround(state: State): CFrame
	local frame = HorseRig.getFrame(state.horse) :: CFrame
	local look = HorseRig.flatLook(frame)
	local pos = frame.Position
	local hit = workspace:Raycast(pos + Vector3.new(0, 4, 0), Vector3.new(0, -24, 0), HorseRig.groundParams(excludeFor(state), true))
	local ground = Vector3.new(pos.X, if hit then hit.Position.Y else pos.Y, pos.Z)
	return CFrame.lookAt(ground, ground + look)
end

local function refreshPrompt(state: State)
	local prompt = state.prompt
	prompt.ObjectText = tostring(state.horse:GetAttribute("HorseName") or "말")
	if state.busy then
		prompt.Enabled = false
	elseif state.driverSeat.Occupant == nil then
		prompt.ActionText = "타기"
		prompt.Enabled = true
	elseif state.passengerSeat and state.passengerSeat.Occupant == nil then
		prompt.ActionText = "뒤에 타기"
		prompt.Enabled = true
	else
		prompt.Enabled = false
	end
end

local function activate(state: State, player: Player)
	state.active = true
	state.driver = player
	state.strikes = 0
	setAnchored(state, false)
	local mass = state.collider.AssemblyMass
	state.linearVelocity.MaxAxesForce = Vector3.new(mass * 150, mass * (workspace.Gravity + 300), mass * 150)
	state.linearVelocity.VectorVelocity = Vector3.zero
	state.align.CFrame = uprightFrameAtGround(state).Rotation
	state.linearVelocity.Enabled = true
	state.align.Enabled = true
	local ok, err = pcall(function()
		state.collider:SetNetworkOwner(player)
	end)
	if not ok then
		warn("[HorseRiding] SetNetworkOwner 실패:", err)
	end
	state.lastValid = state.root.CFrame
	state.lastCheckPos = state.collider.Position
	state.lastCheckTime = os.clock()
	state.horse:SetAttribute("Ridden", true)
	state.horse:SetAttribute("DriverUserId", player.UserId)
end

local function park(state: State)
	if not state.active then
		return
	end
	state.active = false
	state.driver = nil
	state.linearVelocity.Enabled = false
	state.align.Enabled = false
	pcall(function()
		state.collider:SetNetworkOwner(nil)
	end)
	state.collider.AssemblyLinearVelocity = Vector3.zero
	state.collider.AssemblyAngularVelocity = Vector3.zero
	moveFrameTo(state, uprightFrameAtGround(state))
	setAnchored(state, true)
	state.parkedAt = os.clock()
	state.horse:SetAttribute("Ridden", false)
	state.horse:SetAttribute("DriverUserId", nil)
end

local function onOccupantChanged(state: State, seat: VehicleSeat | Seat)
	local previous = state.occupants[seat]
	local current = seat.Occupant
	if previous == current then
		return
	end
	if previous and previous.Parent then
		setRiderCollision(previous.Parent, false)
	end
	state.occupants[seat] = current :: any
	if current and current.Parent then
		setRiderCollision(current.Parent, true)
	end
	if seat == state.driverSeat then
		if current then
			local player = Players:GetPlayerFromCharacter(current.Parent)
			if player then
				activate(state, player)
			end
		else
			park(state)
		end
	end
	refreshPrompt(state)
end

local function findExit(state: State): CFrame
	local frame = HorseRig.getFrame(state.horse) :: CFrame
	local params = HorseRig.groundParams(excludeFor(state), false)
	local look = HorseRig.flatLook(frame)
	local up = Vector3.new(0, 3.5, 0)
	for _, offset in { Vector3.new(-3.8, 0, 0), Vector3.new(3.8, 0, 0), Vector3.new(0, 0, 6), Vector3.new(0, 0, -7) } do
		local point = (frame * CFrame.new(offset)).Position
		local from = frame.Position + up
		if not workspace:Raycast(from, (point + up) - from, params) then
			local hit = workspace:Raycast(point + Vector3.new(0, 5, 0), Vector3.new(0, -20, 0), params)
			if hit and hit.Material ~= Enum.Material.Water then
				local stand = hit.Position + Vector3.new(0, 3, 0)
				return CFrame.lookAt(stand, stand + look)
			end
		end
	end
	return frame + Vector3.new(0, 9, 0)
end

local function eject(state: State, humanoid: Humanoid)
	local seat = humanoid.SeatPart
	local character = humanoid.Parent
	local exit = findExit(state)
	if seat then
		local seatWeld = seat:FindFirstChild("SeatWeld")
		if seatWeld then
			seatWeld:Destroy()
		end
	end
	humanoid.Sit = false
	if character and character:IsA("Model") then
		character:PivotTo(exit)
	end
end

function Service.returnHome(state: State)
	if state.busy then
		return
	end
	state.busy = true
	refreshPrompt(state)
	for seat, humanoid in state.occupants do
		if seat.Parent and humanoid.SeatPart == seat then
			eject(state, humanoid)
		end
	end
	-- 좌석 Occupant 갱신을 기다린다(갱신되면 park가 불린다)
	local deadline = os.clock() + 2
	while (state.driverSeat.Occupant or (state.passengerSeat and state.passengerSeat.Occupant)) and os.clock() < deadline do
		task.wait()
	end
	park(state)
	local delta = state.homeRoot * state.root.CFrame:Inverse()
	state.horse:PivotTo(delta * state.horse:GetPivot())
	setAnchored(state, true)
	state.parkedAt = os.clock()
	state.busy = false
	refreshPrompt(state)
end

local function resetToLastValid(state: State)
	state.strikes = 0
	pcall(function()
		state.collider:SetNetworkOwner(nil)
	end)
	state.collider.AssemblyLinearVelocity = Vector3.zero
	state.collider.AssemblyAngularVelocity = Vector3.zero
	local delta = state.lastValid * state.root.CFrame:Inverse()
	state.horse:PivotTo(delta * state.horse:GetPivot())
	state.lastCheckPos = state.collider.Position
	state.lastCheckTime = os.clock()
	task.delay(0.5, function()
		local driver = state.driver
		if state.active and driver then
			pcall(function()
				state.collider:SetNetworkOwner(driver)
			end)
		end
	end)
end

local function validate(state: State)
	local now = os.clock()
	local pos = state.collider.Position
	local dt = math.max(now - state.lastCheckTime, 1e-3)
	local horizontal = Vector2.new(pos.X - state.lastCheckPos.X, pos.Z - state.lastCheckPos.Z).Magnitude / dt
	local v = HorseConfig.Validation
	local bad = horizontal > HorseConfig.Speed.Gallop * v.SpeedTolerance + v.ExtraSpeed
		or HorseRig.distanceFromBasinCenter(pos) > HorseConfig.WALK_RADIUS + v.BoundarySlack
		or pos.Y < workspace.FallenPartsDestroyHeight + 50
	state.lastCheckPos = pos
	state.lastCheckTime = now
	if bad then
		state.strikes += 1
		if state.strikes >= v.StrikesBeforeReset then
			warn(("[HorseRiding] %s 위치/속도 검증 실패 → 마지막 정상 위치로 되돌림"):format(state.horse.Name))
			resetToLastValid(state)
		end
	else
		state.strikes = 0
		state.lastValid = state.root.CFrame
	end
end

local function makeSeat(className: "VehicleSeat" | "Seat", name: string, cf: CFrame, role: string, collider: BasePart, horse: Model): BasePart
	local seat = Instance.new(className) :: any
	seat.Name = name
	seat.Size = Vector3.new(1.6, 0.4, 1.6)
	seat.CFrame = cf
	seat.Transparency = 1
	seat.CanCollide = false
	seat.CanTouch = false -- 걸어가다 닿아서 앉는 것 방지. Sit()은 그대로 동작
	seat.CanQuery = false
	seat.Massless = true
	seat.Anchored = true
	seat.CastShadow = false
	if className == "VehicleSeat" then
		seat.HeadsUpDisplay = false
		seat.MaxSpeed = 0
		seat.Torque = 0
		seat.TurnSpeed = 0
	end
	seat:SetAttribute(HorseConfig.SEAT_ATTRIBUTE, role)
	seat.Parent = horse
	weld(seat, collider)
	return seat
end

local function setup(horse: Instance)
	if not horse:IsA("Model") or states[horse] then
		return
	end
	local spec = HorseRig.getSpec(horse)
	local root = HorseRig.getRoot(horse)
	if not spec or not root then
		warn("[HorseRiding] Kind/루트 파트를 찾지 못함:", horse:GetFullName())
		return
	end

	horse.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	if not horse.PrimaryPart then
		horse.PrimaryPart = root
	end
	weldLooseParts(horse, root)
	ensureSounds(root)

	local frame = root.CFrame * spec.frameOffset
	local collider = Instance.new("Part")
	collider.Name = "HorseCollider"
	collider.Size = spec.colliderSize
	collider.CFrame = frame * CFrame.new(spec.colliderCenter)
	collider.Transparency = 1
	collider.CanCollide = true
	collider.CanQuery = false
	collider.CanTouch = false
	collider.CastShadow = false
	collider.Anchored = true
	collider.RootPriority = 20
	collider.CustomPhysicalProperties = PhysicalProperties.new(1, 0.1, 0, 1, 1)
	collider.CollisionGroup = HorseConfig.CollisionGroupHorse
	collider.Parent = horse
	weld(collider, root)

	local attachment = Instance.new("Attachment")
	attachment.Name = "HorseDriveAttachment"
	attachment.Parent = collider

	local linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.Name = "HorseDrive"
	linearVelocity.Attachment0 = attachment
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	linearVelocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	linearVelocity.Enabled = false
	linearVelocity.Parent = collider

	local align = Instance.new("AlignOrientation")
	align.Name = "HorseAlign"
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.MaxTorque = math.huge
	align.Responsiveness = 25
	align.Enabled = false
	align.Parent = collider

	local driverSeat = makeSeat("VehicleSeat", "HorseSeatFront", frame * CFrame.new(spec.driverSeat), "Driver", collider, horse) :: VehicleSeat
	local passengerSeat: Seat? = nil
	if spec.passengerSeat then
		passengerSeat = makeSeat("Seat", "HorseSeatBack", frame * CFrame.new(spec.passengerSeat), "Passenger", collider, horse) :: Seat
	end

	local promptAttachment = Instance.new("Attachment")
	promptAttachment.Name = "RidePromptAttachment"
	promptAttachment.Position = spec.driverSeat - spec.colliderCenter + Vector3.new(0, 0.8, 0)
	promptAttachment.Parent = collider
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RidePrompt"
	prompt.ActionText = "타기"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.UIOffset = Vector2.new(0, -40)
	prompt.Parent = promptAttachment

	local parts: { BasePart } = {}
	for _, d in horse:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			if d ~= collider then
				d.Massless = true
			end
		end
	end

	local state: State = {
		horse = horse,
		spec = spec,
		root = root,
		collider = collider,
		driverSeat = driverSeat,
		passengerSeat = passengerSeat,
		prompt = prompt,
		linearVelocity = linearVelocity,
		align = align,
		parts = parts,
		homeRoot = root.CFrame,
		occupants = {},
		active = false,
		driver = nil,
		busy = false,
		lastValid = root.CFrame,
		lastCheckPos = collider.Position,
		lastCheckTime = os.clock(),
		strikes = 0,
		parkedAt = os.clock(),
	}
	states[horse] = state
	stateBySeat[driverSeat] = state
	driverSeat:GetPropertyChangedSignal("Occupant"):Connect(function()
		onOccupantChanged(state, driverSeat)
	end)
	if passengerSeat then
		stateBySeat[passengerSeat] = state
		passengerSeat:GetPropertyChangedSignal("Occupant"):Connect(function()
			onOccupantChanged(state, passengerSeat)
		end)
	end
	prompt.Triggered:Connect(function(player)
		Service.mount(player, horse)
	end)
	horse:GetAttributeChangedSignal("HorseName"):Connect(function()
		refreshPrompt(state)
	end)
	setAnchored(state, true)
	horse:SetAttribute("Ridden", false)
	refreshPrompt(state)
end

function Service.mount(player: Player, horse: Model): (boolean, string?)
	local state = states[horse]
	if not state then
		return false, "not a horse"
	end
	if state.busy then
		return false, "busy"
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not hrp or not hrp:IsA("BasePart") then
		return false, "no character"
	end
	if humanoid.SeatPart then
		return false, "already seated"
	end
	if (hrp.Position - state.collider.Position).Magnitude > 16 then
		return false, "too far"
	end
	if state.driverSeat.Occupant == nil then
		state.driverSeat:Sit(humanoid)
		playSound(state, "Mount")
		return true, "driver"
	end
	local passengerSeat = state.passengerSeat
	if passengerSeat and passengerSeat.Occupant == nil then
		passengerSeat:Sit(humanoid)
		return true, "passenger"
	end
	return false, "full"
end

function Service.dismount(player: Player, sendHome: boolean)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	local state = seat and stateBySeat[seat]
	if not humanoid or not seat or not state then
		return
	end
	local wasDriver = seat == state.driverSeat
	eject(state, humanoid)
	if sendHome and wasDriver then
		task.spawn(Service.returnHome, state)
	end
end

function Service.getState(horse: Model): State?
	return states[horse]
end

function Service.getStates(): { [Model]: State }
	return states
end

function Service.start()
	if started then
		return
	end
	started = true
	setupCollisionGroups()

	local remote = ReplicatedStorage:FindFirstChild(HorseConfig.REMOTE_NAME)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = HorseConfig.REMOTE_NAME
		remote.Parent = ReplicatedStorage
	end
	(remote :: RemoteEvent).OnServerEvent:Connect(function(player: Player, action: unknown, sendHome: unknown)
		if action == "Dismount" then
			Service.dismount(player, sendHome == true)
		end
	end)

	for _, horse in CollectionService:GetTagged(HorseConfig.TAG) do
		task.spawn(setup, horse)
	end
	CollectionService:GetInstanceAddedSignal(HorseConfig.TAG):Connect(function(horse)
		task.spawn(setup, horse)
	end)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < HorseConfig.Validation.Interval then
			return
		end
		accumulator = 0
		for _, state in states do
			if state.active and state.driver then
				validate(state)
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(5)
			local limit = HorseConfig.AutoReturnSeconds
			if limit then
				for _, state in states do
					local away = (state.root.Position - state.homeRoot.Position).Magnitude > 3
					if away and not state.active and not state.busy and next(state.occupants) == nil and os.clock() - state.parkedAt > limit then
						task.spawn(Service.returnHome, state)
					end
				end
			end
		end
	end)
end

return Service
