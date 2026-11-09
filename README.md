# Wonderguard 3D

A portrait-first 3D toybox tower defense for Little Joy Arcade, built in Godot 4.7
with GDScript and Blender-authored models.

A miniature kingdom sits on a polished table. Wind-up armies march down its
winding road toward your castle, and you answer with brass cannons, frost
crystals, clockwork hives and toy golems. Every tower physically rebuilds itself
as it upgrades, and at tier four you choose one of two ultimates that play
differently rather than merely hitting harder.

- **1,000 campaign levels** across 20 kingdoms, 50 per kingdom, every board
  generated from a seed and validated headless before it ships.
- **26 tower families** in six categories, each with three linear tiers and two
  ultimate evolutions.
- **48 enemy archetypes** with real behaviours: healers, summoners, splitters,
  armoured carriers, phasing constructs, flyers and dodgers.
- **20 bosses**, one per kingdom, three phases each.
- **Seven modes**: campaign, Endless Siege, Survival, Boss Rush, Daily Defense,
  Sandbox and Fortress.
- **A living 3D journey map** that lights the road as kingdoms are cleared.

## Running it

```bash
godot --path .                     # editor
godot --path . Scenes/Main.tscn    # straight into the game
```

The first launch imports the Blender GLBs and the generated audio, which takes a
few seconds.

## Tests

```bash
godot --headless --path . --import
godot --headless --path . Scenes/Tests.tscn
```

The suite (8,116 assertions) regenerates and structurally validates all 1,000
campaign levels, checks every tower's tiers and both ultimate branches, every
enemy archetype and boss phase, the six extra modes, fixed-step combat
(targeting, damage, marks, soak, freeze, leaks), save merging and the asset
inventory. It exits non-zero on any failure and runs in CI before an export.

## Web build

```bash
godot --headless --path . --export-release "Web" web/play/index.html
python3 Tools/patch_web.py                 # arcade bridge, viewport, portrait CSS
python3 -m http.server 4176 --directory web/play
node Tools/smoke.mjs http://127.0.0.1:4176/
```

`Tools/smoke.mjs` drives the real exported build in Chromium: the canvas must
fill the phone window edge to edge, bridge presence, a battle started through
the debug hook, a tower actually built, a wave called and fast-forwarded, plus a
landscape window that must show the rotate gate. It writes screenshots to
`/tmp/wg-shots`.

The export is single-threaded, Compatibility renderer, WebGL 2 — no
cross-origin-isolation headers needed. The stretch mode is `canvas_items` with
`expand`, and the battle camera fits itself to the live viewport aspect, so the
diorama reaches the screen edges on tall phones instead of sitting in 9:16 bars.

## Architecture

```
Scripts/Core/       Towers, Enemies, Bosses, Campaign, SaveManager, Models,
                    AudioManager, ArcadeBridge, Ui
Scripts/Game/       Battlefield  — authoritative fixed 60 Hz simulation
                    BattleView   — 3D diorama that only reads the simulation
Scripts/Map/        JourneyMap   — the 3D kingdom map
Scripts/Main.gd     screens, touch input, HUD, results, codex
Blender/            build_assets.py — the modular toy kit (rerunnable)
Tools/              audio.py, patch_web.py, smoke.mjs
web/play/           the exported build (generated)
```

Gameplay state never lives in a `Node3D`. `Battlefield` owns enemies, towers,
projectiles and statuses on a logical grid and a fixed step; `BattleView`
interpolates the diorama toward it, so visuals can be added without changing a
rule. Levels are data: a road, a socket grid, waves and a budget. That is why
1,000 of them can be generated and checked in seconds.

## Progression and saves

Stars, crowns, records, trophies (100 of them) and settings live in
`user://wonderguard_save.json`, written after every meaningful event. When the
game runs inside Little Joy Arcade and the player is signed in, the same payload
is pushed to cloud saves and achievements are reported; on device start the
newest save wins, trophies are unioned, and device settings are preserved. If
the SDK is absent the game is fully playable offline and says so in the menu.

## Deployment

`.github/workflows/pages.yml` installs Godot 4.7.2 with the export templates,
runs the headless suite, exports, patches the shell and publishes `web/play` to
GitHub Pages. Nothing is published if the suite fails.

The build is pushed to the `gh-pages` branch, and Pages is set to serve that
branch. `actions/deploy-pages` was the original path, but its artifact uploads
for this repo waited in `syncing_files` and hit the ten-minute timeout on every
attempt while the build itself passed; the branch builder publishes in well
under a minute. The site URL is unchanged:
<https://jd4rider.github.io/wonderguard-3d/>.

## Known limitations

- Automated tests are structural and simulated; they do not prove a level is
  fun. Level balance still needs human playtesting.
- Tested in Chromium (desktop and phone emulation). Safari/iOS and Firefox have
  not been verified for this build.
- Sandbox and Fortress share the campaign battlefield generator; Fortress does
  not yet offer player-placed walls, only unrestricted tower placement.
- Boss fights are mechanically distinct (summons, armour, shields, speed and
  ground hazards) but they reuse the enemy body kits rather than unique meshes.

## Credits

Design, code, Blender assets and synthesised audio by FreeBuff for
Little Joy Arcade. Engine: Godot 4.7.2 (MIT). All models and audio are original
and generated by the scripts in `Blender/` and `Tools/`.
