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
    local recConn = nil
    local playConn = nil
    local selectedRecord = "Kosong"
    local customRecordName = "" 

    local FrameInfo 
    local PlayBtn
    local DelBtn
    local RecordListDropdown -- Dibuat lokal agar lebih aman

    local folderName = "Recording"
    if isfolder and not isfolder(folderName) then
        makefolder(folderName)
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
            local success, err = pcall(function()
                writefile(fileName, HttpService:JSONEncode(SerializeData(framesData)))
            end)
            if not success then warn("Gagal save JSON: ", err) end
        end
    end

    local function DeleteRecordFile(recordName)
        if delfile then
            local fileName = folderName .. "/" .. recordName .. ".json"
            if isfile(fileName) then
                pcall(function() delfile(fileName) end)
            end
        end
    end

    local function LoadAllRecords()
        RecordsDB = {}
        if listfiles and isfolder(folderName) then
            local files = listfiles(folderName)
            for _, filePath in ipairs(files) do
                if filePath:match("%.json$") then
                    local fileNameWithExt = filePath:match("([^/\\]+)$")
                    local recordName = fileNameWithExt:gsub("%.json$", "")
                    
                    local success, res = pcall(function()
                        return DeserializeData(HttpService:JSONDecode(readfile(filePath)))
                    end)
                    if success and res then
                        RecordsDB[recordName] = res
                    end
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
    -- UI ELEMENTS RECORDING
    -- ==========================================
    local lockStatus = isUnlocked and "✅ Terbuka (Akses myzzkey)" or "🔒 Terkunci (Bukan myzzkey)"
    FrameInfo = RecordingTab:Paragraph({
        Title = "Deteksi Time Frames",
        Desc = "Status: " .. lockStatus .. "\nTotal Frames: 0",
        Image = "clock",
        Color = Color3.fromHex("#0F7BFF")
    })

    RecordingTab:Paragraph({
        Title = "📁 Folder Penyimpanan Keyframe",
        Desc = "Lokasi: storage/emulated/0/Android/data/com.roblox.client/workspace/Recording/\nSetiap record akan disimpan sebagai file terpisah (.json).",
        Color = Color3.fromHex("#29F89B")
    })

    RecordingTab:Input({
        Title = "Nama Custom Save Record",
        Placeholder = "Nama file (Kosongkan utk Auto Record_01.json)",
        Callback = function(text)
            customRecordName = text
        end
    })

    RecordListDropdown = RecordingTab:Dropdown({
        Title = "List File Record (Folder Recording)",
        Values = {"Kosong"},
        Value = "Kosong",
        SearchBarEnabled = true,
        Callback = function(opt)
            selectedRecord = type(opt) == "table" and opt.Title or opt
            
            local isValid = (selectedRecord ~= "Kosong" and selectedRecord ~= nil)
            if PlayBtn and DelBtn then
                pcall(function() PlayBtn.Instance.Visible = isValid end)
                pcall(function() DelBtn.Instance.Visible = isValid end)
                if isValid then
                    PlayBtn:SetTitle("Play File (".. selectedRecord .. ".json)")
                    DelBtn:SetTitle("Hapus File (".. selectedRecord .. ".json)")
                else
                    PlayBtn:SetTitle("🚫 Pilih List (Play Terkunci)")
                    DelBtn:SetTitle("🚫 Pilih List (Hapus Terkunci)")
                end
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

    RecordingTab:Button({
        Title = "Mulai / Stop Record",
        Icon = "video",
        Callback = function()
            if not isUnlocked then return WindUI:Notify({Title="Akses Ditolak", Content="Hanya myzzkey yang dapat merekam!", Duration=2, Icon="lock"}) end
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
                    
                    UpdateRecordList()
                    WindUI:Notify({Title="Disimpan", Content="Tersimpan: " .. recName .. ".json", Duration=2, Icon="save"})
                    FrameInfo:SetDesc("Status: ✅ Selesai merekam\nTotal Frames: " .. #currentRecordingFrames)
                else
                    WindUI:Notify({Title="Gagal", Content="Frame kosong!", Duration=2})
                    FrameInfo:SetDesc("Status: ✅ Terbuka (Idle)\nTotal Frames: 0")
                end
            end
        end
    })

    PlayBtn = RecordingTab:Button({
        Title = "🚫 Pilih List (Play Terkunci)",
        Icon = "play-circle",
        Callback = function()
            if not isUnlocked then return WindUI:Notify({Title="Akses Ditolak", Content="Hanya myzzkey yang dapat memutar!", Duration=2, Icon="lock"}) end
            if selectedRecord == "Kosong" then return end 
            if isRecording or isPlaying then return WindUI:Notify({Title="Error", Content="Tidak bisa play saat ini!", Duration=2}) end

            local data = RecordsDB[selectedRecord]
            if not data then return WindUI:Notify({Title="Error", Content="Data file tidak valid!", Duration=2}) end

            isPlaying = true
            local index = 1
            WindUI:Notify({Title="Memutar", Content="Membaca file: " .. selectedRecord .. ".json", Duration=1.5, Icon="play"})

            playConn = RunService.Heartbeat:Connect(function()
                local char = lp.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChildOfClass("Humanoid") 

                if hrp and hum and data[index] then
                    local currentData = data[index]
                    local nextData = data[index + 1]
                    
                    hrp.CFrame = currentData.cframe
                    hrp.AssemblyLinearVelocity = currentData.vel

                    if hum:GetState() ~= currentData.state then
                        hum:ChangeState(currentData.state)
                    end
                    
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

                    FrameInfo:SetDesc("Status: ▶️ Memutar File (".. selectedRecord ..")\nFrame: " .. index .. " / " .. #data)
                    index = index + 1
                else
                    if playConn then playConn:Disconnect() end
                    if hum then 
                        hum:Move(Vector3.zero, false) 
                        hum:ChangeState(Enum.HumanoidStateType.Running)
                    end 
                    if hrp then hrp.AssemblyLinearVelocity = Vector3.zero end
                    isPlaying = false
                    FrameInfo:SetDesc("Status: ✅ Selesai memutar\nTotal Frames: " .. #data)
                    WindUI:Notify({Title="Selesai", Content="Playback file selesai!", Duration=1.5, Icon="check"})
                end
            end)
        end
    })

    DelBtn = RecordingTab:Button({
        Title = "🚫 Pilih List (Hapus Terkunci)",
        Icon = "trash",
        Callback = function()
            if not isUnlocked then return WindUI:Notify({Title="Akses Ditolak", Content="Hanya myzzkey yang dapat menghapus!", Duration=2, Icon="lock"}) end
            if selectedRecord == "Kosong" then return end 

            if RecordsDB[selectedRecord] then
                RecordsDB[selectedRecord] = nil
                DeleteRecordFile(selectedRecord) 
                UpdateRecordList()
                WindUI:Notify({Title="File Dihapus", Content=selectedRecord .. ".json dihapus dari perangkat", Duration=1.5, Icon="trash"})
                FrameInfo:SetDesc("Status: ✅ Terbuka (Idle)\nTotal Frames: 0")
                selectedRecord = "Kosong"
                
                pcall(function() PlayBtn.Instance.Visible = false end)
                pcall(function() DelBtn.Instance.Visible = false end)
                PlayBtn:SetTitle("🚫 Pilih List (Play Terkunci)")
                DelBtn:SetTitle("🚫 Pilih List (Hapus Terkunci)")
            end
        end
    })

    LoadAllRecords()
    UpdateRecordList()

    pcall(function() PlayBtn.Instance.Visible = false end)
    pcall(function() DelBtn.Instance.Visible = false end)
end
