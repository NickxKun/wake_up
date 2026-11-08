extends SceneTree

## Comprehensive test suite for the redesigned maps and bespoke landmarks:
## Map 1: Canyon Wasteland (Natural Sandstone Arch Bridge & Hoodoos)
## Map 2: Space Base (Satellite Communications Dish & Pipeline Conduits)
## Map 3: Transport Dock (Heavy Orbital Gantry Crane & Cryo Fuel Depot)

const HoodooPillarScript : Script = preload("res://scenes/level/landmarks/hoodoo_pillar.gd")
const NaturalArchScript : Script = preload("res://scenes/level/landmarks/natural_arch.gd")
const SatelliteDishScript : Script = preload("res://scenes/level/landmarks/satellite_dish.gd")
const PipelineSystemScript : Script = preload("res://scenes/level/landmarks/pipeline_system.gd")
const GantryCraneScript : Script = preload("res://scenes/level/landmarks/gantry_crane.gd")
const FuelDepotScript : Script = preload("res://scenes/level/landmarks/fuel_depot.gd")

var passed_count : int = 0
var failed_count : int = 0

func _init() -> void:
	print("\n=== STARTING REDESIGNED MAPS & BESPOKE LANDMARKS VERIFICATION SUITE ===")
	_run_tests.call_deferred()

func check(condition: bool, test_name: String) -> void:
	if condition:
		passed_count += 1
		print("  [PASS] %s" % test_name)
	else:
		failed_count += 1
		print("  [FAIL] %s" % test_name)

