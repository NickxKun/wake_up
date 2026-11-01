extends Control

## Dedicated full-screen settings and game guide interface with animated sidebar and live search.

signal closed
signal settings_applied

const SETTINGS_PATH : String = "user://settings.cfg"

# Header & Navigation
@onready var close_button : Button = $TopHeader/MarginContainer/HBoxContainer/CloseButton
@onready var search_input : LineEdit = $MainLayout/SidebarMargin/Sidebar/SearchContainer/SearchInput
@onready var clear_search_btn : Button = $MainLayout/SidebarMargin/Sidebar/SearchContainer/ClearSearchButton
@onready var search_icon_btn : Button = $MainLayout/SidebarMargin/Sidebar/SearchContainer/SearchIconButton

# Category Sidebar Buttons
@onready var btn_audio : Button = $MainLayout/SidebarMargin/Sidebar/CategoryList/BtnAudio
@onready var btn_video : Button = $MainLayout/SidebarMargin/Sidebar/CategoryList/BtnVideo
@onready var btn_controls : Button = $MainLayout/SidebarMargin/Sidebar/CategoryList/BtnControls
@onready var btn_guide : Button = $MainLayout/SidebarMargin/Sidebar/CategoryList/BtnGuide
@onready var reset_button : Button = $MainLayout/SidebarMargin/Sidebar/SidebarBottom/ResetButton
@onready var back_button : Button = $MainLayout/SidebarMargin/Sidebar/SidebarBottom/BackButton

# Content Area
@onready var content_scroll : ScrollContainer = $MainLayout/ContentMargin/ContentVBox/ScrollContainer
@onready var content_header_title : Label = $MainLayout/ContentMargin/ContentVBox/HeaderBox/CategoryTitle
@onready var content_header_desc : Label = $MainLayout/ContentMargin/ContentVBox/HeaderBox/CategoryDesc
@onready var panels_container : VBoxContainer = $MainLayout/ContentMargin/ContentVBox/ScrollContainer/PanelsContainer

# Category Panels
@onready var audio_panel : VBoxContainer = $MainLayout/ContentMargin/ContentVBox/ScrollContainer/PanelsContainer/AudioPanel
@onready var video_panel : VBoxContainer = $MainLayout/ContentMargin/ContentVBox/ScrollContainer/PanelsContainer/VideoPanel
@onready var controls_panel : VBoxContainer = $MainLayout/ContentMargin/ContentVBox/ScrollContainer/PanelsContainer/ControlsPanel
@onready var guide_panel : VBoxContainer = $MainLayout/ContentMargin/ContentVBox/ScrollContainer/PanelsContainer/GuidePanel
@onready var no_results_label : Label = $MainLayout/ContentMargin/ContentVBox/ScrollContainer/PanelsContainer/NoResultsLabel

# Audio Controls
@onready var master_slider : HSlider = $MainLayout/ContentMargin/ContentVBox/ScrollContainer/PanelsContainer/AudioPanel/MasterVolSection/Slider
@onready var master_label : Label = $MainLayout/ContentMargin/ContentVBox/ScrollContainer/PanelsContainer/AudioPanel/MasterVolSection/Header/Value
@onready var master_test_btn : Button = $MainLayout/ContentMargin/ContentVBox/ScrollContainer/PanelsContainer/AudioPanel/MasterVolSection/Header/TestBtn
@onready var sfx_slider : HSlider = $MainLayout/ContentMargin/ContentVBox/ScrollContainer/PanelsContainer/AudioPanel/SfxVolSection/Slider
@onready var sfx_label : Label = $MainLayout/ContentMargin/ContentVBox/ScrollContainer/PanelsContainer/AudioPanel/SfxVolSection/Header/Value
@onready var sfx_test_btn : Button = $MainLayout/ContentMargin/ContentVBox/ScrollContainer/PanelsContainer/AudioPanel/SfxVolSection/Header/TestBtn
@onready var music_slider : HSlider = $MainLayout/ContentMargin/ContentVBox/ScrollContainer/PanelsContainer/AudioPanel/MusicVolSection/Slider
@onready var music_label : Label = $MainLayout/ContentMargin/ContentVBox/ScrollContainer/PanelsContainer/AudioPanel/MusicVolSection/Header/Value
@onready var mute_all_toggle : CheckButton = $MainLayout/ContentMargin/ContentVBox/ScrollContainer/PanelsContainer/AudioPanel/MuteSection/CheckButton
@onready var hitmarker_toggle : CheckButton = $MainLayout/ContentMargin/ContentVBox/ScrollContainer/PanelsContainer/AudioPanel/HitmarkerSection/CheckButton

