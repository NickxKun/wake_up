extends Node

## Child of the player. Handles shooting, alt-fire, dual weapon inventory, ammo, and minimal death handling.
## Slot 1: Basic Pistol (infinite ammo, always available)
## Slot 2: Special Weapon (Shotgun, Sniper, Double Pistols, Rocket Launcher) with limited ammo

signal weapon_equipped(weapon_type: int, current_ammo: int, max_ammo: int)
signal ammo_changed(weapon_type: int, current_ammo: int, max_ammo: int)
signal weapon_switched(active_slot: int, weapon_type: int, current_ammo: int, max_ammo: int)

enum WeaponType {
	BASIC = 0,
	SHOTGUN = 1,
	SNIPER = 2,
	DOUBLE_PISTOLS = 3,
	ROCKET_LAUNCHER = 4,
	WRENCH = 5,
}

const SLOT_BASIC : int = 1
const SLOT_SPECIAL : int = 2
const BASIC_COOLDOWN : float = 0.25

const BULLET_SCENE : PackedScene = preload("res://scenes/projectiles/bullet.tscn")
const ROCKET_SCENE : PackedScene = preload("res://scenes/projectiles/rocket.tscn")
const GRENADE_SCENE : PackedScene = preload("res://scenes/projectiles/grenade.tscn")
const SENTRY_TURRET_SCENE : PackedScene = preload("res://scenes/entities/sentry_turret.tscn")
const HEAL_WAVE_SCENE : PackedScene = preload("res://scenes/effects/heal_wave.tscn")

## Collision layers tested by mouse aim raycast:
## Layer 1 = World geometry (floors, walls, cover, ledges)
## Layer 2 = Hostile entities (enemies, targets, airborne/jumping hostiles)
## Layer 4 = Drivable vehicles
const AIM_COLLISION_MASK : int = 1 | 2 | 4
const AIM_RAY_LENGTH : float = 300.0
const MUZZLE_HEIGHT : float = 0.3

## Base damage dealt by each player shot (enemies have 100 max HP).
@export var bullet_damage : int = 40
## Chance for a shot to be a Critical Hit that deals lethal insta-kill damage.
@export var crit_chance : float = 0.25
## Seconds the body takes to tip over and lie flat on death.
@export var death_tip_duration : float = 0.4
## Raise the lying mesh by this much so it rests on the floor instead of sinking into it.
@export var death_lift : float = 0.1

@export var shoot_cooldown : float = 0.25
@export var input_shoot : String = "shoot"
@export var input_alt_shoot : String = "alt_shoot"

var can_shoot : bool = true

# Dual weapon inventory state
var starter_slot1_weapon : int = WeaponType.BASIC
var active_slot : int = SLOT_BASIC
var special_weapon : int = WeaponType.BASIC
var special_ammo : int = 0
var special_max_ammo : int = 0
var special_cooldown : float = 0.25
var active_turrets : Array[Node3D] = []

var current_weapon : int = WeaponType.BASIC:
	set(value):
		current_weapon = value
		if value == WeaponType.BASIC and current_ammo <= 0:
			special_weapon = WeaponType.BASIC
			special_ammo = 0
			special_max_ammo = 0
			active_slot = SLOT_BASIC

var current_ammo : int = 0
var max_ammo : int = 0
var infinite_ammo : bool = false
var next_shot_is_crit : bool = false

var _cooldown_left : float = 0.0
var _last_hurt_sound_time : float = -1.0
var _last_shield_sound_time : float = -1.0
var _camera_tween : Tween = null
var _laser_sight : MeshInstance3D = null
var _shield_bubble : MeshInstance3D = null
var _shield_tween : Tween = null
const DEFAULT_CAM_SIZE : float = 4.0
const SNIPER_CAM_SIZE : float = 5.8

@onready var player : CharacterBody3D = get_parent()
@onready var player_mesh : Node3D = player.get_node("player")
@onready var player_animation : Node = player.get_node_or_null("PlayerAnimation")

func _ready() -> void:
	player.add_to_group("player")
	var char_data : Node = get_node_or_null("/root/CharacterData")
	if char_data != null:
		if "current_class" in char_data:
			apply_character_class(int(char_data.get("current_class")))
		if char_data.has_signal("class_changed") and not char_data.is_connected("class_changed", Callable(self, "_on_class_changed_runtime")):
			char_data.connect("class_changed", Callable(self, "_on_class_changed_runtime"))
	_connect_health.call_deferred()
	_setup_laser_sight.call_deferred()
	_roll_next_crit()

func _process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	_update_laser_sight()

