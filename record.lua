return function(WindUI, RecordingTab)
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local HttpService = game:GetService("HttpService")
    local UserInputService = game:GetService("UserInputService")
    local CoreGui = game:GetService("CoreGui")
    local lp = Players.LocalPlayer

    -- ==========================================
    -- VARIABEL SISTEM & STATE
    -- ==========================================
    local isUnlocked = (lp.Name == "myzzkey") 
    local RecordsDB = {}
    local currentRecordingFrames = {}
    
    local isRecording = false
    local isPlaying = false
    local isPaused = false
    local isAutoWalkingToStart = false
    
    local recConn = nil
    local playConn = nil
    local selectedRecord = "Kosong"
    local playbackIndex = 1

    local folderName = "Recording"
    if isfolder and not isfolder(folderName) then makefolder(folderName) end

    -- ==========================================
    -- FUNGSI INTERNAL DATA
    -- ==========================================
    local function SerializeData(framesArray)
        local serialized = {}
        for i, frame in ipairs(framesArray) do
            serialized[i] = {
                cframe = {frame.cframe:GetComponents()},
                vel = {frame.vel.X, frame.vel.Y, frame.vel.Z},
                state = frame.state.Name 
            }
        end
        return serialized
    end

    local function DeserializeData(jsonFrames)
        local deserialized = {}
        for i, frame in ipairs(jsonFrames) do
            deserialized[i] = {
                cframe = CFrame.new(unpack(frame.cframe)),
                vel = Vector3.new(unpack(frame.vel)),
                state = Enum.HumanoidStateType[frame.state]
            }
        end
        return deserialized
    end

    local function SaveRecordFile(recordName, framesData)
        if writefile then
            local fileName = folderName .. "/" .. recordName .. ".json"
            pcall(function() writefile(fileName, HttpService:JSONEncode(SerializeData(framesData))) end)
        end
    end

    local function DeleteRecordFile(recordName)
        if delfile then
            local fileName = folderName .. "/" .. recordName .. ".json"
            if isfile(fileName) then pcall(function() delfile(fileName) end) end
        end
    end

    local function LoadAllRecords()
        RecordsDB = {}
        if listfiles and isfolder(folderName) then
            for _, filePath in ipairs(listfiles(folderName)) do
                if filePath:match("%.json$") then
                    local recordName = filePath:match("([^/\\]+)$"):gsub("%.json$", "")
                    local s, res = pcall(function() return DeserializeData(HttpService:JSONDecode(readfile(filePath))) end)
                    if s and res then RecordsDB[recordName] = res end
                end
            end
        end
    end

    local function GetNextRecordID()
        local id = 1
        while true do
            local name = string.format("Record_%02d", id)
            if not RecordsDB[name] then return name end
            id = id + 1
        end
    end

    local function FindNearestFrameIndex(data, currentPos)
        local nearestIdx = 1
        local minDis = math.huge
        for i, frame in ipairs(data) do
            local dis = (frame.cframe.Position - currentPos).Magnitude
            if dis < minDis then
                minDis = dis
                nearestIdx = i
            end
        end
        return nearestIdx
    end

    -- ==========================================
    -- CUSTOM FLOATING UI (WIDGET & PANEL)
    -- ==========================================
    local FloatingUI = Instance.new("ScreenGui")
    FloatingUI.Name = "SYNC_RecordPanel"
    FloatingUI.ResetOnSpawn = false
    FloatingUI.Enabled = false
    
    local uiParent = (gethui and gethui()) or (pcall(function() return CoreGui.Name end) and CoreGui) or lp.PlayerGui
    FloatingUI.Parent = uiParent

    -- 1. Widget Button (Lingkaran)
    local WidgetBtn = Instance.new("TextButton")
    WidgetBtn.Size = UDim2.new(0, 50, 0, 50)
    WidgetBtn.Position = UDim2.new(0.5, -25, 0.1, 0)
    WidgetBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    WidgetBtn.Text = "🎬"
    WidgetBtn.TextSize = 24
    WidgetBtn.Parent = FloatingUI
    
    local WidgetCorner = Instance.new("UICorner")
    WidgetCorner.CornerRadius = UDim.new(1, 0)
    WidgetCorner.Parent = WidgetBtn
    
    local WidgetStroke = Instance.new("UIStroke")
    WidgetStroke.Color = Color3.fromRGB(41, 248, 155)
    WidgetStroke.Thickness = 2
    WidgetStroke.Parent = WidgetBtn

    -- 2. Main Panel
    local MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, 250, 0, 340)
    MainFrame.Position = UDim2.new(0.5, -125, 0.5, -170)
    MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
    MainFrame.BorderSizePixel = 0
    MainFrame.Visible = false -- Default tersembunyi, dibuka via widget
    MainFrame.Parent = FloatingUI

    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 12)
    UICorner.Parent = MainFrame

    local UIStroke = Instance.new("UIStroke")
    UIStroke.Color = Color3.fromRGB(41, 248, 155)
    UIStroke.Thickness = 1.5
    UIStroke.Parent = MainFrame

    -- Header Panel
    local HeaderFrame = Instance.new("Frame")
    HeaderFrame.Size = UDim2.new(1, 0, 0, 40)
    HeaderFrame.BackgroundTransparency = 1
    HeaderFrame.Parent = MainFrame

    local TitleLbl = Instance.new("TextLabel")
    TitleLbl.Size = UDim2.new(1, -40, 1, 0)
    TitleLbl.Position = UDim2.new(0, 15, 0, 0)
    TitleLbl.BackgroundTransparency = 1
    TitleLbl.Text = "Studio Recording"
    TitleLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    TitleLbl.Font = Enum.Font.GothamBold
    TitleLbl.TextSize = 16
    TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
    TitleLbl.Parent = HeaderFrame

    local CloseBtnUI = Instance.new("TextButton")
    CloseBtnUI.Size = UDim2.new(0, 40, 0, 40)
    CloseBtnUI.Position = UDim2.new(1, -40, 0, 0)
    CloseBtnUI.BackgroundTransparency = 1
    CloseBtnUI.Text = "✖"
    CloseBtnUI.TextColor3 = Color3.fromRGB(255, 80, 80)
    CloseBtnUI.Font = Enum.Font.GothamBold
    CloseBtnUI.TextSize = 16
    CloseBtnUI.Parent = HeaderFrame

    local Divider = Instance.new("Frame")
    Divider.Size = UDim2.new(1, 0, 0, 1)
    Divider.Position = UDim2.new(0, 0, 1, 0)
    Divider.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    Divider.BorderSizePixel = 0
    Divider.Parent = HeaderFrame

    -- Drag Logic untuk Widget (dengan deteksi Klik vs Drag)
    local dragStart, startPos
    local draggingWidget = false
    local isMoved = false

    WidgetBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingWidget = true
            isMoved = false
            dragStart = input.Position
            startPos = WidgetBtn.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    draggingWidget = false
                    -- Jika pergerakan mouse < 5 pixel, hitung sebagai Klik (Toggle Panel)
                    if not isMoved then
                        MainFrame.Visible = not MainFrame.Visible
                    end
                end
            end)
        end
    end)

    -- Drag Logic untuk Main Frame (di Header)
    local draggingFrame = false
    local frameStartPos, frameDragStart
    HeaderFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingFrame = true
            frameDragStart = input.Position
            frameStartPos = MainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then draggingFrame = false end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            if draggingWidget then
                local delta = input.Position - dragStart
                if delta.Magnitude > 5 then isMoved = true end
                if isMoved then
                    WidgetBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
                end
            elseif draggingFrame then
                local delta = input.Position - frameDragStart
                MainFrame.Position = UDim2.new(frameStartPos.X.Scale, frameStartPos.X.Offset + delta.X, frameStartPos.Y.Scale, frameStartPos.Y.Offset + delta.Y)
            end
        end
    end)

    CloseBtnUI.MouseButton1Click:Connect(function()
        MainFrame.Visible = false
    end)

    -- Content Area (Layouting)
    local ContentFrame = Instance.new("Frame")
    ContentFrame.Size = UDim2.new(1, -20, 1, -55)
    ContentFrame.Position = UDim2.new(0, 10, 0, 50)
    ContentFrame.BackgroundTransparency = 1
    ContentFrame.Parent = MainFrame

    local UIListLayout = Instance.new("UIListLayout")
    UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    UIListLayout.Padding = UDim.new(0, 8)
    UIListLayout.Parent = ContentFrame

    local StatusLbl = Instance.new("TextLabel")
    StatusLbl.Size = UDim2.new(1, 0, 0, 35)
    StatusLbl.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
    StatusLbl.Text = "Status: Menunggu file..."
    StatusLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
    StatusLbl.Font = Enum.Font.Gotham
    StatusLbl.TextSize = 12
    StatusLbl.TextWrapped = true
    StatusLbl.LayoutOrder = 1
    StatusLbl.Parent = ContentFrame
    Instance.new("UICorner", StatusLbl).CornerRadius = UDim.new(0, 6)

    -- Helper untuk membuat tombol custom
    local function CreateButton(text, color, order)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 38)
        btn.BackgroundColor3 = color
        btn.Text = text
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 14
        btn.LayoutOrder = order
        btn.Parent = ContentFrame
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
        return btn
    end

    local RecBtn = CreateButton("🔴 Mulai Record", Color3.fromRGB(220, 50, 50), 2)
    local PlayPanelBtn = CreateButton("▶️ Play Selected File", Color3.fromRGB(40, 130, 230), 3)
    local PausePanelBtn = CreateButton("⏸️ Pause", Color3.fromRGB(220, 160, 40), 4)
    local StopPanelBtn = CreateButton("⏹️ Stop Playback", Color3.fromRGB(180, 60, 60), 5)
    
    -- ADVANCED SLIDER UI (Hanya muncul saat Pause)
    local SliderContainer = Instance.new("Frame")
    SliderContainer.Size = UDim2.new(1, 0, 0, 55)
    SliderContainer.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
    SliderContainer.LayoutOrder = 6
    SliderContainer.Visible = false
    SliderContainer.Parent = ContentFrame
    Instance.new("UICorner", SliderContainer).CornerRadius = UDim.new(0, 8)

    local SliderTitle = Instance.new("TextLabel")
    SliderTitle.Size = UDim2.new(1, -10, 0, 20)
    SliderTitle.Position = UDim2.new(0, 5, 0, 5)
    SliderTitle.BackgroundTransparency = 1
    SliderTitle.Text = "Timeline (0%)"
    SliderTitle.TextColor3 = Color3.fromRGB(180, 180, 180)
    SliderTitle.Font = Enum.Font.Gotham
    SliderTitle.TextSize = 11
    SliderTitle.TextXAlignment = Enum.TextXAlignment.Left
    SliderTitle.Parent = SliderContainer

    local SliderTrack = Instance.new("Frame")
    SliderTrack.Size = UDim2.new(1, -20, 0, 6)
    SliderTrack.Position = UDim2.new(0, 10, 0, 35)
    SliderTrack.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    SliderTrack.Parent = SliderContainer
    Instance.new("UICorner", SliderTrack).CornerRadius = UDim.new(1, 0)

    local SliderFill = Instance.new("Frame")
    SliderFill.Size = UDim2.new(0, 0, 1, 0)
    SliderFill.BackgroundColor3 = Color3.fromRGB(41, 248, 155)
    SliderFill.Parent = SliderTrack
    Instance.new("UICorner", SliderFill).CornerRadius = UDim.new(1, 0)

    local SliderKnob = Instance.new("Frame")
    SliderKnob.Size = UDim2.new(0, 14, 0, 14)
    SliderKnob.Position = UDim2.new(1, -7, 0.5, -7) -- Anchor di ujung fill
    SliderKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    SliderKnob.Parent = SliderFill
    Instance.new("UICorner", SliderKnob).CornerRadius = UDim.new(1, 0)

    local SliderBtn = Instance.new("TextButton")
    SliderBtn.Size = UDim2.new(1, 0, 1, 20)
    SliderBtn.Position = UDim2.new(0, 0, 0, -10)
    SliderBtn.BackgroundTransparency = 1
    SliderBtn.Text = ""
    SliderBtn.Parent = SliderTrack

    local CutBtn = CreateButton("✂️ Cut & Lanjut Rekam", Color3.fromRGB(60, 180, 100), 7)
    CutBtn.Visible = false

    -- Update Visibility UI Panel Logic
    local function UpdatePanelUI()
        if isRecording then
            RecBtn.Text = "⏹️ Stop Record"
            RecBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
            RecBtn.Visible = true
            PlayPanelBtn.Visible = false
            PausePanelBtn.Visible = false
            StopPanelBtn.Visible = false
            SliderContainer.Visible = false
            CutBtn.Visible = false
        elseif isPlaying then
            RecBtn.Visible = false
            PlayPanelBtn.Visible = false
            PausePanelBtn.Visible = true
            StopPanelBtn.Visible = true
            if isPaused then
                PausePanelBtn.Text = "▶️ Resume"
                SliderContainer.Visible = true
                CutBtn.Visible = true
            else
                PausePanelBtn.Text = "⏸️ Pause"
                SliderContainer.Visible = false
                CutBtn.Visible = false
            end
        else
            RecBtn.Text = "🔴 Mulai Record"
            RecBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
            RecBtn.Visible = true
            PlayPanelBtn.Visible = true
            PausePanelBtn.Visible = false
            StopPanelBtn.Visible = false
            SliderContainer.Visible = false
            CutBtn.Visible = false
        end
    end

    UpdatePanelUI() -- Init

    -- ==========================================
    -- LOGIKA TOMBOL FLOATING PANEL
    -- ==========================================
    RecBtn.MouseButton1Click:Connect(function()
        if not isRecording then
            isRecording = true
            currentRecordingFrames = {}
            StatusLbl.Text = "Status: 🔴 Merekam..."
            UpdatePanelUI()

            recConn = RunService.Heartbeat:Connect(function()
                local char = lp.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hrp and hum then
                    table.insert(currentRecordingFrames, {
                        cframe = hrp.CFrame,
                        vel = hrp.AssemblyLinearVelocity,
                        state = hum:GetState() 
                    })
                    StatusLbl.Text = "Status: 🔴 Merekam (" .. #currentRecordingFrames .. " frames)"
                end
            end)
        else
            isRecording = false
            if recConn then recConn:Disconnect() end
            UpdatePanelUI()

            if #currentRecordingFrames > 0 then
                local recName = GetNextRecordID() 
                RecordsDB[recName] = currentRecordingFrames
                SaveRecordFile(recName, currentRecordingFrames) 
                
                local list = {}
                for name, _ in pairs(RecordsDB) do table.insert(list, name) end
                if _G.RecordDropdownMenu then _G.RecordDropdownMenu:Refresh(list) end

                StatusLbl.Text = "Tersimpan: " .. recName .. ".json"
            else
                StatusLbl.Text = "Gagal: Frame kosong!"
            end
        end
    end)

    local function StartPlaybackLoop(data)
        if playConn then playConn:Disconnect() end
        playConn = RunService.Heartbeat:Connect(function()
            local char = lp.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid") 
            
            if not hrp or not hum then return end

            if isAutoWalkingToStart then
                local targetPos = data[playbackIndex].cframe.Position
                local dist = (hrp.Position - targetPos).Magnitude
                
                if dist > 3 then
                    hum:MoveTo(targetPos)
                    StatusLbl.Text = string.format("🚶 Auto-Walk: %d Studs", math.floor(dist))
                else
                    isAutoWalkingToStart = false 
                    StatusLbl.Text = "▶️ Memutar rekaman..."
                end
            else
                if data[playbackIndex] then
                    local currentData = data[playbackIndex]
                    local nextData = data[playbackIndex + 1]
                    
                    hrp.CFrame = currentData.cframe
                    hrp.AssemblyLinearVelocity = currentData.vel
                    if hum:GetState() ~= currentData.state then hum:ChangeState(currentData.state) end
                    
                    if nextData then
                        local moveDir = (nextData.cframe.Position - currentData.cframe.Position)
                        local flatMoveDir = Vector3.new(moveDir.X, 0, moveDir.Z) 
                        if flatMoveDir.Magnitude > 0.02 then
                            hum:Move(flatMoveDir.Unit, false) 
                        else
                            hum:Move(Vector3.zero, false)
                        end
                    else
                        hum:Move(Vector3.zero, false)
                    end

                    local percent = math.floor((playbackIndex / #data) * 100)
                    StatusLbl.Text = string.format("▶️ Frame: %d / %d", playbackIndex, #data)
                    SliderFill.Size = UDim2.new(playbackIndex / #data, 0, 1, 0)
                    SliderTitle.Text = string.format("Timeline (%d%%)", percent)
                    playbackIndex = playbackIndex + 1
                else
                    if playConn then playConn:Disconnect() end
                    hum:Move(Vector3.zero, false) 
                    hum:ChangeState(Enum.HumanoidStateType.Running)
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    
                    isPlaying = false
                    isPaused = false
                    StatusLbl.Text = "✅ Selesai memutar!"
                    UpdatePanelUI()
                end
            end
        end)
    end

    PlayPanelBtn.MouseButton1Click:Connect(function()
        if selectedRecord == "Kosong" or not RecordsDB[selectedRecord] then 
            StatusLbl.Text = "Pilih file di menu WindUI dulu!" 
            return 
        end
        local data = RecordsDB[selectedRecord]
        
        isPlaying = true
        isPaused = false
        UpdatePanelUI()
        
        local char = lp.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        playbackIndex = hrp and FindNearestFrameIndex(data, hrp.Position) or 1
        isAutoWalkingToStart = true 
        
        StartPlaybackLoop(data)
    end)

    PausePanelBtn.MouseButton1Click:Connect(function()
        local data = RecordsDB[selectedRecord]
        if not data then return end

        if not isPaused then
            isPaused = true
            if playConn then playConn:Disconnect() end
            local char = lp.Character
            if char and char:FindFirstChildOfClass("Humanoid") then
                char:FindFirstChildOfClass("Humanoid"):Move(Vector3.zero, false)
            end
            
            StatusLbl.Text = "⏸️ Paused (Geser slider untuk edit)"
            UpdatePanelUI()
        else
            isPaused = false
            StatusLbl.Text = "▶️ Resumed"
            UpdatePanelUI()
            StartPlaybackLoop(data)
        end
    end)

    StopPanelBtn.MouseButton1Click:Connect(function()
        if playConn then playConn:Disconnect() end
        local char = lp.Character
        if char and char:FindFirstChildOfClass("Humanoid") then char:FindFirstChildOfClass("Humanoid"):Move(Vector3.zero, false) end
        
        isPlaying = false
        isPaused = false
        StatusLbl.Text = "⏹️ Dihentikan."
        UpdatePanelUI()
    end)

    -- Custom Slider Logic
    local sliderDragging = false
    SliderBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliderDragging = true
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliderDragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if sliderDragging and isPaused and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local mouseX = input.Position.X
            local sliderX = SliderTrack.AbsolutePosition.X
            local sliderSize = SliderTrack.AbsoluteSize.X
            
            local percent = math.clamp((mouseX - sliderX) / sliderSize, 0, 1)
            SliderFill.Size = UDim2.new(percent, 0, 1, 0)
            SliderTitle.Text = string.format("Timeline (%d%%)", math.floor(percent * 100))
            
            local data = RecordsDB[selectedRecord]
            if data then
                playbackIndex = math.max(1, math.floor(percent * #data))
                StatusLbl.Text = string.format("⏸️ Preview Frame: %d / %d", playbackIndex, #data)
                
                local char = lp.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp and data[playbackIndex] then
                    hrp.CFrame = data[playbackIndex].cframe
                end
            end
        end
    end)

    CutBtn.MouseButton1Click:Connect(function()
        if not isPaused then return end
        local data = RecordsDB[selectedRecord]
        if not data then return end

        local newData = {}
        for i = 1, playbackIndex do
            table.insert(newData, data[i])
        end
        currentRecordingFrames = newData
        
        isPaused = false
        isPlaying = false
        isAutoWalkingToStart = false
        isRecording = true 
        UpdatePanelUI()
        
        StatusLbl.Text = "🔴 Merekam Sambungan..."
        recConn = RunService.Heartbeat:Connect(function()
            local char = lp.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hrp and hum then
                table.insert(currentRecordingFrames, {
                    cframe = hrp.CFrame,
                    vel = hrp.AssemblyLinearVelocity,
                    state = hum:GetState() 
                })
                StatusLbl.Text = "🔴 Merekam Sambungan (" .. #currentRecordingFrames .. " frames)"
            end
        end)
    end)

    -- ==========================================
    -- WIND UI (MAIN MENU - FILE MANAGER)
    -- ==========================================
    RecordingTab:Paragraph({
        Title = "File Manager",
        Desc = "Manajemen file record JSON. Pilih file di sini, lalu buka Panel UI untuk kontrol Play/Record.",
        Color = Color3.fromHex("#0F7BFF")
    })

    _G.RecordDropdownMenu = RecordingTab:Dropdown({
        Title = "Pilih File Record",
        Values = {"Kosong"},
        Value = "Kosong",
        SearchBarEnabled = true,
        Callback = function(opt)
            selectedRecord = type(opt) == "table" and opt.Title or opt
            if selectedRecord ~= "Kosong" then
                StatusLbl.Text = "File Terpilih: " .. selectedRecord
            end
        end
    })

    RecordingTab:Button({
        Title = "🗑️ Hapus File Terpilih",
        Callback = function()
            if not isUnlocked then return WindUI:Notify({Title="Akses Ditolak", Content="Hanya myzzkey yang dapat menghapus!", Duration=2}) end
            if selectedRecord == "Kosong" or isPlaying or isRecording then return WindUI:Notify({Title="Gagal", Content="Pilih list valid / hentikan rekaman", Duration=2}) end 

            if RecordsDB[selectedRecord] then
                RecordsDB[selectedRecord] = nil
                DeleteRecordFile(selectedRecord) 
                
                local list = {}
                for name, _ in pairs(RecordsDB) do table.insert(list, name) end
                if #list == 0 then table.insert(list, "Kosong") end
                if _G.RecordDropdownMenu then _G.RecordDropdownMenu:Refresh(list) end

                WindUI:Notify({Title="Dihapus", Content=selectedRecord .. ".json dihapus", Duration=1.5})
                selectedRecord = "Kosong"
                StatusLbl.Text = "Status: Idle"
            end
        end
    })

    RecordingTab:Space()
    RecordingTab:Divider()
    RecordingTab:Space()

    RecordingTab:Button({
        Title = "🎛️ Buka / Tutup Panel Widget",
        Icon = "monitor",
        Callback = function()
            if not isUnlocked then return WindUI:Notify({Title="Akses Ditolak", Content="Hanya untuk myzzkey!", Duration=2}) end
            FloatingUI.Enabled = not FloatingUI.Enabled
            if FloatingUI.Enabled then
                WindUI:Notify({Title="Widget Aktif", Content="Widget (🎬) muncul di layar. Klik untuk membuka panel.", Duration=2})
            end
        end
    })

    -- Init
    LoadAllRecords()
    local initList = {}
    for name, _ in pairs(RecordsDB) do table.insert(initList, name) end
    if #initList == 0 then table.insert(initList, "Kosong") end
    if _G.RecordDropdownMenu then _G.RecordDropdownMenu:Refresh(initList) end
end
