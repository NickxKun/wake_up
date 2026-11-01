extends Node3D

## One-shot spark burst and flash where a bullet hit. Frees itself when done.

## Seconds before the effect frees itself; longer than the longest particle lifetime.
const LIFETIME : float = 0.5

var is_critical : bool = false

@onready var sparks : CPUParticles3D = $Sparks
@onready var flash : CPUParticles3D = $Flash

func _ready() -> void:
	if is_critical:
		sparks.amount = 24
		sparks.initial_velocity_max = 5.0
		flash.scale = Vector3(2.0, 2.0, 2.0)
	sparks.emitting = true
	flash.emitting = true
	var tree : SceneTree = get_tree()
	if tree != null:
		tree.create_timer(LIFETIME).timeout.connect(queue_free)
	else:
		queue_free()