# Video Controls
@onready var window_mode_btn : OptionButton = $MainLayout/ContentMargin/ContentVBox/ScrollContainer/PanelsContainer/VideoPanel/WindowModeSection/OptionButton
@onready var vsync_toggle : CheckButton = $MainLayout/ContentMargin/ContentVBox/ScrollContainer/PanelsContainer/VideoPanel/VsyncSection/CheckButton
@onready var render_scale_btn : OptionButton = $MainLayout/ContentMargin/ContentVBox/ScrollContainer/PanelsContainer/VideoPanel/RenderScaleSection/OptionButton
@onready var fps_cap_btn : OptionButton = $MainLayout/ContentMargin/ContentVBox/ScrollContainer/PanelsContainer/VideoPanel/FpsCapSection/OptionButton
@onready var vignette_slider : HSlider = $MainLayout/ContentMargin/ContentVBox/ScrollContainer/PanelsContainer/VideoPanel/VignetteSection/Slider
@onready var vignette_label : Label = $MainLayout/ContentMargin/ContentVBox/ScrollContainer/PanelsContainer/VideoPanel/VignetteSection/Header/Value
@onready var fov_slider : HSlider = $MainLayout/ContentMargin/ContentVBox/ScrollContainer/PanelsContainer/VideoPanel/FovSection/Slider
@onready var fov_label : Label = $MainLayout/ContentMargin/ContentVBox/ScrollContainer/PanelsContainer/VideoPanel/FovSection/Header/Value

# Controls Settings
@onready var mouse_sens_slider : HSlider = $MainLayout/ContentMargin/ContentVBox/ScrollContainer/PanelsContainer/ControlsPanel/SensSection/Slider
@onready var mouse_sens_label : Label = $MainLayout/ContentMargin/ContentVBox/ScrollContainer/PanelsContainer/ControlsPanel/SensSection/Header/Value
@onready var invert_y_toggle : CheckButton = $MainLayout/ContentMargin/ContentVBox/ScrollContainer/PanelsContainer/ControlsPanel/InvertYSection/CheckButton
@onready var sprint_mode_btn : OptionButton = $MainLayout/ContentMargin/ContentVBox/ScrollContainer/PanelsContainer/ControlsPanel/SprintModeSection/OptionButton

var current_category : String = "audio"
var _is_transitioning : bool = false
var _is_loading_settings : bool = false
var _active_tween : Tween

func _ready() -> void:
	visible = false
	modulate.a = 0.0

	_setup_option_buttons()
	_connect_signals()
	_setup_button_hover_effects()
	_load_settings()

func _connect_signals() -> void:
	# Navigation
	close_button.pressed.connect(close)
	back_button.pressed.connect(close)
	reset_button.pressed.connect(_on_reset_defaults_pressed)

	btn_audio.pressed.connect(func(): _switch_category("audio"))
	btn_video.pressed.connect(func(): _switch_category("video"))
	btn_controls.pressed.connect(func(): _switch_category("controls"))
	btn_guide.pressed.connect(func(): _switch_category("how_to_play"))

	# Search
	search_input.text_changed.connect(_on_search_text_changed)
	clear_search_btn.pressed.connect(_on_clear_search_pressed)
	search_icon_btn.pressed.connect(func(): search_input.grab_focus())

	# Audio signals
	master_slider.value_changed.connect(_on_master_vol_changed)
	sfx_slider.value_changed.connect(_on_sfx_vol_changed)
	music_slider.value_changed.connect(_on_music_vol_changed)
	mute_all_toggle.toggled.connect(_on_mute_all_toggled)
	hitmarker_toggle.toggled.connect(_on_hitmarker_toggled)

	master_test_btn.pressed.connect(_test_audio_click)
	sfx_test_btn.pressed.connect(_test_audio_click)

	# Video signals
	window_mode_btn.item_selected.connect(_on_window_mode_selected)
	vsync_toggle.toggled.connect(_on_vsync_toggled)
	render_scale_btn.item_selected.connect(_on_render_scale_selected)
	fps_cap_btn.item_selected.connect(_on_fps_cap_selected)
	vignette_slider.value_changed.connect(_on_vignette_changed)
	fov_slider.value_changed.connect(_on_fov_changed)

	# Controls signals
	mouse_sens_slider.value_changed.connect(_on_mouse_sens_changed)
	invert_y_toggle.toggled.connect(_on_invert_y_toggled)
	sprint_mode_btn.item_selected.connect(_on_sprint_mode_selected)

