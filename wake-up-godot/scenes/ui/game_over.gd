extends CanvasLayer

## Shown when the player dies. Emits restart_requested when the Restart button is pressed.

signal restart_requested

@onready var restart_button : Button = $CenterContainer/VBoxContainer/RestartButton

func _ready() -> void:
	restart_button.pressed.connect(_on_restart_pressed)

func _on_restart_pressed() -> void:
	restart_requested.emit()
