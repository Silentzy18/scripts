-- Fixed version — changes from original:
-- FIX 1: isMobAlive defined BEFORE refreshMobData (forward reference crash)
-- FIX 2: upgradeSelected declared BEFORE saveSettings (nil reference)
-- FIX 3: SLbl safe fallback if Win._status doesn't exist
-- FIX 4: TweenInfo.new instead of TweenService.new
-- FIX 5: Enum.TeleportState.RequestedByServer → ~= Enum.TeleportState.None

local NEXUSLIB_URL = "https://raw.githubusercontent.com/headshot7535-png/Nexuslib/main/Nexuslib"
local SCRIPT_URL = "https://raw.githubusercontent.com/Silentzy18/scripts/refs/heads/main/meleerng.lua"

local Lib
if readfile and pcall then
    local ok, data = pcall(readfile, "NexusLib.lua")
    if ok and type(data) == "string" and #data > 500 then
        local loadOk, result = pcall(loadstring, data)
        if loadOk then Lib = result() end
    end
end
if not Lib then
    local ok, err = pcall(function()
        Lib = loadstring(game:HttpGet(NEXUSLIB_URL))()
    end)
    if not ok or not Lib then
        error("[MeleeRNG] NexusLib failed to load: " .. tostring(err))
    end
end

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local VirtualUser      = game:GetService("VirtualUser")
local Lighting         = game:GetService("Lighting")
local HttpService      = game:GetService("HttpService")
local RS               = game:GetService("ReplicatedStorage")
local CollectionService= game:GetService("CollectionService")

task.wait(2)
local LP
for _ = 1, 60 do
    LP = Players.LocalPlayer
    if LP and LP:FindFirstChildOfClass("PlayerGui") then break end
    task.wait(0.3)
end
if not LP then error("[MeleeRNG] LocalPlayer not ready") end

_G.MeleeRNG_Gen = (_G.MeleeRNG_Gen or 0) + 1
local GEN = _G.MeleeRNG_Gen

local _conns   = {}
local _threads = {}
local _stopped = false

