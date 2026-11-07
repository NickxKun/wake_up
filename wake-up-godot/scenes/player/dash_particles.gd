class_name DashParticles
extends Node3D

## High-pressure Reaction Control System (RCS) thruster system for astronaut suit/backpack:
## - Fixed discrete orthogonal nozzles along principal axes (never arbitrary 45-degree rotation):
##   * Rear backpack nozzles: 2 streams firing backward (propels forward)
##   * Front chest/shoulder nozzles: 2 streams firing forward (propels backward)
##   * Left/Right lateral backpack nozzles: streams firing at 90 degrees out the sides (propels left/right)
##   * Bottom nozzles: 2 streams firing straight down for vertical flight
## - Diagonal movement activates a combination of longitudinal and lateral 90-degree thrusters!

@onready var cpu_particles : CPUParticles3D = $CPUParticles3D
@onready var right_particles : CPUParticles3D = get_node_or_null("CPUParticles3D_Right") as CPUParticles3D
@onready var rear_left_particles : CPUParticles3D = $CPUParticles3D
@onready var rear_right_particles : CPUParticles3D = get_node_or_null("CPUParticles3D_Right") as CPUParticles3D
@onready var side_left_particles : CPUParticles3D = get_node_or_null("SideParticles_Left") as CPUParticles3D
@onready var side_right_particles : CPUParticles3D = get_node_or_null("SideParticles_Right") as CPUParticles3D
@onready var front_left_particles : CPUParticles3D = get_node_or_null("FrontParticles_Left") as CPUParticles3D
@onready var front_right_particles : CPUParticles3D = get_node_or_null("FrontParticles_Right") as CPUParticles3D
@onready var flight_particles : CPUParticles3D = get_node_or_null("FlightParticles") as CPUParticles3D
@onready var flight_right_particles : CPUParticles3D = get_node_or_null("FlightParticles_Right") as CPUParticles3D
@onready var jet_light : OmniLight3D = get_node_or_null("JetLight") as OmniLight3D

var _is_flying : bool = false
var _dash_timer : float = 0.0

func _ready() -> void:
	rotation.y = deg_to_rad(180.0)
	stop_dash()
	if flight_particles != null:
		flight_particles.emitting = false
	if flight_right_particles != null:
		flight_right_particles.emitting = false
	if jet_light != null:
		jet_light.light_energy = 0.0

func _physics_process(delta: float) -> void:
	if _dash_timer > 0.0:
		_dash_timer = maxf(_dash_timer - delta, 0.0)
		if _dash_timer <= 0.0:
			stop_dash()

## Starts the continuous narrow pressurized rocket correction stream from the rear backpack nozzles.
func start_dash(_dash_dir: Vector3 = Vector3.ZERO, duration: float = 0.22) -> void:
	start_dash_directional(_dash_dir, Vector3.ZERO, 1.0, 0.0, duration)

## Activates the rear backpack thrusters in one fixed backward direction (propelling the player forward).
func start_dash_directional(_dash_dir: Vector3 = Vector3.ZERO, _facing: Vector3 = Vector3.ZERO, _rel_fwd: float = 1.0, _rel_right: float = 0.0, duration: float = 0.22) -> void:
	_dash_timer = duration
	rotation.y = deg_to_rad(180.0) # Fixed backward backpack nozzle alignment

	# Always fire both rear backpack nozzles directly backwards (consistent single-direction thruster)
	var fire_rear_left : bool = true
	var fire_rear_right : bool = true
	var fire_front_left : bool = false
	var fire_front_right : bool = false
	var fire_side_left : bool = false
	var fire_side_right : bool = false

	# Set emission state on independent nozzles:
	if cpu_particles != null:
		cpu_particles.emitting = fire_rear_left
	if right_particles != null:
		right_particles.emitting = fire_rear_right

	if front_left_particles != null:
		front_left_particles.emitting = fire_front_left
	if front_right_particles != null:
		front_right_particles.emitting = fire_front_right

	if side_left_particles != null:
		side_left_particles.emitting = fire_side_left
	if side_right_particles != null:
		side_right_particles.emitting = fire_side_right

	if jet_light != null:
		jet_light.light_energy = 1.2

## Stops all dash streams immediately and restores standard orientation.
func stop_dash() -> void:
	_dash_timer = 0.0
	rotation.y = deg_to_rad(180.0)
	if cpu_particles != null:
		cpu_particles.emitting = false
	if right_particles != null:
		right_particles.emitting = false
	if front_left_particles != null:
		front_left_particles.emitting = false
	if front_right_particles != null:
		front_right_particles.emitting = false
	if side_left_particles != null:
		side_left_particles.emitting = false
	if side_right_particles != null:
		side_right_particles.emitting = false
	if jet_light != null:
		jet_light.light_energy = 0.0

## Triggers dash stream burst (backward compatibility).
func trigger(dash_dir: Vector3) -> void:
	start_dash(dash_dir, 0.22)

## Sets whether the vertical flight thruster is actively firing pressurized air from the bottom nozzles.
func set_flying(flying: bool) -> void:
	if _is_flying == flying:
		return
	_is_flying = flying
	if flight_particles != null:
		flight_particles.emitting = flying
	if flight_right_particles != null:
		flight_right_particles.emitting = flying
	if jet_light != null:
		jet_light.light_energy = 1.0 if flying else 0.0
