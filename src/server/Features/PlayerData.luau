--!strict
-- 플레이어 저장 데이터의 유일한 진실 소스. 다른 기능은 AddItem / HasItem / RemoveItem 만 사용한다.
--
-- 저장 정책: 입장 시 로드, 5분마다 자동 저장, 퇴장 시 저장. 실패 시 재시도.
-- Studio에서 DataStore API 접근이 꺼져 있으면(또는 계속 실패하면) 메모리 저장으로 자동 전환하고
-- 경고만 출력한다 — 저장 실패가 게임 진행을 막지 않는다.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Features"):WaitForChild("Remotes"))
local ItemDatabase = require(game:GetService("ReplicatedStorage"):WaitForChild("Features"):WaitForChild("ItemDatabase"))
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Features"):WaitForChild("Types"))

type PlayerDataShape = Types.PlayerData

local SCHEMA_VERSION = 1
local DATASTORE_NAME = "HealingForest_PlayerData_v1"
local AUTOSAVE_INTERVAL = 300 -- 5분
local MAX_RETRIES = 3
local RETRY_BASE_DELAY = 1 -- 초, 매 시도마다 2배씩 늘어남

local PlayerData = {}

-- 실 DataStore 접근이 막혀 있을 때를 대비한 세션 내 메모리 백업 저장소.
local memoryStore: { [number]: PlayerDataShape } = {}
local cache: { [number]: PlayerDataShape } = {}
local usingMemoryFallback = false
local warnedFallback = false

local dataStore: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(DATASTORE_NAME)
	end)
	if ok then
		dataStore = result
	end
end
if dataStore == nil then
	usingMemoryFallback = true
end

local function warnFallbackOnce()
	if warnedFallback then
		return
	end
	warnedFallback = true
	warn("[PlayerData] DataStore에 접근할 수 없어 메모리 저장 모드로 전환합니다. (Studio > 게임 설정 > 보안 > Studio에서 API 서비스 접근 허용을 확인하세요) 이 세션 동안은 진행 상황이 서버 메모리에만 저장됩니다.")
end

