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
	print("--- Running Jumping Enemy Hit Registration & Scorch Decal Verification ---")
	call_deferred("_run_tests")

func _count_laser_burns() -> int:
	var count : int = 0
	for node in root.find_children("*", "", true, false):
		var nname : String = node.name.to_lower()
		if nname.contains("laserburn") or nname.contains("laser_burn") or node is LaserBurn:
			count += 1
	return count

func _run_tests() -> void:
	await process_frame
	await process_frame

	var bullet_scene : PackedScene = load("res://scenes/projectiles/bullet.tscn")
	var enemy_scene : PackedScene = load("res://scenes/enemy/enemy.tscn")
	check(bullet_scene != null, "bullet.tscn loaded successfully")
	check(enemy_scene != null, "enemy.tscn loaded successfully")

	# -------------------------------------------------------------------------
	# [Test 1] Bullet Hitting Airborne / Jumping Enemy Registers Damage Cleanly
	# -------------------------------------------------------------------------
	print("\n[Test 1] Testing Bullet Hitting Jumping Enemy Registers Damage...")
	var jumping_enemy : CharacterBody3D = enemy_scene.instantiate() as CharacterBody3D
	jumping_enemy.name = "JumpingEnemy"
	root.add_child(jumping_enemy)
	# Position enemy mid-air as if vaulted 0.65m above ground
	jumping_enemy.global_position = Vector3(0.0, 0.65, 5.0)

	var bullet : Area3D = bullet_scene.instantiate() as Area3D
	bullet.direction = Vector3(0.0, 0.0, 1.0)
	bullet.speed = 20.0
	bullet.damage = 35
	root.add_child(bullet)
	# Fired towards the jumping enemy
	bullet.global_position = Vector3(0.0, 0.85, 2.0)

	var enemy_hc : HealthComponent = jumping_enemy.get_node_or_null("HealthComponent") as HealthComponent
	check(enemy_hc != null, "Enemy has HealthComponent")
	var hp_before : int = enemy_hc.health

	# Step physics frames to simulate flight and impact
	for i in range(12):
		await process_frame

	check(enemy_hc.health < hp_before, "Jumping enemy took damage from airborne bullet (before: %d, after: %d)" % [hp_before, enemy_hc.health])
	jumping_enemy.queue_free()
	await process_frame

	# -------------------------------------------------------------------------
	# [Test 2] High-Speed Bullet Sweep Against Jumping Enemy (No Tunneling)
	# -------------------------------------------------------------------------
	print("\n[Test 2] Testing High-Speed Sniper Sweep (No Tunneling) on Jumping Enemy...")
	var vaulting_enemy : CharacterBody3D = enemy_scene.instantiate() as CharacterBody3D
	vaulting_enemy.name = "VaultingEnemy"
	root.add_child(vaulting_enemy)
	vaulting_enemy.global_position = Vector3(0.0, 0.55, 6.0)

	var fast_bullet : Area3D = bullet_scene.instantiate() as Area3D
	fast_bullet.direction = Vector3(0.0, 0.0, 1.0)
	fast_bullet.speed = 65.0 # Sniper speed
	fast_bullet.damage = 50
	root.add_child(fast_bullet)
	fast_bullet.global_position = Vector3(0.0, 0.75, 1.0)

	var vault_hc : HealthComponent = vaulting_enemy.get_node_or_null("HealthComponent") as HealthComponent
	var v_hp_before : int = vault_hc.health

	for i in range(12):
		await process_frame

	check(vault_hc.health < v_hp_before, "High-velocity bullet connected without tunneling (before: %d, after: %d)" % [v_hp_before, vault_hc.health])
	if is_instance_valid(vaulting_enemy):
		vaulting_enemy.queue_free()
	await process_frame

	# -------------------------------------------------------------------------
	# [Test 3] Fatal Bullet Hit on Dynamically Spawned Enemy Leaves Zero Scorch
	# -------------------------------------------------------------------------
	print("\n[Test 3] Testing Fatal Hit on Dynamic Enemy Spawns Zero Scorch Marks...")
	var dyn_enemy : CharacterBody3D = enemy_scene.instantiate() as CharacterBody3D
	dyn_enemy.name = "@Enemy@42" # Dynamic Godot auto-generated duplicate node name
	root.add_child(dyn_enemy)
	dyn_enemy.global_position = Vector3(0.0, 0.0, 10.0)
	var dyn_hc : HealthComponent = dyn_enemy.get_node_or_null("HealthComponent") as HealthComponent
	dyn_hc.health = 25 # Low HP

	var fatal_bullet : Area3D = bullet_scene.instantiate() as Area3D
	fatal_bullet.direction = Vector3(0.0, 0.0, 1.0)
	fatal_bullet.speed = 25.0
	fatal_bullet.damage = 40 # Fatal shot
	root.add_child(fatal_bullet)
	fatal_bullet.global_position = Vector3(0.0, 0.3, 9.2)

	var burns_before : int = _count_laser_burns()
	for i in range(12):
		await process_frame

	var burns_after : int = _count_laser_burns()
	check(burns_after == burns_before, "Fatal bullet hit on dynamic enemy spawned NO scorch marks (before: %d, after: %d)" % [burns_before, burns_after])

	# -------------------------------------------------------------------------
	# [Test 4] Player Aim Collision Mask Includes Enemy Layer 2
	# -------------------------------------------------------------------------
	print("\n[Test 4] Testing Player Aim Collision Mask Includes Enemy Layer...")
	var proto_scene : PackedScene = load("res://addons/proto_controller/proto_controller.tscn")
	check(proto_scene != null, "proto_controller.tscn loaded successfully")
	var player_instance : CharacterBody3D = proto_scene.instantiate() as CharacterBody3D
	root.add_child(player_instance)
	await process_frame

	var combat_node : Node = player_instance.get_node_or_null("PlayerCombat")
	if combat_node == null:
		var pc_script : GDScript = load("res://scenes/player/player_combat.gd") as GDScript
		combat_node = Node.new()
		combat_node.name = "PlayerCombat"
		combat_node.set_script(pc_script)
		player_instance.add_child(combat_node)
		await process_frame

	var aim_mask : int = combat_node.get("AIM_COLLISION_MASK")
	check((aim_mask & 2) != 0, "Aim collision mask includes Layer 2 (Enemies) bitmask (mask: %d)" % aim_mask)
	check((aim_mask & 1) != 0, "Aim collision mask includes Layer 1 (World) bitmask")
	player_instance.queue_free()
	await process_frame

	# -------------------------------------------------------------------------
	# [Test 5] Enemy Navigation Safeguards Against Unsynced Maps
	# -------------------------------------------------------------------------
	print("\n[Test 5] Testing Enemy Navigation Query Safety on Fresh Instances...")
	var test_enemy : CharacterBody3D = enemy_scene.instantiate() as CharacterBody3D
	root.add_child(test_enemy)
	await process_frame

	var nav_ready : bool = test_enemy.call("_is_nav_ready")
	# If map is not synced, it must return false safely without error
	var path_dir : Vector3 = test_enemy.call("_get_path_direction")
	check(path_dir == Vector3.ZERO or path_dir.is_normalized(), "Path direction calculated safely without engine corridor error")
	var path_dist : float = test_enemy.call("_get_path_distance")
	check(path_dist == INF or path_dist >= 0.0, "Path distance calculated safely without engine error")
	test_enemy.queue_free()
	await process_frame

	# -------------------------------------------------------------------------
	# [Test 6] Rocket Launcher Direct Hit on Character Spawns Zero Scorch
	# -------------------------------------------------------------------------
	print("\n[Test 6] Testing Rocket Direct Hit on Character Spawns Zero Scorch...")
	var rocket_scene : PackedScene = load("res://scenes/projectiles/rocket.tscn")
	check(rocket_scene != null, "rocket.tscn loaded successfully")
	var rocket_enemy : CharacterBody3D = enemy_scene.instantiate() as CharacterBody3D
	rocket_enemy.name = "RocketEnemyTarget"
	root.add_child(rocket_enemy)
	rocket_enemy.global_position = Vector3(0.0, 1.0, 15.0)

	var rocket : Area3D = rocket_scene.instantiate() as Area3D
	root.add_child(rocket)
	rocket.global_position = Vector3(0.0, 1.0, 14.5)

	var burns_pre_rocket : int = _count_laser_burns()
	rocket.detonate(rocket_enemy, Vector3.UP)
	await process_frame
	var burns_post_rocket : int = _count_laser_burns()
	check(burns_post_rocket == burns_pre_rocket, "Rocket direct hit on character spawned NO scorch crater (before: %d, after: %d)" % [burns_pre_rocket, burns_post_rocket])
	if is_instance_valid(rocket_enemy):
		rocket_enemy.queue_free()

	# -------------------------------------------------------------------------
	# Summary
	# -------------------------------------------------------------------------
	print("\n=======================================================")
	print("JUMP HITREG & SCORCH RESULTS: %d Passed, %d Failed" % [passes, failures])
	print("=======================================================\n")
	quit(0 if failures == 0 else 1)
