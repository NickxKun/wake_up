extends Area3D

## Straight-flying projectile that damages the first HealthComponent it hits.

## Max bodies skipped (shooter's allies) by a single movement sweep.
const MAX_SWEEP_SKIPS : int = 4
const IMPACT_SCENE : PackedScene = preload("res://scenes/projectiles/bullet_impact.tscn")
const LASER_BURN_SCENE : PackedScene = preload("res://scenes/projectiles/laser_burn.tscn")
const IMPACT_OFFSET : float = 0.03
const BURN_OFFSET : float = 0.025

@export var speed : float = 10.0
@export var damage : int = 40
## Seconds before the bullet frees itself.
@export var lifetime : float = 2.0
## Scaling factor applied to the impact scorch decal (smaller for pistol/standard rounds).
@export var decal_scale : float = 0.32
## Material used instead of the default when the player fired this bullet.
@export var player_material : Material
## Material used when this bullet rolled a lethal Critical Hit.
@export var crit_material : Material

## The node that fired this bullet; it is never damaged by it.
var shooter : Node3D
var direction : Vector3 = Vector3.FORWARD
## When true, deals lethal damage and triggers special critical visuals & audio.
var is_critical : bool = false

var _previous_position : Vector3
var _has_moved : bool = false

@onready var mesh_instance : MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	add_to_group("bullet")
	body_entered.connect(_on_body_entered)
	var tree : SceneTree = get_tree()
	if tree != null:
		tree.create_timer(lifetime).timeout.connect(queue_free)
	else:
		queue_free()
	if direction != Vector3.ZERO:
		var up_vec : Vector3 = Vector3.BACK if absf(direction.dot(Vector3.UP)) > 0.95 else Vector3.UP
		basis = Basis.looking_at(direction, up_vec)
	if is_critical and crit_material != null:
		mesh_instance.material_override = crit_material
		mesh_instance.scale = Vector3(1.35, 1.35, 1.35)
	elif is_instance_valid(shooter) and shooter.is_in_group("player"):
		mesh_instance.material_override = player_material

func _physics_process(delta: float) -> void:
	if is_queued_for_deletion():
		return
	if not _has_moved:
		_has_moved = true
		# Sweep the first step along the true 3D trajectory so thin walls right at muzzle are detected.
		_previous_position = global_position - direction * 0.2
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
			break
		var body : Node3D = hit.collider as Node3D
		if body != null and _is_ally(body):
			exclude.append(hit.rid)
			continue
		return hit

	# Secondary sweep check for jumping/airborne characters:
	# Zero-thickness rays can tunnel or miss a vaulting enemy by fractions of a centimeter.
	# Check whether the trajectory segment intersects the 3D volume of hostile characters.
	var character_hit := _check_character_sweep(from, to)
	if not character_hit.is_empty():
		return character_hit

	return {}

func _check_character_sweep(from: Vector3, to: Vector3) -> Dictionary:
	if get_tree() == null:
		return {}

	var is_player_shooter : bool = is_instance_valid(shooter) and (shooter.is_in_group("player") or shooter.is_in_group("turret"))
	var targets : Array[Node] = []
	if is_player_shooter or not is_instance_valid(shooter):
		targets = get_tree().get_nodes_in_group("enemy")
	else:
		var p : Node = get_tree().get_first_node_in_group("player")
		if p != null:
			targets.append(p)
		targets.append_array(get_tree().get_nodes_in_group("turret"))

	var seg_delta : Vector3 = to - from
	var seg_len_sq : float = seg_delta.length_squared()
	if seg_len_sq < 0.00001:
		return {}

	var best_hit : Dictionary = {}
	var best_dist_sq : float = INF

	for target in targets:
		if not is_instance_valid(target) or target == shooter or _is_ally(target as Node3D):
			continue
		var char_body : CharacterBody3D = target as CharacterBody3D
		if char_body == null or char_body.is_queued_for_deletion():
			continue

		var base_pos : Vector3 = char_body.global_position
		# Capsule covers vertical span with jump/air tolerance
		var min_y : float = base_pos.y - 0.15
		var max_y : float = base_pos.y + 0.85
		var hit_radius : float = 0.32

		var to_target_xz : Vector2 = Vector2(base_pos.x - from.x, base_pos.z - from.z)
		var seg_xz : Vector2 = Vector2(seg_delta.x, seg_delta.z)
		var seg_xz_len_sq : float = seg_xz.length_squared()

		var t : float = 0.0
		if seg_xz_len_sq > 0.0001:
			t = clampf(to_target_xz.dot(seg_xz) / seg_xz_len_sq, 0.0, 1.0)

		var closest_pt : Vector3 = from + seg_delta * t
		var horiz_dist_sq : float = Vector2(closest_pt.x - base_pos.x, closest_pt.z - base_pos.z).length_squared()

		if horiz_dist_sq <= hit_radius * hit_radius:
			if closest_pt.y >= min_y and closest_pt.y <= max_y:
				var dist_from_start : float = from.distance_squared_to(closest_pt)
				if dist_from_start < best_dist_sq:
					best_dist_sq = dist_from_start
					var hit_normal : Vector3 = (from - base_pos).normalized()
					hit_normal.y = 0.0
					if hit_normal.is_zero_approx():
						hit_normal = -direction
					best_hit = {
						"collider": char_body,
						"position": closest_pt,
						"normal": hit_normal.normalized(),
						"rid": char_body.get_rid()
					}

	return best_hit

