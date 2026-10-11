extends CanvasLayer

## The health component whose health is displayed.
@export var health_component : HealthComponent

## Fill color when health is not changing.
@export var normal_color : Color = Color(0.6, 0.6, 0.6, 1)
## Fill color flashed when health decreases.
@export var damage_color : Color = Color(1.0, 0.55, 0.55, 1)
## Fill color flashed when health increases.
@export var heal_color : Color = Color(0.55, 1.0, 0.55, 1)
## Seconds taken to fade from the flash color back to the normal color.
@export var flash_duration : float = 0.3

@onready var progress_bar : ProgressBar = $MarginContainer/HBoxContainer/ProgressBar
@onready var value_label : Label = $MarginContainer/HBoxContainer/HealthValue

var _fill_style : StyleBoxFlat
var _flash_tween : Tween

func _ready() -> void:
	_fill_style = progress_bar.get_theme_stylebox("fill").duplicate()
	_fill_style.bg_color = normal_color
	progress_bar.add_theme_stylebox_override("fill", _fill_style)
	if health_component == null:
		push_error("HealthBar: health_component is not assigned.")
		return
	progress_bar.value = health_component.health
	value_label.text = str(health_component.health)
	health_component.health_changed.connect(_on_health_changed)

func _on_health_changed(new_health : int, old_health : int) -> void:
	progress_bar.value = new_health
	value_label.text = str(new_health)
	if new_health < old_health:
		_flash(damage_color)
	elif new_health > old_health:
		_flash(heal_color)

func _flash(color : Color) -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	_fill_style.bg_color = color
	_flash_tween = create_tween()
	_flash_tween.tween_property(_fill_style, "bg_color", normal_color, flash_duration)
