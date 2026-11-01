extends Node

## Autoload that manages the player's HealthBar, Scoreboard, Minimap, Out-of-Bounds hazard system,
## and Game Over states.

const HEALTH_BAR_SCENE : PackedScene = preload("res://scenes/ui/health_bar.tscn")
const HEALTH_DEBUG_SCENE : PackedScene = preload("res://scenes/debug/health_debug.tscn")
const GAME_OVER_SCENE : PackedScene = preload("res://scenes/ui/game_over.tscn")
const PAUSE_MENU_SCENE : PackedScene = preload("res://scenes/ui/pause_menu.tscn")
const SCOREBOARD_SCENE : PackedScene = preload("res://scenes/ui/scoreboard.tscn")
const OUT_OF_BOUNDS_WARNING_SCENE : PackedScene = preload("res://scenes/ui/out_of_bounds_warning.tscn")
const MINIMAP_SCENE : PackedScene = preload("res://scenes/ui/minimap.tscn")
const TACTICAL_MAP_SCENE : PackedScene = preload("res://scenes/ui/tactical_map.tscn")
const MAIN_MENU_SCENE_PATH : String = "res://scenes/ui/main_menu.tscn"
const PLAYER_NAME : String = "ProtoController"

const SAFE_ZONE_HALF_SIZE : float = 15.5
const OOB_PULSE_INTERVAL : float = 0.5
const OOB_PULSE_DAMAGE : int = 25
const OOB_DAMAGE_PER_SECOND : float = 50.0

## The health component attached to the player, null when outside gameplay.
var health_component : HealthComponent
## Enemies killed since the last (re)start.
var enemies_killed : int = 0
## Player deaths since the last (re)start.
var player_deaths : int = 0
## Whether Sandbox Mode (with debugging tools) is active.
var is_sandbox_mode : bool = false
## Whether Tutorial Mode is active (disables survival OOB boundaries).
var is_tutorial_mode : bool = false
## Active map theme: 0 = Canyon Wasteland, 1 = Space Base, 2 = Transport Dock
var selected_map_theme : int = 1

var _is_setup : bool = false
var _is_restarting : bool = false
var _game_over : CanvasLayer
var _hud_bar : CanvasLayer
var _scoreboard : CanvasLayer
var _pause_menu : CanvasLayer
var _oob_warning : CanvasLayer
var _minimap : CanvasLayer
var _tactical_map : CanvasLayer
var _vehicle_hint : CanvasLayer
var _weapon_hud : CanvasLayer
var _weapon_name_label : Label
var _weapon_ammo_label : Label
var _weapon_secondary_label : Label
var _weapon_panel : Control
var _weapon_icon : WeaponIcon
var _player_ref : WeakRef = null
var _oob_pulse_timer : float = 0.5

func _process(delta: float) -> void:
	if _is_restarting:
		return
	var tree : SceneTree = get_tree()
	if tree == null:
		return
	var current_scene : Node = tree.current_scene
	if current_scene == null:
		return

	is_tutorial_mode = (current_scene.name == "TutorialMap" or current_scene.find_child("TutorialManager", true, false) != null)

	var player : Node = current_scene.find_child(PLAYER_NAME, true, false)
	if player != null:
		var current_player_node : Node = _player_ref.get_ref() if _player_ref != null else null
		if not _is_setup or current_player_node != player:
			_setup_hud(player)
	elif player == null and _is_setup:
		_cleanup_ui()

	_handle_out_of_bounds(delta)

