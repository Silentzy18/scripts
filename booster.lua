
local function loadLibrary()
    local name = "Scoot UI Library.txt"
    local githubUrl = "https://raw.githubusercontent.com/dadada-rgb/Vhuy.Ghoul/refs/heads/main/scootuilib"

    local function patch(content)
        -- 1. Truncate the demo/documentation section
        -- The library documentation starts after a clear marker
        local markers = {"%-%-example", "local Window = Library:Window", "Library:Watermark"}
        local bestStart = nil
        for _, marker in ipairs(markers) do
            local found = content:find(marker)
            if found and (not bestStart or found < bestStart) then
                bestStart = found
            end
        end
        
        if bestStart then
            content = content:sub(1, bestStart - 1)
        end

        -- 2. Targeted patch for NewButton:SetVisibility to add SetText
        -- We look for the exact NewButton:SetVisibility definition
        local targetFunc = "function NewButton:SetVisibility(Bool)"
        local foundFunc = content:find(targetFunc, 1, true)
        if foundFunc then
            local endPos = content:find("end", foundFunc + #targetFunc, true)
            if endPos then
                local firstPart = content:sub(1, endPos + 2)
                local lastPart = content:sub(endPos + 3)
                content = firstPart .. "\n                function NewButton:SetText(Text) SubItems[\"Text\"].Instance.Text = Text end" .. lastPart
            end
        end

        -- 3. Increase Button TextSize specifically
        -- In Scoot UI, buttons use a TextSize of 9 in their constructor
        -- We search for the TextLabel creation specifically inside the button area
        content = content:gsub('TextSize%s*=%s*9', 'TextSize = 12')

        -- 4. Clean up any existing global assignments and force a clean return
        -- This avoids conflicts if the library was already partially loaded
        content = content .. "\n\nif getgenv().Library then pcall(function() getgenv().Library:Unload() end) end\ngetgenv().Library = Library\nreturn Library"
        
        return content
    end

    local function secureLoad(str)
        local func, err = loadstring(patch(str))
        if not func then
            error("Scoot UI Library Patch Error: " .. tostring(err))
        end
        return func()
    end

    -- Try loading from GitHub first
    local success, content = pcall(game.HttpGet, game, githubUrl)
    if success and content and #content > 0 then
        return secureLoad(content)
    end

    -- Try reading from the root of the workspace second
    success, content = pcall(readfile, name)
    if success and content and #content > 0 then
        return secureLoad(content)
    end
    
    -- Fallback to the subfolder
    success, content = pcall(readfile, "Discord Bots/TryAngle/" .. name)
    if success and content and #content > 0 then
        return secureLoad(content)
    end

    error("Scoot UI Library not found! Please ensure you have an internet connection or '" .. name .. "' is in your executor's workspace folder.")
end

getgenv().Library = nil
local Library = loadLibrary()

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser       = game:GetService("VirtualUser")

local localPlayer = Players.LocalPlayer

-- ── Remotes ──────────────────────────────────────────────────────────
local RS = ReplicatedStorage
    :WaitForChild("\228\186\139\228\187\182")
    :WaitForChild("\229\133\172\231\148\168")
local remoteSupportMode = RS
    :WaitForChild("\230\136\152\230\150\151")
    :WaitForChild("\230\155\180\230\150\176\229\141\143\229\138\169\231\155\174\230\160\135")
local remoteJoinWorld = RS
    :WaitForChild("\229\133\179\229\141\161")
    :WaitForChild("\232\191\155\229\133\165\229\188\128\229\144\175\228\184\173\229\133\179\229\141\161")

-- ── State ─────────────────────────────────────────────────────────────
local isOn           = false
local selectedPlayer = nil
local supportThread  = nil
local antiAfkThread  = nil

-- ── UI Initialization ─────────────────────────────────────────────────
local Window = Library:Window({
    Name = "AURORA HUB",
    Logo = "77218680285262",
    FadeTime = 0.3,
})

local MainPage = Window:Page({Name = "Main", Columns = 1})
local Section = MainPage:Section({Name = "Support Configuration", Side = 1})

local StatusLabel = Section:Label("Status: Idle")

local AntiAfkToggle = Section:Toggle({
    Name = "Anti-AFK",
    Flag = "AntiAfk",
    Default = false,
    Callback = function(Value)
        if Value then
            startAntiAfk()
        else
            if antiAfkThread then task.cancel(antiAfkThread); antiAfkThread = nil end
        end
    end
})

local PlayerDropdown = Section:Dropdown({
    Name = "Target Player",
    Items = {},
    Flag = "TargetPlayer",
    Callback = function(Value)
        selectedPlayer = Players:FindFirstChild(Value)
        if selectedPlayer then
            Library:Notification("Target Selected", "Now targeting: " .. selectedPlayer.Name, 3)
        end
    end
})

local ActionButton = Section:Button()
local InitBtn = ActionButton:Add("Start Support", function()
    toggleSupport()
end)

-- ── Logic ─────────────────────────────────────────────────────────────

function toggleSupport()
    if not selectedPlayer and not isOn then
        Library:Notification("Error", "Please select a player first!", 3)
        return
    end

    isOn = not isOn
    
    if isOn then
        InitBtn:SetText("Stop Support")
        Library:Notification("Support Mode", "Starting session for " .. selectedPlayer.Name, 3)
        StatusLabel:SetText("Status: Initializing...")
        
        -- Fire support mode ON once when activated
        pcall(function() remoteSupportMode:FireServer() end)

        supportThread = task.spawn(function()
            local target = selectedPlayer
            local attempts = 0
            
            -- Phase 1: Join / Teleport Loop
            while isOn do
                if not target or not target.Parent then
                    isOn = false
                    StatusLabel:SetText("Status: Player Left")
                    InitBtn:SetText("Start Support")
                    return
                end

                attempts = attempts + 1
                pcall(function() remoteJoinWorld:FireServer(target) end)
                StatusLabel:SetText("Status: Joining " .. target.Name .. " (" .. attempts .. ")")

                -- Wait 3s between join attempts
                task.wait(3)

                -- Success Check: Are we in the same world/near the target?
                local targetChar = target.Character
                local myChar = localPlayer.Character
                if targetChar and myChar then
                    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
                    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
                    
                    if targetRoot and myRoot then
                        local dist = (targetRoot.Position - myRoot.Position).Magnitude
                        if dist < 500 then
                            -- SUCCESS: We are in the same world now
                            pcall(function() remoteSupportMode:FireServer() end)
                            StatusLabel:SetText("Status: Support Active")
                            break -- Exit Join Phase
                        end
                    end
                end
            end

            -- Phase 2: Active Monitoring Loop
            while isOn do
                if not target or not target.Parent then
                    isOn = false
                    StatusLabel:SetText("Status: Player Left")
                    InitBtn:SetText("Start Support")
                    break
                end
                
                -- We don't fire JoinWorld anymore, just keep the thread alive
                -- and wait for the user to terminate or the player to leave.
                task.wait(3)
            end
        end)
    else
        if supportThread then task.cancel(supportThread); supportThread = nil end
        InitBtn:SetText("Start Support")
        StatusLabel:SetText("Status: Idle")
        Library:Notification("Support Mode", "Session Terminated", 3)
    end
end

function startAntiAfk()
    if antiAfkThread then task.cancel(antiAfkThread) end
    antiAfkThread = task.spawn(function()
        local vuTimer   = 0
        local jumpTimer = 60

        while Library.Flags["AntiAfk"] do
            task.wait(1)
            vuTimer = vuTimer + 1
            jumpTimer = jumpTimer + 1

            if vuTimer >= 50 then
                vuTimer = 0
                pcall(function()
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new())
                end)
            end

            if jumpTimer >= 110 then
                jumpTimer = 0
                pcall(function()
                    local char = localPlayer.Character
                    local hum = char and char:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 then
                        hum:ChangeState(Enum.HumanoidStateType.Jumping)
                    end
                end)
            end
        end
    end)
end

-- ── Player Sync ───────────────────────────────────────────────────────

local function refreshPlayers()
    local names = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= localPlayer then
            table.insert(names, p.Name)
        end
    end
    PlayerDropdown:Refresh(names) -- Library only takes one argument
end

Players.PlayerAdded:Connect(refreshPlayers)
Players.PlayerRemoving:Connect(function(plr)
    if selectedPlayer == plr then
        selectedPlayer = nil
        StatusLabel:SetText("Status: Target Disconnected")
        if isOn then isOn = false end
    end
    refreshPlayers()
end)

refreshPlayers()

-- [[ STANDALONE NOTE ]]
-- To make this a single script, paste the content of "Scoot UI Library.txt" at the VERY TOP of this file.

Library:Notification("Aurora Hub", "Successfully loaded with Scoot UI!", 5)
