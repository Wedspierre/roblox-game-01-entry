-- NeonConfig: every tuning number of NEON VOID in one place.
-- The server and the client both require this module so the arena,
-- the speeds and the scoring never drift apart between the two sides.

local NeonConfig = {}

-- Neon palette on a near-black background.
NeonConfig.Palette = {
	Background = Color3.fromRGB(6, 6, 18),
	Arena = Color3.fromRGB(10, 10, 32),
	Cyan = Color3.fromRGB(0, 240, 255),
	Magenta = Color3.fromRGB(255, 0, 170),
	Yellow = Color3.fromRGB(255, 230, 0),
	White = Color3.fromRGB(235, 245, 255),
	Red = Color3.fromRGB(255, 45, 85),
	Green = Color3.fromRGB(0, 255, 150),
	Orange = Color3.fromRGB(255, 140, 0),
	Purple = Color3.fromRGB(180, 80, 255),
	DimText = Color3.fromRGB(140, 160, 200),
}

-- The playfield. The ship and every enemy live inside this square.
NeonConfig.ArenaHalfSize = 56
NeonConfig.ArenaFloorY = 0

-- Player ship.
NeonConfig.PlayerSpeed = 42 -- studs per second
NeonConfig.PlayerRadius = 2.4
NeonConfig.PlayerStartLives = 3
NeonConfig.PlayerMaxLives = 5 -- Extra Life pickups can raise lives this far
NeonConfig.PlayerInvulnerableSeconds = 2
NeonConfig.PlayerFireCooldown = 0.28 -- seconds between shots
NeonConfig.PlayerRapidFireCooldown = 0.12
NeonConfig.PlayerBulletSpeed = 90
NeonConfig.PlayerBulletDamage = 1

-- Coins and between-wave upgrades. Coins drop from defeated enemies;
-- the shop between waves spends them on permanent run upgrades.
NeonConfig.CoinValue = 5
NeonConfig.CoinMagnetRadius = 18
NeonConfig.CoinMagnetSpeed = 42
NeonConfig.ShopDurationSeconds = 12
NeonConfig.Upgrades = {
	Damage = { Label = "DAMAGE +1", BaseCost = 40, MaxLevel = 5, CostGrowth = 1.6 },
	FireRate = { Label = "FIRE RATE +15%", BaseCost = 35, MaxLevel = 5, CostGrowth = 1.6 },
	Speed = { Label = "SHIP SPEED +8%", BaseCost = 30, MaxLevel = 5, CostGrowth = 1.6 },
}

-- Modes. Survival runs waves until the ship dies (endless past wave 10);
-- Time Attack is a 60-second score rush with endless spawning.
NeonConfig.TimeAttackSeconds = 60
NeonConfig.EndlessStartsAtWave = 11

-- Waves. Each wave spawns more enemies and tougher ones.
NeonConfig.WaveBaseEnemyCount = 4
NeonConfig.WaveEnemyStep = 2
NeonConfig.WaveMaxAlive = 22
NeonConfig.WaveClearBonus = 150
NeonConfig.BossEveryNWaves = 5
NeonConfig.EnemyHealthPerWave = 0.35 -- +35% health per wave, compounded
NeonConfig.EnemySpeedPerWave = 0.04 -- +4% speed per wave, capped below

-- Scoring and combo. A kill raises the combo; taking a hit resets it.
NeonConfig.ComboWindowSeconds = 5
NeonConfig.ComboStep = 0.5 -- each combo level adds +50% score
NeonConfig.ComboMaxLevel = 8

-- Power-ups.
NeonConfig.PowerUpDropChance = 0.16 -- per enemy killed
NeonConfig.PowerUpLifetimeSeconds = 12
NeonConfig.RapidFireDurationSeconds = 10
NeonConfig.TripleShotDurationSeconds = 12
NeonConfig.MagnetDurationSeconds = 12
NeonConfig.ShieldMaxCharges = 1
NeonConfig.BombRadius = 60 -- studs; everything inside it dies

-- The bullet's collision radius, shared by the player and enemy shots.
NeonConfig.BulletRadius = 1

-- Networking. The client sends its move direction this often at most.
NeonConfig.MoveSendInterval = 1 / 15

-- Camera. Fixed angled top-down view of the whole arena.
NeonConfig.CameraPosition = Vector3.new(0, 88, 62)
NeonConfig.CameraLookAt = Vector3.new(0, 0, -4)

return NeonConfig
