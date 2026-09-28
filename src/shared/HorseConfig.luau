--!strict
-- 말 타기 설정. 리그 수치는 forest.rbxl에서 측정한 값이다(파트/뼈 위치, 루트 방향).
-- "말 프레임"은 몸통 중심 아래 지면에 원점을 두고 -Z가 말의 앞, +X가 말의 오른쪽인 좌표계다.

export type LegSpec = { upper: string, lower: string, flexSign: number }
export type RigSpec = {
	rootName: string,
	frameOffset: CFrame, -- 루트 파트 CFrame → 말 프레임
	colliderCenter: Vector3, -- 말 프레임 기준
	colliderSize: Vector3,
	driverSeat: Vector3,
	passengerSeat: Vector3?,
	legs: { [string]: LegSpec }, -- LF, RF, LH, RH
	neck: string,
	tail: string,
}

local HorseConfig = {}

-- true면 점프 후 1초 동안 매 프레임 수직 상태를 클라이언트 출력에 찍는다
-- 점프 버그 진단 중이라 임시로 켜 둠. 문제 해결되면 false로.
HorseConfig.Debug = true

HorseConfig.TAG = "CustomHorse"
HorseConfig.REMOTE_NAME = "HorseRide"
HorseConfig.SEAT_ATTRIBUTE = "HorseSeat" -- "Driver" | "Passenger"

-- 맵 사실(CLAUDE.md): 분지 중심 (X, Z), 걸을 수 있는 반지름
HorseConfig.BASIN_CENTER = Vector2.new(1424, 285)
HorseConfig.WALK_RADIUS = 390

HorseConfig.Speed = {
	Walk = 8,
	Trot = 16,
	Gallop = 30,
	Reverse = 5,
	Accel = 16,
	Brake = 34,
	ShallowWaterFactor = 0.5,
}
HorseConfig.TurnRateStand = math.rad(110)
HorseConfig.TurnRateGallop = math.rad(55)
HorseConfig.JumpVelocity = 50 -- 높이 약 v²/2g = 6.4스터드, 체공 약 0.5초(Gravity 196.2 기준)
HorseConfig.JumpCooldown = 0.8 -- 도약 후 다음 점프까지 최소 시간(초)
HorseConfig.GroundSnap = 1.2 -- 지면에서 이 거리 안이면 "땅 위"로 본다
HorseConfig.MaxSlopeDeg = 40
HorseConfig.MaxPitchDeg = 25
HorseConfig.MaxWadeDepth = 2.5
HorseConfig.ShallowWaterDepth = 0.8

-- 속도 구간(애니메이션/소리 전환)
HorseConfig.GaitThreshold = { Walk = 0.8, Trot = 11, Gallop = 23 }

HorseConfig.Validation = {
	Interval = 0.25,
	SpeedTolerance = 1.6,
	ExtraSpeed = 10,
	BoundarySlack = 12,
	StrikesBeforeReset = 3,
}

-- 아무도 타지 않은 말이 이 시간(초) 뒤 마구간 칸으로 돌아간다. nil이면 끈다.
HorseConfig.AutoReturnSeconds = 300 :: number?

-- 승마 자세 애니메이션. 확실한 에셋 ID가 없어 비워 둔다(사용자가 채움). nil이면 기본 앉기 자세.
HorseConfig.RideAnimationId = nil :: string?

HorseConfig.CollisionGroupHorse = "Horse"
HorseConfig.CollisionGroupRider = "HorseRider"

HorseConfig.Rigs = {
	-- 초코: HumanoidRootPart의 -Z가 앞. 발굽 바닥이 루트 기준 y=-4.16.
	Rigged = {
		rootName = "HumanoidRootPart",
		frameOffset = CFrame.new(0, -4.16, -0.3),
		colliderCenter = Vector3.new(0, 4.8, 0),
		colliderSize = Vector3.new(2.4, 2.6, 6.2),
		driverSeat = Vector3.new(0, 6.1, -0.1),
		passengerSeat = Vector3.new(0, 6.0, 1.8),
		legs = {
			LF = { upper = "LShoulder", lower = "LMetacarpal", flexSign = -1 },
			RF = { upper = "RShoulder", lower = "RMetacarpal", flexSign = -1 },
			LH = { upper = "LThigh", lower = "LAnkle", flexSign = 1 },
			RH = { upper = "RThigh", lower = "RAnkle", flexSign = 1 },
		},
		neck = "N1",
		tail = "Tail",
	} :: RigSpec,
	-- 구름/밤이/눈송이/고구마: RootPart의 -X가 앞(루트는 뒷다리 쪽 지면 높이). 뼈 이름은 4마리 공통.
	Skinned = {
		rootName = "RootPart",
		frameOffset = CFrame.new(-4.5, 0.09, 0) * CFrame.Angles(0, math.pi / 2, 0),
		colliderCenter = Vector3.new(0, 4.9, 0),
		colliderSize = Vector3.new(2.4, 2.6, 6.4),
		driverSeat = Vector3.new(0, 6.6, 0.4),
		passengerSeat = Vector3.new(0, 6.4, 2.2),
		legs = {
			LF = { upper = "Bone.008", lower = "Bone.009", flexSign = -1 },
			RF = { upper = "Bone.011", lower = "Bone.015", flexSign = -1 },
			LH = { upper = "Bone.012", lower = "Bone.013", flexSign = 1 },
			RH = { upper = "Bone.017", lower = "Bone.018", flexSign = 1 },
		},
		neck = "Bone.002",
		tail = "Bone.023",
	} :: RigSpec,
}

-- 걸음 주기에서 각 다리의 위상(0~1)
HorseConfig.LegPhase = {
	Walk = { LH = 0, LF = 0.25, RH = 0.5, RF = 0.75 },
	Trot = { LF = 0, RH = 0, RF = 0.5, LH = 0.5 },
	Gallop = { LH = 0, RH = 0.12, LF = 0.4, RF = 0.52 },
}

HorseConfig.SoundNames = { "Gallop", "Trot", "Mount", "Snort1", "Snort2", "Snort3" }

return HorseConfig
