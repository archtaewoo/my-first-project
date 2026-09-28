--!strict
-- 서버<->클라이언트 통신 지점. 서버가 진실이며 클라이언트는 받은 값을 표시만 한다.
-- 클라이언트가 서버로 보내는 RemoteEvent는 작업 0에는 없다 (채집은 서버가 ProximityPrompt.Triggered로 직접 처리).
--
-- InventorySync : 입장 시 1회, 인벤토리/도감/스탯 전체 스냅샷
-- InventoryDelta: 인벤토리 개수가 바뀔 때마다(증가/감소) 보내는 델타
-- ItemAdded     : 채집 등으로 아이템을 얻었을 때 토스트용 알림 (isNewDiscovery로 최초 발견 여부 포함)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local REMOTE_NAMES = { "InventorySync", "InventoryDelta", "ItemAdded" }

local Remotes = {}

local folderCache: Folder? = nil

local function getFeaturesFolder(): Folder
	local features = ReplicatedStorage:WaitForChild("Features") :: Folder
	return features
end

local function getOrCreateFolder(): Folder
	if folderCache then
		return folderCache
	end

	local features = getFeaturesFolder()

	if RunService:IsServer() then
		local existing = features:FindFirstChild("Remotes")
		if existing and existing:IsA("Folder") then
			folderCache = existing
			return existing
		end

		local folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = features

		for _, name in REMOTE_NAMES do
			if not folder:FindFirstChild(name) then
				local remote = Instance.new("RemoteEvent")
				remote.Name = name
				remote.Parent = folder
			end
		end

		folderCache = folder
		return folder
	else
		local folder = features:WaitForChild("Remotes") :: Folder
		folderCache = folder
		return folder
	end
end

function Remotes.Get(name: string): RemoteEvent
	local folder = getOrCreateFolder()
	local remote = folder:WaitForChild(name)
	assert(remote:IsA("RemoteEvent"), `{name} 은 RemoteEvent가 아닙니다`)
	return remote
end

return Remotes