func _unhandled_input(event: InputEvent) -> void:
	if not can_shoot:
		return

	# Weapon slot switching inputs (Key 1 = Basic Pistol, Key 2 = Special Weapon, Key Q = Quick Toggle)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			if switch_slot(SLOT_BASIC):
				get_viewport().set_input_as_handled()
				return
		elif event.keycode == KEY_2:
			if switch_slot(SLOT_SPECIAL):
				get_viewport().set_input_as_handled()
				return
		elif event.keycode == KEY_Q:
			if has_special_weapon():
				var target_slot : int = SLOT_BASIC if active_slot == SLOT_SPECIAL else SLOT_SPECIAL
				if switch_slot(target_slot):
					get_viewport().set_input_as_handled()
					return

	# Mouse wheel weapon slot switching
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if has_special_weapon():
				var target_slot : int = SLOT_BASIC if active_slot == SLOT_SPECIAL else SLOT_SPECIAL
				if switch_slot(target_slot):
					get_viewport().set_input_as_handled()
					return

	if _cooldown_left > 0.0:
		return

	# Alt Fire: Right Mouse Button (fires in player horizontal facing direction)
	if Input.is_action_just_pressed(input_alt_shoot) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		_fire(true)
		get_viewport().set_input_as_handled()
		return

	# Primary Fire: Left Mouse Button (aims towards cursor on ground/target)
	if Input.is_action_just_pressed(input_shoot) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		_fire(false)
		get_viewport().set_input_as_handled()
		return

## Returns true if the player can pick up a new special weapon from the dispenser.
## Blocked if the player already has a special weapon with remaining ammo.
func can_pickup_weapon() -> bool:
	return special_weapon == WeaponType.BASIC or special_ammo <= 0

## Returns true if the player currently has a valid special weapon in Slot 2 with ammo.
func has_special_weapon() -> bool:
	return special_weapon != WeaponType.BASIC and special_ammo > 0

## Equips a special weapon into Slot 2 with its allocated ammo capacity and equips it.
func equip_weapon(type: int, force: bool = false) -> bool:
	if not force and not can_pickup_weapon():
		return false

	special_weapon = type
	match type:
		WeaponType.SHOTGUN:
			special_max_ammo = 10
			special_cooldown = 0.55
		WeaponType.SNIPER:
			special_max_ammo = 8
			special_cooldown = 0.75
		WeaponType.DOUBLE_PISTOLS:
			special_max_ammo = 30
			special_cooldown = 0.14
		WeaponType.ROCKET_LAUNCHER:
			special_max_ammo = 5
			special_cooldown = 0.85
		_:
			special_weapon = WeaponType.BASIC
			special_max_ammo = 0
			special_cooldown = BASIC_COOLDOWN

	special_ammo = special_max_ammo
	active_slot = SLOT_SPECIAL if special_weapon != WeaponType.BASIC else SLOT_BASIC
	_sync_active_slot_state()

	if player_animation != null and player_animation.has_method("set_weapon_model"):
		player_animation.set_weapon_model(current_weapon)
	_update_weapon_crit_glow()

	weapon_equipped.emit(current_weapon, current_ammo, max_ammo)
	_notify_hud()
	_update_camera_sniper_zoom()
	return true

## Alias for equip_weapon with optional force parameter.
func equip_special_weapon(type: int, force: bool = true) -> bool:
	return equip_weapon(type, force)

## Switches between weapon slots (SLOT_BASIC = 1, SLOT_SPECIAL = 2).
func switch_slot(slot: int) -> bool:
	if slot == active_slot:
		return false
	if slot == SLOT_SPECIAL:
		if not has_special_weapon():
			return false
		active_slot = SLOT_SPECIAL
	else:
		active_slot = SLOT_BASIC

	_sync_active_slot_state()

	if player_animation != null and player_animation.has_method("set_weapon_model"):
		player_animation.set_weapon_model(current_weapon)
	_update_weapon_crit_glow()

	_notify_hud()

	var snd : Node = get_node_or_null("/root/UiSound")
	if snd != null and snd.has_method("play_button_click"):
		snd.play_button_click()

	weapon_switched.emit(active_slot, current_weapon, current_ammo, max_ammo)
	_update_camera_sniper_zoom()
	return true

func _get_starter_cooldown(w_type: int) -> float:
	match w_type:
		WeaponType.WRENCH:
			return 0.35
		WeaponType.SHOTGUN:
			return 0.48 # Medic starter shotgun pump rate
		WeaponType.SNIPER:
			return 0.70 # Scout starter sniper low fire rate
		_:
			return BASIC_COOLDOWN # 0.25

func _sync_active_slot_state() -> void:
	if active_slot == SLOT_SPECIAL and special_weapon != WeaponType.BASIC and special_weapon != WeaponType.WRENCH and special_ammo > 0:
		current_weapon = special_weapon
		current_ammo = special_ammo
		max_ammo = special_max_ammo
		shoot_cooldown = special_cooldown
	else:
		active_slot = SLOT_BASIC
		current_weapon = starter_slot1_weapon
		current_ammo = 0
		max_ammo = 0
		shoot_cooldown = _get_starter_cooldown(starter_slot1_weapon)

