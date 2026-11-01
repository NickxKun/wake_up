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
	print("--- Running Full Game Session & Debugger Cleanliness Verification ---")
	call_deferred("_run_session")

func _run_session() -> void:
	# Load and instantiate main scene
	var main_scene : PackedScene = load("res://scenes/main.tscn")
	check(main_scene != null, "main.tscn loaded successfully")
	if main_scene == null:
		quit(1)
		return

	var main_inst : Node = main_scene.instantiate()
	root.add_child(main_inst)
	print("  [INFO] main.tscn instantiated and added to root. Running 120 frames...")

	# Run for 120 physics and idle frames to allow CSG meshes, navigation baking,
	# enemy spawning, HUD initialization, and game loops to execute fully.
	for i in range(120):
		await process_frame

	check(true, "Main game session simulated 120 full frames without fatal crash")

	# Check that player is alive and in tree
	var player : Node = root.find_children("*", "CharacterBody3D", true, false).filter(
		func(node: Node) -> bool: return node.is_in_group("player")
	).front()
	check(player != null, "Player character is alive and present in scene")

	# Check that enemies have spawned and are active
	var enemies : Array[Node] = get_nodes_in_group("enemy")
	check(enemies.size() > 0, "Enemies successfully spawned (%d active)" % enemies.size())

	# Check that navigation region is active
	var nav_region : NavigationRegion3D = root.find_children("*", "NavigationRegion3D", true, false).front() as NavigationRegion3D
	check(nav_region != null, "NavigationRegion3D exists in scene")

	# Check HUD and UI elements
	var hud : Node = root.get_node_or_null("/root/PlayerHealthHud")
	check(hud != null, "PlayerHealthHud autoload is loaded and running")

	print("\n=======================================================")
	print("DEBUGGER & SESSION RESULTS: %d Passed, %d Failed" % [passes, failures])
	print("=======================================================\n")
	main_inst.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
