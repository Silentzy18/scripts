-- ╔══════════════════════════════════════════════════════════════╗
-- ║          AUTO GRIND v3  —  Tabbed Edition                   ║
-- ║  Tab 1: GRIND  (Farm / Furnace / Gold / Stats)              ║
-- ║  Tab 2: AUTO   (Battlepass / Event / Daily / Investment)     ║
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

-- ── GUI paths ──────────────────────────────────────────────────
local farmlandUI    = player.PlayerGui:WaitForChild("GUI"):WaitForChild("二级界面"):WaitForChild("农田")
local furnaceUI     = player.PlayerGui:WaitForChild("GUI"):WaitForChild("二级界面"):WaitForChild("炼丹炉")
local currencyArea  = player.PlayerGui:WaitForChild("GUI"):WaitForChild("主界面"):WaitForChild("主城"):WaitForChild("货币区域")
local stageLabel    = player.PlayerGui:WaitForChild("GUI"):WaitForChild("主界面"):WaitForChild("战斗"):WaitForChild("关卡信息"):WaitForChild("文本")
local levelSelectUI = player.PlayerGui:WaitForChild("GUI"):WaitForChild("二级界面"):WaitForChild("关卡选择")

-- ── Auto-Claim GUI paths ───────────────────────────────────────
local bpMissionList    = player.PlayerGui:WaitForChild("GUI"):WaitForChild("二级界面"):WaitForChild("商店"):WaitForChild("通行证任务"):WaitForChild("背景"):WaitForChild("任务列表")
local dailyMissionList = player.PlayerGui:WaitForChild("GUI"):WaitForChild("二级界面"):WaitForChild("每日任务"):WaitForChild("背景"):WaitForChild("任务列表")
local mainMissionBtn   = player.PlayerGui:WaitForChild("GUI"):WaitForChild("主界面"):WaitForChild("主城"):WaitForChild("主线任务"):WaitForChild("按钮")
local eventGiftList    = player.PlayerGui:WaitForChild("GUI"):WaitForChild("二级界面"):WaitForChild("节日活动商店"):WaitForChild("背景"):WaitForChild("右侧界面"):WaitForChild("在线奖励"):WaitForChild("列表")

-- ── Stats Tracker data sources ─────────────────────────────────
local statsNode  = player:WaitForChild("值"):WaitForChild("统计")
local killsValue = statsNode:WaitForChild("杀敌数")
local goldValue  = player:WaitForChild("值"):WaitForChild("货币"):WaitForChild("金币")
local expLabel   = player.PlayerGui:WaitForChild("GUI"):WaitForChild("主界面")
    :WaitForChild("主城"):WaitForChild("货币区域")
    :WaitForChild("等级"):WaitForChild("按钮"):WaitForChild("值")

-- ── S() helper ────────────────────────────────────────────────
local function S(...)
    local r = ""
    for _, v in ipairs({...}) do r = r .. string.char(v) end
    return r
end

local AFK_ARG         = S(232,135,170,229,138,168,230,136,152,230,150,151)
local RS              = ReplicatedStorage:WaitForChild(S(228,186,139,228,187,182)):WaitForChild(S(229,133,172,231,148,168))
local remoteWorld     = RS:WaitForChild(S(229,133,179,229,141,161)):WaitForChild(S(232,191,155,229,133,165,228,184,150,231,149,140,229,133,179,229,141,161))
local remoteFarmUp    = RS:WaitForChild(S(229,134,156,231,148,176)):WaitForChild(S(229,141,135,231,186,167))
local remoteFarmCol   = RS:WaitForChild(S(229,134,156,231,148,176)):WaitForChild(S(233,135,135,233,155,134))
local remoteAFK       = RS:WaitForChild(S(232,174,190,231,189,174)):WaitForChild(S(231,142,169,229,174,182,228,191,174,230,148,185,232,174,190,231,189,174))
local remoteFurnaceUp = RS:WaitForChild(S(231,130,188,228,184,185)):WaitForChild(S(229,141,135,231,186,167))

-- ── Auto-Claim remotes ─────────────────────────────────────────
-- 事件→公用→月通行证→完成任务
local remoteBPClaim    = RS:WaitForChild(S(230,156,136,233,128,154,232,161,140,232,175,129)):WaitForChild(S(229,174,140,230,136,144,228,187,187,229,138,161))
-- 事件→公用→月通行证→获取数据
local remoteBPRefresh  = RS:WaitForChild(S(230,156,136,233,128,154,232,161,140,232,175,129)):WaitForChild(S(232,142,183,229,143,150,230,149,176,230,141,174))
-- 事件→公用→每日任务→领取奖励
local remoteDailyClaim = RS:WaitForChild(S(230,175,143,230,151,165,228,187,187,229,138,161)):WaitForChild(S(233,162,134,229,143,150,229,165,150,229,138,177))
-- 事件→公用→主线任务→领取奖励
local remoteMainClaim  = RS:WaitForChild(S(228,184,187,231,186,191,228,187,187,229,138,161)):WaitForChild(S(233,162,134,229,143,150,229,165,150,229,138,177))
-- 事件→公用→节日活动→领取奖励
local remoteEventClaim = RS:WaitForChild(S(232,138,130,230,151,165,230,180,187,229,138,168)):WaitForChild(S(233,162,134,229,143,150,229,165,150,229,138,177))
-- 事件→公用→商店→银行→领取理财  /  购买理财
local remoteInvCollect = RS:WaitForChild(S(229,149,134,229,186,151)):WaitForChild(S(233,147,182,232,161,140)):WaitForChild(S(233,162,134,229,143,150,231,144,134,232,180,162))
local remoteInvBuy     = RS:WaitForChild(S(229,149,134,229,186,151)):WaitForChild(S(233,147,182,232,161,140)):WaitForChild(S(232,180,173,228,185,176,231,144,134,232,180,162))
-- 宗门→贡献 (guild auto-contribute)
local remoteGuildContribute = RS:WaitForChild(S(229,133,172,228,188,154)):WaitForChild(S(230,141,144,231,140,174))
local remoteGuildShopBuy = ReplicatedStorage
    :WaitForChild("事件"):WaitForChild("公用")
    :WaitForChild("公会"):WaitForChild("兑换")

local syncWorld = ReplicatedStorage
    :WaitForChild("事件"):WaitForChild("公用")
    :WaitForChild("关卡"):WaitForChild("同步世界关卡数据")

-- ── Constants ─────────────────────────────────────────────────
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

local DIFFICULTIES       = {"Easy","Normal","Hard","Expert","Master"}
local DIFF_OFFSET        = {Easy=0,Normal=20,Hard=40,Expert=60,Master=80}
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

-- ── Auto-Claim toggle states ───────────────────────────────────
local autoClaimState = {
    battlepass = false,
    event      = false,
    daily      = false,
    investment = false,
    guild      = false,
    guildherb  = false,
}

