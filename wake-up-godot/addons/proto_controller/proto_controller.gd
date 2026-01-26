# ProtoController v1.2 (Isometric/45-Degree Edition)
# Adapted from Brackeys' v1.0
# CC0 License

extends CharacterBody3D

## Can we move around?
@export var can_move : bool = true
## Are we affected by gravity?
@export var has_gravity : bool = true
## Can we press to jump?
@export var can_jump : bool = true
## Can we hold to run?
@export var can_sprint : bool = false
## Can we press to enter freefly mode (noclip)?
@export var can_freefly : bool = false

@export_group("Orientation")
## Offset inputs to match camera angle. 
@export var movement_offset_angle : float = 45.0
## How fast does the character rotate to face movement direction?
@export var rotation_speed : float = 12.0

@export_group("Speeds")
## Normal speed.
@export var base_speed : float = 2.0
## Speed of jump.
@export var jump_velocity : float = 3.5
## How fast do we run?
@export var sprint_speed : float = 4.0
## How fast do we freefly?
@export var freefly_speed : float = 6.0

@export_group("Input Actions")
@export var input_left : String = "ui_left"
@export var input_right : String = "ui_right"
@export var input_forward : String = "ui_up"
@export var input_back : String = "ui_down"
@export var input_jump : String = "ui_accept"
@export var input_sprint : String = "sprint"
@export var input_freefly : String = "freefly"

var move_speed : float = 0.0
var freeflying : bool = false

## IMPORTANT REFERENCES
@onready var collider: CollisionShape3D = $Collider

func _ready() -> void:
	check_input_mappings()

func _unhandled_input(_event: InputEvent) -> void:
	if can_freefly and Input.is_action_just_pressed(input_freefly):
		if not freeflying:
			enable_freefly()
		else:
			disable_freefly()

func _physics_process(delta: float) -> void:
	if can_freefly and freeflying:
		var input_dir := Input.get_vector(input_left, input_right, input_forward, input_back)
		
		# Apply offset to freefly as well so it feels natural
		var motion := Vector3(input_dir.x, 0, input_dir.y)
		motion = motion.rotated(Vector3.UP, deg_to_rad(movement_offset_angle)).normalized()
		
		motion *= freefly_speed * delta
		move_and_collide(motion)
		return
	
	if has_gravity:
		if not is_on_floor():
			velocity += get_gravity() * delta

	if can_jump:
		if Input.is_action_just_pressed(input_jump) and is_on_floor():
			velocity.y = jump_velocity

	if can_sprint and Input.is_action_pressed(input_sprint):
			move_speed = sprint_speed
	else:
		move_speed = base_speed

	if can_move:
		var input_dir := Input.get_vector(input_left, input_right, input_forward, input_back)
		
		# 1. Create the raw direction from input
		var raw_dir := Vector3(input_dir.x, 0, input_dir.y)
		
		# 2. Rotate that direction by our offset angle
		var move_dir := raw_dir.rotated(Vector3.UP, deg_to_rad(movement_offset_angle)).normalized()
		
		if move_dir:
			velocity.x = move_dir.x * move_speed
			velocity.z = move_dir.z * move_speed
			
			# Rotate character to face movement
			var target_angle = atan2(velocity.x, velocity.z)
			rotation.y = lerp_angle(rotation.y, target_angle, rotation_speed * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, move_speed)
			velocity.z = move_toward(velocity.z, 0, move_speed)
	else:
		velocity.x = 0
	
	move_and_slide()

func enable_freefly():
	collider.disabled = true
	freeflying = true
	velocity = Vector3.ZERO

func disable_freefly():
	collider.disabled = false
	freeflying = false

func check_input_mappings():
	if can_move and not InputMap.has_action(input_left):
		push_error("Movement disabled. No InputAction found for input_left: " + input_left)
		can_move = false
	if can_move and not InputMap.has_action(input_right):
		push_error("Movement disabled. No InputAction found for input_right: " + input_right)
		can_move = false
	if can_move and not InputMap.has_action(input_forward):
		push_error("Movement disabled. No InputAction found for input_forward: " + input_forward)
		can_move = false
	if can_move and not InputMap.has_action(input_back):
		push_error("Movement disabled. No InputAction found for input_back: " + input_back)
		can_move = false
