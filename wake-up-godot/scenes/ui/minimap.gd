class_name Minimap
extends CanvasLayer

## Minimal, clean tactical HUD radar matching the game's sleek floating aesthetic.
## Provides real-time radar tracking of player orientation, safe sector boundaries,
## and hostile bio-signals with zero visual clutter.

@export var radar_world_radius : float = 26.0
@export var safe_zone_half_size : float = 15.5
@export var show_map_borders : bool = false

var _player_ref : WeakRef = null
var _is_out_of_bounds : bool = false
var _oob_flash_timer : float = 0.0

@onready var radar_canvas : Control = $RootControl/Container/RadarCanvas
@onready var coords_label : Label = $RootControl/Container/TelemetryRow/CoordsLabel
@onready var status_label : Label = $RootControl/Container/TelemetryRow/StatusLabel

func _ready() -> void:
	layer = 10
	if radar_canvas != null:
		radar_canvas.draw.connect(_on_radar_draw)

func bind_player(player: Node3D) -> void:
	_player_ref = weakref(player)

func set_out_of_bounds(oob: bool) -> void:
	_is_out_of_bounds = oob

func _process(delta: float) -> void:
	if _player_ref == null:
		return
	var player : Node3D = _player_ref.get_ref() as Node3D
	if player == null or not is_instance_valid(player):
		return

	_oob_flash_timer += delta * 6.0
	_update_telemetry(player)

	if radar_canvas != null:
		radar_canvas.queue_redraw()

func _update_telemetry(player: Node3D) -> void:
	var pos : Vector3 = player.global_position
	if coords_label != null:
		coords_label.text = "%+04.1f, %+04.1f" % [pos.x, pos.z]

	if status_label != null:
		if _is_out_of_bounds:
			status_label.text = "HAZARD"
			var flash : float = sin(_oob_flash_timer) * 0.5 + 0.5
			status_label.modulate = Color(1.0, 0.3 + 0.3 * flash, 0.35 + 0.35 * flash, 1.0)
		else:
			status_label.text = "NOMINAL"
			status_label.modulate = Color(0.2, 0.88, 0.95, 0.85)

