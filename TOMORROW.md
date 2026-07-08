# Handoff — pick up next session

_Written 2026-07-09. Everything below is planned/decided but NOT yet built. State at handoff: project imports clean, `run_tests.gd` green (172/0)._

## 1. Hearth rebuild → multi-phase build in the Construction menu (DECIDED, build next)

Move the broken-hearth rebuild out of the inline card action and into **Construction > Shelter**, as a real multi-phase build.

- **Two phases** (user chose multi-phase): (1) clear the fallen stone, (2) relay the firebox. Each phase = provide materials, then a labor session.
- **Cost baseline:** the current inline repair is 3 stone + ~1h labor. Split that across the two phases (e.g. phase 1 clears rubble, phase 2 takes the 3 stone + the bulk of the labor).
- **No research gate.** Available as soon as the broken hearth is discovered (it now reveals on the first manor search).
- **Completion = in-place fixture swap** `broken_hearth -> hearth`. The reposition fix already landed in `_swap_fixture` (replaces in place, no jump to end of row), so reuse that.
- **The wrinkle to design around:** existing builds (`manor_door`, `manor_windows`, `workbench`) complete by setting a `Game.builds[id] = true` stat flag feeding `shelter_damp()` / `shelter_defense()`. The hearth is NOT a stat flag — it is a fixture transform. So the buildsite completion path needs a "transform this fixture" outcome, not just a flag. Add that outcome type.
- **Retire the inline action:** `ACTIONS["broken_hearth"]` = "Rebuild the hearth (1h)" (main.gd ~line 62). Clicking the broken hearth should route into its construction/buildsite instead.

**Read before implementing** (the buildsite flow):
- `main.gd`: `_render_shelter_construction()` (~1024), `_open_buildsite()` (~1086), `_render_buildsite()` (~1044), `_render_craft_hub()` (~985), and how a phase completes/executes.
- `autoload/game.gd`: BUILDS / construction defs (~60–180), `construction_for()` (~657), `build_progress` / `builds`.

**Verify:** headless import + `run_tests`, then DRIVE it in-app: discover hearth (first manor search) -> Construction > Shelter -> complete both phases -> hearth sits in its original slot and can be lit.

## 2. Lighting / environment "grade" layer (DESIGN DIRECTION, prototype when ready)

Convey place/lighting like CSTI's sun-vs-cave, in an already-dark game. Reframe: **do not dial brightness** (no headroom, hurts readability). Dial **colour temperature, saturation, and the light pool / vignette.**

- **Diegetic anchor = the fire.** Lit -> warm amber wash, slow faint flicker, vignette loosens, saturation lifts near centre. Dies -> drains to flat cold blue-grey, edges close in. Lighting becomes the fire mechanic; letting the hearth die = the dark creeping back.
- **Per-context grades:** grounds/woods by day = pale, cool, flat, loose vignette; cellar = cold, low-key, desaturated, tight vignette; night = deep blue, tighter; season drift = winter pulls bluer/greyer over time (makes escalation felt).
- **Hard rule:** grade the WORLD layer only (app bg, panel tints, full-screen vignette/tint overlay, maybe a faint modulate on card ART areas). NEVER the text or bar values. Readability stays constant.
- **Transitions carry it:** tween the grade ~0.8–1s on fire-lit, travel, day/night. A cut does nothing.
- **Impl:** one centralized environment layer — full-screen `ColorRect` + small canvas shader (tint + vignette + desaturate), uniforms driven by state we already track: `is_fire_lit()`, `location_indoor`, time (day/minute), season, `outdoor_temp`. No-shader fallback: `CanvasModulate` + baked radial-gradient overlay, tweened.
- **Minimal first slice:** fire warm-wash + vignette only. Highest impact, most diegetic, proves the approach before grading every location.

## 3. Loose ends (from the text/atmosphere review — optional)

- **Batch F clarity items NOT applied** (undecided): `game.gd:1053` "reserves" -> name the meter (Calories); `game.gd:1055` "won't kill you" -> in-body wording; `forage_food` title "Forage" -> "Wild Food"; `set_snare` title "Snare" -> "Set Snare". (The `cured` hide naming was deliberately KEPT — a curing step is coming later. Immune->Immunity label is DONE.)
- **Engine-rate leak, broader:** `drain_breakdown()` (game.gd ~1125–1146) still prints per-hour rates ("base X/hr", warming/cooling, dysentery). Decide if it is player-facing; if so, qualitativize it like the condition tells were.
- **Log width** set to 220 to stop the 6-card inventory scroll — confirm it actually clears on the target resolution (window runs maximized), else trim further or shrink the card gap.
- **Fireside amnesia echo** — confirm the one-time beat reads well in play.

## Done this session (for context)
Text review applied (safe batches C/G/A/B/D/E + death title/badge + cold-open sensory anchor + Immune->Immunity + once-only manor find); compound free-movement (grounds/manor/cellar 0m); Manor rename (was "Lordly Manor"); fireside amnesia echo (once-only via `Game.mark_beat`); hearth discovered on first manor search; `_swap_fixture` reposition fix; log panel 256->220. Review artifact: the 7-lens "Voice & Atmosphere Review" (voice bible + 34 rewrites). Voice bible + conventions live in the auto-memory `ux-conventions` note.
