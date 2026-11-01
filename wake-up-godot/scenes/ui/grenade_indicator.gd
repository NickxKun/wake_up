class_name GrenadeIndicator
extends CanvasLayer

## Holographic Waypoint-Style Grenade Warning Indicator HUD.
## Features:
## - On-screen 3D-tracked hazard diamond reticle hovering directly over the live grenade with fuse countdown.
## - Off-screen edge-clamped directional arrow pointing to the grenade with distance readout.
## - Accelerating strobe/pulse as detonation nears.
## - Automatic fade-out and cleanup when grenade detonates or leaves the scene.

var target_grenade : Area3D = null
var _player_ref : Node3D = null

var edge_indicator : Control = null
var edge_arrow : Node2D = null
var edge_reticle : Node2D = null
var edge_dist_label : Label = null
var edge_tag_label : Label = null
var _is_fading : bool = false
var _alpha : float = 1.0

func _init() -> void:
	layer = 15

func _ready() -> void:
	_setup_indicator_ui()

func setup(grenade: Area3D, player: Node3D = null) -> void:
	target_grenade = grenade
	_player_ref = player

func _setup_indicator_ui() -> void:
	if edge_indicator != null:
		return

	edge_indicator = Control.new()
	edge_indicator.name = "GrenadeEdgeIndicator"
	edge_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge_indicator.visible = false
	add_child(edge_indicator)

	# 1. Directional Arrow for off-screen tracking (Waypoint style)
	edge_arrow = Node2D.new()
	edge_arrow.name = "ArrowNode"
	edge_indicator.add_child(edge_arrow)

	# Outer glowing red danger chevron
	var poly_outer := Polygon2D.new()
	poly_outer.color = Color(1.0, 0.22, 0.12, 0.95)
	poly_outer.polygon = PackedVector2Array([
		Vector2(20, 0),
		Vector2(-10, -14),
		Vector2(-4, 0),
		Vector2(-10, 14)
	])
	edge_arrow.add_child(poly_outer)

	# Inner bright orange accent chevron
	var poly_inner := Polygon2D.new()
	poly_inner.color = Color(1.0, 0.75, 0.2, 0.95)
	poly_inner.polygon = PackedVector2Array([
		Vector2(14, 0),
		Vector2(-6, -8),
		Vector2(-2, 0),
		Vector2(-6, 8)
	])
	edge_arrow.add_child(poly_inner)

	# 2. Holographic Floating 3D Target Reticle (shown when grenade is on-screen)
	edge_reticle = Node2D.new()
	edge_reticle.name = "ReticleNode"
	edge_reticle.visible = false
	edge_indicator.add_child(edge_reticle)

	# Pulsing hazard diamond
	var ret_diamond := Polygon2D.new()
	ret_diamond.color = Color(1.0, 0.22, 0.12, 0.85)
	ret_diamond.polygon = PackedVector2Array([
		Vector2(0, -18),
		Vector2(18, 0),
		Vector2(0, 18),
		Vector2(-18, 0),
		Vector2(0, -14),
		Vector2(14, 0),
		Vector2(0, 14),
		Vector2(-14, 0)
	])
	edge_reticle.add_child(ret_diamond)

	# Exclamation mark center
	var alert_poly := Polygon2D.new()
	alert_poly.color = Color(1.0, 0.95, 0.9, 1.0)
	alert_poly.polygon = PackedVector2Array([
		Vector2(-2, -8),
		Vector2(2, -8),
		Vector2(1.5, 2),
		Vector2(-1.5, 2)
	])
	edge_reticle.add_child(alert_poly)

	var alert_dot := Polygon2D.new()
	alert_dot.color = Color(1.0, 0.95, 0.9, 1.0)
	alert_dot.polygon = PackedVector2Array([
		Vector2(-2, 5),
		Vector2(2, 5),
		Vector2(2, 9),
		Vector2(-2, 9)
	])
	edge_reticle.add_child(alert_dot)

	# 3. Distance & Alert Labels
	edge_dist_label = Label.new()
	edge_dist_label.name = "DistLabel"
	edge_dist_label.add_theme_font_size_override("font_size", 11)
	edge_dist_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	edge_dist_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	edge_dist_label.add_theme_constant_override("shadow_offset_x", 1)
	edge_dist_label.add_theme_constant_override("shadow_offset_y", 1)
	edge_dist_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	edge_dist_label.custom_minimum_size = Vector2(80, 16)
	edge_dist_label.position = Vector2(-40, 16)
	edge_indicator.add_child(edge_dist_label)

	edge_tag_label = Label.new()
	edge_tag_label.name = "TagLabel"
	edge_tag_label.add_theme_font_size_override("font_size", 9)
	edge_tag_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.2))
	edge_tag_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	edge_tag_label.add_theme_constant_override("shadow_offset_x", 1)
	edge_tag_label.add_theme_constant_override("shadow_offset_y", 1)
	edge_tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	edge_tag_label.custom_minimum_size = Vector2(80, 14)
	edge_tag_label.position = Vector2(-40, -32)
	edge_tag_label.text = "▲ GRENADE"
	edge_indicator.add_child(edge_tag_label)

