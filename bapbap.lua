
-- ╔══════════════════════════════════════════════════════════════╗
-- ║          AUTO GRIND v3  —  Clean Rewrite (FIXED v2)         ║
-- ║  Priority: Farm Lv.80 → Furnace Lv.80 → 246M Gold          ║
-- ║  Goals: Level 300 | Furnace 80 | All Farms 80 | 246M Gold   ║
-- ║  + DUNGEON SELECTOR (Difficulty + Stage chooser)            ║
-- ╚══════════════════════════════════════════════════════════════╝

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local VirtualUser       = game:GetService("VirtualUser")

local player    = Players.LocalPlayer or Players.PlayerAdded:Wait()
local character = player.Character or player.CharacterAdded:Wait()
local root      = character:WaitForChild("HumanoidRootPart")
local humanoid  = character:WaitForChild("Humanoid")

-- ── GUI paths kept as original raw strings (they work fine) ──
local farmlandUI   = player.PlayerGui:WaitForChild("GUI"):WaitForChild("二级界面"):WaitForChild("农田")
local furnaceUI    = player.PlayerGui:WaitForChild("GUI"):WaitForChild("二级界面"):WaitForChild("炼丹炉")
local currencyArea = player.PlayerGui:WaitForChild("GUI"):WaitForChild("主界面"):WaitForChild("主城"):WaitForChild("货币区域")
local stageLabel   = player.PlayerGui:WaitForChild("GUI"):WaitForChild("主界面"):WaitForChild("战斗"):WaitForChild("关卡信息"):WaitForChild("文本")
local levelSelectUI      = player.PlayerGui:WaitForChild("GUI"):WaitForChild("二级界面"):WaitForChild("关卡选择")

-- ── S() helper — builds strings from bytes at runtime so obfuscators
--    cannot corrupt them. Used ONLY for RemoteEvent paths + AFK_ARG ──
local function S(...)
    local r = ""
    for _, v in ipairs({...}) do r = r .. string.char(v) end
    return r
end

-- FIX: AFK_ARG and all ReplicatedStorage remote paths use S() — obfuscator-safe
local AFK_ARG         = S(232,135,170,229,138,168,230,136,152,230,150,151)

local RS              = ReplicatedStorage:WaitForChild(S(228,186,139,228,187,182)):WaitForChild(S(229,133,172,231,148,168))
local remoteWorld     = RS:WaitForChild(S(229,133,179,229,141,161)):WaitForChild(S(232,191,155,229,133,165,228,184,150,231,149,140,229,133,179,229,141,161))
local remoteFarmUp    = RS:WaitForChild(S(229,134,156,231,148,176)):WaitForChild(S(229,141,135,231,186,167))
local remoteFarmCol   = RS:WaitForChild(S(229,134,156,231,148,176)):WaitForChild(S(233,135,135,233,155,134))
local remoteAFK       = RS:WaitForChild(S(232,174,190,231,189,174)):WaitForChild(S(231,142,169,229,174,182,228,191,174,230,148,185,232,174,190,231,189,174))
local remoteFurnaceUp = RS:WaitForChild(S(231,130,188,228,184,185)):WaitForChild(S(229,141,135,231,186,167))

local syncWorld = ReplicatedStorage
    :WaitForChild("事件"):WaitForChild("公用")
    :WaitForChild("关卡"):WaitForChild("同步世界关卡数据")

local GOAL_LEVEL   = 300
local GOAL_FURNACE = 80
local GOAL_FARM    = 80
local GOAL_GOLD    = 246000000
local OFFSCREEN    = UDim2.new(0, 99999, 0, 99999)

local farmlandOrigPos  = farmlandUI.Position
local furnaceOrigPos   = furnaceUI.Position
local farmlandOrigVis  = farmlandUI.Visible
local furnaceOrigVis   = furnaceUI.Visible

local levelSelectOrigPos = levelSelectUI.Position
local levelSelectOrigVis = levelSelectUI.Visible

local data = {
    level="0", xp="0", gold="0", goldNum=0, diamonds="0", herbs="0",
    farms={}, furnace={level="0"}, highestWorld=0,
    infoReady=false, status="Press START", running=false,
}

-- ── FIXED: 5 difficulties, offsets match 1-20 / 21-40 / 41-60 / 61-80 / 81-100
local DIFFICULTIES       = { "Easy", "Normal", "Hard", "Expert", "Master" }
local DIFF_OFFSET        = { Easy=0, Normal=20, Hard=40, Expert=60, Master=80 }
local selectedDifficulty = "Normal"
local selectedStage      = 1
local dungeonOverride    = false

local suppressFarmLevelUpdate = false
local farmWalkLock       = false
local lastFarmWalk       = 0
local FARM_WALK_INTERVAL = 300
local nextFarmWalkAt     = -1
local hasEnteredDungeonOnce = false
local stopFlag           = false

-- ── Colors ───────────────────────────────────────────────────
local C = {
    bg=Color3.fromRGB(8,10,18), panel=Color3.fromRGB(14,18,32),
    panelB=Color3.fromRGB(18,24,44), border=Color3.fromRGB(35,55,110),
    accent=Color3.fromRGB(90,170,255), accentDim=Color3.fromRGB(50,110,220),
    green=Color3.fromRGB(55,220,115), yellow=Color3.fromRGB(255,215,60),
    red=Color3.fromRGB(255,70,70), orange=Color3.fromRGB(255,150,40),
    text=Color3.fromRGB(225,235,255), sub=Color3.fromRGB(110,135,175),
    bar=Color3.fromRGB(18,26,52), barBlue=Color3.fromRGB(55,135,255),
    barGreen=Color3.fromRGB(45,195,95), barOrange=Color3.fromRGB(255,140,30),
    barYellow=Color3.fromRGB(220,190,40),
    easy=Color3.fromRGB(55,220,115), normal=Color3.fromRGB(90,170,255),
    hard=Color3.fromRGB(255,100,70), expert=Color3.fromRGB(220,100,255),
}
local function diffColor(d)
    if d=="Easy"   then return C.easy
    elseif d=="Hard"   then return C.hard
    elseif d=="Expert" then return C.expert
    elseif d=="Master" then return C.orange
    else return C.normal end
end

-- ── GUI build ────────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name="AutoGrindV3"; gui.ResetOnSpawn=false
gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; gui.Parent=player.PlayerGui

local main = Instance.new("Frame",gui)
main.Size=UDim2.new(0,380,0,100); main.Position=UDim2.new(0,16,0,16)
main.BackgroundColor3=C.bg; main.BorderSizePixel=0; main.ClipsDescendants=false
Instance.new("UICorner",main).CornerRadius=UDim.new(0,14)
local mainStroke=Instance.new("UIStroke",main); mainStroke.Color=C.border; mainStroke.Thickness=1.5

