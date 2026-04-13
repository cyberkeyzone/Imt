return function(WindUI, TeleportTab)
    local Players = game:GetService("Players")
    local lp = Players.LocalPlayer
    local GetPlayerList = loadstring(game:HttpGet("https://raw.githubusercontent.com/cyberkeyzone/Imt/refs/heads/main/getplayerlist.lua"))().GetPlayerList

    TeleportTab:Paragraph({
        Title = "Navigasi Server",
        Desc = "Teleport ke pemain lain atau lompat antar Checkpoint/Stage.",
        Color = Color3.fromHex("#0F7BFF")
    })

    -- Bagian Teleport Player
    local selectedTargetPlayer = ""
    local PlayerDropdown = TeleportTab:Dropdown({
        Title = "Dari Player (Daftar Pemain)",
        Values = GetPlayerList(),
        Value = "Pilih Pemain",
        SearchBarEnabled = true,
        Callback = function(opt)
            selectedTargetPlayer = type(opt) == "table" and opt.Title or opt
        end
    })

    TeleportTab:Button({
        Title = "Refresh Daftar Pemain",
        Icon = "refresh-cw",
        Callback = function()
            PlayerDropdown:Refresh(GetPlayerList())
            WindUI:Notify({Title="Refresh", Content="Daftar pemain diperbarui", Duration=1})
        end
    })

    TeleportTab:Button({
        Title = "Teleport ke Pemain",
        Icon = "navigation",
        Callback = function()
            if selectedTargetPlayer == "" or selectedTargetPlayer == "Pilih Pemain" then return WindUI:Notify({Title="Error", Content="Pilih pemain terlebih dahulu!"}) end
            
            local targetName = string.match(selectedTargetPlayer, "@([^%)]+)") or selectedTargetPlayer
            local targetPlr = Players:FindFirstChild(targetName)
            
            if targetPlr and targetPlr.Character and targetPlr.Character:FindFirstChild("HumanoidRootPart") and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
                lp.Character.HumanoidRootPart.CFrame = targetPlr.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3) 
                WindUI:Notify({Title="Teleportasi", Content="Berhasil TP ke " .. targetName, Duration=1.5, Icon="check"})
            else
                WindUI:Notify({Title="Gagal", Content="Karakter pemain tidak ditemukan!", Duration=2})
            end
        end
    })

    TeleportTab:Divider()

    -- Bagian Teleport Checkpoint/Stage
    local CheckpointMap = {}
    local selectedCheckpoint = ""

    local function ScanCheckpoints()
        CheckpointMap = {}
        local list = {}
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("SpawnLocation") then
                local uidName = string.format("Spawn: %s [%d, %d]", obj.Name, math.floor(obj.Position.X), math.floor(obj.Position.Z))
                CheckpointMap[uidName] = obj.CFrame
                table.insert(list, uidName)
            elseif obj:IsA("BasePart") then
                local nameLower = obj.Name:lower()
                local parentLower = obj.Parent and obj.Parent.Name:lower() or ""
                if nameLower:match("checkpoint") or nameLower:match("stage") or nameLower == "cp" or
                   parentLower:match("checkpoint") or parentLower:match("stage") or parentLower:match("spawns") then
                    local uidName = string.format("CP: %s [%d, %d]", obj.Name, math.floor(obj.Position.X), math.floor(obj.Position.Z))
                    CheckpointMap[uidName] = obj.CFrame
                    table.insert(list, uidName)
                end
            end
        end
        table.sort(list)
        if #list == 0 then table.insert(list, "Tidak ada Checkpoint/Spawn") end
        return list
    end

    local CheckpointDropdown = TeleportTab:Dropdown({
        Title = "Deteksi Checkpoint / Stage",
        Values = {"Klik Refresh dulu"},
        Value = "Kosong",
        SearchBarEnabled = true,
        Callback = function(opt)
            selectedCheckpoint = type(opt) == "table" and opt.Title or opt
        end
    })

    TeleportTab:Button({
        Title = "Refresh Checkpoint Area",
        Icon = "radar",
        Callback = function()
            WindUI:Notify({Title="Scanning...", Content="Mencari Spawn/Stage di workspace", Duration=1})
            local cps = ScanCheckpoints()
            CheckpointDropdown:Refresh(cps)
        end
    })

    TeleportTab:Button({
        Title = "Teleport ke Checkpoint",
        Icon = "map",
        Callback = function()
            if selectedCheckpoint == "" or not CheckpointMap[selectedCheckpoint] then return WindUI:Notify({Title="Error", Content="Pilih Checkpoint yang valid!"}) end
            
            if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
                lp.Character.HumanoidRootPart.CFrame = CheckpointMap[selectedCheckpoint] + Vector3.new(0, 4, 0)
                WindUI:Notify({Title="Teleportasi", Content="Berhasil TP ke Checkpoint", Duration=1.5, Icon="check"})
            end
        end
    })
end
