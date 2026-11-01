extends SceneTree

## Automated In-Engine Cinematic Banner Generator.
## Instantiates maps and captures high-resolution screenshots for each game mode.

const BANNER_WIDTH : int = 560
const BANNER_HEIGHT : int = 660

func _initialize() -> void:
	print("--- Generating High-Resolution Cinematic Game Mode Banners ---")
	call_deferred("_generate_all_banners")

func _generate_all_banners() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(BANNER_WIDTH, BANNER_HEIGHT)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame

	# 1. Tutorial Banner
	print("[1/5] Capturing Tutorial Proving Grounds Banner...")
	await _capture_tutorial(viewport)

	# 2. Survival Banner
	print("[2/5] Capturing Survival Sector Banner...")
	await _capture_survival(viewport)

	# 3. Sandbox Banner
	print("[3/5] Capturing Sandbox Testbed Banner...")
	await _capture_sandbox(viewport)

	# 4. Story Mode Banner (Teaser)
	print("[4/5] Capturing Story Mode Industrial Outpost Banner...")
	await _capture_story(viewport)

	# 5. Co-op Mode Banner (Teaser)
	print("[5/5] Capturing Co-op Tactical Squad Banner...")
	await _capture_coop(viewport)

	print("\n=== ALL 5 BANNERS SUCCESSFULLY CAPTURED & SAVED ===")
	quit(0)

func _capture_tutorial(vp: SubViewport) -> void:
	_clear_viewport(vp)
	var scene : PackedScene = load("res://scenes/tutorial/tutorial_map.tscn")
	var map : Node = scene.instantiate()

	# Remove player and HUD to feature only the proving grounds map architecture
	var player : Node = map.find_child("ProtoController", true, false)
	if player != null:
		player.queue_free()

	var hud : Node = map.find_child("TutorialHud", true, false)
	if hud != null:
		hud.queue_free()

	vp.add_child(map)

	# Setup elevated cinematic map overview camera
	var cam := Camera3D.new()
	cam.current = true
	vp.add_child(cam)
	cam.global_position = Vector3(6.0, 16.0, 22.0)
	cam.look_at(Vector3(6.0, 0.5, 3.0), Vector3.UP)
	cam.fov = 48.0

	for _i in range(15):
		await process_frame

	_save_texture(vp, "res://assets/textures/gamemodes/banner_tutorial.png")

func _capture_survival(vp: SubViewport) -> void:
	_clear_viewport(vp)
	var hud : Node = root.get_node_or_null("PlayerHealthHud")
	if hud != null:
		hud.set("selected_map_theme", 0) # Canyon Wasteland desert terrain

	var scene : PackedScene = load("res://scenes/main.tscn")
	var map : Node = scene.instantiate()

	# Remove player and spawners for pure landscape vista
	var player : Node = map.find_child("ProtoController", true, false)
	if player != null:
		player.queue_free()
	var spawner : Node = map.find_child("EnemySpawner", true, false)
	if spawner != null:
		spawner.queue_free()

	vp.add_child(map)

	var station : Node = map.find_child("SpaceStation", true, false)
	if station != null:
		station.set("map_theme", 0)

	var cam := Camera3D.new()
	cam.current = true
	vp.add_child(cam)
	cam.global_position = Vector3(16.0, 13.0, 20.0)
	cam.look_at(Vector3(0.0, 1.5, 0.0), Vector3.UP)
	cam.fov = 48.0

	for _i in range(15):
		await process_frame

	_save_texture(vp, "res://assets/textures/gamemodes/banner_survival.png")