func _on_radar_draw() -> void:
	if radar_canvas == null:
		return

	var rect_size : Vector2 = radar_canvas.size
	var center : Vector2 = rect_size * 0.5
	var radar_pixel_radius : float = minf(center.x, center.y) - 4.0
	if radar_pixel_radius <= 4.0:
		return

	# 1. Floating semi-transparent circular backdrop
	radar_canvas.draw_circle(center, radar_pixel_radius, Color(0.02, 0.03, 0.06, 0.45))

	# 2. Delicate hairline outer rim
	var rim_color : Color
	if _is_out_of_bounds:
		var flash : float = sin(_oob_flash_timer) * 0.5 + 0.5
		rim_color = Color(0.96, 0.24, 0.32, 0.4 + 0.5 * flash)
	else:
		rim_color = Color(1.0, 1.0, 1.0, 0.14)
	radar_canvas.draw_arc(center, radar_pixel_radius, 0.0, TAU, 64, rim_color, 1.0, true)

	# 3. Cardinal tick marks (top North accent, subtle ticks at 3, 6, 9 o'clock)
	var tick_col : Color = Color(1.0, 1.0, 1.0, 0.22)
	radar_canvas.draw_line(Vector2(center.x, center.y - radar_pixel_radius), Vector2(center.x, center.y - radar_pixel_radius + 4.0), Color(0.4, 0.85, 1.0, 0.6), 1.2)
	radar_canvas.draw_line(Vector2(center.x, center.y + radar_pixel_radius - 3.0), Vector2(center.x, center.y + radar_pixel_radius), tick_col, 1.0)
	radar_canvas.draw_line(Vector2(center.x - radar_pixel_radius, center.y), Vector2(center.x - radar_pixel_radius + 3.0, center.y), tick_col, 1.0)
	radar_canvas.draw_line(Vector2(center.x + radar_pixel_radius - 3.0, center.y), Vector2(center.x + radar_pixel_radius, center.y), tick_col, 1.0)

	# Minimal "N" indicator at top
	var font : Font = ThemeDB.fallback_font
	if font != null:
		radar_canvas.draw_string(font, Vector2(center.x - 3.0, center.y - radar_pixel_radius + 12.0), "N", HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color(0.7, 0.88, 1.0, 0.5))

	# 4. Faint single range ring
	var scale_factor : float = radar_pixel_radius / radar_world_radius
	var ring_15m : float = 15.0 * scale_factor
	if ring_15m < radar_pixel_radius:
		radar_canvas.draw_arc(center, ring_15m, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.06), 1.0, true)

	if not is_inside_tree() or _player_ref == null:
		return
	var player : Node3D = _player_ref.get_ref() as Node3D
	if player == null or not is_instance_valid(player) or not player.is_inside_tree():
		return

	var p_pos : Vector3 = player.global_position

	# 5. Station Demarcation Safe Boundary rectangle (disabled by default for a super clean radar aesthetic)
	if show_map_borders:
		var p_min : Vector2 = Vector2(-safe_zone_half_size - p_pos.x, -safe_zone_half_size - p_pos.z) * scale_factor + center
		var p_max : Vector2 = Vector2(safe_zone_half_size - p_pos.x, safe_zone_half_size - p_pos.z) * scale_factor + center
		var bound_col : Color = Color(0.96, 0.28, 0.35, 0.8) if _is_out_of_bounds else Color(1.0, 0.65, 0.18, 0.55)
		_draw_clipped_rect(radar_canvas, center, radar_pixel_radius, p_min, p_max, bound_col)

	# 6. Active Hostile Enemies
	var tree : SceneTree = get_tree()
	if tree != null:
		var enemies : Array[Node] = tree.get_nodes_in_group("enemy")
		for e in enemies:
			if not is_instance_valid(e) or not (e is Node3D) or not (e as Node3D).is_inside_tree():
				continue
			var enemy_pos : Vector3 = (e as Node3D).global_position
			var rel_x : float = (enemy_pos.x - p_pos.x) * scale_factor
			var rel_y : float = (enemy_pos.z - p_pos.z) * scale_factor
			var enemy_radar_pos : Vector2 = center + Vector2(rel_x, rel_y)

			if enemy_radar_pos.distance_to(center) <= radar_pixel_radius - 2.0:
				_draw_enemy_pip(radar_canvas, enemy_radar_pos)

		# 7. Active Mission Waypoints / Objectives
		var waypoints : Array[Node] = tree.get_nodes_in_group("waypoint")
		for wp in waypoints:
			if not is_instance_valid(wp) or not (wp is Node3D) or not (wp as Node3D).is_inside_tree():
				continue
			var is_active : bool = bool(wp.get("is_active")) if "is_active" in wp else (wp as Node3D).visible
			if not is_active:
				continue
			var wp_pos : Vector3 = (wp as Node3D).global_position
			var rel_x : float = (wp_pos.x - p_pos.x) * scale_factor
			var rel_y : float = (wp_pos.z - p_pos.z) * scale_factor
			var dist : float = sqrt(rel_x * rel_x + rel_y * rel_y)
			var max_dist : float = radar_pixel_radius - 5.0

			if dist <= max_dist:
				_draw_waypoint_pip(radar_canvas, center + Vector2(rel_x, rel_y), false, 0.0)
			else:
				var dir : Vector2 = Vector2(rel_x, rel_y) / (dist if dist > 0.0001 else 1.0)
				var edge_pos : Vector2 = center + dir * max_dist
				_draw_waypoint_pip(radar_canvas, edge_pos, true, dir.angle())

	# 8. Player Chevron & Vision Cone at Center
	var facing_angle : float = player.rotation.y
	_draw_player_beacon(radar_canvas, center, facing_angle)

func _draw_clipped_rect(canvas: Control, center: Vector2, radius: float, p_min: Vector2, p_max: Vector2, col: Color) -> void:
	var corners := [
		Vector2(p_min.x, p_min.y),
		Vector2(p_max.x, p_min.y),
		Vector2(p_max.x, p_max.y),
		Vector2(p_min.x, p_max.y),
	]
	for i in range(4):
		var p1 : Vector2 = corners[i]
		var p2 : Vector2 = corners[(i + 1) % 4]
		if p1.distance_to(center) < radius * 1.5 or p2.distance_to(center) < radius * 1.5:
			canvas.draw_line(p1, p2, col, 1.0, true)

