class_name Rover
extends CharacterBody3D

## Drivable sci-fi ground vehicle with realistic arcade handling,
## accurate multi-point slope conformity, health system, low-poly destruction,
## smooth halogen headlights (L key), horn (H key), and boarding (E key).

signal boarded(driver: CharacterBody3D)
signal dismounted(driver: CharacterBody3D)
signal lights_toggled(is_on: bool)
signal horn_honked()
signal health_changed(new_health: int, old_health: int)
signal destroyed()

const TARGET_HEADLIGHT_ENERGY : float = 2.4
const TARGET_TAILLIGHT_ENERGY : float = 0.5
const BRAKE_TAILLIGHT_ENERGY : float = 1.6

@export_group("Vehicle Identity")
@export var vehicle_name : String = "Scout Rover"
@export var model_scene : PackedScene = preload("res://assets/models/fbx/spacetruck.fbx")
@export var requires_explorer : bool = false
const EXPLOSION_EFFECT_SCENE : PackedScene = preload("res://scenes/projectiles/explosion_effect.tscn")
const VEHICLE_BULLET_SCENE : PackedScene = preload("res://scenes/projectiles/bullet.tscn")
const VEHICLE_CANNON_COOLDOWN : float = 0.28
var _cannon_cooldown : float = 0.0

@export_group("Handling & Performance")
## Peak forward velocity in m/s.
@export var max_speed : float = 4.8
## Peak reverse velocity in m/s.
@export var max_reverse_speed : float = 2.4
## Acceleration forward in m/s².
@export var acceleration : float = 8.0
## Reverse acceleration in m/s².
@export var reverse_acceleration : float = 5.5
## Deceleration when coasting without throttle in m/s².
@export var coast_deceleration : float = 4.5
## Braking deceleration with handbrake in m/s².
@export var brake_deceleration : float = 16.0
## Steering turn speed in radians per second.
@export var turn_speed : float = 2.8
## Peak front wheel turn angle in radians (~30 degrees).
@export var max_steer_angle : float = 0.52
## Multiplied into speed to calculate ramming damage against hostile robots.
@export var ram_damage_multiplier : float = 20.0

var is_occupied : bool = false
var is_destroyed : bool = false
var lights_on : bool = false
var current_speed : float = 0.0
var current_steer_angle : float = 0.0
var _is_braking : bool = false
var _boarding_cooldown : float = 0.0
var _e_key_was_pressed : bool = false
var _l_key_was_pressed : bool = false
var _lights_cooldown : float = 0.0
var _throttle_input : float = 0.0
var _prev_speed : float = 0.0

var _driver : CharacterBody3D = null
var _nearby_player : CharacterBody3D = null
var _wheel_fl : MeshInstance3D = null
var _wheel_fr : MeshInstance3D = null
var _wheel_rl : MeshInstance3D = null
var _wheel_rr : MeshInstance3D = null
var _wheel_roll_angle : float = 0.0

# Chassis dynamics & suspension physics
var _chassis_pitch : float = 0.0
var _chassis_roll : float = 0.0
var _chassis_y_offset : float = 0.0
var _suspension_bounce : float = 0.0
var _was_on_floor : bool = true
var _tail_material : StandardMaterial3D = null
var _current_headlight_energy : float = 0.0

@onready var health_component : HealthComponent = $HealthComponent
@onready var model_anchor : Node3D = $ModelAnchor
@onready var interaction_area : Area3D = $InteractionArea
@onready var drive_prompt : Label3D = $PromptAnchor/DrivePrompt
@onready var camera_remote : RemoteTransform3D = $RemoteTransform3D
@onready var headlights_group : Node3D = $Headlights
@onready var taillights_group : Node3D = $Taillights
@onready var left_headlight : SpotLight3D = $Headlights/LeftLight
@onready var right_headlight : SpotLight3D = $Headlights/RightLight
@onready var left_taillight : OmniLight3D = $Taillights/LeftTail
@onready var right_taillight : OmniLight3D = $Taillights/RightTail
@onready var left_tail_square : MeshInstance3D = get_node_or_null("Taillights/LeftTailSquare") as MeshInstance3D
@onready var right_tail_square : MeshInstance3D = get_node_or_null("Taillights/RightTailSquare") as MeshInstance3D
@onready var backup_ground_square : MeshInstance3D = get_node_or_null("Taillights/BackupGroundSquare") as MeshInstance3D
@onready var vehicle_health_bar : Sprite3D = get_node_or_null("PromptAnchor/VehicleHealthBar") as Sprite3D
@onready var tire_dust : CPUParticles3D = get_node_or_null("TireDust") as CPUParticles3D
@onready var engine_smoke : CPUParticles3D = get_node_or_null("EngineSmoke") as CPUParticles3D
@onready var explosion_burst : CPUParticles3D = get_node_or_null("ExplosionBurst") as CPUParticles3D
@onready var gatling_turret : Node3D = find_child("GatlingTurret", true, false) as Node3D

func _ready() -> void:
	add_to_group("vehicle")
	add_to_group("drivable")

	# Instance vehicle visual model if not already present
	_setup_model()

	# Connect proximity interaction area
	if interaction_area != null:
		interaction_area.body_entered.connect(_on_interaction_area_entered)
		interaction_area.body_exited.connect(_on_interaction_area_exited)

	if drive_prompt != null:
		drive_prompt.visible = false
		drive_prompt.text = "[E] Drive " + vehicle_name

	# Initialize health component
	if health_component == null:
		health_component = HealthComponent.new()
		health_component.name = "HealthComponent"
		add_child(health_component)
	health_component.health_changed.connect(_on_health_changed)
	health_component.health_depleted.connect(_on_health_depleted)
	if vehicle_health_bar != null:
		vehicle_health_bar.bind_health_component(health_component)

	# Initialize shared dynamic material for tail square meshes
	if left_tail_square != null:
		var orig_mat : Material = left_tail_square.get_active_material(0)
		if orig_mat is StandardMaterial3D:
			_tail_material = (orig_mat as StandardMaterial3D).duplicate() as StandardMaterial3D
		else:
			_tail_material = StandardMaterial3D.new()
			_tail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_tail_material.albedo_color = Color(0.18, 0.04, 0.04, 1.0)
			_tail_material.emission_enabled = true
			_tail_material.emission = Color(1.0, 0.15, 0.1, 1.0)
			_tail_material.emission_energy_multiplier = 0.0
		left_tail_square.set_surface_override_material(0, _tail_material)
		if right_tail_square != null:
			right_tail_square.set_surface_override_material(0, _tail_material)

	# Set initial lighting state
	_apply_lights()

