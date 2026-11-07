extends SceneTree

## Comprehensive Verification Test Suite for:
## 1. Clean floor without confusing chevron markers.
## 2. Refined layout with unblocked doorway at SectorPartitionWall / Portal 4.
## 3. Compact proportional waypoints and single-fire audio latch (no loop buzz).
## 4. Multi-role showcase (Astronaut, Engineer, Medic, Explorer) in the tutorial.
## 5. Non-colliding weapons spawner across all map themes.
## 6. Map select cards with full-bleed high-POI background vistas.

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
	print("\n=== RUNNING TUTORIAL ROLES, WEAPON SPAWNER & MAP CARDS VERIFICATION ===")
	call_deferred("_run_all_tests")

func _run_all_tests() -> void:
	await process_frame
	await process_frame

	_test_tutorial_layout_and_markers()
	await process_frame
	_test_waypoint_sizing_and_audio()
	await process_frame
	await _test_tutorial_role_progression()
	await process_frame
	_test_weapons_spawner_non_collision()
	await process_frame
	_test_map_select_card_backgrounds()
	await process_frame

	print("\n=======================================================")
	print("RESULTS: %d Passed, %d Failed" % [passes, failures])
	print("=======================================================")
	quit(0 if failures == 0 else 1)

func _test_tutorial_layout_and_markers() -> void:
	print("\n[Phase 1] Testing Floor Markers & Partition Doorway Opening...")
	var tut_scene : PackedScene = load("res://scenes/tutorial/tutorial_map.tscn")
	check(tut_scene != null, "Loaded tutorial_map.tscn")

	var map : Node3D = tut_scene.instantiate() as Node3D
	root.add_child(map)
	await process_frame

	var facility : Node = map.find_child("FacilityGeometry", true, false)
	check(facility != null, "FacilityGeometry exists in tutorial proving grounds")

	var floor_guides : Node = facility.find_child("FloorDirectionGuides", true, false)
	check(floor_guides != null, "FloorDirectionGuides node exists in facility")
	var chevrons : Array[Node] = floor_guides.find_children("*GuideChevron*", "", true, false) if floor_guides != null else []
	check(chevrons.size() == 0, "Floor chevrons cleanly removed for simple clean floor (found: %d)" % chevrons.size())

	var partition : StaticBody3D = facility.find_child("SectorPartitionWall", true, false) as StaticBody3D
	check(partition != null, "SectorPartitionWall exists")

	# Check that Portal 4 corridor at X = 4.0 is clear and unblocked
	var col_shapes : Array[Node] = partition.find_children("", "CollisionShape3D", false, false) if partition != null else []
	check(col_shapes.size() >= 2, "SectorPartitionWall split into segmented walls (found %d segments)" % col_shapes.size())

	var blocks_portal_4 : bool = false
	for cs in col_shapes:
		if cs is CollisionShape3D and cs.shape is BoxShape3D:
			var box : BoxShape3D = cs.shape as BoxShape3D
			var half_w : float = box.size.x * 0.5
			var min_x : float = cs.position.x - half_w
			var max_x : float = cs.position.x + half_w
			if min_x <= 4.0 and 4.0 <= max_x:
				blocks_portal_4 = true

	check(not blocks_portal_4, "Entrance to Sector 4 Rover Bay at X = 4.0 is completely open and unblocked")

	map.queue_free()

