# Dead Air — architecture note

A Godot 4.7 GDScript survival card sim (M0 prototype). Entry point is `main.tscn`
(`config/name="Dead Air"`, autoload `Game` registered in `project.godot`). This note is
the map: read it once instead of re-deriving the layout.

## Big picture / seams

Three files carry almost everything:

- **`autoload/game.gd`** — the `Game` autoload singleton. It IS the entire simulation and
  all persistent game state. UI-free (extends `Node`, never touches Controls). It emits one
  signal, `changed`, whenever state moves.
- **`main.gd`** (extends `Control`) — the whole view + interaction layer, plus the
  combat/siege/death/time popups. It builds the UI in code, connects `Game.changed` to
  `_refresh()`, and drives the sim by calling `Game` methods.
- **`card.gd`** (`class_name CardIcon`, extends `PanelContainer`) — one card tile: art,
  state bar, drag/drop, container fill logic.

Supporting: `card_data.gd` (`class_name CardData`, the `Resource` schema for a card),
`card_row.gd` (`class_name CardRow`, a drop-target row), `clock_face.gd` (`class_name
ClockFace`, the time-passing dial).

**Time is ACTION-DRIVEN.** There is no `_process` tick on the sim. The clock only moves when
an action calls `Game.advance_time(mins, sleeping := false)`, which applies drains,
conditions, weather, fire burn, fatigue, research, the day roll, and the event director in
one step, then emits `changed`. Waiting/sleeping is just an action that calls it repeatedly.

## Where each content type lives

In **`autoload/game.gd`** (edit here to add):
- Conditions: `CONDITIONS` (dict, staged hidden gauges). Continuous needs: `meters` +
  `_drain`. `LETHAL_METERS` (currently `[]` — nothing is instant-death at 0).
- Skills: `skills` / `SKILL_LABEL` / `SKILL_ACTIVE`. Research: `RESEARCH`.
- Construction: `CONSTRUCTION`. Events/director: `EVENTS`, `EVENT_SPINE`, `EVENT_FLAVOR`,
  plus radio/siege prose `RADIO_STATIC`/`RADIO_DEAD`/`SIEGE` and `_fire_event`.

In **`main.gd`** (edit here to add):
- Enemies: `ENEMIES` (dict — HP/damage/verb, lives in the UI layer, NOT in `Game`).
- Card registry: `CARD_FILES` (id -> `.tres` path). Every card id must be listed here.
- Locations: `LOCATIONS` (fixtures, connections, exploration `pool`). Ground start:
  `GROUND_START`. Single-card click actions: `ACTIONS`. Two-card drag recipes: `RECIPES`.

Cards themselves are `CardData` resources in **`data/cards/*.tres`** (fields defined in
`data/card_data.gd`: `id`, `title`, `kind`, `blurb`, `state_kind`, `becomes`, `is_container`,
`capacity`, `sealable`, `is_fire_source`, `blurb_lit`/`blurb_fueled`). `kind` drives the
accent colour in `card.gd` (`location`/`station`/`fixture`/`character`/`creature`/item) and
mobility (only `item`/`resource`/`tool` can be dragged).

## How to add one of each

- **A card**: write `data/cards/<id>.tres` (copy an existing one), then register it in
  `CARD_FILES` in `main.gd`. Place it via `GROUND_START`, a location `fixtures` list, or an
  exploration `pool` entry.
- **A location**: add an entry to `LOCATIONS` in `main.gd` (title, `indoor`, `fixtures`,
  `connections`, optional `pool`). Add a `.tres` of `kind = "location"` and register it.
- **An action** (single click): add an entry under the card id in `ACTIONS` (`label`,
  `mins`, and effect keys `fx`/`state_delta`/`consume`/`spawn`/`cure`/`cond`/`drink`/
  `radio_listen`/`needs_fire`). `_perform` in `main.gd` already interprets these keys — no
  second edit unless you invent a new key.
- **A recipe** (drag item onto target): add `RECIPES[item_id][target_id] = {label, mins}`
  in `main.gd` — AND add a matching branch in `perform_recipe` (`main.gd`) that does the
  actual work. Two places. `RECIPES` only makes the drag legal and shows the hint.
- **A condition**: add an entry to `CONDITIONS` in `game.gd` (staged `enter`/`exit`/`mult`/
  `decay`, optional `incubation_hours`, `lethal`/`death`). Seed it via an action's `cond`,
  `Game.add_condition`, or a hand-written driver in `_apply_influences` (like `hypo`/
  `dehydration`/`infection`).
- **An event**: add to `EVENTS` (mechanics) + `EVENT_SPINE` (or `_extend_schedule` for the
  endless years) + `EVENT_FLAVOR` prose keyed `<id>_telegraph/onset/end/radio`. If it has a
  new mechanical effect, add an arm to `_fire_event`. Weather/threat/power `category` drives
  the radio.
- **A construction project**: add to `CONSTRUCTION` in `game.gd` (shelter, phases with
  materials + `work_mins`, optional `requires_research`). The buildsite UI in `main.gd`
  reads it generically. If the finished build should DO something, wire it into
  `shelter_damp()` / `shelter_defense()` (see gotchas).