func _setup_option_buttons() -> void:
	# Window Mode
	window_mode_btn.clear()
	window_mode_btn.add_item("Fullscreen", 0)
	window_mode_btn.add_item("Windowed", 1)
	window_mode_btn.add_item("Borderless Fullscreen", 2)

	# Render Quality
	render_scale_btn.clear()
	render_scale_btn.add_item("Performance (75%)", 0)
	render_scale_btn.add_item("Standard (100%)", 1)
	render_scale_btn.add_item("Ultra (125%)", 2)
	render_scale_btn.selected = 1

	# FPS Cap
	fps_cap_btn.clear()
	fps_cap_btn.add_item("60 FPS", 0)
	fps_cap_btn.add_item("120 FPS", 1)
	fps_cap_btn.add_item("144 FPS", 2)
	fps_cap_btn.add_item("Uncapped", 3)
	fps_cap_btn.selected = 3

	# Sprint Mode
	sprint_mode_btn.clear()
	sprint_mode_btn.add_item("Hold to Sprint", 0)
	sprint_mode_btn.add_item("Toggle Sprint", 1)
	sprint_mode_btn.selected = 0

func _unhandled_input(event: InputEvent) -> void:
	if not visible or _is_transitioning:
		return
	if event.is_action_pressed("ui_cancel"):
		if search_input.has_focus():
			search_input.release_focus()
		else:
			close()
		get_viewport().set_input_as_handled()

# -----------------------------------------------------------------------------
# Smooth Sliding Transitions
# -----------------------------------------------------------------------------

