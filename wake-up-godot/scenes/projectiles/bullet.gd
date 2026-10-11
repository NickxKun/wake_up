extends Area3D

## Straight-flying projectile that damages the first HealthComponent it hits.

## Max bodies skipped (shooter's allies) by a single movement sweep.
const MAX_SWEEP_SKIPS : int = 4
const IMPACT_SCENE : PackedScene = preload("res://scenes/projectiles/bullet_impact.tscn")
const IMPACT_OFFSET : float = 0.03

@export var speed : float = 10.0
@export var damage : int = 10
## Seconds before the bullet frees itself.
@export var lifetime : float = 2.0
## Material used instead of the default when the player fired this bullet.
@export var player_material : Material

## The node that fired this bullet; it is never damaged by it.
var shooter : Node3D
var direction : Vector3 = Vector3.FORWARD

var _previous_position : Vector3
var _has_moved : bool = false

@onready var mesh_instance : MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)
	if direction != Vector3.ZERO:
		basis = Basis.looking_at(direction)
	if is_instance_valid(shooter) and shooter.is_in_group("player"):
		mesh_instance.material_override = player_material

func _physics_process(delta: float) -> void:
	if is_queued_for_deletion():
		return
	if not _has_moved:
		_has_moved = true
		# Sweep the first step from the shooter's center so a muzzle spawned past a wall still hits it.
		_previous_position = global_position
		if is_instance_valid(shooter):
			_previous_position = Vector3(shooter.global_position.x, global_position.y, shooter.global_position.z)
	var next_position : Vector3 = global_position + direction * speed * delta
	# Raycast the step: Jolt areas don't detect static bodies by default and thin walls can be skipped.
	var hit : Dictionary = _sweep(_previous_position, next_position)
	if not hit.is_empty():
		global_position = hit.position
		_hit(hit.collider as Node3D, hit.normal)
		return
	global_position = next_position
	_previous_position = next_position

func _sweep(from: Vector3, to: Vector3) -> Dictionary:
	var query : PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, collision_mask)
	var exclude : Array[RID] = []
	if is_instance_valid(shooter) and shooter is CollisionObject3D:
		exclude.append((shooter as CollisionObject3D).get_rid())
	var space_state : PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	for _i in MAX_SWEEP_SKIPS:
		query.exclude = exclude
		var hit : Dictionary = space_state.intersect_ray(query)
		if hit.is_empty():
			return hit
		var body : Node3D = hit.collider as Node3D
		if body != null and _is_ally(body):
			exclude.append(hit.rid)
			continue
		return hit
	return {}

func _on_body_entered(body: Node3D) -> void:
	if body == shooter or _is_ally(body):
		return
	_hit(body)

func _hit(body: Node3D, normal: Vector3 = Vector3.ZERO) -> void:
	if is_queued_for_deletion():
		return
	if body != null:
		var health_component : HealthComponent = body.get_node_or_null("HealthComponent")
		if health_component != null:
			health_component.decrease_health(damage)
	_spawn_impact(normal)
	queue_free()

func _is_ally(body: Node3D) -> bool:
	return is_instance_valid(shooter) and shooter.is_in_group("enemy") and body.is_in_group("enemy")

func _spawn_impact(normal: Vector3) -> void:
	if normal.is_zero_approx():
		normal = -direction
	normal = normal.normalized()
	# Back-face ray hits return a normal along the shot; always spray back toward the shooter's side.
	if normal.dot(direction) > 0.0:
		normal = -normal
	var impact : Node3D = IMPACT_SCENE.instantiate()
	# Place it before it enters the tree so the world-space particles never emit from the origin.
	impact.top_level = true
	impact.transform = Transform3D(_basis_from_up(normal), global_position + normal * IMPACT_OFFSET)
	get_parent().add_child(impact)

## Basis whose Y axis points along up; Quaternion(UP, -UP) degenerates to identity.
func _basis_from_up(up: Vector3) -> Basis:
	if up.dot(Vector3.UP) < -0.999:
		return Basis(Vector3.RIGHT, PI)
	return Basis(Quaternion(Vector3.UP, up))
