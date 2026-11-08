extends Control

## Destiny-inspired main menu with procedural emblem, title phase, tactical mode selection,
## dedicated operative specialization selection, full-screen settings, and locked mode teasers.

const GAME_SCENE_PATH : String = "res://scenes/main.tscn"
const TUTORIAL_SCENE_PATH : String = "res://scenes/tutorial/tutorial_map.tscn"
const RANGE_SCENE_PATH : String = "res://scenes/gamemodes/range_mode.tscn"

enum MenuState { TITLE_SCREEN = 0, MODE_SELECT = 1, CHARACTER_SELECT = 2, MAP_SELECT = 3 }
enum GameMode { TUTORIAL, SURVIVAL, SANDBOX, RANGE, ROCKET_MAYHEM }

var current_state : MenuState = MenuState.TITLE_SCREEN
var selected_mode : GameMode = GameMode.SURVIVAL
var _is_transitioning : bool = false
var _prompt_tween : Tween

# -----------------------------------------------------------------------------
# Phase 1: Title Screen
# -----------------------------------------------------------------------------
@onready var title_screen : Control = $TitleScreen
@onready var emblem : Control = $TitleScreen/CenterContainer/VBoxContainer/EmblemBox/Emblem
@onready var prompt_label : Label = $TitleScreen/CenterContainer/VBoxContainer/PromptBox/PromptLabel
@onready var fullscreen_start_button : Button = $TitleScreen/FullscreenStartButton

# -----------------------------------------------------------------------------
# Phase 2: Mode Select Screen
# -----------------------------------------------------------------------------
@onready var mode_select_screen : Control = $ModeSelectScreen

@onready var tutorial_card : Button = $ModeSelectScreen/CenterCards/VBoxContainer/CardsRow/TutorialCard
@onready var tutorial_bar : ColorRect = $ModeSelectScreen/CenterCards/VBoxContainer/CardsRow/TutorialCard/SelectionBar
@onready var tutorial_status : Label = $ModeSelectScreen/CenterCards/VBoxContainer/CardsRow/TutorialCard/CenterContainer/VBoxContainer/StatusLabel

@onready var survival_card : Button = $ModeSelectScreen/CenterCards/VBoxContainer/CardsRow/SurvivalCard
@onready var survival_bar : ColorRect = $ModeSelectScreen/CenterCards/VBoxContainer/CardsRow/SurvivalCard/SelectionBar
@onready var survival_status : Label = $ModeSelectScreen/CenterCards/VBoxContainer/CardsRow/SurvivalCard/CenterContainer/VBoxContainer/StatusLabel

@onready var sandbox_card : Button = $ModeSelectScreen/CenterCards/VBoxContainer/CardsRow/SandboxCard
@onready var sandbox_bar : ColorRect = $ModeSelectScreen/CenterCards/VBoxContainer/CardsRow/SandboxCard/SelectionBar
@onready var sandbox_status : Label = $ModeSelectScreen/CenterCards/VBoxContainer/CardsRow/SandboxCard/CenterContainer/VBoxContainer/StatusLabel

@onready var range_card : Button = $ModeSelectScreen/CenterCards/VBoxContainer/CardsRow/RangeCard
@onready var range_bar : ColorRect = $ModeSelectScreen/CenterCards/VBoxContainer/CardsRow/RangeCard/SelectionBar
@onready var range_status : Label = $ModeSelectScreen/CenterCards/VBoxContainer/CardsRow/RangeCard/CenterContainer/VBoxContainer/StatusLabel

@onready var mayhem_card : Button = $ModeSelectScreen/CenterCards/VBoxContainer/CardsRow/MayhemCard
@onready var mayhem_bar : ColorRect = $ModeSelectScreen/CenterCards/VBoxContainer/CardsRow/MayhemCard/SelectionBar
@onready var mayhem_status : Label = $ModeSelectScreen/CenterCards/VBoxContainer/CardsRow/MayhemCard/CenterContainer/VBoxContainer/StatusLabel

@onready var story_card : Button = $ModeSelectScreen/CenterCards/VBoxContainer/CardsRow/StoryCard
@onready var story_bar : ColorRect = $ModeSelectScreen/CenterCards/VBoxContainer/CardsRow/StoryCard/SelectionBar
@onready var story_status : Label = $ModeSelectScreen/CenterCards/VBoxContainer/CardsRow/StoryCard/CenterContainer/VBoxContainer/StatusLabel

@onready var coop_card : Button = $ModeSelectScreen/CenterCards/VBoxContainer/CardsRow/CoopCard
@onready var coop_bar : ColorRect = $ModeSelectScreen/CenterCards/VBoxContainer/CardsRow/CoopCard/SelectionBar
@onready var coop_status : Label = $ModeSelectScreen/CenterCards/VBoxContainer/CardsRow/CoopCard/CenterContainer/VBoxContainer/StatusLabel

@onready var main_launch_button : Button = $ModeSelectScreen/CenterCards/VBoxContainer/LaunchSection/MainLaunchButton
@onready var return_title_button : Button = $ModeSelectScreen/BottomBar/HBoxContainer/ReturnTitleButton

# Sandbox Map Selection
var selected_sandbox_map : int = 1 # 0: Canyon, 1: Space Base, 2: Transport Dock
@onready var map_select_section : Control = $ModeSelectScreen/CenterCards/VBoxContainer/MapSelectSection
@onready var map_select_label : Label = $ModeSelectScreen/CenterCards/VBoxContainer/MapSelectSection/MapSelectLabel
@onready var map_button_1 : Button = $ModeSelectScreen/CenterCards/VBoxContainer/MapSelectSection/MapButtonsRow/MapButton1
@onready var map_button_2 : Button = $ModeSelectScreen/CenterCards/VBoxContainer/MapSelectSection/MapButtonsRow/MapButton2
@onready var map_button_3 : Button = $ModeSelectScreen/CenterCards/VBoxContainer/MapSelectSection/MapButtonsRow/MapButton3
@onready var map_desc_label : Label = $ModeSelectScreen/CenterCards/VBoxContainer/MapSelectSection/MapDescLabel

# Locked Teaser Modal
@onready var teaser_modal : Control = $ModeSelectScreen/TeaserModal
@onready var teaser_header : Label = $ModeSelectScreen/TeaserModal/CenterContainer/Panel/MarginContainer/VBoxContainer/HeaderLabel
@onready var teaser_title : Label = $ModeSelectScreen/TeaserModal/CenterContainer/Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var teaser_desc : Label = $ModeSelectScreen/TeaserModal/CenterContainer/Panel/MarginContainer/VBoxContainer/DescLabel
@onready var teaser_close_btn : Button = $ModeSelectScreen/TeaserModal/CenterContainer/Panel/MarginContainer/VBoxContainer/CloseButton

# Top-Right Utility Icons
@onready var settings_button : Button = $ModeSelectScreen/TopBar/HBoxContainer/UtilityButtons/SettingsButton
@onready var controls_button : Button = $ModeSelectScreen/TopBar/HBoxContainer/UtilityButtons/ControlsButton
@onready var quit_button : Button = $ModeSelectScreen/TopBar/HBoxContainer/UtilityButtons/QuitButton
@onready var power_icon : Control = $ModeSelectScreen/TopBar/HBoxContainer/UtilityButtons/QuitButton/PowerIcon

# -----------------------------------------------------------------------------
# Phase 3: Dedicated Character Select Screen
# -----------------------------------------------------------------------------
@onready var character_select_screen : Control = $CharacterSelectScreen
@onready var mission_briefing_label : Label = $CharacterSelectScreen/TopBar/HBoxContainer/MissionBriefingLabel

@onready var astronaut_card : Button = $CharacterSelectScreen/CenterCards/VBoxContainer/CardsRow/AstronautCard
@onready var engineer_card : Button = $CharacterSelectScreen/CenterCards/VBoxContainer/CardsRow/EngineerCard
@onready var medic_card : Button = $CharacterSelectScreen/CenterCards/VBoxContainer/CardsRow/MedicCard
@onready var explorer_card : Button = $CharacterSelectScreen/CenterCards/VBoxContainer/CardsRow/ExplorerCard

