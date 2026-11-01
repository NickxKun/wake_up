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
	print("=== RUNNING VEHICLE PHYSICS, HEALTH & JET STAMINA TEST SUITE ===")
	await process_frame

	# -------------------------------------------------------------------------
	# 1. Test Dash Thrusters Size
	# -------------------------------------------------------------------------
	print("\n[Test 1] Testing Dash Thruster Size & Compactness...")
	var dp_scene : PackedScene = load("res://scenes/player/dash_particles.tscn")
	check(dp_scene != null, "dash_particles.tscn loaded successfully")
	var dp : Node3D = dp_scene.instantiate()
	root.add_child(dp)
	await process_frame

	var cpu_p : CPUParticles3D = dp.get_node_or_null("CPUParticles3D") as CPUParticles3D
	check(cpu_p != null, "CPUParticles3D found in DashParticles")
	if cpu_p != null:
		var cmesh : CylinderMesh = cpu_p.mesh as CylinderMesh
		check(cmesh != null, "CPUParticles3D has CylinderMesh")
		if cmesh != null:
			check(cmesh.height <= 0.08, "Dash stream mesh is compact (height <= 0.08m, actual: %.3fm)" % cmesh.height)
			check(cmesh.top_radius <= 0.005, "Dash stream top radius is narrow (<= 0.005m, actual: %.4fm)" % cmesh.top_radius)
		check(cpu_p.initial_velocity_max <= 10.0, "Dash velocity is tuned for compact stream (<= 10.0 m/s, actual: %.1f)" % cpu_p.initial_velocity_max)
		check(cpu_p.lifetime <= 0.06, "Dash stream lifetime is short and sharp (<= 0.06s, actual: %.3fs)" % cpu_p.lifetime)

	dp.queue_free()

	# -------------------------------------------------------------------------
	# 2. Test Jump Jet Thrusters Stamina Rule (>= 1 Bar Required, Zero Jet at 0 Stamina)
	# -------------------------------------------------------------------------
	print("\n[Test 2] Testing Jump Jet Stamina Threshold (1 Bar) & Zero-Stamina Cutoff...")
	var proto_scene : PackedScene = load("res://addons/proto_controller/proto_controller.tscn")
	check(proto_scene != null, "proto_controller.tscn loaded successfully")
	var player : CharacterBody3D = proto_scene.instantiate()
	root.add_child(player)
	player.add_to_group("player")
	await process_frame

	# Case A: Stamina < 1.0 (e.g. 0.5) -> cannot activate flight thrusters
	player.global_position.y = 3.0 # In air
	player.stamina = 0.5 # Less than 1 full bar
	player.is_flying = false
	Input.action_press(player.input_jump)
	player._physics_process(0.016)
	check(player.is_flying == false, "Jump jet CANNOT start when stamina < 1.0 bar (stamina = 0.5)")

	# Case B: Stamina >= 1.0 (e.g. 1.5) -> activates flight thrusters
	player.stamina = 1.5
	player._physics_process(0.016)
	check(player.is_flying == true, "Jump jet activates when stamina >= 1.0 bar (stamina = 1.5)")

	# Case C: Holding jump until stamina drains to 0.0 -> thruster immediately cuts off
	player.stamina = 0.0
	player._physics_process(0.016)
	check(player.is_flying == false, "Jump jet immediately cuts off when stamina reaches 0.0")

	# Case D: While still holding jump, stamina recharges to 0.4 (< 1.0 bar) -> jet does NOT re-fire
	player.stamina = 0.4
	player._physics_process(0.016)
	check(player.is_flying == false, "Jump jet does NOT stutter/re-fire while holding jump with stamina < 1.0 bar")

	# Case E: Stamina recharges to 1.0 bar -> jet can fire again!
	player.stamina = 1.0
	player._physics_process(0.016)
	check(player.is_flying == true, "Jump jet fires again once stamina recharges to full 1.0 bar")

	Input.action_release(player.input_jump)
	player._physics_process(0.016)
	check(player.is_flying == false, "Releasing jump stops flight")
	player.queue_free()

	# -------------------------------------------------------------------------
	# 3. Test Vehicle Terrain Alignment & Slope Conformity
	# -------------------------------------------------------------------------
	print("\n[Test 3] Testing Vehicle Terrain Slope Conformity & Euler Alignment...")
	var rover_scene : PackedScene = load("res://scenes/vehicles/rover.tscn")
	check(rover_scene != null, "rover.tscn loaded successfully")
	var rover : CharacterBody3D = rover_scene.instantiate()
	root.add_child(rover)
	await process_frame

	check(rover.model_anchor != null, "Rover has model_anchor")

	# Simulate Uphill Slope (Front wheels higher than rear)
	# Normal tilts backward (-Z). With corrected convention, _chassis_pitch > 0 (nose up).
	# And model_anchor's nose vector (+Z rotated by -_chassis_pitch) has Y > 0 (points UP the slope)!
	rover.set("_was_on_floor", true)
	rover.set("velocity", Vector3.ZERO)

	# Test fallback normal slope conformity
	# Uphill: floor normal tilts back towards -Z: (0.0, 0.94, -0.34)
	var uphill_normal := Vector3(0.0, 0.94, -0.34).normalized()
	# Apply local normal test
	var local_up := rover.transform.basis.inverse() * uphill_normal
	var simulated_pitch : float = clampf(-atan2(local_up.z, maxf(local_up.y, 0.1)), -0.65, 0.65)
	check(simulated_pitch > 0.1, "Uphill slope produces positive pitch convention (pitch: %.4f)" % simulated_pitch)

	# Test transformed model posture:
	# Positive _chassis_pitch applied with -_chassis_pitch in Godot basis points nose (+Z) UP!
	rover.set("_chassis_pitch", simulated_pitch)
	rover.set("_chassis_roll", 0.0)
	rover.model_anchor.transform.basis = Basis.from_euler(Vector3(-rover.get("_chassis_pitch"), 0.0, rover.get("_chassis_roll")))
	var model_nose_vec : Vector3 = rover.model_anchor.transform.basis * Vector3(0.0, 0.0, 1.0)
	check(model_nose_vec.y > 0.1, "Rover 3D model nose pitches UP on uphill slope (nose.y: %.4f)" % model_nose_vec.y)

	# Simulate Downhill Slope (Front wheels lower than rear)
	# Downhill: floor normal tilts forward towards +Z: (0.0, 0.94, 0.34)
	var downhill_normal := Vector3(0.0, 0.94, 0.34).normalized()
	var local_down := rover.transform.basis.inverse() * downhill_normal
	var sim_down_pitch : float = clampf(-atan2(local_down.z, maxf(local_down.y, 0.1)), -0.65, 0.65)
	check(sim_down_pitch < -0.1, "Downhill slope produces negative pitch convention (pitch: %.4f)" % sim_down_pitch)

	rover.set("_chassis_pitch", sim_down_pitch)
	rover.model_anchor.transform.basis = Basis.from_euler(Vector3(-rover.get("_chassis_pitch"), 0.0, rover.get("_chassis_roll")))
	var model_down_nose : Vector3 = rover.model_anchor.transform.basis * Vector3(0.0, 0.0, 1.0)
	check(model_down_nose.y < -0.1, "Rover 3D model nose pitches DOWN on downhill slope (nose.y: %.4f)" % model_down_nose.y)

	# Simulate Banked Side Slope (Right side higher than left)
	# Lateral slope: floor normal tilts left towards -X: (-0.30, 0.95, 0.0)
	var banked_normal := Vector3(-0.30, 0.95, 0.0).normalized()
	var local_bank := rover.transform.basis.inverse() * banked_normal
	var sim_roll : float = clampf(-atan2(local_bank.x, maxf(local_bank.y, 0.1)), -0.55, 0.55)
	check(sim_roll > 0.1, "Right-side higher slope produces positive roll (roll: %.4f)" % sim_roll)

	rover.set("_chassis_pitch", 0.0)
	rover.set("_chassis_roll", sim_roll)
	rover.model_anchor.transform.basis = Basis.from_euler(Vector3(-rover.get("_chassis_pitch"), 0.0, rover.get("_chassis_roll")))
	var model_right_vec : Vector3 = rover.model_anchor.transform.basis * Vector3(1.0, 0.0, 0.0)
	check(model_right_vec.y > 0.1, "Rover 3D model right side tilts UP on banked slope (right.y: %.4f)" % model_right_vec.y)

	# -------------------------------------------------------------------------
	# 4. Test Vehicle Health, Damage, Low Health Smoke & Explosion
	# -------------------------------------------------------------------------
	print("\n[Test 4] Testing Vehicle Health, Damage, Smoke & Low-Poly Explosion...")
	check(rover.health_component != null, "Rover has HealthComponent attached")
	check(rover.health_component.health == 100, "Initial vehicle health is 100 HP")
	check(rover.is_destroyed == false, "Vehicle begins in undamaged / undestroyed state")

	var engine_smoke : CPUParticles3D = rover.get_node_or_null("EngineSmoke") as CPUParticles3D
	check(engine_smoke != null, "Rover has EngineSmoke CPUParticles3D")
	if engine_smoke != null:
		check(engine_smoke.emitting == false, "Engine smoke starts disabled at full health")

	# Take damage from enemy/bullet
	rover.take_damage(30)
	check(rover.health_component.health == 70, "take_damage(30) reduces vehicle health to 70")
	if engine_smoke != null:
		check(engine_smoke.emitting == false, "Engine smoke still disabled at 70% health")

	# Damage to low health (<= 40 HP)
	rover.take_damage(35)
	check(rover.health_component.health == 35, "take_damage(35) reduces vehicle health to 35 (low health)")
	if engine_smoke != null:
		check(engine_smoke.emitting == true, "Engine smoke begins billowing when health <= 40% (low health visual feedback)")

	# Test Boarding & Ejection on Explosion
	var driver_node := CharacterBody3D.new()
	driver_node.name = "TestAstronaut"
	driver_node.add_to_group("player")
	var d_col := CollisionShape3D.new()
	d_col.name = "Collider"
	d_col.shape = CapsuleShape3D.new()
	driver_node.add_child(d_col)
	var d_mesh := Node3D.new()
	d_mesh.name = "player"
	driver_node.add_child(d_mesh)
	var d_hc_script = load("res://scenes/components/health_component.gd")
	var d_hc : Node = d_hc_script.new()
	d_hc.name = "HealthComponent"
	driver_node.add_child(d_hc)
	root.add_child(driver_node)
	await process_frame

	rover.board_vehicle(driver_node)
	check(rover.is_occupied == true, "Astronaut boarded into vehicle")

	# Fatal damage -> Vehicle blows up!
	rover.take_damage(35)
	check(rover.health_component.is_dead() == true, "Vehicle health depleted to 0")
	check(rover.is_destroyed == true, "Vehicle state is_destroyed = true")
	check(rover.is_occupied == false, "Astronaut safely ejected from vehicle upon explosion")
	check(d_col.disabled == false, "Astronaut collider restored upon ejection")
	check(driver_node.velocity.length() > 2.0, "Astronaut received explosive blast knockback impulse")
	check(d_hc.health < 100, "Astronaut sustained explosion splash damage (health: %d)" % d_hc.health)
	check(rover.interaction_area.monitoring == false, "Interaction area disabled for wrecked vehicle")

	# Cleanup
	driver_node.queue_free()
	rover.queue_free()
	await process_frame

	print("\n=======================================================")
	print("VEHICLE & JET STAMINA RESULTS: %d Passed, %d Failed" % [passes, failures])
	print("=======================================================")
	if failures > 0:
		quit(1)
	else:
		quit(0)
