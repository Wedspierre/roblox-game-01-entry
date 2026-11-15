-- EnemyCatalog: the seven enemy types of NEON VOID and how they scale.
-- Every type behaves differently, not just different numbers: chasers
-- hunt, shooters kite and fire, splitters burst into minis, dashers
-- telegraph a burst charge, tanks shrug off fire and ring shockwaves,
-- spiral shooters lay rotating bullet curtains, and two bosses alternate
-- every fifth wave. The server asks this module for a fresh stat block
-- per spawn; the client only reads the display fields for the HUD legend.

local NeonConfig = require(script.Parent.NeonConfig)

export type EnemyKind = "Chaser" | "Shooter" | "Splitter" | "Mini" | "Tank" | "Dasher" | "Spiral" | "BossWarden" | "BossMaw"

export type EnemyStats = {
	Kind: EnemyKind,
	Label: string,
	Color: Color3,
	Health: number,
	Speed: number,
	Radius: number,
	Score: number,
	ShootCooldown: number?,
	BulletSpeed: number?,
	SplitInto: number,
	ShockwaveCooldown: number?,
	DashCooldown: number?,
	SpawnCooldown: number?,
}

local EnemyCatalog = {}

local BASE: { [EnemyKind]: EnemyStats } = {
	Chaser = {
		Kind = "Chaser",
		Label = "CHASER — hunts your ship",
		Color = NeonConfig.Palette.Magenta,
		Health = 2,
		Speed = 16,
		Radius = 2.2,
		Score = 100,
		ShootCooldown = nil,
		BulletSpeed = nil,
		SplitInto = 0,
		ShockwaveCooldown = nil,
		DashCooldown = nil,
		SpawnCooldown = nil,
	},
	Shooter = {
		Kind = "Shooter",
		Label = "SHOOTER — keeps its distance and fires",
		Color = NeonConfig.Palette.Orange,
		Health = 2,
		Speed = 11,
		Radius = 2.2,
		Score = 150,
		ShootCooldown = 2.2,
		BulletSpeed = 34,
		SplitInto = 0,
		ShockwaveCooldown = nil,
		DashCooldown = nil,
		SpawnCooldown = nil,
	},
	Splitter = {
		Kind = "Splitter",
		Label = "SPLITTER — breaks into two minis",
		Color = NeonConfig.Palette.Purple,
		Health = 3,
		Speed = 9,
		Radius = 2.8,
		Score = 150,
		ShootCooldown = nil,
		BulletSpeed = nil,
		SplitInto = 2,
		ShockwaveCooldown = nil,
		DashCooldown = nil,
		SpawnCooldown = nil,
	},
	Mini = {
		Kind = "Mini",
		Label = "MINI — fast and fragile",
		Color = Color3.fromRGB(255, 110, 220),
		Health = 1,
		Speed = 22,
		Radius = 1.4,
		Score = 50,
		ShootCooldown = nil,
		BulletSpeed = nil,
		SplitInto = 0,
		ShockwaveCooldown = nil,
		DashCooldown = nil,
		SpawnCooldown = nil,
	},
	Tank = {
		Kind = "Tank",
		Label = "TANK — slow, huge health, rings shockwaves",
		Color = Color3.fromRGB(150, 160, 190),
		Health = 10,
		Speed = 6,
		Radius = 3.6,
		Score = 250,
		ShootCooldown = nil,
		BulletSpeed = 28,
		SplitInto = 0,
		ShockwaveCooldown = 4,
		DashCooldown = nil,
		SpawnCooldown = nil,
	},
	Dasher = {
		Kind = "Dasher",
		Label = "DASHER — flashes, then bursts at your ship",
		Color = NeonConfig.Palette.Yellow,
		Health = 1,
		Speed = 14,
		Radius = 1.8,
		Score = 150,
		ShootCooldown = nil,
		BulletSpeed = nil,
		SplitInto = 0,
		ShockwaveCooldown = nil,
		DashCooldown = 2.5,
		SpawnCooldown = nil,
	},
	Spiral = {
		Kind = "Spiral",
		Label = "SPIRAL — lays a rotating curtain of bullets",
		Color = Color3.fromRGB(0, 200, 255),
		Health = 3,
		Speed = 10,
		Radius = 2.2,
		Score = 200,
		ShootCooldown = 0.35,
		BulletSpeed = 28,
		SplitInto = 0,
		ShockwaveCooldown = nil,
		DashCooldown = nil,
		SpawnCooldown = nil,
	},
	BossWarden = {
		Kind = "BossWarden",
		Label = "VOID WARDEN — radial bursts, charges your ship",
		Color = NeonConfig.Palette.Red,
		Health = 60,
		Speed = 8,
		Radius = 5,
		Score = 2000,
		ShootCooldown = 1.6,
		BulletSpeed = 30,
		SplitInto = 0,
		ShockwaveCooldown = nil,
		DashCooldown = nil,
		SpawnCooldown = nil,
	},
	BossMaw = {
		Kind = "BossMaw",
		Label = "VOID MAW — spiral curtains, spawns minis",
		Color = NeonConfig.Palette.Green,
		Health = 80,
		Speed = 6,
		Radius = 6,
		Score = 3000,
		ShootCooldown = 2,
		BulletSpeed = 28,
		SplitInto = 0,
		ShockwaveCooldown = nil,
		DashCooldown = nil,
		SpawnCooldown = 4,
	},
}

