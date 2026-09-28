-- Horse customiser (server): applies colours by "Role" attributes, validates client requests, saves per horse.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local TextService = game:GetService("TextService")

local remote = ReplicatedStorage:WaitForChild("HorseCustomize")
local TAG = "CustomHorse"
local MAX_DISTANCE = 45

local store
pcall(function() store = DataStoreService:GetDataStore("HorseAppearance_v1") end)

local function lum(c) return 0.299 * c.R + 0.587 * c.G + 0.114 * c.B end
local function clamp01(x) return math.clamp(x, 0, 1) end
local function scale(c, s) return Color3.new(clamp01(c.R * s), clamp01(c.G * s), clamp01(c.B * s)) end

local function partsByRole(horse)
	local roles = {}
	for _, d in ipairs(horse:GetDescendants()) do
		if d:IsA("BasePart") then
			local r = d:GetAttribute("Role")
			if r then
				roles[r] = roles[r] or {}
				table.insert(roles[r], d)
			end
		end
	end
	return roles
end

local function anchorPart(horse)
	return horse:FindFirstChild("HumanoidRootPart", true) or horse:FindFirstChild("Cube", true) or horse:FindFirstChildWhichIsA("BasePart", true)
end

-- remember each part's shade relative to its role's average, and the horse's starting colours
local function prepare(horse)
	local roles = partsByRole(horse)
	for role, list in pairs(roles) do
		local avg = 0
		for _, p in ipairs(list) do avg += lum(p.Color) end
		avg = math.max(avg / #list, 0.02)
		for _, p in ipairs(list) do
			if p:GetAttribute("Shade") == nil then p:SetAttribute("Shade", math.clamp(lum(p.Color) / avg, 0.55, 1.35)) end
		end
	end
	local function firstColor(role) local l = roles[role] if l and l[1] then return l[1].Color end end
	local function biggest(role)
		local l, best, bs = roles[role], nil, -1
		if l then for _, p in ipairs(l) do local s = p.Size.X * p.Size.Y * p.Size.Z if s > bs then bs = s best = p end end end
		return best and best.Color
	end
	if horse:GetAttribute("CoatColor") == nil then horse:SetAttribute("CoatColor", biggest("Coat") or Color3.fromRGB(140, 84, 52)) end
	if horse:GetAttribute("ManeColor") == nil then horse:SetAttribute("ManeColor", biggest("Mane") or Color3.fromRGB(40, 32, 28)) end
	if horse:GetAttribute("HoofColor") == nil then horse:SetAttribute("HoofColor", biggest("Hoof") or Color3.fromRGB(30, 28, 28)) end
	if horse:GetAttribute("SaddleColor") == nil then horse:SetAttribute("SaddleColor", Color3.fromRGB(120, 76, 48)) end
	if horse:GetAttribute("Socks") == nil then horse:SetAttribute("Socks", false) end
	if horse:GetAttribute("TackOn") == nil then horse:SetAttribute("TackOn", true) end
	-- remember the factory look so "reset" works
	for _, k in ipairs({"CoatColor", "ManeColor", "HoofColor", "SaddleColor", "Socks", "TackOn", "HorseName"}) do
		if horse:GetAttribute("Default_" .. k) == nil then horse:SetAttribute("Default_" .. k, horse:GetAttribute(k)) end
	end
end

local function updateNameSigns(horse)
	local stall = horse:GetAttribute("Stall")
	local name = horse:GetAttribute("HorseName") or ""
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("Stall") == stall and d.Name:sub(1, 10) == "NamePlate_" then
			local gui = d:FindFirstChild("NameGui")
			local label = gui and gui:FindFirstChild("Label")
			if label then label.Text = name end
		end
	end
	local a = anchorPart(horse)
	if a then
		local bb = a:FindFirstChild("HorseNameTag")
		if not bb then
			bb = Instance.new("BillboardGui")
			bb.Name = "HorseNameTag" bb.Size = UDim2.fromOffset(120, 32) bb.StudsOffset = Vector3.new(0, 5, 0) bb.AlwaysOnTop = false bb.MaxDistance = 60 bb.Parent = a
			local t = Instance.new("TextLabel") t.Name = "L" t.Size = UDim2.fromScale(1, 1) t.BackgroundTransparency = 1 t.TextScaled = true
			t.Font = Enum.Font.GothamBold t.TextColor3 = Color3.new(1, 1, 1) t.TextStrokeTransparency = 0.4 t.Parent = bb
		end
		bb.L.Text = name
	end
end

local function apply(horse)
	local coat = horse:GetAttribute("CoatColor")
	local mane = horse:GetAttribute("ManeColor")
	local hoof = horse:GetAttribute("HoofColor")
	local saddle = horse:GetAttribute("SaddleColor")
	if typeof(coat) ~= "Color3" or typeof(mane) ~= "Color3" or typeof(hoof) ~= "Color3" or typeof(saddle) ~= "Color3" then return end
	local socks = horse:GetAttribute("Socks") == true
	local tackOn = horse:GetAttribute("TackOn") ~= false
	for role, list in pairs(partsByRole(horse)) do
		for _, p in ipairs(list) do
			local shade = p:GetAttribute("Shade") or 1
			if role == "Coat" then p.Color = scale(coat, shade)
			elseif role == "Face" then p.Color = scale(coat:Lerp(Color3.new(0, 0, 0), 0.2), shade)
			elseif role == "Legs" then p.Color = socks and Color3.fromRGB(238, 234, 226) or scale(coat, 0.9 * shade)
			elseif role == "Mane" then p.Color = scale(mane, shade)
			elseif role == "Hoof" then p.Color = scale(hoof, shade)
			elseif role == "Saddle" then
				p.Color = saddle
				p.Transparency = tackOn and 0 or 1
			elseif role == "Tack" then
				p.Color = (p:GetAttribute("TackPart") == "Blanket") and saddle:Lerp(Color3.fromRGB(230, 60, 50), 0.35) or saddle
				p.Transparency = tackOn and 0 or 1
			end
		end
	end
end

local saveQueued = {}
local function save(horse)
	if not store or saveQueued[horse] then return end
	saveQueued[horse] = true
	task.delay(3, function()
		saveQueued[horse] = nil
		local id = horse:GetAttribute("HorseId")
		if not id then return end
		local function c3(c) return {c.R, c.G, c.B} end
		local data = {
			Coat = c3(horse:GetAttribute("CoatColor")), Mane = c3(horse:GetAttribute("ManeColor")), Hoof = c3(horse:GetAttribute("HoofColor")),
			Saddle = c3(horse:GetAttribute("SaddleColor")), Socks = horse:GetAttribute("Socks") == true, TackOn = horse:GetAttribute("TackOn") ~= false,
			Name = horse:GetAttribute("HorseName"),
		}
		pcall(function() store:SetAsync("Horse_" .. id, data) end)
	end)
end

local function load(horse)
	if not store then return end
	local id = horse:GetAttribute("HorseId")
	local ok, data = pcall(function() return store:GetAsync("Horse_" .. id) end)
	if ok and type(data) == "table" then
		local function fromTbl(t) if type(t) == "table" and #t == 3 then return Color3.new(t[1], t[2], t[3]) end end
		horse:SetAttribute("CoatColor", fromTbl(data.Coat) or horse:GetAttribute("CoatColor"))
		horse:SetAttribute("ManeColor", fromTbl(data.Mane) or horse:GetAttribute("ManeColor"))
		horse:SetAttribute("HoofColor", fromTbl(data.Hoof) or horse:GetAttribute("HoofColor"))
		horse:SetAttribute("SaddleColor", fromTbl(data.Saddle) or horse:GetAttribute("SaddleColor"))
		if type(data.Socks) == "boolean" then horse:SetAttribute("Socks", data.Socks) end
		if type(data.TackOn) == "boolean" then horse:SetAttribute("TackOn", data.TackOn) end
		if type(data.Name) == "string" then horse:SetAttribute("HorseName", data.Name) end
	end
end

local function setupHorse(horse)
	if not horse:IsA("Model") or horse:GetAttribute("_ready") then return end
	horse:SetAttribute("_ready", true)
	prepare(horse)
	load(horse)
	apply(horse) updateNameSigns(horse)
	horse.AttributeChanged:Connect(function(attr)
		if attr:sub(1, 1) == "_" or attr:sub(1, 8) == "Default_" then return end
		apply(horse) updateNameSigns(horse) save(horse)
	end)
	-- the prompt players use to open the menu
	local a = anchorPart(horse)
	if a and not a:FindFirstChild("CustomizePrompt") then
		local pp = Instance.new("ProximityPrompt")
		pp.Name = "CustomizePrompt" pp.ActionText = "꾸미기" pp.ObjectText = horse:GetAttribute("HorseName") or "말"
		pp.HoldDuration = 0 pp.MaxActivationDistance = 14 pp.RequiresLineOfSight = false pp.KeyboardKeyCode = Enum.KeyCode.E
		pp.Parent = a
		pp.Triggered:Connect(function(player) remote:FireClient(player, "open", horse) end)
		horse.AttributeChanged:Connect(function(attr) if attr == "HorseName" then pp.ObjectText = horse:GetAttribute("HorseName") or "말" end end)
	end
end

for _, h in ipairs(CollectionService:GetTagged(TAG)) do task.spawn(setupHorse, h) end
CollectionService:GetInstanceAddedSignal(TAG):Connect(function(h) task.spawn(setupHorse, h) end)

local lastRequest = {}
remote.OnServerEvent:Connect(function(player, horse, data)
	if typeof(horse) ~= "Instance" or not horse:IsA("Model") or not CollectionService:HasTag(horse, TAG) or type(data) ~= "table" then return end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local a = anchorPart(horse)
	if not hrp or not a or (hrp.Position - a.Position).Magnitude > MAX_DISTANCE then return end
	local now = os.clock()
	if lastRequest[player] and now - lastRequest[player] < 0.08 then return end
	lastRequest[player] = now
	for _, key in ipairs({"CoatColor", "ManeColor", "HoofColor", "SaddleColor"}) do
		if typeof(data[key]) == "Color3" then horse:SetAttribute(key, data[key]) end
	end
	if type(data.Socks) == "boolean" then horse:SetAttribute("Socks", data.Socks) end
	if type(data.TackOn) == "boolean" then horse:SetAttribute("TackOn", data.TackOn) end
	if type(data.Reset) == "boolean" and data.Reset then
		for _, k in ipairs({"CoatColor", "ManeColor", "HoofColor", "SaddleColor", "Socks", "TackOn", "HorseName"}) do horse:SetAttribute(k, horse:GetAttribute("Default_" .. k)) end
	end
	if type(data.HorseName) == "string" then
		local name = data.HorseName:sub(1, 12)
		local ok, filtered = pcall(function()
			return TextService:FilterStringAsync(name, player.UserId):GetNonChatStringForBroadcastAsync()
		end)
		if ok and filtered and #filtered > 0 then horse:SetAttribute("HorseName", filtered) end
	end
end)
Players.PlayerRemoving:Connect(function(p) lastRequest[p] = nil end)
