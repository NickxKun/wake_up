extends SceneTree

## Dedicated test to verify redeploy / restart lifecycle when dying outside the playable zone.

func _init() -> void:
	print("\n=== STARTING OOB DEATH & REDEPLOY TEST ===")
	call_deferred("_run_test")

func _run_test() -> void:
	var hud_script : Script = load("res://scenes/ui/player_health_hud.gd")
	var hud : Node = Node.new()
	hud.name = "PlayerHealthHud"
	hud.set_script(hud_script)
	root.add_child(hud)

	# Create a mock scene with a player positioned outside the zone
	var mock_scene : Node3D = Node3D.new()
	mock_scene.name = "MockLevel"

	var player : CharacterBody3D = CharacterBody3D.new()
	player.name = "ProtoController"
	player.position = Vector3(25.0, 0.0, 25.0) # Outside the 15.5m safe zone!

	var hc_script : Script = load("res://scenes/components/health_component.gd")
	var hc : Node = Node.new()
	hc.name = "HealthComponent"
	hc.set_script(hc_script)
	player.add_child(hc)

	mock_scene.add_child(player)
	root.add_child(mock_scene)
	current_scene = mock_scene

	# Process 2 frames to let HUD set up
	hud._process(0.016)
	await process_frame
	await process_frame

	print("[Step 1] Verifying HUD bound to player outside zone...")
	var oob_w : Node = hud.get("_oob_warning")
	if oob_w != null and oob_w.call("is_warning_active"):
		print("PASS: OOB warning activated on player outside zone.")
	else:
		print("FAIL: OOB warning did not activate.")
		quit(1)
		return

	# Deplete player health to simulate lethal death outside the zone
	print("[Step 2] Depleting health to simulate death outside zone...")
	hc.call("decrease_health", 100)
	await process_frame

	var is_game_over : bool = hud.call("is_game_over")
	if is_game_over:
		print("PASS: Game Over screen instantiated.")
	else:
		print("FAIL: Game over screen not instantiated.")
		quit(1)
		return

	# Test calling restart() directly
	print("[Step 3] Invoking restart() from Game Over screen...")
	hud.call("restart")

	# Wait a frame to let UI cleanup process
	await process_frame

	# Simulate new scene loading: replace mock scene with fresh new scene and new player
	var new_scene : Node3D = Node3D.new()
	new_scene.name = "MockLevelNew"
	var new_player : CharacterBody3D = CharacterBody3D.new()
	new_player.name = "ProtoController"
	new_player.position = Vector3(0.0, 0.0, 0.0) # Inside safe zone on respawn

	var new_hc : Node = Node.new()
	new_hc.name = "HealthComponent"
	new_hc.set_script(hc_script)
	new_player.add_child(new_hc)

	new_scene.add_child(new_player)

	# Free old scene and attach new scene
	mock_scene.queue_free()
	root.add_child(new_scene)
	current_scene = new_scene

	# Process frames so player_health_hud's async restart loop completes and detects scene change
	for _i in range(5):
		await process_frame

	hud._process(0.016)
	await process_frame

	var new_hc_bound : Node = hud.get("health_component")
	if new_hc_bound == new_hc and not hud.call("is_game_over"):
		print("PASS: Redeploy successfully rebound HUD to new player in fresh scene with zero errors.")
		print("\n=== OOB REDEPLOY TEST PASSED! ===")
		new_scene.queue_free()
		hud.queue_free()
		quit(0)
	else:
		print("FAIL: HealthComponent not bound to new player or still in game over.")
		new_scene.queue_free()
		hud.queue_free()
		quit(1)
