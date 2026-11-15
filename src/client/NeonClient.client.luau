-- NeonClient: everything the player sees and touches in NEON VOID.
-- It builds the start, pause and game-over screens, reads the keyboard
-- and mouse, sends input to the server, and renders the state the
-- server broadcasts (HUD, banners, particles, screen shake).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local NeonConfig = require(ReplicatedStorage.Shared.NeonConfig)
local NeonGui = require(ReplicatedStorage.Shared.NeonGui)
local EnemyCatalog = require(ReplicatedStorage.Shared.EnemyCatalog)
local PowerUpCatalog = require(ReplicatedStorage.Shared.PowerUpCatalog)
local NeonHud = require(script.Parent.NeonHud)

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local remotes: Folder
local stateUpdate: RemoteEvent
local gameEvent: RemoteEvent

local gui: ScreenGui
local startScreen: Frame
local pauseScreen: Frame
local endScreen: Frame
local endScoreLabel: TextLabel
local endWaveLabel: TextLabel
local endBestLabel: TextLabel
local endStarsLabel: TextLabel
local endModeLabel: TextLabel
local shopScreen: Frame
local shopCoinsLabel: TextLabel
local shopTimerLabel: TextLabel
local shopDamageButton: TextButton
local shopFireRateButton: TextButton
local shopSpeedButton: TextButton
local arenaOverlay: Frame

local currentPhase = "Lobby"
local lastMoveSent = 0
local lastMoveDir = Vector2.new(0, 0)
local lastFireTime = 0
local shakeUntil = 0
local shakeStrength = 0

local function waitForRemotes()
	local ok, folder = pcall(function()
		return ReplicatedStorage:WaitForChild("NeonRemotes", 15)
	end)
	if not ok or not folder then
		warn("[NeonVoid] NeonRemotes not found; input will not reach the server")
		return false
	end
	remotes = folder
	stateUpdate = remotes:WaitForChild("StateUpdate") :: RemoteEvent
	gameEvent = remotes:WaitForChild("GameEvent") :: RemoteEvent
	return true
end

local function remote(name: string): RemoteEvent
	return remotes:WaitForChild(name) :: RemoteEvent
end

local function buildGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "NeonVoidGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10
	gui.Parent = player:WaitForChild("PlayerGui")

	local background = NeonGui.newPlainFrame("Background", gui)
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundTransparency = 0

	-- Dim vignette frame the arena overlay sits on (purely cosmetic).
	arenaOverlay = Instance.new("Frame")
	arenaOverlay.Name = "ArenaOverlay"
	arenaOverlay.Size = UDim2.fromScale(1, 1)
	arenaOverlay.BackgroundTransparency = 1
	arenaOverlay.Parent = gui

	NeonHud.build(gui)
end

local function buildStartScreen()
	NeonGui.newDimLayer("StartDim", gui)
	startScreen = NeonGui.newFrame("StartScreen", gui)
	startScreen.AnchorPoint = Vector2.new(0.5, 0.5)
	startScreen.Position = UDim2.fromScale(0.5, 0.5)
	startScreen.Size = UDim2.fromOffset(680, 600)

	local title = NeonGui.newTitleLabel("Title", startScreen, "NEON VOID", 64)
	title.Position = UDim2.new(0, 0, 0, 24)
	title.Size = UDim2.new(1, 0, 0, 72)
	title.TextXAlignment = Enum.TextXAlignment.Center

	local tagline = NeonGui.newLabel("Tagline", startScreen, "Survive the arena. Break the void.", 22, NeonConfig.Palette.DimText)
	tagline.Position = UDim2.new(0, 0, 0, 100)
	tagline.Size = UDim2.new(1, 0, 0, 30)
	tagline.TextXAlignment = Enum.TextXAlignment.Center

	local howTo = NeonGui.newLabel(
		"HowTo",
		startScreen,
		"WASD / ARROW KEYS — fly your ship\nSPACE or CLICK — fire · P or ESC — pause\n\n7 ENEMIES: chaser · shooter · splitter · dasher\ntank · spiral · VOID WARDEN & VOID MAW bosses\n\n6 DROPS: shield · rapid fire · void bomb\ntriple shot · extra life · coin magnet\n\nCoins buy DAMAGE, FIRE RATE and SPEED\nin the shop between waves. Flawless waves earn ★★★.",
		20,
		NeonConfig.Palette.White
	)
	howTo.Position = UDim2.new(0, 24, 0, 150)
	howTo.Size = UDim2.new(1, -48, 0, 250)
	howTo.TextXAlignment = Enum.TextXAlignment.Center

	local survivalButton = NeonGui.newButton("SurvivalButton", startScreen, "▶  SURVIVAL", NeonConfig.Palette.Cyan, 30)
	survivalButton.AnchorPoint = Vector2.new(0.5, 0)
	survivalButton.Position = UDim2.new(0.5, -160, 0, 440)
	survivalButton.Size = UDim2.fromOffset(300, 72)
	survivalButton.MouseButton1Click:Connect(function()
		remote("StartGame"):FireServer("Survival")
	end)

	local timeAttackButton = NeonGui.newButton("TimeAttackButton", startScreen, "⏱  TIME ATTACK 60s", NeonConfig.Palette.Yellow, 30)
	timeAttackButton.AnchorPoint = Vector2.new(0.5, 0)
	timeAttackButton.Position = UDim2.new(0.5, 160, 0, 440)
	timeAttackButton.Size = UDim2.fromOffset(300, 72)
	timeAttackButton.MouseButton1Click:Connect(function()
		remote("StartGame"):FireServer("TimeAttack")
	end)

	local modeHint = NeonGui.newLabel(
		"ModeHint",
		startScreen,
		"SURVIVAL — waves until you fall, endless past wave 10\nTIME ATTACK — 60 seconds, kill everything, top score wins",
		18,
		NeonConfig.Palette.DimText
	)
	modeHint.Position = UDim2.new(0, 0, 0, 524)
	modeHint.Size = UDim2.new(1, 0, 0, 56)
	modeHint.TextXAlignment = Enum.TextXAlignment.Center
