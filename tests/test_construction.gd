extends RefCounted
## CONSTRUCTION / MAINTENANCE: gating, tagged effects, barricade capacity, damage, and
## repeatable proportional repairs kept separate from one-way build progress.

func _job_ids(jobs: Array) -> Array:
	var ids: Array = []
	for job in jobs:
		ids.append(str(job.get("id", "")))
	return ids

func run(tree, h) -> void:
	var g = tree.make_sim(3)
	var loc := "lordly_manor"
	var broken_hearth: CardData = load("res://data/cards/broken_hearth.tres")
	h.expect_eq(broken_hearth.build_project, "manor_hearth", "world fixture links directly to its construction recipe")
	h.expect(g.CONSTRUCTION.has(broken_hearth.build_project), "world fixture construction recipe exists")

	var avail = g.construction_for(loc)
	h.expect("manor_door" in avail, "manor door is available without research")
	h.expect("manor_barricade" in avail, "basic barricade is feasible before the first siege")
	h.expect(not ("manor_windows" in avail), "windows are gated by research")
	h.expect(not ("manor_barricade_reinforced" in avail), "advanced barricade is initially gated")
	h.expect_eq(g.construction_for("nowhere").size(), 0, "a non-shelter offers no builds")

	# Advanced capacity requires both its research and the physical first frame.
	g.researched["r_barricade"] = true
	h.expect(not ("manor_barricade_reinforced" in g.construction_for(loc)), "advanced barricade cannot be built before its basic frame")
	g.builds["manor_barricade"] = true
	g.barricades[loc] = 2
	h.expect("manor_barricade_reinforced" in g.construction_for(loc), "research plus the basic frame unlocks reinforcement")
	var basic = tree.make_sim(31)
	var basic_phases: int = basic.build_phase_count("manor_barricade")
	for i in basic_phases:
		basic.complete_build_phase("manor_barricade")
	h.expect_eq(basic.barricade_capacity(loc), 2, "basic construction establishes two-segment capacity")
	h.expect_eq(basic.barricade_segments(loc), 2, "completing the basic frame installs exactly two sound bars")

	# One-way phase completion remains guarded and capacity projects add only their own new bars.
	var phases: int = g.build_phase_count("manor_barricade_reinforced")
	for i in phases:
		g.complete_build_phase("manor_barricade_reinforced")
	h.expect(g.build_done("manor_barricade_reinforced"), "reinforced barricade completes through ordinary phases")
	h.expect_eq(g.barricade_capacity(loc), 4, "the reinforcement raises maximum capacity from two to four")
	h.expect_eq(g.barricade_segments(loc), 4, "newly constructed capacity arrives as two intact bars")
	g.damage_barricade(loc, 3)
	g.complete_build_phase("manor_barricade_reinforced")
	h.expect_eq(g.barricade_segments(loc), 1, "duplicate completion cannot conjure free repair segments")

	# Tagged effects drive both structure and warmth, with tangible consequences for damage.
	var effects = tree.make_sim(4)
	h.expect_near(effects.shelter_damp(loc), 0.40, "bare manor damp is 0.40")
	effects.builds["manor_door"] = true
	h.expect_eq(effects.shelter_structure_defense(loc), 2, "door effect raises structure defense")
	h.expect_near(effects.shelter_insulation(loc), 0.08, "door effect supplies insulation from data")
	h.expect_near(effects.shelter_damp(loc), 0.32, "door insulation tightens the shelter damp")
	effects.builds["manor_windows"] = true
	h.expect_near(effects.shelter_damp(loc), 0.20, "mixed door and shutter effects stack")
	effects.damaged_builds["manor_door"] = true
	h.expect_eq(effects.shelter_structure_defense(loc), 2, "damaged door loses defense while intact shutters still contribute")
	h.expect_near(effects.shelter_insulation(loc), 0.16, "damaged door retains half insulation beside intact shutters")

	# Repairs are dynamic repeatable jobs, not reset construction phases.
	var repair = tree.make_sim(5)
	repair.builds["manor_door"] = true
	repair.builds["manor_barricade"] = true
	repair.barricades[loc] = 0
	repair.damaged_builds["manor_door"] = true
	repair.shelter_breaches[loc] = true
	var ids := _job_ids(repair.maintenance_for(loc))
	h.expect("close_breach" in ids, "open shell exposes a close-breach maintenance job")
	h.expect("repair:manor_door" in ids, "damaged door exposes its own repair job")
	h.expect("patch_barricade" in ids, "missing bars expose a one-segment patch job")
	h.expect(repair.complete_maintenance(loc, "patch_barricade"), "one barricade patch can complete independently")
	h.expect_eq(repair.barricade_segments(loc), 1, "one patch restores exactly one segment")
	h.expect("patch_barricade" in _job_ids(repair.maintenance_for(loc)), "partial barricade damage remains optionally repairable")
	h.expect(repair.complete_maintenance(loc, "repair:manor_door"), "specific build repair completes")
	h.expect(not repair.damaged_builds.has("manor_door"), "door repair restores the completed build rather than rebuilding its phases")
	h.expect_eq(repair.shelter_structure_defense(loc), 1, "repaired door contributes even while the separate shell breach remains")
	h.expect(repair.complete_maintenance(loc, "close_breach"), "shell breach can be closed separately")
	h.expect(not repair.shelter_breaches.get(loc, false), "closing the shell breach leaves it sound")
	h.expect_eq(repair.shelter_structure_defense(loc), 2, "closing the shell restores innate cover beside the repaired door")
	h.expect(not repair.complete_maintenance("the_woods", "patch_barricade"), "maintenance cannot be completed from the wrong location")
	h.expect(repair.complete_maintenance(loc, "patch_barricade"), "the last missing barricade segment can be patched")
	h.expect(not repair.complete_maintenance(loc, "patch_barricade"), "a stale patch job cannot overfill the barricade")
