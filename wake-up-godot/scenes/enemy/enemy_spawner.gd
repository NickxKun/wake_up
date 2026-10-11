extends Marker3D

## Spawns an enemy at its own position and respawns it after it dies.

@export var enemy_scene : PackedScene
## Seconds between the enemy dying and the new one spawning.
@export var respawn_delay : float = 2.0
## Bullet damage of the first spawned enemy; each later enemy deals 1 more.
@export var first_enemy_damage : int = 2

var _spawn_count : int = 0

func _ready() -> void:
	_spawn.call_deferred()

func _spawn() -> void:
	var enemy : CharacterBody3D = enemy_scene.instantiate()
	enemy.bullet_damage = first_enemy_damage + _spawn_count
	_spawn_count += 1
	get_parent().add_child(enemy)
	enemy.global_transform = global_transform
	enemy.health_component.health_depleted.connect(_on_enemy_died)

func _on_enemy_died() -> void:
	get_tree().create_timer(respawn_delay).timeout.connect(_spawn)
