-- PART CONTROLLER - ROPE SCANNER & MAGNET SYSTEM
-- Versi v2.2 (Permintaan User)
-- v2.2: "Execute Snap" sekarang menggunakan WeldConstraint (las) agar menempel permanen
-- v2.2: Tombol Eksekusi sekarang menjadi toggle (Snap/Release)
-- v2.2: "Auto-Scan" sekarang juga menghancurkan Attachments agar rope tidak kembali
-- v2.2: Tetap menggunakan perbaikan bug filter pemain & ikon dari v4

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Check if UI already exists
if playerGui:FindFirstChild("PartControllerUI") then
    playerGui.PartControllerUI:Destroy()
end

-- Detect device type
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- VARIABLES
local magnetPart = nil
local magnetConnection = nil
local scannedObjects = {}
local ropeCount = 0
local magnetStrength = 500
local isMinimized = false
local isScanning = false
local isSnapped = false -- BARU: Melacak status "Snap" / Weld
local activeWelds = {} -- BARU: Menyimpan las yang aktif

-- Create ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PartControllerUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- Responsive sizing
local frameWidth = isMobile and 300 or 380
local frameHeight = isMobile and 380 or 450

-- Main Frame
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, frameWidth, 0, frameHeight)
mainFrame.Position = UDim2.new(0.5, -frameWidth/2, 0.5, -frameHeight/2)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 12)
mainCorner.Parent = mainFrame

-- Title Bar
local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, isMobile and 45 or 50)
titleBar.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 12)
titleCorner.Parent = titleBar

local titleFix = Instance.new("Frame")
titleFix.Size = UDim2.new(1, 0, 0, 12)
titleFix.Position = UDim2.new(0, 0, 1, -12)
titleFix.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
titleFix.BorderSizePixel = 0
titleFix.Parent = titleBar

-- Title Icon
local titleIcon = Instance.new("TextLabel")
titleIcon.Size = UDim2.new(0, isMobile and 35 or 40, 1, 0)
titleIcon.Position = UDim2.new(0, 10, 0, 0)
titleIcon.BackgroundTransparency = 1
titleIcon.Text = "🧲"
titleIcon.TextSize = isMobile and 20 or 24
titleIcon.Font = Enum.Font.GothamBold
titleIcon.TextXAlignment = Enum.TextXAlignment.Center
titleIcon.Parent = titleBar

-- Title Text
local titleText = Instance.new("TextLabel")
titleText.Name = "TitleText"
titleText.Size = UDim2.new(1, -140, 1, 0)
titleText.Position = UDim2.new(0, isMobile and 45 or 50, 0, 0)
titleText.BackgroundTransparency = 1
titleText.Text = "Part Controller"
titleText.TextColor3 = Color3.fromRGB(255, 255, 255)
titleText.TextSize = isMobile and 15 or 18
titleText.Font = Enum.Font.GothamBold
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.Parent = titleBar

-- Minimize Button
local minimizeButton = Instance.new("ImageButton")
minimizeButton.Name = "MinimizeButton"
minimizeButton.Size = UDim2.new(0, isMobile and 35 or 40, 0, isMobile and 35 or 40)
minimizeButton.Position = UDim2.new(1, isMobile and -80 or -90, 0, isMobile and 5 or 5)
minimizeButton.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
minimizeButton.BorderSizePixel = 0
minimizeButton.BackgroundTransparency = 0
minimizeButton.Parent = titleBar

local minimizeCorner = Instance.new("UICorner")
minimizeCorner.CornerRadius = UDim.new(0, 8)
minimizeCorner.Parent = minimizeButton

local minimizeIcon = Instance.new("ImageLabel")
minimizeIcon.Size = UDim2.new(0.5, 0, 0.5, 0)
minimizeIcon.Position = UDim2.new(0.25, 0, 0.25, 0)
minimizeIcon.Image = "rbxasset://textures/ui/Buttons/minimize-circle-dark.png"
minimizeIcon.ImageColor3 = Color3.fromRGB(255, 255, 255)
minimizeIcon.BackgroundTransparency = 1
minimizeIcon.Parent = minimizeButton

