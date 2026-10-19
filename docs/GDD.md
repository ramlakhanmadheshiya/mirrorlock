# Mirrorlock: game design

## High concept
Mirrorlock is a portrait escape puzzle with a twist that reads in three seconds: the board is split by a glowing mirror, every piece has a twin in mirror image on the other side, and tapping either twin moves both. Clear every piece without bumping.

## Market references
- **Arrows – Puzzle Escape (Lessmore, 2025) and its many clones:** the proven "tap an arrow, it slides off if its path is clear" loop, lives for mistakes, huge level counts. Mirrorlock keeps the loop and makes every move a double move.
- **Single Shot and Word Lantern** (our own): chapters of 40 generated and validated levels, one idea per chapter with a tutorial room, three stars, calm monetisation, share cards, daily puzzles from the date.
- **Monument Valley, Two Dots, I Love Hue:** calm palettes, one obvious action per screen, audio that rewards.

## Player promise
You read a symmetric board, spot the pair that's free, tap once and watch both twins zip off together with a chime. Then the symmetry starts to break, and you have to read both halves.

## Core loop
1. Look at the board. Twins share a colour and breathe in step; pressing a piece lights up its twin and draws a dotted line between them through the mirror.
2. Tap a piece. Its group (the piece and every exact mirror image of it under the mirror in force) slides straight ahead, off the board.
3. If any path is blocked, the whole group bumps forward, springs back, and a heart is lost (three per level).
4. Clear every piece. No bumps ★★★, one bump ★★, more ★. A hint caps it at ★★.
5. Out of hearts: try again, or buy one more heart (40 coins, or a video on Android) and carry on.

## Rules
| Rule | Detail |
|---|---|
| Pieces | Straight capsules 1–3 cells long, lying along their direction (right, down, left, up). They slide head first until they leave the board. |
| Twins | A piece's twin is the piece whose cells and direction are its exact mirror image. Twins share a colour. Tapping either moves both, simultaneously. |
| Blocked | A move is blocked if any moving piece's path holds another piece, an active stone, or if a moving piece is locked. Nothing changes; the group bumps back and a heart is lost. |
| Twins colliding | If the paths of two pieces in the same group meet, they crash. In practice: twins sliding toward the mirror always meet there (head-on for standing and lying mirrors, at the same diagonal cell for the corner-to-corner mirror). Twins sliding away from the mirror, or parallel to it, never collide. |
| Lonely pieces | White pieces have no mirror image on the board. They move alone and block only one side. |
| Stones | Sit on one side only. The number is how many successful moves they last; at zero they crumble. |
| Locks and keys | A piece with a padlock cannot move while any piece carrying its key (same colour id) is still on the board. Twins of a locked piece are locked too. |
| Diagonal mirror | Reflects across the top-left to bottom-right diagonal: (x, y) → (y, x); right ↔ down, left ↔ up. Square boards. |
| Kaleidoscope | Both the standing and the lying mirror: every piece has three images (left-right, top-bottom, and the half turn), so groups are four. |
| Turning mirror | The mirror alternates standing / lying, switching after every successful move. Groups are recomputed for the mirror in force; a piece with no image in it moves alone. Colours follow the current pairing. |
| Undo | Takes back the last successful move (the turning mirror turns back). Bumps and hints are not refunded. |

The move rule lives in one place, `game/core/rules.gd`, compiled into bit masks per level, and is shared by the board, hints, the solver, the generator and every test.

## Progression
9 chapters × 40 levels = 360, gentlest idea first; each later chapter mixes in earlier ideas from about level 16:

| # | Chapter | Mirror | New idea |
|---|---|---|---|
| 1 | Reflect | standing | mirror twins, bumps and hearts (hands-on tutorial with an animated hand) |
| 2 | Horizon | lying (standing mixed in from 16) | up and down swap; twins can meet across a horizontal line |
| 3 | Stones | standing / lying | one-sided stones that crumble after N moves |
| 4 | Solo | standing / lying | lonely pieces with no twin (stones from 21) |
| 5 | Slant | diagonal | corner-to-corner mirror (lonely from 16, stones from 26) |
| 6 | Vault | standing / lying / diagonal | locks and keys (lonely from 16, stones from 21) |
| 7 | Kaleido | both | four-way kaleidoscope (lonely from 16, stones from 26) |
| 8 | Turn | turning | the mirror turns after every move; order matters, dead ends exist (lonely from 11, stones from 26) |
| 9 | Mirrorlock | all five, rotating | finale mix: stones, lonely pieces, locks, every mirror |

- **Tiers:** 1–5 easy, 6–10 easy–medium, 11–20 medium, 21–30 medium–hard, 31–39 hard, 40 extreme.
- **Level 1** of each chapter is a hand-made tutorial room (except the finale), and the first time it opens a chapter card shows the idea on a live, self-playing board.
- **Unlocks:** levels open one at a time; 15 clears open the next chapter; level keys and chapter keys open things early.