func _setup_model() -> void:
	if model_anchor != null and model_anchor.get_node_or_null("VehicleVisualModel") == null and model_scene != null:
		var model_inst : Node3D = model_scene.instantiate() as Node3D
		if model_inst != null:
			model_inst.name = "VehicleVisualModel"
			model_anchor.add_child(model_inst)

	# Clean up any weird emission or glow on the imported vehicle model
	# and cache wheel mesh instances for dynamic steering and roll animation
	if model_anchor != null:
		for c in model_anchor.find_children("*", "MeshInstance3D", true, false):
			var mi := c as MeshInstance3D
			mi.layers = 2

			# Strip unintended FBX emission from materials to prevent bloom glow
			if mi.mesh != null:
				for surf_idx in range(mi.mesh.get_surface_count()):
					var orig_mat = mi.get_active_material(surf_idx)
					if orig_mat is StandardMaterial3D:
						var clean_mat : StandardMaterial3D = orig_mat.duplicate() as StandardMaterial3D
						clean_mat.emission_enabled = false
						clean_mat.emission = Color.BLACK
						clean_mat.emission_energy_multiplier = 0.0
						mi.set_surface_override_material(surf_idx, clean_mat)

			var lname := mi.name.to_lower()
			if lname.ends_with("wheel_front_left") or lname.ends_with("wheel_fl"):
				_wheel_fl = mi
			elif lname.ends_with("wheel_front_right") or lname.ends_with("wheel_fr"):
				_wheel_fr = mi
			elif lname.ends_with("wheel_rear_left") or lname.ends_with("wheel_rl"):
				_wheel_rl = mi
			elif lname.ends_with("wheel_rear_right") or lname.ends_with("wheel_rr"):
				_wheel_rr = mi

func _physics_process(delta: float) -> void:
	if is_destroyed:
		velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)
		if not is_on_floor():
			velocity += get_gravity() * delta
		move_and_slide()
		return

	# Tick down boarding debounce cooldown
	if _boarding_cooldown > 0.0:
		_boarding_cooldown -= delta

	# Tick down lights toggle debounce cooldown
	if _lights_cooldown > 0.0:
		_lights_cooldown -= delta

	# Edge-triggered interact detection
	var e_key_now : bool = Input.is_physical_key_pressed(KEY_E) or Input.is_key_pressed(KEY_E)
	var interact_triggered : bool = Input.is_action_just_pressed("interact") or (e_key_now and not _e_key_was_pressed)
	_e_key_was_pressed = e_key_now

	# Edge-triggered lights toggle detection
	var l_key_now : bool = Input.is_physical_key_pressed(KEY_L) or Input.is_key_pressed(KEY_L)
	var lights_triggered : bool = Input.is_action_just_pressed("vehicle_lights") or (l_key_now and not _l_key_was_pressed)
	_l_key_was_pressed = l_key_now

	if not is_on_floor():
		velocity += get_gravity() * delta

	if not is_occupied:
		_throttle_input = 0.0
		_is_braking = false

		# Unoccupied: coast to a complete stop
		if absf(current_speed) > 0.01:
			current_speed = move_toward(current_speed, 0.0, coast_deceleration * delta)
			var forward_vec : Vector3 = transform.basis.z
			velocity.x = forward_vec.x * current_speed
			velocity.z = forward_vec.z * current_speed
			move_and_slide()
		else:
			current_speed = 0.0
			velocity.x = 0.0
			velocity.z = 0.0

		_update_wheels(delta)
		_update_chassis_physics(delta)
		_update_lighting(delta)

		# Continuously verify nearby player presence when unoccupied
		_refresh_nearby_player()

		if _nearby_player != null and is_instance_valid(_nearby_player):
			var can_drive : bool = not requires_explorer or _is_player_explorer(_nearby_player)
			if drive_prompt != null:
				drive_prompt.visible = _boarding_cooldown <= 0.0
				var hp_pct : int = int(round(float(health_component.health) / float(HealthComponent.MAX_HEALTH) * 100.0))
				if can_drive:
					drive_prompt.text = "[E] Drive %s (Hull: %d%%)" % [vehicle_name, hp_pct]
				else:
					drive_prompt.text = "[E] %s (Explorer Required)" % vehicle_name
			if interact_triggered and _boarding_cooldown <= 0.0:
				if can_drive:
					board_vehicle(_nearby_player)
				else:
					_boarding_cooldown = 0.35
					var snd : Node = get_node_or_null("/root/UiSound")
					if snd != null and snd.has_method("play_denied"):
						snd.play_denied()
		else:
			if drive_prompt != null:
				drive_prompt.visible = false
		return

	# Vehicle mounted Gatling Cannon for Explorer operative (Halo Warthog style)
	if _is_player_explorer(_driver):
		if gatling_turret == null:
			gatling_turret = find_child("GatlingTurret", true, false) as Node3D
		if gatling_turret != null:
			var aim_target : Vector3 = _get_aim_target(gatling_turret.global_position)
			gatling_turret.track_aim(aim_target, delta)
			if Input.is_action_pressed("shoot") and gatling_turret.is_deployed:
				var bullet : Area3D = gatling_turret.fire(aim_target)
				if bullet != null:
					_suspension_bounce = -0.015
		else:
			if _cannon_cooldown > 0.0:
				_cannon_cooldown = maxf(_cannon_cooldown - delta, 0.0)
			if Input.is_action_pressed("shoot") and _cannon_cooldown <= 0.0:
				_cannon_cooldown = VEHICLE_CANNON_COOLDOWN
				_fire_vehicle_cannons()

	# Handle exit when pressing E inside the vehicle (with debounce check)
	if interact_triggered and _boarding_cooldown <= 0.0:
		exit_vehicle()
		return

	# Handle horn (H key)
	if Input.is_action_just_pressed("vehicle_honk") or Input.is_key_pressed(KEY_H):
		honk()

	# Handle headlights (L key) with clean edge-trigger debounce
	if lights_triggered and _lights_cooldown <= 0.0:
		_lights_cooldown = 0.25
		toggle_lights()

	# Driving controls
	_handle_driving_input(delta)

	# Wheel animation & tire dust
	_update_wheels(delta)

	# Dynamic chassis suspension physics & slope conformity
	_update_chassis_physics(delta)

	# Smooth lighting updates & glowing square taillights/backup lights
	_update_lighting(delta)

	# Ramming enemies
	_check_ramming_collisions()

	# Keep driver anchored to vehicle position
	if is_instance_valid(_driver):
		_driver.global_position = global_position
		var hc : Node = _driver.get_node_or_null("HealthComponent")
		if hc != null and hc.has_method("is_dead") and hc.call("is_dead"):
			exit_vehicle()

