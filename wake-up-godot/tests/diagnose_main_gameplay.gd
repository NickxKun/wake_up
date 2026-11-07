extends SceneTree

func _init() -> void:
	print("\n=== RUNNING SCENES/MAIN.TSCN GAMEPLAY DIAGNOSTIC ===")
	_run.call_deferred()

func _run() -> void:
	var root : Window = get_root()
	var main_scene : PackedScene = load("res://scenes/main.tscn")
	if main_scene == null:
		print("ERROR: Could not load scenes/main.tscn")
		quit(1)
		return

	var main_node : Node = main_scene.instantiate()
	root.add_child(main_node)

	print("Running initial frames...")
	for i in range(30):
		await process_frame

	var pc : CharacterBody3D = main_node.find_child("ProtoController", true, false) as CharacterBody3D
	var combat : Node = pc.get_node_or_null("PlayerCombat") if pc else null
	var char_data : Node = root.get_node_or_null("/root/CharacterData")

	print("Simulating gameplay interactions...")
	if pc != null and combat != null:
		# Test all 4 classes
		for cid in range(4):
			if char_data:
				print("Selecting class ", cid)
				char_data.call("select_class", cid)
			for f in range(15):
				await process_frame

			# Simulate shooting
			if combat.has_method("_shoot"):
				combat.call("_shoot")
			await process_frame

			# Simulate grenade
			if combat.has_method("_throw_grenade"):
				combat.call("_throw_grenade")
			await process_frame

			# Simulate turret
			if combat.has_method("_deploy_sentry_turret"):
				combat.call("_deploy_sentry_turret")
			await process_frame

			# Test equipping each weapon type
			for w in [0, 1, 2, 3, 4, 5]:
				if combat.has_method("equip_weapon"):
					combat.call("equip_weapon", w)
				await process_frame
				if combat.has_method("_shoot"):
					combat.call("_shoot")
				await process_frame

	print("Simulating enemy interactions & movement...")
	for f in range(60):
		await process_frame

	main_node.queue_free()
	await process_frame
	print("=== GAMEPLAY DIAGNOSTIC FINISHED ===")
	quit(0)
