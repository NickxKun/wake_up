extends SceneTree

var passed_count : int = 0
var failed_count : int = 0

func _init() -> void:
	print("\n=== RUNNING FLASHLIGHT & MAP VISTAS VERIFICATION TESTS ===")
	_run_tests.call_deferred()

func _assert_test(condition: bool, test_name: String) -> void:
	if condition:
		passed_count += 1
		print("  [PASS] %s" % test_name)
	else:
		failed_count += 1
		print("  [FAIL] %s" % test_name)

func _run_tests() -> void:
	var root : Window = get_root()

	# -------------------------------------------------------------------------
	# 1. Explorer Flashlight Clean Light Verification
	# -------------------------------------------------------------------------
	print("\n--- 1. Testing Explorer Flashlight Configuration ---")
	var char_vis_script : Script = load("res://scenes/player/character_visuals.gd") as Script
	_assert_test(char_vis_script != null, "CharacterVisuals script loads successfully")

	# Build Explorer visuals (Operative Class 3) using create_styled_character_model
	var explorer_model : Node3D = null
	if char_vis_script != null:
		explorer_model = char_vis_script.call("create_styled_character_model", 3) as Node3D

	_assert_test(explorer_model != null, "Explorer model created successfully")
	if explorer_model != null:
		root.add_child(explorer_model)
		await process_frame

		# Find flashlight fixtures
		var left_fixture : Node3D = explorer_model.find_child("FlashlightFixture_L", true, false) as Node3D
		var right_fixture : Node3D = explorer_model.find_child("FlashlightFixture_R", true, false) as Node3D
		_assert_test(left_fixture != null, "FlashlightFixture_L exists on Explorer backpack")
		_assert_test(right_fixture != null, "FlashlightFixture_R exists on Explorer backpack")

		for fixture in [left_fixture, right_fixture]:
			if fixture != null:
				var prefix : String = fixture.name
				var house : MeshInstance3D = fixture.find_child("FlashlightHousing", true, false) as MeshInstance3D
				var lens : MeshInstance3D = fixture.find_child("FlashlightLens", true, false) as MeshInstance3D
				var spot : SpotLight3D = fixture.find_child("FlashlightSpot", true, false) as SpotLight3D

				_assert_test(house != null, "%s: FlashlightHousing mesh exists" % prefix)
				_assert_test(lens != null, "%s: FlashlightLens mesh exists" % prefix)
				_assert_test(spot != null, "%s: FlashlightSpot exists" % prefix)

				if house != null:
					_assert_test(house.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
						"%s: Housing does not cast shadows (prevents shadow acne)" % prefix)

				if lens != null:
					_assert_test(lens.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
						"%s: Lens does not cast shadows (prevents self-shadow streaks)" % prefix)

				if spot != null:
					_assert_test(not spot.shadow_enabled,
						"%s: SpotLight shadow_enabled is false (clean streak-free beam)" % prefix)
					_assert_test(spot.position.z <= -0.20,
						"%s: SpotLight is positioned cleanly in front of lens (z=%f)" % [prefix, spot.position.z])
					_assert_test(spot.spot_attenuation < 1.0,
						"%s: Spot attenuation is smooth falloff (%f)" % [prefix, spot.spot_attenuation])
					_assert_test(spot.spot_angle_attenuation > 1.0,
						"%s: Spot angle attenuation has smooth soft edges (%f)" % [prefix, spot.spot_angle_attenuation])

		explorer_model.queue_free()
		await process_frame

	# -------------------------------------------------------------------------
	# 2. Map Themes & Environment Vista Verification
	# -------------------------------------------------------------------------
	print("\n--- 2. Testing Map Themes & Thematic Vista Environments ---")

	# Create test environment harness
	var test_root := Node3D.new()
	test_root.name = "TestLevelRoot"
	root.add_child(test_root)

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.fog_enabled = true
	world_env.environment = env
	test_root.add_child(world_env)

	var dir_light := DirectionalLight3D.new()
	dir_light.name = "DirectionalLight3D"
	test_root.add_child(dir_light)

	var dnc_script : Script = load("res://scenes/level/day_night_cycle.gd") as Script
	var dnc : Node = Node.new()
	dnc.name = "DayNightCycle"
	dnc.set_script(dnc_script)
	test_root.add_child(dnc)

	var map_scene : PackedScene = load("res://scenes/level/space_station.tscn")
	_assert_test(map_scene != null, "space_station.tscn loads successfully")

	var station_map : SpaceStationMap = map_scene.instantiate() as SpaceStationMap
	test_root.add_child(station_map)

	for frame in range(10):
		await process_frame

	# Test all 3 Map Themes:
	# 0: CANYON WASTELAND
	print("\n--- Testing Canyon Wasteland (Theme 0) Visuals ---")
	station_map.map_theme = SpaceStationMap.MapTheme.CANYON_WASTELAND
	await process_frame

	var ground_mat : StandardMaterial3D = station_map.get("_ground_material") as StandardMaterial3D
	_assert_test(ground_mat != null, "Ground material exists on SpaceStationMap")
	if ground_mat != null:
		_assert_test(is_equal_approx(ground_mat.albedo_color.r, 0.6196),
			"Canyon ground is terracotta sandstone red (r=%f)" % ground_mat.albedo_color.r)

	var barrier_mat : StandardMaterial3D = station_map.get("_perimeter_material") as StandardMaterial3D
	_assert_test(barrier_mat != null, "Perimeter barrier material exists")
	if barrier_mat != null:
		_assert_test(barrier_mat.albedo_color.r > 0.8 and barrier_mat.albedo_color.b < 0.3,
			"Canyon perimeter barrier is warm amber forcefield")

	var mist_mat : StandardMaterial3D = station_map.get("_mist_material") as StandardMaterial3D
	_assert_test(mist_mat != null, "Atmospheric mist material exists")
	if mist_mat != null:
		_assert_test(mist_mat.albedo_color.r > mist_mat.albedo_color.b,
			"Canyon atmospheric haze is warm desert dust")

	_assert_test(sky_mat.sky_horizon_color.r > 0.7 and sky_mat.sky_horizon_color.b < 0.4,
		"Canyon sky horizon is fiery sandstone sunset (r=%f)" % sky_mat.sky_horizon_color.r)
	_assert_test(env.fog_light_color.r > 0.7,
		"Canyon fog light color is warm canyon sandstone")
	_assert_test(dir_light.light_color.r > 0.9 and dir_light.light_color.b < 0.8,
		"Canyon sun is warm golden desert sunlight")

	# Test 1: SPACE BASE
	print("\n--- Testing Space Base (Theme 1) Visuals ---")
	station_map.map_theme = SpaceStationMap.MapTheme.SPACE_BASE
	await process_frame

	if ground_mat != null:
		_assert_test(is_equal_approx(ground_mat.albedo_color.r, 0.30),
			"Space Base ground is lunar slate regolith (r=%f)" % ground_mat.albedo_color.r)

	if barrier_mat != null:
		_assert_test(barrier_mat.albedo_color.b > 0.8 and barrier_mat.albedo_color.g > 0.7,
			"Space Base perimeter barrier is glowing plasma cyan")

	if mist_mat != null:
		_assert_test(mist_mat.albedo_color.b > mist_mat.albedo_color.r,
			"Space Base atmospheric haze is thin lunar exosphere")

	_assert_test(sky_mat.sky_top_color.v < 0.20,
		"Space Base sky top is deep cosmic starry space (v=%f)" % sky_mat.sky_top_color.v)
	_assert_test(dir_light.light_energy >= 1.4,
		"Space Base solar lighting is intense unfiltered white (energy=%f)" % dir_light.light_energy)

	# Test 2: TRANSPORT DOCK
	print("\n--- Testing Transport Dock (Theme 2) Visuals ---")
	station_map.map_theme = SpaceStationMap.MapTheme.TRANSPORT_DOCK
	await process_frame

	if ground_mat != null:
		_assert_test(is_equal_approx(ground_mat.albedo_color.r, 0.22),
			"Transport Dock ground is dark industrial tarmac / runway (r=%f)" % ground_mat.albedo_color.r)

	if barrier_mat != null:
		_assert_test(barrier_mat.albedo_color.r > 0.9 and barrier_mat.albedo_color.g > 0.6 and barrier_mat.albedo_color.b < 0.2,
			"Transport Dock perimeter barrier is industrial hazard gold/yellow")

	if mist_mat != null:
		_assert_test(mist_mat.albedo_color.b > mist_mat.albedo_color.r,
			"Transport Dock atmospheric haze is industrial docking mist")

	_assert_test(sky_mat.sky_horizon_color.b > 0.4,
		"Transport Dock sky horizon is cool aerospace twilight")

	# Test POI Presence
	var dock_logistics : Node3D = station_map.find_child("Sector_DockLogistics", true, false) as Node3D
	_assert_test(dock_logistics != null, "Sector_DockLogistics exists for Transport Dock")

	# Cleanup test harness
	test_root.queue_free()
	await process_frame

	print("\n==================================================")
	print("TEST RESULTS: %d PASSED, %d FAILED" % [passed_count, failed_count])
	print("==================================================")

	quit(0 if failed_count == 0 else 1)