local _drag,_dragStart,_startPos
main.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 then _drag=true;_dragStart=i.Position;_startPos=main.Position end
end)
main.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 then _drag=false end
end)
UserInputService.InputChanged:Connect(function(i)
    if _drag and i.UserInputType==Enum.UserInputType.MouseMovement then
        local d=i.Position-_dragStart
        main.Position=UDim2.new(_startPos.X.Scale,_startPos.X.Offset+d.X,_startPos.Y.Scale,_startPos.Y.Offset+d.Y)
    end
end)

local function mkF(p,sz,pos,col,r,stroke)
    local f=Instance.new("Frame",p); f.Size=sz; f.Position=pos or UDim2.new(0,0,0,0)
    f.BackgroundColor3=col or C.panelB; f.BorderSizePixel=0
    if r then Instance.new("UICorner",f).CornerRadius=UDim.new(0,r) end
    if stroke then local s=Instance.new("UIStroke",f);s.Color=C.border;s.Thickness=1 end
    return f
end
local function mkL(p,txt,sz,pos,col,font,ts,xa,ya)
    local l=Instance.new("TextLabel",p); l.Size=sz; l.Position=pos or UDim2.new(0,0,0,0)
    l.BackgroundTransparency=1; l.Text=txt; l.TextColor3=col or C.text
    l.Font=font or Enum.Font.Gotham; l.TextSize=ts or 14; l.TextScaled=false
    l.TextXAlignment=xa or Enum.TextXAlignment.Left; l.TextYAlignment=ya or Enum.TextYAlignment.Center
    return l
end
local function mkBtn(p,txt,sz,pos,bg,tc,fs)
    local b=Instance.new("TextButton",p); b.Size=sz; b.Position=pos or UDim2.new(0,0,0,0)
    b.BackgroundColor3=bg or C.accentDim; b.BorderSizePixel=0; b.Text=txt
    b.TextColor3=tc or Color3.new(1,1,1); b.Font=Enum.Font.GothamBold; b.TextSize=fs or 13
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,6); return b
end

local hdr=mkF(main,UDim2.new(1,0,0,52),UDim2.new(0,0,0,0),C.panel,14)
mkF(hdr,UDim2.new(1,0,0,14),UDim2.new(0,0,1,-14),C.panel)
mkL(hdr,"⚔  AUTO GRIND v3",UDim2.new(0,200,1,0),UDim2.new(0,14,0,0),C.accent,Enum.Font.GothamBold,17)
local dot=mkF(hdr,UDim2.new(0,10,0,10),UDim2.new(1,-114,0.5,-5),C.red,9)
local toggleBtn=Instance.new("TextButton",hdr)
toggleBtn.Size=UDim2.new(0,96,0,32); toggleBtn.Position=UDim2.new(1,-108,0.5,-16)
toggleBtn.BackgroundColor3=C.accentDim; toggleBtn.BorderSizePixel=0
toggleBtn.Text="▶  START"; toggleBtn.TextColor3=Color3.new(1,1,1)
toggleBtn.Font=Enum.Font.GothamBold; toggleBtn.TextSize=14
Instance.new("UICorner",toggleBtn).CornerRadius=UDim.new(0,7)

local scroll=Instance.new("ScrollingFrame",main)
scroll.Size=UDim2.new(1,0,1,-52); scroll.Position=UDim2.new(0,0,0,52)
scroll.BackgroundTransparency=1; scroll.BorderSizePixel=0
scroll.ScrollBarThickness=3; scroll.ScrollBarImageColor3=C.border
scroll.CanvasSize=UDim2.new(0,0,0,0); scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y

local content=Instance.new("Frame",scroll)
content.Size=UDim2.new(1,-24,0,10); content.Position=UDim2.new(0,12,0,8)
content.BackgroundTransparency=1; content.BorderSizePixel=0; content.AutomaticSize=Enum.AutomaticSize.Y

local layout=Instance.new("UIListLayout",content)
layout.SortOrder=Enum.SortOrder.LayoutOrder; layout.Padding=UDim.new(0,6)
layout.FillDirection=Enum.FillDirection.Vertical
layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    local h=layout.AbsoluteContentSize.Y+20
    main.Size=UDim2.new(0,380,0,math.clamp(h+60,100,720))
end)

local function mkSectionHeader(txt,order)
    local l=mkL(content,txt,UDim2.new(1,0,0,20),nil,C.sub,Enum.Font.GothamBold,12,Enum.TextXAlignment.Left)
    l.LayoutOrder=order; return l
end
local function mkInfoRow(icon,label,order)
    local row=mkF(content,UDim2.new(1,0,0,42),nil,C.panelB,8,true); row.LayoutOrder=order
    mkL(row,icon,UDim2.new(0,30,1,0),UDim2.new(0,8,0,0),C.text,Enum.Font.Gotham,18,Enum.TextXAlignment.Center)
    mkL(row,label,UDim2.new(0.48,0,1,0),UDim2.new(0,40,0,0),C.sub,Enum.Font.Gotham,13)
    local v=mkL(row,"---",UDim2.new(0.5,-4,1,0),UDim2.new(0.5,0,0,0),C.accent,Enum.Font.GothamBold,15,Enum.TextXAlignment.Right); v.Name="Val"
    local s=mkL(row,"",UDim2.new(1,-42,0,12),UDim2.new(0,42,1,-13),C.sub,Enum.Font.Gotham,11,Enum.TextXAlignment.Right); s.Name="Sub"
    return row
