extends Node
## Presentation-only audio service. Semantic cue names keep paths and players out of gameplay.

## The gathered location beds have not passed a listening review. Some are music/drone
## rather than neutral environmental ambience, so continuous location audio stays off
## until purpose-made loops are approved.
const LOCATION_AMBIENCE_ENABLED := false
const DEFAULT_MAX_ONE_SHOT_SECONDS := 3.0
const RADIO_LISTEN_CUE := "radio_dead_switch"

var REQUIRED_P0_CUES := PackedStringArray([
	"ui_card_lift", "ui_card_place", "ui_card_detail_open", "ui_panel_close", "ui_action_commit", "ui_action_blocked", "ui_item_revealed", "ui_time_pass",
	"travel_outdoor", "threshold_interior", "search_outdoors", "search_interior", "wood_axe_oak", "wood_oak_fall", "wood_split", "wood_handling", "construction_wood", "construction_stone",
	"lighter_flick", "tinder_catch", "hearth_ignite", "hearth_add_wood", "cook_meat", "water_boiling", "herbs_steep", "water_fill", "liquid_pour", "drink", "eat_tinned", "eat_dry", "eat_meat", "medicine_pills", "bandage_apply", "cloth_wrap", "coat_on_off",
	"radio_switch_on", "radio_tuning", "radio_static_loop", "radio_signal_found", "radio_switch_off", "radio_dead_switch", "snare_set", "snare_empty", "snare_catch", "encounter_rat", "encounter_zombie",
	"combat_swing", "combat_hit", "combat_rat_attack", "combat_zombie_attack", "combat_player_hurt", "combat_enemy_down", "combat_flee", "sleep_settle", "alarm_clock_wind", "alarm_clock_ring", "collapse", "death"
])

