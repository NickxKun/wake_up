extends CanvasLayer

## Temporary debug UI for adjusting health. Remove before release.
## #TEST ONLY

## The health component to adjust.
@export var health_component : HealthComponent

@onready var up_button : Button = $HBoxContainer/UpButton
@onready var down_button : Button = $HBoxContainer/DownButton
@onready var reset_button : Button = $HBoxContainer/ResetButton #TEST ONLY
@onready var amount_box : SpinBox = $AmountContainer/AmountBox #TEST ONLY

func _ready() -> void:
	if health_component == null:
		push_error("HealthDebug: health_component is not assigned.")
		return
	up_button.pressed.connect(_on_up_pressed)
	down_button.pressed.connect(_on_down_pressed)
	reset_button.pressed.connect(_on_reset_pressed) #TEST ONLY
	amount_box.get_line_edit().text_submitted.connect(_on_amount_submitted) #TEST ONLY

func _on_up_pressed() -> void:
	health_component.increase_health(_get_amount()) #TEST ONLY

func _on_down_pressed() -> void:
	health_component.decrease_health(_get_amount()) #TEST ONLY

func _on_reset_pressed() -> void: #TEST ONLY
	var old_health : int = health_component.health #TEST ONLY
	if old_health == HealthComponent.MAX_HEALTH: #TEST ONLY
		return #TEST ONLY
	health_component.health = HealthComponent.MAX_HEALTH #TEST ONLY
	health_component.health_changed.emit(health_component.health, old_health) #TEST ONLY
	health_component.health_full.emit() #TEST ONLY

func _get_amount()-> int: #TEST ONLY
	var amount : int = int(amount_box.value) #TEST ONLY
	return amount if amount >= 1 else 1 #TEST ONLY

func _on_amount_submitted(_text : String) -> void: #TEST ONLY
	amount_box.get_line_edit().release_focus() #TEST ONLY
