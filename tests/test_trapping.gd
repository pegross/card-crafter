extends RefCounted
## TRAPPING: a snare set on open ground fills over in-world time and yields meat + a hide when
## sprung. The mechanic lives in Game (traps / place_snare / snare_ready / collect_snare) so it is
## headless-testable; the outdoor gate and the fixture UI live in main.gd, out of make_sim's reach.

func run(tree, h) -> void:
	var g = tree.make_sim(11)

	# a freshly set snare is not ready, and checking gives nothing yet
	g.place_snare("the_woods")
	h.expect(not g.snare_ready("the_woods"), "a freshly set snare is not ready")
	h.expect_eq(g.collect_snare("the_woods").size(), 0, "checking an unready snare returns nothing")
	h.expect_eq(g.collect_snare("nowhere").size(), 0, "checking a spot with no snare returns nothing")

	# not enough time: ~10h of a ~14h catch is still not ready
	for i in range(10):
		h.keep_alive(g)
		g.advance_time(60)
	h.expect(not g.snare_ready("the_woods"), "still not ready after ~10h")

	# enough total time: the snare springs
	for i in range(6):
		h.keep_alive(g)
		g.advance_time(60)
	h.expect(g.snare_ready("the_woods"), "the snare is ready after ~16h")

	# collecting yields meat + a hide and resets the snare so it keeps catching
	var yield_ids = g.collect_snare("the_woods")
	h.expect(("rat_meat" in yield_ids) and ("hide" in yield_ids), "a catch yields meat and a hide")
	h.expect_eq(yield_ids.size(), 2, "a catch yields exactly two items")
	h.expect(not g.snare_ready("the_woods"), "the snare resets to zero after collecting")
	h.expect(g.traps.has("the_woods"), "the snare stays set after collecting")

	# reset() clears every set snare
	g.reset()
	h.expect_eq(g.traps.size(), 0, "reset clears all set snares")

	# determinism: two identical runs advance a snare to exactly the same progress
	var a = tree.make_sim(3)
	var b = tree.make_sim(3)
	a.place_snare("the_grounds")
	b.place_snare("the_grounds")
	for i in range(8):
		a.advance_time(60)
		b.advance_time(60)
	h.expect(float(a.traps["the_grounds"]) > 0.0, "the snare progresses over time")
	h.expect_near(float(a.traps["the_grounds"]), float(b.traps["the_grounds"]), "trap progress is deterministic across identical runs")
	a.free()
	b.free()
