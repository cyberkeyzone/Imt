local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "KS Exploit VIP",
    Icon = "door-open",
    Author = "by myzzkey",
})

WindUI:Notify({
    Title = "KS Exploit - Startup",
    Content = "Loading interface...",
    Duration = 3,
    Icon = "bird",
})

wait(3)

Window:ToggleTransparency(true)

Window:Tag({
    Title = "v1.0.0",
    Color = Color3.fromHex("#30ff6a"),
    Radius = 8,
})

Window:EditOpenButton({
    Title = "Open KS VIP",
    Icon = "monitor",
    CornerRadius = UDim.new(0,16),
    StrokeThickness = 2,
    Color = ColorSequence.new(
        Color3.fromHex("FF0F7B"), 
        Color3.fromHex("F89B29")
    ),
    OnlyMobile = false,
    Enabled = true,
    Draggable = true,
})

-- SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

local player = Players.LocalPlayer
local character
local humanoid
local rootPart
local currentConnection
local isReplaying = false
local currentAnimationTrack = nil
local currentPlaybackSpeed = 1.0

-- NEW VARIABLES FOR FEATURES
local isLoopEnabled = false
local isAutoRejoinEnabled = false
local controlsDisabled = false
local LoopToggle
local RejoinToggle
local savedSettings = {
    gunung = "Gn Atin",
    speed = 1.0,
    animation = "Default",
    loop = false,
    autoRejoin = false
}

-- UPDATE CHARACTER REFERENCES
local function updateCharacterReferences()
    character = player.Character or player.CharacterAdded:Wait()
    humanoid = character:WaitForChild("Humanoid")
    rootPart = character:WaitForChild("HumanoidRootPart")
end

updateCharacterReferences()

-- DISABLE PLAYER CONTROLS
local function DisableControls()
    if controlsDisabled then return end
    controlsDisabled = true
    
    pcall(function()
        humanoid.JumpPower = 0
        humanoid.Jump = false
        
        -- Disable all control modules
        local Controls = require(player.PlayerScripts:WaitForChild("PlayerModule")):GetControls()
        if Controls then
            Controls:Disable()
        end
    end)
end

-- ENABLE PLAYER CONTROLS
local function EnableControls()
    if not controlsDisabled then return end
    controlsDisabled = false
    
    pcall(function()
        humanoid.JumpPower = 50
        
        -- Enable all control modules
        local Controls = require(player.PlayerScripts:WaitForChild("PlayerModule")):GetControls()
        if Controls then
            Controls:Enable()
        end
    end)
end

-- SAVE SETTINGS
local function SaveSettings()
    savedSettings.gunung = selectedGunung
    savedSettings.speed = selectedSpeed
    savedSettings.animation = selectedAnimation
    savedSettings.loop = isLoopEnabled
    savedSettings.autoRejoin = isAutoRejoinEnabled
    
    -- Save to global for persistence
    _G.KS_SAVED_SETTINGS = savedSettings
end

-- AUTO REJOIN FUNCTION
local function AutoRejoin()
    local placeId = game.PlaceId
    
    WindUI:Notify({
        Title = "🔄 Auto Rejoin",
        Content = "Rejoining in 3 seconds...",
        Duration = 3,
        Icon = "refresh-cw"
    })
    
    -- Save settings for auto-execute
    SaveSettings()
    
    wait(3)
    
    -- Set global flag for auto-execution detection
    _G.KS_AUTO_EXECUTE = true
    
    -- Teleport
    pcall(function()
        TeleportService:Teleport(placeId, player)
    end)
end

-- DATABASE LIST BANTAI
local ListBantai = {
    ["Gn Atin"] = {
        url = "https://raw.githubusercontent.com/cyberkeyzone/Imt/main/ATIN.json",
        data = nil,
        loaded = false
    },
    ["Gn Imut"] = {
        url = "https://raw.githubusercontent.com/cyberkeyzone/Imt/main/Imut%202.json",
        data = nil,
        loaded = false
    },
    ["Gn Besar"] = {
        url = "https://pastefy.app/YOUR_PASTE_ID_3/raw",
        data = nil,
        loaded = false
    },
    ["Gn Tinggi"] = {
        url = "https://pastefy.app/YOUR_PASTE_ID_4/raw",
        data = nil,
        loaded = false
    },
}

