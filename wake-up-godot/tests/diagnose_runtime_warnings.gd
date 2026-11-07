extends SceneTree

func _init() -> void:
	print("\n=== DIAGNOSING RUNTIME WARNINGS & ERRORS ===")
	_run_diagnostics.call_deferred()

func _run_diagnostics() -> void:
	var root : Window = get_root()

	# 1. Main Menu
	print("\n--- Testing Main Menu Runtime ---")
	var menu_scene : PackedScene = load("res://scenes/ui/main_menu.tscn")
	if menu_scene:
		var menu : Node = menu_scene.instantiate()
		root.add_child(menu)
		for i in range(20):
			await process_frame
		menu.queue_free()
		await process_frame

	# 2. Level Space Station (Themes 0, 1, 2)
	var station_scene : PackedScene = load("res://scenes/level/space_station.tscn")
	var char_data : Node = root.get_node_or_null("/root/CharacterData")

	for theme_id in range(3):
		print("\n--- Testing Space Station Theme %d ---" % theme_id)
		var station : Node = station_scene.instantiate()
		var map_node : Node = station.get_node_or_null("SpaceStationMap")
		if map_node:
			map_node.set("current_theme", theme_id)
		root.add_child(station)
		for i in range(30):
			await process_frame

		# Find player and simulate combat actions
		var player : Node = station.find_child("ProtoController", true, false)
		if player != null:
			var combat : Node = player.get_node_or_null("PlayerCombat")
			if combat != null:
				print("Simulating combat actions on player...")
				# Shoot
				if combat.has_method("_shoot"):
					combat.call("_shoot")
				await process_frame
				# Deploy turret
				if combat.has_method("_deploy_sentry_turret"):
					combat.call("_deploy_sentry_turret")
				await process_frame
				# Throw grenade
				if combat.has_method("_throw_grenade"):
					combat.call("_throw_grenade")
				await process_frame
				# Equip different weapons
				for w_idx in [1, 2, 3, 4, 5]:
					if combat.has_method("equip_weapon"):
						combat.call("equip_weapon", w_idx)
					await process_frame
					if combat.has_method("_shoot"):
						combat.call("_shoot")
					await process_frame

		# Switch operative classes
		if char_data:
			for cid in range(4):
				char_data.call("select_class", cid)
				for i in range(5):
					await process_frame

		station.queue_free()
		await process_frame

	# 3. Tutorial Map
	print("\n--- Testing Tutorial Map ---")
	var tut_scene : PackedScene = load("res://scenes/tutorial/tutorial_map.tscn")
	if tut_scene:
		var tut : Node = tut_scene.instantiate()
		root.add_child(tut)
		for i in range(40):
			await process_frame
		tut.queue_free()
		await process_frame

	print("\n=== DIAGNOSTICS COMPLETED ===")
	quit(0)