## Opens the full-screen settings page with a smooth slide-in animation.
func open(target_category: String = "audio") -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_is_transitioning = true

	_play_sound("slide")

	visible = true
	var viewport_w : float = 1280.0
	if is_inside_tree() and get_viewport() != null:
		viewport_w = get_viewport_rect().size.x
	if viewport_w <= 0.0:
		viewport_w = 1280.0

	position.x = viewport_w * 0.4
	modulate.a = 0.0

	search_input.text = ""
	clear_search_btn.visible = false
	_switch_category(target_category, false)

	_active_tween = create_tween().set_parallel(true)
	_active_tween.tween_property(self, "position:x", 0.0, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(self, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	await _active_tween.finished
	_is_transitioning = false

## Closes the settings page with a smooth slide-out animation.
func close() -> void:
	if not visible:
		return
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_is_transitioning = true

	_play_sound("slide")

	var viewport_w : float = 1280.0
	if is_inside_tree() and get_viewport() != null:
		viewport_w = get_viewport_rect().size.x
	if viewport_w <= 0.0:
		viewport_w = 1280.0

	_active_tween = create_tween().set_parallel(true)
	_active_tween.tween_property(self, "position:x", viewport_w * 0.35, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_active_tween.tween_property(self, "modulate:a", 0.0, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	await _active_tween.finished
	visible = false
	position.x = 0.0
	_is_transitioning = false
	closed.emit()

# -----------------------------------------------------------------------------
# Category Navigation & Search
# -----------------------------------------------------------------------------

func _switch_category(cat_id: String, play_sound: bool = true) -> void:
	if search_input.text.strip_edges() != "":
		search_input.text = ""
		clear_search_btn.visible = false

	current_category = cat_id
	if play_sound:
		_play_sound("tab")

	_update_category_buttons_state()
	_show_selected_panel(cat_id)

func _update_category_buttons_state() -> void:
	_style_category_button(btn_audio, current_category == "audio")
	_style_category_button(btn_video, current_category == "video")
	_style_category_button(btn_controls, current_category == "controls")
	_style_category_button(btn_guide, current_category == "how_to_play")

func _style_category_button(btn: Button, is_active: bool) -> void:
	var bar : ColorRect = btn.get_node_or_null("ActiveBar") as ColorRect
	if bar != null:
		bar.visible = is_active

	var tag : Label = btn.get_node_or_null("Tag") as Label
	var title : Label = btn.get_node_or_null("Title") as Label

	if is_active:
		btn.modulate.a = 1.0
		if tag != null: tag.modulate.a = 0.95
		if title != null:
			title.modulate.a = 1.0
			title.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	else:
		btn.modulate.a = 0.65
		if tag != null: tag.modulate.a = 0.45
		if title != null:
			title.modulate.a = 0.75
			title.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1))

func _show_selected_panel(cat_id: String) -> void:
	no_results_label.visible = false

	# Update titles and description
	match cat_id:
		"audio":
			content_header_title.text = "AUDIO CONFIGURATION"
			content_header_desc.text = "// MANAGE MASTER, SFX & MUSIC VOLUMES WITH DYNAMIC RANGE"
			audio_panel.visible = true
			video_panel.visible = false
			controls_panel.visible = false
			guide_panel.visible = false
		"video":
			content_header_title.text = "DISPLAY & GRAPHICS"
			content_header_desc.text = "// RESOLUTION, V-SYNC, PERFORMANCE PROFILES AND VIGNETTE"
			audio_panel.visible = false
			video_panel.visible = true
			controls_panel.visible = false
			guide_panel.visible = false
		"controls":
			content_header_title.text = "CONTROLS & INPUTS"
			content_header_desc.text = "// MOUSE AIM SENSITIVITY AND TACTICAL KEYBINDINGS"
			audio_panel.visible = false
			video_panel.visible = false
			controls_panel.visible = true
			guide_panel.visible = false
		"how_to_play":
			content_header_title.text = "OPERATIONAL GUIDE"
			content_header_desc.text = "// MISSION DIRECTIVES, PROTOCOLS AND COMBAT MASTERY"
			audio_panel.visible = false
			video_panel.visible = false
			controls_panel.visible = false
			guide_panel.visible = true

	# Smooth vertical entrance tween on content switch
	content_scroll.scroll_vertical = 0
	panels_container.modulate.a = 0.0
	panels_container.position.y = 8.0

	var tw : Tween = create_tween().set_parallel(true)
	tw.tween_property(panels_container, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(panels_container, "position:y", 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_search_text_changed(query: String) -> void:
	var q : String = query.strip_edges().to_lower()
	clear_search_btn.visible = (q != "")

	if q == "":
		_show_selected_panel(current_category)
		return

	# Live search across all category panels
	content_header_title.text = "SEARCH RESULTS"
	content_header_desc.text = '// FILTERING ACTIVE SETTINGS MATCHING: "%s"' % query.to_upper()

	var match_count : int = 0
	match_count += _filter_panel_items(audio_panel, q)
	match_count += _filter_panel_items(video_panel, q)
	match_count += _filter_panel_items(controls_panel, q)
	match_count += _filter_panel_items(guide_panel, q)

	no_results_label.visible = (match_count == 0)

func _filter_panel_items(panel: VBoxContainer, q: String) -> int:
	var matches : int = 0
	for child in panel.get_children():
		if child is Control:
			var text_content : String = _extract_searchable_text(child).to_lower()
			var is_match : bool = (q in text_content)
			child.visible = is_match
			if is_match:
				matches += 1

	panel.visible = (matches > 0)
	return matches

func _extract_searchable_text(node: Node) -> String:
	var text : String = ""
	if node is Label:
		text += node.text + " "
	elif node is Button:
		text += node.text + " "
	for child in node.get_children():
		text += _extract_searchable_text(child) + " "
	return text

func _on_clear_search_pressed() -> void:
	search_input.text = ""
	clear_search_btn.visible = false
	_play_sound("click")
	_show_selected_panel(current_category)

# -----------------------------------------------------------------------------
# Micro-interactions & Audio Triggers
# -----------------------------------------------------------------------------

func _setup_button_hover_effects() -> void:
	var buttons : Array[Button] = [
		close_button, back_button, reset_button,
		btn_audio, btn_video, btn_controls, btn_guide,
		master_test_btn, sfx_test_btn, clear_search_btn, search_icon_btn
	]
	for btn in buttons:
		if btn != null:
			btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			btn.mouse_entered.connect(func():
				_play_sound("hover")
				var tw : Tween = create_tween()
				tw.tween_property(btn, "scale", Vector2(1.02, 1.02), 0.1).set_trans(Tween.TRANS_QUAD)
			)
			btn.mouse_exited.connect(func():
				var tw : Tween = create_tween()
				tw.tween_property(btn, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_QUAD)
			)

func _test_audio_click() -> void:
	_play_sound("click")

func _play_sound(sound_name: String, param: Variant = null) -> void:
	if not is_inside_tree():
		return
	var snd : Node = get_node_or_null("/root/UiSound")
	if snd == null:
		return
	match sound_name:
		"click":
			if param is float:
				snd.call("play_click", param)
			else:
				snd.call("play_click")
		"hover":
			snd.call("play_hover")
		"tab":
			snd.call("play_tab")
		"toggle":
			if param is bool:
				snd.call("play_toggle", param)
			else:
				snd.call("play_toggle")
		"slide":
			snd.call("play_slide")

# -----------------------------------------------------------------------------
# Settings Modification Handlers
# -----------------------------------------------------------------------------

func _on_master_vol_changed(value: float) -> void:
	var bus_idx : int = AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		if value <= 0.0:
			AudioServer.set_bus_mute(bus_idx, true)
		else:
			AudioServer.set_bus_mute(bus_idx, false)
			AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value / 100.0))
	master_label.text = "%d%%" % int(value)
	if not _is_loading_settings:
		_save_settings()

func _on_sfx_vol_changed(value: float) -> void:
	var bus_idx : int = AudioServer.get_bus_index("SFX")
	if bus_idx >= 0:
		if value <= 0.0:
			AudioServer.set_bus_mute(bus_idx, true)
		else:
			AudioServer.set_bus_mute(bus_idx, false)
			AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value / 100.0))
	sfx_label.text = "%d%%" % int(value)
	if not _is_loading_settings:
		_save_settings()