- **A research project**: add to `RESEARCH` in `game.gd` (skill, level, hours, `unlocks` a
  construction id). Research never applies an effect directly — it only gates a build.
- **An enemy**: add to `ENEMIES` in `main.gd` (hp, damage, flee_hit, verb, optional
  `bite_infection`). Add a `.tres` of `kind = "creature"` + register it. Surface it as a
  location `fixture` (pool `milestone` reveal) with a fight `ACTIONS` entry, or via a siege.

## Key patterns

- **Pull model**: the sim never pushes to widgets. `Game` mutates state and emits `changed`;
  `main._refresh()` re-reads everything (meters, conditions, log, card state via
  `CardIcon.sync_state()`) and repaints. Cards read their own persisted state on build.
- **Sim -> UI one-shot flags**: `Game` sets a flag, `_refresh` consumes it. `force_sleep`
  (Exertion/`Energy` hit 0 -> a short forced rest, or `Sleep` hit 0 -> a real collapse-sleep;
  `force_sleep_kind` says which) triggers `_collapse_sleep`; `pending_siege` (a horde event
  fired) triggers `_start_siege`. Both are cleared the moment `_refresh` acts on them.
- **Event director**: deterministic and telegraphed. `_director_tick` runs once per new day
  inside `advance_time`, telegraphs/fires scheduled events, and the radio only ever broadcasts
  the Director's own upcoming events (`_radio_broadcast_for_today`). No hidden RNG spikes —
  combat is the only non-deterministic part (`_strike_roll`).
- **Builds carry effects**: sealing and defence live on completed builds, not on research.
  `shelter_damp()` and `shelter_defense()` sum bonuses over `Game.builds`. Add a new build to
  those functions if it should change insulation or siege resistance.
- **Card state** lives in `Game.card_state` (id -> value), surviving travel/rebuilds. Normal
  cards store a single `float` (fuel %, felled %, explore %). Containers store a
  `{content, fill}` dict (see `CardIcon.fill_with`/`drain_content`/`boil`); `sealable`
  containers can hold fuel, open ones only water, and clean+dirty water always contaminates
  to dirty.

## How to validate changes

The Godot CLI is at `C:\Users\peter\.local\bin\godot.cmd` and is NOT reliably on PATH —
prepend it. From the repo root:

```
export PATH="/c/Users/peter/.local/bin:$PATH"   # Git Bash
godot.cmd --headless --path . --quit-after 5
```

A clean run prints no `SCRIPT ERROR` or `Parse Error` lines — that is the compile/load check.

For the deterministic sim there is a committed headless test harness under `tests/`. Run it:

```
godot.cmd --headless --path . -s res://tests/run_tests.gd
```

It prints `PASSED n  FAILED m`, a line per failure, and exits `0` when everything passes
(non-zero otherwise, so CI/scripts can gate on it). `tests/run_tests.gd` (a `SceneTree`)
builds a FRESH, seeded `Game` per test (`game.gd.new()`, `add_child`, then a manual
`_ready()` — `_ready` is NOT auto-called for a node added during `_init`), and drives
`Game.advance_time`. Per-area suites (`tests/test_*.gd`) cover seasons, conditions/lethality,
the event director + radio, research, construction, siege math, and determinism. Checks go
through `expect`/`expect_eq`/`expect_near` in `tests/test_helpers.gd` — NEVER `assert()`
(it aborts the process and is stripped in release). See `tests/README.md` to add a case.

Add or extend a suite whenever you touch the sim, then re-run the harness. For anything the
harness cannot reach, a throwaway `SceneTree` script driving `Game` and printing state is
still fine (run it with the same `-s` form).

## Gotchas / known debt

- `LOCATIONS` is a **mutated copy owned by `main.gd`**, not `Game`. Exploration reveals push
  fixtures/connections into it at runtime; `main` keeps a deep copy `_locations_initial` and
  restores it on `_restart`. Location titles/`indoor` are here, not in the sim.
- `ENEMIES` lives in the **UI layer** (`main.gd`), not `Game` — combat is a `main.gd`
  concern. Combat is the only RNG in the game.
- `LETHAL_METERS` is `[]`. No need kills instantly at 0 anymore; deprivation feeds a growing
  condition (low Warmth -> `hypo`, low Hydration -> `dehydration`, low Calories burns
  `weight` -> starvation, low Exertion -> `exhaustion`). Neither rest axis is lethal: Exertion
  (`Energy`) at 0 drops you into a short forced rest, `Sleep` at 0 into a collapse-sleep.
- `shelter_damp()` / `shelter_defense()` are **global**, hardcoded to the manor's build ids.
  When a second shelter lands they must become per-location (noted in the source comments).
- Two-place edits are easy to half-do: a `RECIPES` entry with no `perform_recipe` branch
  silently does nothing but pass time; a new lethal condition needs both a `CONDITIONS`
  stage with `lethal` and a driver that pushes its gauge up.
- Enemies on the location row are `fixtures`; `_combat_end("win")` erases the id from
  `LOCATIONS[...]["fixtures"]` and frees the card.
