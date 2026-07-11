# Dead Air — sound implementation plan

Audience: a junior developer who is new to this repository and may be new to
Godot. Follow the phases in order. Do not integrate the entire source library.

Status: implementation plan only. The game currently contains no audio code or
audio nodes.

## 1. What you are building

Add non-positional sound to the current card-based prototype without changing
its survival rules. The finished MVP should provide:

- quiet interface and card-handling feedback;
- one ambience loop for each of the four locations;
- action sounds for all currently playable actions;
- variations for frequently repeated sounds such as chopping and impacts;
- persistent hearth and location ambience loops;
- distinct powered, static, signal, and dead radio states;
- combat, trap, sleep, collapse, and death feedback;
- separate volume controls through Godot audio buses;
- no effect on the deterministic gameplay random-number generator.

Do not add music, spoken broadcasts, positional 2D audio, procedural sound
generation, save-file settings, or final mastering in this task.

## 2. Repository orientation

Open the project in Godot 4.7. The important files are:

| Path | Purpose |
|---|---|
| `project.godot` | Project settings and autoload registration. `Game` is currently the only autoload. |
| `main.tscn` | The single main scene. Most UI is created from code. |
| `main.gd` | Actions, recipes, travel, search, combat, crafting, construction, and UI overlays. Most sound hooks belong here. |
| `card.gd` | Individual card input, click, drag, and drop behavior. |
| `card_row.gd` | Dropping/reordering a card in empty row space. |
| `autoload/game.gd` | Survival simulation and persistent game state. Do not put playback code here. |
| `docs/audio-mvp-cue-sheet.md` | Intended cue names, priorities, and art direction. |
| `demos/audio_source_library/selected_mvp/` | Audition candidates grouped by purpose. These are not final imported assets. |
| `demos/audio_source_library/README.md` | Source provenance, licensing notes, and remaining editing work. |

The simulation is action-driven. Time advances only after actions; there is no
continuous game-world `_process()` simulation. Ambient loops are the main
continuous audio.

## 3. Godot audio concepts used by this plan

- **AudioStream** is an imported audio resource such as WAV, Ogg Vorbis, or MP3.
- **AudioStreamPlayer** plays non-positional audio. Use it here because cards do
  not occupy meaningful positions in the game world.
- **Audio bus** is a mixer channel. A player sends its audio to one named bus.
- **One-shot** is a sound that plays once, such as a card drop or axe strike.
- **Loop** repeats until stopped, such as wind, room tone, or the hearth.
- **Autoload** is a Node created before the main scene and available globally.
  The new audio service will be an autoload named `Audio`.

