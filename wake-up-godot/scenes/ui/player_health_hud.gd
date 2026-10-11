extends Node

## Autoload that attaches a HealthComponent to the player and shows the health UI.

const HEALTH_BAR_SCENE : PackedScene = preload("res://scenes/ui/health_bar.tscn")
const HEALTH_DEBUG_SCENE : PackedScene = preload("res://scenes/debug/health_debug.tscn")
const PLAYER_NAME : String = "ProtoController"

## The health component attached to the player, null until setup succeeds.
var health_component : HealthComponent

var _is_setup : bool = false

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
	var health_bar : CanvasLayer = HEALTH_BAR_SCENE.instantiate()
	health_bar.health_component = health_component
	add_child(health_bar)
	if OS.is_debug_build():
		var health_debug : CanvasLayer = HEALTH_DEBUG_SCENE.instantiate()
		health_debug.health_component = health_component
		add_child(health_debug)
