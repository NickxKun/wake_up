class_name OutOfBoundsWarning
extends CanvasLayer

## Destiny-style Out of Bounds (OOB) warning interface.
## Warns the player when leaving the operational outpost boundary, displaying a countdown
## and pulsing crimson vignette before lethal damage is applied.

signal timer_depleted

@export var max_countdown : float = 5.0

var _is_active : bool = false
var _time_remaining : float = 5.0
var _last_tick_sec : int = -1
var _pulse_phase : float = 0.0

@onready var root_control : Control = $RootControl
@onready var banner_panel : PanelContainer = $RootControl/TopAnchor/BannerPanel
@onready var title_label : Label = $RootControl/TopAnchor/BannerPanel/VBox/TitleRow/TitleLabel
@onready var timer_label : Label = $RootControl/TopAnchor/BannerPanel/VBox/TimerLabel
@onready var progress_bar : ProgressBar = $RootControl/TopAnchor/BannerPanel/VBox/ProgressBar
@onready var sub_label : Label = $RootControl/TopAnchor/BannerPanel/VBox/SubLabel
@onready var vignette_rect : ColorRect = $RootControl/VignetteRect

func _ready() -> void:
	layer = 95
	root_control.modulate.a = 0.0
	root_control.visible = false
	_time_remaining = max_countdown

func _process(delta: float) -> void:
	if not _is_active:
		return

	_time_remaining = maxf(_time_remaining - delta, 0.0)
	_update_display(delta)

	# Sound tick on whole seconds (4s, 3s, 2s, 1s) and sub-second urgency (< 1s)
	var current_sec : int = int(ceil(_time_remaining))
	if current_sec != _last_tick_sec and current_sec > 0:
		_last_tick_sec = current_sec
		_play_tick_sound()

	if _time_remaining <= 0.0:
		timer_depleted.emit()

func set_warning_active(active: bool) -> void:
	if _is_active == active:
		return

	_is_active = active
	var tween : Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if _is_active:
		root_control.visible = true
		_time_remaining = max_countdown
		_last_tick_sec = int(ceil(max_countdown))
		_pulse_phase = 0.0
		_play_tick_sound()
		_update_display(0.0)
		tween.tween_property(root_control, "modulate:a", 1.0, 0.2)
	else:
		tween.tween_property(root_control, "modulate:a", 0.0, 0.25)
		tween.tween_callback(func() -> void:
			if not _is_active:
				root_control.visible = false
				_time_remaining = max_countdown
		)

func is_warning_active() -> bool:
	return _is_active

func get_time_remaining() -> float:
	return _time_remaining

func _update_display(delta: float) -> void:
	var fraction : float = clampf(_time_remaining / max_countdown, 0.0, 1.0)
	progress_bar.value = fraction * 100.0

	var sec_int : int = int(_time_remaining)
	var millis : int = int((_time_remaining - float(sec_int)) * 10.0)
	timer_label.text = "%02d.%1ds" % [sec_int, millis]

	# Pulse rate accelerates as countdown reaches 0
	var pulse_speed : float = lerpf(12.0, 4.0, fraction)
	_pulse_phase += delta * pulse_speed
	var pulse_alpha : float = 0.25 + 0.25 * (sin(_pulse_phase) * 0.5 + 0.5)
	# Ramp up vignette intensity when critically low
	if fraction < 0.35:
		pulse_alpha += (0.35 - fraction) * 0.7

	if vignette_rect != null:
		if vignette_rect.material is ShaderMaterial:
			(vignette_rect.material as ShaderMaterial).set_shader_parameter("vignette_opacity", clampf(pulse_alpha, 0.0, 0.95))
			(vignette_rect.material as ShaderMaterial).set_shader_parameter("vignette_color", Color(0.88, 0.06, 0.12, 1.0))
		else:
			vignette_rect.color = Color(0.85, 0.08, 0.12, clampf(pulse_alpha, 0.0, 0.75))

func _play_tick_sound() -> void:
	var snd : Node = get_node_or_null("/root/UiSound")
	if snd != null and snd.has_method("play_warning_tick"):
		snd.call("play_warning_tick")
