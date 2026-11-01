class_name SentryTurret
extends StaticBody3D

## Autonomous Tactical Sentry Turret deployed by The Engineer.
## Scans 360 degrees for hostile enemies within 16m, swivels turret head smoothly,
## discharges rapid kinetic rounds, displays a sleek minimal health bar,
## and serves as an enemy aggro decoy magnet.

signal destroyed
signal repaired(current_hp: int)

const BULLET_SCENE : PackedScene = preload("res://scenes/projectiles/bullet.tscn")
const SCAN_RANGE : float = 16.0
const ROTATION_SPEED : float = 9.0
const FIRE_RATE : float = 0.35
const BULLET_DAMAGE : int = 22

@export var max_health : int = 100

var _target : Node3D = null
var _fire_timer : float = 0.0
var _is_destroyed : bool = false
var _fire_side : bool = false
var _fill_style : StyleBoxFlat = null
var _hp_tween : Tween = null
var _flash_tween : Tween = null

@onready var health_component : HealthComponent = $HealthComponent
@onready var swivel_head : Node3D = $TurretBase/SwivelHead
@onready var muzzle_left : Marker3D = $TurretBase/SwivelHead/MuzzleL
@onready var muzzle_right : Marker3D = $TurretBase/SwivelHead/MuzzleR
@onready var flash_left : CPUParticles3D = $TurretBase/SwivelHead/MuzzleL/Flash
@onready var flash_right : CPUParticles3D = $TurretBase/SwivelHead/MuzzleR/Flash
@onready var health_sprite : Sprite3D = $HealthBar3D
@onready var sub_viewport : SubViewport = $HealthBar3D/SubViewport
@onready var health_progress : ProgressBar = $HealthBar3D/SubViewport/ProgressBar

func _ready() -> void:
	add_to_group("turret")
	add_to_group("friendly")

	# Bind SubViewport texture to 3D billboard sprite
	if health_sprite != null and sub_viewport != null:
		health_sprite.texture = sub_viewport.get_texture()

	if health_progress != null:
		health_progress.max_value = float(HealthComponent.MAX_HEALTH)
		var orig_fill : StyleBox = health_progress.get_theme_stylebox("fill")
		if orig_fill is StyleBoxFlat:
			_fill_style = orig_fill.duplicate()
		else:
			_fill_style = StyleBoxFlat.new()
			_fill_style.corner_radius_top_left = 2
			_fill_style.corner_radius_top_right = 2
			_fill_style.corner_radius_bottom_right = 2
			_fill_style.corner_radius_bottom_left = 2
		health_progress.add_theme_stylebox_override("fill", _fill_style)

	if health_component != null:
		health_component.health_changed.connect(_on_health_changed)
		health_component.health_depleted.connect(_on_health_depleted)

	_update_health_display()

func _physics_process(delta: float) -> void:
	if _is_destroyed:
		return

	# Find or validate closest hostile target
	_refresh_target()

	if _target != null and is_instance_valid(_target) and _target.is_inside_tree():
		# Aim at center of mass
		var target_pos : Vector3 = _target.global_position + Vector3(0.0, 0.35, 0.0)
		var to_target : Vector3 = target_pos - swivel_head.global_position
		var to_target_horiz := Vector3(to_target.x, 0.0, to_target.z)

		if to_target_horiz.length_squared() > 0.001:
			# In Godot 3D, forward is -Z. To point -Z at (dx, 0, dz), yaw is atan2(-dx, -dz).
			var target_yaw : float = atan2(-to_target_horiz.x, -to_target_horiz.z)
			swivel_head.global_rotation.y = lerp_angle(swivel_head.global_rotation.y, target_yaw, ROTATION_SPEED * delta)

		# Check barrel alignment with target before firing
		var barrel_forward : Vector3 = -swivel_head.global_transform.basis.z.normalized()
		var aim_horiz : Vector3 = to_target_horiz.normalized()
		var alignment : float = barrel_forward.dot(aim_horiz)

		_fire_timer -= delta
		if _fire_timer <= 0.0 and to_target.length() <= SCAN_RANGE and alignment > 0.8 and _has_line_of_sight(_target):
			_fire_timer = FIRE_RATE
			var active_muzzle : Marker3D = muzzle_right if _fire_side else muzzle_left
			var muzzle_pos : Vector3 = active_muzzle.global_position if active_muzzle != null else swivel_head.global_position
			var shoot_dir : Vector3 = (target_pos - muzzle_pos).normalized()
			_fire_round(shoot_dir)
	else:
		_target = null
		# Idle 360 degree scan when no targets in range
		if swivel_head != null:
			swivel_head.global_rotation.y += 0.45 * delta