@onready var astronaut_bar : ColorRect = $CharacterSelectScreen/CenterCards/VBoxContainer/CardsRow/AstronautCard/SelectionBar
@onready var engineer_bar : ColorRect = $CharacterSelectScreen/CenterCards/VBoxContainer/CardsRow/EngineerCard/SelectionBar
@onready var medic_bar : ColorRect = $CharacterSelectScreen/CenterCards/VBoxContainer/CardsRow/MedicCard/SelectionBar
@onready var explorer_bar : ColorRect = $CharacterSelectScreen/CenterCards/VBoxContainer/CardsRow/ExplorerCard/SelectionBar

@onready var astronaut_status : Label = $CharacterSelectScreen/CenterCards/VBoxContainer/CardsRow/AstronautCard/MarginContainer/VBoxContainer/StatusLabel
@onready var engineer_status : Label = $CharacterSelectScreen/CenterCards/VBoxContainer/CardsRow/EngineerCard/MarginContainer/VBoxContainer/StatusLabel
@onready var medic_status : Label = $CharacterSelectScreen/CenterCards/VBoxContainer/CardsRow/MedicCard/MarginContainer/VBoxContainer/StatusLabel
@onready var explorer_status : Label = $CharacterSelectScreen/CenterCards/VBoxContainer/CardsRow/ExplorerCard/MarginContainer/VBoxContainer/StatusLabel

@onready var main_deploy_button : Button = $CharacterSelectScreen/BottomBar/HBoxContainer/MainDeployButton
@onready var return_mode_button : Button = $CharacterSelectScreen/BottomBar/HBoxContainer/ReturnModeButton

@onready var char_settings_button : Button = $CharacterSelectScreen/TopBar/HBoxContainer/UtilityButtons/CharSettingsButton
@onready var char_controls_button : Button = $CharacterSelectScreen/TopBar/HBoxContainer/UtilityButtons/CharControlsButton
@onready var char_quit_button : Button = $CharacterSelectScreen/TopBar/HBoxContainer/UtilityButtons/CharQuitButton
@onready var char_power_icon : Control = $CharacterSelectScreen/TopBar/HBoxContainer/UtilityButtons/CharQuitButton/PowerIcon

# -----------------------------------------------------------------------------
# Phase 3: Dedicated Map Select Screen (Sandbox)
# -----------------------------------------------------------------------------
@onready var map_select_screen : Control = $MapSelectScreen
@onready var canyon_card : Button = $MapSelectScreen/CenterCards/VBoxContainer/CardsRow/CanyonCard
@onready var base_card : Button = $MapSelectScreen/CenterCards/VBoxContainer/CardsRow/BaseCard
@onready var dock_card : Button = $MapSelectScreen/CenterCards/VBoxContainer/CardsRow/DockCard

@onready var canyon_bar : ColorRect = $MapSelectScreen/CenterCards/VBoxContainer/CardsRow/CanyonCard/SelectionBar
@onready var base_bar : ColorRect = $MapSelectScreen/CenterCards/VBoxContainer/CardsRow/BaseCard/SelectionBar
@onready var dock_bar : ColorRect = $MapSelectScreen/CenterCards/VBoxContainer/CardsRow/DockCard/SelectionBar

@onready var canyon_status : Label = $MapSelectScreen/CenterCards/VBoxContainer/CardsRow/CanyonCard/MarginContainer/VBoxContainer/StatusLabel
@onready var base_status : Label = $MapSelectScreen/CenterCards/VBoxContainer/CardsRow/BaseCard/MarginContainer/VBoxContainer/StatusLabel
@onready var dock_status : Label = $MapSelectScreen/CenterCards/VBoxContainer/CardsRow/DockCard/MarginContainer/VBoxContainer/StatusLabel

@onready var map_proceed_button : Button = $MapSelectScreen/BottomBar/HBoxContainer/ProceedButton
@onready var map_return_button : Button = $MapSelectScreen/BottomBar/HBoxContainer/ReturnModeButton

@onready var map_settings_button : Button = $MapSelectScreen/TopBar/HBoxContainer/UtilityButtons/MapSettingsButton
@onready var map_controls_button : Button = $MapSelectScreen/TopBar/HBoxContainer/UtilityButtons/MapControlsButton
@onready var map_quit_button : Button = $MapSelectScreen/TopBar/HBoxContainer/UtilityButtons/MapQuitButton
@onready var map_power_icon : Control = $MapSelectScreen/TopBar/HBoxContainer/UtilityButtons/MapQuitButton/PowerIcon

var _model_pivots : Array[Node3D] = []

