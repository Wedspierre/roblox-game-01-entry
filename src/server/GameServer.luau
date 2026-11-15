-- GameServer: the single authority of NEON VOID.
-- It owns the whole game state (phase, mode, wave, score, coins, lives,
-- combo, upgrades, the ship, every enemy, bullet, power-up and coin) and
-- steps it on Heartbeat. The client only sends input and renders what
-- this server broadcasts.
--
-- Two modes: Survival runs waves until the ship dies (endless past wave
-- 10) with a coin shop between waves; Time Attack is a 60-second score
-- rush with endless spawning. Waves award 1–3 stars by hits taken.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local NeonConfig = require(ReplicatedStorage.Shared.NeonConfig)
local NeonMath = require(ReplicatedStorage.Shared.NeonMath)
local EnemyCatalog = require(ReplicatedStorage.Shared.EnemyCatalog)
local PowerUpCatalog = require(ReplicatedStorage.Shared.PowerUpCatalog)

local GameServer = {}

-- One table holds the whole game state. Nothing else keeps a copy.
local state = {
	Phase = "Lobby", -- Lobby | Playing | Paused | Shop | GameOver
	Mode = "Survival", -- Survival | TimeAttack
	Wave = 0,
	Score = 0,
	BestScore = 0,
	Coins = 0,
	Combo = 0,
	ComboTimer = 0,
	Lives = NeonConfig.PlayerStartLives,
	ShieldCharges = 0,
	RapidFireUntil = 0,
	TripleShotUntil = 0,
	MagnetUntil = 0,
	DamageLevel = 0,
	FireRateLevel = 0,
	SpeedLevel = 0,
	HitsThisWave = 0,
	StarsTotal = 0,
	TimeLeft = 0,
	ShopTimer = 0,
	EnemiesToSpawn = 0,
	SpawnTimer = 0,
	BossAlive = false,
	BossHealth = 0,
	BossMaxHealth = 1,
	PlayerPosition = Vector3.new(0, 1.5, 0),
	PlayerDirection = Vector2.new(0, -1),
	PlayerFacing = Vector3.new(0, 0, -1),
	MoveDirection = Vector2.new(0, 0),
	InvulnerableUntil = 0,
	LastFireTime = 0,
	StateSendTimer = 0,
	Elapsed = 0,
}

local enemies = {} -- { Part, Kind, Stats, Health, ShootTimer, StrafeDir, StrafeTimer, ChargeTimer, Charging, DashState, DashTimer, DashDir, SpiralAngle, ShockwaveTimer, SpawnTimer }
local playerBullets = {} -- { Part, Velocity, Damage }
local enemyBullets = {} -- { Part, Velocity }
local powerUps = {} -- { Part, Kind, ExpiresAt }
local coins = {} -- { Part, Value }

local ship: Part
local remotes: Folder

local function makeRemote(name: string): RemoteEvent
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotes
	return remote
end

local function createRemotes()
	local folder = Instance.new("Folder")
	folder.Name = "NeonRemotes"
	folder.Parent = ReplicatedStorage
	remotes = folder
	makeRemote("StartGame")
	makeRemote("PauseGame")
	makeRemote("ResumeGame")
	makeRemote("RestartGame")
	makeRemote("BuyUpgrade")
	makeRemote("ContinueShop")
	makeRemote("MoveInput")
	makeRemote("FireRequest")
	makeRemote("StateUpdate")
	makeRemote("GameEvent")
end

local function createShip()
	local part = Instance.new("Part")
	part.Name = "PlayerShip"
	part.Shape = Enum.PartType.Wedge
	part.Size = Vector3.new(4.5, 1.2, 5)
	part.Anchored = true
	part.CanCollide = false
	part.Material = Enum.Material.Neon
	part.Color = NeonConfig.Palette.Cyan
	part.CFrame = CFrame.new(state.PlayerPosition)
	part.Parent = Workspace
	local light = Instance.new("PointLight")
	light.Color = NeonConfig.Palette.Cyan
	light.Range = 18
	light.Brightness = 2
	light.Parent = part
	return part
end

