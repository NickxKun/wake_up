class_name LaserBurn
extends Node3D

## Procedural impact scorch decal:
## - Aligns cleanly along the surface normal (perpendicular to contact surface)
## - Uniform circular sizing with ZERO odd angular stretching, irrespective of trajectory angle
## - Adapts material color, cool-down, and charred soot to the hit surface (Metal, Ground, Stone)

enum SurfaceType {
	GROUND,
	METAL,
	STONE
}

@export var lifetime : float = 4.0
@onready var mesh_instance : MeshInstance3D = $MeshInstance3D

var surface_type : int = SurfaceType.GROUND
var is_critical : bool = false
var decal_scale : float = 1.0
var _fade_started : bool = false

func _ready() -> void:
	if mesh_instance == null:
		return
	# Wait a frame if setup_impact hasn't arrived yet
	if not _fade_started:
		call_deferred("_ensure_fading")

func _ensure_fading() -> void:
	if not _fade_started and is_inside_tree():
		_apply_surface_and_fade()

## Configures the scorch mark decal purely along the surface normal.
## Irrespective of hit angle, the impact is placed along the contact normal with uniform circular sizing.
## custom_scale fine-tunes decal dimensions (e.g. realistic ~0.14m bullet hole for pistol).
func setup_impact(normal: Vector3, _shot_dir: Vector3 = Vector3.ZERO, hit_collider: Node3D = null, crit: bool = false, custom_scale: float = 1.0) -> void:
	is_critical = crit
	decal_scale = custom_scale
	surface_type = _detect_surface_type(hit_collider, normal)

	if normal.is_zero_approx():
		normal = Vector3.UP
	normal = normal.normalized()

	# Align decal basis so local Y is aligned along surface normal (perpendicular to contact plane)
	var up_basis : Basis = _get_basis_from_normal(normal)
	basis = up_basis

	if mesh_instance == null:
		mesh_instance = get_node_or_null("MeshInstance3D") as MeshInstance3D

	var size_mult : float = (1.35 if is_critical else 1.0) * decal_scale
	if mesh_instance != null:
		mesh_instance.scale = Vector3(size_mult, 1.0, size_mult)

	if is_inside_tree():
		_apply_surface_and_fade()

func _get_basis_from_normal(up: Vector3) -> Basis:
	if up.dot(Vector3.UP) < -0.999:
		return Basis(Vector3.RIGHT, PI)
	return Basis(Quaternion(Vector3.UP, up))

func _detect_surface_type(collider: Node3D, normal: Vector3) -> int:
	if collider == null:
		return SurfaceType.GROUND if absf(normal.dot(Vector3.UP)) > 0.7 else SurfaceType.METAL

	var c_name : String = collider.name.to_lower()
	var p_name : String = collider.get_parent().name.to_lower() if collider.get_parent() != null else ""

	# Vehicles & Armor
	if collider.is_in_group("vehicles") or c_name.contains("rover") or p_name.contains("rover") or c_name.contains("car"):
		return SurfaceType.METAL

	# Metal structures, station walls, pillars, containers, doors, tech
	if c_name.contains("wall") or c_name.contains("pillar") or c_name.contains("metal") or c_name.contains("station") or c_name.contains("cover") or c_name.contains("dock") or c_name.contains("container") or c_name.contains("hub"):
		return SurfaceType.METAL

	# Concrete, stone, rocks
	if c_name.contains("stone") or c_name.contains("concrete") or c_name.contains("rock") or c_name.contains("boulder"):
		return SurfaceType.STONE

	# Ground, sand, dirt, terrain, canyon
	if c_name.contains("ground") or c_name.contains("floor") or c_name.contains("sand") or c_name.contains("canyon") or c_name.contains("terrain") or collider.is_in_group("navigation_geometry"):
		return SurfaceType.GROUND

	# Fallback
	return SurfaceType.GROUND if absf(normal.dot(Vector3.UP)) > 0.6 else SurfaceType.METAL

func _apply_surface_and_fade() -> void:
	if mesh_instance == null:
		mesh_instance = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh_instance == null or _fade_started:
		return
	_fade_started = true

	var size_mult : float = (1.35 if is_critical else 1.0) * decal_scale
	mesh_instance.scale = Vector3(size_mult, 1.0, size_mult)

	var base_mat : Material = mesh_instance.get_active_material(0)
	if not (base_mat is StandardMaterial3D):
		var tree : SceneTree = get_tree()
		if tree != null:
			tree.create_timer(lifetime).timeout.connect(queue_free)
		else:
			queue_free()
		return

	var mat : StandardMaterial3D = base_mat.duplicate() as StandardMaterial3D
	mat.render_priority = 3
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_instance.material_override = mat

	# Color palettes tailored per surface material
	var initial_heat_color : Color
	var charred_soot_color : Color
	var cool_time : float = 1.0

	match surface_type:
		SurfaceType.METAL:
			initial_heat_color = Color(1.0, 0.82, 0.45, 1.0)
			charred_soot_color = Color(0.12, 0.13, 0.16, 0.88)
			cool_time = 0.8
		SurfaceType.STONE:
			initial_heat_color = Color(0.92, 0.78, 0.60, 1.0)
			charred_soot_color = Color(0.22, 0.22, 0.25, 0.80)
			cool_time = 0.9
		_: # SurfaceType.GROUND
			initial_heat_color = Color(0.95, 0.62, 0.30, 0.98)
			charred_soot_color = Color(0.18, 0.13, 0.09, 0.82)
			cool_time = 1.2

	mat.albedo_color = initial_heat_color

	var tween : Tween = create_tween()
	# 1. Cool down from incandescent heat to charred residue
	tween.tween_property(mat, "albedo_color", charred_soot_color, cool_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 2. Fade alpha smoothly into background
	var fade_time : float = maxf(lifetime - cool_time, 0.5)
	tween.tween_property(mat, "albedo_color:a", 0.0, fade_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)
