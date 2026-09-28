--!strict
-- Studio 전용 자동 테스트. ServerScriptService에 Boolean 속성 RunHorseTests=true를 추가하고 Play하면 실행된다.
-- 플레이어가 2명(테스트 > 클라이언트 및 서버 > 2)이면 뒷자리 탑승도 검사한다.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

if not RunService:IsStudio() or ServerScriptService:GetAttribute("RunHorseTests") ~= true then
	return
end

local HorseConfig = require(ReplicatedStorage:WaitForChild("HorseConfig"))
local HorseRig = require(ReplicatedStorage:WaitForChild("HorseRig"))
local Service = require(script.Parent:WaitForChild("HorseRidingService"))

local passed, failed = 0, 0
local function check(name: string, ok: boolean, detail: string?)
	if ok then
		passed += 1
	else
		failed += 1
	end
	print(("[HorseTest] %s  %s %s"):format(if ok then "PASS" else "FAIL", name, detail or ""))
end

local function waitFor(predicate: () -> boolean, timeout: number): boolean
	local deadline = os.clock() + timeout
	while os.clock() < deadline do
		if predicate() then
			return true
		end
		task.wait(0.05)
	end
	return predicate()
end

-- HorseCustomizer.apply와 같은 계산으로 Coat 파트 색을 검사한다
local function coatMatches(horse: Model, color: Color3): (boolean, string?)
	for _, d in horse:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Role") == "Coat" then
			local shade = d:GetAttribute("Shade")
			local s = if type(shade) == "number" then shade else 1
			local expected = Color3.new(math.clamp(color.R * s, 0, 1), math.clamp(color.G * s, 0, 1), math.clamp(color.B * s, 0, 1))
			local diff = math.max(math.abs(d.Color.R - expected.R), math.abs(d.Color.G - expected.G), math.abs(d.Color.B - expected.B))
			if diff > 0.02 then
				return false, d:GetFullName()
			end
		end
	end
	return true, nil
end

local function characterOf(player: Player): (Model, Humanoid)
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	return character, humanoid
end

local first = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
local character, humanoid = characterOf(first)
task.wait(3) -- HorseCustomizer/HorseRiding 준비 대기

local second = Players:GetPlayers()[2]
if not second then
	print("[HorseTest] 플레이어가 1명이라 뒷자리 검사는 건너뜀")
end

for _, instance in CollectionService:GetTagged(HorseConfig.TAG) do
	local horse = instance :: Model
	local name = tostring(horse:GetAttribute("HorseName"))
	local state = Service.getState(horse)
	check(name .. " 준비됨", state ~= nil)
	if not state then
		continue
	end
	local originalCoat = horse:GetAttribute("CoatColor")

	local red = Color3.fromRGB(200, 40, 40)
	horse:SetAttribute("CoatColor", red)
	task.wait(0.2)
	check(name .. " 꾸미기 색 적용(타기 전)", coatMatches(horse, red))

	character:PivotTo(state.collider.CFrame * CFrame.new(3.5, 0, 0))
	task.wait(0.3)
	local ok, why = Service.mount(first, horse)
	check(name .. " 탑승 요청", ok, why)
	check(name .. " 운전석에 앉음", waitFor(function()
		return state.driverSeat.Occupant == humanoid
	end, 3))
	check(name .. " 고정 해제", waitFor(function()
		return not state.root.Anchored
	end, 2))
	check(name .. " 네트워크 소유자 = 운전자", waitFor(function()
		return state.collider:GetNetworkOwner() == first
	end, 2))

	if second then
		local character2 = characterOf(second)
		character2:PivotTo(state.collider.CFrame * CFrame.new(-3.5, 0, 0))
		task.wait(0.3)
		local ok2, why2 = Service.mount(second, horse)
		check(name .. " 뒷자리 탑승", ok2 and why2 == "passenger", why2)
		local third = Service.mount(second, horse)
		check(name .. " 중복 탑승 거부", not third)
		Service.dismount(second, false)
		check(name .. " 뒷자리 하차", waitFor(function()
			local seat = state.passengerSeat
			return seat == nil or seat.Occupant == nil
		end, 3))
	end

	local green = Color3.fromRGB(40, 160, 60)
	horse:SetAttribute("CoatColor", green)
	task.wait(0.2)
	check(name .. " 꾸미기 색 적용(타는 중)", coatMatches(horse, green))

	Service.dismount(first, false)
	check(name .. " 하차", waitFor(function()
		return state.driverSeat.Occupant == nil and humanoid.SeatPart == nil
	end, 3))
	check(name .. " 다시 고정", waitFor(function()
		return state.root.Anchored
	end, 2))
	local frame = HorseRig.getFrame(horse)
	check(name .. " 똑바로 서 있음", frame ~= nil and frame.UpVector.Y > 0.99)

	-- 말을 옮겨 둔 뒤 "마구간으로"가 원래 칸으로 되돌리는지
	horse:PivotTo(horse:GetPivot() + Vector3.new(-15, 0, 0))
	character:PivotTo(state.collider.CFrame * CFrame.new(3.5, 0, 0))
	task.wait(0.3)
	Service.mount(first, horse)
	waitFor(function()
		return state.driverSeat.Occupant == humanoid
	end, 3)
	Service.dismount(first, true)
	check(name .. " 마구간 칸으로 복귀", waitFor(function()
		return not state.busy and state.root.Anchored and (state.root.Position - state.homeRoot.Position).Magnitude < 0.5
	end, 5))

	horse:SetAttribute("CoatColor", originalCoat)
	task.wait(0.2)
end

print(("[HorseTest] 끝: %d 통과, %d 실패"):format(passed, failed))
