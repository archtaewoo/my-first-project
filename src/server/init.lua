--!strict
-- 초기화: 공유 RemoteEvent 생성
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function createRemoteIfNotExists(name: string)
	if not ReplicatedStorage:FindFirstChild(name) then
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = ReplicatedStorage
	end
end

createRemoteIfNotExists("HorseCustomize")