const CUES := {
	"ui_card_lift": {"bus": "UI", "streams": [preload("res://assets/audio/ui/ui_card_lift_01_DEMO_ONLY.ogg"), preload("res://assets/audio/ui/ui_card_lift_02_DEMO_ONLY.ogg"), preload("res://assets/audio/ui/ui_card_lift_03_DEMO_ONLY.ogg")], "volume_db": -10.0, "pitch_min": 0.98, "pitch_max": 1.02},
	"ui_card_place": {"bus": "UI", "streams": [preload("res://assets/audio/ui/ui_card_place_01_DEMO_ONLY.ogg"), preload("res://assets/audio/ui/ui_card_place_02_DEMO_ONLY.ogg"), preload("res://assets/audio/ui/ui_card_place_03_DEMO_ONLY.ogg")], "volume_db": -11.0, "pitch_min": 0.98, "pitch_max": 1.02},
	"ui_card_detail_open": {"bus": "UI", "streams": [preload("res://assets/audio/ui/ui_card_detail_open_DEMO_ONLY.ogg")], "volume_db": -12.0},
	# The dedicated close sample has a bright, dominant tail. A quiet paper movement
	# reads as dismissing a card without competing with the game state underneath.
	"ui_panel_close": {"bus": "UI", "streams": [preload("res://assets/audio/ui/ui_card_lift_02_DEMO_ONLY.ogg"), preload("res://assets/audio/ui/ui_card_lift_03_DEMO_ONLY.ogg")], "volume_db": -20.0, "pitch_min": 0.92, "pitch_max": 0.98},
	"ui_action_commit": {"bus": "UI", "streams": [preload("res://assets/audio/ui/ui_action_commit_DEMO_ONLY.ogg")], "volume_db": -12.0},
	"ui_action_blocked": {"bus": "UI", "streams": [preload("res://assets/audio/ui/ui_action_blocked_DEMO_ONLY.ogg")], "volume_db": -10.0},
	"ui_item_revealed": {"bus": "UI", "streams": [preload("res://assets/audio/ui/ui_item_revealed_01_DEMO_ONLY.ogg"), preload("res://assets/audio/ui/ui_item_revealed_02_DEMO_ONLY.ogg")], "volume_db": -16.0},
	"ui_time_pass": {"bus": "UI", "streams": [preload("res://assets/audio/ui/ui_time_pass_DEMO_ONLY.ogg")], "volume_db": -18.0},
	"travel_outdoor": {"bus": "SFX", "streams": [preload("res://assets/audio/ambience/travel_outdoor_01_DEMO_ONLY.ogg"), preload("res://assets/audio/ambience/travel_outdoor_02_DEMO_ONLY.ogg")], "volume_db": -8.0},
	"threshold_interior": {"bus": "SFX", "streams": [preload("res://assets/audio/ambience/threshold_interior_01_DEMO_ONLY.ogg"), preload("res://assets/audio/ambience/threshold_interior_02_DEMO_ONLY.ogg")], "volume_db": -9.0},
	"search_outdoors": {"bus": "SFX", "streams": [preload("res://assets/audio/search/search_outdoors_01_DEMO_ONLY.ogg"), preload("res://assets/audio/search/search_outdoors_02_DEMO_ONLY.ogg"), preload("res://assets/audio/search/search_outdoors_03_DEMO_ONLY.ogg")], "volume_db": -8.0},
	"search_interior": {"bus": "SFX", "streams": [preload("res://assets/audio/search/search_interior_01_DEMO_ONLY.ogg"), preload("res://assets/audio/search/search_interior_02_DEMO_ONLY.wav"), preload("res://assets/audio/search/search_interior_03_DEMO_ONLY.wav")], "volume_db": -8.0},
	# This take is Kenney RPG Audio's actual `chop.ogg`. The other short wood
	# variants are generic heavy impacts and read as dull knocks on a standing tree.
	"wood_axe_oak": {"bus": "SFX", "streams": [preload("res://assets/audio/wood/wood_split_01_DEMO_ONLY.ogg")], "volume_db": -5.0, "pitch_min": 0.98, "pitch_max": 1.02},
	"wood_oak_fall": {"bus": "SFX", "streams": [preload("res://assets/audio/wood/wood_oak_fall_DEMO_ONLY.ogg")], "volume_db": -4.0},
	"wood_split": {"bus": "SFX", "streams": [preload("res://assets/audio/wood/wood_split_01_DEMO_ONLY.ogg"), preload("res://assets/audio/wood/wood_split_02_DEMO_ONLY.ogg"), preload("res://assets/audio/wood/wood_split_03_DEMO_ONLY.ogg"), preload("res://assets/audio/wood/wood_split_04_DEMO_ONLY.ogg")], "volume_db": -6.0},
	"wood_handling": {"bus": "SFX", "streams": [preload("res://assets/audio/wood/wood_handling_01_DEMO_ONLY.ogg"), preload("res://assets/audio/wood/wood_handling_02_DEMO_ONLY.ogg"), preload("res://assets/audio/wood/wood_handling_03_DEMO_ONLY.ogg")], "volume_db": -9.0},
	"construction_wood": {"bus": "SFX", "streams": [preload("res://assets/audio/wood/construction_wood_01_DEMO_ONLY.ogg"), preload("res://assets/audio/wood/construction_wood_02_DEMO_ONLY.ogg"), preload("res://assets/audio/wood/construction_wood_03_DEMO_ONLY.ogg")], "volume_db": -7.0},
	"construction_stone": {"bus": "SFX", "streams": [preload("res://assets/audio/wood/construction_stone_01_DEMO_ONLY.ogg"), preload("res://assets/audio/wood/construction_stone_02_DEMO_ONLY.ogg")], "volume_db": -7.0},
	"lighter_flick": {"bus": "SFX", "streams": [preload("res://assets/audio/fire_cooking/lighter_flick_02_DEMO_ONLY.ogg"), preload("res://assets/audio/fire_cooking/lighter_flick_03_DEMO_ONLY.ogg")], "volume_db": -8.0},
	"tinder_catch": {"bus": "SFX", "streams": [preload("res://assets/audio/fire_cooking/tinder_catch_01_DEMO_ONLY.ogg"), preload("res://assets/audio/fire_cooking/tinder_catch_02_DEMO_ONLY.ogg")], "volume_db": -7.0},
	# Do not use hearth_ignite_01 here: it is the full 29-second fireplace bed.
	"hearth_ignite": {"bus": "SFX", "streams": [preload("res://assets/audio/fire_cooking/tinder_catch_01_DEMO_ONLY.ogg"), preload("res://assets/audio/fire_cooking/tinder_catch_02_DEMO_ONLY.ogg")], "volume_db": -7.0},
	"hearth_add_wood": {"bus": "SFX", "streams": [preload("res://assets/audio/fire_cooking/hearth_add_wood_01_DEMO_ONLY.ogg"), preload("res://assets/audio/fire_cooking/hearth_add_wood_02_DEMO_ONLY.ogg"), preload("res://assets/audio/fire_cooking/hearth_add_wood_03_DEMO_ONLY.ogg")], "volume_db": -7.0},
	"cook_meat": {"bus": "SFX", "streams": [preload("res://assets/audio/fire_cooking/cook_meat_01_DEMO_ONLY.ogg"), preload("res://assets/audio/fire_cooking/cook_meat_02_DEMO_ONLY.ogg")], "volume_db": -9.0},
	"water_boiling": {"bus": "SFX", "streams": [preload("res://assets/audio/fire_cooking/water_boiling_DEMO_ONLY.ogg")], "volume_db": -12.0, "max_seconds": 1.5},
	"herbs_steep": {"bus": "SFX", "streams": [preload("res://assets/audio/fire_cooking/herbs_steep_DEMO_ONLY.ogg")], "volume_db": -9.0},
	"water_fill": {"bus": "SFX", "streams": [preload("res://assets/audio/survival/water_fill_01_DEMO_ONLY.ogg"), preload("res://assets/audio/survival/water_fill_02_DEMO_ONLY.ogg")], "volume_db": -11.0, "max_seconds": 1.25},
	"liquid_pour": {"bus": "SFX", "streams": [preload("res://assets/audio/survival/liquid_pour_01_DEMO_ONLY.ogg"), preload("res://assets/audio/survival/liquid_pour_02_DEMO_ONLY.ogg")], "volume_db": -12.0, "max_seconds": 1.25},
	"drink": {"bus": "SFX", "streams": [preload("res://assets/audio/survival/drink_01_DEMO_ONLY.wav"), preload("res://assets/audio/survival/drink_02_DEMO_ONLY.wav")], "volume_db": -11.0},
	"eat_tinned": {"bus": "SFX", "streams": [preload("res://assets/audio/survival/eat_tinned_DEMO_ONLY.ogg")], "volume_db": -9.0},
	"eat_dry": {"bus": "SFX", "streams": [preload("res://assets/audio/survival/eat_dry_01_DEMO_ONLY.ogg"), preload("res://assets/audio/survival/eat_dry_02_DEMO_ONLY.ogg")], "volume_db": -10.0},
	"eat_meat": {"bus": "SFX", "streams": [preload("res://assets/audio/survival/eat_meat_01_DEMO_ONLY.ogg"), preload("res://assets/audio/survival/eat_meat_02_DEMO_ONLY.ogg")], "volume_db": -10.0},
	"medicine_pills": {"bus": "SFX", "streams": [preload("res://assets/audio/survival/medicine_pills_DEMO_ONLY.wav")], "volume_db": -10.0},
	"bandage_apply": {"bus": "SFX", "streams": [preload("res://assets/audio/survival/bandage_apply_01_DEMO_ONLY.wav"), preload("res://assets/audio/survival/bandage_apply_02_DEMO_ONLY.wav")], "volume_db": -9.0},
	"cloth_wrap": {"bus": "SFX", "streams": [preload("res://assets/audio/survival/cloth_wrap_01_DEMO_ONLY.wav"), preload("res://assets/audio/survival/cloth_wrap_02_DEMO_ONLY.wav")], "volume_db": -11.0},
	"coat_on_off": {"bus": "SFX", "streams": [preload("res://assets/audio/survival/coat_on_off_01_DEMO_ONLY.ogg"), preload("res://assets/audio/survival/coat_on_off_02_DEMO_ONLY.ogg")], "volume_db": -10.0},
	"radio_switch_on": {"bus": "Radio", "streams": [preload("res://assets/audio/radio/radio_switch_on_01_DEMO_ONLY.mp3")], "volume_db": -8.0},
	"radio_tuning": {"bus": "Radio", "streams": [preload("res://assets/audio/radio/radio_tuning_DEMO_ONLY.mp3")], "volume_db": -11.0},
	"radio_static_loop": {"bus": "Radio", "streams": [preload("res://assets/audio/radio/radio_static_loop_DEMO_ONLY.mp3")], "volume_db": -16.0},
	"radio_signal_found": {"bus": "Radio", "streams": [preload("res://assets/audio/radio/radio_signal_found_DEMO_ONLY.mp3")], "volume_db": -10.0},
	"radio_switch_off": {"bus": "Radio", "streams": [preload("res://assets/audio/radio/radio_switch_off_DEMO_ONLY.mp3")], "volume_db": -9.0},
	"radio_dead_switch": {"bus": "Radio", "streams": [preload("res://assets/audio/radio/radio_dead_switch_DEMO_ONLY.ogg")], "volume_db": -9.0},
	"snare_set": {"bus": "SFX", "streams": [preload("res://assets/audio/creatures/snare_set_01_DEMO_ONLY.ogg"), preload("res://assets/audio/creatures/snare_set_02_DEMO_ONLY.ogg")], "volume_db": -8.0},
	"snare_empty": {"bus": "SFX", "streams": [preload("res://assets/audio/creatures/snare_empty_DEMO_ONLY.ogg")], "volume_db": -9.0},
	"snare_catch": {"bus": "SFX", "streams": [preload("res://assets/audio/creatures/snare_catch_DEMO_ONLY.ogg")], "volume_db": -7.0},
	"encounter_rat": {"bus": "SFX", "streams": [preload("res://assets/audio/creatures/encounter_rat_DEMO_ONLY.mp3")], "volume_db": -7.0},
	"encounter_zombie": {"bus": "SFX", "streams": [preload("res://assets/audio/creatures/encounter_zombie_02_DEMO_ONLY.ogg")], "volume_db": -10.0, "pitch_min": 0.72, "pitch_max": 0.78, "max_seconds": 0.9},
	"combat_swing": {"bus": "SFX", "streams": [preload("res://assets/audio/combat/combat_swing_01_DEMO_ONLY.ogg"), preload("res://assets/audio/combat/combat_swing_02_DEMO_ONLY.ogg"), preload("res://assets/audio/combat/combat_swing_03_DEMO_ONLY.ogg")], "volume_db": -7.0},
	"combat_hit": {"bus": "SFX", "streams": [preload("res://assets/audio/combat/combat_hit_01_DEMO_ONLY.ogg"), preload("res://assets/audio/combat/combat_hit_02_DEMO_ONLY.ogg"), preload("res://assets/audio/combat/combat_hit_03_DEMO_ONLY.ogg")], "volume_db": -7.0},
	"combat_rat_attack": {"bus": "SFX", "streams": [preload("res://assets/audio/combat/combat_rat_attack_01_DEMO_ONLY.mp3"), preload("res://assets/audio/combat/combat_rat_attack_02_DEMO_ONLY.ogg")], "volume_db": -6.0},
	# Use the shortest vocal take and pitch it down into a compact, weightier strike.
	"combat_zombie_attack": {"bus": "SFX", "streams": [preload("res://assets/audio/combat/combat_zombie_attack_02_DEMO_ONLY.ogg")], "volume_db": -9.0, "pitch_min": 0.72, "pitch_max": 0.78, "max_seconds": 0.85},
	"combat_player_hurt": {"bus": "SFX", "streams": [preload("res://assets/audio/combat/combat_player_hurt_01_DEMO_ONLY.ogg"), preload("res://assets/audio/combat/combat_player_hurt_02_DEMO_ONLY.ogg")], "volume_db": -13.0},
	"combat_enemy_down": {"bus": "SFX", "streams": [preload("res://assets/audio/combat/combat_enemy_down_01_DEMO_ONLY.ogg"), preload("res://assets/audio/combat/combat_enemy_down_02_DEMO_ONLY.ogg")], "volume_db": -7.0},
	"combat_flee": {"bus": "SFX", "streams": [preload("res://assets/audio/combat/combat_flee_DEMO_ONLY.ogg")], "volume_db": -8.0},
	"sleep_settle": {"bus": "SFX", "streams": [preload("res://assets/audio/combat/sleep_settle_DEMO_ONLY.ogg")], "volume_db": -12.0},
	"alarm_clock_wind": {"bus": "SFX", "streams": [preload("res://assets/audio/survival/alarm_clock_wind_01_CC0_DEMO_ONLY.wav"), preload("res://assets/audio/survival/alarm_clock_wind_02_CC0_DEMO_ONLY.wav")], "volume_db": -12.0, "pitch_min": 0.98, "pitch_max": 1.02, "max_seconds": 2.0},
	# A real old mechanical alarm recording, cut short at playback so it wakes without dominating.
	"alarm_clock_ring": {"bus": "SFX", "streams": [preload("res://assets/audio/survival/alarm_clock_ring_PIXABAY_LICENSE_DEMO_ONLY.mp3")], "volume_db": -9.0, "max_seconds": 2.5, "fade_out_seconds": 0.7},
	"collapse": {"bus": "SFX", "streams": [preload("res://assets/audio/combat/collapse_DEMO_ONLY.ogg")], "volume_db": -6.0},
	"death": {"bus": "SFX", "streams": [preload("res://assets/audio/combat/death_DEMO_ONLY.ogg")], "volume_db": -5.0},
}