# Dedicated Full-Screen Settings Page
@onready var settings_menu : Control = $SettingsMenu

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var snd : Node = get_node_or_null("/root/UiSound")
	if snd != null and snd.has_method("play_music"):
		snd.play_music("menu")

	title_screen.visible = true
	title_screen.modulate.a = 1.0
	mode_select_screen.visible = false
	if is_instance_valid(character_select_screen):
		character_select_screen.visible = false
	if is_instance_valid(map_select_screen):
		map_select_screen.visible = false
	if is_instance_valid(settings_menu):
		settings_menu.visible = false
	if is_instance_valid(teaser_modal):
		teaser_modal.visible = false

	# Setup pivots
	var card_pivot := Vector2(75.0, 175.0)
	tutorial_card.pivot_offset = card_pivot
	survival_card.pivot_offset = card_pivot
	sandbox_card.pivot_offset = card_pivot
	if range_card != null: range_card.pivot_offset = card_pivot
	if mayhem_card != null: mayhem_card.pivot_offset = card_pivot
	if story_card != null: story_card.pivot_offset = card_pivot
	if coop_card != null: coop_card.pivot_offset = card_pivot
	main_launch_button.pivot_offset = Vector2(140.0, 24.0)

	var map_card_pivot := Vector2(142.5, 205.0)
	if canyon_card != null: canyon_card.pivot_offset = map_card_pivot
	if base_card != null: base_card.pivot_offset = map_card_pivot
	if dock_card != null: dock_card.pivot_offset = map_card_pivot
	if map_proceed_button != null: map_proceed_button.pivot_offset = Vector2(180.0, 24.0)

	var char_card_pivot := Vector2(122.5, 205.0)
	if astronaut_card != null: astronaut_card.pivot_offset = char_card_pivot
	if engineer_card != null: engineer_card.pivot_offset = char_card_pivot
	if medic_card != null: medic_card.pivot_offset = char_card_pivot
	if explorer_card != null: explorer_card.pivot_offset = char_card_pivot
	if main_deploy_button != null: main_deploy_button.pivot_offset = Vector2(180.0, 24.0)

	# Set mouse cursor
	tutorial_card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	survival_card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	sandbox_card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if range_card != null: range_card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if mayhem_card != null: mayhem_card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if story_card != null: story_card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if coop_card != null: coop_card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	main_launch_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	if canyon_card != null: canyon_card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if base_card != null: base_card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if dock_card != null: dock_card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if map_proceed_button != null: map_proceed_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if map_return_button != null: map_return_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	if astronaut_card != null: astronaut_card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if engineer_card != null: engineer_card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if medic_card != null: medic_card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if explorer_card != null: explorer_card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if main_deploy_button != null: main_deploy_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if return_mode_button != null: return_mode_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# Connect Title Phase
	fullscreen_start_button.pressed.connect(_on_start_prompt_clicked)

	# Connect Playable Mode Cards
	tutorial_card.pressed.connect(func():
		_play_sound("click")
		_select_mode(GameMode.TUTORIAL)
	)
	survival_card.pressed.connect(func():
		_play_sound("click")
		_select_mode(GameMode.SURVIVAL)
	)
	sandbox_card.pressed.connect(func():
		_play_sound("click")
		_select_mode(GameMode.SANDBOX)
	)
	if range_card != null:
		range_card.pressed.connect(func():
			_play_sound("click")
			_select_mode(GameMode.RANGE)
		)
	if mayhem_card != null:
		mayhem_card.pressed.connect(func():
			_play_sound("click")
			_select_mode(GameMode.ROCKET_MAYHEM)
		)

	# Connect Locked Teaser Cards
	if story_card != null:
		story_card.pressed.connect(func():
			_play_sound("toggle", false)
			_open_teaser_modal(
				"OPERATION AURORA // PROTOCOL 05",
				"CLASSIFIED MILITARY BRIEFING",
				"Classified planetary reconnaissance mission into deep uncharted sectors.\nFull narrative story campaign undergoing orbital clearance.\n\nSTATUS: ENCRYPTED // UNDER ACTIVE DEVELOPMENT"
			)
		)
	if coop_card != null:
		coop_card.pressed.connect(func():
			_play_sound("toggle", false)
			_open_teaser_modal(
				"TACTICAL SQUAD // PROTOCOL 06",
				"CO-OPERATIVE DEPLOYMENT",
				"Multiplayer neural network array connecting allied astronaut fireteams.\nCo-op tactical squad incursions currently under synchronization testing.\n\nSTATUS: OFFLINE // UNDER ACTIVE DEVELOPMENT"
			)
		)

	if teaser_close_btn != null:
		teaser_close_btn.pressed.connect(func():
			_play_sound("click")
			_close_teaser_modal()
		)

	main_launch_button.pressed.connect(_on_launch_pressed)
	return_title_button.pressed.connect(func():
		_play_sound("click")
		_transition_to_title_screen()
	)

	# Connect Sandbox Map Selection Cards
	if canyon_card != null:
		canyon_card.pressed.connect(func(): _select_sandbox_map(0))
		_setup_map_card_interactions(canyon_card, 0)
	if base_card != null:
		base_card.pressed.connect(func(): _select_sandbox_map(1))
		_setup_map_card_interactions(base_card, 1)
	if dock_card != null:
		dock_card.pressed.connect(func(): _select_sandbox_map(2))
		_setup_map_card_interactions(dock_card, 2)

	if map_proceed_button != null:
		map_proceed_button.pressed.connect(_on_map_proceed_pressed)
		_setup_button_hover(map_proceed_button)
	if map_return_button != null:
		map_return_button.pressed.connect(_transition_from_map_select_to_mode_select)
		_setup_button_hover(map_return_button)

	if map_settings_button != null:
		map_settings_button.pressed.connect(func():
			_play_sound("click")
			_open_settings("audio")
		)
		_setup_icon_hover(map_settings_button)
	if map_controls_button != null:
		map_controls_button.pressed.connect(func():
			_play_sound("click")
			_open_settings("how_to_play")
		)
		_setup_icon_hover(map_controls_button)
	if map_quit_button != null:
		map_quit_button.pressed.connect(func():
			_play_sound("click")
			_on_quit_pressed()
		)
		_setup_map_quit_hover()

	# Connect Legacy Sandbox Map Selection Buttons
	if map_button_1 != null:
		map_button_1.pressed.connect(func(): _select_sandbox_map(0))
		_setup_button_hover(map_button_1)
	if map_button_2 != null:
		map_button_2.pressed.connect(func(): _select_sandbox_map(1))
		_setup_button_hover(map_button_2)
	if map_button_3 != null:
		map_button_3.pressed.connect(func(): _select_sandbox_map(2))
		_setup_button_hover(map_button_3)

	# Connect Character Selection Cards
	if astronaut_card != null:
		astronaut_card.pressed.connect(func(): _select_operative(0))
		_setup_operative_card_interactions(astronaut_card, 0)
	if engineer_card != null:
		engineer_card.pressed.connect(func(): _select_operative(1))
		_setup_operative_card_interactions(engineer_card, 1)
	if medic_card != null:
		medic_card.pressed.connect(func(): _select_operative(2))
		_setup_operative_card_interactions(medic_card, 2)
	if explorer_card != null:
		explorer_card.pressed.connect(func(): _select_operative(3))
		_setup_operative_card_interactions(explorer_card, 3)

	if main_deploy_button != null:
		main_deploy_button.pressed.connect(_on_deploy_pressed)
		_setup_button_hover(main_deploy_button)

	if return_mode_button != null:
		return_mode_button.pressed.connect(_transition_from_character_select_to_mode_select)
		_setup_button_hover(return_mode_button)

	# Connect Mode Top-Right Utilities
	settings_button.pressed.connect(func():
		_play_sound("click")
		_open_settings("audio")
	)
	controls_button.pressed.connect(func():
		_play_sound("click")
		_open_settings("how_to_play")
	)
	quit_button.pressed.connect(func():
		_play_sound("click")
		_on_quit_pressed()
	)

	# Connect Char Select Top-Right Utilities
	if char_settings_button != null:
		char_settings_button.pressed.connect(func():
			_play_sound("click")
			_open_settings("audio")
		)
		_setup_icon_hover(char_settings_button)
	if char_controls_button != null:
		char_controls_button.pressed.connect(func():
			_play_sound("click")
			_open_settings("how_to_play")
		)
		_setup_icon_hover(char_controls_button)
	if char_quit_button != null:
		char_quit_button.pressed.connect(func():
			_play_sound("click")
			_on_quit_pressed()
		)
		_setup_char_quit_hover()

	if is_instance_valid(settings_menu):
		settings_menu.closed.connect(_on_settings_closed)

	# Setup Micro-interactions
	_setup_card_interactions(tutorial_card, GameMode.TUTORIAL)
	_setup_card_interactions(survival_card, GameMode.SURVIVAL)
	_setup_card_interactions(sandbox_card, GameMode.SANDBOX)
	if range_card != null: _setup_card_interactions(range_card, GameMode.RANGE)
	if mayhem_card != null: _setup_card_interactions(mayhem_card, GameMode.ROCKET_MAYHEM)
	if story_card != null: _setup_locked_card_interactions(story_card)
	if coop_card != null: _setup_locked_card_interactions(coop_card)
	_setup_button_hover(main_launch_button)

	_setup_icon_hover(settings_button)
	_setup_icon_hover(controls_button)
	_setup_quit_hover()

	_setup_button_hover(return_title_button)

	# Ensure all card and button overlay children pass clicks through to their parent button (no dead zones!)
	var all_interactive_buttons : Array[Button] = [
		tutorial_card, survival_card, sandbox_card, range_card, mayhem_card, story_card, coop_card,
		astronaut_card, engineer_card, medic_card, explorer_card,
		canyon_card, base_card, dock_card,
		main_launch_button, main_deploy_button, map_proceed_button,
		return_title_button, return_mode_button, map_return_button
	]
	for btn in all_interactive_buttons:
		if btn != null:
			_make_card_click_transparent(btn)

	# Initialize selection state without animation
	_update_mode_selection_ui(false)
	_update_map_selection_ui(false)
	_update_character_selection_ui(false)
	_setup_operative_banners()
	_start_prompt_pulse()