-- ── Colors ────────────────────────────────────────────────────
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
    kRed=Color3.fromRGB(255,72,88), kRedDim=Color3.fromRGB(120,28,38), kRedDeep=Color3.fromRGB(55,12,18),
    gGold=Color3.fromRGB(255,195,45), gGoldDim=Color3.fromRGB(130,90,12), gGoldDeep=Color3.fromRGB(55,36,5),
    xBlue=Color3.fromRGB(80,165,255), xBlueDim=Color3.fromRGB(35,85,185), xBlueDeep=Color3.fromRGB(14,36,85),
    textDim=Color3.fromRGB(120,140,185), textFaint=Color3.fromRGB(60,78,120),
    borderHi=Color3.fromRGB(65,115,215), bg2=Color3.fromRGB(16,20,36),
    tabActive=Color3.fromRGB(50,110,220), tabInactive=Color3.fromRGB(18,24,44),
    switchOn=Color3.fromRGB(45,195,95), switchOff=Color3.fromRGB(55,35,35),
}
local function diffColor(d)
    if d=="Easy" then return C.easy elseif d=="Hard" then return C.hard
    elseif d=="Expert" then return C.expert elseif d=="Master" then return C.orange
    else return C.normal end
end

-- ══════════════════════════════════════════════════════════════
-- ║  GUI SCAFFOLD
-- ══════════════════════════════════════════════════════════════
local gui = Instance.new("ScreenGui")
gui.Name="AutoGrindV3"; gui.ResetOnSpawn=false
gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; gui.Parent=player.PlayerGui

local main = Instance.new("Frame",gui)
main.Size=UDim2.new(0,380,0,100); main.Position=UDim2.new(0,16,0,16)
main.BackgroundColor3=C.bg; main.BorderSizePixel=0; main.ClipsDescendants=false
Instance.new("UICorner",main).CornerRadius=UDim.new(0,14)
local mainStroke=Instance.new("UIStroke",main); mainStroke.Color=C.border; mainStroke.Thickness=1.5

-- drag
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

-- ── helpers ───────────────────────────────────────────────────
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

-- ── HEADER ────────────────────────────────────────────────────
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

-- ── TAB BAR ───────────────────────────────────────────────────
local tabBar = mkF(main,UDim2.new(1,0,0,34),UDim2.new(0,0,0,52),C.panel)

local TAB_NAMES = {"⚔  GRIND","🤖  AUTO"}
local tabBtns   = {}
local activeTab = 1

local tabPages  = {}   -- tabPages[1] = grind scroll, tabPages[2] = auto scroll

local function activateTab(idx)
    activeTab = idx
    for i,b in ipairs(tabBtns) do
        if i==idx then
            b.BackgroundColor3 = C.tabActive
            b.TextColor3       = Color3.new(1,1,1)
        else
            b.BackgroundColor3 = C.tabInactive
            b.TextColor3       = C.sub
        end
    end
    for i,pg in ipairs(tabPages) do
        pg.Visible = (i==idx)
    end
end

for i,name in ipairs(TAB_NAMES) do
    local b = Instance.new("TextButton",tabBar)
    b.Size             = UDim2.new(0.5,-3,1,-8)
    b.Position         = UDim2.new((i-1)*0.5, i==1 and 4 or -1, 0, 4)
    b.BackgroundColor3 = C.tabInactive
    b.BorderSizePixel  = 0
    b.Text             = name
    b.TextColor3       = C.sub
    b.Font             = Enum.Font.GothamBold
    b.TextSize         = 13
    b.AutoButtonColor  = false
    Instance.new("UICorner",b).CornerRadius = UDim.new(0,6)
    b.MouseButton1Click:Connect(function() activateTab(i) end)
    tabBtns[i] = b
end

-- ── SHARED scroll factory ──────────────────────────────────────
local SCROLL_TOP = 52+34  -- header + tabbar

local function makeScrollPage()
    local scr = Instance.new("ScrollingFrame",main)
    scr.Size=UDim2.new(1,0,1,-SCROLL_TOP); scr.Position=UDim2.new(0,0,0,SCROLL_TOP)
    scr.BackgroundTransparency=1; scr.BorderSizePixel=0
    scr.ScrollBarThickness=3; scr.ScrollBarImageColor3=C.border
    scr.CanvasSize=UDim2.new(0,0,0,0); scr.AutomaticCanvasSize=Enum.AutomaticSize.Y
    scr.Visible=false

    local cnt = Instance.new("Frame",scr)
    cnt.Size=UDim2.new(1,-24,0,10); cnt.Position=UDim2.new(0,12,0,8)
    cnt.BackgroundTransparency=1; cnt.BorderSizePixel=0; cnt.AutomaticSize=Enum.AutomaticSize.Y

    local lay = Instance.new("UIListLayout",cnt)
    lay.SortOrder=Enum.SortOrder.LayoutOrder; lay.Padding=UDim.new(0,6)
    lay.FillDirection=Enum.FillDirection.Vertical

    lay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        if scr.Visible then
            local h = lay.AbsoluteContentSize.Y+20
            main.Size=UDim2.new(0,380,0,math.clamp(h+SCROLL_TOP+8,100,720))
        end
    end)

    return scr, cnt
end

-- create both pages
local grindScroll, grindContent = makeScrollPage()
local autoScroll,  autoContent  = makeScrollPage()
tabPages[1] = grindScroll
tabPages[2] = autoScroll

-- ══════════════════════════════════════════════════════════════
-- ║  GRIND TAB — row helpers that write into grindContent
-- ══════════════════════════════════════════════════════════════
local function mkSectionHeader(cnt,txt,order)
    local l=mkL(cnt,txt,UDim2.new(1,0,0,20),nil,C.sub,Enum.Font.GothamBold,12,Enum.TextXAlignment.Left)
    l.LayoutOrder=order; return l
end
local function mkInfoRow(cnt,icon,label,order)
    local row=mkF(cnt,UDim2.new(1,0,0,42),nil,C.panelB,8,true); row.LayoutOrder=order
    mkL(row,icon,UDim2.new(0,30,1,0),UDim2.new(0,8,0,0),C.text,Enum.Font.Gotham,18,Enum.TextXAlignment.Center)
    mkL(row,label,UDim2.new(0.48,0,1,0),UDim2.new(0,40,0,0),C.sub,Enum.Font.Gotham,13)
    local v=mkL(row,"---",UDim2.new(0.5,-4,1,0),UDim2.new(0.5,0,0,0),C.accent,Enum.Font.GothamBold,15,Enum.TextXAlignment.Right); v.Name="Val"
    local s=mkL(row,"",UDim2.new(1,-42,0,12),UDim2.new(0,42,1,-13),C.sub,Enum.Font.Gotham,11,Enum.TextXAlignment.Right); s.Name="Sub"
    return row
