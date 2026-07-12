# Headless test harness

Deterministic tests for the simulation in `autoload/game.gd` (the `Game` autoload). No UI,
no real-time tick: everything is driven through `Game.advance_time(mins, sleeping)`.

## Run

From the repo root (the Godot CLI is not reliably on PATH — prepend it):

```
export PATH="/c/Users/peter/.local/bin:$PATH"   # Git Bash
godot.cmd --headless --path . -s res://tests/run_tests.gd
```

Output ends with `PASSED n  FAILED m` and a `FAIL: ...` line per failure. Exit code is `0`
when all pass, `1` otherwise.

## Layout

- `run_tests.gd` — the `SceneTree` entry point. `make_sim(seed)` builds a FRESH, seeded sim
  for each test: `preload("res://autoload/game.gd").new()`, `add_child`, then a manual
  `_ready()` (required — `_ready` is not auto-fired for a node added during `_init`),
  `rng.seed = <fixed int>`, then `reset()`. It runs every suite, prints the tally, and quits.
- `test_helpers.gd` — a `RefCounted` accumulator. `expect(cond, msg)`, `expect_eq(a, b, msg)`,
  `expect_near(a, b, msg, eps)` record pass/fail. `keep_alive(g)` pins survival meters high;
  `advance_days(g, n, alive)` rolls whole days (death does not stop the day roll or the
  director, so `alive=false` is fine for schedule assertions).
- `test_*.gd` — one suite per area, each a `RefCounted` with `func run(tree, h)`. They call
  `tree.make_sim(seed)` for fresh sims and record checks on `h`.

## Coverage

- `test_seasons.gd` — `season()` / `season_name()` boundaries, Winter on day 7,
  `days_left_in_season()`.
- `test_conditions.gd` — incubation maturing after its window, `_eval_stage` thresholds,
  hypothermia Deep Cold as a lethal condition, and the composed drain multiplier cap.
- `test_combat.gd` — weapon profiles, exhausted attacks, unique wounds, bleeding, Blood
  lethality, pain, cleaning, bandaging, delayed infection, and wound reset behavior.
- `test_director.gd` — the 4-event spine, telegraph timing, `_fire_event` effects
  (radio power, siege, cold-snap temp drop), the deterministic radio (threat outranks
  weather; a same-day repeat is static), and `_extend_schedule` being idempotent.
- `test_research.gd` — availability by skill level, the single research slot, progress
  accruing only while awake, completion unlocking a build in `construction_for`.
- `test_construction.gd` — `construction_for` gating, `complete_build_phase` progression,
  `shelter_damp` tightening as builds land.
- `test_siege.gd` — the `shelter_defense` gradient (0.20 / 0.44 / 0.66) and 0.90 ceiling,
  `siege_breaches` across preparation levels.
- `test_determinism.gd` — identical `rng.seed` gives identical weather; different seeds
  diverge.

## Conventions

- NEVER use `assert()` — it aborts the whole process and is stripped from release builds.
  Use `expect`/`expect_eq`/`expect_near` so every check is counted and reported.
- One FRESH sim per scenario (`tree.make_sim(seed)`); never share mutated state between checks.
- When a member is read off the untyped sim node (e.g. `g.scheduled_events.size()`), give the
  local an explicit type (`var n: int = ...`), not `:=` — the compiler cannot infer a type
  through a `Node`-typed value, and a parse error there hangs the whole run.

## Add a test

Add a check to an existing suite, or create `tests/test_<area>.gd` as a `RefCounted` with
`func run(tree, h)` and register it in the `suites` dictionary in `run_tests.gd`.
