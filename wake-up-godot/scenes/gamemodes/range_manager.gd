class_name RangeManager
extends Node3D

## Target Practice Range Director
## Controls weapon testing stations, multi-distance shooting lanes,
## target tracking, and range user interface.

const SCENE_TARGET : PackedScene = preload("res://scenes/tutorial/training_target.tscn")
const MAIN_MENU_SCENE_PATH : String = "res://scenes/ui/main_menu.tscn"

@export var player_combat_path : NodePath = "SubViewportContainer/SubViewport/ProtoController/PlayerCombat"
@export var targets_root_path : NodePath = "SubViewportContainer/SubViewport/RangeTargets"
@export var pedestals_root_path : NodePath = "SubViewportContainer/SubViewport/WeaponPedestals"

var _targets_hit : int = 0
var _targets_destroyed : int = 0
var _hud : CanvasLayer = null
var _stats_label : Label = null
var _toast_label : Label = null
var _toast_tween : Tween = null

func _ready() -> void:
	# Configure HUD singleton flags
	var health_hud : Node = get_node_or_null("/root/PlayerHealthHud")
	if health_hud != null:
		if "is_range_mode" in health_hud:
			health_hud.set("is_range_mode", true)
		if "is_tutorial_mode" in health_hud:
			health_hud.set("is_tutorial_mode", false)
		if "is_sandbox_mode" in health_hud:
			health_hud.set("is_sandbox_mode", false)

	_setup_range_hud()
	_setup_weapon_pedestals.call_deferred()
	_connect_targets.call_deferred()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			reset_all_targets()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			_return_to_menu()
			get_viewport().set_input_as_handled()

func _setup_range_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "RangeHUD"
	_hud.layer = 20
	add_child(_hud)

	var root_ctrl := Control.new()
	root_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(root_ctrl)

	# 1. Top Range Title Banner
	var top_panel := PanelContainer.new()
	top_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_panel.offset_top = 16.0
	top_panel.offset_left = 180.0
	top_panel.offset_right = -180.0
	root_ctrl.add_child(top_panel)

	var top_sb := StyleBoxFlat.new()
	top_sb.bg_color = Color(0.06, 0.08, 0.12, 0.85)
	top_sb.border_width_bottom = 2
	top_sb.border_color = Color(0.2, 0.72, 1.0, 0.9) # Range Cyan
	top_sb.corner_radius_bottom_left = 4
	top_sb.corner_radius_bottom_right = 4
	top_sb.content_margin_top = 8.0
	top_sb.content_margin_bottom = 8.0
	top_panel.add_theme_stylebox_override("panel", top_sb)

	var title_vbox := VBoxContainer.new()
	title_vbox.add_theme_constant_override("separation", 2)
	title_panel_contents(title_vbox)
	top_panel.add_child(title_vbox)

	# 2. Right Side Action & Quick Controls
	var right_box := VBoxContainer.new()
	right_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right_box.offset_top = 20.0
	right_box.offset_right = -24.0
	right_box.add_theme_constant_override("separation", 8)
	root_ctrl.add_child(right_box)

	var reset_btn := Button.new()
	reset_btn.text = "RESET TARGETS [R]"
	reset_btn.custom_minimum_size = Vector2(160, 36)
	_style_hud_button(reset_btn, Color(0.2, 0.75, 1.0))
	reset_btn.pressed.connect(reset_all_targets)
	right_box.add_child(reset_btn)

	var menu_btn := Button.new()
	menu_btn.text = "EXIT TO MENU [ESC]"
	menu_btn.custom_minimum_size = Vector2(160, 36)
	_style_hud_button(menu_btn, Color(0.85, 0.35, 0.35))
	menu_btn.pressed.connect(_return_to_menu)
	right_box.add_child(menu_btn)

	# 3. Toast Message (Weapon Equipped notification)
	_toast_label = Label.new()
	_toast_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast_label.offset_bottom = -110.0
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.add_theme_font_size_override("font_size", 16)
	_toast_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_toast_label.modulate.a = 0.0
	root_ctrl.add_child(_toast_label)

