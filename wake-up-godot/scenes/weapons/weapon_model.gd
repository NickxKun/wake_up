class_name WeaponModel
extends Node3D

## Base class for custom 3D sci-fi weapon models.
## Provides standardized muzzle tracking, recoil kick animation, and particle flash effects.

@export var kick_distance : float = 0.025
@export var kick_duration : float = 0.10

const DEFAULT_CYAN_COLOR : Color = Color(0.3, 0.9, 1.0, 1.0)
## High-visibility energetic yellow/gold glow for critical rounds
const CRIT_YELLOW_COLOR : Color = Color(1.0, 0.90, 0.12, 1.0)

var is_crit_loaded : bool = false
var _kick_tween : Tween = null
var _original_z : float = 0.0
var _conduit_meshes : Array[MeshInstance3D] = []
var _default_colors : Array[Color] = []
var _glow_tween : Tween = null

@onready var muzzle : Marker3D = get_node_or_null("Muzzle") as Marker3D
@onready var flash_particles : CPUParticles3D = get_node_or_null("Muzzle/Flash") as CPUParticles3D
@onready var sparks_particles : CPUParticles3D = get_node_or_null("Muzzle/Sparks") as CPUParticles3D

@onready var muzzle_l : Marker3D = get_node_or_null("MuzzleL") as Marker3D
@onready var flash_l : CPUParticles3D = get_node_or_null("MuzzleL/Flash") as CPUParticles3D
@onready var sparks_l : CPUParticles3D = get_node_or_null("MuzzleL/Sparks") as CPUParticles3D

func _ready() -> void:
	_original_z = position.z
	_collect_conduit_meshes()

func _collect_conduit_meshes() -> void:
	_conduit_meshes.clear()
	_default_colors.clear()
	for child in find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		var mname : String = mi.name.to_lower()
		if mname.contains("flash") or mname.contains("spark"):
			continue
		var cur_mat := mi.get_active_material(0) as StandardMaterial3D
		var is_unshaded : bool = cur_mat != null and cur_mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED
		if mname.contains("conduit") or mname.contains("glow") or mname.contains("core") or mname.contains("lens") or mname.contains("shield") or is_unshaded:
			_conduit_meshes.append(mi)
			var base_col : Color = cur_mat.albedo_color if cur_mat != null else DEFAULT_CYAN_COLOR
			_default_colors.append(base_col)

## Sets the weapon's conduit glow: glowing electric yellow when a critical bullet is chambered,
## or standard cyan/weapon color when normal.
func set_critical_glow(is_crit: bool, animate: bool = true) -> void:
	is_crit_loaded = is_crit
	if _conduit_meshes.is_empty():
		_collect_conduit_meshes()
	if _conduit_meshes.is_empty():
		return

	if _glow_tween != null and _glow_tween.is_valid():
		_glow_tween.kill()
		_glow_tween = null

	var tween : Tween = null
	if animate and is_inside_tree():
		tween = create_tween()
		_glow_tween = tween

	for i in range(_conduit_meshes.size()):
		var mi : MeshInstance3D = _conduit_meshes[i]
		var def_col : Color = _default_colors[i] if i < _default_colors.size() else DEFAULT_CYAN_COLOR
		var target_col : Color = CRIT_YELLOW_COLOR if is_crit else def_col

		var mat : StandardMaterial3D = mi.material_override as StandardMaterial3D
		if mat == null:
			var active_mat : StandardMaterial3D = mi.get_active_material(0) as StandardMaterial3D
			mat = (active_mat.duplicate() if active_mat != null else StandardMaterial3D.new()) as StandardMaterial3D
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mi.material_override = mat

		if tween != null:
			tween.parallel().tween_property(mat, "albedo_color", target_col, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		else:
			mat.albedo_color = target_col

## Fires muzzle flash and plays mechanical slide/recoil kick.
func play_shot(muzzle_index: int = 0) -> void:
	flash(muzzle_index)

	if _kick_tween != null and _kick_tween.is_valid():
		_kick_tween.kill()
	position.z = _original_z + kick_distance
	_kick_tween = create_tween()
	_kick_tween.tween_property(self, "position:z", _original_z, kick_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func flash(muzzle_index: int = 0) -> void:
	if muzzle_index == 1 and muzzle_l != null:
		if flash_l != null:
			flash_l.restart()
		if sparks_l != null:
			sparks_l.restart()
	else:
		if flash_particles != null:
			flash_particles.restart()
		if sparks_particles != null:
			sparks_particles.restart()
		# For double pistols, fire both muzzles if both exist and no specific muzzle was targeted
		if muzzle_l != null and muzzle_index == 0:
			if flash_l != null:
				flash_l.restart()
			if sparks_l != null:
				sparks_l.restart()

func get_muzzle_global_position(muzzle_index: int = 0) -> Vector3:
	if muzzle_index == 1 and muzzle_l != null:
		return muzzle_l.global_position
	if muzzle != null:
		return muzzle.global_position
	return global_position
