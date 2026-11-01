extends Sprite3D

## Floating sleek health bar over an enemy with smooth tweening and hit flash.

@onready var sub_viewport : SubViewport = $SubViewport
@onready var progress_bar : ProgressBar = $SubViewport/ProgressBar

var _fill_style : StyleBoxFlat
var _tween : Tween
var _flash_tween : Tween
var _base_color : Color = Color(0.95, 0.28, 0.25, 1.0) # Hostile crimson
var _flash_color : Color = Color(1.0, 1.0, 1.0, 1.0)  # White hit flash

func _ready() -> void:
	texture = sub_viewport.get_texture()
	var orig_fill : StyleBox = progress_bar.get_theme_stylebox("fill")
	if orig_fill is StyleBoxFlat:
		_fill_style = orig_fill.duplicate()
	else:
		_fill_style = StyleBoxFlat.new()
		_fill_style.corner_radius_top_left = 3
		_fill_style.corner_radius_top_right = 3
		_fill_style.corner_radius_bottom_right = 3
		_fill_style.corner_radius_bottom_left = 3
	_fill_style.bg_color = _base_color
	progress_bar.add_theme_stylebox_override("fill", _fill_style)

	var health_component : HealthComponent = get_parent().get_node("HealthComponent")
	progress_bar.max_value = HealthComponent.MAX_HEALTH
	progress_bar.value = health_component.health
	health_component.health_changed.connect(_on_health_changed)

func _on_health_changed(new_health : int, old_health : int) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(progress_bar, "value", float(new_health), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if new_health < old_health:
		_flash()

func _flash() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_fill_style.bg_color = _flash_color
	_flash_tween = create_tween()
	_flash_tween.tween_property(_fill_style, "bg_color", _base_color, 0.15)
