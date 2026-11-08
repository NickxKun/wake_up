extends SceneTree

var passed: int = 0
var failed: int = 0

func check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("  [PASS] " + message)
	else:
		failed += 1
		print("  [FAIL] " + message)

func _init() -> void:
	print("\n=== STARTING CLEAN PIXEL ART FILTER & DISPLAY TIDINESS TEST SUITE ===")
	_run_tests()

func _run_tests() -> void:
	# [Test 1] Verify Shader Architecture & Division-by-Zero Fixes
	print("\n[Test 1] Testing Edge Detection Shader Uniforms & Numerical Stability...")
	var shader_code : String = FileAccess.get_file_as_string("res://assets/shaders/edge_detection.gdshader")
	check(shader_code.length() > 0, "edge_detection.gdshader file read successfully")
	check("DEPTH_TEXTURE : hint_depth_texture, filter_nearest" in shader_code, "DEPTH_TEXTURE uses filter_nearest to avoid blurry depth gradients")
	check("smoothstep(0.85, 0.95, invDepthDifference)" in shader_code, "smoothstep on invDepthDifference has non-zero range (no div-by-zero NaN)")
	check("smoothstep(0.18, 0.25, normalDifference)" in shader_code, "smoothstep on normalDifference has non-zero range (no div-by-zero NaN)")
	check(not "smoothstep(0.9, 0.9" in shader_code, "Zero-range smoothstep(0.9, 0.9) completely eliminated")
	check(not "smoothstep(0.2, 0.2" in shader_code, "Zero-range smoothstep(0.2, 0.2) completely eliminated")

	# [Test 2] Verify Lighting Cleanliness & Elimination of Grain / Milky Wash
	print("\n[Test 2] Testing Light Calculation & Cel-Shaded Crispness...")
	check(not "mix(vec3(0.9)" in shader_code, "Eliminated washed-out milky mix(vec3(0.9), ...) in DIFFUSE_LIGHT")
	check(not "mix(vec3(1.0)" in shader_code, "No legacy washed-out mix(vec3(1.0), ...) in DIFFUSE_LIGHT")
	check("floor(dotNL * 4.0" in shader_code, "Diffuse lighting quantized to 4 discrete tonal bands")
	check("step(0.35, ATTENUATION)" in shader_code, "Hard shadow cut preserved with step(0.35, ATTENUATION)")
	check("mix(0.28, steppedNL, shadowCut)" in shader_code, "Clean uniform shadow tone mixed with stepped light")
	check("DIFFUSE_LIGHT += finalLight * LIGHT_COLOR * lightIntensity;" in shader_code, "Direct pure cel-shaded light added to DIFFUSE_LIGHT")
	check("step(0.28, edge)" in shader_code, "Crisp ink outlines preserved with step(0.28, edge)")

	# [Test 3] Verify Project Configuration: Debanding Disabled to Prevent Upscale Grain
	print("\n[Test 3] Testing Project Rendering Settings for Dither Grain Elimination...")
	var project_godot : String = FileAccess.get_file_as_string("res://project.godot")
	check("anti_aliasing/quality/use_debanding=false" in project_godot, "anti_aliasing/quality/use_debanding is set to false in project.godot")
	check("directional_shadow/soft_shadow_filter_quality=0" in project_godot, "Directional shadow quality is set to Hard (0)")
	check("positional_shadow/soft_shadow_filter_quality=0" in project_godot, "Positional shadow quality is set to Hard (0)")

	# [Test 4] Verify Scene Configurations & Shadow Acne Prevention
	print("\n[Test 4] Testing Viewport and Shadow Bias in Main, Tutorial and Range scenes...")
	var main_scene_text : String = FileAccess.get_file_as_string("res://scenes/main.tscn")
	check("use_debanding = false" in main_scene_text, "main.tscn SubViewport has use_debanding = false")
	check("shadow_bias = 0.03" in main_scene_text, "main.tscn DirectionalLight3D shadow_bias is 0.03 (prevents shadow acne)")
	check("shadow_normal_bias = 1.2" in main_scene_text, "main.tscn DirectionalLight3D shadow_normal_bias is 1.2")

	var tut_scene_text : String = FileAccess.get_file_as_string("res://scenes/tutorial/tutorial_map.tscn")
	check("use_debanding = false" in tut_scene_text, "tutorial_map.tscn SubViewport has use_debanding = false")
	check("shadow_bias = 0.03" in tut_scene_text, "tutorial_map.tscn DirectionalLight3D shadow_bias is 0.03")

	var range_scene_text : String = FileAccess.get_file_as_string("res://scenes/gamemodes/range_mode.tscn")
	check("shadow_bias = 0.03" in range_scene_text, "range_mode.tscn DirectionalLight3D shadow_bias is 0.03")

	var space_station_script : String = FileAccess.get_file_as_string("res://scenes/level/space_station_map.gd")
	check("sun_light.shadow_bias = 0.03" in space_station_script, "space_station_map.gd dynamic sun shadow_bias is 0.03")
	check("sun_light.shadow_normal_bias = 1.2" in space_station_script, "space_station_map.gd dynamic sun shadow_normal_bias is 1.2")

	# [Test 5] Verify Shader Instantiation and Compilation in Engine
	print("\n[Test 5] Testing Shader Loading & Instantiation in Engine...")
	var shader : Shader = load("res://assets/shaders/edge_detection.gdshader") as Shader
	check(shader != null, "edge_detection.gdshader loaded successfully as Shader resource")
	var mat : ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader
	check(mat.shader == shader, "ShaderMaterial created and bound successfully")

	# [Test 6] Verify Main Scene Instantiation with Shader
	print("\n[Test 6] Testing Main Scene Instantiation with Updated Filter...")
	var main_scene : PackedScene = load("res://scenes/main.tscn") as PackedScene
	check(main_scene != null, "main.tscn loaded successfully")
	var main_inst = main_scene.instantiate()
	check(main_inst != null, "main.tscn instantiated without error")
	var dir_light : DirectionalLight3D = main_inst.find_child("DirectionalLight3D", true, false) as DirectionalLight3D
	check(dir_light != null, "DirectionalLight3D found in main scene")
	if dir_light != null:
		check(is_equal_approx(dir_light.shadow_bias, 0.03), "DirectionalLight3D shadow_bias is 0.03")
		check(is_equal_approx(dir_light.shadow_normal_bias, 1.2), "DirectionalLight3D shadow_normal_bias is 1.2")
	main_inst.queue_free()

	print("\n=======================================================")
	print("RESULTS: %d Passed, %d Failed" % [passed, failed])
	print("=======================================================")
	if failed == 0:
		print("CLEAN PIXEL ART FILTER & DISPLAY TIDINESS ALL PASSED!\n")
	quit(0 if failed == 0 else 1)
