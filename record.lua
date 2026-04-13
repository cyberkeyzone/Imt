return function(WindUI, RecordingTab)
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local HttpService = game:GetService("HttpService")
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
    local customRecordName = "" 
    local playbackIndex = 1

    -- Deklarasi UI Global untuk Module
    local FrameInfo, StorageInfo, MainRecordBtn
    local PlayBtn, DelBtn, StopBtn, PauseBtn
    local TimelineInfo, TimelineSlider, CutRecordBtn
    local RecordListDropdown

    local folderName = "Recording"
    if isfolder and not isfolder(folderName) then makefolder(folderName) end

    -- ==========================================
    -- FUNGSI INTERNAL (DATA & FILE)
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
        if timelineText == "" then timelineText = "• Tidak ada CP terdeteksi di rute rekaman ini." end
        return timelineText
    end

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
                    FrameInfo:SetDesc(string.format("Status: 🚶 Auto-Walk ke Rute\nJarak: %d Studs", math.floor(dist)))
                else
                    isAutoWalkingToStart = false 
                    WindUI:Notify({Title="Menempel", Content="Memulai sinkronisasi rute!", Duration=1})
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

                    FrameInfo:SetDesc("Status: ▶️ Memutar (".. selectedRecord ..")\nFrame: " .. playbackIndex .. " / " .. #data)
                    playbackIndex = playbackIndex + 1
                else
                    -- Selesai
                    if playConn then playConn:Disconnect() end
                    hum:Move(Vector3.zero, false) 
                    hum:ChangeState(Enum.HumanoidStateType.Running)
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    
                    isPlaying = false
                    isPaused = false
                    FrameInfo:SetDesc("Status: ✅ Selesai memutar\nTotal Frames: " .. #data)
                    WindUI:Notify({Title="Selesai", Content="Playback file selesai!", Duration=1.5, Icon="check"})
                    
                    PauseBtn:SetTitle("🚫 Pause Terkunci")
                    StopBtn:SetTitle("🚫 Stop Terkunci")
                end
            end
        end)
    end

    -- ==========================================
    -- UI: 1. INFO & FILE MANAGEMENT
    -- ==========================================
    local lockStatus = isUnlocked and "✅ Terbuka (Akses myzzkey)" or "🔒 Terkunci (Bukan myzzkey)"
    FrameInfo = RecordingTab:Paragraph({
        Title = "Deteksi Time Frames",
        Desc = "Status: " .. lockStatus .. "\nTotal Frames: 0",
        Image = "clock",
        Color = Color3.fromHex("#0F7BFF")
    })

    RecordListDropdown = RecordingTab:Dropdown({
        Title = "List File Record",
        Values = {"Kosong"},
        Value = "Kosong",
        SearchBarEnabled = true,
        Callback = function(opt)
            selectedRecord = type(opt) == "table" and opt.Title or opt
            if selectedRecord ~= "Kosong" and selectedRecord ~= nil then
                PlayBtn:SetTitle("▶️ Play File (".. selectedRecord .. ")")
                DelBtn:SetTitle("🗑️ Hapus File (".. selectedRecord .. ")")
            else
                PlayBtn:SetTitle("🚫 Pilih List (Play Terkunci)")
                DelBtn:SetTitle("🚫 Pilih List (Hapus Terkunci)")
            end
        end
    })

    DelBtn = RecordingTab:Button({
        Title = "🚫 Pilih List (Hapus Terkunci)",
        Callback = function()
            if not isUnlocked then return end
            if selectedRecord == "Kosong" or isPlaying or isRecording then 
                return WindUI:Notify({Title="Gagal", Content="Pilih list valid / hentikan aktivitas dulu", Duration=2}) 
            end 

            if RecordsDB[selectedRecord] then
                RecordsDB[selectedRecord] = nil
                DeleteRecordFile(selectedRecord) 
                
                local list = {}
                for name, _ in pairs(RecordsDB) do table.insert(list, name) end
                if #list == 0 then table.insert(list, "Kosong") end
                if RecordListDropdown then RecordListDropdown:Refresh(list) end

                WindUI:Notify({Title="File Dihapus", Content=selectedRecord .. ".json dihapus", Duration=1.5})
                selectedRecord = "Kosong"
                PlayBtn:SetTitle("🚫 Pilih List (Play Terkunci)")
                DelBtn:SetTitle("🚫 Pilih List (Hapus Terkunci)")
            end
        end
    })

    RecordingTab:Divider()

    -- ==========================================
    -- UI: 2. RECORDING CONTROL
    -- ==========================================
    RecordingTab:Input({
        Title = "Nama Custom Save Record",
        Placeholder = "Nama file (Kosongkan utk Auto Record_01)",
        Callback = function(text) customRecordName = text end
    })

    MainRecordBtn = RecordingTab:Button({
        Title = "🔴 Mulai / Stop Record",
        Icon = "video",
        Callback = function()
            if not isUnlocked then return WindUI:Notify({Title="Akses Ditolak", Content="Hanya myzzkey yang dapat merekam!", Duration=2}) end
            if isPlaying then return WindUI:Notify({Title="Error", Content="Sedang memutar record!", Duration=2}) end

            if not isRecording then
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
                    
                    local list = {}
                    for name, _ in pairs(RecordsDB) do table.insert(list, name) end
                    if RecordListDropdown then RecordListDropdown:Refresh(list) end

                    WindUI:Notify({Title="Disimpan", Content="Tersimpan: " .. recName .. ".json", Duration=2, Icon="save"})
                    FrameInfo:SetDesc("Status: ✅ Selesai merekam\nTotal Frames: " .. #currentRecordingFrames)
                else
                    FrameInfo:SetDesc("Status: ✅ Terbuka (Idle)\nTotal Frames: 0")
                end
            end
        end
    })

    RecordingTab:Divider()

    -- ==========================================
    -- UI: 3. PLAYBACK CONTROL
    -- ==========================================
    PlayBtn = RecordingTab:Button({
        Title = "🚫 Pilih List (Play Terkunci)",
        Callback = function()
            if not isUnlocked then return end
            if selectedRecord == "Kosong" then return WindUI:Notify({Title="Gagal", Content="Pilih list file terlebih dahulu!", Duration=2}) end
            if isRecording or isPlaying then return WindUI:Notify({Title="Error", Content="Matikan record/playback saat ini!", Duration=2}) end

            local data = RecordsDB[selectedRecord]
            if not data then return end

            isPlaying = true
            isPaused = false
            
            local char = lp.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            playbackIndex = hrp and FindNearestFrameIndex(data, hrp.Position) or 1
            isAutoWalkingToStart = true 

            WindUI:Notify({Title="Memutar", Content="Berjalan otomatis ke titik rekaman terdekat...", Duration=2})
            
            PauseBtn:SetTitle("⏸️ Pause Playback")
            StopBtn:SetTitle("⏹️ Stop Playback")
            
            StartPlaybackLoop(data)
        end
    })

    PauseBtn = RecordingTab:Button({
        Title = "🚫 Pause Terkunci",
        Callback = function()
            if not isPlaying then return WindUI:Notify({Title="Gagal", Content="Tidak ada yang diputar!", Duration=1.5}) end
            
            local data = RecordsDB[selectedRecord]
            if not data then return end

            if not isPaused then
                -- TRIGGER PAUSE
                isPaused = true
                if playConn then playConn:Disconnect() end
                
                local char = lp.Character
                if char and char:FindFirstChildOfClass("Humanoid") then
                    char:FindFirstChildOfClass("Humanoid"):Move(Vector3.zero, false)
                end
                
                PauseBtn:SetTitle("▶️ Resume Playback")
                
                local cpText = ScanCPTimeline(data)
                TimelineInfo:SetDesc("Gunakan slider untuk mencari frame, lalu klik Lanjut Rekam.\n\n" .. cpText)
                FrameInfo:SetDesc("Status: ⏸️ Paused / Editing\nFrame: " .. playbackIndex .. " / " .. #data)
                WindUI:Notify({Title="Paused", Content="Gunakan editor di bawah untuk memotong rekaman.", Duration=2})
            else
                -- TRIGGER RESUME
                isPaused = false
                PauseBtn:SetTitle("⏸️ Pause Playback")
                TimelineInfo:SetDesc("Status: Playback sedang berjalan. Tekan Pause untuk mengedit.")
                WindUI:Notify({Title="Resumed", Content="Melanjutkan pemutaran...", Duration=1.5})
                StartPlaybackLoop(data)
            end
        end
    })

    StopBtn = RecordingTab:Button({
        Title = "🚫 Stop Terkunci",
        Callback = function()
            if not isPlaying and not isPaused then return end
            
            if playConn then playConn:Disconnect() end
            local char = lp.Character
            if char and char:FindFirstChildOfClass("Humanoid") then char:FindFirstChildOfClass("Humanoid"):Move(Vector3.zero, false) end
            
            isPlaying = false
            isPaused = false
            
            FrameInfo:SetDesc("Status: ⏹️ Dihentikan\nTotal Frames: 0")
            PauseBtn:SetTitle("🚫 Pause Terkunci")
            StopBtn:SetTitle("🚫 Stop Terkunci")
            TimelineInfo:SetDesc("Status: Menunggu file di Play & Pause...")
            
            WindUI:Notify({Title="Stop", Content="Pemutaran dihentikan secara paksa.", Duration=1.5})
        end
    })

    RecordingTab:Divider()

    -- ==========================================
    -- UI: 4. EDITOR TIMELINE & CUT
    -- ==========================================
    TimelineInfo = RecordingTab:Paragraph({
        Title = "✂️ Editor Keyframe & Timeline CP",
        Desc = "Status: Menunggu file di Play & Pause...",
        Color = Color3.fromHex("#F89B29")
    })

    TimelineSlider = RecordingTab:Slider({
        Title = "Scrub Timeline (%)",
        Min = 1, Max = 100, Value = 1,
        Callback = function(percent)
            if not isPaused then return end 
            local data = RecordsDB[selectedRecord]
            if not data then return end
            
            playbackIndex = math.floor((percent / 100) * #data)
            if playbackIndex < 1 then playbackIndex = 1 end
            
            local char = lp.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp and data[playbackIndex] then
                hrp.CFrame = data[playbackIndex].cframe
            end
            
            FrameInfo:SetDesc("Status: ⏸️ Preview Frame\nFrame: " .. playbackIndex .. " / " .. #data)
        end
    })

    CutRecordBtn = RecordingTab:Button({
        Title = "✂️ Cut & Lanjut Rekam (Dari Sini)",
        Callback = function()
            if not isPaused then return WindUI:Notify({Title="Gagal", Content="Harus dalam status Pause untuk mengedit!", Duration=2}) end
            
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
            
            PauseBtn:SetTitle("🚫 Pause Terkunci")
            StopBtn:SetTitle("🚫 Stop Terkunci")
            TimelineInfo:SetDesc("Status: Sedang merekam ulang sambungan...")
            
            WindUI:Notify({Title="Cut & Record", Content="Melanjutkan rekaman dari Frame " .. playbackIndex, Duration=2})
            
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

    -- ==========================================
    -- INISIALISASI AKHIR
    -- ==========================================
    LoadAllRecords()
    local initList = {}
    for name, _ in pairs(RecordsDB) do table.insert(initList, name) end
    if #initList == 0 then table.insert(initList, "Kosong") end
    if RecordListDropdown then RecordListDropdown:Refresh(initList) end
end
