extends SceneTree

var passes : int = 0
var failures : int = 0

func check(condition: bool, message: String) -> void:
	if condition:
		passes += 1
		print("  [PASS] ", message)
	else:
		failures += 1
		print("  [FAIL] ", message)

func _initialize() -> void:
	print("--- Running RCS Thruster & Dash Animation Test Suite ---")
	call_deferred("_run_tests")

func _run_tests() -> void:
	await process_frame
	await process_frame

	# ----------------------------------------------------
	# [Test 1] Load DashParticles & Verify Nozzle Layout
	# ----------------------------------------------------
	print("\n[Test 1] Testing DashParticles Scene & Nozzle Separation...")
	var dp_scene : PackedScene = load("res://scenes/player/dash_particles.tscn")
	check(dp_scene != null, "dash_particles.tscn loaded successfully")
	var dp : DashParticles = dp_scene.instantiate() as DashParticles
	root.add_child(dp)
	await process_frame

	check(dp.rear_left_particles != null, "Rear Left nozzle (CPUParticles3D) found")
	check(dp.rear_right_particles != null, "Rear Right nozzle (CPUParticles3D_Right) found")
	check(dp.rear_left_particles != dp.rear_right_particles, "Rear nozzles are distinct independent nodes")
	check(dp.side_left_particles != null, "Side Left nozzle found")
	check(dp.side_right_particles != null, "Side Right nozzle found")
	check(dp.front_left_particles != null, "Front Left nozzle found")
	check(dp.front_right_particles != null, "Front Right nozzle found")

	# Verify nozzles are stopped initially
	dp.stop_dash()
	check(dp.rear_left_particles.emitting == false, "Rear left nozzle starts stopped")
	check(dp.rear_right_particles.emitting == false, "Rear right nozzle starts stopped")
	check(dp.side_left_particles.emitting == false, "Side left nozzle starts stopped")
	check(dp.side_right_particles.emitting == false, "Side right nozzle starts stopped")
	check(dp.front_left_particles.emitting == false, "Front left nozzle starts stopped")
	check(dp.front_right_particles.emitting == false, "Front right nozzle starts stopped")

	# ----------------------------------------------------
	# [Test 2] Forward Dash Thrusters (Both rear nozzles fire)
	# ----------------------------------------------------
	print("\n[Test 2] Testing Pure Forward Dash Thrusters...")
	dp.start_dash_directional(Vector3(0, 0, 1), Vector3(0, 0, 1), 1.0, 0.0, 0.22)
	check(dp.rear_left_particles.emitting == true, "Forward dash fires Rear Left nozzle")
	check(dp.rear_right_particles.emitting == true, "Forward dash fires Rear Right nozzle")
	check(dp.side_left_particles.emitting == false, "Forward dash keeps Side Left nozzle OFF")
	check(dp.side_right_particles.emitting == false, "Forward dash keeps Side Right nozzle OFF")
	check(dp.front_left_particles.emitting == false, "Forward dash keeps Front nozzles OFF")

	# ----------------------------------------------------
	# [Test 3] Diagonal Forward-Right Dash (Independent Rear Nozzles)
	# ----------------------------------------------------
	print("\n[Test 3] Testing Diagonal Forward-Right Dash Thrusters...")
	# rel_fwd > 0.35 and rel_right > 0.35:
	# Side Left nozzle fires at 90° out left side (propelling rightward)
	# Rear Left nozzle fires backward (propelling forward)
	# Rear Right nozzle is OFF (independent rear nozzle control)
	dp.start_dash_directional(Vector3(0.7, 0, 0.7), Vector3(0, 0, 1), 0.707, 0.707, 0.22)
	check(dp.side_left_particles.emitting == true, "Diag Forward-Right fires 90° Side Left nozzle")
	check(dp.rear_left_particles.emitting == true, "Diag Forward-Right fires Rear Left nozzle")
	check(dp.rear_right_particles.emitting == false, "Diag Forward-Right turns Rear Right nozzle OFF (independent)")
	check(dp.side_right_particles.emitting == false, "Diag Forward-Right keeps Side Right nozzle OFF")
	check(dp.front_left_particles.emitting == false and dp.front_right_particles.emitting == false, "Front nozzles remain OFF")

	# ----------------------------------------------------
	# [Test 4] Diagonal Forward-Left Dash (Independent Rear Nozzles)
	# ----------------------------------------------------
	print("\n[Test 4] Testing Diagonal Forward-Left Dash Thrusters...")
	# rel_fwd > 0.35 and rel_right < -0.35:
	# Side Right nozzle fires at 90° out right side (propelling leftward)
	# Rear Right nozzle fires backward (propelling forward)
	# Rear Left nozzle is OFF (independent rear nozzle control)
	dp.start_dash_directional(Vector3(-0.7, 0, 0.7), Vector3(0, 0, 1), 0.707, -0.707, 0.22)
	check(dp.side_right_particles.emitting == true, "Diag Forward-Left fires 90° Side Right nozzle")
	check(dp.rear_right_particles.emitting == true, "Diag Forward-Left fires Rear Right nozzle")
	check(dp.rear_left_particles.emitting == false, "Diag Forward-Left turns Rear Left nozzle OFF (independent)")
	check(dp.side_left_particles.emitting == false, "Diag Forward-Left keeps Side Left nozzle OFF")
	check(dp.front_left_particles.emitting == false and dp.front_right_particles.emitting == false, "Front nozzles remain OFF")

	# ----------------------------------------------------
	# [Test 5] Pure Backward Dash (Both front nozzles fire)
	# ----------------------------------------------------
	print("\n[Test 5] Testing Pure Backward Dash Thrusters...")
	dp.start_dash_directional(Vector3(0, 0, -1), Vector3(0, 0, 1), -1.0, 0.0, 0.22)
	check(dp.front_left_particles.emitting == true, "Backward dash fires Front Left nozzle")
	check(dp.front_right_particles.emitting == true, "Backward dash fires Front Right nozzle")
	check(dp.rear_left_particles.emitting == false, "Backward dash keeps Rear Left nozzle OFF")
	check(dp.rear_right_particles.emitting == false, "Backward dash keeps Rear Right nozzle OFF")
	check(dp.side_left_particles.emitting == false and dp.side_right_particles.emitting == false, "Side nozzles remain OFF")

	# ----------------------------------------------------
	# [Test 6] Diagonal Backward-Right & Backward-Left
	# ----------------------------------------------------
	print("\n[Test 6] Testing Diagonal Backward-Right & Backward-Left Thrusters...")
	dp.start_dash_directional(Vector3(0.7, 0, -0.7), Vector3(0, 0, 1), -0.707, 0.707, 0.22)
	check(dp.side_left_particles.emitting == true, "Diag Backward-Right fires Side Left nozzle")
	check(dp.front_right_particles.emitting == true, "Diag Backward-Right fires Front Right nozzle")
	check(dp.rear_left_particles.emitting == false and dp.rear_right_particles.emitting == false, "Rear nozzles remain OFF")

	dp.start_dash_directional(Vector3(-0.7, 0, -0.7), Vector3(0, 0, 1), -0.707, -0.707, 0.22)
	check(dp.side_right_particles.emitting == true, "Diag Backward-Left fires Side Right nozzle")
	check(dp.front_left_particles.emitting == true, "Diag Backward-Left fires Front Left nozzle")

	# ----------------------------------------------------
	# [Test 7] Pure Lateral Dashes
	# ----------------------------------------------------
	print("\n[Test 7] Testing Pure Lateral Dashes...")
	dp.start_dash_directional(Vector3(1, 0, 0), Vector3(0, 0, 1), 0.0, 1.0, 0.22)
	check(dp.side_left_particles.emitting == true, "Pure Right dash fires Side Left nozzle (propels right)")
	check(dp.rear_left_particles.emitting == false and dp.rear_right_particles.emitting == false, "Rear nozzles OFF")
	check(dp.front_left_particles.emitting == false and dp.front_right_particles.emitting == false, "Front nozzles OFF")

	dp.start_dash_directional(Vector3(-1, 0, 0), Vector3(0, 0, 1), 0.0, -1.0, 0.22)
	check(dp.side_right_particles.emitting == true, "Pure Left dash fires Side Right nozzle (propels left)")
	check(dp.rear_left_particles.emitting == false and dp.rear_right_particles.emitting == false, "Rear nozzles OFF")

	dp.stop_dash()
	check(dp.rear_left_particles.emitting == false and dp.side_left_particles.emitting == false, "stop_dash shuts off all thrusters")

	# ----------------------------------------------------
	# [Test 8] Player Facing & Directional Animation
	# ----------------------------------------------------
	print("\n[Test 8] Testing Player Facing & Directional Animation...")
	var proto_scene : PackedScene = load("res://addons/proto_controller/proto_controller.tscn")
	check(proto_scene != null, "proto_controller.tscn loaded successfully")
	var player : CharacterBody3D = proto_scene.instantiate() as CharacterBody3D
	root.add_child(player)
	player.add_to_group("player")
	await process_frame
	await process_frame

	var anim : Node = player.get_node_or_null("PlayerAnimation")
	if anim == null:
		var anim_script : Script = load("res://scenes/player/player_animation.gd")
		anim = Node.new()
		anim.name = "PlayerAnimation"
		anim.set_script(anim_script)
		player.add_child(anim)
		await process_frame

	check(anim != null, "PlayerAnimation component attached to player")

	# Test get_facing_direction() in all 4 cardinal angles
	player.global_rotation.y = 0.0
	var fwd_south : Vector3 = anim.call("get_facing_direction")
	check(is_equal_approx(fwd_south.z, 1.0) and absf(fwd_south.x) < 0.001, "Facing vector at yaw=0 is +Z (South)")

	player.global_rotation.y = PI * 0.5 # 90 degrees
	var fwd_east : Vector3 = anim.call("get_facing_direction")
	check(is_equal_approx(fwd_east.x, 1.0) and absf(fwd_east.z) < 0.001, "Facing vector at yaw=PI/2 is +X (East)")

	player.global_rotation.y = PI # 180 degrees
	var fwd_north : Vector3 = anim.call("get_facing_direction")
	check(is_equal_approx(fwd_north.z, -1.0) and absf(fwd_north.x) < 0.001, "Facing vector at yaw=PI is -Z (North)")

	player.global_rotation.y = -PI * 0.5 # -90 degrees
	var fwd_west : Vector3 = anim.call("get_facing_direction")
	check(is_equal_approx(fwd_west.x, -1.0) and absf(fwd_west.z) < 0.001, "Facing vector at yaw=-PI/2 is -X (West)")

	# Test play_dash directional parameters
	anim.call("play_dash", Vector3(1, 0, 0), Vector3(0, 0, 1), 0.0, 1.0)
	check(anim.get("_dash_rel_forward") == 0.0, "Animation records rel_fwd = 0.0 for pure right dash")
	check(anim.get("_dash_rel_right") == 1.0, "Animation records rel_right = 1.0 for pure right dash")

	anim.call("play_dash", Vector3(0, 0, -1), Vector3(0, 0, 1), -1.0, 0.0)
	check(anim.get("_dash_rel_forward") == -1.0, "Animation records rel_fwd = -1.0 for pure back dash")
	check(anim.get("_dash_rel_right") == 0.0, "Animation records rel_right = 0.0 for pure back dash")

	print("\n=======================================================")
	print("RCS & ANIMATION RESULTS: %d Passed, %d Failed" % [passes, failures])
	print("=======================================================")

	dp.queue_free()
	player.queue_free()
	quit(0 if failures == 0 else 1)
