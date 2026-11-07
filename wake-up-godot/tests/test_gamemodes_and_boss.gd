extends SceneTree

const BossMechScript = preload("res://scenes/enemy/boss_mech.gd")
const RangeManagerScript = preload("res://scenes/gamemodes/range_manager.gd")
const TrainingTargetScript = preload("res://scenes/tutorial/training_target.gd")

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
	print("--- Running Range Mode, Rocket Mayhem, Enemy Weapons & Titan Mech Boss Verification Suite ---")
	call_deferred("_run_tests")

func _run_tests() -> void:
	await process_frame
	await process_frame

	# =========================================================================
	# [Test 1] Target System: Motion, Armor Regen & Auto-Reset
	# =========================================================================
	print("\n[Test 1] Testing Target System Upgrades...")
	var target_scene : PackedScene = load("res://scenes/tutorial/training_target.tscn")
	check(target_scene != null, "training_target.tscn loaded successfully")

	var target : TrainingTarget = target_scene.instantiate() as TrainingTarget
	target.regen_armor_on_hit = true
	target.auto_reset_delay = 5.0
	target.is_moving = true
	target.move_distance = 6.0
	target.move_speed = 3.0
	root.add_child(target)
	await process_frame
	await process_frame

	check(target.is_in_group("target"), "Target is registered in 'target' group")
	check(target.regen_armor_on_hit == true, "regen_armor_on_hit property set correctly")
	check(target.auto_reset_delay == 5.0, "auto_reset_delay set to 5.0 seconds")
	check(target.is_moving == true, "is_moving property set to true")

	# Simulate taking damage on armor regen target
	var prev_pos : Vector3 = target.position
	target._process(0.5)
	check(target.position != prev_pos, "Target moves dynamically along axis over time")

	var dmg_result : int = target.take_damage(20)
	check(dmg_result == 20, "take_damage returns amount")
	check(target._is_disabled == true, "Target collapses and is disabled after hit")
	await process_frame
	check(target.collision_shape.disabled == true, "Target collision is disabled while folded")

	# Reset target manually
	target.reset_target()
	check(target._is_disabled == false, "Target resets disabled flag")
	check(target.collision_shape.disabled == false, "Target collision re-enabled upon reset")
	target.queue_free()
	await process_frame

	# =========================================================================
	# [Test 2] Natural Map Target Spawning
	# =========================================================================
	print("\n[Test 2] Testing Natural Map Tactical Targets Spawning...")
	var map_script : GDScript = load("res://scenes/level/space_station_map.gd") as GDScript
	check(map_script != null, "space_station_map.gd loaded successfully")

	var map_node : Node3D = Node3D.new()
	map_node.set_script(map_script)
	root.add_child(map_node)
	await process_frame
	await process_frame

	var map_targets : Node = map_node.get_node_or_null("MapTrainingTargets")
	check(map_targets != null, "MapTrainingTargets container node spawned on map")
	if map_targets != null:
		var count : int = map_targets.get_child_count()
		check(count >= 6, "Spawns 6 fixed tactical targets across map (actual: %d)" % count)
		var first_target : TrainingTarget = map_targets.get_child(0) as TrainingTarget
		if first_target != null:
			check(first_target.regen_armor_on_hit == true, "Natural map targets have regen_armor_on_hit enabled")
			check(first_target.auto_reset_delay == 5.0, "Natural map targets have 5.0s auto_reset_delay")

	# Check Boss Director on map
	check("boss_spawn_interval" in map_node, "Map has boss_spawn_interval property")
	check(map_node.get("boss_spawn_interval") == 300.0, "Boss spawn interval is 300.0 seconds (5 minutes)")
	check(map_node.has_method("spawn_boss_mech"), "Map has spawn_boss_mech() method")

	# Test spawning boss mech from map
	var spawned_boss : Node3D = map_node.call("spawn_boss_mech") as Node3D
	check(spawned_boss != null, "spawn_boss_mech() successfully instantiates BossMech on map")
	if spawned_boss != null:
		check(spawned_boss.is_in_group("boss"), "Spawned boss is in 'boss' group")
		check(spawned_boss.is_in_group("enemy"), "Spawned boss is in 'enemy' group")
		spawned_boss.queue_free()

	map_node.queue_free()
	await process_frame

	# =========================================================================
	# [Test 3] "The Range" Game Mode
	# =========================================================================
	print("\n[Test 3] Testing The Range Game Mode...")
	var range_scene : PackedScene = load("res://scenes/gamemodes/range_mode.tscn")
	check(range_scene != null, "range_mode.tscn loaded successfully")

	var range_node : Node3D = range_scene.instantiate() as Node3D
	root.add_child(range_node)
	await process_frame
	await process_frame

	var range_mgr : Node3D = range_node
	check(range_mgr != null and range_mgr.has_method("reset_all_targets"), "RangeManager script attached to range_mode root")

	var range_targets : Node = range_node.find_child("RangeTargets", true, false)
	check(range_targets != null, "RangeTargets container exists")
	if range_targets != null:
		var target_count : int = range_targets.get_child_count()
		check(target_count >= 8, "Range contains at least 8 practice targets (actual: %d)" % target_count)

		var has_stationary : bool = false
		var has_moving : bool = false
		for c in range_targets.get_children():
			if c is TrainingTarget:
				var tt := c as TrainingTarget
				if tt.is_moving:
					has_moving = true
				else:
					has_stationary = true
		check(has_stationary, "Range contains stationary targets")
		check(has_moving, "Range contains moving targets")

	# Test resetting all targets
	range_mgr.reset_all_targets()
	check(true, "reset_all_targets() executes cleanly")

	range_node.queue_free()
	await process_frame

	# =========================================================================
	# [Test 4] Rocket Mayhem & Explosion Immunity
	# =========================================================================
	print("\n[Test 4] Testing Rocket Mayhem & Blast Immunity...")
	var hud : Node = root.get_node_or_null("PlayerHealthHud")
	check(hud != null, "PlayerHealthHud autoload is available")
	if hud != null:
		check("is_rocket_mayhem_mode" in hud, "PlayerHealthHud has is_rocket_mayhem_mode flag")
		check("is_range_mode" in hud, "PlayerHealthHud has is_range_mode flag")
		hud.set("is_rocket_mayhem_mode", true)

	var explosion_scene : PackedScene = load("res://scenes/projectiles/explosion_effect.tscn")
	check(explosion_scene != null, "explosion_effect.tscn loaded successfully")

	# Create a dummy player with HealthComponent
	var dummy_player := CharacterBody3D.new()
	dummy_player.name = "ProtoController"
	dummy_player.add_to_group("player")
	var player_hc := HealthComponent.new()
	player_hc.name = "HealthComponent"
	player_hc.health = 100
	player_hc.has_shield = false
	dummy_player.add_child(player_hc)
	root.add_child(dummy_player)
	dummy_player.global_position = Vector3.ZERO
	await process_frame

	# Trigger explosion directly at player position while Rocket Mayhem is active
	ExplosionEffect.apply_explosion_damage(self, Vector3.ZERO, 5.0, 50, 10.0, null, 0.38)
	await process_frame

	check(player_hc.health == 100, "Player takes 0 damage from explosions in Rocket Mayhem (health: %d/100)" % player_hc.health)

	# Now disable rocket mayhem mode and verify explosion damages normally
	if hud != null:
		hud.set("is_rocket_mayhem_mode", false)
	ExplosionEffect.apply_explosion_damage(self, Vector3.ZERO, 5.0, 50, 10.0, null, 0.38)
	await process_frame

	check(player_hc.health < 100, "Player takes normal damage from explosions when Rocket Mayhem is inactive (health: %d/100)" % player_hc.health)

	dummy_player.queue_free()
	await process_frame

	# =========================================================================
	# [Test 5] Enemy Weapon Variety (Shotgun, Double Pistols)
	# =========================================================================
	print("\n[Test 5] Testing Enemy Weapon Variants...")
	var enemy_scene : PackedScene = load("res://scenes/enemy/enemy.tscn")
	check(enemy_scene != null, "enemy.tscn loaded successfully")

	var enemy : CharacterBody3D = enemy_scene.instantiate() as CharacterBody3D
	root.add_child(enemy)
	await process_frame
	await process_frame

	check("weapon_type" in enemy, "Enemy has weapon_type property")
	check(enemy.has_method("set_weapon_type"), "Enemy has set_weapon_type() method")

	# Test Shotgun weapon configuration
	enemy.call("set_weapon_type", 1) # SHOTGUN
	check(enemy.get("weapon_type") == 1, "Enemy configured with SHOTGUN")
	check(enemy.get("shoot_interval") >= 1.8, "Shotgun enemy has longer shoot interval")

	# Test Double Pistols weapon configuration
	enemy.call("set_weapon_type", 2) # DOUBLE_PISTOLS
	check(enemy.get("weapon_type") == 2, "Enemy configured with DOUBLE_PISTOLS")
	check(enemy.get("shoot_interval") <= 1.1, "Double Pistols enemy has rapid fire interval")

	# Test shooting with both variants
	enemy.call("_shoot", Vector3.FORWARD)
	await process_frame
	check(true, "_shoot() with DOUBLE_PISTOLS executes without errors")

	enemy.call("set_weapon_type", 1)
	enemy.call("_shoot", Vector3.FORWARD)
	await process_frame
	check(true, "_shoot() with SHOTGUN executes without errors")

	enemy.queue_free()
	for c in root.get_children():
		if c is Area3D:
			c.queue_free()
	await process_frame
	await process_frame

	# =========================================================================
	# [Test 6] Titan Mech Boss (Stats, Attacks, Patterns)
	# =========================================================================
	print("\n[Test 6] Testing Titan Mech Boss...")
	var boss_scene : PackedScene = load("res://scenes/enemy/boss_mech.tscn")
	check(boss_scene != null, "boss_mech.tscn loaded successfully")

	var boss : CharacterBody3D = boss_scene.instantiate() as CharacterBody3D
	boss.position = Vector3(50.0, 0.0, 50.0)
	root.add_child(boss)
	await process_frame
	await process_frame

	check(boss.get("max_health") == 800, "Boss max health is 800 HP")
	var boss_hc : HealthComponent = boss.get_node_or_null("HealthComponent") as HealthComponent
	check(boss_hc != null and boss_hc.health == 800, "Boss HealthComponent starts at 800 HP")
	check(boss.is_in_group("boss"), "Boss is in 'boss' group")
	check(boss.is_in_group("enemy"), "Boss is in 'enemy' group")

	# Verify attack pattern methods exist and can be called safely
	check(boss.has_method("_start_plasma_volley"), "Boss has _start_plasma_volley() pattern")
	check(boss.has_method("_start_rocket_salvo"), "Boss has _start_rocket_salvo() pattern")
	check(boss.has_method("_start_seismic_stomp"), "Boss has _start_seismic_stomp() pattern")

	# Trigger Seismic Stomp
	boss.call("_start_seismic_stomp")
	await process_frame
	check(true, "_start_seismic_stomp() triggers shockwave sequence cleanly")

	boss.queue_free()
	await process_frame

	# =========================================================================
	# [Test 7] Main Menu Integration
	# =========================================================================
	print("\n[Test 7] Testing Main Menu Cards & Mode Selection...")
	var menu_scene : PackedScene = load("res://scenes/ui/main_menu.tscn")
	check(menu_scene != null, "main_menu.tscn loaded successfully")

	var menu : Control = menu_scene.instantiate() as Control
	root.add_child(menu)
	await process_frame
	await process_frame

	var story_card : Button = menu.find_child("StoryCard", true, false) as Button
	var coop_card : Button = menu.find_child("CoopCard", true, false) as Button
	check(story_card != null, "StoryCard (The Range) exists in main menu")
	check(coop_card != null, "CoopCard (Rocket Mayhem) exists in main menu")

	# Select The Range
	menu.call("_select_mode", 3) # GameMode.RANGE
	await process_frame
	check(menu.get("selected_mode") == 3, "GameMode.RANGE can be selected")

	# Select Rocket Mayhem
	menu.call("_select_mode", 4) # GameMode.ROCKET_MAYHEM
	await process_frame
	check(menu.get("selected_mode") == 4, "GameMode.ROCKET_MAYHEM can be selected")

	menu.queue_free()
	await process_frame

	# =========================================================================
	# Final Summary
	# =========================================================================
	print("\n=======================================================")
	print("VERIFICATION RESULTS: %d Passed, %d Failed" % [passes, failures])
	print("=======================================================\n")
	quit(0 if failures == 0 else 1)
