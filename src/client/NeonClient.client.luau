local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local C = require(ReplicatedStorage.Shared.NeonConfig)
local G = require(ReplicatedStorage.Shared.NeonGui)
local E = require(ReplicatedStorage.Shared.EnemyCatalog)
local H = require(script.Parent.NeonHud)
local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local remotes: Folder
local stateUpdate: RemoteEvent
local gameEvent: RemoteEvent
local gui: ScreenGui
local titleScreen: Frame
local pauseScreen: Frame
local endScreen: Frame
local clearScreen: Frame
local bestLabel: TextLabel
local raiderLabels: { TextLabel } = {}
local endTitleLabel: TextLabel
local endScoreLabel: TextLabel
local endVaultLabel: TextLabel
local endBestLabel: TextLabel
local endStarsLabel: TextLabel
local clearVaultLabel: TextLabel
local clearScoreLabel: TextLabel
local clearTimeLabel: TextLabel
local clearNoHitLabel: TextLabel
local clearTotalLabel: TextLabel
local clearStarsLabel: TextLabel
local arenaOverlay: Frame
local currentPhase = "Lobby"
local lastMoveSent = 0
local lastMoveDir = Vector2.new(0, 0)
local lastFireTime = 0
local shakeUntil = 0
local shakeStrength = 0
local bestVault = 0
local topRuns: { { Score: number, Vault: number } } = {}
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
	arenaOverlay = Instance.new("Frame")
	arenaOverlay.Name = "ArenaOverlay"
	arenaOverlay.Size = UDim2.fromScale(1, 1)
	arenaOverlay.BackgroundTransparency = 1
	arenaOverlay.Parent = gui
	H.build(gui)
end
local function updateTitleStats(bestScore: number, raidsWon: number)
	bestLabel.Text = "BEST " .. tostring(bestScore) .. "   ·   BEST VAULT " .. tostring(bestVault) .. "   ·   RAIDS WON " .. tostring(raidsWon)
	for i = 1, 5 do
		local run = topRuns[i]
		if run then
			raiderLabels[i].Text = tostring(i) .. ".  " .. tostring(run.Score) .. "  —  VAULT " .. tostring(run.Vault)
		else
			raiderLabels[i].Text = tostring(i) .. ".  —"
		end
	end
end
local function buildTitleScreen()
	G.newDimLayer("StartDim", gui)
	titleScreen = G.newFrame("TitleScreen", gui)
	titleScreen.AnchorPoint = Vector2.new(0.5, 0.5)
	titleScreen.Position = UDim2.fromScale(0.5, 0.5)
	titleScreen.Size = UDim2.fromOffset(680, 620)
	local title = G.newTitleLabel("Title", titleScreen, "NEON VOID", 64)
	title.Position = UDim2.new(0, 0, 0, 20)
	title.Size = UDim2.new(1, 0, 0, 72)
	title.TextXAlignment = Enum.TextXAlignment.Center
	local tagline = G.newLabel("Tagline", titleScreen, "Raid the vaults. Break the void.", 22, C.Palette.DimText)
	tagline.Position = UDim2.new(0, 0, 0, 96)
	tagline.Size = UDim2.new(1, 0, 0, 30)
	tagline.TextXAlignment = Enum.TextXAlignment.Center
	bestLabel = G.newLabel("BestStats", titleScreen, "BEST 0   ·   BEST VAULT 0   ·   RAIDS WON 0", 20, C.Palette.Yellow)
	bestLabel.Position = UDim2.new(0, 0, 0, 132)
	bestLabel.Size = UDim2.new(1, 0, 0, 28)
	bestLabel.TextXAlignment = Enum.TextXAlignment.Center
	local raidButton = G.newButton("RaidButton", titleScreen, "▶  RAID", C.Palette.Cyan, 30)
	raidButton.AnchorPoint = Vector2.new(0.5, 0)
	raidButton.Position = UDim2.new(0.5, -310, 0, 172)
	raidButton.Size = UDim2.fromOffset(300, 68)
	raidButton.MouseButton1Click:Connect(function()
		remote("StartGame"):FireServer("Raid")
	end)
	local endlessButton = G.newButton("EndlessButton", titleScreen, "∞  ENDLESS", C.Palette.Yellow, 30)
	endlessButton.AnchorPoint = Vector2.new(0.5, 0)
	endlessButton.Position = UDim2.new(0.5, 10, 0, 172)
	endlessButton.Size = UDim2.fromOffset(300, 68)
	endlessButton.MouseButton1Click:Connect(function()
		remote("StartGame"):FireServer("Endless")
	end)
	local controls = G.newLabel("Controls", titleScreen, "WASD — fly   ·   CLICK — fire   ·   SPACE — dash   ·   P — pause", 20, C.Palette.White)
	controls.Position = UDim2.new(0, 0, 0, 256)
	controls.Size = UDim2.new(1, 0, 0, 28)
	controls.TextXAlignment = Enum.TextXAlignment.Center
	local roster = G.newLabel("Roster", titleScreen, "7 ENEMIES · 6 DROPS · BOSSES EVERY 5TH VAULT · 10 SHARDS / VAULT", 18, C.Palette.DimText)
	roster.Position = UDim2.new(0, 0, 0, 288)
	roster.Size = UDim2.new(1, 0, 0, 26)
	roster.TextXAlignment = Enum.TextXAlignment.Center
	local raidersTitle = G.newLabel("RaidersTitle", titleScreen, "TOP RAIDERS", 24, C.Palette.Cyan)
	raidersTitle.Position = UDim2.new(0, 0, 0, 330)
	raidersTitle.Size = UDim2.new(1, 0, 0, 30)
	raidersTitle.TextXAlignment = Enum.TextXAlignment.Center
	for i = 1, 5 do
		local row = G.newLabel("Raider" .. tostring(i), titleScreen, tostring(i) .. ".  —", 20, C.Palette.White)
		row.Position = UDim2.new(0, 0, 0, 364 + (i - 1) * 28)
		row.Size = UDim2.new(1, 0, 0, 26)
		row.TextXAlignment = Enum.TextXAlignment.Center
		raiderLabels[i] = row
	end
	local hint = G.newLabel("ModeHint", titleScreen, "RAID — clear all 10 vaults   ·   ENDLESS — the vaults never stop", 18, C.Palette.DimText)
	hint.Position = UDim2.new(0, 0, 0, 522)
	hint.Size = UDim2.new(1, 0, 0, 26)
	hint.TextXAlignment = Enum.TextXAlignment.Center
