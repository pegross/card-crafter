extends RefCounted
## TWO-LAYER HUNGER: a fast Satiation meter over the slow Calories reservoir.
## Satiation self-drains; Calories no longer self-drains but is driven by Satiation
## (rebuilds on a full belly, burns on an empty one). Calories bottoming out still
## burns Weight down to a starvation death.

func run(tree, h) -> void:
	# --- Satiation self-drains over elapsed time ---
	var g = tree.make_sim(3)
	var s0: float = g.meters["Satiation"]
	g.advance_time(120)  # 2h
	h.expect(g.meters["Satiation"] < s0, "Satiation drains across advance_time")

	# --- Calories no longer self-drains: it is gone from the drain table, Satiation took its place.
	# Its movement is driven entirely by Satiation (see the falls/rises cases below).
	var g2 = tree.make_sim(3)
	h.expect(not g2._drain.has("Calories"), "Calories no longer self-drains (removed from the drain table)")
	h.expect(g2._drain.has("Satiation"), "Satiation is the new self-draining hunger meter")

	# --- Calories FALLS when Satiation is held low ---
	var g3 = tree.make_sim(3)
	var cal_lo0: float = g3.meters["Calories"]
	for i in range(6):
		g3.meters["Satiation"] = 0.0
		g3.advance_time(60)
	h.expect(g3.meters["Calories"] < cal_lo0, "Calories falls when Satiation is held low")

	# --- Calories RISES when Satiation is held high ---
	var g4 = tree.make_sim(3)
	g4.meters["Calories"] = 50.0
	var cal_hi0: float = g4.meters["Calories"]
	for i in range(6):
		g4.meters["Satiation"] = 100.0
		g4.advance_time(60)
	h.expect(g4.meters["Calories"] > cal_hi0, "Calories rises when Satiation is held high")

	# --- eating raises Satiation (modify up, as the eat actions do) ---
	var g5 = tree.make_sim(3)
	g5.meters["Satiation"] = 30.0
	g5.modify("Satiation", 35.0)
	h.expect_near(g5.meters["Satiation"], 65.0, "eating raises Satiation")

	# --- Calories bottoming out still burns Weight to a starvation death ---
	var g6 = tree.make_sim(3)
	g6.meters["Calories"] = 0.0
	g6.weight = 5.0  # bound the loop; the burn path is unchanged
	var iters := 0
	while not g6.dead and iters < 60:
		g6.meters["Satiation"] = 0.0    # keep Calories pinned at the floor
		g6.meters["Hydration"] = 80.0   # rule out other death paths
		g6.meters["Warmth"] = 80.0
		g6.meters["Energy"] = 80.0
		g6.meters["Immune"] = 80.0
		g6.meters["Mental"] = 80.0
		g6.advance_time(60)
		iters += 1
	h.expect(g6.dead, "Calories bottoming out burns Weight to a starvation death")
	h.expect(g6.obituary.find("starvation") >= 0, "starvation obituary when Weight hits zero")
