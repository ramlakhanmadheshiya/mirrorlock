# Mirrorlock

*A mirrored twin escape puzzle.* The board is split by a glowing mirror and every piece has a twin on the other side. Tap either twin and both slide off the board together. If anything stands in either twin's way, both bump back and you lose a heart. Clear every piece to win.

Made with Godot 4.7.2 (GDScript, Compatibility renderer, so it also runs on the web). Portrait-first; works with touch, mouse and keyboard.

**Play / download:** https://theramlakhan.com/mirrorlock/ (browser version and Android APK)
**Made by:** [Ramlakhan Madheshiya](https://theramlakhan.com), with Claude as AI co-developer.

## The game

- **Twin moves.** Every piece is a neon capsule, 1–3 cells long, pointing the way it will slide. Its twin is its exact mirror image (cells and direction reflected) and shares its colour; twins breathe in step, and pressing a piece lights its twin and draws a dotted line between them. Tapping either moves both, at once, straight off the board.
- **Bumps cost hearts.** A move is blocked if any path holds another piece, a stone or a lock. **Twins sliding toward each other across the mirror always crash** (they meet at the line), so only twins heading away from or along the mirror can leave. A blocked pair nudges forward, bumps and springs back; the obstacle flashes, the board shakes, and one of three hearts is lost. Out of hearts: try again, or take one more heart for 40 coins (or a video).
- **9 chapters × 40 levels = 360 levels.** Each chapter adds one idea, opens with a tutorial room and a chapter card with a live demo board, and mixes in earlier ideas from about level 16:

  | # | Chapter | New idea | Boards |
  |---|---|---|---|
  | 1 | Reflect | a standing mirror: left and right swap (hands-on tutorial with an animated hand) | 4×5 → 8×10 |
  | 2 | Horizon | the mirror lies down: up and down swap | 5×4 → 8×10 |
  | 3 | Stones | one-sided stones that crumble after N moves | 4×4 → 8×10 |
  | 4 | Solo | white lonely pieces with no twin | 4×4 → 8×10 |
  | 5 | Slant | a diagonal mirror: right becomes down, left becomes up | 4×4 → 8×8 |
  | 6 | Vault | locks that open when their key pair escapes | 4×5 → 8×10 |
  | 7 | Kaleido | two mirrors: four copies of every piece | 4×4 → 8×10 |
  | 8 | Turn | the mirror turns after every move, so twins change as you play | 4×4 → 8×8 |
  | 9 | Mirrorlock | every mirror and every idea, mixed | 6×6 → 8×10 |

  Every chapter follows the same curve: 1–5 easy, 6–10 easy–medium, 11–20 medium, 21–30 medium–hard, 31–39 hard, 40 extreme. `tests/levels_test.gd` checks that every level is harder than the one before, every tier harder on average than the one before, and level 40 the hardest of its chapter.
- **Three stars.** No bumps ★★★, one bump ★★, more ★; using a hint makes ★★ the most. A HEARTS / STARS / LEFT strip over the board shows what is still on offer.
- **Hints and Undo:** a hint lights up a pair that can leave safely (the solver's next safe tap). 3 free hints a day, refilled at midnight (6 for Supporters); after that 30 coins, and **out of coins the player can watch a rewarded video for the hint** (on the web, where no video can play, it is free). Undo takes back the last move (no refund of hearts).
- **Progress:** levels open one at a time; clearing 15 levels in a chapter opens the next. A level key opens any locked level early. A **chapter key** opens a whole locked chapter (its level 1); you earn one by clearing level 40 of any chapter, can buy 1–5, or get one a day from a video. Locked levels are still shown on the level grid.
- **Daily Mirror:** built on the phone from the date (`LevelGenerator.daily`), with no server and no stored pool, so it never runs out. Everyone gets the same puzzle on the same date: the date seeds the generator, the rules rotate through all nine chapters (every mirror kind appears), and difficulty follows the week (Monday gentlest, Sunday hardest). A test builds a full year of dailies and pins one puzzle, so an accidental generator change is caught. Shareable like any level.
- **Rewards** (each paid once): +5 coins for a first clear, +5 for every new star, +100 and an award for finishing a chapter, +30 (plus a streak bonus) for the Daily Mirror, and 26 awards in all.
- **Shop** (Single Shot's and Word Lantern's model; one-time packs plus consumables, all via Google Play):

  | Product | What it gives |
  |---|---|
  | Complete pack | Everything below, plus 1,000 coins and 5 level keys |
  | Supporter pack | No banner ads, 6 free hints a day instead of 3 |
  | Theme pack | 11 colour themes (9 dark, 2 light) that recolour the whole app (1-hour trial from a video) |
  | Mirror styles | 6 styles for the twin pieces: Prism, Candy, Ember, Glass, Jewel, Mono (1-hour trial from a video) |
  | Chapter keys | 1–5; each opens a whole locked chapter; plus one free from a video a day |
  | Coin bags | 100 to 6,000 coins; plus free coins from a video (5 a day) |
  | Level keys | 1–10 keys, 10% off for 5+; plus a free key from a video (5 a day) |
  | Tip jar | Say thanks; unlocks nothing |

  Product ids and Play Console setup: [`store/PLAY_PRODUCTS.md`](store/PLAY_PRODUCTS.md) and [`store/PLAY_CONSOLE.md`](store/PLAY_CONSOLE.md). Debug desktop builds simulate purchases; the web build explains that purchases are in the Android app.
- **Ads (Android):** a banner at the bottom of every screen, with its space reserved before the ad loads so the layout never jumps; it loads a fresh ad when the player changes screens (at most every 30 s, per AdMob policy). Rewarded videos only when the player asks (a hint or a heart when out of coins, free coins, a level or chapter key, a pack trial). **No full-screen ads between levels.** Supporters see no banners.
- **Sharing:** after a clear, Share makes a 1080×1350 picture of the level's board (every twin glowing), the stars, the verdict, a link and a QR code, and opens the phone's share sheet; Save puts it in the gallery (Pictures › Mirrorlock); Copy link copies the message. Android uses a small plugin (`plugins_src/mirrorlock_share`, built by CI).
- **Feel:** synced zips off the board with trails and sparks, a two-bell chime when twins leave together, bump + elastic spring-back + shake + red flash on a block, stones that crumble, locks that pop, a turning mirror that swings, haptics on every tap, and generated audio (no samples).
- **Appearance:** a thin Auto / Dark / Light slider in Settings; Auto follows the phone's dark mode. The board itself is always dark glass so the neon reads on every theme.
- **Settings:** Music and Sound volume sliders, Vibration, Screen shake, Appearance, colour theme and mirror style pickers, How to play (live demo boards for every idea), Shop, Awards, About, Credits, Ad privacy (when required), and Reset progress (tap once to arm, again to erase; hidden during a level; keeps settings, packs, keys and bought coins).
- **Saving:** everything is saved locally with atomic writes and a backup after every tap; half-played levels resume (with their Undo history).

### Controls

| Input | Action |
|---|---|
| Tap / click a piece | Move it and its twin(s) |
| H | Hint |
| Z | Undo |
| R | Restart the level |
| Esc, or Back on Android | Back |

## Run

```sh
./play.sh            # launches the game window directly (no editor)
```

## Check

```sh
./tests/run_all.sh   # levels + daily, rules and solver, saves and rewards, UI flow, boot smoke
```

| Test | What it covers |
|---|---|
| `tests/levels_test.gd` | All 360 levels: ids, board shapes (even sides for standing/lying mirrors, square for diagonal/turning), no overlaps, groups that are lonely pieces or complete twin sets, solvable and played to the end through the real `PlayState` with no bumps, stored scores, not trivial, the chapter's idea matters, the difficulty curve and tiers, level 40 the peak; a full year of daily puzzles (valid, deterministic, every mirror kind, Sunday harder than Monday) and a pinned daily. |
| `tests/logic_test.gd` | Mirroring for every axis (cells, directions, involutions), twin moves and bumps, head-on crashes (standing, lying, diagonal), the kaleidoscope, the turning mirror (pairs change, lonely moves, Undo turns it back), stones, locks, lonely pieces, the solver and hints, hearts/stars/extra hearts, save and restore of a half-played level, and the generator (solvable by construction for every axis, deterministic, locks). |
| `tests/profile_test.tscn` | Coins, free hints, stars and star rewards, unlocks, keys, chapter keys, dailies and streaks, awards (once), video reward limits, simulated purchases, trials, reset keeping purchases, restart persistence, corrupt-save recovery, and every glyph the UI can show. |
| `tests/ui_flow.tscn` | The real app end to end with the mock ad provider: banner space, chapters, 40-tile level grid, the first-play tutorial, a bump (2★), Again for 3★, Next, a locked level opened with a key, free/paid hints, out-of-coins video (watched and skipped), Undo, running out of hearts (+1 heart, Try again), Restart, the shop (coin bag, free coins video, style trial, themes, Supporter removes the banner), settings, the daily, an app restart, a chapter key, chapter cards, sharing, and Reset. |
| Boot smoke | Runs the game for 300 frames and fails on any error, warning or leak. |

Screenshots of every screen (needs a display; add `clean` to hide the test banner, `store` for the 1080×1920 Play screenshots):

```sh
godot --path . res://tests/capture.tscn -- /tmp/ml_shots 450 800
godot --path . res://tests/capture.tscn -- "$PWD/store/screenshots" 450 800 store
```

## Make the levels and art

```sh
godot --headless --path . -s res://tools/generate_levels.gd             # everything (~2 min)
godot --headless --path . -s res://tools/generate_levels.gd -- slant    # one chapter
godot --headless --path . -s res://tools/render_icons.gd                # launcher icons, splash, Play icon
godot --path . --resolution 1024x500 res://tools/render_feature_graphic.tscn
python3 tools/synth_audio.py                                            # every sound and music loop
```

Levels are generated once from the plan in `data/chapters.json` and committed. The generator is deterministic (CI regenerates and fails on any difference). It builds each level **backwards from an empty board**: groups are added in reverse removal order, each one's paths clear of everything already placed (which leaves after it), so every level is solvable by construction; placements that block the most existing pieces are preferred, which builds long dependency chains. A solver then verifies it (a greedy peel for fixed mirrors, which are monotone; a memoised search for the turning mirror, which has dead ends), scores it (taps, pieces, dependency depth, how many groups would bump, forced steps, traps and dead ends, timing, stones, locks), rejects trivial levels and levels where the chapter's idea doesn't matter, and a small dynamic programme picks one candidate per level so difficulty rises strictly through the chapter. Details: [`docs/GDD.md`](docs/GDD.md).

## Build & publish

Every push to `main` runs `.github/workflows/build.yml`: tests, the level reproducibility check, a web export, the share plugin (Gradle), a signed Android APK and App Bundle (with the AdMob and Play Billing plugins), publishing to `gh-pages` (served at `https://theramlakhan.com/mirrorlock/` with `play/`, `help/`, `privacy/` and `mirrorlock.apk`), the APK as a GitHub release, the APK and AAB as artifacts, and (once its secret exists) an upload of the AAB to Google Play internal testing.

Repository secrets:

| Secret | Purpose |
|---|---|
| `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEYSTORE_ALIAS` | Release signing (without them a throwaway key is used, and updates can't install over older builds) |
| `ADMOB_APP_ID`, `ADMOB_BANNER_ID`, `ADMOB_REWARDED_ID` | Real AdMob units (without them Google's test ads are used) |
| `PLAY_SERVICE_ACCOUNT_JSON` | Optional: upload every build's AAB to the internal testing track |

## Project structure

| Path | What it holds |
|---|---|
| `game/core/` | Pure logic: `level.gd` (board, pieces, stones, mirror maths), `rules.gd` (the move rule as bit masks), `solver.gd` (solve, hints, difficulty), `generator.gd` (backward construction, grading, the chapter curve, the daily), `play_state.gd` (a level in play: taps, hearts, stars, undo, save), `economy.gd`, `achievements.gd` |
| `game/autoload/` | `save.gd` (versioned JSON save), `catalog.gd` (chapters, tiers, levels, daily), `profile.gd` (coins, stars, unlocks, keys, purchases, trials, streaks, awards, settings), `store.gd` (catalogue and Play Billing), `share_service.gd`, `audio.gd`, `haptics.gd` |
| `game/ads/` | `ad_manager.gd` (banner and rewarded policy) and providers: AdMob (Android) and a mock (debug desktop, tests) |
| `game/board/` | `board_view.gd` (glass board, mirror lines, pieces, taps, zips, bumps, trails, particles, hint glow, ghost finger) |
| `game/ui/` | `app.gd` (screens, Back chain, overlays, toasts, error state), `splash.gd`, `screen.gd`, `overlay.gd`, `ui_kit.gd`, `style.gd`, `look.gd` (themes and mirror styles), `screens/` (home, chapters, levels, play, shop), `overlays/` (settings, result, how-to, chapter intro, product, picker, keys, chapter keys, coins, tips, locked, about, credits, awards, messages, share), `widgets/` |
| `data/` | `chapters.json` (chapters, generation plan, tutorial rooms, tiers, daily), `levels/` |
| `addons/` | Godot AdMob plugin (Poing Studios, MIT), Godot Google Play Billing (MIT), the share plugin's export hook |
| `store/` | Play listing, products, Console guide, icon, feature graphic, screenshots |
| `tools/`, `tests/`, `web/`, `docs/` | Generators, tests, the website pages, the design and audio notes |

## Decisions made while building

- **Crash rule:** a group is blocked if any two of its pieces' paths meet. With mirror symmetry this means exactly "twins sliding toward the mirror crash at the line" (head-on for standing/lying mirrors, at the shared diagonal cell for the corner-to-corner mirror); twins sliding away from or along the mirror never collide.
- **Twins by geometry, not labels:** a piece's group is "itself plus every exact mirror image of it on the board under the mirror in force". That one rule covers pairs, lonely pieces, the kaleidoscope's groups of four and the turning mirror's changing pairs, and the generator rejects accidental images.
- **Chapter 3's one-sided blockers are stones that crumble.** Permanent blockers in a path would make pieces unescapable, so stones last N moves (shown on them); that keeps them one-sided and makes them matter.
- **Chapter 6 uses locks and keys** (not ice) because it adds real ordering, and its tutorial teaches "free the key first".
- **Chapter 8 (turning mirror)** alternates standing and lying; a piece with no image in the current mirror moves alone, and pair colours follow the current mirror. It is the only chapter where a careless order can strand a piece, so Undo exists (it is harmless elsewhere).
- **Hearts and stars:** 3 hearts; ★★★ no bumps, ★★ one, ★ more; a hint caps at ★★ (as in Single Shot). An extra heart costs 40 coins or a video, so coins have a second use besides hints.
- **No interstitials:** the brief's ad policy (banner + rewarded on request + Supporters ad-free) is followed, like Single Shot, rather than Word Lantern's video every 5 levels.
- **The board stays dark** in light themes and light appearance, so the neon pieces always read.
- **Game art** (coin, key, chapter key, heart, star, lock, trophy, calendar, bag, theme, watch) is shared with Word Lantern (same author); the app icon, hint bulb, every in-game shape and the audio are new.

## Credits

| Asset | Source | Licence |
|---|---|---|
| Engine: [Godot Engine](https://godotengine.org) 4.7.2 | Godot contributors | MIT |
| Font: [Outfit](https://github.com/google/fonts/tree/main/ofl/outfit) | Google Fonts | SIL OFL 1.1, `assets/fonts/OFL.txt` |
| Fallback glyphs: Noto Sans subsets | Google | SIL OFL 1.1, `assets/fonts/OFL-Noto.txt` |
| UI icons: [Lucide](https://lucide.dev) | lucide-static 0.460.0 | ISC, `assets/icons/LICENSE.txt` |
| Game icons and the app icon | Drawn for the theramlakhan.com games | Released with the project |
| Music and sound effects | Generated by `tools/synth_audio.py`, no samples | Released with the project (CC0), see `docs/AUDIO.md` |
| Levels and daily puzzles | Generated by `game/core/generator.gd` | Released with the project |
| QR code on the share card | Generated with [segno](https://github.com/heuer/segno) | Generated output |
| [Godot AdMob Plugin](https://github.com/poingstudios/godot-admob-plugin) | Poing Studios | MIT, `addons/admob/LICENSE` |
| [Godot Google Play Billing](https://github.com/godot-sdk-integrations/godot-google-play-billing) | Godot contributors | MIT, `addons/GodotGooglePlayBilling/LICENSE` |

The game-dev agent skills used while building this are in `.claude/skills/`. They come from [GodotPrompter](https://github.com/jame581/GodotPrompter) (MIT), [awesome-gamedev-agent-skills](https://github.com/gamedev-skills/awesome-gamedev-agent-skills) (Apache-2.0) and [godot-skills](https://github.com/vl4dt/godot-skills) (MIT).

Game design and development: **Ramlakhan Madheshiya** — https://theramlakhan.com