end
local function buildVaultClearPanel()
	G.newDimLayer("ClearDim", gui).Visible = false
	clearScreen = G.newFrame("ClearScreen", gui)
	clearScreen.AnchorPoint = Vector2.new(0.5, 0.5)
	clearScreen.Position = UDim2.fromScale(0.5, 0.5)
	clearScreen.Size = UDim2.fromOffset(520, 430)
	clearScreen.Visible = false
	local title = G.newTitleLabel("ClearTitle", clearScreen, "VAULT CLEARED", 44)
	title.TextColor3 = C.Palette.Green
	title.Position = UDim2.new(0, 0, 0, 20)
	title.Size = UDim2.new(1, 0, 0, 52)
	title.TextXAlignment = Enum.TextXAlignment.Center
	clearVaultLabel = G.newLabel("ClearVault", clearScreen, "VAULT 1 · LOBBY RESERVE", 24, C.Palette.Cyan)
	clearVaultLabel.Position = UDim2.new(0, 0, 0, 80)
	clearVaultLabel.Size = UDim2.new(1, 0, 0, 32)
	clearVaultLabel.TextXAlignment = Enum.TextXAlignment.Center
	clearScoreLabel = G.newLabel("ClearScore", clearScreen, "Vault score  0", 26, C.Palette.White)
	clearScoreLabel.Position = UDim2.new(0, 0, 0, 124)
	clearScoreLabel.Size = UDim2.new(1, 0, 0, 34)
	clearScoreLabel.TextXAlignment = Enum.TextXAlignment.Center
	clearTimeLabel = G.newLabel("ClearTime", clearScreen, "Time bonus  +0", 26, C.Palette.White)
	clearTimeLabel.Position = UDim2.new(0, 0, 0, 162)
	clearTimeLabel.Size = UDim2.new(1, 0, 0, 34)
	clearTimeLabel.TextXAlignment = Enum.TextXAlignment.Center
	clearNoHitLabel = G.newLabel("ClearNoHit", clearScreen, "No-hit bonus  +0", 26, C.Palette.White)
	clearNoHitLabel.Position = UDim2.new(0, 0, 0, 200)
	clearNoHitLabel.Size = UDim2.new(1, 0, 0, 34)
	clearNoHitLabel.TextXAlignment = Enum.TextXAlignment.Center
	clearStarsLabel = G.newLabel("ClearStars", clearScreen, "★★★", 30, C.Palette.Yellow)
	clearStarsLabel.Position = UDim2.new(0, 0, 0, 238)
	clearStarsLabel.Size = UDim2.new(1, 0, 0, 36)
	clearStarsLabel.TextXAlignment = Enum.TextXAlignment.Center
	clearTotalLabel = G.newLabel("ClearTotal", clearScreen, "Total score  0", 30, C.Palette.Yellow)
	clearTotalLabel.Position = UDim2.new(0, 0, 0, 280)
	clearTotalLabel.Size = UDim2.new(1, 0, 0, 38)
	clearTotalLabel.TextXAlignment = Enum.TextXAlignment.Center
	local cont = G.newButton("ContinueButton", clearScreen, "CONTINUE ▶", C.Palette.Cyan, 26)
	cont.AnchorPoint = Vector2.new(0.5, 0)
	cont.Position = UDim2.new(0.5, -140, 0, 332)
	cont.Size = UDim2.fromOffset(280, 60)
	cont.MouseButton1Click:Connect(function()
		remote("ContinueVault"):FireServer()
	end)