func _process(delta: float) -> void:
	if not is_instance_valid(target_grenade) or target_grenade.is_queued_for_deletion():
		_start_fade_out(delta)
		return

	if "is_detonated" in target_grenade and target_grenade.get("is_detonated") == true:
		_start_fade_out(delta)
		return
	if "_detonated" in target_grenade and target_grenade.get("_detonated") == true:
		_start_fade_out(delta)
		return

	_update_position_and_draw(delta)

func _start_fade_out(delta: float) -> void:
	_is_fading = true
	_alpha -= delta * 5.0
	if edge_indicator != null:
		edge_indicator.modulate.a = maxf(_alpha, 0.0)
	if _alpha <= 0.0:
		queue_free()

func _update_position_and_draw(delta: float) -> void:
	if edge_indicator == null or not is_instance_valid(target_grenade):
		return

	var viewport : Viewport = get_viewport()
	if viewport == null:
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

	var grn_pos : Vector3 = target_grenade.global_position + Vector3(0.0, 0.5, 0.0)

	# Resolve player position for distance readout
	if _player_ref == null or not is_instance_valid(_player_ref):
		var tree : SceneTree = get_tree()
		if tree != null:
			_player_ref = tree.get_first_node_in_group("player") as Node3D

	var player_pos : Vector3 = _player_ref.global_position if is_instance_valid(_player_ref) else camera.global_position
	var dist : float = player_pos.distance_to(grn_pos)

	var vp_size : Vector2 = viewport.get_visible_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return

	var cam_vp : Viewport = camera.get_viewport()
	var unprojected : Vector2 = camera.unproject_position(grn_pos)
	var screen_pos : Vector2 = unprojected
	if cam_vp != null and cam_vp != viewport and cam_vp.size.x > 0 and cam_vp.size.y > 0:
		screen_pos = Vector2(
			unprojected.x * (vp_size.x / float(cam_vp.size.x)),
			unprojected.y * (vp_size.y / float(cam_vp.size.y))
		)

	var center : Vector2 = vp_size * 0.5
	var is_behind : bool = camera.is_position_behind(grn_pos)
	if is_behind:
		screen_pos = center - (screen_pos - center)

	var dir_to_target : Vector2 = screen_pos - center
	if dir_to_target.length_squared() < 0.001:
		dir_to_target = Vector2.UP
	else:
		dir_to_target = dir_to_target.normalized()

	var margin : float = 50.0
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
		target_pos = screen_pos
		if edge_arrow != null:
			edge_arrow.visible = false
		if edge_reticle != null:
			edge_reticle.visible = true
			edge_reticle.rotation = Time.get_ticks_msec() * 0.003

	edge_indicator.visible = true
	if edge_indicator.global_position.length_squared() < 1.0:
		edge_indicator.global_position = target_pos
	else:
		edge_indicator.global_position = edge_indicator.global_position.lerp(target_pos, clampf(delta * 24.0, 0.0, 1.0))

	# Fuse countdown readout
	var fuse_left : float = target_grenade.get("_fuse_remaining") if "_fuse_remaining" in target_grenade else 1.0
	if edge_dist_label != null:
		edge_dist_label.text = "%.0fM // %.1fs" % [dist, maxf(fuse_left, 0.0)]

	# Accelerating urgency pulse
	var fuse_ratio : float = clampf(fuse_left / 1.4, 0.0, 1.0)
	var pulse_speed : float = lerpf(24.0, 8.0, fuse_ratio)
	var pulse : float = sin(Time.get_ticks_msec() * 0.001 * pulse_speed) * 0.25 + 0.75
	edge_indicator.modulate.a = pulse * _alpha