end
local function mkStatRow(icon,label,goalStr,order,showFarmExtra)
    local h=showFarmExtra and 100 or 64
    local wrap=Instance.new("Frame",content)
    wrap.Size=UDim2.new(1,0,0,h); wrap.BackgroundTransparency=1; wrap.BorderSizePixel=0; wrap.LayoutOrder=order
    local row=mkF(wrap,UDim2.new(1,0,0,h),nil,C.panelB,8,true)
    mkL(row,icon,UDim2.new(0,30,0,32),UDim2.new(0,8,0,4),C.text,Enum.Font.Gotham,19,Enum.TextXAlignment.Center)
    mkL(row,label,UDim2.new(0.5,-10,0,20),UDim2.new(0,40,0,5),C.sub,Enum.Font.Gotham,13)
    local val=mkL(row,"---",UDim2.new(0.5,0,0,20),UDim2.new(0.5,-2,0,5),C.text,Enum.Font.GothamBold,15,Enum.TextXAlignment.Right); val.Name="Val"
    local barBg=mkF(row,UDim2.new(1,-40,0,6),UDim2.new(0,40,0,33),C.bar,4)
    local fill=mkF(barBg,UDim2.new(0,0,1,0),UDim2.new(0,0,0,0),C.barBlue,4); fill.Name="Fill"
    mkL(row,"Goal: "..goalStr,UDim2.new(0.55,0,0,15),UDim2.new(0,40,0,44),C.sub,Enum.Font.Gotham,11)
    local pctL=mkL(row,"0%",UDim2.new(0.45,-2,0,15),UDim2.new(0.55,0,0,44),C.sub,Enum.Font.Gotham,11,Enum.TextXAlignment.Right); pctL.Name="Pct"
    if showFarmExtra then
        local line1=mkF(row,UDim2.new(1,-12,0,16),UDim2.new(0,6,0,62),Color3.fromRGB(12,16,30),3)
        local hl=mkL(line1,"🌿 --/h",UDim2.new(0.5,0,1,0),UDim2.new(0,4,0,0),C.yellow,Enum.Font.Gotham,12); hl.Name="HerbLbl"
        local cl=mkL(line1,"📦 --/--",UDim2.new(0.5,-4,1,0),UDim2.new(0.5,0,0,0),C.sub,Enum.Font.Gotham,12,Enum.TextXAlignment.Right); cl.Name="CapLbl"
        local cbBg=mkF(row,UDim2.new(1,-12,0,4),UDim2.new(0,6,0,80),C.bar,2)
        local cf=mkF(cbBg,UDim2.new(0,0,1,0),UDim2.new(0,0,0,0),C.barYellow,2); cf.Name="CapFill"
        local tl=mkL(row,"⏱ --",UDim2.new(1,-12,0,14),UDim2.new(0,6,0,85),C.sub,Enum.Font.Gotham,11); tl.Name="TimeLbl"
    end
    return row
end

local worldRow  = mkInfoRow("🌍","Highest World",1)
local statusRow = mkInfoRow("📡","Status",2)

local _dSep0=mkF(content,UDim2.new(1,0,0,1),nil,C.border); _dSep0.LayoutOrder=3
mkSectionHeader("  🗺 DUNGEON SELECTOR",4)
local dungeonPanel=mkF(content,UDim2.new(1,0,0,110),nil,C.panelB,8,true); dungeonPanel.LayoutOrder=5

mkL(dungeonPanel,"Auto highest world (toggle to override):",UDim2.new(0.72,0,0,20),UDim2.new(0,10,0,4),C.sub,Enum.Font.Gotham,12)
local overrideToggle=Instance.new("TextButton",dungeonPanel)
overrideToggle.Size=UDim2.new(0,56,0,20); overrideToggle.Position=UDim2.new(1,-64,0,4)
overrideToggle.BackgroundColor3=C.red; overrideToggle.BorderSizePixel=0
overrideToggle.Text="OFF"; overrideToggle.TextColor3=Color3.new(1,1,1)
overrideToggle.Font=Enum.Font.GothamBold; overrideToggle.TextSize=12
Instance.new("UICorner",overrideToggle).CornerRadius=UDim.new(0,5)

mkL(dungeonPanel,"Difficulty:",UDim2.new(0,70,0,22),UDim2.new(0,10,0,30),C.sub,Enum.Font.Gotham,13)
local diffLeft=mkBtn(dungeonPanel,"◀",UDim2.new(0,28,0,22),UDim2.new(0,82,0,30),Color3.fromRGB(30,40,70))
local diffValLbl=Instance.new("TextLabel",dungeonPanel)
diffValLbl.Size=UDim2.new(0,72,0,22); diffValLbl.Position=UDim2.new(0,113,0,30)
diffValLbl.BackgroundColor3=Color3.fromRGB(20,28,58); diffValLbl.BorderSizePixel=0
diffValLbl.Text=selectedDifficulty; diffValLbl.TextColor3=diffColor(selectedDifficulty)
diffValLbl.Font=Enum.Font.GothamBold; diffValLbl.TextSize=14; diffValLbl.TextXAlignment=Enum.TextXAlignment.Center
Instance.new("UICorner",diffValLbl).CornerRadius=UDim.new(0,5)
local diffRight=mkBtn(dungeonPanel,"▶",UDim2.new(0,28,0,22),UDim2.new(0,188,0,30),Color3.fromRGB(30,40,70))

mkL(dungeonPanel,"Stage (1–20):",UDim2.new(0,90,0,22),UDim2.new(0,10,0,58),C.sub,Enum.Font.Gotham,13)
local stageLeft=mkBtn(dungeonPanel,"◀",UDim2.new(0,28,0,22),UDim2.new(0,102,0,58),Color3.fromRGB(30,40,70))
local stageValLbl=Instance.new("TextLabel",dungeonPanel)
stageValLbl.Size=UDim2.new(0,40,0,22); stageValLbl.Position=UDim2.new(0,133,0,58)
stageValLbl.BackgroundColor3=Color3.fromRGB(20,28,58); stageValLbl.BorderSizePixel=0
stageValLbl.Text=tostring(selectedStage); stageValLbl.TextColor3=C.text
stageValLbl.Font=Enum.Font.GothamBold; stageValLbl.TextSize=15; stageValLbl.TextXAlignment=Enum.TextXAlignment.Center
Instance.new("UICorner",stageValLbl).CornerRadius=UDim.new(0,5)
local stageRight=mkBtn(dungeonPanel,"▶",UDim2.new(0,28,0,22),UDim2.new(0,176,0,58),Color3.fromRGB(30,40,70))
local stageMaxBtn=mkBtn(dungeonPanel,"MAX",UDim2.new(0,40,0,20),UDim2.new(0,209,0,60),Color3.fromRGB(40,55,100),C.yellow,11)
local enterNowBtn=mkBtn(dungeonPanel,"⚔ Enter Now",UDim2.new(0,120,0,24),UDim2.new(0,10,0,82),Color3.fromRGB(30,80,30),C.green,13)
local dungeonPreviewLbl=mkL(dungeonPanel,"[Normal] World 1",UDim2.new(0,190,0,24),UDim2.new(0,136,0,82),C.accent,Enum.Font.GothamBold,13,Enum.TextXAlignment.Right)

local function refreshDungeonUI()
    diffValLbl.Text=selectedDifficulty; diffValLbl.TextColor3=diffColor(selectedDifficulty)
    stageValLbl.Text=tostring(selectedStage)
    -- FIXED: world number = offset + stage  (e.g. Normal offset=20, stage=1 → world 21)
    local wn = DIFF_OFFSET[selectedDifficulty] + selectedStage
    dungeonPreviewLbl.Text=string.format("[%s] W%d (arg:%d)", selectedDifficulty, selectedStage, wn)
    dungeonPreviewLbl.TextColor3=diffColor(selectedDifficulty)
    if dungeonOverride then
        overrideToggle.Text="AUTO"; overrideToggle.BackgroundColor3=C.accentDim
    else
        overrideToggle.Text="MANUAL"; overrideToggle.BackgroundColor3=C.green
    end
end

