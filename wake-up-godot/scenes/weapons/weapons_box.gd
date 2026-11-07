class_name WeaponsBox
extends Node3D

## Sci-fi Weapons Box / Dispenser:
## - Spawns a random special weapon every 30 seconds.
## - Displays the actual 3D custom model of the dispensed weapon floating and rotating above the pedestal.
## - If a weapon is already in the dispenser, replaces it with the new random weapon.
## - Proximity pickup: awards weapon to player's secondary slot if player has no active special ammo.
## - If player already has a special weapon with remaining ammo, blocks pickup until ammo is expended.

signal weapon_dispensed(weapon_type: int)
signal weapon_claimed(weapon_type: int, player: CharacterBody3D)

enum WeaponType {
	BASIC = 0,
	SHOTGUN = 1,
	SNIPER = 2,
	DOUBLE_PISTOLS = 3,
	ROCKET_LAUNCHER = 4,
}

const WEAPON_MODELS : Dictionary = {
	WeaponType.BASIC: preload("res://scenes/weapons/models/model_pistol.tscn"),
	WeaponType.SHOTGUN: preload("res://scenes/weapons/models/model_shotgun.tscn"),
	WeaponType.SNIPER: preload("res://scenes/weapons/models/model_sniper.tscn"),
	WeaponType.DOUBLE_PISTOLS: preload("res://scenes/weapons/models/model_double_pistols.tscn"),
	WeaponType.ROCKET_LAUNCHER: preload("res://scenes/weapons/models/model_rocket_launcher.tscn"),
}

@export var spawn_interval : float = 30.0
@export var auto_spawn_on_ready : bool = true

var current_weapon : int = -1 # -1 = empty
var time_until_spawn : float = 30.0
var _bob_time : float = 0.0
var _spawned_model : Node3D = null

@onready var interaction_area : Area3D = get_node_or_null("InteractionArea") as Area3D
@onready var holo_anchor : Node3D = get_node_or_null("HoloAnchor") as Node3D
@onready var holo_light : OmniLight3D = get_node_or_null("HoloAnchor/HoloLight") as OmniLight3D
@onready var info_label : Label3D = get_node_or_null("LabelAnchor/InfoLabel") as Label3D
@onready var timer_label : Label3D = get_node_or_null("LabelAnchor/TimerLabel") as Label3D

func _ready() -> void:
	add_to_group("weapons_box")
	if interaction_area != null:
		interaction_area.body_entered.connect(_on_body_entered)

	time_until_spawn = spawn_interval
	if auto_spawn_on_ready:
		spawn_random_weapon()
	else:
		_update_visuals()

func _process(delta: float) -> void:
	# Countdown timer for weapon rotation
	time_until_spawn -= delta
	if time_until_spawn <= 0.0:
		time_until_spawn = spawn_interval
		spawn_random_weapon()

	# Floating holographic animation
	_bob_time += delta * 2.2
	if holo_anchor != null:
		holo_anchor.rotation.y += delta * 1.6
		holo_anchor.position.y = 0.52 + sin(_bob_time) * 0.05

	# Update countdown text
	if timer_label != null:
		var secs : int = clampi(int(ceil(time_until_spawn)), 0, int(spawn_interval))
		timer_label.text = "RE-SUPPLY IN %02ds" % secs

## Replaces the currently dispensed weapon with a newly selected random special weapon.
func spawn_random_weapon() -> void:
	# Choose randomly from Shotgun, Sniper, Double Pistols, Rocket Launcher
	var options : Array[int] = [
		WeaponType.SHOTGUN,
		WeaponType.SNIPER,
		WeaponType.DOUBLE_PISTOLS,
		WeaponType.ROCKET_LAUNCHER
	]

	# If current weapon exists, remove it and pick a different random one if possible
	if current_weapon in options and options.size() > 1:
		options.erase(current_weapon)

	current_weapon = options[randi() % options.size()]
	time_until_spawn = spawn_interval
	_update_visuals()

	weapon_dispensed.emit(current_weapon)

