local ReplicatedStorage = game:GetService("ReplicatedStorage")
local C = require(ReplicatedStorage.Shared.NeonConfig)
local G = require(ReplicatedStorage.Shared.NeonGui)
local H = {}
local TweenService = game:GetService("TweenService")
local hud: ScreenGui
local scoreLabel: TextLabel
local comboLabel: TextLabel
local vaultLabel: TextLabel
local shardBack: Frame
local shardFill: Frame
local shardLabel: TextLabel
local timerLabel: TextLabel
local livesLabel: TextLabel
local pw: { TextLabel } = {}
local bossBack: Frame
local bossFill: Frame
local bossLabel: TextLabel
local bannerLabel: TextLabel
local dashBack: Frame
local dashFill: Frame
local popupLayer: Frame
function H.build(parentGui: ScreenGui)
	hud = parentGui
	scoreLabel = G.newLabel("Score", hud, "0", 34, C.Palette.White)
	scoreLabel.Position = UDim2.new(0, 64, 0, 6)
	scoreLabel.Size = UDim2.fromOffset(220, 40)
	scoreLabel.TextXAlignment = Enum.TextXAlignment.Left
	comboLabel = G.newLabel("Combo", hud, "", 22, C.Palette.Yellow)
	comboLabel.Position = UDim2.new(0, 64, 0, 46)
	comboLabel.Size = UDim2.fromOffset(220, 28)
	comboLabel.TextXAlignment = Enum.TextXAlignment.Left
	vaultLabel = G.newLabel("Vault", hud, "VAULT 1 · LOBBY RESERVE", 24, C.Palette.Cyan)
	vaultLabel.AnchorPoint = Vector2.new(0.5, 0)
	vaultLabel.Position = UDim2.new(0.5, 0, 0, 6)
	vaultLabel.Size = UDim2.fromOffset(560, 30)
	vaultLabel.TextXAlignment = Enum.TextXAlignment.Center
	shardBack, shardFill = G.newBar("Shards", hud, C.Palette.Yellow)
	shardBack.AnchorPoint = Vector2.new(0.5, 0)
	shardBack.Position = UDim2.new(0.5, -120, 0, 40)
	shardBack.Size = UDim2.fromOffset(240, 12)
	shardLabel = G.newLabel("ShardCount", hud, "SHARDS 0 / 10", 16, C.Palette.White)
	shardLabel.AnchorPoint = Vector2.new(0.5, 0)
	shardLabel.Position = UDim2.new(0.5, 0, 0, 40)
	shardLabel.Size = UDim2.fromOffset(240, 12)
	shardLabel.TextXAlignment = Enum.TextXAlignment.Center
	timerLabel = G.newLabel("Timer", hud, "0:00", 28, C.Palette.White)
	timerLabel.AnchorPoint = Vector2.new(1, 0)
	timerLabel.Position = UDim2.new(1, -16, 0, 6)
	timerLabel.Size = UDim2.fromOffset(200, 36)
	timerLabel.TextXAlignment = Enum.TextXAlignment.Right
	livesLabel = G.newLabel("Lives", hud, "◆◆◆", 22, C.Palette.Red)
	livesLabel.AnchorPoint = Vector2.new(1, 0)
	livesLabel.Position = UDim2.new(1, -16, 0, 44)
	livesLabel.Size = UDim2.fromOffset(200, 28)
	livesLabel.TextXAlignment = Enum.TextXAlignment.Right
	bossBack, bossFill = G.newBar("BossHealth", hud, C.Palette.Red)
	bossBack.AnchorPoint = Vector2.new(0.5, 0)
	bossBack.Position = UDim2.new(0.5, -220, 0, 64)
	bossBack.Size = UDim2.fromOffset(440, 20)
	bossBack.Visible = false
	bossLabel = G.newLabel("BossName", hud, "VOID WARDEN", 20, C.Palette.Red)
	bossLabel.AnchorPoint = Vector2.new(0.5, 0)
	bossLabel.Position = UDim2.new(0.5, -220, 0, 88)
	bossLabel.Size = UDim2.fromOffset(440, 26)
	bossLabel.TextXAlignment = Enum.TextXAlignment.Center
	bossLabel.Visible = false
	for i, v in ipairs({ { "Shield", C.Palette.Cyan }, { "Rapid", C.Palette.Yellow }, { "Triple", C.Palette.Magenta }, { "Magnet", C.Palette.Orange } }) do
		local l = G.newLabel(v[1], hud, "", 22, v[2])
		l.AnchorPoint = Vector2.new(1, 0)
		l.Position = UDim2.new(1, -16, 0, 270 + i * 30)
		l.Size = UDim2.fromOffset(300, 30)
		l.TextXAlignment = Enum.TextXAlignment.Right
		pw[i] = l
	end
	local dashLabel = G.newLabel("DashTitle", hud, "DASH", 20, C.Palette.Cyan)
	dashLabel.AnchorPoint = Vector2.new(0, 1)
	dashLabel.Position = UDim2.new(0, 16, 1, -40)
	dashLabel.Size = UDim2.fromOffset(100, 22)
	dashLabel.TextXAlignment = Enum.TextXAlignment.Left
	dashBack, dashFill = G.newBar("Dash", hud, C.Palette.Cyan)
	dashBack.AnchorPoint = Vector2.new(0, 1)
	dashBack.Position = UDim2.new(0, 16, 1, -16)
	dashBack.Size = UDim2.fromOffset(220, 14)
	bannerLabel = G.newTitleLabel("Banner", hud, "", 44)
	bannerLabel.AnchorPoint = Vector2.new(0.5, 0)
	bannerLabel.Position = UDim2.new(0.5, 0, 0, 120)
	bannerLabel.Size = UDim2.fromOffset(760, 56)
	bannerLabel.TextXAlignment = Enum.TextXAlignment.Center
	bannerLabel.Visible = false
	popupLayer = Instance.new("Frame")
	popupLayer.Name = "PopupLayer"
	popupLayer.Size = UDim2.fromScale(1, 1)
	popupLayer.BackgroundTransparency = 1
	popupLayer.Parent = hud
