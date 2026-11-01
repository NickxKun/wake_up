extends CanvasLayer

## Minimal, smooth tactical loading screen with background threaded resource loading.

signal loading_started
signal loading_finished

const MIN_DISPLAY_TIME : float = 0.55
const DEFAULT_BAR_WIDTH : float = 360.0

const STATUS_MESSAGES : Array[String] = [
	"ALLOCATING QUANTUM SECTOR BUFFER...",
	"LOADING 3D STATION & HABITAT ASSETS...",
	"COMPUTING NAVIGATION VECTOR MESH...",
	"CALIBRATING HOSTILE DRONE MATRICES...",
	"SIMULATION INITIALIZED // DEPLOYING"
]

@onready var root_control : Control = $RootControl
@onready var backdrop : ColorRect = $RootControl/Backdrop
@onready var emblem : Control = $RootControl/CenterContainer/VBoxContainer/EmblemBox/Emblem
@onready var protocol_label : Label = $RootControl/CenterContainer/VBoxContainer/TextBox/ProtocolLabel
@onready var title_label : Label = $RootControl/CenterContainer/VBoxContainer/TextBox/TitleLabel
@onready var bar_container : Control = $RootControl/CenterContainer/VBoxContainer/ProgressSection/BarContainer
@onready var progress_bar_bg : ColorRect = $RootControl/CenterContainer/VBoxContainer/ProgressSection/BarContainer/ProgressBarBg
@onready var fill_bar : ColorRect = $RootControl/CenterContainer/VBoxContainer/ProgressSection/BarContainer/FillBar
@onready var status_label : Label = $RootControl/CenterContainer/VBoxContainer/ProgressSection/StatusRow/StatusLabel
@onready var percent_label : Label = $RootControl/CenterContainer/VBoxContainer/ProgressSection/StatusRow/PercentLabel

var _target_scene_path : String = ""
var _is_loading : bool = false
var _raw_progress : float = 0.0
var _display_progress : float = 0.0
var _elapsed_time : float = 0.0
var _status_timer : float = 0.0
var _status_index : int = 0
var _fade_tween : Tween
var _bar_width : float = DEFAULT_BAR_WIDTH

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_ensure_nodes()
	if root_control != null:
		root_control.modulate.a = 0.0

func _ensure_nodes() -> void:
	if root_control == null:
		root_control = get_node_or_null("RootControl") as Control
	if root_control != null:
		if backdrop == null:
			backdrop = root_control.get_node_or_null("Backdrop") as ColorRect
		if emblem == null:
			emblem = root_control.get_node_or_null("CenterContainer/VBoxContainer/EmblemBox/Emblem") as Control
		if protocol_label == null:
			protocol_label = root_control.get_node_or_null("CenterContainer/VBoxContainer/TextBox/ProtocolLabel") as Label
		if title_label == null:
			title_label = root_control.get_node_or_null("CenterContainer/VBoxContainer/TextBox/TitleLabel") as Label
		if bar_container == null:
			bar_container = root_control.get_node_or_null("CenterContainer/VBoxContainer/ProgressSection/BarContainer") as Control
		if progress_bar_bg == null:
			progress_bar_bg = root_control.get_node_or_null("CenterContainer/VBoxContainer/ProgressSection/BarContainer/ProgressBarBg") as ColorRect
		if fill_bar == null:
			fill_bar = root_control.get_node_or_null("CenterContainer/VBoxContainer/ProgressSection/BarContainer/FillBar") as ColorRect
		if status_label == null:
			status_label = root_control.get_node_or_null("CenterContainer/VBoxContainer/ProgressSection/StatusRow/StatusLabel") as Label
		if percent_label == null:
			percent_label = root_control.get_node_or_null("CenterContainer/VBoxContainer/ProgressSection/StatusRow/PercentLabel") as Label

	if bar_container != null:
		_bar_width = bar_container.custom_minimum_size.x
		if _bar_width <= 0.0:
			_bar_width = DEFAULT_BAR_WIDTH