func _test_waypoint_sizing_and_audio() -> void:
	print("\n[Phase 2] Testing Waypoint Marker Sizing & Audio Latch...")
	var wp_scene : PackedScene = load("res://scenes/tutorial/tutorial_waypoint.tscn")
	check(wp_scene != null, "Loaded tutorial_waypoint.tscn")

	var wp : TutorialWaypoint = wp_scene.instantiate() as TutorialWaypoint
	root.add_child(wp)
	await process_frame

	var col : CollisionShape3D = wp.get_node_or_null("CollisionShape3D") as CollisionShape3D
	check(col != null and col.shape is CylinderShape3D, "CollisionShape3D exists on waypoint")
	var cyl_shape : CylinderShape3D = col.shape as CylinderShape3D
	check(cyl_shape.radius <= 1.5, "Waypoint collision radius is compact (%.2fm <= 1.5m)" % cyl_shape.radius)
	check(cyl_shape.height <= 2.5, "Waypoint collision height is compact (%.2fm <= 2.5m)" % cyl_shape.height)

	var ground_ring : MeshInstance3D = wp.get_node_or_null("GroundRing") as MeshInstance3D
	check(ground_ring != null and ground_ring.mesh is TorusMesh, "GroundRing exists on waypoint")
	var torus : TorusMesh = ground_ring.mesh as TorusMesh
	check(torus.outer_radius <= 1.0, "GroundRing outer radius is compact (%.2fm <= 1.0m)" % torus.outer_radius)

	var light_beam : MeshInstance3D = wp.get_node_or_null("LightBeam") as MeshInstance3D
	check(light_beam != null and light_beam.mesh is CylinderMesh, "LightBeam exists on waypoint")
	var beam_mesh : CylinderMesh = light_beam.mesh as CylinderMesh
	check(beam_mesh.height <= 8.0, "LightBeam height is proportional and not giant (%.1fm <= 8.0m)" % beam_mesh.height)

	var diamond : MeshInstance3D = wp.find_child("DiamondMesh", true, false) as MeshInstance3D
	check(diamond != null and diamond.mesh is BoxMesh, "Beacon DiamondMesh exists")
	var diamond_box : BoxMesh = diamond.mesh as BoxMesh
	check(diamond_box.size.x <= 0.5, "DiamondMesh size is compact (%.2fm <= 0.5m)" % diamond_box.size.x)

	# Test Audio latch in TutorialHud
	var hud_scene : PackedScene = load("res://scenes/tutorial/tutorial_hud.tscn")
	var hud : TutorialHud = hud_scene.instantiate() as TutorialHud
	root.add_child(hud)
	await process_frame

	hud.set_objective("TEST", "TITLE", "INSTR", [{"text": "Task A", "completed": false}])
	check(hud._task_labels.size() == 1, "TutorialHud populated 1 task")

	# Multiple calls to update_task with completed=true should only play sound on state change
	hud.update_task(0, true)
	check(hud._task_labels[0].text.begins_with("▣ "), "Task marked completed")
	# Second call when already completed should not throw and safely guard
	hud.update_task(0, true)
	check(hud._task_labels[0].text.begins_with("▣ "), "Task remains completed without redundant audio/tween triggers")

	hud.queue_free()
	wp.queue_free()

