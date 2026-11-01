class_name Rocket
extends Area3D

## High-explosive propelled rocket projectile.
## Features smoke exhaust trail, warhead glow, AoE blast damage, and explosive knockback.

const MAX_SWEEP_SKIPS : int = 4
const IMPACT_SCENE : PackedScene = preload("res://scenes/projectiles/bullet_impact.tscn")
const EXPLOSION_SCENE : PackedScene = preload("res://scenes/projectiles/explosion_effect.tscn")
const LASER_BURN_SCENE : PackedScene = preload("res://scenes/projectiles/laser_burn.tscn")

@export var speed : float = 16.0
@export var damage : int = 180
@export var explosion_radius : float = 3.8
@export var knockback_force : float = 9.0
@export var lifetime : float = 3.0

var shooter : Node3D = null
var direction : Vector3 = Vector3.FORWARD
var _previous_position : Vector3
var _has_moved : bool = false
var _detonated : bool = false

@onready var rocket_mesh : Node3D = get_node_or_null("RocketMesh") as Node3D
@onready var trail_particles : CPUParticles3D = get_node_or_null("SmokeTrail") as CPUParticles3D
@onready var explosion_particles : CPUParticles3D = get_node_or_null("ExplosionBurst") as CPUParticles3D
@onready var warhead_light : OmniLight3D = get_node_or_null("WarheadLight") as OmniLight3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var tree : SceneTree = get_tree()
	if tree != null:
		tree.create_timer(lifetime).timeout.connect(_on_lifetime_expired)
	if direction != Vector3.ZERO:
		var up_vec : Vector3 = Vector3.BACK if absf(direction.dot(Vector3.UP)) > 0.95 else Vector3.UP
		basis = Basis.looking_at(direction, up_vec)

func _physics_process(delta: float) -> void:
	if _detonated or is_queued_for_deletion():
		return
	if not _has_moved:
		_has_moved = true
		_previous_position = global_position - direction * 0.25
	var next_position : Vector3 = global_position + direction * speed * delta
	var hit : Dictionary = _sweep(_previous_position, next_position)
	if not hit.is_empty():
		global_position = hit.position
		detonate(hit.collider as Node3D, hit.normal)
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
	if body == shooter or _is_ally(body) or _detonated:
		return
	detonate(body)

func _on_lifetime_expired() -> void:
	if not _detonated and is_inside_tree():
		detonate(null)

func _is_character_target(node: Node) -> bool:
	if node == null:
		return false
	var cur : Node = node
	while cur != null and cur != get_tree().root:
		if cur.is_in_group("enemy") or cur.is_in_group("player"):
			return true
		var bname : String = cur.name.to_lower()
		if bname.contains("enemy") or bname.contains("proto_controller") or bname.contains("protocontroller") or bname.contains("player"):
			return true
		if cur.get_node_or_null("HealthComponent") != null and not cur.is_in_group("vehicles") and not cur.is_in_group("vehicle") and not bname.contains("rover"):
			return true
		cur = cur.get_parent()
	return false

func _is_vehicle_target(node: Node) -> bool:
	if node == null:
		return false
	var cur : Node = node
	while cur != null and cur != get_tree().root:
		if cur.is_in_group("vehicle") or cur.is_in_group("vehicles") or cur.is_in_group("drivable"):
			return true
		var bname : String = cur.name.to_lower()
		if bname.contains("rover") or bname.contains("truck") or bname.contains("spacetruck") or bname.contains("car") or bname.contains("trailer") or bname.contains("vehicle"):
			return true
		cur = cur.get_parent()
	return false

func _is_terrain_edge(space_state: PhysicsDirectSpaceState3D, hit_pos: Vector3, normal: Vector3, _collider: Node3D) -> bool:
	if normal.y < -0.05:
		return true
	if absf(hit_pos.x) >= 38.5 or absf(hit_pos.z) >= 38.5:
		return true
	if space_state != null:
		var center_query := PhysicsRayQueryParameters3D.create(hit_pos + normal * 0.06, hit_pos - normal * 0.18, collision_mask)
		if is_instance_valid(shooter) and (shooter is CollisionObject3D):
			center_query.exclude = [(shooter as CollisionObject3D).get_rid()]
		var center_res := space_state.intersect_ray(center_query)
		if not center_res.is_empty():
			var up_vec : Vector3 = Vector3.BACK if absf(normal.dot(Vector3.UP)) > 0.95 else Vector3.UP
			var basis_norm : Basis = Basis.looking_at(normal, up_vec)
			var right_vec : Vector3 = basis_norm.x.normalized()
			var fwd_vec : Vector3 = basis_norm.y.normalized()
			for probe_dir in [right_vec, -right_vec, fwd_vec, -fwd_vec]:
				var probe_pos : Vector3 = hit_pos + probe_dir * 0.25
				var probe_ray := PhysicsRayQueryParameters3D.create(probe_pos + normal * 0.08, probe_pos - normal * 0.25, collision_mask)
				if is_instance_valid(shooter) and (shooter is CollisionObject3D):
					probe_ray.exclude = [(shooter as CollisionObject3D).get_rid()]
				var res := space_state.intersect_ray(probe_ray)
				if res.is_empty():
					return true
				var p_norm : Vector3 = res["normal"] as Vector3
				if p_norm.dot(normal) < 0.4:
					return true
	return false

