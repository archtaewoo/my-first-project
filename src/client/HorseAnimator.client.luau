--!strict
-- 모든 말의 걸음 애니메이션(Motor6D/Bone Transform)과 발굽 소리. Transform과 로컬 재생은 복제되지 않으므로
-- 각 클라이언트가 말의 실제 속도를 보고 스스로 움직인다.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HorseConfig = require(ReplicatedStorage:WaitForChild("HorseConfig"))
local HorseRig = require(ReplicatedStorage:WaitForChild("HorseRig"))

local ANIMATE_DISTANCE = 220
local SNORT_DISTANCE = 45
local TAU = 2 * math.pi

type Joint = { inst: Motor6D | Bone, lateral: Vector3, up: Vector3 }
type Leg = { upper: Joint?, lower: Joint?, flexSign: number, offset: number }
type Gait = "Idle" | "Walk" | "Trot" | "Gallop"
type AnimRig = {
	horse: Model,
	root: BasePart,
	spec: HorseConfig.RigSpec,
	legs: { [string]: Leg },
	neck: Joint?,
	tail: Joint?,
	dust: { ParticleEmitter },
	phase: number,
	weight: number,
	amp: { upper: number, lower: number, neck: number },
	time: number,
	nextSnort: number,
}

local GAIT_AMP = {
	Idle = { upper = 0, lower = 0, neck = 0 },
	Walk = { upper = 0.28, lower = 0.45, neck = 0.06 },
	Trot = { upper = 0.4, lower = 0.7, neck = 0.05 },
	Gallop = { upper = 0.6, lower = 0.9, neck = 0.12 },
}
local STRIDE_LENGTH = { Idle = 6, Walk = 6, Trot = 9, Gallop = 14 }

local rigs: { [Model]: AnimRig } = {}

local function findJointInstance(horse: Model, name: string): (Motor6D | Bone)?
	for _, d in horse:GetDescendants() do
		if d.Name == name then
			if d:IsA("Motor6D") then
				return d
			elseif d:IsA("Bone") then
				return d
			end
		end
	end
	return nil
end

-- 회전축(말의 옆축, 위축)을 관절 자신의 좌표계로 바꿔 둔다. Transform이 모두 기본값일 때 계산해야 한다.
local function makeJoint(horse: Model, name: string, frame: CFrame): Joint?
	local inst = findJointInstance(horse, name)
	if not inst then
		return nil
	end
	local jointFrame: CFrame
	if inst:IsA("Motor6D") then
		local part0 = inst.Part0
		if not part0 then
			return nil
		end
		jointFrame = part0.CFrame * inst.C0
	elseif inst:IsA("Bone") then
		jointFrame = inst.WorldCFrame
	else
		return nil
	end
	return {
		inst = inst,
		lateral = jointFrame:VectorToObjectSpace(frame.RightVector),
		up = jointFrame:VectorToObjectSpace(frame.UpVector),
	}
end

local function setTransform(joint: Joint?, cf: CFrame)
	local inst = joint and joint.inst
	if inst and inst:IsA("Motor6D") then
		inst.Transform = cf
	elseif inst and inst:IsA("Bone") then
		inst.Transform = cf
	end
end

local function build(horse: Instance)
	if not horse:IsA("Model") or rigs[horse] then
		return
	end
	local spec = HorseRig.getSpec(horse)
	if not spec then
		return
	end
	local root = horse:WaitForChild(spec.rootName, 15)
	if not root or not root:IsA("BasePart") or not horse:IsDescendantOf(workspace) then
		return
	end
	local frame = root.CFrame * spec.frameOffset
	local legs: { [string]: Leg } = {}
	for legName, legSpec in spec.legs do
		legs[legName] = {
			upper = makeJoint(horse, legSpec.upper, frame),
			lower = makeJoint(horse, legSpec.lower, frame),
			flexSign = legSpec.flexSign,
			offset = HorseConfig.LegPhase.Walk[legName] or 0,
		}
	end
	local dust: { ParticleEmitter } = {}
	for _, d in horse:GetDescendants() do
		if d:IsA("ParticleEmitter") and d.Parent and d.Parent.Name == "Dust" then
			table.insert(dust, d)
		end
	end
	rigs[horse] = {
		horse = horse,
		root = root,
		spec = spec,
		legs = legs,
		neck = makeJoint(horse, spec.neck, frame),
		tail = makeJoint(horse, spec.tail, frame),
		dust = dust,
		phase = 0,
		weight = 0,
		amp = { upper = 0, lower = 0, neck = 0 },
		time = math.random() * 10,
		nextSnort = os.clock() + 15 + math.random() * 30,
	}
end

local function gaitFor(speed: number): Gait
	local t = HorseConfig.GaitThreshold
	if speed < t.Walk then
		return "Idle"
	elseif speed < t.Trot then
		return "Walk"
	elseif speed < t.Gallop then
		return "Trot"
	end
	return "Gallop"
