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
	if not is_inside_tree() or enemy_scene == null:
		return
	var parent : Node = get_parent()
	if parent == null or not parent.is_inside_tree():
		return
	var enemy : Node3D = enemy_scene.instantiate() as Node3D
	if enemy != null:
		if "bullet_damage" in enemy:
			enemy.set("bullet_damage", first_enemy_damage + _spawn_count)

		var hud : Node = get_node_or_null("/root/PlayerHealthHud")
		var is_mayhem : bool = (hud != null and "is_rocket_mayhem_mode" in hud and hud.is_rocket_mayhem_mode)
		if enemy.has_method("set_weapon_type"):
			var roll : float = randf()
			if is_mayhem:
				# High chaos weapon frequency in Rocket Mayhem
				if roll < 0.35:
					enemy.call("set_weapon_type", 1) # SHOTGUN
				elif roll < 0.70:
					enemy.call("set_weapon_type", 2) # DOUBLE_PISTOLS
				else:
					enemy.call("set_weapon_type", 0) # PISTOL
			else:
				# Rare spawns in standard gameplay
				if roll < 0.10:
					enemy.call("set_weapon_type", 1) # SHOTGUN
				elif roll < 0.20:
					enemy.call("set_weapon_type", 2) # DOUBLE_PISTOLS
				else:
					enemy.call("set_weapon_type", 0) # PISTOL

		_spawn_count += 1
		parent.add_child(enemy)
		enemy.global_transform = global_transform
		var hc : HealthComponent = enemy.get_node_or_null("HealthComponent") as HealthComponent
		if hc != null:
			hc.health_depleted.connect(_on_enemy_died)

func _on_enemy_died() -> void:
	if not is_inside_tree():
		return
	var tree : SceneTree = get_tree()
	if tree != null:
		tree.create_timer(respawn_delay).timeout.connect(_spawn)