Godot 4.7 imports WAV, Ogg Vorbis, and MP3. It does not list FLAC as an import
format, so convert the two selected FLAC candidates before putting them under
`assets/audio/`. Godot recommends WAV for short/repeated effects and Ogg Vorbis
for long sounds such as ambience. See the official
[audio import guide](https://docs.godotengine.org/en/4.7/tutorials/assets_pipeline/importing_audio_samples.html).

## 4. Target folder layout

Create this production-facing layout. Copy only chosen candidates into it:

```text
assets/audio/
  ui/
  ambience/
  search/
  wood/
  fire_cooking/
  survival/
  radio/
  creatures/
  combat/
```

Rules:

1. Keep `demos/audio_source_library/` as provenance and audition material.
2. Never reference `raw_packs/` or `extracted/` from game code.
3. Copy the selected candidate, rename it to its cue-sheet name, trim silence,
   and convert it before integration.
4. Use 16-bit or 24-bit WAV at no more than 48 kHz for short effects.
5. Use Ogg Vorbis for ambience and other longer loops.
6. Keep the source manifest. For Freesound previews, add `DEMO_ONLY` to the
   filename until replaced by the original-quality download.
7. Do not normalize every source blindly to 0 dB. Level-match by ear and leave
   headroom; the bus limiter is only a safety net.

For the first implementation pass, one acceptable file per cue is enough.
Add the additional variations after the playback system is proven.

## 5. Phase A — prepare a very small vertical slice

Before writing the full system, prepare these files first:

```text
assets/audio/ui/ui_card_lift_01.wav
assets/audio/ui/ui_card_place_01.wav
assets/audio/ui/ui_card_detail_open.wav
assets/audio/ui/ui_panel_close.wav
assets/audio/ui/ui_action_blocked.wav
assets/audio/wood/wood_axe_oak_01.wav
assets/audio/wood/wood_oak_fall.ogg
assets/audio/fire_cooking/hearth_fire_loop.ogg
assets/audio/radio/radio_switch_on_01.ogg
assets/audio/radio/radio_static_loop.ogg
assets/audio/ambience/amb_grounds_loop.ogg
```

Import the files by placing them under `assets/audio/` while the Godot editor is
open. Wait for import to finish. Click each file in the FileSystem panel and use
the preview control to verify that it plays.

For loops, enable **Loop** in the Import dock and click **Reimport**. Do not enable
looping on one-shots. A looping stream never emits `finished`, so loop players
must be stopped explicitly.

Acceptance check: every prepared file plays in the editor, starts immediately,
contains no accidental silence, and has the correct loop setting.

## 6. Phase B — create the audio buses

Open the **Audio** panel at the bottom of the Godot editor. Starting from Master,
add these buses in this order:

```text
Master
UI
SFX
Ambience
Radio
```

Route all four child buses to Master. Use these safe starting volumes:

| Bus | Starting volume |
|---|---:|
| UI | -8 dB |
| SFX | -5 dB |
| Ambience | -18 dB |
| Radio | -10 dB |

Add a Limiter as the final effect on Master. Do not add reverb, distortion, or
heavy EQ yet. Save the layout as the project's default bus layout. Godot effects
operate on every sound routed through a bus; see the official
[audio effects guide](https://docs.godotengine.org/en/4.7/tutorials/audio/audio_effects.html).

Acceptance check: reopening the project still shows all five buses.

## 7. Phase C — create the `Audio` autoload

Create `autoload/audio.gd`, extending `Node`. Register it in **Project > Project
Settings > Globals > Autoload** with the name `Audio`. The resulting section in
`project.godot` should contain both `Game` and `Audio`.

### 7.1 Responsibilities

`Audio` should be the only code that knows file paths or creates
`AudioStreamPlayer` nodes. It must provide:

```gdscript
Audio.play_cue("ui_card_lift")
Audio.set_location("the_grounds")
Audio.set_hearth_active(true)
Audio.play_radio_listen(is_powered, found_signal)
Audio.stop_all()
Audio.validate_registry()
```

Game code should request semantic cue names. It should never call `load()` on an
audio path or create its own player.

### 7.2 Player structure

In `_ready()`, create:

- 12 `AudioStreamPlayer` nodes for overlapping one-shots;
- 2 `AudioStreamPlayer` nodes for ambience crossfading;
- 1 loop player for the hearth;
- 1 player for radio sequences.

Twelve one-shot players are enough for this prototype. When `play_cue()` is
called, find the first player that is not currently playing. If all are busy,
reuse the oldest one. This prevents an axe strike from cutting off UI or combat
audio.

Set a player's `bus` immediately before playback. Always reset `volume_db` and
`pitch_scale` before reusing a pooled player; otherwise a previous cue's settings
will leak into the next cue.

### 7.3 Cue registry

Define one dictionary in `audio.gd`. Begin with the vertical-slice cues, then
fill it from the cue sheet. Use this shape:

```gdscript
const CUES := {
    "ui_card_lift": {
        "bus": "UI",
        "streams": [
            preload("res://assets/audio/ui/ui_card_lift_01.wav"),
        ],
        "volume_db": -5.0,
        "pitch_min": 0.98,
        "pitch_max": 1.02,
    },
    "wood_axe_oak": {
        "bus": "SFX",
        "streams": [
            preload("res://assets/audio/wood/wood_axe_oak_01.wav"),
        ],
        "volume_db": -2.0,
        "pitch_min": 0.97,
        "pitch_max": 1.02,
    },
}
```

`play_cue(cue_name)` must:

1. check `CUES.has(cue_name)`;
2. print a clear error and return if the cue is unknown;
3. choose a stream without immediately repeating the last choice when more than
   one stream is available;
4. use a private audio-only `RandomNumberGenerator` for choice and pitch;
5. configure a free pooled player;
6. call `play()`.

Do **not** use `Game.rng`, `randf()`, or `randi()` for audio variation. The tests
expect deterministic gameplay. Audio choices must never consume gameplay random
numbers.

Godot also supplies `AudioStreamRandomizer`, which supports no-repeat playback
and pitch/volume variation. The dictionary/pool approach above is recommended
for this MVP because all cue mappings remain visible in one file. If you choose
randomizer resources instead, use `PLAYBACK_RANDOM_NO_REPEATS`; see the official
[AudioStreamRandomizer reference](https://docs.godotengine.org/en/4.7/classes/class_audiostreamrandomizer.html).

### 7.4 Loops and crossfades

Create this location mapping:

```gdscript
const LOCATION_AMBIENCE := {
    "the_grounds": preload("res://assets/audio/ambience/amb_grounds_loop.ogg"),
    "the_woods": preload("res://assets/audio/ambience/amb_woods_loop.ogg"),
    "lordly_manor": preload("res://assets/audio/ambience/amb_manor_loop.ogg"),
    "cellar": preload("res://assets/audio/ambience/amb_cellar_loop.ogg"),
}
```

`set_location(location_id)` must be idempotent: if that location is already
playing, do nothing. Otherwise:

1. set the unused ambience player to the new stream and the `Ambience` bus;
2. start it at approximately -40 dB;
3. tween it to 0 dB over 0.8 seconds;
4. tween the old ambience player to -40 dB over 0.8 seconds;
5. stop the old player when its tween finishes;
6. remember the current location ID.

`set_hearth_active(active)` must start or stop the hearth loop only when its state
actually changes. Fade over roughly 0.4 seconds instead of cutting abruptly.

Kill an old fade tween before starting a replacement tween on the same player.
This prevents rapid travel or restart from leaving multiple fades competing.

### 7.5 Radio helper

For the MVP, `play_radio_listen(is_powered, found_signal)` may use a short fixed
sequence:

- not powered: play `radio_dead_switch` only;
- powered, no signal: play switch-on, then radio static/tuning;
- powered, signal found: play switch-on, tuning, then `radio_signal_found`;
- finish with switch-off if the selected source is not already a complete cue.

Use `SceneTree.create_timer()` or a tween callback for delays. Do not `await` this
sequence from `main.gd`; game input and time progression should not wait for
audio to finish. Keep a monotonically increasing sequence token in `Audio`. If a
new radio listen begins, increment the token so delayed callbacks from the old
sequence do nothing.

### 7.6 Registry validation

`validate_registry()` should return `PackedStringArray` errors. Check:

- every cue has a non-empty stream list;
- no stream is null;
- every bus name exists using `AudioServer.get_bus_index(name) >= 0`;
- all four location ambience mappings exist.

Call it once from `_ready()` in debug builds and print every error. Do not crash a
release build because an optional sound is missing.

Acceptance check: a temporary call to `Audio.play_cue("ui_card_lift")` from
`main.gd::_ready()` plays once. Remove that temporary call after testing.

## 8. Phase D — wire interface and card handling

Implement these hooks before game-action sounds.

### `main.gd`

- In `_open_detail()`, record whether `detail_layer.visible` was false before
  rendering. Play `ui_card_detail_open` only when changing from hidden to visible.
  `_open_detail()` is also used to redraw an already-open craft/build screen, and
  those redraws must not repeatedly play the opening sound.
- In `_hide_detail()`, return immediately when already hidden. Otherwise play
  `ui_panel_close`, then hide it.
- At the start of `_show_time_passing(mins)`, after the existing early-return
  guard, play `ui_time_pass`.
- In `_reveal(e, is_loot)`, play `ui_item_revealed` only after a ground card,
  fixture, or location was successfully added. Do not play it for a flavor-only
  log entry or a duplicate reveal.
- In `on_card_right_clicked(card)`, play `ui_card_place` only after a card was
  successfully moved. Do not play it when the inventory is full.
- Add `func on_card_reordered() -> void`, which plays `ui_card_place` and then
  calls `on_layout_changed()`.

### `card.gd`

- Do not play audio directly from the card. In `_get_drag_data()`, the existing
  call to `main.on_drag_begin(self)` is enough; make `main.on_drag_begin()` play
  `ui_card_lift`.
- In `_drop_data()`, when this is only a reorder/move and not a recipe, replace
  the final `main.on_layout_changed()` call with `main.on_card_reordered()`.
- Do not play a card-place sound for a recipe. The action sound will replace it.

### `card_row.gd`

- In `_drop_data()`, after a successful move, call `main.on_card_reordered()`
  instead of `main.on_layout_changed()`.

Acceptance checks:

- Clicking a card plays one open sound.
- Switching tabs within the detail overlay does not replay it.
- Closing plays one close sound.
- Dragging begins with one lift sound.
- Dropping/reordering plays one place sound.
- Dropping onto a recipe target does not also play the generic place sound.

## 9. Phase E — add generic action cue metadata

Avoid a giant new `match` statement. Add an optional `audio` key to simple action
dictionaries in `main.gd`'s `ACTIONS` table.

Suggested mappings:

| Action/card | `audio` value |
|---|---|
| Hearth — Sit by fire | `fireside_rest` |
| Oak Tree — Fell | `wood_axe_oak` |
| Woods or Grounds search | `search_outdoors` |
| Manor or Cellar search | `search_interior` |
| Spoiled/Raw/Cooked Rat Meat | `eat_meat` |
| Canned Food | `eat_tinned` |
| Forage Food / Preserved Meat | `eat_dry` |
| Wool Blanket | `cloth_wrap` |
| Hide Coat on/off | `coat_on_off` |
| Log — Split | `wood_split` |
| Herbal Remedy / water | `drink` |
| Antibiotics | `medicine_pills` |
| Bandage | `bandage_apply` |

In `_perform(card, act)`, play `act["audio"]` only after all validation has
passed and immediately before time advances. Do not play it before checks such
as “no fire,” “already felled,” “empty,” or “nothing to cure.”

Specialized branches that return early—travel, wear/take-off, drinking, fighting,
snare, radio, and buildsite—must play their sound inside their own helper instead
of relying on the generic bottom half of `_perform()`.

For blocked actions, play `ui_action_blocked` at the same point where the failure
log is added. Add it only to actual user-triggered failures. Do not attach it to
internal guard clauses such as `if Game.dead: return`.

### Oak completion

The axe strike happens on every Fell action. After increasing the oak's state,
the existing code detects 100% and calls `_transform_fixture()`. Immediately
before that transform, play `wood_oak_fall`. This produces one chop followed by
the fall only on the final action.

Acceptance check: two Fell actions produce two varied strikes; only the second
one produces the tree-fall cue.

## 10. Phase F — wire recipes and survival helpers

Add an `audio` key to recipes where one cue is sufficient:

| Recipe | Cue |
|---|---|
| Firewood → Hearth | `hearth_add_wood` |
| Lighter → Tinder | `lighter_flick` |
| Burning Tinder → Hearth | `hearth_ignite` |
| Herbs → Hearth | `herbs_steep` |
| Rat Meat → Hearth | `cook_meat` |
| Cooked Meat → Hearth | `meat_smoking` |

In `perform_recipe(src, target, rec)`, play a recipe's cue only after the branch
has succeeded. Do not put one unconditional call at the top because many recipe
branches can reject empty containers, missing fire, full targets, or mixed
liquids.

Add direct calls after success for dynamic container recipes:

- filling from Stream/Rain Barrel: `water_fill`;
- pouring container to container: `liquid_pour`;
- topping up Lighter: `liquid_pour` at lower volume if the API supports an
  override;
- boiling dirty water at Hearth: `water_boiling`.

In `_do_drink()`, play `drink` only after determining that liquid is available.

After any recipe/action/time advancement, synchronize loops through one helper
in `main.gd`:

```gdscript
func _sync_world_audio() -> void:
    Audio.set_location(Game.current_location)
    var near_hearth := Game.current_location == "lordly_manor"
    Audio.set_hearth_active(near_hearth and Game.is_fire_lit())
```

Call `_sync_world_audio()` from `_refresh()`. The Audio methods must be
idempotent because `_refresh()` is called frequently through `Game.changed`.

Acceptance checks:

- Failed recipes are silent except for the blocked cue.
- Successful recipes play exactly one primary action cue.
- The hearth loop begins after ignition, continues while lit in the Manor, and
  fades out when fuel is exhausted or the player leaves the Manor.

## 11. Phase G — ambience, search, and travel

- Call `_sync_world_audio()` once near the end of `main.gd::_ready()` after the
  world is populated.
- Because `_refresh()` also synchronizes, changing `Game.current_location` in
  `_travel_to()` will crossfade ambience automatically.
- In `_travel_to()`, play `travel_outdoor` when `mins > 0`.
- For zero-minute base-compound movement, play `threshold_interior`. A later pass
  may split this into door and cellar-stair cues.
- Search cues come from the `audio` metadata described above.
- `_reveal()` adds a quiet reveal sound after a successful discovery. It may
  overlap the search source; keep the reveal substantially quieter.

Acceptance check: Grounds, Woods, Manor, and Cellar each have one continuous bed
and crossfade without silence, pops, or two loops remaining audible indefinitely.

## 12. Phase H — radio states

The current `Game.radio_listen()` returns only prose, so determine the audio state
without parsing prose:

```gdscript
var was_powered := Game.radio_powered
var previous_broadcast_day := Game.radio_last_broadcast_day
var line := Game.radio_listen()
var found_signal := Game.radio_last_broadcast_day != previous_broadcast_day
Audio.play_radio_listen(was_powered, found_signal)
```

Place this in the existing `radio_listen` branch of `_perform()`. Capture both
values before advancing time. Never inspect the English log line to decide which
sound to play.

Expected behavior:

- Powered with no scheduled information: switch, tuning/static, switch off.
- Powered with a forecast/threat: switch, tuning, signal-found, switch off.
- Second listen on the same day: static path.
- After grid failure: dead mechanical switch only.

Acceptance check: use the existing director tests or temporarily set the Game
fields in the Remote Inspector to exercise all four paths.

## 13. Phase I — traps, combat, rest, and death

### Traps

- `_set_snare()` after successful placement: `snare_set`.
- `_check_snare()` when ready: `snare_catch`.
- `_check_snare()` when not ready: `snare_empty`.

### Combat

- `_start_combat()`: `encounter_rat` or `encounter_zombie` based on enemy ID.
- `_combat_strike()`: always play `combat_swing`.
- If player damage is greater than zero: also play `combat_hit`.
- If the enemy survives and attacks: play `combat_rat_attack` or
  `combat_zombie_attack`, then one quieter `combat_player_hurt` layer.
- If killed: play `combat_enemy_down` before `_combat_end("win")`.
- `_combat_flee()`: play `combat_flee` after the flee is accepted.

Do not base sound variation on `Game.strike_roll()` beyond the existing result;
never make an extra gameplay RNG call for audio.

### Rest, collapse, and death

- `_sleep()`: play `sleep_settle` after entering the valid sleep path.
- `_collapse_sleep()`: play `collapse` once at the start.
- `_show_death()`: call `Audio.stop_all(1.0)` to fade ambience/hearth/radio, then
  play `death` on SFX or a dedicated non-faded player.
- `_restart()`: call `Audio.stop_all(0.2)`, rebuild the world, then call
  `_sync_world_audio()`.

Acceptance check: combat swing/hit/attack layers remain clear and never produce
obvious digital clipping on Master.

## 14. Phase J — crafting and construction

Add `audio` metadata to `Game.CONSTRUCTION` phases and `Game.CRAFTS` entries, or
map their IDs in `main.gd`. Metadata is preferred because the cue remains beside
the action definition.

Suggested families:

- door, shutters, workbench, mallet, and snare craft: `construction_wood`;
- hearth rebuild: `construction_stone`;
- hide coat: `cloth_hide_stitch`;
- kindling: `wood_split`.

In `_do_build_phase()` and `_do_craft()`, play after material validation and
consumption but before `_show_time_passing()`. If a final project has a unique
completion cue, play it only after `Game.build_done(id)` becomes true.

## 15. Testing

### 15.1 Automated registry test

Create `tests/test_audio.gd` as a `RefCounted` suite and register it in the
`suites` dictionary in `tests/run_tests.gd`. Because `Audio` is now a registered
autoload, use the global `Audio` instance; do not instantiate a second audio
manager inside the test.

Call `Audio.validate_registry()` and use the existing `h.expect()` helpers.
Check:

- validation returns no errors;
- every P0 cue name from a maintained `REQUIRED_P0_CUES` array exists;
- every configured bus string is one of `UI`, `SFX`, `Ambience`, or `Radio`;
- location mapping contains all four current location IDs;
- the manager exposes a private `RandomNumberGenerator` for audio selection.

Separately verify by code review that `autoload/audio.gd` never references
`Game.rng`; absence of a forbidden reference is not useful to test at runtime.

Do not test whether speakers produced sound in headless mode. Test registry
structure and resource validity only.

Run:

```powershell
godot.cmd --headless --path . -s res://tests/run_tests.gd
```

All existing deterministic tests must still pass.

### 15.2 Manual smoke test

Start a fresh game and perform this exact route:

1. Open and close a card.
2. Drag/reorder a card and right-click it between ground/inventory.
3. Search Grounds until Manor is revealed; enter Manor.
4. Search/build enough to obtain and rebuild the Hearth.
5. Light Tinder, ignite Hearth, add Firewood, leave and re-enter Manor.
6. Travel to Woods, fell Oak twice, and split the resulting Log.
7. Fill a container, pour it, boil water, drink, and eat one item.
8. Listen to powered Radio twice on one day.
9. Fight Rat or Zombie; exercise strike and flee if possible.
10. Set/check a Snare.
11. Rest, sleep, force collapse in a debug run, and trigger death/restart.

For every step, check:

- sound fires once, not twice;
- failure paths do not play success audio;
- repeated cues vary without extreme pitch changes;
- ambience and hearth state are correct;
- no cue is much louder than the rest;
- Master never shows sustained clipping;
- closing/reopening and restart leave no orphaned loops.

## 16. Suggested implementation commits

Keep the work reviewable:

1. `audio: add approved MVP assets and bus layout`
2. `audio: add Audio autoload and registry validation`
3. `audio: hook card UI and location ambience`
4. `audio: hook survival actions and hearth state`
5. `audio: hook radio, traps, and combat`
6. `audio: add registry tests and level balancing`

Do not combine audio hookup with unrelated gameplay or UI refactors.

## 17. Definition of done

The implementation is complete when:

- all P0 actions in `docs/audio-mvp-cue-sheet.md` have an audible path;
- every referenced asset lives under `assets/audio/`;
- no game code references `demos/audio_source_library/`;
- Audio owns all audio players and paths;
- UI, SFX, Ambience, and Radio buses work independently;
- repeated cues avoid immediate repeats and use subtle variation;
- ambience crossfades and hearth/radio loops stop correctly;
- audio never consumes gameplay RNG;
- every blocked action is distinguishable from success;
- all automated tests pass;
- the manual smoke route passes without double playback, orphan loops, or
  clipping;
- no compressed preview is accidentally treated as a production master.

## 18. Common mistakes to avoid

- Do not add an `AudioStreamPlayer` to every card. Cards are created and destroyed
  dynamically; centralized playback is simpler and prevents duplicate nodes.
- Do not put audio calls inside `autoload/game.gd`. The simulation is tested and
  should remain independent from presentation.
- Do not use `AudioStreamPlayer2D`; the board has no meaningful world-space audio.
- Do not use `Game.rng` for variants.
- Do not start a loop every time `_refresh()` runs. Loop setters must be
  idempotent.
- Do not play success audio before validation.
- Do not attach generic card-place and recipe sounds to the same drop.
- Do not leave FLAC files in `assets/audio/`; convert them first.
- Do not enable Loop on one-shots.
- Do not expect `finished` from a looping stream.
- Do not tune final levels while listening to files individually. Balance them
  while playing the game with ambience and overlapping actions active.
