extends Sprite3D

## Floating health bar over an enemy. Reads the parent's HealthComponent.

@onready var progress_bar : ProgressBar = $SubViewport/ProgressBar
@onready var value_label : Label = $SubViewport/HealthValue

func _ready() -> void:
	texture = $SubViewport.get_texture()
	var health_component : HealthComponent = get_parent().get_node("HealthComponent")
	progress_bar.max_value = HealthComponent.MAX_HEALTH
	_update(health_component.health)
	health_component.health_changed.connect(_on_health_changed)

func _on_health_changed(new_health : int, _old_health : int) -> void:
	_update(new_health)

func _update(health : int) -> void:
	progress_bar.value = health
	value_label.text = "%d/%d" % [health, HealthComponent.MAX_HEALTH]