## Discharges the active weapon. If is_alt_fire is true, shoots along the player's facing direction.
func _fire(is_alt_fire: bool) -> void:
	_cooldown_left = shoot_cooldown

	var center : Vector3 = player.global_position + Vector3(0.0, MUZZLE_HEIGHT, 0.0)
	var direction : Vector3 = Vector3.FORWARD

	if is_alt_fire:
		# Alt fire: strictly horizontal facing direction, ignoring ground raycast
		var facing : Vector3 = player.global_transform.basis.z
		facing.y = 0.0
		direction = facing.normalized()
		if direction.is_zero_approx():
			direction = Vector3.FORWARD
	else:
		# Primary fire: aimed at mouse raycast intersection
		direction = _get_aim_direction(center)

	var muzzle : Vector3 = center + direction * 0.4
	if player_animation != null:
		muzzle = player_animation.play_shoot(direction)
		if not is_alt_fire:
			direction = _get_aim_direction(muzzle)

	# Execute firing pattern per weapon type
	match current_weapon:
		WeaponType.SHOTGUN:
			_fire_shotgun(muzzle, direction)
		WeaponType.SNIPER:
			_fire_sniper(muzzle, direction)
		WeaponType.DOUBLE_PISTOLS:
			_fire_double_pistols(muzzle, direction)
		WeaponType.ROCKET_LAUNCHER:
			_fire_rocket(muzzle, direction)
		WeaponType.WRENCH:
			_fire_wrench(muzzle, direction, is_alt_fire)
		_:
			_fire_basic(muzzle, direction)

	# Decrement special weapon ammo when firing special slot
	if active_slot == SLOT_SPECIAL and special_weapon != WeaponType.BASIC and special_weapon != WeaponType.WRENCH:
		if not infinite_ammo:
			special_ammo -= 1
		current_ammo = special_ammo
		ammo_changed.emit(current_weapon, current_ammo, max_ammo)
		_notify_hud()

		# Exhausted ammo: automatically revert to starter weapon!
		if not infinite_ammo and special_ammo <= 0:
			special_weapon = starter_slot1_weapon
			special_ammo = 0
			special_max_ammo = 0
			active_slot = SLOT_BASIC
			_sync_active_slot_state()
			if player_animation != null and player_animation.has_method("set_weapon_model"):
				player_animation.set_weapon_model(starter_slot1_weapon)
			_notify_hud()
			_update_camera_sniper_zoom()

## Basic Pistol: single standard bullet with 25% crit chance.
func _fire_basic(muzzle: Vector3, direction: Vector3) -> void:
	var snd : Node = get_node_or_null("/root/UiSound")
	if snd != null and snd.has_method("play_shoot"):
		snd.play_shoot()

	var is_crit : bool = next_shot_is_crit
	var bullet : Area3D = BULLET_SCENE.instantiate()
	bullet.shooter = player
	bullet.direction = direction
	bullet.damage = 999 if is_crit else bullet_damage
	bullet.is_critical = is_crit
	bullet.decal_scale = 0.32
	player.get_parent().add_child(bullet)
	bullet.global_position = muzzle

	_roll_next_crit()

## Shotgun: multi-pellet conical blast. Medic starts with compact shotgun (low range, good damage).
func _fire_shotgun(muzzle: Vector3, direction: Vector3) -> void:
	var snd : Node = get_node_or_null("/root/UiSound")
	if snd != null and snd.has_method("play_shotgun"):
		snd.play_shotgun()

	var is_starter : bool = (active_slot == SLOT_BASIC)
	var pellet_count : int = 5 if is_starter else 6
	var spread_angle_rad : float = deg_to_rad(8.0 if is_starter else 6.5)
	var pellet_damage : int = 16 if is_starter else 22
	var pellet_lifetime : float = 0.35 if is_starter else 0.65

	for _i in range(pellet_count):
		var jitter_yaw : float = randf_range(-spread_angle_rad, spread_angle_rad)
		var jitter_pitch : float = randf_range(-spread_angle_rad * 0.7, spread_angle_rad * 0.7)
		var pellet_dir : Vector3 = direction.rotated(Vector3.UP, jitter_yaw)
		var right_axis : Vector3 = direction.cross(Vector3.UP).normalized()
		if not right_axis.is_zero_approx():
			pellet_dir = pellet_dir.rotated(right_axis, jitter_pitch)

		var bullet : Area3D = BULLET_SCENE.instantiate()
		bullet.shooter = player
		bullet.direction = pellet_dir.normalized()
		bullet.damage = pellet_damage
		bullet.speed = 18.0
		bullet.lifetime = pellet_lifetime
		bullet.decal_scale = 0.20
		player.get_parent().add_child(bullet)
		bullet.global_position = muzzle

