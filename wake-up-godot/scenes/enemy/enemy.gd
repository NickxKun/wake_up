extends CharacterBody3D

## Chases the player in a straight line and shoots at them.

enum EnemyWeaponType {
	PISTOL = 0,
	SHOTGUN = 1,
	DOUBLE_PISTOLS = 2,
}

const BULLET_SCENE : PackedScene = preload("res://scenes/projectiles/bullet.tscn")
## Height above the feet that bullets and line-of-sight rays start from.
const MUZZLE_HEIGHT : float = 0.15
## Layers that block line of sight (level geometry).
const SIGHT_COLLISION_MASK : int = 1

@export var weapon_type : EnemyWeaponType = EnemyWeaponType.PISTOL
@export var move_speed : float = 1.5
## Enemy stops moving when closer than this to the player.
@export var stop_distance : float = 2.5
## Enemy only shoots when the player is within this distance.
@export var shoot_range : float = 8.0
## Seconds between shots.
@export var shoot_interval : float = 1.5
@export var rotation_speed : float = 8.0
## Seconds between navigation path updates.
@export var repath_interval : float = 0.2
## Damage dealt by each bullet this enemy fires. Set by the spawner.
@export var bullet_damage : int = 2
## Multiplied into the model's texture colour so enemies read as hostile.
@export var model_tint : Color = Color(1.0, 0.35, 0.35)
## Colour of the model's emissive parts.
@export var model_emission : Color = Color(1.0, 0.15, 0.1)

@export_group("Obstacle & Jump Handling")
## Can the enemy jump over small obstacles and elevation changes?
@export var can_jump : bool = true
## Vertical impulse when jumping over an obstacle.
@export var jump_velocity : float = 3.6
## Seconds before the enemy can jump again.
@export var jump_cooldown : float = 0.6

var _player : Node3D
var _shoot_timer : float = 0.0
var _repath_timer : float = 0.0
var _jump_cooldown_timer : float = 0.0
var _is_dying : bool = false
var _current_nav_path : PackedVector3Array = PackedVector3Array()
var _current_nav_index : int = 0

@onready var health_component : HealthComponent = $HealthComponent
@onready var navigation_agent : NavigationAgent3D = $NavigationAgent3D
@onready var model : Node3D = $Model
@onready var enemy_animation : Node = $EnemyAnimation

func _ready() -> void:
	add_to_group("enemy")
	health_component.health_depleted.connect(_on_death)
	var hud : Node = get_node_or_null("/root/PlayerHealthHud")
	if hud != null and hud.has_method("add_enemy_kill"):
		health_component.health_depleted.connect(hud.add_enemy_kill)
	set_weapon_type(weapon_type)
	_shoot_timer = shoot_interval

## Configures the combat role, weapon model attachment, and stats of this enemy unit
func set_weapon_type(new_type: EnemyWeaponType) -> void:
	weapon_type = new_type
	if enemy_animation == null:
		enemy_animation = get_node_or_null("EnemyAnimation")
	match weapon_type:
		EnemyWeaponType.SHOTGUN:
			shoot_interval = 2.0
			shoot_range = 7.5
			model_tint = Color(1.0, 0.58, 0.22) # Heavy ballistic orange
			model_emission = Color(1.0, 0.35, 0.05)
			if enemy_animation != null and enemy_animation.has_method("set_weapon_model"):
				enemy_animation.set_weapon_model(1)
		EnemyWeaponType.DOUBLE_PISTOLS:
			shoot_interval = 0.95
			shoot_range = 8.5
			model_tint = Color(0.35, 1.0, 0.55) # Cyber twin green
			model_emission = Color(0.15, 0.85, 0.3)
			if enemy_animation != null and enemy_animation.has_method("set_weapon_model"):
				enemy_animation.set_weapon_model(3)
		_:
			shoot_interval = 1.5
			shoot_range = 8.0
			model_tint = Color(1.0, 0.35, 0.35) # Standard hostile crimson
			model_emission = Color(1.0, 0.15, 0.1)
			if enemy_animation != null and enemy_animation.has_method("set_weapon_model"):
				enemy_animation.set_weapon_model(0)
	_tint_model()

func _on_death() -> void:
	if _is_dying:
		return
	_is_dying = true

	# Play enemy death audio
	var snd : Node = get_node_or_null("/root/UiSound")
	if snd != null and snd.has_method("play_enemy_death"):
		snd.play_enemy_death()

	# Immediately remove from enemy group and disable collisions so player / auto-aim / bullets ignore dying entity
	remove_from_group("enemy")
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	set_process(false)

	_play_disintegration()