func _on_music_vol_changed(value: float) -> void:
	var bus_idx : int = AudioServer.get_bus_index("Music")
	if bus_idx >= 0:
		if value <= 0.0:
			AudioServer.set_bus_mute(bus_idx, true)
		else:
			AudioServer.set_bus_mute(bus_idx, false)
			AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value / 100.0))
	music_label.text = "%d%%" % int(value)
	if not _is_loading_settings:
		_save_settings()

func _on_mute_all_toggled(toggled_on: bool) -> void:
	var bus_idx : int = AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		AudioServer.set_bus_mute(bus_idx, toggled_on)
	mute_all_toggle.text = "MUTED" if toggled_on else "UNMUTED"
	_play_sound("toggle", not toggled_on)
	if not _is_loading_settings:
		_save_settings()

func _on_hitmarker_toggled(toggled_on: bool) -> void:
	hitmarker_toggle.text = "ENABLED" if toggled_on else "DISABLED"
	_play_sound("toggle", toggled_on)
	if not _is_loading_settings:
		_save_settings()

func _on_window_mode_selected(index: int) -> void:
	match index:
		0: # Fullscreen
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		1: # Windowed
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		2: # Borderless Fullscreen
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_play_sound("click")
	if not _is_loading_settings:
		_save_settings()

