--!strict
-- ServerScriptService의 Boolean 속성 RunFeatureTests가 true가 되면
-- AddItem -> 저장 -> 재로드 흐름을 검증하고 PASS/FAIL을 출력한다.
-- Studio 명령줄에서: game:GetService("ServerScriptService"):SetAttribute("RunFeatureTests", true)

local ServerScriptService = game:GetService("ServerScriptService")

local PlayerData = require(script.Parent.PlayerData)

local FeatureTests = {}

-- 실제 Roblox UserId와 겹치지 않도록 음수를 사용한다.
local TEST_USER_ID = -1001

local function runInventoryRoundTripTest(): boolean
	local Test = PlayerData._Test

	Test.Reset(TEST_USER_ID)

	local loaded = Test.Load(TEST_USER_ID)
	if not loaded then
		warn("[FeatureTests] FAIL: 초기 로드가 nil을 반환했습니다")
		return false
	end
	if loaded.inventory["mushroom_white"] ~= nil then
		warn("[FeatureTests] FAIL: 초기 인벤토리가 비어있지 않습니다")
		return false
	end

	local added, newCount, isNewDiscovery = Test.AddItem(TEST_USER_ID, "mushroom_white", 1)
	if not added or newCount ~= 1 or not isNewDiscovery then
		warn(`[FeatureTests] FAIL: AddItem 결과 이상 (added={tostring(added)}, newCount={tostring(newCount)}, isNewDiscovery={tostring(isNewDiscovery)})`)
		return false
	end

	local savedOk = Test.Save(TEST_USER_ID)
	if not savedOk then
		warn("[FeatureTests] FAIL: 저장이 실패했습니다")
		return false
	end

	-- 퇴장 후 재접속을 흉내낸다: 캐시만 비우고(백업 저장소는 남겨둔 채) 다시 로드한다.
	Test.ClearCache(TEST_USER_ID)
	local reloaded = Test.Load(TEST_USER_ID)

	local pass = reloaded ~= nil
		and reloaded.inventory["mushroom_white"] == 1
		and reloaded.codex["mushroom_white"] ~= nil
		and reloaded.codex["mushroom_white"].count == 1
		and reloaded.stats["itemsCollected"] == 1
		and reloaded.lastSaved ~= nil

	if pass then
		local mode = if PlayerData.IsMemoryFallback() then "메모리 폴백" else "DataStore"
		print(`[FeatureTests] PASS: AddItem -> 저장 -> 재로드 검증 완료 (모드: {mode})`)
	else
		warn(`[FeatureTests] FAIL: 재로드된 데이터가 예상과 다릅니다 - {game:GetService("HttpService"):JSONEncode(reloaded)}`)
	end

	Test.Reset(TEST_USER_ID)
	return pass
end

local function runAll()
	print("[FeatureTests] 테스트 시작")
	local ok, result = pcall(runInventoryRoundTripTest)
	if not ok then
		warn(`[FeatureTests] FAIL: 테스트 실행 중 예외 발생 - {tostring(result)}`)
	end
	print("[FeatureTests] 테스트 종료")
end

function FeatureTests.Init()
	if ServerScriptService:GetAttribute("RunFeatureTests") == true then
		runAll()
	end

	ServerScriptService:GetAttributeChangedSignal("RunFeatureTests"):Connect(function()
		if ServerScriptService:GetAttribute("RunFeatureTests") == true then
			runAll()
		end
	end)
end

return FeatureTests
