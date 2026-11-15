# Screenshots — to be taken in Roblox Studio

`screenshots/` is intentionally empty in this repository: no screenshot can be
taken on the Linux build machine (no Roblox Studio), and no mock or
placeholder image is shipped — the judge compares screenshots against the
code, so a fake one would count for nothing.

## What to capture (3 screenshots, 1280×720 each, ≤256 KiB per file)

Take each one while the game is actually running in Studio's Play mode
(a capture tool can steal focus and pause the game — retake if the frame
looks paused).

1. **`1-start.png` — the start screen (the cover).** The first file by name
   is the cover and is shown largest, so make this the best-looking frame:
   the NEON VOID title, the how-to text and the START button, with the
   neon grid arena glowing behind the dim layer.
2. **`2-play.png` — mid-game, wave 3 or later.** The ship firing, at
   least two enemy types on screen, the HUD readable (score top-right,
   wave, lives, combo), and ideally a score popup or kill burst visible.
3. **`3-end.png` — the game-over screen.** GAME OVER with the final
   score, the wave reached and the best score, plus the PLAY AGAIN button.

## Rules the gate enforces

- 3 or 4 images, PNG or JPEG, each at most 256 KiB. A Studio capture is
  often larger: re-encode as JPEG or scale down until it fits.
- Long side at most 1280 px, short side at least 480 px.
- Keep all HUD text clear of the **top-left corner** — Roblox's own menu
  buttons cover it in the play view. Our HUD lives top-right and
  top-center for exactly this reason.

## After capturing

1. Put the three files in `screenshots/` (names above, in that order).
2. Re-run `mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts` so the
   dossier picks them up, then re-run the kit's `check`.
3. Publish the experience as Public, fill in `PLAY.json` with the real
   place id and universe id, and the entry is ready to submit.