-- DATABASE ANIMASI WALKING
local AnimasiList = {
    ["Default"] = {
        id = nil,
        name = "Default Roblox"
    },
    ["Animasi 1"] = {
        id = "rbxassetid://YOUR_ANIMATION_ID_1",
        name = "Zombie Walk"
    },
    ["Animasi 2"] = {
        id = "rbxassetid://YOUR_ANIMATION_ID_2",
        name = "Stylish Walk"
    },
    ["Animasi 3"] = {
        id = "rbxassetid://YOUR_ANIMATION_ID_3",
        name = "Robot Walk"
    },
    ["Animasi 4"] = {
        id = "rbxassetid://YOUR_ANIMATION_ID_4",
        name = "Ninja Walk"
    },
    ["Animasi 5"] = {
        id = "rbxassetid://YOUR_ANIMATION_ID_5",
        name = "Pirate Walk"
    },
}

-- SPEED OPTIONS
local speedOptions = {
    "0.5x", "0.75x", "1.0x", "1.25x", "1.5x", 
    "1.75x", "2.0x", "2.5x", "3.0x", "4.0x",
    "5.0x", "7.5x", "10.0x", "15.0x", "20.0x"
}

-- ANIMASI OPTIONS
local animasiOptions = {}
for name, _ in pairs(AnimasiList) do
    table.insert(animasiOptions, name)
end
table.sort(animasiOptions)

-- APPLY ANIMATION
local function ApplyAnimation(animName)
    if not character or not humanoid then
        updateCharacterReferences()
    end
    
    local animData = AnimasiList[animName]
    if not animData then return false end
    
    -- Stop current animation
    if currentAnimationTrack then
        currentAnimationTrack:Stop()
        currentAnimationTrack = nil
    end
    
    -- Reset to default
    if animData.id == nil then
        for _, track in pairs(humanoid:GetPlayingAnimationTracks()) do
            if track.Animation and track.Animation.AnimationId:find("rbxassetid://") then
                track:Stop()
            end
        end
        
        WindUI:Notify({
            Title = "Animation Reset",
            Content = "Kembali ke animasi default",
            Duration = 2,
            Icon = "rotate-ccw"
        })
        return true
    end
    
    -- Apply custom animation
    pcall(function()
        local anim = Instance.new("Animation")
        anim.AnimationId = animData.id
        
        currentAnimationTrack = humanoid:LoadAnimation(anim)
        currentAnimationTrack.Looped = true
        currentAnimationTrack.Priority = Enum.AnimationPriority.Movement
        currentAnimationTrack:Play()
        
        WindUI:Notify({
            Title = "Animation Applied",
            Content = animData.name,
            Duration = 2,
            Icon = "activity"
        })
    end)
    
    return true
end

-- LOAD DATA FROM PASTEFY
local function LoadData(namaGunung)
    local data = ListBantai[namaGunung]
    if not data then 
        WindUI:Notify({
            Title = "Error",
            Content = "Gunung tidak ditemukan",
            Duration = 3,
            Icon = "x-circle"
        })
        return false 
    end
    
    if data.loaded and data.data then return true end
    
    WindUI:Notify({
        Title = "Loading",
        Content = "Memuat " .. namaGunung,
        Duration = 2,
        Icon = "loader"
    })
    
    local success, result = pcall(function()
        local rawData = game:HttpGet(data.url)
        return HttpService:JSONDecode(rawData)
    end)
    
    if success and result then
        data.data = result
        data.loaded = true
        WindUI:Notify({
            Title = "Loaded",
            Content = namaGunung .. " (" .. #result .. " frames)",
            Duration = 2,
            Icon = "check-circle"
        })
        return true
    else
        WindUI:Notify({
            Title = "Error",
            Content = "Gagal load " .. namaGunung,
            Duration = 3,
            Icon = "x-circle"
        })
        return false
    end
end

