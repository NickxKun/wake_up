class_name Gun
extends Node3D

## Simple primitive gun. Plays a muzzle flash and slides back along its barrel when fired.

## Metres the gun slides back along its barrel on each shot.
@export var kick_distance : float = 0.03
## Seconds the gun takes to return after a kick.
@export var kick_duration : float = 0.12

var _kick_tween : Tween

@onready var pivot : Node3D = $Pivot
@onready var muzzle : Marker3D = $Pivot/Muzzle
@onready var flash : CPUParticles3D = $Pivot/Muzzle/Flash
@onready var sparks : CPUParticles3D = $Pivot/Muzzle/Sparks

## Kicks the gun back and restarts the muzzle flash.
func play_shot() -> void:
	flash.restart()
	sparks.restart()
	if _kick_tween != null:
		_kick_tween.kill()
	pivot.position.z = kick_distance
	_kick_tween = create_tween()
	_kick_tween.tween_property(pivot, "position:z", 0.0, kick_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