end
local function mkStatRow(cnt,icon,label,goalStr,order,showFarmExtra)
    local h=showFarmExtra and 100 or 64
    local wrap=Instance.new("Frame",cnt)
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

-- ── GRIND TAB rows ─────────────────────────────────────────────
local worldRow  = mkInfoRow(grindContent,"🌍","Highest World",1)
local statusRow = mkInfoRow(grindContent,"📡","Status",2)

local _dSep0=mkF(grindContent,UDim2.new(1,0,0,1),nil,C.border); _dSep0.LayoutOrder=3
mkSectionHeader(grindContent,"  🗺 DUNGEON SELECTOR",4)
local dungeonPanel=mkF(grindContent,UDim2.new(1,0,0,110),nil,C.panelB,8,true); dungeonPanel.LayoutOrder=5

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
    local wn=DIFF_OFFSET[selectedDifficulty]+selectedStage
    dungeonPreviewLbl.Text=string.format("[%s] W%d (arg:%d)",selectedDifficulty,selectedStage,wn)
    dungeonPreviewLbl.TextColor3=diffColor(selectedDifficulty)
    if dungeonOverride then overrideToggle.Text="AUTO"; overrideToggle.BackgroundColor3=C.accentDim
    else overrideToggle.Text="MANUAL"; overrideToggle.BackgroundColor3=C.green end
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

local _d1=mkF(grindContent,UDim2.new(1,0,0,1),nil,C.border); _d1.LayoutOrder=6
mkSectionHeader(grindContent,"  PLAYER",7)
local levelRow=mkStatRow(grindContent,"🧑","Player Level","300",8,false)
local goldRow =mkStatRow(grindContent,"💰","Gold","246M",9,false)
local _d2=mkF(grindContent,UDim2.new(1,0,0,1),nil,C.border); _d2.LayoutOrder=10
mkSectionHeader(grindContent,"  ① FARMLANDS",11)
local farmRows={}
for i=1,5 do farmRows[i]=mkStatRow(grindContent,"🌾","Farm "..i,"Lv.80",11+i,true) end
local _d3=mkF(grindContent,UDim2.new(1,0,0,1),nil,C.border); _d3.LayoutOrder=17
mkSectionHeader(grindContent,"  ② FURNACE",18)
local furnaceRow=mkStatRow(grindContent,"🔥","Furnace Level","Lv.80",19,false)
local _d4=mkF(grindContent,UDim2.new(1,0,0,1),nil,C.border); _d4.LayoutOrder=20

-- ── STATS TRACKER (inside Grind tab) ──────────────────────────
mkSectionHeader(grindContent,"  ③ STATS TRACKER  (KPS · GPS · XPS)",21)

local function fmtStat(n,decimals)
    decimals=decimals or 1
    if math.abs(n)>=1e9 then return string.format("%."..decimals.."fB",n/1e9)
    elseif math.abs(n)>=1e6 then return string.format("%."..decimals.."fM",n/1e6)
    elseif math.abs(n)>=1e3 then return string.format("%."..decimals.."fK",n/1e3)
    else return string.format("%d",math.floor(n+0.5)) end
end
local function getAccurateExp(text)
    local left,right=text:match("([^/]+)/([^/]+)")
    if not left or not right then return 0 end
    local function cvt(s) s=s:gsub("K","000"):gsub("M","000000"):gsub("B","000000000"); return tonumber(s) or 0 end
    local l,r=cvt(left),cvt(right); if r==0 then return 0 end; return r*(l/r)
end
local STAT_UNITS={"/sec","/min","/hour"}; local STAT_MULTIPLIER={1,60,3600}
local stats_data={
    kps={label="KPS",sublabel="Kills",icon="⚔",accent=C.kRed,accentDim=C.kRedDim,accentDeep=C.kRedDeep,unitIdx=1,history={},current=0,avg=0,getValue=function() return killsValue.Value end,prev=0,prevTime=tick()},
    gps={label="GPS",sublabel="Gold",icon="💰",accent=C.gGold,accentDim=C.gGoldDim,accentDeep=C.gGoldDeep,unitIdx=1,history={},current=0,avg=0,getValue=function() return goldValue.Value end,prev=0,prevTime=tick()},
    xps={label="XPS",sublabel="Exp",icon="✨",accent=C.xBlue,accentDim=C.xBlueDim,accentDeep=C.xBlueDeep,unitIdx=1,history={},current=0,avg=0,getValue=function() return getAccurateExp(expLabel.Text) end,prev=0,prevTime=tick()},
}
local STAT_ORDER={"kps","gps","xps"}
for _,s in pairs(stats_data) do pcall(function() s.prev=s.getValue() end) end
local statRowRefs={}
local function makeTrackerRow(key,order)
    local s=stats_data[key]
    local wrap=Instance.new("Frame",grindContent); wrap.Size=UDim2.new(1,0,0,56); wrap.BackgroundTransparency=1; wrap.BorderSizePixel=0; wrap.LayoutOrder=order
    local row=mkF(wrap,UDim2.new(1,0,0,56),nil,C.panelB,8,true)
    local bar=Instance.new("Frame",row); bar.Size=UDim2.new(0,3,0,36); bar.Position=UDim2.new(0,0,0.5,-18); bar.BackgroundColor3=s.accent; bar.BorderSizePixel=0; Instance.new("UICorner",bar).CornerRadius=UDim.new(0,2)
    local iconBox=mkF(row,UDim2.new(0,34,0,34),UDim2.new(0,10,0.5,-17),s.accentDeep,8)
    local iconStk=Instance.new("UIStroke",iconBox); iconStk.Color=s.accentDim; iconStk.Thickness=1
    mkL(iconBox,s.icon,UDim2.new(1,0,1,0),nil,C.text,Enum.Font.Gotham,17,Enum.TextXAlignment.Center,Enum.TextYAlignment.Center)
    mkL(row,s.label,UDim2.new(0,40,0,16),UDim2.new(0,52,0,9),s.accent,Enum.Font.GothamBold,13)
    mkL(row,s.sublabel,UDim2.new(0,50,0,13),UDim2.new(0,52,0,26),C.textFaint,Enum.Font.Gotham,11)
    local valLbl=mkL(row,"---",UDim2.new(0,110,0,22),UDim2.new(0,108,0,8),C.text,Enum.Font.GothamBold,20); valLbl.Name="StatVal_"..key
    local unitLbl=mkL(row,"/sec",UDim2.new(0,110,0,13),UDim2.new(0,108,0,30),C.textDim,Enum.Font.Gotham,11); unitLbl.Name="StatUnit_"..key
    local unitBtn=Instance.new("TextButton",row); unitBtn.Size=UDim2.new(0,60,0,22); unitBtn.Position=UDim2.new(1,-68,0.5,-11)
    unitBtn.BackgroundColor3=s.accentDeep; unitBtn.BorderSizePixel=0; unitBtn.Text="/sec"; unitBtn.TextColor3=s.accent; unitBtn.Font=Enum.Font.GothamBold; unitBtn.TextSize=11; unitBtn.AutoButtonColor=false
    Instance.new("UICorner",unitBtn).CornerRadius=UDim.new(0,5); local ubStk=Instance.new("UIStroke",unitBtn); ubStk.Color=s.accentDim; ubStk.Thickness=1
    unitBtn.MouseEnter:Connect(function() TweenService:Create(unitBtn,TweenInfo.new(0.12),{BackgroundColor3=s.accentDim}):Play() end)
    unitBtn.MouseLeave:Connect(function() TweenService:Create(unitBtn,TweenInfo.new(0.12),{BackgroundColor3=s.accentDeep}):Play() end)
    unitBtn.MouseButton1Click:Connect(function()
        s.unitIdx=s.unitIdx%#STAT_UNITS+1; local u=STAT_UNITS[s.unitIdx]; unitBtn.Text=u; unitLbl.Text=u
    end)
    statRowRefs[key]={valLbl=valLbl,unitLbl=unitLbl,unitBtn=unitBtn}