-- Close Button
local closeButton = Instance.new("ImageButton")
closeButton.Name = "CloseButton"
closeButton.Size = UDim2.new(0, isMobile and 35 or 40, 0, isMobile and 35 or 40)
closeButton.Position = UDim2.new(1, isMobile and -40 or -45, 0, isMobile and 5 or 5)
closeButton.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
closeButton.BorderSizePixel = 0
closeButton.BackgroundTransparency = 0
closeButton.Parent = titleBar

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = closeButton

local closeIcon = Instance.new("ImageLabel")
closeIcon.Size = UDim2.new(0.5, 0, 0.5, 0)
closeIcon.Position = UDim2.new(0.25, 0, 0.25, 0)
closeIcon.Image = "rbxasset://textures/ui/Buttons/close-circle-dark.png"
closeIcon.ImageColor3 = Color3.fromRGB(255, 255, 255)
closeIcon.BackgroundTransparency = 1
closeIcon.Parent = closeButton

-- Content Frame (ScrollingFrame)
local contentFrame = Instance.new("ScrollingFrame")
contentFrame.Name = "ContentFrame"
contentFrame.Size = UDim2.new(1, -20, 1, (isMobile and -55 or -60))
contentFrame.Position = UDim2.new(0, 10, 0, (isMobile and 50 or 55))
contentFrame.BackgroundTransparency = 1
contentFrame.BorderSizePixel = 0
contentFrame.ScrollingDirection = Enum.ScrollingDirection.Y
contentFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 85)
contentFrame.ScrollBarThickness = 6
contentFrame.Parent = mainFrame

-- Calculate and set CanvasSize
local totalContentHeight = (isMobile and 450 or 490) + 10
contentFrame.CanvasSize = UDim2.new(0, 0, 0, totalContentHeight)

-- Status Label
local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.Size = UDim2.new(1, 0, 0, 30)
statusLabel.Position = UDim2.new(0, 0, 0, 0)
statusLabel.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
statusLabel.BorderSizePixel = 0
statusLabel.Text = "🔍 Ready to Scan"
statusLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
statusLabel.TextSize = isMobile and 13 or 15
statusLabel.Font = Enum.Font.GothamBold
statusLabel.Parent = contentFrame

local statusCorner = Instance.new("UICorner")
statusCorner.CornerRadius = UDim.new(0, 8)
statusCorner.Parent = statusLabel

-- Info Section
local infoFrame = Instance.new("Frame")
infoFrame.Name = "InfoFrame"
infoFrame.Size = UDim2.new(1, 0, 0, isMobile and 70 or 80)
infoFrame.Position = UDim2.new(0, 0, 0, 40)
infoFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
infoFrame.BorderSizePixel = 0
infoFrame.Parent = contentFrame

local infoCorner = Instance.new("UICorner")
infoCorner.CornerRadius = UDim.new(0, 8)
infoCorner.Parent = infoFrame

-- Rope Count Label
local ropeCountLabel = Instance.new("TextLabel")
ropeCountLabel.Size = UDim2.new(0.5, -5, 0, 30)
ropeCountLabel.Position = UDim2.new(0, 10, 0, 10)
ropeCountLabel.BackgroundTransparency = 1
ropeCountLabel.Text = "🔗 Ropes: 0"
ropeCountLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
ropeCountLabel.TextSize = isMobile and 12 or 14
ropeCountLabel.Font = Enum.Font.GothamBold
ropeCountLabel.TextXAlignment = Enum.TextXAlignment.Left
ropeCountLabel.Parent = infoFrame

