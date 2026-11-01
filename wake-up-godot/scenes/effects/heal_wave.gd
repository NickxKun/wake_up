class_name HealWaveEffect
extends Node3D

## Visual & physical area-of-effect for The Medic's Nanite Healing Surge.
## Expands an emerald holographic shockwave ring, emits nanite cross particles,
## and restores health to the player, friendly turrets, and drivable vehicles.

@export var max_radius : float = 8.0
@export var duration : float = 0.85
@export var instant_heal : int = 35

var _time : float = 0.0
var _healed_entities : Array[Node] = []

@onready var wave_ring : MeshInstance3D = $Ring
@onready var cross_particles : CPUParticles3D = $CrossParticles

func _ready() -> void:
	if cross_particles != null:
		cross_particles.emitting = true
	_perform_heal_sweep()

func _process(delta: float) -> void:
	_time += delta
	var progress : float = clampf(_time / duration, 0.0, 1.0)
	var current_r : float = max_radius * (1.0 - pow(1.0 - progress, 3.0)) # Smooth cubic ease out

	if wave_ring != null:
		wave_ring.scale = Vector3(current_r, 1.0, current_r)
		var mat : StandardMaterial3D = wave_ring.get_active_material(0) as StandardMaterial3D
		if mat != null:
			mat.albedo_color.a = (1.0 - progress) * 0.75

	if progress >= 1.0:
		queue_free()

func _perform_heal_sweep() -> void:
	var tree : SceneTree = get_tree()
	if tree == null:
		return

	# Heal Player
	var player : Node = tree.get_first_node_in_group("player")
	if player != null and is_instance_valid(player) and (player is Node3D):
		if global_position.distance_to((player as Node3D).global_position) <= max_radius:
			_heal_node(player)

	# Heal Friendly Turrets
	var turrets := tree.get_nodes_in_group("turret")
	for t in turrets:
		if t != null and is_instance_valid(t) and (t is Node3D):
			if global_position.distance_to((t as Node3D).global_position) <= max_radius:
				_heal_node(t)

	# Heal Vehicles
	var vehicles := tree.get_nodes_in_group("vehicle")
	for v in vehicles:
		if v != null and is_instance_valid(v) and (v is Node3D):
			if global_position.distance_to((v as Node3D).global_position) <= max_radius:
				_heal_node(v)

func _heal_node(node: Node) -> void:
	if node in _healed_entities:
		return
	_healed_entities.append(node)

	var hc : HealthComponent = node.get_node_or_null("HealthComponent") as HealthComponent
	if hc != null and not hc.is_dead():
		hc.increase_health(instant_heal)
		hc.increase_shield(20.0)