const LOCATION_AMBIENCE := {
	"the_grounds": preload("res://assets/audio/ambience/amb_grounds_loop_DEMO_ONLY.mp3"),
	"the_woods": preload("res://assets/audio/ambience/amb_woods_loop_DEMO_ONLY.mp3"),
	"lordly_manor": preload("res://assets/audio/ambience/amb_manor_loop_DEMO_ONLY.mp3"),
	"cellar": preload("res://assets/audio/ambience/amb_cellar_loop_FALLBACK_DEMO_ONLY.mp3"),
}
const HEARTH_STREAM = preload("res://assets/audio/fire_cooking/hearth_fire_loop_DEMO_ONLY.wav")
const BGM_STREAM = preload("res://assets/audio/music/bgm.wav")

var audio_rng := RandomNumberGenerator.new()
var _one_shots: Array[AudioStreamPlayer] = []
var _one_shot_fades: Array[Tween] = []
var _player_ages: Array[int] = []
var _last_stream_indices := {}
var _age: int = 0
var _ambience_players: Array[AudioStreamPlayer] = []
var _active_ambience: int = -1
var _current_location := ""
var _hearth_player: AudioStreamPlayer
var _hearth_stream: AudioStream
var _bgm_player: AudioStreamPlayer
var _bgm_stream: AudioStream
var _radio_player: AudioStreamPlayer
var _hearth_active := false
var _ambience_tweens: Array[Tween] = []
var _hearth_tween: Tween
var _bgm_tween: Tween
var _radio_sequence: int = 0