-- FIND NEAREST FRAME INDEX
local function FindNearestFrameIndex(recordData)
    if not rootPart or not recordData or #recordData == 0 then
        return 1, 0
    end
    
    local currentPos = rootPart.Position
    local nearestIndex = 1
    local nearestDistance = math.huge
    
    -- Check if data structure is correct
    if not recordData[1] or not recordData[1].position then
        warn("Invalid record data structure")
        return 1, 0
    end
    
    -- Phase 1: Quick scan with larger steps for performance
    local stepSize = math.max(1, math.floor(#recordData / 100))
    
    for i = 1, #recordData, stepSize do
        local data = recordData[i]
        if data and data.position then
            local recordPos = Vector3.new(data.position.X, data.position.Y, data.position.Z)
            local distance = (currentPos - recordPos).Magnitude
            
            if distance < nearestDistance then
                nearestDistance = distance
                nearestIndex = i
            end
        end
    end
    
    -- Phase 2: Fine-tune search around nearest found index
    local searchRange = stepSize * 2
    local searchStart = math.max(1, nearestIndex - searchRange)
    local searchEnd = math.min(#recordData, nearestIndex + searchRange)
    
    for i = searchStart, searchEnd do
        local data = recordData[i]
        if data and data.position then
            local recordPos = Vector3.new(data.position.X, data.position.Y, data.position.Z)
            local distance = (currentPos - recordPos).Magnitude
            
            if distance < nearestDistance then
                nearestDistance = distance
                nearestIndex = i
            end
        end
    end
    
    return nearestIndex, math.floor(nearestDistance)
end

-- STOP PLAYBACK
local function StopPlayback()
    if currentConnection then
        currentConnection:Disconnect()
        currentConnection = nil
    end
    isReplaying = false
    
    -- Re-enable controls
    EnableControls()
    
    WindUI:Notify({
        Title = "Stopped",
        Content = "Replay dihentikan",
        Duration = 2,
        Icon = "stop-circle"
    })
end

-- PLAY RECORDING
local function PlayRecording(namaGunung, speed, fromLoop)
    if isReplaying and not fromLoop then
        StopPlayback()
        wait(0.5)
    end
    
    if not LoadData(namaGunung) then return end
    
    local recordData = ListBantai[namaGunung]
    if not recordData.data or #recordData.data == 0 then 
        WindUI:Notify({
            Title = "Error",
            Content = "Data kosong",
            Duration = 3,
            Icon = "x-circle"
        })
        return 
    end
    
    updateCharacterReferences()
    
    -- Disable player controls during playback
    DisableControls()
    
    -- Set current playback speed
    currentPlaybackSpeed = speed
    
    -- For loop mode, always start from beginning (index 1)
    -- For normal mode, find nearest position
    local startIndex, distance
    
    if fromLoop then
        -- Loop mode: always start from frame 1
        startIndex = 1
        distance = 0
        
        WindUI:Notify({
            Title = "🔁 Loop Restart",
            Content = "Starting from beginning...",
            Duration = 2,
            Icon = "repeat"
        })
    else
        -- Normal mode: find nearest position
        WindUI:Notify({
            Title = "🔍 Scanning",
            Content = "Mencari posisi terdekat...",
            Duration = 1,
            Icon = "search"
        })
        wait(0.1)
        
        startIndex, distance = FindNearestFrameIndex(recordData.data)
    end
    
    local totalFrames = #recordData.data
    local percentage = math.floor((startIndex / totalFrames) * 100)
    
    local statusMsg = string.format(
        "%s | %dx | Start: %d/%d (%d%%)",
        namaGunung,
        speed,
        startIndex,
        totalFrames,
        percentage
    )
    
    WindUI:Notify({
        Title = "▶️ Playing",
        Content = statusMsg,
        Duration = 3,
        Icon = "play-circle"
    })
    
    -- Show distance warning only for normal mode
    if not fromLoop then
        if distance > 100 then
            WindUI:Notify({
                Title = "⚠️ Far From Track",
                Content = "Distance: " .. distance .. " studs",
                Duration = 3,
                Icon = "alert-triangle"
            })
        elseif distance > 50 then
            WindUI:Notify({
                Title = "✓ Found Track",
                Content = "Distance: " .. distance .. " studs",
                Duration = 2,
                Icon = "check"
            })
        else
            WindUI:Notify({
                Title = "✓ On Track",
                Content = "Distance: " .. distance .. " studs",
                Duration = 2,
                Icon = "check-circle"
            })
        end
    end
    
    isReplaying = true
    local currentIndex = startIndex
    
    currentConnection = RunService.Heartbeat:Connect(function(deltaTime)
        if not isReplaying then
            currentConnection:Disconnect()
            EnableControls()
            return
        end
        
        if not character or not character.Parent then
            pcall(updateCharacterReferences)
            return
        end
        
        -- Use current playback speed (can be changed while playing)
        local speed = currentPlaybackSpeed
        
        -- Calculate frames to skip based on speed multiplier
        local framesToProcess = math.floor(speed)
        local fractionalPart = speed % 1
        
        -- Add fractional accumulation for smooth speed control
        if math.random() < fractionalPart then
            framesToProcess = framesToProcess + 1
        end
        
        -- Process multiple frames per tick for higher speeds
        for i = 1, math.max(1, framesToProcess) do
            if currentIndex <= #recordData.data and isReplaying then
                local data = recordData.data[currentIndex]
                
                pcall(function()
                    rootPart.CFrame = CFrame.new(
                        data.position.X,
                        data.position.Y,
                        data.position.Z
                    ) * CFrame.lookAt(
                        Vector3.new(0, 0, 0),
                        Vector3.new(
                            data.cframe.LookVector.X,
                            data.cframe.LookVector.Y,
                            data.cframe.LookVector.Z
                        )
                    )
                    
                    rootPart.Velocity = Vector3.new(
                        data.velocity.X,
                        data.velocity.Y,
                        data.velocity.Z
                    ) * speed
                    
                    humanoid.WalkSpeed = data.walkSpeed * math.min(speed, 2)
                    humanoid.Jump = false  -- Force disable jump
                end)
                
                currentIndex = currentIndex + 1
            else
                if currentIndex > #recordData.data then
                    -- Playback finished
                    isReplaying = false
                    EnableControls()
                    
                    WindUI:Notify({
                        Title = "✓ Complete",
                        Content = namaGunung .. " finished!",
                        Duration = 2,
                        Icon = "check-circle"
                    })
                    
                    -- Handle loop or auto rejoin
                    if isLoopEnabled then
                        wait(0.5)
                        
                        WindUI:Notify({
                            Title = "🔁 Loop Active",
                            Content = "Respawning in 2 seconds...",
                            Duration = 2,
                            Icon = "refresh-cw"
                        })
                        
                        wait(2)
                        
                        -- Keep isReplaying = true to prevent CharacterAdded from stopping
                        local wasReplaying = isReplaying
                        
                        -- Respawn character
                        pcall(function()
                            character:BreakJoints()
                        end)
                        
                        -- Restore replay state
                        isReplaying = wasReplaying
                        
                        -- Wait for respawn
                        wait(1)
                        character = player.Character or player.CharacterAdded:Wait()
                        updateCharacterReferences()
                        wait(1)
                        
                        -- Restart from beginning
                        PlayRecording(namaGunung, currentPlaybackSpeed, true)
                    elseif isAutoRejoinEnabled then
                        SaveSettings()
                        AutoRejoin()
                    end
                end
                break
            end
        end
    end)
end

-- CREATE TAB
local BantaiTab = Window:Tab({
    Title = "BANTAI GUNUNG",
    Icon = "mountain",
    Locked = false,
})

-- VARIABLES
local selectedGunung = "Gn Atin"
local selectedSpeed = 1.0
local selectedAnimation = "Default"

-- SECTION 1: LIST BANTAI
local ListSection = BantaiTab:Section({
    Title = "List Bantai"
})

local GunungDropdown = ListSection:Dropdown({
    Title = "Pilih Gunung",
    Desc = "Pilih gunung yang ingin dibantai",
    Values = { "Gn Atin", "Gn Imut", "Gn Besar", "Gn Tinggi" },
    Value = "Gn Atin",
    Multi = false,
    Callback = function(option) 
        selectedGunung = option
        SaveSettings()
        
        WindUI:Notify({
            Title = "Selected",
            Content = selectedGunung,
            Duration = 1.5,
            Icon = "target"
        })
    end
})

-- SECTION 2: PILIHAN ANIMASI
local AnimasiSection = BantaiTab:Section({
    Title = "Pilihan Animasi"
})

local AnimasiDropdown = AnimasiSection:Dropdown({
    Title = "Walking Animation",
    Desc = "Pilih animasi berjalan",
    Values = animasiOptions,
    Value = "Default",
    Multi = false,
    Callback = function(option)
        selectedAnimation = option
        SaveSettings()
        ApplyAnimation(selectedAnimation)
    end
})

-- SECTION 3: PLAYBACK SPEED
local SpeedSection = BantaiTab:Section({
    Title = "Playback Speed"
})

local SpeedDropdown = SpeedSection:Dropdown({
    Title = "Kecepatan Replay",
    Desc = "Atur kecepatan replay (real-time)",
    Values = speedOptions,
    Value = "1.0x",
    Multi = false,
    Callback = function(option)
        selectedSpeed = tonumber(option:match("([%d%.]+)"))
        SaveSettings()
        
        -- Update speed in real-time if playing
        if isReplaying then
            currentPlaybackSpeed = selectedSpeed
            WindUI:Notify({
                Title = "⚡ Speed Updated",
                Content = option .. " (Real-time)",
                Duration = 2,
                Icon = "zap"
            })
        else
            WindUI:Notify({
                Title = "Speed Set",
                Content = option,
                Duration = 1.5,
                Icon = "zap"
            })
        end
    end
})

-- SECTION 4: CONTROLS
local ControlSection = BantaiTab:Section({
    Title = "Controls"
})

LoopToggle = ControlSection:Toggle({
    Title = "🔁 Loop Mode",
    Desc = "Ulangi replay terus menerus",
    Value = false,
    Callback = function(value)
        -- Auto disable Auto Rejoin when Loop is enabled
        if value and isAutoRejoinEnabled then
            isAutoRejoinEnabled = false
            SaveSettings()
            
            task.spawn(function()
                wait(0.05)
                if RejoinToggle then
                    RejoinToggle:SetValue(false)
                end
            end)
            
            WindUI:Notify({
                Title = "🔁 Loop Enabled",
                Content = "Auto Rejoin disabled",
                Duration = 2,
                Icon = "repeat"
            })
        end
        
        isLoopEnabled = value
        SaveSettings()
        
        if not (value and isAutoRejoinEnabled) then
            local status = value and "Enabled" or "Disabled"
            WindUI:Notify({
                Title = "Loop Mode",
                Content = status,
                Duration = 2,
                Icon = value and "repeat" or "x"
            })
        end
    end
})

RejoinToggle = ControlSection:Toggle({
    Title = "🔄 Auto Rejoin",
    Desc = "Rejoin otomatis setelah selesai",
    Value = false,
    Callback = function(value)
        -- Auto disable Loop when Auto Rejoin is enabled
        if value and isLoopEnabled then
            isLoopEnabled = false
            SaveSettings()
            
            task.spawn(function()
                wait(0.05)
                if LoopToggle then
                    LoopToggle:SetValue(false)
                end
            end)
            
            WindUI:Notify({
                Title = "🔄 Auto Rejoin Enabled",
                Content = "Loop Mode disabled",
                Duration = 2,
                Icon = "refresh-cw"
            })
        end
        
        isAutoRejoinEnabled = value
        SaveSettings()
        
        if not (value and isLoopEnabled) then
            if value then
                WindUI:Notify({
                    Title = "Auto Rejoin",
                    Content = "Enabled\n📁 Save this script to autoexec folder!",
                    Duration = 4,
                    Icon = "refresh-cw"
                })
            else
                WindUI:Notify({
                    Title = "Auto Rejoin",
                    Content = "Disabled",
                    Duration = 2,
                    Icon = "x"
                })
            end
        end
    end
})

ControlSection:Button({
    Title = "▶️ Play",
    Desc = "Mulai bantai gunung",
    Locked = false,
    Callback = function()
        PlayRecording(selectedGunung, selectedSpeed, false)
    end
})

ControlSection:Button({
    Title = "⏹️ Stop",
    Desc = "Hentikan replay",
    Locked = false,
    Callback = function()
        StopPlayback()
    end
})

-- SECTION 5: INFO
local InfoSection = BantaiTab:Section({
    Title = "Info"
})

InfoSection:Button({
    Title = "ℹ️ Current Selection",
    Desc = "Lihat pilihan saat ini",
    Callback = function()
        local loopStatus = isLoopEnabled and "ON" or "OFF"
        local rejoinStatus = isAutoRejoinEnabled and "ON" or "OFF"
        local controlStatus = controlsDisabled and "LOCKED" or "FREE"
        
        local msg = string.format(
            "%s | %sx | %s\nLoop: %s | Rejoin: %s\nControls: %s",
            selectedGunung,
            selectedSpeed,
            selectedAnimation,
            loopStatus,
            rejoinStatus,
            controlStatus
        )
        
        WindUI:Notify({
            Title = "Current Settings",
            Content = msg,
            Duration = 5,
            Icon = "info"
        })
    end
})

InfoSection:Button({
    Title = "🔄 Reset Animation",
    Desc = "Reset ke animasi default",
    Callback = function()
        selectedAnimation = "Default"
        ApplyAnimation("Default")
    end
})

-- HANDLE RESPAWN
player.CharacterAdded:Connect(function()
    -- DON'T stop playback if loop mode is active
    if isReplaying and not isLoopEnabled then 
        StopPlayback() 
    end
    
    wait(1)
    updateCharacterReferences()
    
    -- Don't re-enable controls if loop is active
    if not isLoopEnabled then
        EnableControls()
    end
    
    if selectedAnimation ~= "Default" then
        wait(0.5)
        ApplyAnimation(selectedAnimation)
    end
end)

-- CHECK FOR AUTO-EXECUTION AFTER REJOIN
if _G.KS_AUTO_EXECUTE and _G.KS_SAVED_SETTINGS then
    task.spawn(function()
        wait(1)
        
        WindUI:Notify({
            Title = "🔄 Auto-Execute Detected",
            Content = "Restoring previous session...",
            Duration = 3,
            Icon = "refresh-cw"
        })
        
        wait(1)
        
        -- Restore settings
        local restored = _G.KS_SAVED_SETTINGS
        
        selectedGunung = restored.gunung or "Gn Atin"
        selectedSpeed = restored.speed or 1.0
        selectedAnimation = restored.animation or "Default"
        isLoopEnabled = restored.loop or false
        isAutoRejoinEnabled = restored.autoRejoin or false
        
        -- Update UI toggles
        task.wait(0.5)
        if LoopToggle and isLoopEnabled then
            LoopToggle:SetValue(true)
        end
        if RejoinToggle and isAutoRejoinEnabled then
            RejoinToggle:SetValue(true)
        end
        
        -- Apply animation
        if restored.animation and restored.animation ~= "Default" then
            wait(0.5)
            ApplyAnimation(restored.animation)
        end
        
        -- Auto start play
        wait(1.5)
        WindUI:Notify({
            Title = "▶️ Auto Starting",
            Content = string.format("%s | %sx | %s", 
                restored.gunung or "Gn Atin", 
                restored.speed or 1.0, 
                restored.animation or "Default"
            ),
            Duration = 3,
            Icon = "play-circle"
        })
        
        wait(1)
        PlayRecording(selectedGunung, selectedSpeed, false)
        
        -- Keep flag active for continuous rejoin cycles
    end)
end

-- SELECT TAB
BantaiTab:Select()

-- OPEN WINDOW
Window:Toggle()

print("✅ BANTAI GUNUNG Loaded!")
print("📋 Gunung: 4 locations | Speed: 15 options | Animasi: 6 options")
print("🔒 Controls Lock | 🔁 Loop Mode FIXED | 🔄 Auto Rejoin")