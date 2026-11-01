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

func _count_laser_burns() -> int:
	var count : int = 0
	for node in root.get_children():
		var nname : String = node.name.to_lower()
		if nname.contains("laserburn") or nname.contains("laser_burn") or node is LaserBurn:
			count += 1
	return count

func _cleanup_laser_burns() -> void:
	for node in root.get_children():
		var nname : String = node.name.to_lower()
		if nname.contains("laserburn") or nname.contains("laser_burn") or node is LaserBurn:
			node.queue_free()

func _initialize() -> void:
	print("--- Running Terrain Edge, Truck Impacts, Weapon Glow & Disintegration Test Suite ---")
	call_deferred("_run_tests")

func _run_tests() -> void:
	await process_frame
	await process_frame

	var bullet_scene : PackedScene = load("res://scenes/projectiles/bullet.tscn")
	check(bullet_scene != null, "bullet.tscn loaded successfully")
	var burn_scene : PackedScene = load("res://scenes/projectiles/laser_burn.tscn")
	check(burn_scene != null, "laser_burn.tscn loaded successfully")

	# ----------------------------------------------------
	# [Test 1] Truck / Rover Shot: Leaves NO Scorch Decal Marker
	# ----------------------------------------------------
	print("\n[Test 1] Testing Truck Shot Leaves No Decal Marker...")
	var rover_scene : PackedScene = load("res://scenes/vehicles/rover.tscn")
	check(rover_scene != null, "rover.tscn loaded successfully")

	var rover : CharacterBody3D = rover_scene.instantiate() as CharacterBody3D
	root.add_child(rover)
	rover.global_position = Vector3(0.0, 0.0, 15.0)
	await process_frame

	var rover_hc : HealthComponent = rover.get_node_or_null("HealthComponent") as HealthComponent
	check(rover_hc != null, "Rover has HealthComponent")
	var hp_before : int = rover_hc.health if rover_hc != null else 0

	_cleanup_laser_burns()
	var burns_before : int = _count_laser_burns()

	var truck_bullet : Area3D = bullet_scene.instantiate() as Area3D
	truck_bullet.direction = Vector3(0.0, 0.0, 1.0)
	root.add_child(truck_bullet)
	truck_bullet.global_position = Vector3(0.0, 0.25, 14.5)

	# Bullet hits the rover truck
	truck_bullet._hit(rover, Vector3(0.0, 0.0, -1.0))
	await process_frame

	var burns_after : int = _count_laser_burns()
	check(burns_after == burns_before, "Bullet hitting truck spawned ZERO scorch decals (before: %d, after: %d)" % [burns_before, burns_after])
	if rover_hc != null:
		check(rover_hc.health < hp_before, "Truck HealthComponent took damage properly (HP: %d -> %d)" % [hp_before, rover_hc.health])

	rover.queue_free()
	await process_frame

	# ----------------------------------------------------
	# [Test 2] Terrain Edge & Drop-off Decal Suppression
	# ----------------------------------------------------
	print("\n[Test 2] Testing Terrain Edge Decal Suppression...")
	var test_bullet : Area3D = bullet_scene.instantiate() as Area3D
	root.add_child(test_bullet)

	# 1. Downward normal (underside/degenerate edge face)
	var downward_edge : bool = test_bullet._is_terrain_edge(null, Vector3(0, 0, 0), Vector3(0.0, -0.2, 0.0), null)
	check(downward_edge == true, "Downward-facing normal is identified as terrain edge/underside and suppressed")

	# 2. Outer perimeter boundary of map
	var boundary_edge : bool = test_bullet._is_terrain_edge(null, Vector3(39.0, 0, 0), Vector3.UP, null)
	check(boundary_edge == true, "Hit at outer map boundary is identified as terrain edge and suppressed")

	# 3. Flat normal in map interior
	var flat_ground : bool = test_bullet._is_terrain_edge(null, Vector3(0, 0, 0), Vector3.UP, null)
	check(flat_ground == false, "Flat ground normal within map bounds is NOT an edge")

	test_bullet.queue_free()

	# ----------------------------------------------------
	# [Test 3] Pistol Impact Decal Sizing (~0.13m realistic bullet hole)
	# ----------------------------------------------------
	print("\n[Test 3] Testing Pistol Decal Sizing...")
	_cleanup_laser_burns()

	# Default unscaled setup_impact (backward compatibility check)
	var burn_default : Node3D = burn_scene.instantiate() as Node3D
	root.add_child(burn_default)
	burn_default.call("setup_impact", Vector3.UP, Vector3.DOWN, null, false)
	await process_frame
	check(is_equal_approx(burn_default.scale.x, 1.0) and is_equal_approx(burn_default.scale.z, 1.0), "Default setup_impact retains 1.0 uniform scale")

	# Pistol scaled setup_impact (custom_scale = 0.32)
	var burn_pistol : Node3D = burn_scene.instantiate() as Node3D
	root.add_child(burn_pistol)
	burn_pistol.call("setup_impact", Vector3.UP, Vector3.DOWN, null, false, 0.32)
	await process_frame

	var mi : MeshInstance3D = burn_pistol.get_node_or_null("MeshInstance3D") as MeshInstance3D
	check(mi != null and is_equal_approx(mi.scale.x, 0.32) and is_equal_approx(mi.scale.z, 0.32), "Pistol decal mesh scaled down to ~0.32 (scale: %.2f x %.2f)" % [mi.scale.x if mi != null else 0.0, mi.scale.z if mi != null else 0.0])

	if mi != null and mi.mesh is PlaneMesh:
		var pm : PlaneMesh = mi.mesh as PlaneMesh
		var world_size : float = pm.size.x * mi.scale.x
		check(world_size > 0.10 and world_size < 0.20, "Pistol impact decal world size is realistic small bullet hole (%.3fm)" % world_size)

	burn_default.queue_free()
	burn_pistol.queue_free()

	# ----------------------------------------------------
	# [Test 4] Critical Chambered Round Weapon Glow (Yellow Conduit)
	# ----------------------------------------------------
	print("\n[Test 4] Testing Critical Shot Loaded Weapon Glow...")
	var pistol_model_scene : PackedScene = load("res://scenes/weapons/models/model_pistol.tscn")
	check(pistol_model_scene != null, "model_pistol.tscn loaded successfully")

	var pistol_model : WeaponModel = pistol_model_scene.instantiate() as WeaponModel
	root.add_child(pistol_model)
	await process_frame

	var conduit : MeshInstance3D = pistol_model.find_child("Conduit", true, false) as MeshInstance3D
	check(conduit != null, "Pistol model has Conduit mesh")

	# Set critical round loaded
	pistol_model.set_critical_glow(true, false)
	var crit_mat : StandardMaterial3D = conduit.material_override as StandardMaterial3D
	check(crit_mat != null, "Conduit has active material override for glow")
	if crit_mat != null:
		check(crit_mat.albedo_color.r > 0.8 and crit_mat.albedo_color.g > 0.7 and crit_mat.albedo_color.b < 0.3, "Chambered critical shot glows energetic yellow (R: %.2f, G: %.2f, B: %.2f)" % [crit_mat.albedo_color.r, crit_mat.albedo_color.g, crit_mat.albedo_color.b])

	# Discharge / standard round loaded
	pistol_model.set_critical_glow(false, false)
	var normal_mat : StandardMaterial3D = conduit.material_override as StandardMaterial3D
	if normal_mat != null:
		check(normal_mat.albedo_color.b > 0.7, "Discharged / normal shot returns to standard cyan glow (B: %.2f)" % normal_mat.albedo_color.b)

	pistol_model.queue_free()

	# ----------------------------------------------------
	# [Test 5] Enemy Snappy Disintegration Dust Animation
	# ----------------------------------------------------
	print("\n[Test 5] Testing Enemy Snappy Disintegration Dust...")
	var enemy_scene : PackedScene = load("res://scenes/enemy/enemy.tscn")
	check(enemy_scene != null, "enemy.tscn loaded successfully")

	var dying_enemy : CharacterBody3D = enemy_scene.instantiate() as CharacterBody3D
	root.add_child(dying_enemy)
	dying_enemy.global_position = Vector3(0.0, 0.0, 5.0)
	await process_frame

	check(dying_enemy.is_in_group("enemy"), "Spawned enemy is in 'enemy' group before death")

	# Trigger death
	dying_enemy._on_death()

	# Immediately upon death: removed from group and collisions disabled
	check(not dying_enemy.is_in_group("enemy"), "Enemy immediately removed from 'enemy' group upon death")
	check(dying_enemy.collision_layer == 0 and dying_enemy.collision_mask == 0, "Enemy collisions disabled immediately to avoid blocking")
	check(not dying_enemy.is_physics_processing(), "Enemy physics processing halted immediately")

	# Check that disintegration dust particles spawned in root
	var dust_found : bool = false
	for child in root.get_children():
		if child.name == "DisintegrationDust" and child is CPUParticles3D:
			dust_found = true
			var cp : CPUParticles3D = child as CPUParticles3D
			check(cp.one_shot and cp.explosiveness >= 0.9, "Disintegration particles configured as snappy one-shot burst")
			break
	check(dust_found, "Snappy DisintegrationDust CPUParticles3D spawned in scene")

	# Wait for disintegration animation to conclude and enemy to free
	for i in range(25):
		await process_frame

	check(not is_instance_valid(dying_enemy) or dying_enemy.is_queued_for_deletion(), "Enemy successfully completed disintegration and cleaned up")

	# ----------------------------------------------------
	# [Test 6] Sandbox UI Collapse & Minimal Aesthetic
	# ----------------------------------------------------
	print("\n[Test 6] Testing Sandbox UI Collapse & Aesthetics...")
	var dbg_scene : PackedScene = load("res://scenes/debug/health_debug.tscn")
	check(dbg_scene != null, "health_debug.tscn loaded successfully")

	var dbg_ui : CanvasLayer = dbg_scene.instantiate() as CanvasLayer
	root.add_child(dbg_ui)
	await process_frame

	var dbg_panel : PanelContainer = dbg_ui.get_node_or_null("DebugPanel") as PanelContainer
	var content_box : Control = dbg_ui.get_node_or_null("DebugPanel/VBoxContainer/ContentBox") as Control
	var toggle_btn : Button = dbg_ui.get_node_or_null("ToggleBar/ToggleButton") as Button

	check(dbg_panel != null, "DebugPanel exists")
	check(content_box != null, "ContentBox exists")
	check(toggle_btn != null, "ToggleButton exists")

	# Initial state: expanded
	check(dbg_panel.visible == true, "Initial state: DebugPanel is visible")
	check(content_box.visible == true, "Initial state: ContentBox is visible")

	# Collapse
	dbg_ui.call("_toggle_collapse")
	check(content_box.visible == false, "Collapsing hides ContentBox")
	check(dbg_panel.visible == false, "Collapsing completely hides DebugPanel (no lingering border or background box)")
	check("▼" in toggle_btn.text, "Toggle button indicator switches to collapsed icon (▼)")

	# Expand again
	dbg_ui.call("_toggle_collapse")
	check(content_box.visible == true, "Expanding restores ContentBox")
	check(dbg_panel.visible == true, "Expanding restores DebugPanel")
	check("▲" in toggle_btn.text, "Toggle button indicator switches to expanded icon (▲)")

	dbg_ui.queue_free()

	# ----------------------------------------------------
	# Summary
	# ----------------------------------------------------
	print("\n=======================================================")
	print("TEST RESULTS: %d Passed, %d Failed" % [passes, failures])
	print("=======================================================\n")
	quit(0 if failures == 0 else 1)