func _play_disintegration() -> void:
	if not is_inside_tree() or model == null:
		queue_free()
		return

	# 1. Spawn snappy low-poly dust cloud burst
	_spawn_disintegration_particles()

	# 2. Snappy model disintegration animation (0.30s)
	# Flash bright cyber-tint (0.05s) -> collapse vertically into ash while fading (0.25s)
	var tween := create_tween()
	var initial_scale := model.scale

	# Flash and fade materials
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for surface in mi.get_surface_override_material_count():
			var mat := mi.get_active_material(surface) as StandardMaterial3D
			if mat != null:
				var unique_mat := mat.duplicate() as StandardMaterial3D
				unique_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				unique_mat.emission_enabled = true
				unique_mat.emission = Color(1.0, 0.45, 0.15)
				unique_mat.emission_energy_multiplier = 3.0
				mi.set_surface_override_material(surface, unique_mat)
				tween.parallel().tween_property(unique_mat, "emission_energy_multiplier", 0.0, 0.28)
				tween.parallel().tween_property(unique_mat, "albedo_color:a", 0.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Collapse model into ground dust
	tween.parallel().tween_property(model, "scale", Vector3(initial_scale.x * 0.1, 0.01, initial_scale.z * 0.1), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(model, "position:y", 0.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	tween.tween_callback(queue_free)

func _spawn_disintegration_particles() -> void:
	var parent_node := get_parent()
	if parent_node == null or not is_inside_tree():
		return

	var p := CPUParticles3D.new()
	p.name = "DisintegrationDust"
	p.top_level = true
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = 0.45
	p.amount = 32

	# Faceted low-poly box chunk
	var box := BoxMesh.new()
	box.size = Vector3(0.045, 0.045, 0.045)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	box.material = mat
	p.mesh = box

	# Disintegration velocity & spread
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.15
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 1.4
	p.initial_velocity_max = 2.6
	p.linear_accel_min = -1.5
	p.linear_accel_max = -0.5
	p.gravity = Vector3(0.0, 0.8, 0.0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4

	# Color ramp from bright fiery cyber-orange to dark ash carbon to transparent
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.35, 0.8, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 0.72, 0.2, 1.0),
		Color(0.92, 0.28, 0.18, 0.95),
		Color(0.24, 0.18, 0.16, 0.7),
		Color(0.1, 0.08, 0.08, 0.0)
	])
	p.color_ramp = gradient

	parent_node.add_child(p)
	p.global_position = global_position + Vector3(0.0, 0.35, 0.0)
	p.restart()

	var tree : SceneTree = get_tree()
	if tree != null:
		tree.create_timer(0.6).timeout.connect(p.queue_free)
	else:
		p.queue_free()

var _active_target : Node3D = null

func _select_target() -> Node3D:
	if not is_inside_tree() or get_tree() == null:
		return null

	# 1. Prioritize active sentry turrets within detection range (18.0m) before player
	var turrets := get_tree().get_nodes_in_group("turret")
	var closest_turret : Node3D = null
	var closest_turret_dist : float = 18.0
	for t in turrets:
		if t != null and is_instance_valid(t) and (t is Node3D) and (t as Node3D).is_inside_tree():
			var hc : HealthComponent = (t as Node).get_node_or_null("HealthComponent") as HealthComponent
			if hc != null and hc.is_dead():
				continue
			var d : float = global_position.distance_to((t as Node3D).global_position)
			if d < closest_turret_dist:
				closest_turret_dist = d
				closest_turret = t as Node3D

	if closest_turret != null:
		return closest_turret

	# 2. Fall back to player if no active turret in range
	if _player != null and is_instance_valid(_player) and _player.is_inside_tree() and not _is_player_dead():
		return _player

	var found_player : Node = get_tree().get_first_node_in_group("player")
	if found_player != null and is_instance_valid(found_player) and (found_player as Node).is_inside_tree():
		_player = found_player as Node3D
		if not _is_player_dead():
			return _player

	return null

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	if _jump_cooldown_timer > 0.0:
		_jump_cooldown_timer = maxf(_jump_cooldown_timer - delta, 0.0)

	_active_target = _select_target()
	if _active_target == null or not is_instance_valid(_active_target) or not _active_target.is_inside_tree():
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var target_center : Vector3 = _active_target.global_position + Vector3(0.0, 0.3, 0.0)
	var muzzle_approx : Vector3 = global_position + Vector3(0.0, MUZZLE_HEIGHT, 0.0)
	var to_target_3d : Vector3 = target_center - muzzle_approx
	var distance_3d : float = to_target_3d.length()
	var shoot_direction_3d : Vector3 = to_target_3d.normalized() if distance_3d > 0.0001 else -transform.basis.z

	var to_target_horiz := Vector3(to_target_3d.x, 0.0, to_target_3d.z)
	var distance_horiz : float = to_target_horiz.length()
	var horiz_direction : Vector3 = to_target_horiz.normalized() if distance_horiz > 0.0001 else -transform.basis.z
	var has_sight : bool = _has_line_of_sight()

	# Only repath when grounded to avoid off-mesh navigation queries during mid-air vaults
	if is_on_floor():
		_repath_timer -= delta
		if _repath_timer <= 0.0:
			_repath_timer = repath_interval
			if _is_nav_ready():
				var map : RID = navigation_agent.get_navigation_map() if navigation_agent != null else get_world_3d().navigation_map
				var start_pos : Vector3 = NavigationServer3D.map_get_closest_point(map, global_position)
				var nav_target : Vector3 = NavigationServer3D.map_get_closest_point(map, _active_target.global_position)
				var start_owner : RID = NavigationServer3D.map_get_closest_point_owner(map, start_pos)
				var target_owner : RID = NavigationServer3D.map_get_closest_point_owner(map, nav_target)
				if start_owner.is_valid() and target_owner.is_valid():
					if start_pos.distance_to(global_position) < 3.0 and nav_target.distance_to(_active_target.global_position) < 12.0 and start_pos.distance_squared_to(nav_target) >= 0.04:
						var p : PackedVector3Array = NavigationServer3D.map_get_path(map, start_pos, nav_target, true)
						if p.size() >= 2:
							_current_nav_path = p
							_current_nav_index = 1
						else:
							_current_nav_path.clear()
							_current_nav_index = 0
					else:
						_current_nav_path.clear()
						_current_nav_index = 0
				else:
					_current_nav_path.clear()
					_current_nav_index = 0

	var direction : Vector3 = _get_path_direction()
	var path_distance : float = _get_path_distance()
	if direction == Vector3.ZERO:
		# No usable navigation path (navmesh empty or not synced yet): chase directly.
		direction = horiz_direction
		path_distance = distance_horiz

	# Calculate crowd separation so enemies steer around allies rather than clumping
	var separation := _get_crowd_separation()
	var move_dir : Vector3 = direction
	if separation != Vector3.ZERO:
		move_dir = (direction + separation * 0.75).normalized()

	# Check for jumping over small obstacles (low rocks, curbs, ledges, or slope steps)
	if can_jump and _should_jump(move_dir):
		_perform_jump(move_dir)

	# Keep closing in while a wall is between us, even inside stop_distance.
	if direction != Vector3.ZERO and (path_distance > stop_distance or not has_sight):
		velocity.x = move_dir.x * move_speed
		velocity.z = move_dir.z * move_speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	if distance_horiz > 0.01:
		var is_moving : bool = velocity.x != 0.0 or velocity.z != 0.0
		var look_direction : Vector3 = move_dir if is_moving and move_dir != Vector3.ZERO else horiz_direction
		rotation.y = lerp_angle(rotation.y, atan2(look_direction.x, look_direction.z), rotation_speed * delta)
	move_and_slide()

	_shoot_timer -= delta
	if _shoot_timer <= 0.0 and distance_3d <= shoot_range and has_sight:
		_shoot_timer = shoot_interval
		_shoot(shoot_direction_3d)

## Applies vertical velocity impulse to vault cleanly over small obstacles or elevation steps.
func _perform_jump(move_dir: Vector3) -> void:
	velocity.y = jump_velocity
	_jump_cooldown_timer = jump_cooldown
	# Apply forward impulse to clear the obstacle during the arc
	velocity.x = move_dir.x * move_speed * 1.15
	velocity.z = move_dir.z * move_speed * 1.15

## Detects if an obstacle ahead requires a jump to clear.
func _should_jump(move_dir: Vector3) -> bool:
	if not is_on_floor() or _jump_cooldown_timer > 0.0 or move_dir.length_squared() < 0.001:
		return false

	var space_state := get_world_3d().direct_space_state
	if space_state == null:
		return false

	# 1. Contact with a wall/obstruction while advancing forward
	if is_on_wall():
		if _has_head_clearance(space_state, move_dir):
			return true

	# 2. Forward raycast at low height hits obstacle, but high height is clear
	var low_from : Vector3 = global_position + Vector3(0.0, 0.12, 0.0)
	var low_to : Vector3 = low_from + move_dir * 0.52
	var low_query := PhysicsRayQueryParameters3D.create(low_from, low_to, 1) # Layer 1 = World geometry
	low_query.exclude = [get_rid()]
	var low_hit := space_state.intersect_ray(low_query)

	if not low_hit.is_empty():
		var high_from : Vector3 = global_position + Vector3(0.0, 0.55, 0.0)
		var high_to : Vector3 = high_from + move_dir * 0.52
		var high_query := PhysicsRayQueryParameters3D.create(high_from, high_to, 1)
		high_query.exclude = [get_rid()]
		var high_hit := space_state.intersect_ray(high_query)
		if high_hit.is_empty():
			return true

	# 3. Path elevation rise ahead (slope step or ledge transition)
	if _current_nav_index < _current_nav_path.size():
		var next_path_pos : Vector3 = _current_nav_path[_current_nav_index]
		var dy : float = next_path_pos.y - global_position.y
		if dy > 0.18 and dy < 1.2:
			var horiz_dist : float = Vector2(next_path_pos.x - global_position.x, next_path_pos.z - global_position.z).length()
			if horiz_dist < 0.85:
				return true

	return false

## Verifies open space above the obstacle so the enemy doesn't jump into ceilings or tall walls.
func _has_head_clearance(space_state: PhysicsDirectSpaceState3D, move_dir: Vector3) -> bool:
	var high_from : Vector3 = global_position + Vector3(0.0, 0.58, 0.0)
	var high_to : Vector3 = high_from + move_dir * 0.5
	var query := PhysicsRayQueryParameters3D.create(high_from, high_to, 1)
	query.exclude = [get_rid()]
	return space_state.intersect_ray(query).is_empty()

## Dynamic flocking force that steers enemies around each other so they do not overlap.
func _get_crowd_separation() -> Vector3:
	var separation := Vector3.ZERO
	if not is_inside_tree():
		return separation
	var tree : SceneTree = get_tree()
	if tree == null:
		return separation
	var enemies := tree.get_nodes_in_group("enemy")
	for other in enemies:
		if other == self or not is_instance_valid(other) or not (other is CharacterBody3D):
			continue
		var to_self : Vector3 = global_position - other.global_position
		to_self.y = 0.0
		var dist_sq : float = to_self.length_squared()
		if dist_sq < 0.42 and dist_sq > 0.0001: # Within 0.65m radius
			var dist : float = sqrt(dist_sq)
			var push : float = (0.65 - dist) / 0.65
			separation += (to_self / dist) * push
	return separation

func _shoot(direction: Vector3) -> void:
	var muzzle : Vector3 = global_position + Vector3(0.0, MUZZLE_HEIGHT, 0.0) + direction * 0.4
	if enemy_animation != null:
		# Gun muzzle position in 3D
		muzzle = enemy_animation.play_shoot(direction)
		if _active_target != null and is_instance_valid(_active_target):
			var target_center : Vector3 = _active_target.global_position + Vector3(0.0, 0.3, 0.0)
			var to_target : Vector3 = target_center - muzzle
			if to_target.length_squared() > 0.0001:
				direction = to_target.normalized()

	match weapon_type:
		EnemyWeaponType.SHOTGUN:
			var snd : Node = get_node_or_null("/root/UiSound")
			if snd != null and snd.has_method("play_shoot"):
				snd.play_shoot(0.22)
			var spread_angles := [-12.0, -6.0, 0.0, 6.0, 12.0]
			for angle_deg in spread_angles:
				var rad : float = deg_to_rad(angle_deg)
				var spread_dir : Vector3 = direction.rotated(Vector3.UP, rad)
				_spawn_enemy_bullet(muzzle, spread_dir, maxi(1, bullet_damage / 2), 0.75, 12.0)
		EnemyWeaponType.DOUBLE_PISTOLS:
			var snd : Node = get_node_or_null("/root/UiSound")
			if snd != null and snd.has_method("play_shoot"):
				snd.play_shoot(0.05)
			var right_vec : Vector3 = direction.cross(Vector3.UP).normalized()
			if right_vec.is_zero_approx():
				right_vec = Vector3.RIGHT
			_spawn_enemy_bullet(muzzle + right_vec * 0.14, direction, maxi(1, int(bullet_damage * 0.75)), 1.4, 13.0)
			_spawn_enemy_bullet(muzzle - right_vec * 0.14, direction, maxi(1, int(bullet_damage * 0.75)), 1.4, 13.0)
		_:
			var snd : Node = get_node_or_null("/root/UiSound")
			if snd != null and snd.has_method("play_enemy_shoot"):
				snd.play_enemy_shoot()
			_spawn_enemy_bullet(muzzle, direction, bullet_damage, 2.0, 10.0)

func _spawn_enemy_bullet(muzzle_pos: Vector3, dir: Vector3, dmg: int, life: float = 2.0, spd: float = 10.0) -> void:
	var bullet : Area3D = BULLET_SCENE.instantiate()
	bullet.shooter = self
	bullet.direction = dir
	bullet.damage = dmg
	if "speed" in bullet:
		bullet.speed = spd
	if "lifetime" in bullet:
		bullet.lifetime = life
	get_parent().add_child(bullet)
	bullet.global_position = muzzle_pos

## Gives each model surface a tinted copy of its material; roughness is kept so edge outlines still show.
func _tint_model() -> void:
	if model == null:
		model = get_node_or_null("Model")
	if model == null:
		return
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance : MeshInstance3D = node
		for surface in mesh_instance.get_surface_override_material_count():
			var material : BaseMaterial3D = mesh_instance.get_active_material(surface) as BaseMaterial3D
			if material == null:
				continue
			var tinted : BaseMaterial3D = material.duplicate()
			tinted.albedo_color = model_tint
			tinted.emission = model_emission
			mesh_instance.set_surface_override_material(surface, tinted)

## True when no level geometry blocks a 3D ray from our muzzle to the active target's center.
func _has_line_of_sight() -> bool:
	if _active_target == null or not is_instance_valid(_active_target) or not _active_target.is_inside_tree():
		return false
	if not is_inside_tree():
		return false
	var world_3d : World3D = get_world_3d()
	if world_3d == null or world_3d.direct_space_state == null:
		return false
	var from : Vector3 = global_position + Vector3(0.0, MUZZLE_HEIGHT, 0.0)
	var to : Vector3 = _active_target.global_position + Vector3(0.0, 0.3, 0.0)
	var query : PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, SIGHT_COLLISION_MASK)
	var exclude : Array[RID] = [get_rid()]
	if _active_target is CollisionObject3D:
		exclude.append((_active_target as CollisionObject3D).get_rid())
	if get_tree() != null:
		for v in get_tree().get_nodes_in_group("vehicle"):
			if is_instance_valid(v) and v is CollisionObject3D:
				exclude.append((v as CollisionObject3D).get_rid())
	query.exclude = exclude
	return world_3d.direct_space_state.intersect_ray(query).is_empty()

