extends CanvasLayer

## Atmospheric, sleek tactical pause menu with full-screen system settings, telemetry, and smooth animations.

signal resumed
signal restart_requested
signal main_menu_requested

@onready var backdrop : ColorRect = $Backdrop
@onready var vignette : ColorRect = $Vignette
@onready var modal_panel : PanelContainer = $CenterContainer/ModalPanel
@onready var emblem : Control = $CenterContainer/ModalPanel/MarginContainer/ContentBox/HeaderBox/EmblemBox/Emblem
@onready var eyebrow : Label = $CenterContainer/ModalPanel/MarginContainer/ContentBox/HeaderBox/Labels/Eyebrow
@onready var title : Label = $CenterContainer/ModalPanel/MarginContainer/ContentBox/HeaderBox/Labels/Title
@onready var subtitle : Label = $CenterContainer/ModalPanel/MarginContainer/ContentBox/HeaderBox/Labels/Subtitle
@onready var telemetry_label : Label = $CenterContainer/ModalPanel/MarginContainer/ContentBox/TelemetryBox/TelemetryLabel

@onready var main_view : VBoxContainer = $CenterContainer/ModalPanel/MarginContainer/ContentBox/MainView
@onready var resume_button : Button = $CenterContainer/ModalPanel/MarginContainer/ContentBox/MainView/ResumeButton
@onready var settings_button : Button = $CenterContainer/ModalPanel/MarginContainer/ContentBox/MainView/SettingsButton
@onready var restart_button : Button = $CenterContainer/ModalPanel/MarginContainer/ContentBox/MainView/RestartButton
@onready var menu_button : Button = $CenterContainer/ModalPanel/MarginContainer/ContentBox/MainView/MenuButton
@onready var quit_button : Button = $CenterContainer/ModalPanel/MarginContainer/ContentBox/MainView/QuitButton

@onready var settings_menu : Control = $SettingsMenu

var _is_transitioning : bool = false
var _is_settings_open : bool = false

func _ready() -> void:
	visible = false
	if is_instance_valid(settings_menu):
		settings_menu.visible = false
		settings_menu.closed.connect(_on_settings_closed)

	# Connect navigation buttons
	resume_button.pressed.connect(_on_resume_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# Setup Micro-interactions
	_setup_button_hover(resume_button)
	_setup_button_hover(settings_button)
	_setup_button_hover(restart_button)
	_setup_button_hover(menu_button)
	_setup_button_hover(quit_button)

func update_telemetry(kills: int, deaths: int, is_sandbox: bool) -> void:
	if telemetry_label != null:
		var mode_str : String = "SANDBOX // PROTOCOL 02" if is_sandbox else "SURVIVAL // PROTOCOL 01"
		telemetry_label.text = "%s  •  HOSTILES: %d  •  DEATHS: %d" % [mode_str, kills, deaths]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P):
		_handle_pause_toggle()

func _handle_pause_toggle() -> void:
	if _is_transitioning:
		return
	if visible:
		if _is_settings_open:
			if is_instance_valid(settings_menu):
				settings_menu.close()
			modal_panel.visible = true
			_is_settings_open = false
		else:
			resume()
		get_viewport().set_input_as_handled()
	elif _can_pause():
		pause()
		get_viewport().set_input_as_handled()

func _can_pause() -> bool:
	var hud : Node = get_node_or_null("/root/PlayerHealthHud")
	if hud != null:
		if hud.has_method("is_game_over") and hud.is_game_over():
			return false
		if hud.has_method("is_map_open") and hud.is_map_open():
			return false
	return is_inside_tree() and get_tree().current_scene != null

## Pauses game execution and displays the modal menu with a smooth entrance.
func pause() -> void:
	if _is_transitioning or visible:
		return
	_is_transitioning = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_play_sound("slide")

	_is_settings_open = false
	modal_panel.visible = true
	visible = true

	# Pull latest telemetry from hud if available
	var hud : Node = get_node_or_null("/root/PlayerHealthHud")
	if hud != null:
		var k : int = hud.get("enemies_killed") if "enemies_killed" in hud else 0
		var d : int = hud.get("player_deaths") if "player_deaths" in hud else 0
		var s : bool = hud.get("is_sandbox_mode") if "is_sandbox_mode" in hud else false
		update_telemetry(k, d, s)

	if is_instance_valid(emblem) and emblem.has_method("play_burst"):
		emblem.play_burst()

	modal_panel.pivot_offset = modal_panel.size / 2.0
	modal_panel.scale = Vector2(0.92, 0.92)
	modal_panel.modulate.a = 0.0
	backdrop.modulate.a = 0.0
	vignette.modulate.a = 0.0

	var tween : Tween = create_tween().set_parallel(true)
	tween.tween_property(backdrop, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(vignette, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(modal_panel, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(modal_panel, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await tween.finished
	_is_transitioning = false

## Resumes gameplay with an exit animation and unpauses the tree.
func resume() -> void:
	if _is_transitioning or not visible:
		return
	_is_transitioning = true
	_play_sound("click")

	if _is_settings_open and is_instance_valid(settings_menu):
		settings_menu.close()

	modal_panel.pivot_offset = modal_panel.size / 2.0

	var tween : Tween = create_tween().set_parallel(true)
	tween.tween_property(backdrop, "modulate:a", 0.0, 0.16).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(vignette, "modulate:a", 0.0, 0.16).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(modal_panel, "modulate:a", 0.0, 0.16).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(modal_panel, "scale", Vector2(0.92, 0.92), 0.16).set_trans(Tween.TRANS_QUAD)

	await tween.finished
	visible = false
	_is_settings_open = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_is_transitioning = false
	resumed.emit()

func _on_resume_pressed() -> void:
	resume()

func _on_settings_pressed() -> void:
	_play_sound("click")
	_is_settings_open = true
	modal_panel.visible = false
	if is_instance_valid(settings_menu):
		settings_menu.open("audio")

func _on_settings_closed() -> void:
	_is_settings_open = false
	modal_panel.visible = true

func _on_restart_pressed() -> void:
	if _is_transitioning:
		return
	_play_sound("click")
	_is_transitioning = true

	var tween : Tween = create_tween()
	tween.tween_property(modal_panel, "modulate:a", 0.0, 0.15)
	await tween.finished

	visible = false
	get_tree().paused = false
	_is_transitioning = false
	restart_requested.emit()

func _on_menu_pressed() -> void:
	if _is_transitioning:
		return
	_play_sound("click")
	_is_transitioning = true

	var tween : Tween = create_tween()
	tween.tween_property(modal_panel, "modulate:a", 0.0, 0.15)
	await tween.finished

	visible = false
	get_tree().paused = false
	_is_transitioning = false
	main_menu_requested.emit()

func _on_quit_pressed() -> void:
	_play_sound("click")
	get_tree().quit()

# -----------------------------------------------------------------------------
# Micro-interactions & Visual Polish
# -----------------------------------------------------------------------------

func _setup_button_hover(button: Button) -> void:
	button.pivot_offset = button.size / 2.0
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.mouse_entered.connect(func():
		_play_sound("hover")
		button.pivot_offset = button.size / 2.0
		var tween : Tween = create_tween()
		tween.tween_property(button, "scale", Vector2(1.025, 1.025), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)
	button.mouse_exited.connect(func():
		var tween : Tween = create_tween()
		tween.tween_property(button, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)

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
