--!strict
-- 효과음 재생 헬퍼. SoundId는 전부 빈 값(placeholder)이다 — 이 개발 환경에서는 Roblox
-- 오디오 카탈로그에 접근할 수 없어 실제로 들어보고 검증된 효과음 ID를 넣을 수 없었다.
-- 근거 없이 아무 숫자나 넣으면 엉뚱하거나 어울리지 않는 소리가 재생될 수 있어, 대신
-- 빈 값이면 조용히 아무 소리도 내지 않도록(에러 없이) 만들어 뒀다.
-- 원하는 효과음이 생기면 아래 표의 값만 "rbxassetid://<번호>" 형태로 채우면 바로 동작한다.

local SoundService = game:GetService("SoundService")

export type SfxName =
	"ShopOpen"
	| "Purchase"
	| "Sell"
	| "PurchaseError"
	| "TabSwitch"
	| "FishingBite"
	| "FishingCatch"
	| "FishingMiss"
	| "HorseCare"
	| "QuestComplete"

local SOUND_IDS: { [SfxName]: string } = {
	ShopOpen = "",
	Purchase = "",
	Sell = "",
	PurchaseError = "",
	TabSwitch = "",
	FishingBite = "",
	FishingCatch = "",
	FishingMiss = "",
	HorseCare = "",
	QuestComplete = "",
}

local VOLUME: { [SfxName]: number } = {
	ShopOpen = 0.5,
	Purchase = 0.6,
	Sell = 0.6,
	PurchaseError = 0.4,
	TabSwitch = 0.3,
	FishingBite = 0.6,
	FishingCatch = 0.6,
	FishingMiss = 0.4,
	HorseCare = 0.5,
	QuestComplete = 0.6,
}

local SFX = {}

function SFX.Play(name: SfxName)
	local id = SOUND_IDS[name]
	if id == "" then
		return
	end

	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = VOLUME[name] or 0.5
	sound.Parent = SoundService
	sound.Ended:Connect(function()
		sound:Destroy()
	end)

	local ok = pcall(function()
		sound:Play()
	end)
	if not ok then
		sound:Destroy()
	end
end

return SFX
