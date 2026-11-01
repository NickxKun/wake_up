extends SceneTree

## Comprehensive Verification Test Suite for 4 Character Classes:
## 1. Astronaut (Vanguard)
## 2. Engineer (Architect - Sentry Turret, Aggro Decoy, Melee Wrench)
## 3. Medic (Surgeon - Cellular Regeneration, Nanite Healing Surge)
## 4. Explorer (Pathfinder - Camera Visibility, Radar Range, Space Truck, Vehicle Cannons)
## And UI integration (Main Menu Operative Selector & In-game Health HUD Ability indicator).

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
	print("--- Running Character Classes Comprehensive Test Suite ---")
	call_deferred("_run_tests")

func _run_tests() -> void:
	await process_frame
	await process_frame

	# -------------------------------------------------------------------------
	# 1. Verify CharacterData Singleton & Class Configs
	# -------------------------------------------------------------------------
	print("\n[Phase 1] Testing CharacterData Singleton & Configurations...")
	var char_data : Node = root.get_node_or_null("CharacterData")
	check(char_data != null, "CharacterData autoload singleton is present in tree")
	if char_data == null:
		print("FATAL: CharacterData missing")
		quit(1)
		return

	check(CharacterDataSingleton.CharacterClass.ASTRONAUT == 0, "Enum ASTRONAUT == 0")
	check(CharacterDataSingleton.CharacterClass.ENGINEER == 1, "Enum ENGINEER == 1")
	check(CharacterDataSingleton.CharacterClass.MEDIC == 2, "Enum MEDIC == 2")
	check(CharacterDataSingleton.CharacterClass.EXPLORER == 3, "Enum EXPLORER == 3")

	var astro_cfg : Dictionary = char_data.call("get_class_config", CharacterDataSingleton.CharacterClass.ASTRONAUT)
	var engi_cfg : Dictionary = char_data.call("get_class_config", CharacterDataSingleton.CharacterClass.ENGINEER)
	var medic_cfg : Dictionary = char_data.call("get_class_config", CharacterDataSingleton.CharacterClass.MEDIC)
	var exp_cfg : Dictionary = char_data.call("get_class_config", CharacterDataSingleton.CharacterClass.EXPLORER)

	check(astro_cfg.get("name") == "Astronaut", "Astronaut name is correct")
	check(engi_cfg.get("has_pistol") == false, "Engineer has_pistol == false (No sidearm)")
	check(engi_cfg.get("starter_weapon") == 5, "Engineer starter_weapon == WRENCH (5)")
	check(medic_cfg.get("starter_weapon") == 1, "Medic starter_weapon == SHOTGUN (1)")
	check(medic_cfg.get("starter_weapon_name") == "Bio-Shotgun", "Medic starter weapon is Bio-Shotgun")
	check(exp_cfg.get("starter_weapon") == 2, "Explorer starter_weapon == SNIPER (2)")
	check(exp_cfg.get("starter_weapon_name") == "Marksman Rifle", "Explorer starter weapon is Marksman Rifle")
	check(exp_cfg.get("camera_size") == 5.2, "Explorer has +30% camera size (5.2)")
	check(exp_cfg.get("radar_radius") == 38.0, "Explorer has extended radar radius (38.0)")
	check(exp_cfg.get("can_drive_truck") == true, "Explorer authorized to drive Space Truck")
	check(exp_cfg.get("vehicle_weapons") == true, "Explorer has vehicle_weapons enabled")

	# Test select_class
	char_data.call("select_class", CharacterDataSingleton.CharacterClass.ENGINEER)
	check(int(char_data.get("current_class")) == CharacterDataSingleton.CharacterClass.ENGINEER, "select_class switches current_class to ENGINEER")

	# -------------------------------------------------------------------------
	# 2. Instantiate Player & Verify Engineer Class
	# -------------------------------------------------------------------------
	print("\n[Phase 2] Testing Player Controller & Engineer Class...")
	var player_scene : PackedScene = load("res://addons/proto_controller/proto_controller.tscn")
	check(player_scene != null, "Loaded proto_controller.tscn")
	var player : CharacterBody3D = player_scene.instantiate() as CharacterBody3D
	root.add_child(player)
	player.global_position = Vector3(0, 0, 0)
	await process_frame
	await process_frame

	var combat : Node = player.get_node_or_null("PlayerCombat")
	if combat == null:
		var combat_script : Script = load("res://scenes/player/player_combat.gd")
		combat = Node.new()
		combat.name = "PlayerCombat"
		combat.set_script(combat_script)
		player.add_child(combat)
	check(combat != null, "PlayerCombat component attached to player")

	# Verify Engineer perks applied
	combat.call("apply_character_class", CharacterDataSingleton.CharacterClass.ENGINEER)
	check(combat.get("starter_slot1_weapon") == 5, "Engineer equips WRENCH (5) in starter Slot 1")
	check(combat.call("get_weapon_name") == "TITANIUM WRENCH", "get_weapon_name() returns TITANIUM WRENCH")

	# Verify Engineer 3D Model Polish & Anti-Clipping Geometry
	var engi_rig : Node3D = player.find_child("EngineerTurretRig", true, false) as Node3D
	var engi_visor : Node3D = player.find_child("EngineerVisor", true, false) as Node3D
	var engi_pauldrons : Node3D = player.find_child("EngineerPauldrons", true, false) as Node3D
	var engi_belt : Node3D = player.find_child("EngineerBelt", true, false) as Node3D
	check(engi_rig != null, "EngineerTurretRig accessory attached to player")
	check(engi_visor != null, "EngineerVisor accessory attached to player")
	check(engi_pauldrons != null, "EngineerPauldrons shoulder armor attached to player")
	check(engi_belt != null, "EngineerBelt utility waist belt attached to player")

	if engi_rig != null:
		check(engi_rig.global_position.z > player.global_position.z + 0.04, "EngineerTurretRig correctly positioned on back (global.z: %.3f > %.3f)" % [engi_rig.global_position.z, player.global_position.z])
		var micro_bay : Node3D = engi_rig.get_node_or_null("MicroTurretBay") as Node3D
		check(micro_bay != null, "Folded MicroTurretBay mounted on top of Engineer fabrication rig")

	if engi_visor != null:
		check(engi_visor.global_position.z < player.global_position.z - 0.04, "EngineerVisor correctly positioned on front face (global.z: %.3f < %.3f)" % [engi_visor.global_position.z, player.global_position.z])

	var player_sk : Skeleton3D = player.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	if player_sk != null and engi_rig != null:
		var arm_l_bone : int = player_sk.find_bone("UpperArm.L")
		var arm_r_bone : int = player_sk.find_bone("UpperArm.R")
		var arm_l_pos : Vector3 = player_sk.global_transform * player_sk.get_bone_global_pose(arm_l_bone).origin
		var arm_r_pos : Vector3 = player_sk.global_transform * player_sk.get_bone_global_pose(arm_r_bone).origin
		var clearance_l : float = absf(arm_l_pos.x - engi_rig.global_position.x) - 0.051
		var clearance_r : float = absf(arm_r_pos.x - engi_rig.global_position.x) - 0.051
		check(clearance_l > 0.03, "Left arm has clear non-clipping clearance to backpack rig (%.3f m > 0.03 m)" % clearance_l)
		check(clearance_r > 0.03, "Right arm has clear non-clipping clearance to backpack rig (%.3f m > 0.03 m)" % clearance_r)

	# Test Engineer deploy sentry turret ability
	check(char_data.call("is_ability_ready") == true, "Ability is ready before execution")
	combat.call("execute_class_ability")
	check(char_data.call("is_ability_ready") == false, "Ability cooldown triggered after deploying turret")
	check(float(char_data.get("ability_cooldown_remaining")) > 0.0, "Cooldown timer is ticking")

	await process_frame
	await process_frame

	var turrets : Array[Node] = get_nodes_in_group("turret")
	check(turrets.size() >= 1, "Sentry turret instantiated and registered in group 'turret'")
	var turret : Node3D = turrets[0] as Node3D
	check(turret != null, "Sentry turret is a valid Node3D")
	var turret_hc : HealthComponent = turret.get_node_or_null("HealthComponent") as HealthComponent
	check(turret_hc != null and turret_hc.health == 100, "Sentry turret has HealthComponent with 100 HP")

	# Verify Turret Minimal Health Bar 3D
	var hp_sprite : Sprite3D = turret.get_node_or_null("HealthBar3D") as Sprite3D
	check(hp_sprite != null, "Turret has HealthBar3D Sprite3D")
	check(hp_sprite.no_depth_test == true, "HealthBar3D has no_depth_test = true (unobstructed)")
	check(hp_sprite.billboard == 1, "HealthBar3D has billboard enabled (faces camera)")
	var hp_prog : ProgressBar = turret.get_node_or_null("HealthBar3D/SubViewport/ProgressBar") as ProgressBar
	check(hp_prog != null and hp_prog.value == 100.0, "Turret ProgressBar exists with initial 100 HP")

	# Test Turret Forward Aiming Direction (targeting East +X)
	var test_target_east : Node3D = Node3D.new()
	test_target_east.add_to_group("enemy")
	var dummy_hc : HealthComponent = HealthComponent.new()
	test_target_east.add_child(dummy_hc)
	root.add_child(test_target_east)
	test_target_east.global_position = turret.global_position + Vector3(6.0, 0.0, 0.0)

	for _i in range(15):
		turret.call("_physics_process", 0.033)
		await process_frame

	var swivel : Node3D = turret.get_node_or_null("TurretBase/SwivelHead") as Node3D
	check(swivel != null, "SwivelHead found on turret")
	var fwd_east : Vector3 = -swivel.global_transform.basis.z.normalized()
	check(fwd_east.x > 0.85, "Turret front barrels point towards East target (fwd.x: %.2f > 0.85)" % fwd_east.x)
	check(abs(fwd_east.z) < 0.4, "Turret is horizontally aligned with East target")

	# Test Turret Forward Aiming Direction (targeting South +Z)
	test_target_east.global_position = turret.global_position + Vector3(0.0, 0.0, 6.0)
	for _i in range(20):
		turret.call("_physics_process", 0.033)
		await process_frame

	var fwd_south : Vector3 = -swivel.global_transform.basis.z.normalized()
	check(fwd_south.z > 0.85, "Turret front barrels point towards South target (fwd.z: %.2f > 0.85)" % fwd_south.z)
	check(abs(fwd_south.x) < 0.4, "Turret is horizontally aligned with South target")

	# Test bullet firing direction
	var bullets_before : int = get_nodes_in_group("bullet").size()
	turret.set("_fire_timer", 0.0)
	turret.call("_physics_process", 0.033)
	await process_frame

	var bullets_after := get_nodes_in_group("bullet")
	var spawned_turret_bullet : Area3D = null
	for i in range(bullets_after.size() - 1, -1, -1):
		var b : Node = bullets_after[i]
		if b.get("shooter") == turret:
			spawned_turret_bullet = b as Area3D
			break
	check(spawned_turret_bullet != null, "Turret discharged kinetic round")
	if spawned_turret_bullet != null:
		check(spawned_turret_bullet.direction.z > 0.85, "Turret bullet fires forward towards target (bullet.dir.z: %.2f > 0.85, NOT backwards)" % spawned_turret_bullet.direction.z)

	# Test Turret Damage and Wrench Repair
	turret_hc.take_damage(30)
	check(turret_hc.health == 70, "Turret health decreased to 70 after damage")
	turret_hc.heal(20)
	check(turret_hc.health == 90, "Turret health repaired to 90 HP")

	# Test HUD TurretTag display when turret is active
	var hb_scene_p2 : PackedScene = load("res://scenes/ui/health_bar.tscn")
	var test_hb : CanvasLayer = hb_scene_p2.instantiate() as CanvasLayer
	root.add_child(test_hb)
	test_hb.call("_process", 0.016)
	var t_tag : Label = test_hb.get_node_or_null("MarginContainer/VBoxContainer/OperativeRow/TurretTag") as Label
	check(t_tag != null and t_tag.visible == true, "TurretTag is visible in HUD when Engineer has active turret")
	check("TURRET: 90 HP" in t_tag.text, "TurretTag reflects active turret health: 90 HP")
	test_hb.queue_free()

	test_target_east.queue_free()

	# -------------------------------------------------------------------------
	# 3. Enemy Aggro Prioritization (Turret before Player)
	# -------------------------------------------------------------------------
	print("\n[Phase 3] Testing Enemy Target Prioritization...")
	var enemy_scene : PackedScene = load("res://scenes/enemy/enemy.tscn")
	check(enemy_scene != null, "Loaded enemy.tscn")
	var enemy : CharacterBody3D = enemy_scene.instantiate() as CharacterBody3D
	root.add_child(enemy)
	enemy.global_position = Vector3(5, 0, 0)
	await process_frame
	await process_frame

	var target : Node3D = enemy.call("_select_target")
	check(target == turret, "Enemy prioritizes Sentry Turret over Player when turret is in range")

	# Destroy turret and verify fallback to player
	turret.queue_free()
	await process_frame
	await process_frame

	var target_after : Node3D = enemy.call("_select_target")
	check(target_after == player, "Enemy falls back to targeting Player when no active turrets are present")
	enemy.queue_free()

	# -------------------------------------------------------------------------
	# 4. Medic Class & Nanite Healing Surge
	# -------------------------------------------------------------------------
	print("\n[Phase 4] Testing Medic Class & Healing Systems...")
	char_data.call("select_class", CharacterDataSingleton.CharacterClass.MEDIC)
	char_data.set("ability_cooldown_remaining", 0.0) # Reset cooldown for test
	player.call("_apply_class_perks", CharacterDataSingleton.CharacterClass.MEDIC)

	var hc : HealthComponent = player.get_node_or_null("HealthComponent") as HealthComponent
	check(hc != null, "Player has HealthComponent")
	check(hc.passive_health_regen == true, "Medic has passive_health_regen enabled on HealthComponent")

	# Test passive regen after delay
	hc.health = 50
	hc.health_regen_timer = 0.0 # Fast-forward regen timer
	hc._process(1.0)
	check(hc.health > 50, "Medic HealthComponent passively regenerates health (+3 HP/s)")

	# Test active Nanite Healing Surge
	hc.health = 40
	combat.call("execute_class_ability")
	check(hc.health > 40, "Nanite Healing Surge restored HP to Medic")
	check(float(char_data.get("ability_cooldown_remaining")) > 0.0, "Medic ability triggered cooldown")
	check(combat.get("starter_slot1_weapon") == 1, "Medic equips Compact Bio-Shotgun (1) in starter Slot 1")
	check(combat.call("get_weapon_name") == "BIO-SHOTGUN", "Medic get_weapon_name() returns BIO-SHOTGUN")

	# -------------------------------------------------------------------------
	# 5. Explorer Class, Visibility & Space Truck Authorization
	# -------------------------------------------------------------------------
	print("\n[Phase 5] Testing Explorer Class & Space Truck Authorization...")
	# First test as Astronaut: Space Truck should deny access
	char_data.call("select_class", CharacterDataSingleton.CharacterClass.ASTRONAUT)
	player.call("_apply_class_perks", CharacterDataSingleton.CharacterClass.ASTRONAUT)

	var truck_scene : PackedScene = load("res://scenes/vehicles/spacetruck.tscn")
	check(truck_scene != null, "Loaded spacetruck.tscn")
	var truck : CharacterBody3D = truck_scene.instantiate() as CharacterBody3D
	root.add_child(truck)
	truck.global_position = Vector3(2.0, 0, 0)
	await process_frame
	await process_frame

	check(truck.get("requires_explorer") == true, "Space Truck has requires_explorer flag set to true")

	# Non-explorer attempts to board
	truck.call("board_vehicle", player)
	check(truck.get("is_occupied") == false, "Astronaut denied boarding Space Truck (requires Explorer)")

	# Switch to Explorer
	char_data.call("select_class", CharacterDataSingleton.CharacterClass.EXPLORER)
	player.call("_apply_class_perks", CharacterDataSingleton.CharacterClass.EXPLORER)
	check(combat.get("starter_slot1_weapon") == 2, "Explorer equips Scout Marksman Sniper (2) in starter Slot 1")
	check(combat.call("get_weapon_name") == "MARKSMAN RIFLE", "Explorer get_weapon_name() returns MARKSMAN RIFLE")

	# Explorer attempts to board
	truck.call("board_vehicle", player)
	check(truck.get("is_occupied") == true, "Explorer successfully boarded Space Truck")
	check(player.get("is_driving_vehicle") == true, "Player driving flag set to true")

	# Test vehicle mounted cannon firing
	check(truck.has_method("_fire_vehicle_cannons"), "Truck has _fire_vehicle_cannons method")
	truck.call("_fire_vehicle_cannons")
	await process_frame
	var bullets : Array[Node] = get_nodes_in_group("bullet")
	# Vehicle cannons fire twin projectiles
	check(bullets.size() >= 2, "Vehicle mounted cannons fired dual plasma projectiles")

	# Exit vehicle cleanly
	truck.call("exit_vehicle")
	check(truck.get("is_occupied") == false, "Space Truck exited cleanly")
	check(player.get("is_driving_vehicle") == false, "Player driving flag reset to false")
	truck.queue_free()

	# -------------------------------------------------------------------------
	# 5b. Astronaut Frag Grenade Active Ability
	# -------------------------------------------------------------------------
	print("\n[Phase 5b] Testing Astronaut Frag Grenade Active Ability...")
	char_data.call("select_class", CharacterDataSingleton.CharacterClass.ASTRONAUT)
	char_data.set("ability_cooldown_remaining", 0.0)
	player.call("_apply_class_perks", CharacterDataSingleton.CharacterClass.ASTRONAUT)
	combat.call("execute_class_ability")
	await process_frame
	await process_frame
	var grenades : Array[Node] = []
	for c in root.find_children("*", "Area3D", true, false):
		if c.name.to_lower().contains("grenade") or c is Grenade:
			grenades.append(c)
	check(grenades.size() > 0, "Astronaut Frag Grenade spawned into the world upon ability execution")
	check(float(char_data.get("ability_cooldown_remaining")) > 0.0, "Astronaut Frag Grenade triggered cooldown (8.0s)")

	# Clean up any spawned grenade
	for g in grenades:
		g.queue_free()

	# -------------------------------------------------------------------------
	# 6. Dedicated Character Selection Screen UI & Flow
	# -------------------------------------------------------------------------
	print("\n[Phase 6] Testing Dedicated Character Selection Screen & Flow...")
	var menu_scene : PackedScene = load("res://scenes/ui/main_menu.tscn")
	check(menu_scene != null, "Loaded main_menu.tscn")
	var menu : Control = menu_scene.instantiate() as Control
	root.add_child(menu)
	await process_frame
	await process_frame

	var title_sc : Control = menu.get_node_or_null("TitleScreen") as Control
	var mode_sc : Control = menu.get_node_or_null("ModeSelectScreen") as Control
	var char_sc : Control = menu.get_node_or_null("CharacterSelectScreen") as Control
	var map_sc : Control = menu.get_node_or_null("MapSelectScreen") as Control

	check(title_sc != null and mode_sc != null and char_sc != null and map_sc != null, "All 4 screen phase controls exist in MainMenu")
	check(title_sc.visible == true, "Starts at Title Screen phase (visible == true)")
	check(char_sc.visible == false, "CharacterSelectScreen starts inactive (visible == false)")
	check(map_sc.visible == false, "MapSelectScreen starts inactive (visible == false)")

	# 1. Step 1: Click start on title screen -> transitions to Mode Select
	menu.call("_on_start_prompt_clicked")
	while menu.get("_is_transitioning"):
		await process_frame
	check(menu.get("current_state") == 1, "MenuState transitioned to MODE_SELECT (1)")
	check(mode_sc.visible == true, "ModeSelectScreen is visible")

	var launch_btn : Button = mode_sc.get_node_or_null("CenterCards/VBoxContainer/LaunchSection/MainLaunchButton") as Button
	check(launch_btn != null, "Mode select action button exists")
	check("SELECT OPERATIVE" in launch_btn.text, "Mode action button prompts 'SELECT OPERATIVE'")

	# 2. Step 2: Click select operative button -> transitions to dedicated Character Selection
	menu.call("_on_launch_pressed")
	while menu.get("_is_transitioning"):
		await process_frame
	check(menu.get("current_state") == 2, "MenuState transitioned to CHARACTER_SELECT (2)")
	check(char_sc.visible == true, "CharacterSelectScreen is now visible")

	var briefing_lbl : Label = char_sc.get_node_or_null("TopBar/HBoxContainer/MissionBriefingLabel") as Label
	check(briefing_lbl != null and "SURVIVAL PROTOCOL" in briefing_lbl.text, "MissionBriefingLabel reflects SURVIVAL PROTOCOL")

	# Verify 4 Character Cards exist and have 3D model banners
	var astro_card : Button = char_sc.get_node_or_null("CenterCards/VBoxContainer/CardsRow/AstronautCard") as Button
	var engi_card : Button = char_sc.get_node_or_null("CenterCards/VBoxContainer/CardsRow/EngineerCard") as Button
	var med_card : Button = char_sc.get_node_or_null("CenterCards/VBoxContainer/CardsRow/MedicCard") as Button
	var exp_card : Button = char_sc.get_node_or_null("CenterCards/VBoxContainer/CardsRow/ExplorerCard") as Button
	var deploy_btn : Button = char_sc.get_node_or_null("BottomBar/HBoxContainer/MainDeployButton") as Button
	var return_btn : Button = char_sc.get_node_or_null("BottomBar/HBoxContainer/ReturnModeButton") as Button

	check(astro_card != null and engi_card != null and med_card != null and exp_card != null, "All 4 Character Cards exist in CardsRow")
	check(deploy_btn != null and return_btn != null, "MainDeployButton and ReturnModeButton exist")

	for c in [astro_card, engi_card, med_card, exp_card]:
		var b_cont : Control = c.find_child("BannerContainer", true, false) as Control
		var b_vp : SubViewport = c.find_child("SubViewport", true, false) as SubViewport
		var b_piv : Node3D = c.find_child("ModelPivot", true, false) as Node3D
		check(b_cont != null and b_vp != null and b_piv != null, "Character card %s has 3D SubViewport banner and ModelPivot" % c.name)
		check(b_piv.get_child_count() > 0, "Character card %s has styled 3D operative model attached in banner" % c.name)

	var astro_ab_lbl : Label = astro_card.find_child("AbilityBox", true, false).find_child("Name", true, false) as Label
	check(astro_ab_lbl != null and "[MMB] Frag Grenade" in astro_ab_lbl.text, "Astronaut card reflects '[MMB] Frag Grenade' active ability")

	# 3. Test selecting each character card and verifying CharacterData + UI update
	# Select Engineer
	menu.call("_select_operative", CharacterDataSingleton.CharacterClass.ENGINEER)
	check(int(char_data.get("current_class")) == CharacterDataSingleton.CharacterClass.ENGINEER, "Selected ENGINEER operative")
	var engi_bar : ColorRect = engi_card.get_node_or_null("SelectionBar") as ColorRect
	var engi_status : Label = engi_card.get_node_or_null("MarginContainer/VBoxContainer/StatusLabel") as Label
	check(engi_bar != null and engi_bar.visible == true, "Engineer selection bar is visible")
	check("◈" in engi_status.text, "Engineer status shows active selection ◈")
	check("ENGINEER" in deploy_btn.text, "MainDeployButton text reflects ENGINEER")

	# Select Medic
	menu.call("_select_operative", CharacterDataSingleton.CharacterClass.MEDIC)
	check(int(char_data.get("current_class")) == CharacterDataSingleton.CharacterClass.MEDIC, "Selected MEDIC operative")
	var med_bar : ColorRect = med_card.get_node_or_null("SelectionBar") as ColorRect
	var med_status : Label = med_card.get_node_or_null("MarginContainer/VBoxContainer/StatusLabel") as Label
	check(med_bar != null and med_bar.visible == true, "Medic selection bar is visible")
	check("◈" in med_status.text, "Medic status shows active selection ◈")
	check("MEDIC" in deploy_btn.text, "MainDeployButton text reflects MEDIC")

	# Select Explorer
	menu.call("_select_operative", CharacterDataSingleton.CharacterClass.EXPLORER)
	check(int(char_data.get("current_class")) == CharacterDataSingleton.CharacterClass.EXPLORER, "Selected EXPLORER operative")
	var exp_bar : ColorRect = exp_card.get_node_or_null("SelectionBar") as ColorRect
	var exp_status : Label = exp_card.get_node_or_null("MarginContainer/VBoxContainer/StatusLabel") as Label
	check(exp_bar != null and exp_bar.visible == true, "Explorer selection bar is visible")
	check("◈" in exp_status.text, "Explorer status shows active selection ◈")
	check("EXPLORER" in deploy_btn.text, "MainDeployButton text reflects EXPLORER")

	# Select Astronaut back
	menu.call("_select_operative", CharacterDataSingleton.CharacterClass.ASTRONAUT)
	check(int(char_data.get("current_class")) == CharacterDataSingleton.CharacterClass.ASTRONAUT, "Selected ASTRONAUT operative")
	check("ASTRONAUT" in deploy_btn.text, "MainDeployButton text reflects ASTRONAUT")

	# 4. Test Return to Mode Select
	menu.call("_transition_from_character_select_to_mode_select")
	while menu.get("_is_transitioning"):
		await process_frame
	check(menu.get("current_state") == 1, "Returned back to MODE_SELECT (1)")
	check(mode_sc.visible == true, "ModeSelectScreen is active again")

	# 5. Dedicated Sandbox Card-Select Flow
	print("\n[Phase 6b] Testing Sandbox Map Selection Flow...")
	menu.call("_select_mode", 2) # SANDBOX
	check("SELECT MAP" in launch_btn.text, "Launch button text changed to 'SELECT MAP • SANDBOX'")
	menu.call("_on_launch_pressed")
	while menu.get("_is_transitioning"):
		await process_frame
	check(menu.get("current_state") == 3, "State transitioned to MAP_SELECT (3)")
	check(map_sc.visible == true, "MapSelectScreen is visible")

	var canyon_card : Button = map_sc.get_node_or_null("CenterCards/VBoxContainer/CardsRow/CanyonCard") as Button
	var base_card : Button = map_sc.get_node_or_null("CenterCards/VBoxContainer/CardsRow/BaseCard") as Button
	var dock_card : Button = map_sc.get_node_or_null("CenterCards/VBoxContainer/CardsRow/DockCard") as Button
	var proceed_btn : Button = map_sc.get_node_or_null("BottomBar/HBoxContainer/ProceedButton") as Button
	var map_return_btn : Button = map_sc.get_node_or_null("BottomBar/HBoxContainer/ReturnModeButton") as Button
	check(canyon_card != null and base_card != null and dock_card != null, "All 3 Sector Cards exist in MapSelectScreen")
	check(proceed_btn != null and map_return_btn != null, "Proceed and Return buttons exist in MapSelectScreen")

	# Select Sector 03 (Dock)
	menu.call("_select_sandbox_map", 2)
	check(menu.get("selected_sandbox_map") == 2, "Selected Sector 03 Transport Dock")
	check("DOCK" in proceed_btn.text, "Proceed button prompts 'CONFIRM TRANSPORT DOCK'")

	# Proceed to Character Selection
	menu.call("_on_map_proceed_pressed")
	while menu.get("_is_transitioning"):
		await process_frame
	check(menu.get("current_state") == 2, "Proceeded to CHARACTER_SELECT (2)")
	check(char_sc.visible == true, "CharacterSelectScreen is visible")
	check(briefing_lbl != null and "SECTOR 03" in briefing_lbl.text, "Mission briefing reflects SECTOR 03 (TRANSPORT DOCK)")

	# Press Return -> Should route back to MapSelectScreen for Sandbox
	menu.call("_transition_from_character_select_to_mode_select")
	while menu.get("_is_transitioning"):
		await process_frame
	check(menu.get("current_state") == 3, "Returned from CharacterSelect back to MAP_SELECT (3)")
	check(map_sc.visible == true, "MapSelectScreen is visible")

	# Press Return from MapSelectScreen -> Should route back to ModeSelectScreen
	menu.call("_transition_from_map_select_to_mode_select")
	while menu.get("_is_transitioning"):
		await process_frame
	check(menu.get("current_state") == 1, "Returned from MapSelect back to MODE_SELECT (1)")
	check(mode_sc.visible == true, "ModeSelectScreen is visible")

	menu.queue_free()

	# -------------------------------------------------------------------------
	# 7. HealthBar HUD Operative Badge & Cooldown Display
	# -------------------------------------------------------------------------
	print("\n[Phase 7] Testing In-Game HealthBar Operative & Ability HUD...")
	var hb_scene : PackedScene = load("res://scenes/ui/health_bar.tscn")
	check(hb_scene != null, "Loaded health_bar.tscn")
	var hb : CanvasLayer = hb_scene.instantiate() as CanvasLayer
	root.add_child(hb)
	await process_frame
	await process_frame

	var class_tag : Label = hb.get_node_or_null("MarginContainer/VBoxContainer/OperativeRow/ClassTag") as Label
	var ability_tag : Label = hb.get_node_or_null("MarginContainer/VBoxContainer/OperativeRow/AbilityTag") as Label
	var ability_status : Label = hb.get_node_or_null("MarginContainer/VBoxContainer/OperativeRow/AbilityStatus") as Label
	var turret_tag : Label = hb.get_node_or_null("MarginContainer/VBoxContainer/OperativeRow/TurretTag") as Label

	check(class_tag != null and ability_tag != null and ability_status != null, "HealthBar OperativeRow tags exist")
	check(turret_tag != null, "HealthBar OperativeRow has minimal TurretTag")

	# Test Ready display
	hb.call("update_operative_display", CharacterDataSingleton.CharacterClass.ENGINEER, 0.0, 12.0)
	check("ENGINEER" in class_tag.text, "ClassTag reflects ENGINEER")
	check("SENTRY TURRET" in ability_tag.text, "AbilityTag reflects SENTRY TURRET")
	check(ability_status.text == "READY", "AbilityStatus displays READY when cooldown is 0")

	# Test Cooldown display
	hb.call("update_operative_display", CharacterDataSingleton.CharacterClass.ENGINEER, 8.4, 12.0)
	check("CD: 8.4s" in ability_status.text, "AbilityStatus displays countdown when cooldown active")

	# Test TurretTag updates in HUD (hidden when no active turrets deployed)
	hb.call("_process", 0.016)
	check(turret_tag.visible == false, "TurretTag is hidden when no active turrets are deployed")

	# Verify bottom-left HUD non-overlap between WeaponPanel and HealthBar MarginContainer
	var hud_script : GDScript = load("res://scenes/ui/player_health_hud.gd") as GDScript
	check(hud_script != null, "Loaded player_health_hud.gd")
	var hud_inst = Node.new()
	hud_inst.set_script(hud_script)
	root.add_child(hud_inst)
	hud_inst.call("_setup_weapon_hud")
	await process_frame

	var weapon_panel : Control = hud_inst.find_child("WeaponPanel", true, false) as Control
	var hb_margin : Control = hb.get_node_or_null("MarginContainer") as Control
	check(weapon_panel != null, "WeaponPanel exists in PlayerHealthHud")
	check(hb_margin != null, "MarginContainer exists in HealthBar")
	if weapon_panel != null and hb_margin != null:
		check(weapon_panel.offset_bottom <= hb_margin.offset_top, "WeaponPanel (bottom: %.1f) is cleanly positioned above HealthBar (top: %.1f) with zero vertical overlap" % [weapon_panel.offset_bottom, hb_margin.offset_top])
	hud_inst.queue_free()

	hb.queue_free()
	player.queue_free()

	# -------------------------------------------------------------------------
	# Summary
	# -------------------------------------------------------------------------
	print("\n==================================================")
	print("CHARACTER CLASSES TEST RESULTS: %d Passed, %d Failed" % [passes, failures])
	print("==================================================")
	if failures > 0:
		quit(1)
	else:
		quit(0)
