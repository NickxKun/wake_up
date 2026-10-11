extends Node

## Child of a character body (player or enemy). Procedural animation written to the model's Skeleton3D each frame:
## walk cycle, right arm aiming a gun, shot recoil, and jump / landing poses.

const ANIMATED_BONES : Array[String] = ["Pelvis", "Spine1", "Spine2", "UpperLeg.L", "UpperLeg.R", "LowerLeg.L", "LowerLeg.R", "UpperArm.L", "UpperArm.R", "Hand.R"]
## Air leg angles (upper, lower) around bone X: + swings the thigh forward, - bends the knee back.
const TUCK_L : Vector2 = Vector2(0.9, -1.4)
const TUCK_R : Vector2 = Vector2(0.6, -1.0)
const EXTEND_L : Vector2 = Vector2(0.25, -0.35)
const EXTEND_R : Vector2 = Vector2(0.1, -0.2)
## Landing squash at full weight: (upper, lower) leg angles, and Spine1 forward lean.
const LAND_LEG : Vector2 = Vector2(0.5, -1.0)
const LAND_LEAN : float = 0.2

## Metres travelled per full walk cycle.
@export var stride_length : float = 0.5
## Peak upper-leg swing in radians.
@export var leg_swing : float = 0.6
## Peak knee bend in radians.
@export var knee_bend : float = 0.9
## Peak arm swing in radians.
@export var arm_swing : float = 0.35
## Blend weight change per second when starting or stopping the walk.
@export var blend_speed : float = 8.0
## Horizontal speed below which the player counts as standing still.
@export var min_walk_speed : float = 0.1
## Radians the upper arms rotate down from the T-pose, around bone Z; flip sign if arms go up.
@export var arm_lower : float = 1.2
## Path to the character's visual model that contains the Skeleton3D.
@export var mesh_path : NodePath = NodePath("../player")

@export_group("Gun")
## Gun scene placed in the right hand; leave empty for no gun.
@export var gun_scene : PackedScene
## Downward tilt of the aiming right arm in radians; sets the muzzle height (0.15 = about 0.3 m, 0.6 = about 0.17 m).
@export var aim_pitch : float = 0.15
## Grip position in Hand.R bone space, in model units (before the model's scale).
@export var gun_grip_offset : Vector3 = Vector3(0.0, 0.2, 0.0)
## Seconds the model keeps facing the last shot direction.
@export var aim_hold_time : float = 0.5
## How fast the model turns between the aim direction and the body's facing.
@export var aim_turn_speed : float = 15.0

@export_group("Recoil")
## Radians the right arm kicks up on a shot.
@export var recoil_arm : float = 0.5
## Radians the upper spine kicks back on a shot.
@export var recoil_spine : float = 0.08
## Seconds the recoil takes to recover.
@export var recoil_duration : float = 0.12

@export_group("Jump")
## Blend weight change per second when leaving or reaching the floor.
@export var air_blend_speed : float = 10.0
## Vertical speed at which the air pose is fully tucked (rising) or fully extended (falling).
@export var air_speed_range : float = 3.5
## Radians the left arm rises for balance while airborne.
@export var air_arm_raise : float = 0.6
## Seconds in the air before a landing squash plays; ignores tiny drops.
@export var min_air_time : float = 0.15
## Seconds the landing squash takes to recover.
@export var land_duration : float = 0.15
## Pelvis drop at full squash, in model units.
@export var land_drop : float = 0.15

var _phase : float = 0.0
var _weight : float = 0.0
var _skeleton : Skeleton3D
var _bone_indices : Dictionary = {}
var _gun : Gun
var _aim_pose : Quaternion
var _recoil_axis : Vector3 = Vector3.RIGHT
var _gun_basis : Basis
var _pelvis_rest : Vector3
var _base_yaw : float = 0.0
var _yaw_offset : float = 0.0
var _aim_yaw : float = 0.0
var _aim_hold_left : float = 0.0
var _recoil : float = 0.0
var _air_weight : float = 0.0
var _air_time : float = 0.0
var _land : float = 0.0

