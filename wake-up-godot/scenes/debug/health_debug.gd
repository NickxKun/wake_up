extends CanvasLayer

## Advanced Collapsible Sandbox / Developer Toolbox:
## Includes cheat toggles (Godmode, Infinite Stamina, Infinite Ammo),
## real-time map switcher, instant weapon arsenal spawner, vehicle deployment,
## time-of-day scrubber, and health adjustments.

@export var health_component : HealthComponent

const ROVER_SCENE : PackedScene = preload("res://scenes/vehicles/rover.tscn")

# UI Nodes
@onready var debug_panel : PanelContainer = $DebugPanel
@onready var toggle_button : Button = $ToggleBar/ToggleButton
@onready var content_box : VBoxContainer = $DebugPanel/VBoxContainer/ContentBox

# Cheat Buttons
@onready var godmode_btn : Button = $DebugPanel/VBoxContainer/ContentBox/CheatsRow/GodmodeBtn
@onready var stamina_btn : Button = $DebugPanel/VBoxContainer/ContentBox/CheatsRow/StaminaBtn
@onready var ammo_btn : Button = $DebugPanel/VBoxContainer/ContentBox/CheatsRow/AmmoBtn

# Operative Buttons
@onready var astro_btn : Button = $DebugPanel/VBoxContainer/ContentBox/OperativesRow/AstroBtn
@onready var engi_btn : Button = $DebugPanel/VBoxContainer/ContentBox/OperativesRow/EngiBtn
@onready var medic_btn : Button = $DebugPanel/VBoxContainer/ContentBox/OperativesRow/MedicBtn
@onready var explorer_btn : Button = $DebugPanel/VBoxContainer/ContentBox/OperativesRow/ExplorerBtn

# Weapon Buttons
@onready var wpn_pistol_btn : Button = $DebugPanel/VBoxContainer/ContentBox/WeaponsRow/PistolBtn
@onready var wpn_shotgun_btn : Button = $DebugPanel/VBoxContainer/ContentBox/WeaponsRow/ShotgunBtn
@onready var wpn_sniper_btn : Button = $DebugPanel/VBoxContainer/ContentBox/WeaponsRow/SniperBtn
@onready var wpn_dual_btn : Button = $DebugPanel/VBoxContainer/ContentBox/WeaponsRow/DualBtn
@onready var wpn_rocket_btn : Button = $DebugPanel/VBoxContainer/ContentBox/WeaponsRow/RocketBtn

# Map Buttons
@onready var map_0_btn : Button = $DebugPanel/VBoxContainer/ContentBox/MapRow/Map0Btn
@onready var map_1_btn : Button = $DebugPanel/VBoxContainer/ContentBox/MapRow/Map1Btn
@onready var map_2_btn : Button = $DebugPanel/VBoxContainer/ContentBox/MapRow/Map2Btn

# Utility Buttons
@onready var spawn_vehicle_btn : Button = $DebugPanel/VBoxContainer/ContentBox/UtilRow/SpawnVehicleBtn
@onready var time_dawn_btn : Button = $DebugPanel/VBoxContainer/ContentBox/TimeRow/DawnBtn
@onready var time_noon_btn : Button = $DebugPanel/VBoxContainer/ContentBox/TimeRow/NoonBtn
@onready var time_dusk_btn : Button = $DebugPanel/VBoxContainer/ContentBox/TimeRow/DuskBtn
@onready var time_night_btn : Button = $DebugPanel/VBoxContainer/ContentBox/TimeRow/NightBtn
@onready var time_pause_btn : Button = $DebugPanel/VBoxContainer/ContentBox/TimeRow/PauseBtn

# Health Adjuster
@onready var up_button : Button = $DebugPanel/VBoxContainer/ContentBox/HealthRow/UpButton
@onready var down_button : Button = $DebugPanel/VBoxContainer/ContentBox/HealthRow/DownButton
@onready var reset_button : Button = $DebugPanel/VBoxContainer/ContentBox/HealthRow/ResetButton
@onready var amount_box : SpinBox = $DebugPanel/VBoxContainer/ContentBox/HealthRow/AmountBox

var _is_collapsed : bool = false
var _godmode : bool = false
var _unlimited_stamina : bool = false
var _unlimited_ammo : bool = false