## Sniper: single hyper-velocity piercing round. Scout starts with marksman rifle (low fire rate, high damage).
func _fire_sniper(muzzle: Vector3, direction: Vector3) -> void:
	var snd : Node = get_node_or_null("/root/UiSound")
	if snd != null and snd.has_method("play_sniper"):
		snd.play_sniper()

	var is_starter : bool = (active_slot == SLOT_BASIC)
	var bullet : Area3D = BULLET_SCENE.instantiate()
	bullet.shooter = player
	bullet.direction = direction
	bullet.damage = 110 if is_starter else 220 # High single-shot damage (110) vs anti-materiel (220)
	bullet.speed = 55.0 if is_starter else 65.0
	bullet.lifetime = 2.2 if is_starter else 2.5
	bullet.scale = Vector3(1.3, 1.3, 1.3) if is_starter else Vector3(1.5, 1.5, 1.5)
	bullet.decal_scale = 0.45 if is_starter else 0.55
	player.get_parent().add_child(bullet)
	bullet.global_position = muzzle

## Double Pistols: twin parallel muzzle bursts.
func _fire_double_pistols(muzzle: Vector3, direction: Vector3) -> void:
	var snd : Node = get_node_or_null("/root/UiSound")
	if snd != null and snd.has_method("play_double_pistols"):
		snd.play_double_pistols()

	var right_vec : Vector3 = direction.cross(Vector3.UP).normalized() * 0.08
	var is_crit : bool = next_shot_is_crit

	for offset_mult in [-1.0, 1.0]:
		var bullet : Area3D = BULLET_SCENE.instantiate()
		bullet.shooter = player
		bullet.direction = direction
		bullet.damage = 999 if is_crit else 30
		bullet.is_critical = is_crit
		bullet.speed = 22.0
		bullet.lifetime = 1.2
		bullet.decal_scale = 0.32
		player.get_parent().add_child(bullet)
		bullet.global_position = muzzle + right_vec * offset_mult

	_roll_next_crit()

func _roll_next_crit() -> void:
	next_shot_is_crit = randf() < crit_chance
	_update_weapon_crit_glow()

func _update_weapon_crit_glow() -> void:
	if player_animation != null and player_animation.has_method("get_gun_model"):
		var gun_model : Node3D = player_animation.get_gun_model()
		if gun_model != null and gun_model.has_method("set_critical_glow"):
			gun_model.call("set_critical_glow", next_shot_is_crit)

## Rocket Launcher: fires high-explosive rocket.
func _fire_rocket(muzzle: Vector3, direction: Vector3) -> void:
	var snd : Node = get_node_or_null("/root/UiSound")
	if snd != null and snd.has_method("play_rocket_launch"):
		snd.play_rocket_launch()

	var rocket : Area3D = ROCKET_SCENE.instantiate()
	rocket.shooter = player
	rocket.direction = direction
	player.get_parent().add_child(rocket)
	rocket.global_position = muzzle

## Returns human-readable active weapon name.
func get_weapon_name() -> String:
	if active_slot == SLOT_BASIC:
		return _get_slot1_name()
	match current_weapon:
		WeaponType.SHOTGUN:
			return "SHOTGUN"
		WeaponType.SNIPER:
			return "SNIPER RIFLE"
		WeaponType.DOUBLE_PISTOLS:
			return "DOUBLE PISTOLS"
		WeaponType.ROCKET_LAUNCHER:
			return "ROCKET LAUNCHER"
		WeaponType.WRENCH:
			return "TITANIUM WRENCH"
		_:
			return "BASIC PISTOL"

## Returns human-readable special weapon name.
func get_special_weapon_name() -> String:
	match special_weapon:
		WeaponType.SHOTGUN:
			return "SHOTGUN"
		WeaponType.SNIPER:
			return "SNIPER RIFLE"
		WeaponType.DOUBLE_PISTOLS:
			return "DOUBLE PISTOLS"
		WeaponType.ROCKET_LAUNCHER:
			return "ROCKET LAUNCHER"
		_:
			return "NONE"

func _get_slot1_name() -> String:
	match starter_slot1_weapon:
		WeaponType.WRENCH:
			return "TITANIUM WRENCH"
		WeaponType.SHOTGUN:
			return "BIO-SHOTGUN"
		WeaponType.SNIPER:
			return "MARKSMAN RIFLE"
		_:
			return "BASIC PISTOL"

func _notify_hud() -> void:
	var hud : Node = get_node_or_null("/root/PlayerHealthHud")
	if hud == null:
		return
	if hud.has_method("update_dual_weapons"):
		hud.update_dual_weapons(
			active_slot,
			_get_slot1_name(),
			0,
			0,
			get_special_weapon_name(),
			special_ammo,
			special_max_ammo
		)
	elif hud.has_method("update_weapon_ammo"):
		hud.update_weapon_ammo(get_weapon_name(), current_ammo, max_ammo)

