class_name TutorialWaypoint
extends Area3D

## Holographic 3D Waypoint Beacon for the guided tutorial.
## Features rotating beacon icon, pulsing ground pad, light beam, and proximity trigger.

signal reached(waypoint_id: String)

@export var waypoint_id : String = "checkpoint"
@export var is_active : bool = false:
	set(val):
		is_active = val
		_update_visibility()
@export var beacon_color : Color = Color(0.2, 0.8, 1.0)
@export var triggered_once : bool = true

var _triggered : bool = false
var _time : float = 0.0

@onready var beacon_mesh : Node3D = $BeaconIcon
@onready var ground_ring : MeshInstance3D = $GroundRing
@onready var light_beam : MeshInstance3D = $LightBeam
@onready var collision_shape : CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	add_to_group("waypoint")
	body_entered.connect(_on_body_entered)
	_setup_materials()
	_update_visibility()

func _setup_materials() -> void:
	if ground_ring != null:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = beacon_color
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = 0.75
		ground_ring.material_override = mat

	if light_beam != null:
		var beam_mat := StandardMaterial3D.new()
		beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		beam_mat.albedo_color = Color(beacon_color.r, beacon_color.g, beacon_color.b, 0.38)
		beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		light_beam.material_override = beam_mat

func _process(delta: float) -> void:
	if not is_active:
		return
	_time += delta
	var pulse : float = (sin(_time * 3.6) + 1.0) * 0.5
	if light_beam != null and light_beam.material_override is StandardMaterial3D:
		(light_beam.material_override as StandardMaterial3D).albedo_color.a = 0.25 + 0.25 * pulse
	if beacon_mesh != null:
		beacon_mesh.rotate_y(2.2 * delta)
		beacon_mesh.position.y = 1.4 + sin(_time * 3.0) * 0.22
		beacon_mesh.scale = Vector3.ONE * (1.0 + 0.12 * pulse)

func _update_visibility() -> void:
	visible = is_active
	if collision_shape != null:
		collision_shape.disabled = not is_active

func _on_body_entered(body: Node3D) -> void:
	if not is_active or (_triggered and triggered_once):
		return
	var is_player : bool = body.is_in_group("player") or body.is_in_group("vehicle")
	if is_player:
		if triggered_once:
			_triggered = true
		_play_reached_effect()
		reached.emit(waypoint_id)

func _play_reached_effect() -> void:
	var snd : Node = get_node_or_null("/root/UiSound")
	if snd != null:
		if snd.has_method("play_waypoint_reached"):
			snd.call("play_waypoint_reached")
		elif snd.has_method("play_tab"):
			snd.call("play_tab")

	# Expanding burst ring tween
	if ground_ring != null:
		var tween := create_tween()
		tween.tween_property(ground_ring, "scale", Vector3(1.8, 1.0, 1.8), 0.25)
		tween.parallel().tween_property(ground_ring.material_override, "albedo_color:a", 0.0, 0.25)
		tween.tween_callback(func():
			ground_ring.scale = Vector3.ONE
			if ground_ring.material_override is StandardMaterial3D:
				(ground_ring.material_override as StandardMaterial3D).albedo_color.a = 0.75
		)

func activate(play_sound: bool = false) -> void:
	_triggered = false
	is_active = true
	_update_visibility()
	if play_sound:
		var snd : Node = get_node_or_null("/root/UiSound")
		if snd != null and snd.has_method("play_waypoint_activate"):
			snd.call("play_waypoint_activate")

func deactivate() -> void:
	is_active = false
	_update_visibility()
