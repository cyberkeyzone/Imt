Return function(WindUI, RecordingTab)
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local HttpService = game:GetService("HttpService")
    local UserInputService = game:GetService("UserInputService")
    local TweenService = game:GetService("TweenService")
    local CoreGui = game:GetService("CoreGui")
    local lp = Players.LocalPlayer
    local currentPlaceId = game.PlaceId 

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
    local countdownActive = false
    
    local recConn = nil
    local playConn = nil
    local playbackIndex = 1
    local appendTargetFile = nil 
    
    -- Variabel Mesin Waktu (Anti-Lag & Presisi Tinggi)
    local recordingStartTime = 0
    local playbackStartTime = 0
    local autoWalkStartTime = 0 -- FIX: Ditambahkan untuk mencegah macet saat AutoWalk

    local folderName = "Recording"
    if isfolder and not isfolder(folderName) then makefolder(folderName) end

    -- ==========================================
    -- FUNGSI INTERNAL DATA
    -- ==========================================
    local function SerializeData(framesArray)
        local serializedFrames = {}
        for i, frame in ipairs(framesArray) do
            serializedFrames[i] = {
                time = frame.time, 
                cframe = {frame.cframe:GetComponents()},
                vel = {frame.vel.X, frame.vel.Y, frame.vel.Z},
                state = frame.state.Name 
            }
        end
        return {
            PlaceId = tostring(currentPlaceId),
            Frames = serializedFrames
        }
    end

    local function DeserializeData(jsonData)
        local deserializedFrames = {}
        local framesToProcess = jsonData.Frames or jsonData
        
        for i, frame in ipairs(framesToProcess) do
            deserializedFrames[i] = {
                time = frame.time or (i * 0.016), 
                cframe = CFrame.new(unpack(frame.cframe)),
                vel = Vector3.new(unpack(frame.vel)),
                state = Enum.HumanoidStateType[frame.state]
            }
        end
        return deserializedFrames
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

    local MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, 250, 0, 75) 
    MainFrame.Position = UDim2.new(0.5, -125, 0.8, -80)
    MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    MainFrame.BackgroundTransparency = 0.15 
    MainFrame.BorderSizePixel = 0
    MainFrame.ClipsDescendants = true
    MainFrame.Parent = FloatingUI

    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 14)
    UICorner.Parent = MainFrame

    local UIStroke = Instance.new("UIStroke")
    UIStroke.Color = Color3.fromRGB(41, 248, 155)
    UIStroke.Thickness = 1.2
    UIStroke.Transparency = 0.2
    UIStroke.Parent = MainFrame

    local MainLayout = Instance.new("UIListLayout")
    MainLayout.SortOrder = Enum.SortOrder.LayoutOrder
    MainLayout.Parent = MainFrame

    -- ROW 1: Controls
    local Row1 = Instance.new("Frame")
    Row1.Size = UDim2.new(1, 0, 0, 40)
    Row1.BackgroundTransparency = 1
    Row1.LayoutOrder = 1
    Row1.Parent = MainFrame

    local Row1Layout = Instance.new("UIListLayout")
    Row1Layout.FillDirection = Enum.FillDirection.Horizontal
    Row1Layout.SortOrder = Enum.SortOrder.LayoutOrder
    Row1Layout.Padding = UDim.new(0, 4) 
    Row1Layout.Parent = Row1

    local function CreateIconBtn(text, color, isBold)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 38, 0, 38)
        btn.Position = UDim2.new(0, 0, 0, 1)
        btn.BackgroundTransparency = 1
        btn.Text = text
        btn.TextColor3 = color
        btn.Font = isBold and Enum.Font.GothamBold or Enum.Font.Gotham
        btn.TextSize = 18
        return btn
    end

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
    StatusLbl.Size = UDim2.new(1, -120, 1, 0)
    StatusLbl.BackgroundTransparency = 1
    StatusLbl.Text = " Siap."
    StatusLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
    StatusLbl.Font = Enum.Font.Gotham
    StatusLbl.TextSize = 12
    StatusLbl.TextXAlignment = Enum.TextXAlignment.Left
    StatusLbl.Parent = Row1

    -- ROW 2: File Manager
    local Row2 = Instance.new("Frame")
    Row2.Size = UDim2.new(1, 0, 0, 35)
    Row2.BackgroundTransparency = 1
    Row2.LayoutOrder = 2
    Row2.Parent = MainFrame

    local PrevBtn = Instance.new("TextButton")
    PrevBtn.Size = UDim2.new(0, 30, 0, 25)
    PrevBtn.Position = UDim2.new(0, 8, 0, 5)
    PrevBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    PrevBtn.Text = "<"
    PrevBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    PrevBtn.Font = Enum.Font.GothamBold
    PrevBtn.TextSize = 12
    Instance.new("UICorner", PrevBtn).CornerRadius = UDim.new(0, 6)
    PrevBtn.Parent = Row2

    local FileLbl = Instance.new("TextLabel")
    FileLbl.Size = UDim2.new(1, -116, 0, 25)
    FileLbl.Position = UDim2.new(0, 42, 0, 5)
    FileLbl.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    FileLbl.Text = "Kosong"
    FileLbl.TextColor3 = Color3.fromRGB(220, 220, 220)
    FileLbl.Font = Enum.Font.Gotham
    FileLbl.TextSize = 11
    Instance.new("UICorner", FileLbl).CornerRadius = UDim.new(0, 6)
    FileLbl.Parent = Row2

    local NextBtn = Instance.new("TextButton")
    NextBtn.Size = UDim2.new(0, 30, 0, 25)
    NextBtn.Position = UDim2.new(1, -70, 0, 5)
    NextBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    NextBtn.Text = ">"
    NextBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    NextBtn.Font = Enum.Font.GothamBold
    NextBtn.TextSize = 12
    Instance.new("UICorner", NextBtn).CornerRadius = UDim.new(0, 6)
    NextBtn.Parent = Row2

    local DelBtn = Instance.new("TextButton")
    DelBtn.Size = UDim2.new(0, 25, 0, 25)
    DelBtn.Position = UDim2.new(1, -33, 0, 5)
    DelBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
    DelBtn.Text = "🗑️"
    DelBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    DelBtn.Font = Enum.Font.Gotham
    DelBtn.TextSize = 12
    Instance.new("UICorner", DelBtn).CornerRadius = UDim.new(0, 6)
    DelBtn.Parent = Row2

    -- ROW 3: Editor Slider & Save Button
    local Row3 = Instance.new("Frame")
    Row3.Size = UDim2.new(1, 0, 0, 75) 
    Row3.BackgroundTransparency = 1
    Row3.LayoutOrder = 3
    Row3.Parent = MainFrame

    local SliderTrack = Instance.new("Frame")
    SliderTrack.Size = UDim2.new(1, -24, 0, 8) 
    SliderTrack.Position = UDim2.new(0, 12, 0, 15)
    SliderTrack.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    Instance.new("UICorner", SliderTrack).CornerRadius = UDim.new(1, 0)
    SliderTrack.Parent = Row3

    local SliderFill = Instance.new("Frame")
    SliderFill.Size = UDim2.new(0, 0, 1, 0)
    SliderFill.BackgroundColor3 = Color3.fromRGB(41, 248, 155)
    Instance.new("UICorner", SliderFill).CornerRadius = UDim.new(1, 0)
    SliderFill.Parent = SliderTrack

    local SliderKnob = Instance.new("Frame")
    SliderKnob.Size = UDim2.new(0, 20, 0, 20) 
    SliderKnob.Position = UDim2.new(1, -10, 0.5, -10)
    SliderKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Instance.new("UICorner", SliderKnob).CornerRadius = UDim.new(1, 0)
    SliderKnob.Parent = SliderFill

    local SliderTouchBtn = Instance.new("TextButton")
    SliderTouchBtn.Size = UDim2.new(1, 0, 1, 40) 
    SliderTouchBtn.Position = UDim2.new(0, 0, 0, -20)
    SliderTouchBtn.BackgroundTransparency = 1
    SliderTouchBtn.Text = ""
    SliderTouchBtn.Parent = SliderTrack

    local CutBtn = Instance.new("TextButton")
    CutBtn.Size = UDim2.new(0, 105, 0, 28)
    CutBtn.Position = UDim2.new(0, 12, 0, 36)
    CutBtn.BackgroundColor3 = Color3.fromRGB(60, 180, 100)
    CutBtn.Text = "✂️ Cut & Rekam"
    CutBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    CutBtn.Font = Enum.Font.GothamBold
    CutBtn.TextSize = 11
    Instance.new("UICorner", CutBtn).CornerRadius = UDim.new(0, 5)
    CutBtn.Parent = Row3

    local SaveEditBtn = Instance.new("TextButton")
    SaveEditBtn.Size = UDim2.new(0, 105, 0, 28)
    SaveEditBtn.Position = UDim2.new(1, -117, 0, 36)
    SaveEditBtn.BackgroundColor3 = Color3.fromRGB(40, 130, 230)
    SaveEditBtn.Text = "💾 Simpan Edit"
    SaveEditBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    SaveEditBtn.Font = Enum.Font.GothamBold
    SaveEditBtn.TextSize = 11
    Instance.new("UICorner", SaveEditBtn).CornerRadius = UDim.new(0, 5)
    SaveEditBtn.Parent = Row3

    -- ==========================================
    -- LOGIKA ANIMASI PANEL
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
            AnimatePanel(40, 40)
            return
        end

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
            AnimatePanel(190, 40) 
            
        elseif isPlaying then
            RecBtn.Visible = false
            PlayBtn.Visible = false
            PauseBtn.Visible = true
            StopBtn.Visible = true
            Row2.Visible = false
            
            if isPaused then
                PauseBtn.Text = "▶️"
                Row3.Visible = true
                AnimatePanel(250, 115) 
            else
                PauseBtn.Text = "⏸️"
                Row3.Visible = false
                AnimatePanel(190, 40) 
            end
            
        else
            RecBtn.Visible = true
            RecBtn.Text = "🔴"
            PlayBtn.Visible = true
            PauseBtn.Visible = false
            StopBtn.Visible = false
            Row2.Visible = true
            Row3.Visible = false
            AnimatePanel(250, 75) 
        end
    end

    -- ==========================================
    -- LOGIKA DRAG & TOGGLE PANEL
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
    -- LOGIKA FILE MANAGER
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

    -- ==========================================
    -- 🕒 RECORDING ENGINE (OS.CLOCK)
    -- ==========================================
    RecBtn.MouseButton1Click:Connect(function()
        if not isRecording then
            appendTargetFile = nil
            isRecording = true
            countdownActive = false
            currentRecordingFrames = {}
            recordingStartTime = os.clock() 
            
            StatusLbl.Text = " Merekam..."
            UpdatePanelUI()

            recConn = RunService.Heartbeat:Connect(function()
                local char = lp.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                
                if hrp and hum then
                    table.insert(currentRecordingFrames, {
                        time = os.clock() - recordingStartTime,
                        cframe = hrp.CFrame,
                        vel = hrp.AssemblyLinearVelocity,
                        state = hum:GetState() 
                    })
                    StatusLbl.Text = string.format(" Rec: %df", #currentRecordingFrames)
                end
            end)
        else
            isRecording = false
            countdownActive = false
            if recConn then recConn:Disconnect() end

            if #currentRecordingFrames > 0 then
                local recName = appendTargetFile or GetNextRecordID() 
                RecordsDB[recName] = currentRecordingFrames
                SaveRecordFile(recName, currentRecordingFrames) 
                
                LoadAllRecords()
                for i, v in ipairs(availableRecords) do
                    if v == recName then currentRecordIndex = i break end
                end
                StatusLbl.Text = " Disimpan."
            else
                StatusLbl.Text = " Frame kosong!"
            end
            
            appendTargetFile = nil 
            UpdatePanelUI()
        end
    end)

    -- ==========================================
    -- 🕒 STEPPED PLAYBACK ENGINE (SUPER SMOOTH)
    -- ==========================================
    local function StartPlaybackLoop(data)
        if playConn then playConn:Disconnect() end
        
        playConn = RunService.Stepped:Connect(function()
            local char = lp.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid") 
            
            if not hrp or not hum then return end

            if isAutoWalkingToStart then
                -- Fase Auto-Walk: Bergerak normal pakai physics bawaan
                local targetPos = data[playbackIndex].cframe.Position
                local dist = (hrp.Position - targetPos).Magnitude
                
                -- FIX: Beri batas waktu (3 detik) agar tidak macet/stuck selamanya
                if dist > 3 and (os.clock() - autoWalkStartTime) < 3 then
                    hum:MoveTo(targetPos)
                    StatusLbl.Text = string.format(" AutoWalk: %d Studs", math.floor(dist))
                else
                    -- Jika kelamaan atau sudah dekat, paksa teleport langsung ke titik awal agar pasti jalan
                    hrp.CFrame = data[playbackIndex].cframe
                    isAutoWalkingToStart = false 
                    playbackStartTime = os.clock() - (data[playbackIndex].time or 0)
                end
            else
                -- Fase Playback: Injeksi CFrame & Velocity Murni
                local t = os.clock() - playbackStartTime
                
                while data[playbackIndex + 1] and t >= data[playbackIndex + 1].time do
                    playbackIndex = playbackIndex + 1
                end

                local currentFrame = data[playbackIndex]
                local nextFrame = data[playbackIndex + 1]

                if nextFrame then
                    local timeDiff = nextFrame.time - currentFrame.time
                    if timeDiff <= 0 then timeDiff = 0.001 end
                    local alpha = math.clamp((t - currentFrame.time) / timeDiff, 0, 1)
                    
                    hrp.CFrame = currentFrame.cframe:Lerp(nextFrame.cframe, alpha)
                    hrp.AssemblyLinearVelocity = currentFrame.vel:Lerp(nextFrame.vel, alpha)
                    
                    if hum:GetState() ~= currentFrame.state then 
                        hum:ChangeState(currentFrame.state) 
                    end

                    local percent = math.floor((playbackIndex / #data) * 100)
                    StatusLbl.Text = string.format(" ▶ %d%%", percent)
                    SliderFill.Size = UDim2.new(playbackIndex / #data, 0, 1, 0)
                else
                    if playConn then playConn:Disconnect() end
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
        autoWalkStartTime = os.clock() -- FIX: Mulai timer mencegah stuck
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
            if char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then hrp.Anchored = true end 
            end
            
            StatusLbl.Text = " ⏸️ Editor"
            UpdatePanelUI()
        else
            isPaused = false
            StatusLbl.Text = " ▶️ Resumed"
            UpdatePanelUI()
            
            local char = lp.Character
            if char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then hrp.Anchored = false end 
            end
            
            playbackStartTime = os.clock() - (data[playbackIndex].time or 0)
            StartPlaybackLoop(data)
        end
    end)

    StopBtn.MouseButton1Click:Connect(function()
        if playConn then playConn:Disconnect() end
        local char = lp.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then hrp.Anchored = false end
        end
        
        countdownActive = false 
        isPlaying = false
        isPaused = false
        StatusLbl.Text = " ⏹️ Stopped"
        UpdatePanelUI()
    end)

    -- ==========================================
    -- LOGIKA EDITOR SLIDER & SMART CUT 
    -- ==========================================
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
            
            -- FIX: Cegah pembagian angka dengan 0 jika size slider sedang tidak wajar (Penyebab Black Screen/NaN)
            if sliderSize <= 0 then sliderSize = 1 end
            
            local percent = math.clamp((mouseX - sliderX) / sliderSize, 0, 1)
            SliderFill.Size = UDim2.new(percent, 0, 1, 0)
            
            local selectedFile = availableRecords[currentRecordIndex]
            local data = RecordsDB[selectedFile]
            if data and #data > 0 then
                -- FIX: Pastikan index selalu di dalam range agar tidak memanggil tabel kosong
                playbackIndex = math.clamp(math.floor(percent * #data), 1, #data)
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

        local char = lp.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then return end

        -- FIX: Menggunakan playbackIndex langsung dari slider!
        -- Saya telah menghapus FindNearestFrameIndex agar potongan 100% presisi dan tidak ngacak
        
        appendTargetFile = selectedFile

        local newData = {}
        for i = 1, playbackIndex do table.insert(newData, data[i]) end
        currentRecordingFrames = newData
        
        isPaused = false
        isPlaying = false
        isAutoWalkingToStart = false
        isRecording = true 
        UpdatePanelUI()
        
        countdownActive = true
        
        task.spawn(function()
            hrp.Anchored = true
            hrp.CFrame = data[playbackIndex].cframe

            for i = 2, 1, -1 do
                if not countdownActive then 
                    hrp.Anchored = false
                    return 
                end 
                StatusLbl.Text = string.format(" ⏳ Siap Gerak... %d", i)
                task.wait(1)
            end

            if not countdownActive then 
                hrp.Anchored = false
                return 
            end
            
            countdownActive = false
            StatusLbl.Text = " 🔴 Merekam Sambungan..."

            hrp.Anchored = false
            hrp.CFrame = data[playbackIndex].cframe
            hrp.AssemblyLinearVelocity = data[playbackIndex].vel
            hum:ChangeState(data[playbackIndex].state)

            recordingStartTime = os.clock() - (data[playbackIndex].time or 0)

            recConn = RunService.Heartbeat:Connect(function()
                if hrp and hum then
                    table.insert(currentRecordingFrames, {
                        time = os.clock() - recordingStartTime,
                        cframe = hrp.CFrame,
                        vel = hrp.AssemblyLinearVelocity,
                        state = hum:GetState() 
                    })
                    StatusLbl.Text = string.format(" Lanjut: %df", #currentRecordingFrames)
                end
            end)
        end)
    end)

    SaveEditBtn.MouseButton1Click:Connect(function()
        if not isPaused then return end
        local selectedFile = availableRecords[currentRecordIndex]
        local data = RecordsDB[selectedFile]
        if not data then return end

        local newData = {}
        for i = 1, playbackIndex do table.insert(newData, data[i]) end
        
        RecordsDB[selectedFile] = newData
        SaveRecordFile(selectedFile, newData)
        
        SliderFill.Size = UDim2.new(1, 0, 1, 0)
        StatusLbl.Text = " 💾 Timpa: " .. selectedFile
    end)

    -- ==========================================
    -- WIND UI SETUP
    -- ==========================================
    RecordingTab:Paragraph({
        Title = "Kapsul Dynamic Record",
        Desc = "Sistem Recording telah dipindahkan ke Floating Panel. Klik tombol di bawah untuk menampilkannya.",
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
