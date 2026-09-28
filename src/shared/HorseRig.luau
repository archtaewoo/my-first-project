--!strict
local CollectionService = game:GetService("CollectionService")

local HorseConfig = require(script.Parent:WaitForChild("HorseConfig"))

local HorseRig = {}

function HorseRig.getSpec(horse: Model): HorseConfig.RigSpec?
	local kind = horse:GetAttribute("Kind")
	if kind == "Rigged" then
		return HorseConfig.Rigs.Rigged
	elseif kind == "Skinned" then
		return HorseConfig.Rigs.Skinned
	end
	return nil
end

function HorseRig.getRoot(horse: Model): BasePart?
	local spec = HorseRig.getSpec(horse)
	if not spec then
		return nil
	end
	local root = horse:FindFirstChild(spec.rootName)
	return if root and root:IsA("BasePart") then root else nil
end

-- 말 프레임: 몸통 중심 아래 지면, LookVector = 말의 앞
function HorseRig.getFrame(horse: Model): CFrame?
	local spec = HorseRig.getSpec(horse)
	local root = HorseRig.getRoot(horse)
	if not spec or not root then
		return nil
	end
	return root.CFrame * spec.frameOffset
end

function HorseRig.findHorseFromPart(part: Instance): Model?
	local node: Instance? = part.Parent
	while node do
		if node:IsA("Model") and CollectionService:HasTag(node, HorseConfig.TAG) then
			return node
		end
		node = node.Parent
	end
	return nil
end

-- 지면 탐색용: 충돌하는 것만(나무 잎, 풀 등 CanCollide=false 제외), 말과 캐릭터 제외
function HorseRig.groundParams(exclude: { Instance }, ignoreWater: boolean): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	params.IgnoreWater = ignoreWater
	params.RespectCanCollide = true
	return params
end

function HorseRig.flatLook(cf: CFrame): Vector3
	local look = cf.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		return Vector3.new(0, 0, -1)
	end
	return flat.Unit
end

function HorseRig.distanceFromBasinCenter(position: Vector3): number
	return (Vector2.new(position.X, position.Z) - HorseConfig.BASIN_CENTER).Magnitude
end

-- 앞쪽 지점을 살펴본다: 깊은 물/분지 밖/너무 가파른 오르막이면 blocked, 얕은 물이면 slow
function HorseRig.probe(origin: Vector3, direction: Vector3, distance: number, exclude: { Instance }): (boolean, boolean)
	local point = origin + direction * distance
	if HorseRig.distanceFromBasinCenter(point) > HorseConfig.WALK_RADIUS then
		return true, false
	end
	local rayStart = point + Vector3.new(0, 6, 0)
	local hit = workspace:Raycast(rayStart, Vector3.new(0, -40, 0), HorseRig.groundParams(exclude, false))
	if not hit then
		return true, false -- 발밑이 없거나(큰 절벽) 지형 속: 막는다
	end
	if hit.Material == Enum.Material.Water then
		local floor = workspace:Raycast(hit.Position, Vector3.new(0, -30, 0), HorseRig.groundParams(exclude, true))
		local depth = if floor then hit.Position.Y - floor.Position.Y else math.huge
		if depth > HorseConfig.MaxWadeDepth then
			return true, false
		end
		return false, depth > HorseConfig.ShallowWaterDepth
	end
	local rise = hit.Position.Y - origin.Y
	if rise > 2.5 and rise / distance > math.tan(math.rad(HorseConfig.MaxSlopeDeg)) then
		return true, false
	end
	return false, false
end

return HorseRig