local function addConn(c)   _conns[#_conns+1]    = c end
local function addThread(t) _threads[#_threads+1] = t end
local function cleanupAll()
    _stopped = true
    for _, c in ipairs(_conns)   do pcall(function() c:Disconnect() end) end
    for _, t in ipairs(_threads) do pcall(function() task.cancel(t) end) end
    _conns = {}; _threads = {}
end

local function getChar()  return LP.Character end
local function getRoot()  local c=getChar() return c and c:FindFirstChild("HumanoidRootPart") end
local function getHuman() local c=getChar() return c and c:FindFirstChildOfClass("Humanoid") end
local function alive()    local h=getHuman() return h and h.Health > 0 end

local _ls = nil
local function getLS()
    if _ls and _ls.Parent then return _ls end
    _ls = LP:FindFirstChild("leaderstats")
    return _ls
end
local _cachedStats = {}
local function getCachedStat(name)
    if _cachedStats[name] and _cachedStats[name].Parent then
        return _cachedStats[name].Value
    end
    local ls = getLS(); if not ls then return 0 end
    for _, child in ipairs(ls:GetChildren()) do
        if child.Name:find(name, 1, true) then
            _cachedStats[name] = child
            return child.Value
        end
    end
    return 0
end
local function getKills()   return getCachedStat("Kills") end
local function getMana()    return getCachedStat("Mana") end
local function getSP()      return getCachedStat("SP") end
local function getAscends() return getCachedStat("Ascends") end

local _remotes = {}
local function R(name)
    if _remotes[name] and _remotes[name].Parent then return _remotes[name] end
    local r = RS:FindFirstChild("Remotes")
    if not r then return nil end
    _remotes[name] = r:FindFirstChild(name)
    return _remotes[name]
end
local function fireR(name, ...)
    local r = R(name); if not r then return end
    local args = table.pack(...)
    return pcall(function() r:FireServer(table.unpack(args, 1, args.n)) end)
end
local function invokeR(name, ...)
    local r = R(name); if not r then return nil end
    local args = table.pack(...)
    local ok, res = pcall(function() return r:InvokeServer(table.unpack(args, 1, args.n)) end)
    return ok and res or nil
end

-- FIX 1: isMobAlive defined BEFORE refreshMobData
local function isMobAlive(model)
    if not (model and model.Parent) then return false end
    local hrp = model:FindFirstChild("HumanoidRootPart")
    return hrp ~= nil and model:GetAttribute("ID") ~= nil
end

local MOB_DATA = {}
local function refreshMobData()
    MOB_DATA = {}
    local mobsFolder = workspace:FindFirstChild("Mobs")
    if not mobsFolder then return end
    for _, model in ipairs(mobsFolder:GetChildren()) do
        if model:IsA("Model") and isMobAlive(model) then
            local hrp = model:FindFirstChild("HumanoidRootPart")
            local id  = model:GetAttribute("ID") or model.Name
            MOB_DATA[model] = {
                id=id, model=model, root=hrp,
                boss=model:GetAttribute("Boss") == true,
                megaBoss=model:GetAttribute("MegaBoss") == true,
            }
        end
    end
end

local function getNearestMob(filterFn)
    local root = getRoot(); if not root then return nil end
    local mobsFolder = workspace:FindFirstChild("Mobs")
    if not mobsFolder then return nil end
    local best, bestDist = nil, math.huge
    for _, model in ipairs(mobsFolder:GetChildren()) do
        if model:IsA("Model") and isMobAlive(model) then
            if not filterFn or filterFn(model) then
                local hrp = model:FindFirstChild("HumanoidRootPart")
                local d = (root.Position - hrp.Position).Magnitude
                if d < bestDist then bestDist = d; best = model end
            end
        end
    end
    return best, bestDist
end

local function countAliveMobs()
    local mobsFolder = workspace:FindFirstChild("Mobs"); if not mobsFolder then return 0 end
    local n = 0
    for _, m in pairs(mobsFolder:GetChildren()) do
        if m:IsA("Model") and isMobAlive(m) then n = n + 1 end
    end
    return n
end

local _dmgMulti = 0
local function getDmgMulti()
    local v = invokeR("GetUpgradeValue", "Damage Multiplier")
    if type(v) == "number" then _dmgMulti = v end
    return _dmgMulti
end

local states = {
    autoEquipBest=false, autoAscend=false, farmBoss=true,
    farmMegaBoss=false, skipRegular=false, noclip=false,
    godMode=false, fly=false, infJump=false, antiAfk=false,
    fullBright=false, espMobs=false, autoSave=true,
    showAutoRaid=false, showHideMobs=false, autoReExec=false,
    hitboxPulse=false, hitboxDutyCycle=2,
}

local walkSpeedVal  = 16
local hitboxSize    = 500
local flyBV, flyBG
local espBillboards = {}

-- FIX 2: upgradeSelected declared BEFORE saveSettings
local upgradeSelected = {}

local SETTINGS_FILE = "meleernq_settings.json"
local function saveSettings()
    pcall(function()
        local t = {}
        for k, v in pairs(states) do t[k] = v end
        t.walkSpeedVal    = walkSpeedVal
        t.upgradeSelected = upgradeSelected
        t.hitboxSize      = hitboxSize
        writefile(SETTINGS_FILE, HttpService:JSONEncode(t))
    end)
end
local function forceSave() saveSettings() end

local LS = {}
pcall(function()
    if isfile and isfile(SETTINGS_FILE) then
        local ok, d = pcall(function() return HttpService:JSONDecode(readfile(SETTINGS_FILE)) end)
        if ok and type(d) == "table" then LS = d end
    end
end)
for k in pairs(states) do if LS[k] ~= nil then states[k] = LS[k] end end
if LS.walkSpeedVal then walkSpeedVal = LS.walkSpeedVal end
if LS.autoSave     then states.autoSave     = LS.autoSave     end
if LS.showAutoRaid then states.showAutoRaid = LS.showAutoRaid end
if LS.showHideMobs then states.showHideMobs = LS.showHideMobs end
if type(LS.upgradeSelected) == "table" then upgradeSelected = LS.upgradeSelected end
if LS.hitboxSize ~= nil then
    local n = tonumber(LS.hitboxSize)
    if n then
        n = math.max(10, math.min(100000, math.floor(n)))
        if n >= 50000 then n = 500 elseif n >= 15000 then n = 350 end
        hitboxSize = n
    end
end

local Win  = Lib:Window({ title = "⚔️  Melee RNG  v1.0" })
-- FIX 3: safe fallback for SLbl
local SLbl = Win._status or setmetatable({}, {__newindex=function() end})

local MoveTab = Win:Tab("🚀", "Movement")
local ESPTab  = Win:Tab("👁️", "ESP")
local AreaTab = Win:Tab("🗺️", "Areas")
local MiscTab = Win:Tab("⚙️", "Misc")
local UpgTab  = Win:Tab("⬆️", "Auto Upgrade")
pcall(function() Win:ChatTab() end)

local C = {
    bg=Color3.fromRGB(8,10,18), card=Color3.fromRGB(15,19,32),
    border=Color3.fromRGB(25,35,60), accent=Color3.fromRGB(0,180,255),
    accentD=Color3.fromRGB(0,100,180), text=Color3.fromRGB(210,225,245),
    sub=Color3.fromRGB(60,80,120), green=Color3.fromRGB(0,200,100),
    purple=Color3.fromRGB(160,80,255), red=Color3.fromRGB(255,70,70),
    orange=Color3.fromRGB(255,160,30), gold=Color3.fromRGB(255,210,50),
}

local function makeStatusCard(page, lo, titleStr, accentCol)
    accentCol = accentCol or C.accent
    local Card = Instance.new("Frame", page)
    Card.Size = UDim2.new(1,-10,0,88)
    Card.BackgroundColor3 = C.card; Card.BorderSizePixel = 0; Card.LayoutOrder = lo
    Instance.new("UICorner", Card).CornerRadius = UDim.new(0,10)
    local stroke = Instance.new("UIStroke", Card); stroke.Color = C.border; stroke.Thickness = 1
    local function lbl(txt, xOff, yOff, h, col, font, size)
        local L = Instance.new("TextLabel", Card)
        L.Text = txt; L.Size = UDim2.new(1,-110,0,h)
        L.Position = UDim2.new(0, xOff or 14, 0, yOff or 8)
        L.BackgroundTransparency = 1; L.TextColor3 = col or C.text
        L.Font = font or Enum.Font.GothamBold; L.TextSize = size or 12
        L.TextXAlignment = Enum.TextXAlignment.Left
        return L
    end
    local Title  = lbl(titleStr, 14, 8,  18, C.text, Enum.Font.GothamBold, 13)
    local Status = lbl("OFF · Idle", 14, 28, 13, C.sub, Enum.Font.Code, 9)
    local Info1  = lbl("", 14, 44, 12, C.sub, Enum.Font.Code, 9)
    local Info2  = lbl("", 14, 58, 12, accentCol, Enum.Font.Code, 9)
    local Pill = Instance.new("Frame", Card)
    Pill.Size = UDim2.new(0,44,0,24); Pill.Position = UDim2.new(1,-50,0.5,-12)
    Pill.BackgroundColor3 = C.border; Pill.BorderSizePixel = 0
    Instance.new("UICorner", Pill).CornerRadius = UDim.new(1,0)
    local Thumb = Instance.new("Frame", Pill)
    Thumb.Size = UDim2.new(0,18,0,18); Thumb.Position = UDim2.new(0,3,0.5,-9)
    Thumb.BackgroundColor3 = C.sub; Thumb.BorderSizePixel = 0
    Instance.new("UICorner", Thumb).CornerRadius = UDim.new(1,0)
    local PBtn = Instance.new("TextButton", Pill)
    PBtn.Size = UDim2.new(1,0,1,0); PBtn.BackgroundTransparency = 1; PBtn.Text = ""; PBtn.ZIndex = 3
    -- FIX 4: TweenInfo.new (not TweenService.new)
    local ti = TweenInfo.new(0.18, Enum.EasingStyle.Quad)
    local function setState(on)
        if on then
            TweenService:Create(Pill,  ti, {BackgroundColor3 = accentCol}):Play()
            TweenService:Create(Thumb, ti, {Position=UDim2.new(0,23,0.5,-9), BackgroundColor3=accentCol}):Play()
            stroke.Color = accentCol; Title.TextColor3 = accentCol
        else
            TweenService:Create(Pill,  ti, {BackgroundColor3 = C.border}):Play()
            TweenService:Create(Thumb, ti, {Position=UDim2.new(0,3,0.5,-9), BackgroundColor3=C.sub}):Play()
            stroke.Color = C.border; Title.TextColor3 = C.text; Status.Text = "OFF · Idle"
        end
    end
    return {Card=Card,Title=Title,Status=Status,Info1=Info1,Info2=Info2,
            Pill=Pill,PBtn=PBtn,stroke=stroke,setState=setState}
end

local UPGRADE_PRICES = {
    ["Weapons Equipped"]       = function(p) return 1 + p^2 * p end,
    ["Damage Multiplier"]      = function(p) return p^4 + 5 end,
    ["Enemy Spawn Rate"]       = function(p) return math.floor(p^1.5 + 10) end,
    ["Enemy Limit"]            = function(p) return math.round(p^1.1 + 1) end,
    ["Mana Multiplier"]        = function(p) return math.round(8 + p^2.35 * p) end,
    ["Spin Speed"]             = function(p) return p^4 + 5 end,
    ["RNG Luck"]               = function(p) return p^4 + 5 end,
    ["Kill Multiplier"]        = function(p) return math.round(p^3.9 + 100) end,
    ["Skill Point Multiplier"] = function(p) return math.round(p^4.5) + 1 end,
    ["Boss Spawn Chance"]      = function(p) return math.round(p^4) + 150 end,
}
local UPGRADE_ORDER = {
    "Weapons Equipped","Damage Multiplier","Enemy Spawn Rate","Enemy Limit",
    "Mana Multiplier","Spin Speed","RNG Luck","Kill Multiplier",
    "Skill Point Multiplier","Boss Spawn Chance",
}

local autoUpgradeActive = false
local upgStatusLbl = UpgTab:Label("Status: OFF")
local upgInfoLbl   = UpgTab:Label("SP: — | Next: —")
local function setAutoUpgrade(on)
    autoUpgradeActive = on
    upgStatusLbl.Set(on and "Status: ON - Watching SP..." or "Status: OFF")
end
UpgTab:Button("⚡","Toggle Auto Upgrade","Start/stop the auto upgrade loop",C.gold,function()
    autoUpgradeActive = not autoUpgradeActive; setAutoUpgrade(autoUpgradeActive)
end)
UpgTab:Label("Buys checked upgrades when SP is sufficient.")
UpgTab:Section("Select Upgrades to Auto-Buy")

local upgToggles = {}
for _, name in ipairs(UPGRADE_ORDER) do
    local isSel = upgradeSelected[name] == true
    local n2 = name
    local t = UpgTab:Toggle(name,"Auto-buy when SP is sufficient",isSel,function(on)
        upgradeSelected[n2] = on; saveSettings()
    end)
    upgToggles[name] = t
end
UpgTab:Button("✅","Select All / None","Toggle all upgrades on or off",C.green,function()
    local anyOff = false
    for _, n in ipairs(UPGRADE_ORDER) do if not upgradeSelected[n] then anyOff=true; break end end
    for _, n in ipairs(UPGRADE_ORDER) do
        upgradeSelected[n] = anyOff
        if upgToggles[n] then pcall(function() upgToggles[n].Set(anyOff) end) end
    end
    saveSettings()
end)

addThread(task.spawn(function()
    task.wait(2)
    while true do
        if GEN ~= _G.MeleeRNG_Gen then break end
        if not autoUpgradeActive then task.wait(2); continue end
        local sp = getSP(); local nextName, nextPrice = "none", math.huge
        for _, name in ipairs(UPGRADE_ORDER) do
            if upgradeSelected[name] then
                local lvl=0; pcall(function() lvl = invokeR("GetUpgradeLevel",name) or 0 end)
                local priceFn = UPGRADE_PRICES[name]
                local price   = priceFn and priceFn(lvl+1) or math.huge
                if price < nextPrice then nextPrice=price; nextName=name end
            end
        end
        upgInfoLbl.Set(string.format("SP: %s | Next: %s (%s SP)",
            tostring(sp), nextName,
            nextPrice==math.huge and "?" or tostring(math.floor(nextPrice))))
        task.wait(3)
    end
end))

addThread(task.spawn(function()
    while true do
        if GEN ~= _G.MeleeRNG_Gen then break end
        task.wait(1)
        if not autoUpgradeActive then continue end
        local sp=getSP(); local bought=false; local unlocked={}
        pcall(function()
            local u = invokeR("GetUnlockedUpgrades")
            if type(u)=="table" then unlocked=u end
        end)
        for _, name in ipairs(UPGRADE_ORDER) do
            if not upgradeSelected[name] then continue end
            if not unlocked[name] then continue end
            local lvl=0; pcall(function() lvl=invokeR("GetUpgradeLevel",name) or 0 end)
            local priceFn=UPGRADE_PRICES[name]; local price=priceFn and priceFn(lvl+1) or math.huge
            if sp >= price then
                local ok=invokeR("BuyUpgrade",name)
                if ok then
                    bought=true; sp=getCachedStat("SP")
                    upgStatusLbl.Set(string.format("✓ Bought: %s Lv%d→Lv%d | SP: %s",name,lvl,lvl+1,tostring(sp)))
                    SLbl.Text = "⬆️ Upgraded: "..name; _cachedStats["SP"]=nil
                end
            end
        end
        if not bought then
            local nextName,nextPrice="none",math.huge
            for _, name in ipairs(UPGRADE_ORDER) do
                if upgradeSelected[name] and unlocked[name] then
                    local lvl=0; pcall(function() lvl=invokeR("GetUpgradeLevel",name) or 0 end)
                    local priceFn=UPGRADE_PRICES[name]; local price=priceFn and priceFn(lvl+1) or math.huge
                    if price<nextPrice then nextPrice=price; nextName=name end
                end
            end
            upgStatusLbl.Set(string.format("⏳ Next: %s | Need %d SP | Have %d",
                nextName, nextPrice==math.huge and 0 or nextPrice, sp))
        end
    end
end))

local HITBOX_BIG_DEFAULT=500; local HITBOX_BIG_LIGHT=350; local HITBOX_TINY_STUDS=0.01
local hitboxExpanded=false; local hitboxOrigSizes={}; local _pulseConn=nil
local _TINY_V=Vector3.new(HITBOX_TINY_STUDS,HITBOX_TINY_STUDS,HITBOX_TINY_STUDS)
local _pulseActive=false; local _pulsePhase=false; local _hitboxCache={}; local _hitboxCacheDirty=true
local _pulseBigVec=Vector3.new(hitboxSize,hitboxSize,hitboxSize); local HITBOX_DUTY_MAX=12

MoveTab:Section("Hitbox Pulse")
MoveTab:Label("BIG ~500 studs for best KPM. Tiny=0.01. CanTouch must stay on.")
MoveTab:Label("Duty N: 1 Heartbeat BIG then N-1 tiny. Lower N = more Touched events.")

local hitboxDutySlider, hitboxRadiusSlider
hitboxDutySlider = MoveTab:Slider("Big phase duty (1 big / N heartbeats)","Higher N = calmer physics.",
    {min=2,max=HITBOX_DUTY_MAX,default=math.clamp(math.floor(tonumber(states.hitboxDutyCycle) or 2),2,HITBOX_DUTY_MAX),
     format=function(v) return "1 big / "..tostring(math.floor(v)) end},
    function(v) states.hitboxDutyCycle=math.clamp(math.floor(v),2,HITBOX_DUTY_MAX); saveSettings() end)

hitboxRadiusSlider = MoveTab:Slider("BIG size (studs)","~500 is sweet spot.",
    {min=10,max=100000,default=hitboxSize,format=function(v) return math.floor(v).." studs" end},
    function(v) hitboxSize=math.floor(v); _pulseBigVec=Vector3.new(hitboxSize,hitboxSize,hitboxSize); saveSettings() end)

local function applyHitboxPulsePreset(title,duty,radius)
    local d=math.clamp(math.floor(duty),2,HITBOX_DUTY_MAX)
    local r=math.clamp(math.floor(radius),10,100000)
    if hitboxDutySlider and type(hitboxDutySlider.Set)=="function"
        and hitboxRadiusSlider and type(hitboxRadiusSlider.Set)=="function" then
        hitboxDutySlider.Set(d); hitboxRadiusSlider.Set(r)
    else
        states.hitboxDutyCycle=d; hitboxSize=r; _pulseBigVec=Vector3.new(r,r,r)
    end
    saveSettings(); SLbl.Text = "⚡ Preset: "..title
end

MoveTab:Label("Presets:")
MoveTab:Button("⚡","Max farm — duty 2","BIG 500 highest flip rate",C.green,function()
    applyHitboxPulsePreset("Max farm — duty 2",2,HITBOX_BIG_DEFAULT) end)
MoveTab:Button("⚖️","Balanced — duty 5","BIG 500 lighter physics",C.accent,function()
    applyHitboxPulsePreset("Balanced — duty 5",5,HITBOX_BIG_DEFAULT) end)
MoveTab:Button("🐢","Low lag — duty 10","BIG 350 rare BIG frames",C.sub,function()
    applyHitboxPulsePreset("Low lag — duty 10",10,HITBOX_BIG_LIGHT) end)

local function getPlayerWeaponFolder() return workspace:FindFirstChild(LP.Name) end
local function restoreHitboxes()
    for hb, origSize in pairs(hitboxOrigSizes) do
        pcall(function() if hb and hb.Parent then hb.Size=origSize end end)
    end
    hitboxOrigSizes={}
end
local function rebuildHitboxCache()
    _hitboxCache={}
    local folder=getPlayerWeaponFolder(); if not folder then return end
    for _, weapon in ipairs(folder:GetChildren()) do
        if weapon:IsA("Model") then
            for _, desc in pairs(weapon:GetDescendants()) do
                if desc:IsA("BasePart") and desc.Name=="Hitbox" then
                    if not hitboxOrigSizes[desc] then hitboxOrigSizes[desc]=desc.Size end
                    desc.CanTouch=true; _hitboxCache[#_hitboxCache+1]=desc
                end
            end
        end
    end
    _hitboxCacheDirty=false
end

addThread(task.spawn(function()
    local lastCount=0
    while true do
        if GEN~=_G.MeleeRNG_Gen then break end
        task.wait(2)
        local folder=getPlayerWeaponFolder()
        local count=folder and #folder:GetChildren() or 0
        if count~=lastCount then lastCount=count; _hitboxCacheDirty=true end
    end
end))

local function setHitboxPulse(on)
    _pulseActive=on; hitboxExpanded=on
    if on then
        _pulseBigVec=Vector3.new(hitboxSize,hitboxSize,hitboxSize); _hitboxCacheDirty=true
        if _pulseConn then _pulseConn:Disconnect() end
        local _dutyTick=0
        _pulseConn=RunService.Heartbeat:Connect(function()
            if GEN~=_G.MeleeRNG_Gen or not _pulseActive then
                if _pulseConn then _pulseConn:Disconnect(); _pulseConn=nil end; return
            end
            if _hitboxCacheDirty then rebuildHitboxCache() end
            _dutyTick=_dutyTick+1
            local duty=math.clamp(math.floor(tonumber(states.hitboxDutyCycle) or 2),2,HITBOX_DUTY_MAX)
            _pulsePhase=((_dutyTick-1)%duty)==0
            local newSize=_pulsePhase and _pulseBigVec or _TINY_V
            local hCache=_hitboxCache; local nh=#hCache
            for i=1,nh do
                local hb=hCache[i]
                if hb and hb.Parent then
                    if hb.Size~=newSize then hb.Size=newSize end
                else _hitboxCacheDirty=true end
            end
        end)
        addConn(_pulseConn); rebuildHitboxCache()
        SLbl.Text=string.format("⚡ Pulse ON | %.0f studs | %d hitboxes | duty 1/%d",
            hitboxSize,#_hitboxCache,
            math.clamp(math.floor(tonumber(states.hitboxDutyCycle) or 2),2,HITBOX_DUTY_MAX))
    else
        if _pulseConn then _pulseConn:Disconnect(); _pulseConn=nil end
        for i=1,#_hitboxCache do
            local hb=_hitboxCache[i]
            if hb and hb.Parent and hitboxOrigSizes[hb] then hb.Size=hitboxOrigSizes[hb] end
        end
        _hitboxCache={}; SLbl.Text="Pulse OFF — hitboxes restored"
    end
end

local hitboxPulseToggle=MoveTab:Toggle("⚡ Hitbox Pulse","BIG/tiny duty cycle on weapon Hitboxes.",states.hitboxPulse,function(on)
    states.hitboxPulse=on; setHitboxPulse(on); saveSettings()
end)
task.defer(function()
    if states.hitboxPulse then
        setHitboxPulse(true)
        pcall(function() if hitboxPulseToggle and hitboxPulseToggle.Set then hitboxPulseToggle.Set(true) end end)
    end
end)

MoveTab:Button("🔍","Print Hitbox Sizes","Lists all weapons and current Hitbox sizes",C.sub,function()
    local folder=getPlayerWeaponFolder()
    if not folder then SLbl.Text="⚠ workspace."..LP.Name.." not found"; return end
    local count=0
    for _, weapon in ipairs(folder:GetChildren()) do
        if weapon:IsA("Model") then
            for _, desc in pairs(weapon:GetDescendants()) do
                if desc:IsA("BasePart") and desc.Name=="Hitbox" then
                    count=count+1
                    print(string.format("[MeleeRNG] Hitbox: %-30s  Size: %.1f x %.1f x %.1f",
                        weapon.Name,desc.Size.X,desc.Size.Y,desc.Size.Z))
                end
            end
        end
    end
    if count==0 then print("[MeleeRNG] No Hitbox parts found in workspace."..LP.Name) end
    SLbl.Text=count.." hitboxes found — check output"
end)

MoveTab:Section("Walk Speed")
MoveTab:Slider("Walk Speed","Default 16 · Max 250",{min=0,max=250,default=walkSpeedVal},function(v)
    walkSpeedVal=math.floor(v); saveSettings()
    local h=getHuman(); if h then h.WalkSpeed=walkSpeedVal end
end)

MoveTab:Section("Hacks")
MoveTab:Toggle("🚀 Infinite Jump","Jump while airborne",states.infJump,function(on) states.infJump=on; saveSettings() end)
MoveTab:Toggle("👻 No Clip","Walk through walls",states.noclip,function(on) states.noclip=on; saveSettings() end)
MoveTab:Toggle("🛡️ God Mode","Lock health at max",states.godMode,function(on) states.godMode=on; saveSettings() end)
MoveTab:Toggle("🦅 Fly","WASD + E/Q to go up/down",states.fly,function(on)
    states.fly=on; saveSettings()
    if not on then
        if flyBV then flyBV:Destroy(); flyBV=nil end
        if flyBG then flyBG:Destroy(); flyBG=nil end
    end
end)
MoveTab:Toggle("⏱️ Anti AFK","Prevents auto-kick",states.antiAfk,function(on) states.antiAfk=on; saveSettings() end)
MoveTab:Toggle("💡 Full Bright","Max ambient light, remove fog",states.fullBright,function(on) states.fullBright=on; saveSettings() end)

MoveTab:Section("Actions")
MoveTab:Button("📋","Print Position","Prints XYZ + current area",C.accent,function()
    local r=getRoot(); if not r then SLbl.Text="No character"; return end
    local p=r.Position; local area=invokeR("GetArea")
    local areaName=area and area.Name or "Unknown"
    local msg=string.format("X=%.1f Y=%.1f Z=%.1f | Area: %s | Kills: %s",p.X,p.Y,p.Z,areaName,tostring(getKills()))
    print("[MeleeRNG] "..msg); SLbl.Text=msg
end)
MoveTab:Button("🔄","Respawn","Kills character",C.red,function()
    local h=getHuman(); if h then h.Health=0 end
end)
MoveTab:Button("🌀","Fire Nearest Machine","Teleports to & fires nearest ProximityPrompt",C.green,function()
    local root=getRoot(); if not root then SLbl.Text="No character"; return end
    local machines=workspace:FindFirstChild("Machines")
    if not machines then SLbl.Text="⚠ workspace.Machines not found"; return end
    local best,bestDist,bestPrompt=nil,math.huge,nil
    for _, machine in pairs(machines:GetChildren()) do
        local prompt=machine:FindFirstChild("ProximityPrompt")
        if prompt and prompt:IsA("ProximityPrompt") then
            local hrp=machine:FindFirstChild("HumanoidRootPart") or machine.PrimaryPart
            local pos
            if hrp then pos=hrp.Position
            else local ok,bb=pcall(function() return machine:GetBoundingBox() end)
                if ok then pos=bb.Position end end
            if pos then
                local d=(root.Position-pos).Magnitude
                if d<bestDist then bestDist=d; bestPrompt=prompt; best=machine end
            end
        end
    end
    if bestPrompt then
        pcall(function() fireproximityprompt(bestPrompt) end)
        SLbl.Text=string.format("Fired prompt: %s (%.0f studs)",best.Name,bestDist)
    else SLbl.Text="⚠ No ProximityPrompt found" end
end)

ESPTab:Section("Mob ESP")
ESPTab:Toggle("👹 Mob ESP","Billboard tags on all mobs",states.espMobs,function(on)
    states.espMobs=on; saveSettings()
    if not on then
        for _, bb in pairs(espBillboards) do pcall(function() bb:Destroy() end) end
        espBillboards={}
    end
end)
ESPTab:Section("Info")
ESPTab:Label("Mob ESP attaches BillboardGui to Head/UpperTorso. All removed on Stop.")

AreaTab:Section("Teleport to Area")
AreaTab:Label("Areas discovered live from workspace.Areas.")

local AreaListFrame=Instance.new("Frame",AreaTab._page)
AreaListFrame.Size=UDim2.new(1,-10,0,280); AreaListFrame.BackgroundColor3=C.card
AreaListFrame.BorderSizePixel=0; AreaListFrame.LayoutOrder=5; AreaListFrame.ClipsDescendants=true
Instance.new("UICorner",AreaListFrame).CornerRadius=UDim.new(0,10)
Instance.new("UIStroke",AreaListFrame).Color=C.border

local AreaScroll=Instance.new("ScrollingFrame",AreaListFrame)
AreaScroll.Size=UDim2.new(1,-6,1,-4); AreaScroll.Position=UDim2.new(0,3,0,4)
AreaScroll.BackgroundTransparency=1; AreaScroll.BorderSizePixel=0
AreaScroll.ScrollBarThickness=3; AreaScroll.ScrollBarImageColor3=C.accent
AreaScroll.AutomaticCanvasSize=Enum.AutomaticSize.Y; AreaScroll.CanvasSize=UDim2.new(0,0,0,0)
local AreaLayout=Instance.new("UIListLayout",AreaScroll)
AreaLayout.Padding=UDim.new(0,3); AreaLayout.SortOrder=Enum.SortOrder.LayoutOrder

local function buildAreaList()
    for _, c in pairs(AreaScroll:GetChildren()) do
        if c:IsA("TextButton") or c:IsA("Frame") then c:Destroy() end
    end
    local areasFolder=workspace:FindFirstChild("Areas"); if not areasFolder then return end
    local areas=areasFolder:GetChildren()
    table.sort(areas,function(a,b)
        return (tonumber(a:GetAttribute("MinimumKills")) or 0)<(tonumber(b:GetAttribute("MinimumKills")) or 0)
    end)
    for i, area in ipairs(areas) do
        local minKills=tonumber(area:GetAttribute("MinimumKills")) or 0
        local minAscends=tonumber(area:GetAttribute("MinAscends")) or 0
        local unlocked=getKills()>=minKills and getAscends()>=minAscends
        local btn=Instance.new("TextButton",AreaScroll)
        btn.Size=UDim2.new(1,-4,0,36); btn.LayoutOrder=i
        btn.BackgroundColor3=unlocked and Color3.fromRGB(0,30,15) or C.card
        btn.BorderSizePixel=0; btn.Text=""
        Instance.new("UICorner",btn).CornerRadius=UDim.new(0,7)
        local bStroke=Instance.new("UIStroke",btn)
        bStroke.Color=unlocked and C.green or C.border; bStroke.Thickness=1
        local nLbl=Instance.new("TextLabel",btn)
        nLbl.Text=area.Name; nLbl.Size=UDim2.new(0.55,0,1,0); nLbl.Position=UDim2.new(0,10,0,0)
        nLbl.BackgroundTransparency=1; nLbl.TextColor3=unlocked and C.green or C.sub
        nLbl.Font=Enum.Font.GothamBold; nLbl.TextSize=10; nLbl.TextXAlignment=Enum.TextXAlignment.Left
        local reqLbl=Instance.new("TextLabel",btn)
        local reqStr=minAscends>0
            and string.format("⚔%s | 🌟%d",tostring(minKills),minAscends)
            or  string.format("⚔ %s kills",tostring(minKills))
        reqLbl.Text=reqStr; reqLbl.Size=UDim2.new(0.45,-10,1,0); reqLbl.Position=UDim2.new(0.55,0,0,0)
        reqLbl.BackgroundTransparency=1; reqLbl.TextColor3=C.sub
        reqLbl.Font=Enum.Font.Code; reqLbl.TextSize=8; reqLbl.TextXAlignment=Enum.TextXAlignment.Right
        local aName=area.Name
        btn.MouseButton1Click:Connect(function()
            local root=getRoot(); if not root then SLbl.Text="No character"; return end
            local areaRef=areasFolder:FindFirstChild(aName)
            if not areaRef then SLbl.Text="⚠ Area not found"; return end
            local spawn=areaRef:FindFirstChild("SafeAreaSpawn")
            if spawn then
                local ok=pcall(function() root.CFrame=spawn.CFrame*CFrame.new(0,3,0) end)
                SLbl.Text=ok and ("TP → "..aName) or "⚠ Teleport failed"
            else SLbl.Text="⚠ No SafeAreaSpawn in "..aName end
        end)
    end
end

AreaTab:Button("🔄","Refresh Area List","Re-scans workspace.Areas",C.accent,function()
    buildAreaList(); SLbl.Text="Area list refreshed"
end)
task.defer(buildAreaList)

AreaTab:Section("Current Area")
local CurAreaLbl=AreaTab:Label("Current area: checking...")
task.spawn(function()
    while true do
        if GEN~=_G.MeleeRNG_Gen then break end
        task.wait(3)
        pcall(function()
            local area=invokeR("GetArea")
            if area then
                CurAreaLbl.Set("Current area: "..area.Name..
                    " | Kills: "..tostring(getKills())..
                    " | Ascends: "..tostring(getAscends()))
            end
        end)
    end
end)

MiscTab:Section("UI Buttons")
MiscTab:Toggle("👁️ Show AutoRaid Button","Keeps AutoRaidBtn visible",states.showAutoRaid,function(on)
    states.showAutoRaid=on; saveSettings()
    pcall(function()
        LP.PlayerGui:WaitForChild("MainGUI",3):WaitForChild("OptionsList",3):WaitForChild("AutoRaidBtn",3).Visible=on
    end)
    SLbl.Text=on and "✓ AutoRaidBtn shown" or "AutoRaidBtn hidden"
end)
MiscTab:Toggle("🙈 Show HideMobs Button","Keeps HideMobsBtn visible",states.showHideMobs,function(on)
    states.showHideMobs=on; saveSettings()
    pcall(function()
        LP.PlayerGui:WaitForChild("MainGUI",3):WaitForChild("OptionsList",3):WaitForChild("HideMobsBtn",3).Visible=on
    end)
    SLbl.Text=on and "✓ HideMobsBtn shown" or "HideMobsBtn hidden"
end)

MiscTab:Section("Machines")
MiscTab:Label("Teleport to each machine and fire its ProximityPrompt.")
local MACHINE_NAMES={"Fountain Of Skill","Fusion Machine","Totem Of Fortune","Weapon Crafter"}
for _, mname in ipairs(MACHINE_NAMES) do
    local mn=mname
    MiscTab:Button("🔧",mn,"TP to "..mn,C.accent,function()
        local root=getRoot(); if not root then SLbl.Text="No character"; return end
        local machines=workspace:FindFirstChild("Machines")
        local machine=machines and machines:FindFirstChild(mn)
        if not machine then SLbl.Text="⚠ "..mn.." not found"; return end
        local ok,bb=pcall(function() return machine:GetBoundingBox() end)
        if ok then root.CFrame=CFrame.new(bb.Position+Vector3.new(0,5,0)); task.wait(0.3) end
        local prompt=machine:FindFirstChild("ProximityPrompt")
        if prompt then
            pcall(function() fireproximityprompt(prompt) end)
            SLbl.Text="✓ Fired: "..mn
        else SLbl.Text="⚠ No ProximityPrompt on "..mn end
    end)
end

MiscTab:Section("Ascend")
MiscTab:Toggle("⬆️ Auto Ascend","Ascends automatically when kill requirement is met",states.autoAscend,function(on)
    states.autoAscend=on; saveSettings()
    SLbl.Text=on and "Auto Ascend ON" or "Auto Ascend OFF"
end)
MiscTab:Button("⬆️","Ascend Now","Manually calls ConfirmAscend",C.gold,function()
    local ok=invokeR("ConfirmAscend")
    SLbl.Text=ok and "✓ Ascended!" or "⚠ Not ready"
end)
MiscTab:Button("🎯","Check Ascend Status","Shows kills needed for next area",C.accent,function()
    local area=invokeR("GetArea"); if not area then SLbl.Text="⚠ GetArea returned nil"; return end
    local np=area:FindFirstChild("NextPortal"); if not np then SLbl.Text="No NextPortal found"; return end
    local dest=np:GetAttribute("Destination"); if not dest then SLbl.Text="No Destination"; return end
    local nextArea=workspace:FindFirstChild("Areas") and workspace.Areas:FindFirstChild(dest)
    if not nextArea then SLbl.Text="Area not found: "..tostring(dest); return end
    local minK=tonumber(nextArea:GetAttribute("MinimumKills")) or 0
    local minA=tonumber(nextArea:GetAttribute("MinAscends"))   or 0
    local have=getKills()
    SLbl.Text=string.format("-> %s | Need %d kills (%d more) | %d ascends req",dest,minK,math.max(0,minK-have),minA)
end)

MiscTab:Section("Upgrades")
local UPGRADE_NAMES={"Weapons Equipped","Damage Multiplier","Enemy Spawn Rate","Enemy Limit",
    "Mana Multiplier","Spin Speed","RNG Luck","Kill Multiplier","Skill Point Multiplier","Boss Spawn Chance"}
MiscTab:Button("📊","Print Upgrade Levels","Fetches all upgrade levels",C.accent,function()
    local upgrades=invokeR("GetUnlockedUpgrades")
    if not upgrades then SLbl.Text="⚠ GetUnlockedUpgrades returned nil"; return end
    for _, name in ipairs(UPGRADE_NAMES) do
        local level=invokeR("GetUpgradeLevel",name) or 0
        local val=invokeR("GetUpgradeValue",name) or 0
        print(string.format("[MeleeRNG] %-30s  Lv%d  Value: %s",name,level,tostring(val)))
    end
    SLbl.Text="Upgrade levels printed to output"
end)

MiscTab:Section("Remote Logger")
local logActive=false
MiscTab:Toggle("📡 Remote Logger","Hooks DropLoot OnClientEvent to log loot",false,function(on)
    logActive=on
    if on then
        local dr=RS.Remotes and RS.Remotes:FindFirstChild("DropLoot")
        if dr then
            local conn=dr.OnClientEvent:Connect(function(model,pos,ref)
                if not logActive then return end
                local rarity=model and model:GetAttribute("OneIn") or "?"
                print(string.format("[MeleeRNG][Loot] %s | OneIn: %s | Ref: %s",
                    model and model.Name or "?",tostring(rarity),tostring(ref)))
            end)
            addConn(conn); SLbl.Text="Remote logger: DropLoot hooked"
        else SLbl.Text="⚠ DropLoot remote not found" end
    end
end)

addConn(UserInputService.JumpRequest:Connect(function()
    if GEN~=_G.MeleeRNG_Gen then return end
    if states.infJump then local h=getHuman(); if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end end
end))

local noclipParts,noclipConns={},{}
local function clearNoclipConns()
    for _, c in ipairs(noclipConns) do pcall(function() c:Disconnect() end) end; noclipConns={}
end
local function rebuildNoclipParts(char)
    table.clear(noclipParts); clearNoclipConns(); if not char then return end
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BasePart") then noclipParts[#noclipParts+1]=d end
    end
    noclipConns[#noclipConns+1]=char.DescendantAdded:Connect(function(d)
        if d:IsA("BasePart") then noclipParts[#noclipParts+1]=d end
    end)
end
rebuildNoclipParts(getChar())

local _lastNoclipPrune=0
addConn(RunService.Stepped:Connect(function()
    if GEN~=_G.MeleeRNG_Gen then return end
    if not states.noclip then return end
    local now=os.clock()
    if now-_lastNoclipPrune>5 then
        _lastNoclipPrune=now
        for i=#noclipParts,1,-1 do
            if not(noclipParts[i] and noclipParts[i].Parent) then table.remove(noclipParts,i) end
        end
    end
    for _, p in ipairs(noclipParts) do if p and p.Parent then p.CanCollide=false end end
end))

local _lastGod=0
addConn(RunService.Heartbeat:Connect(function()
    if GEN~=_G.MeleeRNG_Gen then return end
    if not states.godMode then return end
    local now=os.clock(); if now-_lastGod<0.5 then return end; _lastGod=now
    local h=getHuman()
    if h then
        if h.MaxHealth~=math.huge then h.MaxHealth=math.huge end
        if h.Health~=math.huge then h.Health=math.huge end
    end
end))

addConn(RunService.Heartbeat:Connect(function()
    if GEN~=_G.MeleeRNG_Gen then return end
    if states.fly then
        local root=getRoot(); if not root then return end
        if not flyBV then
            flyBV=Instance.new("BodyVelocity",root)
            flyBV.MaxForce=Vector3.new(1e5,1e5,1e5); flyBV.Velocity=Vector3.zero
        end
        if not flyBG then
            flyBG=Instance.new("BodyGyro",root)
            flyBG.MaxTorque=Vector3.new(1e5,1e5,1e5); flyBG.D=100
        end
        local cam=workspace.CurrentCamera; local spd=60; local mv=Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then mv=mv+cam.CFrame.LookVector  end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then mv=mv-cam.CFrame.LookVector  end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then mv=mv-cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then mv=mv+cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.E) then mv=mv+Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.Q) then mv=mv-Vector3.new(0,1,0) end
        if mv.Magnitude>0 then mv=mv.Unit end
        flyBV.Velocity=mv*spd; flyBG.CFrame=cam.CFrame
        local h=getHuman(); if h then h:ChangeState(Enum.HumanoidStateType.Physics) end
    else
        if flyBV then flyBV:Destroy(); flyBV=nil end
        if flyBG then flyBG:Destroy(); flyBG=nil end
    end
end))

local _fbApplied=false
local _origLight={
    Ambient=Lighting.Ambient, OutdoorAmbient=Lighting.OutdoorAmbient,
    Brightness=Lighting.Brightness, FogEnd=Lighting.FogEnd, FogStart=Lighting.FogStart,
}
addConn(RunService.Heartbeat:Connect(function()
    if GEN~=_G.MeleeRNG_Gen then return end
    if states.fullBright then
        if _fbApplied then return end; _fbApplied=true
        Lighting.Ambient=Color3.fromRGB(255,255,255); Lighting.OutdoorAmbient=Color3.fromRGB(255,255,255)
        Lighting.Brightness=10; Lighting.FogEnd=1e6; Lighting.FogStart=1e6
    elseif _fbApplied then
        _fbApplied=false
        Lighting.Ambient=_origLight.Ambient; Lighting.OutdoorAmbient=_origLight.OutdoorAmbient
        Lighting.Brightness=_origLight.Brightness; Lighting.FogEnd=_origLight.FogEnd; Lighting.FogStart=_origLight.FogStart
    end
end))

addThread(task.spawn(function()
    while true do
        if GEN~=_G.MeleeRNG_Gen then break end
        task.wait(55)
        if states.antiAfk then
            pcall(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new()) end)
        end
    end
end))

local _speedConn=nil
local function enforceSpeed()
    local h=getHuman(); if not h then return end
    h.WalkSpeed=walkSpeedVal
    if _speedConn then _speedConn:Disconnect() end
    _speedConn=h:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
        if GEN~=_G.MeleeRNG_Gen then if _speedConn then _speedConn:Disconnect() end return end
        if h.WalkSpeed~=walkSpeedVal then h.WalkSpeed=walkSpeedVal end
    end)
    addConn(_speedConn)