func _handle_out_of_bounds(delta: float) -> void:
	if not _is_setup or _player_ref == null or not is_instance_valid(health_component) or is_game_over():
		return
	if is_tutorial_mode:
		if is_instance_valid(_oob_warning):
			_oob_warning.set_warning_active(false)
		if is_instance_valid(_minimap):
			_minimap.set_out_of_bounds(false)
			_minimap.radar_world_radius = 32.0
		return
	if health_component.is_dead():
		return
	var player : Node3D = _player_ref.get_ref() as Node3D
	if player == null or not is_instance_valid(player):
		return

	var p_pos : Vector3 = player.global_position
	var is_oob : bool = absf(p_pos.x) > SAFE_ZONE_HALF_SIZE or absf(p_pos.z) > SAFE_ZONE_HALF_SIZE

	if is_instance_valid(_oob_warning):
		_oob_warning.set_warning_active(is_oob)
	if is_instance_valid(_minimap):
		_minimap.set_out_of_bounds(is_oob)

	if is_oob:
		if is_instance_valid(_oob_warning) and _oob_warning.get_time_remaining() <= 0.0:
			_oob_pulse_timer += delta
			if _oob_pulse_timer >= OOB_PULSE_INTERVAL:
				_oob_pulse_timer = 0.0
				if health_component.has_method("decrease_health"):
					health_component.decrease_health(OOB_PULSE_DAMAGE)
				elif health_component.has_method("take_damage"):
					health_component.take_damage(OOB_PULSE_DAMAGE)

				var snd : Node = get_node_or_null("/root/UiSound")
				if snd != null and snd.has_method("play_hazard_pulse"):
					snd.play_hazard_pulse()
	else:
		_oob_pulse_timer = OOB_PULSE_INTERVAL

func _unhandled_input(event: InputEvent) -> void:
	if not _is_setup or is_game_over():
		return
	if is_instance_valid(_pause_menu) and _pause_menu.visible:
		return

	var is_map_action : bool = false
	if event.is_action_pressed("toggle_map"):
		is_map_action = true
	elif event is InputEventKey and event.pressed and not event.echo:
		var k : InputEventKey = event as InputEventKey
		if k.physical_keycode == KEY_M or k.keycode == KEY_M:
			is_map_action = true

	if is_map_action and is_instance_valid(_tactical_map):
		_tactical_map.toggle_map()
		get_viewport().set_input_as_handled()

func _setup_hud(player: Node) -> void:
	if player == null:
		return

	var hc : HealthComponent = player.get_node_or_null("HealthComponent") as HealthComponent
	if hc == null or hc.is_dead():
		return # Never bind HUD to a dead player or corpse

	_is_setup = true
	_player_ref = weakref(player)
	health_component = hc

	# Clean up previous UI instances if re-binding
	if is_instance_valid(_hud_bar): _hud_bar.queue_free()
	if is_instance_valid(_oob_warning): _oob_warning.queue_free()
	if is_instance_valid(_minimap): _minimap.queue_free()
	if is_instance_valid(_tactical_map): _tactical_map.queue_free()
	if is_instance_valid(_pause_menu): _pause_menu.queue_free()
	if is_instance_valid(_game_over): _game_over.queue_free()
	if is_instance_valid(_weapon_hud): _weapon_hud.queue_free()

	if not health_component.health_depleted.is_connected(_on_player_died):
		health_component.health_depleted.connect(_on_player_died)

	# Minimal, sleek floating HUD in bottom-left with HP bar and kills/deaths
	var health_bar : CanvasLayer = HEALTH_BAR_SCENE.instantiate()
	health_bar.health_component = health_component
	if health_bar.has_method("bind_player"):
		health_bar.bind_player(player)
	_hud_bar = health_bar
	add_child(health_bar)
	_update_scoreboard()

	# Destiny-style Out of Bounds Warning banner and crimson vignette
	_oob_warning = OUT_OF_BOUNDS_WARNING_SCENE.instantiate()
	add_child(_oob_warning)

	# Tactical Minimap in top-right HUD
	_minimap = MINIMAP_SCENE.instantiate()
	_minimap.safe_zone_half_size = SAFE_ZONE_HALF_SIZE
	_minimap.bind_player(player as Node3D)
	var char_data : Node = get_node_or_null("/root/CharacterData")
	if char_data != null and char_data.has_method("get_current_config"):
		var cfg : Dictionary = char_data.get_current_config()
		_minimap.radar_world_radius = float(cfg.get("radar_radius", 26.0))
	add_child(_minimap)

	# Fullscreen Tactical Blueprint Map (toggled with M)
	_tactical_map = TACTICAL_MAP_SCENE.instantiate()
	_tactical_map.safe_zone_half_size = SAFE_ZONE_HALF_SIZE
	_tactical_map.bind_player(player as Node3D)
	add_child(_tactical_map)

	# Start in-game tactical combat BGM
	var snd : Node = get_node_or_null("/root/UiSound")
	if snd != null and snd.has_method("play_music"):
		snd.play_music("game")

	# Pause menu (processes while tree is paused)
	_pause_menu = PAUSE_MENU_SCENE.instantiate()
	_pause_menu.restart_requested.connect(restart)
	_pause_menu.main_menu_requested.connect(_on_menu_requested)
	add_child(_pause_menu)

	# Dedicated Weapon & Ammo Display overlay in bottom-right
	_setup_weapon_hud()

	# In Sandbox Mode only, show the debugging controls
	if is_sandbox_mode:
		var health_debug : CanvasLayer = HEALTH_DEBUG_SCENE.instantiate()
		health_debug.health_component = health_component
		add_child(health_debug)

