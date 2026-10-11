extends Node3D

## One-shot spark burst and flash where a bullet hit. Frees itself when done.

## Seconds before the effect frees itself; longer than the longest particle lifetime.
const LIFETIME : float = 0.5

@onready var sparks : CPUParticles3D = $Sparks
@onready var flash : CPUParticles3D = $Flash

func _ready() -> void:
	sparks.emitting = true
	flash.emitting = true
	get_tree().create_timer(LIFETIME).timeout.connect(queue_free)