func _on_body_entered(body: Node3D) -> void:
	if body == shooter or _is_ally(body):
		return
	_hit(body)

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

## Detects whether an impact point is at a sharp terrain cliff lip, edge drop-off,
## or degenerate corner seam where a decal would hang over empty air or clip awkwardly.
func _is_terrain_edge(space_state: PhysicsDirectSpaceState3D, hit_pos: Vector3, normal: Vector3, _collider: Node3D) -> bool:
	# Downward-facing normals on ground/terrain are inverted or degenerate underside hits
	if normal.y < -0.05:
		return true

	# Hits right at the outer perimeter boundaries of the map
	if absf(hit_pos.x) >= 38.5 or absf(hit_pos.z) >= 38.5:
		return true

	# Probe footprint around the scorch decal perimeter to detect cliff drop-offs
	if space_state != null:
		# Check if physics engine has this surface registered
		var center_query := PhysicsRayQueryParameters3D.create(hit_pos + normal * 0.06, hit_pos - normal * 0.18, collision_mask)
		if is_instance_valid(shooter) and (shooter is CollisionObject3D):
			center_query.exclude = [(shooter as CollisionObject3D).get_rid()]
		var center_res := space_state.intersect_ray(center_query)
		# If center probe succeeds, the collider is fully recognized in physics space; check perimeter
		if not center_res.is_empty():
			var basis_norm : Basis = _basis_from_up(normal)
			var right_vec : Vector3 = basis_norm.x.normalized()
			var fwd_vec : Vector3 = basis_norm.z.normalized()
			var probe_radius : float = 0.10

			for probe_dir in [right_vec, -right_vec, fwd_vec, -fwd_vec]:
				var probe_pos : Vector3 = hit_pos + probe_dir * probe_radius
				var probe_ray := PhysicsRayQueryParameters3D.create(probe_pos + normal * 0.06, probe_pos - normal * 0.18, collision_mask)
				if is_instance_valid(shooter) and (shooter is CollisionObject3D):
					probe_ray.exclude = [(shooter as CollisionObject3D).get_rid()]
				var res := space_state.intersect_ray(probe_ray)
				if res.is_empty():
					# Probe dropped into empty space / abyss beyond cliff edge
					return true
				var p_norm : Vector3 = res["normal"] as Vector3
				if p_norm.dot(normal) < 0.5:
					# Probe hit an acute perpendicular corner seam
					return true

	return false