@onready var player : CharacterBody3D = get_parent()
@onready var player_mesh : Node3D = get_node(mesh_path)

func _ready() -> void:
	var skeletons : Array[Node] = player_mesh.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		push_error("No Skeleton3D found under the player mesh")
		set_process(false)
		return
	_skeleton = skeletons[0]
	for bone_name in ANIMATED_BONES:
		var index : int = _skeleton.find_bone(bone_name)
		if index == -1:
			push_error("Bone not found: " + bone_name)
			set_process(false)
			return
		_bone_indices[bone_name] = index
	_base_yaw = player_mesh.rotation.y
	_pelvis_rest = _skeleton.get_bone_rest(_bone_indices["Pelvis"]).origin
	_compute_aim_pose()
	if gun_scene != null:
		_attach_gun.call_deferred()

func _process(delta: float) -> void:
	var dead : bool = _is_dead()
	var on_floor : bool = player.is_on_floor()
	var horizontal_speed : float = Vector2(player.velocity.x, player.velocity.z).length()
	var can_move : bool = not ("can_move" in player) or player.can_move
	var walking : bool = not dead and can_move and on_floor and horizontal_speed > min_walk_speed
	_weight = move_toward(_weight, 1.0 if walking else 0.0, blend_speed * delta)
	if walking:
		_phase = fmod(_phase + horizontal_speed / stride_length * TAU * delta, TAU)
	var swing : float = sin(_phase) * _weight
	var lift : float = cos(_phase)

	# Jump: tuck while rising, extend while falling, squash on landing.
	if on_floor:
		if _air_time >= min_air_time and not dead:
			_land = 1.0
		_air_time = 0.0
	else:
		_air_time += delta
	_air_weight = move_toward(_air_weight, 1.0 if not on_floor and not dead else 0.0, air_blend_speed * delta)
	_land = move_toward(_land, 0.0, delta / land_duration)
	var squash : float = _land * _land * (3.0 - 2.0 * _land)
	var fall : float = clampf(0.5 - player.velocity.y / (2.0 * air_speed_range), 0.0, 1.0)
	var air_l : Vector2 = TUCK_L.lerp(EXTEND_L, fall) * _air_weight
	var air_r : Vector2 = TUCK_R.lerp(EXTEND_R, fall) * _air_weight
	var land_leg : Vector2 = LAND_LEG * squash

	_recoil = move_toward(_recoil, 0.0, delta / recoil_duration)
	var kick : float = _recoil * _recoil

	_set_bone_angle("UpperLeg.L", leg_swing * swing + air_l.x + land_leg.x)
	_set_bone_angle("UpperLeg.R", -leg_swing * swing + air_r.x + land_leg.x)
	_set_bone_angle("LowerLeg.L", -knee_bend * maxf(lift, 0.0) * _weight + air_l.y + land_leg.y)
	_set_bone_angle("LowerLeg.R", -knee_bend * maxf(-lift, 0.0) * _weight + air_r.y + land_leg.y)
	_set_arm_angle("UpperArm.L", -(arm_lower - air_arm_raise * _air_weight), -arm_swing * swing)
	_skeleton.set_bone_pose_rotation(_bone_indices["UpperArm.R"], _aim_pose * Quaternion(_recoil_axis, recoil_arm * kick))
	_set_bone_angle("Spine1", LAND_LEAN * squash)
	_set_bone_angle("Spine2", -recoil_spine * kick)
	_skeleton.set_bone_pose_position(_bone_indices["Pelvis"], _pelvis_rest + Vector3(0.0, -land_drop * squash, 0.0))
	if not dead:
		_update_yaw(delta)

## Call when the character fires toward direction. Turns the model to aim, plays recoil and the muzzle flash,
## and returns the muzzle's world position (callers set their own bullet height).
func play_shoot(direction: Vector3) -> Vector3:
	var fallback : Vector3 = player.global_position + direction * 0.4
	if _skeleton == null or _is_dead():
		return fallback
	_aim_yaw = atan2(direction.x, direction.z)
	_aim_hold_left = aim_hold_time
	_yaw_offset = wrapf(_aim_yaw - player.global_rotation.y, -PI, PI)
	player_mesh.rotation.y = _base_yaw + _yaw_offset
	_recoil = 1.0
	if _gun == null:
		return fallback
	var muzzle_position : Vector3 = _gun.muzzle.global_position
	_gun.play_shot()
	return muzzle_position

