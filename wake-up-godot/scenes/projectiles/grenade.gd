class_name Grenade
extends Area3D

## High-explosive fragmentation grenade projectile.
## Features ballistic arc trajectory, geometry bounce physics, blinking fuse LED,
## AoE blast damage, and explosive knockback.

const MAX_SWEEP_SKIPS : int = 4
const EXPLOSION_SCENE : PackedScene = preload("res://scenes/projectiles/explosion_effect.tscn")
const IMPACT_SCENE : PackedScene = preload("res://scenes/projectiles/bullet_impact.tscn")
const LASER_BURN_SCENE : PackedScene = preload("res://scenes/projectiles/laser_burn.tscn")
const GRENADE_INDICATOR_SCENE : PackedScene = preload("res://scenes/ui/grenade_indicator.tscn")

@export var damage : int = 120
@export var explosion_radius : float = 4.0
@export var knockback_force : float = 8.5
@export var fuse_time : float = 1.4
@export var fall_gravity : float = 18.0
@export var bounce_factor : float = 0.52
@export var friction : float = 0.85

var shooter : Node3D = null
var velocity : Vector3 = Vector3.ZERO
var _fuse_remaining : float = 1.4
var _previous_position : Vector3
var _has_moved : bool = false
var _detonated : bool = false
var _blink_timer : float = 0.0
var _tick_timer : float = 0.0

var _indicator_instance : CanvasLayer = null
var _ground_blast_ring : MeshInstance3D = null
var _floating_beacon : Node3D = null

@onready var grenade_mesh : Node3D = get_node_or_null("GrenadeMesh") as Node3D
@onready var fuse_light : OmniLight3D = get_node_or_null("FuseLight") as OmniLight3D

func _ready() -> void:
	_fuse_remaining = fuse_time
	_previous_position = global_position
	body_entered.connect(_on_body_entered)

	# 1. Spawn Waypoint-Style Grenade Warning Indicator in HUD
	var tree : SceneTree = get_tree()
	if tree != null and tree.root != null:
		var indicator : CanvasLayer = GRENADE_INDICATOR_SCENE.instantiate() as CanvasLayer
		if indicator != null:
			indicator.call("setup", self, shooter)
			tree.root.add_child(indicator)
			_indicator_instance = indicator

	# 2. Build In-World 3D Blast Hazard Zone Ring (matching explosion_radius)
	_setup_in_world_hazard_indicators()

func _setup_in_world_hazard_indicators() -> void:
	# Ground Blast Zone Perimeter Ring
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = explosion_radius - 0.08
	ring_mesh.outer_radius = explosion_radius
	ring_mesh.rings = 36
	ring_mesh.ring_segments = 4

	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color(1.0, 0.22, 0.12, 0.45)
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	_ground_blast_ring = MeshInstance3D.new()
	_ground_blast_ring.name = "GroundBlastRing"
	_ground_blast_ring.mesh = ring_mesh
	_ground_blast_ring.material_override = ring_mat
	_ground_blast_ring.top_level = true # Independent world transform to stay flat on floor!
	add_child(_ground_blast_ring)

	# Floating 3D Warning Beacon
	_floating_beacon = Node3D.new()
	_floating_beacon.name = "FloatingWarningBeacon"
	_floating_beacon.top_level = true

	# Warning diamond
	var beacon_mesh := MeshInstance3D.new()
	var prism := BoxMesh.new()
	prism.size = Vector3(0.18, 0.18, 0.04)
	beacon_mesh.mesh = prism

	var b_mat := StandardMaterial3D.new()
	b_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	b_mat.albedo_color = Color(1.0, 0.25, 0.12, 0.95)
	beacon_mesh.material_override = b_mat
	beacon_mesh.rotation_degrees.z = 45.0 # Diamond orientation!
	_floating_beacon.add_child(beacon_mesh)
	add_child(_floating_beacon)

func _physics_process(delta: float) -> void:
	if _detonated or is_queued_for_deletion():
		return

	# Blink fuse LED with accelerating pulse as detonation nears
	_blink_timer += delta
	var blink_interval : float = 0.25 if _fuse_remaining > 0.6 else 0.10
	if fuse_light != null:
		fuse_light.visible = fmod(_blink_timer, blink_interval * 2.0) < blink_interval

	# Audio warning tick accelerating as detonation nears
	_tick_timer -= delta
	var tick_interval : float = lerpf(0.08, 0.32, clampf(_fuse_remaining / fuse_time, 0.0, 1.0))
	if _tick_timer <= 0.0:
		_tick_timer = tick_interval
		var snd : Node = get_node_or_null("/root/UiSound")
		if snd != null and snd.has_method("play_warning_tick"):
			snd.call("play_warning_tick", 0.02)

	# Update In-World Ground Hazard Ring position on floor under grenade
	if _ground_blast_ring != null and is_instance_valid(_ground_blast_ring):
		_ground_blast_ring.global_position = Vector3(global_position.x, 0.03, global_position.z)
		var fuse_ratio : float = clampf(_fuse_remaining / fuse_time, 0.0, 1.0)
		var ring_pulse : float = sin(_blink_timer * lerpf(24.0, 8.0, fuse_ratio)) * 0.2 + 0.8
		var mat : StandardMaterial3D = _ground_blast_ring.material_override as StandardMaterial3D
		if mat != null:
			mat.albedo_color.a = (0.35 + 0.35 * (1.0 - fuse_ratio)) * ring_pulse

	# Update Floating Warning Beacon hovering above grenade
	if _floating_beacon != null and is_instance_valid(_floating_beacon):
		_floating_beacon.global_position = global_position + Vector3(0.0, 0.45 + sin(_blink_timer * 6.0) * 0.05, 0.0)
		_floating_beacon.rotation.y += 3.5 * delta

	# Fuse countdown
	_fuse_remaining -= delta
	if _fuse_remaining <= 0.0:
		detonate(null, Vector3.UP)
		return

	# Ballistic movement with gravity
	velocity += Vector3.DOWN * fall_gravity * delta
	var from_pos : Vector3 = global_position
	var to_pos : Vector3 = from_pos + velocity * delta

	# Tumbling rotation
	if grenade_mesh != null:
		grenade_mesh.rotate_x(velocity.length() * delta * 0.8)
		grenade_mesh.rotate_z(velocity.length() * delta * 0.4)

	# Raycast sweep for collisions
	var hit : Dictionary = _sweep(from_pos, to_pos)
	if not hit.is_empty():
		var col : Node = hit.collider as Node
		# Direct hit on hostile enemy explodes instantly
		if col != null and (col.is_in_group("enemy") or col.name.to_lower().contains("enemy")):
			global_position = hit.position
			detonate(col as Node3D, hit.normal)
			return

		# Bounce off surfaces
		global_position = hit.position + hit.normal * 0.08
		velocity = velocity.bounce(hit.normal) * bounce_factor
		velocity.x *= friction
		velocity.z *= friction

		var snd : Node = get_node_or_null("/root/UiSound")
		if snd != null and snd.has_method("play_impact"):
			snd.play_impact()
	else:
		global_position = to_pos

	_previous_position = global_position

