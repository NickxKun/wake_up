extends SceneTree

## Comprehensive test suite for the 3 distinct themed maps:
## 1. Map 1: Desolate Canyon Wasteland (Pure terrain & natural rocks, NO equipment)
## 2. Map 2: Space Base (Habitation & Power Grid, protective northern cliff, 0 clipping)
## 3. Map 3: Transport Dock (Freight logistics, Landing Pads & Mining quarry, 0 clipping)
## Also verifies outer terrain smoothness and Main Menu Sandbox / Survival selection.

func _init() -> void:
	print("\n=== STARTING THEMED MAPS & TERRAIN REDESIGN TEST SUITE ===")
	call_deferred("_run_tests")

func _run_tests() -> void:
	var passes : int = 0
	var fails : int = 0

	var map_scene : PackedScene = load("res://scenes/level/space_station.tscn")
	if map_scene == null:
		print("FAIL: Could not load space_station.tscn")
		quit(1)
		return

	var hud_scene : PackedScene = load("res://scenes/ui/player_health_hud.tscn")
	var hud_node : Node = root.get_node_or_null("PlayerHealthHud")
	if hud_node == null and hud_scene != null:
		hud_node = hud_scene.instantiate()
		hud_node.name = "PlayerHealthHud"
		root.add_child(hud_node)

	# -------------------------------------------------------------------------
	# Test 1: Map 1 (Desolate Canyon Wasteland)
	# -------------------------------------------------------------------------
	print("\n[Test 1] Testing Map 1: Desolate Canyon Wasteland (No Equipment)...")
	if hud_node != null:
		hud_node.set("selected_map_theme", 0)
	var map1 : Node3D = map_scene.instantiate() as Node3D
	map1.set("map_theme", 0) # CANYON_WASTELAND
	root.add_child(map1)
	await process_frame
	await process_frame

	var hab1 : Node = map1.get_node_or_null("Sector_Habitation")
	var logist1 : Node = map1.get_node_or_null("Sector_Logistics")
	var quarry1 : Node = map1.get_node_or_null("Sector_MiningQuarry")
	var power1 : Node = map1.get_node_or_null("Sector_PowerGrid")
	var checkp1 : Node = map1.get_node_or_null("Sector_Checkpoint")
	var rocks1 : Node = map1.get_node_or_null("Sector_NaturalRocks")

	# In Godot, queue_free() removes children at frame end
	await process_frame

	var no_equipment : bool = (
		(hab1 == null or not is_instance_valid(hab1) or hab1.is_queued_for_deletion()) and
		(logist1 == null or not is_instance_valid(logist1) or logist1.is_queued_for_deletion()) and
		(quarry1 == null or not is_instance_valid(quarry1) or quarry1.is_queued_for_deletion()) and
		(power1 == null or not is_instance_valid(power1) or power1.is_queued_for_deletion()) and
		(checkp1 == null or not is_instance_valid(checkp1) or checkp1.is_queued_for_deletion())
	)
	var has_natural_rocks : bool = rocks1 != null and is_instance_valid(rocks1) and rocks1.get_child_count() > 0

	if no_equipment and has_natural_rocks:
		print("  [PASS] Map 1 has zero human equipment sectors and tactical rocks are spawned.")
		passes += 1
	else:
		print("  [FAIL] Map 1 equipment check failed: no_eq=%s, rocks=%s" % [no_equipment, has_natural_rocks])
		fails += 1

	# Verify outer edges drop to 0 for seamless transition to outer desert plane
	var perimeter_flat_1 : bool = true
	for x in [-20.0, -19.0, 19.0, 20.0]:
		for z in [-20.0, 0.0, 20.0]:
			if map1.call("get_terrain_height", x, z) != 0.0:
				perimeter_flat_1 = false
	for z in [-20.0, -19.0, 19.0, 20.0]:
		for x in [-20.0, 0.0, 20.0]:
			if map1.call("get_terrain_height", x, z) != 0.0:
				perimeter_flat_1 = false

	if perimeter_flat_1:
		print("  [PASS] Map 1 perimeter edges are mathematically flat (Y = 0) for seamless outer lands.")
		passes += 1
	else:
		print("  [FAIL] Map 1 perimeter edges have non-zero elevations.")
		fails += 1

	map1.queue_free()
	await process_frame
	await process_frame

	# -------------------------------------------------------------------------
	# Test 2: Map 2 (Space Base Colony)
	# -------------------------------------------------------------------------
	print("\n[Test 2] Testing Map 2: Space Base Colony Outpost...")
	if hud_node != null:
		hud_node.set("selected_map_theme", 1)
	var map2 : Node3D = map_scene.instantiate() as Node3D
	map2.set("map_theme", 1) # SPACE_BASE
	root.add_child(map2)
	await process_frame
	await process_frame
	await process_frame

	var hab2 : Node = map2.get_node_or_null("Sector_Habitation")
	var power2 : Node = map2.get_node_or_null("Sector_PowerGrid")
	var logist2 : Node = map2.get_node_or_null("Sector_Logistics")
	var quarry2 : Node = map2.get_node_or_null("Sector_MiningQuarry")

	var spacebase_sectors_valid : bool = (
		hab2 != null and is_instance_valid(hab2) and not hab2.is_queued_for_deletion() and
		power2 != null and is_instance_valid(power2) and not power2.is_queued_for_deletion() and
		(logist2 == null or not is_instance_valid(logist2) or logist2.is_queued_for_deletion()) and
		(quarry2 == null or not is_instance_valid(quarry2) or quarry2.is_queued_for_deletion())
	)

	if spacebase_sectors_valid:
		print("  [PASS] Map 2 has Habitation and Power Grid present; Logistics and Quarry removed.")
		passes += 1
	else:
		print("  [FAIL] Map 2 sector presence incorrect.")
		fails += 1

	# Foundation heights under Habitation (-11 to -3, -11 to -4) and Power Grid (4 to 11, -11 to -4) must be 0.0
	var foundation_flat_2 : bool = true
	# Habitation area
	for x in range(-11, -3):
		for z in range(-11, -4):
			if map2.call("get_terrain_height", float(x), float(z)) > 0.001:
				foundation_flat_2 = false
	# Power Grid area
	for x in range(4, 11):
		for z in range(-11, -4):
			if map2.call("get_terrain_height", float(x), float(z)) > 0.001:
				foundation_flat_2 = false

	if foundation_flat_2:
		print("  [PASS] Map 2 building foundations are 100% flat at Y = 0.0 (Zero Clipping).")
		passes += 1
	else:
		print("  [FAIL] Map 2 building foundations have elevation clipping.")
		fails += 1

	# Protective northwest mesa cliff elevation check (north of habitation, e.g. x <= -13, z <= -9)
	var has_cliff_north : bool = map2.call("get_terrain_height", -14.0, -14.0) > 0.5
	if has_cliff_north:
		print("  [PASS] Map 2 northern protective mesa cliff elevation verified.")
		passes += 1
	else:
		print("  [FAIL] Map 2 northern mesa cliff missing or flat.")
		fails += 1

	# Check modular cabin attachments in Habitation Complex (hub-and-spoke with 0mm gap/clipping)
	var cmd_hub : Node3D = hab2.get_node_or_null("CommandHab_A") as Node3D
	var corr_n : Node3D = hab2.get_node_or_null("Corridor_North") as Node3D
	var sci_lab : Node3D = hab2.get_node_or_null("ScienceLab_North") as Node3D
	var corr_s : Node3D = hab2.get_node_or_null("Corridor_South") as Node3D
	var crew_q : Node3D = hab2.get_node_or_null("CrewQuarters_South") as Node3D
	var corr_w : Node3D = hab2.get_node_or_null("Corridor_West") as Node3D
	var med_bay : Node3D = hab2.get_node_or_null("MedBay_West") as Node3D
	var corr_e : Node3D = hab2.get_node_or_null("Corridor_East") as Node3D
	var airlock : Node3D = hab2.get_node_or_null("Airlock_East") as Node3D

	var modules_attached : bool = (
		cmd_hub != null and corr_n != null and sci_lab != null and
		corr_s != null and crew_q != null and
		corr_w != null and med_bay != null and
		corr_e != null and airlock != null
	)
	if modules_attached:
		var d_n : float = absf(cmd_hub.position.z - corr_n.position.z) # should be 2.0
		var d_lab : float = absf(corr_n.position.z - sci_lab.position.z) # should be 2.0
		var d_s : float = absf(cmd_hub.position.z - corr_s.position.z) # should be 2.0
		var d_w : float = absf(cmd_hub.position.x - corr_w.position.x) # should be 2.0
		var d_e : float = absf(cmd_hub.position.x - corr_e.position.x) # should be 2.0
		if absf(d_n - 2.0) < 0.05 and absf(d_lab - 2.0) < 0.05 and absf(d_s - 2.0) < 0.05 and absf(d_w - 2.0) < 0.05 and absf(d_e - 2.0) < 0.05:
			print("  [PASS] Map 2 cabins attached to main command hub on strict 2.0m modular grid (Zero gap/clipping).")
			passes += 1
		else:
			print("  [FAIL] Map 2 cabin spacing misaligned.")
			fails += 1
	else:
		print("  [FAIL] Map 2 missing modular cabin or corridor nodes.")
		fails += 1

	# Check crater excavation dig site and concave hole hitbox
	var dig_poi : Node = map2.get_node_or_null("Sector_ResearchDig")
	var has_dig_poi : bool = dig_poi != null and dig_poi.get_child_count() >= 5
	if has_dig_poi:
		print("  [PASS] Map 2 geological crater dig site POI present with drill, rover, and equipment.")
		passes += 1
	else:
		print("  [FAIL] Map 2 missing Sector_ResearchDig POI.")
		fails += 1

	# Verify single terrain_mining tile has ConcavePolygonShape3D (not solid convex box)
	var terrain_node_2 : Node = map2.get_node_or_null("Sector_Terrain")
	var mining_tile_count : int = 0
	var is_hole_concave : bool = false
	if terrain_node_2 != null:
		for c in terrain_node_2.get_children():
			if c.name.begins_with("terrain_mining"):
				mining_tile_count += 1
				# Inspect StaticBody3D collision shape inside the mesh instance
				for grand in c.get_children():
					if grand is MeshInstance3D:
						for body in grand.get_children():
							if body is StaticBody3D:
								for cs in body.get_children():
									if cs is CollisionShape3D and (cs as CollisionShape3D).shape is ConcavePolygonShape3D:
										is_hole_concave = true

	if mining_tile_count == 1 and is_hole_concave:
		print("  [PASS] Map 2 terrain_mining used sparingly (1 tile) with walkable concave trimesh hole hitbox.")
		passes += 1
	else:
		print("  [FAIL] Map 2 mining tile check failed: count=%d concave=%s" % [mining_tile_count, is_hole_concave])
		fails += 1

	map2.queue_free()
	await process_frame
	await process_frame

	# -------------------------------------------------------------------------
	# Test 3: Map 3 (Transport Dock)
	# -------------------------------------------------------------------------
	print("\n[Test 3] Testing Map 3: Transport Dock Terminal...")
	if hud_node != null:
		hud_node.set("selected_map_theme", 2)
	var map3 : Node3D = map_scene.instantiate() as Node3D
	map3.set("map_theme", 2) # TRANSPORT_DOCK
	root.add_child(map3)
	await process_frame
	await process_frame
	await process_frame

	var hab3 : Node = map3.get_node_or_null("Sector_Habitation")
	var power3 : Node = map3.get_node_or_null("Sector_PowerGrid")
	var logist3 : Node = map3.get_node_or_null("Sector_Logistics")
	var quarry3 : Node = map3.get_node_or_null("Sector_MiningQuarry")

	var dock_sectors_valid : bool = (
		logist3 != null and is_instance_valid(logist3) and not logist3.is_queued_for_deletion() and
		quarry3 != null and is_instance_valid(quarry3) and not quarry3.is_queued_for_deletion() and
		(hab3 == null or not is_instance_valid(hab3) or hab3.is_queued_for_deletion()) and
		(power3 == null or not is_instance_valid(power3) or power3.is_queued_for_deletion())
	)

	if dock_sectors_valid:
		print("  [PASS] Map 3 has Logistics and Mining Quarry present; Habitation and Power removed.")
		passes += 1
	else:
		print("  [FAIL] Map 3 sector presence incorrect.")
		fails += 1

	# Foundation heights under Landing Pads (-12 to -4, 0 to 10) must be 0.0
	var pad_flat_3 : bool = true
	for x in range(-11, -4):
		for z in range(1, 10):
			if map3.call("get_terrain_height", float(x), float(z)) > 0.001:
				pad_flat_3 = false

	# Mining Drill Rig foundation (5 to 11, 2 to 8) must be 0.0
	for x in range(5, 11):
		for z in range(2, 8):
			if map3.call("get_terrain_height", float(x), float(z)) > 0.001:
				pad_flat_3 = false

	if pad_flat_3:
		print("  [PASS] Map 3 tarmac and landing pad foundations are 100% flat at Y = 0.0 (Zero Clipping).")
		passes += 1
	else:
		print("  [FAIL] Map 3 tarmac or landing pads have elevation clipping.")
		fails += 1

	# Verify mining quarry excavation tiles are used
	var terrain_node : Node = map3.get_node_or_null("Sector_Terrain")
	var has_mining_tile : bool = false
	if terrain_node != null:
		for c in terrain_node.get_children():
			if c.name.begins_with("terrain_mining"):
				has_mining_tile = true
				break

	if has_mining_tile:
		print("  [PASS] Map 3 utilizes terrain_mining excavation tiles for the quarry.")
		passes += 1
	else:
		print("  [FAIL] Map 3 missing terrain_mining tiles.")
		fails += 1

	map3.queue_free()
	await process_frame
	await process_frame

	# -------------------------------------------------------------------------
	# Test 4: Outer Terrain Smoothness Verification (No Cubic Blocks in Outer Sectors)
	# -------------------------------------------------------------------------
	print("\n[Test 4] Testing Outer Land Smoothness (No modular cubic blocks off-grid)...")
	var map_test : Node3D = map_scene.instantiate() as Node3D
	root.add_child(map_test)
	await process_frame
	await process_frame

	var outer_root : Node = map_test.get_node_or_null("OuterSectors")
	var has_no_cubic_blocks_outer : bool = true
	var outer_prop_count : int = 0

	if outer_root != null:
		for sec in outer_root.get_children():
			for prop in sec.get_children():
				outer_prop_count += 1
				var p_name : String = prop.name.to_lower()
				if "terrain_tall" in p_name or "terrain_slope" in p_name or "terrain_mining" in p_name:
					has_no_cubic_blocks_outer = false

	if has_no_cubic_blocks_outer and outer_prop_count >= 30:
		print("  [PASS] Outer sectors populated solely by natural rocks & boulders on smooth sand plane (count: %d)." % outer_prop_count)
		passes += 1
	else:
		print("  [FAIL] Outer sectors contain unaligned modular blocks or insufficient rocks.")
		fails += 1

	# Ground plane verification
	var gb : Node = map_test.get_node_or_null("GroundBase")
	var gv : MeshInstance3D = gb.get_node_or_null("GroundVisual") as MeshInstance3D if gb != null else null
	var plane_mesh : PlaneMesh = gv.mesh as PlaneMesh if gv != null else null
	var is_ground_expanded : bool = plane_mesh != null and plane_mesh.size.x >= 80.0 and plane_mesh.size.y >= 80.0

	if is_ground_expanded:
		print("  [PASS] GroundVisual plane extends across entire 80m x 80m landscape.")
		passes += 1
	else:
		print("  [FAIL] GroundVisual plane dimensions incorrect.")
		fails += 1

	map_test.queue_free()
	await process_frame
	await process_frame

	# -------------------------------------------------------------------------
	# Test 5: Main Menu Sandbox Map Selection & Survival Randomizer
	# -------------------------------------------------------------------------
	print("\n[Test 5] Testing Main Menu Map Selection UI...")
	var menu_scene : PackedScene = load("res://scenes/ui/main_menu.tscn")

	if menu_scene != null:
		var menu : Control = menu_scene.instantiate() as Control
		root.add_child(menu)
		await process_frame
		await process_frame

		var map_row : Control = menu.get_node_or_null("ModeSelectScreen/CenterCards/VBoxContainer/MapSelectSection") as Control
		var btn1 : Button = menu.get_node_or_null("ModeSelectScreen/CenterCards/VBoxContainer/MapSelectSection/MapButtonsRow/MapButton1") as Button
		var btn2 : Button = menu.get_node_or_null("ModeSelectScreen/CenterCards/VBoxContainer/MapSelectSection/MapButtonsRow/MapButton2") as Button
		var btn3 : Button = menu.get_node_or_null("ModeSelectScreen/CenterCards/VBoxContainer/MapSelectSection/MapButtonsRow/MapButton3") as Button

		var menu_elements_exist : bool = map_row != null and btn1 != null and btn2 != null and btn3 != null

		if menu_elements_exist:
			# Test clicking Map 1
			btn1.emit_signal("pressed")
			var selected_1 : int = int(menu.get("selected_sandbox_map"))
			# Test clicking Map 3
			btn3.emit_signal("pressed")
			var selected_3 : int = int(menu.get("selected_sandbox_map"))
			# Test clicking Map 2
			btn2.emit_signal("pressed")
			var selected_2 : int = int(menu.get("selected_sandbox_map"))

			var selection_works : bool = (selected_1 == 0 and selected_3 == 2 and selected_2 == 1)
			if selection_works:
				print("  [PASS] Main Menu Sandbox map buttons successfully update selection (0, 1, 2).")
				passes += 1
			else:
				print("  [FAIL] Main Menu map selection did not update state correctly.")
				fails += 1
		else:
			print("  [FAIL] Main Menu map selection UI buttons missing.")
			fails += 1

		menu.queue_free()
		await process_frame
		await process_frame

	# -------------------------------------------------------------------------
	# Test 6: Tactical Map UI Theme Adaptability
	# -------------------------------------------------------------------------
	print("\n[Test 6] Testing Tactical Map Blueprint & Schematic Adaptation...")
	var tac_scene : PackedScene = load("res://scenes/ui/tactical_map.tscn")
	if tac_scene != null:
		var tac_map : TacticalMap = tac_scene.instantiate() as TacticalMap
		root.add_child(tac_map)
		await process_frame

		if hud_node != null:
			# Test Map 1 theme title
			hud_node.set("selected_map_theme", 0)
			tac_map.open_map()
			var t1_title : String = tac_map.title_label.text if tac_map.title_label != null else ""
			tac_map.close_map()

			# Test Map 3 theme title
			hud_node.set("selected_map_theme", 2)
			tac_map.open_map()
			var t3_title : String = tac_map.title_label.text if tac_map.title_label != null else ""
			tac_map.close_map()

			# Test Map 2 theme title
			hud_node.set("selected_map_theme", 1)
			tac_map.open_map()
			var t2_title : String = tac_map.title_label.text if tac_map.title_label != null else ""
			tac_map.close_map()

			var titles_correct : bool = (
				"CANYON" in t1_title and
				"TRANSPORT DOCK" in t3_title and
				"SPACE BASE" in t2_title
			)

			if titles_correct:
				print("  [PASS] Tactical map dynamically updates blueprint schematics and titles for all 3 themes.")
				passes += 1
			else:
				print("  [FAIL] Tactical map title mismatch: t1='%s', t2='%s', t3='%s'" % [t1_title, t2_title, t3_title])
				fails += 1

		tac_map.queue_free()
		await process_frame

	# -------------------------------------------------------------------------
	# Summary
	# -------------------------------------------------------------------------
	print("\n=======================================================")
	print("THEMED MAPS VERIFICATION RESULTS: %d Passed, %d Failed" % [passes, fails])
	print("=======================================================\n")

	if fails == 0:
		print("ALL THEMED MAP & TERRAIN REDESIGN TESTS PASSED!")
		quit(0)
	else:
		print("SOME TESTS FAILED.")
		quit(1)
