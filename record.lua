return function(WindUI, RecordingTab)
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local HttpService = game:GetService("HttpService")
    local UserInputService = game:GetService("UserInputService")
    local TweenService = game:GetService("TweenService")
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
    local isMinimized = false
    
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
    -- CUSTOM FLOATING UI (DYNAMIC CAPSULE)
    -- ==========================================
    local FloatingUI = Instance.new("ScreenGui")
    FloatingUI.Name = "SYNC_DynamicPanel"
    FloatingUI.ResetOnSpawn = false
    FloatingUI.Enabled = false
    
    local uiParent = (gethui and gethui()) or (pcall(function() return CoreGui.Name end) and CoreGui) or lp.PlayerGui
    FloatingUI.Parent = uiParent

    -- Main Frame (Kapsul)
    local MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, 260, 0, 75) -- Default Size Idle
    MainFrame.Position = UDim2.new(0.5, -130, 0.8, -80)
    MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    MainFrame.BackgroundTransparency = 0.2 -- Efek elegan transparan
    MainFrame.BorderSizePixel = 0
    MainFrame.ClipsDescendants = true
    MainFrame.Parent = FloatingUI

    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 12)
    UICorner.Parent = MainFrame

    local UIStroke = Instance.new("UIStroke")
    UIStroke.Color = Color3.fromRGB(41, 248, 155)
    UIStroke.Thickness = 1.2
    UIStroke.Transparency = 0.3
    UIStroke.Parent = MainFrame

    local MainLayout = Instance.new("UIListLayout")
    MainLayout.SortOrder = Enum.SortOrder.LayoutOrder
    MainLayout.Parent = MainFrame

    -- ROW 1: Controls & Drag Handle
    local Row1 = Instance.new("Frame")
    Row1.Size = UDim2.new(1, 0, 0, 40)
    Row1.BackgroundTransparency = 1
    Row1.LayoutOrder = 1
    Row1.Parent = MainFrame

    local Row1Layout = Instance.new("UIListLayout")
    Row1Layout.FillDirection = Enum.FillDirection.Horizontal
    Row1Layout.SortOrder = Enum.SortOrder.LayoutOrder
    Row1Layout.Parent = Row1

    -- Fungsi membuat icon button seragam
    local function CreateIconBtn(text, color, isBold)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 40, 0, 40)
        btn.BackgroundTransparency = 1
        btn.Text = text
        btn.TextColor3 = color
        btn.Font = isBold and Enum.Font.GothamBold or Enum.Font.Gotham
        btn.TextSize = 18
        return btn
    end

    -- Tombol UI
    local ToggleBtn = CreateIconBtn("🎬", Color3.fromRGB(41, 248, 155), false)
    ToggleBtn.Parent = Row1
    
    local RecBtn = CreateIconBtn("🔴", Color3.fromRGB(255, 80, 80), false)
    RecBtn.Parent = Row1
    
    local PlayBtn = CreateIconBtn("▶️", Color3.fromRGB(80, 200, 255), false)
    PlayBtn.Parent = Row1
    
    local PauseBtn = CreateIconBtn("⏸️", Color3.fromRGB(255, 180, 80), false)
    PauseBtn.Parent = Row1
    
    local StopBtn = CreateIconBtn("⏹️", Color3.fromRGB(200, 100, 100), false)
    StopBtn.Parent = Row1

    local StatusLbl = Instance.new("TextLabel")
    StatusLbl.Size = UDim2.new(1, -200, 1, 0) -- Fill sisa lebar
    StatusLbl.BackgroundTransparency = 1
    StatusLbl.Text = " Siap."
    StatusLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
    StatusLbl.Font = Enum.Font.Gotham
    StatusLbl.TextSize = 11
    StatusLbl.TextXAlignment = Enum.TextXAlignment.Left
    StatusLbl.Parent = Row1

    -- ROW 2: File Manager (Hanya muncul saat Idle)
    local Row2 = Instance.new("Frame")
    Row2.Size = UDim2.new(1, 0, 0, 35)
    Row2.BackgroundTransparency = 1
    Row2.LayoutOrder = 2
    Row2.Parent = MainFrame

    local PrevBtn = Instance.new("TextButton")
    PrevBtn.Size = UDim2.new(0, 30, 0, 25)
    PrevBtn.Position = UDim2.new(0, 5, 0, 5)
    PrevBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    PrevBtn.Text = "<"
    PrevBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    PrevBtn.Font = Enum.Font.GothamBold
    PrevBtn.TextSize = 12
    Instance.new("UICorner", PrevBtn).CornerRadius = UDim.new(0, 6)
    PrevBtn.Parent = Row2

    local FileLbl = Instance.new("TextLabel")
    FileLbl.Size = UDim2.new(1, -110, 0, 25)
    FileLbl.Position = UDim2.new(0, 40, 0, 5)
    FileLbl.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    FileLbl.Text = "Kosong"
    FileLbl.TextColor3 = Color3.fromRGB(220, 220, 220)
    FileLbl.Font = Enum.Font.Gotham
    FileLbl.TextSize = 11
    Instance.new("UICorner", FileLbl).CornerRadius = UDim.new(0, 6)
    FileLbl.Parent = Row2

    local NextBtn = Instance.new("TextButton")
    NextBtn.Size = UDim2.new(0, 30, 0, 25)
    NextBtn.Position = UDim2.new(1, -65, 0, 5)
    NextBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    NextBtn.Text = ">"
    NextBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    NextBtn.Font = Enum.Font.GothamBold
    NextBtn.TextSize = 12
    Instance.new("UICorner", NextBtn).CornerRadius = UDim.new(0, 6)
    NextBtn.Parent = Row2

    local DelBtn = Instance.new("TextButton")
    DelBtn.Size = UDim2.new(0, 25, 0, 25)
    DelBtn.Position = UDim2.new(1, -30, 0, 5)
    DelBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
    DelBtn.Text = "🗑️"
    DelBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    DelBtn.Font = Enum.Font.Gotham
    DelBtn.TextSize = 12
    Instance.new("UICorner", DelBtn).CornerRadius = UDim.new(0, 6)
    DelBtn.Parent = Row2

    -- ROW 3: Editor Slider (Hanya muncul saat Pause)
    local Row3 = Instance.new("Frame")
    Row3.Size = UDim2.new(1, 0, 0, 50)
    Row3.BackgroundTransparency = 1
    Row3.LayoutOrder = 3
    Row3.Parent = MainFrame

    local SliderTrack = Instance.new("Frame")
    SliderTrack.Size = UDim2.new(1, -90, 0, 6)
    SliderTrack.Position = UDim2.new(0, 10, 0, 22)
    SliderTrack.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    Instance.new("UICorner", SliderTrack).CornerRadius = UDim.new(1, 0)
    SliderTrack.Parent = Row3

    local SliderFill = Instance.new("Frame")
    SliderFill.Size = UDim2.new(0, 0, 1, 0)
    SliderFill.BackgroundColor3 = Color3.fromRGB(41, 248, 155)
    Instance.new("UICorner", SliderFill).CornerRadius = UDim.new(1, 0)
    SliderFill.Parent = SliderTrack

    local SliderKnob = Instance.new("Frame")
    SliderKnob.Size = UDim2.new(0, 14, 0, 14)
    SliderKnob.Position = UDim2.new(1, -7, 0.5, -7)
    SliderKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Instance.new("UICorner", SliderKnob).CornerRadius = UDim.new(1, 0)
    SliderKnob.Parent = SliderFill

    local SliderTouchBtn = Instance.new("TextButton")
    SliderTouchBtn.Size = UDim2.new(1, 0, 1, 30)
    SliderTouchBtn.Position = UDim2.new(0, 0, 0, -15)
    SliderTouchBtn.BackgroundTransparency = 1
    SliderTouchBtn.Text = ""
    SliderTouchBtn.Parent = SliderTrack

    local CutBtn = Instance.new("TextButton")
    CutBtn.Size = UDim2.new(0, 65, 0, 26)
    CutBtn.Position = UDim2.new(1, -75, 0, 12)
    CutBtn.BackgroundColor3 = Color3.fromRGB(60, 180, 100)
    CutBtn.Text = "✂️ Cut"
    CutBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    CutBtn.Font = Enum.Font.GothamBold
    CutBtn.TextSize = 11
    Instance.new("UICorner", CutBtn).CornerRadius = UDim.new(0, 5)
    CutBtn.Parent = Row3

    -- ==========================================
    -- LOGIKA ANIMASI & DYNAMIC SIZING
    -- ==========================================
    local function UpdateFileUI()
        if #availableRecords == 0 then
            FileLbl.Text = "Kosong"
        else
            FileLbl.Text = availableRecords[currentRecordIndex] or "Error"
        end
    end

    local function AnimatePanel(targetWidth, targetHeight)
        local tweenInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        local tween = TweenService:Create(MainFrame, tweenInfo, {Size = UDim2.new(0, targetWidth, 0, targetHeight)})
        tween:Play()
    end

    local function UpdatePanelUI()
        UpdateFileUI()

        if isMinimized then
            ToggleBtn.Text = isRecording and "🔴" or "🎬"
            RecBtn.Visible = false
            PlayBtn.Visible = false
            PauseBtn.Visible = false
            StopBtn.Visible = false
            StatusLbl.Visible = false
            Row2.Visible = false
            Row3.Visible = false
            AnimatePanel(40, 40) -- Shrink menjadi tombol bulat kecil
            return
        end

        -- Mode Expanded
        ToggleBtn.Text = "✖"
        StatusLbl.Visible = true

        if isRecording then
            RecBtn.Visible = true
            RecBtn.Text = "⏹️"
            PlayBtn.Visible = false
            PauseBtn.Visible = false
            StopBtn.Visible = false
            Row2.Visible = false
            Row3.Visible = false
            AnimatePanel(160, 40) -- Ultra compact saat merekam
            
        elseif isPlaying then
            RecBtn.Visible = false
            PlayBtn.Visible = false
            PauseBtn.Visible = true
            StopBtn.Visible = true
            Row2.Visible = false
            
            if isPaused then
                PauseBtn.Text = "▶️"
                Row3.Visible = true
                AnimatePanel(260, 90) -- Expand ke bawah untuk slider
            else
                PauseBtn.Text = "⏸️"
                Row3.Visible = false
                AnimatePanel(200, 40) -- Compact saat play biasa
            end
            
        else
            -- Mode Idle
            RecBtn.Visible = true
            RecBtn.Text = "🔴"
            PlayBtn.Visible = true
            PauseBtn.Visible = false
            StopBtn.Visible = false
            Row2.Visible = true
            Row3.Visible = false
            AnimatePanel(260, 75) -- Standar size dengan file manager
        end
    end

    -- ==========================================
    -- LOGIKA DRAG & TOGGLE (Super Presisi)
    -- ==========================================
    local isDragging = false
    local dragStart, startPos
    local hasMoved = false

    ToggleBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
            hasMoved = false
            dragStart = input.Position
            startPos = MainFrame.Position
        end
    end)

    ToggleBtn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = false
            if not hasMoved then
                isMinimized = not isMinimized
                UpdatePanelUI()
            end
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            if delta.Magnitude > 5 then hasMoved = true end
            if hasMoved then
                MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end
    end)

    -- ==========================================
    -- LOGIKA FUNGSI (FILE, REC, PLAY, SLIDER)
    -- ==========================================
    PrevBtn.MouseButton1Click:Connect(function()
        if #availableRecords > 0 then
            currentRecordIndex = currentRecordIndex - 1
            if currentRecordIndex < 1 then currentRecordIndex = #availableRecords end
            UpdateFileUI()
        end
    end)

    NextBtn.MouseButton1Click:Connect(function()
        if #availableRecords > 0 then
            currentRecordIndex = currentRecordIndex + 1
            if currentRecordIndex > #availableRecords then currentRecordIndex = 1 end
            UpdateFileUI()
        end
    end)

    DelBtn.MouseButton1Click:Connect(function()
        if not isUnlocked or #availableRecords == 0 then return end
        local targetFile = availableRecords[currentRecordIndex]
        if RecordsDB[targetFile] then
            RecordsDB[targetFile] = nil
            DeleteRecordFile(targetFile)
            LoadAllRecords()
            StatusLbl.Text = " Terhapus."
            UpdatePanelUI()
        end
    end)

    RecBtn.MouseButton1Click:Connect(function()
        if not isRecording then
            isRecording = true
            currentRecordingFrames = {}
            StatusLbl.Text = " 🔴 Merekam..."
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
                    StatusLbl.Text = " 🔴 " .. #currentRecordingFrames .. "f"
                end
            end)
        else
            isRecording = false
            if recConn then recConn:Disconnect() end

            if #currentRecordingFrames > 0 then
                local recName = GetNextRecordID() 
                RecordsDB[recName] = currentRecordingFrames
                SaveRecordFile(recName, currentRecordingFrames) 
                
                LoadAllRecords()
                -- Auto focus ke file baru
                for i, v in ipairs(availableRecords) do
                    if v == recName then currentRecordIndex = i break end
                end
                StatusLbl.Text = " Disimpan."
            else
                StatusLbl.Text = " Frame kosong!"
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
                    StatusLbl.Text = string.format(" 🚶 %d Studs", math.floor(dist))
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
                    StatusLbl.Text = string.format(" ▶ %d%%", percent)
                    SliderFill.Size = UDim2.new(playbackIndex / #data, 0, 1, 0)
                    playbackIndex = playbackIndex + 1
                else
                    if playConn then playConn:Disconnect() end
                    hum:Move(Vector3.zero, false) 
                    hum:ChangeState(Enum.HumanoidStateType.Running)
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    
                    isPlaying = false
                    isPaused = false
                    StatusLbl.Text = " ✅ Selesai."
                    UpdatePanelUI()
                end
            end
        end)
    end

    PlayBtn.MouseButton1Click:Connect(function()
        if #availableRecords == 0 then return end
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

    PauseBtn.MouseButton1Click:Connect(function()
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
            StatusLbl.Text = " ⏸️ Paused"
            UpdatePanelUI()
        else
            isPaused = false
            StatusLbl.Text = " ▶️ Resumed"
            UpdatePanelUI()
            StartPlaybackLoop(data)
        end
    end)

    StopBtn.MouseButton1Click:Connect(function()
        if playConn then playConn:Disconnect() end
        local char = lp.Character
        if char and char:FindFirstChildOfClass("Humanoid") then char:FindFirstChildOfClass("Humanoid"):Move(Vector3.zero, false) end
        
        isPlaying = false
        isPaused = false
        StatusLbl.Text = " ⏹️ Stopped"
        UpdatePanelUI()
    end)

    local sliderDragging = false
    SliderTouchBtn.InputBegan:Connect(function(input)
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
                StatusLbl.Text = string.format(" ⏸ Preview: %d%%", math.floor(percent * 100))
                
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
        
        StatusLbl.Text = " ✂ Lanjut Rekam..."
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
                StatusLbl.Text = " 🔴 Lanjut: " .. #currentRecordingFrames .. "f"
            end
        end)
    end)

    -- ==========================================
    -- WIND UI SETUP
    -- ==========================================
    RecordingTab:Paragraph({
        Title = "Kapsul Dynamic Record",
        Desc = "UI telah dioptimasi untuk mobile. Klik tombol di bawah untuk menampilkan Panel Kapsul.",
        Color = Color3.fromHex("#0F7BFF")
    })

    RecordingTab:Button({
        Title = "🎛️ Buka / Tutup Kapsul",
        Icon = "monitor",
        Callback = function()
            if not isUnlocked then return WindUI:Notify({Title="Akses Ditolak", Content="Hanya untuk myzzkey!", Duration=2}) end
            FloatingUI.Enabled = not FloatingUI.Enabled
        end
    })

    LoadAllRecords()
    UpdatePanelUI()
end
