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
	print("--- Running Guided Tutorial & Game Modes Verification Test Suite ---")
	call_deferred("_run_tests")

func _run_tests() -> void:
	await process_frame
	await process_frame

	# ----------------------------------------------------
	# [Test 1] Tutorial Map Scene Structure & Preloads
	# ----------------------------------------------------
	print("\n[Test 1] Testing Tutorial Map Scene Structure...")
	var tut_scene : PackedScene = load("res://scenes/tutorial/tutorial_map.tscn")
	check(tut_scene != null, "tutorial_map.tscn loaded successfully")

	var map : Node3D = tut_scene.instantiate() as Node3D
	root.add_child(map)
	await process_frame
	await process_frame

	var player : CharacterBody3D = map.find_child("ProtoController", true, false) as CharacterBody3D
	check(player != null, "ProtoController player exists in tutorial map")

	var mgr : TutorialManager = map.find_child("TutorialManager", true, false) as TutorialManager
	check(mgr != null, "TutorialManager node exists in tutorial map")

	var hud : TutorialHud = map.find_child("TutorialHud", true, false) as TutorialHud
	check(hud != null, "TutorialHud node exists in tutorial map")

	var rover : CharacterBody3D = map.find_child("Rover", true, false) as CharacterBody3D
	check(rover != null, "Rover vehicle exists in tutorial map")

	var targets : Array[Node] = map.find_children("*", "TrainingTarget", true, false)
	check(targets.size() == 3, "3 TrainingTarget dummies positioned on firing range (found: %d)" % targets.size())

	var waypoints : Array[Node] = map.find_children("*", "TutorialWaypoint", true, false)
	check(waypoints.size() >= 8, "All 8+ TutorialWaypoints present across training zones (found: %d)" % waypoints.size())

	var wall_n : Node = map.find_child("WallNorth", true, false)
	var wall_s : Node = map.find_child("WallSouth", true, false)
	check(wall_n != null and wall_s != null, "Tutorial map perimeter containment walls exist preventing border escape")

	check(hud.edge_indicator != null and hud.edge_arrow != null, "Tutorial HUD minimal screen-edge navigation indicator initialized")

	# ----------------------------------------------------
	# [Test 2] Tutorial Phase 1: Locomotion & Jumping
	# ----------------------------------------------------
	print("\n[Test 2] Testing Tutorial Phase 1 (Locomotion & Jumping)...")
	check(mgr.current_phase == TutorialManager.Phase.PHASE_1_LOCOMOTION, "Initial tutorial phase is PHASE_1_LOCOMOTION")
	check(mgr.wp_locomotion != null and mgr.wp_locomotion.is_active == true, "Locomotion waypoint is actively glowing")

	# Simulate movement
	player.global_position += Vector3(6.0, 0.0, 0.0)
	mgr._process_phase_1()
	check(mgr._moved_distance >= 5.0, "Player movement tracked accurately (dist: %.1fm)" % mgr._moved_distance)

	# Trigger locomotion waypoint
	mgr.wp_locomotion._on_body_entered(player)
	await process_frame
	check(mgr.current_phase == TutorialManager.Phase.PHASE_2_THRUSTERS, "Reaching locomotion waypoint advances to PHASE_2_THRUSTERS")
	check(mgr.wp_locomotion.is_active == false, "Locomotion waypoint deactivated")
	check(mgr.wp_thrusters.is_active == true, "Thruster platform waypoint activated")

	# ----------------------------------------------------
	# [Test 3] Tutorial Phase 2: Thrusters & Flight
	# ----------------------------------------------------
	print("\n[Test 3] Testing Tutorial Phase 2 (Thrusters & Agility)...")
	player.set("is_dashing", true)
	mgr._process_phase_2()
	check(mgr._has_dashed == true, "Dash detected and checked off in objective HUD")

	player.set("is_flying", true)
	mgr._process_phase_2()
	check(mgr._has_hovered == true, "Pressurized thruster flight detected and checked off")

	# Trigger thruster waypoint atop platform
	mgr.wp_thrusters._on_body_entered(player)
	await process_frame
	check(mgr.current_phase == TutorialManager.Phase.PHASE_3_WEAPONS, "Reaching elevated platform advances to PHASE_3_WEAPONS")

	# ----------------------------------------------------
	# [Test 4] Tutorial Phase 3: Weapons & Marksmanship
	# ----------------------------------------------------
	print("\n[Test 4] Testing Tutorial Phase 3 (Weapons & Marksmanship)...")
	mgr._on_weapon_switched()
	check(mgr._has_switched_weapon == true, "Weapon switch detected")

	var target1 : TrainingTarget = targets[0] as TrainingTarget
	check(target1.has_method("take_damage"), "TrainingTarget exposes take_damage method for bullet hits")

	# Destroy 3 targets
	for t in targets:
		var target := t as TrainingTarget
		target.take_damage(60)
	for _f in range(20):
		await process_frame

	check(mgr._targets_destroyed_count == 3, "All 3 target dummies neutralized (count: %d)" % mgr._targets_destroyed_count)
	check(target1._is_destroyed == true, "Target marked destroyed")
	check(target1.model.rotation_degrees.x <= -80.0, "Destroyed target went down flat onto the floor (rot_x: %.1f deg)" % target1.model.rotation_degrees.x)
	check(mgr.wp_weapons.is_active == true, "Advance waypoint activated upon marksmanship completion")

	# Reach weapons advance waypoint
	mgr.wp_weapons._on_body_entered(player)
	await process_frame
	check(mgr.current_phase == TutorialManager.Phase.PHASE_4_VEHICLE, "Transitioned to PHASE_4_VEHICLE")

	# ----------------------------------------------------
	# [Test 5] Tutorial Phase 4: Rover Operations
	# ----------------------------------------------------
	print("\n[Test 5] Testing Tutorial Phase 4 (Vehicle Operations)...")
	check(mgr.wp_rover_bay.is_active == true, "Rover depot waypoint active")

	# Simulate boarding rover
	mgr._on_rover_boarded()
	check(mgr._has_boarded_rover == true, "Boarding rover registered")
	check(mgr.wp_slalom_1.is_active == true, "Slalom gate 1 waypoint activated")

	# Navigate slalom 1
	mgr._on_slalom_1_wp_reached()
	check(mgr._passed_slalom_1 == true, "Slalom gate 1 cleared")
	check(mgr.wp_slalom_2.is_active == true, "Slalom gate 2 waypoint activated")

	# Navigate slalom 2
	mgr._on_slalom_2_wp_reached()
	check(mgr._passed_slalom_2 == true, "Slalom gate 2 cleared")
	check(mgr.wp_rover_park.is_active == true, "Parking terminal waypoint activated")

	# Dismount rover
	mgr._on_rover_dismounted()
	await process_frame
	check(mgr.current_phase == TutorialManager.Phase.PHASE_5_COMBAT, "Transitioned to PHASE_5_COMBAT")

	# ----------------------------------------------------
	# [Test 6] Tutorial Phase 5: Combat Trial & Victory
	# ----------------------------------------------------
	print("\n[Test 6] Testing Tutorial Phase 5 (Combat Arena & Victory)...")
	mgr._on_combat_arena_wp_reached()
	await process_frame

	# Simulate defeating 3 training hostiles
	mgr._on_enemy_neutralized()
	mgr._on_enemy_neutralized()
	mgr._on_enemy_neutralized()
	check(mgr._enemies_cleared_count == 3, "All 3 training hostiles neutralized")
	check(mgr.wp_extraction.is_active == true, "Extraction pad beacon activated")

	# Reach extraction beacon
	mgr._on_extraction_wp_reached()
	check(mgr.current_phase == TutorialManager.Phase.COMPLETED, "Tutorial successfully COMPLETED")
	check(hud.victory_modal.visible == true, "Tutorial completion victory modal displayed")

	# Clean up map instance
	map.queue_free()
	await process_frame

	# ----------------------------------------------------
	# [Test 7] Main Menu 5 Game Modes & Teasers
	# ----------------------------------------------------
	print("\n[Test 7] Testing Main Menu Gamemodes, Banners & Teasers...")
	var menu_scene : PackedScene = load("res://scenes/ui/main_menu.tscn")
	check(menu_scene != null, "main_menu.tscn loaded successfully")

	var menu : Control = menu_scene.instantiate() as Control
	root.add_child(menu)
	await process_frame
	await process_frame

	var tut_card : Button = menu.find_child("TutorialCard", true, false) as Button
	var surv_card : Button = menu.find_child("SurvivalCard", true, false) as Button
	var sand_card : Button = menu.find_child("SandboxCard", true, false) as Button
	var story_card : Button = menu.find_child("StoryCard", true, false) as Button
	var coop_card : Button = menu.find_child("CoopCard", true, false) as Button

	check(tut_card != null, "TutorialCard exists in mode select screen")
	check(surv_card != null, "SurvivalCard exists in mode select screen")
	check(sand_card != null, "SandboxCard exists in mode select screen")
	check(story_card != null, "Locked StoryCard exists in mode select screen")
	check(coop_card != null, "Locked CoopCard exists in mode select screen")

	# Check banners are assigned
	var tut_bg : TextureRect = tut_card.find_child("CardBackground", true, false) as TextureRect
	var surv_bg : TextureRect = surv_card.find_child("CardBackground", true, false) as TextureRect
	var sand_bg : TextureRect = sand_card.find_child("CardBackground", true, false) as TextureRect
	var story_bg : TextureRect = story_card.find_child("CardBackground", true, false) as TextureRect
	var coop_bg : TextureRect = coop_card.find_child("CardBackground", true, false) as TextureRect

	check(tut_bg != null and tut_bg.texture != null, "TutorialCard has detailed in-engine map banner")
	check(surv_bg != null and surv_bg.texture != null, "SurvivalCard has detailed in-engine map banner")
	check(sand_bg != null and sand_bg.texture != null, "SandboxCard has detailed in-engine map banner")
	check(story_bg != null and story_bg.texture != null, "StoryCard has detailed in-engine map banner")
	check(coop_bg != null and coop_bg.texture != null, "CoopCard has detailed in-engine map banner")

	# Test Tutorial Selection
	menu._select_mode(menu.GameMode.TUTORIAL)
	check(menu.selected_mode == menu.GameMode.TUTORIAL, "Tutorial mode selected")
	check(menu.main_launch_button.text.contains("TUTORIAL"), "Launch button text updated to 'LAUNCH TUTORIAL'")

	# Test Locked Story Mode Teaser Modal
	var teaser_modal : Control = menu.find_child("TeaserModal", true, false) as Control
	check(teaser_modal != null, "TeaserModal exists in mode select screen")
	check(teaser_modal.visible == false, "TeaserModal initially hidden")

	story_card.emit_signal("pressed")
	await process_frame
	check(teaser_modal.visible == true, "Clicking locked Story Card opens TeaserModal")
	check(menu.teaser_title.text.contains("BRIEFING"), "Teaser modal displays classified military briefing")

	menu._close_teaser_modal()
	await process_frame
	check(teaser_modal.visible == false, "Acknowledging closes TeaserModal")

	# Test Locked Co-op Mode Teaser Modal
	coop_card.emit_signal("pressed")
	await process_frame
	check(teaser_modal.visible == true, "Clicking locked Co-op Card opens TeaserModal")
	check(menu.teaser_header.text.contains("TACTICAL SQUAD"), "Teaser modal displays Tactical Squad co-op teaser")

	menu._close_teaser_modal()
	await process_frame

	# ----------------------------------------------------
	# [Test 8] Banner Tints, Card Height & Minimal UI Verification
	# ----------------------------------------------------
	print("\n[Test 8] Testing Banner Tints, Card Height & Clean Minimal UI...")
	# Verify all cards have increased height (>= 360px)
	check(tut_card.custom_minimum_size.y >= 360.0, "TutorialCard is taller (height: %.0fpx)" % tut_card.custom_minimum_size.y)
	check(surv_card.custom_minimum_size.y >= 360.0, "SurvivalCard is taller (height: %.0fpx)" % surv_card.custom_minimum_size.y)
	check(sand_card.custom_minimum_size.y >= 360.0, "SandboxCard is taller (height: %.0fpx)" % sand_card.custom_minimum_size.y)
	check(story_card.custom_minimum_size.y >= 360.0, "StoryCard is taller (height: %.0fpx)" % story_card.custom_minimum_size.y)
	check(coop_card.custom_minimum_size.y >= 360.0, "CoopCard is taller (height: %.0fpx)" % coop_card.custom_minimum_size.y)

	# Verify banner self_modulate tints
	check(surv_bg.self_modulate.r > surv_bg.self_modulate.g + 0.3, "Survival banner tinted distinct red")
	check(sand_bg.self_modulate.r > 0.8 and sand_bg.self_modulate.g > 0.7 and sand_bg.self_modulate.b < 0.6, "Sandbox banner tinted distinct yellow")
	check(story_bg.self_modulate.r < 0.65 and story_bg.self_modulate.g < 0.65 and story_bg.self_modulate.b < 0.65, "Story banner tinted muted grey")
	check(coop_bg.self_modulate.r < 0.65 and coop_bg.self_modulate.g < 0.65 and coop_bg.self_modulate.b < 0.65, "Coop banner tinted muted grey")

	# Verify HexAmbientBackground was cleanly removed for minimalist aesthetic
	var hex_bg : Node = menu.find_child("HexAmbientBackground", true, false)
	check(hex_bg == null, "HexAmbientBackground removed keeping background clean and minimal")

	menu.queue_free()

	# ----------------------------------------------------
	# Final Verification Results
	# ----------------------------------------------------
	print("\n=======================================================")
	print("TUTORIAL & GAMEMODES RESULTS: %d Passed, %d Failed" % [passes, failures])
	print("=======================================================\n")
	quit(0 if failures == 0 else 1)
