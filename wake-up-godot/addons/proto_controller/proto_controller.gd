# ProtoController v1.2 (Isometric/45-Degree Edition)
# Adapted from Brackeys' v1.0
# CC0 License

extends CharacterBody3D

signal dashed(direction: Vector3)
signal stamina_changed(current: float, max_val: float)
signal dash_cooldown_changed(remaining: float, max_val: float)

## Can we move around?
@export var can_move : bool = true
## Are we affected by gravity?
@export var has_gravity : bool = true
## Can we press to jump?
@export var can_jump : bool = true
## Can we press to enter freefly mode (noclip)?
@export var can_freefly : bool = false

@export_group("Orientation")
## Offset inputs to match camera angle. 
@export var movement_offset_angle : float = 45.0
## How fast does the character rotate to face movement direction?
@export var rotation_speed : float = 12.0

@export_group("Speeds")
## Normal speed.
@export var base_speed : float = 2.0
## Speed of jump.
@export var jump_velocity : float = 3.5
## Stamina consumed per ground jump from shared pool.
@export var jump_cost : float = 0.5
## How fast do we freefly?
@export var freefly_speed : float = 6.0

@export_group("Dash System")
## Can the character perform a high-speed thruster dash?
@export var can_dash : bool = true
## Velocity during dash burst.
@export var dash_speed : float = 9.5
## Duration of dash burst in seconds.
@export var dash_duration : float = 0.22
## Anti-spam cooldown between dashes in seconds.
@export var dash_cooldown : float = 0.35
## Maximum stamina / dash charges (allows 3 continuous dashes).
@export var max_stamina : float = 3.0
## Stamina consumed per dash.
@export var dash_cost : float = 1.0
## Constant recharge rate of stamina per second (1 charge per ~1.33 seconds).
@export var stamina_recharge_rate : float = 0.75
## PackedScene for dash particle effect.
@export var dash_particles_scene : PackedScene = preload("res://scenes/player/dash_particles.tscn")
## PackedScene for floating stamina arc.
@export var stamina_arc_scene : PackedScene = preload("res://scenes/player/stamina_arc.tscn")

@export_group("Input Actions")
@export var input_left : String = "ui_left"
@export var input_right : String = "ui_right"
@export var input_forward : String = "ui_up"
@export var input_back : String = "ui_down"
@export var input_jump : String = "ui_accept"
@export var input_sprint : String = "sprint"
@export var input_freefly : String = "freefly"

@export_group("Flight System")
## Can the character use pressurized air thrusters to fly?
@export var can_fly : bool = true
## Upward vertical acceleration when firing jetpack thrusters.
@export var fly_acceleration : float = 16.0
## Maximum upward vertical velocity achievable via flight thrusters.
@export var max_fly_speed : float = 2.4
## Maximum hover / flight altitude above ground (in meters). Keeps thrusters reasonable and balanced.
@export var max_flight_height : float = 1.9
## Pressurized air (stamina) consumed per second while flying.
@export var fly_cost_per_second : float = 1.0

var move_speed : float = 0.0
var freeflying : bool = false
var is_flying : bool = false
var _flight_start_y : float = 0.0

## Dash & Stamina State
var stamina : float = 3.0
var infinite_stamina : bool = false
var dash_cooldown_left : float = 0.0
var is_dashing : bool = false
var _dash_time_left : float = 0.0
var _dash_direction : Vector3 = Vector3.ZERO
var _dash_particles_instance : Node3D = null
var _stamina_arc_instance : Node = null

## Vehicle driving state
var is_driving_vehicle : bool = false

## IMPORTANT REFERENCES
@onready var collider: CollisionShape3D = $Collider

func _ready() -> void:
	add_to_group("player")
	check_input_mappings()
	stamina = max_stamina
	var hc : HealthComponent = get_node_or_null("HealthComponent") as HealthComponent
	if hc != null:
		hc.has_shield = true
	if dash_particles_scene != null:
		_dash_particles_instance = dash_particles_scene.instantiate()
		_dash_particles_instance.position = Vector3(0.0, 0.38, -0.13)
		_dash_particles_instance.rotation_degrees.y = 180.0
		add_child(_dash_particles_instance)
	if stamina_arc_scene != null:
		_stamina_arc_instance = stamina_arc_scene.instantiate()
		add_child(_stamina_arc_instance)
		if _stamina_arc_instance.has_method("update_stamina"):
			_stamina_arc_instance.update_stamina(stamina, max_stamina)

	# Attach custom 3D character visuals component
	var visuals : CharacterVisuals = get_node_or_null("CharacterVisuals") as CharacterVisuals
	if visuals == null:
		visuals = CharacterVisuals.new()
		visuals.name = "CharacterVisuals"
		add_child(visuals)

	# Connect class changed
	var char_data : Node = get_node_or_null("/root/CharacterData")
	if char_data != null:
		if char_data.has_signal("class_changed"):
			char_data.class_changed.connect(_on_class_changed)
		_apply_class_perks.call_deferred(int(char_data.get("current_class")))