func _ready() -> void:
	audio_rng.randomize()
	for i in 12:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_one_shots.append(player)
		_one_shot_fades.append(null)
		_player_ages.append(0)
	for i in 2:
		var ambience := AudioStreamPlayer.new()
		ambience.bus = &"Ambience"
		add_child(ambience)
		_ambience_players.append(ambience)
		_ambience_tweens.append(null)
	_hearth_player = AudioStreamPlayer.new()
	_hearth_player.bus = &"Ambience"
	_hearth_stream = HEARTH_STREAM
	add_child(_hearth_player)
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = &"Music"
	_bgm_stream = BGM_STREAM
	_bgm_player.stream = _bgm_stream
	add_child(_bgm_player)
	_bgm_player.finished.connect(start_bgm)
	if is_inside_tree():
		start_bgm()
	_radio_player = AudioStreamPlayer.new()
	_radio_player.bus = &"Radio"
	add_child(_radio_player)
	if OS.is_debug_build():
		for error in validate_registry():
			push_error("Audio registry: " + error)

func play_cue(cue_name: String, volume_offset_db: float = 0.0) -> void:
	if not CUES.has(cue_name):
		push_error("Audio cue is not registered: " + cue_name)
		return
	var cue: Dictionary = CUES[cue_name]
	var streams: Array = cue["streams"]
	if streams.is_empty():
		push_error("Audio cue has no streams: " + cue_name)
		return
	var stream_index := 0
	if streams.size() > 1:
		stream_index = audio_rng.randi_range(0, streams.size() - 1)
		var last_index: int = int(_last_stream_indices.get(cue_name, -1))
		if stream_index == last_index:
			stream_index = (stream_index + 1 + audio_rng.randi_range(0, streams.size() - 2)) % streams.size()
	_last_stream_indices[cue_name] = stream_index
	var player := _next_one_shot()
	var player_index := _one_shots.find(player)
	_kill_one_shot_fade(player_index)
	var play_token := _age
	player.stop()
	player.stream = streams[stream_index]
	player.bus = StringName(cue["bus"])
	player.volume_db = float(cue.get("volume_db", 0.0)) + volume_offset_db
	player.pitch_scale = audio_rng.randf_range(float(cue.get("pitch_min", 1.0)), float(cue.get("pitch_max", 1.0)))
	player.set_meta("audio_play_token", play_token)
	player.play()
	var max_seconds := float(cue.get("max_seconds", DEFAULT_MAX_ONE_SHOT_SECONDS))
	if player.stream.get_length() > max_seconds:
		var fade_seconds := clampf(float(cue.get("fade_out_seconds", 0.0)), 0.0, max_seconds)
		var stop_delay := max_seconds - fade_seconds
		get_tree().create_timer(stop_delay).timeout.connect(func() -> void:
			if is_instance_valid(player) and int(player.get_meta("audio_play_token", -1)) == play_token:
				if fade_seconds <= 0.0:
					player.stop()
					return
				_kill_one_shot_fade(player_index)
				var fade := create_tween()
				_one_shot_fades[player_index] = fade
				fade.tween_property(player, "volume_db", -40.0, fade_seconds)
				fade.tween_callback(func() -> void:
					if is_instance_valid(player) and int(player.get_meta("audio_play_token", -1)) == play_token:
						player.stop()
				)
		)

