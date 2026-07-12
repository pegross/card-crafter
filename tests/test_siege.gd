extends RefCounted
## SIEGE: deterministic pressure, preparation gradient, attended choices, positional breach
## advantage, unattended damage, and clean separation between house state and combat RNG.

func _outcomes(results: Array) -> Array:
	var out: Array = []
	for result in results:
		out.append(str(result.get("outcome", "")))
	return out

func run(tree, h) -> void:
	var loc := "lordly_manor"
	var g = tree.make_sim(3)
	h.expect_eq(g.siege_pressures(1), [1, 2, 3], "first siege has three escalating pushes despite intensity 1")
	h.expect_eq(g.siege_pressures(2), [2, 3, 3, 4], "second intensity grows to four pushes")
	h.expect_eq(g.shelter_structure_defense(loc), 1, "bare manor shell supplies one structure point")
	h.expect_eq(g.shelter_structure_defense("open_field"), 0, "open ground has no shelter structure")

	# A bare but healthy defender can spend heavily to limit the first siege to one breach.
	var state: Dictionary = g.begin_siege(loc, 1, true)
	h.expect(not state.is_empty(), "an attended manor siege begins")
	var r1: Dictionary = g.resolve_siege_push("brace")
	var r2: Dictionary = g.resolve_siege_push("brace")
	var r3: Dictionary = g.resolve_siege_push("brace")
	h.expect_eq(_outcomes([r1, r2, r3]), ["firm", "strain", "breach"], "bracing every bare-manor push holds two and limits entry to the final push")
	h.expect_eq(int(g.active_siege["breaches"]), 1, "bare active defense suffers one breach")
	h.expect_near(float(g.meters["Energy"]), 25.0, "three braces cost substantial stamina")
	h.expect(not bool(r3["opening_strike"]), "bracing does not also grant the ready-at-gap advantage")
	h.expect(g.finish_siege_combat(true), "winning breach combat returns the siege to its state machine")
	h.expect_eq(str(g.active_siege["phase"]), "complete", "the final breach victory completes the ordeal")
	h.expect(bool((g.active_siege["last_result"] as Dictionary).get("complete", false)), "final breach result is marked complete after combat")
	var summary: Dictionary = g.finish_siege()
	h.expect_eq(int(summary["breaches"]), 1, "finished siege reports its breach count")

	# Door + rough barricade holds the first ordeal cleanly, with one visible segment of wear.
	var prepared = tree.make_sim(4)
	prepared.builds["manor_door"] = true
	prepared.builds["manor_barricade"] = true
	prepared.barricades[loc] = 2
	h.expect_eq(prepared.shelter_structure_defense(loc), 2, "the repaired door adds one permanent structure point")
	h.expect_eq(prepared.barricade_resistance(loc), 1, "two barricade segments contribute one resistance point")
	prepared.begin_siege(loc, 1, true)
	var prepared_results: Array = []
	for i in 3:
		prepared_results.append(prepared.resolve_siege_push("ready"))
	h.expect_eq(_outcomes(prepared_results), ["firm", "firm", "strain"], "door plus rough barricade prevents every first-siege breach")
	h.expect_eq(prepared.barricade_segments(loc), 1, "the final equal push leaves one crossbar damaged")
	h.expect_eq(int(prepared.active_siege["breaches"]), 0, "prepared first siege has no melee breach")

	# Standing ready preserves the zombie but grants one unanswered opening when entry happens.
	var ready = tree.make_sim(5)
	ready.begin_siege(loc, 1, true)
	ready.resolve_siege_push("ready")
	var breach: Dictionary = ready.resolve_siege_push("ready")
	h.expect_eq(str(breach["outcome"]), "breach", "conserving strength at a bare manor allows the second push through")
	h.expect(bool(breach["opening_strike"]), "standing ready grants the no-counter opening on that breach")
	h.expect_eq(str(ready.active_siege["phase"]), "combat", "an attended breach pauses push resolution for real combat")
	h.expect(ready.resolve_siege_push("ready").is_empty(), "another push cannot resolve while breach combat is pending")

	# Away is a valid strategy: no combat, but the unattended manor pays in structure.
	var away = tree.make_sim(6)
	away.begin_siege(loc, 1, false)
	var away_results: Array = away.resolve_unattended_siege()
	h.expect_eq(str(away.active_siege["phase"]), "complete", "unattended siege resolves without entering combat")
	h.expect(away.shelter_breaches.get(loc, false), "an unattended bare manor is left with an open structural breach")
	h.expect(_outcomes(away_results).count("breach") >= 1, "the away resolution records pressure breaches")

	var away_door = tree.make_sim(7)
	away_door.builds["manor_door"] = true
	away_door.begin_siege(loc, 1, false)
	away_door.resolve_unattended_siege()
	h.expect(away_door.damaged_builds.has("manor_door"), "an unattended door takes the structural consequence first")
	h.expect(not away_door.shelter_breaches.get(loc, false), "first-intensity mercy cap does not also tear open the shell")

	var away_prepared = tree.make_sim(8)
	away_prepared.builds["manor_door"] = true
	away_prepared.builds["manor_barricade"] = true
	away_prepared.barricades[loc] = 2
	away_prepared.begin_siege(loc, 1, false)
	away_prepared.resolve_unattended_siege()
	h.expect(not away_prepared.damaged_builds.has("manor_door"), "door plus barricade can earn an unattended clean structural hold")
	h.expect_eq(away_prepared.barricade_segments(loc), 1, "the unattended clean hold still records barricade wear")

	# Action authority and costs are enforced by Game, not only by button state.
	var authority = tree.make_sim(9)
	authority.builds["manor_barricade"] = true
	authority.barricades[loc] = 1
	authority.begin_siege(loc, 1, true)
	h.expect(authority.resolve_siege_push("away").is_empty(), "present defender cannot use the internal unattended action")
	authority.meters["Energy"] = 3.0
	h.expect(authority.resolve_siege_push("shore").is_empty(), "shore-up is rejected when its stamina cost cannot be paid")
	h.expect_eq(authority.barricade_segments(loc), 1, "rejected shore-up does not restore a free segment")
	var absent = tree.make_sim(10)
	absent.begin_siege(loc, 1, false)
	h.expect(absent.resolve_siege_push("ready").is_empty(), "absent defender cannot submit attended choices")

	# Higher winter intensity can progressively tear through distinct structural layers while away.
	var late = tree.make_sim(11)
	late.builds["manor_door"] = true
	late.builds["manor_windows"] = true
	late.begin_siege(loc, 3, false)
	late.resolve_unattended_siege()
	h.expect(late.damaged_builds.has("manor_door"), "late unattended ordeal can split the door brace")
	h.expect(late.damaged_builds.has("manor_windows"), "later pressure can continue into the shutters")
	h.expect(late.shelter_breaches.get(loc, false), "third structural consequence can open the shell at intensity three")

	# Mechanical outcomes do not consume or depend on combat RNG.
	var da = tree.make_sim(111)
	var db = tree.make_sim(999)
	for sim in [da, db]:
		sim.builds["manor_door"] = true
		sim.begin_siege(loc, 2, false)
	var rng_state_before: int = da.rng.state
	var a_results: Array = da.resolve_unattended_siege()
	var b_results: Array = db.resolve_unattended_siege()
	h.expect_eq(_outcomes(a_results), _outcomes(b_results), "siege outcomes are identical across RNG seeds")
	var a_margins: Array = []
	var b_margins: Array = []
	for result in a_results:
		a_margins.append(int(result["margin"]))
	for result in b_results:
		b_margins.append(int(result["margin"]))
	h.expect_eq(a_margins, b_margins, "siege margins are deterministic as well as outcome labels")
	h.expect_eq(da.rng.state, rng_state_before, "pure siege pushes do not consume or shift combat RNG")

	# Pending capture is atomic and reset clears every new persistence surface.
	var pending = tree.make_sim(12)
	pending.pending_siege = {"target": "not_a_shelter", "intensity": 1}
	h.expect(pending.begin_pending_siege(true).is_empty(), "invalid future target cannot begin")
	h.expect(not pending.pending_siege.is_empty(), "invalid target remains queued instead of being silently lost")
	pending.pending_siege = {"target": loc, "intensity": 1}
	h.expect(not pending.begin_pending_siege(false).is_empty(), "valid pending siege begins")
	h.expect(pending.pending_siege.is_empty(), "valid pending siege is consumed exactly once")
	pending.barricades[loc] = 2
	pending.damaged_builds["manor_door"] = true
	pending.shelter_breaches[loc] = true
	pending.siege_cooldown_until[loc] = 99
	pending.reset()
	h.expect(pending.pending_siege.is_empty() and pending.active_siege.is_empty(), "reset clears pending and active siege state")
	h.expect(pending.barricades.is_empty() and pending.damaged_builds.is_empty() and pending.shelter_breaches.is_empty(), "reset clears barricade and structural damage state")
	h.expect(pending.siege_cooldown_until.is_empty(), "reset clears future attention cooldown state")