func _hit(body: Node3D, normal: Vector3 = Vector3.ZERO) -> void:
	if is_queued_for_deletion():
		return

	# Determine character and vehicle identity BEFORE damaging health
	var is_character : bool = _is_character_target(body)
	var is_vehicle : bool = _is_vehicle_target(body)

	var hit_entity : bool = false
	var hc : HealthComponent = null
	if body != null:
		hc = body.get_node_or_null("HealthComponent") as HealthComponent
		if hc == null and body.get_parent() != null:
			hc = body.get_parent().get_node_or_null("HealthComponent") as HealthComponent

	if hc != null:
		hit_entity = true
		if not is_vehicle:
			is_character = true
		hc.decrease_health(damage)

	var snd : Node = get_node_or_null("/root/UiSound")
	if snd != null:
		if hit_entity:
			if is_critical and snd.has_method("play_crit"):
				snd.play_crit()
			elif snd.has_method("play_hit"):
				snd.play_hit()
		elif snd.has_method("play_impact"):
			snd.play_impact()

	# Only leave scorch decals when hitting environmental surfaces (walls, ground, rocks),
	# NEVER when bullets make contact with an enemy, the player, or the truck/vehicles,
	# and NEVER when hitting terrain edges or cliff drop-offs.
	if not is_character and not is_vehicle:
		var space_state : PhysicsDirectSpaceState3D = null
		if is_inside_tree():
			var w3d : World3D = get_world_3d()
			if w3d != null:
				space_state = w3d.direct_space_state

		# If normal is missing (e.g. from area collision callback), query world space to find true surface normal
		if normal.is_zero_approx() and space_state != null:
			var query := PhysicsRayQueryParameters3D.create(global_position - direction * 0.4, global_position + direction * 0.4, collision_mask)
			if is_instance_valid(shooter) and (shooter is CollisionObject3D):
				query.exclude = [(shooter as CollisionObject3D).get_rid()]
			var env_hit := space_state.intersect_ray(query)
			if not env_hit.is_empty() and not (env_hit["normal"] as Vector3).is_zero_approx():
				normal = env_hit["normal"]

		if not _is_terrain_edge(space_state, global_position, normal, body):
			_spawn_laser_burn(normal, body)

	_spawn_impact(normal)
	queue_free()

func _is_ally(body: Node3D) -> bool:
	if not is_instance_valid(shooter) or body == null:
		return false
	if shooter.is_in_group("enemy") and (body.is_in_group("enemy") or body.name.to_lower().contains("enemy")):
		return true
	var is_friendly_shooter : bool = (
		shooter.is_in_group("player")
		or shooter.is_in_group("turret")
		or shooter.is_in_group("vehicles")
		or shooter.is_in_group("vehicle")
		or (shooter is CharacterBody3D and (shooter.is_in_group("driving") or shooter.has_method("exit_vehicle")))
	)
	var is_friendly_body : bool = (
		body.is_in_group("player")
		or body.is_in_group("turret")
		or body.is_in_group("vehicles")
		or body.is_in_group("vehicle")
		or (body is CharacterBody3D and (body.is_in_group("driving") or body.has_method("exit_vehicle")))
		or body.name.to_lower().contains("player")
		or body.name.to_lower().contains("proto_controller")
		or body.name.to_lower().contains("turret")
		or body.name.to_lower().contains("rover")
		or body.name.to_lower().contains("truck")
	)
	if is_friendly_shooter and is_friendly_body:
		return true
	return false

func _spawn_impact(normal: Vector3) -> void:
	if normal.is_zero_approx():
		normal = -direction
	normal = normal.normalized()
	# Back-face ray hits return a normal along the shot; always spray back toward the shooter's side.
	if normal.dot(direction) > 0.0:
		normal = -normal
	var impact : Node3D = IMPACT_SCENE.instantiate()
	if "is_critical" in impact:
		impact.set("is_critical", is_critical)
	# Place it before it enters the tree so the world-space particles never emit from the origin.
	impact.top_level = true
	impact.transform = Transform3D(_basis_from_up(normal), global_position + normal * IMPACT_OFFSET)
	get_parent().add_child(impact)

func _spawn_laser_burn(normal: Vector3, hit_collider: Node3D = null) -> void:
	if normal.is_zero_approx():
		normal = -direction
	normal = normal.normalized()
	if normal.dot(direction) > 0.0:
		normal = -normal
	var parent_node : Node = get_parent()
	if parent_node == null:
		return
	var burn : Node3D = LASER_BURN_SCENE.instantiate()
	burn.top_level = true
	parent_node.add_child(burn)
	burn.global_position = global_position + normal * BURN_OFFSET
	if burn.has_method("setup_impact"):
		burn.call("setup_impact", normal, direction, hit_collider, is_critical, decal_scale)
	else:
		burn.transform = Transform3D(_basis_from_up(normal), global_position + normal * BURN_OFFSET)
		var s : float = (1.4 if is_critical else 1.0) * decal_scale
		burn.scale = Vector3(s, s, s)

## Basis whose Y axis points along up; Quaternion(UP, -UP) degenerates to identity.
func _basis_from_up(up: Vector3) -> Basis:
	if up.dot(Vector3.UP) < -0.999:
		return Basis(Vector3.RIGHT, PI)
	return Basis(Quaternion(Vector3.UP, up))