diffLeft.MouseButton1Click:Connect(function()
    local i=table.find(DIFFICULTIES,selectedDifficulty) or 1; i=i-1; if i<1 then i=#DIFFICULTIES end
    selectedDifficulty=DIFFICULTIES[i]; refreshDungeonUI()
end)
diffRight.MouseButton1Click:Connect(function()
    local i=table.find(DIFFICULTIES,selectedDifficulty) or 1; i=i+1; if i>#DIFFICULTIES then i=1 end
    selectedDifficulty=DIFFICULTIES[i]; refreshDungeonUI()
end)
stageLeft.MouseButton1Click:Connect(function() selectedStage=math.max(1,selectedStage-1); refreshDungeonUI() end)
stageRight.MouseButton1Click:Connect(function() selectedStage=math.min(20,selectedStage+1); refreshDungeonUI() end)
stageMaxBtn.MouseButton1Click:Connect(function() selectedStage=20; refreshDungeonUI() end)
overrideToggle.MouseButton1Click:Connect(function() dungeonOverride=not dungeonOverride; refreshDungeonUI() end)
refreshDungeonUI()

local _d1=mkF(content,UDim2.new(1,0,0,1),nil,C.border); _d1.LayoutOrder=6
mkSectionHeader("  PLAYER",7)
local levelRow=mkStatRow("🧑","Player Level","300",8,false)
local goldRow=mkStatRow("💰","Gold","246M",9,false)
local _d2=mkF(content,UDim2.new(1,0,0,1),nil,C.border); _d2.LayoutOrder=10
mkSectionHeader("  ① FARMLANDS",11)
local farmRows={}
for i=1,5 do farmRows[i]=mkStatRow("🌾","Farm "..i,"Lv.80",11+i,true) end
local _d3=mkF(content,UDim2.new(1,0,0,1),nil,C.border); _d3.LayoutOrder=17
mkSectionHeader("  ② FURNACE",18)
local furnaceRow=mkStatRow("🔥","Furnace Level","Lv.80",19,false)
local _d4=mkF(content,UDim2.new(1,0,0,1),nil,C.border); _d4.LayoutOrder=20

local footerWrap=Instance.new("Frame",content)
footerWrap.Size=UDim2.new(1,0,0,38); footerWrap.BackgroundTransparency=1
footerWrap.BorderSizePixel=0; footerWrap.LayoutOrder=21
local nextRefreshLbl=mkL(footerWrap,"Next GUI refresh: --s",UDim2.new(1,0,0,18),UDim2.new(0,0,0,0),C.sub,Enum.Font.Gotham,12,Enum.TextXAlignment.Center)
local nextFarmLbl=mkL(footerWrap,"🚶 Next farm walk: --",UDim2.new(1,0,0,18),UDim2.new(0,0,0,20),C.yellow,Enum.Font.Gotham,12,Enum.TextXAlignment.Center)

-- ── UI panel management ───────────────────────────────────────
local function openUIPanels()
    furnaceUI.Position=OFFSCREEN; furnaceUI.Visible=true
    levelSelectUI.Position=OFFSCREEN; levelSelectUI.Visible=true
end
local function closeUIPanels()
    farmlandUI.Position=farmlandOrigPos; farmlandUI.Visible=farmlandOrigVis
    furnaceUI.Position=furnaceOrigPos; furnaceUI.Visible=furnaceOrigVis
    levelSelectUI.Position=levelSelectOrigPos; levelSelectUI.Visible=levelSelectOrigVis
end

local function getWorldNumber()
    -- FIXED: offset + stage  (Easy 1-20, Normal 21-40, Hard 41-60, Expert 61-80, Master 81-100)
    return (DIFF_OFFSET[selectedDifficulty] or 0) + selectedStage
end

local function getTargetWorld()
    if dungeonOverride then return data.highestWorld end
    return getWorldNumber()
end

local updateGUI -- forward declare

enterNowBtn.MouseButton1Click:Connect(function()
    local wn=getWorldNumber()
    data.status=string.format("🗺 Re-entering [%s] World %d (arg:%d)",selectedDifficulty,selectedStage,wn)
    updateGUI(); remoteWorld:FireServer(wn)
end)

-- ── GUI update helpers ────────────────────────────────────────
local function setBar(row,pct,color)
    local f=row:FindFirstChild("Fill",true); if not f then return end
    pct=math.clamp(pct,0,1)
    TweenService:Create(f,TweenInfo.new(0.3),{Size=UDim2.new(pct,0,1,0),BackgroundColor3=color or C.barBlue}):Play()
end
local function setCapBar(row,pct)
    local f=row:FindFirstChild("CapFill",true); if not f then return end
    pct=math.clamp(pct,0,1)
    local col=pct>=1 and C.red or (pct>=0.5 and C.barOrange or C.barYellow)
    TweenService:Create(f,TweenInfo.new(0.3),{Size=UDim2.new(pct,0,1,0),BackgroundColor3=col}):Play()
end
local function fmtCountdown(secs)
    secs=math.max(0,math.floor(secs))
    if secs>=3600 then return string.format("%dh %dm",math.floor(secs/3600),math.floor((secs%3600)/60))
    elseif secs>=60 then return string.format("%dm %ds",math.floor(secs/60),secs%60)
    else return secs.."s" end
end

local function updateFarmWalkLabel()
    if not data.running then
        nextFarmLbl.Text="🚶 Farm walk: idle"; nextFarmLbl.TextColor3=C.sub; return
    end
    if nextFarmWalkAt==-1 then
        nextFarmLbl.Text="🚶 Farm walk: starting soon..."; nextFarmLbl.TextColor3=C.sub; return
    end
    if nextFarmWalkAt==0 then
        nextFarmLbl.Text="🚶 Farm walk: pending..."; nextFarmLbl.TextColor3=C.yellow; return
    end
    local remaining=nextFarmWalkAt-os.time()
    if remaining<=0 then
        nextFarmLbl.Text="🚶 Farm walk: NOW"; nextFarmLbl.TextColor3=C.green
    else
        nextFarmLbl.Text="🚶 Next farm walk: "..fmtCountdown(remaining)
        nextFarmLbl.TextColor3=remaining<30 and C.orange or C.yellow
    end
end