-- Objects Count Label
local objectsCountLabel = Instance.new("TextLabel")
objectsCountLabel.Size = UDim2.new(0.5, -15, 0, 30)
objectsCountLabel.Position = UDim2.new(0.5, 5, 0, 10)
objectsCountLabel.BackgroundTransparency = 1
objectsCountLabel.Text = "📦 Objects: 0"
objectsCountLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
objectsCountLabel.TextSize = isMobile and 12 or 14
objectsCountLabel.Font = Enum.Font.GothamBold
objectsCountLabel.TextXAlignment = Enum.TextXAlignment.Left
objectsCountLabel.Parent = infoFrame

-- Magnet Status Label
local magnetStatusLabel = Instance.new("TextLabel")
magnetStatusLabel.Size = UDim2.new(1, -20, 0, 30)
magnetStatusLabel.Position = UDim2.new(0, 10, 0, 40)
magnetStatusLabel.BackgroundTransparency = 1
magnetStatusLabel.Text = "🧲 Magnet: Inactive"
magnetStatusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
magnetStatusLabel.TextSize = isMobile and 12 or 14
magnetStatusLabel.Font = Enum.Font.Gotham
magnetStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
magnetStatusLabel.Parent = infoFrame

-- Scan Section
local scanSection = Instance.new("Frame")
scanSection.Name = "ScanSection"
scanSection.Size = UDim2.new(1, 0, 0, isMobile and 100 or 110)
scanSection.Position = UDim2.new(0, 0, 0, isMobile and 130 or 140)
scanSection.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
scanSection.BorderSizePixel = 0
scanSection.Parent = contentFrame

local scanCorner = Instance.new("UICorner")
scanCorner.CornerRadius = UDim.new(0, 8)
scanCorner.Parent = scanSection

-- Scan Title
local scanTitle = Instance.new("TextLabel")
scanTitle.Size = UDim2.new(1, -20, 0, 25)
scanTitle.Position = UDim2.new(0, 10, 0, 8)
scanTitle.BackgroundTransparency = 1
scanTitle.Text = "🔍 Auto-Rope Scanner"
scanTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
scanTitle.TextSize = isMobile and 13 or 15
scanTitle.Font = Enum.Font.GothamBold
scanTitle.TextXAlignment = Enum.TextXAlignment.Left
scanTitle.Parent = scanSection

-- Scan Button
local scanButton = Instance.new("TextButton")
scanButton.Name = "ScanButton"
scanButton.Size = UDim2.new(1, -20, 0, isMobile and 45 or 50)
scanButton.Position = UDim2.new(0, 10, 0, isMobile and 40 or 45)
scanButton.BackgroundColor3 = Color3.fromRGB(59, 130, 246)
scanButton.BorderSizePixel = 0
scanButton.Text = "▶️ Start Auto-Scan"
scanButton.TextColor3 = Color3.fromRGB(255, 255, 255)
scanButton.TextSize = isMobile and 13 or 15
scanButton.Font = Enum.Font.GothamBold
scanButton.Parent = scanSection

local scanBtnCorner = Instance.new("UICorner")
scanBtnCorner.CornerRadius = UDim.new(0, 8)
scanBtnCorner.Parent = scanButton

-- Magnet Section
local magnetSection = Instance.new("Frame")
magnetSection.Name = "MagnetSection"
magnetSection.Size = UDim2.new(1, 0, 0, isMobile and 205 or 225)
magnetSection.Position = UDim2.new(0, 0, 0, isMobile and 240 or 260)
magnetSection.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
magnetSection.BorderSizePixel = 0
magnetSection.Parent = contentFrame

local magnetCorner = Instance.new("UICorner")
magnetCorner.CornerRadius = UDim.new(0, 8)
magnetCorner.Parent = magnetSection

-- Magnet Title
local magnetTitle = Instance.new("TextLabel")
magnetTitle.Size = UDim2.new(1, -20, 0, 25)
magnetTitle.Position = UDim2.new(0, 10, 0, 8)
magnetTitle.BackgroundTransparency = 1
magnetTitle.Text = "🧲 Magnet Control"
magnetTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
magnetTitle.TextSize = isMobile and 13 or 15
magnetTitle.Font = Enum.Font.GothamBold
magnetTitle.TextXAlignment = Enum.TextXAlignment.Left
magnetTitle.Parent = magnetSection

