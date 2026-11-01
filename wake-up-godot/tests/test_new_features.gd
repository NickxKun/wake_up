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
	print("=== RUNNING ADVANCED FEATURES TEST SUITE ===")
	call_deferred("_run_tests")

func _run_tests() -> void:
	await process_frame
	await process_frame

	# -------------------------------------------------------------------------
	# 1. Camera Tall Objects Clipping & Isometric Preservation
	# -------------------------------------------------------------------------
	print("\n[Test 1] Testing Camera Near-Clipping & Isometric Settings...")
	var main_scene : PackedScene = load("res://scenes/main.tscn")
	check(main_scene != null, "main.tscn loaded successfully")
	var main_inst : Node = main_scene.instantiate()
	root.add_child(main_inst)
	await process_frame

	var camera : Camera3D = main_inst.find_child("Camera3D", true, false) as Camera3D
	check(camera != null, "Camera3D found in scene")
	if camera != null:
		check(camera.projection == Camera3D.PROJECTION_ORTHOGONAL, "Camera projection is ORTHOGONAL (isometric)")
		check(camera.position.y > 20.0, "Camera pulled back along optical axis (Y: %.2f > 20m) preventing tall object clipping" % camera.position.y)
		check(camera.far >= 350.0, "Camera far plane covers world geometry (far: %.1f >= 350)" % camera.far)

	var dnc : Node = main_inst.find_child("DayNightCycle", true, false)
	check(dnc != null, "DayNightCycle found attached in main scene")

	# -------------------------------------------------------------------------
	# 2. Directional Dash Animation & Facing-Relative Thrusters
	# -------------------------------------------------------------------------
	print("\n[Test 2] Testing Directional Dash Animation & Facing...")
	var player : CharacterBody3D = main_inst.find_child("ProtoController", true, false) as CharacterBody3D
	check(player != null, "ProtoController player instance found in scene")
	player.add_to_group("player")

	var player_anim : Node = player.get_node_or_null("PlayerAnimation")
	check(player_anim != null, "PlayerAnimation component found on player")
	var particles : Node3D = player.get_node_or_null("DashParticles")
	check(particles != null, "DashParticles component found on player")

	# Forward dash (facing North, dashing North)
	if player_anim != null and player_anim.has_method("play_dash"):
		player_anim.call("play_dash", Vector3(0, 0, -1), Vector3(0, 0, -1), 1.0, 0.0)
		check(player_anim.get("_dash_rel_forward") == 1.0, "Forward dash records relative forward: 1.0")
		check(player_anim.get("_dash_rel_right") == 0.0, "Forward dash records relative right: 0.0")

	# Backward dash (facing North, dashing South)
	if player_anim != null and player_anim.has_method("play_dash"):
		player_anim.call("play_dash", Vector3(0, 0, 1), Vector3(0, 0, -1), -1.0, 0.0)
		check(player_anim.get("_dash_rel_forward") == -1.0, "Backward dash records relative forward: -1.0")
		check(player_anim.get("_dash_rel_right") == 0.0, "Backward dash records relative right: 0.0")

	# Left strafe dash (facing North, dashing West)
	if player_anim != null and player_anim.has_method("play_dash"):
		player_anim.call("play_dash", Vector3(-1, 0, 0), Vector3(0, 0, -1), 0.0, -1.0)
		check(player_anim.get("_dash_rel_right") == -1.0, "Left strafe dash records relative right: -1.0")

	# Discrete orthogonal Reaction Control System (RCS) thrusters check
	if particles != null and particles.has_method("start_dash_directional"):
		# Test 1: Straight Forward Dash -> Rear nozzles fire, Front & Side do not
		particles.call("start_dash_directional", Vector3(0, 0, 1), Vector3(0, 0, 1), 1.0, 0.0, 0.22)
		var rear_p : CPUParticles3D = particles.get_node_or_null("CPUParticles3D") as CPUParticles3D
		var front_p : CPUParticles3D = particles.get_node_or_null("FrontParticles_Left") as CPUParticles3D
		var side_l : CPUParticles3D = particles.get_node_or_null("SideParticles_Left") as CPUParticles3D
		var side_r : CPUParticles3D = particles.get_node_or_null("SideParticles_Right") as CPUParticles3D
		check(rear_p != null and rear_p.emitting == true, "Straight forward dash activates rear backpack thrusters")
		check(front_p != null and front_p.emitting == false, "Straight forward dash keeps front chest thrusters off")
		check(side_l != null and side_l.emitting == false, "Straight forward dash keeps side thrusters off")

		# Test 2: Diagonal Forward-Right Dash -> Rear nozzle AND Left side 90° nozzle fire together
		particles.call("start_dash_directional", Vector3(1, 0, 1).normalized(), Vector3(0, 0, 1), 0.7, 0.7, 0.22)
		check(rear_p != null and rear_p.emitting == true, "Diagonal forward dash fires rear thruster for forward propulsion")
		check(side_l != null and side_l.emitting == true, "Diagonal forward-right dash fires 90-degree lateral side thruster simultaneously")
		check(front_p != null and front_p.emitting == false, "Diagonal forward dash does not fire front thrusters")

		# Test 3: Backward Dash -> Front chest nozzles fire, rear does not
		particles.call("start_dash_directional", Vector3(0, 0, -1), Vector3(0, 0, 1), -1.0, 0.0, 0.22)
		check(front_p != null and front_p.emitting == true, "Backward dash activates front chest thrusters")
		check(rear_p != null and rear_p.emitting == false, "Backward dash turns off rear backpack thrusters")

		# Test 4: Diagonal Backward-Left Dash -> Front nozzles AND Right side 90° nozzle fire together
		particles.call("start_dash_directional", Vector3(-1, 0, -1).normalized(), Vector3(0, 0, 1), -0.7, -0.7, 0.22)
		check(front_p != null and front_p.emitting == true, "Diagonal backward dash fires front chest thrusters")
		check(side_r != null and side_r.emitting == true, "Diagonal backward-left dash fires 90-degree lateral side thruster")

		particles.call("stop_dash")
		check(rear_p.emitting == false and front_p.emitting == false and side_l.emitting == false and side_r.emitting == false, "Stopping dash shuts off all RCS thruster nozzles immediately")

	# -------------------------------------------------------------------------
	# 3. Sniper Enhanced Range & Visuals
	# -------------------------------------------------------------------------
	print("\n[Test 3] Testing Sniper Enhanced Range...")
	var combat : Node = player.get_node_or_null("PlayerCombat")
	check(combat != null, "PlayerCombat found on player")
	if combat != null:
		combat.call("equip_special_weapon", 2) # SNIPER
		check(combat.get("current_weapon") == 2, "Sniper Rifle equipped in combat")
		var laser : MeshInstance3D = combat.get("_laser_sight") as MeshInstance3D
		check(laser != null, "Sniper targeting laser sight initialized")
		if laser != null:
			check(laser.visible == true, "Sniper laser sight is active and visible when holding Sniper")

		# Fire sniper bullet
		combat.call("_fire", true)
		var sniper_bullet : Area3D = null
		for c in player.get_parent().get_children():
			if c.name.begins_with("Bullet") or (c is Area3D and not (c is CharacterBody3D)):
				sniper_bullet = c as Area3D
		check(sniper_bullet != null, "Sniper projectile spawned")
		if sniper_bullet != null:
			check(sniper_bullet.get("speed") >= 60.0, "Sniper bullet has enhanced speed (>= 60 m/s, actual: %.1f)" % sniper_bullet.get("speed"))
			check(sniper_bullet.get("lifetime") >= 2.0, "Sniper bullet has extended lifetime (>= 2.0s, actual: %.1f)" % sniper_bullet.get("lifetime"))
		await process_frame

	# -------------------------------------------------------------------------
	# 4. Screen Shake Autoload
	# -------------------------------------------------------------------------
	print("\n[Test 4] Testing Screen Shake Autoload System...")
	var screen_shake : Node = root.get_node_or_null("ScreenShake")
	check(screen_shake != null, "ScreenShake autoload registered in project tree")
	if screen_shake != null:
		check(screen_shake.get("trauma") == 0.0, "Initial screen shake trauma is 0.0")
		screen_shake.call("shake", 0.75)
		check(is_equal_approx(screen_shake.get("trauma"), 0.75), "add_trauma/shake sets trauma to 0.75")
		screen_shake._process(0.1)
		check(screen_shake.get("trauma") < 0.75, "Trauma decays smoothly over time (actual: %.2f)" % screen_shake.get("trauma"))

	# -------------------------------------------------------------------------
	# 5. Rocket Explosion & Thick Smoke Cloud
	# -------------------------------------------------------------------------
	print("\n[Test 5] Testing Rocket Explosion & Billowing Smoke Cloud...")
	var exp_scene : PackedScene = load("res://scenes/projectiles/explosion_effect.tscn")
	check(exp_scene != null, "explosion_effect.tscn loaded successfully")
	var exp_fx : Node3D = exp_scene.instantiate()
	root.add_child(exp_fx)
	await process_frame

	var smoke : CPUParticles3D = exp_fx.find_child("SmokeCloud", true, false) as CPUParticles3D
	check(smoke != null, "ExplosionEffect has SmokeCloud CPUParticles3D")
	if smoke != null:
		check(smoke.amount >= 30, "Smoke cloud has thick particle density (amount: %d >= 30)" % smoke.amount)
		check(smoke.lifetime >= 1.0, "Smoke cloud lingers billowing (lifetime: %.2fs >= 1.0s)" % smoke.lifetime)
		check(smoke.mesh is SphereMesh, "Smoke puffs use 3D SphereMesh geometry")

	var fireball : MeshInstance3D = exp_fx.find_child("Fireball", true, false) as MeshInstance3D
	check(fireball != null, "ExplosionEffect has expanding fireball core")

	# -------------------------------------------------------------------------
	# 6. Bullet Impact Scorch Decal That Fades
	# -------------------------------------------------------------------------
	print("\n[Test 6] Testing Impact Scorch Decal That Fades Over Time...")
	var burn_scene : PackedScene = load("res://scenes/projectiles/laser_burn.tscn")
	check(burn_scene != null, "laser_burn.tscn loads successfully")
	var burn : Node3D = burn_scene.instantiate()
	root.add_child(burn)
	await process_frame

	var mesh_inst : MeshInstance3D = burn.get_node_or_null("MeshInstance3D") as MeshInstance3D
	check(mesh_inst != null, "Scorch decal has MeshInstance3D")
	if mesh_inst != null:
		var mat : Material = mesh_inst.get_active_material(0)
		check(mat is StandardMaterial3D, "Scorch decal has StandardMaterial3D override")
		if mat is StandardMaterial3D:
			check((mat as StandardMaterial3D).render_priority >= 1, "Scorch decal render_priority prevents z-fighting on walls")

	# -------------------------------------------------------------------------
	# 7. Car Auto-Eject on Impending Explosion & Screen Shake
	# -------------------------------------------------------------------------
	print("\n[Test 7] Testing Car Auto-Eject & Destruction Screen Shake...")
	var rover_scene : PackedScene = load("res://scenes/vehicles/rover.tscn")
	check(rover_scene != null, "rover.tscn loaded successfully")
	var rover : CharacterBody3D = rover_scene.instantiate()
	root.add_child(rover)
	await process_frame

	rover.call("board_vehicle", player)
	check(rover.get("is_occupied") == true, "Astronaut successfully boarded rover")

	# Deplete health -> should auto-eject driver immediately
	var rover_hc : HealthComponent = rover.get_node_or_null("HealthComponent") as HealthComponent
	check(rover_hc != null, "Rover has HealthComponent")
	if rover_hc != null:
		rover_hc.decrease_health(100) # lethal
		await process_frame
		check(rover.get("is_occupied") == false, "Driver auto-ejected when vehicle reached 0 HP")
		check(rover.get("is_destroyed") == true, "Vehicle marked destroyed")

	# -------------------------------------------------------------------------
	# 8. Day / Night Cycle System
	# -------------------------------------------------------------------------
	print("\n[Test 8] Testing Day / Night Cycle Transitions...")
	var dn_cycle := DayNightCycle.new()
	root.add_child(dn_cycle)
	await process_frame

	dn_cycle.set_time_preset("noon")
	check(is_equal_approx(dn_cycle.time_of_day, 0.5), "Noon preset sets time_of_day to 0.5")
	dn_cycle.set_time_preset("night")
	check(is_equal_approx(dn_cycle.time_of_day, 0.96), "Night preset sets time_of_day to 0.96")
	dn_cycle.set_time_preset("morning")
	check(is_equal_approx(dn_cycle.time_of_day, 0.26), "Morning preset sets time_of_day to 0.26")

	# -------------------------------------------------------------------------
	# 9. Collapsible Sandbox UI, Cheats & Weapon Selector
	# -------------------------------------------------------------------------
	print("\n[Test 9] Testing Collapsible Sandbox UI & Cheats...")
	var debug_scene : PackedScene = load("res://scenes/debug/health_debug.tscn")
	check(debug_scene != null, "health_debug.tscn loaded successfully")
	var debug_ui : CanvasLayer = debug_scene.instantiate()
	debug_ui.set("health_component", player.get_node_or_null("HealthComponent"))
	root.add_child(debug_ui)
	await process_frame

	var toggle_btn : Button = debug_ui.get_node_or_null("ToggleBar/ToggleButton") as Button
	var content : Control = debug_ui.get_node_or_null("DebugPanel/VBoxContainer/ContentBox") as Control
	check(toggle_btn != null, "Sandbox UI has collapsible ToggleButton")
	check(content != null, "Sandbox UI has ContentBox")

	# Test collapse toggle
	if toggle_btn != null:
		toggle_btn.pressed.emit()
		check(content.visible == false, "Clicking toggle collapses ContentBox cleanly")
		toggle_btn.pressed.emit()
		check(content.visible == true, "Clicking toggle again expands ContentBox")

	# Test Godmode Cheat
	var godmode_btn : Button = debug_ui.find_child("GodmodeBtn", true, false) as Button
	check(godmode_btn != null, "Godmode cheat button found")
	if godmode_btn != null:
		godmode_btn.pressed.emit()
		var p_hc : HealthComponent = player.get_node_or_null("HealthComponent") as HealthComponent
		check(p_hc != null and p_hc.is_invulnerable == true, "Godmode toggle makes player invulnerable to damage")

	# Test Unlimited Stamina Cheat
	var stam_btn : Button = debug_ui.find_child("StaminaBtn", true, false) as Button
	check(stam_btn != null, "Stamina cheat button found")
	if stam_btn != null:
		stam_btn.pressed.emit()
		check(player.get("infinite_stamina") == true, "Unlimited stamina toggle activates infinite stamina")

	# Test Unlimited Ammo Cheat
	var ammo_btn : Button = debug_ui.find_child("AmmoBtn", true, false) as Button
	check(ammo_btn != null, "Ammo cheat button found")
	if ammo_btn != null:
		ammo_btn.pressed.emit()
		check(combat.get("infinite_ammo") == true, "Unlimited ammo toggle activates infinite ammo")

	# Test In-Sandbox Map Switcher Buttons
	var map_btn0 : Button = debug_ui.find_child("Map0Btn", true, false) as Button
	var map_btn1 : Button = debug_ui.find_child("Map1Btn", true, false) as Button
	var map_btn2 : Button = debug_ui.find_child("Map2Btn", true, false) as Button
	check(map_btn0 != null and map_btn1 != null and map_btn2 != null, "Sandbox UI has in-game map switcher buttons (Canyon, Base, Dock)")

	# Test Vehicle Spawner in Sandbox
	var spawn_v_btn : Button = debug_ui.find_child("SpawnVehicleBtn", true, false) as Button
	check(spawn_v_btn != null, "Sandbox UI has SpawnVehicleBtn")

	print("\n=======================================================")
	print("NEW FEATURES RESULTS: %d Passed, %d Failed" % [passes, failures])
	print("=======================================================")
	quit(0 if failures == 0 else 1)
