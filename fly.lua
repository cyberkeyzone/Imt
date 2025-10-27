-- Tempatkan skrip ini di StarterPlayer -> StarterPlayerScripts (Ganti kode sebelumnya)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")

local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local PlayerScripts = Player:WaitForChild("PlayerScripts")
local PlayerModule = PlayerScripts:WaitForChild("PlayerModule")
local ControlModule = require(PlayerModule:WaitForChild("ControlModule"))

-- PENGATURAN KECEPATAN BARU
local FLY_SPEED = 75           -- Default Speed
local SPEED_INCREMENT = 25     -- Langkah penambahan/pengurangan
local MAX_SPEED = 500          -- KECEPATAN MAKSIMUM BARU
local MIN_SPEED = 25           -- Kecepatan Minimum

-- PENGATURAN INPUT
local TOGGLE_KEY = Enum.KeyCode.F      
local TOGGLE_ACTION_NAME = "ToggleFlyAction"

-- VARIABEL INTERNAL
local IsFlying = false
local Character 
local HumanoidRootPart
local BodyPosition
local BodyGyro
local ToggleButton 
local SpeedValueLabel 
local humanoid

-- =========================================================================
-- FUNGSI LOGIKA FLY & INPUT
-- (Logika ini tetap sama)
-- =========================================================================

local function handleFlyAction(actionName, inputState, inputObject)
	if actionName == TOGGLE_ACTION_NAME then
		if inputState == Enum.UserInputState.End then
			toggleFly()
		end
	end
	return Enum.ContextActionResult.Pass 
end

local function toggleFly()
	if not Character or not HumanoidRootPart or not humanoid then 
		warn("Karakter atau HRP tidak ditemukan saat mencoba toggle fly.")
		return 
	end

	IsFlying = not IsFlying
	
	if IsFlying then
		humanoid.PlatformStand = true
		
		BodyPosition = Instance.new("BodyPosition", HumanoidRootPart)
		BodyPosition.MaxForce = Vector3.new(math.huge, math.huge, math.huge) 
		BodyPosition.P = 10000 
		BodyPosition.D = 500  
		BodyPosition.Position = HumanoidRootPart.Position
		
		BodyGyro = Instance.new("BodyGyro", HumanoidRootPart)
		BodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
		BodyGyro.P = 10000 
		BodyGyro.D = 500
		BodyGyro.CFrame = HumanoidRootPart.CFrame 

		if ToggleButton then
			ToggleButton.Text = "STOP"
			ToggleButton.BackgroundColor3 = Color3.fromRGB(255, 0, 0) 
		end

		RunService:BindToRenderStep("FlyMovement", Enum.RenderPriority.Camera.Value + 1, function(dt)
			if not Character or not IsFlying or not BodyPosition or not BodyGyro then 
				RunService:UnbindFromRenderStep("FlyMovement")
				return 
			end

			local moveVectorFromInput = ControlModule:GetMoveVector()
			local direction = Vector3.new(0, 0, 0)
			
			if moveVectorFromInput.Magnitude > 0 then
				
				local invertedZ = -moveVectorFromInput.Z
				
				local forwardVector = Camera.CFrame.LookVector * invertedZ 
				local rightVector = Camera.CFrame.RightVector * moveVectorFromInput.X
				
				direction = forwardVector + rightVector
			end
			
			BodyGyro.CFrame = Camera.CFrame 

			if direction.Magnitude > 0 then
				direction = direction.unit
				local newTargetPosition = HumanoidRootPart.Position + (direction * FLY_SPEED * dt) 
				BodyPosition.Position = newTargetPosition
			else
				BodyPosition.Position = HumanoidRootPart.Position
			end
		end)

	else
		if BodyPosition then BodyPosition:Destroy() end
		if BodyGyro then BodyGyro:Destroy() end
		humanoid.PlatformStand = false
		if ToggleButton then
			ToggleButton.Text = "FLY"
			ToggleButton.BackgroundColor3 = Color3.fromRGB(0, 170, 0) 
		end
		RunService:UnbindFromRenderStep("FlyMovement")
	end
end

