class_name VehicleHealthBar
extends Sprite3D

## In-world 3D floating health bar for vehicles with smooth tweening, dynamic color states,
## and hit-flash visual feedback.

@onready var sub_viewport : SubViewport = $SubViewport
@onready var progress_bar : ProgressBar = $SubViewport/ProgressBar
@onready var label : Label = $SubViewport/ProgressBar/Label

var _fill_style : StyleBoxFlat
var _tween : Tween
var _flash_tween : Tween
var _fade_tween : Tween
var _max_health : int = 100
var _current_health : int = 100

const COLOR_HEALTHY : Color = Color(0.2, 0.8, 1.0, 1.0)     # High-tech cyan
const COLOR_DAMAGED : Color = Color(0.96, 0.74, 0.18, 1.0)  # Warning amber
const COLOR_CRITICAL : Color = Color(0.95, 0.25, 0.2, 1.0)  # Critical crimson
const COLOR_FLASH : Color = Color(1.0, 1.0, 1.0, 1.0)       # Hit impact flash

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
	_fill_style.bg_color = COLOR_HEALTHY
	progress_bar.add_theme_stylebox_override("fill", _fill_style)

	var parent_node : Node = get_parent()
	if parent_node != null:
		var health_comp : HealthComponent = parent_node.get_node_or_null("HealthComponent") as HealthComponent
		if health_comp != null:
			bind_health_component(health_comp)

## Binds the health bar to a HealthComponent.
func bind_health_component(health_comp: HealthComponent) -> void:
	if health_comp == null:
		return
	_max_health = HealthComponent.MAX_HEALTH
	_current_health = health_comp.health
	progress_bar.max_value = _max_health
	progress_bar.value = _current_health
	_update_label(_current_health)
	_update_color(_current_health)

	if not health_comp.health_changed.is_connected(_on_health_changed):
		health_comp.health_changed.connect(_on_health_changed)
	if not health_comp.health_depleted.is_connected(_on_health_depleted):
		health_comp.health_depleted.connect(_on_health_depleted)

func _on_health_changed(new_health: int, old_health: int) -> void:
	_current_health = new_health
	_update_label(new_health)

	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(progress_bar, "value", float(new_health), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var target_col : Color = _get_status_color(new_health)
	if new_health < old_health:
		_flash(target_col)
	else:
		_fill_style.bg_color = target_col

func _on_health_depleted() -> void:
	_current_health = 0
	_update_label(0)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	progress_bar.value = 0.0
	visible = false

func _update_label(_hp: int) -> void:
	if label != null:
		label.text = ""
		label.visible = false

func _get_status_color(hp: int) -> Color:
	var ratio : float = float(hp) / float(_max_health)
	if ratio > 0.5:
		return COLOR_HEALTHY
	elif ratio > 0.25:
		return COLOR_DAMAGED
	else:
		return COLOR_CRITICAL

func _update_color(hp: int) -> void:
	if _fill_style != null:
		_fill_style.bg_color = _get_status_color(hp)

func _flash(target_color: Color) -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_fill_style.bg_color = COLOR_FLASH
	_flash_tween = create_tween()
	_flash_tween.tween_property(_fill_style, "bg_color", target_color, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## Sets visibility smoothly (e.g. when approaching, driving, or damaged).
func set_bar_active(active: bool) -> void:
	if not visible and active:
		visible = true
		modulate.a = 0.0
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	var target_alpha : float = 1.0 if active else 0.0
	_fade_tween.tween_property(self, "modulate:a", target_alpha, 0.2)
	if not active:
		_fade_tween.tween_callback(func(): if modulate.a <= 0.05: visible = false)