updateGUI = function()
    local wv=worldRow:FindFirstChild("Val",true)
    if wv then wv.Text=data.highestWorld>0 and "World "..data.highestWorld or "---" end
    local sv=statusRow:FindFirstChild("Val",true); local ss=statusRow:FindFirstChild("Sub",true)
    if sv then sv.Text=data.running and "RUNNING" or "STOPPED"; sv.TextColor3=data.running and C.green or C.red end
    local afkState=hasEnteredDungeonOnce and "🟢 AFK on" or "🔴 AFK off"
    if ss then ss.Text=data.status.." | "..afkState end
    local lvl=tonumber(data.level) or 0; local lvlP=math.min(lvl/GOAL_LEVEL,1)
    local lv=levelRow:FindFirstChild("Val",true)
    if lv then lv.Text="Lv."..data.level..(lvl>=GOAL_LEVEL and " ✓" or ""); lv.TextColor3=lvl>=GOAL_LEVEL and C.green or C.text end
    setBar(levelRow,lvlP,lvl>=GOAL_LEVEL and C.barGreen or C.barBlue)
    local lp=levelRow:FindFirstChild("Pct",true); if lp then lp.Text=math.floor(lvlP*100).."%" end
    local gP=math.min(data.goldNum/GOAL_GOLD,1)
    local gv=goldRow:FindFirstChild("Val",true)
    if gv then gv.Text=string.format("%.2fM%s",data.goldNum/1e6,data.goldNum>=GOAL_GOLD and " ✓" or ""); gv.TextColor3=data.goldNum>=GOAL_GOLD and C.green or C.text end
    setBar(goldRow,gP,data.goldNum>=GOAL_GOLD and C.barGreen or C.barBlue)
    local gp=goldRow:FindFirstChild("Pct",true); if gp then gp.Text=math.floor(gP*100).."%" end
    for i=1,5 do
        local f=data.farms[i]; local fl=f and (tonumber(f.level) or 0) or 0
        local fp=math.min(fl/GOAL_FARM,1); local done=fl>=GOAL_FARM
        if not suppressFarmLevelUpdate then
            local fv=farmRows[i]:FindFirstChild("Val",true)
            if fv then fv.Text="Lv."..fl..(done and " ✓" or ""); fv.TextColor3=done and C.green or C.text end
            setBar(farmRows[i],fp,done and C.barGreen or (fp>=0.5 and C.barOrange or C.barBlue))
            local pp=farmRows[i]:FindFirstChild("Pct",true); if pp then pp.Text=math.floor(fp*100).."%" end
            local hl=farmRows[i]:FindFirstChild("HerbLbl",true)
            if hl then hl.Text="🌿 "..(f and f.production or "--") end
            local predCur,predMax=0,0
            if f then
                predMax=f.capacityMax or 0
                if f.ratePerSec and f.lastCollect and predMax>0 then
                    local el=os.time()-f.lastCollect
                    predCur=math.min((f.capacityCur or 0)+f.ratePerSec*el,predMax); predCur=math.floor(predCur)
                else predCur=f.capacityCur or 0 end
            end
            local cl=farmRows[i]:FindFirstChild("CapLbl",true)
            if cl then cl.Text="📦 "..predCur.."/"..predMax end
            if predMax>0 then setCapBar(farmRows[i],predCur/predMax) end
        end
        local function fmtTime(s) s=math.max(0,math.floor(s))
            if s>=3600 then return string.format("%dh %dm",math.floor(s/3600),math.floor((s%3600)/60))
            elseif s>=60 then return string.format("%dm %ds",math.floor(s/60),s%60) else return s.."s" end
        end
        local timeStr=""
        if f and (f.ratePerSec or 0)>0 and (f.capacityMax or 0)>0 then
            local el=os.time()-(f.lastCollect or os.time())
            local pct=math.min((f.capacityCur or 0)+f.ratePerSec*el,f.capacityMax)
            local half=f.capacityMax*0.5
            if pct<half then timeStr="⏱ 50% in "..fmtTime((half-pct)/f.ratePerSec)
            elseif pct<f.capacityMax then timeStr="⏱ FULL in "..fmtTime((f.capacityMax-pct)/f.ratePerSec)
            else timeStr="⚡ READY TO COLLECT" end
        end
        local tl=farmRows[i]:FindFirstChild("TimeLbl",true)
        if tl then
            tl.Text=suppressFarmLevelUpdate and "⏳ upgrading..." or timeStr
            tl.TextColor3=suppressFarmLevelUpdate and C.sub or
                ((f and (f.capacityCur or 0)>=(f.capacityMax or 1)*0.5) and C.yellow or C.sub)
        end
    end
    local furnLvl=tonumber(data.furnace.level) or 0; local furnP=math.min(furnLvl/GOAL_FURNACE,1)
    local furnDone=furnLvl>=GOAL_FURNACE; local fv2=furnaceRow:FindFirstChild("Val",true)
    if fv2 then fv2.Text="Lv."..(data.furnace.level or "0")..(furnDone and " ✓" or ""); fv2.TextColor3=furnDone and C.green or C.text end
    setBar(furnaceRow,furnP,furnDone and C.barGreen or C.barBlue)
    local fp2=furnaceRow:FindFirstChild("Pct",true); if fp2 then fp2.Text=math.floor(furnP*100).."%" end
    if data.running then
        toggleBtn.Text="■  STOP"; toggleBtn.BackgroundColor3=Color3.fromRGB(175,40,40); dot.BackgroundColor3=C.green
    else
        toggleBtn.Text="▶  START"; toggleBtn.BackgroundColor3=C.accentDim; dot.BackgroundColor3=C.red
    end
    updateFarmWalkLabel()
end

-- ── Helpers ───────────────────────────────────────────────────
local function parseNum(text)
    if not text then return 0 end
    local t=tostring(text):gsub(",",""); local n=tonumber(t); if n then return n end
    local num,suf=t:match("^([%d%.]+)([KMBkmb]?)$")
    if num then
        num=tonumber(num) or 0; suf=suf:upper()
        if suf=="K" then return num*1e3 elseif suf=="M" then return num*1e6 elseif suf=="B" then return num*1e9 else return num end
    end; return 0
end
local function goalsReached()
    if (tonumber(data.level) or 0)<GOAL_LEVEL then return false end
    if (tonumber(data.furnace.level) or 0)<GOAL_FURNACE then return false end
    if data.goldNum<GOAL_GOLD then return false end
    for i=1,5 do if not data.farms[i] or (tonumber(data.farms[i].level) or 0)<GOAL_FARM then return false end end
    return true
end
local function parseCap(text)
    if not text then return 0,0 end
    local a,b=text:match("^(%d+)/(%d+)$"); return tonumber(a) or 0, tonumber(b) or 0
end
local function parseProductionRate(text)
    if not text then return 0 end
    local s=tostring(text):gsub(",",""):gsub("%s",""); local num=s:match("^(%d+)/")
    if num then return (tonumber(num) or 0)/3600 end; return 0
end
local function initFarmTimers()
    local now=os.time()
    for i=1,5 do local f=data.farms[i]; if f then f.ratePerSec=parseProductionRate(f.production); f.lastCollect=now end end
end
local function getPredictedCapacity(i)
    local f=data.farms[i]; if not f then return 0,0 end
    local el=os.time()-(f.lastCollect or os.time())
    return math.floor(math.min((f.capacityCur or 0)+(f.ratePerSec or 0)*el,f.capacityMax or 0)), (f.capacityMax or 0)