func _run_tests() -> void:
	var root : Window = get_root()

	var map_scene : PackedScene = load("res://scenes/level/space_station.tscn")
	check(map_scene != null, "space_station.tscn loads successfully")

	# =========================================================================
	# Test 1: Map 1 (Canyon Wasteland) Redesign & Landmarks
	# =========================================================================
	print("\n[Test 1] Testing Map 1 (Canyon Wasteland) Arch, Hoodoos & Tactical Layout...")
	var hud : Node = root.get_node_or_null("PlayerHealthHud")
	if hud != null:
		hud.set("selected_map_theme", 0)
	var map1 : SpaceStationMap = map_scene.instantiate() as SpaceStationMap
	map1.map_theme = SpaceStationMap.MapTheme.CANYON_WASTELAND
	root.add_child(map1)
	for i in range(5):
		await process_frame

	var rocks_root : Node = map1.get_node_or_null("Sector_NaturalRocks")
	check(rocks_root != null, "Sector_NaturalRocks exists on Canyon Wasteland")

	var arch : Node = rocks_root.get_node_or_null("NaturalSandstoneArch") if rocks_root else null
	check(arch != null, "NaturalSandstoneArch exists spanning canyon gorge")
	if arch != null:
		var arch_mesh : MeshInstance3D = arch.get_node_or_null("ArchMesh") as MeshInstance3D
		check(arch_mesh != null and arch_mesh.mesh != null, "NaturalSandstoneArch has valid SurfaceTool ArrayMesh")
		var has_arch_col : bool = false
		for c in arch_mesh.get_children():
			if c is StaticBody3D:
				has_arch_col = true
				break
		check(has_arch_col, "NaturalSandstoneArch has walkable trimesh StaticBody collision")

	# Check Hoodoo Pillars
	var hoodoo_count : int = 0
	if rocks_root != null:
		for c in rocks_root.get_children():
			if c.get_script() == HoodooPillarScript:
				hoodoo_count += 1
				var sb : StaticBody3D = c.get_node_or_null("HoodooStaticBody") as StaticBody3D
				check(sb != null and sb.collision_layer == 1, "HoodooPillar has StaticBody3D on layer 1")
	check(hoodoo_count >= 6, "At least 6 HoodooPillar spires spawned along canyon rim (count: %d)" % hoodoo_count)

	# Check weapons box in central amphitheater
	var wbox1 : Node = map1.get_node_or_null("WeaponsBox")
	if wbox1 == null:
		# Could be direct child with generated name or in group
		var boxes := root.get_tree().get_nodes_in_group("weapons_box")
		wbox1 = boxes[0] if not boxes.is_empty() else null
	check(wbox1 != null, "WeaponsBox spawned cleanly on Map 1")
	if wbox1 is Node3D:
		var wb3d := wbox1 as Node3D
		check(wb3d.position.distance_to(Vector3(0.0, 0.0, 2.5)) < 1.0, "WeaponsBox located in open amphitheater at (0, 2.5)")

	# Check targets
	var targets_root : Node = map1.get_node_or_null("MapTrainingTargets")
	check(targets_root != null and targets_root.get_child_count() == 6, "6 Tactical armor-regen targets spawned on Map 1")

	map1.queue_free()
	for i in range(5):
		await process_frame

	# =========================================================================
	# Test 2: Map 2 (Space Base) Redesign & Landmarks
	# =========================================================================
	print("\n[Test 2] Testing Map 2 (Space Base) Satellite Dish & Industrial Pipelines...")
	if hud != null:
		hud.set("selected_map_theme", 1)
	var map2 : SpaceStationMap = map_scene.instantiate() as SpaceStationMap
	map2.map_theme = SpaceStationMap.MapTheme.SPACE_BASE
	root.add_child(map2)
	for i in range(5):
		await process_frame

	var dig_root : Node = map2.get_node_or_null("Sector_ResearchDig")
	check(dig_root != null, "Sector_ResearchDig exists on Space Base")

	var dish : Node = dig_root.get_node_or_null("OutpostSatelliteDish") if dig_root else null
	check(dish != null, "OutpostSatelliteDish exists on northern observation bluff")
	if dish != null:
		var dish_sb : StaticBody3D = dish.get_node_or_null("DishStaticBody") as StaticBody3D
		check(dish_sb != null, "SatelliteDish has DishStaticBody collision")
		var dish_head : Node = dish.get_node_or_null("DishHead")
		check(dish_head != null, "SatelliteDish has articulated DishHead node")
		var beacon : OmniLight3D = dish_head.get_node_or_null("TransceiverBeacon") as OmniLight3D if dish_head else null
		check(beacon != null and beacon.light_color.b > 0.8, "SatelliteDish has pulsing cyan transceiver beacon light")

	# Check pipelines
	var pipe_main : Node = dig_root.get_node_or_null("Pipeline_HabToPower") if dig_root else null
	var pipe_quarry : Node = dig_root.get_node_or_null("Pipeline_PowerToQuarry") if dig_root else null
	check(pipe_main != null, "Pipeline_HabToPower conduit exists")
	check(pipe_quarry != null, "Pipeline_PowerToQuarry conduit exists")
	if pipe_main != null:
		var psb : StaticBody3D = pipe_main.get_node_or_null("PipelineStaticBody") as StaticBody3D
		check(psb != null, "PipelineSystem has PipelineStaticBody collider")

	map2.queue_free()
	for i in range(5):
		await process_frame

	# =========================================================================
	# Test 3: Map 3 (Transport Dock) Redesign & Landmarks
	# =========================================================================
	print("\n[Test 3] Testing Map 3 (Transport Dock) Heavy Gantry Crane & Fuel Depot...")
	if hud != null:
		hud.set("selected_map_theme", 2)
	var map3 : SpaceStationMap = map_scene.instantiate() as SpaceStationMap
	map3.map_theme = SpaceStationMap.MapTheme.TRANSPORT_DOCK
	root.add_child(map3)
	for i in range(5):
		await process_frame

	var dock_root : Node = map3.get_node_or_null("Sector_DockLogistics")
	check(dock_root != null, "Sector_DockLogistics exists on Transport Dock")

	var crane : Node = dock_root.get_node_or_null("HeavyOrbitalGantryCrane") if dock_root else null
	check(crane != null, "HeavyOrbitalGantryCrane exists spanning freight apron")
	if crane != null:
		# Check A-frame leg collisions
		var leg_count : int = 0
		var has_container_sb : bool = false
		for c in crane.get_children():
			if c is StaticBody3D:
				leg_count += 1
				if c.position.y > 1.5:
					has_container_sb = true
		check(leg_count >= 2, "GantryCrane has solid A-frame leg StaticBody collisions (count: %d)" % leg_count)
		check(has_container_sb, "GantryCrane has suspended shipping container with tactical elevated collision")

	var fuel_depot : Node = dock_root.get_node_or_null("CryoFuelDepot") if dock_root else null
	check(fuel_depot != null, "CryoFuelDepot propellant tanks exist adjacent to shuttle pads")
	if fuel_depot != null:
		var fsb : StaticBody3D = fuel_depot.get_node_or_null("FuelDepotStaticBody") as StaticBody3D
		check(fsb != null, "CryoFuelDepot has FuelDepotStaticBody collision")

	map3.queue_free()
	for i in range(5):
		await process_frame

	print("\n=======================================================")
	print("RESULTS: %d Passed, %d Failed" % [passed_count, failed_count])
	print("=======================================================")
	if failed_count == 0:
		print("ALL REDESIGNED MAPS & BESPOKE LANDMARKS TESTS PASSED!")
		quit(0)
	else:
		quit(1)