-- Strength Input Container
local strengthContainer = Instance.new("Frame")
strengthContainer.Size = UDim2.new(1, -20, 0, isMobile and 35 or 40)
strengthContainer.Position = UDim2.new(0, 10, 0, isMobile and 40 or 45)
strengthContainer.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
strengthContainer.BorderSizePixel = 0
strengthContainer.Parent = magnetSection

local strengthCorner = Instance.new("UICorner")
strengthCorner.CornerRadius = UDim.new(0, 8)
strengthCorner.Parent = strengthContainer

local strengthLabel = Instance.new("TextLabel")
strengthLabel.Size = UDim2.new(0.4, 0, 1, 0)
strengthLabel.Position = UDim2.new(0, 10, 0, 0)
strengthLabel.BackgroundTransparency = 1
strengthLabel.Text = "Strength:"
strengthLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
strengthLabel.TextSize = isMobile and 12 or 14
strengthLabel.Font = Enum.Font.Gotham
strengthLabel.TextXAlignment = Enum.TextXAlignment.Left
strengthLabel.Parent = strengthContainer

local strengthInput = Instance.new("TextBox")
strengthInput.Size = UDim2.new(0.5, -10, 0, isMobile and 25 or 30)
strengthInput.Position = UDim2.new(0.5, 0, 0.5, isMobile and -12.5 or -15)
strengthInput.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
strengthInput.BorderSizePixel = 0
strengthInput.Text = "500"
strengthInput.PlaceholderText = "500"
strengthInput.TextColor3 = Color3.fromRGB(255, 255, 255)
strengthInput.TextSize = isMobile and 12 or 14
strengthInput.Font = Enum.Font.GothamBold
strengthInput.TextXAlignment = Enum.TextXAlignment.Center
strengthInput.ClearTextOnFocus = false
strengthInput.Parent = strengthContainer

local strengthInputCorner = Instance.new("UICorner")
strengthInputCorner.CornerRadius = UDim.new(0, 6)
strengthInputCorner.Parent = strengthInput

-- Magnet Button
local magnetButton = Instance.new("TextButton")
magnetButton.Name = "MagnetButton"
magnetButton.Size = UDim2.new(1, -20, 0, isMobile and 45 or 50)
magnetButton.Position = UDim2.new(0, 10, 0, isMobile and 85 or 95)
magnetButton.BackgroundColor3 = Color3.fromRGB(168, 85, 247)
magnetButton.BorderSizePixel = 0
magnetButton.Text = "🧲 Create Magnet"
magnetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
magnetButton.TextSize = isMobile and 13 or 15
magnetButton.Font = Enum.Font.GothamBold
magnetButton.Parent = magnetSection

local magnetBtnCorner = Instance.new("UICorner")
magnetBtnCorner.CornerRadius = UDim.new(0, 8)
magnetBtnCorner.Parent = magnetButton

-- Execute Magnet Button
local executeButton = Instance.new("TextButton")
executeButton.Name = "ExecuteButton"
executeButton.Size = UDim2.new(1, -20, 0, isMobile and 45 or 50)
executeButton.Position = UDim2.new(0, 10, 0, isMobile and 140 or 155)
executeButton.BackgroundColor3 = Color3.fromRGB(22, 163, 74) -- Hijau
executeButton.BorderSizePixel = 0
executeButton.Text = "⚡ Execute Snap"
executeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
executeButton.TextSize = isMobile and 13 or 15
executeButton.Font = Enum.Font.GothamBold
executeButton.Parent = magnetSection

local executeBtnCorner = Instance.new("UICorner")
executeBtnCorner.CornerRadius = UDim.new(0, 8)
executeBtnCorner.Parent = executeButton