## Updates the holographic weapon representation, colors, and 3D floating labels.
func _update_visuals() -> void:
	# Remove any previously instantiated floating 3D weapon model
	if _spawned_model != null and is_instance_valid(_spawned_model):
		_spawned_model.queue_free()
		_spawned_model = null

	if current_weapon == -1:
		if holo_anchor != null:
			holo_anchor.visible = false
		if info_label != null:
			info_label.text = "[RE-SUPPLYING...]"
			info_label.modulate = Color(0.6, 0.6, 0.6, 0.7)
		if holo_light != null:
			holo_light.light_energy = 0.2
		return

	if holo_anchor != null:
		holo_anchor.visible = true

	var w_name : String = ""
	var w_color : Color = Color.WHITE
	var w_ammo_desc : String = ""

	match current_weapon:
		WeaponType.SHOTGUN:
			w_name = "SHOTGUN"
			w_color = Color(1.0, 0.60, 0.18) # Amber orange
			w_ammo_desc = "10 HEAVY SHELLS"
		WeaponType.SNIPER:
			w_name = "SNIPER RIFLE"
			w_color = Color(0.25, 0.85, 1.0) # High-tech cyan
			w_ammo_desc = "8 AP ROUNDS"
		WeaponType.DOUBLE_PISTOLS:
			w_name = "DOUBLE PISTOLS"
			w_color = Color(0.35, 1.0, 0.5) # Tactical green
			w_ammo_desc = "30 HIGH-VELOCITY ROUNDS"
		WeaponType.ROCKET_LAUNCHER:
			w_name = "ROCKET LAUNCHER"
			w_color = Color(1.0, 0.3, 0.25) # Hazard crimson
			w_ammo_desc = "5 EXPLOSIVE ROCKETS"

	if info_label != null:
		info_label.text = "%s\n(%s)" % [w_name, w_ammo_desc]
		info_label.modulate = w_color

	if holo_light != null:
		holo_light.light_color = w_color
		holo_light.light_energy = 2.4

	# Instantiate the exact 3D custom model of the weapon floating in the dispenser
	if holo_anchor != null and current_weapon in WEAPON_MODELS and WEAPON_MODELS[current_weapon] != null:
		var packed : PackedScene = WEAPON_MODELS[current_weapon]
		var model_inst : Node3D = packed.instantiate() as Node3D
		if model_inst != null:
			holo_anchor.add_child(model_inst)
			model_inst.position = Vector3(0.0, 0.05, 0.0)
			model_inst.scale = Vector3(1.35, 1.35, 1.35)
			_spawned_model = model_inst

func _on_body_entered(body: Node3D) -> void:
	if current_weapon == -1 or body == null:
		return
	if not body.is_in_group("player") or not (body is CharacterBody3D):
		return

	var player_body := body as CharacterBody3D
	var pc : Node = player_body.get_node_or_null("PlayerCombat")
	if pc == null:
		return

	# Check if player is allowed to pick up a special weapon
	if pc.has_method("can_pickup_weapon") and not pc.can_pickup_weapon():
		_show_feedback("AMMO REMAINING!\nEXPEND CURRENT WEAPON FIRST", Color(1.0, 0.35, 0.35))
		return

	# Award the weapon to player's secondary slot!
	if pc.has_method("equip_weapon"):
		var success : bool = pc.equip_weapon(current_weapon)
		if success:
			var claimed := current_weapon
			current_weapon = -1
			_update_visuals()
			weapon_claimed.emit(claimed, player_body)
			_show_feedback("WEAPON EQUIPPED!", Color(0.4, 1.0, 0.5))

func _show_feedback(msg: String, col: Color) -> void:
	if info_label == null:
		return
	var old_text : String = info_label.text
	var old_col : Color = info_label.modulate
	info_label.text = msg
	info_label.modulate = col
	var tween := create_tween()
	tween.tween_interval(1.8)
	tween.tween_callback(func():
		if is_instance_valid(info_label):
			info_label.text = old_text
			info_label.modulate = old_col
	)
