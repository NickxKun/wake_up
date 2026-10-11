extends Node

## Autoload that attaches a HealthComponent to the player and shows the health UI.

const HEALTH_BAR_SCENE : PackedScene = preload("res://scenes/ui/health_bar.tscn")
const HEALTH_DEBUG_SCENE : PackedScene = preload("res://scenes/debug/health_debug.tscn")
const GAME_OVER_SCENE : PackedScene = preload("res://scenes/ui/game_over.tscn")
const SCOREBOARD_SCENE : PackedScene = preload("res://scenes/ui/scoreboard.tscn")
const PLAYER_NAME : String = "ProtoController"

## The health component attached to the player, null until setup succeeds.
var health_component : HealthComponent
## Enemies killed since the last (re)start.
var enemies_killed : int = 0
## Player deaths since the last (re)start.
var player_deaths : int = 0

var _is_setup : bool = false
var _game_over : CanvasLayer
var _scoreboard : CanvasLayer

func _ready() -> void:
	_setup.call_deferred()

func _setup() -> void:
	if _is_setup:
		return
	await get_tree().process_frame
	var current_scene : Node = get_tree().current_scene
	if current_scene == null:
		push_warning("PlayerHealthHud: no current scene.")
		return
	var player : Node = current_scene.find_child(PLAYER_NAME, true, false)
	if player == null:
		push_warning("PlayerHealthHud: %s not found in current scene." % PLAYER_NAME)
		return
	_is_setup = true
	health_component = HealthComponent.new()
	health_component.name = "HealthComponent"
	player.add_child(health_component)
	health_component.health_depleted.connect(_on_player_died)
	var health_bar : CanvasLayer = HEALTH_BAR_SCENE.instantiate()
	health_bar.health_component = health_component
	add_child(health_bar)
	_scoreboard = SCOREBOARD_SCENE.instantiate()
	add_child(_scoreboard)
	_update_scoreboard()
	if OS.is_debug_build():
		var health_debug : CanvasLayer = HEALTH_DEBUG_SCENE.instantiate()
		health_debug.health_component = health_component
		add_child(health_debug)

func _on_player_died() -> void:
	player_deaths += 1
	_update_scoreboard()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_game_over = GAME_OVER_SCENE.instantiate()
	_game_over.restart_requested.connect(restart)
	add_child(_game_over)

## Counts one enemy kill and refreshes the scoreboard.
func add_enemy_kill() -> void:
	enemies_killed += 1
	_update_scoreboard()

func _update_scoreboard() -> void:
	if is_instance_valid(_scoreboard):
		_scoreboard.update_scores(enemies_killed, player_deaths)

## Reloads the current scene and rebinds the UI to the new player's HealthComponent.
func restart() -> void:
	for child in get_children():
		child.queue_free()
	_game_over = null
	_scoreboard = null
	enemies_killed = 0
	player_deaths = 0
	health_component = null
	_is_setup = false
	get_tree().reload_current_scene()
	_setup.call_deferred()