end

local function sound(root: BasePart, name: string): Sound?
	local s = root:FindFirstChild(name)
	return if s and s:IsA("Sound") then s else nil
end

-- 발굽 소리는 로컬에서 반복 재생한다(Looped를 켠 것은 이 스크립트가 재생한 소리뿐)
local function setLoop(s: Sound?, on: boolean, playbackSpeed: number)
	if not s then
		return
	end
	if on then
		if not s.IsPlaying then
			s.Looped = true
			s:Play()
		end
		s.PlaybackSpeed = playbackSpeed
	elseif s.IsPlaying and s.Looped then
		s:Stop()
	end
end

local function wrapLerp(current: number, target: number, alpha: number): number
	local diff = (target - current + 0.5) % 1 - 0.5
	return (current + diff * alpha) % 1
end

local function update(rig: AnimRig, dt: number, cameraPos: Vector3)
	local root = rig.root
	local distance = (root.Position - cameraPos).Magnitude
	if distance > ANIMATE_DISTANCE then
		return
	end
	local frame = root.CFrame * rig.spec.frameOffset
	local velocity = root.AssemblyLinearVelocity
	local forwardSpeed = velocity:Dot(frame.LookVector)
	local speed = math.abs(forwardSpeed)
	local gait = gaitFor(speed)
	rig.time += dt

	local alpha = math.min(1, dt * 4)
	rig.weight += ((if gait == "Idle" then 0 else 1) - rig.weight) * alpha
	local targetAmp = GAIT_AMP[gait]
	rig.amp.upper += (targetAmp.upper - rig.amp.upper) * alpha
	rig.amp.lower += (targetAmp.lower - rig.amp.lower) * alpha
	rig.amp.neck += (targetAmp.neck - rig.amp.neck) * alpha

	local frequency = math.max(speed / STRIDE_LENGTH[gait], 0.5)
	rig.phase = (rig.phase + dt * frequency * (if forwardSpeed < 0 then -1 else 1)) % 1

	local phases = HorseConfig.LegPhase[if gait == "Idle" then "Walk" else gait]
	for legName, leg in rig.legs do
		leg.offset = wrapLerp(leg.offset, phases[legName] or 0, alpha)
		local angle = TAU * (rig.phase + leg.offset)
		local swing = rig.amp.upper * math.sin(angle) * rig.weight
		local flex = rig.amp.lower * math.max(0, math.cos(angle)) * rig.weight * leg.flexSign
		if leg.upper then
			setTransform(leg.upper, CFrame.fromAxisAngle(leg.upper.lateral, swing))
		end
		if leg.lower then
			setTransform(leg.lower, CFrame.fromAxisAngle(leg.lower.lateral, flex))
		end
	end

	local neck = rig.neck
	if neck then
		local nod = rig.amp.neck * math.sin(TAU * rig.phase * 2) * rig.weight
		local graze = if gait == "Idle" then 0.04 * math.sin(rig.time * 0.4) else 0
		setTransform(neck, CFrame.fromAxisAngle(neck.lateral, nod + graze))
	end
	local tail = rig.tail
	if tail then
		local swish = (0.18 + 0.1 * rig.weight) * math.sin(rig.time * 1.7) * (0.6 + 0.4 * math.sin(rig.time * 0.23))
		setTransform(tail, CFrame.fromAxisAngle(tail.up, swish))
	end

	local trot = sound(root, "Trot")
	local gallop = sound(root, "Gallop")
	setLoop(trot, gait == "Walk" or gait == "Trot", 0.8 + 0.4 * math.clamp(speed / HorseConfig.Speed.Trot, 0, 1))
	setLoop(gallop, gait == "Gallop", 0.9 + 0.2 * math.clamp((speed - HorseConfig.GaitThreshold.Gallop) / 10, 0, 1))
	for _, emitter in rig.dust do
		emitter.Enabled = gait == "Gallop"
	end

	if gait == "Idle" and distance < SNORT_DISTANCE and os.clock() > rig.nextSnort then
		rig.nextSnort = os.clock() + 20 + math.random() * 40
		local snort = sound(root, "Snort" .. math.random(1, 3))
		if snort and not snort.IsPlaying then
			snort:Play()
		end
	end
end

for _, horse in CollectionService:GetTagged(HorseConfig.TAG) do
	task.spawn(build, horse)
end
CollectionService:GetInstanceAddedSignal(HorseConfig.TAG):Connect(function(horse)
	task.spawn(build, horse)
end)
CollectionService:GetInstanceRemovedSignal(HorseConfig.TAG):Connect(function(horse)
	if horse:IsA("Model") then
		rigs[horse] = nil
	end
end)

RunService.PreSimulation:Connect(function(dt)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local cameraPos = camera.CFrame.Position
	for horse, rig in rigs do
		if rig.root.Parent == nil then
			rigs[horse] = nil
		else
			update(rig, dt, cameraPos)
		end
	end
end)