func _on_class_changed(new_class: int, _info: Dictionary) -> void:
	_apply_class_perks(new_class)

func _apply_class_perks(class_id: int) -> void:
	set_meta("character_class", class_id)
	var hc : HealthComponent = get_node_or_null("HealthComponent") as HealthComponent
	if hc != null:
		# Only Medic has innate cellular health regeneration
		hc.passive_health_regen = (class_id == 2) # CharacterClass.MEDIC

	var pc : Node = get_node_or_null("PlayerCombat")
	if pc != null and pc.has_method("apply_character_class"):
		pc.apply_character_class(class_id)

	_update_explorer_perks(class_id)

func _update_explorer_perks(class_id: int) -> void:
	var tree : SceneTree = get_tree()
	if tree == null:
		return
	var cam : Camera3D = tree.get_first_node_in_group("camera") as Camera3D
	if cam != null:
		var target_size : float = 5.2 if class_id == 3 else 4.0
		var tw : Tween = create_tween()
		tw.tween_property(cam, "size", target_size, 0.4).set_trans(Tween.TRANS_SINE)

	var hud : Node = get_node_or_null("/root/PlayerHealthHud")
	if hud != null and hud.has_method("set_radar_radius"):
		var target_radar : float = 38.0 if class_id == 3 else 26.0
		hud.set_radar_radius(target_radar)