end
do local h=getHuman(); if h then h.WalkSpeed=walkSpeedVal end end
enforceSpeed()

local function makeBillboard(parent,text,color,yOff)
    local bb=Instance.new("BillboardGui",parent)
    bb.Size=UDim2.new(0,120,0,24); bb.StudsOffset=Vector3.new(0,yOff or 3,0)
    bb.AlwaysOnTop=true; bb.MaxDistance=200
    local lbl=Instance.new("TextLabel",bb)
    lbl.Size=UDim2.new(1,0,1,0); lbl.BackgroundTransparency=1
    lbl.Text=text; lbl.TextColor3=color or C.red
    lbl.Font=Enum.Font.GothamBold; lbl.TextSize=11; lbl.TextStrokeTransparency=0.2
    return bb
end

addThread(task.spawn(function()
    while true do
        if GEN~=_G.MeleeRNG_Gen then break end
        task.wait(0.6)
        if states.espMobs then
            local mobs=workspace:FindFirstChild("Mobs")
            if mobs then
                for model,bb in pairs(espBillboards) do
                    if not isMobAlive(model) then bb:Destroy(); espBillboards[model]=nil end
                end
                for _, model in pairs(mobs:GetChildren()) do
                    if model:IsA("Model") and isMobAlive(model) and not espBillboards[model] then
                        local anchor=model:FindFirstChild("Head")
                                  or model:FindFirstChild("UpperTorso")
                                  or model:FindFirstChild("HumanoidRootPart")
                        if anchor then
                            local isBoss=model:GetAttribute("Boss")==true
                            local isMega=model:GetAttribute("MegaBoss")==true
                            local col=isMega and C.red or isBoss and C.gold or C.orange
                            local tag=isMega and " [MEGA]" or isBoss and " [BOSS]" or ""
                            espBillboards[model]=makeBillboard(anchor,model.Name..tag,col,2.5)
                        end
                    end
                end
            end
        elseif next(espBillboards) then
            for _, bb in pairs(espBillboards) do pcall(function() bb:Destroy() end) end
            espBillboards={}
        end
    end
end))

