extends Node

## Universal audio and music manager for crisp tactical SFX and atmospheric background music.

# UI Audio Streams
var click_stream : AudioStream = preload("res://assets/audio/ui_click.wav")
var hover_stream : AudioStream = preload("res://assets/audio/ui_hover.wav")
var tab_stream : AudioStream = preload("res://assets/audio/ui_tab.wav")
var toggle_stream : AudioStream = preload("res://assets/audio/ui_toggle.wav")
var slide_stream : AudioStream = preload("res://assets/audio/ui_slide.wav")
var map_open_stream : AudioStream = preload("res://assets/audio/sfx_map_open.wav")
var map_close_stream : AudioStream = preload("res://assets/audio/sfx_map_close.wav")

# In-Game SFX Streams
var player_shoot_stream : AudioStream = preload("res://assets/audio/sfx_player_shoot.wav")
var enemy_shoot_stream : AudioStream = preload("res://assets/audio/sfx_enemy_shoot.wav")
var impact_stream : AudioStream = preload("res://assets/audio/sfx_impact.wav")
var hit_stream : AudioStream = preload("res://assets/audio/sfx_hit.wav")
var enemy_death_stream : AudioStream = preload("res://assets/audio/sfx_enemy_death.wav")
var player_hurt_stream : AudioStream = preload("res://assets/audio/sfx_player_hurt.wav")
var player_jump_stream : AudioStream = preload("res://assets/audio/sfx_player_jump.wav")
var crit_stream : AudioStream = preload("res://assets/audio/sfx_crit.wav")
var warning_tick_stream : AudioStream = preload("res://assets/audio/sfx_warning_tick.wav")
var player_death_stream : AudioStream = preload("res://assets/audio/sfx_player_death.wav")
var hazard_pulse_stream : AudioStream = preload("res://assets/audio/sfx_hazard_pulse.wav")
var dash_stream : AudioStream = preload("res://assets/audio/sfx_dash.wav")
var vehicle_honk_stream : AudioStream = preload("res://assets/audio/sfx_vehicle_honk.wav")
var vehicle_lights_stream : AudioStream = preload("res://assets/audio/sfx_vehicle_lights.wav")
var vehicle_enter_stream : AudioStream = preload("res://assets/audio/sfx_vehicle_enter.wav")
var vehicle_exit_stream : AudioStream = preload("res://assets/audio/sfx_vehicle_exit.wav")
var shotgun_stream : AudioStream = preload("res://assets/audio/sfx_shotgun.wav")
var sniper_stream : AudioStream = preload("res://assets/audio/sfx_sniper.wav")
var double_pistols_stream : AudioStream = preload("res://assets/audio/sfx_double_pistols.wav")
var rocket_launch_stream : AudioStream = preload("res://assets/audio/sfx_rocket_launch.wav")
var rocket_explode_stream : AudioStream = preload("res://assets/audio/sfx_rocket_explode.wav")
var weapon_pickup_stream : AudioStream = preload("res://assets/audio/sfx_weapon_pickup.wav")
var waypoint_activate_stream : AudioStream = preload("res://assets/audio/sfx_waypoint_activate.wav")
var waypoint_reached_stream : AudioStream = preload("res://assets/audio/sfx_waypoint_reached.wav")
var wrench_swing_stream : AudioStream = load("res://assets/audio/sfx_wrench_swing.wav")
var wrench_hit_stream : AudioStream = load("res://assets/audio/sfx_wrench_hit.wav")
var wrench_repair_stream : AudioStream = load("res://assets/audio/sfx_wrench_repair.wav")
var turret_deploy_stream : AudioStream = load("res://assets/audio/sfx_turret_deploy.wav")
var turret_shoot_stream : AudioStream = load("res://assets/audio/sfx_turret_shoot.wav")
var heal_surge_stream : AudioStream = load("res://assets/audio/sfx_heal_surge.wav")
var vehicle_cannon_stream : AudioStream = load("res://assets/audio/sfx_vehicle_cannon.wav")
var denied_stream : AudioStream = load("res://assets/audio/sfx_denied.wav")

