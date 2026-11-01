extends Control

## Procedural, vector-rendered Destiny-style geometric animated emblem.

@export var emblem_color : Color = Color(1.0, 1.0, 1.0, 0.95)
@export var accent_color : Color = Color(1.0, 1.0, 1.0, 0.75)
@export var base_radius : float = 52.0
@export var spin_speed : float = 0.22

var _time : float = 0.0
var _burst : float = 0.0
var _burst_rot : float = 0.0

func _process(delta: float) -> void:
	_time += delta
	if _burst > 0.0:
		_burst = maxf(_burst - delta * 2.2, 0.0)
		_burst_rot += delta * 6.0 * _burst
	queue_redraw()

## Plays a kinetic flare and rapid spin burst on click.
func play_burst() -> void:
	_burst = 1.0
	queue_redraw()

func _draw() -> void:
	var center : Vector2 = size / 2.0
	if center.x <= 0 or center.y <= 0:
		return

	var current_emblem_color : Color = emblem_color.lerp(Color.WHITE, _burst)
	var current_accent_color : Color = accent_color.lerp(Color.WHITE, _burst)

	# 1. Outer segmented rotating ring (4 arcs)
	var rot_ring : float = _time * spin_speed + _burst_rot
	var arc_width : float = 1.6 + _burst * 0.8
	var outer_r : float = base_radius + _burst * 6.0
	for i in range(4):
		var base_deg : float = float(i) * 90.0
		var start_rad : float = rot_ring + deg_to_rad(base_deg + 12.0)
		var end_rad : float = rot_ring + deg_to_rad(base_deg + 78.0)
		draw_arc(center, outer_r, start_rad, end_rad, 24, current_emblem_color * 0.75, arc_width, true)

	# 2. Outer 4 reticle ticks at 45 degree angles (Destiny target brackets)
	for i in range(4):
		var tick_deg : float = float(i) * 90.0 + 45.0
		var dir : Vector2 = Vector2.from_angle(deg_to_rad(tick_deg))
		var p_start : Vector2 = center + dir * (outer_r + 4.0)
		var p_end : Vector2 = center + dir * (outer_r + 12.0 + _burst * 4.0)
		draw_line(p_start, p_end, current_accent_color * 0.8, 1.5, true)

	# 3. Rotating inner diamond
	var diamond_rot : float = -_time * (spin_speed * 0.7) - _burst_rot * 0.6
	var diamond_r : float = base_radius * 0.66
	var d_pts : PackedVector2Array = [
		center + Vector2(0, -diamond_r).rotated(diamond_rot),
		center + Vector2(diamond_r, 0).rotated(diamond_rot),
		center + Vector2(0, diamond_r).rotated(diamond_rot),
		center + Vector2(-diamond_r, 0).rotated(diamond_rot)
	]
	for i in range(4):
		var p_a : Vector2 = d_pts[i]
		var p_b : Vector2 = d_pts[(i + 1) % 4]
		draw_line(p_a, p_b, current_accent_color, 1.5, true)

	# 4. Subtle inner concentric circle guide
	var guide_r : float = base_radius * 0.42
	draw_arc(center, guide_r, 0.0, TAU, 36, current_emblem_color * 0.25, 1.0, true)

	# 5. Central pulsing geometric chevron / core
	var pulse : float = 1.0 + sin(_time * 2.4) * 0.08 + _burst * 0.4
	var core_r : float = base_radius * 0.26 * pulse
	var top_pt : Vector2 = center + Vector2(0, -core_r * 1.35)
	var br_pt : Vector2 = center + Vector2(core_r * 1.15, core_r * 0.85)
	var bc_pt : Vector2 = center + Vector2(0, core_r * 0.35)
	var bl_pt : Vector2 = center + Vector2(-core_r * 1.15, core_r * 0.85)

	var chevron_pts : PackedVector2Array = [top_pt, br_pt, bc_pt, bl_pt]
	draw_colored_polygon(chevron_pts, Color(1.0, 1.0, 1.0, 0.12 * (1.0 + _burst * 0.5)))
	draw_polyline([top_pt, br_pt, bc_pt, bl_pt, top_pt], current_emblem_color, 1.6, true)

	# 6. Central micro diamond core
	var micro_r : float = 3.0 + _burst * 2.0
	var micro_pts : PackedVector2Array = [
		center + Vector2(0, -micro_r),
		center + Vector2(micro_r, 0),
		center + Vector2(0, micro_r),
		center + Vector2(-micro_r, 0)
	]
	draw_colored_polygon(micro_pts, Color.WHITE)