func title_panel_contents(vbox: VBoxContainer) -> void:
	var title_lbl := Label.new()
	title_lbl.text = "THE RANGE  //  WEAPONS PROVING GROUNDS"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	vbox.add_child(title_lbl)

	_stats_label = Label.new()
	_stats_label.text = "TARGETS ENGAGED: 0   |   TARGETS DESTROYED: 0   |   APPROACH ANY PEDESTAL TO EQUIP WEAPON"
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_label.add_theme_font_size_override("font_size", 11)
	_stats_label.add_theme_color_override("font_color", Color(0.55, 0.75, 0.95))
	vbox.add_child(_stats_label)

func _style_hud_button(btn: Button, accent: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.1, 0.14, 0.85)
	sb.border_width_left = 2
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 2
	sb.border_color = accent
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_right = 4
	sb.corner_radius_bottom_left = 4
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_color_override("font_color", Color.WHITE)

func _connect_targets() -> void:
	var targets_node : Node = get_node_or_null(targets_root_path)
	if targets_node == null:
		return
	for c in targets_node.get_children():
		if c is TrainingTarget:
			var target := c as TrainingTarget
			target.target_destroyed.connect(_on_target_destroyed)
			var hc : HealthComponent = target.get_node_or_null("HealthComponent") as HealthComponent
			if hc != null:
				hc.health_changed.connect(_on_target_hit)

func _on_target_hit(_cur: int, _max_hp: int) -> void:
	_targets_hit += 1
	_update_stats_display()

func _on_target_destroyed(_target: TrainingTarget) -> void:
	_targets_destroyed += 1
	_update_stats_display()

func _update_stats_display() -> void:
	if _stats_label != null:
		_stats_label.text = "TARGETS ENGAGED: %d   |   TARGETS DESTROYED: %d   |   APPROACH ANY PEDESTAL TO EQUIP WEAPON" % [_targets_hit, _targets_destroyed]

## Resets and pops back up all targets on the range with smooth spring animation
func reset_all_targets() -> void:
	var targets_node : Node = get_node_or_null(targets_root_path)
	if targets_node == null:
		return
	for c in targets_node.get_children():
		if c is TrainingTarget:
			(c as TrainingTarget).reset_target()

	var snd : Node = get_node_or_null("/root/UiSound")
	if snd != null and snd.has_method("play_click"):
		snd.play_click()
	show_toast("ALL TARGETS RESET")

## Builds and registers the 6 interactive weapon pedestals
func _setup_weapon_pedestals() -> void:
	var root : Node = get_node_or_null(pedestals_root_path)
	if root == null:
		return

	var weapon_configs := [
		{"type": 0, "name": "STANDARD PISTOL", "col": Color(0.4, 0.85, 1.0), "x": -7.5},
		{"type": 1, "name": "BREACHER SHOTGUN", "col": Color(1.0, 0.62, 0.18), "x": -4.5},
		{"type": 2, "name": "MARKSMAN SNIPER", "col": Color(0.25, 0.85, 1.0), "x": -1.5},
		{"type": 3, "name": "DUAL SIDEARMS", "col": Color(0.35, 1.0, 0.5), "x": 1.5},
		{"type": 4, "name": "ROCKET LAUNCHER", "col": Color(1.0, 0.3, 0.25), "x": 4.5},
		{"type": 5, "name": "TACTICAL WRENCH", "col": Color(1.0, 0.55, 0.1), "x": 7.5},
	]

	for cfg in weapon_configs:
		var pedestal := _create_weapon_pedestal(cfg["type"], cfg["name"], cfg["col"], Vector3(cfg["x"], 0.0, -3.5))
		root.add_child(pedestal)

