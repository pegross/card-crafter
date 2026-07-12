extends RefCounted
## HUNGER: a fast Satiation meter over the slow Weight reserve (single body reserve; Calories is gone).
## Satiation self-drains and is refilled by eating; Weight is driven by Satiation (a full belly builds
## it, an empty one burns it) and by hard work. Weight bottoming out is the starvation death, and an
## empty belly also wears on Mental.

func run(tree, h) -> void:
	# --- Satiation self-drains over elapsed time ---
	var g = tree.make_sim(3)
	var s0: float = g.meters["Satiation"]
	g.advance_time(120)  # 2h
	h.expect(g.meters["Satiation"] < s0, "Satiation drains across advance_time")

	# --- Weight is the single reserve now: Calories is gone entirely ---
	var g2 = tree.make_sim(3)
	h.expect(not g2.meters.has("Calories"), "Calories meter is gone")
	h.expect(g2.meters.has("Weight"), "Weight is a meter (the single body reserve)")
	h.expect(not g2._drain.has("Weight"), "Weight does not self-drain (it is driven by Satiation)")

	# --- Weight FALLS when Satiation is held low ---
	var g3 = tree.make_sim(3)
	var w_lo0: float = g3.meters["Weight"]
	for i in range(6):
		g3.meters["Satiation"] = 0.0
		g3.advance_time(60)
	h.expect(g3.meters["Weight"] < w_lo0, "Weight falls when Satiation is held low")

	# --- Weight RISES when Satiation is held high ---
	var g4 = tree.make_sim(3)
	g4.meters["Weight"] = 50.0
	var w_hi0: float = g4.meters["Weight"]
	for i in range(6):
		g4.meters["Satiation"] = 100.0
		g4.advance_time(60)
	h.expect(g4.meters["Weight"] > w_hi0, "Weight rises when Satiation is held high")

	# --- eating raises Satiation (modify up, as the eat actions do) ---
	var g5 = tree.make_sim(3)
	g5.meters["Satiation"] = 30.0
	g5.modify("Satiation", 35.0)
	h.expect_near(g5.meters["Satiation"], 65.0, "eating raises Satiation")

	# --- an empty belly wears on Mental ---
	var gm = tree.make_sim(3)
	gm.meters["Satiation"] = 0.0
	gm.meters["Mental"] = 80.0
	var m0: float = gm.meters["Mental"]
	gm.advance_time(120)
	h.expect(gm.meters["Mental"] < m0, "an empty Satiation drains Mental (hunger makes you miserable)")

	# --- Weight bottoming out is a starvation death ---
	var g6 = tree.make_sim(3)
	g6.meters["Weight"] = 3.0  # bound the loop; the burn path is unchanged
	var iters := 0
	while not g6.dead and iters < 60:
		g6.meters["Satiation"] = 0.0    # empty belly burns Weight
		g6.meters["Hydration"] = 80.0   # rule out other death paths
		g6.meters["Warmth"] = 80.0
		g6.meters["Energy"] = 80.0
		g6.meters["Immune"] = 80.0
		g6.meters["Mental"] = 80.0
		g6.advance_time(60)
		iters += 1
	h.expect(g6.dead, "Weight bottoming out is a starvation death")
	h.expect(g6.obituary.find("starvation") >= 0, "starvation obituary when Weight hits zero")