end
local function collectFarmsIfNeeded()
    for i=1,5 do
        local cur,max=getPredictedCapacity(i)
        if max>0 and cur>=max*0.5 then
            data.status=string.format("🌿 Collecting Farm %d  (%d/%d)",i,cur,max); updateGUI()
            remoteFarmCol:FireServer(i); task.wait(0.3)
            if data.farms[i] then data.farms[i].capacityCur=0; data.farms[i].lastCollect=os.time() end
            updateGUI()
        end
    end
end
local function allFarmsDone()
    for i=1,5 do if not data.farms[i] or (tonumber(data.farms[i].level) or 0)<GOAL_FARM then return false end end
    return true
end
local function shouldWalkFarms()
    for i=1,5 do
        if not data.farms[i] or (tonumber(data.farms[i].level) or 0)<GOAL_FARM then return true end
    end
    return false
end
local function furnaceDone()
    return (tonumber(data.furnace.level) or 0)>=GOAL_FURNACE
end
local function hasFarmData()
    for i=1,5 do if not data.farms[i] or not data.farms[i].level then return false end end
    return true
end

-- ── Anti-AFK ─────────────────────────────────────────────────
task.spawn(function()
    local vt,jt,mt=0,60,0
    while true do
        task.wait(1); vt+=1; jt+=1; mt+=1
        if vt>=50 then vt=0; pcall(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new()) end) end
        if jt>=110 then jt=0; pcall(function()
            local ch=player.Character; if ch then local hm=ch:FindFirstChildOfClass("Humanoid")
            if hm and hm.Health>0 then hm:ChangeState(Enum.HumanoidStateType.Jumping) end end
        end) end
        if mt>=20 then mt=0; pcall(function()
            local ch=player.Character; if ch then
                local rt=ch:FindFirstChild("HumanoidRootPart"); local hm=ch:FindFirstChildOfClass("Humanoid")
                if rt and hm and hm.Health>0 then hm:MoveTo(rt.Position+rt.CFrame.LookVector*0.5); task.wait(0.5); hm:MoveTo(rt.Position) end
            end
        end) end
    end
end)

-- ── Farm walk ────────────────────────────────────────────────
local function getMyScene()
    local best,bestD=nil,math.huge
    for _,sc in ipairs(workspace:GetChildren()) do
        if sc.Name:find("主场景") then
            for _,v in ipairs(sc:GetDescendants()) do
                if tostring(v:GetAttribute("index"))=="农田1" then
                    local p=v:FindFirstChildWhichIsA("BasePart",true)
                    if p then local d=(p.Position-root.Position).Magnitude; if d<bestD then bestD=d; best=sc end end
                end
            end
        end
    end; return best
end
local function walkTo(part)
    root.CFrame=CFrame.new(part.Position+Vector3.new(15,2,0)); task.wait(0.4)
    humanoid:MoveTo(part.Position); local t=0
    repeat task.wait(0.1); t+=0.1 until (root.Position-part.Position).Magnitude<8 or t>10
end

local function walkAndReadAllFarms()
    if farmWalkLock then print("[AutoGrind] walk skipped — already in progress"); return end
    if not shouldWalkFarms() then print("[AutoGrind] walk skipped — all farms already Lv.80"); return end
    farmWalkLock=true; suppressFarmLevelUpdate=true
    local scene=getMyScene()
    if not scene then data.status="⚠ Scene not found"; updateGUI(); suppressFarmLevelUpdate=false; farmWalkLock=false; return end
    local freshData={}
    for i=1,5 do
        if stopFlag then break end
        data.status=string.format("🚶 Walking to Farm %d...",i); updateGUI()
        local found=false
        for _,v in ipairs(scene:GetDescendants()) do
            if tostring(v:GetAttribute("index"))=="农田"..i then
                local part=v:FindFirstChildWhichIsA("BasePart",true)
                if part then
                    walkTo(part); task.wait(2.5)
                    if farmlandUI.Visible then
                        local ok,result=pcall(function()
                            local list=farmlandUI["背景"]["属性区域"]["属性列表"]["列表"]
                            local cur,max=parseCap(list["容量"]["值"].Text); local prod=list["生产效率"]["值"].Text
                            return {level=list["等级"]["值"].Text,production=prod,capacityCur=cur,capacityMax=max,ratePerSec=parseProductionRate(prod),lastCollect=os.time()}
                        end)
                        if ok and result then freshData[i]=result; data.status=string.format("✓ Farm %d — Lv.%s",i,result.level); updateGUI()
                        else data.status=string.format("⚠ Farm %d read failed",i); updateGUI() end
                    else data.status=string.format("⚠ Farm %d UI not visible",i); updateGUI() end
                    found=true; break
                end
            end
        end
        if not found then data.status=string.format("⚠ Farm %d not found",i); updateGUI() end
    end
    local failedFarms={}
    for i=1,5 do if not freshData[i] then table.insert(failedFarms,i) end end
    if #failedFarms>0 then
        for attempt=1,2 do
            if #failedFarms==0 or stopFlag then break end
            local stillFailed={}
            for _,i in ipairs(failedFarms) do
                if stopFlag then break end
                data.status=string.format("🔄 Retry %d: Farm %d...",attempt,i); updateGUI()
                local found=false
                for _,v in ipairs(scene:GetDescendants()) do
                    if tostring(v:GetAttribute("index"))=="农田"..i then
                        local part=v:FindFirstChildWhichIsA("BasePart",true)
                        if part then
                            walkTo(part); task.wait(2.5)
                            if farmlandUI.Visible then
                                local ok,result=pcall(function()
                                    local list=farmlandUI["背景"]["属性区域"]["属性列表"]["列表"]
                                    local cur,max=parseCap(list["容量"]["值"].Text); local prod=list["生产效率"]["值"].Text
                                    return {level=list["等级"]["值"].Text,production=prod,capacityCur=cur,capacityMax=max,ratePerSec=parseProductionRate(prod),lastCollect=os.time()}
                                end)
                                if ok and result then freshData[i]=result else table.insert(stillFailed,i) end
                            else table.insert(stillFailed,i) end
                            found=true; break
                        end
                    end
                end
                if not found then table.insert(stillFailed,i) end
            end
            failedFarms=stillFailed
        end
    end
    for i=1,5 do if freshData[i] then data.farms[i]=freshData[i] end end
    lastFarmWalk=os.time()
    local allWalkDataOk=hasFarmData()
    nextFarmWalkAt = allWalkDataOk and (os.time()+FARM_WALK_INTERVAL) or -1
    suppressFarmLevelUpdate=false; data.status="✓ Farm data refreshed"; updateGUI()
    print("[AutoGrind] Farm walk done. Lvs:",
        (data.farms[1] and data.farms[1].level or "?"),
        (data.farms[2] and data.farms[2].level or "?"),
        (data.farms[3] and data.farms[3].level or "?"),
        (data.farms[4] and data.farms[4].level or "?"),
        (data.farms[5] and data.farms[5].level or "?"))

    if data.running and not stopFlag then
        local wn=getTargetWorld()
        if wn>0 then
            data.status=not dungeonOverride
                and string.format("🔄 Returning to [%s] W%d after walk...",selectedDifficulty,selectedStage)
                or "🔄 Returning to World "..wn.." after walk..."
            updateGUI()
            local waited=0; local confirmed=false
            repeat
                pcall(function() remoteWorld:FireServer(wn) end)
                task.wait(3); waited+=3
                local ln=tonumber(stageLabel.Text:match("World (%d+)"))
                if ln==wn then confirmed=true; break end
            until waited>=20 or not data.running or stopFlag
            if confirmed then
                pcall(function()
                    if AFK_ARG and AFK_ARG~="" then remoteAFK:FireServer(AFK_ARG) end
                end)
                data.status=not dungeonOverride
                    and string.format("✅ [%s] W%d — back, AFK on",selectedDifficulty,selectedStage)
                    or "✅ World "..wn.." — back, AFK on"
            else
                data.status="⚠ Failed to re-enter — main loop will retry"
            end
            updateGUI()
        end
    end
    farmWalkLock=false
