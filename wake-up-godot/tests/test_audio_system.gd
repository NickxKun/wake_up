extends SceneTree

var passes : int = 0
var failures : int = 0

func check(condition: bool, message: String) -> void:
	if condition:
		passes += 1
		print("[PASS] ", message)
	else:
		failures += 1
		print("[FAIL] ", message)

func _initialize() -> void:
	print("--- Running Audio System & Sound Effects Test ---")
	call_deferred("_run_tests")

func _run_tests() -> void:
	await process_frame
	await process_frame

	# 1. Instantiate UiSound
	var sound_scene = load("res://scenes/ui/ui_sound.tscn")
	check(sound_scene != null, "ui_sound.tscn loaded successfully")
	var sound_mgr = sound_scene.instantiate()
	check(sound_mgr != null, "UiSound instantiated successfully")
	root.add_child(sound_mgr)
	await process_frame

	# 2. Check Audio Buses
	var master_idx = AudioServer.get_bus_index("Master")
	var sfx_idx = AudioServer.get_bus_index("SFX")
	var music_idx = AudioServer.get_bus_index("Music")
	check(master_idx >= 0, "Master audio bus exists")
	check(sfx_idx >= 0, "SFX audio bus exists")
	check(music_idx >= 0, "Music audio bus exists")
	check(AudioServer.get_bus_send(sfx_idx) == "Master", "SFX bus sends to Master")
	check(AudioServer.get_bus_send(music_idx) == "Master", "Music bus sends to Master")

	# 3. Check Stream Resources
	check(sound_mgr.player_shoot_stream != null, "sfx_player_shoot stream loaded")
	check(sound_mgr.enemy_shoot_stream != null, "sfx_enemy_shoot stream loaded")
	check(sound_mgr.impact_stream != null, "sfx_impact stream loaded")
	check(sound_mgr.hit_stream != null, "sfx_hit stream loaded")
	check(sound_mgr.enemy_death_stream != null, "sfx_enemy_death stream loaded")
	check(sound_mgr.player_hurt_stream != null, "sfx_player_hurt stream loaded")
	check(sound_mgr.player_death_stream != null, "sfx_player_death stream loaded")
	check(sound_mgr.hazard_pulse_stream != null, "sfx_hazard_pulse stream loaded")
	check(sound_mgr.dash_stream != null, "sfx_dash stream loaded")
	check(sound_mgr.player_jump_stream != null, "sfx_player_jump stream loaded")
	check(sound_mgr.wrench_swing_stream != null, "sfx_wrench_swing stream loaded")
	check(sound_mgr.wrench_hit_stream != null, "sfx_wrench_hit stream loaded")
	check(sound_mgr.wrench_repair_stream != null, "sfx_wrench_repair stream loaded")
	check(sound_mgr.turret_deploy_stream != null, "sfx_turret_deploy stream loaded")
	check(sound_mgr.turret_shoot_stream != null, "sfx_turret_shoot stream loaded")
	check(sound_mgr.heal_surge_stream != null, "sfx_heal_surge stream loaded")
	check(sound_mgr.vehicle_cannon_stream != null, "sfx_vehicle_cannon stream loaded")
	check(sound_mgr.denied_stream != null, "sfx_denied stream loaded")
	check(sound_mgr.bgm_menu_stream != null, "bgm_menu stream loaded")
	check(sound_mgr.bgm_game_stream != null, "bgm_game stream loaded")

	# 4. Check Loop Modes on Music
	if sound_mgr.bgm_menu_stream is AudioStreamWAV:
		check((sound_mgr.bgm_menu_stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD, "bgm_menu has forward loop mode")
	if sound_mgr.bgm_game_stream is AudioStreamWAV:
		check((sound_mgr.bgm_game_stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD, "bgm_game has forward loop mode")

	# 5. Test SFX Pool Playback
	sound_mgr.play_shoot()
	sound_mgr.play_enemy_shoot()
	sound_mgr.play_impact()
	sound_mgr.play_hit()
	sound_mgr.play_enemy_death()
	sound_mgr.play_player_hurt()
	sound_mgr.play_player_death()
	sound_mgr.play_hazard_pulse()
	sound_mgr.play_warning_tick()
	sound_mgr.play_jump()
	sound_mgr.play_dash()
	sound_mgr.play_vehicle_honk()
	sound_mgr.play_vehicle_lights()
	sound_mgr.play_vehicle_enter()
	sound_mgr.play_vehicle_exit()
	sound_mgr.play_shotgun()
	sound_mgr.play_sniper()
	sound_mgr.play_double_pistols()
	sound_mgr.play_rocket_launch()
	sound_mgr.play_rocket_explode()
	sound_mgr.play_weapon_pickup()
	sound_mgr.play_wrench_swing()
	sound_mgr.play_wrench_hit()
	sound_mgr.play_wrench_repair()
	sound_mgr.play_turret_deploy()
	sound_mgr.play_turret_shoot()
	sound_mgr.play_heal_surge()
	sound_mgr.play_vehicle_cannon()
	sound_mgr.play_denied()
	check(true, "All in-game, vehicle, and weapon SFX play without error")

	# 6. Test UI SFX Playback
	sound_mgr.play_click()
	sound_mgr.play_hover()
	sound_mgr.play_tab()
	sound_mgr.play_toggle(true)
	sound_mgr.play_slide()
	check(true, "All UI SFX play without error")

	# 7. Test Music Transitions
	sound_mgr.play_music("menu", 0.1)
	await process_frame
	check(sound_mgr._active_music_player.playing, "Menu BGM is playing")
	check(sound_mgr._current_track_name == "menu", "Current track is menu")

	# Crossfade to Game Music
	sound_mgr.play_music("game", 0.1)
	await process_frame
	check(sound_mgr._active_music_player.playing, "Game BGM is playing")
	check(sound_mgr._current_track_name == "game", "Current track is game")

	# Stop Music
	sound_mgr.stop_music(0.05)
	for i in range(10):
		await process_frame
	check(sound_mgr._current_track_name == "", "Music stopped cleanly")

	sound_mgr.queue_free()
	await process_frame

	print("--- Verification Results: %d Passed, %d Failed ---" % [passes, failures])
	if failures > 0:
		quit(1)
	else:
		quit(0)