func _process(delta: float) -> void:
	if current_state != MenuState.CHARACTER_SELECT:
		return
	var t : float = Time.get_ticks_msec() / 1000.0
	for i in range(_model_pivots.size()):
		var pivot : Node3D = _model_pivots[i]
		if is_instance_valid(pivot):
			pivot.rotation.y = deg_to_rad(168.0) + sin(t * 1.2 + i * 1.5) * 0.06

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(settings_menu) and settings_menu.visible:
		return
	if is_instance_valid(teaser_modal) and teaser_modal.visible:
		if event.is_action_pressed("ui_cancel"):
			_close_teaser_modal()
			get_viewport().set_input_as_handled()
		return

	if current_state == MenuState.TITLE_SCREEN:
		if event.is_pressed() and not event.is_echo():
			_on_start_prompt_clicked()
			get_viewport().set_input_as_handled()
	elif current_state == MenuState.MODE_SELECT:
		if event.is_action_pressed("ui_cancel"):
			_transition_to_title_screen()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_accept"):
			if not _is_transitioning:
				_on_launch_pressed()
				get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_left"):
			var modes := [GameMode.TUTORIAL, GameMode.SURVIVAL, GameMode.SANDBOX, GameMode.RANGE, GameMode.ROCKET_MAYHEM]
			var idx : int = modes.find(selected_mode)
			if idx != -1:
				_select_mode(modes[(idx - 1 + modes.size()) % modes.size()])
				get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_right"):
			var modes := [GameMode.TUTORIAL, GameMode.SURVIVAL, GameMode.SANDBOX, GameMode.RANGE, GameMode.ROCKET_MAYHEM]
			var idx : int = modes.find(selected_mode)
			if idx != -1:
				_select_mode(modes[(idx + 1) % modes.size()])
				get_viewport().set_input_as_handled()
		elif event is InputEventKey and event.pressed and not event.echo:
			match event.keycode:
				KEY_1, KEY_KP_1:
					_select_mode(GameMode.TUTORIAL)
					get_viewport().set_input_as_handled()
				KEY_2, KEY_KP_2:
					_select_mode(GameMode.SURVIVAL)
					get_viewport().set_input_as_handled()
				KEY_3, KEY_KP_3:
					_select_mode(GameMode.SANDBOX)
					get_viewport().set_input_as_handled()
				KEY_4, KEY_KP_4:
					_select_mode(GameMode.RANGE)
					get_viewport().set_input_as_handled()
				KEY_5, KEY_KP_5:
					_select_mode(GameMode.ROCKET_MAYHEM)
					get_viewport().set_input_as_handled()
	elif current_state == MenuState.MAP_SELECT:
		if event.is_action_pressed("ui_cancel"):
			_transition_from_map_select_to_mode_select()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_accept"):
			if not _is_transitioning:
				_on_map_proceed_pressed()
				get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_left"):
			_select_sandbox_map((selected_sandbox_map - 1 + 3) % 3)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_right"):
			_select_sandbox_map((selected_sandbox_map + 1) % 3)
			get_viewport().set_input_as_handled()
		elif event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_1 or event.keycode == KEY_KP_1:
				_select_sandbox_map(0)
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_2 or event.keycode == KEY_KP_2:
				_select_sandbox_map(1)
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_3 or event.keycode == KEY_KP_3:
				_select_sandbox_map(2)
				get_viewport().set_input_as_handled()
	elif current_state == MenuState.CHARACTER_SELECT:
		var char_data : Node = get_node_or_null("/root/CharacterData")
		if event.is_action_pressed("ui_cancel"):
			if selected_mode == GameMode.SANDBOX:
				_transition_from_character_select_to_map_select()
			else:
				_transition_from_character_select_to_mode_select()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_accept"):
			if not _is_transitioning:
				_on_deploy_pressed()
				get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_left"):
			var cur_cls : int = int(char_data.get("current_class")) if char_data != null else 0
			var next_cls : int = (cur_cls - 1 + 4) % 4
			_select_operative(next_cls)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_right"):
			var cur_cls : int = int(char_data.get("current_class")) if char_data != null else 0
			var next_cls : int = (cur_cls + 1) % 4
			_select_operative(next_cls)
			get_viewport().set_input_as_handled()
		elif event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_1 or event.keycode == KEY_KP_1:
				_select_operative(0)
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_2 or event.keycode == KEY_KP_2:
				_select_operative(1)
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_3 or event.keycode == KEY_KP_3:
				_select_operative(2)
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_4 or event.keycode == KEY_KP_4:
				_select_operative(3)
				get_viewport().set_input_as_handled()

# -----------------------------------------------------------------------------
# Screen State Transitions
# -----------------------------------------------------------------------------

