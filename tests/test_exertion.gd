extends RefCounted
## STAMINA + SLEEP: the two rest axes that replaced the old Energy/sleep-debt coupling.
## The "Energy" meter is Stamina — physical work (advance_time physical=true) burns it fast, light
## activity or rest recovers it. "Sleep" is the deep need that only sleeping restores and
## it drains faster the more spent you are. Physical work also warms you and makes you sweat (wet).
## Also guards the warmth-in-a-cold-room regression (an unheated room must bleed Warmth, not pin it).

func run(tree, h) -> void:
	# --- light activity (awake, non-physical) RECOVERS Stamina; physical work BURNS it ---
	var glight = tree.make_sim(5)
	glight.meters["Energy"] = 50.0
	glight.meters["Warmth"] = 80.0
	glight.advance_time(60)
	h.expect(glight.meters["Energy"] > 50.0, "an awake hour of light activity recovers Stamina")

	var gphys = tree.make_sim(5)
	gphys.meters["Energy"] = 50.0
	gphys.meters["Warmth"] = 80.0
	gphys.advance_time(60, false, true)
	h.expect(gphys.meters["Energy"] < 50.0, "an hour of physical work burns Stamina")

	# --- physical work is fuelled by food/water and wears you toward sleep ---
	var gfuel = tree.make_sim(5)
	gfuel.meters["Warmth"] = 80.0
	var sat0: float = gfuel.meters["Satiation"]
	var wgt0: float = gfuel.meters["Weight"]
	var slp0: float = gfuel.meters["Sleep"]
	gfuel.advance_time(60, false, true)
	var gidle = tree.make_sim(5)
	gidle.meters["Warmth"] = 80.0
	gidle.advance_time(60)  # light hour for comparison
	h.expect(gfuel.meters["Satiation"] < sat0, "physical work makes you hungry (drains Satiation)")
	h.expect(gfuel.meters["Weight"] < wgt0, "physical work bites into your body reserve (Weight)")
	h.expect((slp0 - gfuel.meters["Sleep"]) > (slp0 - gidle.meters["Sleep"]), "physical work drains Sleep faster than a light hour")

	# --- heavier work (higher effort) costs more than lighter work of the same length ---
	var gheavy = tree.make_sim(5)
	gheavy.meters["Warmth"] = 80.0; gheavy.meters["Energy"] = 100.0
	gheavy.advance_time(60, false, true, 1.5)
	var glightwork = tree.make_sim(5)
	glightwork.meters["Warmth"] = 80.0; glightwork.meters["Energy"] = 100.0
	glightwork.advance_time(60, false, true, 1.0)
	h.expect(gheavy.meters["Energy"] < glightwork.meters["Energy"], "higher-effort work burns more Stamina")
	h.expect(gheavy.meters["Satiation"] < glightwork.meters["Satiation"], "higher-effort work burns more food")

	# --- continuous physical work is not sustainable: it runs the reserve to nothing ---
	var gburn = tree.make_sim(5)
	gburn.meters["Energy"] = 100.0
	gburn.meters["Warmth"] = 80.0
	gburn.advance_time(240, false, true)  # 4h flat out
	h.expect(gburn.meters["Energy"] <= 0.0, "four hours of unbroken physical work empties Stamina")

	# --- physical work generates body heat AND sweat (raises wetness), more when already spent ---
	var gsweat = tree.make_sim(5)
	gsweat.meters["Energy"] = 25.0  # already spent, so sweat runs high
	gsweat.meters["Warmth"] = 50.0
	gsweat.wet = 0.0
	gsweat.location_indoor = true
	gsweat.advance_time(60, false, true)
	h.expect(gsweat.wet > 0.0, "working while spent makes you sweat (raises wetness)")

	# --- sleeping restores both Sleep and Stamina ---
	var gs = tree.make_sim(5)
	gs.meters["Sleep"] = 40.0
	gs.meters["Energy"] = 40.0
	gs.meters["Warmth"] = 80.0  # decent sleep quality so rest is productive
	gs.advance_time(120, true)
	h.expect(gs.meters["Sleep"] > 40.0, "sleeping restores the Sleep need")
	h.expect(gs.meters["Energy"] > 40.0, "sleeping refreshes Stamina")

	# --- Sleep drains FASTER when spent (low Stamina) than when fresh ---
	var gfresh = tree.make_sim(7)
	gfresh.meters["Energy"] = 100.0
	gfresh.meters["Sleep"] = 90.0
	gfresh.meters["Warmth"] = 80.0
	gfresh.advance_time(60)
	var fresh_drain: float = 90.0 - gfresh.meters["Sleep"]

	var gtired = tree.make_sim(7)
	gtired.meters["Energy"] = 10.0
	gtired.meters["Sleep"] = 90.0
	gtired.meters["Warmth"] = 80.0
	gtired.advance_time(60)
	var tired_drain: float = 90.0 - gtired.meters["Sleep"]
	h.expect(tired_drain > fresh_drain, "a spent body loses the Sleep need faster than a fresh one")

	# --- staying spent (Stamina under 40) ramps the exhaustion condition ---
	var gex = tree.make_sim(3)
	for i in range(6):
		gex.meters["Energy"] = 10.0
		gex.meters["Hydration"] = 80.0
		gex.meters["Satiation"] = 80.0
		gex.meters["Warmth"] = 80.0
		gex.advance_time(60)
	h.expect(gex.conditions.get("exhaustion", 0.0) > 0.0, "staying spent ramps the exhaustion condition")

	# recovering Stamina lets exhaustion recede
	for i in range(8):
		gex.meters["Energy"] = 100.0
		gex.advance_time(60)
	h.expect(gex.conditions.get("exhaustion", 0.0) <= 0.0, "recovering Stamina clears the exhaustion condition")

	# --- the two forced-collapse kinds ---
	var gr = tree.make_sim(9)
	gr.meters["Energy"] = 0.0
	gr._check_collapse()
	h.expect(gr.force_sleep and gr.force_sleep_kind == "rest", "Stamina at 0 forces a collapse-rest")

	var gsl = tree.make_sim(9)
	gsl.meters["Energy"] = 50.0
	gsl.meters["Sleep"] = 0.0
	gsl._check_collapse()
	h.expect(gsl.force_sleep and gsl.force_sleep_kind == "sleep", "Sleep at 0 forces a collapse-sleep")

	# --- warmth regression: an unheated cold room bleeds Warmth instead of pinning at max ---
	var gw = tree.make_sim(13)
	gw.location_indoor = true
	gw.weather = "clear"
	gw.wet = 0.0
	gw.temperature = 8.0
	gw.lit_sources = {}
	gw.meters["Warmth"] = 100.0
	gw.advance_time(120)
	h.expect(gw.meters["Warmth"] < 100.0, "an unheated cold room bleeds Warmth instead of pinning it at max")
