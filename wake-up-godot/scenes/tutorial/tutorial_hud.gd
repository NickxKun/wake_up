class_name TutorialHud
extends CanvasLayer

## Dedicated futuristic HUD overlay for the guided tutorial proving grounds.
## Displays step-by-step guidance, dynamic checklist, distance to waypoint,
## and a polished mission completion celebration screen.

signal replay_requested
signal menu_requested
signal proceed_to_game_requested

@onready var objective_panel : PanelContainer = $Root/TopLeftMargin/ObjectivePanel
@onready var phase_label : Label = $Root/TopLeftMargin/ObjectivePanel/VBoxContainer/HeaderBox/PhaseLabel
@onready var title_label : Label = $Root/TopLeftMargin/ObjectivePanel/VBoxContainer/TitleLabel
@onready var instruction_label : Label = $Root/TopLeftMargin/ObjectivePanel/VBoxContainer/InstructionLabel
@onready var tasks_container : VBoxContainer = $Root/TopLeftMargin/ObjectivePanel/VBoxContainer/TasksContainer
@onready var waypoint_label : Label = $Root/TopLeftMargin/ObjectivePanel/VBoxContainer/WaypointLabel

# Victory / Completion Screen
@onready var victory_modal : Control = $Root/VictoryModal
@onready var victory_stats_label : Label = $Root/VictoryModal/CenterContainer/VBoxContainer/StatsLabel
@onready var btn_survival : Button = $Root/VictoryModal/CenterContainer/VBoxContainer/ButtonsRow/BtnSurvival
@onready var btn_replay : Button = $Root/VictoryModal/CenterContainer/VBoxContainer/ButtonsRow/BtnReplay
@onready var btn_menu : Button = $Root/VictoryModal/CenterContainer/VBoxContainer/ButtonsRow/BtnMenu

var _task_labels : Array[Label] = []
var _target_waypoint : Node3D = null
var _player_ref : Node3D = null

# Screen-Edge & Floating 3D Waypoint Direction Markers
var edge_indicator : Control = null
var edge_arrow : Node2D = null
var edge_reticle : Node2D = null
var edge_dist_label : Label = null

func _ready() -> void:
	victory_modal.visible = false
	_setup_edge_indicator()
	if btn_survival != null:
		btn_survival.pressed.connect(func():
			_play_sound("click")
			proceed_to_game_requested.emit()
		)
	if btn_replay != null:
		btn_replay.pressed.connect(func():
			_play_sound("click")
			replay_requested.emit()
		)
	if btn_menu != null:
		btn_menu.pressed.connect(func():
			_play_sound("click")
			menu_requested.emit()
		)

