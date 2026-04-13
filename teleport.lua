return function(WindUI, TeleportTab)
    local Players = game:GetService("Players")
    local lp = Players.LocalPlayer

    -- ==========================================
    -- DATABASE CACHE (AUTO-INTERCEPTOR)
    -- ==========================================
    local CPCache = {} 
    local CPList = {}  
    local selectedCP = ""
    local CPDropdown

    -- Fungsi untuk mengupdate UI Dropdown tanpa perlu klik apapun
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

    -- Fungsi Intelijen untuk mendeteksi apakah objek itu Checkpoint
    local function ProcessPart(part)
        if not part:IsA("BasePart") then return end
        
        local parentName = part.Parent and part.Parent.Name or ""
        local partName = part.Name
        local isCP = false
        
        -- Deteksi dari nama folder induk
        local folders = {"Checkpoints", "Stages", "CheckPoints", "stages", "Spawns"}
        for _, f in ipairs(folders) do
            if parentName == f then isCP = true break end
        end
        
        -- Deteksi dari nama part-nya langsung
        if string.match(string.lower(partName), "checkpoint") or string.match(string.lower(partName), "stage") then
            isCP = true
        end
        
        -- Deteksi jika dev gamenya malas (cuma namain part dengan angka 1, 2, 3)
        if tonumber(partName) and (isCP or parentName == "Workspace") then
            isCP = true
        end

        if isCP then
            local cpName = partName
            if tonumber(cpName) then cpName = "CP " .. cpName end
            
            -- Jika CP baru ditemukan, simpan diam-diam dan update UI
            if not CPCache[cpName] then
                CPCache[cpName] = part.CFrame + Vector3.new(0, 3, 0)
                UpdateDropdown()
            end
        end
    end

    -- ==========================================
    -- BYPASS STREAMING ENABLED ENGINE
    -- ==========================================
    -- 1. Deep Scan: Scan seluruh area yang sudah dirender saat ini
    for _, part in ipairs(workspace:GetDescendants()) do
        pcall(function() ProcessPart(part) end)
    end

    -- 2. Auto-Hook: Menangkap Checkpoint yang baru saja dikirim server tanpa henti
    workspace.DescendantAdded:Connect(function(part)
        pcall(function() ProcessPart(part) end)
    end)

    -- ==========================================
    -- UI ELEMENTS (WIND UI)
    -- ==========================================
    TeleportTab:Paragraph({
        Title = "Teleport (Auto-Bypass Stream)",
        Desc = "Sistem secara otomatis menangkap koordinat Checkpoint di belakang layar seiring kamu bergerak. Daftar akan bertambah sendiri tanpa perlu Refresh!",
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
                    -- Memaksa server merender map tempat kita akan mendarat
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
end