end
makeTrackerRow("kps",22); makeTrackerRow("gps",23); makeTrackerRow("xps",24)
local _d5=mkF(grindContent,UDim2.new(1,0,0,1),nil,C.border); _d5.LayoutOrder=25

-- footer in grind tab
local footerWrap=Instance.new("Frame",grindContent)
footerWrap.Size=UDim2.new(1,0,0,38); footerWrap.BackgroundTransparency=1; footerWrap.BorderSizePixel=0; footerWrap.LayoutOrder=26
local nextRefreshLbl=mkL(footerWrap,"Next GUI refresh: --s",UDim2.new(1,0,0,18),UDim2.new(0,0,0,0),C.sub,Enum.Font.Gotham,12,Enum.TextXAlignment.Center)
local nextFarmLbl=mkL(footerWrap,"🚶 Next farm walk: --",UDim2.new(1,0,0,18),UDim2.new(0,0,0,20),C.yellow,Enum.Font.Gotham,12,Enum.TextXAlignment.Center)

-- ══════════════════════════════════════════════════════════════
-- ║  AUTO TAB — toggle-switch rows
-- ══════════════════════════════════════════════════════════════

-- status labels for each toggle (updated by loops)
local autoStatusLabels = {}

-- helper: make a toggle-switch card in AUTO tab
local function mkToggleCard(cnt, icon, title, desc, key, order)
    local h = 72
    local wrap = Instance.new("Frame",cnt)
    wrap.Size=UDim2.new(1,0,0,h); wrap.BackgroundTransparency=1; wrap.BorderSizePixel=0; wrap.LayoutOrder=order

    local row = mkF(wrap,UDim2.new(1,0,0,h),nil,C.panelB,8,true)

    -- icon
    local iconBox = mkF(row,UDim2.new(0,36,0,36),UDim2.new(0,10,0.5,-18),Color3.fromRGB(20,28,58),8)
    local iconStk = Instance.new("UIStroke",iconBox); iconStk.Color=C.border; iconStk.Thickness=1
    mkL(iconBox,icon,UDim2.new(1,0,1,0),nil,C.text,Enum.Font.Gotham,18,Enum.TextXAlignment.Center,Enum.TextYAlignment.Center)

    -- title + desc + status
    mkL(row,title,UDim2.new(0,200,0,18),UDim2.new(0,54,0,10),C.text,Enum.Font.GothamBold,13)
    mkL(row,desc,UDim2.new(0,200,0,14),UDim2.new(0,54,0,29),C.sub,Enum.Font.Gotham,11)
    local statusLbl = mkL(row,"● Idle",UDim2.new(0,200,0,13),UDim2.new(0,54,0,49),C.sub,Enum.Font.Gotham,10)
    statusLbl.Name = "AutoStatus_"..key
    autoStatusLabels[key] = statusLbl

    -- toggle switch (right side)
    local switchBg = mkF(row,UDim2.new(0,50,0,26),UDim2.new(1,-62,0.5,-13),C.switchOff,13)
    local switchKnob = mkF(switchBg,UDim2.new(0,20,0,20),UDim2.new(0,3,0.5,-10),Color3.new(1,1,1),10)

    local function refreshSwitch()
        local on = autoClaimState[key]
        TweenService:Create(switchBg,TweenInfo.new(0.18),{BackgroundColor3=on and C.switchOn or C.switchOff}):Play()
        TweenService:Create(switchKnob,TweenInfo.new(0.18),{Position=on and UDim2.new(0,27,0.5,-10) or UDim2.new(0,3,0.5,-10)}):Play()
        if not on then statusLbl.Text="● Idle"; statusLbl.TextColor3=C.sub end
    end

    switchBg.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            autoClaimState[key] = not autoClaimState[key]
            refreshSwitch()
        end
    end)
    refreshSwitch()
    return row
end

-- ── AUTO TAB header label ──────────────────────────────────────
mkSectionHeader(autoContent,"   AUTO CLAIM",1)
local autoDescLbl = mkL(autoContent,"Toggles run independently — no need to START grind.",UDim2.new(1,0,0,16),nil,C.sub,Enum.Font.Gotham,11,Enum.TextXAlignment.Left)
autoDescLbl.LayoutOrder=2

local _ad0=mkF(autoContent,UDim2.new(1,0,0,1),nil,C.border); _ad0.LayoutOrder=3

-- ── Toggle cards ───────────────────────────────────────────────
mkToggleCard(autoContent,"📜","Battlepass Quest Claim","Auto-claims completed monthly pass tasks","battlepass",4)
mkToggleCard(autoContent,"🎁","Event / Online Rewards","Auto-claims timed event gift boxes (1–6)","event",5)
mkToggleCard(autoContent,"📅","Daily Task Claim","Auto-claims completed daily tasks","daily",6)
mkToggleCard(autoContent,"💹","Auto Investment","Collects & re-buys bank investments every 10 min","investment",7)
mkToggleCard(autoContent,"⚔️","Guild Auto-Contribute","Auto-contributes to your guild every 5 min","guild",8)
mkToggleCard(autoContent,"🌿","Guild Shop — Auto Buy Herbs","Buys all available Herbs from guild shop","guildherb",9)

local _ad1=mkF(autoContent,UDim2.new(1,0,0,1),nil,C.border); _ad1.LayoutOrder=10

-- last-run log panel
mkSectionHeader(autoContent,"  📋 ACTIVITY LOG",11)
local logPanel = mkF(autoContent,UDim2.new(1,0,0,110),nil,Color3.fromRGB(10,13,24),8,true); logPanel.LayoutOrder=12
local logLines = {}
local logLabels = {}
for i=1,5 do
    local lbl = mkL(logPanel,"",UDim2.new(1,-12,0,16),UDim2.new(0,6,0,(i-1)*20),C.sub,Enum.Font.Gotham,11)
    logLabels[i] = lbl
