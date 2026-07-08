extends RefCounted
## RESEARCH: availability gated by skill level, a single research slot, progress accruing only
## while awake, and completion making the unlocked build appear in construction_for().

func run(tree, h) -> void:
	var g = tree.make_sim(7)

	# availability is gated by skill level
	g.skills["woodworking"] = 25.0
	h.expect(g.research_available("r_shutters"), "r_shutters is available at woodworking 25")
	h.expect(not g.research_available("r_workbench"), "r_workbench needs woodworking 45")

	# start a project; the slot is single-occupancy
	h.expect(g.start_research("r_shutters"), "start_research(r_shutters) succeeds")
	h.expect_eq(g.current_research, "r_shutters", "current_research is now r_shutters")
	g.skills["woodworking"] = 45.0
	h.expect(g.research_available("r_workbench"), "r_workbench is now available")
	h.expect(not g.start_research("r_workbench"), "the single slot blocks a second project")
	h.expect_eq(g.current_research, "r_shutters", "still working on r_shutters")

	# progress accrues only while awake
	var p0: float = g.research_progress
	g.advance_time(60)  # 1 waking hour
	h.expect_near(g.research_progress, p0 + 1.0, "1 waking hour = +1 research progress", 0.0001)
	var p1: float = g.research_progress
	g.advance_time(60, true)  # 1 sleeping hour
	h.expect_near(g.research_progress, p1, "sleeping adds no research progress", 0.0001)

	# the unlocked build is not offered until the research completes
	h.expect(not ("manor_windows" in g.construction_for("lordly_manor")), "manor_windows is locked before research")

	# grind out the remaining hours (r_shutters needs 24h) while staying alive
	for i in range(26):
		h.keep_alive(g)
		g.advance_time(60)
	h.expect(g.researched.has("r_shutters"), "r_shutters completes after enough waking hours")
	h.expect_eq(g.current_research, "", "the research slot is freed on completion")
	h.expect("manor_windows" in g.construction_for("lordly_manor"), "completed research unlocks the manor_windows build")
