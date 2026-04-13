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
    
    -- Nama file unik untuk setiap game/map
    local saveFileName = cacheFolderName .. "/" .. tostring(currentPlaceId) .. "_CPs.json"

    local CPCache = {} 
    local CPList = {}  
    local selectedCP = ""
    local CPDropdown

    -- FUNGSI SERIALISASI (Mengubah CFrame jadi teks untuk disimpan)
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

    -- FUNGSI SAVE & LOAD
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
    -- FUNGSI UPDATE UI & DETEKSI OTOMATIS
    -- ==========================================
    local function UpdateDropdown()
        CPList = {}
        for name, _ in pairs(CPCache) do
            table.insert(CPList, name)
        end
        
        -- Mengurutkan nama CP agar rapi (CP 1, CP 2, CP 10, dst)
        table.sort(CPList, function(a, b)
            local numA = tonumber(string.match(a, "%d+"))
            local numB = tonumber(string.match(b, "%d+"))
            if numA and numB then return numA < numB end
            return a < b
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
            
            -- Jika CP BARU ditemukan, masukkan ke cache lalu SIMPAN PERMANEN
            if not CPCache[cpName] then
                CPCache[cpName] = part.CFrame + Vector3.new(0, 3, 0)
                SaveCacheToDevice() -- Menyimpan secara diam-diam ke HP
                UpdateDropdown()
            end
        end
    end

    -- ==========================================
    -- INISIALISASI MESIN (BYPASS & LOAD)
    -- ==========================================
    -- 1. Coba muat memori masa lalu dari penyimpanan HP
    local isLoaded = LoadCacheFromDevice()
    if isLoaded then
        task.delay(1, function()
            WindUI:Notify({Title="Teleport Data Loaded", Content="Berhasil memuat daftar CP permanen dari game ini!", Duration=3, Icon="check"})
        end)
    end

    -- 2. Deep Scan map yang ada saat ini
    task.spawn(function()
        for _, part in ipairs(workspace:GetDescendants()) do
            pcall(function() ProcessPart(part) end)
        end
        UpdateDropdown()
    end)

    -- 3. Auto-Hook (Menangkap CP baru saat kita berjalan mengeksplorasi map)
    workspace.DescendantAdded:Connect(function(part)
        pcall(function() ProcessPart(part) end)
    end)

    -- ==========================================
    -- UI ELEMENTS (WIND UI)
    -- ==========================================
    TeleportTab:Paragraph({
        Title = "Teleport (Permanent Cache)",
        Desc = "Setiap Checkpoint yang pernah terdeteksi akan disimpan secara permanen di HP kamu. Saat keluar masuk game, data CP tidak akan hilang!",
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

    TeleportTab:Divider()

    TeleportTab:Button({
        Title = "⚡ Teleport ke Checkpoint",
        Callback = function()
            if selectedCP == "" or selectedCP == "Pilih CP" or selectedCP == "Belum ada CP terdeteksi" then
                return WindUI:Notify({Title="Error", Content="Pilih Checkpoint terlebih dahulu!", Duration=2, Icon="x"})
            end

            local char = lp.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            
            if hrp then
                local targetCFrame = CPCache[selectedCP]
                if targetCFrame then
                    -- Bypass StreamingEnabled: Paksa server memuat map tujuan
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