func _cleanup_ui() -> void:
	get_tree().paused = false
	for child in get_children():
		child.queue_free()
	_game_over = null
	_hud_bar = null
	_scoreboard = null
	_pause_menu = null
	_oob_warning = null
	_minimap = null
	_tactical_map = null
	_vehicle_hint = null
	_weapon_hud = null
	_weapon_name_label = null
	_weapon_ammo_label = null
	_weapon_panel = null
	_weapon_icon = null
	_player_ref = null
	_oob_pulse_timer = 0.5
	health_component = null
	_is_setup = false
	enemies_killed = 0
	player_deaths = 0

func _on_player_died() -> void:
	if is_instance_valid(_pause_menu) and _pause_menu.has_method("force_close"):
		_pause_menu.force_close()
	if is_instance_valid(_oob_warning):
		_oob_warning.set_warning_active(false)
	if is_instance_valid(_tactical_map) and _tactical_map.is_map_open():
		_tactical_map.close_map()

	# Stop battle music and play deep cinematic player death audio
	var snd : Node = get_node_or_null("/root/UiSound")
	if snd != null:
		if snd.has_method("play_player_death"):
			snd.play_player_death()
		if snd.has_method("stop_music"):
			snd.stop_music(0.8)

	get_tree().paused = false

	player_deaths += 1
	_update_scoreboard()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_game_over = GAME_OVER_SCENE.instantiate()
	_game_over.restart_requested.connect(restart)
	_game_over.main_menu_requested.connect(_on_menu_requested)
	if _game_over.has_method("set_stats"):
		_game_over.set_stats(enemies_killed, player_deaths, is_sandbox_mode)
	add_child(_game_over)

## Returns true if the Game Over screen is currently active.
func is_game_over() -> bool:
	return is_instance_valid(_game_over)

## Returns true if the Fullscreen Tactical Map is currently displayed.
func is_map_open() -> bool:
	return is_instance_valid(_tactical_map) and _tactical_map.is_map_open()