## Direction from the muzzle toward the mouse position in 3D world space.
func _get_aim_direction(muzzle: Vector3) -> Vector3:
	var facing : Vector3 = player.global_transform.basis.z
	facing.y = 0.0
	facing = facing.normalized()
	var viewport : Viewport = player.get_viewport()
	var camera : Camera3D = viewport.get_camera_3d()
	if camera == null:
		return facing
	var mouse_position : Vector2 = viewport.get_mouse_position()
	var ray_origin : Vector3 = camera.project_ray_origin(mouse_position)
	var ray_end : Vector3 = ray_origin + camera.project_ray_normal(mouse_position) * AIM_RAY_LENGTH
	var query : PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_origin, ray_end, AIM_COLLISION_MASK)
	query.exclude = [player.get_rid()]
	var hit : Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return facing
	var direction : Vector3 = hit.position - muzzle
	if direction.length_squared() < 0.0001:
		return facing
	return direction.normalized()

func _connect_health() -> void:
	if player == null:
		return
	var health_component : HealthComponent = player.get_node_or_null("HealthComponent")
	var attempts : int = 0
	while health_component == null and attempts < 20 and is_inside_tree() and get_tree() != null:
		await get_tree().process_frame
		if not is_inside_tree() or player == null:
			return
		health_component = player.get_node_or_null("HealthComponent")
		attempts += 1
	if health_component == null:
		return
	if not health_component.health_depleted.is_connected(_on_player_died):
		health_component.health_depleted.connect(_on_player_died)
	if not health_component.health_changed.is_connected(_on_player_health_changed):
		health_component.health_changed.connect(_on_player_health_changed)
	if health_component.has_signal("shield_changed") and not health_component.shield_changed.is_connected(_on_player_shield_changed):
		health_component.shield_changed.connect(_on_player_shield_changed)
	if health_component.has_signal("shield_broken") and not health_component.shield_broken.is_connected(_on_player_shield_broken):
		health_component.shield_broken.connect(_on_player_shield_broken)
	if health_component.has_signal("shield_regen_started") and not health_component.shield_regen_started.is_connected(_on_player_shield_regen_started):
		health_component.shield_regen_started.connect(_on_player_shield_regen_started)
	if health_component.has_signal("shield_full") and not health_component.shield_full.is_connected(_on_player_shield_full):
		health_component.shield_full.connect(_on_player_shield_full)

func _setup_shield_visual() -> void:
	if _shield_bubble != null or player == null:
		return
	_shield_bubble = MeshInstance3D.new()
	_shield_bubble.name = "ShieldBubble"
	var sphere := SphereMesh.new()
	sphere.radius = 0.38
	sphere.height = 0.76
	sphere.radial_segments = 16
	sphere.rings = 8
	_shield_bubble.mesh = sphere
	
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.2, 0.85, 1.0, 0.0)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_shield_bubble.material_override = mat
	_shield_bubble.position = Vector3(0.0, 0.35, 0.0)
	_shield_bubble.visible = false
	player.add_child(_shield_bubble)