func _is_player_dead() -> bool:
	if _player == null or not is_instance_valid(_player) or not _player.is_inside_tree():
		return true
	var player_health : HealthComponent = _player.get_node_or_null("HealthComponent")
	return player_health != null and player_health.is_dead()

func _is_nav_ready() -> bool:
	if not is_inside_tree():
		return false
	var map : RID = navigation_agent.get_navigation_map() if navigation_agent != null else get_world_3d().navigation_map
	if not map.is_valid():
		return false
	# If iteration ID is 0, the map has not completed a physics synchronization cycle yet.
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return false
	var regions : Array[RID] = NavigationServer3D.map_get_regions(map)
	if regions.is_empty():
		return false
	return true

func _get_path_direction() -> Vector3:
	if not _is_nav_ready() or _current_nav_path.is_empty():
		return Vector3.ZERO
	while _current_nav_index < _current_nav_path.size():
		var target_pt : Vector3 = _current_nav_path[_current_nav_index]
		var diff : Vector3 = target_pt - global_position
		diff.y = 0.0
		if diff.length() < 0.6:
			_current_nav_index += 1
		else:
			return diff.normalized()
	return Vector3.ZERO

## Remaining walking distance along the navigation path to the player.
func _get_path_distance() -> float:
	if _current_nav_path.is_empty() or _current_nav_index >= _current_nav_path.size():
		return INF
	var total : float = 0.0
	var prev : Vector3 = global_position
	for i in range(_current_nav_index, _current_nav_path.size()):
		total += prev.distance_to(_current_nav_path[i])
		prev = _current_nav_path[i]
	return total