end

-- ── Furnace / World reading ───────────────────────────────────
local function readFurnaceFromUI()
    local ok,r=pcall(function()
        local list=furnaceUI["背景"]["属性区域"]["属性列表"]["列表"]; task.wait(0.05)
        return {level=list["等级"]["值"].Text}
    end); if ok then return r end; return nil
end
local function readHighestWorld()
    local highest=0
    pcall(function()
        local nr=not data.running
        if nr then levelSelectUI.Position=OFFSCREEN; levelSelectUI.Visible=true; task.wait(0.5) end
        local list=levelSelectUI:WaitForChild("背景",2):WaitForChild("右侧界面",2):WaitForChild("世界",2):WaitForChild("列表",2)
        for _,e in ipairs(list:GetChildren()) do
            if e.Name=="世界预制体" then
                local mask=e:FindFirstChild("蒙版"); local nl=e:FindFirstChild("名称")
                if mask and not mask.Visible and nl then
                    local n=tonumber(nl.Text:match("%[Normal%]World (%d+)"))
                    if n and n>highest then highest=n end
                end
            end
        end
        if nr then levelSelectUI.Position=levelSelectOrigPos; levelSelectUI.Visible=levelSelectOrigVis end
    end)
    pcall(function()
        local n=tonumber(stageLabel.Text:match("World (%d+)")); if n and n>highest then highest=n end
    end)
    if highest>data.highestWorld then data.highestWorld=highest; updateGUI() end
    return data.highestWorld
end
syncWorld.OnClientEvent:Connect(function(wd)
    pcall(function()
        if type(wd)~="table" then return end
        local p=wd["进度"]; if type(p)=="table" then
            local w=tonumber(p["世界"]) or 0
            if w>data.highestWorld then data.highestWorld=w; updateGUI() end
        end
    end)
end)

-- ── Background tasks ──────────────────────────────────────────
task.spawn(function()
    while true do task.wait(5)
        if data.infoReady and data.running then pcall(collectFarmsIfNeeded) end
    end
end)
task.spawn(function()
    while true do
        pcall(function()
            data.gold=currencyArea["金币"]["按钮"]["值"].Text
            data.diamonds=currencyArea["钻石"]["按钮"]["值"].Text
            data.herbs=currencyArea["草药"]["按钮"]["值"].Text
            data.xp=currencyArea["等级"]["按钮"]["值"].Text
            data.level=currencyArea["等级"]["按钮"]["图标"]["等级"].Text
            data.goldNum=parseNum(data.gold)
        end)
        if data.running then pcall(readHighestWorld) end
        task.wait(0.5)
    end
end)

task.spawn(function()
    while true do task.wait(10)
        if data.infoReady and data.running then
            local now=os.time()
            local walkNeeded=shouldWalkFarms()
            local shouldWalk=((nextFarmWalkAt==-1) or (nextFarmWalkAt>0 and now>=nextFarmWalkAt)) and walkNeeded
            if shouldWalk and not farmWalkLock then
                data.status=nextFarmWalkAt==-1 and "🚶 Getting farm data..." or "🚶 5min — walking farms..."
                updateGUI(); pcall(walkAndReadAllFarms)
                local furn=readFurnaceFromUI(); if furn then data.furnace=furn end; updateGUI()
                if not hasFarmData() then
                    nextFarmWalkAt=-1
                    data.status="⚠ Some farms missing — retrying walk soon..."; updateGUI()
                end
            end
        end
    end
end)

task.spawn(function()
    while true do
        for i=10,1,-1 do nextRefreshLbl.Text="Next GUI refresh: "..i.."s"; updateFarmWalkLabel(); task.wait(1) end
        updateGUI(); nextRefreshLbl.Text="✓ Updated"; task.wait(1)
    end
end)
task.spawn(function()
    while true do
        if data.running then
            TweenService:Create(dot,TweenInfo.new(0.5),{BackgroundTransparency=0.7}):Play(); task.wait(0.5)
            TweenService:Create(dot,TweenInfo.new(0.5),{BackgroundTransparency=0}):Play(); task.wait(0.5)
        else dot.BackgroundTransparency=0; task.wait(0.3) end
    end
end)

-- ── Grind loop helpers ────────────────────────────────────────
local grindThread=nil
local function getLowestFarm()
    local li,ll=nil,math.huge
    for i=1,5 do if data.farms[i] then local lv=tonumber(data.farms[i].level) or 0; if lv<GOAL_FARM and lv<ll then ll=lv; li=i end end end
    return li,ll
end

local function waitForWorld(wn, timeout)
    local waited=0
    repeat
        task.wait(1); waited+=1
        local txt=stageLabel.Text or ""
        local ln=tonumber(txt:match("World (%d+)%-"))
            or tonumber(txt:match("World (%d+)"))
        if ln==wn then return true end
    until waited>=(timeout or 15) or stopFlag
    return false
end

local function enterDungeon(wn)
    local label=not dungeonOverride
        and string.format("🗺 Entering [%s] W%d...",selectedDifficulty,selectedStage)
        or "🌍 Entering World "..wn.."..."
    data.status=label; updateGUI()
    remoteWorld:FireServer(wn)
    local confirmed=waitForWorld(wn, 15)
    if not hasEnteredDungeonOnce and not stopFlag then
        hasEnteredDungeonOnce=true
        pcall(function()
            if AFK_ARG and AFK_ARG~="" then remoteAFK:FireServer(AFK_ARG) end
        end)
        local okLabel=not dungeonOverride
            and string.format("✅ [%s] W%d — AFK on",selectedDifficulty,selectedStage)
            or "✅ World "..wn.." — AFK on"
        data.status=okLabel; updateGUI()
        print("[AutoGrind] AFK remote fired (first entry)")
    end
    return confirmed