-- ============================================
-- FUNCTIONS
-- ============================================

-- Deklarasi fungsi (agar bisa saling memanggil)
local StartMagnetAttraction
local ReleaseSnappedObjects

-- Update Status
local function UpdateStatus(message, color)
    statusLabel.Text = message
    statusLabel.TextColor3 = color or Color3.fromRGB(100, 255, 150)
end

-- Update Info
local function UpdateInfo()
    ropeCountLabel.Text = "🔗 Ropes: " .. ropeCount
    objectsCountLabel.Text = "📦 Objects: " .. #scannedObjects
end

-- Scan and Destroy Ropes (UPDATED: Menghancurkan Attachments)
local function DoScanLogic()
    local destroyedCount = 0
    local playerCharacter = player.Character
    
    local function AddScannable(part)
        if not part then return end
        if playerCharacter and part:IsDescendantOf(playerCharacter) then
            return
        end
        if not table.find(scannedObjects, part) then
            table.insert(scannedObjects, part)
        end
    end
    
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("RopeConstraint") then
            local part0 = obj.Attachment0 and obj.Attachment0.Parent:IsA("BasePart") and obj.Attachment0.Parent
            local part1 = obj.Attachment1 and obj.Attachment1.Parent:IsA("BasePart") and obj.Attachment1.Parent
            
            -- BARU: Simpan referensi ke attachments
            local attach0 = obj.Attachment0
            local attach1 = obj.Attachment1
            
            AddScannable(part0)
            AddScannable(part1)
            
            obj:Destroy() -- Hancurkan tali
            
            -- BARU: Hancurkan attachments agar tidak menyambung lagi
            if attach0 then attach0:Destroy() end
            if attach1 then attach1:Destroy() end
            
            destroyedCount = destroyedCount + 1
        end
    end
    
    if destroyedCount > 0 then
        ropeCount = ropeCount + destroyedCount
        UpdateInfo()
    end
end

-- BARU: Fungsi Eksekusi "Snap" (Sekarang Menggunakan Weld)
local function ExecuteMagnetSnap()
    if not magnetPart then
        UpdateStatus("❌ Create magnet first!", Color3.fromRGB(255, 100, 100))
        return false -- Gagal
    end
    
    if #scannedObjects == 0 then
        UpdateStatus("⚠️ No objects scanned to snap!", Color3.fromRGB(255, 150, 0))
        return false -- Gagal
    end
    
    -- BARU: Matikan loop tarikan fisika
    if magnetConnection then
        magnetConnection:Disconnect()
        magnetConnection = nil
    end
    
    UpdateStatus("⚡ Snapping and WELDING objects...", Color3.fromRGB(22, 163, 74))
    local magnetPos = magnetPart.Position
    
    ReleaseSnappedObjects() -- Hapus las lama jika ada
    
    for i = #scannedObjects, 1, -1 do
        local obj = scannedObjects[i]
        
        if obj and obj.Parent and obj:IsA("BasePart") then
            pcall(function()
                local root = obj.AssemblyRootPart or obj
                root.Anchored = false
                root.CFrame = CFrame.new(magnetPos) -- Pindahkan
                root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                
                -- BARU: Buat WeldConstraint
                local weld = Instance.new("WeldConstraint")
                weld.Name = "MagnetWeld"
                weld.Part0 = magnetPart
                weld.Part1 = root
                weld.Parent = magnetPart
                table.insert(activeWelds, weld) -- Simpan las
            end)
        else
            table.remove(scannedObjects, i)
            UpdateInfo()
        end
    end
    
    wait(0.1)
    UpdateStatus("✓ All objects WELDED!", Color3.fromRGB(100, 255, 100))
    return true -- Berhasil
end

