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

-- 이 폴더 이름을 "Remotes"로 하면 안 된다 — 이 파일 자체가 Rojo에 의해
-- ReplicatedStorage.Features.Remotes 라는 "Remotes"란 이름의 ModuleScript가 되므로,
-- 같은 이름의 Folder를 같은 부모(Features) 밑에 만들면 형제 인스턴스 이름이 겹친다.
-- FindFirstChild/WaitForChild("Remotes")는 둘 중 먼저 찾아지는 걸 반환하는데, 보통
-- (Rojo가 Play 시작 전부터 이미 만들어 둔) ModuleScript가 먼저 있어서 그게 잡히고,
-- 그 안엔 RemoteEvent가 없으니 클라이언트가 영원히 기다리게 된다.
local REMOTES_FOLDER_NAME = "RemoteEvents"

local function getOrCreateFolder(): Folder
	if folderCache then
		return folderCache
	end

	local features = getFeaturesFolder()

	if RunService:IsServer() then
		local existing = features:FindFirstChild(REMOTES_FOLDER_NAME)
		local folder: Folder
		if existing and existing:IsA("Folder") then
			folder = existing
		else
			folder = Instance.new("Folder")
			folder.Name = REMOTES_FOLDER_NAME
			folder.Parent = features
		end

		-- 폴더를 새로 만들었든 이미 있던 걸 재사용하든, 빠진 RemoteEvent가 있으면
		-- 항상 채워 넣는다. 이전에 빈 폴더만 만들어졌던 경우를 그냥 반환해버리면
		-- InventorySync 등이 영원히 생기지 않아 클라이언트가 무한 대기에 빠진다.
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
		local folder = features:WaitForChild(REMOTES_FOLDER_NAME) :: Folder
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

-- 서버 시작 시 한 번 호출해서 플레이어 접속 여부와 무관하게 즉시 RemoteEvent를 만들어 둔다.
-- 이걸 호출하지 않으면 (예: 플레이어가 아직 없거나 PlayerData.Load가 아직 안 불린 시점에)
-- 클라이언트의 WaitForChild가 영원히 끝나지 않는 "Infinite yield" 상태에 빠질 수 있다.
function Remotes.EnsureAll()
	if not RunService:IsServer() then
		return
	end
	getOrCreateFolder()
end

return Remotes