end

local function pushLog(msg)
    table.insert(logLines,1,msg)
    if #logLines>5 then table.remove(logLines) end
    for i,lbl in ipairs(logLabels) do
        lbl.Text = logLines[i] or ""
        lbl.TextColor3 = i==1 and C.text or C.sub
    end
end

-- auto tab footer
local autoFooterWrap = Instance.new("Frame",autoContent)
autoFooterWrap.Size=UDim2.new(1,0,0,24); autoFooterWrap.BackgroundTransparency=1; autoFooterWrap.BorderSizePixel=0; autoFooterWrap.LayoutOrder=13
mkL(autoFooterWrap,"Loops check every ~3s while toggle is ON",UDim2.new(1,0,1,0),nil,C.sub,Enum.Font.Gotham,11,Enum.TextXAlignment.Center)

-- ══════════════════════════════════════════════════════════════
-- ║  AUTO-CLAIM LOGIC
-- ══════════════════════════════════════════════════════════════

-- ── helpers ───────────────────────────────────────────────────
local function setAutoStatus(key, msg, col)
    local lbl = autoStatusLabels[key]
    if lbl then lbl.Text="● "..msg; lbl.TextColor3=col or C.yellow end
end

-- Rename battlepass task list items so we can index them
local bpNamesReady = false
local function initBPNames()
    if bpNamesReady then return end
    pcall(function()
        for i=1,12 do
            local item = bpMissionList:FindFirstChild("任务项预制体")
            if item then item.Name=tostring(i) end
        end
    end)
    bpNamesReady=true
end

-- ── Battlepass loop ────────────────────────────────────────────
task.spawn(function()
    while true do
        task.wait(3)
        if autoClaimState.battlepass then
            setAutoStatus("battlepass","Checking..."); pcall(function()
                initBPNames()
                local claimed=0
                for _,child in ipairs(bpMissionList:GetChildren()) do
                    if child:IsA("Frame") and child.Visible then
                        local idx=tonumber(child.Name)
                        local nl=child:FindFirstChild("名称")
                        if idx and nl then
                            local a,b=nl.Text:match("%((%d+)/(%d+)%)")
                            if a and b and tonumber(a)/tonumber(b)>=1 then
                                remoteBPClaim:FireServer(idx); task.wait(0.3)
                                remoteBPRefresh:FireServer(); task.wait(0.2)
                                claimed+=1
                            end
                        end
                    end
                end
                if claimed>0 then
                    local msg="[BP] Claimed "..claimed.." task(s)"
                    setAutoStatus("battlepass","Claimed "..claimed,C.green); pushLog(msg)
                else
                    setAutoStatus("battlepass","Watching...",C.sub)
                end
            end)
        end
    end
end)


-- ── Guild Shop Auto-Buy Herbs ─────────────────────────────────
local guildShopList = player.PlayerGui
    :WaitForChild("GUI")
    :WaitForChild("二级界面")
    :WaitForChild("公会")
    :WaitForChild("背景")
    :WaitForChild("右侧界面")
    :WaitForChild("商店")
    :WaitForChild("列表")

task.spawn(function()
    while true do
        task.wait(5)
        if autoClaimState.guildherb then
            setAutoStatus("guildherb","Scanning...",C.yellow)
            pcall(function()
                local bought = 0
                local serverIdx = 0
                for _, item in ipairs(guildShopList:GetChildren()) do
                    if item:IsA("Frame") then
                        serverIdx += 1
                        local btn     = item:FindFirstChild("按钮")
                        local nameLbl = btn and btn:FindFirstChild("名称")
                        local soldOut = btn and btn:FindFirstChild("蒙版")
                        local itemName = nameLbl and nameLbl.Text or ""
                        if (itemName:lower():find("herb") or itemName:find("草药")) and soldOut and not soldOut.Visible then
                            remoteGuildShopBuy:FireServer(serverIdx)
                            bought += 1
                            task.wait(0.5)
                        end
                    end
                end
                if bought > 0 then
                    setAutoStatus("guildherb","Bought "..bought.." ✓",C.green)
                    pushLog("[GuildShop] Bought "..bought.." Herb(s)")
                else
                    setAutoStatus("guildherb","No Herbs available",C.sub)
                end
            end)
        end
    end
end)


-- ── Event / Online rewards loop ────────────────────────────────
-- First rename the gift items to "在线奖励01" etc
local eventNamesReady=false
local function initEventNames()
    if eventNamesReady then return end
    pcall(function()
        for i=1,6 do
            local gift=eventGiftList:FindFirstChild("在线奖励0"..i)
            if gift then gift.Name=string.format("在线奖励%02d",i) end
        end
    end)
    eventNamesReady=true
end

task.spawn(function()
    while true do
        task.wait(3)
        if autoClaimState.event then
            setAutoStatus("event","Checking..."); pcall(function()
                initEventNames()
                local claimed=0
                local nextSecs=math.huge
                for i=1,6 do
                    local folder=eventGiftList:FindFirstChild(string.format("在线奖励%02d",i))
                    if folder then
                        local btn=folder:FindFirstChild("按钮")
                        local cd=btn and btn:FindFirstChild("倒计时")
                        if cd then
                            local txt=cd.Text
                            if txt=="DONE" then
                                remoteEventClaim:FireServer(i); task.wait(0.3)
                                claimed+=1
                            elseif txt~="CLAIMED!" then
                                local m,s=txt:match("(%d+):(%d+)")
                                if m and s then
                                    local secs=tonumber(m)*60+tonumber(s)
                                    if secs<nextSecs then nextSecs=secs end
                                end
                            end
                        end
                    end
                end
                if claimed>0 then
                    local msg="[Event] Claimed "..claimed.." gift(s)"
                    setAutoStatus("event","Claimed "..claimed,C.green); pushLog(msg)
                elseif nextSecs<math.huge then
                    local m=math.floor(nextSecs/60); local s=nextSecs%60
                    setAutoStatus("event",string.format("Next in %dm %ds",m,s),C.sub)
                else
                    setAutoStatus("event","All claimed ✓",C.green)
                end
            end)
        end
    end
end)

