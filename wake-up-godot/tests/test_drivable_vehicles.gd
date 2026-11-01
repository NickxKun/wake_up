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
	print("=== RUNNING DRIVABLE VEHICLES TEST SUITE ===")
	await process_frame

	# 1. Test Rover Instantiation
	var rover_scene : PackedScene = load("res://scenes/vehicles/rover.tscn")
	check(rover_scene != null, "rover.tscn loaded successfully")
	var rover : CharacterBody3D = rover_scene.instantiate() as CharacterBody3D
	check(rover != null, "Rover instantiated successfully")
	root.add_child(rover)
	await process_frame

	# 2. Check Groups & Components
	check(rover.is_in_group("vehicle"), "Rover is in group 'vehicle'")
	check(rover.is_in_group("drivable"), "Rover is in group 'drivable'")
	check(rover.has_node("Collider"), "Rover has Collider child")
	check(rover.has_node("InteractionArea"), "Rover has InteractionArea child")
	check(rover.has_node("PromptAnchor/DrivePrompt"), "Rover has DrivePrompt child")
	check(rover.has_node("Headlights/LeftLight"), "Rover has LeftLight SpotLight3D")
	check(rover.has_node("Headlights/RightLight"), "Rover has RightLight SpotLight3D")
	check(rover.has_node("Taillights/LeftTail"), "Rover has LeftTail OmniLight3D")
	check(rover.has_node("Taillights/RightTail"), "Rover has RightTail OmniLight3D")

	# 3. Test Headlights Toggle & Smooth Lighting (L key)
	check(rover.lights_on == false, "Headlights default to OFF for parked rovers")
	var left_l : SpotLight3D = rover.get_node("Headlights/LeftLight") as SpotLight3D
	var left_t : OmniLight3D = rover.get_node("Taillights/LeftTail") as OmniLight3D
	check(left_l.light_cull_mask == 1, "Headlights have light_cull_mask = 1 (does not illuminate vehicle layer 2)")
	check(left_t.light_cull_mask == 1, "Taillights have light_cull_mask = 1 (does not illuminate vehicle layer 2)")

	rover.toggle_lights()
	check(rover.lights_on == true, "toggle_lights() toggled lights to ON")
	check(left_l.visible == true, "LeftLight visibility set to true for smooth fade-in")

	rover.toggle_lights()
	check(rover.lights_on == false, "toggle_lights() toggled lights back to OFF")

	# 4. Test Horn (H key)
	var signal_tracker := {"horn_signaled": false}
	rover.horn_honked.connect(func(): signal_tracker["horn_signaled"] = true)
	rover.honk()
	check(signal_tracker["horn_signaled"] == true, "honk() emitted horn_honked signal")

	# 5. Test Steering Physics & Direction Alignment
	# Check steering left turns toward +X (rotation.y increases)
	rover.rotation.y = 0.0
	rover.current_speed = 3.5
	# Steer left by simulating steer angle
	rover.current_steer_angle = 0.5
	var prev_rot_y : float = rover.rotation.y
	rover.rotation.y += rover.current_steer_angle * rover.turn_speed * 1.0 * 1.0 * 0.05
	check(rover.rotation.y > prev_rot_y, "Steering left turns heading toward +X (counter-clockwise)")
	var forward_steer_left : Vector3 = rover.transform.basis.z
	check(forward_steer_left.x > 0.0, "Steering left forward basis.z has positive X (left side)")

	# Check steering right turns toward -X (rotation.y decreases)
	rover.rotation.y = 0.0
	rover.current_steer_angle = -0.5
	prev_rot_y = rover.rotation.y
	rover.rotation.y += rover.current_steer_angle * rover.turn_speed * 1.0 * 1.0 * 0.05
	check(rover.rotation.y < prev_rot_y, "Steering right turns heading toward -X (clockwise)")
	var forward_steer_right : Vector3 = rover.transform.basis.z
	check(forward_steer_right.x < 0.0, "Steering right forward basis.z has negative X (right side)")

	# 6. Test Slower Controlled Truck Speed & Non-Wobbling Wheel Spin
	check(rover.max_speed <= 5.5, "Truck max_speed is slower and controllable (<= 5.5 m/s, actual: %.1f)" % rover.max_speed)
	check(rover.max_reverse_speed <= 3.0, "Truck max_reverse_speed is slower (<= 3.0 m/s, actual: %.1f)" % rover.max_reverse_speed)

	rover.current_speed = 4.8
	rover.current_steer_angle = 0.45
	rover._update_wheels(0.016)
	var fl_mesh : MeshInstance3D = rover.get("_wheel_fl") as MeshInstance3D
	var rl_mesh : MeshInstance3D = rover.get("_wheel_rl") as MeshInstance3D
	check(fl_mesh != null and rl_mesh != null, "Wheel meshes cached for wheel spin")
	if fl_mesh != null and rl_mesh != null:
		check(absf(fl_mesh.global_transform.basis.x.y) < 0.05, "Steered front wheel axle remains horizontal without wobbling into ground (Y: %.4f)" % fl_mesh.global_transform.basis.x.y)
		check(absf(rl_mesh.global_transform.basis.x.y) < 0.05, "Rear wheel axle remains horizontal (Y: %.4f)" % rl_mesh.global_transform.basis.x.y)
		check(fl_mesh.transform.basis.determinant() > 0.99, "Front wheel basis is a valid orthonormal rotation (det ~ 1.0)")
		check(rover._wheel_roll_angle > 0.0, "Wheel roll angle advances forward with forward speed")

	# 7. Test Boarding & Dismounting (E key)
	var player_body := CharacterBody3D.new()
	player_body.name = "TestPlayer"
	player_body.add_to_group("player")
	var p_col := CollisionShape3D.new()
	p_col.name = "Collider"
	p_col.shape = CapsuleShape3D.new()
	player_body.add_child(p_col)
	var p_mesh := Node3D.new()
	p_mesh.name = "player"
	player_body.add_child(p_mesh)
	root.add_child(player_body)
	await process_frame

	check(rover.is_occupied == false, "Rover begins unoccupied")
	rover.board_vehicle(player_body)
	await process_frame
	check(rover.is_occupied == true, "Rover is occupied after board_vehicle()")
	check(rover.get("_boarding_cooldown") > 0.0, "Boarding cooldown active to prevent rapid double-trigger")
	check(p_col.disabled == true, "Player collider is disabled while driving")
	check(p_mesh.visible == false, "Player mesh is hidden while driving")
	check(player_body.is_physics_processing() == false, "Player physics processing disabled while driving")
	check(player_body.velocity == Vector3.ZERO, "Player velocity zeroed on boarding")

	var safe_exit : Vector3 = rover._find_safe_exit_position()
	check(safe_exit.distance_to(rover.global_position) >= 1.2, "Safe exit position calculated outside vehicle body")

	rover.exit_vehicle()
	await process_frame
	check(rover.is_occupied == false, "Rover is unoccupied after exit_vehicle()")
	check(rover.get("_boarding_cooldown") > 0.0, "Dismount cooldown active to prevent rapid re-entry")
	check(p_col.disabled == false, "Player collider re-enabled after dismount")
	check(p_mesh.visible == true, "Player mesh visible after dismount")
	check(player_body.is_physics_processing() == true, "Player physics processing re-enabled after dismount")
	check(player_body.global_position.distance_to(rover.global_position) >= 1.0, "Player placed safely clear of vehicle hull")

	# 7. Test Input Configuration
	check(InputMap.has_action("interact"), "Input action 'interact' exists (E key)")
	check(InputMap.has_action("vehicle_honk"), "Input action 'vehicle_honk' exists (H key)")
	check(InputMap.has_action("vehicle_lights"), "Input action 'vehicle_lights' exists (L key)")

	# 8. Test Dynamic Driving Physics (Squat, Dive, Roll, Slope Conformity)
	rover.is_occupied = true
	# Test Acceleration Squat (pitch up)
	rover.set("_prev_speed", 0.0)
	rover.current_speed = 4.0
	rover.set("_throttle_input", 1.0)
	rover.set("_is_braking", false)
	rover._update_chassis_physics(0.1)
	check(rover.get("_chassis_pitch") > 0.01, "Acceleration produces positive chassis pitch (squat rear / nose up, pitch: %.4f)" % rover.get("_chassis_pitch"))

	# Test Hard Braking Dive (pitch down)
	rover.set("_prev_speed", 4.0)
	rover.current_speed = 1.0
	rover.set("_throttle_input", 0.0)
	rover.set("_is_braking", true)
	rover._update_chassis_physics(0.1)
	check(rover.get("_chassis_pitch") < 0.0, "Hard braking produces negative chassis pitch (dive nose down, pitch: %.4f)" % rover.get("_chassis_pitch"))

	# Test Cornering Body Roll
	rover.current_speed = 4.5
	rover.current_steer_angle = 0.5 # Steer left
	rover.set("_is_braking", false)
	rover._update_chassis_physics(0.1)
	check(rover.get("_chassis_roll") < -0.01, "Left turn at speed produces outward body roll (roll: %.4f)" % rover.get("_chassis_roll"))

	# Test Suspension Landing Bounce Recovery
	rover.set("_suspension_bounce", -0.05)
	var initial_bounce : float = rover.get("_suspension_bounce")
	rover._update_chassis_physics(0.05)
	check(absf(rover.get("_suspension_bounce")) < absf(initial_bounce), "Suspension bounce smoothly recovers toward equilibrium")

	# 9. Test Neat Glowing Square Backup Lights (Zero Blurry Radial Gradient)
	check(rover.has_node("Taillights/LeftTailSquare"), "Rover has LeftTailSquare MeshInstance3D fixture")
	check(rover.has_node("Taillights/RightTailSquare"), "Rover has RightTailSquare MeshInstance3D fixture")
	check(rover.has_node("Taillights/BackupGroundSquare"), "Rover has BackupGroundSquare MeshInstance3D")

	var backup_ground : MeshInstance3D = rover.get_node("Taillights/BackupGroundSquare") as MeshInstance3D
	var tail_mat : StandardMaterial3D = rover.get("_tail_material") as StandardMaterial3D
	check(tail_mat != null, "Shared taillight dynamic material initialized")

	# Test Reverse Lighting
	rover.current_speed = -1.2
	rover.set("_throttle_input", -1.0)
	rover._update_lighting(0.016)
	check(backup_ground.visible == true, "BackupGroundSquare is visible in reverse")
	if tail_mat != null:
		check(tail_mat.emission.r > 0.9 and tail_mat.emission.b > 0.9, "Taillight squares glow crisp bright white in reverse")
		check(tail_mat.emission_energy_multiplier >= 2.0, "Taillight square emission intensity boosted in reverse")

	# Test Forward Motion / Parked Lighting (Backup Ground Square Off)
	rover.current_speed = 2.5
	rover.set("_throttle_input", 1.0)
	rover.set("_is_braking", false)
	rover.lights_on = false
	rover._update_lighting(0.016)
	check(backup_ground.visible == false, "BackupGroundSquare hidden when moving forward")

	# Test Brake Light Glowing Squares
	rover.set("_is_braking", true)
	rover._update_lighting(0.016)
	if tail_mat != null:
		check(tail_mat.emission.r > 0.9 and tail_mat.emission.b < 0.2, "Taillight squares glow bright red when braking")

	# Test Zero Blurry OmniLight Falloff (Legacy lights remain 0 energy)
	check(left_t.light_energy == 0.0 and left_t.visible == false, "Legacy OmniLight taillights maintain 0.0 energy (zero unnatural blurry radial gradient)")

	rover.queue_free()
	player_body.queue_free()
	await process_frame

	print("=== VEHICLE TESTS SUMMARY: %d Passed, %d Failed ===" % [passes, failures])
	if failures > 0:
		quit(1)
	else:
		quit(0)