end

-- Between-wave shop: spend coins on permanent run upgrades.
local function buildShopPanel()
	shopScreen = NeonGui.newFrame("ShopScreen", gui)
	shopScreen.AnchorPoint = Vector2.new(0.5, 0.5)
	shopScreen.Position = UDim2.fromScale(0.5, 0.5)
	shopScreen.Size = UDim2.fromOffset(560, 420)
	shopScreen.Visible = false

	local title = NeonGui.newTitleLabel("ShopTitle", shopScreen, "WAVE CLEAR — SHOP", 40)
	title.Position = UDim2.new(0, 0, 0, 20)
	title.Size = UDim2.new(1, 0, 0, 52)
	title.TextXAlignment = Enum.TextXAlignment.Center

	shopCoinsLabel = NeonGui.newLabel("ShopCoins", shopScreen, "◉ 0 COINS", 30, NeonConfig.Palette.Yellow)
	shopCoinsLabel.Position = UDim2.new(0, 0, 0, 80)
	shopCoinsLabel.Size = UDim2.new(1, 0, 0, 38)
	shopCoinsLabel.TextXAlignment = Enum.TextXAlignment.Center

	local function upgradeButton(name: string, y: number): TextButton
		local button = NeonGui.newButton(name, shopScreen, name, NeonConfig.Palette.Green, 24)
		button.AnchorPoint = Vector2.new(0.5, 0)
		button.Position = UDim2.new(0.5, -210, 0, y)
		button.Size = UDim2.fromOffset(420, 56)
		return button
	end

	shopDamageButton = upgradeButton("DamageButton", 138)
	shopFireRateButton = upgradeButton("FireRateButton", 204)
	shopSpeedButton = upgradeButton("SpeedButton", 270)
	shopDamageButton.MouseButton1Click:Connect(function()
		remote("BuyUpgrade"):FireServer("Damage")
	end)
	shopFireRateButton.MouseButton1Click:Connect(function()
		remote("BuyUpgrade"):FireServer("FireRate")
	end)
	shopSpeedButton.MouseButton1Click:Connect(function()
		remote("BuyUpgrade"):FireServer("Speed")
	end)

	shopTimerLabel = NeonGui.newLabel("ShopTimer", shopScreen, "NEXT WAVE IN 12s", 22, NeonConfig.Palette.DimText)
	shopTimerLabel.Position = UDim2.new(0, 0, 0, 336)
	shopTimerLabel.Size = UDim2.new(1, 0, 0, 30)
	shopTimerLabel.TextXAlignment = Enum.TextXAlignment.Center

	local continueButton = NeonGui.newButton("ContinueButton", shopScreen, "NEXT WAVE ▶", NeonConfig.Palette.Cyan, 26)
	continueButton.AnchorPoint = Vector2.new(0.5, 0)
	continueButton.Position = UDim2.new(0.5, -140, 0, 366)
	continueButton.Size = UDim2.fromOffset(280, 52)
	continueButton.MouseButton1Click:Connect(function()
		remote("ContinueShop"):FireServer()
	end)