## Shows or hides the cockpit vehicle control HUD hints overlay while driving,
## including a dedicated hull integrity bar and real-time damage indicators.
func set_vehicle_hint(active: bool, vehicle_name: String = "Scout Rover", current_health: int = -1, max_health: int = 100) -> void:
	if not active:
		if is_instance_valid(_vehicle_hint):
			var vh := _vehicle_hint
			_vehicle_hint = null
			var tween := create_tween()
			var panel : Control = vh.get_node_or_null("HintContainer") as Control
			if panel != null:
				tween.tween_property(panel, "modulate:a", 0.0, 0.2)
			tween.tween_callback(vh.queue_free)
		# Restore weapon HUD visibility when dismounting vehicle
		if is_instance_valid(_weapon_panel):
			_weapon_panel.visible = true
		return

	# Hide weapon HUD while in vehicle to keep UI minimal
	if is_instance_valid(_weapon_panel):
		_weapon_panel.visible = false

	if is_instance_valid(_vehicle_hint):
		var title : Label = _vehicle_hint.find_child("TitleLabel", true, false) as Label
		if title != null:
			title.text = vehicle_name.to_upper() + " // COCKPIT CONTROLS"
		if current_health >= 0:
			update_vehicle_health(current_health, max_health)
		return

	var cl := CanvasLayer.new()
	cl.layer = 15
	_vehicle_hint = cl
	add_child(cl)

	var root := Control.new()
	root.name = "HintContainer"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(root)

	var panel := PanelContainer.new()
	panel.name = "VehicleControlPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -310.0
	panel.offset_right = 310.0
	panel.offset_top = -86.0
	panel.offset_bottom = -14.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Keep the UI minimal while in truck: do not display the bulky bottom screen box
	panel.visible = false

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.09, 0.14, 0.90)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.24, 0.65, 0.95, 0.7)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	panel.add_theme_stylebox_override("panel", sb)
	root.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	panel.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.name = "TitleLabel"
	title_lbl.text = vehicle_name.to_upper() + " // COCKPIT CONTROLS"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 11)
	title_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0, 0.9))
	vbox.add_child(title_lbl)

	# Hull Integrity Progress Bar Row
	var hull_row := HBoxContainer.new()
	hull_row.name = "HullRow"
	hull_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hull_row.add_theme_constant_override("separation", 8)
	vbox.add_child(hull_row)

	var hull_lbl := Label.new()
	hull_lbl.text = "HULL"
	hull_lbl.add_theme_font_size_override("font_size", 10)
	hull_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0, 0.85))
	hull_row.add_child(hull_lbl)

	var hull_bar := ProgressBar.new()
	hull_bar.name = "VehicleHullBar"
	hull_bar.custom_minimum_size = Vector2(280, 8)
	hull_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hull_bar.show_percentage = false
	hull_bar.max_value = max_health
	hull_bar.value = current_health if current_health >= 0 else max_health

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.04, 0.06, 0.09, 0.9)
	bar_bg.corner_radius_top_left = 2
	bar_bg.corner_radius_top_right = 2
	bar_bg.corner_radius_bottom_right = 2
	bar_bg.corner_radius_bottom_left = 2
	hull_bar.add_theme_stylebox_override("background", bar_bg)

	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.2, 0.82, 0.98, 1.0)
	bar_fill.corner_radius_top_left = 2
	bar_fill.corner_radius_top_right = 2
	bar_fill.corner_radius_bottom_right = 2
	bar_fill.corner_radius_bottom_left = 2
	hull_bar.add_theme_stylebox_override("fill", bar_fill)
	hull_row.add_child(hull_bar)

	var hp_readout := Label.new()
	hp_readout.name = "VehicleHealthReadout"
	hp_readout.text = ""
	hp_readout.visible = false
	hull_row.add_child(hp_readout)

	var keys_lbl := Label.new()
	keys_lbl.text = "[W/S] Drive   [A/D] Steer   [SPACE] Brake   [H] Horn   [L] Headlights   [E] Exit"
	keys_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keys_lbl.add_theme_font_size_override("font_size", 12)
	keys_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98, 1.0))
	vbox.add_child(keys_lbl)

	# Smooth entrance fade
	root.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(root, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## Updates the vehicle hull bar indicator dynamically without numeric clutter.
func update_vehicle_health(current_hp: int, max_hp: int = 100) -> void:
	if not is_instance_valid(_vehicle_hint):
		return
	var hull_bar : ProgressBar = _vehicle_hint.find_child("VehicleHullBar", true, false) as ProgressBar
	var readout : Label = _vehicle_hint.find_child("VehicleHealthReadout", true, false) as Label
	if hull_bar != null:
		hull_bar.max_value = max_hp
		var tween := create_tween()
		tween.tween_property(hull_bar, "value", float(current_hp), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

		var fill : StyleBox = hull_bar.get_theme_stylebox("fill")
		if fill is StyleBoxFlat:
			var fill_flat := fill as StyleBoxFlat
			var ratio : float = float(current_hp) / float(max_hp)
			var target_color : Color = Color(0.2, 0.82, 0.98, 1.0)
			if ratio <= 0.25:
				target_color = Color(0.95, 0.25, 0.2, 1.0)
			elif ratio <= 0.5:
				target_color = Color(0.96, 0.74, 0.18, 1.0)
			fill_flat.bg_color = target_color
	if readout != null:
		readout.text = ""
		readout.visible = false

## Creates the dedicated Minimalist Weapon & Ammo HUD on the left (no box, no outline).
func _setup_weapon_hud() -> void:
	if is_instance_valid(_weapon_hud):
		_weapon_hud.queue_free()

	var cl := CanvasLayer.new()
	cl.layer = 12
	_weapon_hud = cl
	add_child(cl)

	var root := Control.new()
	root.name = "WeaponHudRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(root)

	# Minimal HUD on the bottom-left, positioned gracefully above health bar (zero overlap)
	var panel := PanelContainer.new()
	panel.name = "WeaponPanel"
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.anchor_left = 0.0
	panel.anchor_right = 0.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 24.0
	panel.offset_right = 310.0
	panel.offset_top = -196.0
	panel.offset_bottom = -140.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var w_sb := StyleBoxFlat.new()
	w_sb.bg_color = Color(0.04, 0.06, 0.10, 0.60)
	w_sb.border_width_left = 1
	w_sb.border_width_top = 1
	w_sb.border_width_right = 1
	w_sb.border_width_bottom = 1
	w_sb.border_color = Color(0.25, 0.38, 0.52, 0.45)
	w_sb.corner_radius_top_left = 4
	w_sb.corner_radius_top_right = 4
	w_sb.corner_radius_bottom_right = 4
	w_sb.corner_radius_bottom_left = 4
	w_sb.content_margin_left = 8.0
	w_sb.content_margin_right = 8.0
	w_sb.content_margin_top = 4.0
	w_sb.content_margin_bottom = 4.0
	panel.add_theme_stylebox_override("panel", w_sb)
	root.add_child(panel)

	var container := HBoxContainer.new()
	container.name = "WeaponContainer"
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_theme_constant_override("separation", 10)
	panel.add_child(container)
	_weapon_panel = panel # alias for compatibility

	# Clean procedural vector icon
	var icon := WeaponIcon.new()
	icon.name = "WeaponIcon"
	icon.custom_minimum_size = Vector2(56, 30)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.pivot_offset = Vector2(28, 15)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(icon)
	_weapon_icon = icon

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.name = "WeaponName"
	name_lbl.text = "BASIC PISTOL"
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color", Color(0.45, 0.88, 1.0, 0.95))
	name_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	name_lbl.add_theme_constant_override("shadow_offset_x", 0)
	name_lbl.add_theme_constant_override("shadow_offset_y", 1)
	vbox.add_child(name_lbl)
	_weapon_name_label = name_lbl

	var ammo_lbl := Label.new()
	ammo_lbl.name = "AmmoCount"
	ammo_lbl.text = "AMMO: ∞"
	ammo_lbl.add_theme_font_size_override("font_size", 16)
	ammo_lbl.add_theme_color_override("font_color", Color(0.98, 0.98, 1.0, 1.0))
	ammo_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	ammo_lbl.add_theme_constant_override("shadow_offset_x", 0)
	ammo_lbl.add_theme_constant_override("shadow_offset_y", 1)
	vbox.add_child(ammo_lbl)
	_weapon_ammo_label = ammo_lbl

	var sec_lbl := Label.new()
	sec_lbl.name = "SecondarySlot"
	sec_lbl.text = "[2] NO SPECIAL WEAPON"
	sec_lbl.add_theme_font_size_override("font_size", 10)
	sec_lbl.add_theme_color_override("font_color", Color(0.6, 0.72, 0.85, 0.65))
	sec_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	sec_lbl.add_theme_constant_override("shadow_offset_x", 0)
	sec_lbl.add_theme_constant_override("shadow_offset_y", 1)
	vbox.add_child(sec_lbl)
	_weapon_secondary_label = sec_lbl

## Sets the radar scanning radius on the tactical minimap (e.g. for Explorer class perk).
func set_radar_radius(radius: float) -> void:
	if is_instance_valid(_minimap):
		_minimap.radar_world_radius = radius

## Updates dual weapon inventory status on the HUD.
func update_dual_weapons(active_slot: int, slot1_name: String, _slot1_ammo: int, _slot1_max: int, slot2_name: String, slot2_ammo: int, slot2_max: int) -> void:
	if not is_instance_valid(_weapon_name_label) or not is_instance_valid(_weapon_ammo_label):
		return

	var is_slot_1 : bool = (active_slot == 1)
	var active_name : String = slot1_name if is_slot_1 else slot2_name
	var active_ammo : int = 0 if is_slot_1 else slot2_ammo
	var active_max : int = 0 if is_slot_1 else slot2_max

	# Update active weapon name & ammo
	update_weapon_ammo(active_name, active_ammo, active_max)

	# Update secondary weapon slot indicator
	if is_instance_valid(_weapon_secondary_label):
		if is_slot_1:
			if slot2_name != "NONE" and slot2_ammo > 0:
				_weapon_secondary_label.text = "[2] %s (%d/%d)  [Q/2 to equip]" % [slot2_name, slot2_ammo, slot2_max]
				_weapon_secondary_label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.35, 0.9))
			else:
				_weapon_secondary_label.text = "[2] NO SPECIAL WEAPON"
				_weapon_secondary_label.add_theme_color_override("font_color", Color(0.55, 0.65, 0.75, 0.5))
		else:
			_weapon_secondary_label.text = "[1] %s (∞)  [Q/1 to equip]" % slot1_name
			_weapon_secondary_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.1, 0.85) if "WRENCH" in slot1_name else Color(0.4, 0.85, 1.0, 0.85))

