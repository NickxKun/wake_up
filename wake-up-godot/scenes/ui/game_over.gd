extends CanvasLayer

## Modern, polished tactical Game Over screen with animated modal card and stats.

signal restart_requested
signal main_menu_requested

@onready var backdrop : ColorRect = $Backdrop
@onready var vignette : ColorRect = $Vignette
@onready var modal_panel : PanelContainer = $CenterContainer/ModalPanel
@onready var emblem : Control = $CenterContainer/ModalPanel/MarginContainer/VBoxContainer/HeaderBox/EmblemBox/Emblem
@onready var kills_value : Label = $CenterContainer/ModalPanel/MarginContainer/VBoxContainer/TelemetryCard/VBox/RowKills/Value
@onready var deaths_value : Label = $CenterContainer/ModalPanel/MarginContainer/VBoxContainer/TelemetryCard/VBox/RowDeaths/Value
@onready var mode_value : Label = $CenterContainer/ModalPanel/MarginContainer/VBoxContainer/TelemetryCard/VBox/RowMode/Value
@onready var restart_button : Button = $CenterContainer/ModalPanel/MarginContainer/VBoxContainer/ActionsBox/RestartButton
@onready var menu_button : Button = $CenterContainer/ModalPanel/MarginContainer/VBoxContainer/ActionsBox/MenuButton

var _kills_recorded : int = 0
var _deaths_recorded : int = 1
var _is_sandbox_recorded : bool = false
var _is_actioned : bool = false

func _ready() -> void:
	restart_button.pressed.connect(_on_restart_pressed)
	menu_button.pressed.connect(_on_menu_pressed)

	_setup_button_hover(restart_button)
	_setup_button_hover(menu_button)

	_update_labels()
	_play_entrance_animation()

func set_stats(kills: int, deaths: int = 1, is_sandbox: bool = false) -> void:
	_kills_recorded = kills
	_deaths_recorded = max(deaths, 1)
	_is_sandbox_recorded = is_sandbox
	_update_labels()

func _update_labels() -> void:
	if not is_node_ready():
		return
	if kills_value != null:
		kills_value.text = "%d" % _kills_recorded
	if deaths_value != null:
		deaths_value.text = "%d" % _deaths_recorded
	if mode_value != null:
		mode_value.text = "SANDBOX // PROTOCOL 02" if _is_sandbox_recorded else "SURVIVAL // PROTOCOL 01"

func _unhandled_input(event: InputEvent) -> void:
	if _is_actioned:
		return
	if event.is_action_pressed("ui_accept"):
		_on_restart_pressed()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_on_menu_pressed()
		get_viewport().set_input_as_handled()

func _setup_button_hover(button: Button) -> void:
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.mouse_entered.connect(func():
		_play_sound("hover")
		_animate_scale(button, Vector2(1.025, 1.025))
	)
	button.mouse_exited.connect(func():
		_animate_scale(button, Vector2.ONE)
	)

func _animate_scale(button: Button, target_scale: Vector2) -> void:
	if button.disabled:
		return
	button.pivot_offset = button.size / 2.0
	var tween : Tween = create_tween()
	tween.tween_property(button, "scale", target_scale, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _play_entrance_animation() -> void:
	_play_sound("slide")

	if is_instance_valid(emblem) and emblem.has_method("play_burst"):
		emblem.play_burst()

	backdrop.modulate.a = 0.0
	vignette.modulate.a = 0.0
	modal_panel.modulate.a = 0.0
	modal_panel.pivot_offset = modal_panel.size / 2.0
	modal_panel.scale = Vector2(0.92, 0.92)

	var tween : Tween = create_tween().set_parallel(true)
	tween.tween_property(backdrop, "modulate:a", 1.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(vignette, "modulate:a", 1.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(modal_panel, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(modal_panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_restart_pressed() -> void:
	if _is_actioned:
		return
	_is_actioned = true
	_play_sound("click")
	restart_button.disabled = true
	menu_button.disabled = true

	var click_tween : Tween = create_tween()
	click_tween.tween_property(restart_button, "scale", Vector2(0.96, 0.96), 0.08)
	click_tween.tween_callback(restart_requested.emit)

func _on_menu_pressed() -> void:
	if _is_actioned:
		return
	_is_actioned = true
	_play_sound("click")
	restart_button.disabled = true
	menu_button.disabled = true

	var click_tween : Tween = create_tween()
	click_tween.tween_property(menu_button, "scale", Vector2(0.96, 0.96), 0.08)
	click_tween.tween_callback(main_menu_requested.emit)

func _play_sound(sound_name: String, param: Variant = null) -> void:
	if not is_inside_tree():
		return
	var snd : Node = get_node_or_null("/root/UiSound")
	if snd == null:
		return
	match sound_name:
		"click":
			if param is float: snd.call("play_click", param)
			else: snd.call("play_click")
		"hover":
			snd.call("play_hover")
		"slide":
			snd.call("play_slide")
