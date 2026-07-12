extends SceneTree
## Headless test harness for the deterministic sim in autoload/game.gd.
##
## Run it with:
##   godot.cmd --headless --path . -s res://tests/run_tests.gd
##
## Exit code 0 = all passed, 1 = at least one failure (see the per-failure lines).
## Each test gets a FRESH sim via make_sim(): a new game.gd instance, _ready() called by hand
## (add_child in _init does NOT auto-fire _ready before we quit), a fixed rng seed, then reset().

## Build a fresh, seeded simulation instance.
var audio: Node

func make_sim(seed_val: int = 1) -> Node:
	var g = preload("res://autoload/game.gd").new()
	get_root().add_child(g)
	g._ready()          # REQUIRED: _ready is not auto-called for a node added during _init
	g.rng.seed = seed_val  # deterministic stream (reset() does not touch rng)
	g.reset()
	return g

func _init() -> void:
	# A script-run SceneTree does not instantiate project autoloads, so construct the
	# same service once for registry checks. Gameplay suites remain simulation-only.
	audio = preload("res://autoload/audio.gd").new()
	get_root().add_child(audio)
	audio._ready()
	var h = preload("res://tests/test_helpers.gd").new()
	var suites := {
		"seasons": preload("res://tests/test_seasons.gd").new(),
		"spoilage": preload("res://tests/test_spoilage.gd").new(),
		"conditions": preload("res://tests/test_conditions.gd").new(),
		"combat": preload("res://tests/test_combat.gd").new(),
		"celestial": preload("res://tests/test_celestial.gd").new(),
		"alarm": preload("res://tests/test_alarm.gd").new(),
		"attention": preload("res://tests/test_attention.gd").new(),
		"hunger": preload("res://tests/test_hunger.gd").new(),
		"director": preload("res://tests/test_director.gd").new(),
		"research": preload("res://tests/test_research.gd").new(),
		"construction": preload("res://tests/test_construction.gd").new(),
		"crafts": preload("res://tests/test_crafts.gd").new(),
		"trapping": preload("res://tests/test_trapping.gd").new(),
		"stocks": preload("res://tests/test_stocks.gd").new(),
		"siege": preload("res://tests/test_siege.gd").new(),
		"food": preload("res://tests/test_food.gd").new(),
		"equipment": preload("res://tests/test_equipment.gd").new(),
		"exertion": preload("res://tests/test_exertion.gd").new(),
		"warmth": preload("res://tests/test_warmth.gd").new(),
		"determinism": preload("res://tests/test_determinism.gd").new(),
		"audio": preload("res://tests/test_audio.gd").new(),
	}
	for name in suites:
		h.ctx(name)
		suites[name].run(self, h)

	print("PASSED %d  FAILED %d" % [h.passed, h.failed])
	for f in h.failures:
		print("  FAIL: " + f)
	quit(1 if h.failed > 0 else 0)
