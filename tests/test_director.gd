extends RefCounted
## EVENT DIRECTOR: the authored spine, telegraph timing, the mechanical effects each event
## fires, the deterministic radio (threat outranks weather; a same-day repeat is static), and
## the endless-year schedule extension being idempotent.

func _find(g, id: String) -> Dictionary:
	for ev in g.scheduled_events:
		if str(ev["id"]) == id:
			return ev
	return {}

func run(tree, h) -> void:
	# --- the spine seeds exactly 5 events for a fresh game (gale, grid_failure, cold_snap, horde, drought) ---
	var g = tree.make_sim(42)
	h.expect_eq(g.scheduled_events.size(), 5, "the spine seeds 5 scheduled events")

	# --- telegraph timing: grid_failure (day 8, telegraph_days 3) -> telegraphed by day 5 ---
	var g2 = tree.make_sim(42)
	h.advance_days(g2, 3, false)  # to day 4
	var gf = _find(g2, "grid_failure")
	h.expect(not gf.is_empty(), "grid_failure is on the schedule")
	h.expect(not bool(gf.get("telegraphed", true)), "grid_failure is not telegraphed by day 4")
	h.advance_days(g2, 1, false)  # to day 5
	gf = _find(g2, "grid_failure")
	h.expect(bool(gf.get("telegraphed", false)), "grid_failure is telegraphed by day 5")

	# --- _fire_event effects are all in place by day 11 ---
	var g3 = tree.make_sim(42)
	h.advance_days(g3, 10, false)  # to day 11
	h.expect(g3.radio_powered == false, "grid_failure has killed radio power")
	h.expect(not g3.pending_siege.is_empty(), "horde_surge has queued a targeted siege")
	h.expect_eq(str(g3.pending_siege.get("target", "")), "lordly_manor", "M1 siege target is explicitly the manor")
	h.expect_eq(int(g3.pending_siege.get("intensity", 0)), 1, "first horde queues intensity one")
	var cold_active := false
	for a in g3.active_events:
		if float(a.get("temp_drop", 0.0)) < 0.0:
			cold_active = true
	h.expect(cold_active, "cold_snap is active with a negative temp_drop")

	# --- radio: threat outranks weather, and a same-day repeat listen is static ---
	var g4 = tree.make_sim(42)
	h.advance_days(g4, 6, false)  # to day 7, before grid_failure kills the power
	h.expect(g4.radio_powered, "radio is still powered on day 7")
	var line = g4.radio_listen()
	h.expect(line in g4.EVENT_FLAVOR["horde_surge_radio"], "radio warns of the horde (threat outranks weather)")
	var line2 = g4.radio_listen()
	h.expect(line2 in g4.RADIO_STATIC, "a second same-day listen is only static")

	# --- _extend_schedule is idempotent: no duplicate events after a long run ---
	var g5 = tree.make_sim(42)
	h.advance_days(g5, 59, false)  # to day 60, several years of extension
	var seen := {}
	var dup := false
	for ev in g5.scheduled_events:
		var key := "%s:%d" % [str(ev["id"]), int(ev["day"])]
		if seen.has(key):
			dup = true
		seen[key] = true
	h.expect(not dup, "no duplicate scheduled events after 60 days")
	var sz: int = g5.scheduled_events.size()
	g5._extend_schedule(g5._schedule_seeded_year)  # re-running the current year adds nothing
	h.expect_eq(g5.scheduled_events.size(), sz, "_extend_schedule is idempotent for the current year")