addConn(LP.CharacterAdded:Connect(function(c)
    if GEN~=_G.MeleeRNG_Gen then return end
    task.wait(0.5); rebuildNoclipParts(c)
    local h=c:WaitForChild("Humanoid",5)
    if h then h.WalkSpeed=walkSpeedVal end
    if flyBV then flyBV:Destroy(); flyBV=nil end
    if flyBG then flyBG:Destroy(); flyBG=nil end
    enforceSpeed(); _hitboxCacheDirty=true
end))

addThread(task.spawn(function()
    while true do
        if GEN~=_G.MeleeRNG_Gen then break end
        if not states.autoAscend then task.wait(2); continue end
        pcall(function()
            local area=invokeR("GetArea"); if not area then return end
            local nextPortal=area:FindFirstChild("NextPortal"); if not nextPortal then return end
            local dest=nextPortal:GetAttribute("Destination"); if not dest then return end
            local nextArea=workspace.Areas and workspace.Areas:FindFirstChild(dest)
            if not nextArea then return end
            local minK=tonumber(nextArea:GetAttribute("MinimumKills")) or math.huge
            local minA=tonumber(nextArea:GetAttribute("MinAscends"))  or 0
            if getKills()>=minK and getAscends()>=minA then
                local ok=invokeR("ConfirmAscend")
                if ok then
                    SLbl.Text="✓ Ascended! → "..dest
                    local root=getRoot()
                    if root then
                        local spawn=nextArea:FindFirstChild("SafeAreaSpawn")
                        if spawn then pcall(function() root.CFrame=spawn.CFrame*CFrame.new(0,3,0) end) end
                    end
                end
            end
        end)
        task.wait(5)
    end
end))