func _handle_driving_input(delta: float) -> void:
	# Throttle input (W / Up = forward, S / Down = reverse)
	var throttle : float = 0.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) or Input.is_action_pressed("ui_up") or Input.is_action_pressed("move_up"):
		throttle += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN) or Input.is_action_pressed("ui_down") or Input.is_action_pressed("move_down"):
		throttle -= 1.0
	_throttle_input = throttle

	# Steering input: A / Left = Steer Left (+X), D / Right = Steer Right (-X)
	var steer_raw : float = 0.0
	var press_left : bool = Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT) or Input.is_action_pressed("ui_left") or Input.is_action_pressed("move_left")
	var press_right : bool = Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT) or Input.is_action_pressed("ui_right") or Input.is_action_pressed("move_right")

	if press_left:
		steer_raw += 1.0
	if press_right:
		steer_raw -= 1.0

	# Handbrake (Space)
	_is_braking = Input.is_action_pressed("jump") or Input.is_key_pressed(KEY_SPACE)

	# Speed adjustment
	if _is_braking:
		current_speed = move_toward(current_speed, 0.0, brake_deceleration * delta)
	elif throttle > 0.0:
		current_speed = move_toward(current_speed, max_speed, acceleration * delta)
	elif throttle < 0.0:
		current_speed = move_toward(current_speed, -max_reverse_speed, reverse_acceleration * delta)
	else:
		current_speed = move_toward(current_speed, 0.0, coast_deceleration * delta)

	# Dynamic steering: smoothly adjust angle and yaw
	current_steer_angle = move_toward(current_steer_angle, steer_raw * max_steer_angle, 6.0 * delta)
	if absf(current_steer_angle) > 0.001:
		var speed_factor : float = clampf(absf(current_speed) / 2.0, 0.45, 1.0)
		var turn_dir : float = 1.0 if current_speed >= -0.05 else -1.0
		rotation.y += current_steer_angle * turn_speed * speed_factor * turn_dir * delta

	# Forward velocity vector (+Z is forward for the SpaceBits truck)
	var forward_vec : Vector3 = transform.basis.z
	velocity.x = forward_vec.x * current_speed
	velocity.z = forward_vec.z * current_speed

	move_and_slide()

func _is_another_vehicle_closer(player: CharacterBody3D) -> bool:
	if get_tree() == null or player == null or not is_instance_valid(player):
		return false
	var my_dist: float = global_position.distance_to(player.global_position)
	var vehicles := get_tree().get_nodes_in_group("vehicle")
	for v in vehicles:
		if v != self and is_instance_valid(v) and (v is Node3D):
			var n3d := v as Node3D
			if not bool(n3d.get("is_occupied")):
				var other_dist: float = n3d.global_position.distance_to(player.global_position)
				if other_dist < my_dist - 0.05 or (abs(other_dist - my_dist) <= 0.05 and n3d.get_instance_id() < get_instance_id()):
					return true
	return false

func _refresh_nearby_player() -> void:
	if _nearby_player != null and is_instance_valid(_nearby_player):
		if _nearby_player.get("is_driving_vehicle") == true or _nearby_player.is_in_group("driving") or _nearby_player.has_meta("current_vehicle"):
			_nearby_player = null
			return
		if global_position.distance_to(_nearby_player.global_position) > 3.4:
			_nearby_player = null
			return
		if _is_another_vehicle_closer(_nearby_player):
			_nearby_player = null
		return

	var candidate : CharacterBody3D = null
	if interaction_area != null:
		for b in interaction_area.get_overlapping_bodies():
			if b.is_in_group("player") and (b is CharacterBody3D):
				candidate = b as CharacterBody3D
				break

	if candidate == null and get_tree() != null:
		var p_node := get_tree().get_first_node_in_group("player") as CharacterBody3D
		if p_node != null and is_instance_valid(p_node):
			if global_position.distance_to(p_node.global_position) <= 2.2:
				candidate = p_node

	if candidate != null and is_instance_valid(candidate):
		if candidate.get("is_driving_vehicle") == true or candidate.is_in_group("driving") or candidate.has_meta("current_vehicle"):
			_nearby_player = null
			return
		if _is_another_vehicle_closer(candidate):
			_nearby_player = null
			return
		_nearby_player = candidate

## Boards the astronaut into the rover and transfers driving controls.
func board_vehicle(player: CharacterBody3D) -> void:
	if is_occupied or is_destroyed or player == null or not is_instance_valid(player):
		return
	# Strict protection against boarding multiple vehicles simultaneously
	if player.get("is_driving_vehicle") == true or player.is_in_group("driving") or player.has_meta("current_vehicle"):
		return
	# Enforce class authorization on heavy transports
	if requires_explorer and not _is_player_explorer(player):
		return

	is_occupied = true
	_driver = player
	_boarding_cooldown = 0.4
	_e_key_was_pressed = true

	# Mark the driver as actively driving this vehicle
	_driver.set("is_driving_vehicle", true)
	_driver.add_to_group("driving")
	_driver.set_meta("current_vehicle", self)

	if drive_prompt != null:
		drive_prompt.visible = false

	# Play hatch boarding sound
	var snd : Node = get_node_or_null("/root/UiSound")
	if snd != null and snd.has_method("play_vehicle_enter"):
		snd.play_vehicle_enter()

	# Cleanly cancel any active dash or flight states on the astronaut
	if "is_dashing" in _driver:
		_driver.set("is_dashing", false)
	if "is_flying" in _driver:
		_driver.set("is_flying", false)

	var dash_particles : Node = _driver.get_node_or_null("DashParticles")
	if dash_particles != null:
		if dash_particles.has_method("stop_dash"):
			dash_particles.call("stop_dash")
		if dash_particles.has_method("set_flying"):
			dash_particles.call("set_flying", false)

	if snd != null and snd.has_method("stop_thruster"):
		snd.call("stop_thruster")

	# Disable foot movement, collision, and combat
	_driver.velocity = Vector3.ZERO
	_driver.global_position = global_position
	_driver.set_physics_process(false)

	var col : CollisionShape3D = _driver.get_node_or_null("Collider") as CollisionShape3D
	if col != null:
		col.set_deferred("disabled", true)

	var p_mesh : Node3D = _driver.get_node_or_null("player") as Node3D
	if p_mesh != null:
		p_mesh.visible = false

	var pc : Node = _driver.get_node_or_null("PlayerCombat")
	if pc != null:
		pc.set_process_unhandled_input(false)

	var stamina_arc : Node = _driver.get_node_or_null("StaminaArc")
	if stamina_arc != null and stamina_arc is Node3D:
		(stamina_arc as Node3D).visible = false

	# Tactile suspension dip feedback when boarding
	_suspension_bounce = -0.035

	# Transfer camera rig to follow rover
	var tree : SceneTree = get_tree()
	var camera_rig : Node3D = tree.get_first_node_in_group("camera_rig") as Node3D if tree != null else null
	var player_remote : RemoteTransform3D = _driver.get_node_or_null("RemoteTransform3D") as RemoteTransform3D
	if player_remote != null:
		player_remote.remote_path = NodePath("")
	if camera_remote != null and camera_rig != null:
		camera_remote.remote_path = camera_rig.get_path()

	# Display HUD driving hints overlay with current hull health
	if vehicle_health_bar != null and not is_destroyed:
		vehicle_health_bar.set_bar_active(true)

	# Deploy Warthog-style Gatling Cannon turret if Explorer boards heavy transport
	if _is_player_explorer(_driver):
		if gatling_turret == null:
			gatling_turret = find_child("GatlingTurret", true, false) as Node3D
		if gatling_turret == null:
			var gt_scene : PackedScene = load("res://scenes/vehicles/gatling_turret.tscn")
			if gt_scene != null:
				gatling_turret = gt_scene.instantiate() as Node3D
				if model_anchor != null:
					gatling_turret.position = Vector3(0.0, 0.18, -0.22)
					model_anchor.add_child(gatling_turret)
				else:
					gatling_turret.position = Vector3(0.0, 0.18, -0.22)
					add_child(gatling_turret)
		if gatling_turret != null:
			gatling_turret.deploy()

	_notify_hud()

	boarded.emit(_driver)

