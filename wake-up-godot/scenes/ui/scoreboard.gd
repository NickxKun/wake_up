extends CanvasLayer

## Shows enemies killed and player deaths with modern kinetic feedback.

@onready var panel_container : PanelContainer = $MarginContainer/PanelContainer
@onready var kills_value : Label = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/KillsRow/KillsValue
@onready var deaths_value : Label = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/DeathsRow/DeathsValue

var _last_kills : int = -1
var _last_deaths : int = -1
var _kill_punch_tween : Tween
var _death_punch_tween : Tween

func _ready() -> void:
	update_scores(0, 0)

func update_scores(enemies_killed : int, player_deaths : int) -> void:
	if not is_node_ready():
		await ready

	if enemies_killed != _last_kills:
		var increased : bool = _last_kills != -1 and enemies_killed > _last_kills
		_last_kills = enemies_killed
		kills_value.text = str(enemies_killed)
		if increased:
			_punch_label(kills_value, Color(1.0, 0.95, 0.5), Color(0.98, 0.75, 0.22))

	if player_deaths != _last_deaths:
		var increased : bool = _last_deaths != -1 and player_deaths > _last_deaths
		_last_deaths = player_deaths
		deaths_value.text = str(player_deaths)
		if increased:
			_punch_label(deaths_value, Color(1.0, 0.7, 0.7), Color(0.95, 0.45, 0.45))

func _punch_label(label: Label, flash_color: Color, base_color: Color) -> void:
	label.pivot_offset = label.size / 2.0
	var tween : Tween = create_tween()
	label.modulate = flash_color
	label.scale = Vector2(1.35, 1.35)
	tween.set_parallel(true)
	tween.tween_property(label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate", base_color, 0.35)