end
function H.updateFromSnapshot(s: any)
	scoreLabel.Text = tostring(s.Score or 0)
	if s.Combo and s.Combo >= 2 then
		comboLabel.Text = string.format("x%d  (x%.1f)", s.Combo, 1 + 0.5 * math.min(s.Combo, 8))
	else
		comboLabel.Text = "x1"
	end
	vaultLabel.Text = "VAULT " .. tostring(s.Vault or 0) .. " · " .. tostring(s.VaultName or "")
	local quota = s.ShardQuota or 10
	shardFill.Size = UDim2.fromScale(math.clamp((s.Shards or 0) / quota, 0, 1), 1)
	shardLabel.Text = "SHARDS " .. tostring(s.Shards or 0) .. " / " .. tostring(quota)
	local t = math.max(0, math.floor(s.VaultTime or 0))
	timerLabel.Text = string.format("%d:%02d", math.floor(t / 60), t % 60)
	local diamonds = ""
	for _ = 1, s.Lives or 0 do diamonds ..= "◆" end
	livesLabel.Text = diamonds
	pw[1].Text = if s.ShieldCharges and s.ShieldCharges > 0 then "🛡 SHIELD READY" else ""
	pw[2].Text = if s.RapidFire then "⚡ RAPID FIRE" else ""
	pw[3].Text = if s.TripleShot then "✦ TRIPLE SHOT" else ""
	pw[4].Text = if s.Magnet then "🧲 SHARD MAGNET" else ""
	dashFill.Size = UDim2.fromScale(math.clamp(1 - (s.DashCd or 0) / C.DashCooldown, 0, 1), 1)
	if s.BossAlive then
		bossBack.Visible = true
		bossLabel.Visible = true
		local f = 0
		if s.BossMaxHealth > 0 then f = math.clamp(s.BossHealth / s.BossMaxHealth, 0, 1) end
		bossFill.Size = UDim2.fromScale(f, 1)
	else
		bossBack.Visible = false
		bossLabel.Visible = false
	end
end
function H.showBanner(text: string, holdSeconds: number?)
	bannerLabel.Text = text
	bannerLabel.Visible = true
	task.delay(holdSeconds or 2.2, function()
		bannerLabel.Visible = false
	end)
end
function H.showScorePopup(screenPosition: Vector2, text: string, color: Color3)
	local p = G.newLabel("ScorePopup", popupLayer, text, 26, color)
	p.AnchorPoint = Vector2.new(0.5, 0.5)
	p.Position = UDim2.fromOffset(screenPosition.X, screenPosition.Y)
	p.Size = UDim2.fromOffset(160, 34)
	local tween = TweenService:Create(p, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(screenPosition.X, screenPosition.Y - 60), TextTransparency = 1 })
	tween:Play()
	tween.Completed:Connect(function()
		p:Destroy()
	end)
end
return H