## Updates the HUD weapon display with active weapon name and remaining rounds.
func update_weapon_ammo(weapon_name: String, current_ammo: int, max_ammo: int) -> void:
	if not is_instance_valid(_weapon_name_label) or not is_instance_valid(_weapon_ammo_label):
		return

	var upper_name := weapon_name.to_upper()
	_weapon_name_label.text = upper_name

	var accent_col := Color(0.45, 0.88, 1.0)
	var type_idx : int = 0
	if "SHOTGUN" in upper_name:
		accent_col = Color(1.0, 0.62, 0.18)
		type_idx = 1
	elif "SNIPER" in upper_name:
		accent_col = Color(0.25, 0.85, 1.0)
		type_idx = 2
	elif "DOUBLE" in upper_name:
		accent_col = Color(0.35, 1.0, 0.5)
		type_idx = 3
	elif "ROCKET" in upper_name:
		accent_col = Color(1.0, 0.3, 0.25)
		type_idx = 4
	elif "WRENCH" in upper_name:
		accent_col = Color(1.0, 0.55, 0.1) # Hazard Orange
		type_idx = 5

	_weapon_name_label.add_theme_color_override("font_color", accent_col)

	if is_instance_valid(_weapon_icon):
		_weapon_icon.set_weapon(type_idx, accent_col)

	if max_ammo <= 0 or current_ammo <= 0:
		_weapon_ammo_label.text = "AMMO: ∞"
		_weapon_ammo_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98))
	else:
		_weapon_ammo_label.text = "AMMO: %d / %d" % [current_ammo, max_ammo]
		# Warning color when down to last 2 shots
		if current_ammo <= 2:
			_weapon_ammo_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		else:
			_weapon_ammo_label.add_theme_color_override("font_color", Color(0.98, 0.98, 1.0))

	# Subtle firing scale pulse on icon (using Vector2 to prevent type mismatch crash!)
	if is_instance_valid(_weapon_icon):
		var tween := create_tween()
		if tween != null:
			tween.tween_property(_weapon_icon, "scale", Vector2(1.15, 1.15), 0.05).set_trans(Tween.TRANS_QUAD)
			tween.tween_property(_weapon_icon, "scale", Vector2.ONE, 0.08).set_trans(Tween.TRANS_QUAD)