-- ── Daily task loop ────────────────────────────────────────────
task.spawn(function()
    while true do
        task.wait(3)
        if autoClaimState.daily then
            setAutoStatus("daily","Checking..."); pcall(function()
                -- main quest
                local mainVisible=mainMissionBtn:FindFirstChild("提示") and mainMissionBtn:FindFirstChild("提示").Visible
                if mainVisible then remoteMainClaim:FireServer(); task.wait(0.3) end
                -- daily tasks
                local claimed=0
                for _,child in ipairs(dailyMissionList:GetChildren()) do
                    if child:IsA("Frame") and child.Visible then
                        local idx=tonumber(child.Name)
                        local nl=child:FindFirstChild("名称")
                        if idx and nl then
                            local a,b=nl.Text:match("%((%d+)/(%d+)%)")
                            if a and b and tonumber(a)/tonumber(b)>=1 then
                                remoteDailyClaim:FireServer(idx); task.wait(0.3)
                                claimed+=1
                            end
                        end
                    end
                end
                if claimed>0 or mainVisible then
                    local msg="[Daily] Claimed "..claimed.."+ task(s)"
                    setAutoStatus("daily","Claimed "..claimed,C.green); pushLog(msg)
                else
                    setAutoStatus("daily","Watching...",C.sub)
                end
            end)
        end
    end
end)

-- ── Investment loop (every 10 min) ─────────────────────────────
-- ── Investment loop (tracks real countdowns via 有效期 label) ───
local slotReadyAt = {0, 0, 0}
local SLOT_DURATION = {20*3600, 40*3600, 60*3600}

local function getInvSlot(i)
    return player.PlayerGui
        :WaitForChild("GUI")
        :WaitForChild("二级界面")
        :WaitForChild("商店")
        :WaitForChild("背景")
        :WaitForChild("右侧界面")
        :WaitForChild("银行")
        :WaitForChild("理财"..i)
end

local function readSlotCountdown(i)
    -- reads 有效期 label, format "Countdown: HH:MM:SS"
    -- returns seconds remaining, or 0 if ready/not found
    local ok, secs = pcall(function()
        local label = getInvSlot(i):FindFirstChild("有效期")
        if not label then return 0 end
        local h, m, s = label.Text:match("(%d+):(%d+):(%d+)")
        if h then
            return tonumber(h)*3600 + tonumber(m)*60 + tonumber(s)
        end
        return 0
    end)
    return (ok and secs) or 0
end

local function syncSlotTimers()
    -- call once on enable to read real countdowns from UI
    for i = 1, 3 do
        local secs = readSlotCountdown(i)
        if secs > 0 then
            slotReadyAt[i] = os.time() + secs
        else
            slotReadyAt[i] = 0
        end
    end
end

local invSynced = false
task.spawn(function()
    while true do
        task.wait(3)
        if autoClaimState.investment then
            -- sync timers on first enable
            if not invSynced then
                setAutoStatus("investment", "Syncing timers...", C.yellow)
                syncSlotTimers()
                invSynced = true
            end

            local now = os.time()
            local readySlots = {}
            local minRem = math.huge
            local minSlot = 1

            for i = 1, 3 do
                if slotReadyAt[i] == 0 or now >= slotReadyAt[i] then
                    table.insert(readySlots, i)
                else
                    local rem = slotReadyAt[i] - now
                    if rem < minRem then minRem = rem; minSlot = i end
                end
            end

            if #readySlots > 0 then
                setAutoStatus("investment", "Collecting "..#readySlots.." slot(s)...", C.yellow)
                pcall(function()
                    for _, i in ipairs(readySlots) do
                        remoteInvCollect:FireServer(i); task.wait(0.5)
                    end
                    task.wait(1)
                    for _, i in ipairs(readySlots) do
                        remoteInvBuy:FireServer(i)
                        slotReadyAt[i] = os.time() + SLOT_DURATION[i]
                        task.wait(0.5)
                    end
                    local msg = "[Invest] Slot(s) "..table.concat(readySlots,",").." collected & re-bought"
                    pushLog(msg)
                    -- re-sync after buying to get accurate server time
                    task.wait(2)
                    syncSlotTimers()
                    setAutoStatus("investment", "Done ✓", C.green)
                end)
            else
                -- show nearest slot countdown
                if minRem < math.huge then
                    local h = math.floor(minRem/3600)
                    local m = math.floor((minRem%3600)/60)
                    setAutoStatus("investment",
                        string.format("Slot %d ready in %dh %dm", minSlot, h, m), C.sub)
                end
            end
        else
            invSynced = false  -- reset so it re-syncs next time toggled on
        end
    end
end)
-- ── Guild Auto-Contribute loop (every 5 min) ──────────────────
local lastGuildContrib = 0
local function getNext12AM()
    -- returns the next 12:00 AM (midnight) UTC as os.time()
    local now = os.time()
    local t = os.date("!*t", now)
    -- build today's midnight UTC
    local midnight = os.time({
        year=t.year, month=t.month, day=t.day,
        hour=0, min=0, sec=0
    })
    -- if we're already past today's midnight, add 1 day
    if midnight <= now then midnight = midnight + 86400 end
    return midnight
end
local nextGuildReset = getNext12AM()

task.spawn(function()
    while true do
        task.wait(3)
        if autoClaimState.guild then
            local now = os.time()
            -- check if we've crossed midnight reset
            if now >= nextGuildReset then
                nextGuildReset = getNext12AM()
                lastGuildContrib = 0  -- reset so it fires immediately
            end
            if lastGuildContrib == 0 then
                setAutoStatus("guild","Contributing...",C.yellow)
                pcall(function()
                    for i = 1, 5 do
                        remoteGuildContribute:FireServer()
                        task.wait(0.4)
                    end
                    lastGuildContrib = now
                    local msg = "[Guild] Contributed x5 to guild"
                    setAutoStatus("guild","Done ✓  (resets at midnight)",C.green)
                    pushLog(msg)
                end)
            else
                local rem = nextGuildReset - now
                local h = math.floor(rem/3600)
                local m = math.floor((rem%3600)/60)
                setAutoStatus("guild",string.format("Next at 12am (%dh %dm)",h,m),C.sub)
            end
        end
    end
end)

-- ══════════════════════════════════════════════════════════════
-- ║  GRIND LOGIC (unchanged from original)
-- ══════════════════════════════════════════════════════════════

local function openUIPanels()
    furnaceUI.Position=OFFSCREEN; furnaceUI.Visible=true
    levelSelectUI.Position=OFFSCREEN; levelSelectUI.Visible=true
end
local function closeUIPanels()
    farmlandUI.Position=farmlandOrigPos; farmlandUI.Visible=farmlandOrigVis
    furnaceUI.Position=furnaceOrigPos; furnaceUI.Visible=furnaceOrigVis
    levelSelectUI.Position=levelSelectOrigPos; levelSelectUI.Visible=levelSelectOrigVis
end
local function getWorldNumber() return (DIFF_OFFSET[selectedDifficulty] or 0)+selectedStage end
local function getTargetWorld() if dungeonOverride then return data.highestWorld end; return getWorldNumber() end

local updateGUI

enterNowBtn.MouseButton1Click:Connect(function()
    local wn=getWorldNumber()
    data.status=string.format("🗺 Re-entering [%s] World %d (arg:%d)",selectedDifficulty,selectedStage,wn)
    updateGUI(); remoteWorld:FireServer(wn)
end)

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
    if not data.running then nextFarmLbl.Text="🚶 Farm walk: idle"; nextFarmLbl.TextColor3=C.sub; return end
    if nextFarmWalkAt==-1 then nextFarmLbl.Text="🚶 Farm walk: starting soon..."; nextFarmLbl.TextColor3=C.sub; return end
    if nextFarmWalkAt==0 then nextFarmLbl.Text="🚶 Farm walk: pending..."; nextFarmLbl.TextColor3=C.yellow; return end
    local remaining=nextFarmWalkAt-os.time()
    if remaining<=0 then nextFarmLbl.Text="🚶 Farm walk: NOW"; nextFarmLbl.TextColor3=C.green
    else nextFarmLbl.Text="🚶 Next farm walk: "..fmtCountdown(remaining); nextFarmLbl.TextColor3=remaining<30 and C.orange or C.yellow end
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
            tl.TextColor3=suppressFarmLevelUpdate and C.sub or ((f and (f.capacityCur or 0)>=(f.capacityMax or 1)*0.5) and C.yellow or C.sub)
        end
    end
    local furnLvl=tonumber(data.furnace.level) or 0; local furnP=math.min(furnLvl/GOAL_FURNACE,1)
    local furnDone=furnLvl>=GOAL_FURNACE; local fv2=furnaceRow:FindFirstChild("Val",true)
    if fv2 then fv2.Text="Lv."..(data.furnace.level or "0")..(furnDone and " ✓" or ""); fv2.TextColor3=furnDone and C.green or C.text end
    setBar(furnaceRow,furnP,furnDone and C.barGreen or C.barBlue)
    local fp2=furnaceRow:FindFirstChild("Pct",true); if fp2 then fp2.Text=math.floor(furnP*100).."%" end
    if data.running then toggleBtn.Text="■  STOP"; toggleBtn.BackgroundColor3=Color3.fromRGB(175,40,40); dot.BackgroundColor3=C.green
    else toggleBtn.Text="▶  START"; toggleBtn.BackgroundColor3=C.accentDim; dot.BackgroundColor3=C.red end
    updateFarmWalkLabel()
end

local function parseNum(text)
    if not text then return 0 end
    local t=tostring(text):gsub(",",""); local n=tonumber(t); if n then return n end
    local num,suf=t:match("^([%d%.]+)([KMBkmb]?)$")
    if num then num=tonumber(num) or 0; suf=suf:upper()
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
    local a,b=text:match("^(%d+)/(%d+)$"); return tonumber(a) or 0,tonumber(b) or 0
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
    return math.floor(math.min((f.capacityCur or 0)+(f.ratePerSec or 0)*el,f.capacityMax or 0)),(f.capacityMax or 0)
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
    for i=1,5 do if not data.farms[i] or (tonumber(data.farms[i].level) or 0)<GOAL_FARM then return false end end; return true
end
local function shouldWalkFarms()
    for i=1,5 do if not data.farms[i] or (tonumber(data.farms[i].level) or 0)<GOAL_FARM then return true end end; return false
end
local function furnaceDone() return (tonumber(data.furnace.level) or 0)>=GOAL_FURNACE end
local function hasFarmData()
    for i=1,5 do if not data.farms[i] or not data.farms[i].level then return false end end; return true
end

-- ── Anti-AFK ──────────────────────────────────────────────────
task.spawn(function()
    local vt,jt,mt=0,60,0
    while true do
        task.wait(1); vt+=1; jt+=1; mt+=1
        if vt>=50 then vt=0; pcall(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new()) end) end
        if jt>=110 then jt=0; pcall(function()
            local ch=player.Character; if ch then local hm=ch:FindFirstChildOfClass("Humanoid")
            if hm and hm.Health>0 then hm:ChangeState(Enum.HumanoidStateType.Jumping) end end end) end
        if mt>=20 then mt=0; pcall(function()
            local ch=player.Character; if ch then
                local rt=ch:FindFirstChild("HumanoidRootPart"); local hm=ch:FindFirstChildOfClass("Humanoid")
                if rt and hm and hm.Health>0 then hm:MoveTo(rt.Position+rt.CFrame.LookVector*0.5); task.wait(0.5); hm:MoveTo(rt.Position) end
            end end) end
    end
end)