func set_objective(phase_text: String, title_text: String, instruction_text: String, tasks: Array[Dictionary]) -> void:
	if phase_label != null:
		phase_label.text = phase_text.to_upper()
	if title_label != null:
		title_label.text = title_text
	if instruction_label != null:
		instruction_label.text = instruction_text

	# Clear previous tasks
	for child in tasks_container.get_children():
		child.queue_free()
	_task_labels.clear()

	# Populate tasks list
	for task in tasks:
		var lbl := Label.new()
		var completed : bool = task.get("completed", false)
		var text : String = task.get("text", "")
		lbl.text = ("▣ " if completed else "□ ") + text
		lbl.add_theme_font_size_override("font_size", 12)
		if completed:
			lbl.modulate = Color(0.2, 0.9, 0.4, 0.95)
		else:
			lbl.modulate = Color(0.9, 0.9, 0.95, 0.85)
		tasks_container.add_child(lbl)
		_task_labels.append(lbl)

	# Smooth punch-in tween for new objective
	if objective_panel != null:
		var tween := create_tween()
		objective_panel.scale = Vector2(0.95, 0.95)
		tween.tween_property(objective_panel, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func update_task(index: int, completed: bool, custom_text: String = "") -> void:
	if index >= 0 and index < _task_labels.size():
		var lbl : Label = _task_labels[index]
		var was_completed : bool = lbl.text.begins_with("▣ ")
		var base_text : String = custom_text if custom_text != "" else lbl.text.substr(2)
		lbl.text = ("▣ " if completed else "□ ") + base_text
		if completed:
			lbl.modulate = Color(0.2, 0.9, 0.4, 1.0)
			if not was_completed:
				_play_sound("tab")
				var punch := create_tween()
				punch.tween_property(lbl, "scale", Vector2(1.08, 1.08), 0.08)
				punch.tween_property(lbl, "scale", Vector2.ONE, 0.08)
		else:
			lbl.modulate = Color(0.9, 0.9, 0.95, 0.85)

func track_waypoint(player: Node3D, waypoint: Node3D) -> void:
	_player_ref = player
	_target_waypoint = waypoint

func _setup_edge_indicator() -> void:
	if edge_indicator != null:
		return
	var root : Control = get_node_or_null("Root") as Control
	if root == null:
		return

	edge_indicator = Control.new()
	edge_indicator.name = "EdgeIndicator"
	edge_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge_indicator.visible = false
	edge_indicator.modulate.a = 0.0
	root.add_child(edge_indicator)

	# Container node for rotating the chevron arrow around its origin
	edge_arrow = Node2D.new()
	edge_arrow.name = "ArrowNode"
	edge_indicator.add_child(edge_arrow)

	# Glowing cyber chevron polygon
	var poly := Polygon2D.new()
	poly.color = Color(0.2, 0.85, 1.0, 0.95)
	poly.polygon = PackedVector2Array([
		Vector2(16.0, 0.0),
		Vector2(-8.0, -10.0),
		Vector2(-2.0, 0.0),
		Vector2(-8.0, 10.0)
	])
	edge_arrow.add_child(poly)

	# Inner glowing core
	var poly_core := Polygon2D.new()
	poly_core.color = Color(1.0, 1.0, 1.0, 0.95)
	poly_core.polygon = PackedVector2Array([
		Vector2(12.0, 0.0),
		Vector2(-5.0, -5.0),
		Vector2(0.0, 0.0),
		Vector2(-5.0, 5.0)
	])
	edge_arrow.add_child(poly_core)

	# Holographic Floating 3D Target Reticle (shown when waypoint is on-screen)
	edge_reticle = Node2D.new()
	edge_reticle.name = "ReticleNode"
	edge_reticle.visible = false
	edge_indicator.add_child(edge_reticle)

	var ret_outer := Polygon2D.new()
	ret_outer.color = Color(0.2, 0.88, 1.0, 0.85)
	ret_outer.polygon = PackedVector2Array([
		Vector2(0, -9),
		Vector2(9, 0),
		Vector2(0, 9),
		Vector2(-9, 0)
	])
	edge_reticle.add_child(ret_outer)

	var ret_inner := Polygon2D.new()
	ret_inner.color = Color(1.0, 1.0, 1.0, 0.95)
	ret_inner.polygon = PackedVector2Array([
		Vector2(0, -5),
		Vector2(5, 0),
		Vector2(0, 5),
		Vector2(-5, 0)
	])
	edge_reticle.add_child(ret_inner)

	# Distance Badge beneath the arrow / reticle
	edge_dist_label = Label.new()
	edge_dist_label.name = "DistanceBadge"
	edge_dist_label.add_theme_font_size_override("font_size", 11)
	edge_dist_label.add_theme_color_override("font_color", Color(0.9, 0.96, 1.0, 0.95))
	edge_dist_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	edge_dist_label.add_theme_constant_override("shadow_offset_x", 1)
	edge_dist_label.add_theme_constant_override("shadow_offset_y", 1)
	edge_dist_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	edge_dist_label.custom_minimum_size = Vector2(60, 16)
	edge_dist_label.position = Vector2(-30, 12)
	edge_indicator.add_child(edge_dist_label)

func _process(delta: float) -> void:
	if waypoint_label != null:
		if is_instance_valid(_player_ref) and is_instance_valid(_target_waypoint) and _target_waypoint.visible:
			var dist : float = _player_ref.global_position.distance_to(_target_waypoint.global_position)
			waypoint_label.visible = true
			waypoint_label.text = "◈ WAYPOINT // %04.1f M" % dist
		else:
			waypoint_label.visible = false

	_update_edge_indicator(delta)

func _update_edge_indicator(delta: float) -> void:
	if edge_indicator == null:
		return

	if not is_instance_valid(_player_ref) or not is_instance_valid(_target_waypoint) or not _target_waypoint.visible:
		edge_indicator.visible = false
		return

	var viewport : Viewport = get_viewport()
	if viewport == null:
		edge_indicator.visible = false
		return

	var camera : Camera3D = null
	if is_inside_tree():
		var tree : SceneTree = get_tree()
		if tree != null:
			camera = tree.get_first_node_in_group("camera") as Camera3D
	if camera == null:
		camera = viewport.get_camera_3d()
	if camera == null:
		edge_indicator.visible = false
		return

	var wp_pos : Vector3 = _target_waypoint.global_position + Vector3(0.0, 1.4, 0.0)
	var player_pos : Vector3 = _player_ref.global_position
	var dist : float = player_pos.distance_to(wp_pos)

	var vp_size : Vector2 = viewport.get_visible_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return

	var cam_vp : Viewport = camera.get_viewport()
	var unprojected : Vector2 = camera.unproject_position(wp_pos)
	var screen_pos : Vector2 = unprojected
	if cam_vp != null and cam_vp != viewport and cam_vp.size.x > 0 and cam_vp.size.y > 0:
		screen_pos = Vector2(
			unprojected.x * (vp_size.x / float(cam_vp.size.x)),
			unprojected.y * (vp_size.y / float(cam_vp.size.y))
		)

	var center : Vector2 = vp_size * 0.5
	var is_behind : bool = camera.is_position_behind(wp_pos)

	if is_behind:
		screen_pos = center - (screen_pos - center)

	var dir_to_target : Vector2 = screen_pos - center
	if dir_to_target.length_squared() < 0.001:
		dir_to_target = Vector2.UP
	else:
		dir_to_target = dir_to_target.normalized()

	var margin : float = 45.0
	var min_bound := Vector2(margin, margin)
	var max_bound := vp_size - Vector2(margin, margin)

	var is_offscreen : bool = is_behind or screen_pos.x < min_bound.x or screen_pos.x > max_bound.x or screen_pos.y < min_bound.y or screen_pos.y > max_bound.y

	var target_pos : Vector2
	if is_offscreen:
		# Calculate screen-edge intersection
		var t_x : float = ((max_bound.x if dir_to_target.x > 0.0 else min_bound.x) - center.x) / dir_to_target.x if absf(dir_to_target.x) > 0.0001 else 999999.0
		var t_y : float = ((max_bound.y if dir_to_target.y > 0.0 else min_bound.y) - center.y) / dir_to_target.y if absf(dir_to_target.y) > 0.0001 else 999999.0
		var t_edge : float = minf(absf(t_x), absf(t_y))
		var clamped_pos : Vector2 = center + dir_to_target * t_edge
		clamped_pos.x = clampf(clamped_pos.x, min_bound.x, max_bound.x)
		clamped_pos.y = clampf(clamped_pos.y, min_bound.y, max_bound.y)
		target_pos = clamped_pos

		if edge_arrow != null:
			edge_arrow.visible = true
			edge_arrow.rotation = dir_to_target.angle()
		if edge_reticle != null:
			edge_reticle.visible = false
	else:
		# Floating on-screen 3D reticle hovering directly above waypoint
		target_pos = screen_pos
		if edge_arrow != null:
			edge_arrow.visible = false
		if edge_reticle != null:
			edge_reticle.visible = true
			edge_reticle.rotation = Time.get_ticks_msec() * 0.002

	edge_indicator.visible = true
	if edge_indicator.global_position.length_squared() < 1.0:
		edge_indicator.global_position = target_pos
	else:
		edge_indicator.global_position = edge_indicator.global_position.lerp(target_pos, clampf(delta * 22.0, 0.0, 1.0))

	if edge_dist_label != null:
		edge_dist_label.text = "%.0fM" % dist

	# Always clearly visible with gentle breathing pulse
	var pulse : float = sin(Time.get_ticks_msec() * 0.006) * 0.12 + 0.88
	edge_indicator.modulate.a = pulse

func show_victory(completion_time: float, targets_hit: int, hostiles_cleared: int) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if victory_stats_label != null:
		var minutes : int = int(completion_time) / 60
		var seconds : int = int(completion_time) % 60
		victory_stats_label.text = "COURSE TIME: %02d:%02d   •   TARGETS HIT: %d/3   •   HOSTILES NEUTRALIZED: %d" % [minutes, seconds, targets_hit, hostiles_cleared]

	victory_modal.visible = true
	victory_modal.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(victory_modal, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _play_sound(sound_name: String) -> void:
	var snd : Node = get_node_or_null("/root/UiSound")
	if snd != null:
		if sound_name == "click" and snd.has_method("play_click"):
			snd.call("play_click")
		elif sound_name == "tab" and snd.has_method("play_tab"):
			snd.call("play_tab")
