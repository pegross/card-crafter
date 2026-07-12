extends RefCounted
## ATTENTION / HORDE TARGETING: coarse zones, distinct trace decay, weather and active-light
## modifiers, locked deterministic targets, generic arrival modes, explicit decoy destruction,
## location-owned alarm sound, and outdoor campfire construction state.

func run(tree, h) -> void:
	# Manor, grounds, and cellar deliberately share evidence; the woods is the one off-site zone.
	var zones = tree.make_sim(61)
	h.expect_eq(zones.attention_zone_for_location("lordly_manor"), "manor_compound", "manor belongs to the compound attention zone")
	h.expect_eq(zones.attention_zone_for_location("the_grounds"), "manor_compound", "grounds do not act as a free decoy beside the house")
	h.expect_eq(zones.attention_zone_for_location("cellar"), "manor_compound", "cellar evidence belongs to the compound")
	h.expect_eq(zones.attention_zone_for_location("the_woods"), "woods", "woods is the separate activity zone")
	h.expect_eq(zones.attention_zone_for_location("nowhere"), "", "unknown locations cannot accumulate evidence")
	zones.add_attention("the_woods", {"sound": 120.0, "scent": 20.0, "unknown": 99.0})
	h.expect_near(zones.attention_trace("woods", "sound"), 100.0, "trace additions clamp at 100")
	h.expect_near(zones.attention_trace("woods", "scent"), 20.0, "known trace kinds are location-bound")
	h.expect_near(zones.attention_trace("woods", "unknown"), 0.0, "unknown trace kinds are rejected")
	h.expect("noise" in zones.attention_summary("woods").to_lower(), "attention feedback is qualitative rather than a numeric bar")

	# Feedback reads the actual evidence channels, never the combined targeting score. Noise cannot
	# masquerade as smoke; scent cannot masquerade as sound; habitation and light keep their own prose.
	var sound_only = tree.make_sim(610)
	sound_only.add_attention("the_woods", {"sound": 40.0})
	var sound_words: String = sound_only.attention_summary("woods").to_lower()
	h.expect("noise" in sound_words and "scent" not in sound_words and "smoke" not in sound_words and "fire" not in sound_words, "sound-only evidence produces only sound feedback")
	var scent_only = tree.make_sim(611)
	scent_only.add_attention("the_woods", {"scent": 40.0})
	var scent_words: String = scent_only.attention_summary("woods").to_lower()
	h.expect("scent" in scent_words and "noise" not in scent_words and "sound" not in scent_words and "fire" not in scent_words, "scent-only evidence produces only scent feedback")
	var habitation_only = tree.make_sim(612)
	habitation_only.add_attention("the_woods", {"habitation": 40.0})
	var habitation_words: String = habitation_only.attention_summary("woods").to_lower()
	h.expect("habitation" in habitation_words and "noise" not in habitation_words and "smoke" not in habitation_words and "fire" not in habitation_words, "habitation-only evidence produces only physical-sign feedback")
	var light_only = tree.make_sim(613)
	light_only.minute = 0
	light_only.weather = "clear"
	light_only.builds["campfire_woods"] = true
	light_only.lit_sources["campfire_woods"] = true
	light_only.card_state["campfire_woods"] = 50.0
	var light_words: String = light_only.attention_summary("woods").to_lower()
	h.expect("fire" in light_words and "noise" not in light_words and "smoke" not in light_words and "scent" not in light_words, "light-only evidence produces only visibility feedback")

	# Sound vanishes in hours, scent in days, habitation much more slowly; rain washes/masks.
	var decay = tree.make_sim(62)
	decay.weather = "clear"
	decay.add_attention("the_woods", {"sound": 50.0, "scent": 50.0, "habitation": 50.0})
	decay._tick_attention(1.0)
	h.expect_near(decay.attention_trace("woods", "sound"), 32.0, "sound has the fast hourly decay")
	h.expect_near(decay.attention_trace("woods", "scent"), 49.25, "scent lingers across days")
	h.expect_near(decay.attention_trace("woods", "habitation"), 49.90, "habitation evidence decays slowest")
	var rain = tree.make_sim(63)
	rain.weather = "rain"
	rain.add_attention("the_woods", {"sound": 50.0, "scent": 50.0, "habitation": 50.0})
	rain._tick_attention(1.0)
	h.expect(rain.attention_trace("woods", "sound") < decay.attention_trace("woods", "sound"), "rain clears sound evidence faster")
	h.expect(rain.attention_trace("woods", "scent") < decay.attention_trace("woods", "scent"), "rain washes lingering scent faster")
	h.expect_near(rain.attention_trace("woods", "habitation"), decay.attention_trace("woods", "habitation"), "rain does not erase habitation")
	h.expect(rain.attention_score("woods") < decay.attention_score("woods"), "rain also masks what remains at score time")

	# Light is derived from authoritative lit/fuel state and does not linger as a trace.
	var light = tree.make_sim(64)
	light.minute = 0
	light.weather = "clear"
	light.lit_sources["hearth"] = true
	light.card_state["hearth"] = 100.0
	var night_light: float = light.active_light_attention("manor_compound")
	h.expect(night_light > 0.0, "a fuelled lit hearth shows in the manor zone at night")
	light.minute = 12 * 60
	h.expect(light.active_light_attention("manor_compound") < night_light, "the same flame is less conspicuous by day")
	light.minute = 0
	light.weather = "rain"
	h.expect(light.active_light_attention("manor_compound") < night_light, "rain obscures active light")
	light.extinguish("hearth")
	h.expect_near(light.active_light_attention("manor_compound"), 0.0, "extinguishing leaves no stale light score")
	var embers = tree.make_sim(640)
	embers.lit_sources["hearth"] = true
	embers.card_state["hearth"] = 6.0 # half an hour of fuel
	embers._tick_attention(2.0)
	h.expect_near(embers.attention_trace("manor_compound", "scent"), 0.60, "continuous fire scent stops accruing when its limited fuel would run out")

	# Outdoor fire rings are site projects, repeatable after explicit destruction, and map to stable ids.
	var camp = tree.make_sim(65)
	h.expect("campfire_grounds" in camp.construction_for("the_grounds"), "grounds campfire is a site project outside a shelter")
	h.expect("campfire_woods" in camp.construction_for("the_woods"), "woods campfire is a site project outside a shelter")
	h.expect_eq(camp.build_phase_count("campfire_woods"), 1, "woods fire ring is one 45-minute build phase")
	camp.complete_build_phase("campfire_woods")
	h.expect(camp.campfire_built("the_woods"), "completing the site establishes the woods campfire")
	h.expect_eq(camp.fire_source_at("the_woods"), "campfire_woods", "woods maps to its stable built fire source")
	camp.lit_sources["campfire_woods"] = true
	camp.card_state["campfire_woods"] = 100.0
	camp.current_location = "the_woods"
	h.expect(camp.fire_here(), "a lit built campfire is local fire in the woods")
	camp.minute = 0
	h.expect(camp.active_light_attention("woods") > 0.0, "built lit campfire contributes active woods light")
	h.expect_eq(camp.destroy_campfire("the_woods"), "campfire_woods", "explicit camp destruction reports the fixture lost")
	h.expect(not camp.campfire_built("the_woods") and not camp.is_lit("campfire_woods"), "destroying camp clears build, flame, and fuel state")
	h.expect("campfire_woods" in camp.construction_for("the_woods"), "a destroyed fire ring can be rebuilt from its first phase")

	# Target choice and intensity lock without consuming the combat/weather RNG stream.
	var target = tree.make_sim(66)
	var rng_before: int = target.rng.state
	var quiet: Dictionary = target.horde_target_snapshot(1)
	h.expect_eq(str(quiet["zone"]), "manor_compound", "an exact zero-trace tie preserves the authored manor target")
	target.add_attention("the_woods", {"sound": 50.0})
	var decoy: Dictionary = target.horde_target_snapshot(1)
	h.expect_eq(str(decoy["zone"]), "woods", "stronger woods evidence redirects the horde whether occupied or not")
	h.expect_eq(int(decoy["intensity"]), 1, "one alarm-sized lure redirects without automatically escalating first winter")
	target.add_attention("the_woods", {"sound": 20.0})
	var loud: Dictionary = target.horde_target_snapshot(1)
	h.expect_eq(int(loud["intensity"]), 2, "locked score thresholds can raise horde intensity")
	h.expect_eq(target.rng.state, rng_before, "attention scoring and target lock consume no RNG")
	target.pending_siege = decoy.duplicate(true)
	target.add_attention("lordly_manor", {"sound": 100.0})
	h.expect_eq(str(target.pending_siege["zone"]), "woods", "new evidence cannot retarget an already locked horde")

	# Generic claims distinguish an occupied open zone from a successful empty lure.
	var occupied = tree.make_sim(67)
	occupied.pending_siege = {"zone": "woods", "target": "the_woods", "intensity": 2}
	var occupied_claim: Dictionary = occupied.claim_pending_horde("the_woods")
	h.expect_eq(str(occupied_claim["mode"]), "open_ground", "being caught in the targeted woods becomes open-ground danger")
	h.expect_eq(int(occupied_claim["fights_left"]), 2, "open-ground danger scales from locked intensity")
	h.expect(not occupied.finish_horde("survived").is_empty(), "non-shelter horde can finish through the generic API")
	var shelter_claim = tree.make_sim(670)
	shelter_claim.pending_siege = shelter_claim.horde_target_snapshot(1)
	var manor_claim: Dictionary = shelter_claim.claim_pending_horde("the_woods")
	h.expect_eq(str(manor_claim["mode"]), "shelter_siege", "generic claim preserves the existing manor siege mode")
	h.expect(not bool(manor_claim["player_present"]), "presence is captured separately from the locked target")
	h.expect(not shelter_claim.begin_siege("lordly_manor", 1, false).is_empty(), "claimed manor horde enters the existing siege state machine")
	var compound_claim = tree.make_sim(671)
	compound_claim.pending_siege = compound_claim.horde_target_snapshot(1)
	var grounds_claim: Dictionary = compound_claim.claim_pending_horde("the_grounds")
	h.expect_eq(str(grounds_claim["mode"]), "shelter_approach", "being elsewhere in the compound requires a defend-or-stay-clear choice")
	h.expect(not bool(grounds_claim["player_present"]), "coarse attention geography never teleports the player into the target shelter")

	var empty = tree.make_sim(68)
	empty.builds["campfire_woods"] = true
	empty.lit_sources["campfire_woods"] = true
	empty.card_state["campfire_woods"] = 50.0
	empty.add_attention("the_woods", {"sound": 50.0, "scent": 40.0, "habitation": 20.0})
	empty.pending_siege = empty.horde_target_snapshot(1)
	var empty_claim: Dictionary = empty.claim_pending_horde("lordly_manor")
	h.expect_eq(str(empty_claim["mode"]), "empty_search", "an unoccupied woods target resolves as an investigation, not player combat")
	var empty_result: Dictionary = empty.resolve_empty_horde()
	h.expect_eq(str(empty_result["destroyed_source"]), "campfire_woods", "empty horde destroys the explicit conspicuous camp source")
	h.expect(not empty.campfire_built("the_woods"), "camp loss is tangible but unrelated cached items are untouched")
	h.expect(empty.active_horde.is_empty(), "empty-target resolution finishes and clears generic horde state")
	h.expect_near(empty.attention_trace("woods", "sound"), 0.0, "the passing horde consumes recent target sound")
	h.expect(empty.attention_trace("woods", "scent") < 40.0 and empty.attention_trace("woods", "habitation") < 20.0, "older target evidence is reduced rather than magically erased")
	h.expect(not empty.attention_aftermath_for_location("the_woods").is_empty(), "remote investigation leaves deferred discoverable aftermath")
	h.expect(empty.shelter_breaches.is_empty(), "a woods decoy never damages the manor")

	# A ground alarm is the first explicit lure found, and its sound belongs to its remote location.
	var alarm = tree.make_sim(69)
	alarm.location_ground["the_woods"] = ["alarm_clock", "firewood"]
	alarm.set_alarm_owner("the_woods")
	alarm.set_alarm(8, 5)
	alarm.advance_time(5)
	h.expect(alarm.attention_trace("woods", "sound") >= 49.0, "remote clock deposits its sound in the woods even when player is elsewhere")
	alarm.pending_siege = alarm.horde_target_snapshot(1)
	alarm.claim_pending_horde("lordly_manor")
	var alarm_result: Dictionary = alarm.resolve_empty_horde()
	h.expect_eq(str(alarm_result["destroyed_source"]), "alarm_clock", "horde finds a ringing ground clock before the camp")
	h.expect(not ("alarm_clock" in alarm.location_ground["the_woods"]), "destroyed decoy is removed from serialized ground state")
	h.expect_eq(alarm.alarm_at, -1, "destroying the clock stops its recurring alarm")
	h.expect("firewood" in alarm.location_ground["the_woods"], "empty-target damage never deletes a random cache item")

	# A pre-midnight ring is applied before the Director locks day 11's target.
	var timed = tree.make_sim(70)
	timed.day = 10
	timed.minute = 23 * 60 + 50
	timed.set_alarm_owner("the_woods")
	timed.set_alarm(23, 55)
	timed.advance_time(10)
	h.expect(not timed.pending_siege.is_empty(), "day-11 Director queues its horde after the clock boundary")
	h.expect_eq(str(timed.pending_siege.get("zone", "")), "woods", "pre-midnight woods alarm influences the same boundary's locked target")

	# Reset clears every new mutable system and returns the unique clock to its authored start place.
	timed.active_horde = {"mode": "open_ground"}
	timed.attention_aftermath["woods"] = {"seen": false}
	timed.reset()
	h.expect_eq(timed.attention_trace("woods", "sound"), 0.0, "reset clears attention traces")
	h.expect(timed.attention_aftermath.is_empty() and timed.active_horde.is_empty(), "reset clears aftermath and generic horde state")
	h.expect_eq(timed.alarm_owner, "lordly_manor", "reset returns clock ownership to its authored ground location")
