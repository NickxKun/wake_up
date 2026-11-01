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
	print("--- Running Low-Poly Mushroom Cloud & Explosion Mechanics Test Suite ---")
	call_deferred("_run_tests")

func _run_tests() -> void:
	await process_frame
	await process_frame

	# ----------------------------------------------------
	# [Test 1] Low-Poly Mushroom Cloud Structure & Aesthetics
	# ----------------------------------------------------
	print("\n[Test 1] Testing Low-Poly Mushroom Cloud Structure & Aesthetics...")
	var exp_scene : PackedScene = load("res://scenes/projectiles/explosion_effect.tscn")
	check(exp_scene != null, "explosion_effect.tscn loaded successfully")
	var exp_inst : Node3D = exp_scene.instantiate() as Node3D
	root.add_child(exp_inst)
	await process_frame

	var smoke : CPUParticles3D = exp_inst.get_node_or_null("SmokeCloud") as CPUParticles3D
	check(smoke != null, "SmokeCloud particle emitter present")
	if smoke != null:
		check(smoke.amount >= 60, "SmokeCloud has dense particle count (%d >= 60)" % smoke.amount)
		check(smoke.mesh is SphereMesh, "SmokeCloud uses SphereMesh")
		if smoke.mesh is SphereMesh:
			var sm : SphereMesh = smoke.mesh as SphereMesh
			check(sm.radial_segments <= 8, "SmokeCloud mesh is low-poly faceted (radial_segments: %d <= 8)" % sm.radial_segments)

	var stem : CPUParticles3D = exp_inst.get_node_or_null("MushroomStem") as CPUParticles3D
	check(stem != null, "MushroomStem vertical pillar emitter present")
	if stem != null:
		check(stem.direction.y > 0.8, "MushroomStem emits upwards to form mushroom column")
		if stem.mesh is SphereMesh:
			var stem_mesh : SphereMesh = stem.mesh as SphereMesh
			check(stem_mesh.radial_segments <= 6, "MushroomStem mesh is low-poly faceted (radial_segments: %d <= 6)" % stem_mesh.radial_segments)

	var mushroom_mesh : Node3D = exp_inst.get_node_or_null("LowPolyMushroomCloud") as Node3D
	check(mushroom_mesh != null, "Procedural LowPolyMushroomCloud assembly present")
	if mushroom_mesh != null:
		var stalk : Node3D = mushroom_mesh.get_node_or_null("Stalk") as Node3D
		check(stalk != null, "Mushroom cloud stalk column exists")
		check(stalk != null and stalk.get_child_count() >= 3, "Mushroom stalk composed of stacked low-poly puffs")

		var cap : Node3D = mushroom_mesh.get_node_or_null("Cap") as Node3D
		check(cap != null, "Mushroom cloud crown cap canopy exists")
		check(cap != null and cap.get_child_count() >= 6, "Mushroom cap has wide radial billow puffs")

	exp_inst.queue_free()
	await process_frame

	# ----------------------------------------------------
	# [Test 2] Distance Falloff: Farther Away = Always Lesser Damage
	# ----------------------------------------------------
	print("\n[Test 2] Testing Explosion Distance Falloff (Farther = Always Lesser Damage)...")
	var enemy_scene : PackedScene = load("res://scenes/enemy/enemy.tscn")
	check(enemy_scene != null, "enemy.tscn loaded successfully")

	var epicenter := Vector3(0.0, 0.0, 0.0)
	var blast_radius : float = 6.0
	var base_dmg : int = 100

	# 3 targets at increasing distances from epicenter: 1.0m, 2.5m, 4.5m
	var near_enemy : CharacterBody3D = enemy_scene.instantiate() as CharacterBody3D
	near_enemy.name = "NearEnemy"
	root.add_child(near_enemy)
	near_enemy.global_position = Vector3(1.0, 0.0, 0.0)

	var mid_enemy : CharacterBody3D = enemy_scene.instantiate() as CharacterBody3D
	mid_enemy.name = "MidEnemy"
	root.add_child(mid_enemy)
	mid_enemy.global_position = Vector3(2.5, 0.0, 0.0)

	var far_enemy : CharacterBody3D = enemy_scene.instantiate() as CharacterBody3D
	far_enemy.name = "FarEnemy"
	root.add_child(far_enemy)
	far_enemy.global_position = Vector3(4.5, 0.0, 0.0)

	var near_hc : HealthComponent = near_enemy.get_node("HealthComponent") as HealthComponent
	var mid_hc : HealthComponent = mid_enemy.get_node("HealthComponent") as HealthComponent
	var far_hc : HealthComponent = far_enemy.get_node("HealthComponent") as HealthComponent

	ExplosionEffect.apply_explosion_damage(self, epicenter, blast_radius, base_dmg, 8.0, null, 0.4)

	var near_loss : int = 100 - near_hc.health
	var mid_loss : int = 100 - mid_hc.health
	var far_loss : int = 100 - far_hc.health

	check(near_loss > mid_loss, "Near target received more damage than mid target (near: %d > mid: %d)" % [near_loss, mid_loss])
	check(mid_loss > far_loss, "Mid target received more damage than far target (mid: %d > far: %d)" % [mid_loss, far_loss])
	check(far_loss > 0, "Far target still received damage within blast radius (far: %d > 0)" % far_loss)

	near_enemy.queue_free()
	mid_enemy.queue_free()
	far_enemy.queue_free()
	await process_frame

	# ----------------------------------------------------
	# [Test 3] Explosions Always Affect Both Player and Enemy
	# ----------------------------------------------------
	print("\n[Test 3] Testing Explosions Affect Both Player and Enemy...")
	var proto_scene : PackedScene = load("res://addons/proto_controller/proto_controller.tscn")
	check(proto_scene != null, "proto_controller.tscn loaded successfully")

	var player_test : CharacterBody3D = proto_scene.instantiate() as CharacterBody3D
	player_test.name = "ExplosionTestPlayer"
	root.add_child(player_test)
	player_test.global_position = Vector3(1.5, 0.0, 0.0)

	var enemy_test : CharacterBody3D = enemy_scene.instantiate() as CharacterBody3D
	enemy_test.name = "ExplosionTestEnemy"
	root.add_child(enemy_test)
	enemy_test.global_position = Vector3(-1.5, 0.0, 0.0)

	var p_hc : HealthComponent = player_test.get_node("HealthComponent") as HealthComponent
	var e_hc : HealthComponent = enemy_test.get_node("HealthComponent") as HealthComponent

	# Store initial health/shield
	var p_health_before : int = p_hc.health
	var p_shield_before : float = p_hc.shield
	var e_health_before : int = e_hc.health

	ExplosionEffect.apply_explosion_damage(self, Vector3.ZERO, 4.0, 120, 8.0, null, 0.38)

	var p_damaged : bool = (p_hc.shield < p_shield_before) or (p_hc.health < p_health_before)
	var e_damaged : bool = e_hc.health < e_health_before

	check(p_damaged, "Player was affected and damaged by explosion")
	check(e_damaged, "Enemy was affected and damaged by explosion")

	# ----------------------------------------------------
	# [Test 4] Player Takes Lesser Damage Than Enemy at Same Distance
	# ----------------------------------------------------
	print("\n[Test 4] Testing Player Takes Lesser Damage Than Enemy at Same Distance...")
	# Player took damage with 0.38 scale; calculate total damage absorbed
	var player_dmg_taken : float = (p_shield_before - p_hc.shield) + float(p_health_before - p_hc.health)
	var enemy_dmg_taken : int = e_health_before - e_hc.health

	check(player_dmg_taken < float(enemy_dmg_taken), "Player damage taken is lesser than enemy damage (player: %.1f < enemy: %d)" % [player_dmg_taken, enemy_dmg_taken])
	check(player_dmg_taken > 0.0, "Player still took meaningful explosion damage (%.1f > 0)" % player_dmg_taken)

	player_test.queue_free()
	enemy_test.queue_free()
	await process_frame

	# ----------------------------------------------------
	# [Test 5] Vehicle Explosions Affect Enemies
	# ----------------------------------------------------
	print("\n[Test 5] Testing Vehicle Explosions Affect Enemies...")
	var rover_scene : PackedScene = load("res://scenes/vehicles/rover.tscn")
	check(rover_scene != null, "rover.tscn loaded successfully")

	var rover : CharacterBody3D = rover_scene.instantiate() as CharacterBody3D
	rover.name = "TestExplodingRover"
	root.add_child(rover)
	rover.global_position = Vector3(0.0, 0.5, 0.0)

	var bystander_enemy : CharacterBody3D = enemy_scene.instantiate() as CharacterBody3D
	bystander_enemy.name = "BystanderEnemy"
	root.add_child(bystander_enemy)
	bystander_enemy.global_position = Vector3(2.0, 0.0, 0.0)

	var bystander_hc : HealthComponent = bystander_enemy.get_node("HealthComponent") as HealthComponent
	var b_hp_before : int = bystander_hc.health

	# Trigger vehicle detonation
	rover._explode()
	await process_frame

	var enemy_killed_or_damaged : bool = not is_instance_valid(bystander_enemy) or bystander_hc.health < b_hp_before
	check(enemy_killed_or_damaged, "Vehicle explosion dealt fatal/heavy AoE blast damage to nearby enemy")

	if is_instance_valid(bystander_enemy):
		bystander_enemy.queue_free()
	if is_instance_valid(rover):
		rover.queue_free()
	await process_frame

	# ----------------------------------------------------
	# [Test 6] Knockback Applied to Both Player & Enemy
	# ----------------------------------------------------
	print("\n[Test 6] Testing Knockback Applied Away From Epicenter...")
	var kb_player : CharacterBody3D = proto_scene.instantiate() as CharacterBody3D
	root.add_child(kb_player)
	kb_player.global_position = Vector3(0.0, 0.0, 2.0)
	kb_player.velocity = Vector3.ZERO

	var kb_enemy : CharacterBody3D = enemy_scene.instantiate() as CharacterBody3D
	root.add_child(kb_enemy)
	kb_enemy.global_position = Vector3(0.0, 0.0, -2.0)
	kb_enemy.velocity = Vector3.ZERO

	ExplosionEffect.apply_explosion_damage(self, Vector3.ZERO, 5.0, 80, 10.0, null, 0.4)

	check(kb_player.velocity.z > 1.0, "Player flung backward along +Z blast vector (vel.z: %.2f > 1.0)" % kb_player.velocity.z)
	check(kb_player.velocity.y > 1.0, "Player received upward lift impulse (vel.y: %.2f > 1.0)" % kb_player.velocity.y)
	check(kb_enemy.velocity.z < -1.0, "Enemy flung forward along -Z blast vector (vel.z: %.2f < -1.0)" % kb_enemy.velocity.z)
	check(kb_enemy.velocity.y > 1.0, "Enemy received upward lift impulse (vel.y: %.2f > 1.0)" % kb_enemy.velocity.y)

	kb_player.queue_free()
	kb_enemy.queue_free()
	await process_frame

	# ----------------------------------------------------
	# Summary
	# ----------------------------------------------------
	print("\n=======================================================")
	print("LOW-POLY MUSHROOM & EXPLOSION RESULTS: %d Passed, %d Failed" % [passes, failures])
	print("=======================================================\n")
	quit(0 if failures == 0 else 1)