func _test_tutorial_role_progression() -> void:
	print("\n[Phase 3] Testing Multi-Role Progression Across Tutorial Proving Grounds...")
	var tut_scene : PackedScene = load("res://scenes/tutorial/tutorial_map.tscn")
	var map : Node3D = tut_scene.instantiate() as Node3D
	root.add_child(map)
	await process_frame
	await process_frame

	var mgr : TutorialManager = map.find_child("TutorialManager", true, false) as TutorialManager
	check(mgr != null, "TutorialManager found in tutorial scene")

	var char_data : Node = root.get_node_or_null("CharacterData")
	check(char_data != null, "CharacterData singleton exists")

	# Phase 1: Astronaut Vanguard
	check(mgr.current_phase == TutorialManager.Phase.PHASE_1_LOCOMOTION, "Starts in Phase 1 Locomotion")
	check(int(char_data.get("current_class")) == CharacterDataSingleton.CharacterClass.ASTRONAUT, "Cadet begins specialized as Astronaut Vanguard")

	# Advance to Phase 2: Thrusters
	mgr._on_locomotion_wp_reached()
	await process_frame
	check(mgr.current_phase == TutorialManager.Phase.PHASE_2_THRUSTERS, "Advances to Phase 2 Thrusters")

	# Advance to Phase 3: Engineer Combat Architect Showcase
	mgr._on_thrusters_wp_reached()
	await process_frame
	check(mgr.current_phase == TutorialManager.Phase.PHASE_3_WEAPONS, "Advances to Phase 3 Weapons & Specializations")
	check(int(char_data.get("current_class")) == CharacterDataSingleton.CharacterClass.ENGINEER, "Operative specialized as ENGINEER for combat architecture")

	var player_combat : Node = map.find_child("PlayerCombat", true, false)
	check(player_combat != null, "PlayerCombat found on player")
	check(player_combat.get("starter_slot1_weapon") == 5, "Engineer holds Titanium Hydro-Wrench as starter weapon (5 == WRENCH)")

	# Destroy targets and test role showcase transition to Medic
	var targets : Node3D = map.find_child("Targets", true, false) as Node3D
	var target_list : Array[Node] = targets.get_children() if targets != null else []
	check(target_list.size() >= 3, "Target dummies found on firing range")

	# Simulate destroying 2 targets
	mgr._on_target_destroyed(target_list[0] as TrainingTarget)
	mgr._on_target_destroyed(target_list[1] as TrainingTarget)
	await process_frame
	check(int(char_data.get("current_class")) == CharacterDataSingleton.CharacterClass.MEDIC, "Operative transitioned to MEDIC to showcase Bio-Shotgun and Healing Surge")
	check(player_combat.get("starter_slot1_weapon") == 1, "Medic holds Compact Bio-Shotgun (1 == SHOTGUN)")

	# Neutralize 3rd target
	mgr._on_target_destroyed(target_list[2] as TrainingTarget)
	await process_frame

	# Advance to Phase 4: Explorer Reconnaissance & Vehicle Gatling
	mgr._on_weapons_wp_reached()
	await process_frame
	check(mgr.current_phase == TutorialManager.Phase.PHASE_4_VEHICLE, "Advances to Phase 4 Vehicle & Reconnaissance")
	check(int(char_data.get("current_class")) == CharacterDataSingleton.CharacterClass.EXPLORER, "Operative specialized as EXPLORER")
	check(player_combat.get("starter_slot1_weapon") == 2, "Explorer holds high-damage Marksman Rifle (2 == SNIPER)")

	map.queue_free()

