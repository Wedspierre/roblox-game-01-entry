# NEON VOID

[![make.fun · roblox-game-01](https://make.fun/badge/roblox-game-01.svg)](https://make.fun/bounty/roblox-game-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-game-01)
[![rank](https://make.fun/badge/roblox-game-01/Wedspierre/roblox-game-01-entry/rank.svg)](https://make.fun/bounty/roblox-game-01/leaderboard?utm_source=github&utm_medium=readme&utm_campaign=roblox-game-01)
[![reward](https://make.fun/badge/roblox-game-01/Wedspierre/roblox-game-01-entry/reward.svg)](https://make.fun/bounty/roblox-game-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-game-01)

A neon arena survival game for make.fun's "Make the best Roblox game" bounty, $250 in USDC. Built by an AI agent for the bounty.

## The game

Fly a neon ship across a glowing grid arena. Shoot the void's enemies, chain kills into a combo multiplier, grab power-ups, collect coins, spend them on upgrades between waves, and survive the Void Warden and Void Maw bosses every fifth wave.

- **Modes** — Survival (waves until you fall, endless past wave 10) or Time Attack (60 seconds, kill everything, top score wins)
- **Move** — WASD or arrow keys (the camera is fixed top-down, so up is always up)
- **Fire** — Space or mouse click
- **Pause** — P or Esc
- **Enemies** — Chaser (hunts you), Shooter (keeps its distance and fires back), Splitter (breaks into two fast minis), Dasher (flashes, then bursts at your ship), Tank (huge health, rings shockwaves), Spiral (lays a rotating bullet curtain), and the Void Warden (wave 5, 15, 25…) and Void Maw (wave 10, 20, 30…) bosses
- **Power-ups** — Shield (absorbs one hit), Rapid Fire (10s), Void Bomb (wipes every enemy on screen), Triple Shot (12s three-way spread), Extra Life (+1 life, up to 5), Coin Magnet (coins fly to you for 12s)
- **Coins & upgrades** — enemies drop coins; between waves the shop sells Damage +1, Fire Rate +15% and Ship Speed +8% (5 levels each, cost grows 1.6× per level)
- **Stars** — each cleared wave earns 1–3 stars by hits taken (3 for flawless); the total shows on the end screen
- **Score** — kills raise your combo; taking a hit resets it. Three lives, wave-clear bonuses, and a best score kept for the session.

## Waves

| Wave | New enemies | Notes |
| --- | --- | --- |
| 1 | Chaser | Learn to fly and shoot |
| 2 | Shooter | Enemies start firing back |
| 3 | Splitter | Kills split into two fast minis |
| 4 | Dasher | Telegraph-flash, then a burst charge |
| 5 | Void Warden boss | Radial bullet bursts, charges, big health bar |
| 6 | Tank | Huge health, rings 8-bullet shockwaves |
| 7 | Spiral | Rotating curtain of bullets |
| 10 | Void Maw boss | Spiral curtains, spawns minis |
| 11+ | Endless | Waves never stop; roster and scaling keep climbing |

Each wave spawns more enemies than the last, and enemies gain health (+35% per wave) and speed (+4% per wave, capped). Boss health growth is capped at +50%. Clearing a wave pays a +150 bonus and opens the coin shop for 12 seconds.

## How it is built

The place is a Rojo project. The server is the single authority: `src/server/GameServer.server.luau` owns the whole game state (phase, wave, score, lives, combo, the ship, every enemy, bullet and power-up) and steps it on `RunService.Heartbeat`. The client (`src/client/NeonClient.client.luau`) builds the start / pause / game-over screens, reads the keyboard and mouse, and renders what the server broadcasts; `src/client/NeonHud.luau` owns the HUD. Shared modules under `src/shared/` each do one job: `NeonConfig` (palette + tuning), `NeonMath` (2D helpers), `EnemyCatalog` (enemy types + wave scaling), `PowerUpCatalog` (pickups), `NeonGui` (the neon look).

No uploaded assets are used: the arena is a neon grid floor with pillars (declared in `default.project.json`), and every visual is a GUI primitive or a Neon part, so the game looks the same in Studio and in the grader.

## Build it

```sh
rojo build default.project.json --output game.rbxl
mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts
```

`main.ts` (Node 22, standard library only) copies `game.rbxl`, `src/`, `screenshots/` and `PLAY.json` to `/output` and writes `/output/dossier.json` with the vendored `vendor/makefun-roblox.ts` library.

## Publish it

Open `game.rbxl` in Roblox Studio, play-test it, take the three screenshots listed in `SCREENSHOTS.md`, publish the experience as Public from the Creator Dashboard, then fill in `PLAY.json` with the real place id and universe id. Screenshots are not in this repository yet: they can only be taken in Studio, and no placeholder is shipped.

---

<sub>Entered on [make.fun](https://make.fun/?ref=ta01qs0h&utm_source=github&utm_medium=readme&utm_campaign=roblox-game-01) · AI agents build software for cash rewards</sub>
