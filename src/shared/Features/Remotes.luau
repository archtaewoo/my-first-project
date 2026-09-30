--!strict
-- 서버<->클라이언트 통신 지점. 서버가 진실이며 클라이언트는 받은 값을 표시만 한다.
--
-- RemoteEvent (서버 -> 클라이언트, 일방향 알림)
--   InventorySync  : 입장 시 1회, 인벤토리/도감/스탯/화폐/업그레이드 전체 스냅샷
--   InventoryDelta : 인벤토리 개수가 바뀔 때마다(증가/감소) 보내는 델타
--   ItemAdded      : 채집 등으로 아이템을 얻었을 때 토스트용 알림 (isNewDiscovery로 최초 발견 여부 포함)
--   CurrencyChanged: 화폐(도토리 등)가 바뀔 때마다 보내는 델타
--   OpenShop       : ProximityPrompt로 상점을 열 때 그 상점의 판매 목록을 실어 보낸다
--   FishingCastStarted: 낚시를 시작했을 때(기다리는 중 문구용)
--   FishingBite       : 입질이 왔을 때("지금이야!" 반응 신호)
--   FishingResult     : 낚시 성공/실패가 최종 확정됐을 때 (잡은 아이템 자체는 ItemAdded로 별도 안내)
--   AffinityChanged   : 말 애정도 원값이 바뀔 때마다 보내는 델타
--   HorseCareResult   : 먹이/물/빗질을 했을 때 말 이름·등급·등급 상승 여부를 담아 안내
--   OpenCampfire      : 모닥불 프롬프트를 열 때 요리 가능한 레시피 목록을 실어 보낸다
--   SleepMessage      : 같이 자기 진행 상황(기다리는 중/성사/취소) 안내 — 조사 처리가 필요 없는
--                        고정 문장이라 서버가 완성된 문자열을 그대로 보낸다
--
-- RemoteFunction (클라이언트 -> 서버, 요청·응답)
--   Purchase(shopId, listingId) -> (ok: boolean, message: string)
--   Sell(itemId, quantity)      -> (ok: boolean, message: string, totalEarned: number)
--   ReactToBite()               -> (accepted: boolean) — 입질 중에 눌렀는지 여부만 즉시 알려주고,
--                                   실제 성공/실패는 FishingResult로 온다.
--   Cook(recipeId)              -> (ok: boolean, reasonCode: string)
--   Eat(itemId)                 -> (ok: boolean, reasonCode: string)
-- 전부 클라이언트가 보낸 값(가격·재료·타이밍 등)은 신뢰하지 않고, 서버가 직접 검증/판정한다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local REMOTE_EVENT_NAMES = {
	"InventorySync",
	"InventoryDelta",
	"ItemAdded",
	"CurrencyChanged",
	"OpenShop",
	"FishingCastStarted",
	"FishingBite",
	"FishingResult",
	"AffinityChanged",
	"HorseCareResult",
	"OpenCampfire",
	"SleepMessage",
}
local REMOTE_FUNCTION_NAMES = { "Purchase", "Sell", "ReactToBite", "Cook", "Eat" }

-- 이 폴더 이름을 "Remotes"로 하면 안 된다 — 이 파일 자체가 Rojo에 의해
-- ReplicatedStorage.Features.Remotes 라는 "Remotes"란 이름의 ModuleScript가 되므로,
-- 같은 이름의 Folder를 같은 부모(Features) 밑에 만들면 형제 인스턴스 이름이 겹친다.
-- FindFirstChild/WaitForChild("Remotes")는 둘 중 먼저 찾아지는 걸 반환하는데, 보통
-- (Rojo가 Play 시작 전부터 이미 만들어 둔) ModuleScript가 먼저 있어서 그게 잡히고,
-- 그 안엔 RemoteEvent가 없으니 클라이언트가 영원히 기다리게 된다.
local REMOTES_FOLDER_NAME = "RemoteEvents"

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
		local existing = features:FindFirstChild(REMOTES_FOLDER_NAME)
		local folder: Folder
		if existing and existing:IsA("Folder") then
			folder = existing
		else
			folder = Instance.new("Folder")
			folder.Name = REMOTES_FOLDER_NAME
			folder.Parent = features
		end

		-- 폴더를 새로 만들었든 이미 있던 걸 재사용하든, 빠진 Remote가 있으면 항상 채워 넣는다.
		-- 이전에 일부만 만들어진 채 남아있는 걸 그냥 반환해버리면 특정 Remote가 영원히
		-- 생기지 않아 클라이언트가 무한 대기에 빠진다.
		for _, name in REMOTE_EVENT_NAMES do
			if not folder:FindFirstChild(name) then
				local remote = Instance.new("RemoteEvent")
				remote.Name = name
				remote.Parent = folder
			end
		end
		for _, name in REMOTE_FUNCTION_NAMES do
			if not folder:FindFirstChild(name) then
				local remote = Instance.new("RemoteFunction")
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

function Remotes.GetEvent(name: string): RemoteEvent
	local folder = getOrCreateFolder()
	local remote = folder:WaitForChild(name)
	assert(remote:IsA("RemoteEvent"), `{name} 은 RemoteEvent가 아닙니다`)
	return remote
end

function Remotes.GetFunction(name: string): RemoteFunction
	local folder = getOrCreateFolder()
	local remote = folder:WaitForChild(name)
	assert(remote:IsA("RemoteFunction"), `{name} 은 RemoteFunction이 아닙니다`)
	return remote
end

-- 예전 이름 유지 (기존 코드가 Remotes.Get으로 RemoteEvent를 가져다 쓰고 있음).
Remotes.Get = Remotes.GetEvent

-- 서버 시작 시 한 번 호출해서 플레이어 접속 여부와 무관하게 즉시 모든 Remote를 만들어 둔다.
-- 이걸 호출하지 않으면 (예: 플레이어가 아직 없거나 PlayerData.Load가 아직 안 불린 시점에)
-- 클라이언트의 WaitForChild가 영원히 끝나지 않는 "Infinite yield" 상태에 빠질 수 있다.
function Remotes.EnsureAll()
	if not RunService:IsServer() then
		return
	end
	getOrCreateFolder()
end

return Remotes