func _start_prompt_pulse() -> void:
	if _prompt_tween != null and _prompt_tween.is_valid():
		_prompt_tween.kill()
	_prompt_tween = create_tween().set_loops()
	_prompt_tween.tween_property(prompt_label, "modulate:a", 0.35, 1.1).set_trans(Tween.TRANS_SINE)
	_prompt_tween.tween_property(prompt_label, "modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_SINE)

func _on_start_prompt_clicked() -> void:
	if _is_transitioning or current_state != MenuState.TITLE_SCREEN:
		return
	_play_sound("click")
	_transition_to_mode_select()

func _transition_to_mode_select() -> void:
	_is_transitioning = true
	current_state = MenuState.MODE_SELECT

	if is_instance_valid(emblem) and emblem.has_method("play_burst"):
		emblem.play_burst()

	if _prompt_tween != null and _prompt_tween.is_valid():
		_prompt_tween.kill()

	_update_mode_selection_ui(false)

	var tween : Tween = create_tween()
	tween.tween_property(title_screen, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		title_screen.visible = false
		mode_select_screen.visible = true
		mode_select_screen.modulate.a = 0.0
		mode_select_screen.position.y = 12.0
	)
	var in_tween : Tween = create_tween().set_parallel(true)
	in_tween.tween_property(mode_select_screen, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	in_tween.tween_property(mode_select_screen, "position:y", 0.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	await in_tween.finished
	_is_transitioning = false

func _transition_to_title_screen() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	current_state = MenuState.TITLE_SCREEN

	var tween : Tween = create_tween()
	tween.tween_property(mode_select_screen, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		mode_select_screen.visible = false
		title_screen.visible = true
		title_screen.modulate.a = 0.0
		_start_prompt_pulse()
	)
	tween.tween_property(title_screen, "modulate:a", 1.0, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	await tween.finished
	_is_transitioning = false

func _transition_to_character_select() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	current_state = MenuState.CHARACTER_SELECT

	# Update mission briefing header
	if mission_briefing_label != null:
		match selected_mode:
			GameMode.TUTORIAL:
				mission_briefing_label.text = "DEPLOYMENT: PROVING GROUNDS // PROTOCOL 00"
				mission_briefing_label.modulate = Color(0.2, 0.75, 1.0, 1.0)
			GameMode.SURVIVAL:
				mission_briefing_label.text = "DEPLOYMENT: SURVIVAL PROTOCOL // 01"
				mission_briefing_label.modulate = Color(0.92, 0.22, 0.32, 1.0)
			GameMode.SANDBOX:
				var map_names := ["CANYON", "SPACE BASE", "TRANSPORT DOCK"]
				var s_map : String = map_names[selected_sandbox_map] if selected_sandbox_map < map_names.size() else "SPACE BASE"
				mission_briefing_label.text = "DEPLOYMENT: SANDBOX TESTBED // SECTOR %02d (%s)" % [selected_sandbox_map + 1, s_map]
				mission_briefing_label.modulate = Color(0.96, 0.68, 0.18, 1.0)
			GameMode.RANGE:
				mission_briefing_label.text = "DEPLOYMENT: THE RANGE // PROTOCOL 03"
				mission_briefing_label.modulate = Color(0.2, 0.75, 1.0, 1.0)
			GameMode.ROCKET_MAYHEM:
				mission_briefing_label.text = "DEPLOYMENT: ROCKET MAYHEM // PROTOCOL 04"
				mission_briefing_label.modulate = Color(1.0, 0.35, 0.15, 1.0)

	_update_character_selection_ui(false)

	var tween : Tween = create_tween()
	tween.tween_property(mode_select_screen, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		mode_select_screen.visible = false
		character_select_screen.visible = true
		character_select_screen.modulate.a = 0.0
		character_select_screen.position.y = 12.0
	)
	var in_tween : Tween = create_tween().set_parallel(true)
	in_tween.tween_property(character_select_screen, "modulate:a", 1.0, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	in_tween.tween_property(character_select_screen, "position:y", 0.0, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	await in_tween.finished
	_is_transitioning = false

func _transition_from_character_select_to_mode_select() -> void:
	if _is_transitioning:
		return
	if selected_mode == GameMode.SANDBOX:
		_transition_from_character_select_to_map_select()
		return
	_is_transitioning = true
	current_state = MenuState.MODE_SELECT
	_play_sound("click")

	var tween : Tween = create_tween()
	tween.tween_property(character_select_screen, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		character_select_screen.visible = false
		mode_select_screen.visible = true
		mode_select_screen.modulate.a = 0.0
		mode_select_screen.position.y = -8.0
	)
	var in_tween : Tween = create_tween().set_parallel(true)
	in_tween.tween_property(mode_select_screen, "modulate:a", 1.0, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	in_tween.tween_property(mode_select_screen, "position:y", 0.0, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	await in_tween.finished
	_is_transitioning = false

func _transition_to_map_select() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	current_state = MenuState.MAP_SELECT
	_update_map_selection_ui(false)

	var tween : Tween = create_tween()
	tween.tween_property(mode_select_screen, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		mode_select_screen.visible = false
		map_select_screen.visible = true
		map_select_screen.modulate.a = 0.0
		map_select_screen.position.y = 12.0
	)
	var in_tween : Tween = create_tween().set_parallel(true)
	in_tween.tween_property(map_select_screen, "modulate:a", 1.0, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	in_tween.tween_property(map_select_screen, "position:y", 0.0, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	await in_tween.finished
	_is_transitioning = false

func _transition_from_map_select_to_mode_select() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	current_state = MenuState.MODE_SELECT
	_play_sound("click")

	var tween : Tween = create_tween()
	tween.tween_property(map_select_screen, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		map_select_screen.visible = false
		mode_select_screen.visible = true
		mode_select_screen.modulate.a = 0.0
		mode_select_screen.position.y = -8.0
	)
	var in_tween : Tween = create_tween().set_parallel(true)
	in_tween.tween_property(mode_select_screen, "modulate:a", 1.0, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	in_tween.tween_property(mode_select_screen, "position:y", 0.0, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	await in_tween.finished
	_is_transitioning = false

func _transition_from_map_select_to_character_select() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	current_state = MenuState.CHARACTER_SELECT

	if mission_briefing_label != null:
		var map_names := ["CANYON", "SPACE BASE", "TRANSPORT DOCK"]
		var s_map : String = map_names[selected_sandbox_map] if selected_sandbox_map < map_names.size() else "SPACE BASE"
		mission_briefing_label.text = "DEPLOYMENT: SANDBOX TESTBED // SECTOR %02d (%s)" % [selected_sandbox_map + 1, s_map]
		mission_briefing_label.modulate = Color(0.96, 0.68, 0.18, 1.0)

	_update_character_selection_ui(false)

	var tween : Tween = create_tween()
	tween.tween_property(map_select_screen, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		map_select_screen.visible = false
		character_select_screen.visible = true
		character_select_screen.modulate.a = 0.0
		character_select_screen.position.y = 12.0
	)
	var in_tween : Tween = create_tween().set_parallel(true)
	in_tween.tween_property(character_select_screen, "modulate:a", 1.0, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	in_tween.tween_property(character_select_screen, "position:y", 0.0, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	await in_tween.finished
	_is_transitioning = false

func _transition_from_character_select_to_map_select() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	current_state = MenuState.MAP_SELECT
	_play_sound("click")

	var tween : Tween = create_tween()
	tween.tween_property(character_select_screen, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		character_select_screen.visible = false
		map_select_screen.visible = true
		map_select_screen.modulate.a = 0.0
		map_select_screen.position.y = -8.0
	)
	var in_tween : Tween = create_tween().set_parallel(true)
	in_tween.tween_property(map_select_screen, "modulate:a", 1.0, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	in_tween.tween_property(map_select_screen, "position:y", 0.0, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	await in_tween.finished
	_is_transitioning = false

# -----------------------------------------------------------------------------
# Mode Selection Phase
# -----------------------------------------------------------------------------

func _select_mode(mode: GameMode) -> void:
	if _is_transitioning:
		return
	if selected_mode == mode:
		return
	selected_mode = mode
	_update_mode_selection_ui(true)

func _update_mode_selection_ui(animated: bool) -> void:
	var is_tutorial : bool = (selected_mode == GameMode.TUTORIAL)
	var is_survival : bool = (selected_mode == GameMode.SURVIVAL)
	var is_sandbox : bool = (selected_mode == GameMode.SANDBOX)
	var is_range : bool = (selected_mode == GameMode.RANGE)
	var is_mayhem : bool = (selected_mode == GameMode.ROCKET_MAYHEM)

	tutorial_bar.visible = is_tutorial
	survival_bar.visible = is_survival
	sandbox_bar.visible = is_sandbox
	if range_bar != null: range_bar.visible = is_range
	if mayhem_bar != null: mayhem_bar.visible = is_mayhem
	if story_bar != null: story_bar.visible = false
	if coop_bar != null: coop_bar.visible = false

	tutorial_status.text = "◈ SELECTED ◈" if is_tutorial else "PROVING GROUNDS"
	survival_status.text = "◈ SELECTED ◈" if is_survival else "ENDLESS SWARM"
	sandbox_status.text = "◈ SELECTED ◈" if is_sandbox else "FREE ROAM"
	if range_status != null: range_status.text = "◈ SELECTED ◈" if is_range else "WEAPON TESTING"
	if mayhem_status != null: mayhem_status.text = "◈ SELECTED ◈" if is_mayhem else "CHAOS COMBAT"
	if story_status != null: story_status.text = "LOCKED // TEASER"
	if coop_status != null: coop_status.text = "LOCKED // TEASER"

	if map_select_section != null:
		map_select_section.visible = false

	if is_tutorial:
		main_launch_button.text = "▶  SELECT OPERATIVE  •  TUTORIAL"
	elif is_survival:
		main_launch_button.text = "▶  SELECT OPERATIVE  •  SURVIVAL"
	elif is_sandbox:
		main_launch_button.text = "▶  SELECT MAP  •  SANDBOX"
	elif is_range:
		main_launch_button.text = "▶  SELECT OPERATIVE  •  THE RANGE"
	elif is_mayhem:
		main_launch_button.text = "▶  SELECT OPERATIVE  •  ROCKET MAYHEM"

	var tut_alpha : float = 1.0 if is_tutorial else 0.52
	var surv_alpha : float = 1.0 if is_survival else 0.52
	var sand_alpha : float = 1.0 if is_sandbox else 0.52
	var range_alpha : float = 1.0 if is_range else 0.52
	var mayhem_alpha : float = 1.0 if is_mayhem else 0.52

	var tut_scale : Vector2 = Vector2(1.025, 1.025) if is_tutorial else Vector2.ONE
	var surv_scale : Vector2 = Vector2(1.025, 1.025) if is_survival else Vector2.ONE
	var sand_scale : Vector2 = Vector2(1.025, 1.025) if is_sandbox else Vector2.ONE
	var range_scale : Vector2 = Vector2(1.025, 1.025) if is_range else Vector2.ONE
	var mayhem_scale : Vector2 = Vector2(1.025, 1.025) if is_mayhem else Vector2.ONE

	if animated:
		var tween : Tween = create_tween().set_parallel(true)
		tween.tween_property(tutorial_card, "modulate:a", tut_alpha, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(tutorial_card, "scale", tut_scale, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(survival_card, "modulate:a", surv_alpha, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(survival_card, "scale", surv_scale, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(sandbox_card, "modulate:a", sand_alpha, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(sandbox_card, "scale", sand_scale, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if range_card != null:
			tween.tween_property(range_card, "modulate:a", range_alpha, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(range_card, "scale", range_scale, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if mayhem_card != null:
			tween.tween_property(mayhem_card, "modulate:a", mayhem_alpha, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(mayhem_card, "scale", mayhem_scale, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if story_card != null:
			tween.tween_property(story_card, "modulate:a", 0.45, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(story_card, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if coop_card != null:
			tween.tween_property(coop_card, "modulate:a", 0.45, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(coop_card, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		tutorial_card.modulate.a = tut_alpha
		tutorial_card.scale = tut_scale
		survival_card.modulate.a = surv_alpha
		survival_card.scale = surv_scale
		sandbox_card.modulate.a = sand_alpha
		sandbox_card.scale = sand_scale
		if range_card != null:
			range_card.modulate.a = range_alpha
			range_card.scale = range_scale
		if mayhem_card != null:
			mayhem_card.modulate.a = mayhem_alpha
			mayhem_card.scale = mayhem_scale
		if story_card != null:
			story_card.modulate.a = 0.45
			story_card.scale = Vector2.ONE
		if coop_card != null:
			coop_card.modulate.a = 0.45
			coop_card.scale = Vector2.ONE

func _select_sandbox_map(map_index: int) -> void:
	if selected_sandbox_map == map_index and current_state == MenuState.MAP_SELECT:
		return
	_play_sound("click")
	selected_sandbox_map = map_index
	_update_map_selection_ui(true)
	_update_map_buttons_ui()

func _update_map_selection_ui(animated: bool) -> void:
	var cards := [canyon_card, base_card, dock_card]
	var bars := [canyon_bar, base_bar, dock_bar]
	var statuses := [canyon_status, base_status, dock_status]
	var names := ["CANYON", "SPACE BASE", "TRANSPORT DOCK"]

	for i in range(cards.size()):
		var card : Button = cards[i]
		if card == null:
			continue
		var is_sel : bool = (i == selected_sandbox_map)
		if bars[i] != null:
			bars[i].visible = is_sel
		if statuses[i] != null:
			statuses[i].text = "◈ SELECTED ◈" if is_sel else ""

		var target_alpha : float = 1.0 if is_sel else 0.55
		var target_scale : Vector2 = Vector2(1.025, 1.025) if is_sel else Vector2.ONE

		if animated:
			var tw : Tween = create_tween().set_parallel(true)
			tw.tween_property(card, "modulate:a", target_alpha, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(card, "scale", target_scale, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		else:
			card.modulate.a = target_alpha
			card.scale = target_scale

	if map_proceed_button != null:
		var cur_name : String = names[selected_sandbox_map] if selected_sandbox_map < names.size() else "SECTOR"
		map_proceed_button.text = "▶  CONFIRM %s & SELECT OPERATIVE" % cur_name

func _update_map_buttons_ui() -> void:
	if map_button_1 == null or map_button_2 == null or map_button_3 == null:
		return
	var buttons := [map_button_1, map_button_2, map_button_3]
	var names := ["01 // CANYON", "02 // SPACE BASE", "03 // DOCK"]
	var descs := [
		"SECTOR 01: DESOLATE CANYON  •  RAW NATURAL TERRAIN & ROCKS",
		"SECTOR 02: SPACE BASE  •  COLONY HABITATION & SOLAR RIDGE",
		"SECTOR 03: TRANSPORT DOCK  •  SHUTTLE RUNWAYS & MINING QUARRY"
	]
	for i in range(buttons.size()):
		var btn : Button = buttons[i]
		var is_sel : bool = (i == selected_sandbox_map)
		btn.text = ("◈ " if is_sel else "") + names[i]
		if is_sel:
			btn.modulate = Color(1.0, 0.82, 0.28, 1.0)
		else:
			btn.modulate = Color(1.0, 1.0, 1.0, 0.55)
	if map_desc_label != null:
		map_desc_label.text = descs[selected_sandbox_map]

func _on_launch_pressed() -> void:
	if _is_transitioning:
		return
	_play_sound("click")
	if selected_mode == GameMode.SANDBOX:
		_transition_to_map_select()
	else:
		_transition_to_character_select()

func _on_map_proceed_pressed() -> void:
	if _is_transitioning:
		return
	_play_sound("click")
	_transition_from_map_select_to_character_select()

# -----------------------------------------------------------------------------
# Character Selection Phase
# -----------------------------------------------------------------------------

func _select_operative(class_id: int) -> void:
	var char_data : Node = get_node_or_null("/root/CharacterData")
	if char_data != null and char_data.has_method("select_class"):
		char_data.call("select_class", class_id)
	_play_sound("click")
	_update_character_selection_ui(true)

func _update_character_selection_ui(animated: bool) -> void:
	var char_data : Node = get_node_or_null("/root/CharacterData")
	var cur_class : int = int(char_data.get("current_class")) if char_data != null else 0

	var cards := [astronaut_card, engineer_card, medic_card, explorer_card]
	var bars := [astronaut_bar, engineer_bar, medic_bar, explorer_bar]
	var statuses := [astronaut_status, engineer_status, medic_status, explorer_status]
	var titles := ["ASTRONAUT", "ENGINEER", "MEDIC", "EXPLORER"]
	var colors := [
		Color(0.2, 0.75, 1.0),
		Color(1.0, 0.55, 0.1),
		Color(0.1, 0.9, 0.55),
		Color(0.95, 0.78, 0.25)
	]

	for i in range(cards.size()):
		var card : Button = cards[i]
		if card == null:
			continue
		var is_sel : bool = (i == cur_class)
		if bars[i] != null:
			bars[i].visible = is_sel
		if statuses[i] != null:
			statuses[i].text = "◈ SELECTED ◈" if is_sel else ""

		var target_alpha : float = 1.0 if is_sel else 0.55
		var target_scale : Vector2 = Vector2(1.025, 1.025) if is_sel else Vector2.ONE

		if animated:
			var tw : Tween = create_tween().set_parallel(true)
			tw.tween_property(card, "modulate:a", target_alpha, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(card, "scale", target_scale, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		else:
			card.modulate.a = target_alpha
			card.scale = target_scale

	if main_deploy_button != null:
		var cur_name : String = titles[cur_class] if cur_class < titles.size() else "OPERATIVE"
		main_deploy_button.text = "▶  DEPLOY AS %s  •  LAUNCH MISSION" % cur_name
		var active_col : Color = colors[cur_class] if cur_class < colors.size() else Color.WHITE
		main_deploy_button.modulate = active_col

# -----------------------------------------------------------------------------
# Deployment & Game Launch
# -----------------------------------------------------------------------------

func _on_deploy_pressed() -> void:
	if _is_transitioning:
		return
	_play_sound("click")
	if selected_mode == GameMode.TUTORIAL:
		_launch_tutorial(main_deploy_button)
	elif selected_mode == GameMode.RANGE:
		_launch_range(main_deploy_button)
	elif selected_mode == GameMode.ROCKET_MAYHEM:
		var hud : Node = get_node_or_null("/root/PlayerHealthHud")
		if hud != null:
			hud.is_sandbox_mode = false
			hud.is_rocket_mayhem_mode = true
			hud.is_range_mode = false
			hud.selected_map_theme = randi() % 3
		_launch_rocket_mayhem(main_deploy_button)
	else:
		var is_sandbox : bool = (selected_mode == GameMode.SANDBOX)
		var hud : Node = get_node_or_null("/root/PlayerHealthHud")
		if hud != null:
			hud.is_sandbox_mode = is_sandbox
			hud.is_rocket_mayhem_mode = false
			hud.is_range_mode = false
			if is_sandbox:
				hud.selected_map_theme = selected_sandbox_map
			else:
				hud.selected_map_theme = randi() % 3
		_launch_game_mode(is_sandbox, main_deploy_button)

func _launch_range(trigger_button: Button) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	_disable_menu_buttons()

	var hud : Node = get_node_or_null("/root/PlayerHealthHud")
	if hud != null:
		hud.is_sandbox_mode = false
		hud.is_rocket_mayhem_mode = false
		hud.is_range_mode = true

	var click_tween : Tween = create_tween()
	if trigger_button != null:
		click_tween.tween_property(trigger_button, "scale", Vector2(0.96, 0.96), 0.08)
	click_tween.tween_property(self, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	click_tween.tween_callback(func():
		var loader : Node = get_node_or_null("/root/LoadingScreen")
		if loader != null and loader.has_method("load_scene"):
			loader.call("load_scene", RANGE_SCENE_PATH, "DEPLOYING THE RANGE", "PROTOCOL // 03", Color(0.2, 0.75, 1.0, 1.0))
		else:
			get_tree().change_scene_to_file(RANGE_SCENE_PATH)
	)

func _launch_rocket_mayhem(trigger_button: Button) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	_disable_menu_buttons()

	var click_tween : Tween = create_tween()
	if trigger_button != null:
		click_tween.tween_property(trigger_button, "scale", Vector2(0.96, 0.96), 0.08)
	click_tween.tween_property(self, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	click_tween.tween_callback(func():
		var loader : Node = get_node_or_null("/root/LoadingScreen")
		if loader != null and loader.has_method("load_scene"):
			loader.call("load_scene", GAME_SCENE_PATH, "ROCKET MAYHEM INITIATED", "PROTOCOL // 04", Color(1.0, 0.35, 0.15, 1.0))
		else:
			get_tree().change_scene_to_file(GAME_SCENE_PATH)
	)

func _launch_tutorial(trigger_button: Button) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	_disable_menu_buttons()

	var hud : Node = get_node_or_null("/root/PlayerHealthHud")
	if hud != null:
		hud.is_sandbox_mode = false

	var click_tween : Tween = create_tween()
	if trigger_button != null:
		click_tween.tween_property(trigger_button, "scale", Vector2(0.96, 0.96), 0.08)
	click_tween.tween_property(self, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	click_tween.tween_callback(func():
		var loader : Node = get_node_or_null("/root/LoadingScreen")
		if loader != null and loader.has_method("load_scene"):
			loader.call("load_scene", TUTORIAL_SCENE_PATH, "DEPLOYING PROVING GROUNDS", "PROTOCOL // 00", Color(0.2, 0.75, 1.0, 1.0))
		else:
			get_tree().change_scene_to_file(TUTORIAL_SCENE_PATH)
	)

func _launch_game_mode(is_sandbox: bool, trigger_button: Button) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	_disable_menu_buttons()

	var hud : Node = get_node_or_null("/root/PlayerHealthHud")
	if hud != null:
		hud.is_sandbox_mode = is_sandbox

	var title_text : String = "DEPLOYING SANDBOX TESTBED" if is_sandbox else "DEPLOYING SURVIVAL SECTOR"
	var proto_text : String = "PROTOCOL // 02" if is_sandbox else "PROTOCOL // 01"
	var accent_color : Color = Color(0.96, 0.68, 0.18, 1.0) if is_sandbox else Color(0.92, 0.22, 0.32, 1.0)

	var click_tween : Tween = create_tween()
	if trigger_button != null:
		click_tween.tween_property(trigger_button, "scale", Vector2(0.96, 0.96), 0.08)
	click_tween.tween_property(self, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	click_tween.tween_callback(func():
		var loader : Node = get_node_or_null("/root/LoadingScreen")
		if loader != null and loader.has_method("load_scene"):
			loader.call("load_scene", GAME_SCENE_PATH, title_text, proto_text, accent_color)
		else:
			get_tree().change_scene_to_file(GAME_SCENE_PATH)
	)

func _disable_menu_buttons() -> void:
	tutorial_card.disabled = true
	survival_card.disabled = true
	sandbox_card.disabled = true
	if range_card != null: range_card.disabled = true
	if mayhem_card != null: mayhem_card.disabled = true
	if story_card != null: story_card.disabled = true
	if coop_card != null: coop_card.disabled = true
	main_launch_button.disabled = true
	settings_button.disabled = true
	controls_button.disabled = true
	quit_button.disabled = true
	if astronaut_card != null: astronaut_card.disabled = true
	if engineer_card != null: engineer_card.disabled = true
	if medic_card != null: medic_card.disabled = true
	if explorer_card != null: explorer_card.disabled = true
	if main_deploy_button != null: main_deploy_button.disabled = true
	if return_mode_button != null: return_mode_button.disabled = true
	if char_settings_button != null: char_settings_button.disabled = true
	if char_controls_button != null: char_controls_button.disabled = true
	if char_quit_button != null: char_quit_button.disabled = true
	if canyon_card != null: canyon_card.disabled = true
	if base_card != null: base_card.disabled = true
	if dock_card != null: dock_card.disabled = true
	if map_proceed_button != null: map_proceed_button.disabled = true
	if map_return_button != null: map_return_button.disabled = true
	if map_settings_button != null: map_settings_button.disabled = true
	if map_controls_button != null: map_controls_button.disabled = true
	if map_quit_button != null: map_quit_button.disabled = true

# -----------------------------------------------------------------------------
# Teaser Modal
# -----------------------------------------------------------------------------

func _open_teaser_modal(header: String, title: String, description: String) -> void:
	if teaser_modal == null:
		return
	if teaser_header != null: teaser_header.text = header
	if teaser_title != null: teaser_title.text = title
	if teaser_desc != null: teaser_desc.text = description

	teaser_modal.visible = true
	teaser_modal.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(teaser_modal, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _close_teaser_modal() -> void:
	if teaser_modal == null:
		return
	teaser_modal.visible = false
	teaser_modal.modulate.a = 0.0

# -----------------------------------------------------------------------------
# Dedicated Full-Screen Settings Page Navigation
# -----------------------------------------------------------------------------

func _open_settings(category: String) -> void:
	if is_instance_valid(settings_menu) and settings_menu.has_method("open"):
		settings_menu.open(category)

func _on_settings_closed() -> void:
	pass

func _on_quit_pressed() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	get_tree().quit()

# -----------------------------------------------------------------------------
# Visual Feedback & Hover Effects
# -----------------------------------------------------------------------------

func _setup_card_interactions(card: Button, mode: GameMode) -> void:
	card.mouse_entered.connect(func():
		_play_sound("hover")
		card.pivot_offset = Vector2(75.0, 175.0)
		var is_selected : bool = (selected_mode == mode)
		var target_scale : Vector2 = Vector2(1.045, 1.045) if is_selected else Vector2(1.015, 1.015)
		var target_alpha : float = 1.0 if is_selected else 0.82
		var tween : Tween = create_tween().set_parallel(true)
		tween.tween_property(card, "scale", target_scale, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(card, "modulate:a", target_alpha, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)
	card.mouse_exited.connect(func():
		card.pivot_offset = Vector2(75.0, 175.0)
		var is_selected : bool = (selected_mode == mode)
		var target_scale : Vector2 = Vector2(1.025, 1.025) if is_selected else Vector2.ONE
		var target_alpha : float = 1.0 if is_selected else 0.52
		var tween : Tween = create_tween().set_parallel(true)
		tween.tween_property(card, "scale", target_scale, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(card, "modulate:a", target_alpha, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)

func _setup_operative_card_interactions(card: Button, class_id: int) -> void:
	card.mouse_entered.connect(func():
		_play_sound("hover")
		card.pivot_offset = Vector2(122.5, 205.0)
		var char_data : Node = get_node_or_null("/root/CharacterData")
		var is_selected : bool = (char_data != null and int(char_data.get("current_class")) == class_id)
		var target_scale : Vector2 = Vector2(1.045, 1.045) if is_selected else Vector2(1.018, 1.018)
		var target_alpha : float = 1.0 if is_selected else 0.85
		var tween : Tween = create_tween().set_parallel(true)
		tween.tween_property(card, "scale", target_scale, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(card, "modulate:a", target_alpha, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)
	card.mouse_exited.connect(func():
		card.pivot_offset = Vector2(122.5, 205.0)
		var char_data : Node = get_node_or_null("/root/CharacterData")
		var is_selected : bool = (char_data != null and int(char_data.get("current_class")) == class_id)
		var target_scale : Vector2 = Vector2(1.025, 1.025) if is_selected else Vector2.ONE
		var target_alpha : float = 1.0 if is_selected else 0.55
		var tween : Tween = create_tween().set_parallel(true)
		tween.tween_property(card, "scale", target_scale, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(card, "modulate:a", target_alpha, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)

## Recursively sets mouse_filter to IGNORE on all non-button child controls
## so clicks anywhere inside the card boundary land directly on the parent Button with zero dead zones.
func _make_card_click_transparent(node: Node) -> void:
	for child in node.get_children():
		if child is Control and not (child is Button):
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
			_make_card_click_transparent(child)

func _setup_locked_card_interactions(card: Button) -> void:
	card.modulate.a = 0.45
	card.mouse_entered.connect(func():
		_play_sound("hover")
		card.pivot_offset = Vector2(75.0, 175.0)
		var tween : Tween = create_tween().set_parallel(true)
		tween.tween_property(card, "scale", Vector2(1.02, 1.02), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(card, "modulate:a", 0.75, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)
	card.mouse_exited.connect(func():
		card.pivot_offset = Vector2(75.0, 175.0)
		var tween : Tween = create_tween().set_parallel(true)
		tween.tween_property(card, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(card, "modulate:a", 0.45, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)

func _setup_icon_hover(button: Button) -> void:
	button.pivot_offset = button.size / 2.0
	button.modulate.a = 0.75
	button.mouse_entered.connect(func():
		_play_sound("hover")
		button.pivot_offset = button.size / 2.0
		var tween : Tween = create_tween().set_parallel(true)
		tween.tween_property(button, "scale", Vector2(1.15, 1.15), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(button, "modulate:a", 1.0, 0.12)
	)
	button.mouse_exited.connect(func():
		var tween : Tween = create_tween().set_parallel(true)
		tween.tween_property(button, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(button, "modulate:a", 0.75, 0.12)
	)

func _setup_quit_hover() -> void:
	quit_button.pivot_offset = quit_button.size / 2.0
	quit_button.modulate.a = 0.75
	quit_button.mouse_entered.connect(func():
		_play_sound("hover")
		quit_button.pivot_offset = quit_button.size / 2.0
		if is_instance_valid(power_icon) and power_icon.has_method("set_color"):
			power_icon.set_color(Color(1.0, 1.0, 1.0, 1.0))
		var tween : Tween = create_tween().set_parallel(true)
		tween.tween_property(quit_button, "scale", Vector2(1.15, 1.15), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(quit_button, "modulate:a", 1.0, 0.12)
	)
	quit_button.mouse_exited.connect(func():
		if is_instance_valid(power_icon) and power_icon.has_method("set_color"):
			power_icon.set_color(Color(1.0, 1.0, 1.0, 0.75))
		var tween : Tween = create_tween().set_parallel(true)
		tween.tween_property(quit_button, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(quit_button, "modulate:a", 0.75, 0.12)
	)

func _setup_char_quit_hover() -> void:
	char_quit_button.pivot_offset = char_quit_button.size / 2.0
	char_quit_button.modulate.a = 0.75
	char_quit_button.mouse_entered.connect(func():
		_play_sound("hover")
		char_quit_button.pivot_offset = char_quit_button.size / 2.0
		if is_instance_valid(char_power_icon) and char_power_icon.has_method("set_color"):
			char_power_icon.set_color(Color(1.0, 1.0, 1.0, 1.0))
		var tween : Tween = create_tween().set_parallel(true)
		tween.tween_property(char_quit_button, "scale", Vector2(1.15, 1.15), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(char_quit_button, "modulate:a", 1.0, 0.12)
	)
	char_quit_button.mouse_exited.connect(func():
		if is_instance_valid(char_power_icon) and char_power_icon.has_method("set_color"):
			char_power_icon.set_color(Color(1.0, 1.0, 1.0, 0.75))
		var tween : Tween = create_tween().set_parallel(true)
		tween.tween_property(char_quit_button, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(char_quit_button, "modulate:a", 0.75, 0.12)
	)

func _setup_button_hover(button: Button) -> void:
	button.mouse_entered.connect(func():
		_play_sound("hover")
		button.pivot_offset = button.size / 2.0
		var tween : Tween = create_tween()
		tween.tween_property(button, "scale", Vector2(1.03, 1.03), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
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
		"tab":
			snd.call("play_tab")
		"toggle":
			if param is bool: snd.call("play_toggle", param)
			else: snd.call("play_toggle")
		"slide":
			snd.call("play_slide")

func _setup_map_card_interactions(card: Button, map_idx: int) -> void:
	card.mouse_entered.connect(func():
		_play_sound("hover")
		card.pivot_offset = Vector2(142.5, 205.0)
		var is_selected : bool = (selected_sandbox_map == map_idx)
		var target_scale : Vector2 = Vector2(1.045, 1.045) if is_selected else Vector2(1.018, 1.018)
		var target_alpha : float = 1.0 if is_selected else 0.85
		var tween : Tween = create_tween().set_parallel(true)
		tween.tween_property(card, "scale", target_scale, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(card, "modulate:a", target_alpha, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)
	card.mouse_exited.connect(func():
		card.pivot_offset = Vector2(142.5, 205.0)
		var is_selected : bool = (selected_sandbox_map == map_idx)
		var target_scale : Vector2 = Vector2(1.025, 1.025) if is_selected else Vector2.ONE
		var target_alpha : float = 1.0 if is_selected else 0.55
		var tween : Tween = create_tween().set_parallel(true)
		tween.tween_property(card, "scale", target_scale, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(card, "modulate:a", target_alpha, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)

func _setup_map_quit_hover() -> void:
	if map_quit_button == null:
		return
	map_quit_button.pivot_offset = map_quit_button.size / 2.0
	map_quit_button.modulate.a = 0.75
	map_quit_button.mouse_entered.connect(func():
		_play_sound("hover")
		map_quit_button.pivot_offset = map_quit_button.size / 2.0
		if is_instance_valid(map_power_icon) and map_power_icon.has_method("set_color"):
			map_power_icon.set_color(Color(1.0, 1.0, 1.0, 1.0))
		var tween : Tween = create_tween().set_parallel(true)
		tween.tween_property(map_quit_button, "scale", Vector2(1.15, 1.15), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(map_quit_button, "modulate:a", 1.0, 0.12)
	)
	map_quit_button.mouse_exited.connect(func():
		if is_instance_valid(map_power_icon) and map_power_icon.has_method("set_color"):
			map_power_icon.set_color(Color(1.0, 1.0, 1.0, 0.75))
		var tween : Tween = create_tween().set_parallel(true)
		tween.tween_property(map_quit_button, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(map_quit_button, "modulate:a", 0.75, 0.12)
	)

func _setup_operative_banners() -> void:
	_model_pivots.clear()
	var card_nodes : Array[Button] = [astronaut_card, engineer_card, medic_card, explorer_card]
	var class_ids : Array[int] = [0, 1, 2, 3]
	var accent_colors : Array[Color] = [
		Color(0.2, 0.75, 1.0),
		Color(1.0, 0.55, 0.1),
		Color(0.1, 0.9, 0.55),
		Color(0.95, 0.78, 0.25)
	]

	for i in range(card_nodes.size()):
		var card : Button = card_nodes[i]
		if card == null:
			continue
		var class_id : int = class_ids[i]
		var pivot : Node3D = card.find_child("ModelPivot", true, false) as Node3D
		if pivot == null:
			var banner_cont := SubViewportContainer.new()
			banner_cont.name = "BannerContainer"
			banner_cont.layout_mode = 1
			banner_cont.set_anchors_preset(Control.PRESET_TOP_WIDE)
			banner_cont.offset_bottom = 120.0
			banner_cont.mouse_filter = Control.MOUSE_FILTER_IGNORE
			banner_cont.stretch = true
			card.add_child(banner_cont)
			card.move_child(banner_cont, 1)

			var vp := SubViewport.new()
			vp.name = "SubViewport"
			vp.size = Vector2i(245, 120)
			vp.transparent_bg = true
			vp.own_world_3d = true
			vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			banner_cont.add_child(vp)

			var cam := Camera3D.new()
			cam.name = "Camera3D"
			cam.position = Vector3(0.0, 0.38, 0.70)
			cam.rotation_degrees = Vector3(-6.0, 0.0, 0.0)
			cam.fov = 40.0
			vp.add_child(cam)

			var kl := DirectionalLight3D.new()
			kl.name = "KeyLight"
			kl.rotation_degrees = Vector3(-25.0, 35.0, 0.0)
			kl.light_color = Color(1.0, 0.96, 0.92)
			kl.light_energy = 1.2
			vp.add_child(kl)

			var rl := DirectionalLight3D.new()
			rl.name = "RimLight"
			rl.rotation_degrees = Vector3(20.0, -145.0, 0.0)
			rl.light_color = accent_colors[i]
			rl.light_energy = 1.6
			vp.add_child(rl)

			pivot = Node3D.new()
			pivot.name = "ModelPivot"
			pivot.rotation_degrees.y = -12.0
			vp.add_child(pivot)

		if pivot != null:
			pivot.rotation_degrees.y = -12.0
			if pivot.get_child_count() == 0:
				var model : Node3D = CharacterVisuals.create_styled_character_model(class_id)
				if model != null:
					pivot.add_child(model)
			_model_pivots.append(pivot)