-- BARU: Fungsi untuk Melepas Las (Weld)
function ReleaseSnappedObjects()
    if #activeWelds == 0 then return end
    
    UpdateStatus("🔓 Releasing objects...", Color3.fromRGB(255, 200, 0))
    for _, weld in ipairs(activeWelds) do
        if weld then
            weld:Destroy()
        end
    end
    activeWelds = {}
    
    -- BARU: Hidupkan kembali loop tarikan fisika
    StartMagnetAttraction()
end


-- Start Magnet Attraction (Fungsi Tarikan)
function StartMagnetAttraction()
    if not magnetPart then return end
    
    -- Pastikan tidak ada dua loop berjalan
    if magnetConnection then
        magnetConnection:Disconnect()
        magnetConnection = nil
    end
    
    -- Jangan jalankan loop ini jika objek sedang di-las
    if isSnapped then return end
    
    magnetConnection = RunService.Heartbeat:Connect(function()
        if not magnetPart or not magnetPart.Parent then
            RemoveMagnet()
            return
        end
        
        local magnetPos = magnetPart.Position
        
        for i = #scannedObjects, 1, -1 do
            local obj = scannedObjects[i]
            
            if obj and obj.Parent and obj:IsA("BasePart") then
                pcall(function()
                    local root = obj.AssemblyRootPart or obj
                    if root.Anchored then root.Anchored = false end

                    local direction = (magnetPos - root.Position).Unit
                    local distance = (magnetPos - root.Position).Magnitude
                    
                    if distance > 1.5 then
                        local speed = magnetStrength / math.max(distance, 1)
                        root.AssemblyLinearVelocity = direction * speed
                        root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                    else
                        root.CFrame = CFrame.new(magnetPos)
                        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                    end
                end)
            else
                table.remove(scannedObjects, i)
                UpdateInfo()
            end
        end
    end)
end

-- Create Magnet Part (UPDATED: Mereset status snap)
local function CreateMagnet()
    if magnetPart then
        UpdateStatus("⚠️ Magnet already exists!", Color3.fromRGB(255, 150, 0))
        return
    end
    
    local character = player.Character
    if not character then
        UpdateStatus("❌ Character not found!", Color3.fromRGB(255, 100, 100))
        return
    end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        UpdateStatus("❌ HumanoidRootPart not found!", Color3.fromRGB(255, 100, 100))
        return
    end
    
    -- BARU: Reset status snap saat buat magnet baru
    if isSnapped then
        ReleaseSnappedObjects()
        isSnapped = false
        executeButton.Text = "⚡ Execute Snap"
        executeButton.BackgroundColor3 = Color3.fromRGB(22, 163, 74)
    end
    
    magnetPart = Instance.new("Part")
    magnetPart.Name = "MagnetPart"
    magnetPart.Size = Vector3.new(8, 8, 8)
    magnetPart.Position = hrp.Position + Vector3.new(0, 3, 0)
    magnetPart.Anchored = true
    magnetPart.CanCollide = false
    magnetPart.Material = Enum.Material.Neon
    magnetPart.Color = Color3.fromRGB(168, 85, 247)
    magnetPart.Transparency = 0.3
    magnetPart.Parent = workspace
    
    local highlight = Instance.new("SelectionBox")
    highlight.Adornee = magnetPart
    highlight.Color3 = Color3.fromRGB(168, 85, 247)
    highlight.LineThickness = 0.1
    highlight.Transparency = 0.5
    highlight.Parent = magnetPart -- Parent harusnya magnetPart
    
    local particles = Instance.new("ParticleEmitter")
    particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    particles.Rate = 50
    particles.Lifetime = NumberRange.new(1, 2)
    particles.Speed = NumberRange.new(2, 5)
    particles.SpreadAngle = Vector2.new(180, 180)
    particles.Color = ColorSequence.new(Color3.fromRGB(168, 85, 247))
    particles.LightEmission = 1
    particles.Size = NumberSequence.new(0.5)
    particles.Parent = magnetPart
    
    UpdateStatus("✓ Magnet created!", Color3.fromRGB(168, 85, 247))
    magnetStatusLabel.Text = "🧲 Magnet: Active"
    magnetStatusLabel.TextColor3 = Color3.fromRGB(168, 85, 247)
    magnetButton.Text = "🗑️ Remove Magnet"
    magnetButton.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
    
    StartMagnetAttraction() -- Mulai loop tarikan
