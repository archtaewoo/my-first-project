--!strict
-- 서버 진입점. ModuleScript는 스스로 실행되지 않으므로 여기서 require 하고 Init()을 호출한다.
-- 순서: Remotes(플레이어 접속과 무관하게 즉시 생성) -> PlayerData -> MarketService -> FishingService -> CollectibleService -> FeatureTests

local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Features"):WaitForChild("Remotes"))
local PlayerData = require(script.Parent.PlayerData)
local MarketService = require(script.Parent.MarketService)
local FishingService = require(script.Parent.FishingService)
local CollectibleService = require(script.Parent.CollectibleService)
local FeatureTests = require(script.Parent.FeatureTests)

-- 플레이어가 아직 없어도(예: RunFeatureTests만 켠 서버 전용 테스트) RemoteEvent가 먼저 만들어지도록
-- PlayerData.Init()보다 먼저, 무조건 호출한다. 안 그러면 클라이언트의 WaitForChild가
-- 첫 플레이어의 PlayerAdded -> PlayerData.Load 호출을 기다리다 무한 대기에 빠질 수 있다.
Remotes.EnsureAll()

PlayerData.Init()
MarketService.Init()
FishingService.Init()
CollectibleService.Init()
FeatureTests.Init()

print("[Main] 힐링 숲 서버 기반 기능 초기화 완료")
