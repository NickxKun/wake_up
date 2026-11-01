extends SceneTree

var passes : int = 0
var failures : int = 0

func check(condition: bool, message: String) -> void:
	if condition:
		passes += 1
		print("[PASS] ", message)
	else:
		failures += 1
		print("[FAIL] ", message)

func _initialize() -> void:
	print("--- Running Pause Menu & Game Over Verification Test ---")

	# Wait a frame for SceneTree to settle
	await process_frame

	# 1. Test Pause Menu scene instantiation
	var pause_scene = load("res://scenes/ui/pause_menu.tscn")
	check(pause_scene != null, "pause_menu.tscn loaded successfully")
	var pause_inst = pause_scene.instantiate()
	check(pause_inst != null, "pause_menu instantiated successfully")
	root.add_child(pause_inst)

	# Allow _ready() to fire on pause_inst
	await process_frame

	check(pause_inst.is_node_ready(), "pause_menu node is ready")
	check(pause_inst.visible == false, "pause_menu starts hidden")
	check(pause_inst.has_signal("resumed"), "pause_menu has resumed signal")
	check(pause_inst.has_signal("restart_requested"), "pause_menu has restart_requested signal")
	check(pause_inst.has_signal("main_menu_requested"), "pause_menu has main_menu_requested signal")

	# Test update_telemetry
	pause_inst.update_telemetry(12, 3, false)
	var telemetry_lbl = pause_inst.get_node("CenterContainer/ModalPanel/MarginContainer/ContentBox/TelemetryBox/TelemetryLabel")
	check("HOSTILES: 12" in telemetry_lbl.text, "telemetry hostiles updated")
	check("DEATHS: 3" in telemetry_lbl.text, "telemetry deaths updated")
	check("SURVIVAL // PROTOCOL 01" in telemetry_lbl.text, "telemetry mode updated for survival")

	pause_inst.update_telemetry(45, 1, true)
	check("SANDBOX // PROTOCOL 02" in telemetry_lbl.text, "telemetry mode updated for sandbox")

	# 2. Test Game Over scene instantiation
	var game_over_scene = load("res://scenes/ui/game_over.tscn")
	check(game_over_scene != null, "game_over.tscn loaded successfully")
	var game_over_inst = game_over_scene.instantiate()
	check(game_over_inst != null, "game_over instantiated successfully")
	root.add_child(game_over_inst)

	# Allow _ready() to fire on game_over_inst
	await process_frame

	check(game_over_inst.is_node_ready(), "game_over node is ready")
	check(game_over_inst.has_signal("restart_requested"), "game_over has restart_requested signal")
	check(game_over_inst.has_signal("main_menu_requested"), "game_over has main_menu_requested signal")

	# Test set_stats
	game_over_inst.set_stats(27, 4, false)
	var kills_val = game_over_inst.get_node("CenterContainer/ModalPanel/MarginContainer/VBoxContainer/TelemetryCard/VBox/RowKills/Value")
	var deaths_val = game_over_inst.get_node("CenterContainer/ModalPanel/MarginContainer/VBoxContainer/TelemetryCard/VBox/RowDeaths/Value")
	var mode_val = game_over_inst.get_node("CenterContainer/ModalPanel/MarginContainer/VBoxContainer/TelemetryCard/VBox/RowMode/Value")

	check(kills_val.text == "27", "game_over kills stat matches: " + kills_val.text)
	check(deaths_val.text == "4", "game_over deaths stat matches: " + deaths_val.text)
	check("SURVIVAL" in mode_val.text, "game_over survival protocol label matches")

	game_over_inst.set_stats(5, 0, true)
	check(deaths_val.text == "1", "game_over minimum death clamp works: " + deaths_val.text)
	check("SANDBOX" in mode_val.text, "game_over sandbox protocol label matches")

	# Test restart button signal emission
	var restart_emitted := {"val": false}
	game_over_inst.restart_requested.connect(func(): restart_emitted["val"] = true)
	var restart_btn = game_over_inst.get_node("CenterContainer/ModalPanel/MarginContainer/VBoxContainer/ActionsBox/RestartButton")
	restart_btn.emit_signal("pressed")

	# Process frames to let tween callback fire
	for i in range(15):
		await process_frame

	check(restart_emitted["val"] == true, "game_over restart_requested fired via button press")

	# Clean up test instances
	pause_inst.queue_free()
	game_over_inst.queue_free()
	await process_frame

	print("--- Verification Results: %d Passed, %d Failed ---" % [passes, failures])
	if failures > 0:
		quit(1)
	else:
		quit(0)
