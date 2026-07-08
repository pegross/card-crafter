extends RefCounted
## CONSTRUCTION: construction_for() gated by shelter + research, complete_build_phase()
## progressing phase-by-phase then marking the build done, and shelter_damp() tightening as
## builds land.

func run(tree, h) -> void:
	var g = tree.make_sim(3)

	# gating: only manor projects, and research-locked ones are hidden until unlocked
	var avail = g.construction_for("lordly_manor")
	h.expect("manor_door" in avail, "manor_door is available (needs no research)")
	h.expect(not ("manor_windows" in avail), "manor_windows is gated by research")
	h.expect(not ("manor_workbench" in avail), "manor_workbench is gated by research")
	h.expect_eq(g.construction_for("nowhere").size(), 0, "a non-shelter offers no builds")

	# phased completion: manor_door has 2 phases
	h.expect_eq(g.build_phase_count("manor_door"), 2, "manor_door has 2 phases")
	h.expect(not g.build_done("manor_door"), "manor_door is not built yet")
	g.complete_build_phase("manor_door")
	h.expect_eq(g.build_phase_idx("manor_door"), 1, "one phase done")
	h.expect(not g.build_done("manor_door"), "still not fully built after one phase")
	g.complete_build_phase("manor_door")
	h.expect(g.build_done("manor_door"), "manor_door is done after both phases")

	# shelter_damp tightens (drops) as sealing builds complete
	var g2 = tree.make_sim(3)
	h.expect_near(g2.shelter_damp(), 0.40, "base damp is 0.40")
	g2.builds["manor_door"] = true
	h.expect_near(g2.shelter_damp(), 0.32, "the braced door tightens damp to 0.32")
	g2.builds["manor_windows"] = true
	h.expect_near(g2.shelter_damp(), 0.20, "shuttered windows tighten damp to 0.20")