## Level generation (tools/generate_levels.gd → game/core/generator.gd)
- **Backwards from an empty board.** Groups are added in reverse removal order. When the k-th group is placed, every piece already on the board will still be there when it moves, so its paths must be clear of all of them (and of stones still standing at that move). Its own cells may sit on the paths of pieces already placed, which makes them wait for it. Every level is therefore solvable by construction.
- **Tangle.** Among ~70 random placements per group, the generator prefers those that block the most existing pieces (long "this before that" chains), plus a little randomness.
- **Images stay clean.** A new piece is rejected if it is the exact mirror image of a piece already on the board (it would silently join that group).
- **Stones, locks, lonely pieces** are placed so they matter: a stone is crossed by a group that leaves after it crumbles; a lock goes on a group that would be free at once, its key on a group that is blocked at the start and leaves earlier.
- **Solver.** With a fixed mirror the game is monotone (removing pieces only frees paths, stones crumble and locks open as moves are made), so a greedy peel decides solvability exactly and any safe tap keeps the level solvable. The turning mirror is not monotone, so it is searched in full with a memo over (pieces left, moves made), capped at 40,000 positions.
- **Difficulty score** (`LevelGenerator.score_of`): taps in a solution, pieces, dependency depth (rounds when every free group is taken at once), the average share of groups that would bump along a solution, forced steps (only one safe tap), traps and dead ends (turning mirror), timing (pieces whose fate flips with the mirror), stones and locks, board area, total piece length and path length. Only `+ * /` and `sqrt`, so scores are identical on every platform.
- **Rejected:** unsolvable, fewer than 4 pieces, everything free at the start, too shallow (depth < 2 from level 2, < 3 from level 13), the chapter's idea not mattering (stones, lonely pieces, locks), or the turning mirror not mattering (no timing).
- **The curve.** Each level gets a pool of ~30 valid candidates from its own plan (board size and group count grow through the chapter); a small dynamic programme then picks one per level so that scores rise strictly from level to level while staying close to each pool's median. Level 40 takes the hardest pick and is the chapter's peak.
- **Deterministic.** Everything is seeded; CI regenerates all 360 levels and fails on any difference.

## Daily Mirror
Built on the phone from the date (`LevelGenerator.daily`): the date seeds the generator, the chapter rules rotate through all nine (so all five mirror kinds appear), and difficulty follows the week (Monday gentlest, Sunday hardest). No server, no stored pool. A test builds a full year and pins one puzzle's signature, so an accidental change to the generator (which would change every player's daily) is caught.

## Feel
- **Tap:** pressing lifts the group and draws a dotted link through the mirror; a tick haptic.
- **Escape:** the group zips off with ease-in acceleration and colour trails; sparks burst where each piece leaves the board; a whoosh, then a two-bell chime a fifth apart when twins leave together (rising through the pentatonic as the level goes on); a success haptic.
- **Bump:** everyone nudges forward the same amount, hits, and springs back with an elastic ease; the obstacle cells flash red, red sparks, screen shake (can be turned off), a thud and a falling third; the lost heart pops in the HUD; an error haptic.
- **Turning mirror:** the line swings a quarter turn with a back ease and pair colours cross-fade to the new pairing.
- **Stones** crumble into grit with a sound; **locks** pop away when their key escapes.
- **Clear:** a shower of sparks across the board, the result card with stars popping in on rising notes.

## Presentation
- 720 × 1280 portrait, canvas_items stretch, Compatibility renderer (also runs on the web).
- One typeface (Outfit) and line icons (Lucide); full-colour game art for coins, keys, hearts, stars.
- Each chapter has its own sky and accent; the backdrop has twin motes drifting in mirror image around a faint centre line. The board is always dark glass so the neon twins read on any theme.
- Original colours with Auto / Dark / Light; 11 more themes (Theme pack) and 6 more mirror styles (Mirror styles pack).
- Music: two synthesised loops (menu, play); every sound is generated by `tools/synth_audio.py`.

## Monetisation
Ads come from AdMob through the Poing plugin and purchases from Google Play Billing (rules in `game/ads/ad_manager.gd` and `game/autoload/store.gd`):
- **Banner** at the bottom of every screen, its space reserved so it never covers a button; refreshed on screen changes at most every 30 s.
- **No interstitials**, by design.
- **Rewarded** only when the player asks: a hint or a heart when out of coins, free coins (5 a day), a level key (5 a day), a chapter key (1 a day), a one-hour trial of the Theme or Mirror styles pack.
- **Hints:** 3 free a day (6 for Supporters), then 30 coins.
- **Shop:** Complete pack, Supporter pack (no banner, 6 free hints a day), Theme pack, Mirror styles, coin bags, chapter keys (1–5), level keys (1–10, 10% off for 5+), tip jar. Supporters are ad-free.