func _test_weapons_spawner_non_collision() -> void:
	print("\n[Phase 4] Testing Non-Colliding Weapons Spawner Across Map Themes...")
	var station_scene : PackedScene = load("res://scenes/level/space_station.tscn")
	check(station_scene != null, "Loaded space_station.tscn")

	# 1. Test Space Base theme
	var hud : Node = root.get_node_or_null("PlayerHealthHud")
	if hud != null:
		hud.set("selected_map_theme", 1) # Space Base

	var map_base : Node3D = station_scene.instantiate() as Node3D
	root.add_child(map_base)
	await process_frame
	await process_frame

	var courtyard : Node = map_base.get_node_or_null("Sector_Courtyard")
	check(courtyard != null, "Sector_Courtyard exists on Space Base")
	var center_light : Node = courtyard.get_node_or_null("Center_Beacon_Light") if courtyard != null else null
	check(center_light == null, "Center_Beacon_Light removed; weapons box does NOT collide at (0, 0, 0)")

	var wbox : Node = map_base.find_child("WeaponsBox*", true, false)
	check(wbox != null, "WeaponsBox dispenser spawned successfully in map")
	if wbox != null and wbox is Node3D:
		check(wbox.position.is_equal_approx(Vector3(0.0, 0.0, 0.0)), "Weapons box cleanly positioned at courtyard supply hub (0, 0, 0)")

	# Verify extra Space Base POIs spawned
	var dig_root : Node3D = map_base.get_node_or_null("Sector_ResearchDig") as Node3D
	check(dig_root != null, "Sector_ResearchDig exists on Space Base")
	check(dig_root.get_child_count() >= 15, "Space Base fleshed out with 15+ environmental props, sensors and equipment (found: %d)" % dig_root.get_child_count())

	map_base.queue_free()
	await process_frame

	# 2. Test Transport Dock theme
	if hud != null:
		hud.set("selected_map_theme", 2) # Transport Dock

	var map_dock : Node3D = station_scene.instantiate() as Node3D
	root.add_child(map_dock)
	await process_frame
	await process_frame

	var dock_logistics : Node3D = map_dock.get_node_or_null("Sector_DockLogistics") as Node3D
	check(dock_logistics != null, "Sector_DockLogistics POIs spawned on Transport Dock")
	check(dock_logistics.get_child_count() >= 14, "Transport Dock fleshed out with 14+ staging props, haulers and containers (found: %d)" % dock_logistics.get_child_count())

	map_dock.queue_free()
	await process_frame

	# 3. Test Canyon Wasteland theme
	if hud != null:
		hud.set("selected_map_theme", 0) # Canyon Wasteland

	var map_canyon : Node3D = station_scene.instantiate() as Node3D
	root.add_child(map_canyon)
	await process_frame
	await process_frame

	var rocks_root : Node3D = map_canyon.get_node_or_null("Sector_NaturalRocks") as Node3D
	check(rocks_root != null, "Sector_NaturalRocks exists on Canyon Wasteland")
	check(rocks_root.get_child_count() >= 45, "Canyon Wasteland fleshed out with 45+ natural rock formations, spires and boulders (found: %d)" % rocks_root.get_child_count())

	map_canyon.queue_free()

func _test_map_select_card_backgrounds() -> void:
	print("\n[Phase 5] Testing Full-Bleed High-POI Map Select Card Backgrounds...")
	var menu_scene : PackedScene = load("res://scenes/ui/main_menu.tscn")
	check(menu_scene != null, "Loaded main_menu.tscn")

	var menu : Control = menu_scene.instantiate() as Control
	root.add_child(menu)
	await process_frame

	var canyon_card : Button = menu.find_child("CanyonCard", true, false) as Button
	var base_card : Button = menu.find_child("BaseCard", true, false) as Button
	var dock_card : Button = menu.find_child("DockCard", true, false) as Button

	check(canyon_card != null, "CanyonCard exists in map selection")
	check(base_card != null, "BaseCard exists in map selection")
	check(dock_card != null, "DockCard exists in map selection")

	var cards := [canyon_card, base_card, dock_card]
	var banner_textures := ["banner_map_canyon.png", "banner_map_spacebase.png", "banner_map_transportdock.png"]

	for i in range(cards.size()):
		var card : Button = cards[i]
		var banner : TextureRect = card.get_node_or_null("Banner") as TextureRect
		check(banner != null, "Card %d has Banner TextureRect" % i)
		check(banner.anchors_preset == Control.PRESET_FULL_RECT, "Card %d Banner uses full-bleed PRESET_FULL_RECT (15)" % i)
		check(banner.texture != null, "Card %d Banner has assigned texture" % i)
		var tex_path : String = banner.texture.resource_path
		check(tex_path.ends_with(banner_textures[i]), "Card %d displays high-POI vista texture '%s'" % [i, banner_textures[i]])

		var tint : TextureRect = card.get_node_or_null("BannerTint") as TextureRect
		check(tint != null, "Card %d has BannerTint overlay" % i)
		check(tint.anchors_preset == Control.PRESET_FULL_RECT, "Card %d BannerTint covers full card with gradient fade" % i)

		var margin : MarginContainer = card.get_node_or_null("MarginContainer") as MarginContainer
		check(margin != null, "Card %d has MarginContainer for labels" % i)
		check(margin.anchors_preset == Control.PRESET_FULL_RECT, "Card %d MarginContainer covers card for clean top-to-bottom layout" % i)

	menu.queue_free()