func _on_vsync_toggled(toggled_on: bool) -> void:
	var mode : int = DisplayServer.VSYNC_ENABLED if toggled_on else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(mode)
	vsync_toggle.text = "ON" if toggled_on else "OFF"
	_play_sound("toggle", toggled_on)
	if not _is_loading_settings:
		_save_settings()

func _on_render_scale_selected(index: int) -> void:
	var scale_val : float = 1.0
	match index:
		0: scale_val = 0.75
		1: scale_val = 1.0
		2: scale_val = 1.25
	var vp : Viewport = get_viewport()
	if vp != null:
		vp.scaling_3d_scale = scale_val
	_play_sound("click")
	if not _is_loading_settings:
		_save_settings()

func _on_fps_cap_selected(index: int) -> void:
	var fps : int = 0
	match index:
		0: fps = 60
		1: fps = 120
		2: fps = 144
		3: fps = 0 # uncapped
	Engine.max_fps = fps
	_play_sound("click")
	if not _is_loading_settings:
		_save_settings()

func _on_vignette_changed(value: float) -> void:
	vignette_label.text = "%d%%" % int(value)
	var tree : SceneTree = get_tree()
	if tree != null and tree.root != null:
		var vig : ColorRect = tree.root.find_child("Vignette", true, false) as ColorRect
		if vig != null and vig.material is ShaderMaterial:
			var mat : ShaderMaterial = vig.material as ShaderMaterial
			mat.set_shader_parameter("vignette_opacity", value / 100.0)
	if not _is_loading_settings:
		_save_settings()

func _on_fov_changed(value: float) -> void:
	fov_label.text = "%d°" % int(value)
	if not _is_loading_settings:
		_save_settings()

func _on_mouse_sens_changed(value: float) -> void:
	mouse_sens_label.text = "%.2fx" % value
	if not _is_loading_settings:
		_save_settings()

func _on_invert_y_toggled(toggled_on: bool) -> void:
	invert_y_toggle.text = "ON" if toggled_on else "OFF"
	_play_sound("toggle", toggled_on)
	if not _is_loading_settings:
		_save_settings()

func _on_sprint_mode_selected(_index: int) -> void:
	_play_sound("click")
	if not _is_loading_settings:
		_save_settings()

func _on_reset_defaults_pressed() -> void:
	_play_sound("click")

	_is_loading_settings = true

	master_slider.value = 100.0
	_on_master_vol_changed(100.0)

	sfx_slider.value = 100.0
	_on_sfx_vol_changed(100.0)

	music_slider.value = 100.0
	_on_music_vol_changed(100.0)

	mute_all_toggle.button_pressed = false
	_on_mute_all_toggled(false)

	hitmarker_toggle.button_pressed = true
	_on_hitmarker_toggled(true)

	window_mode_btn.selected = 0
	_on_window_mode_selected(0)

	vsync_toggle.button_pressed = true
	_on_vsync_toggled(true)

	render_scale_btn.selected = 1
	_on_render_scale_selected(1)

	fps_cap_btn.selected = 3
	_on_fps_cap_selected(3)

	vignette_slider.value = 72.0
	_on_vignette_changed(72.0)

	fov_slider.value = 90.0
	_on_fov_changed(90.0)

	mouse_sens_slider.value = 1.0
	_on_mouse_sens_changed(1.0)

	invert_y_toggle.button_pressed = false
	_on_invert_y_toggled(false)

	sprint_mode_btn.selected = 0
	_on_sprint_mode_selected(0)

	_is_loading_settings = false
	_save_settings()

# -----------------------------------------------------------------------------
# Persistence Load & Save
# -----------------------------------------------------------------------------

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_volume", master_slider.value)
	cfg.set_value("audio", "sfx_volume", sfx_slider.value)
	cfg.set_value("audio", "music_volume", music_slider.value)
	cfg.set_value("audio", "mute_all", mute_all_toggle.button_pressed)
	cfg.set_value("audio", "hitmarker_sound", hitmarker_toggle.button_pressed)

	cfg.set_value("video", "window_mode", window_mode_btn.selected)
	cfg.set_value("video", "vsync", vsync_toggle.button_pressed)
	cfg.set_value("video", "render_scale", render_scale_btn.selected)
	cfg.set_value("video", "fps_cap", fps_cap_btn.selected)
	cfg.set_value("video", "vignette_opacity", vignette_slider.value)
	cfg.set_value("video", "fov", fov_slider.value)

	cfg.set_value("controls", "mouse_sens", mouse_sens_slider.value)
	cfg.set_value("controls", "invert_y", invert_y_toggle.button_pressed)
	cfg.set_value("controls", "sprint_mode", sprint_mode_btn.selected)

	cfg.save(SETTINGS_PATH)
	settings_applied.emit()

