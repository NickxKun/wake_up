class_name TrainingTarget
extends StaticBody3D

## Reactive marksmanship target for the tutorial proving grounds.
## Features health component, hit reaction wobble, emissive pulse, and destruction particles.

signal target_destroyed(target: TrainingTarget)

@export var initial_health : int = 50
@export var target_color : Color = Color(0.18, 0.72, 1.0) # Cyber cyan

var _is_destroyed : bool = false
var _initial_transform : Transform3D
var _wobble_tween : Tween = null
var _fold_tween : Tween = null

@onready var health_component : HealthComponent = $HealthComponent
@onready var model : Node3D = $TargetModel
@onready var mesh_instance : MeshInstance3D = $TargetModel/Stand/FaceMesh
@onready var collision_shape : CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	add_to_group("target")
	_initial_transform = transform
	if health_component != null:
		health_component.health = initial_health
		health_component.health_changed.connect(_on_health_changed)
		health_component.health_depleted.connect(_on_health_depleted)
	_setup_materials()

func take_damage(amount: int) -> int:
	if _is_destroyed or health_component == null:
		return 0
	return health_component.decrease_health(amount)

func _setup_materials() -> void:
	if mesh_instance != null:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.12, 0.14, 0.18)
		mat.emission_enabled = true
		mat.emission = target_color
		mat.emission_energy_multiplier = 1.8
		mat.roughness = 0.3
		mesh_instance.material_override = mat

func _on_health_changed(_current: int, _old_h: int) -> void:
	if _is_destroyed or (health_component != null and health_component.is_dead()):
		return
	_play_hit_reaction()

func _play_hit_reaction() -> void:
	if model == null or _is_destroyed:
		return
	# Audio hit feedback
	var snd : Node = get_node_or_null("/root/UiSound")
	if snd != null and snd.has_method("play_hit"):
		snd.play_hit()

	if _wobble_tween != null and _wobble_tween.is_valid():
		_wobble_tween.kill()

	# Mechanical target wobble tween
	_wobble_tween = create_tween()
	_wobble_tween.tween_property(model, "rotation_degrees:x", -22.0, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_wobble_tween.tween_property(model, "rotation_degrees:x", 12.0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_wobble_tween.tween_property(model, "rotation_degrees:x", -5.0, 0.06).set_trans(Tween.TRANS_QUAD)
	_wobble_tween.tween_property(model, "rotation_degrees:x", 0.0, 0.06).set_trans(Tween.TRANS_QUAD)

	# Emissive flash
	if mesh_instance != null and mesh_instance.material_override is StandardMaterial3D:
		var mat := mesh_instance.material_override as StandardMaterial3D
		var flash_tween := create_tween()
		mat.emission = Color(1.0, 0.95, 0.6)
		mat.emission_energy_multiplier = 4.0
		flash_tween.tween_property(mat, "emission", target_color, 0.2)
		flash_tween.parallel().tween_property(mat, "emission_energy_multiplier", 1.8, 0.2)

func _on_health_depleted() -> void:
	if _is_destroyed:
		return
	_is_destroyed = true
	target_destroyed.emit(self)

	# Immediately kill any wobble or previous fold tweens
	if _wobble_tween != null and _wobble_tween.is_valid():
		_wobble_tween.kill()
	if _fold_tween != null and _fold_tween.is_valid():
		_fold_tween.kill()

	# Disable collision immediately so no more bullets register
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)

	_spawn_destruction_particles()

	# Extinguish emissive illumination and dim albedo
	if mesh_instance != null and mesh_instance.material_override is StandardMaterial3D:
		var mat := mesh_instance.material_override as StandardMaterial3D
		mat.emission_enabled = false
		mat.albedo_color = Color(0.1, 0.12, 0.15)

	# Fold down flat onto the floor and sink down so it stays down
	if model != null:
		_fold_tween = create_tween().set_parallel(true)
		_fold_tween.tween_property(model, "rotation_degrees:x", -90.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_fold_tween.tween_property(model, "position:y", -0.2, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _spawn_destruction_particles() -> void:
	var p := CPUParticles3D.new()
	p.top_level = true
	get_parent().add_child(p)
	p.global_position = global_position + Vector3(0.0, 0.8, 0.0)
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.9
	p.lifetime = 0.5
	p.amount = 24

	var box := BoxMesh.new()
	box.size = Vector3(0.06, 0.06, 0.06)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = target_color
	box.material = mat
	p.mesh = box

	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.5
	p.gravity = Vector3(0.0, -8.0, 0.0)

	p.emitting = true
	var tree : SceneTree = get_tree()
	if tree != null:
		tree.create_timer(0.6).timeout.connect(p.queue_free)
	else:
		p.queue_free()

func reset_target() -> void:
	if _wobble_tween != null and _wobble_tween.is_valid():
		_wobble_tween.kill()
	if _fold_tween != null and _fold_tween.is_valid():
		_fold_tween.kill()

	_is_destroyed = false
	if collision_shape != null:
		collision_shape.disabled = false
	if health_component != null:
		health_component.health = initial_health
	if model != null:
		model.rotation_degrees = Vector3.ZERO
		model.position = Vector3.ZERO
	_setup_materials()