end

local function upgradeCost(level: number, baseCost: number): number
	return math.floor(baseCost * (1.6 ^ level) + 0.5)
end

local function updateShopFromSnapshot(snapshot: any)
	shopCoinsLabel.Text = "◉ " .. tostring(snapshot.Coins or 0) .. " COINS"
	shopTimerLabel.Text = "NEXT WAVE IN " .. tostring(math.max(0, math.ceil(snapshot.ShopTimer or 0))) .. "s"
	local function labelFor(button: TextButton, defLabel: string, level: number, baseCost: number, maxLevel: number)
		if level >= maxLevel then
			button.Text = defLabel .. "  —  MAXED ★"
			button.BackgroundColor3 = NeonConfig.Palette.DimText
		else
			button.Text = defLabel .. "  —  ◉ " .. tostring(upgradeCost(level, baseCost))
			button.BackgroundColor3 = NeonConfig.Palette.Green
		end
	end
	labelFor(shopDamageButton, "DAMAGE +1", snapshot.DamageLevel or 0, 40, 5)
	labelFor(shopFireRateButton, "FIRE RATE +15%", snapshot.FireRateLevel or 0, 35, 5)
	labelFor(shopSpeedButton, "SHIP SPEED +8%", snapshot.SpeedLevel or 0, 30, 5)
end

local function buildPauseScreen()
	NeonGui.newDimLayer("PauseDim", gui).Visible = false
	pauseScreen = NeonGui.newFrame("PauseScreen", gui)
	pauseScreen.AnchorPoint = Vector2.new(0.5, 0.5)
	pauseScreen.Position = UDim2.fromScale(0.5, 0.5)
	pauseScreen.Size = UDim2.fromOffset(440, 300)
	pauseScreen.Visible = false

	local title = NeonGui.newTitleLabel("PauseTitle", pauseScreen, "PAUSED", 48)
	title.Position = UDim2.new(0, 0, 0, 24)
	title.Size = UDim2.new(1, 0, 0, 60)
	title.TextXAlignment = Enum.TextXAlignment.Center

	local hint = NeonGui.newLabel("PauseHint", pauseScreen, "Take a breath. The void waits.", 20, NeonConfig.Palette.DimText)
	hint.Position = UDim2.new(0, 0, 0, 92)
	hint.Size = UDim2.new(1, 0, 0, 30)
	hint.TextXAlignment = Enum.TextXAlignment.Center

	local resumeButton = NeonGui.newButton("ResumeButton", pauseScreen, "RESUME", NeonConfig.Palette.Green, 30)
	resumeButton.AnchorPoint = Vector2.new(0.5, 0)
	resumeButton.Position = UDim2.new(0.5, -130, 0, 150)
	resumeButton.Size = UDim2.fromOffset(260, 64)
	resumeButton.MouseButton1Click:Connect(function()
		remote("ResumeGame"):FireServer()
	end)

	local quitButton = NeonGui.newButton("QuitButton", pauseScreen, "QUIT TO TITLE", NeonConfig.Palette.Magenta, 24)
	quitButton.AnchorPoint = Vector2.new(0.5, 0)
	quitButton.Position = UDim2.new(0.5, -130, 0, 224)
	quitButton.Size = UDim2.fromOffset(260, 52)
	quitButton.MouseButton1Click:Connect(function()
		remote("StartGame"):FireServer()
	end)
end