-- =========================================================================
-- FUNGSI KONTROL KECEPATAN (Tetap sama)
-- =========================================================================

local function changeFlySpeed(change)
	local newSpeed = FLY_SPEED + (change * SPEED_INCREMENT)
	
	if newSpeed > MAX_SPEED then
		newSpeed = MAX_SPEED
	elseif newSpeed < MIN_SPEED then
		newSpeed = MIN_SPEED
	end
	
	FLY_SPEED = newSpeed
	
	if SpeedValueLabel then
		SpeedValueLabel.Text = tostring(math.floor(FLY_SPEED))
	end
end

-- =========================================================================
-- FUNGSI BUAT UI (DIRUBAH DENGAN MINIMIZE/CLOSE)
-- =========================================================================

local function createFlyUI()
	if Player.PlayerGui:FindFirstChild("FlyControlGUI") then 
		Player.PlayerGui.FlyControlGUI:Destroy() 
	end

	local ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = "FlyControlGUI"
	ScreenGui.ResetOnSpawn = false -- Agar tidak reset saat mati
	ScreenGui.Parent = Player:WaitForChild("PlayerGui")
	
	-- Frame Utama sebagai Kontainer
	local MainFrame = Instance.new("Frame")
	MainFrame.Name = "MainFrame"
	MainFrame.Size = UDim2.new(0, 70, 0, 85) -- Lebar 70, Tinggi 85 (Cukup untuk semua tombol)
	MainFrame.Position = UDim2.new(1, -80, 0, 10) -- 80px dari kanan, 10px dari atas
	MainFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	MainFrame.BackgroundTransparency = 0.2
	MainFrame.BorderSizePixel = 1
	MainFrame.BorderColor3 = Color3.fromRGB(200, 200, 200)
	MainFrame.ClipsDescendants = true -- Penting agar tween size terlihat rapi
	MainFrame.Parent = ScreenGui

	-- Variabel untuk menyimpan kontrol yang bisa di-minimize
	local speedControls = {}
	local isMinimized = false

	-- Tombol Close (X)
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Text = "X"
	closeButton.Size = UDim2.new(0, 20, 0, 20)
	closeButton.Position = UDim2.new(1, -20, 0, 0) -- Pojok kanan atas frame
	closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeButton.Font = Enum.Font.SourceSansBold
	closeButton.Parent = MainFrame
	closeButton.MouseButton1Click:Connect(function()
		ScreenGui:Destroy() -- Hancurkan seluruh GUI
		ContextActionService:UnbindAction(TOGGLE_ACTION_NAME) -- Hentikan binding tombol F
	end)
	
	-- Tombol Minimize (_)
	local minimizeButton = Instance.new("TextButton")
	minimizeButton.Name = "MinimizeButton"
	minimizeButton.Text = "_"
	minimizeButton.Size = UDim2.new(0, 20, 0, 20)
	minimizeButton.Position = UDim2.new(1, -40, 0, 0) -- Sebelah kiri tombol close
	minimizeButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
	minimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	minimizeButton.Font = Enum.Font.SourceSansBold
	minimizeButton.Parent = MainFrame
	
	-- 1. Tombol TOGGLE FLY 
	local toggleButton = Instance.new("TextButton")
	toggleButton.Name = "ToggleFlyButton"
	toggleButton.Text = "FLY"
	toggleButton.Size = UDim2.new(0, 50, 0, 30) 
	toggleButton.Position = UDim2.new(0.5, 0, 0, 22) -- Di bawah min/close, tengah
	toggleButton.AnchorPoint = Vector2.new(0.5, 0) -- Jangkar di tengah atas
	toggleButton.BackgroundColor3 = Color3.fromRGB(0, 170, 0) 
	toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	toggleButton.Font = Enum.Font.SourceSansBold
	toggleButton.Parent = MainFrame -- Ubah parent ke MainFrame
	
	ToggleButton = toggleButton
	toggleButton.MouseButton1Click:Connect(toggleFly)

	-- 2. Tombol Kurangi Kecepatan (-)
	local minusButton = Instance.new("TextButton")
	minusButton.Name = "MinusButton"
	minusButton.Text = "-"
	minusButton.Size = UDim2.new(0, 20, 0, 20)
	minusButton.Position = UDim2.new(0, 0, 0, 60) -- Posisi Y di bawah toggle
	minusButton.BackgroundColor3 = Color3.fromRGB(255, 100, 100) 
	minusButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	minusButton.Font = Enum.Font.SourceSansBold
	minusButton.Parent = MainFrame -- Ubah parent ke MainFrame
	minusButton.MouseButton1Click:Connect(function()
		changeFlySpeed(-1)
	end)
	table.insert(speedControls, minusButton) -- Tambahkan ke tabel
	
	-- 3. Label Nilai Kecepatan
	local speedLabel = Instance.new("TextLabel")
	speedLabel.Name = "SpeedValueLabel"
	speedLabel.Text = tostring(math.floor(FLY_SPEED)) 
	speedLabel.Size = UDim2.new(0, 30, 0, 20)
	speedLabel.Position = UDim2.new(0, 20, 0, 60) -- Di sebelah tombol minus
	speedLabel.BackgroundColor3 = Color3.fromRGB(50, 50, 50) 
	speedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	speedLabel.Font = Enum.Font.SourceSansBold
	speedLabel.Parent = MainFrame -- Ubah parent ke MainFrame
	SpeedValueLabel = speedLabel
	table.insert(speedControls, speedLabel) -- Tambahkan ke tabel
	
	-- 4. Tombol Tambah Kecepatan (+)
	local plusButton = Instance.new("TextButton")
	plusButton.Name = "PlusButton"
	plusButton.Text = "+"
	plusButton.Size = UDim2.new(0, 20, 0, 20)
	plusButton.Position = UDim2.new(0, 50, 0, 60) -- Di sebelah label
	plusButton.BackgroundColor3 = Color3.fromRGB(100, 255, 100) 
	plusButton.TextColor3 = Color3.fromRGB(0, 0, 0)
	plusButton.Font = Enum.Font.SourceSansBold
	plusButton.Parent = MainFrame -- Ubah parent ke MainFrame
	plusButton.MouseButton1Click:Connect(function()
		changeFlySpeed(1)
	end)
	table.insert(speedControls, plusButton) -- Tambahkan ke tabel
	
	-- Logika Tombol Minimize
	minimizeButton.MouseButton1Click:Connect(function()
		isMinimized = not isMinimized
		local newFrameHeight
		
		if isMinimized then
			-- Sembunyikan kontrol kecepatan
			minimizeButton.Text = "+" -- Ganti teks tombol jadi "maximize"
			newFrameHeight = 55 -- Tinggi baru (cukup untuk min/close + tombol fly)
			for _, control in ipairs(speedControls) do
				control.Visible = false
			end
		else
			-- Tampilkan lagi
			minimizeButton.Text = "_" -- Ganti teks kembali ke "minimize"
			newFrameHeight = 85 -- Tinggi asli
			for _, control in ipairs(speedControls) do
				control.Visible = true
			end
		end
		
		-- Animasi perubahan ukuran frame
		MainFrame:TweenSize(
			UDim2.new(0, 70, 0, newFrameHeight),
			Enum.EasingDirection.Out,
			Enum.EasingStyle.Quad,
			0.2,
			true
		)
	end)

	-- Binding Input
	ContextActionService:BindAction(
		TOGGLE_ACTION_NAME, 
		handleFlyAction, 
		false, 
		TOGGLE_KEY
	)
end

-- =========================================================================
-- SETUP KARAKTER (Tetap sama)
-- =========================================================================

local function setupCharacter(char)
	Character = char
	humanoid = char:WaitForChild("Humanoid")
	HumanoidRootPart = char:WaitForChild("HumanoidRootPart")
	
	if IsFlying then
		IsFlying = false
		toggleFly() 
	end
end

Player.CharacterAdded:Connect(setupCharacter)

if Player.Character then
	setupCharacter(Player.Character)
end

if Player.PlayerGui then
	createFlyUI()
else
	Player:WaitForChild("PlayerGui"):Wait()
	createFlyUI()
end
