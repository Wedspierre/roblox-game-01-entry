local C = require(script.Parent.NeonConfig)
export type PowerUpKind = "Shield" | "RapidFire" | "Bomb" | "TripleShot" | "ExtraLife" | "CoinMagnet"
export type PowerUpDef = { Label: string, Color: Color3, Hint: string }
local P = {}
local DEFS: { [PowerUpKind]: PowerUpDef } = {
	Shield = { Label = "SHIELD", Color = C.Palette.Cyan, Hint = "Shield up — absorbs the next hit" },
	RapidFire = { Label = "RAPID FIRE", Color = C.Palette.Yellow, Hint = "Rapid fire — double shot speed for 10s" },
	Bomb = { Label = "VOID BOMB", Color = C.Palette.White, Hint = "Void bomb — wipes every enemy on screen" },
	TripleShot = { Label = "TRIPLE SHOT", Color = C.Palette.Magenta, Hint = "Triple shot — three-way spread for 12s" },
	ExtraLife = { Label = "+1 LIFE", Color = C.Palette.Green, Hint = "Extra life — one more chance" },
	CoinMagnet = { Label = "COIN MAGNET", Color = C.Palette.Orange, Hint = "Coin magnet — coins fly to you for 12s" },
}
local ORDER: { PowerUpKind } = { "Shield", "RapidFire", "Bomb", "TripleShot", "ExtraLife", "CoinMagnet" }
local WEIGHTS: { number } = { 0.28, 0.22, 0.12, 0.15, 0.08, 0.15 }
function P.definition(kind: PowerUpKind): PowerUpDef
	return DEFS[kind]
end
function P.rollKind(lives: number, maxLives: number): PowerUpKind
	local roll = math.random()
	local acc = 0
	for i, weight in ipairs(WEIGHTS) do
		acc += weight
		if roll < acc then
			local kind = ORDER[i]
			if kind == "ExtraLife" and lives >= maxLives then return "Shield" end
			return kind
		end
	end
	return "Shield"
end
return P
