extends RefCounted
## FIRE SCOPING: a lit hearth only warms the room it is in (the manor). Being in the cellar while the
## manor hearth burns upstairs must NOT warm you — the warmth target is gated on fire_here().

func run(tree, h) -> void:
	# in the manor with the hearth lit, Warmth climbs
	var gm = tree.make_sim(21)
	gm.current_location = "lordly_manor"
	gm.location_indoor = true
	gm.lit_sources = {"hearth": true}
	gm.meters["Warmth"] = 40.0
	gm.temperature = 10.0
	for i in range(4):
		gm.card_state["hearth"] = 100.0  # keep the fire fuelled
		gm.advance_time(60)
	h.expect(gm.fire_here(), "fire_here() is true in the manor with the hearth lit")
	h.expect(gm.meters["Warmth"] > 40.0, "the hearth warms you in the manor")

	# the SAME lit hearth, but you are down in the cellar: it must not reach you
	var gc = tree.make_sim(21)
	gc.current_location = "cellar"
	gc.location_indoor = true
	gc.lit_sources = {"hearth": true}   # manor hearth still burning upstairs
	gc.meters["Warmth"] = 40.0
	gc.temperature = 10.0
	for i in range(4):
		gc.card_state["hearth"] = 100.0
		gc.advance_time(60)
	h.expect(not gc.fire_here(), "fire_here() is false in the cellar though the manor hearth burns")
	h.expect(gc.meters["Warmth"] < 40.0, "the manor hearth does not warm the cellar (Warmth falls there)")
	h.expect(gc.meters["Warmth"] < gm.meters["Warmth"], "cellar stays colder than the fire-warmed manor")
