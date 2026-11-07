class_name BossMech
extends CharacterBody3D

## Titan Combat Mech // Goliath-Class Siege Platform
## High-threat final boss with 800 HP, multi-tier boss health HUD,
## and 3 distinct deadly attack patterns:
## 1. Twin Heavy Plasma Volley (alternating shoulder autocannons)
## 2. Micro-Missile Rocket Salvo (4-pod propelled explosive rockets)
## 3. Seismic Stomp (expanding ground shockwave with knockback)

signal boss_defeated(boss: BossMech)

const BULLET_SCENE : PackedScene = preload("res://scenes/projectiles/bullet.tscn")
const ROCKET_SCENE : PackedScene = preload("res://scenes/projectiles/rocket.tscn")

@export var max_health : int = 800
@export var move_speed : float = 2.4
@export var rotation_speed : float = 2.5
@export var min_attack_interval : float = 2.5
@export var max_attack_interval : float = 4.0

enum BossState {
	IDLE,
	APPROACH,
	PATTERN_PLASMA_VOLLEY,
	PATTERN_ROCKET_SALVO,
	PATTERN_SEISMIC_STOMP,
	DYING
}

var current_state : BossState = BossState.APPROACH
var _player : Node3D = null
var _attack_timer : float = 3.0
var _walk_cycle_time : float = 0.0
var _is_dying : bool = false
var _consecutive_stomps : int = 0

# Visual Components
var _model_root : Node3D = null
var _torso : MeshInstance3D = null
var _visor : MeshInstance3D = null
var _left_cannon : Node3D = null
var _right_cannon : Node3D = null
var _missile_pod : Node3D = null
var _leg_left : Node3D = null
var _leg_right : Node3D = null
var _telegraph_mesh : MeshInstance3D = null
var _exhaust_particles_left : CPUParticles3D = null
var _exhaust_particles_right : CPUParticles3D = null

# Health & UI Components
@onready var health_component : HealthComponent = $HealthComponent
var _boss_hud : CanvasLayer = null
var _hud_progress_bar : ProgressBar = null
var _hud_lag_bar : ProgressBar = null
var _hud_hp_label : Label = null
var _billboard_sprite : Sprite3D = null
var _billboard_progress : ProgressBar = null

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")

	_build_procedural_mech_model()
	_setup_health_and_bars()
	_create_boss_hud()

	# Announce boss spawn with sound & screen shake
	var snd : Node = get_node_or_null("/root/UiSound")
	if snd != null and snd.has_method("play_hazard_pulse"):
		snd.play_hazard_pulse()
	var ss : Node = get_node_or_null("/root/ScreenShake")
	if ss != null and ss.has_method("shake"):
		ss.shake(0.5)

func _setup_health_and_bars() -> void:
	if health_component != null:
		health_component.max_health = max_health
		health_component.health = max_health
		health_component.health_changed.connect(_on_health_changed)
		health_component.health_depleted.connect(_on_death)

	# 3D Billboard Overhead Health Bar
	_billboard_sprite = Sprite3D.new()
	_billboard_sprite.name = "BossBillboard"
	_billboard_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_billboard_sprite.pixel_size = 0.003
	_billboard_sprite.position = Vector3(0.0, 3.4, 0.0)
	add_child(_billboard_sprite)

	var sub_viewport := SubViewport.new()
	sub_viewport.size = Vector2i(200, 24)
	sub_viewport.transparent_bg = true
	_billboard_sprite.add_child(sub_viewport)

	_billboard_progress = ProgressBar.new()
	_billboard_progress.size = Vector2(200, 24)
	_billboard_progress.max_value = float(max_health)
	_billboard_progress.value = float(max_health)
	_billboard_progress.show_percentage = false

	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = Color(0.08, 0.1, 0.12, 0.85)
	bg_sb.border_width_left = 2
	bg_sb.border_width_top = 2
	bg_sb.border_width_right = 2
	bg_sb.border_width_bottom = 2
	bg_sb.border_color = Color(0.85, 0.2, 0.2, 0.9)
	bg_sb.corner_radius_top_left = 3
	bg_sb.corner_radius_top_right = 3
	bg_sb.corner_radius_bottom_right = 3
	bg_sb.corner_radius_bottom_left = 3

	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = Color(0.95, 0.18, 0.15, 1.0)
	fill_sb.corner_radius_top_left = 2
	fill_sb.corner_radius_top_right = 2
	fill_sb.corner_radius_bottom_right = 2
	fill_sb.corner_radius_bottom_left = 2

	_billboard_progress.add_theme_stylebox_override("background", bg_sb)
	_billboard_progress.add_theme_stylebox_override("fill", fill_sb)
	sub_viewport.add_child(_billboard_progress)

	_billboard_sprite.texture = sub_viewport.get_texture()