## Initiates a smooth, threaded scene load with custom title and accent color.
func load_scene(path: String, title: String = "DEPLOYING SECTOR", subtitle: String = "PROTOCOL // 01", accent: Color = Color.WHITE) -> void:
	if _is_loading:
		return
	_ensure_nodes()
	_is_loading = true
	_target_scene_path = path
	_raw_progress = 0.0
	_display_progress = 0.0
	_elapsed_time = 0.0
	_status_timer = 0.0
	_status_index = 0

	# Apply context typography & colors
	if title_label != null:
		title_label.text = title
	if protocol_label != null:
		protocol_label.text = subtitle
	if fill_bar != null:
		fill_bar.color = accent
		fill_bar.size = Vector2(0.0, 3.0)
	if status_label != null:
		status_label.text = STATUS_MESSAGES[0]
	if percent_label != null:
		percent_label.text = "0%"

	if is_instance_valid(emblem):
		if "emblem_color" in emblem:
			emblem.set("emblem_color", accent)
		if "accent_color" in emblem:
			emblem.set("accent_color", accent * 0.8)

	# Audio cue
	_play_sound("slide")

	# Request background threaded load
	var req_err : Error = ResourceLoader.load_threaded_request(path)
	if req_err != OK:
		push_warning("LoadingScreen: load_threaded_request returned %d, falling back to direct load." % req_err)

	# Smooth entrance animation
	visible = true
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()

	if root_control != null:
		_fade_tween = create_tween()
		_fade_tween.tween_property(root_control, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	loading_started.emit()

func _process(delta: float) -> void:
	if not _is_loading:
		return

	_elapsed_time += delta
	_status_timer += delta

	# Cycle tactical status message
	if _status_timer >= 0.25 and _status_index < STATUS_MESSAGES.size() - 2:
		_status_timer = 0.0
		_status_index += 1
		if status_label != null:
			status_label.text = STATUS_MESSAGES[_status_index]

	# Poll threaded loading progress
	var progress_arr : Array = []
	var load_status : ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(_target_scene_path, progress_arr)

	match load_status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if progress_arr.size() > 0:
				_raw_progress = maxf(_raw_progress, float(progress_arr[0]))
			else:
				_raw_progress = maxf(_raw_progress, 0.2)
		ResourceLoader.THREAD_LOAD_LOADED:
			_raw_progress = 1.0
			if status_label != null:
				status_label.text = STATUS_MESSAGES[STATUS_MESSAGES.size() - 1]
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("LoadingScreen: Threaded load failed for '%s'. Falling back." % _target_scene_path)
			_finish_direct_fallback()
			return

	# Smoothly interpolate visual progress bar
	var time_ratio : float = clampf(_elapsed_time / MIN_DISPLAY_TIME, 0.0, 1.0)
	var target_display : float = minf(_raw_progress, time_ratio if _raw_progress < 1.0 else 1.0)
	_display_progress = move_toward(_display_progress, target_display, delta * 3.5)
	_display_progress = clampf(_display_progress, 0.0, 1.0)

	if fill_bar != null:
		fill_bar.size = Vector2(_display_progress * _bar_width, 3.0)
	if percent_label != null:
		percent_label.text = "%d%%" % int(_display_progress * 100.0)

	# Transition once loaded, displayed at 100%, and minimum display time elapsed
	if _raw_progress >= 1.0 and _display_progress >= 0.999 and _elapsed_time >= MIN_DISPLAY_TIME:
		_complete_load()

func _complete_load() -> void:
	_is_loading = false

	if fill_bar != null:
		fill_bar.size = Vector2(_bar_width, 3.0)
	if percent_label != null:
		percent_label.text = "100%"
	if status_label != null:
		status_label.text = "SIMULATION READY // INITIALIZING"

	# Get loaded PackedScene from background thread
	var loaded_resource : Resource = ResourceLoader.load_threaded_get(_target_scene_path)
	if loaded_resource is PackedScene:
		get_tree().change_scene_to_packed(loaded_resource as PackedScene)
	else:
		get_tree().change_scene_to_file(_target_scene_path)

	# Audio cue
	_play_sound("click", 0.0)

	# Wait two frames for scene tree reconstruction and node ready processing
	await get_tree().process_frame
	await get_tree().process_frame

	# Smooth exit fade
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()

	if root_control != null and is_inside_tree():
		_fade_tween = create_tween()
		_fade_tween.tween_property(root_control, "modulate:a", 0.0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		await _fade_tween.finished

	visible = false
	loading_finished.emit()

func _finish_direct_fallback() -> void:
	_is_loading = false
	get_tree().change_scene_to_file(_target_scene_path)
	visible = false
	loading_finished.emit()

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
		"slide":
			snd.call("play_slide")