## Dismounts the astronaut safely outside the vehicle and restores character controls.
func exit_vehicle() -> void:
	if not is_occupied or _driver == null or not is_instance_valid(_driver):
		is_occupied = false
		_driver = null
		return

	# Retract Warthog-style Gatling Cannon turret
	if gatling_turret != null and (gatling_turret.is_deployed or gatling_turret.is_deploying):
		gatling_turret.retract()

	_boarding_cooldown = 0.4
	_e_key_was_pressed = true

	# Stop rover motion
	current_speed = 0.0
	velocity = Vector3.ZERO

	# Play hatch unsealing sound
	var snd : Node = get_node_or_null("/root/UiSound")
	if snd != null and snd.has_method("play_vehicle_exit"):
		snd.play_vehicle_exit()

	# Tactile suspension rebound feedback on dismount
	_suspension_bounce = 0.025

	# Detach camera from rover
	if camera_remote != null:
		camera_remote.remote_path = NodePath("")

	# Find a clear, safe dismount position unobstructed by rocks or walls
	var exit_pos : Vector3 = _find_safe_exit_position()

	_driver.global_position = exit_pos
	_driver.velocity = Vector3.ZERO

	# Restore player physics, visuals, and combat
	var col : CollisionShape3D = _driver.get_node_or_null("Collider") as CollisionShape3D
	if col != null:
		col.set_deferred("disabled", false)
	var p_mesh : Node3D = _driver.get_node_or_null("player") as Node3D
	if p_mesh != null:
		p_mesh.visible = true
	var pc : Node = _driver.get_node_or_null("PlayerCombat")
	if pc != null:
		pc.set_process_unhandled_input(true)
	var stamina_arc : Node = _driver.get_node_or_null("StaminaArc")
	if stamina_arc != null and stamina_arc is Node3D:
		(stamina_arc as Node3D).visible = true
	_driver.set_physics_process(true)

	# Restore camera tracking to player
	var tree : SceneTree = get_tree()
	var camera_rig : Node3D = tree.get_first_node_in_group("camera_rig") as Node3D if tree != null else null
	var player_remote : RemoteTransform3D = _driver.get_node_or_null("RemoteTransform3D") as RemoteTransform3D
	if player_remote != null and camera_rig != null:
		player_remote.remote_path = camera_rig.get_path()

	# Hide HUD driving hints overlay
	var hud : Node = get_node_or_null("/root/PlayerHealthHud")
	if hud != null and hud.has_method("set_vehicle_hint"):
		hud.set_vehicle_hint(false)

	if drive_prompt != null:
		drive_prompt.visible = false

	var exited_driver := _driver
	if is_instance_valid(exited_driver):
		exited_driver.set("is_driving_vehicle", false)
		if exited_driver.is_in_group("driving"):
			exited_driver.remove_from_group("driving")
		if exited_driver.has_meta("current_vehicle"):
			exited_driver.remove_meta("current_vehicle")
	_driver = null
	is_occupied = false

	dismounted.emit(exited_driver)

## Tests candidate exit locations around the vehicle to guarantee the driver never clips into terrain, walls, or rocks.
func _find_safe_exit_position() -> Vector3:
	var candidates : Array[Vector3] = [
		-transform.basis.x * 1.35, # Driver side (left)
		transform.basis.x * 1.35,  # Passenger side (right)
		-transform.basis.z * 1.5,  # Rear (behind tailgate)
		transform.basis.z * 1.5    # Front (in front of hood)
	]

	var default_pos : Vector3 = global_position + candidates[0] + Vector3(0.0, 0.15, 0.0)
	var tree_check : SceneTree = get_tree()
	var map_geom : Node = tree_check.get_first_node_in_group("navigation_geometry") if tree_check != null else null
	if map_geom != null and map_geom.has_method("get_terrain_height"):
		var ty : float = float(map_geom.call("get_terrain_height", default_pos.x, default_pos.z))
		default_pos.y = maxf(default_pos.y, ty + 0.15)

	var world_3d := get_world_3d()
	if world_3d == null:
		return default_pos

	var space_state := world_3d.direct_space_state
	if space_state == null:
		return default_pos

	var vehicle_origin : Vector3 = global_position + Vector3(0.0, 0.35, 0.0)

	for offset in candidates:
		var target_spot : Vector3 = global_position + offset + Vector3(0.0, 0.35, 0.0)

		# Clamp elevation to terrain geometry if available
		if map_geom != null and map_geom.has_method("get_terrain_height"):
			var gh : float = float(map_geom.call("get_terrain_height", target_spot.x, target_spot.z))
			target_spot.y = maxf(target_spot.y, gh + 0.35)

		# Test obstacle occlusion between vehicle and exit spot
		var ray_query := PhysicsRayQueryParameters3D.create(vehicle_origin, target_spot)
		ray_query.collision_mask = 1 # Static environment / walls / rocks
		var ray_exclude : Array[RID] = [get_rid()]
		if _driver != null:
			ray_exclude.append(_driver.get_rid())
		ray_query.exclude = ray_exclude

		var hit := space_state.intersect_ray(ray_query)
		if hit.is_empty():
			# Path is clear! Verify floor ground under the exit position
			var ground_query := PhysicsRayQueryParameters3D.create(target_spot, target_spot + Vector3(0.0, -2.5, 0.0))
			ground_query.collision_mask = 1
			ground_query.exclude = ray_exclude
			var ground_hit := space_state.intersect_ray(ground_query)
			if not ground_hit.is_empty():
				target_spot.y = (ground_hit["position"] as Vector3).y + 0.15
			else:
				target_spot.y = global_position.y + 0.15
			return target_spot

	return default_pos

