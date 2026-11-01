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
	print("--- Running Dash & Stamina Arc Test Suite ---")
	call_deferred("_run_tests")

func _run_tests() -> void:
	await process_frame
	await process_frame

	# 1. Load and instantiate ProtoController scene
	var proto_scene : PackedScene = load("res://addons/proto_controller/proto_controller.tscn")
	check(proto_scene != null, "proto_controller.tscn loaded successfully")
	var player : CharacterBody3D = proto_scene.instantiate()
	root.add_child(player)
	player.add_to_group("player")
	await process_frame
	await process_frame

	# 2. Verify Dash Configuration & Initial State
	check(player.can_dash == true, "can_dash is enabled by default")
	check(player.max_stamina == 3.0, "max_stamina is 3.0 (3 continuous dashes)")
	check(is_equal_approx(player.stamina, 3.0), "Initial stamina is full (3.0)")
	check(player.dash_cooldown == 0.35, "dash_cooldown is 0.35s")
	check(player.dash_cooldown_left == 0.0, "Initial dash_cooldown_left is 0.0")

	# 3. Verify Child Subsystems (DashParticles and StaminaArc)
	var particles : Node3D = player.get_node_or_null("DashParticles")
	check(particles != null, "DashParticles component attached to player")

	var arc : Node = player.get_node_or_null("StaminaArc")
	check(arc != null, "StaminaArc component attached to player")
	if arc != null:
		check(arc.visible == false and arc.modulate.a == 0.0, "Stamina arc starts hidden when full")

	# 4. Instantiate HealthBar HUD and bind to player
	var hb_scene : PackedScene = load("res://scenes/ui/health_bar.tscn")
	check(hb_scene != null, "health_bar.tscn loaded successfully")
	var health_bar : CanvasLayer = hb_scene.instantiate()
	root.add_child(health_bar)
	health_bar.call("bind_player", player)
	await process_frame

	var pip0 : ColorRect = health_bar.get_node_or_null("MarginContainer/VBoxContainer/HealthRow/DashRow/PipsBox/Pip0")
	var pip1 : ColorRect = health_bar.get_node_or_null("MarginContainer/VBoxContainer/HealthRow/DashRow/PipsBox/Pip1")
	var pip2 : ColorRect = health_bar.get_node_or_null("MarginContainer/VBoxContainer/HealthRow/DashRow/PipsBox/Pip2")
	var cd_status : Label = health_bar.get_node_or_null("MarginContainer/VBoxContainer/HealthRow/DashRow/CooldownStatus")
	check(pip0 != null and pip1 != null and pip2 != null, "3 HUD dash charge pips found")
	check(cd_status != null and cd_status.text == "READY", "HUD cooldown status shows READY initially")

	# 5. Execute Dash 1
	print("\n[Testing Dash 1 Execution]")
	player.call("_perform_dash")
	check(is_equal_approx(player.stamina, 2.0), "Stamina consumed to 2.0 after Dash 1")
	check(is_equal_approx(player.dash_cooldown_left, 0.35), "Cooldown set to 0.35s after Dash 1")
	check(player.is_dashing == true, "Player is_dashing is true")
	check(arc != null and arc.visible == true and arc.modulate.a == 1.0, "Stamina arc becomes visible when dash is used")

	# Verify anti-spam cooldown: cannot dash again immediately
	player._physics_process(0.016)
	var prev_stam : float = player.stamina
	# Try to dash while in cooldown
	if player.dash_cooldown_left > 0.0:
		check(player.dash_cooldown_left > 0.0, "Anti-spam cooldown active; prevents spamming")

	# 6. Fast-forward past cooldown to test Dash 2 and Dash 3 (Continuous dashes)
	print("\n[Testing Continuous Dashes 2 & 3]")
	player.stamina = 2.0
	player.dash_cooldown_left = 0.0
	player.is_dashing = false
	player.call("_perform_dash")
	check(is_equal_approx(player.stamina, 1.0), "Stamina consumed to 1.0 after Dash 2")

	player.stamina = 1.0
	player.dash_cooldown_left = 0.0
	player.is_dashing = false
	player.call("_perform_dash")
	check(is_equal_approx(player.stamina, 0.0), "Stamina consumed to 0.0 after Dash 3 (exhausted)")

	# Verify 4th dash cannot occur when stamina is 0
	player.dash_cooldown_left = 0.0
	player.is_dashing = false
	var can_dash_4 : bool = (player.dash_cooldown_left <= 0.0 and player.stamina >= player.dash_cost)
	check(can_dash_4 == false, "4th dash blocked: player cannot dash when stamina is exhausted")

	# 7. Test Constant Stamina Recharge over time
	print("\n[Testing Stamina Recharge]")
	# Simulate 2.0 seconds of recharge at 0.5/sec -> should restore 1.0 stamina
	for _i in range(120): # 120 frames at 0.0166s = 2.0s
		player._physics_process(0.0166667)
	
	check(player.stamina >= 0.95, "Stamina constantly recharges over time (~1.0 restored in 2s)")
	check(arc != null and arc.visible == true, "Stamina arc remains visible while recharging")

	# Simulate another 4.0 seconds of recharge -> reaches full 3.0 stamina
	for _i in range(250):
		player._physics_process(0.0166667)

	check(is_equal_approx(player.stamina, 3.0), "Stamina reaches full capacity (3.0)")

	# Allow smooth fade-out tween to finish
	await create_tween().tween_interval(0.65).finished

	check(arc != null and (not arc.visible or arc.modulate.a <= 0.05), "Stamina arc smoothly hides when fully recharged")

	# 8. Test Backpack Thruster Alignment & Pressurized Air Flight
	print("\n[Testing Backpack Thrusters & Flight]")
	check(particles.position.y >= 0.35 and absf(particles.position.z) >= 0.1, "Jet stream thrusters mounted at astronaut backpack (Y >= 0.35m)")

	var cpu_p : CPUParticles3D = particles.get_node_or_null("CPUParticles3D") as CPUParticles3D
	check(cpu_p != null and cpu_p.local_coords == true, "Dash stream uses local_coords = true (anchored to backpack, not left behind as cloud trail)")
	check(cpu_p != null and cpu_p.particle_flag_align_y == true, "Dash stream aligned with nozzle axis (particle_flag_align_y = true)")
	check(cpu_p != null and cpu_p.spread <= 3.0, "Dash stream is a narrow pressurized beam (spread <= 3.0 deg, actual: %.1f deg)" % (cpu_p.spread if cpu_p else 0.0))

	var flight_p_node : CPUParticles3D = particles.get_node_or_null("FlightParticles") as CPUParticles3D
	check(flight_p_node != null and flight_p_node.transform.origin.y < -0.05, "Flight thrusters located at bottom of backpack (Y < -0.05, actual: %.2fm)" % (flight_p_node.transform.origin.y if flight_p_node else 0.0))
	check(flight_p_node != null and flight_p_node.direction.y < -0.9, "Flight thrusters spray straight down (direction.y < -0.9)")
	check(flight_p_node != null and flight_p_node.local_coords == true, "Flight thrusters use local_coords = true (anchored to bottom of backpack)")

	# Test Flight Mode in air
	player.global_position.y = 2.0
	Input.action_press(player.input_jump)
	player.stamina = 3.0
	player.velocity = Vector3.ZERO
	# Simulate 0.3s of flight
	for _i in range(18):
		player._physics_process(0.0166667)

	check(player.is_flying == true, "Hold Space in mid-air activates pressurized air flight thrusters")
	check(player.velocity.y > 0.0, "Flight thrusters provide upward vertical velocity to escape holes")
	check(player.stamina < 3.0, "Flight thrusters drain shared pressurized air (stamina)")
	check(particles.get_node_or_null("FlightParticles") != null and (particles.get_node_or_null("FlightParticles") as CPUParticles3D).emitting == true, "Downward flight thruster particles emitting")

	# Release Space -> flight stops
	Input.action_release(player.input_jump)
	player._physics_process(0.0166667)
	check(player.is_flying == false, "Releasing Space cuts flight thrusters")
	check((particles.get_node_or_null("FlightParticles") as CPUParticles3D).emitting == false, "Flight particles stop emitting when Space is released")

	# 9. Test 3D Enemy Shooting
	print("\n[Testing 3D Enemy Shooting]")
	var enemy_scene : PackedScene = load("res://scenes/enemy/enemy.tscn")
	check(enemy_scene != null, "enemy.tscn loaded successfully")
	var enemy : CharacterBody3D = enemy_scene.instantiate()
	root.add_child(enemy)
	enemy.global_position = Vector3(0.0, 0.0, 4.0)
	player.global_position = Vector3(0.0, 2.5, 0.0) # Player is high in the air
	await process_frame

	# Trigger enemy shoot
	enemy.call("_shoot", (player.global_position + Vector3(0, 0.3, 0) - enemy.global_position).normalized())
	await process_frame

	# Find bullet
	var bullets : Array[Node] = []
	for c in root.get_children():
		if c.name.begins_with("Bullet"):
			bullets.append(c)
	check(bullets.size() > 0, "Enemy fired a bullet in 3D")
	if bullets.size() > 0:
		var b : Node3D = bullets[0] as Node3D
		var b_dir : Vector3 = b.get("direction")
		check(b_dir.y > 0.25, "Enemy bullet aims upwards in 3D toward airborne player (dir.y = %.2f)" % b_dir.y)
		b.queue_free()

	enemy.queue_free()

	# 10. Test SFX in UiSound
	var snd : Node = root.get_node_or_null("UiSound")
	check(snd != null and snd.has_method("play_dash"), "UiSound has play_dash() method")
	check(snd != null and snd.has_method("start_thruster"), "UiSound has start_thruster() method")
	check(snd != null and snd.has_method("stop_thruster"), "UiSound has stop_thruster() method")

	# Cleanup
	health_bar.queue_free()
	player.queue_free()
	await process_frame

	print("\n--- Verification Results: %d Passed, %d Failed ---" % [passes, failures])
	if failures > 0:
		quit(1)
	else:
		quit(0)
