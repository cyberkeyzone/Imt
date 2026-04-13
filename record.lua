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
    local availableRecords = {}
    local currentRecordIndex = 1
    
    local currentRecordingFrames = {}
    local isRecording = false
    local isPlaying = false
    local isPaused = false
    local isAutoWalkingToStart = false
    
    local recConn = nil
    local playConn = nil
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

    local function RefreshAvailableRecords()
        availableRecords = {}
        local sortedKeys = {}
        for name, _ in pairs(RecordsDB) do table.insert(sortedKeys, name) end
        table.sort(sortedKeys)
        
        for _, name in ipairs(sortedKeys) do table.insert(availableRecords, name) end
        
        if #availableRecords == 0 then
            currentRecordIndex = 0
        elseif currentRecordIndex > #availableRecords or currentRecordIndex == 0 then
            currentRecordIndex = 1
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
        RefreshAvailableRecords()
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
    -- CUSTOM FLOATING UI (COMPACT HORIZONTAL)
    -- ==========================================
    local FloatingUI = Instance.new("ScreenGui")
    FloatingUI.Name = "SYNC_RecordPanel_Compact"
    FloatingUI.ResetOnSpawn = false
    FloatingUI.Enabled = false
    
    local uiParent = (gethui and gethui()) or (pcall(function() return CoreGui.Name end) and CoreGui) or lp.PlayerGui
    FloatingUI.Parent = uiParent

    -- 1. Widget Button (Lingkaran Diperkecil)
    local WidgetBtn = Instance.new("TextButton")
    WidgetBtn.Size = UDim2.new(0, 38, 0, 38)
    WidgetBtn.Position = UDim2.new(0.5, -19, 0.05, 0)
    WidgetBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    WidgetBtn.Text = "🎬"
    WidgetBtn.TextSize = 18
    WidgetBtn.Parent = FloatingUI
    
    Instance.new("UICorner", WidgetBtn).CornerRadius = UDim.new(1, 0)
    local WidgetStroke = Instance.new("UIStroke")
    WidgetStroke.Color = Color3.fromRGB(41, 248, 155)
    WidgetStroke.Thickness = 2
    WidgetStroke.Parent = WidgetBtn

    -- 2. Main Panel (Lebih Kecil & Ramping)
    local MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, 400, 0, 75)
    MainFrame.Position = UDim2.new(0.5, -200, 0.8, -80)
    MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
    MainFrame.BorderSizePixel = 0
    MainFrame.Visible = false 
    MainFrame.ClipsDescendants = true
    MainFrame.Parent = FloatingUI

    Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)
    local UIStroke = Instance.new("UIStroke")
    UIStroke.Color = Color3.fromRGB(41, 248, 155)
    UIStroke.Thickness = 1.5
    UIStroke.Parent = MainFrame

    -- Header / Drag Area
    local HeaderFrame = Instance.new("Frame")
    HeaderFrame.Size = UDim2.new(1, 0, 0, 30)
    HeaderFrame.BackgroundTransparency = 1
    HeaderFrame.Parent = MainFrame

    local TitleLbl = Instance.new("TextLabel")
    TitleLbl.Size = UDim2.new(0, 110, 1, 0)
    TitleLbl.Position = UDim2.new(0, 12, 0, 0)
    TitleLbl.BackgroundTransparency = 1
    TitleLbl.Text = "SYNC Record"
    TitleLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    TitleLbl.Font = Enum.Font.GothamBold
    TitleLbl.TextSize = 13
    TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
    TitleLbl.Parent = HeaderFrame

    -- File Cycler (Navigasi File Horizontal)
    local FileNavFrame = Instance.new("Frame")
    FileNavFrame.Size = UDim2.new(0, 180, 0, 22)
    FileNavFrame.Position = UDim2.new(1, -215, 0, 4)
    FileNavFrame.BackgroundTransparency = 1
    FileNavFrame.Parent = HeaderFrame

    local UIListLayoutNav = Instance.new("UIListLayout")
    UIListLayoutNav.FillDirection = Enum.FillDirection.Horizontal
    UIListLayoutNav.HorizontalAlignment = Enum.HorizontalAlignment.Right
    UIListLayoutNav.SortOrder = Enum.SortOrder.LayoutOrder
    UIListLayoutNav.Padding = UDim.new(0, 4)
    UIListLayoutNav.Parent = FileNavFrame

    local function CreateNavBtn(text, color, width, order)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, width, 1, 0)
        btn.BackgroundColor3 = color
        btn.Text = text
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 11
        btn.LayoutOrder = order
        btn.Parent = FileNavFrame
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
        return btn
    end

    local PrevFileBtn = CreateNavBtn("<", Color3.fromRGB(40, 40, 50), 22, 1)
    
    local CurrentFileLbl = Instance.new("TextLabel")
    CurrentFileLbl.Size = UDim2.new(0, 90, 1, 0)
    CurrentFileLbl.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
    CurrentFileLbl.Text = "Kosong"
    CurrentFileLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
    CurrentFileLbl.Font = Enum.Font.Gotham
    CurrentFileLbl.TextSize = 11
    CurrentFileLbl.LayoutOrder = 2
    CurrentFileLbl.Parent = FileNavFrame
    Instance.new("UICorner", CurrentFileLbl).CornerRadius = UDim.new(0, 4)

    local NextFileBtn = CreateNavBtn(">", Color3.fromRGB(40, 40, 50), 22, 3)
    local DeleteFileBtn = CreateNavBtn("🗑️", Color3.fromRGB(180, 60, 60), 26, 4)

    -- Status Bawah Header
    local StatusLbl = Instance.new("TextLabel")
    StatusLbl.Size = UDim2.new(1, -24, 0, 12)
    StatusLbl.Position = UDim2.new(0, 12, 0, 28)
    StatusLbl.BackgroundTransparency = 1
    StatusLbl.Text = "Status: Siap merekam/memutar."
    StatusLbl.TextColor3 = Color3.fromRGB(150, 150, 150)
    StatusLbl.Font = Enum.Font.Gotham
    StatusLbl.TextSize = 10
    StatusLbl.TextXAlignment = Enum.TextXAlignment.Left
    StatusLbl.Parent = MainFrame

    -- Logika Input Sempurna untuk Widget (Klik vs Drag)
    local isDraggingWidget = false
    local widgetDragStart, widgetStartPos

    WidgetBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDraggingWidget = true
            widgetDragStart = input.Position
            widgetStartPos = WidgetBtn.Position
        end
    end)

    WidgetBtn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDraggingWidget = false
            local delta = input.Position - widgetDragStart
            if delta.Magnitude < 5 then
                MainFrame.Visible = not MainFrame.Visible
            end
        end
    end)

    -- Logika Input Drag MainFrame
    local isDraggingFrame = false
    local frameDragStart, frameStartPos

    HeaderFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDraggingFrame = true
            frameDragStart = input.Position
            frameStartPos = MainFrame.Position
        end
    end)

    HeaderFrame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDraggingFrame = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            if isDraggingWidget then
                local delta = input.Position - widgetDragStart
                WidgetBtn.Position = UDim2.new(widgetStartPos.X.Scale, widgetStartPos.X.Offset + delta.X, widgetStartPos.Y.Scale, widgetStartPos.Y.Offset + delta.Y)
            elseif isDraggingFrame then
                local delta = input.Position - frameDragStart
                MainFrame.Position = UDim2.new(frameStartPos.X.Scale, frameStartPos.X.Offset + delta.X, frameStartPos.Y.Scale, frameStartPos.Y.Offset + delta.Y)
            end
        end
    end)

    -- Container Tombol Aksi
    local BtnContainer = Instance.new("Frame")
    BtnContainer.Size = UDim2.new(1, -24, 0, 26)
    BtnContainer.Position = UDim2.new(0, 12, 0, 42)
    BtnContainer.BackgroundTransparency = 1
    BtnContainer.Parent = MainFrame

    local UIListLayout = Instance.new("UIListLayout")
    UIListLayout.FillDirection = Enum.FillDirection.Horizontal
    UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    UIListLayout.Padding = UDim.new(0, 8)
    UIListLayout.Parent = BtnContainer

    local function CreateButton(text, color, width, order)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, width, 1, 0)
        btn.BackgroundColor3 = color
        btn.Text = text
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 11
        btn.LayoutOrder = order
        btn.Parent = BtnContainer
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
        return btn
    end

    local RecBtn = CreateButton("🔴 Record", Color3.fromRGB(200, 50, 50), 85, 1)
    local PlayPanelBtn = CreateButton("▶️ Play", Color3.fromRGB(40, 120, 200), 85, 2)
    local PausePanelBtn = CreateButton("⏸️ Pause", Color3.fromRGB(200, 140, 40), 85, 3)
    local StopPanelBtn = CreateButton("⏹️ Stop", Color3.fromRGB(160, 60, 60), 85, 4)
    
    -- EDITOR CONTAINER (Hanya muncul saat Pause)
    local EditContainer = Instance.new("Frame")
    EditContainer.Size = UDim2.new(1, -24, 0, 35)
    EditContainer.Position = UDim2.new(0, 12, 0, 75)
    EditContainer.BackgroundTransparency = 1
    EditContainer.Visible = false
    EditContainer.Parent = MainFrame

    local SliderTrack = Instance.new("Frame")
    SliderTrack.Size = UDim2.new(0, 240, 0, 4)
    SliderTrack.Position = UDim2.new(0, 0, 0.5, -2)
    SliderTrack.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    SliderTrack.Parent = EditContainer
    Instance.new("UICorner", SliderTrack).CornerRadius = UDim.new(1, 0)

    local SliderFill = Instance.new("Frame")
    SliderFill.Size = UDim2.new(0, 0, 1, 0)
    SliderFill.BackgroundColor3 = Color3.fromRGB(41, 248, 155)
    SliderFill.Parent = SliderTrack
    Instance.new("UICorner", SliderFill).CornerRadius = UDim.new(1, 0)

    local SliderKnob = Instance.new("Frame")
    SliderKnob.Size = UDim2.new(0, 12, 0, 12)
    SliderKnob.Position = UDim2.new(1, -6, 0.5, -6) 
    SliderKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    SliderKnob.Parent = SliderFill
    Instance.new("UICorner", SliderKnob).CornerRadius = UDim.new(1, 0)

    local SliderBtn = Instance.new("TextButton")
    SliderBtn.Size = UDim2.new(1, 0, 1, 20)
    SliderBtn.Position = UDim2.new(0, 0, 0, -10)
    SliderBtn.BackgroundTransparency = 1
    SliderBtn.Text = ""
    SliderBtn.Parent = SliderTrack

    local CutBtn = Instance.new("TextButton")
    CutBtn.Size = UDim2.new(0, 120, 0, 24)
    CutBtn.Position = UDim2.new(1, -120, 0.5, -12)
    CutBtn.BackgroundColor3 = Color3.fromRGB(60, 180, 100)
    CutBtn.Text = "✂️ Cut & Rekam"
    CutBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    CutBtn.Font = Enum.Font.GothamBold
    CutBtn.TextSize = 11
    CutBtn.Parent = EditContainer
    Instance.new("UICorner", CutBtn).CornerRadius = UDim.new(0, 5)

    -- Fungsi Update UI File Cycler
    local function UpdateFileUI()
        if #availableRecords == 0 then
            CurrentFileLbl.Text = "Kosong"
        else
            CurrentFileLbl.Text = availableRecords[currentRecordIndex] or "Error"
        end
    end

    -- Logika Perluasan Panel UI
    local function UpdatePanelUI()
        if isRecording then
            MainFrame.Size = UDim2.new(0, 400, 0, 75)
            RecBtn.Text = "⏹️ Stop"
            RecBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
            RecBtn.Visible = true
            PlayPanelBtn.Visible = false
            PausePanelBtn.Visible = false
            StopPanelBtn.Visible = false
            EditContainer.Visible = false
            FileNavFrame.Visible = false
        elseif isPlaying then
            RecBtn.Visible = false
            PlayPanelBtn.Visible = false
            PausePanelBtn.Visible = true
            StopPanelBtn.Visible = true
            FileNavFrame.Visible = false
            if isPaused then
                MainFrame.Size = UDim2.new(0, 400, 0, 120) -- Expand for slider
                PausePanelBtn.Text = "▶️ Resume"
                EditContainer.Visible = true
            else
                MainFrame.Size = UDim2.new(0, 400, 0, 75)
                PausePanelBtn.Text = "⏸️ Pause"
                EditContainer.Visible = false
            end
        else
            MainFrame.Size = UDim2.new(0, 400, 0, 75)
            RecBtn.Text = "🔴 Record"
            RecBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            RecBtn.Visible = true
            PlayPanelBtn.Visible = true
            PausePanelBtn.Visible = false
            StopPanelBtn.Visible = false
            EditContainer.Visible = false
            FileNavFrame.Visible = true
        end
        UpdateFileUI()
    end

    -- ==========================================
    -- LOGIKA FILE CYCLER
    -- ==========================================
    PrevFileBtn.MouseButton1Click:Connect(function()
        if #availableRecords > 0 then
            currentRecordIndex = currentRecordIndex - 1
            if currentRecordIndex < 1 then currentRecordIndex = #availableRecords end
            UpdateFileUI()
        end
    end)

    NextFileBtn.MouseButton1Click:Connect(function()
        if #availableRecords > 0 then
            currentRecordIndex = currentRecordIndex + 1
            if currentRecordIndex > #availableRecords then currentRecordIndex = 1 end
            UpdateFileUI()
        end
    end)

    DeleteFileBtn.MouseButton1Click:Connect(function()
        if not isUnlocked then return end
        if #availableRecords == 0 or isPlaying or isRecording then return end
        
        local targetFile = availableRecords[currentRecordIndex]
        if RecordsDB[targetFile] then
            RecordsDB[targetFile] = nil
            DeleteRecordFile(targetFile)
            RefreshAvailableRecords()
            UpdatePanelUI()
            StatusLbl.Text = "Status: File " .. targetFile .. " dihapus."
        end
    end)

    -- ==========================================
    -- LOGIKA TOMBOL RECORD & PLAYBACK
    -- ==========================================
    RecBtn.MouseButton1Click:Connect(function()
        if not isRecording then
            isRecording = true
            currentRecordingFrames = {}
            StatusLbl.Text = "🔴 Merekam..."
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
                    StatusLbl.Text = "🔴 Merekam: " .. #currentRecordingFrames .. " frames"
                end
            end)
        else
            isRecording = false
            if recConn then recConn:Disconnect() end

            if #currentRecordingFrames > 0 then
                local recName = GetNextRecordID() 
                RecordsDB[recName] = currentRecordingFrames
                SaveRecordFile(recName, currentRecordingFrames) 
                
                RefreshAvailableRecords()
                
                -- Auto select file baru
                for i, v in ipairs(availableRecords) do
                    if v == recName then currentRecordIndex = i break end
                end

                StatusLbl.Text = "Status: Tersimpan (" .. recName .. ")"
            else
                StatusLbl.Text = "Status: Gagal (Frame kosong!)"
            end
            UpdatePanelUI()
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
                        if flatMoveDir.Magnitude > 0.02 then hum:Move(flatMoveDir.Unit, false) 
                        else hum:Move(Vector3.zero, false) end
                    else hum:Move(Vector3.zero, false) end

                    local percent = math.floor((playbackIndex / #data) * 100)
                    StatusLbl.Text = string.format("▶️ Memutar: Frame %d / %d (%d%%)", playbackIndex, #data, percent)
                    SliderFill.Size = UDim2.new(playbackIndex / #data, 0, 1, 0)
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
        if #availableRecords == 0 then 
            StatusLbl.Text = "Tidak ada file record!" 
            return 
        end
        local selectedFile = availableRecords[currentRecordIndex]
        local data = RecordsDB[selectedFile]
        
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
        local selectedFile = availableRecords[currentRecordIndex]
        local data = RecordsDB[selectedFile]
        if not data then return end

        if not isPaused then
            isPaused = true
            if playConn then playConn:Disconnect() end
            local char = lp.Character
            if char and char:FindFirstChildOfClass("Humanoid") then
                char:FindFirstChildOfClass("Humanoid"):Move(Vector3.zero, false)
            end
            StatusLbl.Text = "⏸️ Paused (Edit mode)"
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

    -- Custom Slider Input Logic
    local sliderDragging = false
    SliderBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then sliderDragging = true end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then sliderDragging = false end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if sliderDragging and isPaused and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local mouseX = input.Position.X
            local sliderX = SliderTrack.AbsolutePosition.X
            local sliderSize = SliderTrack.AbsoluteSize.X
            
            local percent = math.clamp((mouseX - sliderX) / sliderSize, 0, 1)
            SliderFill.Size = UDim2.new(percent, 0, 1, 0)
            
            local selectedFile = availableRecords[currentRecordIndex]
            local data = RecordsDB[selectedFile]
            if data then
                playbackIndex = math.max(1, math.floor(percent * #data))
                StatusLbl.Text = string.format("⏸️ Preview: Frame %d / %d (%d%%)", playbackIndex, #data, math.floor(percent * 100))
                
                local char = lp.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp and data[playbackIndex] then hrp.CFrame = data[playbackIndex].cframe end
            end
        end
    end)

    CutBtn.MouseButton1Click:Connect(function()
        if not isPaused then return end
        local selectedFile = availableRecords[currentRecordIndex]
        local data = RecordsDB[selectedFile]
        if not data then return end

        local newData = {}
        for i = 1, playbackIndex do table.insert(newData, data[i]) end
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
                StatusLbl.Text = "🔴 Lanjut: " .. #currentRecordingFrames .. " frames"
            end
        end)
    end)

    -- ==========================================
    -- WIND UI (MAIN MENU)
    -- ==========================================
    RecordingTab:Paragraph({
        Title = "Recording System Aktif",
        Desc = "Sistem manajemen file dan playback sekarang dipindahkan sepenuhnya ke dalam Widget Panel mengambang (Floating UI).",
        Color = Color3.fromHex("#0F7BFF")
    })

    RecordingTab:Button({
        Title = "🎛️ Buka / Tutup Panel Widget",
        Icon = "monitor",
        Callback = function()
            if not isUnlocked then return WindUI:Notify({Title="Akses Ditolak", Content="Hanya untuk myzzkey!", Duration=2}) end
            FloatingUI.Enabled = not FloatingUI.Enabled
            if FloatingUI.Enabled then
                WindUI:Notify({Title="Widget Aktif", Content="Widget (🎬) muncul di layar.", Duration=2})
            end
        end
    })

    LoadAllRecords()
    UpdatePanelUI()
end