local function deepCopy<T>(value: T): T
	if typeof(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in (value :: any) do
		copy[k] = deepCopy(v)
	end
	return (copy :: any) :: T
end

local function defaultData(): PlayerDataShape
	return {
		version = SCHEMA_VERSION,
		inventory = {},
		codex = {},
		quests = {},
		horseAffinity = {},
		stats = {},
		lastSaved = os.time(),
	}
end

local function migrate(data: PlayerDataShape): PlayerDataShape
	-- 스키마가 바뀌면 여기서 버전별로 채워 넣는다. 현재는 v1 하나뿐이라 누락 필드만 보정한다.
	data.version = data.version or SCHEMA_VERSION
	data.inventory = data.inventory or {}
	data.codex = data.codex or {}
	data.quests = data.quests or {}
	data.horseAffinity = data.horseAffinity or {}
	data.stats = data.stats or {}
	data.lastSaved = data.lastSaved or os.time()
	return data
end

local function keyFor(userId: number): string
	return "player_" .. tostring(userId)
end

-- pcall + 재시도(지수 백오프)로 fn을 실행한다. 메모리 폴백 모드에서는 즉시 실패로 처리해 헛수고를 하지 않는다.
local function withRetry(fn: () -> ...any): (boolean, any)
	if usingMemoryFallback then
		return false, "memory-fallback"
	end

	local delay = RETRY_BASE_DELAY
	for attemptIndex = 1, MAX_RETRIES do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		if attemptIndex < MAX_RETRIES then
			task.wait(delay)
			delay *= 2
		else
			return false, result
		end
	end
	return false, "unreachable"
end

local function coreLoad(userId: number): PlayerDataShape
	if cache[userId] then
		return cache[userId]
	end

	local loaded: PlayerDataShape? = nil

	if dataStore and not usingMemoryFallback then
		local ok, result = withRetry(function()
			return dataStore:GetAsync(keyFor(userId))
		end)
		if ok then
			if result then
				loaded = migrate(result :: PlayerDataShape)
			end
		else
			usingMemoryFallback = true
			warnFallbackOnce()
		end
	end

	if not loaded then
		-- DataStore를 못 쓰거나 처음 접속이면 메모리 백업(같은 서버 세션 내 재접속 대비)을 확인한다.
		local backup = memoryStore[userId]
		if backup then
			loaded = deepCopy(backup)
		end
	end

	if not loaded then
		loaded = defaultData()
	end

	cache[userId] = loaded :: PlayerDataShape
	return loaded :: PlayerDataShape
end

local function coreSave(userId: number): boolean
	local data = cache[userId]
	if not data then
		return false
	end

	data.lastSaved = os.time()

	if dataStore and not usingMemoryFallback then
		local ok = withRetry(function()
			dataStore:UpdateAsync(keyFor(userId), function()
				return data
			end)
		end)
		if ok then
			return true
		end
		usingMemoryFallback = true
		warnFallbackOnce()
	end

	-- 메모리 폴백: 최소한 이 서버 세션 안에서는 데이터가 유지되도록 백업해 둔다.
	memoryStore[userId] = deepCopy(data)
	return true
end

local function coreAddItem(userId: number, itemId: string, amount: number): (boolean, number, boolean)
	if amount <= 0 or amount ~= math.floor(amount) then
		return false, 0, false
	end
	if not ItemDatabase.Exists(itemId) then
		warn(`[PlayerData] 알 수 없는 ItemId: {itemId}`)
		return false, 0, false
	end

	local data = coreLoad(userId)
	local newCount = (data.inventory[itemId] or 0) + amount
	data.inventory[itemId] = newCount

	local isNewDiscovery = false
	local codexEntry = data.codex[itemId]
	if codexEntry then
		codexEntry.count += amount
	else
		isNewDiscovery = true
		data.codex[itemId] = { firstSeenAt = os.time(), count = amount }
	end

	data.stats.itemsCollected = (data.stats.itemsCollected or 0) + amount

	return true, newCount, isNewDiscovery
end

local function coreRemoveItem(userId: number, itemId: string, amount: number): (boolean, number)
	if amount <= 0 or amount ~= math.floor(amount) then
		return false, 0
	end

	local data = coreLoad(userId)
	local current = data.inventory[itemId] or 0
	if current < amount then
		return false, current
	end

	local newCount = current - amount
	if newCount <= 0 then
		data.inventory[itemId] = nil
		newCount = 0
	else
		data.inventory[itemId] = newCount
	end

	return true, newCount
end

local function coreHasItem(userId: number, itemId: string, amount: number): boolean
	local data = coreLoad(userId)
	return (data.inventory[itemId] or 0) >= amount
end

-- ===== 플레이어 대상 공개 API =====

function PlayerData.Load(player: Player)
	local data = coreLoad(player.UserId)

	local inventorySync = Remotes.Get("InventorySync")
	inventorySync:FireClient(player, {
		inventory = data.inventory,
		codex = data.codex,
		stats = data.stats,
	})
end

function PlayerData.Save(player: Player): boolean
	return coreSave(player.UserId)
end

function PlayerData.AddItem(player: Player, itemId: string, amount: number?): (boolean, number)
	local ok, newCount, isNewDiscovery = coreAddItem(player.UserId, itemId, amount or 1)
	if not ok then
		return false, 0
	end

	local itemAdded = Remotes.Get("ItemAdded")
	itemAdded:FireClient(player, {
		itemId = itemId,
		amount = amount or 1,
		newCount = newCount,
		isNewDiscovery = isNewDiscovery,
	})

	local inventoryDelta = Remotes.Get("InventoryDelta")
	inventoryDelta:FireClient(player, {
		itemId = itemId,
		newCount = newCount,
		delta = amount or 1,
	})

	return true, newCount
end

function PlayerData.RemoveItem(player: Player, itemId: string, amount: number?): (boolean, number)
	local removeAmount = amount or 1
	local ok, newCount = coreRemoveItem(player.UserId, itemId, removeAmount)
	if not ok then
		return false, newCount
	end

	local inventoryDelta = Remotes.Get("InventoryDelta")
	inventoryDelta:FireClient(player, {
		itemId = itemId,
		newCount = newCount,
		delta = -removeAmount,
	})

	return true, newCount
end

function PlayerData.HasItem(player: Player, itemId: string, amount: number?): boolean
	return coreHasItem(player.UserId, itemId, amount or 1)
end

function PlayerData.GetSnapshot(player: Player): PlayerDataShape
	return coreLoad(player.UserId)
end

function PlayerData.IsMemoryFallback(): boolean
	return usingMemoryFallback
end

-- ===== FeatureTests 전용 (userId 기반, Player 인스턴스 불필요) =====

PlayerData._Test = {
	-- cache/memoryStore뿐 아니라 실제 DataStore에 남아있을 수 있는 이전 테스트 실행분까지 지운다.
	-- 그렇지 않으면 (실제 DataStore가 연결된 세션에서) 이전에 성공한 테스트가 저장해 둔
	-- "player_-1001" 레코드를 다음 실행이 그대로 읽어와 "초기 인벤토리가 비어있지 않다"로 실패한다.
	Reset = function(userId: number)
		cache[userId] = nil
		memoryStore[userId] = nil
		if dataStore then
			pcall(function()
				dataStore:RemoveAsync(keyFor(userId))
			end)
		end
	end,
	Load = function(userId: number): PlayerDataShape
		return coreLoad(userId)
	end,
	AddItem = function(userId: number, itemId: string, amount: number): (boolean, number, boolean)
		return coreAddItem(userId, itemId, amount)
	end,
	Save = function(userId: number): boolean
		return coreSave(userId)
	end,
	ClearCache = function(userId: number)
		cache[userId] = nil
	end,
}

-- ===== 생명주기 =====

local function autosaveLoop()
	while true do
		task.wait(AUTOSAVE_INTERVAL)
		for _, player in Players:GetPlayers() do
			local ok, err = pcall(coreSave, player.UserId)
			if not ok then
				warn(`[PlayerData] 자동 저장 중 오류 ({player.Name}): {tostring(err)}`)
			end
		end
	end
end

function PlayerData.Init()
	Players.PlayerAdded:Connect(function(player)
		PlayerData.Load(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		PlayerData.Save(player)
	end)

	-- 스크립트가 다시 시작된 경우를 대비해 이미 접속해 있는 플레이어도 처리한다.
	for _, player in Players:GetPlayers() do
		PlayerData.Load(player)
	end

	task.spawn(autosaveLoop)

	print("[PlayerData] 초기화 완료" .. (dataStore == nil and " (DataStore 서비스 자체를 가져오지 못함 - 메모리 모드)" or ""))
	if dataStore == nil then
		usingMemoryFallback = true
	end
end

return PlayerData