# Background Music Streams
var bgm_menu_stream : AudioStream = preload("res://assets/audio/bgm_menu.wav")
var bgm_game_stream : AudioStream = preload("res://assets/audio/bgm_game.wav")

# UI Dedicated Players
var _click_player : AudioStreamPlayer
var _hover_player : AudioStreamPlayer
var _tab_player : AudioStreamPlayer
var _toggle_player : AudioStreamPlayer
var _slide_player : AudioStreamPlayer

# Dynamic SFX Pool for Polyphonic Gameplay Sound
const SFX_POOL_SIZE : int = 16
var _sfx_pool : Array[AudioStreamPlayer] = []
var _sfx_pool_index : int = 0
var _thruster_player : AudioStreamPlayer = null
var _is_thruster_active : bool = false

# Music Crossfade Players
var _music_player_a : AudioStreamPlayer
var _music_player_b : AudioStreamPlayer
var _active_music_player : AudioStreamPlayer
var _current_track_name : String = ""
var _music_fade_tween : Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_audio_buses()
	_setup_loop_modes()
	_create_ui_players()
	_create_sfx_pool()
	_create_music_players()

func _ensure_audio_buses() -> void:
	var sfx_idx : int = AudioServer.get_bus_index("SFX")
	if sfx_idx == -1:
		sfx_idx = AudioServer.bus_count
		AudioServer.add_bus(sfx_idx)
		AudioServer.set_bus_name(sfx_idx, "SFX")
		AudioServer.set_bus_send(sfx_idx, "Master")

	var music_idx : int = AudioServer.get_bus_index("Music")
	if music_idx == -1:
		music_idx = AudioServer.bus_count
		AudioServer.add_bus(music_idx)
		AudioServer.set_bus_name(music_idx, "Music")
		AudioServer.set_bus_send(music_idx, "Master")

func _setup_loop_modes() -> void:
	for stream in [bgm_menu_stream, bgm_game_stream]:
		if stream is AudioStreamWAV:
			var wav : AudioStreamWAV = stream as AudioStreamWAV
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			var sample_len : int = int(wav.get_length() * float(wav.mix_rate))
			if sample_len > 0:
				wav.loop_end = sample_len

func _create_ui_players() -> void:
	_click_player = _build_player("ClickPlayer", click_stream, -2.0, "SFX", Node.PROCESS_MODE_ALWAYS)
	_hover_player = _build_player("HoverPlayer", hover_stream, -6.0, "SFX", Node.PROCESS_MODE_ALWAYS)
	_tab_player = _build_player("TabPlayer", tab_stream, -3.0, "SFX", Node.PROCESS_MODE_ALWAYS)
	_toggle_player = _build_player("TogglePlayer", toggle_stream, -3.0, "SFX", Node.PROCESS_MODE_ALWAYS)
	_slide_player = _build_player("SlidePlayer", slide_stream, -4.0, "SFX", Node.PROCESS_MODE_ALWAYS)

func _create_sfx_pool() -> void:
	for i in range(SFX_POOL_SIZE):
		var p : AudioStreamPlayer = AudioStreamPlayer.new()
		p.name = "SFXPool_%d" % i
		p.bus = "SFX"
		p.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(p)
		_sfx_pool.append(p)

	_thruster_player = AudioStreamPlayer.new()
	_thruster_player.name = "ThrusterPlayer"
	_thruster_player.bus = "SFX"
	_thruster_player.stream = dash_stream
	_thruster_player.volume_db = -10.0
	_thruster_player.finished.connect(func() -> void:
		if _is_thruster_active and _thruster_player != null:
			_thruster_player.pitch_scale = randf_range(0.85, 0.95)
			_thruster_player.play()
	)
	add_child(_thruster_player)

func _create_music_players() -> void:
	_music_player_a = _build_player("MusicPlayerA", null, -80.0, "Music", Node.PROCESS_MODE_ALWAYS)
	_music_player_b = _build_player("MusicPlayerB", null, -80.0, "Music", Node.PROCESS_MODE_ALWAYS)
	_active_music_player = _music_player_a

	_music_player_a.finished.connect(func() -> void:
		if _active_music_player == _music_player_a and not _current_track_name.is_empty():
			_music_player_a.play()
	)
	_music_player_b.finished.connect(func() -> void:
		if _active_music_player == _music_player_b and not _current_track_name.is_empty():
			_music_player_b.play()
	)