## Triggers the vehicle's dual-tone horn (H key) and alerts nearby enemies.
func honk() -> void:
	var snd : Node = get_node_or_null("/root/UiSound")
	if snd != null and snd.has_method("play_vehicle_honk"):
		snd.play_vehicle_honk()

	# Alert enemies within hearing radius
	if get_tree() != null:
		for enemy in get_tree().get_nodes_in_group("enemy"):
			if is_instance_valid(enemy) and enemy is CharacterBody3D:
				if global_position.distance_to(enemy.global_position) < 16.0:
					if "navigation_agent" in enemy and enemy.navigation_agent != null:
						enemy.navigation_agent.target_position = global_position

	# Subtle suspension bounce feedback
	_suspension_bounce = 0.015

	horn_honked.emit()

## Toggles high-beam spotlights on/off (L key) with smooth warm-up/cool-down transition.
func toggle_lights() -> void:
	lights_on = not lights_on
	if lights_on:
		if left_headlight != null:
			left_headlight.visible = true
		if right_headlight != null:
			right_headlight.visible = true
	var snd : Node = get_node_or_null("/root/UiSound")
	if snd != null and snd.has_method("play_vehicle_lights"):
		snd.play_vehicle_lights()
	lights_toggled.emit(lights_on)

func _apply_lights() -> void:
	_current_headlight_energy = TARGET_HEADLIGHT_ENERGY if lights_on else 0.0
	if left_headlight != null:
		left_headlight.light_cull_mask = 1
		left_headlight.visible = lights_on
		left_headlight.light_energy = _current_headlight_energy
	if right_headlight != null:
		right_headlight.light_cull_mask = 1
		right_headlight.visible = lights_on
		right_headlight.light_energy = _current_headlight_energy
	if left_taillight != null:
		left_taillight.light_cull_mask = 1
		left_taillight.visible = false
		left_taillight.light_energy = 0.0
	if right_taillight != null:
		right_taillight.light_cull_mask = 1
		right_taillight.visible = false
		right_taillight.light_energy = 0.0

## Dynamic chassis suspension physics: multi-point slope conformity, cornering roll, squat & dive, road rumble.
func _update_chassis_physics(delta: float) -> void:
	if model_anchor == null:
		return

	# 1. Longitudinal acceleration / braking inertia (squat & dive)
	# Aerospace / vehicle pitch convention: pitch > 0 is nose up, pitch < 0 is nose down.
	var dt : float = maxf(delta, 0.001)
	var accel_rate : float = (current_speed - _prev_speed) / dt
	_prev_speed = current_speed

	var inertial_pitch : float = 0.0
	var cornering_roll : float = 0.0
	var road_vibe : float = 0.0
	var speed_ratio : float = clampf(absf(current_speed) / max_speed, 0.0, 1.0)

	if is_occupied:
		if _is_braking:
			# Hard brake dive (nose dives down: pitch < 0)
			var brake_factor : float = clampf(absf(current_speed) / max_speed, 0.3, 1.0)
			inertial_pitch = -0.11 * brake_factor
		elif _throttle_input > 0.0:
			# Forward acceleration squat (rear dips, nose rises: pitch > 0)
			var accel_factor : float = clampf(accel_rate / acceleration, 0.25, 1.0)
			inertial_pitch = 0.08 * accel_factor
		elif _throttle_input < 0.0:
			# Reverse acceleration (front dips: pitch < 0)
			inertial_pitch = -0.06
		elif absf(current_speed) > 0.2:
			# Subtle coasting pitch
			inertial_pitch = clampf(accel_rate / coast_deceleration, -0.04, 0.04)

		# Centrifugal cornering body roll (body rolls outward)
		cornering_roll = -current_steer_angle * speed_ratio * 0.09

	# 2. Multi-point terrain slope conformity (pitch & roll from ground surface)
	var slope_pitch : float = 0.0
	var slope_roll : float = 0.0
	var on_floor : bool = is_on_floor()

	if on_floor:
		# Probe ground heights under the 4 wheel positions
		var world_3d := get_world_3d()
		var sampled_ground : bool = false
		if world_3d != null and world_3d.direct_space_state != null:
			var space_state := world_3d.direct_space_state
			var wheel_offsets : Array[Vector3] = [
				Vector3(-0.30, 0.40, 0.42),  # Front-Left
				Vector3(0.30, 0.40, 0.42),   # Front-Right
				Vector3(-0.30, 0.40, -0.42), # Rear-Left
				Vector3(0.30, 0.40, -0.42)   # Rear-Right
			]
			var ground_heights : Array[float] = []
			var ray_query := PhysicsRayQueryParameters3D.new()
			ray_query.collision_mask = 1 # Static terrain/geometry
			var ray_ex : Array[RID] = [get_rid()]
			if is_instance_valid(_driver):
				ray_ex.append(_driver.get_rid())
			ray_query.exclude = ray_ex

			for offset in wheel_offsets:
				var r_from : Vector3 = global_position + transform.basis * offset
				var r_to : Vector3 = r_from + Vector3(0.0, -1.6, 0.0)
				ray_query.from = r_from
				ray_query.to = r_to
				var hit := space_state.intersect_ray(ray_query)
				if not hit.is_empty():
					ground_heights.append((hit["position"] as Vector3).y)

			if ground_heights.size() == 4:
				sampled_ground = true
				var h_front : float = (ground_heights[0] + ground_heights[1]) * 0.5
				var h_rear : float = (ground_heights[2] + ground_heights[3]) * 0.5
				var delta_pitch : float = h_front - h_rear
				# Uphill: front is higher (delta_pitch > 0) -> positive pitch (nose up).
				# Downhill: front is lower (delta_pitch < 0) -> negative pitch (nose down).
				slope_pitch = clampf(atan2(delta_pitch, 0.84), -0.65, 0.65)

				var h_left : float = (ground_heights[0] + ground_heights[2]) * 0.5
				var h_right : float = (ground_heights[1] + ground_heights[3]) * 0.5
				var delta_roll : float = h_right - h_left
				# Right side higher: delta_roll > 0 -> positive roll (right side up).
				slope_roll = clampf(atan2(delta_roll, 0.60), -0.55, 0.55)

		# Fallback to floor normal if 4-point raycast was incomplete
		if not sampled_ground:
			var floor_n : Vector3 = get_floor_normal()
			if floor_n.y < 0.999 and floor_n.length_squared() > 0.5:
				var local_n : Vector3 = transform.basis.inverse() * floor_n
				# Uphill slope: normal tilts backward (-Z, local_n.z < 0).
				# -atan2(negative, positive) is positive -> positive pitch (nose up).
				slope_pitch = clampf(-atan2(local_n.z, maxf(local_n.y, 0.1)), -0.65, 0.65)
				# Lateral slope: normal tilts left (-X, local_n.x < 0).
				# -atan2(negative, positive) is positive -> positive roll (right side up).
				slope_roll = clampf(-atan2(local_n.x, maxf(local_n.y, 0.1)), -0.55, 0.55)

		# Suspension landing compression
		if not _was_on_floor:
			_suspension_bounce = -0.05 * clampf(absf(velocity.y) / 4.0, 0.4, 1.5)

		# High-frequency terrain micro-vibration while in motion
		if is_occupied and speed_ratio > 0.15:
			road_vibe = sin(float(Time.get_ticks_msec()) * 0.024) * 0.0025 * speed_ratio
	else:
		# Airborne pitch: nose dips if falling while occupied (pitch < 0)
		if is_occupied and velocity.y < -0.5:
			inertial_pitch -= clampf(absf(velocity.y) / 12.0, 0.0, 1.0) * 0.08

	_was_on_floor = on_floor

	# 3. Suspension spring-damper recovery
	_suspension_bounce = move_toward(_suspension_bounce, 0.0, (0.2 + absf(_suspension_bounce) * 8.0) * delta)

	# 4. Smooth chassis interpolation
	var target_pitch : float = slope_pitch + inertial_pitch
	var target_roll : float = slope_roll + cornering_roll

	_chassis_pitch = lerpf(_chassis_pitch, target_pitch, clampf(11.0 * delta, 0.0, 1.0))
	_chassis_roll = lerpf(_chassis_roll, target_roll, clampf(11.0 * delta, 0.0, 1.0))

	# 5. Apply transformed posture to model anchor
	# In Godot (forward = +Z), negative Euler X pitch rotates nose UP (+Y) matching positive _chassis_pitch.
	model_anchor.transform.basis = Basis.from_euler(Vector3(-_chassis_pitch, 0.0, _chassis_roll))
	model_anchor.position = Vector3(0.0, _chassis_y_offset + _suspension_bounce + road_vibe, 0.0)

	# Synchronize lighting fixture angles so headlights beam with chassis pitch/roll
	if headlights_group != null:
		headlights_group.transform.basis = model_anchor.transform.basis
		headlights_group.position.y = model_anchor.position.y
	if taillights_group != null:
		taillights_group.transform.basis = model_anchor.transform.basis
		taillights_group.position.y = model_anchor.position.y