func _load_settings() -> void:
	_is_loading_settings = true
	var cfg := ConfigFile.new()
	var err := cfg.load(SETTINGS_PATH)
	if err == OK:
		var m_vol : float = cfg.get_value("audio", "master_volume", 100.0)
		master_slider.value = m_vol
		_on_master_vol_changed(m_vol)

		var s_vol : float = cfg.get_value("audio", "sfx_volume", 100.0)
		sfx_slider.value = s_vol
		_on_sfx_vol_changed(s_vol)

		var mu_vol : float = cfg.get_value("audio", "music_volume", 100.0)
		music_slider.value = mu_vol
		_on_music_vol_changed(mu_vol)

		var mute : bool = cfg.get_value("audio", "mute_all", false)
		mute_all_toggle.button_pressed = mute
		_on_mute_all_toggled(mute)

		var hit : bool = cfg.get_value("audio", "hitmarker_sound", true)
		hitmarker_toggle.button_pressed = hit
		_on_hitmarker_toggled(hit)

		var win_mode : int = cfg.get_value("video", "window_mode", 0)
		window_mode_btn.selected = win_mode
		_on_window_mode_selected(win_mode)

		var vsync : bool = cfg.get_value("video", "vsync", true)
		vsync_toggle.button_pressed = vsync
		_on_vsync_toggled(vsync)

		var r_scale : int = cfg.get_value("video", "render_scale", 1)
		render_scale_btn.selected = r_scale
		_on_render_scale_selected(r_scale)

		var fps : int = cfg.get_value("video", "fps_cap", 3)
		fps_cap_btn.selected = fps
		_on_fps_cap_selected(fps)

		var vig : float = cfg.get_value("video", "vignette_opacity", 72.0)
		vignette_slider.value = vig
		_on_vignette_changed(vig)

		var fov : float = cfg.get_value("video", "fov", 90.0)
		fov_slider.value = fov
		_on_fov_changed(fov)

		var sens : float = cfg.get_value("controls", "mouse_sens", 1.0)
		mouse_sens_slider.value = sens
		_on_mouse_sens_changed(sens)

		var inv : bool = cfg.get_value("controls", "invert_y", false)
		invert_y_toggle.button_pressed = inv
		_on_invert_y_toggled(inv)

		var sp : int = cfg.get_value("controls", "sprint_mode", 0)
		sprint_mode_btn.selected = sp
		_on_sprint_mode_selected(sp)
	else:
		_sync_from_engine()

	_is_loading_settings = false

func _sync_from_engine() -> void:
	var bus_idx : int = AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		var muted : bool = AudioServer.is_bus_mute(bus_idx)
		mute_all_toggle.button_pressed = muted
		mute_all_toggle.text = "MUTED" if muted else "UNMUTED"
		var linear : float = db_to_linear(AudioServer.get_bus_volume_db(bus_idx)) * 100.0
		master_slider.value = clampf(linear, 0.0, 100.0)
		master_label.text = "%d%%" % int(master_slider.value)

	var cur_mode : int = DisplayServer.window_get_mode()
	var borderless : bool = DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS)
	if cur_mode == DisplayServer.WINDOW_MODE_FULLSCREEN or cur_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		window_mode_btn.selected = 2 if borderless else 0
	else:
		window_mode_btn.selected = 1

	var vsync_mode : int = DisplayServer.window_get_vsync_mode()
	var vsync_on : bool = (vsync_mode != DisplayServer.VSYNC_DISABLED)
	vsync_toggle.button_pressed = vsync_on
	vsync_toggle.text = "ON" if vsync_on else "OFF"