func _build_player(p_name: String, stream_res: AudioStream, volume_db: float, bus_name: String, p_mode: int) -> AudioStreamPlayer:
	var player : AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = p_name
	player.stream = stream_res
	player.volume_db = volume_db
	player.bus = bus_name
	player.process_mode = p_mode
	add_child(player)
	return player

# -----------------------------------------------------------------------------
# Background Music System with Smooth Crossfading
# -----------------------------------------------------------------------------

## Fades smoothly to the requested music track ("menu", "game", or "" to stop).
func play_music(track_name: String, fade_duration: float = 0.8) -> void:
	if _current_track_name == track_name and _active_music_player != null and _active_music_player.playing:
		return

	_current_track_name = track_name

	if _music_fade_tween != null and _music_fade_tween.is_valid():
		_music_fade_tween.kill()

	var incoming_stream : AudioStream = null
	var target_volume_db : float = -6.0

	match track_name:
		"menu":
			incoming_stream = bgm_menu_stream
			target_volume_db = -6.0
		"game":
			incoming_stream = bgm_game_stream
			target_volume_db = -7.0
		_:
			# Stop music
			if _active_music_player != null and _active_music_player.playing:
				var tween : Tween = create_tween()
				tween.tween_property(_active_music_player, "volume_db", -80.0, fade_duration)
				tween.tween_callback(_active_music_player.stop)
				_music_fade_tween = tween
			return

	if incoming_stream == null:
		return

	# Swap to alternate player for crossfade
	var outgoing_player : AudioStreamPlayer = _active_music_player
	var incoming_player : AudioStreamPlayer = _music_player_b if outgoing_player == _music_player_a else _music_player_a
	_active_music_player = incoming_player

	incoming_player.stream = incoming_stream
	incoming_player.volume_db = -80.0
	incoming_player.play()

	var tween : Tween = create_tween().set_parallel(true)
	if outgoing_player != null and outgoing_player.playing:
		tween.tween_property(outgoing_player, "volume_db", -80.0, fade_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(incoming_player, "volume_db", target_volume_db, fade_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Stop outgoing player after fade completes
	if outgoing_player != null:
		var stop_callable : Callable = func():
			if outgoing_player != _active_music_player:
				outgoing_player.stop()
		tween.chain().tween_callback(stop_callable)

	_music_fade_tween = tween

func stop_music(fade_duration: float = 0.5) -> void:
	play_music("", fade_duration)

# -----------------------------------------------------------------------------
# Polyphonic In-Game SFX
# -----------------------------------------------------------------------------

func _play_pooled_sfx(stream_res: AudioStream, base_volume_db: float, pitch: float, is_pausable: bool = true) -> void:
	if stream_res == null or _sfx_pool.is_empty():
		return
	var player : AudioStreamPlayer = _sfx_pool[_sfx_pool_index]
	_sfx_pool_index = (_sfx_pool_index + 1) % SFX_POOL_SIZE

	player.stream = stream_res
	player.volume_db = base_volume_db
	player.pitch_scale = pitch
	player.process_mode = Node.PROCESS_MODE_PAUSABLE if is_pausable else Node.PROCESS_MODE_ALWAYS
	player.play()

## High-energy player kinetic/energy rifle shot.
func play_shoot(pitch_jitter: float = 0.04) -> void:
	_play_pooled_sfx(player_shoot_stream, -2.5, randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter))

## Aggressive plasma discharge shot fired by hostile units.
func play_enemy_shoot(pitch_jitter: float = 0.06) -> void:
	_play_pooled_sfx(enemy_shoot_stream, -4.5, randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter))

## Bullet ricochet or metal impact on level geometry.
func play_impact(pitch_jitter: float = 0.05) -> void:
	_play_pooled_sfx(impact_stream, -2.5, randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter))

## Tactile hitmarker confirmation when a bullet damages an entity.
func play_hit(pitch_jitter: float = 0.04) -> void:
	_play_pooled_sfx(hit_stream, -2.5, randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter))

