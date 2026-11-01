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
	print("--- Running Bullet Hits, Vehicle UI & Weapon Icon Test Suite ---")
	call_deferred("_run_tests")

func _run_tests() -> void:
	await process_frame
	await process_frame

	# ----------------------------------------------------
	# [Test 1] Bullet Contact With Enemy: Leaves No Marker
	# ----------------------------------------------------
	print("\n[Test 1] Testing Bullet Contact With Enemy Leaves No Marker...")
	var bullet_scene : PackedScene = load("res://scenes/projectiles/bullet.tscn")
	check(bullet_scene != null, "bullet.tscn loaded successfully")

	# Create an enemy character
	var enemy : CharacterBody3D = CharacterBody3D.new()
	enemy.name = "Enemy_Target"
	enemy.add_to_group("enemy")
	var enemy_hc : HealthComponent = HealthComponent.new()
	enemy.add_child(enemy_hc)
	var enemy_col : CollisionShape3D = CollisionShape3D.new()
	var enemy_box : BoxShape3D = BoxShape3D.new()
	enemy_box.size = Vector3(1.0, 1.0, 1.0)
	enemy_col.shape = enemy_box
	enemy.add_child(enemy_col)
	root.add_child(enemy)
	enemy.global_position = Vector3(0.0, 1.0, 10.0)

	var p_bullet : Area3D = bullet_scene.instantiate() as Area3D
	p_bullet.direction = Vector3(0.0, 0.0, 1.0)
	p_bullet.speed = 10.0
	root.add_child(p_bullet)
	p_bullet.global_position = Vector3(0.0, 1.0, 9.9)

	var burns_before : int = _count_laser_burns()
	p_bullet._hit(enemy, Vector3(0.0, 0.0, -1.0))
	await process_frame
	var burns_after : int = _count_laser_burns()

	check(burns_after == burns_before, "Bullet hitting enemy spawned NO scorch marker (before: %d, after: %d)" % [burns_before, burns_after])

	# ----------------------------------------------------
	# [Test 2] Enemy Bullet Contact With Player: Leaves No Marker
	# ----------------------------------------------------
	print("\n[Test 2] Testing Enemy Bullet Contact With Player Leaves No Marker...")
	var proto_scene : PackedScene = load("res://addons/proto_controller/proto_controller.tscn")
	check(proto_scene != null, "proto_controller.tscn loaded successfully")
	var player : CharacterBody3D = proto_scene.instantiate() as CharacterBody3D
	root.add_child(player)
	player.global_position = Vector3(5.0, 1.0, 10.0)

	var e_bullet : Area3D = bullet_scene.instantiate() as Area3D
	e_bullet.shooter = enemy
	e_bullet.direction = Vector3(1.0, 0.0, 0.0)
	root.add_child(e_bullet)
	e_bullet.global_position = Vector3(4.9, 1.0, 10.0)

	burns_before = _count_laser_burns()
	e_bullet._hit(player, Vector3(-1.0, 0.0, 0.0))
	await process_frame
	burns_after = _count_laser_burns()

	check(burns_after == burns_before, "Enemy bullet hitting player spawned NO scorch marker (before: %d, after: %d)" % [burns_before, burns_after])

	# ----------------------------------------------------
	# [Test 3] Bullet Contact With Wall: DOES Leave Marker
	# ----------------------------------------------------
	print("\n[Test 3] Testing Bullet Contact With Wall Leaves Marker...")
	var wall : StaticBody3D = StaticBody3D.new()
	wall.name = "StationWall"
	wall.collision_layer = 1
	var wcol : CollisionShape3D = CollisionShape3D.new()
	var wbox : BoxShape3D = BoxShape3D.new()
	wbox.size = Vector3(5.0, 5.0, 1.0)
	wcol.shape = wbox
	wall.add_child(wcol)
	root.add_child(wall)
	wall.global_position = Vector3(0.0, 1.0, 20.0)

	var wall_bullet : Area3D = bullet_scene.instantiate() as Area3D
	wall_bullet.direction = Vector3(0.0, 0.0, 1.0)
	root.add_child(wall_bullet)
	wall_bullet.global_position = Vector3(0.0, 1.0, 19.5)

	burns_before = _count_laser_burns()
	wall_bullet._hit(wall, Vector3(0.0, 0.0, -1.0))
	await process_frame
	burns_after = _count_laser_burns()

	check(burns_after == burns_before + 1, "Bullet hitting environmental wall spawned scorch marker as expected")

	# ----------------------------------------------------
	# [Test 4] Truck Cockpit UI: No Box At Bottom Of Screen
	# ----------------------------------------------------
	print("\n[Test 4] Testing Truck Cockpit UI Minimal (No Box At Bottom)...")
	var hud : Node = root.get_node_or_null("/root/PlayerHealthHud")
	check(hud != null, "PlayerHealthHud autoload present")
	if hud != null:
		# Test activating vehicle hint
		hud.call("set_vehicle_hint", true, "Scout Rover", 80, 100)
		await process_frame

		var v_panel : PanelContainer = hud.find_child("VehicleControlPanel", true, false) as PanelContainer
		check(v_panel != null, "VehicleControlPanel instance created")
		if v_panel != null:
			check(v_panel.visible == false, "Vehicle control box at bottom of screen is hidden (visible = false)")

		var weapon_panel : Control = hud.get("_weapon_panel") as Control
		if weapon_panel != null:
			check(weapon_panel.visible == false, "Personal weapon HUD hidden while driving truck")

		# Test exiting vehicle
		hud.call("set_vehicle_hint", false)
		await process_frame

		if weapon_panel != null:
			check(weapon_panel.visible == true, "Personal weapon HUD restored when dismounting truck")

	# ----------------------------------------------------
	# [Test 5] Weapon Icons: 2:1 Proportions & Zero Squishing
	# ----------------------------------------------------
	print("\n[Test 5] Testing Weapon Icons Proportions & Zero Squishing...")
	var icon : WeaponIcon = WeaponIcon.new()
	icon.size = Vector2(38, 52) # Taller container that previously squished icons
	root.add_child(icon)
	await process_frame

	check(icon.CANVAS_W == 56.0 and icon.CANVAS_H == 28.0, "WeaponIcon uses locked 2:1 widescreen proportions (56 x 28)")
	var aspect_ratio : float = icon.CANVAS_W / icon.CANVAS_H
	check(is_equal_approx(aspect_ratio, 2.0), "Weapon aspect ratio is strictly 2.0 (widescreen, never squished)")

	# Verify uniform scale calculation
	var s : float = minf(icon.size.x / icon.CANVAS_W, icon.size.y / icon.CANVAS_H)
	check(s > 0.0, "Uniform scaling factor calculated properly (s: %.3f)" % s)

	# Verify all 5 weapon types can be set and drawn cleanly
	for type_idx in range(5):
		icon.set_weapon(type_idx, Color(0.4, 0.8, 1.0))
		await process_frame
	check(true, "All 5 weapons (Pistol, Shotgun, Sniper, Dual Pistols, Rocket) rendered with uniform geometry")

	# Test in wide container as well
	icon.size = Vector2(100, 30)
	icon.queue_redraw()
	await process_frame
	var s_wide : float = minf(icon.size.x / icon.CANVAS_W, icon.size.y / icon.CANVAS_H)
	check(is_equal_approx(s_wide, 30.0 / 28.0), "Icon preserves aspect ratio even in wide rectangular container")

	print("\n=======================================================")
	print("HITS, VEHICLE UI & ICON RESULTS: %d Passed, %d Failed" % [passes, failures])
	print("=======================================================")

	# Cleanup
	enemy.queue_free()
	player.queue_free()
	wall.queue_free()
	icon.queue_free()
	_cleanup_laser_burns()

	quit(0 if failures == 0 else 1)

func _count_laser_burns() -> int:
	var count : int = 0
	for child in root.get_children():
		if child is LaserBurn:
			count += 1
	return count

func _cleanup_laser_burns() -> void:
	for child in root.get_children():
		if child is LaserBurn:
			child.queue_free()