func _refresh_target() -> void:
	if _target != null and is_instance_valid(_target) and _target.is_inside_tree():
		var dist : float = global_position.distance_to(_target.global_position)
		var target_hc : HealthComponent = _target.get_node_or_null("HealthComponent") as HealthComponent
		if target_hc != null and not target_hc.is_dead() and dist <= SCAN_RANGE and _has_line_of_sight(_target):
			return # Target remains valid and engaged

	# Search for closest active enemy within SCAN_RANGE
	_target = null
	var min_dist : float = SCAN_RANGE
	var tree : SceneTree = get_tree()
	if tree == null:
		return

	var enemies := tree.get_nodes_in_group("enemy")
	for e in enemies:
		if e == null or not is_instance_valid(e) or not (e is Node3D) or not (e as Node3D).is_inside_tree():
			continue
		var n3d := e as Node3D
		var hc : HealthComponent = n3d.get_node_or_null("HealthComponent") as HealthComponent
		if hc != null and hc.is_dead():
			continue

		var dist : float = global_position.distance_to(n3d.global_position)
		if dist < min_dist and _has_line_of_sight(n3d):
			min_dist = dist
			_target = n3d

func _has_line_of_sight(target_node: Node3D) -> bool:
	var space_state := get_world_3d().direct_space_state
	if space_state == null or target_node == null:
		return false

	var from : Vector3 = swivel_head.global_position + Vector3(0.0, 0.15, 0.0)
	var to : Vector3 = target_node.global_position + Vector3(0.0, 0.3, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, to, 1) # Layer 1 = World geometry
	query.exclude = [get_rid()]

	var hit := space_state.intersect_ray(query)
	return hit.is_empty()

func _fire_round(direction: Vector3) -> void:
	_fire_side = not _fire_side
	var active_muzzle : Marker3D = muzzle_right if _fire_side else muzzle_left
	var active_flash : CPUParticles3D = flash_right if _fire_side else flash_left

	if active_flash != null:
		active_flash.restart()
		active_flash.emitting = true

	# Play turret shoot sound
	var snd : Node = get_node_or_null("/root/UiSound")
	if snd != null and snd.has_method("play_turret_shoot"):
		snd.play_turret_shoot()

	# Spawn kinetic bullet
	var bullet : Area3D = BULLET_SCENE.instantiate() as Area3D
	bullet.shooter = self
	bullet.direction = direction
	bullet.damage = BULLET_DAMAGE
	bullet.speed = 15.0
	bullet.decal_scale = 0.28
	get_parent().add_child(bullet)
	bullet.global_position = active_muzzle.global_position if active_muzzle != null else swivel_head.global_position

func _on_health_changed(new_hp: int, old_hp: int) -> void:
	_update_health_display(new_hp, old_hp)
	if new_hp > old_hp:
		repaired.emit(new_hp)

func _update_health_display(new_hp: int = -1, old_hp: int = -1) -> void:
	if health_progress == null or health_component == null:
		return
	var cur_hp : int = health_component.health if new_hp < 0 else new_hp
	var max_hp : int = HealthComponent.MAX_HEALTH

	if _hp_tween != null and _hp_tween.is_valid():
		_hp_tween.kill()
	_hp_tween = create_tween()
	_hp_tween.tween_property(health_progress, "value", float(cur_hp), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var ratio : float = clampf(float(cur_hp) / float(max_hp), 0.0, 1.0)
	var target_col : Color
	if ratio > 0.5:
		target_col = Color(1.0, 0.65, 0.15, 1.0).lerp(Color(0.2, 0.9, 0.55, 1.0), (ratio - 0.5) * 2.0)
	else:
		target_col = Color(0.95, 0.22, 0.22, 1.0).lerp(Color(1.0, 0.65, 0.15, 1.0), ratio * 2.0)

	if _fill_style != null:
		if _flash_tween != null and _flash_tween.is_valid():
			_flash_tween.kill()

		if new_hp >= 0 and old_hp >= 0 and new_hp < old_hp:
			_fill_style.bg_color = Color.WHITE
			_flash_tween = create_tween()
			_flash_tween.tween_property(_fill_style, "bg_color", target_col, 0.14)
		elif new_hp >= 0 and old_hp >= 0 and new_hp > old_hp:
			_fill_style.bg_color = Color(0.2, 1.0, 0.6, 1.0)
			_flash_tween = create_tween()
			_flash_tween.tween_property(_fill_style, "bg_color", target_col, 0.14)
		else:
			_fill_style.bg_color = target_col

func _on_health_depleted() -> void:
	if _is_destroyed:
		return
	_is_destroyed = true
	destroyed.emit()

	# Explosion visual & audio
	var snd : Node = get_node_or_null("/root/UiSound")
	if snd != null and snd.has_method("play_enemy_death"):
		snd.play_enemy_death()

	# Destroyed scrap burst
	var death_particles : CPUParticles3D = $DestructionParticles
	if death_particles != null:
		death_particles.emitting = true
		death_particles.reparent(get_parent())

	queue_free()