## High-reward electrifying shockwave when landing a critical insta-kill.
func play_crit(pitch_jitter: float = 0.03) -> void:
	_play_pooled_sfx(crit_stream, -1.5, randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter))

## Detonation / disintegration when a hostile unit is eliminated.
func play_enemy_death(pitch_jitter: float = 0.04) -> void:
	_play_pooled_sfx(enemy_death_stream, -2.0, randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter))

## Shield breach and blunt damage taken by the player.
func play_player_hurt(pitch_jitter: float = 0.04) -> void:
	_play_pooled_sfx(player_hurt_stream, -4.5, randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter))

## Cinematic player vital signs offline / suit flatline and heavy collapse.
func play_player_death() -> void:
	_play_pooled_sfx(player_death_stream, -2.0, 1.0, false)

## High-frequency electric shield absorption / deflection chime.
func play_shield_hit(pitch_jitter: float = 0.04) -> void:
	_play_pooled_sfx(crit_stream, -3.0, randf_range(1.45 - pitch_jitter, 1.45 + pitch_jitter))

## Heavy resonant shield overload / shattered barrier burst.
func play_shield_break(pitch_jitter: float = 0.03) -> void:
	_play_pooled_sfx(impact_stream, 0.5, randf_range(0.65 - pitch_jitter, 0.65 + pitch_jitter), false)

## Harmonic ascending ping when personal shield starts actively recharging.
func play_shield_regen_start(pitch_jitter: float = 0.02) -> void:
	_play_pooled_sfx(tab_stream, -4.0, randf_range(1.25 - pitch_jitter, 1.25 + pitch_jitter))

## Subtle confirmation chime when shield is 100% fully restored.
func play_shield_recharged(pitch_jitter: float = 0.02) -> void:
	_play_pooled_sfx(weapon_pickup_stream, -6.0, randf_range(1.5 - pitch_jitter, 1.5 + pitch_jitter))

## Deep muffled biometric heartbeat & suit pressure drop when exposed to out-of-bounds hazard.
func play_hazard_pulse(pitch_jitter: float = 0.03) -> void:
	_play_pooled_sfx(hazard_pulse_stream, -4.0, randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter), false)

## Thruster puff when the player jumps.
func play_jump(pitch_jitter: float = 0.03) -> void:
	_play_pooled_sfx(player_jump_stream, -7.0, randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter))

## High-speed pneumatic thruster dash burst.
func play_dash(pitch_jitter: float = 0.04) -> void:
	_play_pooled_sfx(dash_stream, -4.0, randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter))

## Continuous pressurized air flight thruster hiss.
func start_thruster() -> void:
	if _is_thruster_active:
		return
	_is_thruster_active = true
	if _thruster_player != null and not _thruster_player.playing:
		_thruster_player.pitch_scale = 0.9
		_thruster_player.play()

## Stops pressurized air flight thruster hiss.
func stop_thruster() -> void:
	_is_thruster_active = false
	if _thruster_player != null and _thruster_player.playing:
		_thruster_player.stop()

## Dual-tone retro-future rover horn.
func play_vehicle_honk(pitch_jitter: float = 0.02) -> void:
	_play_pooled_sfx(vehicle_honk_stream, -2.0, randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter), false)

## Mechanical toggle relay click for headlights.
func play_vehicle_lights(pitch_jitter: float = 0.03) -> void:
	_play_pooled_sfx(vehicle_lights_stream, -5.0, randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter))

## Cabin hatch opening & boarding sound.
func play_vehicle_enter(pitch_jitter: float = 0.03) -> void:
	_play_pooled_sfx(vehicle_enter_stream, -4.0, randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter))

## Cabin hatch unsealing & dismounting sound.
func play_vehicle_exit(pitch_jitter: float = 0.03) -> void:
	_play_pooled_sfx(vehicle_exit_stream, -4.0, randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter))

## Punchy shotgun blast sound.
func play_shotgun(pitch_jitter: float = 0.04) -> void:
	_play_pooled_sfx(shotgun_stream, -1.0, randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter))