## Detonates the rocket, dealing AoE blast damage and knockback to all nearby hostiles.
func detonate(direct_hit_target: Node3D = null, _normal: Vector3 = Vector3.UP) -> void:
	if _detonated:
		return
	_detonated = true

	# Play explosive detonation audio
	var snd : Node = get_node_or_null("/root/UiSound")
	if snd != null and snd.has_method("play_rocket_explode"):
		snd.play_rocket_explode()

	# Trigger concussive screen shake
	var ss : Node = get_node_or_null("/root/ScreenShake")
	if ss != null and ss.has_method("shake"):
		ss.shake(0.65)

	# Spawn billowing thick smoke cloud explosion effect
	if get_parent() != null and EXPLOSION_SCENE != null:
		var exp_fx : Node3D = EXPLOSION_SCENE.instantiate()
		get_parent().add_child(exp_fx)
		exp_fx.global_position = global_position

	# Spawn surface blast scorch crater that fades over time (only on environment, never on character body or truck)
	var is_direct_character : bool = direct_hit_target != null and _is_character_target(direct_hit_target)
	var is_direct_vehicle : bool = direct_hit_target != null and _is_vehicle_target(direct_hit_target)
	var space_state : PhysicsDirectSpaceState3D = null
	if is_inside_tree():
		var w3d : World3D = get_world_3d()
		if w3d != null:
			space_state = w3d.direct_space_state
	var is_edge : bool = _is_terrain_edge(space_state, global_position, _normal, direct_hit_target)

	if not is_direct_character and not is_direct_vehicle and not is_edge and not _normal.is_zero_approx() and LASER_BURN_SCENE != null and get_parent() != null:
		var scorch : Node3D = LASER_BURN_SCENE.instantiate()
		scorch.top_level = true
		get_parent().add_child(scorch)
		scorch.global_position = global_position + _normal * 0.03
		if scorch.has_method("setup_impact"):
			scorch.call("setup_impact", _normal, direction, direct_hit_target, true)
			scorch.scale *= 2.8
		else:
			scorch.scale = Vector3(3.8, 3.8, 3.8)
			var up_basis : Basis = Basis.looking_at(_normal, Vector3.UP if absf(_normal.dot(Vector3.UP)) < 0.9 else Vector3.BACK) * Basis(Vector3.RIGHT, deg_to_rad(90))
			scorch.transform = Transform3D(up_basis, global_position + _normal * 0.03)

	# Visual shockwave & flash on local projectile
	if rocket_mesh != null:
		rocket_mesh.visible = false
	if trail_particles != null:
		trail_particles.emitting = false
	if warhead_light != null:
		warhead_light.light_energy = 5.0
		var tween := create_tween()
		tween.tween_property(warhead_light, "light_energy", 0.0, 0.35)
	if explosion_particles != null:
		explosion_particles.emitting = true

	# Apply distance-falloff AoE damage & knockback to all entities (enemies, player, vehicles)
	var tree : SceneTree = get_tree()
	if tree != null:
		ExplosionEffect.apply_explosion_damage(
			tree,
			global_position,
			explosion_radius,
			damage,
			knockback_force,
			shooter,
			0.38
		)
		# Wait for explosion particles to conclude before cleanup
		tree.create_timer(0.4).timeout.connect(queue_free)
	else:
		queue_free()

func _is_ally(body: Node3D) -> bool:
	if shooter == null:
		return false
	var shooter_is_player : bool = shooter.is_in_group("player")
	var target_is_player : bool = body.is_in_group("player")
	var shooter_is_enemy : bool = shooter.is_in_group("enemy")
	var target_is_enemy : bool = body.is_in_group("enemy")
	return (shooter_is_player and target_is_player) or (shooter_is_enemy and target_is_enemy)
