extends RefCounted

func run(tree, h) -> void:
	var audio = tree.audio
	var errors: PackedStringArray = audio.validate_registry()
	h.expect(errors.is_empty(), "audio registry validates: " + "; ".join(errors))
	for cue_name in audio.REQUIRED_P0_CUES:
		h.expect(audio.CUES.has(cue_name), "required P0 cue exists: " + cue_name)
	for cue_name in audio.CUES:
		var bus_name := str((audio.CUES[cue_name] as Dictionary).get("bus", ""))
		h.expect(bus_name in ["UI", "SFX", "Ambience", "Radio"], "cue uses a configured child bus: " + cue_name)
	for location_id in ["the_grounds", "the_woods", "lordly_manor", "cellar"]:
		h.expect(audio.LOCATION_AMBIENCE.has(location_id), "location ambience exists: " + location_id)
	h.expect(not audio.LOCATION_AMBIENCE_ENABLED, "unreviewed location ambience remains disabled")
	h.expect_eq(audio.RADIO_LISTEN_CUE, "radio_dead_switch", "radio listen uses the short click only")
	h.expect(audio.DEFAULT_MAX_ONE_SHOT_SECONDS <= 3.0, "one-shot cues have a global duration safety cap")
	h.expect(float(audio.CUES["ui_panel_close"].get("volume_db", 0.0)) <= -18.0, "card close cue remains subtle")
	h.expect_eq(audio.CUES["alarm_clock_ring"]["streams"].size(), 1, "alarm uses one authentic mechanical clock recording")
	h.expect(float(audio.CUES["alarm_clock_ring"].get("volume_db", -99.0)) >= -10.0, "alarm ring is loud enough to demand attention")
	h.expect(float(audio.CUES["alarm_clock_ring"].get("max_seconds", 99.0)) <= 2.5, "long alarm source is capped to a short wake burst")
	h.expect(float(audio.CUES["alarm_clock_ring"].get("fade_out_seconds", 0.0)) >= 0.5, "alarm ends with an audible fade instead of a hard cut")
	h.expect(audio.CUES["alarm_clock_ring"]["streams"][0].get_length() > 10.0, "alarm source is the full field recording, not synthesized impacts")
	h.expect_eq(audio.CUES["alarm_clock_wind"]["streams"].size(), 2, "winding the clock rotates two real mechanism recordings")
	h.expect(float(audio.CUES["alarm_clock_wind"].get("max_seconds", 99.0)) <= 2.0, "clock winding stays a compact interaction sound")
	h.expect(AudioServer.get_bus_index(&"Music") >= 0, "dedicated music bus exists")
	h.expect(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Music")) >= -10.0, "music bus remains audibly mixed")
	h.expect(audio.BGM_STREAM != null and audio.BGM_STREAM.get_length() > 60.0, "background music is registered")
	h.expect(audio._bgm_stream == audio.BGM_STREAM, "BGM player uses the playable imported stream directly")
	h.expect(audio._bgm_player.finished.is_connected(audio.start_bgm), "background music restarts when the track finishes")
	h.expect(float(audio.CUES["combat_zombie_attack"].get("max_seconds", 99.0)) <= 1.0, "zombie strike stays short")
	h.expect(float(audio.CUES["combat_zombie_attack"].get("pitch_max", 1.0)) < 0.8, "zombie strike is pitched deeper")
	h.expect(float(audio.CUES["encounter_zombie"].get("max_seconds", 99.0)) <= 1.0, "zombie encounter vocal stays short")
	h.expect(float(audio.CUES["encounter_zombie"].get("pitch_max", 1.0)) < 0.8, "zombie encounter vocal is pitched deeper")
	for stream in audio.CUES["wood_axe_oak"]["streams"]:
		h.expect(stream.get_length() < 1.0, "tree chop selects a single short impact")
	h.expect_eq(audio.CUES["wood_axe_oak"]["streams"].size(), 1, "tree chopping always uses the dedicated axe chop")
	for stream in audio.CUES["hearth_ignite"]["streams"]:
		h.expect(stream.get_length() < 1.0, "hearth ignition selects a short event")
	h.expect(audio.audio_rng is RandomNumberGenerator, "audio manager owns an isolated audio RNG")