end
local function buildPauseScreen()
	G.newDimLayer("PauseDim", gui).Visible = false
	pauseScreen = G.newFrame("PauseScreen", gui)
	pauseScreen.AnchorPoint = Vector2.new(0.5, 0.5)
	pauseScreen.Position = UDim2.fromScale(0.5, 0.5)
	pauseScreen.Size = UDim2.fromOffset(440, 300)
	pauseScreen.Visible = false
	local title = G.newTitleLabel("PauseTitle", pauseScreen, "PAUSED", 48)
	title.Position = UDim2.new(0, 0, 0, 24)
	title.Size = UDim2.new(1, 0, 0, 60)
	title.TextXAlignment = Enum.TextXAlignment.Center
	local hint = G.newLabel("PauseHint", pauseScreen, "Take a breath. The void waits.", 20, C.Palette.DimText)
	hint.Position = UDim2.new(0, 0, 0, 92)
	hint.Size = UDim2.new(1, 0, 0, 30)
	hint.TextXAlignment = Enum.TextXAlignment.Center
	local resume = G.newButton("ResumeButton", pauseScreen, "RESUME", C.Palette.Green, 30)
	resume.AnchorPoint = Vector2.new(0.5, 0)
	resume.Position = UDim2.new(0.5, -130, 0, 150)
	resume.Size = UDim2.fromOffset(260, 64)
	resume.MouseButton1Click:Connect(function()
		remote("ResumeGame"):FireServer()
	end)
	local quit = G.newButton("QuitButton", pauseScreen, "QUIT TO TITLE", C.Palette.Magenta, 24)
	quit.AnchorPoint = Vector2.new(0.5, 0)
	quit.Position = UDim2.new(0.5, -130, 0, 224)
	quit.Size = UDim2.fromOffset(260, 52)
	quit.MouseButton1Click:Connect(function()
		remote("StartGame"):FireServer()
	end)