func _ready() -> void:
	# Connect collapsible toggle
	toggle_button.pressed.connect(_toggle_collapse)

	# Cheats
	godmode_btn.pressed.connect(_on_godmode_toggled)
	stamina_btn.pressed.connect(_on_stamina_toggled)
	ammo_btn.pressed.connect(_on_ammo_toggled)

	# Operatives
	if astro_btn != null: astro_btn.pressed.connect(func(): _switch_operative(0))
	if engi_btn != null: engi_btn.pressed.connect(func(): _switch_operative(1))
	if medic_btn != null: medic_btn.pressed.connect(func(): _switch_operative(2))
	if explorer_btn != null: explorer_btn.pressed.connect(func(): _switch_operative(3))

	var char_data : Node = get_node_or_null("/root/CharacterData")
	if char_data != null and char_data.has_signal("class_changed"):
		char_data.class_changed.connect(func(_c, _i): _update_operative_buttons())
	_update_operative_buttons()

	# Weapons
	wpn_pistol_btn.pressed.connect(func(): _equip_weapon(0))
	wpn_shotgun_btn.pressed.connect(func(): _equip_weapon(1))
	wpn_sniper_btn.pressed.connect(func(): _equip_weapon(2))
	wpn_dual_btn.pressed.connect(func(): _equip_weapon(3))
	wpn_rocket_btn.pressed.connect(func(): _equip_weapon(4))

	# Maps
	map_0_btn.pressed.connect(func(): _switch_map(0))
	map_1_btn.pressed.connect(func(): _switch_map(1))
	map_2_btn.pressed.connect(func(): _switch_map(2))

	# Vehicle
	spawn_vehicle_btn.pressed.connect(_spawn_vehicle)

	# Time of day
	time_dawn_btn.pressed.connect(func(): _set_time("morning"))
	time_noon_btn.pressed.connect(func(): _set_time("noon"))
	time_dusk_btn.pressed.connect(func(): _set_time("sunset"))
	time_night_btn.pressed.connect(func(): _set_time("night"))
	time_pause_btn.pressed.connect(_toggle_time_pause)

	# Health adjustments
	up_button.pressed.connect(_on_up_pressed)
	down_button.pressed.connect(_on_down_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	amount_box.get_line_edit().text_submitted.connect(_on_amount_submitted)

	_update_active_map_buttons()

func _toggle_collapse() -> void:
	_is_collapsed = not _is_collapsed
	content_box.visible = not _is_collapsed
	debug_panel.visible = not _is_collapsed
	toggle_button.text = "◈ SANDBOX TOOLS  ▼" if _is_collapsed else "◈ SANDBOX TOOLS  ▲"

func _on_godmode_toggled() -> void:
	_godmode = not _godmode
	var player := _get_player()
	if player != null:
		var hc : HealthComponent = player.get_node_or_null("HealthComponent") as HealthComponent
		if hc != null:
			hc.is_invulnerable = _godmode
			if _godmode:
				hc.health = HealthComponent.MAX_HEALTH
				hc.health_changed.emit(hc.health, hc.health)
	godmode_btn.text = "GODMODE: " + ("ON" if _godmode else "OFF")
	godmode_btn.modulate = Color(0.3, 0.95, 1.0, 1.0) if _godmode else Color(0.85, 0.9, 0.95, 0.65)

func _on_stamina_toggled() -> void:
	_unlimited_stamina = not _unlimited_stamina
	var player := _get_player()
	if player != null and "infinite_stamina" in player:
		player.infinite_stamina = _unlimited_stamina
	stamina_btn.text = "∞ STAMINA: " + ("ON" if _unlimited_stamina else "OFF")
	stamina_btn.modulate = Color(0.3, 0.95, 1.0, 1.0) if _unlimited_stamina else Color(0.85, 0.9, 0.95, 0.65)

func _on_ammo_toggled() -> void:
	_unlimited_ammo = not _unlimited_ammo
	var player := _get_player()
	if player != null:
		var combat : Node = player.get_node_or_null("PlayerCombat")
		if combat != null and "infinite_ammo" in combat:
			combat.infinite_ammo = _unlimited_ammo
	ammo_btn.text = "∞ AMMO: " + ("ON" if _unlimited_ammo else "OFF")
	ammo_btn.modulate = Color(0.3, 0.95, 1.0, 1.0) if _unlimited_ammo else Color(0.85, 0.9, 0.95, 0.65)

func _equip_weapon(wpn_idx: int) -> void:
	var player := _get_player()
	if player == null:
		return
	var combat : Node = player.get_node_or_null("PlayerCombat")
	if combat == null:
		return
	if wpn_idx == 0:
		if combat.has_method("switch_slot"):
			combat.call("switch_slot", 1) # SLOT_BASIC
	else:
		if combat.has_method("equip_special_weapon"):
			combat.call("equip_special_weapon", wpn_idx)

func _switch_map(map_index: int) -> void:
	var hud : Node = get_node_or_null("/root/PlayerHealthHud")
	if hud != null:
		hud.selected_map_theme = map_index
		if hud.has_method("restart"):
			hud.call("restart")

func _update_active_map_buttons() -> void:
	var hud : Node = get_node_or_null("/root/PlayerHealthHud")
	var cur_theme : int = 1
	if hud != null and "selected_map_theme" in hud:
		cur_theme = hud.selected_map_theme
	map_0_btn.modulate = Color(0.3, 0.95, 1.0, 1.0) if cur_theme == 0 else Color(0.85, 0.9, 0.95, 0.6)
	map_1_btn.modulate = Color(0.3, 0.95, 1.0, 1.0) if cur_theme == 1 else Color(0.85, 0.9, 0.95, 0.6)
	map_2_btn.modulate = Color(0.3, 0.95, 1.0, 1.0) if cur_theme == 2 else Color(0.85, 0.9, 0.95, 0.6)

func _spawn_vehicle() -> void:
	var player := _get_player()
	if player == null or ROVER_SCENE == null:
		return
	var rover : CharacterBody3D = ROVER_SCENE.instantiate() as CharacterBody3D
	var parent_node := player.get_parent()
	parent_node.add_child(rover)
	var spawn_pos : Vector3 = player.global_position - player.global_transform.basis.z * 3.0
	spawn_pos.y += 0.2
	rover.global_position = spawn_pos
	rover.rotation.y = player.rotation.y

func _set_time(preset: String) -> void:
	var dnc : Node = get_tree().get_first_node_in_group("day_night_cycle")
	if dnc != null and dnc.has_method("set_time_preset"):
		dnc.call("set_time_preset", preset)

func _toggle_time_pause() -> void:
	var dnc : Node = get_tree().get_first_node_in_group("day_night_cycle")
	if dnc != null and "is_paused" in dnc:
		dnc.is_paused = not dnc.is_paused
		time_pause_btn.text = "RESUME" if dnc.is_paused else "PAUSE"
		time_pause_btn.modulate = Color(1.0, 0.4, 0.4) if dnc.is_paused else Color(1.0, 1.0, 1.0, 0.8)

func _get_player() -> CharacterBody3D:
	return get_tree().get_first_node_in_group("player") as CharacterBody3D

func _on_up_pressed() -> void:
	if health_component != null:
		health_component.increase_health(_get_amount())

func _on_down_pressed() -> void:
	if health_component != null:
		health_component.decrease_health(_get_amount())

func _on_reset_pressed() -> void:
	if health_component != null:
		var old_health : int = health_component.health
		health_component.health = HealthComponent.MAX_HEALTH
		health_component.health_changed.emit(health_component.health, old_health)
		health_component.health_full.emit()
		if health_component.has_shield:
			health_component.reset_shield()

func _get_amount() -> int:
	var amount : int = int(amount_box.value)
	return amount if amount >= 1 else 1

func _switch_operative(class_id: int) -> void:
	var char_data : Node = get_node_or_null("/root/CharacterData")
	if char_data != null and char_data.has_method("select_class"):
		char_data.call("select_class", class_id)
	var snd : Node = get_node_or_null("/root/UiSound")
	if snd != null and snd.has_method("play_click"):
		snd.call("play_click")
	_update_operative_buttons()

func _update_operative_buttons() -> void:
	if astro_btn == null or engi_btn == null or medic_btn == null or explorer_btn == null:
		return
	var char_data : Node = get_node_or_null("/root/CharacterData")
	var curr : int = int(char_data.get("current_class")) if char_data != null else 0
	var buttons := [astro_btn, engi_btn, medic_btn, explorer_btn]
	var colors := [
		Color(0.2, 0.75, 1.0),
		Color(1.0, 0.55, 0.1),
		Color(0.1, 0.9, 0.55),
		Color(0.95, 0.78, 0.25)
	]
	for i in range(buttons.size()):
		var b : Button = buttons[i]
		if i == curr:
			b.modulate = colors[i]
		else:
			b.modulate = Color(0.85, 0.9, 0.95, 0.65)

func _on_amount_submitted(_text : String) -> void:
	amount_box.get_line_edit().release_focus()
