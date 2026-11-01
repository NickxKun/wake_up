class_name StaminaArc
extends Sprite3D

## Tactical floating holographic stamina arc displayed beside the player.
## Represents 3 continuous dash charges, constantly recharging over time.
## Only visible when stamina is depleted/recharging; smoothly fades away when fully restored.

@export var max_stamina : float = 3.0
var stamina : float = 3.0

@onready var sub_viewport : SubViewport = $SubViewport
@onready var arc_canvas : Control = $SubViewport/ArcCanvas

var _is_fading_out : bool = false
var _fade_tween : Tween
var _flash_tween : Tween
var _flash_intensity : float = 0.0

const ARC_SPAN : float = PI * 0.82 # ~147.6 degrees
const SEGMENT_GAP : float = 0.08    # ~4.6 degrees gap between charges
const ARC_RADIUS : float = 58.0
const ARC_WIDTH : float = 6.0
const CENTER : Vector2 = Vector2(96.0, 96.0)

func _ready() -> void:
	texture = sub_viewport.get_texture()
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	# Initially full, so hide immediately
	modulate.a = 0.0
	visible = false

	# Connect canvas draw call
	if arc_canvas != null:
		arc_canvas.draw.connect(_on_canvas_draw)

## Update stamina level from player controller.
func update_stamina(curr: float, max_val: float) -> void:
	stamina = curr
	max_stamina = max_val

	if stamina < max_stamina - 0.005:
		_show_arc()
	else:
		_hide_arc_smoothly()

	if arc_canvas != null:
		arc_canvas.queue_redraw()

func _show_arc() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_is_fading_out = false
	visible = true
	modulate.a = 1.0

func _hide_arc_smoothly() -> void:
	if _is_fading_out or not visible or modulate.a <= 0.01:
		return

	_is_fading_out = true

	# Brief full charge bloom flash before fade out
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_intensity = 0.6
	_flash_tween.tween_property(self, "_flash_intensity", 0.0, 0.18)

	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_interval(0.2)
	_fade_tween.tween_property(self, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_fade_tween.tween_callback(func() -> void:
		if stamina >= max_stamina - 0.01:
			visible = false
			_is_fading_out = false
	)

func _on_canvas_draw() -> void:
	var total_segments : int = 3
	var seg_length : float = (ARC_SPAN - float(total_segments - 1) * SEGMENT_GAP) / float(total_segments)
	var start_base : float = -ARC_SPAN * 0.5

	# Palette
	var track_color : Color = Color(0.04, 0.08, 0.14, 0.55)
	var rim_color : Color = Color(0.15, 0.35, 0.48, 0.45)
	var active_color : Color = Color(0.20, 0.95, 0.88, 0.95)
	var flash_tint : Color = Color(0.85, 1.0, 0.98, 1.0)
	var current_color : Color = active_color.lerp(flash_tint, _flash_intensity)

	# Low stamina warning (less than 1 full dash available)
	if stamina < 1.0:
		current_color = Color(0.98, 0.68, 0.22, 0.95)

	for i in range(total_segments):
		var seg_start : float = start_base + float(i) * (seg_length + SEGMENT_GAP)
		var seg_end : float = seg_start + seg_length

		# 1. Background Track
		arc_canvas.draw_arc(CENTER, ARC_RADIUS, seg_start, seg_end, 18, track_color, ARC_WIDTH, true)
		# Outer subtle hairline rim
		arc_canvas.draw_arc(CENTER, ARC_RADIUS + ARC_WIDTH * 0.5 + 0.5, seg_start, seg_end, 18, rim_color, 1.0, true)

		# 2. Segment Fill
		var fill_pct : float = clampf((stamina - float(i)) / 1.0, 0.0, 1.0)
		if fill_pct > 0.001:
			var fill_end : float = seg_start + seg_length * fill_pct
			arc_canvas.draw_arc(CENTER, ARC_RADIUS, seg_start, fill_end, 18, current_color, ARC_WIDTH, true)

			# Leading edge pip glow on recharging segment
			if fill_pct < 0.999:
				var head_pos : Vector2 = CENTER + Vector2(cos(fill_end), sin(fill_end)) * ARC_RADIUS
				arc_canvas.draw_circle(head_pos, ARC_WIDTH * 0.55, Color(1.0, 1.0, 1.0, 0.95))