end

-- Remove Magnet (UPDATED: Membersihkan las)
local function RemoveMagnet()
    if isSnapped then
        ReleaseSnappedObjects()
        isSnapped = false
        executeButton.Text = "⚡ Execute Snap"
        executeButton.BackgroundColor3 = Color3.fromRGB(22, 163, 74)
    end
    
    if magnetPart then
        magnetPart:Destroy()
        magnetPart = nil
    end
    
    if magnetConnection then
        magnetConnection:Disconnect()
        magnetConnection = nil
    end
    
    UpdateStatus("🔍 Magnet removed", Color3.fromRGB(100, 255, 150))
    magnetStatusLabel.Text = "🧲 Magnet: Inactive"
    magnetStatusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    magnetButton.Text = "🧲 Create Magnet"
    magnetButton.BackgroundColor3 = Color3.fromRGB(168, 85, 247)
end

-- Toggle Minimize
local function ToggleMinimize()
    isMinimized = not isMinimized
    local targetSize
    
    if isMinimized then
        targetSize = UDim2.new(0, frameWidth, 0, isMobile and 45 or 50)
        minimizeIcon.Image = "rbxasset://textures/ui/Buttons/maximize-circle-dark.png"
    else
        targetSize = UDim2.new(0, frameWidth, 0, frameHeight)
        minimizeIcon.Image = "rbxasset://textures/ui/Buttons/minimize-circle-dark.png"
    end
    
    TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
        Size = targetSize
    }):Play()
end

-- ============================================
-- EVENT CONNECTIONS
-- ============================================

-- Scan Button (Toggle)
scanButton.MouseButton1Click:Connect(function()
    isScanning = not isScanning
    
    if isScanning then
        scanButton.Text = "🛑 Stop Auto-Scan"
        scanButton.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
        UpdateStatus("🔍 Scanning continuously...", Color3.fromRGB(255, 200, 0))
        
        coroutine.wrap(function()
            while isScanning do
                DoScanLogic()
                wait(0.1)
            end
        end)()
        
    else
        scanButton.Text = "▶️ Start Auto-Scan"
        scanButton.BackgroundColor3 = Color3.fromRGB(59, 130, 246)
        UpdateStatus("🔍 Auto-Scan stopped.", Color3.fromRGB(100, 255, 150))
    end
end)
scanButton.MouseEnter:Connect(function()
    local color = isScanning and Color3.fromRGB(248, 113, 113) or Color3.fromRGB(96, 165, 250)
    TweenService:Create(scanButton, TweenInfo.new(0.2), { BackgroundColor3 = color }):Play()
end)
scanButton.MouseLeave:Connect(function()
    local color = isScanning and Color3.fromRGB(239, 68, 68) or Color3.fromRGB(59, 130, 246)
    TweenService:Create(scanButton, TweenInfo.new(0.2), { BackgroundColor3 = color }):Play()
end)

-- Magnet Button
magnetButton.MouseButton1Click:Connect(function()
    if magnetPart then
        RemoveMagnet()
    else
        CreateMagnet()
    end
end)
magnetButton.MouseEnter:Connect(function()
    if magnetPart then
        TweenService:Create(magnetButton, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(248, 113, 113) }):Play()
    else
        TweenService:Create(magnetButton, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(192, 132, 252) }):Play()
    end
end)
magnetButton.MouseLeave:Connect(function()
    if magnetPart then
        TweenService:Create(magnetButton, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(239, 68, 68) }):Play()
    else
        TweenService:Create(magnetButton, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(168, 85, 247) }):Play()
    end
end)

