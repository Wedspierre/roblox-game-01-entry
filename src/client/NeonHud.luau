-- NeonHud: the heads-up display of NEON VOID.
-- One module builds every always-on readout (score, wave, lives, combo,
-- boss bar, power-up timers) and updates it from server snapshots.
-- It keeps the top-left corner empty: Roblox's own menu sits there.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NeonConfig = require(ReplicatedStorage.Shared.NeonConfig)
local NeonGui = require(ReplicatedStorage.Shared.NeonGui)

local NeonHud = {}

local TweenService = game:GetService("TweenService")

local hud: ScreenGui
local scoreLabel: TextLabel
local waveLabel: TextLabel
local livesLabel: TextLabel
local coinsLabel: TextLabel
local comboLabel: TextLabel
local shieldLabel: TextLabel
local rapidLabel: TextLabel
local tripleLabel: TextLabel
local magnetLabel: TextLabel
local starsLabel: TextLabel
local modeLabel: TextLabel
local bossBack: Frame
local bossFill: Frame
local bossLabel: TextLabel
local bannerLabel: TextLabel
local popupLayer: Frame

function NeonHud.build(parentGui: ScreenGui)
	hud = parentGui

	-- Score block: top-right, far from Roblox's top-left menu.
	local scorePanel = NeonGui.newFrame("ScorePanel", hud)
	scorePanel.AnchorPoint = Vector2.new(1, 0)
	scorePanel.Position = UDim2.new(1, -16, 0, 16)
	scorePanel.Size = UDim2.fromOffset(300, 160)
	scoreLabel = NeonGui.newLabel("Score", scorePanel, "SCORE 0", 34, NeonConfig.Palette.White)
	scoreLabel.Position = UDim2.new(0, 12, 0, 8)
	scoreLabel.Size = UDim2.new(1, -24, 0, 40)
	scoreLabel.TextXAlignment = Enum.TextXAlignment.Right
	waveLabel = NeonGui.newLabel("Wave", scorePanel, "WAVE 1", 24, NeonConfig.Palette.Cyan)
	waveLabel.Position = UDim2.new(0, 12, 0, 48)
	waveLabel.Size = UDim2.new(1, -24, 0, 30)
	waveLabel.TextXAlignment = Enum.TextXAlignment.Right
	livesLabel = NeonGui.newLabel("Lives", scorePanel, "♥♥♥", 24, NeonConfig.Palette.Red)
	livesLabel.Position = UDim2.new(0, 12, 0, 78)
	livesLabel.Size = UDim2.new(1, -24, 0, 30)
	livesLabel.TextXAlignment = Enum.TextXAlignment.Right
	coinsLabel = NeonGui.newLabel("Coins", scorePanel, "◉ 0", 24, NeonConfig.Palette.Yellow)
	coinsLabel.Position = UDim2.new(0, 12, 0, 108)
	coinsLabel.Size = UDim2.new(1, -24, 0, 30)
	coinsLabel.TextXAlignment = Enum.TextXAlignment.Right
	starsLabel = NeonGui.newLabel("Stars", scorePanel, "★ 0", 22, NeonConfig.Palette.Yellow)
	starsLabel.Position = UDim2.new(0, 12, 0, 132)
	starsLabel.Size = UDim2.new(1, -24, 0, 26)
	starsLabel.TextXAlignment = Enum.TextXAlignment.Right

	-- Combo meter: under the score panel.
	comboLabel = NeonGui.newLabel("Combo", hud, "", 28, NeonConfig.Palette.Yellow)
	comboLabel.AnchorPoint = Vector2.new(1, 0)
	comboLabel.Position = UDim2.new(1, -16, 0, 188)
	comboLabel.Size = UDim2.fromOffset(300, 36)
	comboLabel.TextXAlignment = Enum.TextXAlignment.Right

	-- Active power-ups: under the combo meter.
	shieldLabel = NeonGui.newLabel("Shield", hud, "", 22, NeonConfig.Palette.Cyan)
	shieldLabel.AnchorPoint = Vector2.new(1, 0)
	shieldLabel.Position = UDim2.new(1, -16, 0, 228)
	shieldLabel.Size = UDim2.fromOffset(300, 30)
	shieldLabel.TextXAlignment = Enum.TextXAlignment.Right
	rapidLabel = NeonGui.newLabel("Rapid", hud, "", 22, NeonConfig.Palette.Yellow)
	rapidLabel.AnchorPoint = Vector2.new(1, 0)
	rapidLabel.Position = UDim2.new(1, -16, 0, 258)
	rapidLabel.Size = UDim2.fromOffset(300, 30)
	rapidLabel.TextXAlignment = Enum.TextXAlignment.Right
	tripleLabel = NeonGui.newLabel("Triple", hud, "", 22, NeonConfig.Palette.Magenta)
	tripleLabel.AnchorPoint = Vector2.new(1, 0)
	tripleLabel.Position = UDim2.new(1, -16, 0, 288)
	tripleLabel.Size = UDim2.fromOffset(300, 30)
	tripleLabel.TextXAlignment = Enum.TextXAlignment.Right
	magnetLabel = NeonGui.newLabel("Magnet", hud, "", 22, NeonConfig.Palette.Orange)
	magnetLabel.AnchorPoint = Vector2.new(1, 0)
	magnetLabel.Position = UDim2.new(1, -16, 0, 318)
	magnetLabel.Size = UDim2.fromOffset(300, 30)
	magnetLabel.TextXAlignment = Enum.TextXAlignment.Right

	-- Mode + Time Attack countdown: top-center, under the boss bar.
	modeLabel = NeonGui.newLabel("Mode", hud, "", 26, NeonConfig.Palette.Yellow)
	modeLabel.AnchorPoint = Vector2.new(0.5, 0)
	modeLabel.Position = UDim2.new(0.5, -220, 0, 76)
	modeLabel.Size = UDim2.fromOffset(440, 32)
	modeLabel.TextXAlignment = Enum.TextXAlignment.Center
	modeLabel.Visible = false

	-- Boss health bar: top-center.
	bossBack, bossFill = NeonGui.newBar("BossHealth", hud, NeonConfig.Palette.Red)
	bossBack.AnchorPoint = Vector2.new(0.5, 0)
	bossBack.Position = UDim2.new(0.5, -220, 0, 18)
	bossBack.Size = UDim2.fromOffset(440, 22)
	bossBack.Visible = false
	bossLabel = NeonGui.newLabel("BossName", hud, "VOID WARDEN", 20, NeonConfig.Palette.Red)
	bossLabel.AnchorPoint = Vector2.new(0.5, 0)
	bossLabel.Position = UDim2.new(0.5, -220, 0, 44)
	bossLabel.Size = UDim2.fromOffset(440, 26)
	bossLabel.TextXAlignment = Enum.TextXAlignment.Center
	bossLabel.Visible = false

	-- Wave banner: center-top, large.
	bannerLabel = NeonGui.newTitleLabel("Banner", hud, "", 44)
	bannerLabel.AnchorPoint = Vector2.new(0.5, 0)
	bannerLabel.Position = UDim2.new(0.5, 0, 0, 96)
	bannerLabel.Size = UDim2.fromOffset(700, 56)
	bannerLabel.TextXAlignment = Enum.TextXAlignment.Center
	bannerLabel.Visible = false

	-- Layer for floating score popups (world positions projected to screen).
	popupLayer = Instance.new("Frame")
	popupLayer.Name = "PopupLayer"
	popupLayer.Size = UDim2.fromScale(1, 1)
	popupLayer.BackgroundTransparency = 1
	popupLayer.Parent = hud
