extends CanvasLayer

## Shows enemies killed and player deaths.

@onready var kills_label : Label = $MarginContainer/VBoxContainer/KillsLabel
@onready var deaths_label : Label = $MarginContainer/VBoxContainer/DeathsLabel

func update_scores(enemies_killed : int, player_deaths : int) -> void:
	kills_label.text = "Kills: %d" % enemies_killed
	deaths_label.text = "Deaths: %d" % player_deaths
