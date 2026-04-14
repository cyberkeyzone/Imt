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
    
    local isAutoLooping = false -- State untuk Auto Farm (Base -> Summit)
    local isAutoSequence = false -- State untuk Auto Sequence (Urut 1 per 1)

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
    -- FUNGSI SMART SORTING & UPDATE UI
    -- ==========================================
    -- Algoritma untuk memastikan Base selalu di atas dan Summit selalu di bawah
    local function GetCPWeight(name)
        local lowerName = string.lower(name)
        if string.match(lowerName, "spawn") or string.match(lowerName, "base") or string.match(lowerName, "start") or name == "0" or name == "CP 0" then
            return -99999 -- Bobot terkecil, pasti paling atas
        elseif string.match(lowerName, "summit") or string.match(lowerName, "end") or string.match(lowerName, "win") or string.match(lowerName, "finish") then
            return 99999 -- Bobot terbesar, pasti paling bawah
        end

        local num = tonumber(string.match(name, "%d+"))
        if num then return num end

        return 0 
    end

    local function UpdateDropdown()
        CPList = {}
        for name, _ in pairs(CPCache) do
            table.insert(CPList, name)
        end
        
        -- Mengurutkan nama CP menggunakan Smart Sorting
        table.sort(CPList, function(a, b)
            local weightA = GetCPWeight(a)
            local weightB = GetCPWeight(b)

            if weightA ~= weightB then
                return weightA < weightB
            end
            return a < b -- Jika bobot sama, urutkan sesuai abjad
        end)
        
        if #CPList == 0 then table.insert(CPList, "Belum ada CP terdeteksi") end
        
        if CPDropdown then
            pcall(function() CPDropdown:Refresh(CPList) end)
        end
    end

    -- Fungsi Intelijen untuk mendeteksi CP baru
    local function ProcessPart(part)
        if not part:IsA("BasePart") then return end
        
        local parentName = part.Parent and part.Parent.Name or ""
        local partName = part.Name
        local isCP = false
        
        -- Deteksi folder
        local folders = {"Checkpoints", "Stages", "CheckPoints", "stages", "Spawns"}
        for _, f in ipairs(folders) do
            if parentName == f then isCP = true break end
        end
        
        -- Deteksi nama part
        if string.match(string.lower(partName), "checkpoint") or string.match(string.lower(partName), "stage") then
            isCP = true
        end
        
        -- Deteksi angka
        if tonumber(partName) and (isCP or parentName == "Workspace") then
            isCP = true
        end

        if isCP then
            local cpName = partName
            if tonumber(cpName) then cpName = "CP " .. cpName end
            
            if not CPCache[cpName] then
                -- Menyimpan posisi 3 stud di atas CP agar karakter jatuh dan menyentuh pad (Memicu event Touched)
                CPCache[cpName] = part.CFrame + Vector3.new(0, 3, 0)
                SaveCacheToDevice() 
                UpdateDropdown()
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
        for _, part in ipairs(workspace:GetDescendants()) do
            pcall(function() ProcessPart(part) end)
        end
        UpdateDropdown()
    end)

    workspace.DescendantAdded:Connect(function(part)
        pcall(function() ProcessPart(part) end)
    end)

    -- ==========================================
    -- UI ELEMENTS (WIND UI)
    -- ==========================================
    TeleportTab:Paragraph({
        Title = "Teleport (Permanent Cache)",
        Desc = "Checkpoint disimpan otomatis secara permanen. Gunakan fitur Loop untuk farming otomatis!",
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

    -- FITUR 1: AUTO LOOP TELEPORT FARM (Base -> Summit)
    TeleportTab:Toggle({
        Title = "🔁 Auto Loop Teleport (Farm Base -> Summit)",
        Default = false,
        Callback = function(state)
            isAutoLooping = state
            
            -- Matikan Sequence jika dinyalakan bersamaan
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
                            local firstCPName = CPList[1]
                            local lastCPName = CPList[#CPList]
                            
                            local firstCFrame = CPCache[firstCPName]
                            local lastCFrame = CPCache[lastCPName]
                            
                            if firstCFrame and lastCFrame then
                                pcall(function() lp:RequestStreamAroundAsync(firstCFrame.Position) end)
                                hrp.CFrame = firstCFrame
                                task.wait(5)
                                
                                if not isAutoLooping then break end
                                
                                pcall(function() lp:RequestStreamAroundAsync(lastCFrame.Position) end)
                                hrp.CFrame = lastCFrame
                                task.wait(5)
                            else
                                task.wait(0.5)
                            end
                        else
                            task.wait(1) 
                        end
                    end
                end)
            else
                WindUI:Notify({Title="Berhenti", Content="Auto Loop Farm dimatikan.", Duration=1.5})
            end
        end
    })

    -- FITUR 2: AUTO LOOP SEQUENCE (Berurutan 1 per 1 dengan Cepat)
    TeleportTab:Toggle({
        Title = "▶️ Auto Loop Sequence (Teleport Berurutan)",
        Default = false,
        Callback = function(state)
            isAutoSequence = state
            
            -- Matikan Farm jika dinyalakan bersamaan
            if isAutoSequence and isAutoLooping then isAutoLooping = false end

            if isAutoSequence then
                if #CPList < 2 or CPList[1] == "Belum ada CP terdeteksi" then
                    WindUI:Notify({Title="Gagal", Content="Minimal butuh 2 Checkpoint untuk melakukan Sequence!", Duration=3, Icon="x"})
                    isAutoSequence = false
                    return
                end
                
                WindUI:Notify({Title="Sequence", Content="Melaju berurutan dari Base ke Summit!", Duration=2, Icon="check"})
                
                task.spawn(function()
                    while isAutoSequence do
                        for i = 1, #CPList do
                            if not isAutoSequence then break end
                            
                            local char = lp.Character
                            local hrp = char and char:FindFirstChild("HumanoidRootPart")
                            
                            if hrp then
                                local cpName = CPList[i]
                                local targetCFrame = CPCache[cpName]
                                
                                if targetCFrame then
                                    -- Paksa server merender map
                                    pcall(function() lp:RequestStreamAroundAsync(targetCFrame.Position) end)
                                    
                                    -- Set CFrame dan Hentikan Momentum (Agar tidak terlempar)
                                    hrp.AssemblyLinearVelocity = Vector3.zero
                                    hrp.CFrame = targetCFrame
                                    
                                    -- JEDA 0.3 DETIK: Ini SANGAT PENTING. 
                                    -- Memberi waktu karakter jatuh menyentuh CP dan mesin physics Roblox memicu notifikasi.
                                    task.wait(0.3)
                                end
                            else
                                task.wait(1) -- Jika karakter mati, tunggu 1 detik
                            end
                        end
                        
                        -- Jika sudah sampai Summit, tunggu 1 detik sebelum mulai lagi dari Base
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