## Smooth lighting transitions and crisp glowing square taillight / backup light updates.
func _update_lighting(delta: float) -> void:
	if is_destroyed:
		return

	# 1. Smooth headlight fade transition
	var target_hl_energy : float = TARGET_HEADLIGHT_ENERGY if lights_on else 0.0
	_current_headlight_energy = move_toward(_current_headlight_energy, target_hl_energy, 9.0 * delta)
	if left_headlight != null:
		left_headlight.light_energy = _current_headlight_energy
		left_headlight.visible = _current_headlight_energy > 0.01
	if right_headlight != null:
		right_headlight.light_energy = _current_headlight_energy
		right_headlight.visible = _current_headlight_energy > 0.01

	# 2. Glowing square taillights and backup lights
	var is_reversing : bool = current_speed < -0.15 or (is_occupied and _throttle_input < -0.1)

	if backup_ground_square != null:
		backup_ground_square.visible = is_reversing

	if _tail_material != null:
		if is_reversing:
			_tail_material.albedo_color = Color(0.92, 0.96, 1.0, 1.0)
			_tail_material.emission = Color(0.92, 0.96, 1.0, 1.0)
			_tail_material.emission_energy_multiplier = 3.6
		elif _is_braking:
			_tail_material.albedo_color = Color(0.95, 0.12, 0.08, 1.0)
			_tail_material.emission = Color(1.0, 0.15, 0.1, 1.0)
			_tail_material.emission_energy_multiplier = BRAKE_TAILLIGHT_ENERGY
		elif lights_on:
			_tail_material.albedo_color = Color(0.65, 0.08, 0.08, 1.0)
			_tail_material.emission = Color(1.0, 0.12, 0.08, 1.0)
			_tail_material.emission_energy_multiplier = TARGET_TAILLIGHT_ENERGY
		else:
			_tail_material.albedo_color = Color(0.18, 0.04, 0.04, 1.0)
			_tail_material.emission_energy_multiplier = 0.0

## Advances wheel rotation animations and updates steered wheel posture.
func _update_wheels(delta: float) -> void:
	var wheel_radius : float = 0.22
	var spin_speed : float = current_speed / wheel_radius
	_wheel_roll_angle = fmod(_wheel_roll_angle + spin_speed * delta, TAU)

	var roll_basis := Basis(Vector3(1, 0, 0), _wheel_roll_angle)
	var steer_basis := Basis(Vector3(0, 0, 1), current_steer_angle)

	# Front wheels: steer around local Z (kingpin/vertical) and roll around local X (axle)
	if _wheel_fl != null:
		_wheel_fl.transform.basis = steer_basis * roll_basis
	if _wheel_fr != null:
		_wheel_fr.transform.basis = steer_basis * roll_basis

	# Rear wheels: roll around local X (axle) without steering
	if _wheel_rl != null:
		_wheel_rl.transform.basis = roll_basis
	if _wheel_rr != null:
		_wheel_rr.transform.basis = roll_basis

	# Dynamic tire dust when driving fast
	if tire_dust != null:
		tire_dust.emitting = is_occupied and absf(current_speed) > 1.8 and is_on_floor()

## Deals collision ramming damage against enemy robots based on speed.
func _check_ramming_collisions() -> void:
	if absf(current_speed) < 1.2:
		return

	var col_count : int = get_slide_collision_count()
	for i in range(col_count):
		var col := get_slide_collision(i)
		var collider := col.get_collider() as Node3D
		if collider != null and collider.is_in_group("enemy"):
			var hc : Node = collider.get_node_or_null("HealthComponent")
			if hc != null and hc.has_method("decrease_health"):
				var dmg : int = int(absf(current_speed) * ram_damage_multiplier)
				hc.call("decrease_health", dmg)
				var snd : Node = get_node_or_null("/root/UiSound")
				if snd != null and snd.has_method("play_impact"):
					snd.play_impact()
				_suspension_bounce = -0.04
				break

