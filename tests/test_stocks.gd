extends RefCounted
## RENEWABLE STOCKS: the time-based logistic stock per location+resource (Game.stocks). A slot
## regrows toward K on the clock with a seed floor (so a barren spot recovers) and a per-season
## pace. The math (register_stock / stock_count / harvest_stock / add_stock / _tick_stocks) lives in
## game.gd and is headless-testable; the ground-card reconciliation lives in main.gd (boot-checked).

func run(tree, h) -> void:
	var g = tree.make_sim(7)

	# register_stock: a fresh slot starts half-stocked (K/2), and it is idempotent
	g.register_stock("loc_a", "firewood", 4)
	h.expect_eq(g.stocks["loc_a"]["firewood"]["S"], 2.0, "register starts S at K/2")
	h.expect_eq(g.stocks["loc_a"]["firewood"]["K"], 4.0, "register records K")
	g.stocks["loc_a"]["firewood"]["S"] = 3.5
	g.register_stock("loc_a", "firewood", 4)
	h.expect_eq(g.stocks["loc_a"]["firewood"]["S"], 3.5, "register is idempotent (never overwrites an existing slot)")

	# stock_count == floor(S), and 0 for an absent slot/id
	g.stocks["loc_a"]["firewood"]["S"] = 2.9
	h.expect_eq(g.stock_count("loc_a", "firewood"), 2, "stock_count is floor(S)")
	h.expect_eq(g.stock_count("nowhere", "firewood"), 0, "stock_count of an absent location is 0")
	h.expect_eq(g.stock_count("loc_a", "nothing"), 0, "stock_count of an absent id is 0")

	# _tick_stocks grows S toward K, and clamps: it never exceeds K no matter how long it runs
	g.day = 1  # Autumn (firewood's season multipliers are 1.0 in every season regardless)
	g.stocks["loc_a"]["firewood"]["S"] = 2.0
	g._tick_stocks(5.0)
	h.expect(g.stocks["loc_a"]["firewood"]["S"] > 2.0, "a tick grows S toward K")
	for i in range(60):
		g._tick_stocks(10.0)
	h.expect_near(g.stocks["loc_a"]["firewood"]["S"], 4.0, "S saturates at K over a long run", 0.0001)
	h.expect(g.stocks["loc_a"]["firewood"]["S"] <= 4.0, "S never exceeds K")

	# DECLINING pace: growth over a fixed step is smaller near K than at K/2 (logistic)
	g.stocks["loc_a"]["firewood"]["S"] = 2.0  # K/2
	var s0 := float(g.stocks["loc_a"]["firewood"]["S"])
	g._tick_stocks(1.0)
	var d_mid := float(g.stocks["loc_a"]["firewood"]["S"]) - s0
	g.stocks["loc_a"]["firewood"]["S"] = 3.8  # near K
	var s1 := float(g.stocks["loc_a"]["firewood"]["S"])
	g._tick_stocks(1.0)
	var d_near := float(g.stocks["loc_a"]["firewood"]["S"]) - s1
	h.expect(d_near < d_mid, "growth pace declines as S approaches K")

	# recovery from empty: the seed floor pulls a fully barren stock back up
	g.stocks["loc_a"]["firewood"]["S"] = 0.0
	g._tick_stocks(5.0)
	h.expect(g.stocks["loc_a"]["firewood"]["S"] > 0.0, "a barren stock recovers from zero (seed > 0)")

	# harvest_stock lowers S (floored at 0); a later tick regrows it
	g.stocks["loc_a"]["firewood"]["S"] = 3.0
	g.harvest_stock("loc_a", "firewood", 2)
	h.expect_near(g.stocks["loc_a"]["firewood"]["S"], 1.0, "harvest_stock lowers S by n", 0.0001)
	g.harvest_stock("loc_a", "firewood", 5)
	h.expect_eq(g.stocks["loc_a"]["firewood"]["S"], 0.0, "harvest_stock floors S at 0")
	g.stocks["loc_a"]["firewood"]["S"] = 1.0
	var before_regrow := float(g.stocks["loc_a"]["firewood"]["S"])
	g._tick_stocks(5.0)
	h.expect(g.stocks["loc_a"]["firewood"]["S"] > before_regrow, "a harvested stock regrows on a later tick")

	# add_stock raises S, clamped to K
	g.stocks["loc_a"]["firewood"]["S"] = 1.0
	g.add_stock("loc_a", "firewood", 1.5)
	h.expect_near(g.stocks["loc_a"]["firewood"]["S"], 2.5, "add_stock raises S", 0.0001)
	g.add_stock("loc_a", "firewood", 99.0)
	h.expect_eq(g.stocks["loc_a"]["firewood"]["S"], 4.0, "add_stock clamps to K")

	# SEASONAL: forage_food grows over a summer tick (season 3), but is ~flat over winter (season 1, mult 0)
	g.register_stock("loc_b", "forage_food", 4)
	g.day = 20
	h.expect_eq(g.season(), 3, "day 20 is Summer (season 3)")
	g.stocks["loc_b"]["forage_food"]["S"] = 2.0
	g._tick_stocks(5.0)
	h.expect(g.stocks["loc_b"]["forage_food"]["S"] > 2.0, "forage_food grows over a summer tick")
	g.day = 8
	h.expect_eq(g.season(), 1, "day 8 is Winter (season 1)")
	g.stocks["loc_b"]["forage_food"]["S"] = 2.0
	g._tick_stocks(5.0)
	h.expect_near(g.stocks["loc_b"]["forage_food"]["S"], 2.0, "forage_food is flat over a winter tick (mult 0)", 0.0001)

	# reset() clears every stock
	g.reset()
	h.expect_eq(g.stocks.size(), 0, "reset clears all stocks")

	# DETERMINISM: two identical runs tick to exactly the same S (no rng in the stock math)
	var a = tree.make_sim(3)
	var b = tree.make_sim(3)
	a.register_stock("x", "herbs", 3)
	b.register_stock("x", "herbs", 3)
	for i in range(6):
		a._tick_stocks(3.0)
		b._tick_stocks(3.0)
	h.expect(float(a.stocks["x"]["herbs"]["S"]) > 1.5, "the stock grows over repeated ticks")
	h.expect_near(float(a.stocks["x"]["herbs"]["S"]), float(b.stocks["x"]["herbs"]["S"]), "stock growth is deterministic across identical runs")
	a.free()
	b.free()
