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
	print("--- Running Dash Overhaul, Pixel Art Lighting & Selection UI Test Suite ---")
	call_deferred("_run_tests")

func _run_tests() -> void:
	await process_frame
	await process_frame

	# =========================================================================
	# [Test 1] Dash Orientation: Face Dash Direction & Turn Back on Completion
	# =========================================================================
	print("\n[Test 1] Testing Dash Orientation & Facing Snap-back...")
	var player_scene : PackedScene = load("res://addons/proto_controller/proto_controller.tscn")
	check(player_scene != null, "proto_controller.tscn loaded")

	var player = player_scene.instantiate()
	root.add_child(player)

	var combat_script = preload("res://scenes/player/player_combat.gd")
	var combat = combat_script.new()
	combat.name = "PlayerCombat"
	player.add_child(combat)

	await process_frame
	await process_frame

	var hc = player.get_node_or_null("HealthComponent")
	check(combat != null, "PlayerCombat found")
	check(hc != null, "HealthComponent found")

	# Set initial facing orientation (e.g. 0.75 rad)
	var initial_facing : float = 0.75
	player.rotation.y = initial_facing

	# Set dash direction: East (+X) -> angle is PI/2
	var east_dash : Vector3 = Vector3(1.0, 0.0, 0.0)
	var expected_dash_yaw : float = atan2(east_dash.x, east_dash.z) # PI/2

	# Trigger dash execution toward East (+X)
	player._perform_dash(east_dash)

	check(player.is_dashing == true, "Player is_dashing is true after dash trigger")
	check(is_equal_approx(player._pre_dash_facing, initial_facing), "Pre-dash facing recorded correctly (0.75 rad)")
	check(is_equal_approx(player.rotation.y, expected_dash_yaw), "Player model immediately faces dash direction (PI/2 rad)")

	# Advance physics while dashing: orientation remains locked to dash direction
	player._physics_process(player.dash_duration * 0.5)
	check(player.is_dashing == true, "Player still dashing halfway through duration")
	check(is_equal_approx(player.rotation.y, expected_dash_yaw), "Player continues facing dash direction mid-dash")

	# Advance physics until dash duration expires
	player._physics_process(player.dash_duration * 0.6)
	check(player.is_dashing == false, "Player is_dashing is false when duration completes")
	check(is_equal_approx(player.rotation.y, initial_facing), "Player orientation turns back to initial pre-dash facing (0.75 rad)")

	# =========================================================================
	# [Test 2] Dash i-Frames: Invulnerability During Dash, Vulnerable After
	# =========================================================================
	print("\n[Test 2] Testing Dash i-Frames (Invulnerability)...")
	hc.health = 100
	hc.shield = 0.0 # Clear shield so health damage is direct

	# Trigger dash
	player._dash_direction = Vector3.FORWARD
	player._perform_dash()
	check(player.is_dashing == true, "Dash active for i-frame test")
	check(hc.is_invulnerable == true, "HealthComponent.is_invulnerable is TRUE during dash")

	# Attempt to inflict damage while dashing
	var damage_applied : int = hc.decrease_health(30)
	check(damage_applied == 0, "Zero damage applied while dashing (invulnerable)")
	check(hc.health == 100, "Health remained at 100 during dash")

	# Complete dash
	player._physics_process(player.dash_duration + 0.05)
	check(player.is_dashing == false, "Dash complete")
	check(hc.is_invulnerable == false, "HealthComponent.is_invulnerable restored to FALSE after dash")

	# Inflict damage when not dashing
	var post_damage : int = hc.decrease_health(25)
	check(post_damage == 25, "Damage successfully applied when not dashing")
	check(hc.health == 75, "Health decreased to 75 after dash ended")

	# =========================================================================
	# [Test 3] Weapon Lock: Cannot Shoot Mid-Dash
	# =========================================================================
	print("\n[Test 3] Testing Weapon Lock During Dash...")
	combat.can_shoot = true
	combat._cooldown_left = 0.0

	# While dashing: verify _fire is blocked
	player._perform_dash()
	check(player.is_dashing == true, "Player is dashing")

	var initial_bullet_count : int = root.find_children("Bullet*", "Node3D", true, false).size()
	combat._fire(false) # Attempt primary fire
	combat._fire(true)  # Attempt alt fire

	var mid_dash_bullet_count : int = root.find_children("Bullet*", "Node3D", true, false).size()
	check(mid_dash_bullet_count == initial_bullet_count, "No bullets spawned while dashing (fire blocked)")

	# Finish dash
	player._physics_process(player.dash_duration + 0.05)
	check(player.is_dashing == false, "Dash finished")

	# Verify firing works normally when not dashing
	combat._cooldown_left = 0.0
	combat._fire(false)
	var post_dash_bullet_count : int = root.find_children("Bullet*", "Node3D", true, false).size()
	check(post_dash_bullet_count > initial_bullet_count, "Weapon discharges normally after dash completes")

	# Clean up bullets and player
	for b in root.find_children("Bullet*", "Node3D", true, false):
		b.queue_free()
	player.queue_free()

	# =========================================================================
	# [Test 4] Dash Particles: Single-Direction Backpack Thrusters
	# =========================================================================
	print("\n[Test 4] Testing Dash Particles Directional Alignment...")
	var dp_scene : PackedScene = load("res://scenes/player/dash_particles.tscn")
	check(dp_scene != null, "dash_particles.tscn loaded")

	var dp = dp_scene.instantiate()
	root.add_child(dp)
	await process_frame

	# Start dash with backward parameters: thrusters should still fire rear nozzles
	dp.start_dash_directional(Vector3.BACK, Vector3.FORWARD, -1.0, 0.0, 0.22)
	check(dp.cpu_particles.emitting == true, "Rear left nozzle emits")
	if dp.right_particles != null:
		check(dp.right_particles.emitting == true, "Rear right nozzle emits")
	if dp.front_left_particles != null:
		check(dp.front_left_particles.emitting == false, "Front left nozzle is OFF (single-direction thruster)")
	if dp.side_left_particles != null:
		check(dp.side_left_particles.emitting == false, "Side nozzle is OFF (single-direction thruster)")

	dp.stop_dash()
	check(dp.cpu_particles.emitting == false, "Rear nozzles stop when dash completes")
	dp.queue_free()

	# =========================================================================
	# [Test 5] Weapons Box: No Audio Cue on Spawn
	# =========================================================================
	print("\n[Test 5] Testing Weapons Box Spawn Audio...")
	var wb_scene : PackedScene = load("res://scenes/weapons/weapons_box.tscn")
	check(wb_scene != null, "weapons_box.tscn loaded")

	var wb = wb_scene.instantiate()
	root.add_child(wb)
	await process_frame

	# Verify script has no play_weapon_pickup in spawn method
	var wb_script_text : String = FileAccess.get_file_as_string("res://scenes/weapons/weapons_box.gd")
	var spawn_section : String = wb_script_text.substr(wb_script_text.find("func spawn_random_weapon"), 400)
	check(not ("play_weapon_pickup" in spawn_section), "play_weapon_pickup removed from spawn_random_weapon()")

	wb.spawn_random_weapon()
	check(wb.current_weapon != -1, "Weapon dispensed successfully in dispenser")
	wb.queue_free()

	# =========================================================================
	# [Test 6] Shadow Settings & Pixel Art Shader
	# =========================================================================
	print("\n[Test 6] Testing Shadow Quality & Pixel Art Shader...")
	var project_godot : String = FileAccess.get_file_as_string("res://project.godot")
	check("directional_shadow/soft_shadow_filter_quality=0" in project_godot, "Directional shadow quality is set to Hard (0)")
	check("positional_shadow/soft_shadow_filter_quality=0" in project_godot, "Positional shadow quality is set to Hard (0)")

	var shader_code : String = FileAccess.get_file_as_string("res://assets/shaders/edge_detection.gdshader")
	check("floor(dotNL * 4.0" in shader_code, "Shader quantizes diffuse lighting into discrete pixel art bands")
	check("step(0.35, ATTENUATION)" in shader_code, "Shader quantizes shadows into crisp hard cuts")
	check("step(0.28, edge)" in shader_code, "Shader creates crisp pixel-art ink outlines")

	var main_scene_text : String = FileAccess.get_file_as_string("res://scenes/main.tscn")
	check("shadow_blur = 0.0" in main_scene_text, "main.tscn DirectionalLight3D has shadow_blur = 0.0")
	check("directional_shadow_max_distance = 48.0" in main_scene_text, "main.tscn DirectionalLight3D shadow max distance optimized to 48m")

	# =========================================================================
	# [Test 7] Gamemode Vista Banners: Dimensions & Files
	# =========================================================================
	print("\n[Test 7] Testing Gamemode Banners on Disk...")
	var banner_files := [
		"res://assets/textures/gamemodes/banner_tutorial.png",
		"res://assets/textures/gamemodes/banner_survival.png",
		"res://assets/textures/gamemodes/banner_sandbox.png",
		"res://assets/textures/gamemodes/banner_story.png",
		"res://assets/textures/gamemodes/banner_coop.png"
	]

	for bf in banner_files:
		check(FileAccess.file_exists(bf), "Banner file exists: " + bf)
		var img := Image.new()
		var err := img.load(bf)
		check(err == OK, "Banner loaded successfully: " + bf)
		check(img.get_width() == 560 and img.get_height() == 660, "Banner dimensions are 560x660: " + bf)

	# =========================================================================
	# [Test 8] Selection UI: Dead Zone Elimination & Unlocked Gamemodes
	# =========================================================================
	print("\n[Test 8] Testing Selection UI Clickability & Unlocked Gamemodes...")
	var menu_scene : PackedScene = load("res://scenes/ui/main_menu.tscn")
	check(menu_scene != null, "main_menu.tscn loaded")

	var menu = menu_scene.instantiate()
	root.add_child(menu)
	await process_frame
	await process_frame

	# Check that all non-button children of cards have mouse_filter == MOUSE_FILTER_IGNORE (no dead zones!)
	var cards_to_verify := [
		menu.tutorial_card, menu.survival_card, menu.sandbox_card, menu.range_card, menu.mayhem_card, menu.story_card, menu.coop_card,
		menu.astronaut_card, menu.engineer_card, menu.medic_card, menu.explorer_card,
		menu.canyon_card, menu.base_card, menu.dock_card
	]

	var all_children_transparent : bool = true
	var checked_children_count : int = 0
	for card in cards_to_verify:
		if card == null:
			continue
		check(card.disabled == false, "Card button is enabled: " + card.name)
		for child in card.find_children("*", "Control", true, false):
			if not (child is Button):
				checked_children_count += 1
				if child.mouse_filter != Control.MOUSE_FILTER_IGNORE:
					all_children_transparent = false
					print("  [FAIL] Child has blocking mouse_filter: ", child.name, " in ", card.name)

	check(all_children_transparent and checked_children_count > 30, "All " + str(checked_children_count) + " card overlay children have mouse_filter = IGNORE (0 dead zones)")

	# Verify The Range and Rocket Mayhem are unlocked and selectable
	check(menu.range_card.disabled == false, "The Range card is unlocked and clickable")
	check(menu.mayhem_card.disabled == false, "Rocket Mayhem card is unlocked and clickable")
	check(menu.story_card.disabled == false, "Story card is clickable to open teaser")
	check(menu.coop_card.disabled == false, "Co-op card is clickable to open teaser")

	# Test mode selection
	menu._select_mode(menu.GameMode.RANGE)
	check(menu.selected_mode == menu.GameMode.RANGE, "Selecting The Range updates selected_mode to RANGE")
	check("THE RANGE" in menu.main_launch_button.text, "Launch button text updates for The Range")

	menu._select_mode(menu.GameMode.ROCKET_MAYHEM)
	check(menu.selected_mode == menu.GameMode.ROCKET_MAYHEM, "Selecting Rocket Mayhem updates selected_mode to ROCKET_MAYHEM")
	check("ROCKET MAYHEM" in menu.main_launch_button.text, "Launch button text updates for Rocket Mayhem")

	menu.queue_free()

	# =========================================================================
	# Summary
	# =========================================================================
	print("\n=======================================================")
	print("RESULTS: %d Passed, %d Failed" % [passes, failures])
	print("=======================================================\n")
	if failures > 0:
		quit(1)
	else:
		quit(0)
