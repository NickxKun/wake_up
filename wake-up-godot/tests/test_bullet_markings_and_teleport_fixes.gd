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
	print("--- Running Bullet Markings & Teleport Fixes Verification ---")
	call_deferred("_run_tests")

func _run_tests() -> void:
	await process_frame
	await process_frame

	# ----------------------------------------------------
	# [Test 1] Bullet Decal: In-Tree Instantiation & Normal Sizing
	# ----------------------------------------------------
	print("\n[Test 1] Testing Bullet Decal In-Tree Setup & Perpendicular Normal...")
	var bullet_scene : PackedScene = load("res://scenes/projectiles/bullet.tscn")
	check(bullet_scene != null, "bullet.tscn loaded successfully")

	var wall : StaticBody3D = StaticBody3D.new()
	wall.name = "TestStationWall"
	wall.collision_layer = 1
	wall.collision_mask = 1
	var col : CollisionShape3D = CollisionShape3D.new()
	var box : BoxShape3D = BoxShape3D.new()
	box.size = Vector3(10.0, 10.0, 1.0)
	col.shape = box
	wall.add_child(col)
	root.add_child(wall)
	wall.global_position = Vector3(0.0, 2.0, 5.0)

	var bullet : Area3D = bullet_scene.instantiate() as Area3D
	bullet.direction = Vector3(0.0, 0.0, 1.0)
	bullet.speed = 40.0
	root.add_child(bullet)
	bullet.global_position = Vector3(0.0, 2.0, 4.0)

	await process_frame
	await process_frame

	# Find the spawned LaserBurn decal
	var spawned_burn : Node3D = null
	for child in root.get_children():
		if child is LaserBurn:
			spawned_burn = child as Node3D
			break

	check(spawned_burn != null, "LaserBurn decal spawned in scene tree upon bullet impact")
	if spawned_burn != null:
		check(spawned_burn.is_inside_tree(), "LaserBurn is securely inside scene tree")
		check(is_equal_approx(spawned_burn.scale.x, spawned_burn.scale.z), "Mark has zero odd stretching: scale.x == scale.z (%.2f == %.2f)" % [spawned_burn.scale.x, spawned_burn.scale.z])
		var decal_up : Vector3 = spawned_burn.global_transform.basis.y
		var expected_normal : Vector3 = Vector3(0.0, 0.0, -1.0) # Outward from wall facing South
		check(decal_up.dot(expected_normal) > 0.98, "Decal basis is perpendicular along contact normal (dot: %.2f > 0.98)" % decal_up.dot(expected_normal))
		check(absf(spawned_burn.global_position.z - 4.5) < 0.1, "Decal global position cleanly placed at impact surface (Z: %.2f)" % spawned_burn.global_position.z)

	# ----------------------------------------------------
	# [Test 2] LaserBurn Decal Visual Quality & Cull Mode
	# ----------------------------------------------------
	print("\n[Test 2] Testing LaserBurn Decal Material & Cull Mode...")
	var burn_scene : PackedScene = load("res://scenes/projectiles/laser_burn.tscn")
	check(burn_scene != null, "laser_burn.tscn loaded successfully")
	var burn_inst : Node3D = burn_scene.instantiate() as Node3D
	root.add_child(burn_inst)
	burn_inst.call("setup_impact", Vector3.UP, Vector3.DOWN, null, false)
	await process_frame

	var mi : MeshInstance3D = burn_inst.get_node_or_null("MeshInstance3D") as MeshInstance3D
	check(mi != null, "LaserBurn has MeshInstance3D")
	if mi != null:
		var pm : PlaneMesh = mi.mesh as PlaneMesh
		check(pm != null and pm.size.x >= 0.35, "PlaneMesh size is visible and impactful (size: %.2fm >= 0.35m)" % pm.size.x)
		var mat : StandardMaterial3D = mi.material_override as StandardMaterial3D
		check(mat != null, "LaserBurn has active StandardMaterial3D override")
		if mat != null:
			check(mat.cull_mode == BaseMaterial3D.CULL_DISABLED, "cull_mode is CULL_DISABLED (always visible from any camera angle)")
			check(mat.render_priority >= 3, "render_priority is >= 3 (renders on top of walls and ground without z-fighting)")

	# ----------------------------------------------------
	# [Test 3] Rocket Detonation Scorch Instantiation
	# ----------------------------------------------------
	print("\n[Test 3] Testing Rocket Detonation Scorch Decal...")
	var rocket_scene : PackedScene = load("res://scenes/projectiles/rocket.tscn")
	check(rocket_scene != null, "rocket.tscn loaded successfully")
	var rocket : Area3D = rocket_scene.instantiate() as Area3D
	root.add_child(rocket)
	rocket.global_position = Vector3(0.0, 1.0, 0.0)
	rocket.set("_normal", Vector3.UP)
	rocket.detonate()
	await process_frame

	var rocket_scorch : Node3D = null
	for child in root.get_children():
		if child is LaserBurn and child != spawned_burn and child != burn_inst:
			rocket_scorch = child as Node3D
			break

	check(rocket_scorch != null, "Rocket detonated and spawned blast scorch mark in tree")
	if rocket_scorch != null:
		check(rocket_scorch.is_inside_tree(), "Blast scorch is inside scene tree")
		check(rocket_scorch.scale.x > 2.0, "Rocket scorch is scaled crater (scale.x: %.2f > 2.0)" % rocket_scorch.scale.x)
		check(is_equal_approx(rocket_scorch.scale.x, rocket_scorch.scale.z), "Rocket crater is uniformly circular without stretching")

	# ----------------------------------------------------
	# [Test 4] Rover Explosion & Depenetration / Signal Fix
	# ----------------------------------------------------
	print("\n[Test 4] Testing Rover Explosion Collider & Signal Handling...")
	var rover_scene : PackedScene = load("res://scenes/vehicles/rover.tscn")
	check(rover_scene != null, "rover.tscn loaded successfully")
	var rover : CharacterBody3D = rover_scene.instantiate() as CharacterBody3D
	root.add_child(rover)
	rover.global_position = Vector3(5.0, 0.2, 5.0)

	var proto_scene : PackedScene = load("res://addons/proto_controller/proto_controller.tscn")
	check(proto_scene != null, "proto_controller.tscn loaded successfully")
	var driver : CharacterBody3D = proto_scene.instantiate() as CharacterBody3D
	root.add_child(driver)
	driver.global_position = Vector3(5.0, 0.2, 5.0)

	rover.board_vehicle(driver)
	check(rover.is_occupied == true, "Driver boarded rover")

	# Trigger vehicle health depletion (simulating fatal destruction)
	var rhc : HealthComponent = rover.get_node_or_null("HealthComponent") as HealthComponent
	check(rhc != null, "Rover has HealthComponent")
	if rhc != null:
		rhc.decrease_health(999) # Destroys rover

	await process_frame
	await process_frame

	check(rover.is_destroyed == true, "Rover marked destroyed")
	check(rover.is_occupied == false, "Driver auto-ejected upon fatal damage")
	var rover_col : CollisionShape3D = rover.get_node_or_null("Collider") as CollisionShape3D
	check(rover_col != null and rover_col.disabled == true, "Rover chassis collider disabled on destruction (prevents entrapment)")
	check(driver.velocity.length() > 0.0 and driver.velocity.length() < 15.0, "Driver ejected with smooth safe velocity (length: %.2f)" % driver.velocity.length())

	# ----------------------------------------------------
	# [Test 5] Player Spawn Clearance & Void Fallback Recovery
	# ----------------------------------------------------
	print("\n[Test 5] Testing Player Spawn Safety & Abyss Recovery...")
	var map_scene : PackedScene = load("res://scenes/main.tscn")
	check(map_scene != null, "main.tscn loaded successfully")
	var main_node : Node = map_scene.instantiate()
	root.add_child(main_node)
	await process_frame
	await process_frame

	var main_player : CharacterBody3D = main_node.find_child("ProtoController", true, false) as CharacterBody3D
	check(main_player != null, "ProtoController found in main scene")
	if main_player != null:
		check(main_player.global_position.y >= -0.05 and main_player.global_position.y < 1.0, "Player resting elevation is safely atop terrain (Y: %.2f)" % main_player.global_position.y)

	# Verify level map exists and loaded correctly
	var space_map : Node = main_node.find_child("SpaceStation", true, false)
	check(space_map != null, "SpaceStation level found in main scene")

	# Test ProtoController Abyss Rescue
	var test_player : CharacterBody3D = proto_scene.instantiate() as CharacterBody3D
	root.add_child(test_player)
	test_player.global_position = Vector3(0.0, -12.0, 0.0) # In the abyss
	test_player._physics_process(0.016)
	check(test_player.global_position.y >= 0.0, "Player falling into abyss rescued to safe surface (Y: %.2f >= 0.0)" % test_player.global_position.y)

	# Test ProtoController NaN velocity protection
	test_player.velocity = Vector3(NAN, INF, -INF)
	test_player._physics_process(0.016)
	check(not is_nan(test_player.velocity.x) and not is_inf(test_player.velocity.y), "NaN / Inf velocity cleanly filtered to zero")

	print("\n=======================================================")
	print("BULLET MARKINGS & TELEPORT FIXES: %d Passed, %d Failed" % [passes, failures])
	print("=======================================================")

	# Cleanup
	wall.queue_free()
	if spawned_burn != null: spawned_burn.queue_free()
	burn_inst.queue_free()
	if rocket_scorch != null: rocket_scorch.queue_free()
	rover.queue_free()
	driver.queue_free()
	main_node.queue_free()
	test_player.queue_free()

	quit(0 if failures == 0 else 1)