func _kill_one_shot_fade(index: int) -> void:
	if index < 0 or index >= _one_shot_fades.size():
		return
	var fade := _one_shot_fades[index]
	if fade and fade.is_valid():
		fade.kill()
	_one_shot_fades[index] = null

func _next_one_shot() -> AudioStreamPlayer:
	_age += 1
	for i in _one_shots.size():
		if not _one_shots[i].playing:
			_player_ages[i] = _age
			return _one_shots[i]
	var oldest := 0
	for i in range(1, _player_ages.size()):
		if _player_ages[i] < _player_ages[oldest]:
			oldest = i
	_player_ages[oldest] = _age
	return _one_shots[oldest]

func set_location(location_id: String) -> void:
	if not LOCATION_AMBIENCE_ENABLED:
		_stop_location_ambience()
		_current_location = location_id
		return
	if location_id == _current_location or not LOCATION_AMBIENCE.has(location_id):
		return
	var next_index := 0 if _active_ambience != 0 else 1
	var next := _ambience_players[next_index]
	_kill_ambience_tween(next_index)
	next.stop()
	next.stream = LOCATION_AMBIENCE[location_id]
	next.bus = &"Ambience"
	next.volume_db = -40.0
	next.play()
	var fade_in := create_tween()
	_ambience_tweens[next_index] = fade_in
	fade_in.tween_property(next, "volume_db", 0.0, 0.8)
	if _active_ambience >= 0:
		var old_index := _active_ambience
		var old := _ambience_players[old_index]
		_kill_ambience_tween(old_index)
		var fade_out := create_tween()
		_ambience_tweens[old_index] = fade_out
		fade_out.tween_property(old, "volume_db", -40.0, 0.8)
		fade_out.tween_callback(old.stop)
	_current_location = location_id
	_active_ambience = next_index

