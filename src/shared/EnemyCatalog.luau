local C = require(script.Parent.NeonConfig)
export type EnemyKind = "Chaser" | "Shooter" | "Splitter" | "Mini" | "Tank" | "Dasher" | "Spiral" | "BossWarden" | "BossMaw"
local E = {}
local BASE = {
	Chaser = { Kind = "Chaser", Color = C.Palette.Magenta, Health = 2, Speed = 16, Radius = 2.2, Score = 100, SplitInto = 0 },
	Shooter = { Kind = "Shooter", Color = C.Palette.Orange, Health = 2, Speed = 11, Radius = 2.2, Score = 150, ShootCooldown = 2.2, BulletSpeed = 34, SplitInto = 0 },
	Splitter = { Kind = "Splitter", Color = C.Palette.Purple, Health = 3, Speed = 9, Radius = 2.8, Score = 150, SplitInto = 2 },
	Mini = { Kind = "Mini", Color = Color3.fromRGB(255, 110, 220), Health = 1, Speed = 22, Radius = 1.4, Score = 50, SplitInto = 0 },
	Tank = { Kind = "Tank", Color = Color3.fromRGB(150, 160, 190), Health = 10, Speed = 6, Radius = 3.6, Score = 250, BulletSpeed = 28, SplitInto = 0, ShockwaveCooldown = 4 },
	Dasher = { Kind = "Dasher", Color = C.Palette.Yellow, Health = 1, Speed = 14, Radius = 1.8, Score = 150, SplitInto = 0, DashCooldown = 2.5 },
	Spiral = { Kind = "Spiral", Color = Color3.fromRGB(0, 200, 255), Health = 3, Speed = 10, Radius = 2.2, Score = 200, ShootCooldown = 0.35, BulletSpeed = 28, SplitInto = 0 },
	BossWarden = { Kind = "BossWarden", Color = C.Palette.Red, Health = 60, Speed = 8, Radius = 5, Score = 2000, ShootCooldown = 1.6, BulletSpeed = 30, SplitInto = 0 },
	BossMaw = { Kind = "BossMaw", Color = C.Palette.Green, Health = 80, Speed = 6, Radius = 6, Score = 3000, ShootCooldown = 2, BulletSpeed = 28, SplitInto = 0, SpawnCooldown = 4 },
}
function E.kindsForWave(wave: number): { EnemyKind }
	local kinds: { EnemyKind } = { "Chaser" }
	if wave >= 2 then table.insert(kinds, "Shooter") end
	if wave >= 3 then table.insert(kinds, "Splitter") end
	if wave >= 4 then table.insert(kinds, "Dasher") end
	if wave >= 6 then table.insert(kinds, "Tank") end
	if wave >= 7 then table.insert(kinds, "Spiral") end
	return kinds
end
function E.isBossWave(wave: number): boolean
	return wave % C.BossEveryNWaves == 0
end
function E.bossKindForWave(wave: number): EnemyKind
	if wave % (C.BossEveryNWaves * 2) == 0 then return "BossMaw" else return "BossWarden" end
end
function E.isBossKind(kind: EnemyKind): boolean
	return kind == "BossWarden" or kind == "BossMaw"
end
function E.makeStats(kind: EnemyKind, wave: number)
	local b = BASE[kind]
	local hs = 1 + C.EnemyHealthPerWave * (wave - 1)
	if E.isBossKind(kind) then hs = math.min(hs, 1.5) end
	local ss = math.min(1.6, 1 + C.EnemySpeedPerWave * (wave - 1))
	return { Kind = b.Kind, Color = b.Color, Health = math.max(1, math.floor(b.Health * hs + 0.5)), Speed = b.Speed * ss, Radius = b.Radius, Score = b.Score, ShootCooldown = b.ShootCooldown, BulletSpeed = b.BulletSpeed, SplitInto = b.SplitInto, ShockwaveCooldown = b.ShockwaveCooldown, DashCooldown = b.DashCooldown, SpawnCooldown = b.SpawnCooldown }
end
function E.displayColor(kind: EnemyKind): Color3
	return BASE[kind].Color
end
return E
