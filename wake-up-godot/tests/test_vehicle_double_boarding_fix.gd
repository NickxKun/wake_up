extends SceneTree

## Verification Test Suite for Double Vehicle Boarding Prevention and Proximity Resolution.

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
	print("--- Running Double Vehicle Boarding Prevention Test Suite ---")
	call_deferred("_run_tests")

func _run_tests() -> void:
	await process_frame
	await process_frame

	# 1. Instantiate Player
	var player_scene : PackedScene = load("res://addons/proto_controller/proto_controller.tscn")
	check(player_scene != null, "proto_controller.tscn loaded successfully")
	var player : CharacterBody3D = player_scene.instantiate() as CharacterBody3D
	root.add_child(player)
	player.global_position = Vector3(0, 0, 0)
	await process_frame

	# 2. Instantiate Rover 1 (closer, at distance 1.5m)
	var rover_scene : PackedScene = load("res://scenes/vehicles/rover.tscn")
	check(rover_scene != null, "rover.tscn loaded successfully")
	var rover1 : CharacterBody3D = rover_scene.instantiate() as CharacterBody3D
	root.add_child(rover1)
	rover1.global_position = Vector3(1.5, 0, 0)

	# 3. Instantiate Rover 2 (further, at distance 2.0m)
	var rover2 : CharacterBody3D = rover_scene.instantiate() as CharacterBody3D
	root.add_child(rover2)
	rover2.global_position = Vector3(-2.0, 0, 0)

	await process_frame
	await process_frame

	# 4. Refresh nearby player on both rovers
	rover1._refresh_nearby_player()
	rover2._refresh_nearby_player()

	check(rover1.get("_nearby_player") == player, "Closer Rover 1 recognizes player as nearby")
	check(rover2.get("_nearby_player") == null, "Further Rover 2 defers nearby player to the closer Rover 1")

	# 5. Board Rover 1
	rover1.board_vehicle(player)
	check(rover1.is_occupied == true, "Rover 1 is now occupied")
	check(player.get("is_driving_vehicle") == true, "Player has is_driving_vehicle flag set to true")
	check(player.is_in_group("driving") == true, "Player is added to 'driving' group")
	check(player.has_meta("current_vehicle") == true, "Player has 'current_vehicle' metadata set")

	# 6. Attempt boarding Rover 2 while already in Rover 1
	rover2.board_vehicle(player)
	check(rover2.is_occupied == false, "Rover 2 strictly rejects boarding because player is already driving")
	check(rover2.get("_driver") == null, "Rover 2 has no driver")

	# Rover 2 should not detect player as nearby while player is driving
	rover2._refresh_nearby_player()
	check(rover2.get("_nearby_player") == null, "Rover 2 nearby player remains null while player is driving")

	# 7. Exit Rover 1
	rover1.exit_vehicle()
	check(rover1.is_occupied == false, "Rover 1 is no longer occupied after exit")
	check(rover1.get("_driver") == null, "Rover 1 driver is cleared")
	check(player.get("is_driving_vehicle") == false, "Player is_driving_vehicle flag reset to false")
	check(player.is_in_group("driving") == false, "Player removed from 'driving' group")
	check(player.has_meta("current_vehicle") == false, "Player 'current_vehicle' meta removed")

	# 8. Clean up
	player.queue_free()
	rover1.queue_free()
	rover2.queue_free()
	await process_frame

	print("\n--- Verification Results: %d Passed, %d Failed ---" % [passes, failures])
	if failures > 0:
		quit(1)
	else:
		quit(0)