func _create_boss_hud() -> void:
	_boss_hud = CanvasLayer.new()
	_boss_hud.name = "TitanMechBossHUD"
	_boss_hud.layer = 15
	add_child(_boss_hud)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	margin.offset_top = 24.0
	margin.offset_left = 120.0
	margin.offset_right = -120.0
	_boss_hud.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	# Header Title & Subtitle
	var title_box := HBoxContainer.new()
	vbox.add_child(title_box)

	var skull_icon := Label.new()
	skull_icon.text = "☠"
	skull_icon.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2))
	skull_icon.add_theme_font_size_override("font_size", 16)
	title_box.add_child(skull_icon)

	var title_label := Label.new()
	title_label.text = " TITAN COMBAT MECH  //  GOLIATH CLASS"
	title_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.92))
	title_label.add_theme_font_size_override("font_size", 14)
	title_box.add_child(title_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_child(spacer)

	_hud_hp_label = Label.new()
	_hud_hp_label.text = "%d / %d HP" % [max_health, max_health]
	_hud_hp_label.add_theme_color_override("font_color", Color(0.9, 0.45, 0.4))
	_hud_hp_label.add_theme_font_size_override("font_size", 12)
	title_box.add_child(_hud_hp_label)

	# Stacked Progress Bar (Lag Bar behind Health Bar)
	var bar_container := PanelContainer.new()
	bar_container.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(bar_container)

	_hud_lag_bar = ProgressBar.new()
	_hud_lag_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_lag_bar.max_value = float(max_health)
	_hud_lag_bar.value = float(max_health)
	_hud_lag_bar.show_percentage = false

	var lag_bg := StyleBoxFlat.new()
	lag_bg.bg_color = Color(0.06, 0.08, 0.1, 0.9)
	lag_bg.border_width_left = 1
	lag_bg.border_width_top = 1
	lag_bg.border_width_right = 1
	lag_bg.border_width_bottom = 1
	lag_bg.border_color = Color(0.4, 0.15, 0.15, 0.8)

	var lag_fill := StyleBoxFlat.new()
	lag_fill.bg_color = Color(0.95, 0.65, 0.18, 0.9) # Amber trailing lag
	_hud_lag_bar.add_theme_stylebox_override("background", lag_bg)
	_hud_lag_bar.add_theme_stylebox_override("fill", lag_fill)
	bar_container.add_child(_hud_lag_bar)

	_hud_progress_bar = ProgressBar.new()
	_hud_progress_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_progress_bar.max_value = float(max_health)
	_hud_progress_bar.value = float(max_health)
	_hud_progress_bar.show_percentage = false

	var empty_bg := StyleBoxEmpty.new()
	var health_fill := StyleBoxFlat.new()
	health_fill.bg_color = Color(0.92, 0.18, 0.16, 1.0) # Vivid Crimson
	_hud_progress_bar.add_theme_stylebox_override("background", empty_bg)
	_hud_progress_bar.add_theme_stylebox_override("fill", health_fill)
	bar_container.add_child(_hud_progress_bar)

	# Smooth entrance tween
	margin.modulate.a = 0.0
	margin.position.y -= 20.0
	var enter_tween := create_tween().set_parallel(true)
	enter_tween.tween_property(margin, "modulate:a", 1.0, 0.5)
	enter_tween.tween_property(margin, "position:y", margin.position.y + 20.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_health_changed(current: int, _max_hp: int) -> void:
	if _billboard_progress != null:
		_billboard_progress.value = float(current)
	if _hud_progress_bar != null:
		_hud_progress_bar.value = float(current)
	if _hud_hp_label != null:
		_hud_hp_label.text = "%d / %d HP" % [maxi(0, current), max_health]

	# Lag bar smoothly catches up
	if _hud_lag_bar != null:
		var tween := create_tween()
		tween.tween_interval(0.35)
		tween.tween_property(_hud_lag_bar, "value", float(current), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Heavy impact sound on taking damage
	var snd : Node = get_node_or_null("/root/UiSound")
	if snd != null and snd.has_method("play_hit"):
		snd.play_hit(0.08)

func _physics_process(delta: float) -> void:
	if _is_dying:
		return

	if not is_on_floor():
		velocity += get_gravity() * delta

	_update_target()
	if _player == null or not is_instance_valid(_player):
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var to_player_3d : Vector3 = _player.global_position - global_position
	var to_player_horiz := Vector3(to_player_3d.x, 0.0, to_player_3d.z)
	var dist_horiz : float = to_player_horiz.length()
	var dir_horiz : Vector3 = to_player_horiz.normalized() if dist_horiz > 0.01 else -transform.basis.z

	# Turn to face player smoothly
	if dist_horiz > 0.1:
		var target_yaw : float = atan2(dir_horiz.x, dir_horiz.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, rotation_speed * delta)

	# State Machine Logic
	match current_state:
		BossState.APPROACH:
			_attack_timer -= delta
			# Move into optimal engagement distance (7m to 12m)
			if dist_horiz > 7.5:
				velocity.x = dir_horiz.x * move_speed
				velocity.z = dir_horiz.z * move_speed
				_animate_walk_cycle(delta, true)
			elif dist_horiz < 4.5:
				# Back up slightly if player is too close
				velocity.x = -dir_horiz.x * move_speed * 0.6
				velocity.z = -dir_horiz.z * move_speed * 0.6
				_animate_walk_cycle(delta, true)
			else:
				velocity.x = 0.0
				velocity.z = 0.0
				_animate_walk_cycle(delta, false)

			if _attack_timer <= 0.0:
				_select_next_attack(dist_horiz)

		BossState.PATTERN_PLASMA_VOLLEY, BossState.PATTERN_ROCKET_SALVO, BossState.PATTERN_SEISMIC_STOMP:
			# Stationary during committed heavy attacks
			velocity.x = 0.0
			velocity.z = 0.0
			_animate_walk_cycle(delta, false)

	move_and_slide()

func _update_target() -> void:
	if _player != null and is_instance_valid(_player) and _player.is_inside_tree():
		return
	var found : Node = get_tree().get_first_node_in_group("player")
	if found != null and is_instance_valid(found):
		_player = found as Node3D

func _select_next_attack(dist_to_player: float) -> void:
	# Choose attack pattern intelligently based on distance
	var roll : float = randf()

	if dist_to_player <= 8.5 and _consecutive_stomps < 2:
		# Player is in close-quarters -> trigger Seismic Stomp
		_consecutive_stomps += 1
		_start_seismic_stomp()
	elif roll < 0.55:
		_consecutive_stomps = 0
		_start_plasma_volley()
	else:
		_consecutive_stomps = 0
		_start_rocket_salvo()

# -----------------------------------------------------------------------------
# Attack Pattern 1: Twin Heavy Plasma Volley
# -----------------------------------------------------------------------------
func _start_plasma_volley() -> void:
	current_state = BossState.PATTERN_PLASMA_VOLLEY
	var snd : Node = get_node_or_null("/root/UiSound")
	if snd != null and snd.has_method("play_turret_deploy"):
		snd.play_turret_deploy()

	# Recoil animation and alternating rapid cannon discharges
	var shots_count : int = 8
	var interval : float = 0.14
	for i in range(shots_count):
		get_tree().create_timer(i * interval).timeout.connect(func():
			if _is_dying or not is_inside_tree() or _player == null:
				return
			var is_left : bool = (i % 2 == 0)
			var cannon_node : Node3D = _left_cannon if is_left else _right_cannon
			var muzzle_pos : Vector3 = cannon_node.global_position + (-cannon_node.global_transform.basis.z * 1.2)
			var aim_target : Vector3 = _player.global_position + Vector3(0.0, 0.4, 0.0)
			var shot_dir : Vector3 = (aim_target - muzzle_pos).normalized()

			# Cannon recoil twitch
			var recoil_tween := create_tween()
			recoil_tween.tween_property(cannon_node, "position:z", 0.18, 0.04)
			recoil_tween.tween_property(cannon_node, "position:z", 0.0, 0.08)

			# Spawn heavy bullet
			var b : Area3D = BULLET_SCENE.instantiate()
			b.shooter = self
			b.direction = shot_dir
			b.damage = 8
			if "speed" in b:
				b.speed = 15.0
			get_parent().add_child(b)
			b.global_position = muzzle_pos

			var shoot_snd : Node = get_node_or_null("/root/UiSound")
			if shoot_snd != null and shoot_snd.has_method("play_enemy_shoot"):
				shoot_snd.play_enemy_shoot(0.12)
		)

	# Conclude attack and reset timer
	get_tree().create_timer(shots_count * interval + 0.6).timeout.connect(func():
		if not _is_dying:
			current_state = BossState.APPROACH
			_attack_timer = randf_range(min_attack_interval, max_attack_interval)
	)

# -----------------------------------------------------------------------------
# Attack Pattern 2: Micro-Missile Rocket Salvo
# -----------------------------------------------------------------------------
func _start_rocket_salvo() -> void:
	current_state = BossState.PATTERN_ROCKET_SALVO
	var snd : Node = get_node_or_null("/root/UiSound")
	if snd != null and snd.has_method("play_warning_tick"):
		snd.play_warning_tick()

	# Open missile pod hatch tween
	if _missile_pod != null:
		var hatch_tween := create_tween()
		hatch_tween.tween_property(_missile_pod, "scale:y", 1.25, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var rockets_count : int = 4
	var launch_interval : float = 0.2
	for i in range(rockets_count):
		get_tree().create_timer(0.3 + i * launch_interval).timeout.connect(func():
			if _is_dying or not is_inside_tree() or _player == null:
				return
			var muzzle_pos : Vector3 = _missile_pod.global_position + Vector3((i - 1.5) * 0.28, 0.35, -0.2)
			var base_dir : Vector3 = (_player.global_position + Vector3(0.0, 0.4, 0.0) - muzzle_pos).normalized()
			# Slight spread fan
			var spread_angle : float = deg_to_rad((i - 1.5) * 11.0)
			var rocket_dir : Vector3 = base_dir.rotated(Vector3.UP, spread_angle)

			var r : Area3D = ROCKET_SCENE.instantiate()
			if "shooter" in r:
				r.set("shooter", self)
			if "direction" in r:
				r.set("direction", rocket_dir)
			if "damage" in r:
				r.set("damage", 35) # High danger explosive warhead
			get_parent().add_child(r)
			r.global_position = muzzle_pos

			var launch_snd : Node = get_node_or_null("/root/UiSound")
			if launch_snd != null and launch_snd.has_method("play_rocket_launch"):
				launch_snd.play_rocket_launch()
		)

	get_tree().create_timer(0.3 + rockets_count * launch_interval + 0.8).timeout.connect(func():
		if _missile_pod != null and is_instance_valid(_missile_pod):
			var reset_tween := create_tween()
			reset_tween.tween_property(_missile_pod, "scale:y", 1.0, 0.2)
		if not _is_dying:
			current_state = BossState.APPROACH
			_attack_timer = randf_range(min_attack_interval, max_attack_interval)
	)

# -----------------------------------------------------------------------------
# Attack Pattern 3: Seismic Stomp (Earthquake Shockwave)
# -----------------------------------------------------------------------------
func _start_seismic_stomp() -> void:
	current_state = BossState.PATTERN_SEISMIC_STOMP
	var snd : Node = get_node_or_null("/root/UiSound")
	if snd != null and snd.has_method("play_hazard_pulse"):
		snd.play_hazard_pulse()

	# Expand telegraph ring on ground (7.5m radius)
	if _telegraph_mesh != null:
		_telegraph_mesh.visible = true
		_telegraph_mesh.scale = Vector3(0.01, 1.0, 0.01)
		var t_tween := create_tween()
		t_tween.tween_property(_telegraph_mesh, "scale", Vector3(7.5, 1.0, 7.5), 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Mech rears back before stomping
	if _model_root != null:
		var rear_tween := create_tween()
		rear_tween.tween_property(_model_root, "position:y", 0.5, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		rear_tween.parallel().tween_property(_model_root, "rotation_degrees:x", -15.0, 0.6)

	# Slam down at 0.75s
	get_tree().create_timer(0.75).timeout.connect(func():
		if _is_dying or not is_inside_tree():
			return
		if _telegraph_mesh != null:
			_telegraph_mesh.visible = false

		if _model_root != null:
			var slam_tween := create_tween()
			slam_tween.tween_property(_model_root, "position:y", 0.0, 0.1).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			slam_tween.parallel().tween_property(_model_root, "rotation_degrees:x", 8.0, 0.1)
			slam_tween.tween_property(_model_root, "rotation_degrees:x", 0.0, 0.3)

		# Screen shake & explosive impact
		var ss : Node = get_node_or_null("/root/ScreenShake")
		if ss != null and ss.has_method("shake"):
			ss.shake(0.95)
		var exp_snd : Node = get_node_or_null("/root/UiSound")
		if exp_snd != null and exp_snd.has_method("play_rocket_explode"):
			exp_snd.play_rocket_explode()

		_spawn_shockwave_particles(global_position)
		_apply_seismic_damage_and_knockback(7.5, 30)

		# Recovery delay
		get_tree().create_timer(0.8).timeout.connect(func():
			if not _is_dying:
				current_state = BossState.APPROACH
				_attack_timer = randf_range(min_attack_interval, max_attack_interval)
		)
	)

func _apply_seismic_damage_and_knockback(radius: float, damage_amount: int) -> void:
	var tree : SceneTree = get_tree()
	if tree == null:
		return

	var candidates : Array[Node3D] = []
	for p in tree.get_nodes_in_group("player"):
		if is_instance_valid(p) and p is Node3D:
			candidates.append(p as Node3D)
	for t in tree.get_nodes_in_group("turret"):
		if is_instance_valid(t) and t is Node3D:
			candidates.append(t as Node3D)

	for target in candidates:
		var d : float = global_position.distance_to(target.global_position)
		if d <= radius:
			var hc : HealthComponent = target.get_node_or_null("HealthComponent") as HealthComponent
			if hc == null and target.get_parent() != null:
				hc = target.get_parent().get_node_or_null("HealthComponent") as HealthComponent
			if hc != null:
				hc.decrease_health(damage_amount)

			if target is CharacterBody3D:
				var cb := target as CharacterBody3D
				var push_dir : Vector3 = (cb.global_position - global_position).normalized()
				push_dir.y = 0.0
				if push_dir.is_zero_approx():
					push_dir = Vector3.UP
				cb.velocity += push_dir * 9.0 + Vector3.UP * 5.5

func _spawn_shockwave_particles(pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.top_level = true
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = 0.55
	p.amount = 48

	var ring := CylinderMesh.new()
	ring.top_radius = 0.1
	ring.bottom_radius = 0.1
	ring.height = 0.05
	p.mesh = ring

	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_radius = 0.4
	p.emission_ring_inner_radius = 0.1
	p.emission_ring_height = 0.1
	p.direction = Vector3.UP
	p.spread = 90.0
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 9.0
	p.gravity = Vector3(0.0, -9.8, 0.0)
	p.color = Color(1.0, 0.35, 0.15, 0.9)

	get_parent().add_child(p)
	p.global_position = pos + Vector3(0.0, 0.1, 0.0)
	p.restart()

	get_tree().create_timer(1.0).timeout.connect(p.queue_free)

# -----------------------------------------------------------------------------
# Walk Cycle & Death Animation
# -----------------------------------------------------------------------------
func _animate_walk_cycle(delta: float, is_walking: bool) -> void:
	if _model_root == null or _leg_left == null or _leg_right == null:
		return

	if is_walking:
		_walk_cycle_time += delta * 5.0
		var step_bob : float = sin(_walk_cycle_time * 2.0) * 0.06
		_model_root.position.y = step_bob
		_leg_left.rotation_degrees.x = sin(_walk_cycle_time) * 18.0
		_leg_right.rotation_degrees.x = -sin(_walk_cycle_time) * 18.0
	else:
		_model_root.position.y = lerpf(_model_root.position.y, 0.0, delta * 6.0)
		_leg_left.rotation_degrees.x = lerpf(_leg_left.rotation_degrees.x, 0.0, delta * 6.0)
		_leg_right.rotation_degrees.x = lerpf(_leg_right.rotation_degrees.x, 0.0, delta * 6.0)

func _on_death() -> void:
	if _is_dying:
		return
	_is_dying = true
	current_state = BossState.DYING

	remove_from_group("enemy")
	remove_from_group("boss")
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO

	# Victory audio & screen rumble
	var snd : Node = get_node_or_null("/root/UiSound")
	if snd != null and snd.has_method("play_enemy_death"):
		snd.play_enemy_death(0.02)
	var ss : Node = get_node_or_null("/root/ScreenShake")
	if ss != null and ss.has_method("shake"):
		ss.shake(1.0)

	# Fade out Boss HUD
	if _boss_hud != null:
		var hud_tween := create_tween()
		hud_tween.tween_property(_boss_hud, "scale", Vector2(1.05, 1.05), 0.1)
		hud_tween.parallel().tween_property(_boss_hud, "modulate:a", 0.0, 0.6)
		hud_tween.tween_callback(_boss_hud.queue_free)

	# Cascading explosions across mech chassis
	var expl_offsets := [
		Vector3(-0.6, 1.8, 0.2),
		Vector3(0.6, 1.8, -0.2),
		Vector3(0.0, 2.5, 0.1),
		Vector3(-0.4, 0.8, -0.3),
		Vector3(0.4, 0.8, 0.3),
		Vector3(0.0, 1.5, 0.0)
	]

	for i in range(expl_offsets.size()):
		get_tree().create_timer(i * 0.25).timeout.connect(func():
			if not is_inside_tree():
				return
			_spawn_death_burst(global_position + expl_offsets[i])
			var s : Node = get_node_or_null("/root/UiSound")
			if s != null and s.has_method("play_rocket_explode"):
				s.play_rocket_explode(0.08)
		)

	# Collapse model & notify
	if _model_root != null:
		var death_tween := create_tween()
		death_tween.tween_interval(1.2)
		death_tween.tween_property(_model_root, "position:y", -0.4, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		death_tween.parallel().tween_property(_model_root, "rotation_degrees:x", -35.0, 0.5)
		death_tween.parallel().tween_property(_model_root, "scale", Vector3.ZERO, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		death_tween.tween_callback(func():
			boss_defeated.emit(self)
			queue_free()
		)
	else:
		boss_defeated.emit(self)
		queue_free()

func _spawn_death_burst(pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.top_level = true
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = 0.5
	p.amount = 28
	var b := BoxMesh.new()
	b.size = Vector3(0.12, 0.12, 0.12)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.45, 0.1)
	b.material = mat
	p.mesh = b
	p.spread = 180.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.5
	get_parent().add_child(p)
	p.global_position = pos
	p.restart()
	get_tree().create_timer(0.6).timeout.connect(p.queue_free)

# -----------------------------------------------------------------------------
# Procedural 3D Mech Assembly
# -----------------------------------------------------------------------------
func _build_procedural_mech_model() -> void:
	_model_root = Node3D.new()
	_model_root.name = "ModelRoot"
	add_child(_model_root)

	# Dark carbon chassis material
	var carbon_mat := StandardMaterial3D.new()
	carbon_mat.albedo_color = Color(0.12, 0.14, 0.17) # Charcoal military plate
	carbon_mat.metallic = 0.75
	carbon_mat.roughness = 0.35

	# Heavy steel joint material
	var steel_mat := StandardMaterial3D.new()
	steel_mat.albedo_color = Color(0.24, 0.26, 0.3)
	steel_mat.metallic = 0.9
	steel_mat.roughness = 0.2

	# Crimson glowing emissive visor/reactor material
	var crimson_emissive := StandardMaterial3D.new()
	crimson_emissive.albedo_color = Color(1.0, 0.15, 0.1)
	crimson_emissive.emission_enabled = true
	crimson_emissive.emission = Color(1.0, 0.15, 0.1)
	crimson_emissive.emission_energy_multiplier = 3.2

	# Orange hazard accent material
	var hazard_mat := StandardMaterial3D.new()
	hazard_mat.albedo_color = Color(0.95, 0.62, 0.12)
	hazard_mat.roughness = 0.4

	# 1. Main Core Torso
	_torso = MeshInstance3D.new()
	var torso_mesh := BoxMesh.new()
	torso_mesh.size = Vector3(1.2, 0.9, 0.9)
	_torso.mesh = torso_mesh
	_torso.material_override = carbon_mat
	_torso.position = Vector3(0.0, 1.8, 0.0)
	_model_root.add_child(_torso)

	# Armor Chest Plate
	var chest_plate := MeshInstance3D.new()
	var chest_mesh := BoxMesh.new()
	chest_mesh.size = Vector3(1.0, 0.55, 0.25)
	chest_plate.mesh = chest_mesh
	chest_plate.material_override = hazard_mat
	chest_plate.position = Vector3(0.0, -0.1, -0.42)
	_torso.add_child(chest_plate)

	# 2. Glowing Visor Eye
	_visor = MeshInstance3D.new()
	var visor_mesh := BoxMesh.new()
	visor_mesh.size = Vector3(0.65, 0.12, 0.1)
	_visor.mesh = visor_mesh
	_visor.material_override = crimson_emissive
	_visor.position = Vector3(0.0, 0.2, -0.47)
	_torso.add_child(_visor)

	# 3. Shoulder Cannons (Left and Right)
	_left_cannon = _build_cannon(carbon_mat, steel_mat, crimson_emissive, Vector3(-0.85, 0.25, -0.1))
	_torso.add_child(_left_cannon)

	_right_cannon = _build_cannon(carbon_mat, steel_mat, crimson_emissive, Vector3(0.85, 0.25, -0.1))
	_torso.add_child(_right_cannon)

	# 4. Missile Pod Battery on upper chassis
	_missile_pod = Node3D.new()
	_missile_pod.position = Vector3(0.0, 0.65, 0.05)
	_torso.add_child(_missile_pod)

	var pod_box := MeshInstance3D.new()
	var pod_mesh := BoxMesh.new()
	pod_mesh.size = Vector3(0.85, 0.35, 0.55)
	pod_box.mesh = pod_mesh
	pod_box.material_override = carbon_mat
	_missile_pod.add_child(pod_box)

	# 4 Missile Launcher Tubes
	for i in 4:
		var tube := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.065
		cyl.bottom_radius = 0.065
		cyl.height = 0.35
		tube.mesh = cyl
		tube.material_override = steel_mat
		tube.rotation_degrees.x = 90.0
		tube.position = Vector3((i - 1.5) * 0.2, 0.0, -0.15)
		_missile_pod.add_child(tube)

	# 5. Dual Exhaust Stacks with smoke
	_build_exhaust_stacks(_torso, steel_mat)

	# 6. Bipedal Hydraulic Legs
	_leg_left = _build_leg(carbon_mat, steel_mat, -0.4)
	_model_root.add_child(_leg_left)

	_leg_right = _build_leg(carbon_mat, steel_mat, 0.4)
	_model_root.add_child(_leg_right)

	# 7. Telegraph Ground Ring (Hidden initially)
	_telegraph_mesh = MeshInstance3D.new()
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 1.0
	ring_mesh.bottom_radius = 1.0
	ring_mesh.height = 0.04
	_telegraph_mesh.mesh = ring_mesh
	var tel_mat := StandardMaterial3D.new()
	tel_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tel_mat.albedo_color = Color(1.0, 0.15, 0.1, 0.4)
	tel_mat.emission_enabled = true
	tel_mat.emission = Color(1.0, 0.15, 0.1)
	tel_mat.emission_energy_multiplier = 2.0
	_telegraph_mesh.material_override = tel_mat
	_telegraph_mesh.position = Vector3(0.0, 0.05, 0.0)
	_telegraph_mesh.visible = false
	add_child(_telegraph_mesh)

func _build_cannon(main_mat: Material, joint_mat: Material, glow_mat: Material, local_pos: Vector3) -> Node3D:
	var cannon_root := Node3D.new()
	cannon_root.position = local_pos

	# Shoulder joint sphere
	var joint := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.22
	sph.height = 0.44
	joint.mesh = sph
	joint.material_override = joint_mat
	cannon_root.add_child(joint)

	# Barrel mount
	var barrel := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.08
	cyl.bottom_radius = 0.1
	cyl.height = 0.9
	barrel.mesh = cyl
	barrel.material_override = main_mat
	barrel.rotation_degrees.x = 90.0
	barrel.position = Vector3(0.0, 0.0, -0.45)
	cannon_root.add_child(barrel)

	# Glowing Muzzle Tip
	var muzzle := MeshInstance3D.new()
	var tip_cyl := CylinderMesh.new()
	tip_cyl.top_radius = 0.09
	tip_cyl.bottom_radius = 0.09
	tip_cyl.height = 0.12
	muzzle.mesh = tip_cyl
	muzzle.material_override = glow_mat
	muzzle.rotation_degrees.x = 90.0
	muzzle.position = Vector3(0.0, 0.0, -0.92)
	cannon_root.add_child(muzzle)

	return cannon_root

func _build_leg(main_mat: Material, joint_mat: Material, offset_x: float) -> Node3D:
	var leg_root := Node3D.new()
	leg_root.position = Vector3(offset_x, 1.35, 0.0)

	# Hip joint
	var hip := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.18
	sph.height = 0.36
	hip.mesh = sph
	hip.material_override = joint_mat
	leg_root.add_child(hip)

	# Thigh
	var thigh := MeshInstance3D.new()
	var thigh_mesh := BoxMesh.new()
	thigh_mesh.size = Vector3(0.24, 0.65, 0.28)
	thigh.mesh = thigh_mesh
	thigh.material_override = main_mat
	thigh.position = Vector3(0.0, -0.35, 0.0)
	leg_root.add_child(thigh)

	# Knee Armor Plate
	var knee := MeshInstance3D.new()
	var knee_mesh := BoxMesh.new()
	knee_mesh.size = Vector3(0.28, 0.22, 0.14)
	knee.mesh = knee_mesh
	knee.material_override = joint_mat
	knee.position = Vector3(0.0, -0.65, -0.15)
	leg_root.add_child(knee)

	# Shin
	var shin := MeshInstance3D.new()
	var shin_mesh := BoxMesh.new()
	shin_mesh.size = Vector3(0.22, 0.65, 0.26)
	shin.mesh = shin_mesh
	shin.material_override = main_mat
	shin.position = Vector3(0.0, -0.95, 0.0)
	leg_root.add_child(shin)

	# Heavy Foot Pad
	var foot := MeshInstance3D.new()
	var foot_mesh := BoxMesh.new()
	foot_mesh.size = Vector3(0.36, 0.14, 0.55)
	foot.mesh = foot_mesh
	foot.material_override = main_mat
	foot.position = Vector3(0.0, -1.3, -0.1)
	leg_root.add_child(foot)

	return leg_root

func _build_exhaust_stacks(parent_torso: Node3D, pipe_mat: Material) -> void:
	for side in [-0.35, 0.35]:
		var pipe := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.075
		cyl.bottom_radius = 0.075
		cyl.height = 0.55
		pipe.mesh = cyl
		pipe.material_override = pipe_mat
		pipe.rotation_degrees.x = -15.0
		pipe.position = Vector3(side, 0.45, 0.45)
		parent_torso.add_child(pipe)

		var p := CPUParticles3D.new()
		p.name = "ExhaustSmoke"
		p.emitting = true
		p.lifetime = 0.65
		p.amount = 14
		p.speed_scale = 1.0
		p.direction = Vector3(0.0, 1.0, 0.4).normalized()
		p.spread = 15.0
		p.initial_velocity_min = 1.2
		p.initial_velocity_max = 2.0
		p.scale_amount_min = 0.08
		p.scale_amount_max = 0.22
		p.color = Color(0.2, 0.2, 0.22, 0.55)
		pipe.add_child(p)
		p.position = Vector3(0.0, 0.3, 0.0)