func _sweep(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask)
	var exclude : Array[RID] = []
	if is_instance_valid(shooter) and shooter is CollisionObject3D:
		exclude.append((shooter as CollisionObject3D).get_rid())
	var space_state := get_world_3d().direct_space_state
	if space_state == null:
		return {}

	for _i in MAX_SWEEP_SKIPS:
		query.exclude = exclude
		var result := space_state.intersect_ray(query)
		if result.is_empty():
			return {}
		var hit_collider : Node = result.collider as Node
		if hit_collider == shooter:
			if hit_collider is CollisionObject3D:
				exclude.append(hit_collider.get_rid())
			continue
		return result
	return {}

func _on_body_entered(body: Node3D) -> void:
	if _detonated or body == shooter:
		return
	if body.is_in_group("enemy") or body.name.to_lower().contains("enemy"):
		detonate(body, Vector3.UP)

func detonate(direct_target: Node3D = null, impact_normal: Vector3 = Vector3.UP) -> void:
	if _detonated:
		return
	_detonated = true

	# Clean up in-world hazard indicators
	if _ground_blast_ring != null and is_instance_valid(_ground_blast_ring):
		_ground_blast_ring.queue_free()
		_ground_blast_ring = null
	if _floating_beacon != null and is_instance_valid(_floating_beacon):
		_floating_beacon.queue_free()
		_floating_beacon = null
	if _indicator_instance != null and is_instance_valid(_indicator_instance):
		_indicator_instance.call("_start_fade_out", 0.05)

	var explosion_pos : Vector3 = global_position

	# 1. Spawn Visual & Audio FX
	var parent_node : Node = get_parent()
	if parent_node == null and is_inside_tree():
		parent_node = get_tree().root

	if parent_node != null and EXPLOSION_SCENE != null:
		var effect : Node3D = EXPLOSION_SCENE.instantiate() as Node3D
		parent_node.add_child(effect)
		effect.global_position = explosion_pos

	var snd : Node = get_node_or_null("/root/UiSound")
	if snd != null and snd.has_method("play_explosion"):
		snd.play_explosion()
	elif snd != null and snd.has_method("play_hazard_pulse"):
		snd.play_hazard_pulse()

	# 2. Direct Target Damage
	if direct_target != null:
		var direct_hc : HealthComponent = direct_target.get_node_or_null("HealthComponent") as HealthComponent
		if direct_hc == null and direct_target.get_parent() != null:
			direct_hc = direct_target.get_parent().get_node_or_null("HealthComponent") as HealthComponent
		if direct_hc != null:
			direct_hc.decrease_health(damage)

	# 3. Splash Area-of-Effect Damage & Knockback
	_apply_splash_damage(explosion_pos)

	queue_free()

func _apply_splash_damage(epicenter: Vector3) -> void:
	var space_state := get_world_3d().direct_space_state
	if space_state == null:
		return

	var sphere := SphereShape3D.new()
	sphere.radius = explosion_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, epicenter)
	query.collision_mask = 2 | 4 # Enemies and Vehicles

	var results := space_state.intersect_shape(query, 32)
	var damaged_entities : Array[Node] = []

	for hit in results:
		var collider : Node = hit.collider as Node
		if collider == null or collider == shooter:
			continue

		var entity_root : Node = collider
		while entity_root.get_parent() != null and not entity_root.is_in_group("enemy") and not entity_root.is_in_group("drivable"):
			entity_root = entity_root.get_parent()

		if damaged_entities.has(entity_root):
			continue
		damaged_entities.append(entity_root)

		var hc : HealthComponent = collider.get_node_or_null("HealthComponent") as HealthComponent
		if hc == null:
			hc = entity_root.get_node_or_null("HealthComponent") as HealthComponent

		if hc != null:
			var dist : float = epicenter.distance_to(collider.global_position)
			var falloff : float = clampf(1.0 - (dist / explosion_radius), 0.35, 1.0)
			var splash_dmg : int = int(float(damage) * falloff)
			hc.decrease_health(splash_dmg)

		# Apply physics knockback impulse
		if collider is CharacterBody3D:
			var kb_dir : Vector3 = (collider.global_position - epicenter).normalized()
			kb_dir.y = maxf(kb_dir.y, 0.35)
			(collider as CharacterBody3D).velocity += kb_dir * knockback_force
