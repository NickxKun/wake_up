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
	print("--- Running Enemy Movement, Obstacle Jumping, Mutual Collision & Flight Height Limits Test ---")
	await process_frame
	await process_frame

	# 1. Test Flight Height Limits
	print("\n[Testing Astronaut Pressurized Air Flight Height Limits]")
	var player_scene : PackedScene = load("res://addons/proto_controller/proto_controller.tscn")
	check(player_scene != null, "proto_controller.tscn loaded")
	var player : CharacterBody3D = player_scene.instantiate()
	root.add_child(player)

	# Add ground floor below player
	var floor_body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(50, 1, 50)
	col.shape = box
	floor_body.add_child(col)
	floor_body.position = Vector3(0, -0.5, 0)
	root.add_child(floor_body)

	await process_frame
	await process_frame

	player.global_position = Vector3(0, 0.3, 0)
	player.stamina = 3.0
	check(player.get("max_flight_height") != null and player.max_flight_height <= 2.0, "Reasonable max_flight_height configured (<= 2.0m, actual: %.2fm)" % player.max_flight_height)
	check(player.get("max_fly_speed") != null and player.max_fly_speed <= 3.0, "Reasonable max_fly_speed configured (<= 3.0m/s, actual: %.2fm/s)" % player.max_fly_speed)

	# Simulate holding jump to fly
	Input.action_press(player.input_jump)
	player.velocity = Vector3(0, 2.0, 0)
	player.global_position = Vector3(0, 0.8, 0) # Already mid-air

	# Simulate 60 physics frames (1 second of sustained flight)
	for _i in range(60):
		player._physics_process(0.0166667)
		await process_frame

	var peak_height : float = player.global_position.y - 0.3
	check(peak_height <= player.max_flight_height + 0.35, "Player flight height capped reasonably at ceiling (height: %.2fm, ceiling: %.2fm)" % [peak_height, player.max_flight_height])
	check(player.velocity.y <= 1.0, "Vertical velocity decelerates near ceiling to prevent rocketing into sky (vel.y: %.2f)" % player.velocity.y)
	Input.action_release(player.input_jump)

	# 2. Test Enemy Slope & CharacterBody3D Settings
	print("\n[Testing Enemy Slope Pathing & Settings]")
	var enemy_scene : PackedScene = load("res://scenes/enemy/enemy.tscn")
	check(enemy_scene != null, "enemy.tscn loaded")
	var enemy : CharacterBody3D = enemy_scene.instantiate()
	root.add_child(enemy)
	await process_frame

	check(enemy.floor_constant_speed == true, "Enemy has floor_constant_speed = true for consistent slope speed")
	check(enemy.floor_max_angle >= deg_to_rad(50.0), "Enemy floor_max_angle >= 50 deg (actual: %.1f deg) to traverse terrain slopes" % rad_to_deg(enemy.floor_max_angle))
	check(enemy.floor_snap_length >= 0.2, "Enemy floor_snap_length >= 0.2m (actual: %.2fm) for secure slope adhesion" % enemy.floor_snap_length)

	var nav_agent : NavigationAgent3D = enemy.get_node_or_null("NavigationAgent3D")
	check(nav_agent != null and nav_agent.path_desired_distance >= 0.3, "NavigationAgent3D path_desired_distance >= 0.3m (actual: %.2fm) to avoid slope waypoint stutter" % (nav_agent.path_desired_distance if nav_agent else 0.0))

	# 3. Test Enemy-to-Enemy Mutual Physics Collision
	print("\n[Testing Enemy Mutual Physics Collision]")
	check((enemy.collision_layer & 2) != 0, "Enemy on collision_layer 2 (Enemies)")
	check((enemy.collision_mask & 2) != 0, "Enemy collision_mask includes layer 2 (collides with other enemies)")

	var enemy2 : CharacterBody3D = enemy_scene.instantiate()
	root.add_child(enemy2)
	await process_frame
	await process_frame

	enemy.global_position = Vector3(5.0, 0.3, 5.0)
	enemy2.global_position = Vector3(5.8, 0.3, 5.0)
	await process_frame
	await process_frame

	# Move enemy2 directly into enemy
	for _step in range(25):
		enemy2.velocity = Vector3(-4.0, 0.0, 0.0)
		enemy2.move_and_slide()
		await process_frame

	var mutual_distance : float = enemy.global_position.distance_to(enemy2.global_position)
	check(mutual_distance >= 0.36, "Enemies physically collide and do not penetrate each other (distance: %.2fm >= 0.36m)" % mutual_distance)

	# 4. Test Crowd Separation / Flocking
	print("\n[Testing Enemy Crowd Separation]")
	var separation : Vector3 = enemy2._get_crowd_separation()
	check(separation.length_squared() > 0.001, "Crowd separation produces non-zero steering vector away from adjacent ally (len: %.2f)" % separation.length())
	check(separation.x > 0.0, "Crowd separation steers enemy2 away (+X) from enemy at -X")

	# 5. Test Obstacle Jumping Logic
	print("\n[Testing Enemy Obstacle Jumping]")
	check(enemy.can_jump == true, "Enemy can_jump is enabled")
	check(enemy.jump_velocity >= 3.0, "Enemy jump_velocity >= 3.0m/s (actual: %.2fm/s)" % enemy.jump_velocity)
	check(enemy.jump_cooldown >= 0.4, "Enemy jump_cooldown >= 0.4s to prevent hopping spam")

	# Add low obstacle (0.25m tall box)
	var obs := StaticBody3D.new()
	var col_obs := CollisionShape3D.new()
	var box_obs := BoxShape3D.new()
	box_obs.size = Vector3(0.4, 0.25, 2.0)
	col_obs.shape = box_obs
	obs.add_child(col_obs)
	obs.position = Vector3(10.0, 0.125, 0.0)
	root.add_child(obs)
	await process_frame
	await process_frame

	# Place enemy facing low obstacle on floor
	enemy.global_position = Vector3(9.6, 0.05, 0.0)
	enemy._jump_cooldown_timer = 0.0
	for _f in range(5):
		enemy.velocity.y = -2.0
		enemy.move_and_slide()
		await process_frame
	enemy._jump_cooldown_timer = 0.0

	var should_jump : bool = enemy._should_jump(Vector3(1.0, 0.0, 0.0))
	check(should_jump == true, "Enemy detects small obstacle ahead and decides to jump")

	# Execute jump
	enemy._perform_jump(Vector3(1.0, 0.0, 0.0))
	check(is_equal_approx(enemy.velocity.y, enemy.jump_velocity), "Enemy executes jump with correct jump_velocity (%.2fm/s)" % enemy.velocity.y)
	check(enemy._jump_cooldown_timer > 0.0, "Enemy jump cooldown timer activated")

	# While on cooldown, enemy does not double-jump
	check(enemy._should_jump(Vector3(1.0, 0.0, 0.0)) == false, "Enemy does not jump while on cooldown")

	print("\n--- Verification Results: %d Passed, %d Failed ---" % [passes, failures])
	quit(0 if failures == 0 else 1)
