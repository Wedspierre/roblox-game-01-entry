local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local C = require(ReplicatedStorage.Shared.NeonConfig)
local M = require(ReplicatedStorage.Shared.NeonMath)
local E = require(ReplicatedStorage.Shared.EnemyCatalog)
local P = require(ReplicatedStorage.Shared.PowerUpCatalog)
local GameServer = {}
local state = {
	Phase = "Lobby", Mode = "Raid", Vault = 0, Score = 0, BestScore = 0, Coins = 0,
	Combo = 0, ComboTimer = 0, Lives = C.PlayerStartLives, ShieldCharges = 0,
	RapidFireUntil = 0, TripleShotUntil = 0, MagnetUntil = 0, HitsThisVault = 0,
	StarsTotal = 0, VaultScore = 0, VaultStart = 0, VaultTime = 0, Shards = 0,
	EnemiesToSpawn = 0, SpawnTimer = 0, BossAlive = false, BossHealth = 0, BossMaxHealth = 1,
	PlayerPosition = Vector3.new(0, 1.5, 0),
	PlayerFacing = Vector3.new(0, 0, -1), MoveDirection = Vector2.new(0, 0),
	InvulnerableUntil = 0, LastFireTime = 0, DashReadyAt = 0, StateSendTimer = 0,
	ClearTimer = 0, RaidsWon = 0,
}
local enemies = {}
local playerBullets = {}
local enemyBullets = {}
local powerUps = {}
local coins = {}
local shards = {}
local ship: Part
local remotes: Folder
local function makeRemote(name: string): RemoteEvent
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end
local function createRemotes()
	local f = Instance.new("Folder")
	f.Name = "NeonRemotes"
	f.Parent = ReplicatedStorage
	remotes = f
	makeRemote("StartGame")
	makeRemote("PauseGame")
	makeRemote("ResumeGame")
	makeRemote("RestartGame")
	makeRemote("MoveInput")
	makeRemote("FireRequest")
	makeRemote("DashRequest")
	makeRemote("ContinueVault")
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
	part.Color = C.Palette.Cyan
	part.CFrame = CFrame.new(state.PlayerPosition)
	part.Parent = Workspace
	local light = Instance.new("PointLight")
	light.Color = C.Palette.Cyan
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
local function vaultName(n: number): string
	return C.VaultNames[(n - 1) % #C.VaultNames + 1]
end
local function sendState(target: Player?)
	local s = {
		Phase = state.Phase, Vault = state.Vault, VaultName = vaultName(math.max(state.Vault, 1)),
		Score = state.Score, BestScore = state.BestScore, Combo = state.Combo,
		Lives = state.Lives, MaxLives = C.PlayerMaxLives, ShieldCharges = state.ShieldCharges,
		RapidFire = os.clock() < state.RapidFireUntil, TripleShot = os.clock() < state.TripleShotUntil,
		Magnet = os.clock() < state.MagnetUntil, Shards = state.Shards, ShardQuota = C.ShardQuota,
		VaultTime = state.VaultTime, DashCd = math.max(0, state.DashReadyAt - os.clock()),
		BossAlive = state.BossAlive, BossHealth = state.BossHealth, BossMaxHealth = state.BossMaxHealth,
		RaidsWon = state.RaidsWon,
	}
	if target then remotes.StateUpdate:FireClient(target, s) else remotes.StateUpdate:FireAllClients(s) end
end
local function sendEvent(kind: string, payload: any)
	remotes.GameEvent:FireAllClients(kind, payload)
end
local function clearEntities(list: { any })
	for _, e in ipairs(list) do if e.Part then e.Part:Destroy() end end
	table.clear(list)
end
local function resetEntities()
	clearEntities(enemies)
	clearEntities(playerBullets)
	clearEntities(enemyBullets)
	clearEntities(powerUps)
	clearEntities(coins)
	clearEntities(shards)
	state.BossAlive = false
end
local function resetRun()
	resetEntities()
	state.Vault = 0
	state.Score = 0
	state.Coins = 0
	state.Combo = 0
	state.ComboTimer = 0
	state.Lives = C.PlayerStartLives
	state.ShieldCharges = 0
	state.RapidFireUntil = 0
	state.TripleShotUntil = 0
	state.MagnetUntil = 0
	state.HitsThisVault = 0
	state.StarsTotal = 0
	state.VaultScore = 0
	state.VaultTime = 0
	state.Shards = 0
	state.EnemiesToSpawn = 0
	state.SpawnTimer = 0
	state.PlayerPosition = Vector3.new(0, 1.5, 0)
	state.PlayerFacing = Vector3.new(0, 0, -1)
	state.MoveDirection = Vector2.new(0, 0)
	state.InvulnerableUntil = 0
	state.LastFireTime = 0
	state.DashReadyAt = 0
	state.ClearTimer = 0
	ship.CFrame = CFrame.new(state.PlayerPosition)
end
local function spawnEnemy(kind: E.EnemyKind, atPosition: Vector3?)
	local stats = E.makeStats(kind, math.max(state.Vault, 1))
	local pos = atPosition or M.randomEdgePoint(C.ArenaHalfSize - 2)
	local part = makePart("Enemy_" .. kind, stats.Color, Vector3.new(stats.Radius * 2, stats.Radius * 2, stats.Radius * 2), Vector3.new(pos.X, 1.5, pos.Z))
	if E.isBossKind(kind) then
		part.Shape = Enum.PartType.Block
		part.Size = if kind == "BossMaw" then Vector3.new(12, 3, 12) else Vector3.new(10, 3, 10)
		state.BossAlive = true
		state.BossHealth = stats.Health
		state.BossMaxHealth = stats.Health
	end
	table.insert(enemies, { Part = part, Kind = kind, Stats = stats, Health = stats.Health, ShootTimer = stats.ShootCooldown or 0, StrafeDir = 1, StrafeTimer = 0, ChargeTimer = 5, Charging = 0, DashState = "Approach", DashTimer = 0, DashDir = Vector3.zero, SpiralAngle = 0, ShockwaveTimer = stats.ShockwaveCooldown or 0, SpawnTimer = stats.SpawnCooldown or 0 })
end
local function spawnShards()
	for _ = 1, C.ShardQuota do
		local x = math.random(-50, 50) + math.random()
		local z = math.random(-50, 50) + math.random()
		local part = Instance.new("Part")
		part.Name = "Shard"
		part.Shape = Enum.PartType.Block
		part.Size = Vector3.new(1.8, 1.8, 1.8)
		part.Anchored = true
		part.CanCollide = false
		part.Material = Enum.Material.Neon
		part.Color = C.Palette.Yellow
		part.CFrame = CFrame.new(x, 1.5, z) * CFrame.Angles(0, math.rad(45), math.rad(45))
		part.Parent = Workspace
		table.insert(shards, { Part = part })
	end
end
local function startVault(n: number)
	state.Vault = n
	state.HitsThisVault = 0
	state.VaultScore = 0
	state.Shards = 0
	state.VaultStart = os.clock()
	state.VaultTime = 0
	state.EnemiesToSpawn = C.WaveBaseEnemyCount + C.WaveEnemyStep * n
	state.SpawnTimer = 0.5
	spawnShards()
	if E.isBossWave(n) then
		local boss = E.bossKindForWave(n)
		spawnEnemy(boss)
		sendEvent("Banner", "VAULT " .. n .. " · " .. vaultName(n) .. " — " .. (boss == "BossMaw" and "VOID MAW AWAKENS" or "VOID WARDEN AWAKENS"))
	else
		sendEvent("Banner", "VAULT " .. n .. " · " .. vaultName(n))
	end
	sendState()
end
local function dropCoins(position: Vector3, count: number)
	for _ = 1, count do
		local at = Vector3.new(M.clamp(position.X + math.random(-4, 4), -56, 56), 1.5, M.clamp(position.Z + math.random(-4, 4), -56, 56))
		local part = makePart("Coin", C.Palette.Yellow, Vector3.new(1.2, 1.2, 1.2), at)
		table.insert(coins, { Part = part, Value = C.CoinValue })
	end
end
local function dropPowerUp(position: Vector3)
	local kind = P.rollKind(state.Lives, C.PlayerMaxLives)
	local def = P.definition(kind)
	local part = makePart("PowerUp_" .. kind, def.Color, Vector3.new(2.4, 2.4, 2.4), Vector3.new(position.X, 1.5, position.Z))
	part.Shape = Enum.PartType.Block
	table.insert(powerUps, { Part = part, Kind = kind, ExpiresAt = os.clock() + C.PowerUpLifetimeSeconds })
end
local function awardScore(base: number, position: Vector3?)
	local mult = 1 + C.ComboStep * math.min(state.Combo, C.ComboMaxLevel)
	local points = math.floor(base * mult + 0.5)
	state.Score += points
	state.VaultScore += points
	state.Combo += 1
	state.ComboTimer = C.ComboWindowSeconds
	if position then sendEvent("ScorePopup", { Points = points, Position = position, Combo = state.Combo }) end
end
local function killEnemy(index: number, award: boolean)
	local enemy = enemies[index]
	if not enemy then return end
	local position = enemy.Part.Position
	local kind = enemy.Kind
	enemy.Part:Destroy()
	table.remove(enemies, index)
	if award then
		awardScore(enemy.Stats.Score, position)
		if kind == "Tank" then dropCoins(position, 3)
		elseif E.isBossKind(kind) then dropCoins(position, 10)
		elseif math.random() < 0.5 then dropCoins(position, 2)
		else dropCoins(position, 1) end
		if math.random() < C.PowerUpDropChance then dropPowerUp(position) end
	end
	sendEvent("EnemyDestroyed", { Kind = kind, Position = position })
	if kind == "Splitter" then
		for _ = 1, enemy.Stats.SplitInto do
			spawnEnemy("Mini", Vector3.new(position.X + math.random(-3, 3), 1.5, position.Z + math.random(-3, 3)))
		end
	elseif E.isBossKind(kind) then
		state.BossAlive = false
		sendEvent("Banner", kind == "BossMaw" and "VOID MAW DESTROYED!" or "VOID WARDEN DESTROYED!")
	end
end
local function detonateBomb()
	local victims = {}
	for i = #enemies, 1, -1 do
		if M.distance2D(enemies[i].Part.Position, state.PlayerPosition) <= C.BombRadius then table.insert(victims, i) end
	end
	for _, i in ipairs(victims) do killEnemy(i, true) end
	clearEntities(enemyBullets)
	sendEvent("Banner", "VOID BOMB!")
end
local function applyPowerUp(kind: P.PowerUpKind)
	local def = P.definition(kind)
	if kind == "Shield" then state.ShieldCharges = C.ShieldMaxCharges
	elseif kind == "RapidFire" then state.RapidFireUntil = os.clock() + C.RapidFireDurationSeconds
	elseif kind == "Bomb" then detonateBomb()
	elseif kind == "TripleShot" then state.TripleShotUntil = os.clock() + C.TripleShotDurationSeconds
	elseif kind == "ExtraLife" then state.Lives = math.min(state.Lives + 1, C.PlayerMaxLives)
	elseif kind == "CoinMagnet" then state.MagnetUntil = os.clock() + C.MagnetDurationSeconds end
	sendEvent("PowerUp", def.Hint)
	sendState()
end
local function gameOver(won: boolean)
	state.Phase = "GameOver"
	if state.Score > state.BestScore then state.BestScore = state.Score end
	if won then
		state.RaidsWon += 1
		sendEvent("RaidWon", { Score = state.Score, Vault = state.Vault, BestScore = state.BestScore, StarsTotal = state.StarsTotal, RaidsWon = state.RaidsWon })
	else
		sendEvent("GameOver", { Score = state.Score, Vault = state.Vault, BestScore = state.BestScore, StarsTotal = state.StarsTotal, Mode = state.Mode, RaidsWon = state.RaidsWon })
	end
	sendState()
end
local function damagePlayer()
	if os.clock() < state.InvulnerableUntil then return end
	if state.ShieldCharges > 0 then
		state.ShieldCharges = 0
		state.InvulnerableUntil = os.clock() + C.PlayerInvulnerableSeconds
		sendEvent("ShieldBreak", nil)
		sendState()
		return
	end
	state.Lives -= 1
	state.Combo = 0
	state.ComboTimer = 0
	state.HitsThisVault += 1
	state.InvulnerableUntil = os.clock() + C.PlayerInvulnerableSeconds
	sendEvent("PlayerHit", { Lives = state.Lives })
	if state.Lives <= 0 then gameOver(false) return end
	sendState()
end
local function spawnPlayerBullet(direction: Vector3)
	local origin = state.PlayerPosition + direction * 3
	local part = makePart("PlayerBullet", C.Palette.Yellow, Vector3.new(1.2, 1.2, 1.2), Vector3.new(origin.X, 1.5, origin.Z))
	table.insert(playerBullets, { Part = part, Velocity = direction * C.PlayerBulletSpeed, Damage = C.PlayerBulletDamage })
end
local function firePlayerBullet()
	local now = os.clock()
	local cd = if now < state.RapidFireUntil then C.PlayerRapidFireCooldown else C.PlayerFireCooldown
	if now - state.LastFireTime < cd then return end
	state.LastFireTime = now
	if now < state.TripleShotUntil then
		local f = state.PlayerFacing
		local function rot(a: number): Vector3
			local c = math.cos(a)
			local s = math.sin(a)
			return Vector3.new(f.X * c - f.Z * s, 0, f.X * s + f.Z * c)
		end
		spawnPlayerBullet(rot(-0.22))
		spawnPlayerBullet(f)
		spawnPlayerBullet(rot(0.22))
	else
		spawnPlayerBullet(state.PlayerFacing)
	end
end
local function fireEnemyBullet(from: Vector3, target: Vector3, speed: number)
	local part = makePart("EnemyBullet", C.Palette.Magenta, Vector3.new(1.5, 1.5, 1.5), Vector3.new(from.X, 1.5, from.Z))
	table.insert(enemyBullets, { Part = part, Velocity = M.directionTo(from, target) * speed })
end
local function fireRadialBurst(from: Vector3, count: number, speed: number, color: Color3)
	for i = 0, count - 1 do
		local a = i * (2 * math.pi / count)
		local part = makePart("EnemyBullet", color, Vector3.new(1.5, 1.5, 1.5), from)
		table.insert(enemyBullets, { Part = part, Velocity = Vector3.new(math.cos(a), 0, math.sin(a)) * speed })
	end
end
local function movePlayer(dt: number)
	local dir = state.MoveDirection
	if dir.X == 0 and dir.Y == 0 then return end
	local len = M.magnitude2D(dir.X, dir.Y)
	local nx = dir.X / len
	local nz = dir.Y / len
	local half = C.ArenaHalfSize - C.PlayerRadius
	state.PlayerPosition = Vector3.new(M.clamp(state.PlayerPosition.X + nx * C.PlayerSpeed * dt, -half, half), 1.5, M.clamp(state.PlayerPosition.Z + nz * C.PlayerSpeed * dt, -half, half))
	state.PlayerFacing = Vector3.new(nx, 0, nz)
	ship.CFrame = CFrame.new(state.PlayerPosition) * CFrame.Angles(0, math.atan2(-nx, -nz), 0)
end
local function clampToArena(position: Vector3): Vector3
	return Vector3.new(M.clamp(position.X, -58, 58), 1.5, M.clamp(position.Z, -58, 58))
end
local function stepEnemies(dt: number)
	for i = #enemies, 1, -1 do
		local enemy = enemies[i]
		local part = enemy.Part
		local stats = enemy.Stats
		local toPlayer = M.directionTo(part.Position, state.PlayerPosition)
		local dist = M.distance2D(part.Position, state.PlayerPosition)
		if enemy.Kind == "Chaser" or enemy.Kind == "Splitter" or enemy.Kind == "Mini" then
			local wob = if enemy.Kind == "Mini" then math.sin(os.clock() * 6 + i) * 0.6 else 0
			local mv = toPlayer * stats.Speed * dt
			part.Position = clampToArena(Vector3.new(part.Position.X + mv.X - toPlayer.Z * wob * dt, 1.5, part.Position.Z + mv.Z + toPlayer.X * wob * dt))
		elseif enemy.Kind == "Tank" then
			part.Position = clampToArena(part.Position + toPlayer * stats.Speed * dt)
			enemy.ShockwaveTimer -= dt
			if enemy.ShockwaveTimer <= 0 then
				enemy.ShockwaveTimer = stats.ShockwaveCooldown or 4
				fireRadialBurst(part.Position, 8, stats.BulletSpeed or 28, C.Palette.White)
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
					enemy.DashDir = M.directionTo(part.Position, state.PlayerPosition)
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
				if enemy.DashTimer <= 0 then enemy.DashState = "Approach" end
			end
		elseif enemy.Kind == "Shooter" or enemy.Kind == "Spiral" then
			enemy.StrafeTimer -= dt
			if enemy.StrafeTimer <= 0 then
				enemy.StrafeDir = -enemy.StrafeDir
				enemy.StrafeTimer = 2
			end
			local mx, mz = 0, 0
			local near = if enemy.Kind == "Shooter" then 14 else 16
			local far = if enemy.Kind == "Shooter" then 26 else 24
			if dist > far then mx, mz = toPlayer.X, toPlayer.Z
			elseif dist < near then mx, mz = -toPlayer.X, -toPlayer.Z
			else mx, mz = -toPlayer.Z * enemy.StrafeDir, toPlayer.X * enemy.StrafeDir end
			part.Position = clampToArena(Vector3.new(part.Position.X + mx * stats.Speed * dt, 1.5, part.Position.Z + mz * stats.Speed * dt))
			enemy.ShootTimer -= dt
			if enemy.ShootTimer <= 0 then
				enemy.ShootTimer = stats.ShootCooldown or 0.35
				if enemy.Kind == "Shooter" then
					if dist < 45 then fireEnemyBullet(part.Position, state.PlayerPosition, stats.BulletSpeed or 34) end
				else
					enemy.SpiralAngle += 0.45
					local dir = Vector3.new(math.cos(enemy.SpiralAngle), 0, math.sin(enemy.SpiralAngle))
					local b = makePart("EnemyBullet", C.Palette.Cyan, Vector3.new(1.5, 1.5, 1.5), part.Position)
					table.insert(enemyBullets, { Part = b, Velocity = dir * (stats.BulletSpeed or 28) })
				end
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
				fireRadialBurst(part.Position, 8, stats.BulletSpeed or 30, C.Palette.Red)
			end
		elseif enemy.Kind == "BossMaw" then
			part.Position = clampToArena(part.Position + toPlayer * stats.Speed * dt)
			enemy.ShootTimer -= dt
			if enemy.ShootTimer <= 0 then
				enemy.ShootTimer = stats.ShootCooldown or 2
				enemy.SpiralAngle += 0.6
				for k = 0, 5 do
					local a = enemy.SpiralAngle + k * (2 * math.pi / 6)
					local b = makePart("EnemyBullet", C.Palette.Green, Vector3.new(1.5, 1.5, 1.5), part.Position)
					table.insert(enemyBullets, { Part = b, Velocity = Vector3.new(math.cos(a), 0, math.sin(a)) * (stats.BulletSpeed or 28) })
				end
			end
			enemy.SpawnTimer -= dt
			if enemy.SpawnTimer <= 0 and #enemies < C.WaveMaxAlive then
				enemy.SpawnTimer = stats.SpawnCooldown or 4
				spawnEnemy("Mini", Vector3.new(part.Position.X + 6, 1.5, part.Position.Z))
				spawnEnemy("Mini", Vector3.new(part.Position.X - 6, 1.5, part.Position.Z))
				sendEvent("Banner", "THE MAW SPAWNS MINIS!")
			end
		end
		if M.distance2D(part.Position, state.PlayerPosition) < stats.Radius + C.PlayerRadius then
			damagePlayer()
			if not E.isBossKind(enemy.Kind) then killEnemy(i, false) end
		end
	end
end
local function stepBullets(dt: number)
	for i = #playerBullets, 1, -1 do
		local b = playerBullets[i]
		local part = b.Part
		part.Position += b.Velocity * dt
		local out = math.abs(part.Position.X) > 62 or math.abs(part.Position.Z) > 62
		local hit = false
		if not out then
			for j = #enemies, 1, -1 do
				local enemy = enemies[j]
				if M.distance2D(part.Position, enemy.Part.Position) < enemy.Stats.Radius + C.BulletRadius then
					enemy.Health -= b.Damage
					hit = true
					sendEvent("EnemyHit", { Position = enemy.Part.Position })
					if enemy.Health <= 0 then
						if E.isBossKind(enemy.Kind) then state.BossHealth = 0 end
						killEnemy(j, true)
					elseif E.isBossKind(enemy.Kind) then
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
		local b = enemyBullets[i]
		local part = b.Part
		part.Position += b.Velocity * dt
		local out = math.abs(part.Position.X) > 62 or math.abs(part.Position.Z) > 62
		local hitPlayer = not out and M.distance2D(part.Position, state.PlayerPosition) < C.PlayerRadius + C.BulletRadius
		if out or hitPlayer then
			part:Destroy()
			table.remove(enemyBullets, i)
			if hitPlayer then damagePlayer() end
		end
	end
end
local function stepPowerUps(dt: number)
	local now = os.clock()
	for i = #powerUps, 1, -1 do
		local p = powerUps[i]
		if now > p.ExpiresAt then
			p.Part:Destroy()
			table.remove(powerUps, i)
		elseif M.distance2D(p.Part.Position, state.PlayerPosition) < C.PlayerRadius + 2 then
			local kind = p.Kind
			p.Part:Destroy()
			table.remove(powerUps, i)
			applyPowerUp(kind)
		end
	end
end
local function stepCoins(dt: number)
	local magnet = os.clock() < state.MagnetUntil
	for i = #coins, 1, -1 do
		local coin = coins[i]
		local dist = M.distance2D(coin.Part.Position, state.PlayerPosition)
		if magnet and dist < C.CoinMagnetRadius and dist > 0.5 then
			coin.Part.Position += M.directionTo(coin.Part.Position, state.PlayerPosition) * C.CoinMagnetSpeed * dt
			dist = M.distance2D(coin.Part.Position, state.PlayerPosition)
		end
		if dist < C.PlayerRadius + 2 then
			state.Coins += coin.Value
			state.Score += coin.Value
			coin.Part:Destroy()
			table.remove(coins, i)
		end
	end
end
local function stepShards(dt: number)
	local magnet = os.clock() < state.MagnetUntil
	for i = #shards, 1, -1 do
		local s = shards[i]
		local dist = M.distance2D(s.Part.Position, state.PlayerPosition)
		if magnet and dist < C.CoinMagnetRadius and dist > 0.5 then
			s.Part.Position += M.directionTo(s.Part.Position, state.PlayerPosition) * C.CoinMagnetSpeed * dt
			dist = M.distance2D(s.Part.Position, state.PlayerPosition)
		end
		if dist < C.PlayerRadius + 2 then
			state.Shards += 1
			state.Score += C.ShardValue
			state.VaultScore += C.ShardValue
			s.Part:Destroy()
			table.remove(shards, i)
		end
	end
end
local function stepSpawning(dt: number)
	if state.EnemiesToSpawn <= 0 then return end
	state.SpawnTimer -= dt
	if state.SpawnTimer > 0 or #enemies >= C.WaveMaxAlive then return end
	state.SpawnTimer = 0.9
	state.EnemiesToSpawn -= 1
	local kinds = E.kindsForWave(state.Vault)
	spawnEnemy(kinds[math.random(1, #kinds)])
end
local function starsForVault(): number
	if state.HitsThisVault == 0 then return 3 elseif state.HitsThisVault <= 1 then return 2 else return 1 end
end
local function vaultClear()
	local seconds = math.floor(os.clock() - state.VaultStart)
	local timeBonus = math.max(0, 900 - seconds * 15)
	local noHit = if state.HitsThisVault == 0 then 1000 else 0
	local total = state.VaultScore + timeBonus + noHit
	state.Score += timeBonus + noHit
	local stars = starsForVault()
	state.StarsTotal += stars
	clearEntities(playerBullets)
	clearEntities(enemyBullets)
	if state.Mode == "Raid" and state.Vault >= C.VaultCount then
		gameOver(true)
		return
	end
	state.Phase = "VaultClear"
	state.ClearTimer = C.VaultClearSeconds
	sendEvent("VaultClear", { Vault = state.Vault, Name = vaultName(state.Vault), VaultScore = state.VaultScore, TimeBonus = timeBonus, NoHitBonus = noHit, Total = total, Stars = stars })
	sendState()
end
local function updatePlaying(dt: number)
	state.VaultTime = os.clock() - state.VaultStart
	movePlayer(dt)
	stepSpawning(dt)
	stepEnemies(dt)
	stepBullets(dt)
	stepPowerUps(dt)
	stepCoins(dt)
	stepShards(dt)
	if state.ComboTimer > 0 then
		state.ComboTimer -= dt
		if state.ComboTimer <= 0 then state.Combo = 0 end
	end
	state.StateSendTimer -= dt
	if state.StateSendTimer <= 0 then
		state.StateSendTimer = 0.1
		sendState()
	end
	if state.Phase ~= "Playing" then return end
	if state.EnemiesToSpawn == 0 and #enemies == 0 and not state.BossAlive and state.Shards >= C.ShardQuota then
		vaultClear()
	end
end
local function updateVaultClear(dt: number)
	movePlayer(dt)
	stepPowerUps(dt)
	stepCoins(dt)
	state.ClearTimer -= dt
	if state.ClearTimer <= 0 then
		startVault(state.Vault + 1)
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
	if state.Phase == "Playing" then updatePlaying(dt)
	elseif state.Phase == "VaultClear" then updateVaultClear(dt) end
end
local function startRun(mode: string)
	resetRun()
	state.Mode = if mode == "Endless" then "Endless" else "Raid"
	state.Phase = "Playing"
	sendEvent("Banner", if state.Mode == "Endless" then "ENDLESS — THE VOID NEVER ENDS" else "RAID THE VAULTS")
	startVault(1)
	sendState()
end
local function bindRemotes()
	remotes.StartGame.OnServerEvent:Connect(function(player: Player, mode: string?)
		if state.Phase == "Paused" then
			resetRun()
			state.Phase = "Lobby"
			sendState()
			return
		end
		if mode == "Title" then
			resetRun()
			state.Phase = "Lobby"
			sendState()
			return
		end
		if state.Phase ~= "Lobby" and state.Phase ~= "GameOver" then return end
		startRun(mode or "Raid")
	end)
	remotes.RestartGame.OnServerEvent:Connect(function(player: Player)
		if state.Phase ~= "GameOver" then return end
		startRun(state.Mode)
	end)
	remotes.PauseGame.OnServerEvent:Connect(function(player: Player)
		if state.Phase ~= "Playing" then return end
		state.Phase = "Paused"
		sendState()
	end)
	remotes.ResumeGame.OnServerEvent:Connect(function(player: Player)
		if state.Phase ~= "Paused" then return end
		state.Phase = "Playing"
		sendState()
	end)
	remotes.ContinueVault.OnServerEvent:Connect(function(player: Player)
		if state.Phase ~= "VaultClear" then return end
		startVault(state.Vault + 1)
		state.Phase = "Playing"
		sendState()
	end)
	remotes.MoveInput.OnServerEvent:Connect(function(player: Player, direction: Vector2)
		if state.Phase ~= "Playing" and state.Phase ~= "VaultClear" then return end
		local len = M.magnitude2D(direction.X, direction.Y)
		if len > 1 then direction = direction / len end
		state.MoveDirection = direction
	end)
	remotes.FireRequest.OnServerEvent:Connect(function(player: Player)
		if state.Phase ~= "Playing" then return end
		firePlayerBullet()
	end)
	remotes.DashRequest.OnServerEvent:Connect(function(player: Player)
		if state.Phase ~= "Playing" then return end
		local now = os.clock()
		if now < state.DashReadyAt then return end
		state.DashReadyAt = now + C.DashCooldown
		state.InvulnerableUntil = now + C.DashInvuln
		local half = C.ArenaHalfSize - C.PlayerRadius
		local f = state.PlayerFacing
		state.PlayerPosition = Vector3.new(M.clamp(state.PlayerPosition.X + f.X * C.DashDistance, -half, half), 1.5, M.clamp(state.PlayerPosition.Z + f.Z * C.DashDistance, -half, half))
		ship.CFrame = CFrame.new(state.PlayerPosition) * CFrame.Angles(0, math.atan2(-f.X, -f.Z), 0)
		sendEvent("Dash", nil)
		sendState()
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
		if state.Phase ~= "Playing" and state.Phase ~= "VaultClear" then return end
		local okStep, errStep = pcall(update, dt)
		if not okStep then warn("[NeonVoid] update failed: " .. tostring(errStep)) end
	end)
end
return GameServer
