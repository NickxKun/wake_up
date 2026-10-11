extends Node

## Child of the player. Handles shooting and minimal death handling.

const BULLET_SCENE : PackedScene = preload("res://scenes/projectiles/bullet.tscn")

const AIM_COLLISION_MASK : int = 1
const AIM_RAY_LENGTH : float = 100.0
const MUZZLE_HEIGHT : float = 0.3

## Seconds between shots.
@export var shoot_cooldown : float = 0.25
@export var input_shoot : String = "shoot"
## Seconds the body takes to tip over and lie flat on death.
@export var death_tip_duration : float = 0.4
## Raise the lying mesh by this much so it rests on the floor instead of sinking into it.
@export var death_lift : float = 0.1

var can_shoot : bool = true
var _cooldown_left : float = 0.0

@onready var player : CharacterBody3D = get_parent()
@onready var player_mesh : Node3D = player.get_node("player")
@onready var player_animation : Node = player.get_node_or_null("PlayerAnimation")

func _ready() -> void:
	player.add_to_group("player")
	_connect_health.call_deferred()

func _process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)

func _unhandled_input(_event: InputEvent) -> void:
	if can_shoot and Input.is_action_just_pressed(input_shoot) and _cooldown_left <= 0.0:
		_shoot()

func _shoot() -> void:
	_cooldown_left = shoot_cooldown
	var center : Vector3 = player.global_position + Vector3(0, MUZZLE_HEIGHT, 0)
	var direction : Vector3 = _get_aim_direction(center)
	var muzzle : Vector3 = center + direction * 0.4
	if player_animation != null:
		# Bullets leave from the gun's muzzle but stay at MUZZLE_HEIGHT so cover rules don't change.
		muzzle = player_animation.play_shoot(direction)
		muzzle.y = center.y
		direction = _get_aim_direction(muzzle)
	var bullet : Area3D = BULLET_SCENE.instantiate()
	bullet.shooter = player
	bullet.direction = direction
	player.get_parent().add_child(bullet)
	bullet.global_position = muzzle

## Direction from the muzzle toward the mouse position on the world, flattened to horizontal.
func _get_aim_direction(muzzle: Vector3) -> Vector3:
	var facing : Vector3 = player.global_basis.z
	facing.y = 0.0
	facing = facing.normalized()
	var viewport : Viewport = player.get_viewport()
	var camera : Camera3D = viewport.get_camera_3d()
	if camera == null:
		return facing
	var mouse_position : Vector2 = viewport.get_mouse_position()
	var ray_origin : Vector3 = camera.project_ray_origin(mouse_position)
	var ray_end : Vector3 = ray_origin + camera.project_ray_normal(mouse_position) * AIM_RAY_LENGTH
	var query : PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_origin, ray_end, AIM_COLLISION_MASK)
	query.exclude = [player.get_rid()]
	var hit : Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return facing
	var direction : Vector3 = hit.position - muzzle
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return facing
	return direction.normalized()

func _connect_health() -> void:
	var health_component : HealthComponent = player.get_node_or_null("HealthComponent")
	while health_component == null:
		await get_tree().process_frame
		health_component = player.get_node_or_null("HealthComponent")
	health_component.health_depleted.connect(_on_player_died)

func _on_player_died() -> void:
	can_shoot = false
	player.can_move = false
	player.can_jump = false
	# ProtoController only zeroes velocity.x when can_move is false; clear leftover horizontal drift.
	player.velocity.x = 0.0
	player.velocity.z = 0.0
	# Corpse: ignored by bullets/enemies, still collides with the level so gravity lands it on the floor.
	player.set_deferred("collision_layer", 0)
	player.set_deferred("collision_mask", 1)
	var tween : Tween = create_tween().set_parallel(true)
	tween.tween_property(player_mesh, "rotation:x", -PI / 2.0, death_tip_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(player_mesh, "position:y", death_lift, death_tip_duration)
