extends CharacterBody3D

## Chases the player in a straight line and shoots at them.

const BULLET_SCENE : PackedScene = preload("res://scenes/projectiles/bullet.tscn")
## Height above the feet that bullets and line-of-sight rays start from.
const MUZZLE_HEIGHT : float = 0.15
## Layers that block line of sight (level geometry).
const SIGHT_COLLISION_MASK : int = 1

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

var _player : Node3D
var _shoot_timer : float = 0.0
var _repath_timer : float = 0.0

@onready var health_component : HealthComponent = $HealthComponent
@onready var navigation_agent : NavigationAgent3D = $NavigationAgent3D
@onready var model : Node3D = $Model
@onready var enemy_animation : Node = $EnemyAnimation

func _ready() -> void:
	add_to_group("enemy")
	health_component.health_depleted.connect(queue_free)
	health_component.health_depleted.connect(PlayerHealthHud.add_enemy_kill)
	_shoot_timer = shoot_interval
	_tint_model()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	if _player == null or _is_player_dead():
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var to_player : Vector3 = _player.global_position - global_position
	to_player.y = 0.0
	var distance : float = to_player.length()
	var shoot_direction : Vector3 = to_player.normalized()
	var has_sight : bool = _has_line_of_sight()

	_repath_timer -= delta
	if _repath_timer <= 0.0:
		_repath_timer = repath_interval
		navigation_agent.target_position = _player.global_position

	var direction : Vector3 = _get_path_direction()
	var path_distance : float = _get_path_distance()
	if direction == Vector3.ZERO:
		# No usable navigation path (navmesh empty or not synced yet): chase directly.
		direction = shoot_direction
		path_distance = distance
	# Keep closing in while a wall is between us, even inside stop_distance.
	if direction != Vector3.ZERO and (path_distance > stop_distance or not has_sight):
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	if distance > 0.01:
		var is_moving : bool = velocity.x != 0.0 or velocity.z != 0.0
		var look_direction : Vector3 = direction if is_moving and direction != Vector3.ZERO else shoot_direction
		rotation.y = lerp_angle(rotation.y, atan2(look_direction.x, look_direction.z), rotation_speed * delta)
	move_and_slide()

	_shoot_timer -= delta
	if _shoot_timer <= 0.0 and distance <= shoot_range and has_sight:
		_shoot_timer = shoot_interval
		_shoot(shoot_direction)

func _shoot(direction: Vector3) -> void:
	var muzzle : Vector3 = global_position + Vector3(0, MUZZLE_HEIGHT, 0) + direction * 0.4
	if enemy_animation != null:
		# Leave from the gun's muzzle, but keep shots level at MUZZLE_HEIGHT so the player can jump them.
		muzzle = enemy_animation.play_shoot(direction)
		muzzle.y = global_position.y + MUZZLE_HEIGHT
		var to_player : Vector3 = _player.global_position - muzzle
		to_player.y = 0.0
		if to_player.length_squared() > 0.0001:
			direction = to_player.normalized()
	var bullet : Area3D = BULLET_SCENE.instantiate()
	bullet.shooter = self
	bullet.direction = direction
	bullet.damage = bullet_damage
	get_parent().add_child(bullet)
	bullet.global_position = muzzle

## Gives each model surface a tinted copy of its material; roughness is kept so edge outlines still show.
func _tint_model() -> void:
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

## True when no level geometry blocks a ray from our muzzle to the player.
func _has_line_of_sight() -> bool:
	var from : Vector3 = global_position + Vector3(0, MUZZLE_HEIGHT, 0)
	var to : Vector3 = _player.global_position + Vector3(0, MUZZLE_HEIGHT, 0)
	var query : PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, SIGHT_COLLISION_MASK)
	var exclude : Array[RID] = [get_rid()]
	if _player is CollisionObject3D:
		exclude.append((_player as CollisionObject3D).get_rid())
	query.exclude = exclude
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _is_player_dead() -> bool:
	var player_health : HealthComponent = _player.get_node_or_null("HealthComponent")
	return player_health != null and player_health.is_dead()

func _get_path_direction() -> Vector3:
	if navigation_agent.is_navigation_finished():
		return Vector3.ZERO
	var to_next : Vector3 = navigation_agent.get_next_path_position() - global_position
	to_next.y = 0.0
	if to_next.length_squared() < 0.0001:
		return Vector3.ZERO
	return to_next.normalized()

## Remaining walking distance along the navigation path to the player.
func _get_path_distance() -> float:
	var path : PackedVector3Array = navigation_agent.get_current_navigation_path()
	var index : int = navigation_agent.get_current_navigation_path_index()
	if path.is_empty():
		return INF
	var total : float = 0.0
	var previous : Vector3 = global_position
	for i in range(index, path.size()):
		total += previous.distance_to(path[i])
		previous = path[i]
	return total