end
local function buildEndScreen()
	G.newDimLayer("EndDim", gui).Visible = false
	endScreen = G.newFrame("EndScreen", gui)
	endScreen.AnchorPoint = Vector2.new(0.5, 0.5)
	endScreen.Position = UDim2.fromScale(0.5, 0.5)
	endScreen.Size = UDim2.fromOffset(520, 440)
	endScreen.Visible = false
	endTitleLabel = G.newTitleLabel("EndTitle", endScreen, "RAID FAILED", 48)
	endTitleLabel.Position = UDim2.new(0, 0, 0, 24)
	endTitleLabel.Size = UDim2.new(1, 0, 0, 60)
	endTitleLabel.TextXAlignment = Enum.TextXAlignment.Center
	endScoreLabel = G.newLabel("EndScore", endScreen, "Final score  0", 32, C.Palette.White)
	endScoreLabel.Position = UDim2.new(0, 0, 0, 100)
	endScoreLabel.Size = UDim2.new(1, 0, 0, 40)
	endScoreLabel.TextXAlignment = Enum.TextXAlignment.Center
	endVaultLabel = G.newLabel("EndVault", endScreen, "Reached  VAULT 1", 26, C.Palette.Cyan)
	endVaultLabel.Position = UDim2.new(0, 0, 0, 146)
	endVaultLabel.Size = UDim2.new(1, 0, 0, 34)
	endVaultLabel.TextXAlignment = Enum.TextXAlignment.Center
	endBestLabel = G.newLabel("EndBest", endScreen, "Best score  0", 26, C.Palette.Yellow)
	endBestLabel.Position = UDim2.new(0, 0, 0, 184)
	endBestLabel.Size = UDim2.new(1, 0, 0, 34)
	endBestLabel.TextXAlignment = Enum.TextXAlignment.Center
	endStarsLabel = G.newLabel("EndStars", endScreen, "★ 0 STARS", 26, C.Palette.Yellow)
	endStarsLabel.Position = UDim2.new(0, 0, 0, 222)
	endStarsLabel.Size = UDim2.new(1, 0, 0, 34)
	endStarsLabel.TextXAlignment = Enum.TextXAlignment.Center
	local again = G.newButton("AgainButton", endScreen, "RAID AGAIN", C.Palette.Cyan, 28)
	again.AnchorPoint = Vector2.new(0.5, 0)
	again.Position = UDim2.new(0.5, -140, 0, 276)
	again.Size = UDim2.fromOffset(280, 62)
	again.MouseButton1Click:Connect(function()
		remote("RestartGame"):FireServer()
	end)
	local titleBtn = G.newButton("TitleButton", endScreen, "TITLE", C.Palette.Magenta, 26)
	titleBtn.AnchorPoint = Vector2.new(0.5, 0)
	titleBtn.Position = UDim2.new(0.5, -140, 0, 350)
	titleBtn.Size = UDim2.fromOffset(280, 56)
	titleBtn.MouseButton1Click:Connect(function()
		remote("StartGame"):FireServer("Title")
	end)
end
local function showScreen(which: string)
	titleScreen.Visible = which == "Title"
	pauseScreen.Visible = which == "Pause"
	endScreen.Visible = which == "End"
	clearScreen.Visible = which == "VaultClear"
	gui:FindFirstChild("StartDim").Visible = which == "Title"
	gui:FindFirstChild("PauseDim").Visible = which == "Pause"
	gui:FindFirstChild("EndDim").Visible = which == "End"
	gui:FindFirstChild("ClearDim").Visible = which == "VaultClear"
end
local function setupCamera()
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.new(C.CameraPosition, C.CameraLookAt)
end
local function applyScreenShake()
	if os.clock() > shakeUntil then return end
	local o = Vector3.new((math.random() - 0.5) * shakeStrength, (math.random() - 0.5) * shakeStrength * 0.5, (math.random() - 0.5) * shakeStrength)
	camera.CFrame = CFrame.new(C.CameraPosition + o, C.CameraLookAt)
end
local function startShake(strength: number, seconds: number)
	shakeStrength = strength
	shakeUntil = os.clock() + seconds
end
local function spawnKillBurst(worldPosition: Vector3, color: Color3)
	if not camera then return end
	local screenPos, onScreen = camera:WorldToViewportPoint(worldPosition)
	if not onScreen then return end
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
		local tween = TweenService:Create(shard, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(screenPos.X + (math.random() - 0.5) * 120, screenPos.Y + (math.random() - 0.5) * 120), BackgroundTransparency = 1, Size = UDim2.fromOffset(2, 2) })
		tween:Play()
		tween.Completed:Connect(function()
			shard:Destroy()
		end)
	end
end
local function readMoveDirection(): Vector2
	local x = 0
	local y = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then x -= 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then x += 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then y -= 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then y += 1 end
	return Vector2.new(x, y)
end
local function sendMoveIfNeeded(now: number)
	local dir = readMoveDirection()
	if dir ~= lastMoveDir or now - lastMoveSent >= C.MoveSendInterval then
		lastMoveDir = dir
		lastMoveSent = now
		remote("MoveInput"):FireServer(dir)
	end
end
local function tryFire()
	if currentPhase ~= "Playing" then return end
	local now = os.clock()
	if now - lastFireTime < C.PlayerFireCooldown then return end
	lastFireTime = now
	remote("FireRequest"):FireServer()
end
local function recordRun(score: number, vault: number)
	bestVault = math.max(bestVault, vault)
	table.insert(topRuns, { Score = score, Vault = vault })
	table.sort(topRuns, function(a, b) return a.Score > b.Score end)
	while #topRuns > 5 do table.remove(topRuns) end