## High-velocity supersonic sniper rifle sound.
func play_sniper(pitch_jitter: float = 0.03) -> void:
	_play_pooled_sfx(sniper_stream, -0.5, randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter))

## Rapid dual pistol burst sound.
func play_double_pistols(pitch_jitter: float = 0.04) -> void:
	_play_pooled_sfx(double_pistols_stream, -2.5, randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter))

## Rocket launch ignition and propellant roar.
func play_rocket_launch(pitch_jitter: float = 0.04) -> void:
	_play_pooled_sfx(rocket_launch_stream, -1.5, randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter))

## Deep concussive rocket explosion sound.
func play_rocket_explode(pitch_jitter: float = 0.05) -> void:
	_play_pooled_sfx(rocket_explode_stream, 0.0, randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter))

## Weapon pickup and chamber cocking sound.
func play_weapon_pickup(pitch_jitter: float = 0.02) -> void:
	_play_pooled_sfx(weapon_pickup_stream, -3.0, randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter))

# -----------------------------------------------------------------------------
# Micro-Interaction UI Sounds (Always process even when paused)
# -----------------------------------------------------------------------------

func play_click(pitch_jitter: float = 0.05) -> void:
	if _click_player != null and _click_player.stream != null:
		_click_player.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
		_click_player.play()

func play_hover() -> void:
	if _hover_player != null and _hover_player.stream != null:
		_hover_player.pitch_scale = randf_range(0.98, 1.02)
		_hover_player.play()

func play_tab() -> void:
	if _tab_player != null and _tab_player.stream != null:
		_tab_player.pitch_scale = 1.0
		_tab_player.play()

func play_toggle(is_on: bool = true) -> void:
	if _toggle_player != null and _toggle_player.stream != null:
		_toggle_player.pitch_scale = 1.08 if is_on else 0.92
		_toggle_player.play()

func play_slide() -> void:
	if _slide_player != null and _slide_player.stream != null:
		_slide_player.pitch_scale = 1.0
		_slide_player.play()

## Sleek tactical sonar / avionics alert ping when player enters restricted hazard zone.
func play_warning_tick(pitch_jitter: float = 0.015) -> void:
	_play_pooled_sfx(warning_tick_stream, -8.0, randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter), false)

## Holographic tactical map open chirp.
func play_map_open() -> void:
	_play_pooled_sfx(map_open_stream, -3.0, 1.0, false)

## Holographic tactical map close dismiss.
func play_map_close() -> void:
	_play_pooled_sfx(map_close_stream, -3.5, 1.0, false)

## Subtle warm holographic blip when a new waypoint objective activates.
func play_waypoint_activate(pitch_jitter: float = 0.02) -> void:
	_play_pooled_sfx(waypoint_activate_stream, -10.0, randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter))

## Pristine celestial glass chime when player reaches an active waypoint.
func play_waypoint_reached(pitch_jitter: float = 0.02) -> void:
	_play_pooled_sfx(waypoint_reached_stream, -8.0, randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter))

func play_wrench_swing(pitch_jitter: float = 0.05) -> void:
	_play_pooled_sfx(wrench_swing_stream, -4.0, randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter))

func play_wrench_hit(pitch_jitter: float = 0.04) -> void:
	_play_pooled_sfx(wrench_hit_stream, -2.5, randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter))

func play_wrench_repair(pitch_jitter: float = 0.03) -> void:
	_play_pooled_sfx(wrench_repair_stream, -3.5, randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter))

func play_turret_deploy(pitch_jitter: float = 0.02) -> void:
	_play_pooled_sfx(turret_deploy_stream, -2.0, randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter))

func play_turret_shoot(pitch_jitter: float = 0.04) -> void:
	_play_pooled_sfx(turret_shoot_stream, -4.5, randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter))

func play_heal_surge(pitch_jitter: float = 0.01) -> void:
	_play_pooled_sfx(heal_surge_stream, -2.0, randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter))

func play_vehicle_cannon(pitch_jitter: float = 0.03) -> void:
	_play_pooled_sfx(vehicle_cannon_stream, -1.5, randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter))

func play_denied() -> void:
	_play_pooled_sfx(denied_stream, -4.0, 1.0)