local function buildEndScreen()
	NeonGui.newDimLayer("EndDim", gui).Visible = false
	endScreen = NeonGui.newFrame("EndScreen", gui)
	endScreen.AnchorPoint = Vector2.new(0.5, 0.5)
	endScreen.Position = UDim2.fromScale(0.5, 0.5)
	endScreen.Size = UDim2.fromOffset(520, 420)
	endScreen.Visible = false

	local title = NeonGui.newTitleLabel("EndTitle", endScreen, "GAME OVER", 52)
	title.Position = UDim2.new(0, 0, 0, 24)
	title.Size = UDim2.new(1, 0, 0, 64)
	title.TextXAlignment = Enum.TextXAlignment.Center

	endScoreLabel = NeonGui.newLabel("EndScore", endScreen, "SCORE 0", 36, NeonConfig.Palette.White)
	endScoreLabel.Position = UDim2.new(0, 0, 0, 104)
	endScoreLabel.Size = UDim2.new(1, 0, 0, 44)
	endScoreLabel.TextXAlignment = Enum.TextXAlignment.Center

	endWaveLabel = NeonGui.newLabel("EndWave", endScreen, "WAVE 1", 26, NeonConfig.Palette.Cyan)
	endWaveLabel.Position = UDim2.new(0, 0, 0, 152)
	endWaveLabel.Size = UDim2.new(1, 0, 0, 34)
	endWaveLabel.TextXAlignment = Enum.TextXAlignment.Center

	endBestLabel = NeonGui.newLabel("EndBest", endScreen, "BEST 0", 26, NeonConfig.Palette.Yellow)
	endBestLabel.Position = UDim2.new(0, 0, 0, 190)
	endBestLabel.Size = UDim2.new(1, 0, 0, 34)
	endBestLabel.TextXAlignment = Enum.TextXAlignment.Center

	endStarsLabel = NeonGui.newLabel("EndStars", endScreen, "★ 0", 30, NeonConfig.Palette.Yellow)
	endStarsLabel.Position = UDim2.new(0, 0, 0, 228)
	endStarsLabel.Size = UDim2.new(1, 0, 0, 36)
	endStarsLabel.TextXAlignment = Enum.TextXAlignment.Center

	endModeLabel = NeonGui.newLabel("EndMode", endScreen, "", 20, NeonConfig.Palette.DimText)
	endModeLabel.Position = UDim2.new(0, 0, 0, 268)
	endModeLabel.Size = UDim2.new(1, 0, 0, 28)
	endModeLabel.TextXAlignment = Enum.TextXAlignment.Center

	local restartButton = NeonGui.newButton("RestartButton", endScreen, "↻  PLAY AGAIN", NeonConfig.Palette.Cyan, 30)
	restartButton.AnchorPoint = Vector2.new(0.5, 0)
	restartButton.Position = UDim2.new(0.5, -140, 0, 308)
	restartButton.Size = UDim2.fromOffset(280, 68)
	restartButton.MouseButton1Click:Connect(function()
		remote("RestartGame"):FireServer()
	end)
end

local function showScreen(which: string)
	startScreen.Visible = which == "Start"
	pauseScreen.Visible = which == "Pause"
	endScreen.Visible = which == "End"
	shopScreen.Visible = which == "Shop"
	gui:FindFirstChild("StartDim").Visible = which == "Start"
	gui:FindFirstChild("PauseDim").Visible = which == "Pause"
	gui:FindFirstChild("EndDim").Visible = which == "End"
end

local function setupCamera()
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.new(NeonConfig.CameraPosition, NeonConfig.CameraLookAt)
end

local function applyScreenShake()
	if os.clock() > shakeUntil then
		return
	end
	local offset = Vector3.new(
		(math.random() - 0.5) * shakeStrength,
		(math.random() - 0.5) * shakeStrength * 0.5,
		(math.random() - 0.5) * shakeStrength
	)
	camera.CFrame = CFrame.new(NeonConfig.CameraPosition + offset, NeonConfig.CameraLookAt)
end

local function startShake(strength: number, seconds: number)
	shakeStrength = strength
	shakeUntil = os.clock() + seconds
end

local function spawnKillBurst(worldPosition: Vector3, color: Color3)
	if not camera then
		return
	end
	local screenPos, onScreen = camera:WorldToViewportPoint(worldPosition)
	if not onScreen then
		return
	end
	for _ = 1, 6 do
		local shard = Instance.new("Frame")
		shard.Name = "BurstShard"
		shard.Size = UDim2.fromOffset(8, 8)
		shard.Position = UDim2.fromOffset(screenPos.X, screenPos.Y)
		shard.BackgroundColor3 = color
		shard.BorderSizePixel = 0
		shard.Parent = arenaOverlay
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = shard
		local targetX = screenPos.X + (math.random() - 0.5) * 120
		local targetY = screenPos.Y + (math.random() - 0.5) * 120
		local tween = TweenService:Create(
			shard,
			TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = UDim2.fromOffset(targetX, targetY), BackgroundTransparency = 1, Size = UDim2.fromOffset(2, 2) }
		)
		tween:Play()
		tween.Completed:Connect(function()
			shard:Destroy()
		end)
	end
end

local function readMoveDirection(): Vector2
	local x = 0
	local y = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
		x -= 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
		x += 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then
		y -= 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then
		y += 1
	end
	return Vector2.new(x, y)
end