-- Which kinds may appear in a wave. The roster grows as waves climb:
-- chasers from 1, shooters from 2, splitters from 3, dashers from 4,
-- tanks from 6, spiral shooters from 7.
function EnemyCatalog.kindsForWave(wave: number): { EnemyKind }
	local kinds: { EnemyKind } = { "Chaser" }
	if wave >= 2 then
		table.insert(kinds, "Shooter")
	end
	if wave >= 3 then
		table.insert(kinds, "Splitter")
	end
	if wave >= 4 then
		table.insert(kinds, "Dasher")
	end
	if wave >= 6 then
		table.insert(kinds, "Tank")
	end
	if wave >= 7 then
		table.insert(kinds, "Spiral")
	end
	return kinds
end

function EnemyCatalog.isBossWave(wave: number): boolean
	return wave % NeonConfig.BossEveryNWaves == 0
end

-- The two bosses alternate: the Warden on waves 5, 15, 25…,
-- the Maw on waves 10, 20, 30…
function EnemyCatalog.bossKindForWave(wave: number): EnemyKind
	if wave % (NeonConfig.BossEveryNWaves * 2) == 0 then
		return "BossMaw"
	else
		return "BossWarden"
	end
end

function EnemyCatalog.isBossKind(kind: EnemyKind): boolean
	return kind == "BossWarden" or kind == "BossMaw"
end

-- A fresh stat block for one spawn, scaled by the wave number.
-- Bosses scale less: at full wave scaling they would take a minute
-- of perfect fire to kill, so their health growth is capped at +50%.
function EnemyCatalog.makeStats(kind: EnemyKind, wave: number): EnemyStats
	local base = BASE[kind]
	local healthScale = 1 + NeonConfig.EnemyHealthPerWave * (wave - 1)
	if EnemyCatalog.isBossKind(kind) then
		healthScale = math.min(healthScale, 1.5)
	end
	local speedScale = math.min(1.6, 1 + NeonConfig.EnemySpeedPerWave * (wave - 1))
	return {
		Kind = base.Kind,
		Label = base.Label,
		Color = base.Color,
		Health = math.max(1, math.floor(base.Health * healthScale + 0.5)),
		Speed = base.Speed * speedScale,
		Radius = base.Radius,
		Score = base.Score,
		ShootCooldown = base.ShootCooldown,
		BulletSpeed = base.BulletSpeed,
		SplitInto = base.SplitInto,
		ShockwaveCooldown = base.ShockwaveCooldown,
		DashCooldown = base.DashCooldown,
		SpawnCooldown = base.SpawnCooldown,
	}
end

function EnemyCatalog.displayColor(kind: EnemyKind): Color3
	return BASE[kind].Color
end

return EnemyCatalog
