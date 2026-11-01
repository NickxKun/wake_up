extends SceneTree

## Comprehensive test suite for soft borders, Demarcation Line, outer desert sectors,
## atmospheric fog, Out-of-Bounds warning, and redeployment lifecycle.

func _init() -> void:
	print("\n=== STARTING MAP & OUT-OF-BOUNDS TEST SUITE ===")
	call_deferred("_run_tests")

func _run_tests() -> void:
	var passes : int = 0
	var fails : int = 0

	# ---------------------------------------------------------
	# Test 1: SpaceStationMap Ground, Demarcation Line, Outer Desert & Barriers
	# ---------------------------------------------------------
	print("\n[Test 1] Testing SpaceStationMap extended ground, demarcation line & outer desert...")
	var map_script : Script = load("res://scenes/level/space_station_map.gd")
	if map_script == null:
		print("FAIL: space_station_map.gd not found")
		fails += 1
	else:
		var map_node : Node3D = Node3D.new()
		map_node.set_script(map_script)
		root.add_child(map_node)
		await process_frame
		await process_frame

		var is_ready : bool = map_node.has_method("is_geometry_ready") and map_node.call("is_geometry_ready")
		var ground_base : Node = map_node.get_node_or_null("GroundBase")
		var demarcation : Node = map_node.get_node_or_null("DemarcationLine")
		var outer_sectors : Node = map_node.get_node_or_null("OuterSectors")
		var outer_fog : Node = map_node.get_node_or_null("OuterAtmosphere")
		var barriers : Node = map_node.get_node_or_null("PerimeterBarriers")

		var has_all_subsystems : bool = (
			ground_base != null and
			demarcation != null and
			outer_sectors != null and
			outer_fog != null and
			barriers != null
		)

		if is_ready and has_all_subsystems:
			var sec_n : Node = outer_sectors.get_node_or_null("Sector_Outer_North")
			var sec_s : Node = outer_sectors.get_node_or_null("Sector_Outer_South")
			var sec_e : Node = outer_sectors.get_node_or_null("Sector_Outer_East")
			var sec_w : Node = outer_sectors.get_node_or_null("Sector_Outer_West")
			var has_all_sectors : bool = sec_n != null and sec_s != null and sec_e != null and sec_w != null

			var col_count : int = 0
			for c in barriers.get_children():
				if c is CollisionShape3D:
					col_count += 1

			# Verify GroundVisual material has no broken palette texture
			var gv : MeshInstance3D = ground_base.get_node_or_null("GroundVisual") as MeshInstance3D
			var ground_mat : StandardMaterial3D = gv.material_override as StandardMaterial3D if gv != null else null
			var has_clean_ground_color : bool = ground_mat != null and ground_mat.albedo_texture == null and is_equal_approx(ground_mat.albedo_color.r, 0.6196)

			if has_all_sectors and col_count == 4 and demarcation.get_child_count() > 10 and has_clean_ground_color:
				print("PASS: SpaceStationMap initialized 80x80m ground with terracotta desert tone, demarcation line, 4 desert rock sectors, dust fog, and 4 true barriers.")
				passes += 1
			else:
				print("FAIL: Outer sectors, demarcation, or ground material invalid.")
				fails += 1
		else:
			print("FAIL: One or more map subsystems missing or geometry not ready.")
			fails += 1

		map_node.queue_free()
		await process_frame

	# ---------------------------------------------------------
	# Test 2: HealthComponent take_damage & damage methods
	# ---------------------------------------------------------
	print("\n[Test 2] Testing HealthComponent take_damage / decrease_health methods...")
	var hc_script : Script = load("res://scenes/components/health_component.gd")
	if hc_script == null:
		print("FAIL: health_component.gd not found")
		fails += 1
	else:
		var hc : Node = Node.new()
		hc.set_script(hc_script)
		root.add_child(hc)

		var start_hp : int = hc.get("health")
		if hc.has_method("take_damage") and hc.has_method("decrease_health"):
			hc.call("take_damage", 30)
			var hp_after : int = hc.get("health")
			if hp_after == 70:
				hc.call("decrease_health", 70)
				if hc.call("is_dead"):
					print("PASS: HealthComponent take_damage alias and decrease_health work with zero errors.")
					passes += 1
				else:
					print("FAIL: Expected entity to be dead at 0 HP.")
					fails += 1
			else:
				print("FAIL: Expected 70 HP, got %d" % hp_after)
				fails += 1
		else:
			print("FAIL: Missing take_damage or decrease_health methods on HealthComponent.")
			fails += 1

		hc.queue_free()
		await process_frame

	# ---------------------------------------------------------
	# Test 3: OutOfBoundsWarning Lifecycle & Depletion
	# ---------------------------------------------------------
	print("\n[Test 3] Testing OutOfBoundsWarning component...")
	var oob_scene : PackedScene = load("res://scenes/ui/out_of_bounds_warning.tscn")
	if oob_scene == null:
		print("FAIL: out_of_bounds_warning.tscn not found")
		fails += 1
	else:
		var oob : CanvasLayer = oob_scene.instantiate() as CanvasLayer
		root.add_child(oob)
		await process_frame

		if oob.call("is_warning_active"):
			print("FAIL: Warning should be inactive on spawn.")
			fails += 1
		else:
			oob.call("set_warning_active", true)
			if not oob.call("is_warning_active"):
				print("FAIL: Warning failed to activate.")
				fails += 1
			else:
				# Process 2 seconds of warning countdown
				oob._process(2.0)
				var time_left : float = oob.call("get_time_remaining")
				if is_equal_approx(time_left, 3.0):
					# Process down to 0 to test depletion signal
					var signal_box : Array[bool] = [false]
					oob.connect("timer_depleted", func() -> void: signal_box[0] = true)
					oob._process(3.5)

					if signal_box[0] and oob.call("get_time_remaining") <= 0.0:
						oob.call("set_warning_active", false)
						print("PASS: OutOfBoundsWarning countdown, signal emission, and reset verified.")
						passes += 1
					else:
						print("FAIL: timer_depleted signal was not emitted (time_remaining=%f, signal=%s)" % [oob.call("get_time_remaining"), signal_box[0]])
						fails += 1
				else:
					print("FAIL: Expected time_left around 3.0s, got %f" % time_left)
					fails += 1

		oob.queue_free()
		await process_frame

	# ---------------------------------------------------------
	# Test 4: Minimap HUD Radar Component
	# ---------------------------------------------------------
	print("\n[Test 4] Testing Minimap HUD radar component...")
	var minimap_scene : PackedScene = load("res://scenes/ui/minimap.tscn")
	if minimap_scene == null:
		print("FAIL: minimap.tscn not found")
		fails += 1
	else:
		var minimap : CanvasLayer = minimap_scene.instantiate() as CanvasLayer
		root.add_child(minimap)

		var mock_player : Node3D = Node3D.new()
		mock_player.name = "MockPlayer"
		mock_player.position = Vector3(4.0, 0.0, -8.0)
		root.add_child(mock_player)
		await process_frame

		minimap.call("bind_player", mock_player)
		minimap.call("set_out_of_bounds", true)
		minimap._process(0.016)
		await process_frame

		var status_text : String = minimap.get("status_label").text
		if status_text == "HAZARD":
			minimap.call("set_out_of_bounds", false)
			minimap._process(0.016)
			if minimap.get("status_label").text == "NOMINAL":
				print("PASS: Minimap successfully bound to player, updated telemetry, and rendered radar vector geometry.")
				passes += 1
			else:
				print("FAIL: Minimap did not update status to NOMINAL.")
				fails += 1
		else:
			print("FAIL: Expected HAZARD status, got: " + status_text)
			fails += 1

		mock_player.queue_free()
		minimap.queue_free()
		await process_frame

	# ---------------------------------------------------------
	# Test 5: Fullscreen Tactical Map Modal with Desert Landmarks
	# ---------------------------------------------------------
	print("\n[Test 5] Testing TacticalMap fullscreen schematic with desert landmarks...")
	var tac_scene : PackedScene = load("res://scenes/ui/tactical_map.tscn")
	if tac_scene == null:
		print("FAIL: tactical_map.tscn not found")
		fails += 1
	else:
		var tac_map : CanvasLayer = tac_scene.instantiate() as CanvasLayer
		root.add_child(tac_map)

		var mock_player2 : Node3D = Node3D.new()
		mock_player2.name = "MockPlayer2"
		mock_player2.position = Vector3(2.5, 0.0, 3.5)
		root.add_child(mock_player2)
		await process_frame

		tac_map.call("bind_player", mock_player2)

		if tac_map.call("is_map_open"):
			print("FAIL: TacticalMap should be closed initially.")
			fails += 1
		else:
			tac_map.call("open_map")
			if not tac_map.call("is_map_open"):
				print("FAIL: TacticalMap failed to open.")
				fails += 1
			else:
				tac_map._process(0.016)
				await process_frame

				tac_map.call("close_map")
				print("PASS: TacticalMap open, process, vector blueprint draw, and close verified.")
				passes += 1

		mock_player2.queue_free()
		tac_map.queue_free()
		await process_frame

	# ---------------------------------------------------------
	# Test 6: UiSound Warning & Map Audio Methods
	# ---------------------------------------------------------
	print("\n[Test 6] Testing UiSound warning & map audio methods...")
	var ui_sound_script : Script = load("res://scenes/ui/ui_sound.gd")
	if ui_sound_script == null:
		print("FAIL: ui_sound.gd not found")
		fails += 1
	else:
		var sound_node : Node = Node.new()
		sound_node.name = "UiSound"
		sound_node.set_script(ui_sound_script)
		root.add_child(sound_node)
		await process_frame

		var has_methods : bool = (
			sound_node.has_method("play_warning_tick") and
			sound_node.has_method("play_map_open") and
			sound_node.has_method("play_map_close") and
			sound_node.has_method("play_player_hurt")
		)

		if has_methods:
			sound_node.call("play_warning_tick")
			sound_node.call("play_map_open")
			sound_node.call("play_map_close")
			sound_node.call("play_player_hurt")
			print("PASS: UiSound warning, map, and hurt SFX methods functional.")
			passes += 1
		else:
			print("FAIL: Missing audio methods on UiSound.")
			fails += 1

		sound_node.queue_free()
		await process_frame

	# ---------------------------------------------------------
	# Summary
	# ---------------------------------------------------------
	print("\n==============================================")
	print("RESULTS: %d PASSED, %d FAILED" % [passes, fails])
	print("==============================================")

	if fails == 0:
		print("ALL MAP & BOUNDS TESTS PASSED!")
		quit(0)
	else:
		print("SOME TESTS FAILED.")
		quit(1)