## Turns the model toward the last shot direction while the aim is held, then back to the body's facing.
func _update_yaw(delta: float) -> void:
	var target_offset : float = 0.0
	if _aim_hold_left > 0.0:
		_aim_hold_left -= delta
		target_offset = wrapf(_aim_yaw - player.global_rotation.y, -PI, PI)
	_yaw_offset = lerp_angle(_yaw_offset, target_offset, minf(aim_turn_speed * delta, 1.0))
	player_mesh.rotation.y = _base_yaw + _yaw_offset

## Precomputes the right arm's aiming rotation, its recoil axis and the gun's orientation in hand-bone space.
func _compute_aim_pose() -> void:
	var upper : int = _bone_indices["UpperArm.R"]
	var hand : int = _bone_indices["Hand.R"]
	var parent_rest : Quaternion = _skeleton.get_bone_global_rest(_skeleton.get_bone_parent(upper)).basis.get_rotation_quaternion()
	var upper_rest : Quaternion = _skeleton.get_bone_global_rest(upper).basis.get_rotation_quaternion()
	var hand_rest : Quaternion = _skeleton.get_bone_global_rest(hand).basis.get_rotation_quaternion()
	# The model faces -Z in skeleton space; aim forward and aim_pitch radians down.
	var aim_direction : Vector3 = Vector3(0.0, -sin(aim_pitch), -cos(aim_pitch))
	# Swing the whole arm about the shoulder so the hand points along aim_direction with minimal twist.
	var swing : Quaternion = Quaternion((hand_rest * Vector3.UP).normalized(), aim_direction)
	var aimed_upper : Quaternion = swing * upper_rest
	_aim_pose = parent_rest.inverse() * aimed_upper
	# Recoil rotates about the character's right axis (+X in skeleton space), which lifts the forward arm.
	_recoil_axis = (aimed_upper.inverse() * Vector3.RIGHT).normalized()
	var aimed_hand : Quaternion = swing * hand_rest
	_gun_basis = Basis(aimed_hand.inverse()) * Basis.looking_at(aim_direction, Vector3.UP)

## Puts the gun in the right hand with a BoneAttachment3D; the gun is sized in metres, so undo the model scale.
func _attach_gun() -> void:
	var attachment : BoneAttachment3D = BoneAttachment3D.new()
	attachment.name = "GunAttachment"
	_skeleton.add_child(attachment)
	attachment.bone_name = "Hand.R"
	_gun = gun_scene.instantiate()
	attachment.add_child(_gun)
	_gun.transform = Transform3D(_gun_basis.scaled(Vector3.ONE / player_mesh.scale.x), gun_grip_offset)

func _is_dead() -> bool:
	var health_component : HealthComponent = player.get_node_or_null("HealthComponent")
	return health_component != null and health_component.is_dead()

## Rotates a bone around its own X axis away from its rest pose.
func _set_bone_angle(bone_name: String, angle: float) -> void:
	var index : int = _bone_indices[bone_name]
	var rest : Quaternion = _skeleton.get_bone_rest(index).basis.get_rotation_quaternion()
	_skeleton.set_bone_pose_rotation(index, rest * Quaternion(Vector3.RIGHT, angle))

## Lowers an arm from the T-pose around the bone's Z axis, then swings it around X.
func _set_arm_angle(bone_name: String, lower_angle: float, swing_angle: float) -> void:
	var index : int = _bone_indices[bone_name]
	var rest : Quaternion = _skeleton.get_bone_rest(index).basis.get_rotation_quaternion()
	_skeleton.set_bone_pose_rotation(index, rest * Quaternion(Vector3.BACK, lower_angle) * Quaternion(Vector3.RIGHT, swing_angle))