func _kill_ambience_tween(index: int) -> void:
	var tween := _ambience_tweens[index]
	if tween and tween.is_valid():
		tween.kill()

func _stop_location_ambience() -> void:
	for i in _ambience_players.size():
		_kill_ambience_tween(i)
		_ambience_players[i].stop()
	_active_ambience = -1

func set_hearth_active(active: bool) -> void:
	if active == _hearth_active:
		return
	_hearth_active = active
	if _hearth_tween and _hearth_tween.is_valid():
		_hearth_tween.kill()
	_hearth_tween = create_tween()
	if active:
		_hearth_player.stop()
		_hearth_player.stream = _hearth_stream
		_hearth_player.bus = &"Ambience"
		_hearth_player.volume_db = -40.0
		_hearth_player.play()
		_hearth_tween.tween_property(_hearth_player, "volume_db", -4.0, 0.4)
	else:
		_hearth_tween.tween_property(_hearth_player, "volume_db", -40.0, 0.4)
		_hearth_tween.tween_callback(_hearth_player.stop)

func play_radio_listen(_is_powered: bool, _found_signal: bool) -> void:
	_radio_sequence += 1
	_radio_player.stop()
	_play_radio_cue(RADIO_LISTEN_CUE)

func play_alarm_ring() -> void:
	play_cue("alarm_clock_ring")