addThread(task.spawn(function()
    while true do
        if GEN~=_G.MeleeRNG_Gen then break end
        task.wait(30); pcall(getDmgMulti)
    end
end))

local _killHistory={}; local _KILL_WINDOW=60; local _lastKillCount=0
local function recordKills()
    local now=os.clock(); local kills=getKills()
    if kills~=_lastKillCount then _lastKillCount=kills; _killHistory[#_killHistory+1]={t=now,k=kills} end
    local cutoff=now-_KILL_WINDOW; local i=1
    while i<=#_killHistory and _killHistory[i].t<cutoff do i=i+1 end
    if i>1 then
        for j=1,#_killHistory-i+1 do _killHistory[j]=_killHistory[j+i-1] end
        for j=#_killHistory-i+2,#_killHistory do _killHistory[j]=nil end
    end
end
local function getKillRate()
    if #_killHistory<2 then return 0 end
    local oldest=_killHistory[1]; local newest=_killHistory[#_killHistory]
    local dt=newest.t-oldest.t; if dt<1 then return 0 end
    return (newest.k-oldest.k)/dt*60
end
local function fmtTime(secs)
    if secs<=0 or secs~=secs then return "—" end
    if secs>86400*30 then return ">30 days" end
    local d=math.floor(secs/86400); local h=math.floor((secs%86400)/3600)
    local m=math.floor((secs%3600)/60); local s=math.floor(secs%60)
    if d>0 then return string.format("%dd %dh %dm",d,h,m) end
    if h>0 then return string.format("%dh %dm %ds",h,m,s) end
    if m>0 then return string.format("%dm %ds",m,s) end
    return string.format("%ds",s)
end
local function getAscendETA()
    local area=invokeR("GetArea"); if not area then return nil,nil,nil end
    local np=area:FindFirstChild("NextPortal"); if not np then return nil,nil,nil end
    local dest=np:GetAttribute("Destination"); if not dest then return nil,nil,nil end
    local nextArea=workspace:FindFirstChild("Areas") and workspace.Areas:FindFirstChild(dest)
    if not nextArea then return nil,nil,nil end
    local minK=tonumber(nextArea:GetAttribute("MinimumKills")) or 0
    local minA=tonumber(nextArea:GetAttribute("MinAscends"))  or 0
    return dest,math.max(0,minK-getKills()),math.max(0,minA-getAscends())
end

addThread(task.spawn(function()
    while true do
        if GEN~=_G.MeleeRNG_Gen then break end
        recordKills(); task.wait(0.5)
    end
end))

MiscTab:Section("Stats & Kill Rate")
local StatsLbl=MiscTab:Label("Kills: — | Mana: — | SP: — | Ascends: —")
local KPMLbl=MiscTab:Label("KPM: — | ETA to next area: —")
local ETALbl=MiscTab:Label("Next area: — | Need: — kills")

addThread(task.spawn(function()
    while true do
        if GEN~=_G.MeleeRNG_Gen then break end
        task.wait(1); local kpm=getKillRate()
        pcall(function()
            StatsLbl.Set(string.format("Kills: %s | Mana: %s | SP: %s | Ascends: %s",
                tostring(getKills()),tostring(getMana()),tostring(getSP()),tostring(getAscends())))
            local dest,killsNeeded,ascendsNeeded=getAscendETA()
            if dest then
                local etaSecs=(kpm>0 and killsNeeded>0) and (killsNeeded/kpm*60) or nil
                local etaStr=etaSecs and fmtTime(etaSecs) or (killsNeeded==0 and "READY" or "—")
                KPMLbl.Set(string.format("KPM: %.1f | ETA %s: %s",kpm,dest,etaStr))
                ETALbl.Set(string.format("Need: %s kills%s | Have: %s",
                    tostring(killsNeeded),
                    ascendsNeeded>0 and (" + "..ascendsNeeded.." ascends") or "",
                    tostring(getKills())))
            else KPMLbl.Set(string.format("KPM: %.1f | Area data loading...",kpm)) end
        end)
    end
end))

MiscTab:Section("Community")
MiscTab:Button("💬","Join Discord","Opens discord.gg/vSTmMTyw",C.purple,function()
    if setclipboard then setclipboard("https://discord.gg/vSTmMTyw"); SLbl.Text="Discord link copied!" end
    pcall(function() game:GetService("GuiService"):OpenBrowserWindow("https://discord.gg/vSTmMTyw") end)
end)

MiscTab:Section("Script Control")
MiscTab:Toggle("🔁 Auto Rejoin","Re-executes on disconnect or hop",states.autoReExec,function(on)
    states.autoReExec=on; saveSettings()
    SLbl.Text=on and "Auto Rejoin ON" or "Auto Rejoin OFF"
end)
MiscTab:Toggle("💾 Auto Save","Saves all toggle/slider states to disk",states.autoSave,function(on)
    states.autoSave=on; forceSave()
    SLbl.Text=on and "✓ Auto Save ON" or "Auto Save OFF"
end)
MiscTab:Button("🛑","Stop All Loops","Disconnects all connections and cancels threads",C.red,function()
    states.autoAscend=false; states.noclip=false; states.godMode=false
    states.fly=false; states.antiAfk=false; states.fullBright=false; states.espMobs=false
    cleanupAll()
    if _fbApplied then
        Lighting.Ambient=_origLight.Ambient; Lighting.OutdoorAmbient=_origLight.OutdoorAmbient
        Lighting.Brightness=_origLight.Brightness; Lighting.FogEnd=_origLight.FogEnd; Lighting.FogStart=_origLight.FogStart
        _fbApplied=false
    end
    for _, bb in pairs(espBillboards) do pcall(function() bb:Destroy() end) end; espBillboards={}
    if flyBV then flyBV:Destroy(); flyBV=nil end
    if flyBG then flyBG:Destroy(); flyBG=nil end
    hitboxExpanded=false; _pulseActive=false
    if _pulseConn then pcall(function() _pulseConn:Disconnect() end); _pulseConn=nil end
    pcall(restoreHitboxes)
    SLbl.Text="All loops stopped. Re-execute to restart."
end)
MiscTab:Button("💾","Save Settings","Force-saves current state",C.green,function()
    saveSettings(); SLbl.Text="Settings saved to "..SETTINGS_FILE
end)

-- FIX 5: RequestedByServer → ~= None
do
    local REEXEC_URL=SCRIPT_URL
    if _G.MeleeRNG_AutoRejoin and not states.autoReExec then
        states.autoReExec=true; saveSettings()
    end
    local function syncMeleeRejoinFlag() _G.MeleeRNG_AutoRejoin=states.autoReExec end
    syncMeleeRejoinFlag()
    pcall(function()
LP.OnTeleport:Connect(function(teleportState)
    syncMeleeRejoinFlag()
    if queue_on_teleport and states.autoReExec then
        pcall(function()
            queue_on_teleport('loadstring(game:HttpGet("'..REEXEC_URL..'",true))()')
        end)
    end
end)
    end)
    local function armQueue()
        pcall(function()
            if queue_on_teleport and states.autoReExec then
                queue_on_teleport('loadstring(game:HttpGet("'..REEXEC_URL..'",true))()')
            end
        end)
    end
    armQueue()
    task.spawn(function()
        local wasOn=false
        while true do
            if GEN~=_G.MeleeRNG_Gen then break end
            task.wait(2); syncMeleeRejoinFlag()
            if states.autoReExec and not wasOn then pcall(armQueue) end
            wasOn=states.autoReExec
        end
    end)
end

do local h=getHuman(); if h then h.WalkSpeed=walkSpeedVal end end
task.defer(function()
    if states.showAutoRaid then
        pcall(function()
            LP.PlayerGui:WaitForChild("MainGUI",5):WaitForChild("OptionsList",5):WaitForChild("AutoRaidBtn",5).Visible=true
        end)
    end
    if states.showHideMobs then
        pcall(function()
            LP.PlayerGui:WaitForChild("MainGUI",5):WaitForChild("OptionsList",5):WaitForChild("HideMobsBtn",5).Visible=true
        end)
    end
end)
print(string.format("[MeleeRNG] Loaded v1.0 | Gen=%d | DMGx=%d%%",GEN,_dmgMulti))
SLbl.Text=string.format("MeleeRNG v1.0 ready | Gen=%d | Kills: %s",GEN,tostring(getKills()))