func _unhandled_input(event: InputEvent) -> void:
	if can_freefly and Input.is_action_just_pressed(input_freefly):
		if not freeflying:
			enable_freefly()
		else:
			disable_freefly()
		return

	# Handle Class Specialization Active Ability [F] or [Middle Mouse Button]
	var is_ability_input : bool = Input.is_action_just_pressed("class_ability") \
		or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F) \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_MIDDLE)
	if is_ability_input:
		var pc : Node = get_node_or_null("PlayerCombat")
		if pc != null and pc.has_method("execute_class_ability"):
			pc.execute_class_ability()
			get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	if can_freefly and freeflying:
		var input_dir := Input.get_vector(input_left, input_right, input_forward, input_back)
		
		# Apply offset to freefly as well so it feels natural
		var motion := Vector3(input_dir.x, 0, input_dir.y)
		motion = motion.rotated(Vector3.UP, deg_to_rad(movement_offset_angle)).normalized()
		
		motion *= freefly_speed * delta
		move_and_collide(motion)
		return
	
	if has_gravity:
		if not is_on_floor():
			velocity += get_gravity() * delta

	# Constant stamina recharge over time (when not dashing and not flying)
	if infinite_stamina:
		stamina = max_stamina
		stamina_changed.emit(stamina, max_stamina)
	elif not is_dashing and not is_flying and stamina < max_stamina:
		stamina = minf(stamina + stamina_recharge_rate * delta, max_stamina)
		stamina_changed.emit(stamina, max_stamina)
		if is_instance_valid(_stamina_arc_instance) and _stamina_arc_instance.has_method("update_stamina"):
			_stamina_arc_instance.update_stamina(stamina, max_stamina)

	# Dash cooldown timer
	if dash_cooldown_left > 0.0:
		dash_cooldown_left = maxf(dash_cooldown_left - delta, 0.0)
		dash_cooldown_changed.emit(dash_cooldown_left, dash_cooldown)

	# Jump and Jetpack Flight handling
	var wants_jump : bool = Input.is_action_just_pressed(input_jump)
	var holding_jump : bool = Input.is_action_pressed(input_jump)

	# 1. Ground Jump (consumes shared stamina, independent of dash cooldown)
	if can_jump and wants_jump and is_on_floor() and not is_dashing and stamina >= jump_cost:
		stamina = maxf(stamina - jump_cost, 0.0)
		stamina_changed.emit(stamina, max_stamina)
		if is_instance_valid(_stamina_arc_instance) and _stamina_arc_instance.has_method("update_stamina"):
			_stamina_arc_instance.update_stamina(stamina, max_stamina)
		velocity.y = jump_velocity
		var snd : Node = get_node_or_null("/root/UiSound")
		if snd != null and snd.has_method("play_jump"):
			snd.play_jump()

	# 2. Pressurized Air Flight Thrusters (Hold Space in mid-air or after jumping)
	# Requires minimal remaining stamina (>= 0.2) to engage flight thrusters.
	# Continues burning while holding Space until stamina depletes to 0.0.
	# Once stamina reaches 0, the thruster cuts off until at least a minimal burst has recharged.
	var can_thrust : bool = can_fly and can_move and not freeflying and not _is_dead() and not is_dashing
	var can_start_thrust : bool = (stamina >= 0.2)
	var can_continue_thrust : bool = is_flying and (stamina > 0.0)
	var should_thrust : bool = can_thrust and holding_jump and not is_on_floor() and (can_start_thrust or can_continue_thrust)

	if should_thrust:
		if not is_flying:
			_flight_start_y = global_position.y
		is_flying = true

		# Calculate altitude above ground to keep flight height reasonable and balanced
		var altitude : float = _get_altitude_above_ground()
		if is_inf(altitude):
			altitude = maxf(global_position.y - _flight_start_y, 0.0)

		# Upward vertical thrust counteracting gravity and accelerating upward up to ceiling
		if altitude < max_flight_height:
			velocity.y = move_toward(velocity.y, max_fly_speed, fly_acceleration * delta)
		else:
			# Reached maximum reasonable flight height: hover smoothly at ceiling
			velocity.y = move_toward(velocity.y, 0.0, fly_acceleration * 1.5 * delta)

		# Consume pressurized air (stamina)
		stamina = maxf(stamina - fly_cost_per_second * delta, 0.0)
		stamina_changed.emit(stamina, max_stamina)
		if is_instance_valid(_stamina_arc_instance) and _stamina_arc_instance.has_method("update_stamina"):
			_stamina_arc_instance.update_stamina(stamina, max_stamina)

		# Visual & Audio Thrusters
		if is_instance_valid(_dash_particles_instance) and _dash_particles_instance.has_method("set_flying"):
			_dash_particles_instance.set_flying(true)
		var snd : Node = get_node_or_null("/root/UiSound")
		if snd != null and snd.has_method("start_thruster"):
			snd.start_thruster()
	else:
		if is_flying:
			is_flying = false
			if is_instance_valid(_dash_particles_instance) and _dash_particles_instance.has_method("set_flying"):
				_dash_particles_instance.set_flying(false)
			var snd : Node = get_node_or_null("/root/UiSound")
			if snd != null and snd.has_method("stop_thruster"):
				snd.stop_thruster()

	# Dash handling: pressing Shift triggers a dash, or holding Shift continuously fires dashes (up to 3) spaced by cooldown
	if can_dash and can_move and not freeflying and not _is_dead():
		if Input.is_action_pressed(input_sprint) and not is_dashing and dash_cooldown_left <= 0.0 and stamina >= dash_cost:
			_perform_dash()

	# Movement execution
	if is_dashing:
		_dash_time_left -= delta
		velocity.x = _dash_direction.x * dash_speed
		velocity.z = _dash_direction.z * dash_speed
		if _dash_time_left <= 0.0:
			is_dashing = false
			if is_instance_valid(_dash_particles_instance) and _dash_particles_instance.has_method("stop_dash"):
				_dash_particles_instance.stop_dash()
	elif can_move:
		var input_dir := Input.get_vector(input_left, input_right, input_forward, input_back)
		
		# 1. Create the raw direction from input
		var raw_dir := Vector3(input_dir.x, 0, input_dir.y)
		
		# 2. Rotate that direction by our offset angle
		var move_dir := raw_dir.rotated(Vector3.UP, deg_to_rad(movement_offset_angle)).normalized()
		
		if move_dir:
			velocity.x = move_dir.x * base_speed
			velocity.z = move_dir.z * base_speed
			
			# Rotate character to face movement
			var target_angle = atan2(velocity.x, velocity.z)
			rotation.y = lerp_angle(rotation.y, target_angle, rotation_speed * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, base_speed)
			velocity.z = move_toward(velocity.z, 0, base_speed)
	else:
		velocity.x = 0
		velocity.z = 0

	# Prevent physics explosion, NaN contamination, or runaway velocity spikes
	if is_nan(velocity.x) or is_inf(velocity.x): velocity.x = 0.0
	if is_nan(velocity.y) or is_inf(velocity.y): velocity.y = 0.0
	if is_nan(velocity.z) or is_inf(velocity.z): velocity.z = 0.0
	velocity.x = clampf(velocity.x, -28.0, 28.0)
	velocity.y = clampf(velocity.y, -35.0, 22.0)
	velocity.z = clampf(velocity.z, -28.0, 28.0)

	move_and_slide()

	# Safeguard against falling through world geometry or being launched into the abyss
	if global_position.y < -8.0 or absf(global_position.x) > 45.0 or absf(global_position.z) > 45.0:
		var rescue_pos := Vector3(0.0, 0.25, 0.0)
		var map_geom : Node = get_tree().get_first_node_in_group("navigation_geometry") if get_tree() != null else null
		if map_geom != null and map_geom.has_method("get_terrain_height"):
			rescue_pos.y = float(map_geom.call("get_terrain_height", rescue_pos.x, rescue_pos.z)) + 0.25
		global_position = rescue_pos
		velocity = Vector3.ZERO

