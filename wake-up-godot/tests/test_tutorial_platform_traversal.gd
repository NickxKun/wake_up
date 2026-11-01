extends SceneTree

## Verification Test Suite for Tutorial Elevated Platform Traversal,
## Physics Flight Reachability, and Tiered Platform Geometry.

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
	print("--- Running Tutorial Platform Traversal Verification Suite ---")
	call_deferred("_run_tests")

func _run_tests() -> void:
	await process_frame
	await process_frame

	# ----------------------------------------------------
	# [Test 1] Platform Geometry & Hierarchy Validation
	# ----------------------------------------------------
	print("\n[Test 1] Validating Tutorial Platform & Step Geometry...")
	var tut_scene : PackedScene = load("res://scenes/tutorial/tutorial_map.tscn")
	check(tut_scene != null, "tutorial_map.tscn loaded successfully")

	var map : Node3D = tut_scene.instantiate() as Node3D
	root.add_child(map)
	await process_frame
	await process_frame

	var facility : Node = map.find_child("FacilityGeometry", true, false)
	check(facility != null, "FacilityGeometry exists in scene")

	var platform : StaticBody3D = facility.find_child("FlightPlatform", true, false) as StaticBody3D
	check(platform != null, "FlightPlatform exists in facility")
	var p_col : CollisionShape3D = platform.find_child("CollisionShape3D", true, false) as CollisionShape3D
	var p_shape : BoxShape3D = p_col.shape as BoxShape3D if p_col != null else null
	check(p_shape != null, "Platform has BoxShape3D collision")
	var deck_top_y : float = platform.position.y + (p_shape.size.y * 0.5) if p_shape != null else 0.0
	check(is_equal_approx(deck_top_y, 1.0), "FlightPlatform deck top is positioned at reachable height 1.0m (actual: %.2fm)" % deck_top_y)

	var step_west : StaticBody3D = facility.find_child("PlatformStepWest", true, false) as StaticBody3D
	check(step_west != null, "PlatformStepWest exists providing tiered approach ledge")
	var sw_col : CollisionShape3D = step_west.find_child("CollisionShape3D", true, false) as CollisionShape3D
	var sw_shape : BoxShape3D = sw_col.shape as BoxShape3D if sw_col != null else null
	var sw_top_y : float = step_west.position.y + (sw_shape.size.y * 0.5) if sw_shape != null else 0.0
	check(is_equal_approx(sw_top_y, 0.5), "PlatformStepWest top is positioned at intermediate height 0.5m (actual: %.2fm)" % sw_top_y)

	var step_east : StaticBody3D = facility.find_child("PlatformStepEast", true, false) as StaticBody3D
	check(step_east != null, "PlatformStepEast exists providing descent step towards weapons range")

	# Waypoint placement
	var wp_thrusters : TutorialWaypoint = map.find_child("Waypoint_Thrusters", true, false) as TutorialWaypoint
	check(wp_thrusters != null, "Waypoint_Thrusters exists in scene")
	check(is_equal_approx(wp_thrusters.position.y, 1.0), "Waypoint_Thrusters placed at y=1.0m matching platform deck (actual: %.2fm)" % wp_thrusters.position.y)

	# Vault barrier & Locomotion waypoint spacing
	var vault_barrier : StaticBody3D = facility.find_child("VaultBarrier", true, false) as StaticBody3D
	check(vault_barrier != null, "VaultBarrier exists")
	check(vault_barrier.position.x <= -14.0, "VaultBarrier spaced west of Locomotion waypoint (pos.x: %.1f)" % vault_barrier.position.x)
	var wp_locomotion : TutorialWaypoint = map.find_child("Waypoint_Locomotion", true, false) as TutorialWaypoint
	check(wp_locomotion != null and wp_locomotion.position.x > vault_barrier.position.x, "Waypoint_Locomotion positioned after VaultBarrier")

	# ----------------------------------------------------
	# [Test 2] Player Thruster Settings & Responsiveness
	# ----------------------------------------------------
	print("\n[Test 2] Testing Player Thruster Physics Configuration...")
	var player : CharacterBody3D = map.find_child("ProtoController", true, false) as CharacterBody3D
	check(player != null, "Player ProtoController found")
	check(player.get("max_flight_height") >= 1.8 and player.max_flight_height <= 2.0, "max_flight_height (%.2fm) gives comfortable clearance over 1.0m platform" % player.max_flight_height)
	check(player.get("stamina_recharge_rate") >= 0.7, "stamina_recharge_rate is responsive (%.2f/s)" % player.stamina_recharge_rate)

	# Verify flight can engage with partial stamina (< 1.0 bar)
	player.stamina = 0.5 # Less than 1 full bar
	player.global_position = Vector3(-10.0, 0.8, 0.0) # In air
	player.velocity = Vector3.ZERO
	# Simulate pressing and holding jump
	Input.action_press(player.input_jump)
	player._physics_process(0.016) # Updates floor detection in air
	player._physics_process(0.016) # Engages thrusters in air
	check(player.is_flying == true, "Thrusters engage successfully with partial stamina (0.5 bar)")
	Input.action_release(player.input_jump)
	player.is_flying = false

	# ----------------------------------------------------
	# [Test 3] Simulated Jump + Thruster Flight onto Platform
	# ----------------------------------------------------
	print("\n[Test 3] Simulating Player Jump + Flight onto Elevated Platform...")
	# Position player on the ground approaching the platform
	player.global_position = Vector3(-10.0, 0.1, 0.0)
	player.velocity = Vector3.ZERO
	player.stamina = 3.0

	var reached_deck : bool = false
	var wp_triggered : bool = false
	wp_thrusters.reached.connect(func(_id): wp_triggered = true)
	wp_thrusters.activate()

	# Simulate: Player jumps and engages thrusters while moving eastward (+X) towards the platform
	Input.action_press(player.input_jump)
	# In 45-deg isometric setup (angle +45), Right + Back yields pure East (+X)
	Input.action_press(player.input_right)
	Input.action_press(player.input_back)

	for frame in range(150): # Simulate up to 2.5 seconds of physics
		player._physics_process(0.0166667)
		await process_frame

		if player.global_position.y >= 0.95 and player.global_position.x >= -7.0:
			reached_deck = true

		if wp_triggered:
			break

	Input.action_release(player.input_jump)
	Input.action_release(player.input_right)
	Input.action_release(player.input_back)

	check(reached_deck, "Player successfully scaled the height and reached the platform deck (final pos: %.2f, %.2f, %.2f)" % [player.global_position.x, player.global_position.y, player.global_position.z])
	check(player.global_position.y >= 0.9, "Player maintained altitude on top of the platform deck")

	# ----------------------------------------------------
	# [Test 4] Facility Visual Trims & Guides
	# ----------------------------------------------------
	print("\n[Test 4] Testing Platform Trims & Elevated Floor Chevrons...")
	var trims : Node = facility.find_child("PlatformTrims", true, false)
	check(trims != null, "PlatformTrims node exists with hazard stripes and glowing deck perimeter")

	var floor_guides : Node = facility.find_child("FloorDirectionGuides", true, false)
	check(floor_guides != null, "FloorDirectionGuides exists")
	var chevrons : Array[Node] = floor_guides.find_children("*GuideChevron*", "", true, false) if floor_guides != null else []
	check(chevrons.size() >= 15, "At least 15 ground directional chevrons placed across compound (found: %d)" % chevrons.size())

	# Verify elevated chevrons on steps and deck
	var elevated_chevrons : int = 0
	for c in chevrons:
		var c3d := c as Node3D
		if c3d != null and c3d.position.y > 0.1:
			elevated_chevrons += 1
	check(elevated_chevrons >= 3, "Elevated guide chevrons present on steps and platform deck (found: %d)" % elevated_chevrons)

	# Cleanup
	map.queue_free()
	await process_frame

	# ----------------------------------------------------
	# Final Verification Results
	# ----------------------------------------------------
	print("\n=======================================================")
	print("PLATFORM TRAVERSAL RESULTS: %d Passed, %d Failed" % [passes, failures])
	print("=======================================================\n")
	quit(0 if failures == 0 else 1)