func _on_menu_requested() -> void:
	get_tree().paused = false
	is_sandbox_mode = false
	_cleanup_ui()
	var snd : Node = get_node_or_null("/root/UiSound")
	if snd != null and snd.has_method("play_music"):
		snd.play_music("menu")
	var loader : Node = get_node_or_null("/root/LoadingScreen")
	if loader != null and loader.has_method("load_scene"):
		loader.call("load_scene", MAIN_MENU_SCENE_PATH, "RETURNING TO COMMAND", "INTERFACE // 00", Color(1.0, 1.0, 1.0, 1.0))
	else:
		get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)

## Counts one enemy kill and refreshes the scoreboard.
func add_enemy_kill() -> void:
	enemies_killed += 1
	_update_scoreboard()

func _update_scoreboard() -> void:
	if is_instance_valid(_hud_bar) and _hud_bar.has_method("update_scores"):
		_hud_bar.update_scores(enemies_killed, player_deaths)
	if is_instance_valid(_scoreboard):
		_scoreboard.update_scores(enemies_killed, player_deaths)

## Reloads the current scene and rebinds the UI to the new player's HealthComponent.
func restart() -> void:
	if _is_restarting:
		return
	_is_restarting = true
	_is_setup = false
	get_tree().paused = false

	var snd : Node = get_node_or_null("/root/UiSound")
	if snd != null and snd.has_method("play_music"):
		snd.play_music("game")

	# Clean up current UI nodes
	for child in get_children():
		child.queue_free()
	_game_over = null
	_hud_bar = null
	_scoreboard = null
	_pause_menu = null
	_oob_warning = null
	_minimap = null
	_tactical_map = null
	_vehicle_hint = null
	_weapon_hud = null
	_weapon_name_label = null
	_weapon_ammo_label = null
	_weapon_panel = null
	_weapon_icon = null
	_player_ref = null
	_oob_pulse_timer = 0.5
	health_component = null
	enemies_killed = 0
	# Note: player_deaths is preserved across respawns and only resets on returning to Main Menu.
	if not is_sandbox_mode:
		selected_map_theme = randi() % 3

	var cur_scene : Node = get_tree().current_scene
	var scene_path : String = ""
	if cur_scene != null and not cur_scene.scene_file_path.is_empty():
		scene_path = cur_scene.scene_file_path
	elif is_sandbox_mode:
		scene_path = "res://scenes/debug/health_debug.tscn"
	else:
		scene_path = "res://scenes/main.tscn"
	var old_scene : Node = cur_scene

	var title_text : String = "REINITIALIZING SANDBOX TESTBED" if is_sandbox_mode else "REDEPLOYING SURVIVAL SECTOR"
	var proto_text : String = "PROTOCOL // 02" if is_sandbox_mode else "PROTOCOL // 01"
	var accent_color : Color = Color(0.96, 0.68, 0.18, 1.0) if is_sandbox_mode else Color(0.92, 0.22, 0.32, 1.0)

	var loader : Node = get_node_or_null("/root/LoadingScreen")
	if loader != null and loader.has_method("load_scene") and not scene_path.is_empty() and ResourceLoader.exists(scene_path):
		loader.call("load_scene", scene_path, title_text, proto_text, accent_color)
		# Keep _is_restarting true until scene change is fully completed
		while get_tree() != null and get_tree().current_scene == old_scene:
			await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		_is_restarting = false
		return

	if cur_scene != null and not cur_scene.scene_file_path.is_empty():
		get_tree().reload_current_scene()
	elif not scene_path.is_empty() and ResourceLoader.exists(scene_path):
		get_tree().change_scene_to_file(scene_path)

	# Wait until scene reload replaces the old scene with a new instance
	while get_tree() != null and get_tree().current_scene == old_scene:
		await get_tree().process_frame

	# Wait for queued frees and scene ready to complete cleanly
	await get_tree().process_frame
	await get_tree().process_frame

	_is_restarting = false
