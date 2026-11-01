extends Control

## Vector-rendered power-off icon for the quit button.

@export var icon_color : Color = Color(1.0, 1.0, 1.0, 0.75)
@export var radius : float = 7.0

func _draw() -> void:
	var center : Vector2 = size / 2.0
	if center.x <= 0 or center.y <= 0:
		return

	# Power circle arc with open gap at the top (-60 deg to +240 deg)
	draw_arc(center, radius, deg_to_rad(-60.0), deg_to_rad(240.0), 28, icon_color, 1.8, true)

	# Vertical power tick line through the top opening
	var p_top : Vector2 = center - Vector2(0.0, radius + 2.5)
	var p_bottom : Vector2 = center - Vector2(0.0, 1.0)
	draw_line(p_top, p_bottom, icon_color, 1.8, true)

func set_color(new_color: Color) -> void:
	icon_color = new_color
	queue_redraw()