func _draw_enemy_pip(canvas: Control, pos: Vector2) -> void:
	var sz : float = 2.8
	var diamond := PackedVector2Array([
		pos + Vector2(0, -sz),
		pos + Vector2(sz, 0),
		pos + Vector2(0, sz),
		pos + Vector2(-sz, 0),
	])
	canvas.draw_colored_polygon(diamond, Color(0.96, 0.22, 0.32, 0.95))
	canvas.draw_circle(pos, 0.9, Color(1.0, 0.88, 0.9, 1.0))

func _draw_waypoint_pip(canvas: Control, pos: Vector2, is_edge: bool, edge_angle: float) -> void:
	var pulse : float = (sin(Time.get_ticks_msec() * 0.006) + 1.0) * 0.5
	if is_edge:
		# Glowing rim chevron pointing toward off-screen objective
		var fwd : Vector2 = Vector2.from_angle(edge_angle)
		var right : Vector2 = Vector2(-fwd.y, fwd.x)
		var arrow_len : float = 6.5
		var arrow_half : float = 4.2
		var tip : Vector2 = pos + fwd * 2.5
		var p1 : Vector2 = pos - fwd * arrow_len + right * arrow_half
		var p2 : Vector2 = pos - fwd * (arrow_len * 0.45)
		var p3 : Vector2 = pos - fwd * arrow_len - right * arrow_half
		var poly := PackedVector2Array([tip, p1, p2, p3])
		canvas.draw_colored_polygon(poly, Color(0.2, 0.88, 1.0, 0.9 + 0.1 * pulse))
		canvas.draw_polyline(poly + PackedVector2Array([tip]), Color(1.0, 1.0, 1.0, 0.95), 1.0, true)
	else:
		# Expanding radar pulse ring
		var ring_r : float = 4.5 + 3.0 * pulse
		canvas.draw_arc(pos, ring_r, 0.0, TAU, 16, Color(0.2, 0.88, 1.0, 0.35 * (1.0 - pulse)), 1.2, true)
		# Holographic diamond icon
		var sz : float = 4.0
		var diamond := PackedVector2Array([
			pos + Vector2(0, -sz),
			pos + Vector2(sz, 0),
			pos + Vector2(0, sz),
			pos + Vector2(-sz, 0),
		])
		canvas.draw_colored_polygon(diamond, Color(0.12, 0.55, 0.85, 0.65))
		canvas.draw_polyline(diamond + PackedVector2Array([diamond[0]]), Color(0.3, 0.95, 1.0, 1.0), 1.2, true)
		canvas.draw_circle(pos, 1.5, Color(1.0, 1.0, 1.0, 0.95))

func _draw_player_beacon(canvas: Control, center: Vector2, facing_angle: float) -> void:
	var angle_2d : float = facing_angle - PI * 0.5

	# Subtle, soft forward vision cone
	var fov_span : float = deg_to_rad(36.0)
	var fov_len : float = 18.0
	var left_pt : Vector2 = center + Vector2(cos(angle_2d - fov_span), sin(angle_2d - fov_span)) * fov_len
	var right_pt : Vector2 = center + Vector2(cos(angle_2d + fov_span), sin(angle_2d + fov_span)) * fov_len
	var cone_poly := PackedVector2Array([center, left_pt, right_pt])
	canvas.draw_colored_polygon(cone_poly, Color(0.2, 0.85, 1.0, 0.08))

	# Razor-sharp white chevron
	var forward := Vector2(cos(angle_2d), sin(angle_2d)).normalized()
	var right := Vector2(-forward.y, forward.x)

	var tip : Vector2 = center + forward * 5.5
	var left_wing : Vector2 = center - forward * 3.5 - right * 3.5
	var right_wing : Vector2 = center - forward * 3.5 + right * 3.5
	var inner_notch : Vector2 = center - forward * 1.2

	var chevron := PackedVector2Array([tip, right_wing, inner_notch, left_wing])
	canvas.draw_colored_polygon(chevron, Color(1.0, 1.0, 1.0, 0.95))
	canvas.draw_polyline(PackedVector2Array([tip, right_wing, inner_notch, left_wing, tip]), Color(0.2, 0.92, 1.0, 1.0), 1.0, true)