## Decreases vehicle hull health and checks for destruction.
func take_damage(amount: int) -> int:
	if is_destroyed:
		return 0
	if health_component != null:
		return health_component.decrease_health(amount)
	return 0

func _on_health_changed(new_hp: int, old_hp: int) -> void:
	health_changed.emit(new_hp, old_hp)

	# Subtle suspension shudder on damage impact
	if new_hp < old_hp:
		_suspension_bounce = -0.02 * randf_range(0.8, 1.2)
		var snd : Node = get_node_or_null("/root/UiSound")
		if snd != null and snd.has_method("play_hit"):
			snd.play_hit()

	# Low health smoke effects (<= 40% health)
	if engine_smoke != null:
		engine_smoke.emitting = (new_hp <= 40 and not is_destroyed)
		if new_hp <= 20 and not is_destroyed:
			engine_smoke.amount = 28
			engine_smoke.initial_velocity_max = 2.0
		else:
			engine_smoke.amount = 16
			engine_smoke.initial_velocity_max = 1.4

	if vehicle_health_bar != null and not is_destroyed:
		vehicle_health_bar.set_bar_active(true)

	_notify_hud()

func _on_health_depleted() -> void:
	# Auto-eject driver immediately when car is about to explode
	if is_occupied and _driver != null and is_instance_valid(_driver):
		_auto_eject_driver()
	_explode()

## Safely and dynamically launches driver clear of vehicle before detonation.
func _auto_eject_driver() -> void:
	if not is_occupied or _driver == null or not is_instance_valid(_driver):
		return
	var driver_ref := _driver
	var snd : Node = get_node_or_null("/root/UiSound")
	if snd != null and snd.has_method("play_dash"):
		snd.play_dash()

	exit_vehicle()
	if is_instance_valid(driver_ref):
		var outward : Vector3 = (driver_ref.global_position - global_position).normalized()
		if outward.is_zero_approx():
			outward = -global_transform.basis.z
		outward.y = 0.0
		# Safe launch speed that clears the vehicle without excessive momentum
		driver_ref.velocity = outward.normalized() * 6.0 + Vector3.UP * 3.5
		var dhc : Node = driver_ref.get_node_or_null("HealthComponent")
		if dhc != null and dhc.has_method("decrease_health"):
			dhc.call("decrease_health", 30)

## Low-poly vehicle explosion animation, flying debris, and driver ejection.
func _explode() -> void:
	if is_destroyed:
		return
	is_destroyed = true

	# Disable chassis collision shape immediately to prevent collision spasms or ejection entrapment
	var chassis_col : CollisionShape3D = get_node_or_null("Collider") as CollisionShape3D
	if chassis_col != null:
		chassis_col.set_deferred("disabled", true)

	# Play deep concussive explosion sound
	var snd : Node = get_node_or_null("/root/UiSound")
	if snd != null:
		if snd.has_method("play_rocket_explode"):
			snd.play_rocket_explode(0.02)
		elif snd.has_method("play_enemy_death"):
			snd.play_enemy_death()

	# Trigger heavy screen shake
	var ss : Node = get_node_or_null("/root/ScreenShake")
	if ss != null and ss.has_method("shake"):
		ss.shake(0.85)

	# If occupied and somehow not yet ejected, safely eject now
	if is_occupied and _driver != null and is_instance_valid(_driver):
		_auto_eject_driver()

	# Spawn billowing low-poly mushroom cloud explosion effect
	if get_parent() != null and EXPLOSION_EFFECT_SCENE != null:
		var exp_fx : Node3D = EXPLOSION_EFFECT_SCENE.instantiate()
		get_parent().add_child(exp_fx)
		exp_fx.global_position = global_position

	# Vehicle detonation AoE: deals heavy blast damage and knockback to all nearby enemies and player
	ExplosionEffect.apply_explosion_damage(
		get_tree(),
		global_position,
		6.0, # Large vehicle blast radius
		160, # Massive vehicle explosion damage
		11.0, # Concussive vehicle blast knockback
		self,
		0.35 # Player takes reduced damage
	)

	# 1. Fire and smoke explosive burst
	if explosion_burst != null:
		explosion_burst.emitting = true

	# 2. Expanding low-poly blast shockwave sphere
	_spawn_low_poly_shockwave()

	# 3. Scatter low-poly flying debris chunks
	_spawn_low_poly_debris()

	# 4. Scorched charred wreck visual finish
	_apply_wreck_materials()

	# Disable driving interactions safely
	if interaction_area != null:
		interaction_area.monitoring = false
		interaction_area.set_deferred("monitorable", false)
	if drive_prompt != null:
		drive_prompt.visible = false

	# Keep smoke and embers burning from the charred chassis
	if engine_smoke != null:
		engine_smoke.emitting = true
		engine_smoke.amount = 20

	destroyed.emit()
	if vehicle_health_bar != null and not is_destroyed:
		vehicle_health_bar.set_bar_active(true)

	_notify_hud()

## Spawns an expanding and rapidly collapsing low-poly blast sphere.
func _spawn_low_poly_shockwave() -> void:
	var blast := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.2
	mesh.height = 0.4
	mesh.radial_segments = 6
	mesh.rings = 4

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.62, 0.15, 0.95)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	blast.mesh = mesh
	blast.top_level = true
	get_parent().add_child(blast)
	blast.global_position = global_position + Vector3(0.0, 0.35, 0.0)

	var tween := create_tween()
	if tween != null:
		tween.tween_property(blast, "scale", Vector3(3.2, 2.6, 3.2), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.24)
		tween.tween_callback(blast.queue_free)