end
local function fillEnd(payload: any, won: boolean)
	endTitleLabel.Text = if won then "RAID COMPLETE!" else "RAID FAILED"
	endTitleLabel.TextColor3 = if won then C.Palette.Green else C.Palette.Red
	endScoreLabel.Text = "Final score  " .. tostring(payload.Score)
	endVaultLabel.Text = "Reached  VAULT " .. tostring(payload.Vault)
	endBestLabel.Text = "Best score  " .. tostring(payload.BestScore)
	endStarsLabel.Text = "★ " .. tostring(payload.StarsTotal or 0) .. " STARS"
	recordRun(payload.Score, payload.Vault)
	showScreen("End")
end
local function bindInput()
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.Space then
			if currentPhase == "Playing" then remote("DashRequest"):FireServer() end
		elseif input.KeyCode == Enum.KeyCode.P or input.KeyCode == Enum.KeyCode.Escape then
			if currentPhase == "Playing" then remote("PauseGame"):FireServer()
			elseif currentPhase == "Paused" then remote("ResumeGame"):FireServer() end
		elseif input.KeyCode == Enum.KeyCode.Return and currentPhase == "Lobby" then
			remote("StartGame"):FireServer("Raid")
		end
	end)
end
local function bindServerEvents()
	stateUpdate.OnClientEvent:Connect(function(snapshot: any)
		currentPhase = snapshot.Phase
		H.updateFromSnapshot(snapshot)
		if snapshot.Phase == "Lobby" then
			updateTitleStats(snapshot.BestScore or 0, snapshot.RaidsWon or 0)
			showScreen("Title")
		elseif snapshot.Phase == "Paused" then
			showScreen("Pause")
		elseif snapshot.Phase == "Playing" then
			showScreen("None")
		elseif snapshot.Phase == "VaultClear" then
			showScreen("VaultClear")
		end
	end)
	gameEvent.OnClientEvent:Connect(function(kind: string, payload: any)
		if kind == "Banner" then
			H.showBanner(payload, 2.4)
		elseif kind == "VaultClear" then
			clearVaultLabel.Text = "VAULT " .. tostring(payload.Vault) .. " · " .. tostring(payload.Name)
			clearScoreLabel.Text = "Vault score  " .. tostring(payload.VaultScore)
			clearTimeLabel.Text = "Time bonus  +" .. tostring(payload.TimeBonus)
			clearNoHitLabel.Text = "No-hit bonus  +" .. tostring(payload.NoHitBonus)
			clearTotalLabel.Text = "Total score  " .. tostring(payload.Total)
			clearStarsLabel.Text = string.rep("★", payload.Stars or 0) .. string.rep("☆", 3 - (payload.Stars or 0))
			showScreen("VaultClear")
		elseif kind == "RaidWon" then
			currentPhase = "GameOver"
			fillEnd(payload, true)
		elseif kind == "GameOver" then
			currentPhase = "GameOver"
			fillEnd(payload, false)
		elseif kind == "EnemyDestroyed" then
			spawnKillBurst(payload.Position, E.displayColor(payload.Kind))
		elseif kind == "ScorePopup" then
			if camera then
				local screenPos, onScreen = camera:WorldToViewportPoint(payload.Position)
				if onScreen then H.showScorePopup(Vector2.new(screenPos.X, screenPos.Y), "+" .. tostring(payload.Points), C.Palette.Yellow) end
			end
		elseif kind == "PlayerHit" then
			startShake(2.5, 0.35)
			H.showBanner("HIT!  LIVES LEFT: " .. tostring(payload.Lives), 1.4)
		elseif kind == "ShieldBreak" then
			startShake(1.5, 0.25)
			H.showBanner("SHIELD DOWN!", 1.4)
		elseif kind == "PowerUp" then
			H.showBanner(payload, 1.8)
		elseif kind == "Dash" then
			startShake(0.8, 0.15)
		end
	end)
end
local function startRenderLoop()
	RunService.RenderStepped:Connect(function()
		applyScreenShake()
		if currentPhase ~= "Playing" and currentPhase ~= "VaultClear" then return end
		sendMoveIfNeeded(os.clock())
		if currentPhase == "Playing" and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
			tryFire()
		end
	end)
end
local function start()
	buildGui()
	buildTitleScreen()
	buildVaultClearPanel()
	buildPauseScreen()
	buildEndScreen()
	setupCamera()
	if not waitForRemotes() then return end
	bindInput()
	bindServerEvents()
	startRenderLoop()
	showScreen("Title")
end
local ok, err = pcall(start)
if not ok then warn("[NeonVoid] client start failed: " .. tostring(err)) end
