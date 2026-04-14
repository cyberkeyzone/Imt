return function(WindUI, TeleportTab)
    local Players = game:GetService("Players")
    local HttpService = game:GetService("HttpService")
    local lp = Players.LocalPlayer
    local currentPlaceId = game.PlaceId

    -- ==========================================
    -- SISTEM PENYIMPANAN PERMANEN (LOKAL)
    -- ==========================================
    local cacheFolderName = "TeleportData" 
    if isfolder and not isfolder(cacheFolderName) then 
        pcall(function() makefolder(cacheFolderName) end) 
    end
    
    local saveFileName = cacheFolderName .. "/" .. tostring(currentPlaceId) .. "_CPs.json"

    local CPCache = {} 
    local CPList = {}  
    local selectedCP = ""
    local CPDropdown
    
    local isAutoLooping = false
    local isAutoSequence = false

    -- FUNGSI SERIALISASI
    local function SerializeCPs()
        local dataToSave = {}
        for name, cf in pairs(CPCache) do
            dataToSave[name] = {cf:GetComponents()}
        end
        return dataToSave
    end

    local function DeserializeCPs(data)
        local loadedData = {}
        for name, comps in pairs(data) do
            loadedData[name] = CFrame.new(unpack(comps))
        end
        return loadedData
    end

    local function SaveCacheToDevice()
        if writefile then
            local data = SerializeCPs()
            pcall(function() writefile(saveFileName, HttpService:JSONEncode(data)) end)
        end
    end

    local function LoadCacheFromDevice()
        if isfile and isfile(saveFileName) then
            local success, result = pcall(function() return readfile(saveFileName) end)
            if success and result then
                local jsonSuccess, jsonData = pcall(function() return HttpService:JSONDecode(result) end)
                if jsonSuccess and type(jsonData) == "table" then
                    CPCache = DeserializeCPs(jsonData)
                    return true
                end
            end
        end
        return false
    end

    -- ==========================================
    -- FUNGSI SMART SORTING
    -- ==========================================
    local function GetCPWeight(name)
        local lowerName = string.lower(name)
        if string.match(lowerName, "spawn") or string.match(lowerName, "base") or string.match(lowerName, "start") or name == "0" or name == "CP 0" then
            return -99999 
        elseif string.match(lowerName, "summit") or string.match(lowerName, "end") or string.match(lowerName, "win") or string.match(lowerName, "finish") then
            return 99999 
        end
        local num = tonumber(string.match(name, "%d+"))
        if num then return num end
        return 0 
    end

    local function UpdateDropdown()
        CPList = {}
        for name, _ in pairs(CPCache) do table.insert(CPList, name) end
        
        table.sort(CPList, function(a, b)
            local weightA = GetCPWeight(a)
            local weightB = GetCPWeight(b)
            if weightA ~= weightB then return weightA < weightB end
            return a < b 
        end)
        
        if #CPList == 0 then table.insert(CPList, "Belum ada CP terdeteksi") end
        if CPDropdown then pcall(function() CPDropdown:Refresh(CPList) end) end
    end

    local function ProcessPart(part)
        if not part:IsA("BasePart") then return end
        
        local parentName = part.Parent and part.Parent.Name or ""
        local partName = part.Name
        local isCP = false
        
        local folders = {"Checkpoints", "Stages", "CheckPoints", "stages", "Spawns"}
        for _, f in ipairs(folders) do
            if parentName == f then isCP = true break end
        end
        
        if string.match(string.lower(partName), "checkpoint") or string.match(string.lower(partName), "stage") then isCP = true end
        if tonumber(partName) and (isCP or parentName == "Workspace") then isCP = true end

        if isCP then
            local cpName = partName
            if tonumber(cpName) then cpName = "CP " .. cpName end
            
            if not CPCache[cpName] then
                CPCache[cpName] = part.CFrame + Vector3.new(0, 3, 0)
                SaveCacheToDevice() 
                UpdateDropdown()
            end
        end
    end

    -- ==========================================
    -- FUNGSI GAIB: KLIK UI RESET CHECKPOINT
    -- ==========================================
    local function AttemptResetCheckpointGameUI()
        -- 1. Scan dan klik Remote Event game (Jika dev gamenya pakai ini)
        for _, v in ipairs(game:GetDescendants()) do
            if v:IsA("RemoteEvent") then
                local name = string.lower(v.Name)
                if string.match(name, "reset") and (string.match(name, "cp") or string.match(name, "check") or string.match(name, "stage")) then
                    pcall(function() v:FireServer() end)
                end
            end
        end

        -- 2. Scan UI di layar HP kamu secara virtual dan Klik Otomatis
        local fireClick = getgenv().firesignal or firesignal
        if fireClick then
            local pg = lp:FindFirstChild("PlayerGui")
            if pg then
                for _, gui in ipairs(pg:GetDescendants()) do
                    if (gui:IsA("TextButton") or gui:IsA("ImageButton")) and gui.Visible then
                        local text = string.lower(gui:IsA("TextButton") and gui.Text or gui.Name)
                        -- Cari tombol berunsur kata reset atau kembali
                        if string.match(text, "reset") or string.match(text, "basecamp") or string.match(text, "restart") then
                            pcall(function() fireClick(gui.MouseButton1Click) end)
                            pcall(function() fireClick(gui.Activated) end)
                        end
                    end
                end
            end
        end
    end

    -- ==========================================
    -- INISIALISASI MESIN (BYPASS & LOAD)
    -- ==========================================
    local isLoaded = LoadCacheFromDevice()
    if isLoaded then
        task.delay(1, function()
            WindUI:Notify({Title="Teleport Data Loaded", Content="Berhasil memuat daftar CP permanen dari game ini!", Duration=3, Icon="check"})
        end)
    end

    task.spawn(function()
        for _, part in ipairs(workspace:GetDescendants()) do pcall(function() ProcessPart(part) end) end
        UpdateDropdown()
    end)

    workspace.DescendantAdded:Connect(function(part) pcall(function() ProcessPart(part) end) end)

    -- ==========================================
    -- UI ELEMENTS (WIND UI)
    -- ==========================================
    TeleportTab:Paragraph({
        Title = "Teleport (Permanent Cache)",
        Desc = "Gunakan Auto Loop Sequence (Smart) untuk pendakian gunung otomatis yang sangat rapi!",
        Color = Color3.fromHex("#F89B29")
    })

    CPDropdown = TeleportTab:Dropdown({
        Title = "📍 Pilih Checkpoint",
        Values = CPList,
        Value = "Pilih CP",
        SearchBarEnabled = true,
        Callback = function(opt)
            selectedCP = type(opt) == "table" and opt.Title or opt
        end
    })

    TeleportTab:Button({
        Title = "⚡ Teleport Manual",
        Callback = function()
            if selectedCP == "" or selectedCP == "Pilih CP" or selectedCP == "Belum ada CP terdeteksi" then
                return WindUI:Notify({Title="Error", Content="Pilih Checkpoint terlebih dahulu!", Duration=2, Icon="x"})
            end

            local char = lp.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            
            if hrp then
                local targetCFrame = CPCache[selectedCP]
                if targetCFrame then
                    pcall(function() lp:RequestStreamAroundAsync(targetCFrame.Position) end)
                    hrp.CFrame = targetCFrame
                    WindUI:Notify({Title="Zhoosh!", Content="Teleport ke " .. selectedCP, Duration=1.5})
                else
                    WindUI:Notify({Title="Error", Content="Data kordinat CP rusak/hilang.", Duration=2})
                end
            else
                WindUI:Notify({Title="Gagal", Content="Karaktermu belum spawn!", Duration=2})
            end
        end
    })

    TeleportTab:Divider()

    -- FITUR 1: AUTO LOOP TELEPORT FARM
    TeleportTab:Toggle({
        Title = "🔁 Auto Loop Teleport (Farm Base -> Summit)",
        Default = false,
        Callback = function(state)
            isAutoLooping = state
            if isAutoLooping and isAutoSequence then isAutoSequence = false end
            
            if isAutoLooping then
                if #CPList < 2 or CPList[1] == "Belum ada CP terdeteksi" then
                    WindUI:Notify({Title="Gagal", Content="Minimal butuh 2 Checkpoint untuk melakukan Auto Loop!", Duration=3, Icon="x"})
                    isAutoLooping = false
                    return
                end
                
                WindUI:Notify({Title="Auto Loop", Content="Memulai farming dari titik Awal ke Akhir (Jeda 5 Detik)...", Duration=2, Icon="check"})
                task.spawn(function()
                    while isAutoLooping do
                        local char = lp.Character
                        local hrp = char and char:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            local firstCFrame = CPCache[CPList[1]]
                            local lastCFrame = CPCache[CPList[#CPList]]
                            
                            if firstCFrame and lastCFrame then
                                AttemptResetCheckpointGameUI() -- Coba klik reset UI
                                pcall(function() lp:RequestStreamAroundAsync(firstCFrame.Position) end)
                                hrp.CFrame = firstCFrame
                                task.wait(5)
                                if not isAutoLooping then break end
                                pcall(function() lp:RequestStreamAroundAsync(lastCFrame.Position) end)
                                hrp.CFrame = lastCFrame
                                task.wait(5)
                            else task.wait(0.5) end
                        else task.wait(1) end
                    end
                end)
            else
                WindUI:Notify({Title="Berhenti", Content="Auto Loop Farm dimatikan.", Duration=1.5})
            end
        end
    })

    -- FITUR 2: AUTO LOOP SEQUENCE (SMART RESUME & AUTO RESET)
    TeleportTab:Toggle({
        Title = "▶️ Auto Loop Sequence (Smart Resume)",
        Default = false,
        Callback = function(state)
            isAutoSequence = state
            if isAutoSequence and isAutoLooping then isAutoLooping = false end

            if isAutoSequence then
                if #CPList < 2 or CPList[1] == "Belum ada CP terdeteksi" then
                    WindUI:Notify({Title="Gagal", Content="Minimal butuh 2 Checkpoint untuk melakukan Sequence!", Duration=3, Icon="x"})
                    isAutoSequence = false
                    return
                end
                
                local char = lp.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                
                -- ==========================================
                -- ALGORITMA SMART RESUME (CARI POSISI SAAT INI)
                -- ==========================================
                local startIndex = 1
                if hrp then
                    local minDis = math.huge
                    for i, cpName in ipairs(CPList) do
                        local cpCFrame = CPCache[cpName]
                        if cpCFrame then
                            local dist = (hrp.Position - cpCFrame.Position).Magnitude
                            if dist < minDis then
                                minDis = dist
                                startIndex = i
                            end
                        end
                    end
                end
                
                WindUI:Notify({Title="Sequence", Content="Melanjutkan otomatis dari " .. CPList[startIndex] .. "!", Duration=3, Icon="check"})
                
                task.spawn(function()
                    local currentIndex = startIndex
                    
                    while isAutoSequence do
                        for i = currentIndex, #CPList do
                            if not isAutoSequence then break end
                            
                            local cChar = lp.Character
                            local cHrp = cChar and cChar:FindFirstChild("HumanoidRootPart")
                            
                            if cHrp then
                                -- JIKA BERADA DI BASE (Index 1) -> TRIGGER AUTO RESET
                                if i == 1 then
                                    AttemptResetCheckpointGameUI()
                                    task.wait(0.5) -- Beri waktu sistem UI memproses reset
                                end

                                local targetCFrame = CPCache[CPList[i]]
                                if targetCFrame then
                                    pcall(function() lp:RequestStreamAroundAsync(targetCFrame.Position) end)
                                    cHrp.AssemblyLinearVelocity = Vector3.zero
                                    cHrp.CFrame = targetCFrame
                                    task.wait(0.3) -- Jeda emas 0.3 dtk agar game mendeteksi sentuhan
                                end
                            else
                                task.wait(1) 
                            end
                        end
                        
                        -- Jika selesai sampai ujung (Summit), Reset ke 1 untuk loop kembali
                        currentIndex = 1
                        if isAutoSequence then task.wait(1) end
                    end
                end)
            else
                WindUI:Notify({Title="Berhenti", Content="Auto Loop Sequence dimatikan.", Duration=1.5})
            end
        end
    })

    TeleportTab:Divider()

    TeleportTab:Button({
        Title = "🗑️ Hapus Data CP Permanen",
        Callback = function()
            if isfile and isfile(saveFileName) then
                pcall(function() delfile(saveFileName) end)
                CPCache = {}
                UpdateDropdown()
                WindUI:Notify({Title="Terhapus", Content="Semua data Checkpoint untuk map ini telah di-reset.", Duration=2})
            else
                WindUI:Notify({Title="Info", Content="Tidak ada data tersimpan untuk map ini.", Duration=2})
            end
        end
    })
end