local function sendMoveIfNeeded(now: number)
	local dir = readMoveDirection()
	if dir ~= lastMoveDir or now - lastMoveSent >= NeonConfig.MoveSendInterval then
		lastMoveDir = dir
		lastMoveSent = now
		remote("MoveInput"):FireServer(dir)
	end
end

local function tryFire()
	if currentPhase ~= "Playing" then
		return
	end
	local now = os.clock()
	local cooldown = NeonConfig.PlayerFireCooldown
	if now - lastFireTime < cooldown then
		return
	end
	lastFireTime = now
	remote("FireRequest"):FireServer()
end

local function bindInput()
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Space then
			tryFire()
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 and currentPhase == "Playing" then
			tryFire()
		elseif input.KeyCode == Enum.KeyCode.P or input.KeyCode == Enum.KeyCode.Escape then
			if currentPhase == "Playing" then
				remote("PauseGame"):FireServer()
			elseif currentPhase == "Paused" then
				remote("ResumeGame"):FireServer()
			end
		elseif input.KeyCode == Enum.KeyCode.Return and currentPhase == "Lobby" then
			remote("StartGame"):FireServer()
		end
	end)
end

local function bindServerEvents()
	stateUpdate.OnClientEvent:Connect(function(snapshot: any)
		currentPhase = snapshot.Phase
		NeonHud.updateFromSnapshot(snapshot)
		if snapshot.Phase == "Lobby" then
			showScreen("Start")
		elseif snapshot.Phase == "Paused" then
			showScreen("Pause")
		elseif snapshot.Phase == "Playing" then
			showScreen("None")
		elseif snapshot.Phase == "Shop" then
			updateShopFromSnapshot(snapshot)
			showScreen("Shop")
		end
	end)
	gameEvent.OnClientEvent:Connect(function(kind: string, payload: any)
		if kind == "Banner" then
			NeonHud.showBanner(payload, 2.4)
		elseif kind == "ShopOpened" then
			NeonHud.showBanner("SHOP OPEN — SPEND YOUR COINS!", 2)
		elseif kind == "UpgradeBought" then
			NeonHud.showBanner(payload.Label .. " LV" .. tostring(payload.Level) .. " BOUGHT!", 1.8)
			startShake(1, 0.2)
		elseif kind == "EnemyDestroyed" then
			local color = EnemyCatalog.displayColor(payload.Kind)
			spawnKillBurst(payload.Position, color)
		elseif kind == "ScorePopup" then
			if camera then
				local screenPos, onScreen = camera:WorldToViewportPoint(payload.Position)
				if onScreen then
					NeonHud.showScorePopup(Vector2.new(screenPos.X, screenPos.Y), "+" .. tostring(payload.Points), NeonConfig.Palette.Yellow)
				end
			end
		elseif kind == "PlayerHit" then
			startShake(2.5, 0.35)
			NeonHud.showBanner("HIT!  LIVES LEFT: " .. tostring(payload.Lives), 1.4)
		elseif kind == "ShieldBreak" then
			startShake(1.5, 0.25)
			NeonHud.showBanner("SHIELD DOWN!", 1.4)
		elseif kind == "PowerUp" then
			NeonHud.showBanner(payload, 1.8)
		elseif kind == "GameOver" then
			currentPhase = "GameOver"
			endScoreLabel.Text = "SCORE " .. tostring(payload.Score)
			endWaveLabel.Text = "REACHED WAVE " .. tostring(payload.Wave)
			endBestLabel.Text = "BEST " .. tostring(payload.BestScore)
			endStarsLabel.Text = "★ " .. tostring(payload.StarsTotal or 0) .. " STARS"
			endModeLabel.Text = payload.Mode == "TimeAttack" and "TIME ATTACK 60s" or "SURVIVAL — ENDLESS PAST WAVE 10"
			showScreen("End")
		end
	end)
end

local function startRenderLoop()
	RunService.RenderStepped:Connect(function()
		applyScreenShake()
		if currentPhase ~= "Playing" and currentPhase ~= "Shop" then
			return
		end
		sendMoveIfNeeded(os.clock())
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
			tryFire()
		end
	end)
end

local function start()
	buildGui()
	buildStartScreen()
	buildShopPanel()
	buildPauseScreen()
	buildEndScreen()
	setupCamera()
	if not waitForRemotes() then
		return
	end
	bindInput()
	bindServerEvents()
	startRenderLoop()
	showScreen("Start")
end

local ok, err = pcall(start)
if not ok then
	warn("[NeonVoid] client start failed: " .. tostring(err))
end