end

function NeonHud.updateFromSnapshot(snapshot: any)
	scoreLabel.Text = "SCORE " .. tostring(snapshot.Score)
	waveLabel.Text = "WAVE " .. tostring(snapshot.Wave)
	local hearts = ""
	for _ = 1, snapshot.Lives do
		hearts ..= "♥"
	end
	livesLabel.Text = hearts
	coinsLabel.Text = "◉ " .. tostring(snapshot.Coins or 0)
	starsLabel.Text = "★ " .. tostring(snapshot.StarsTotal or 0)
	if snapshot.Mode == "TimeAttack" and snapshot.Phase == "Playing" then
		modeLabel.Visible = true
		local seconds = math.max(0, math.ceil(snapshot.TimeLeft or 0))
		modeLabel.Text = string.format("TIME ATTACK  %d:%02d", math.floor(seconds / 60), seconds % 60)
	elseif snapshot.Phase == "Shop" then
		modeLabel.Visible = true
		modeLabel.Text = "SHOP — NEXT WAVE IN " .. tostring(math.max(0, math.ceil(snapshot.ShopTimer or 0))) .. "s"
	else
		modeLabel.Visible = false
	end
	if snapshot.Combo and snapshot.Combo >= 2 then
		local multiplier = 1 + 0.5 * math.min(snapshot.Combo, 8)
		comboLabel.Text = string.format("COMBO x%d  (x%.1f)", snapshot.Combo, multiplier)
	else
		comboLabel.Text = ""
	end
	if snapshot.ShieldCharges and snapshot.ShieldCharges > 0 then
		shieldLabel.Text = "🛡 SHIELD READY"
	else
		shieldLabel.Text = ""
	end
	if snapshot.RapidFire then
		rapidLabel.Text = "⚡ RAPID FIRE"
	else
		rapidLabel.Text = ""
	end
	if snapshot.TripleShot then
		tripleLabel.Text = "✦ TRIPLE SHOT"
	else
		tripleLabel.Text = ""
	end
	if snapshot.Magnet then
		magnetLabel.Text = "🧲 COIN MAGNET"
	else
		magnetLabel.Text = ""
	end
	if snapshot.BossAlive then
		bossBack.Visible = true
		bossLabel.Visible = true
		local fraction = 0
		if snapshot.BossMaxHealth > 0 then
			fraction = math.clamp(snapshot.BossHealth / snapshot.BossMaxHealth, 0, 1)
		end
		bossFill.Size = UDim2.fromScale(fraction, 1)
	else
		bossBack.Visible = false
		bossLabel.Visible = false
	end
end

function NeonHud.showBanner(text: string, holdSeconds: number?)
	bannerLabel.Text = text
	bannerLabel.Visible = true
	task.delay(holdSeconds or 2.2, function()
		bannerLabel.Visible = false
	end)
end

function NeonHud.showScorePopup(screenPosition: Vector2, text: string, color: Color3)
	local popup = NeonGui.newLabel("ScorePopup", popupLayer, text, 26, color)
	popup.AnchorPoint = Vector2.new(0.5, 0.5)
	popup.Position = UDim2.fromOffset(screenPosition.X, screenPosition.Y)
	popup.Size = UDim2.fromOffset(160, 34)
	local tween = TweenService:Create(
		popup,
		TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = UDim2.fromOffset(screenPosition.X, screenPosition.Y - 60), TextTransparency = 1 }
	)
	tween:Play()
	tween.Completed:Connect(function()
		popup:Destroy()
	end)
end

return NeonHud