## Spawns low-poly debris chunks that tumble and scatter away from the blast center.
func _spawn_low_poly_debris() -> void:
	var debris_parent : Node = get_parent()
	if debris_parent == null:
		return

	var debris_colors : Array[Color] = [
		Color(0.12, 0.14, 0.16),
		Color(0.20, 0.22, 0.25),
		Color(0.85, 0.35, 0.08),
		Color(0.15, 0.15, 0.15),
		Color(0.35, 0.25, 0.18)
	]

	for i in range(5):
		var chunk := MeshInstance3D.new()
		var bmesh := BoxMesh.new()
		bmesh.size = Vector3(randf_range(0.08, 0.16), randf_range(0.08, 0.14), randf_range(0.10, 0.20))
		var mat := StandardMaterial3D.new()
		mat.albedo_color = debris_colors[i % debris_colors.size()]
		mat.roughness = 0.85
		bmesh.material = mat
		chunk.mesh = bmesh
		chunk.top_level = true
		debris_parent.add_child(chunk)
		chunk.global_position = global_position + Vector3(randf_range(-0.3, 0.3), 0.35, randf_range(-0.3, 0.3))

		var throw_vel := Vector3(
			randf_range(-5.5, 5.5),
			randf_range(4.5, 8.0),
			randf_range(-5.5, 5.5)
		)
		var rot_axis := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
		var target_pos : Vector3 = chunk.global_position + throw_vel * 0.45
		target_pos.y = maxf(global_position.y + 0.05, target_pos.y - 1.2)

		var tween := create_tween().set_parallel(true)
		if tween != null:
			tween.tween_property(chunk, "global_position", target_pos, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(chunk, "rotation", rot_axis * TAU * randf_range(1.0, 2.5), 0.55)
			# Fade out debris after 10s
			tween.chain().tween_interval(10.0)
			tween.chain().tween_callback(chunk.queue_free)

## Tints vehicle meshes to charred soot finish and cuts all lights.
func _apply_wreck_materials() -> void:
	var charred_mat := StandardMaterial3D.new()
	charred_mat.albedo_color = Color(0.08, 0.08, 0.09, 1.0)
	charred_mat.metallic = 0.15
	charred_mat.roughness = 0.95

	if model_anchor != null:
		for c in model_anchor.find_children("*", "MeshInstance3D", true, false):
			var mi := c as MeshInstance3D
			if mi != null and mi.mesh != null:
				for s in range(mi.mesh.get_surface_count()):
					mi.set_surface_override_material(s, charred_mat)

	# Cut all light sources
	lights_on = false
	if left_headlight != null:
		left_headlight.visible = false
	if right_headlight != null:
		right_headlight.visible = false
	if backup_ground_square != null:
		backup_ground_square.visible = false
	if _tail_material != null:
		_tail_material.albedo_color = Color(0.05, 0.05, 0.05, 1.0)
		_tail_material.emission_energy_multiplier = 0.0

func _notify_hud() -> void:
	var hud : Node = get_node_or_null("/root/PlayerHealthHud")
	if hud == null:
		return
	if is_occupied and hud.has_method("set_vehicle_hint"):
		if is_destroyed:
			hud.set_vehicle_hint(false)
		else:
			hud.set_vehicle_hint(true, vehicle_name, health_component.health, HealthComponent.MAX_HEALTH)

func _on_interaction_area_entered(body: Node3D) -> void:
	if is_destroyed:
		return
	if body.is_in_group("player") and (body is CharacterBody3D):
		_nearby_player = body as CharacterBody3D
		if vehicle_health_bar != null:
			vehicle_health_bar.set_bar_active(true)
		if drive_prompt != null and not is_occupied:
			var hp_pct : int = int(round(float(health_component.health) / float(HealthComponent.MAX_HEALTH) * 100.0))
			drive_prompt.text = "[E] Drive %s (Hull: %d%%)" % [vehicle_name, hp_pct]
			drive_prompt.visible = _boarding_cooldown <= 0.0

func _on_interaction_area_exited(body: Node3D) -> void:
	if body == _nearby_player:
		_nearby_player = null
		if vehicle_health_bar != null and not is_occupied and health_component.health >= HealthComponent.MAX_HEALTH:
			vehicle_health_bar.set_bar_active(false)
		if drive_prompt != null:
			drive_prompt.visible = false

func _is_player_explorer(p: CharacterBody3D) -> bool:
	if p == null or not is_instance_valid(p):
		return false
	if p.has_meta("character_class"):
		return int(p.get_meta("character_class")) == 3 # CharacterClass.EXPLORER
	var char_data : Node = get_node_or_null("/root/CharacterData")
	if char_data != null and "current_class" in char_data:
		return int(char_data.current_class) == 3
	return false

func _fire_vehicle_cannons() -> void:
	if gatling_turret == null:
		gatling_turret = find_child("GatlingTurret", true, false) as Node3D
	if gatling_turret != null and gatling_turret.is_deployed:
		var aim_target : Vector3 = _get_aim_target(gatling_turret.global_position)
		gatling_turret.fire(aim_target)
		_suspension_bounce = -0.015
		return

	var center : Vector3 = global_position + Vector3(0.0, 0.65, 0.0)
	var aim_dir : Vector3 = _get_aim_direction(center)

	var right_offset : Vector3 = transform.basis.x * 0.28
	var muzzles : Array[Vector3] = [
		center - right_offset + aim_dir * 0.35,
		center + right_offset + aim_dir * 0.35
	]

	for muzzle_pos in muzzles:
		var bullet : Area3D = VEHICLE_BULLET_SCENE.instantiate() as Area3D
		bullet.shooter = self
		bullet.direction = aim_dir
		bullet.damage = 60
		bullet.speed = 18.0
		bullet.decal_scale = 0.45
		get_parent().add_child(bullet)
		bullet.global_position = muzzle_pos

	var snd : Node = get_node_or_null("/root/UiSound")
	if snd != null and snd.has_method("play_vehicle_cannon"):
		snd.play_vehicle_cannon()

	_suspension_bounce = -0.025

func _get_aim_target(from: Vector3) -> Vector3:
	var viewport : Viewport = get_viewport()
	if viewport == null:
		return from + transform.basis.z * 10.0
	var camera : Camera3D = viewport.get_camera_3d()
	if camera == null:
		return from + transform.basis.z * 10.0

	var mouse_pos : Vector2 = viewport.get_mouse_position()
	var ray_origin : Vector3 = camera.project_ray_origin(mouse_pos)
	var ray_normal : Vector3 = camera.project_ray_normal(mouse_pos)

	var space_state : PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if space_state == null:
		return from + transform.basis.z * 10.0

	var query : PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_normal * 300.0, 1 | 2)
	query.exclude = [get_rid()]
	if is_instance_valid(_driver) and (_driver is CollisionObject3D):
		query.exclude.append((_driver as CollisionObject3D).get_rid())

	var hit : Dictionary = space_state.intersect_ray(query)
	if not hit.is_empty():
		return hit.position

	var ground_plane : Plane = Plane(Vector3.UP, from.y)
	var hit_plane = ground_plane.intersects_ray(ray_origin, ray_normal)
	if hit_plane != null:
		return hit_plane

	return from + transform.basis.z * 10.0

func _get_aim_direction(from: Vector3) -> Vector3:
	var aim_target : Vector3 = _get_aim_target(from)
	var dir : Vector3 = (aim_target - from).normalized()
	return dir if not dir.is_zero_approx() else transform.basis.z
