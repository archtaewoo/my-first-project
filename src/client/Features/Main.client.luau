--!strict
-- 클라이언트 진입점. 서버가 보낸 데이터를 받아 표시만 한다 (읽기 전용).

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Features"):WaitForChild("Remotes"))
local ItemDatabase = require(ReplicatedStorage:WaitForChild("Features"):WaitForChild("ItemDatabase"))
local Types = require(ReplicatedStorage:WaitForChild("Features"):WaitForChild("Types"))

local Toast = require(script.Parent.UI.Toast)
local CodexUI = require(script.Parent.UI.CodexUI)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

Toast.Init(playerGui)
CodexUI.Init(playerGui)

-- 한국어 받침에 맞춰 "을"/"를"을 고른다 (예: "버섯을", "꽃을").
local function withEul(korean: string): string
	local lastCharStart = utf8.offset(korean, -1)
	if not lastCharStart then
		return korean .. "를"
	end
	local ok, codepoint = pcall(utf8.codepoint, korean, lastCharStart)
	if not ok or codepoint < 0xAC00 or codepoint > 0xD7A3 then
		return korean .. "를"
	end
	local hasBatchim = (codepoint - 0xAC00) % 28 ~= 0
	return korean .. (hasBatchim and "을" or "를")
end

local inventoryCache: { [string]: number } = {}
local codexCache: { [string]: any } = {}

local inventorySync = Remotes.Get("InventorySync")
local inventoryDelta = Remotes.Get("InventoryDelta")
local itemAdded = Remotes.Get("ItemAdded")

inventorySync.OnClientEvent:Connect(function(payload: Types.InventorySyncPayload)
	inventoryCache = payload.inventory
	codexCache = payload.codex
	CodexUI.SetData(inventoryCache, codexCache)
end)

inventoryDelta.OnClientEvent:Connect(function(payload: Types.InventoryDeltaPayload)
	inventoryCache[payload.itemId] = payload.newCount
	CodexUI.UpdateItem(payload.itemId, payload.newCount)
end)

itemAdded.OnClientEvent:Connect(function(payload: Types.ItemAddedPayload)
	local def = ItemDatabase.Get(payload.itemId)
	local displayName = def and def.displayName or payload.itemId

	Toast.Show(`{withEul(displayName)} 얻었어요 +{payload.amount}`)
	if payload.isNewDiscovery then
		Toast.Show("새로 발견했어요!", true)
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.B then
		CodexUI.Toggle()
	end
end)