func _flash_shield_bubble(is_broken: bool) -> void:
	if _shield_bubble == null:
		_setup_shield_visual()
	if _shield_bubble == null:
		return
	var mat : StandardMaterial3D = _shield_bubble.material_override as StandardMaterial3D
	if mat == null:
		return
	
	if _shield_tween != null and _shield_tween.is_valid():
		_shield_tween.kill()
	
	_shield_bubble.visible = true
	_shield_bubble.scale = Vector3.ONE
	
	_shield_tween = create_tween()
	if is_broken:
		mat.albedo_color = Color(0.9, 0.95, 1.0, 0.85)
		_shield_tween.set_parallel(true)
		_shield_tween.tween_property(mat, "albedo_color", Color(0.2, 0.6, 1.0, 0.0), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_shield_tween.tween_property(_shield_bubble, "scale", Vector3(1.4, 1.4, 1.4), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		mat.albedo_color = Color(0.25, 0.9, 1.0, 0.55)
		_shield_tween.set_parallel(true)
		_shield_tween.tween_property(mat, "albedo_color", Color(0.2, 0.85, 1.0, 0.0), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_shield_tween.tween_property(_shield_bubble, "scale", Vector3(1.12, 1.12, 1.12), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	_shield_tween.chain().tween_callback(func() -> void:
		if is_instance_valid(_shield_bubble):
			_shield_bubble.visible = false
			_shield_bubble.scale = Vector3.ONE
	)

func _on_player_shield_changed(new_shield: float, old_shield: float) -> void:
	if new_shield < old_shield and new_shield > 0.0:
		var now : float = Time.get_ticks_msec() / 1000.0
		if now - _last_shield_sound_time >= 0.15:
			_last_shield_sound_time = now
			var snd : Node = get_node_or_null("/root/UiSound")
			if snd != null and snd.has_method("play_shield_hit"):
				snd.play_shield_hit()
		_flash_shield_bubble(false)

func _on_player_shield_broken() -> void:
	var snd : Node = get_node_or_null("/root/UiSound")
	if snd != null and snd.has_method("play_shield_break"):
		snd.play_shield_break()
	
	var ss : Node = get_node_or_null("/root/ScreenShake")
	if ss != null and ss.has_method("shake"):
		ss.shake(0.25)
	
	_flash_shield_bubble(true)

func _on_player_shield_regen_started() -> void:
	var snd : Node = get_node_or_null("/root/UiSound")
	if snd != null and snd.has_method("play_shield_regen_start"):
		snd.play_shield_regen_start()

func _on_player_shield_full() -> void:
	var snd : Node = get_node_or_null("/root/UiSound")
	if snd != null and snd.has_method("play_shield_recharged"):
		snd.play_shield_recharged()

func _on_player_health_changed(new_health: int, old_health: int) -> void:
	if new_health < old_health and new_health > 0:
		var now : float = Time.get_ticks_msec() / 1000.0
		if now - _last_hurt_sound_time >= 0.22:
			_last_hurt_sound_time = now
			var snd : Node = get_node_or_null("/root/UiSound")
			if snd != null and snd.has_method("play_player_hurt"):
				snd.play_player_hurt()

func _on_player_died() -> void:
	can_shoot = false
	if _shield_bubble != null:
		_shield_bubble.visible = false

	# Reset special weapon on death back to starter weapon
	special_weapon = starter_slot1_weapon
	special_ammo = 0
	special_max_ammo = 0
	active_slot = SLOT_BASIC
	_sync_active_slot_state()

	if player_animation != null and player_animation.has_method("set_weapon_model"):
		player_animation.set_weapon_model(starter_slot1_weapon)

	_notify_hud()

	if "can_move" in player:
		player.can_move = false
	if "can_jump" in player:
		player.can_jump = false

	player.velocity.x = 0.0
	player.velocity.z = 0.0
	player.set_deferred("collision_layer", 0)
	player.set_deferred("collision_mask", 1)
	if is_instance_valid(player_mesh) and is_inside_tree():
		var tween : Tween = create_tween().set_parallel(true)
		if tween != null:
			tween.tween_property(player_mesh, "rotation:x", -PI / 2.0, death_tip_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween.tween_property(player_mesh, "position:y", death_lift, death_tip_duration)

	if _laser_sight != null:
		_laser_sight.visible = false
	_update_camera_sniper_zoom()

func _setup_laser_sight() -> void:
	if _laser_sight != null:
		return
	var sight := MeshInstance3D.new()
	sight.name = "SniperLaserSight"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.005
	cyl.bottom_radius = 0.005
	cyl.height = 14.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.2, 0.85, 1.0, 0.45)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.85, 1.0, 1.0)
	mat.emission_energy_multiplier = 1.8
	sight.mesh = cyl
	sight.material_override = mat
	sight.top_level = true
	sight.visible = false
	if is_instance_valid(player):
		player.add_child(sight)
	_laser_sight = sight

func _update_laser_sight() -> void:
	if _laser_sight == null:
		return
	var is_sniper : bool = (current_weapon == WeaponType.SNIPER and can_shoot and not _is_player_dead())
	_laser_sight.visible = is_sniper
	if not is_sniper:
		return
	var center : Vector3 = player.global_position + Vector3(0.0, MUZZLE_HEIGHT, 0.0)
	var dir : Vector3 = _get_aim_direction(center)
	var muzzle : Vector3 = center + dir * 0.45
	var laser_len : float = 14.0
	_laser_sight.global_position = muzzle + dir * (laser_len * 0.5)
	var up_vec : Vector3 = Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.9 else Vector3.BACK
	_laser_sight.basis = Basis.looking_at(dir, up_vec) * Basis(Vector3.RIGHT, deg_to_rad(90))

func _is_player_dead() -> bool:
	if not is_instance_valid(player):
		return true
	var hc : HealthComponent = player.get_node_or_null("HealthComponent") as HealthComponent
	return hc != null and hc.is_dead()

func _update_camera_sniper_zoom() -> void:
	_update_laser_sight()
	if not is_instance_valid(player) or not is_inside_tree():
		return
	var viewport : Viewport = player.get_viewport()
	if viewport == null:
		return
	var camera : Camera3D = viewport.get_camera_3d()
	if camera == null:
		return
	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.kill()

	var base_cam_size : float = DEFAULT_CAM_SIZE
	var char_data : Node = get_node_or_null("/root/CharacterData")
	if char_data != null and char_data.has_method("get_camera_ortho_size"):
		base_cam_size = float(char_data.call("get_camera_ortho_size"))
	elif char_data != null and "CLASS_CONFIGS" in char_data:
		var cur_cls : int = int(char_data.get("current_class"))
		var configs : Dictionary = char_data.get("CLASS_CONFIGS")
		if cur_cls in configs:
			base_cam_size = float(configs[cur_cls].get("camera_size", DEFAULT_CAM_SIZE))

	var is_special_sniper : bool = (current_weapon == WeaponType.SNIPER and active_slot == SLOT_SPECIAL)
	var target_size : float = (base_cam_size + 1.8) if is_special_sniper else base_cam_size
	_camera_tween = create_tween()
	_camera_tween.tween_property(camera, "size", target_size, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

const WRENCH_REPAIR_MAX_DISTANCE : float = 1.35 # Nerfed mechanic repair reach to melee contact distance

## Heavy Titanium Hydro-Wrench: Point-blank melee strike (2.2m arc) and field repair.
func _fire_wrench(muzzle: Vector3, direction: Vector3, is_alt_fire: bool) -> void:
	var snd : Node = get_node_or_null("/root/UiSound")
	if snd != null and snd.has_method("play_wrench_swing"):
		snd.play_wrench_swing()

	# Sweep forward 2.2m arc
	var space_state := player.get_world_3d().direct_space_state
	if space_state == null:
		return

	var swing_pos : Vector3 = player.global_position + direction * 1.2 + Vector3(0.0, MUZZLE_HEIGHT, 0.0)
	var shape := SphereShape3D.new()
	shape.radius = 1.3
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, swing_pos)
	query.collision_mask = 1 | 2 | 4 # Geometry, Enemies, Vehicles
	query.exclude = [player.get_rid()]

	var results := space_state.intersect_shape(query, 16)

	for res in results:
		var col : Node = res.get("collider") as Node
		if col == null or col == player:
			continue

		# 1. Check for Hostiles (Enemies, Targets)
		var is_enemy : bool = col.is_in_group("enemy") or col.name.to_lower().contains("enemy") or col.name.to_lower().contains("target")
		var target_hc : HealthComponent = col.get_node_or_null("HealthComponent") as HealthComponent
		if target_hc == null and col.get_parent() != null:
			target_hc = col.get_parent().get_node_or_null("HealthComponent") as HealthComponent

		if is_enemy and target_hc != null and not target_hc.is_dead():
			var wrench_dmg : int = 85 if is_alt_fire else 55
			target_hc.decrease_health(wrench_dmg)

			if col is CharacterBody3D:
				var push_dir : Vector3 = (col.global_position - player.global_position).normalized()
				push_dir.y = 0.2
				(col as CharacterBody3D).velocity += push_dir * (8.0 if is_alt_fire else 5.5)

			if snd != null and snd.has_method("play_wrench_hit"):
				snd.play_wrench_hit()
			_spawn_wrench_impact(col.global_position + Vector3(0, 0.3, 0), false)
			break

		# 2. Check for Friendly Turrets or Vehicles to Repair (Strict close-quarters melee reach)
		var is_repairable : bool = col.is_in_group("turret") or col.is_in_group("vehicle") or col.is_in_group("drivable")
		if is_repairable and target_hc != null and target_hc.health < HealthComponent.MAX_HEALTH and not target_hc.is_dead():
			var dist : float = player.global_position.distance_to(col.global_position)
			if dist <= WRENCH_REPAIR_MAX_DISTANCE:
				target_hc.increase_health(25)
				if snd != null and snd.has_method("play_wrench_repair"):
					snd.play_wrench_repair()
				_spawn_wrench_impact(col.global_position + Vector3(0, 0.4, 0), true)
				break

func _spawn_wrench_impact(pos: Vector3, is_repair: bool) -> void:
	var flash := CPUParticles3D.new()
	flash.emitting = false
	flash.one_shot = true
	flash.explosiveness = 1.0
	flash.amount = 12
	flash.lifetime = 0.15

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.2, 0.9, 1.0) if is_repair else Color(1.0, 0.75, 0.2)
	var b := BoxMesh.new()
	b.size = Vector3(0.02, 0.04, 0.02)
	b.material = mat
	flash.mesh = b

	player.get_parent().add_child(flash)
	flash.global_position = pos
	flash.restart()
	flash.emitting = true
	get_tree().create_timer(0.3).timeout.connect(flash.queue_free)

## Configures starter weapon according to operative class.
func apply_character_class(class_id: int) -> void:
	match class_id:
		CharacterDataSingleton.CharacterClass.ENGINEER:
			starter_slot1_weapon = WeaponType.WRENCH
		CharacterDataSingleton.CharacterClass.MEDIC:
			starter_slot1_weapon = WeaponType.SHOTGUN
		CharacterDataSingleton.CharacterClass.EXPLORER:
			starter_slot1_weapon = WeaponType.SNIPER
		_:
			starter_slot1_weapon = WeaponType.BASIC

	if active_slot == SLOT_BASIC:
		current_weapon = starter_slot1_weapon
		_sync_active_slot_state()
		if player_animation != null and player_animation.has_method("set_weapon_model"):
			player_animation.set_weapon_model(current_weapon)
		_notify_hud()
		_update_camera_sniper_zoom()

func _on_class_changed_runtime(new_class: int, _info: Dictionary) -> void:
	apply_character_class(new_class)

## Triggers the active class specialization ability on [F] key.
func execute_class_ability() -> void:
	var char_data : Node = get_node_or_null("/root/CharacterData")
	if char_data == null:
		return
	if not char_data.call("is_ability_ready"):
		var snd : Node = get_node_or_null("/root/UiSound")
		if snd != null and snd.has_method("play_denied"):
			snd.play_denied()
		return

	var current_cls : int = int(char_data.get("current_class"))
	match current_cls:
		CharacterDataSingleton.CharacterClass.ASTRONAUT:
			_throw_frag_grenade()
			char_data.call("trigger_ability_cooldown")
		CharacterDataSingleton.CharacterClass.ENGINEER:
			_deploy_sentry_turret()
			char_data.call("trigger_ability_cooldown")
		CharacterDataSingleton.CharacterClass.MEDIC:
			_activate_healing_surge()
			char_data.call("trigger_ability_cooldown")
		_:
			pass

func _throw_frag_grenade() -> void:
	if GRENADE_SCENE == null:
		return

	var parent_node : Node = player.get_parent() if is_instance_valid(player) else null
	if parent_node == null and is_inside_tree():
		parent_node = get_tree().root
	if parent_node == null:
		return

	var spawn_pos : Vector3 = player.global_position + Vector3(0.0, 0.45, 0.0)
	var throw_dir : Vector3 = Vector3.FORWARD
	var mouse_aim : Vector3 = _get_aim_direction(spawn_pos)
	if not mouse_aim.is_zero_approx():
		throw_dir = mouse_aim
	else:
		var fwd : Vector3 = player.global_transform.basis.z
		fwd.y = 0.0
		throw_dir = fwd.normalized() if not fwd.is_zero_approx() else Vector3.FORWARD

	var grenade : Grenade = GRENADE_SCENE.instantiate() as Grenade
	grenade.shooter = player
	parent_node.add_child(grenade)
	grenade.global_position = spawn_pos + throw_dir * 0.4
	# Arc trajectory: forward velocity + upward launch kick
	grenade.velocity = throw_dir * 13.0 + Vector3.UP * 4.2

	var snd : Node = get_node_or_null("/root/UiSound")
	if snd != null and snd.has_method("play_shoot"):
		snd.play_shoot(0.12)

func _deploy_sentry_turret() -> void:
	if SENTRY_TURRET_SCENE == null:
		return

	var facing : Vector3 = -player.global_transform.basis.z
	facing.y = 0.0
	if facing.is_zero_approx():
		facing = Vector3.FORWARD
	var deploy_pos : Vector3 = player.global_position + facing.normalized() * 1.5

	# Limit to 2 active turrets per Engineer
	active_turrets = active_turrets.filter(func(t): return is_instance_valid(t) and not t.is_queued_for_deletion())
	if active_turrets.size() >= 2:
		var oldest : Node3D = active_turrets.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()

	var parent_node : Node = player.get_parent() if is_instance_valid(player) else null
	if parent_node == null and is_inside_tree():
		parent_node = get_tree().root
	if parent_node == null:
		return

	var turret : Node3D = SENTRY_TURRET_SCENE.instantiate() as Node3D
	parent_node.add_child(turret)
	turret.global_position = deploy_pos
	turret.global_rotation.y = player.global_rotation.y
	active_turrets.append(turret)

	var snd : Node = get_node_or_null("/root/UiSound")
	if snd != null and snd.has_method("play_turret_deploy"):
		snd.play_turret_deploy()

func _activate_healing_surge() -> void:
	if HEAL_WAVE_SCENE == null:
		return

	var parent_node : Node = player.get_parent() if is_instance_valid(player) else null
	if parent_node == null and is_inside_tree():
		parent_node = get_tree().root
	if parent_node == null:
		return

	var wave : Node3D = HEAL_WAVE_SCENE.instantiate() as Node3D
	parent_node.add_child(wave)
	wave.global_position = player.global_position

	var snd : Node = get_node_or_null("/root/UiSound")
	if snd != null and snd.has_method("play_heal_surge"):
		snd.play_heal_surge()
