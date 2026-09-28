--!strict
-- 서버 진입점. ModuleScript는 스스로 실행되지 않으므로 여기서 require 하고 Init()을 호출한다.
-- 순서: PlayerData(다른 모든 기능이 의존) -> CollectibleService -> FeatureTests

local PlayerData = require(script.Parent.PlayerData)
local CollectibleService = require(script.Parent.CollectibleService)
local FeatureTests = require(script.Parent.FeatureTests)

PlayerData.Init()
CollectibleService.Init()
FeatureTests.Init()

print("[Main] 힐링 숲 서버 기반 기능 초기화 완료")