func _play_radio_cue(cue_name: String) -> void:
	var cue: Dictionary = CUES[cue_name]
	var streams: Array = cue["streams"]
	_radio_player.stop()
	_radio_player.stream = streams[0]
	_radio_player.bus = &"Radio"
	_radio_player.volume_db = float(cue.get("volume_db", 0.0))
	_radio_player.pitch_scale = 1.0
	_radio_player.play()

func start_bgm() -> void:
	if _bgm_tween and _bgm_tween.is_valid():
		_bgm_tween.kill()
	if not _bgm_player.playing:
		_bgm_player.volume_db = -40.0
		_bgm_player.play()
	_bgm_tween = create_tween()
	_bgm_tween.tween_property(_bgm_player, "volume_db", 0.0, 1.5)

func stop_all(fade_seconds: float = 0.0) -> void:
	_radio_sequence += 1
	for i in _one_shots.size():
		_kill_one_shot_fade(i)
		var player := _one_shots[i]
		player.set_meta("audio_play_token", -1)
		player.stop()
	if fade_seconds <= 0.0:
		for ambience in _ambience_players:
			ambience.stop()
		_hearth_player.stop()
		_bgm_player.stop()
		_radio_player.stop()
		_active_ambience = -1
		_current_location = ""
		_hearth_active = false
		return
	for i in _ambience_players.size():
		var ambience := _ambience_players[i]
		_kill_ambience_tween(i)
		var ambience_fade := create_tween()
		_ambience_tweens[i] = ambience_fade
		ambience_fade.tween_property(ambience, "volume_db", -40.0, fade_seconds)
		ambience_fade.tween_callback(ambience.stop)
	if _hearth_tween and _hearth_tween.is_valid():
		_hearth_tween.kill()
	_hearth_tween = create_tween()
	_hearth_tween.tween_property(_hearth_player, "volume_db", -40.0, fade_seconds)
	_hearth_tween.tween_callback(_hearth_player.stop)
	if _bgm_tween and _bgm_tween.is_valid():
		_bgm_tween.kill()
	_bgm_tween = create_tween()
	_bgm_tween.tween_property(_bgm_player, "volume_db", -40.0, fade_seconds)
	_bgm_tween.tween_callback(_bgm_player.stop)
	_radio_player.stop()
	_active_ambience = -1
	_current_location = ""
	_hearth_active = false

func validate_registry() -> PackedStringArray:
	var errors := PackedStringArray()
	for cue_name in CUES:
		var cue: Dictionary = CUES[cue_name]
		if not cue.has("streams") or (cue["streams"] as Array).is_empty():
			errors.append("%s has no streams" % cue_name)
			continue
		for stream in cue["streams"]:
			if stream == null:
				errors.append("%s contains a null stream" % cue_name)
		var bus_name := StringName(cue.get("bus", ""))
		if AudioServer.get_bus_index(bus_name) < 0:
			errors.append("%s uses missing bus %s" % [cue_name, bus_name])
	for location_id in ["the_grounds", "the_woods", "lordly_manor", "cellar"]:
		if not LOCATION_AMBIENCE.has(location_id) or LOCATION_AMBIENCE[location_id] == null:
			errors.append("missing ambience for %s" % location_id)
	return errors
