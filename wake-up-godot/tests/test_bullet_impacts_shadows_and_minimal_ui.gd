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
	print("--- Running Impact Decals, Shadows & Minimal UI Test Suite ---")
	call_deferred("_run_tests")

func _run_tests() -> void:
	await process_frame
	await process_frame

	# ----------------------------------------------------
	# [Test 1] Bullet Impact Decals: Pure Normal Sizing (No Odd Stretching)
	# ----------------------------------------------------
	print("\n[Test 1] Testing Bullet Impact Decals: Normal Sizing & No Odd Stretching...")
	var burn_scene : PackedScene = load("res://scenes/projectiles/laser_burn.tscn")
	check(burn_scene != null, "laser_burn.tscn loaded successfully")

	# Head-on impact (direct vertical shot onto floor)
	var burn_headon : Node3D = burn_scene.instantiate() as Node3D
	root.add_child(burn_headon)
	var floor_normal : Vector3 = Vector3.UP
	var shot_vertical : Vector3 = Vector3.DOWN
	burn_headon.call("setup_impact", floor_normal, shot_vertical, null, false)
	await process_frame
	check(is_equal_approx(burn_headon.scale.x, 1.0) and is_equal_approx(burn_headon.scale.z, 1.0), "Head-on perpendicular shot leaves uniform circular mark (1.0 x 1.0)")

	# Glancing oblique angle shot (e.g. shooting across floor at 15 degree angle)
	var burn_glancing : Node3D = burn_scene.instantiate() as Node3D
	root.add_child(burn_glancing)
	var shot_glancing : Vector3 = Vector3(1.0, -0.25, 0.0).normalized()
	burn_glancing.call("setup_impact", floor_normal, shot_glancing, null, false)
	await process_frame
	check(is_equal_approx(burn_glancing.scale.x, 1.0) and is_equal_approx(burn_glancing.scale.z, 1.0), "Glancing shot has ZERO odd stretching, maintaining uniform circular normal size (1.0 x 1.0)")
	check(is_equal_approx(burn_glancing.scale.x, burn_glancing.scale.z), "Mark scale is perfectly symmetric (scale.x == scale.z)")

	# Verify orientation along surface normal
	var decal_up : Vector3 = burn_glancing.global_transform.basis.y
	check(decal_up.dot(floor_normal) > 0.99, "Decal normal is aligned perpendicular along contact surface (dot: %.2f)" % decal_up.dot(floor_normal))

	# ----------------------------------------------------
	# [Test 2] Bullet Impact Decals: Surface Material Adaptation
	# ----------------------------------------------------
	print("\n[Test 2] Testing Bullet Impact Decals: Surface Adaptation...")
	var ground_node : StaticBody3D = StaticBody3D.new()
	ground_node.name = "GroundBase"
	root.add_child(ground_node)

	var metal_node : StaticBody3D = StaticBody3D.new()
	metal_node.name = "StationWall_Metal"
	root.add_child(metal_node)

	var stone_node : StaticBody3D = StaticBody3D.new()
	stone_node.name = "Rock_Boulder_Stone"
	root.add_child(stone_node)

	var burn_ground : Node3D = burn_scene.instantiate() as Node3D
	root.add_child(burn_ground)
	burn_ground.call("setup_impact", floor_normal, shot_vertical, ground_node, false)
	check(burn_ground.get("surface_type") == 0, "Impact on GroundBase identifies GROUND surface (0)")

	var burn_metal : Node3D = burn_scene.instantiate() as Node3D
	root.add_child(burn_metal)
	burn_metal.call("setup_impact", Vector3.LEFT, Vector3.RIGHT, metal_node, false)
	check(burn_metal.get("surface_type") == 1, "Impact on StationWall identifies METAL surface (1)")

	var burn_stone : Node3D = burn_scene.instantiate() as Node3D
	root.add_child(burn_stone)
	burn_stone.call("setup_impact", floor_normal, shot_vertical, stone_node, false)
	check(burn_stone.get("surface_type") == 2, "Impact on Boulder identifies STONE surface (2)")

	# Check render priority and material override
	var mi : MeshInstance3D = burn_metal.get_node_or_null("MeshInstance3D") as MeshInstance3D
	check(mi != null and mi.material_override is StandardMaterial3D, "Scorch decal applies unique StandardMaterial3D override")
	check((mi.material_override as StandardMaterial3D).render_priority >= 2, "Material render_priority prevents z-fighting")

	# ----------------------------------------------------
	# [Test 3] Sharp Shadows & Anti-Banding Configuration
	# ----------------------------------------------------
	print("\n[Test 3] Testing Sharp Shadows & Anti-Banding Configuration...")
	var main_scene : PackedScene = load("res://scenes/main.tscn")
	check(main_scene != null, "main.tscn loaded successfully")
	var main_inst : Node = main_scene.instantiate()
	root.add_child(main_inst)
	await process_frame

	var sun : DirectionalLight3D = main_inst.find_child("DirectionalLight3D", true, false) as DirectionalLight3D
	check(sun != null, "DirectionalLight3D found in main scene")
	if sun != null:
		check(sun.shadow_enabled == true, "Shadows enabled on DirectionalLight3D")
		check(sun.shadow_blur <= 1.0, "Shadow blur is sharp and anti-banded (blur: %.2f <= 1.0)" % sun.shadow_blur)
		check(sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS, "Directional shadow mode is SHADOW_PARALLEL_4_SPLITS (4 cascades preventing acne)")
		check(sun.directional_shadow_blend_splits == true, "Split blending enabled to prevent seam banding")
		check(sun.shadow_bias >= 0.03, "Shadow bias prevents self-shadow acne banding (bias: %.3f >= 0.03)" % sun.shadow_bias)

	var dnc : Node = main_inst.find_child("DayNightCycle", true, false)
	check(dnc != null, "DayNightCycle found in main scene")
	if dnc != null and sun != null:
		# Check sharp configuration at noon
		dnc.call("set_time_preset", "noon")
		dnc.call("_update_lighting", 0.0)
		check(sun.shadow_blur <= 1.0, "Noon sun retains clean shadow blur (%.2f)" % sun.shadow_blur)

		# Check that night moonlight shines from above to cast downward shadows
		dnc.call("set_time_preset", "night")
		dnc.call("_update_lighting", 0.0)
		# Light pitch should be pointing downward (negative pitch) so it comes from sky
		check(sun.rotation.x < 0.0, "Moonlight points downward from sky at night (pitch: %.2f < 0.0)" % sun.rotation.x)

	# ----------------------------------------------------
	# [Test 4] Car Healthbar: Pure Indicator (No Numbers)
	# ----------------------------------------------------
	print("\n[Test 4] Testing Car Healthbar: Pure Indicator Without Numbers...")
	var vhb_scene : PackedScene = load("res://scenes/vehicles/vehicle_health_bar.tscn")
	check(vhb_scene != null, "vehicle_health_bar.tscn loaded successfully")
	var vhb : Node = vhb_scene.instantiate()
	root.add_child(vhb)
	await process_frame

	# 3D floating bar: Label must be invisible / empty
	var floating_label : Label = vhb.get_node_or_null("SubViewport/ProgressBar/Label") as Label
	var is_label_clean : bool = (floating_label == null) or (floating_label.visible == false) or (floating_label.text == "")
	check(is_label_clean, "3D floating vehicle health bar has no numeric text (pure indicator)")

	var floating_pbar : ProgressBar = vhb.get_node_or_null("SubViewport/ProgressBar") as ProgressBar
	check(floating_pbar != null, "3D floating health indicator bar exists")
	check(floating_pbar.show_percentage == false, "Percentage text disabled on 3D floating health bar")

	# Cockpit 2D HUD: set_vehicle_hint & update_vehicle_health
	var hud : Node = root.get_node_or_null("/root/PlayerHealthHud")
	check(hud != null, "PlayerHealthHud autoload present")
	if hud != null:
		hud.call("set_vehicle_hint", true, "Scout Rover", 75, 100)
		await process_frame

		var cockpit_readout : Label = hud.find_child("VehicleHealthReadout", true, false) as Label
		var is_cockpit_clean : bool = (cockpit_readout == null) or (cockpit_readout.visible == false) or (cockpit_readout.text == "")
		check(is_cockpit_clean, "Cockpit 2D vehicle health bar has no numeric readout (pure indicator)")

		var cockpit_bar : ProgressBar = hud.find_child("VehicleHullBar", true, false) as ProgressBar
		check(cockpit_bar != null, "Cockpit vehicle hull indicator bar exists")
		check(cockpit_bar.show_percentage == false, "Percentage text disabled on cockpit hull bar")

		hud.call("set_vehicle_hint", false)
		await process_frame

	# ----------------------------------------------------
	# [Test 5] Minimal Sandbox Tools UI
	# ----------------------------------------------------
	print("\n[Test 5] Testing Minimal Sandbox Tools UI...")
	var dbg_scene : PackedScene = load("res://scenes/debug/health_debug.tscn")
	check(dbg_scene != null, "health_debug.tscn loaded successfully")
	var dbg : CanvasLayer = dbg_scene.instantiate() as CanvasLayer
	root.add_child(dbg)
	await process_frame

	var panel : PanelContainer = dbg.get_node_or_null("DebugPanel") as PanelContainer
	check(panel != null, "Sandbox UI has DebugPanel")
	if panel != null:
		var panel_style : StyleBox = panel.get_theme_stylebox("panel")
		check(panel_style is StyleBoxFlat, "DebugPanel uses StyleBoxFlat")
		if panel_style is StyleBoxFlat:
			check((panel_style as StyleBoxFlat).bg_color.a < 0.85, "DebugPanel uses clean translucent glass backdrop (alpha: %.2f < 0.85)" % (panel_style as StyleBoxFlat).bg_color.a)

	var toggle : Button = dbg.get_node_or_null("ToggleBar/ToggleButton") as Button
	check(toggle != null, "Sandbox UI has minimal ToggleButton")
	var content : Control = dbg.get_node_or_null("DebugPanel/VBoxContainer/ContentBox") as Control
	check(content != null, "Sandbox UI has ContentBox")

	if toggle != null and content != null:
		toggle.pressed.emit()
		check(content.visible == false, "Clicking toggle collapses ContentBox cleanly")
		toggle.pressed.emit()
		check(content.visible == true, "Clicking toggle expands ContentBox cleanly")

	# ----------------------------------------------------
	# [Test 6] Rocket Launcher Dense Smoke Cloud & Screen Shake on Large Impacts
	# ----------------------------------------------------
	print("\n[Test 6] Testing Rocket Impact Dense Smoke Cloud & Large Impact Screen Shake...")
	var exp_scene : PackedScene = load("res://scenes/projectiles/explosion_effect.tscn")
	check(exp_scene != null, "explosion_effect.tscn loaded successfully")
	var exp_inst : Node3D = exp_scene.instantiate() as Node3D
	root.add_child(exp_inst)
	await process_frame

	var smoke : CPUParticles3D = exp_inst.get_node_or_null("SmokeCloud") as CPUParticles3D
	check(smoke != null, "Explosion has SmokeCloud particles")
	if smoke != null:
		check(smoke.amount >= 60, "Rocket explosion has dense smoke particle cloud (amount: %d >= 60)" % smoke.amount)
		check(smoke.mesh is SphereMesh and (smoke.mesh as SphereMesh).radius >= 0.4, "Smoke puffs are thick and voluminous (radius: %.2f >= 0.4)" % (smoke.mesh as SphereMesh).radius)
		check(smoke.lifetime >= 1.5, "Smoke cloud lingers and billows (lifetime: %.2fs >= 1.5s)" % smoke.lifetime)

	var screen_shake : Node = root.get_node_or_null("/root/ScreenShake")
	check(screen_shake != null, "ScreenShake autoload registered")
	if screen_shake != null:
		screen_shake.call("shake", 0.85)
		check(screen_shake.get("trauma") >= 0.85, "Large impact sets heavy screen shake trauma (>= 0.85, actual: %.2f)" % screen_shake.get("trauma"))

		# Advance frame and verify camera is found and offset
		await process_frame
		var cam : Camera3D = screen_shake.call("_get_camera")
		check(cam != null, "ScreenShake successfully binds game Camera3D across subviewports")
		if cam != null:
			check(absf(cam.h_offset) > 0.0 or absf(cam.v_offset) > 0.0 or absf(cam.rotation.z) > 0.0, "Camera has active concussive jolt on large impact")

	print("\n=======================================================")
	print("IMPACTS, SHADOWS & UI RESULTS: %d Passed, %d Failed" % [passes, failures])
	print("=======================================================")

	# Cleanup
	burn_headon.queue_free()
	burn_glancing.queue_free()
	burn_ground.queue_free()
	burn_metal.queue_free()
	burn_stone.queue_free()
	ground_node.queue_free()
	metal_node.queue_free()
	stone_node.queue_free()
	main_inst.queue_free()
	vhb.queue_free()
	dbg.queue_free()
	exp_inst.queue_free()

	quit(0 if failures == 0 else 1)
