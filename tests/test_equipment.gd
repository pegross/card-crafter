extends RefCounted
## EQUIPMENT: a worn garment (the hide coat) cuts Warmth LOSS in the cold. The insulation
## factor lives in Game.warmth_insulation() so it is deterministic and tunable, and reset()
## clears the worn slot. Warmth is written in exactly one place per step (the warm_delta
## block), so a single cold advance_time isolates the coat's effect.

func _cold_setup(g) -> void:
	# a fixed cold, dry, OUTDOOR state so warm_delta is negative; Warmth high so it never clamps
	g.location_indoor = false
	g.weather = "clear"
	g.wet = 0.0
	g.meters["Warmth"] = 90.0

func run(tree, h) -> void:
	# the factor itself is exposed and tunable
	var gf = tree.make_sim(11)
	h.expect_near(gf.warmth_insulation(), 0.65, "warmth_insulation() is the coat's 0.65 factor")

	# bare: no garment worn, one hour in the cold
	var g0 = tree.make_sim(11)
	_cold_setup(g0)
	var bare_before: float = g0.meters["Warmth"]
	g0.advance_time(60)
	var drop_bare: float = bare_before - g0.meters["Warmth"]

	# coated: identical seed + cold state, but wearing the hide coat
	var g1 = tree.make_sim(11)
	_cold_setup(g1)
	g1.worn = "hide_coat"
	var coat_before: float = g1.meters["Warmth"]
	g1.advance_time(60)
	var drop_coat: float = coat_before - g1.meters["Warmth"]

	h.expect(drop_bare > 0.0, "an hour of cold costs Warmth when bare")
	h.expect(drop_coat > 0.0, "an hour of cold still costs some Warmth in a coat")
	h.expect(drop_coat < drop_bare, "the coat makes Warmth drop LESS than going bare")
	h.expect_near(drop_coat, drop_bare * g1.warmth_insulation(), "the coat cuts the loss by exactly the insulation factor", 0.01)

	# reset() takes the coat off
	g1.reset()
	h.expect_eq(g1.worn, "", "reset() clears the worn slot")