-- ── Farm walk ─────────────────────────────────────────────────
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
    if farmWalkLock then return end
    if not shouldWalkFarms() then return end
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
    nextFarmWalkAt=allWalkDataOk and (os.time()+FARM_WALK_INTERVAL) or -1
    suppressFarmLevelUpdate=false; data.status="✓ Farm data refreshed"; updateGUI()
    if data.running and not stopFlag then
        local wn=getTargetWorld()
        if wn>0 then
            data.status=not dungeonOverride and string.format("🔄 Returning to [%s] W%d after walk...",selectedDifficulty,selectedStage) or "🔄 Returning to World "..wn.." after walk..."
            updateGUI()
            local waited=0; local confirmed=false
            repeat pcall(function() remoteWorld:FireServer(wn) end); task.wait(3); waited+=3
                local ln=tonumber(stageLabel.Text:match("World (%d+)"))
                if ln==wn then confirmed=true; break end
            until waited>=20 or not data.running or stopFlag
            if confirmed then
                pcall(function() if AFK_ARG and AFK_ARG~="" then remoteAFK:FireServer(AFK_ARG) end end)
                data.status=not dungeonOverride and string.format("✅ [%s] W%d — back, AFK on",selectedDifficulty,selectedStage) or "✅ World "..wn.." — back, AFK on"
            else data.status="⚠ Failed to re-enter — main loop will retry" end
            updateGUI()
        end
    end
    farmWalkLock=false
end

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

-- background tasks
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
                if not hasFarmData() then nextFarmWalkAt=-1; data.status="⚠ Some farms missing — retrying walk soon..."; updateGUI() end
            end
        end
    end
end)

-- stats calc loop
local function calcStat(s)
    local now=tick(); local cur=s.getValue(); local dt=now-s.prevTime
    if dt<0.01 then dt=0.01 end
    local raw=(cur-s.prev)/dt
    if raw<0 or raw>1e12 then raw=0 end
    s.prev=cur; s.prevTime=now; s.current=raw
    table.insert(s.history,raw)
    if #s.history>60 then table.remove(s.history,1) end
    local sum=0; for _,v in ipairs(s.history) do sum=sum+v end; s.avg=sum/#s.history
end
local function updateStatsDisplay()
    for _,key in ipairs(STAT_ORDER) do
        local s=stats_data[key]; local ref=statRowRefs[key]; if not ref then continue end
        local mult=STAT_MULTIPLIER[s.unitIdx]
        local val=s.unitIdx==1 and (s.current*mult) or (s.avg*mult)
        ref.valLbl.Text=fmtStat(val,val>=100 and 0 or 1)
    end
