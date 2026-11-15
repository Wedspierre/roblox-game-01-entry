-- PowerUpCatalog: the six pickups that drop from defeated enemies.
-- Each entry names its effect, its color and the line the HUD shows
-- when the player collects it. Drop weights make shields the most
-- common find and extra lives the rarest; an extra life never drops
-- while the ship is already at full lives.

local NeonConfig = require(script.Parent.NeonConfig)

export type PowerUpKind = "Shield" | "RapidFire" | "Bomb" | "TripleShot" | "ExtraLife" | "CoinMagnet"

export type PowerUpDef = {
	Kind: PowerUpKind,
	Label: string,
	Color: Color3,
	Hint: string,
}

local PowerUpCatalog = {}

local DEFS: { [PowerUpKind]: PowerUpDef } = {
	Shield = {
		Kind = "Shield",
		Label = "SHIELD",
		Color = NeonConfig.Palette.Cyan,
		Hint = "Shield up — absorbs the next hit",
	},
	RapidFire = {
		Kind = "RapidFire",
		Label = "RAPID FIRE",
		Color = NeonConfig.Palette.Yellow,
		Hint = "Rapid fire — double shot speed for 10s",
	},
	Bomb = {
		Kind = "Bomb",
		Label = "VOID BOMB",
		Color = NeonConfig.Palette.White,
		Hint = "Void bomb — wipes every enemy on screen",
	},
	TripleShot = {
		Kind = "TripleShot",
		Label = "TRIPLE SHOT",
		Color = NeonConfig.Palette.Magenta,
		Hint = "Triple shot — three-way spread for 12s",
	},
	ExtraLife = {
		Kind = "ExtraLife",
		Label = "+1 LIFE",
		Color = NeonConfig.Palette.Green,
		Hint = "Extra life — one more chance",
	},
	CoinMagnet = {
		Kind = "CoinMagnet",
		Label = "COIN MAGNET",
		Color = NeonConfig.Palette.Orange,
		Hint = "Coin magnet — coins fly to you for 12s",
	},
}

local ORDER: { PowerUpKind } = { "Shield", "RapidFire", "Bomb", "TripleShot", "ExtraLife", "CoinMagnet" }

-- Drop weights, in the same order as ORDER; they must add to 1.
local WEIGHTS: { number } = { 0.28, 0.22, 0.12, 0.15, 0.08, 0.15 }

function PowerUpCatalog.allKinds(): { PowerUpKind }
	return ORDER
end

function PowerUpCatalog.definition(kind: PowerUpKind): PowerUpDef
	return DEFS[kind]
end

-- Weighted roll. When the ship is at full lives, an extra life
-- re-rolls into a shield instead of wasting the drop.
function PowerUpCatalog.rollKind(lives: number, maxLives: number): PowerUpKind
	local roll = math.random()
	local acc = 0
	for i, weight in ipairs(WEIGHTS) do
		acc += weight
		if roll < acc then
			local kind = ORDER[i]
			if kind == "ExtraLife" and lives >= maxLives then
				return "Shield"
			end
			return kind
		end
	end
	return "Shield"
end

return PowerUpCatalog
