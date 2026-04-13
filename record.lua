return function(WindUI, RecordingTab)
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local HttpService = game:GetService("HttpService")
    local lp = Players.LocalPlayer

    -- ==========================================
    -- VARIABEL SISTEM & FOLDER MANAGEMENT
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
    local customRecordName = "" 
    local playbackIndex = 1

    -- Deklarasi UI Global untuk Module
    local FrameInfo, StorageInfo, MainRecordBtn
    local PlayBtn, DelBtn, StopBtn, PauseBtn
    local TimelineInfo, TimelineSlider, CutRecordBtn
    local RecordListDropdown

    local folderName = "Recording"
    if isfolder and not isfolder(folderName) then makefolder(folderName) end

    -- Helper Hide/Show UI
    local function SetUIVisible(element, isVisible)
        if element and element.Instance then
            pcall(function() element.Instance.Visible = isVisible end)
        end
    end

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

    -- ==========================================
    -- ADVANCED LOGIC (Nearest Frame & CP Scan)
    -- ==========================================
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

    local function ScanCPTimeline(data)
        local cps = {}
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("SpawnLocation") or (obj:IsA("BasePart") and obj.Name:lower():match("checkpoint")) then
                table.insert(cps, {name = obj.Name, pos = obj.Position})
            end
        end

        local timelineText = ""
        local detectedCPs = {}
        for i, frame in ipairs(data) do
            for _, cp in ipairs(cps) do
                if (frame.cframe.Position - cp.pos).Magnitude < 12 then
                    if not detectedCPs[cp.name] then
                        detectedCPs[cp.name] = true
                        local percent = math.floor((i / #data) * 100)
                        timelineText = timelineText .. string.format("• CP [%s] di %d%%\n", cp.name, percent)
                    end
                end
            end
        end
        if timelineText == "" then timelineText = "• Tidak ada CP terdeteksi di rute ini." end
        return timelineText
    end

    -- ==========================================
    -- UI ELEMENTS RECORDING
    -- ==========================================
    local lockStatus = isUnlocked and "✅ Terbuka (Akses myzzkey)" or "🔒 Terkunci (Bukan myzzkey)"
    FrameInfo = RecordingTab:Paragraph({
        Title = "Deteksi Time Frames",
        Desc = "Status: " .. lockStatus .. "\nTotal Frames: 0",
        Image = "clock",
        Color = Color3.fromHex("#0F7BFF")
    })

    StorageInfo = RecordingTab:Paragraph({
        Title = "📁 Folder Penyimpanan Keyframe",
        Desc = "Lokasi: storage/emulated/0/Android/data/com.roblox.client/workspace/Recording/\nSetiap record akan disimpan sebagai file (.json).",
        Color = Color3.fromHex("#29F89B")
    })

    RecordingTab:Input({
        Title = "Nama Custom Save Record",
        Placeholder = "Nama file (Kosongkan utk Auto Record_01.json)",
        Callback = function(text) customRecordName = text end
    })

    RecordListDropdown = RecordingTab:Dropdown({
        Title = "List File Record (Folder Recording)",
        Values = {"Kosong"},
        Value = "Kosong",
        SearchBarEnabled = true,
        Callback = function(opt)
            selectedRecord = type(opt) == "table" and opt.Title or opt
            local isValid = (selectedRecord ~= "Kosong" and selectedRecord ~= nil)
            
            -- Hide/Show logic berdasarkan validitas
            SetUIVisible(PlayBtn, isValid)
            SetUIVisible(DelBtn, isValid)
            if isValid then
                PlayBtn:SetTitle("▶️ Play File (".. selectedRecord .. ")")
                DelBtn:SetTitle("🗑️ Hapus File (".. selectedRecord .. ")")
            end
        end
    })

    local function UpdateRecordList()
        local list = {}
        local sortedKeys = {}
        for name, _ in pairs(RecordsDB) do table.insert(sortedKeys, name) end
        table.sort(sortedKeys)
        for _, name in ipairs(sortedKeys) do table.insert(list, name) end
        if #list == 0 then table.insert(list, "Kosong") end
        if RecordListDropdown then RecordListDropdown:Refresh(list) end
    end

    MainRecordBtn = RecordingTab:Button({
        Title = "🔴 Mulai / Stop Record",
        Icon = "video",
        Callback = function()
            if not isUnlocked then return WindUI:Notify({Title="Akses Ditolak", Content="Hanya myzzkey yang dapat merekam!", Duration=2}) end
            if isPlaying then return WindUI:Notify({Title="Error", Content="Sedang memutar record!", Duration=2}) end

            if not isRecording then
                -- START RECORD
                isRecording = true
                currentRecordingFrames = {}
                WindUI:Notify({Title="Recording", Content="Merekam posisi karakter...", Duration=1.5, Icon="video"})

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
                        FrameInfo:SetDesc("Status: 🔴 Merekam (LIVE)\nTotal Frames: " .. #currentRecordingFrames)
                    end
                end)
            else
                -- STOP RECORD
                isRecording = false
                if recConn then recConn:Disconnect() end

                if #currentRecordingFrames > 0 then
                    local recName = ""
                    if customRecordName ~= "" then
                        recName = customRecordName
                        if RecordsDB[recName] then recName = recName .. "_" .. tostring(math.random(10,99)) end
                    else
                        recName = GetNextRecordID() 
                    end
                    
                    RecordsDB[recName] = currentRecordingFrames
                    SaveRecordFile(recName, currentRecordingFrames) 
                    UpdateRecordList()
                    WindUI:Notify({Title="Disimpan", Content="Tersimpan: " .. recName .. ".json", Duration=2, Icon="save"})
                    FrameInfo:SetDesc("Status: ✅ Selesai merekam\nTotal Frames: " .. #currentRecordingFrames)
                else
                    FrameInfo:SetDesc("Status: ✅ Terbuka (Idle)\nTotal Frames: 0")
                end
            end
        end
    })

    -- ==========================================
    -- FITUR PLAYBACK (Auto-Walk, Pause, Stop)
    -- ==========================================
    PlayBtn = RecordingTab:Button({
        Title = "▶️ Play File",
        Callback = function()
            if not isUnlocked then return end
            if isRecording or isPlaying then return end

            local data = RecordsDB[selectedRecord]
            if not data then return end

            isPlaying = true
            isPaused = false
            
            -- Deteksi posisi terdekat untuk fitur Auto-Walk Seamless
            local char = lp.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            playbackIndex = hrp and FindNearestFrameIndex(data, hrp.Position) or 1
            isAutoWalkingToStart = true 

            WindUI:Notify({Title="Memutar", Content="Berjalan otomatis ke titik rekaman terdekat...", Duration=2})
            
            -- UI Visibilities
            SetUIVisible(PlayBtn, false)
            SetUIVisible(DelBtn, false)
            SetUIVisible(MainRecordBtn, false)
            SetUIVisible(StopBtn, true)
            SetUIVisible(PauseBtn, true)

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
                        FrameInfo:SetDesc(string.format("Status: 🚶 Auto-Walk ke Rute\nJarak: %d Studs", dist))
                    else
                        isAutoWalkingToStart = false -- Sampai, mulai playback
                        WindUI:Notify({Title="Menempel", Content="Memulai sinkronisasi rute!", Duration=1})
                    end
                else
                    -- Normal Playback
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

                        FrameInfo:SetDesc("Status: ▶️ Memutar (".. selectedRecord ..")\nFrame: " .. playbackIndex .. " / " .. #data)
                        playbackIndex = playbackIndex + 1
                    else
                        -- End of file
                        if playConn then playConn:Disconnect() end
                        hum:Move(Vector3.zero, false) 
                        hum:ChangeState(Enum.HumanoidStateType.Running)
                        hrp.AssemblyLinearVelocity = Vector3.zero
                        
                        isPlaying = false
                        FrameInfo:SetDesc("Status: ✅ Selesai memutar\nTotal Frames: " .. #data)
                        
                        -- Reset UI
                        SetUIVisible(StopBtn, false)
                        SetUIVisible(PauseBtn, false)
                        SetUIVisible(PlayBtn, true)
                        SetUIVisible(DelBtn, true)
                        SetUIVisible(MainRecordBtn, true)
                    end
                end
            end)
        end
    })

    PauseBtn = RecordingTab:Button({
        Title = "⏸️ Pause & Edit (Keyframe)",
        Callback = function()
            if isPlaying and not isPaused then
                isPaused = true
                if playConn then playConn:Disconnect() end
                
                local char = lp.Character
                if char and char:FindFirstChildOfClass("Humanoid") then
                    char:FindFirstChildOfClass("Humanoid"):Move(Vector3.zero, false)
                end
                
                -- Kalkulasi CP Info & Update UI
                local data = RecordsDB[selectedRecord]
                local cpText = ScanCPTimeline(data)
                TimelineInfo:SetDesc("Pilih titik keyframe di mana kamu ingin melanjutkan (Cut).\n\n" .. cpText)
                
                -- Tampilkan Editor Keyframe
                SetUIVisible(PauseBtn, false)
                SetUIVisible(TimelineInfo, true)
                SetUIVisible(TimelineSlider, true)
                SetUIVisible(CutRecordBtn, true)
                
                FrameInfo:SetDesc("Status: ⏸️ Paused / Editing\nFrame: " .. playbackIndex .. " / " .. #data)
            end
        end
    })

    StopBtn = RecordingTab:Button({
        Title = "⏹️ Stop Playback",
        Callback = function()
            if playConn then playConn:Disconnect() end
            local char = lp.Character
            if char and char:FindFirstChildOfClass("Humanoid") then char:FindFirstChildOfClass("Humanoid"):Move(Vector3.zero, false) end
            
            isPlaying = false
            isPaused = false
            
            FrameInfo:SetDesc("Status: ⏹️ Dihentikan\nTotal Frames: 0")
            
            -- Kembalikan UI ke normal
            SetUIVisible(StopBtn, false)
            SetUIVisible(PauseBtn, false)
            SetUIVisible(TimelineInfo, false)
            SetUIVisible(TimelineSlider, false)
            SetUIVisible(CutRecordBtn, false)
            SetUIVisible(PlayBtn, true)
            SetUIVisible(DelBtn, true)
            SetUIVisible(MainRecordBtn, true)
        end
    })

    -- ==========================================
    -- EDITOR SLIDER & CUT SYSTEM
    -- ==========================================
    TimelineInfo = RecordingTab:Paragraph({
        Title = "✂️ Editor Keyframe & Timeline CP",
        Desc = "Memuat data...",
        Color = Color3.fromHex("#F89B29")
    })

    TimelineSlider = RecordingTab:Slider({
        Title = "Scrub Timeline (%)",
        Min = 1,
        Max = 100,
        Value = 1,
        Callback = function(percent)
            if not isPaused then return end
            local data = RecordsDB[selectedRecord]
            if not data then return end
            
            -- Sinkronisasi persen ke index array
            playbackIndex = math.floor((percent / 100) * #data)
            if playbackIndex < 1 then playbackIndex = 1 end
            
            -- Preview Teleport Karakter saat di-slide
            local char = lp.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp and data[playbackIndex] then
                hrp.CFrame = data[playbackIndex].cframe
            end
            
            FrameInfo:SetDesc("Status: ⏸️ Preview Frame\nFrame: " .. playbackIndex .. " / " .. #data)
        end
    })

    CutRecordBtn = RecordingTab:Button({
        Title = "✂️ Lanjut Rekam (Dari Sini)",
        Callback = function()
            if not isPaused then return end
            
            local data = RecordsDB[selectedRecord]
            local newData = {}
            -- Potong (Cut) array dari 1 sampai posisi slider saat ini
            for i = 1, playbackIndex do
                table.insert(newData, data[i])
            end
            
            currentRecordingFrames = newData
            
            -- Reset Status
            isPaused = false
            isPlaying = false
            isAutoWalkingToStart = false
            isRecording = true -- Langsung switch ke mode merekam
            
            -- Kembalikan UI
            SetUIVisible(StopBtn, false)
            SetUIVisible(TimelineInfo, false)
            SetUIVisible(TimelineSlider, false)
            SetUIVisible(CutRecordBtn, false)
            SetUIVisible(MainRecordBtn, true)
            
            WindUI:Notify({Title="Cut & Record", Content="Melanjutkan rekaman dari Frame " .. playbackIndex, Duration=2})
            
            -- Mulai loop merekam sambungan
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
                    FrameInfo:SetDesc("Status: 🔴 Merekam Sambungan\nTotal Frames: " .. #currentRecordingFrames)
                end
            end)
        end
    })

    DelBtn = RecordingTab:Button({
        Title = "🗑️ Hapus File",
        Callback = function()
            if not isUnlocked then return end
            if selectedRecord == "Kosong" then return end 

            if RecordsDB[selectedRecord] then
                RecordsDB[selectedRecord] = nil
                DeleteRecordFile(selectedRecord) 
                UpdateRecordList()
                WindUI:Notify({Title="File Dihapus", Content=selectedRecord .. ".json dihapus", Duration=1.5})
                selectedRecord = "Kosong"
                
                SetUIVisible(PlayBtn, false)
                SetUIVisible(DelBtn, false)
            end
        end
    })

    LoadAllRecords()
    UpdateRecordList()

    -- Sembunyikan UI yang tidak dipakai di awal
    SetUIVisible(PlayBtn, false)
    SetUIVisible(DelBtn, false)
    SetUIVisible(StopBtn, false)
    SetUIVisible(PauseBtn, false)
    SetUIVisible(TimelineInfo, false)
    SetUIVisible(TimelineSlider, false)
    SetUIVisible(CutRecordBtn, false)
end