-- Execute Button Connection (UPDATED: Menjadi Toggle Weld)
executeButton.MouseButton1Click:Connect(function()
    isSnapped = not isSnapped -- Balikkan status
    
    if isSnapped then
        -- Coba lakukan Snap
        local success = ExecuteMagnetSnap()
        if success then
            -- Jika berhasil, ubah tombol
            executeButton.Text = "🔓 Release Objects"
            executeButton.BackgroundColor3 = Color3.fromRGB(220, 38, 38) -- Merah
        else
            -- Jika gagal (misal: tdk ada magnet), batalkan snap
            isSnapped = false
        end
    else
        -- Lakukan Release
        ReleaseSnappedObjects()
        executeButton.Text = "⚡ Execute Snap"
        executeButton.BackgroundColor3 = Color3.fromRGB(22, 163, 74) -- Hijau
    end
end)
executeButton.MouseEnter:Connect(function()
    local color = isSnapped and Color3.fromRGB(248, 113, 113) or Color3.fromRGB(34, 197, 94)
    TweenService:Create(executeButton, TweenInfo.new(0.2), { BackgroundColor3 = color }):Play()
end)
executeButton.MouseLeave:Connect(function()
    local color = isSnapped and Color3.fromRGB(220, 38, 38) or Color3.fromRGB(22, 163, 74)
    TweenService:Create(executeButton, TweenInfo.new(0.2), { BackgroundColor3 = color }):Play()
end)


-- Strength Input
strengthInput.FocusLost:Connect(function()
    local newStrength = tonumber(strengthInput.Text)
    if newStrength and newStrength > 0 then
        magnetStrength = newStrength
        UpdateStatus("⚡ Strength set to " .. magnetStrength, Color3.fromRGB(255, 200, 0))
    else
        strengthInput.Text = tostring(magnetStrength)
        UpdateStatus("⚠️ Invalid strength value!", Color3.fromRGB(255, 150, 0))
    end
end)

-- Minimize Button
minimizeButton.MouseButton1Click:Connect(function()
    ToggleMinimize()
end)
minimizeButton.MouseEnter:Connect(function()
    TweenService:Create(minimizeButton, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(70, 70, 75) }):Play()
end)
minimizeButton.MouseLeave:Connect(function()
    TweenService:Create(minimizeButton, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(50, 50, 55) }):Play()
end)

-- Close Button (UPDATED: Membersihkan las)
closeButton.MouseButton1Click:Connect(function()
    isScanning = false
    RemoveMagnet() -- RemoveMagnet sekarang sudah otomatis melepas las
    
    TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
        Position = UDim2.new(0.5, -frameWidth/2, 1.5, 0)
    }):Play()
    
    wait(0.3)
    screenGui:Destroy()
end)
closeButton.MouseEnter:Connect(function()
    TweenService:Create(closeButton, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(239, 68, 68) }):Play()
end)
closeButton.MouseLeave:Connect(function()
    TweenService:Create(closeButton, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(50, 50, 55) }):Play()
end)

-- Make Draggable
local dragging, dragInput, dragStart, startPos
local function update(input)
    local delta = input.Position - dragStart
    mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end
titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)
titleBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        update(input)
    end
end)

-- Entrance Animation
mainFrame.Position = UDim2.new(0.5, -frameWidth/2, -1, 0)
TweenService:Create(mainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
    Position = UDim2.new(0.5, -frameWidth/2, 0.5, -frameHeight/2)
}):Play()

-- Cleanup on player reset
player.CharacterAdded:Connect(function()
    isScanning = false
    RemoveMagnet()
end)

-- Initial setup
UpdateInfo()

print("========================================")
print("✓ PART CONTROLLER V2.2 (Weld Fix) LOADED")
print("========================================")
print("🔍 Auto-Scanner: Ready (Attachment Destroy)")
print("🧲 Magnet System: Ready")
print("⚡ Execute Snap: Ready (Weld/Release Toggle)")
print("========================================")
