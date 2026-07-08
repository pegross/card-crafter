extends RefCounted
## CONDITIONS / LETHALITY: incubation maturing after its window, gut_bug stage thresholds via
## _eval_stage, hypothermia Deep Cold as a lethal condition, a large wound as instant death, and
## the composed drain multiplier being capped at 1.8.

func run(tree, h) -> void:
	# --- incubation matures only after its window (gut_bug = 6h) ---
	var g = tree.make_sim(5)
	g.add_condition("gut_bug", 60.0, "unboiled water")
	g.advance_time(300)  # 5h, short of the 6h incubation
	h.expect(g.conditions.get("gut_bug", 0.0) == 0.0, "gut_bug still incubating at 5h")
	g.advance_time(120)  # crosses the 6h window
	h.expect(g.conditions.get("gut_bug", 0.0) > 0.0, "gut_bug matured after its 6h incubation")

	# --- gut_bug stage thresholds via _eval_stage ---
	var g2 = tree.make_sim(5)
	g2.conditions["gut_bug"] = 20.0
	g2._eval_stage("gut_bug")
	h.expect_eq(g2.cond_stage.get("gut_bug", 0), 1, "gut_bug 20 -> Queasy (stage 1)")
	g2.conditions["gut_bug"] = 55.0
	g2._eval_stage("gut_bug")
	h.expect_eq(g2.cond_stage.get("gut_bug", 0), 2, "gut_bug 55 -> Loose Stool (stage 2)")
	g2.conditions["gut_bug"] = 80.0
	g2._eval_stage("gut_bug")
	h.expect_eq(g2.cond_stage.get("gut_bug", 0), 3, "gut_bug 80 -> Dysentery (stage 3)")

	# --- hypothermia Deep Cold is lethal: drive Warmth to the floor ---
	var g3 = tree.make_sim(5)
	g3.location_indoor = true  # fire is off, so the cold room still chills you
	g3.meters["Warmth"] = 0.0
	var iters := 0
	while not g3.dead and iters < 48:
		g3.meters["Warmth"] = 0.0
		g3.advance_time(60)
		iters += 1
	h.expect(g3.dead, "driving Warmth low kills via hypothermia")
	h.expect(g3.obituary != "", "hypothermia death writes an obituary")
	h.expect_eq(g3.cond_stage.get("hypo", 0), 3, "hypo reached Deep Cold (stage 3)")

	# --- a large wound is instantly lethal ---
	var g4 = tree.make_sim(5)
	g4.take_wound(100.0)
	h.expect(g4.dead, "a massive wound is lethal on the spot")
	h.expect(g4.obituary != "", "wound death writes an obituary")

	# --- composed drain multiplier is capped at 1.8 ---
	var g5 = tree.make_sim(5)
	g5.conditions["gut_bug"] = 80.0
	g5._eval_stage("gut_bug")  # Dysentery pushes Hydration x2.2, above the cap
	var cm = g5._condition_multipliers()
	h.expect_near(float(cm.get("Hydration", 1.0)), 1.8, "composed Hydration drain mult capped at 1.8")