end
task.spawn(function()
    while true do
        for _,key in ipairs(STAT_ORDER) do pcall(calcStat,stats_data[key]) end
        updateStatsDisplay(); task.wait(1)
    end
end)

-- refresh loop
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

-- ── Grind loop ────────────────────────────────────────────────
local grindThread=nil
local function getLowestFarm()
    local li,ll=nil,math.huge
    for i=1,5 do if data.farms[i] then local lv=tonumber(data.farms[i].level) or 0; if lv<GOAL_FARM and lv<ll then ll=lv; li=i end end end
    return li,ll
end
local function waitForWorld(wn,timeout)
    local waited=0
    repeat task.wait(1); waited+=1
        local txt=stageLabel.Text or ""
        local ln=tonumber(txt:match("World (%d+)%-")) or tonumber(txt:match("World (%d+)"))
        if ln==wn then return true end
    until waited>=(timeout or 15) or stopFlag
    return false
end
local function enterDungeon(wn)
    local label=not dungeonOverride and string.format("🗺 Entering [%s] W%d...",selectedDifficulty,selectedStage) or "🌍 Entering World "..wn.."..."
    data.status=label; updateGUI(); remoteWorld:FireServer(wn)
    local confirmed=waitForWorld(wn,15)
    if not hasEnteredDungeonOnce and not stopFlag then
        hasEnteredDungeonOnce=true
        pcall(function() if AFK_ARG and AFK_ARG~="" then remoteAFK:FireServer(AFK_ARG) end end)
        data.status=not dungeonOverride and string.format("✅ [%s] W%d — AFK on",selectedDifficulty,selectedStage) or "✅ World "..wn.." — AFK on"
        updateGUI()
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
        local lastReenter=0
        task.spawn(function()
            while not stopFlag and data.running do
                local ch=player.Character or player.CharacterAdded:Wait()
                local hm=ch:WaitForChild("Humanoid"); hm.Died:Wait()
                local newCh=player.CharacterAdded:Wait(); RunService.Heartbeat:Wait()
                root=newCh:WaitForChild("HumanoidRootPart"); humanoid=newCh:WaitForChild("Humanoid")
                if not stopFlag and data.running and not farmWalkLock then
                    local w=getTargetWorld()
                    if w>0 then
                        lastReenter=os.time()
                        data.status=not dungeonOverride and string.format("💀 Re-entering [%s] W%d",selectedDifficulty,selectedStage) or "💀 Re-entering World "..w
                        updateGUI()
                        local waited=0; local confirmed=false
                        repeat pcall(function() remoteWorld:FireServer(w) end); task.wait(0.5); waited+=0.5
                            local ln=tonumber(stageLabel.Text:match("World (%d+)"))
                            if ln==w then confirmed=true end
                        until confirmed or waited>=30 or stopFlag or not data.running
                        if confirmed then data.status=not dungeonOverride and string.format("✅ [%s] W%d — back",selectedDifficulty,selectedStage) or "✅ World "..w.." — back"; updateGUI() end
                    end
                end
            end
        end)
        task.spawn(function()
            while not stopFlag and data.running do
                task.wait(0.1)
                pcall(function()
                    local w=getTargetWorld(); if w==0 then return end
                    local now=os.time(); local inScene=false
                    for _,sc in ipairs(workspace:GetChildren()) do
                        if sc.Name:find("世界") then
                            for _,v in ipairs(sc:GetDescendants()) do
                                local bp=v:IsA("BasePart") and v or nil
                                if bp and (bp.Position-root.Position).Magnitude<200 then inScene=true; break end
                            end
                        end
                        if inScene then break end
                    end
                    if not inScene and not farmWalkLock and (now-lastReenter)>=2 then
                        lastReenter=now
                        data.status=not dungeonOverride and string.format("💀 Died — re-entering [%s] W%d",selectedDifficulty,selectedStage) or "💀 Died — re-entering World "..w
                        updateGUI(); remoteWorld:FireServer(w)
                        local waited=0; local ln=nil
                        repeat task.wait(1); waited+=1; ln=tonumber(stageLabel.Text:match("World (%d+)"))
                        until ln==w or waited>=10 or stopFlag
                        if ln==w then data.status=not dungeonOverride and string.format("✅ [%s] W%d — back",selectedDifficulty,selectedStage) or "✅ World "..w.." — back"; updateGUI() end
                    end
                end)
            end
        end)
        if not allFarmsDone() and not stopFlag then
            data.status="[P1] Farm upgrades..."; updateGUI(); suppressFarmLevelUpdate=true
            task.spawn(function()
                while not stopFlag and not allFarmsDone() do
                    local ci,cl=getLowestFarm(); if not ci then break end
                    remoteFarmUp:FireServer(ci)
                    if data.farms[ci] then data.farms[ci].level=tostring((tonumber(data.farms[ci].level) or 0)+1) end
                    task.wait(0.05)
                end
            end)
            while not stopFlag and not allFarmsDone() do collectFarmsIfNeeded(); task.wait(5) end
            suppressFarmLevelUpdate=false
            if not stopFlag then collectFarmsIfNeeded(); data.status="[P1] ✓ All farms Lv.80!"; updateGUI(); task.wait(1) end
        end
        if not furnaceDone() and not stopFlag then
            furnaceUI.Position=OFFSCREEN; furnaceUI.Visible=true; task.wait(0.5)
            local fresh=readFurnaceFromUI(); if fresh then data.furnace=fresh end; updateGUI()
            task.spawn(function() while not stopFlag and not furnaceDone() do remoteFurnaceUp:FireServer(); task.wait(0.05) end end)
            while not stopFlag and not furnaceDone() do collectFarmsIfNeeded(); task.wait(2) end
            if not stopFlag then data.status="[P2] ✓ Furnace Lv.80!"; updateGUI(); task.wait(1) end
        end
        if not stopFlag then
            data.status="[P3] Gold grind → 246M"; updateGUI()
            while not stopFlag and data.goldNum<GOAL_GOLD do collectFarmsIfNeeded(); task.wait(5); updateGUI() end
        end
        suppressFarmLevelUpdate=false; data.running=false
        data.status=goalsReached() and "🎉 ALL GOALS REACHED!" or "Paused — press START to resume."
        nextFarmWalkAt=-1; updateGUI(); grindThread=nil
    end)
end

local function stopGrind()
    stopFlag=true; data.running=false
    suppressFarmLevelUpdate=false; nextFarmWalkAt=-1; hasEnteredDungeonOnce=false
    data.status="Paused — press START to resume."
    closeUIPanels(); updateGUI()
    task.delay(0.5,function() grindThread=nil end)
end

toggleBtn.MouseButton1Click:Connect(function()
    if data.running then stopGrind() else startGrind() end
end)

-- ── Init ──────────────────────────────────────────────────────
activateTab(1)
updateGUI()
print("✅ AutoGrind v3 — Ready")