func _perform_dash() -> void:
	stamina = maxf(stamina - dash_cost, 0.0)
	dash_cooldown_left = dash_cooldown
	is_dashing = true
	_dash_time_left = dash_duration

	stamina_changed.emit(stamina, max_stamina)
	dash_cooldown_changed.emit(dash_cooldown_left, dash_cooldown)

	if is_instance_valid(_stamina_arc_instance) and _stamina_arc_instance.has_method("update_stamina"):
		_stamina_arc_instance.update_stamina(stamina, max_stamina)

	# Determine dash direction from movement input, or fallback to current facing
	var input_dir := Input.get_vector(input_left, input_right, input_forward, input_back)
	var anim : Node = get_node_or_null("PlayerAnimation")
	var current_facing : Vector3 = Vector3(sin(rotation.y), 0.0, cos(rotation.y)).normalized()
	if anim != null and anim.has_method("get_facing_direction"):
		var mesh_facing : Vector3 = anim.call("get_facing_direction")
		if not mesh_facing.is_zero_approx():
			current_facing = mesh_facing.normalized()

	if input_dir.length_squared() > 0.01:
		var raw_dir := Vector3(input_dir.x, 0.0, input_dir.y)
		_dash_direction = raw_dir.rotated(Vector3.UP, deg_to_rad(movement_offset_angle)).normalized()
	else:
		_dash_direction = current_facing

	# Compute relative dash vector (forward, backward, left, right)
	var fwd : Vector3 = current_facing
	fwd.y = 0.0
	fwd = fwd.normalized() if not fwd.is_zero_approx() else Vector3.FORWARD
	var right_vec : Vector3 = fwd.cross(Vector3.UP).normalized()
	var rel_fwd : float = _dash_direction.dot(fwd)
	var rel_right : float = _dash_direction.dot(right_vec)

	# Trigger procedural dash animation with relative direction
	if anim != null and anim.has_method("play_dash"):
		anim.call("play_dash", _dash_direction, current_facing, rel_fwd, rel_right)

	# Trigger dash particle effect
	if is_instance_valid(_dash_particles_instance):
		if _dash_particles_instance.has_method("start_dash_directional"):
			_dash_particles_instance.call("start_dash_directional", _dash_direction, current_facing, rel_fwd, rel_right, dash_duration)
		elif _dash_particles_instance.has_method("start_dash"):
			_dash_particles_instance.start_dash(_dash_direction, dash_duration)
		elif _dash_particles_instance.has_method("trigger"):
			_dash_particles_instance.trigger(_dash_direction)

	# Trigger sound
	var snd : Node = get_node_or_null("/root/UiSound")
	if snd != null and snd.has_method("play_dash"):
		snd.play_dash()

	dashed.emit(_dash_direction)

func _is_dead() -> bool:
	var hc : Node = get_node_or_null("HealthComponent")
	if hc != null and hc.has_method("is_dead"):
		return hc.call("is_dead")
	return false

func _get_altitude_above_ground() -> float:
	var space_state := get_world_3d().direct_space_state
	if space_state == null:
		return INF
	var from : Vector3 = global_position + Vector3(0.0, 0.1, 0.0)
	var to : Vector3 = from + Vector3(0.0, -max_flight_height * 2.5, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, to, 1) # Layer 1 = World geometry
	query.exclude = [get_rid()]
	var hit := space_state.intersect_ray(query)
	if hit.is_empty():
		return INF
	return maxf(from.y - (hit.position as Vector3).y - 0.1, 0.0)

func enable_freefly():
	collider.disabled = true
	freeflying = true
	velocity = Vector3.ZERO

func disable_freefly():
	collider.disabled = false
	freeflying = false

func check_input_mappings():
	if can_move and not InputMap.has_action(input_left):
		push_error("Movement disabled. No InputAction found for input_left: " + input_left)
		can_move = false
	if can_move and not InputMap.has_action(input_right):
		push_error("Movement disabled. No InputAction found for input_right: " + input_right)
		can_move = false
	if can_move and not InputMap.has_action(input_forward):
		push_error("Movement disabled. No InputAction found for input_forward: " + input_forward)
		can_move = false
	if can_move and not InputMap.has_action(input_back):
		push_error("Movement disabled. No InputAction found for input_back: " + input_back)
		can_move = false