func _create_weapon_pedestal(type: int, weapon_name: String, col: Color, pos: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = "Pedestal_" + weapon_name.replace(" ", "_")
	node.position = pos

	# Pedestal Base Cylinder
	var base_mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.55
	cyl.bottom_radius = 0.65
	cyl.height = 0.75
	base_mesh.mesh = cyl
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.12, 0.14, 0.18)
	base_mat.metallic = 0.7
	base_mat.roughness = 0.3
	base_mesh.material_override = base_mat
	base_mesh.position = Vector3(0.0, 0.375, 0.0)
	node.add_child(base_mesh)

	# Holographic Glow Ring
	var ring_mesh := MeshInstance3D.new()
	var ring_cyl := CylinderMesh.new()
	ring_cyl.top_radius = 0.56
	ring_cyl.bottom_radius = 0.56
	ring_cyl.height = 0.06
	ring_mesh.mesh = ring_cyl
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = col
	ring_mat.emission_enabled = true
	ring_mat.emission = col
	ring_mat.emission_energy_multiplier = 2.5
	ring_mesh.material_override = ring_mat
	ring_mesh.position = Vector3(0.0, 0.72, 0.0)
	node.add_child(ring_mesh)

	# 3D Billboard Label
	var sprite := Sprite3D.new()
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.pixel_size = 0.0035
	sprite.position = Vector3(0.0, 1.4, 0.0)
	node.add_child(sprite)

	var sub_viewport := SubViewport.new()
	sub_viewport.size = Vector2i(220, 48)
	sub_viewport.transparent_bg = true
	sprite.add_child(sub_viewport)

	var lbl := Label.new()
	lbl.size = Vector2(220, 48)
	lbl.text = weapon_name + "\n[STAND TO EQUIP]"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", col)
	sub_viewport.add_child(lbl)
	sprite.texture = sub_viewport.get_texture()

	# Proximity Detection Area
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2 # Player CharacterBody3D layer
	var col_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.4, 1.8, 1.4)
	col_shape.shape = box
	col_shape.position = Vector3(0.0, 0.9, 0.0)
	area.add_child(col_shape)
	node.add_child(area)

	area.body_entered.connect(func(body: Node3D):
		if body.is_in_group("player") or body.name.to_lower().contains("proto_controller"):
			_equip_pedestal_weapon(type, weapon_name)
	)

	return node

func _equip_pedestal_weapon(type: int, weapon_name: String) -> void:
	var combat : Node = get_node_or_null(player_combat_path)
	if combat == null:
		var p : Node = get_tree().get_first_node_in_group("player")
		if p != null:
			combat = p.get_node_or_null("PlayerCombat")

	if combat != null:
		if combat.has_method("equip_weapon"):
			combat.call("equip_weapon", type, true)
		if "infinite_ammo" in combat:
			combat.set("infinite_ammo", true)
		if "special_ammo" in combat:
			combat.set("special_ammo", 99)
		if "max_ammo" in combat:
			combat.set("max_ammo", 99)

		var snd : Node = get_node_or_null("/root/UiSound")
		if snd != null and snd.has_method("play_weapon_pickup"):
			snd.play_weapon_pickup()
		show_toast("EQUIPPED: %s (INFINITE AMMO)" % weapon_name)

func show_toast(msg: String) -> void:
	if _toast_label == null:
		return
	_toast_label.text = msg
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast_label, "modulate:a", 1.0, 0.15)
	_toast_tween.tween_interval(1.8)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.4)

func _return_to_menu() -> void:
	var health_hud : Node = get_node_or_null("/root/PlayerHealthHud")
	if health_hud != null:
		if "is_range_mode" in health_hud:
			health_hud.set("is_range_mode", false)

	var snd : Node = get_node_or_null("/root/UiSound")
	if snd != null and snd.has_method("play_music"):
		snd.play_music("menu")

	var loader : Node = get_node_or_null("/root/LoadingScreen")
	if loader != null and loader.has_method("load_scene"):
		loader.call("load_scene", MAIN_MENU_SCENE_PATH, "RETURNING TO COMMAND", "INTERFACE // 00", Color(1.0, 1.0, 1.0, 1.0))
	else:
		get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
