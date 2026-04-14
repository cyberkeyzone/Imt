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
    local isStealthMode = false
    local isAdd50kSummit = false -- State Injector 50k

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
    -- FUNGSI GAIB: INJECTOR 50K SUMMIT WINS
    -- ==========================================
    local function AttemptInject50k(finalCFrame)
        local fireTouch = (typeof(firetouchinterest) == "function" and firetouchinterest) or (getgenv and getgenv().firetouchinterest)
        local finalPart = nil
        
        -- Cari part asli dari CFrame (dikurangi 3 stud karena sebelumnya kita simpan +3 ke atas)
        local searchPos = finalCFrame.Position - Vector3.new(0, 3, 0)
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA("BasePart") then
                if (v.Position - searchPos).Magnitude < 10 then
                    finalPart = v
                    break
                end
            end
        end

        WindUI:Notify({Title="Menyuntik...", Content="Sedang mengeksekusi 50.000 klaim Summit. Jangan keluar...", Duration=3})
        
        -- Cari RemoteEvent tersembunyi di sekitar part akhir (biasanya untuk ngasih reward)
        local remotes = {}
        if finalPart and finalPart.Parent then
            for _, r in ipairs(finalPart.Parent:GetDescendants()) do
                if r:IsA("RemoteEvent") then table.insert(remotes, r) end
            end
        end
        -- Cari juga di ReplicatedStorage (Penyimpanan global server)
        for _, r in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
            if r:IsA("RemoteEvent") then
                local rn = string.lower(r.Name)
                if string.match(rn, "win") or string.match(rn, "summit") or string.match(rn, "reward") or string.match(rn, "finish") then
                    table.insert(remotes, r)
                end
            end
        end

        local char = lp.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        
        if hrp then
            -- LOOP INJEKSI: 50.000 KALI
            for i = 1, 50000 do
                if not isAdd50kSummit then break end -- Bisa dibatalkan jika toggle dimatikan
                
                -- Metode 1: Spam Sentuhan (Menipu Script Server "Touched" Event)
                if finalPart and fireTouch then
                    pcall(function()
                        fireTouch(hrp, finalPart, 0) -- Mulai Sentuh
                        fireTouch(hrp, finalPart, 1) -- Lepas Sentuhan
                    end)
                end
                
                -- Metode 2: Spam Sinyal Remote Server
                for _, r in ipairs(remotes) do
                    pcall(function() r:FireServer() end)
                end
                
                -- Anti-Crash Client: Jeda sangat singkat setiap 500 klaim agar HP kamu tidak meledak/lag
                if i % 500 == 0 then
                    task.wait() 
                end
            end
            WindUI:Notify({Title="Sukses 💉", Content="Suntikan 50.000 Summit/Wins telah ditambahkan!", Duration=4, Icon="check"})
        end
    end

    -- ==========================================
    -- FUNGSI GAIB: MULTI-STAGE UI CLICKER
    -- ==========================================
    local function AttemptResetCheckpointGameUI()
        for _, v in ipairs(game:GetDescendants()) do
            if v:IsA("RemoteEvent") then
                local name = string.lower(v.Name)
                if string.match(name, "reset") and (string.match(name, "cp") or string.match(name, "check") or string.match(name, "stage")) then
                    pcall(function() v:FireServer() end)
                end
            end
        end

        local fireClick = getgenv().firesignal or firesignal
        local pg = lp:FindFirstChild("PlayerGui")
        
        if fireClick and pg then
            local function scanAndClick(keywords)
                local clicked = false
                for _, gui in ipairs(pg:GetDescendants()) do
                    if (gui:IsA("TextButton") or gui:IsA("ImageButton")) and gui.Visible then
                        local text = string.lower(gui:IsA("TextButton") and gui.Text or gui.Name)
                        for _, kw in ipairs(keywords) do
                            if string.match(text, kw) then
                                pcall(function() fireClick(gui.MouseButton1Click) end)
                                pcall(function() fireClick(gui.Activated) end)
                                clicked = true
                            end
                        end
                    end
                end
                return clicked
            end

            local clickedReset = scanAndClick({"reset", "basecamp", "restart"})
            if clickedReset then
                task.wait(0.8) 
                scanAndClick({"yes", "confirm", "ya", "ok", "setuju", "sure", "accept"})
                task.wait(1) 
            end
        end
    end

    -- ==========================================
    -- FUNGSI RADAR STEALTH
    -- ==========================================
    local function IsPlayerNear(targetPosition)
        local safeRadius = 150 
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= lp and p.Character then
                local pRoot = p.Character:FindFirstChild("HumanoidRootPart")
                local pHealth = p.Character:FindFirstChild("Humanoid")
                if pRoot and pHealth and pHealth.Health > 0 then
                    local dist = (pRoot.Position - targetPosition).Magnitude
                    if dist <= safeRadius then
                        return true, p.Name
                    end
                end
            end
        end
        return false, ""
    end

    local function SafeRequestStream(pos)
        task.spawn(function()
            pcall(function() lp:RequestStreamAroundAsync(pos) end)
        end)
    end

    -- ==========================================
    -- INISIALISASI MESIN
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
        Desc = "Dilengkapi Smart Logic V2, Stealth Mode, dan Injector 50.000 Wins!",
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
                    if isStealthMode then
                        local isNear, pName = IsPlayerNear(targetCFrame.Position)
                        if isNear then
                            return WindUI:Notify({Title="Bahaya!", Content="Ada player ("..pName..") di tujuan! Batal demi keamanan.", Duration=3, Icon="x"})
                        end
                    end
                    SafeRequestStream(targetCFrame.Position)
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

    -- TOGGLE STEALTH MODE
    TeleportTab:Toggle({
        Title = "🕵️ Stealth Mode (Anti-Terlihat)",
        Default = false,
        Callback = function(state)
            isStealthMode = state
        end
    })

    -- TOGGLE INJECTOR 50K WINS
    TeleportTab:Toggle({
        Title = "💉 Auto Inject 50k Summit",
        Default = false,
        Callback = function(state)
            isAdd50kSummit = state
            if isAdd50kSummit then
                WindUI:Notify({Title="Injector Aktif", Content="Akan menyuntik 50.000 Wins otomatis setiap mencapai Summit!", Duration=3, Icon="check"})
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
                    isAutoLooping = false
                    return
                end
                
                WindUI:Notify({Title="Auto Loop", Content="Memulai farming...", Duration=2, Icon="check"})
                
                task.spawn(function()
                    local lastNotifyTime = 0
                    local hasResetBase = false
                    
                    while isAutoLooping do
                        local char = lp.Character
                        local hrp = char and char:FindFirstChild("HumanoidRootPart")
                        local hum = char and char:FindFirstChild("Humanoid")
                        
                        if hrp and hum and hum.Health > 0 then
                            local firstCFrame = CPCache[CPList[1]]
                            local lastCFrame = CPCache[CPList[#CPList]]
                            
                            if firstCFrame and lastCFrame then
                                -- BASE
                                if not hasResetBase then
                                    AttemptResetCheckpointGameUI() 
                                    hasResetBase = true
                                end
                                
                                SafeRequestStream(firstCFrame.Position)
                                hrp.CFrame = firstCFrame
                                task.wait(5)
                                if not isAutoLooping then break end
                                
                                -- STEALTH
                                if isStealthMode then
                                    local isNear, pName = IsPlayerNear(lastCFrame.Position)
                                    if isNear then
                                        if os.clock() - lastNotifyTime > 4 then
                                            WindUI:Notify({Title="Stealth", Content="Sembunyi dari " .. pName .. "...", Duration=2})
                                            lastNotifyTime = os.clock()
                                        end
                                        task.wait(2) 
                                        continue 
                                    end
                                end

                                -- SUMMIT
                                SafeRequestStream(lastCFrame.Position)
                                hrp.CFrame = lastCFrame
                                hasResetBase = false 
                                task.wait(1) -- Beri waktu sedikit sebelum injeksi

                                -- INJEKSI 50K WINS
                                if isAdd50kSummit then
                                    AttemptInject50k(lastCFrame)
                                else
                                    task.wait(4)
                                end
                            else 
                                task.wait(0.5) 
                            end
                        else 
                            task.wait(1.5) 
                        end
                    end
                end)
            end
        end
    })

    -- FITUR 2: AUTO LOOP SEQUENCE
    TeleportTab:Toggle({
        Title = "▶️ Auto Loop Sequence (Smart + Stealth)",
        Default = false,
        Callback = function(state)
            isAutoSequence = state
            if isAutoSequence and isAutoLooping then isAutoLooping = false end

            if isAutoSequence then
                if #CPList < 2 or CPList[1] == "Belum ada CP terdeteksi" then
                    isAutoSequence = false
                    return
                end
                
                local char = lp.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
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
                
                WindUI:Notify({Title="Sequence", Content="Melanjutkan dari " .. CPList[startIndex] .. "!", Duration=3, Icon="check"})
                
                task.spawn(function()
                    local currentIndex = startIndex
                    local hasResetThisLap = false
                    local lastNotifyTime = 0
                    
                    while isAutoSequence do
                        if currentIndex > #CPList then
                            currentIndex = 1
                            hasResetThisLap = false
                            task.wait(1)
                        end

                        local cpName = CPList[currentIndex]
                        local targetCFrame = CPCache[cpName]

                        local cChar = lp.Character
                        local cHrp = cChar and cChar:FindFirstChild("HumanoidRootPart")
                        local cHum = cChar and cChar:FindFirstChild("Humanoid")
                        
                        if cHrp and cHum and cHum.Health > 0 and targetCFrame then
                            
                            -- JIKA DI BASE
                            if currentIndex == 1 and not hasResetThisLap then
                                AttemptResetCheckpointGameUI()
                                hasResetThisLap = true
                            end

                            -- STEALTH
                            if isStealthMode then
                                local isNear, pName = IsPlayerNear(targetCFrame.Position)
                                if isNear then
                                    if os.clock() - lastNotifyTime > 4 then
                                        WindUI:Notify({Title="Stealth", Content="Sembunyi, menghindari " .. pName, Duration=1.5})
                                        lastNotifyTime = os.clock()
                                    end
                                    task.wait(2)
                                    continue 
                                end
                            end

                            -- TELEPORT
                            SafeRequestStream(targetCFrame.Position)
                            cHrp.AssemblyLinearVelocity = Vector3.zero
                            cHrp.CFrame = targetCFrame
                            task.wait(0.4) 

                            -- JIKA MENCAPAI SUMMIT (CP TERAKHIR) & INJEKSI AKTIF
                            if currentIndex == #CPList and isAdd50kSummit then
                                AttemptInject50k(targetCFrame)
                            end

                            currentIndex = currentIndex + 1
                        else
                            task.wait(1.5) 
                        end
                    end
                end)
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
                WindUI:Notify({Title="Terhapus", Content="Semua data Checkpoint telah di-reset.", Duration=2})
            else
                WindUI:Notify({Title="Info", Content="Tidak ada data tersimpan.", Duration=2})
            end
        end
    })
end
