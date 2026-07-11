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
	h.expect(audio.audio_rng is RandomNumberGenerator, "audio manager owns an isolated audio RNG")