local function makePart(name: string, color: Color3, size: Vector3, position: Vector3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Ball
	part.Size = size
	part.Anchored = true
	part.CanCollide = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.CFrame = CFrame.new(position)
	part.Parent = Workspace
	return part
end

-- Derived run stats from the upgrades bought in the shop.
local function currentDamage(): number
	return NeonConfig.PlayerBulletDamage + state.DamageLevel
end

local function currentFireCooldown(): number
	local base = NeonConfig.PlayerFireCooldown
	if os.clock() < state.RapidFireUntil then
		base = NeonConfig.PlayerRapidFireCooldown
	end
	return base * (0.85 ^ state.FireRateLevel)
end

local function currentSpeed(): number
	return NeonConfig.PlayerSpeed * (1 + 0.08 * state.SpeedLevel)
end

local function upgradeCost(kind: string): number
	local def = NeonConfig.Upgrades[kind]
	local level = state[kind .. "Level"]
	return math.floor(def.BaseCost * (def.CostGrowth ^ level) + 0.5)
end

local function sendState(targetPlayer: Player?)
	local snapshot = {
		Phase = state.Phase,
		Mode = state.Mode,
		Wave = state.Wave,
		Score = state.Score,
		BestScore = state.BestScore,
		Coins = state.Coins,
		Combo = state.Combo,
		Lives = state.Lives,
		MaxLives = NeonConfig.PlayerMaxLives,
		ShieldCharges = state.ShieldCharges,
		RapidFire = os.clock() < state.RapidFireUntil,
		TripleShot = os.clock() < state.TripleShotUntil,
		Magnet = os.clock() < state.MagnetUntil,
		StarsTotal = state.StarsTotal,
		TimeLeft = state.TimeLeft,
		ShopTimer = state.ShopTimer,
		DamageLevel = state.DamageLevel,
		FireRateLevel = state.FireRateLevel,
		SpeedLevel = state.SpeedLevel,
		EnemiesLeft = state.EnemiesToSpawn + #enemies,
		BossAlive = state.BossAlive,
		BossHealth = state.BossHealth,
		BossMaxHealth = state.BossMaxHealth,
		ShipPosition = state.PlayerPosition,
	}
	if targetPlayer then
		remotes.StateUpdate:FireClient(targetPlayer, snapshot)
	else
		remotes.StateUpdate:FireAllClients(snapshot)
	end
end

local function sendEvent(kind: string, payload: any)
	remotes.GameEvent:FireAllClients(kind, payload)
end

local function clearEntities(list: { any })
	for _, entry in ipairs(list) do
		if entry.Part then
			entry.Part:Destroy()
		end
	end
	table.clear(list)
end

local function resetEntities()
	clearEntities(enemies)
	clearEntities(playerBullets)
	clearEntities(enemyBullets)
	clearEntities(powerUps)
	clearEntities(coins)
	state.BossAlive = false
end

local function resetRun()
	resetEntities()
	state.Wave = 0
	state.Score = 0
	state.Coins = 0
	state.Combo = 0
	state.ComboTimer = 0
	state.Lives = NeonConfig.PlayerStartLives
	state.ShieldCharges = 0
	state.RapidFireUntil = 0
	state.TripleShotUntil = 0
	state.MagnetUntil = 0
	state.DamageLevel = 0
	state.FireRateLevel = 0
	state.SpeedLevel = 0
	state.HitsThisWave = 0
	state.StarsTotal = 0
	state.TimeLeft = NeonConfig.TimeAttackSeconds
	state.ShopTimer = 0
	state.EnemiesToSpawn = 0
	state.SpawnTimer = 0
	state.PlayerPosition = Vector3.new(0, 1.5, 0)
	state.PlayerDirection = Vector2.new(0, -1)
	state.PlayerFacing = Vector3.new(0, 0, -1)
	state.MoveDirection = Vector2.new(0, 0)
	state.InvulnerableUntil = 0
	state.LastFireTime = 0
	state.Elapsed = 0
	ship.CFrame = CFrame.new(state.PlayerPosition)
end

-- The wave number that scales enemy stats: the real wave in Survival,
-- and a clock-driven wave in Time Attack (a new wave every 15 seconds).
local function scalingWave(): number
	if state.Mode == "TimeAttack" then
		return 1 + math.floor(state.Elapsed / 15)
	end
	return math.max(state.Wave, 1)
end

local function spawnEnemy(kind: EnemyCatalog.EnemyKind, atPosition: Vector3?)
	local stats = EnemyCatalog.makeStats(kind, scalingWave())
	local position = atPosition or NeonMath.randomEdgePoint(NeonConfig.ArenaHalfSize - 2)
	local size = Vector3.new(stats.Radius * 2, stats.Radius * 2, stats.Radius * 2)
	local part = makePart("Enemy_" .. kind, stats.Color, size, Vector3.new(position.X, 1.5, position.Z))
	if EnemyCatalog.isBossKind(kind) then
		part.Shape = Enum.PartType.Block
		part.Size = Vector3.new(10, 3, 10)
		if kind == "BossMaw" then
			part.Size = Vector3.new(12, 3, 12)
		end
		state.BossAlive = true
		state.BossHealth = stats.Health
		state.BossMaxHealth = stats.Health
	end
	table.insert(enemies, {
		Part = part,
		Kind = kind,
		Stats = stats,
		Health = stats.Health,
		ShootTimer = stats.ShootCooldown or 0,
		StrafeDir = 1,
		StrafeTimer = 0,
		ChargeTimer = 5,
		Charging = 0,
		DashState = "Approach",
		DashTimer = 0,
		DashDir = Vector3.zero,
		SpiralAngle = 0,
		ShockwaveTimer = stats.ShockwaveCooldown or 0,
		SpawnTimer = stats.SpawnCooldown or 0,
	})
end

local function startWave(wave: number)
	state.Wave = wave
	state.HitsThisWave = 0
	state.EnemiesToSpawn = NeonConfig.WaveBaseEnemyCount + NeonConfig.WaveEnemyStep * wave
	state.SpawnTimer = 0.5
	if wave == NeonConfig.EndlessStartsAtWave then
		sendEvent("Banner", "ENDLESS MODE — THE VOID NEVER ENDS")
	elseif EnemyCatalog.isBossWave(wave) then
		local bossKind = EnemyCatalog.bossKindForWave(wave)
		spawnEnemy(bossKind)
		if bossKind == "BossMaw" then
			sendEvent("Banner", "WAVE " .. wave .. " — VOID MAW AWAKENS")
		else
			sendEvent("Banner", "WAVE " .. wave .. " — VOID WARDEN AWAKENS")
		end
	else
		sendEvent("Banner", "WAVE " .. wave)
	end
	sendState()
end

local function dropCoins(position: Vector3, count: number)
	for _ = 1, count do
		local offset = Vector3.new(math.random(-4, 4), 0, math.random(-4, 4))
		local at = Vector3.new(
			NeonMath.clamp(position.X + offset.X, -56, 56),
			1.5,
			NeonMath.clamp(position.Z + offset.Z, -56, 56)
		)
		local part = makePart("Coin", NeonConfig.Palette.Yellow, Vector3.new(1.2, 1.2, 1.2), at)
		table.insert(coins, { Part = part, Value = NeonConfig.CoinValue })
	end
end

local function dropPowerUp(position: Vector3)
	local kind = PowerUpCatalog.rollKind(state.Lives, NeonConfig.PlayerMaxLives)
	local def = PowerUpCatalog.definition(kind)
	local part = makePart("PowerUp_" .. kind, def.Color, Vector3.new(2.4, 2.4, 2.4), Vector3.new(position.X, 1.5, position.Z))
	part.Shape = Enum.PartType.Block
	table.insert(powerUps, { Part = part, Kind = kind, ExpiresAt = os.clock() + NeonConfig.PowerUpLifetimeSeconds })
end

local function awardScore(basePoints: number, position: Vector3?)
	local multiplier = 1 + NeonConfig.ComboStep * math.min(state.Combo, NeonConfig.ComboMaxLevel)
	local points = math.floor(basePoints * multiplier + 0.5)
	state.Score += points
	state.Combo += 1
	state.ComboTimer = NeonConfig.ComboWindowSeconds
	if position then
		sendEvent("ScorePopup", { Points = points, Position = position, Combo = state.Combo })
	end
end

local function killEnemy(index: number, awardPoints: boolean)
	local enemy = enemies[index]
	if not enemy then
		return
	end
	local position = enemy.Part.Position
	local kind = enemy.Kind
	enemy.Part:Destroy()
	table.remove(enemies, index)
	if awardPoints then
		awardScore(enemy.Stats.Score, position)
		if kind == "Tank" then
			dropCoins(position, 3)
		elseif EnemyCatalog.isBossKind(kind) then
			dropCoins(position, 10)
		elseif math.random() < 0.5 then
			dropCoins(position, 2)
		else
			dropCoins(position, 1)
		end
		if math.random() < NeonConfig.PowerUpDropChance then
			dropPowerUp(position)
		end
	end
	sendEvent("EnemyDestroyed", { Kind = kind, Position = position })
	if kind == "Splitter" then
		for _ = 1, enemy.Stats.SplitInto do
			spawnEnemy("Mini", Vector3.new(position.X + math.random(-3, 3), 1.5, position.Z + math.random(-3, 3)))
		end
	elseif EnemyCatalog.isBossKind(kind) then
		state.BossAlive = false
		sendEvent("Banner", kind == "BossMaw" and "VOID MAW DESTROYED!" or "VOID WARDEN DESTROYED!")
	end
end

local function detonateBomb()
	local victims = {}
	for i = #enemies, 1, -1 do
		local enemy = enemies[i]
		if NeonMath.distance2D(enemy.Part.Position, state.PlayerPosition) <= NeonConfig.BombRadius then
			table.insert(victims, i)
		end
	end
	for _, i in ipairs(victims) do
		killEnemy(i, true)
	end
	clearEntities(enemyBullets)
	sendEvent("Banner", "VOID BOMB!")
end

local function applyPowerUp(kind: PowerUpCatalog.PowerUpKind)
	local def = PowerUpCatalog.definition(kind)
	if kind == "Shield" then
		state.ShieldCharges = NeonConfig.ShieldMaxCharges
	elseif kind == "RapidFire" then
		state.RapidFireUntil = os.clock() + NeonConfig.RapidFireDurationSeconds
	elseif kind == "Bomb" then
		detonateBomb()
	elseif kind == "TripleShot" then
		state.TripleShotUntil = os.clock() + NeonConfig.TripleShotDurationSeconds
	elseif kind == "ExtraLife" then
		state.Lives = math.min(state.Lives + 1, NeonConfig.PlayerMaxLives)
	elseif kind == "CoinMagnet" then
		state.MagnetUntil = os.clock() + NeonConfig.MagnetDurationSeconds
	end
	sendEvent("PowerUp", def.Hint)
	sendState()
end

local function gameOver()
	state.Phase = "GameOver"
	if state.Score > state.BestScore then
		state.BestScore = state.Score
	end
	sendEvent("GameOver", { Score = state.Score, Wave = state.Wave, BestScore = state.BestScore, StarsTotal = state.StarsTotal, Mode = state.Mode })
	sendState()
end

local function damagePlayer()
	if os.clock() < state.InvulnerableUntil then
		return
	end
	if state.ShieldCharges > 0 then
		state.ShieldCharges = 0
		state.InvulnerableUntil = os.clock() + NeonConfig.PlayerInvulnerableSeconds
		sendEvent("ShieldBreak", nil)
		sendState()
		return
	end
	state.Lives -= 1
	state.Combo = 0
	state.ComboTimer = 0
	state.HitsThisWave += 1
	state.InvulnerableUntil = os.clock() + NeonConfig.PlayerInvulnerableSeconds
	sendEvent("PlayerHit", { Lives = state.Lives })
	if state.Lives <= 0 then
		gameOver()
		return
	end
	sendState()
end

local function spawnPlayerBullet(direction: Vector3)
	local origin = state.PlayerPosition + direction * 3
	local velocity = direction * NeonConfig.PlayerBulletSpeed
	local part = makePart("PlayerBullet", NeonConfig.Palette.Yellow, Vector3.new(1.2, 1.2, 1.2), Vector3.new(origin.X, 1.5, origin.Z))
	table.insert(playerBullets, { Part = part, Velocity = velocity, Damage = currentDamage() })
end

local function firePlayerBullet()
	local now = os.clock()
	if now - state.LastFireTime < currentFireCooldown() then
		return
	end
	state.LastFireTime = now
	if now < state.TripleShotUntil then
		local facing = state.PlayerFacing
		local function rotated(angle: number): Vector3
			local cos = math.cos(angle)
			local sin = math.sin(angle)
			return Vector3.new(facing.X * cos - facing.Z * sin, 0, facing.X * sin + facing.Z * cos)
		end
		spawnPlayerBullet(rotated(-0.22))
		spawnPlayerBullet(facing)
		spawnPlayerBullet(rotated(0.22))
	else
		spawnPlayerBullet(state.PlayerFacing)
	end
end

local function fireEnemyBullet(from: Vector3, target: Vector3, speed: number)
	local dir = NeonMath.directionTo(from, target)
	local part = makePart("EnemyBullet", NeonConfig.Palette.Magenta, Vector3.new(1.5, 1.5, 1.5), Vector3.new(from.X, 1.5, from.Z))
	table.insert(enemyBullets, { Part = part, Velocity = dir * speed })
end

local function fireRadialBurst(from: Vector3, count: number, speed: number, color: Color3)
	for i = 0, count - 1 do
		local a = i * (2 * math.pi / count)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local part = makePart("EnemyBullet", color, Vector3.new(1.5, 1.5, 1.5), from)
		table.insert(enemyBullets, { Part = part, Velocity = dir * speed })
	end
end

local function movePlayer(dt: number)
	local dir = state.MoveDirection
	if dir.X == 0 and dir.Y == 0 then
		return
	end
	local length = NeonMath.magnitude2D(dir.X, dir.Y)
	local nx = dir.X / length
	local nz = dir.Y / length
	local half = NeonConfig.ArenaHalfSize - NeonConfig.PlayerRadius
	local newX = NeonMath.clamp(state.PlayerPosition.X + nx * currentSpeed() * dt, -half, half)
	local newZ = NeonMath.clamp(state.PlayerPosition.Z + nz * currentSpeed() * dt, -half, half)
	state.PlayerPosition = Vector3.new(newX, 1.5, newZ)
	state.PlayerFacing = Vector3.new(nx, 0, nz)
	ship.CFrame = CFrame.new(state.PlayerPosition) * CFrame.Angles(0, math.atan2(-nx, -nz), 0)
end

local function clampToArena(position: Vector3): Vector3
	return Vector3.new(NeonMath.clamp(position.X, -58, 58), 1.5, NeonMath.clamp(position.Z, -58, 58))
end

local function stepEnemies(dt: number)
	for i = #enemies, 1, -1 do
		local enemy = enemies[i]
		local part = enemy.Part
		local stats = enemy.Stats
		local toPlayer = NeonMath.directionTo(part.Position, state.PlayerPosition)
		local dist = NeonMath.distance2D(part.Position, state.PlayerPosition)
		if enemy.Kind == "Chaser" or enemy.Kind == "Splitter" or enemy.Kind == "Mini" then
			local wobble = 0
			if enemy.Kind == "Mini" then
				wobble = math.sin(os.clock() * 6 + i) * 0.6
			end
			local move = toPlayer * stats.Speed * dt
			part.Position = clampToArena(Vector3.new(
				part.Position.X + move.X + -toPlayer.Z * wobble * dt,
				1.5,
				part.Position.Z + move.Z + toPlayer.X * wobble * dt
			))
		elseif enemy.Kind == "Tank" then
			part.Position = clampToArena(part.Position + toPlayer * stats.Speed * dt)
			enemy.ShockwaveTimer -= dt
			if enemy.ShockwaveTimer <= 0 then
				enemy.ShockwaveTimer = stats.ShockwaveCooldown or 4
				fireRadialBurst(part.Position, 8, stats.BulletSpeed or 28, NeonConfig.Palette.White)
			end
		elseif enemy.Kind == "Dasher" then
			if enemy.DashState == "Approach" then
				part.Position = clampToArena(part.Position + toPlayer * stats.Speed * dt)
				if dist < 22 then
					enemy.DashState = "Windup"
					enemy.DashTimer = 0.6
					part.Transparency = 0.5
				end
			elseif enemy.DashState == "Windup" then
				enemy.DashTimer -= dt
				part.Transparency = 0.5 + 0.5 * math.abs(math.sin(os.clock() * 20))
				if enemy.DashTimer <= 0 then
					enemy.DashState = "Dash"
					enemy.DashTimer = 0.5
					enemy.DashDir = NeonMath.directionTo(part.Position, state.PlayerPosition)
					part.Transparency = 0
				end
			elseif enemy.DashState == "Dash" then
				enemy.DashTimer -= dt
				part.Position = clampToArena(part.Position + enemy.DashDir * stats.Speed * 3.5 * dt)
				if enemy.DashTimer <= 0 then
					enemy.DashState = "Cooldown"
					enemy.DashTimer = stats.DashCooldown or 2.5
				end
			else
				enemy.DashTimer -= dt
				part.Position = clampToArena(part.Position + toPlayer * stats.Speed * 0.5 * dt)
				if enemy.DashTimer <= 0 then
					enemy.DashState = "Approach"
				end
			end
		elseif enemy.Kind == "Shooter" then
			enemy.StrafeTimer -= dt
			if enemy.StrafeTimer <= 0 then
				enemy.StrafeDir = -enemy.StrafeDir
				enemy.StrafeTimer = 2
			end
			local moveX, moveZ = 0, 0
			if dist > 26 then
				moveX, moveZ = toPlayer.X, toPlayer.Z
			elseif dist < 14 then
				moveX, moveZ = -toPlayer.X, -toPlayer.Z
			else
				moveX, moveZ = -toPlayer.Z * enemy.StrafeDir, toPlayer.X * enemy.StrafeDir
			end
			part.Position = clampToArena(Vector3.new(
				part.Position.X + moveX * stats.Speed * dt,
				1.5,
				part.Position.Z + moveZ * stats.Speed * dt
			))
			enemy.ShootTimer -= dt
			if enemy.ShootTimer <= 0 and dist < 45 then
				enemy.ShootTimer = stats.ShootCooldown or 2.2
				fireEnemyBullet(part.Position, state.PlayerPosition, stats.BulletSpeed or 34)
			end
		elseif enemy.Kind == "Spiral" then
			enemy.StrafeTimer -= dt
			if enemy.StrafeTimer <= 0 then
				enemy.StrafeDir = -enemy.StrafeDir
				enemy.StrafeTimer = 2
			end
			local moveX, moveZ = 0, 0
			if dist > 24 then
				moveX, moveZ = toPlayer.X, toPlayer.Z
			elseif dist < 16 then
				moveX, moveZ = -toPlayer.X, -toPlayer.Z
			else
				moveX, moveZ = -toPlayer.Z * enemy.StrafeDir, toPlayer.X * enemy.StrafeDir
			end
			part.Position = clampToArena(Vector3.new(
				part.Position.X + moveX * stats.Speed * dt,
				1.5,
				part.Position.Z + moveZ * stats.Speed * dt
			))
			enemy.ShootTimer -= dt
			if enemy.ShootTimer <= 0 then
				enemy.ShootTimer = stats.ShootCooldown or 0.35
				enemy.SpiralAngle += 0.45
				local dir = Vector3.new(math.cos(enemy.SpiralAngle), 0, math.sin(enemy.SpiralAngle))
				local bullet = makePart("EnemyBullet", NeonConfig.Palette.Cyan, Vector3.new(1.5, 1.5, 1.5), part.Position)
				table.insert(enemyBullets, { Part = bullet, Velocity = dir * (stats.BulletSpeed or 28) })
			end
		elseif enemy.Kind == "BossWarden" then
			enemy.ChargeTimer -= dt
			if enemy.Charging > 0 then
				enemy.Charging -= dt
				part.Position = clampToArena(part.Position + toPlayer * stats.Speed * 3.2 * dt)
			else
				part.Position = clampToArena(part.Position + toPlayer * stats.Speed * dt)
				if enemy.ChargeTimer <= 0 then
					enemy.Charging = 1
					enemy.ChargeTimer = 7
					sendEvent("Banner", "VOID WARDEN CHARGES!")
				end
			end
			enemy.ShootTimer -= dt
			if enemy.ShootTimer <= 0 then
				enemy.ShootTimer = stats.ShootCooldown or 1.6
				fireRadialBurst(part.Position, 8, stats.BulletSpeed or 30, NeonConfig.Palette.Red)
			end
		elseif enemy.Kind == "BossMaw" then
			part.Position = clampToArena(part.Position + toPlayer * stats.Speed * dt)
			enemy.ShootTimer -= dt
			if enemy.ShootTimer <= 0 then
				enemy.ShootTimer = stats.ShootCooldown or 2
				enemy.SpiralAngle += 0.6
				for k = 0, 5 do
					local a = enemy.SpiralAngle + k * (2 * math.pi / 6)
					local dir = Vector3.new(math.cos(a), 0, math.sin(a))
					local bullet = makePart("EnemyBullet", NeonConfig.Palette.Green, Vector3.new(1.5, 1.5, 1.5), part.Position)
					table.insert(enemyBullets, { Part = bullet, Velocity = dir * (stats.BulletSpeed or 28) })
				end
			end
			enemy.SpawnTimer -= dt
			if enemy.SpawnTimer <= 0 and #enemies < NeonConfig.WaveMaxAlive then
				enemy.SpawnTimer = stats.SpawnCooldown or 4
				spawnEnemy("Mini", Vector3.new(part.Position.X + 6, 1.5, part.Position.Z))
				spawnEnemy("Mini", Vector3.new(part.Position.X - 6, 1.5, part.Position.Z))
				sendEvent("Banner", "THE MAW SPAWNS MINIS!")
			end
		end
		-- Touching the ship hurts the player.
		if NeonMath.distance2D(part.Position, state.PlayerPosition) < stats.Radius + NeonConfig.PlayerRadius then
			damagePlayer()
			if not EnemyCatalog.isBossKind(enemy.Kind) then
				killEnemy(i, false)
			end
		end
	end
end

local function stepBullets(dt: number)
	for i = #playerBullets, 1, -1 do
		local bullet = playerBullets[i]
		local part = bullet.Part
		part.Position += bullet.Velocity * dt
		local out = math.abs(part.Position.X) > 62 or math.abs(part.Position.Z) > 62
		local hit = false
		if not out then
			for j = #enemies, 1, -1 do
				local enemy = enemies[j]
				if NeonMath.distance2D(part.Position, enemy.Part.Position) < enemy.Stats.Radius + NeonConfig.BulletRadius then
					enemy.Health -= bullet.Damage
					hit = true
					sendEvent("EnemyHit", { Position = enemy.Part.Position })
					if enemy.Health <= 0 then
						if EnemyCatalog.isBossKind(enemy.Kind) then
							state.BossHealth = 0
						end
						killEnemy(j, true)
					elseif EnemyCatalog.isBossKind(enemy.Kind) then
						state.BossHealth = enemy.Health
					end
					break
				end
			end
		end
		if out or hit then
			part:Destroy()
			table.remove(playerBullets, i)
		end
	end
	for i = #enemyBullets, 1, -1 do
		local bullet = enemyBullets[i]
		local part = bullet.Part
		part.Position += bullet.Velocity * dt
		local out = math.abs(part.Position.X) > 62 or math.abs(part.Position.Z) > 62
		local hitPlayer = not out
			and NeonMath.distance2D(part.Position, state.PlayerPosition) < NeonConfig.PlayerRadius + NeonConfig.BulletRadius
		if out or hitPlayer then
			part:Destroy()
			table.remove(enemyBullets, i)
			if hitPlayer then
				damagePlayer()
			end
		end
	end
end

local function stepPowerUps(dt: number)
	local now = os.clock()
	for i = #powerUps, 1, -1 do
		local pickup = powerUps[i]
		if now > pickup.ExpiresAt then
			pickup.Part:Destroy()
			table.remove(powerUps, i)
		elseif NeonMath.distance2D(pickup.Part.Position, state.PlayerPosition) < NeonConfig.PlayerRadius + 2 then
			local kind = pickup.Kind
			pickup.Part:Destroy()
			table.remove(powerUps, i)
			applyPowerUp(kind)
		end
	end
end

local function stepCoins(dt: number)
	local magnetActive = os.clock() < state.MagnetUntil
	for i = #coins, 1, -1 do
		local coin = coins[i]
		local dist = NeonMath.distance2D(coin.Part.Position, state.PlayerPosition)
		if magnetActive and dist < NeonConfig.CoinMagnetRadius and dist > 0.5 then
			local dir = NeonMath.directionTo(coin.Part.Position, state.PlayerPosition)
			coin.Part.Position += dir * NeonConfig.CoinMagnetSpeed * dt
			dist = NeonMath.distance2D(coin.Part.Position, state.PlayerPosition)
		end
		if dist < NeonConfig.PlayerRadius + 2 then
			state.Coins += coin.Value
			sendEvent("CoinCollected", { Coins = state.Coins })
			coin.Part:Destroy()
			table.remove(coins, i)
		end
	end
end

local function stepSpawning(dt: number)
	if state.EnemiesToSpawn <= 0 then
		return
	end
	state.SpawnTimer -= dt
	if state.SpawnTimer > 0 or #enemies >= NeonConfig.WaveMaxAlive then
		return
	end
	state.SpawnTimer = 0.9
	state.EnemiesToSpawn -= 1
	local kinds = EnemyCatalog.kindsForWave(state.Wave)
	spawnEnemy(kinds[math.random(1, #kinds)])
end

-- Stars for a cleared wave: 3 for a flawless wave, 2 for one hit,
-- 1 otherwise. Shown in the wave-clear banner and on the end screen.
local function starsForWave(): number
	if state.HitsThisWave == 0 then
		return 3
	elseif state.HitsThisWave <= 1 then
		return 2
	else
		return 1
	end
end

local function openShop()
	state.Phase = "Shop"
	state.ShopTimer = NeonConfig.ShopDurationSeconds
	clearEntities(playerBullets)
	clearEntities(enemyBullets)
	sendEvent("ShopOpened", { Coins = state.Coins })
	sendState()
end

local function updatePlaying(dt: number)
	state.Elapsed += dt
	movePlayer(dt)
	stepSpawning(dt)
	stepEnemies(dt)
	stepBullets(dt)
	stepPowerUps(dt)
	stepCoins(dt)
	if state.ComboTimer > 0 then
		state.ComboTimer -= dt
		if state.ComboTimer <= 0 then
			state.Combo = 0
		end
	end
	-- Broadcast at 10 Hz in both modes, so the HUD clock, coins and
	-- boss bar never freeze (Time Attack returns early below).
	state.StateSendTimer -= dt
	if state.StateSendTimer <= 0 then
		state.StateSendTimer = 0.1
		sendState()
	end
	if state.Phase ~= "Playing" then
		return
	end
	if state.Mode == "TimeAttack" then
		state.Wave = 1 + math.floor(state.Elapsed / 15)
		state.TimeLeft -= dt
		if state.TimeLeft <= 0 then
			state.TimeLeft = 0
			gameOver()
			return
		end
		return
	end
	if state.EnemiesToSpawn == 0 and #enemies == 0 and not state.BossAlive then
		local stars = starsForWave()
		state.StarsTotal += stars
		state.Score += NeonConfig.WaveClearBonus
		local starText = string.rep("★", stars) .. string.rep("☆", 3 - stars)
		sendEvent("Banner", "WAVE " .. state.Wave .. " CLEAR! " .. starText .. " +" .. NeonConfig.WaveClearBonus)
		openShop()
		return
	end
end

local function updateShop(dt: number)
	movePlayer(dt)
	stepPowerUps(dt)
	stepCoins(dt)
	state.ShopTimer -= dt
	if state.ShopTimer <= 0 then
		startWave(state.Wave + 1)
		state.Phase = "Playing"
		sendState()
		return
	end
	state.StateSendTimer -= dt
	if state.StateSendTimer <= 0 then
		state.StateSendTimer = 0.25
		sendState()
	end
end

local function update(dt: number)
	if state.Phase == "Playing" then
		updatePlaying(dt)
	elseif state.Phase == "Shop" then
		updateShop(dt)
	end
end

local function bindRemotes()
	remotes.StartGame.OnServerEvent:Connect(function(player: Player, mode: string?)
		if state.Phase == "Paused" then
			-- Quit to title from the pause menu: back to the lobby.
			resetRun()
			state.Phase = "Lobby"
			sendState()
			return
		end
		if state.Phase ~= "Lobby" and state.Phase ~= "GameOver" then
			return
		end
		resetRun()
		state.Mode = if mode == "TimeAttack" then "TimeAttack" else "Survival"
		state.Phase = "Playing"
		if state.Mode == "TimeAttack" then
			state.Wave = 1
			state.EnemiesToSpawn = 9999
			state.SpawnTimer = 0.5
			sendEvent("Banner", "60 SECONDS — KILL EVERYTHING")
			sendState()
		else
			sendEvent("Banner", "SURVIVE THE VOID")
			startWave(1)
		end
		sendState()
	end)
	remotes.RestartGame.OnServerEvent:Connect(function(player: Player)
		if state.Phase ~= "GameOver" then
			return
		end
		resetRun()
		state.Phase = "Playing"
		if state.Mode == "TimeAttack" then
			state.Wave = 1
			state.EnemiesToSpawn = 9999
			state.SpawnTimer = 0.5
			sendState()
		else
			startWave(1)
		end
		sendState()
	end)
	remotes.PauseGame.OnServerEvent:Connect(function(player: Player)
		if state.Phase ~= "Playing" then
			return
		end
		state.Phase = "Paused"
		sendState()
	end)
	remotes.ResumeGame.OnServerEvent:Connect(function(player: Player)
		if state.Phase ~= "Paused" then
			return
		end
		state.Phase = "Playing"
		sendState()
	end)
	remotes.BuyUpgrade.OnServerEvent:Connect(function(player: Player, kind: string)
		if state.Phase ~= "Shop" then
			return
		end
		local def = NeonConfig.Upgrades[kind]
		if not def then
			return
		end
		local level = state[kind .. "Level"]
		if level >= def.MaxLevel then
			return
		end
		local cost = upgradeCost(kind)
		if state.Coins < cost then
			return
		end
		state.Coins -= cost
		state[kind .. "Level"] = level + 1
		sendEvent("UpgradeBought", { Label = def.Label, Level = level + 1, Coins = state.Coins })
		sendState()
	end)
	remotes.ContinueShop.OnServerEvent:Connect(function(player: Player)
		if state.Phase ~= "Shop" then
			return
		end
		startWave(state.Wave + 1)
		state.Phase = "Playing"
		sendState()
	end)
	remotes.MoveInput.OnServerEvent:Connect(function(player: Player, direction: Vector2)
		if state.Phase ~= "Playing" and state.Phase ~= "Shop" then
			return
		end
		local length = NeonMath.magnitude2D(direction.X, direction.Y)
		if length > 1 then
			direction = direction / length
		end
		state.MoveDirection = direction
	end)
	remotes.FireRequest.OnServerEvent:Connect(function(player: Player)
		if state.Phase ~= "Playing" then
			return
		end
		firePlayerBullet()
	end)
end

function GameServer.start()
	local ok, err = pcall(function()
		createRemotes()
		ship = createShip()
		bindRemotes()
	end)
	if not ok then
		warn("[NeonVoid] server setup failed: " .. tostring(err))
		return
	end
	Players.PlayerAdded:Connect(function(player: Player)
		sendState(player)
	end)
	RunService.Heartbeat:Connect(function(dt: number)
		if state.Phase ~= "Playing" and state.Phase ~= "Shop" then
			return
		end
		local okStep, errStep = pcall(update, dt)
		if not okStep then
			warn("[NeonVoid] update failed: " .. tostring(errStep))
		end
	end)
end

return GameServer
