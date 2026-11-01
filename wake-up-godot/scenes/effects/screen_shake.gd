extends Node

## Screen shake autoload system for concussive explosions, vehicle impacts, and heavy weapons.
## Uses Camera3D h_offset, v_offset, and rotation for zero transform drift.

var trauma : float = 0.0
const TRAUMA_DECAY : float = 1.65
const MAX_OFFSET : float = 0.42
const MAX_ROTATION : float = deg_to_rad(2.2)

var _noise_time : float = 0.0
var _camera_ref : WeakRef = null
var _base_rotation_z : float = 0.0
var _has_base_rotation : bool = false

func _process(delta: float) -> void:
	if trauma <= 0.0:
		_reset_camera()
		return

	trauma = maxf(trauma - TRAUMA_DECAY * delta, 0.0)
	var shake_intensity : float = trauma * trauma
	_noise_time += delta * 45.0

	var camera : Camera3D = _get_camera()
	if camera == null:
		return

	if not _has_base_rotation:
		_base_rotation_z = camera.rotation.z
		_has_base_rotation = true

	# Concussive high-frequency screen shake offsets
	var offset_x : float = sin(_noise_time * 1.3) * MAX_OFFSET * shake_intensity + (randf() * 2.0 - 1.0) * 0.04 * shake_intensity
	var offset_y : float = cos(_noise_time * 1.7) * MAX_OFFSET * shake_intensity + (randf() * 2.0 - 1.0) * 0.04 * shake_intensity
	var roll : float = sin(_noise_time * 1.1) * MAX_ROTATION * shake_intensity

	camera.h_offset = offset_x
	camera.v_offset = offset_y
	camera.rotation.z = _base_rotation_z + roll

func _reset_camera() -> void:
	var camera : Camera3D = _get_camera()
	if camera != null:
		camera.h_offset = 0.0
		camera.v_offset = 0.0
		if _has_base_rotation:
			camera.rotation.z = _base_rotation_z
			_has_base_rotation = false

func _get_camera() -> Camera3D:
	var cached : Camera3D = _camera_ref.get_ref() as Camera3D if _camera_ref != null else null
	if is_instance_valid(cached) and cached.is_inside_tree():
		return cached

	var tree : SceneTree = get_tree()
	if tree != null:
		var cams : Array[Node] = tree.get_nodes_in_group("camera")
		for c in cams:
			if c is Camera3D:
				_camera_ref = weakref(c)
				return c as Camera3D
		var found : Node = tree.root.find_child("Camera3D", true, false)
		if found is Camera3D:
			_camera_ref = weakref(found)
			return found as Camera3D

	var vp : Viewport = get_viewport()
	if vp != null:
		var cam : Camera3D = vp.get_camera_3d()
		if cam != null:
			_camera_ref = weakref(cam)
			return cam
	return null

## Adds screen shake trauma (clamped 0.0 to 1.0).
func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)

## Triggers screen shake with specified intensity.
func shake(amount: float = 0.5) -> void:
	add_trauma(amount)