end

local function startGrind()
    if grindThread then return end
    stopFlag=false; data.running=true; nextFarmWalkAt=-1; updateGUI(); openUIPanels()
    grindThread=task.spawn(function()

        if not hasFarmData() then
            data.status="🚶 Getting farm data first..."; updateGUI()
            walkAndReadAllFarms()
            local furn=readFurnaceFromUI(); if furn then data.furnace=furn end
            initFarmTimers()
        end
        data.infoReady=true

        if not dungeonOverride then readHighestWorld() end

        local targetW=getTargetWorld()
        if targetW>0 and not stopFlag then enterDungeon(targetW) end

        -- ── Death handler ─────────────────────────────────────────
        local lastReenter=0

        task.spawn(function()
            while not stopFlag and data.running do
                local ch = player.Character or player.CharacterAdded:Wait()
                local hm = ch:WaitForChild("Humanoid")
                hm.Died:Wait()
                local newCh = player.CharacterAdded:Wait()
                RunService.Heartbeat:Wait()
                root     = newCh:WaitForChild("HumanoidRootPart")
                humanoid = newCh:WaitForChild("Humanoid")
                if not stopFlag and data.running and not farmWalkLock then
                    local w = getTargetWorld()
                    if w > 0 then
                        lastReenter = os.time()
                        data.status = not dungeonOverride
                            and string.format("💀 Re-entering [%s] W%d", selectedDifficulty, selectedStage)
                            or "💀 Re-entering World "..w
                        updateGUI()
                        local waited = 0
                        local confirmed = false
                        repeat
                            pcall(function() remoteWorld:FireServer(w) end)
                            task.wait(0.5); waited += 0.5
                            local ln = tonumber(stageLabel.Text:match("World (%d+)"))
                            if ln == w then confirmed = true end
                        until confirmed or waited >= 30 or stopFlag or not data.running
                        if confirmed then
                            data.status = not dungeonOverride
                                and string.format("✅ [%s] W%d — back", selectedDifficulty, selectedStage)
                                or "✅ World "..w.." — back"
                            updateGUI()
                        end
                    end
                end
            end
        end)

        task.spawn(function()
            while not stopFlag and data.running do
                task.wait(0.1)
                pcall(function()
                    local w=getTargetWorld(); if w==0 then return end
                    local now=os.time()
                    local inScene=false
                    for _,sc in ipairs(workspace:GetChildren()) do
                        if sc.Name:find("世界") then
                            for _,v in ipairs(sc:GetDescendants()) do
                                local bp=v:IsA("BasePart") and v or nil
                                if bp and (bp.Position-root.Position).Magnitude<200 then
                                    inScene=true; break
                                end
                            end
                        end
                        if inScene then break end
                    end
                    if not inScene and not farmWalkLock and (now-lastReenter)>=2 then
                        lastReenter=now
                        data.status=not dungeonOverride
                            and string.format("💀 Died — re-entering [%s] W%d", selectedDifficulty, selectedStage)
                            or "💀 Died — re-entering World "..w
                        updateGUI()
                        remoteWorld:FireServer(w)
                        local waited=0
                        local ln=nil
                        repeat task.wait(1); waited+=1
                            ln=tonumber(stageLabel.Text:match("World (%d+)"))
                        until ln==w or waited>=10 or stopFlag
                        if ln==w then
                            data.status=not dungeonOverride
                                and string.format("✅ [%s] W%d — back", selectedDifficulty, selectedStage)
                                or "✅ World "..w.." — back"
                            updateGUI()
                        end
                    end
                end)
            end
        end)

        -- ── Phase 1: Farm upgrades ─────────────────────────────────
        if not allFarmsDone() and not stopFlag then
            data.status="[P1] Farm upgrades..."; updateGUI()
            suppressFarmLevelUpdate=true
            task.spawn(function()
                while not stopFlag and not allFarmsDone() do
                    local ci,cl=getLowestFarm(); if not ci then break end
                    remoteFarmUp:FireServer(ci)
                    if data.farms[ci] then
                        data.farms[ci].level=tostring((tonumber(data.farms[ci].level) or 0)+1)
                    end
                    task.wait(0.05)
                end
            end)
            while not stopFlag and not allFarmsDone() do
                collectFarmsIfNeeded()
                task.wait(5)
            end
            suppressFarmLevelUpdate=false
            if not stopFlag then
                collectFarmsIfNeeded()
                data.status="[P1] ✓ All farms Lv.80!"; updateGUI(); task.wait(1)
            end
        end

        -- ── Phase 2: Furnace upgrades ──────────────────────────────
        if not furnaceDone() and not stopFlag then
            furnaceUI.Position=OFFSCREEN; furnaceUI.Visible=true; task.wait(0.5)
            local fresh=readFurnaceFromUI(); if fresh then data.furnace=fresh end
            updateGUI()
            task.spawn(function()
                while not stopFlag and not furnaceDone() do
                    remoteFurnaceUp:FireServer()
                    task.wait(0.05)
                end
            end)
            while not stopFlag and not furnaceDone() do
                collectFarmsIfNeeded()
                task.wait(2)
            end
            if not stopFlag then data.status="[P2] ✓ Furnace Lv.80!"; updateGUI(); task.wait(1) end
        end

        -- ── Phase 3: Gold grind ────────────────────────────────────
        if not stopFlag then
            data.status="[P3] Gold grind → 246M"; updateGUI()
            while not stopFlag and data.goldNum<GOAL_GOLD do
                collectFarmsIfNeeded()
                task.wait(5)
                updateGUI()
            end
        end

        -- ── Done ──────────────────────────────────────────────────
        suppressFarmLevelUpdate=false; data.running=false
        data.status=goalsReached() and "🎉 ALL GOALS REACHED!" or "Paused — press START to resume."
        nextFarmWalkAt=-1; updateGUI(); grindThread=nil
    end)
end

local function stopGrind()
    stopFlag=true; data.running=false
    suppressFarmLevelUpdate=false; nextFarmWalkAt=-1
    hasEnteredDungeonOnce=false
    data.status="Paused — press START to resume."
    closeUIPanels(); updateGUI()
    task.delay(0.5, function() grindThread=nil end)
end

toggleBtn.MouseButton1Click:Connect(function()
    if data.running then stopGrind() else startGrind() end
end)

updateGUI()
print("[AutoGrind v3] Ready — press START")