func _capture_sandbox(vp: SubViewport) -> void:
	_clear_viewport(vp)
	var hud : Node = root.get_node_or_null("PlayerHealthHud")
	if hud != null:
		hud.set("selected_map_theme", 1) # Space Base (Solar ridge, science labs)

	var scene : PackedScene = load("res://scenes/main.tscn")
	var map : Node = scene.instantiate()

	var player : Node = map.find_child("ProtoController", true, false)
	if player != null:
		player.queue_free()
	var spawner : Node = map.find_child("EnemySpawner", true, false)
	if spawner != null:
		spawner.queue_free()

	vp.add_child(map)

	var station : Node = map.find_child("SpaceStation", true, false)
	if station != null:
		station.set("map_theme", 1)

	var cam := Camera3D.new()
	cam.current = true
	vp.add_child(cam)
	cam.global_position = Vector3(-14.0, 13.0, 18.0)
	cam.look_at(Vector3(2.0, 1.8, -2.0), Vector3.UP)
	cam.fov = 50.0

	for _i in range(15):
		await process_frame

	_save_texture(vp, "res://assets/textures/gamemodes/banner_sandbox.png")

func _capture_story(vp: SubViewport) -> void:
	_clear_viewport(vp)
	var hud : Node = root.get_node_or_null("PlayerHealthHud")
	if hud != null:
		hud.set("selected_map_theme", 2) # Transport Dock (Drill, spacetruck, quarry)

	var scene : PackedScene = load("res://scenes/main.tscn")
	var map : Node = scene.instantiate()

	var player : Node = map.find_child("ProtoController", true, false)
	if player != null:
		player.queue_free()
	var spawner : Node = map.find_child("EnemySpawner", true, false)
	if spawner != null:
		spawner.queue_free()

	vp.add_child(map)

	var station : Node = map.find_child("SpaceStation", true, false)
	if station != null:
		station.set("map_theme", 2)

	var cam := Camera3D.new()
	cam.current = true
	vp.add_child(cam)
	cam.global_position = Vector3(14.0, 9.0, 16.0)
	cam.look_at(Vector3(-4.0, 2.5, -4.0), Vector3.UP)
	cam.fov = 48.0

	for _i in range(15):
		await process_frame

	_save_texture(vp, "res://assets/textures/gamemodes/banner_story.png")

func _capture_coop(vp: SubViewport) -> void:
	_clear_viewport(vp)
	var hud : Node = root.get_node_or_null("PlayerHealthHud")
	if hud != null:
		hud.set("selected_map_theme", 1)

	var scene : PackedScene = load("res://scenes/main.tscn")
	var map : Node = scene.instantiate()

	var player : Node = map.find_child("ProtoController", true, false)
	if player != null:
		player.queue_free()
	var spawner : Node = map.find_child("EnemySpawner", true, false)
	if spawner != null:
		spawner.queue_free()

	vp.add_child(map)

	var station : Node = map.find_child("SpaceStation", true, false)
	if station != null:
		station.set("map_theme", 1)

	var cam := Camera3D.new()
	cam.current = true
	vp.add_child(cam)
	cam.global_position = Vector3(-16.0, 14.0, -14.0)
	cam.look_at(Vector3(0.0, 1.2, 0.0), Vector3.UP)
	cam.fov = 50.0

	for _i in range(15):
		await process_frame

	_save_texture(vp, "res://assets/textures/gamemodes/banner_coop.png")

func _clear_viewport(vp: SubViewport) -> void:
	for child in vp.get_children():
		child.queue_free()

func _save_texture(vp: SubViewport, save_path: String) -> void:
	var tex : Texture2D = vp.get_texture()
	if tex == null:
		print("  [ERROR] Viewport texture is null for ", save_path)
		return
	var img : Image = tex.get_image()
	if img == null or img.is_empty():
		print("  [ERROR] Image is null or empty for ", save_path)
		return
	var abs_path : String = ProjectSettings.globalize_path(save_path)
	var err := img.save_png(abs_path)
	if err == OK:
		print("  [SAVED] -> ", save_path, " (size: %dx%d)" % [img.get_width(), img.get_height()])
	else:
		print("  [ERROR] Failed to save PNG: ", err)
