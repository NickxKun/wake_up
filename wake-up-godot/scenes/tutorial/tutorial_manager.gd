class_name TutorialManager
extends Node3D

## Coordinates the guided tutorial gamemode progression.
## Manages 5 distinct training phases:
##   Phase 1: Basic Locomotion & Jumping
##   Phase 2: Thrusters & Pressurized Air Flight
##   Phase 3: Weapons, Alt-Fire & Target Practice
##   Phase 4: Rover Vehicle Operations
##   Phase 5: Combat Trial & Final Extraction

enum Phase {
	NONE,
	PHASE_1_LOCOMOTION,
	PHASE_2_THRUSTERS,
	PHASE_3_WEAPONS,
	PHASE_4_VEHICLE,
	PHASE_5_COMBAT,
	COMPLETED
}

const ENEMY_SCENE : PackedScene = preload("res://scenes/enemy/enemy.tscn")
const MAIN_MENU_SCENE_PATH : String = "res://scenes/ui/main_menu.tscn"
const GAME_SCENE_PATH : String = "res://scenes/main.tscn"

@export var player_path : NodePath
@export var rover_path : NodePath
@export var hud_path : NodePath

var current_phase : Phase = Phase.NONE
var _elapsed_time : float = 0.0
var _targets_destroyed_count : int = 0
var _enemies_cleared_count : int = 0

# Player references
var _player : CharacterBody3D
var _player_combat : Node
var _rover : CharacterBody3D
var _hud : TutorialHud

# Phase tracking flags
var _moved_distance : float = 0.0
var _last_pos : Vector3 = Vector3.ZERO
var _has_sprinted : bool = false
var _has_jumped : bool = false
var _has_dashed : bool = false
var _has_hovered : bool = false
var _has_switched_weapon : bool = false
var _has_boarded_rover : bool = false
var _passed_slalom_1 : bool = false
var _passed_slalom_2 : bool = false
var _has_exited_rover : bool = false

# Waypoints
@onready var wp_locomotion : TutorialWaypoint = $"../Waypoints/Waypoint_Locomotion"
@onready var wp_thrusters : TutorialWaypoint = $"../Waypoints/Waypoint_Thrusters"
@onready var wp_weapons : TutorialWaypoint = $"../Waypoints/Waypoint_Weapons"
@onready var wp_rover_bay : TutorialWaypoint = $"../Waypoints/Waypoint_RoverBay"
@onready var wp_slalom_1 : TutorialWaypoint = $"../Waypoints/Waypoint_Slalom1"
@onready var wp_slalom_2 : TutorialWaypoint = $"../Waypoints/Waypoint_Slalom2"
@onready var wp_rover_park : TutorialWaypoint = $"../Waypoints/Waypoint_RoverPark"
@onready var wp_combat_arena : TutorialWaypoint = $"../Waypoints/Waypoint_CombatArena"
@onready var wp_extraction : TutorialWaypoint = $"../Waypoints/Waypoint_Extraction"

# Targets & Enemies
@onready var targets_container : Node3D = $"../Targets"
@onready var enemies_container : Node3D = $"../CombatEnemies"

func _ready() -> void:
	# Ensure HUD autoload doesn't hijack tutorial mode
	var main_hud : Node = get_node_or_null("/root/PlayerHealthHud")
	if main_hud != null:
		main_hud.set("is_sandbox_mode", false)

	# Start in-game tactical music for the proving grounds
	var snd : Node = get_node_or_null("/root/UiSound")
	if snd != null and snd.has_method("play_music"):
		snd.play_music("game")

	_player = get_node_or_null(player_path) as CharacterBody3D
	_rover = get_node_or_null(rover_path) as CharacterBody3D
	_hud = get_node_or_null(hud_path) as TutorialHud
	if _hud == null:
		_hud = get_node_or_null("../../../TutorialHud") as TutorialHud
	if _hud == null and is_inside_tree():
		_hud = get_tree().root.find_child("TutorialHud", true, false) as TutorialHud

	if _player != null:
		_last_pos = _player.global_position
		_player_combat = _player.get_node_or_null("PlayerCombat")
		if _player_combat != null:
			if _player_combat.has_signal("weapon_switched"):
				_player_combat.connect("weapon_switched", func(_idx): _on_weapon_switched())

	if _rover != null:
		if _rover.has_signal("boarded"):
			_rover.connect("boarded", func(_driver): _on_rover_boarded())
		if _rover.has_signal("dismounted"):
			_rover.connect("dismounted", func(_driver): _on_rover_dismounted())

	# Connect HUD button signals
	if _hud != null:
		_hud.replay_requested.connect(_on_replay_requested)
		_hud.menu_requested.connect(_on_menu_requested)
		_hud.proceed_to_game_requested.connect(_on_proceed_to_game_requested)

	# Connect waypoints
	_connect_waypoint(wp_locomotion, _on_locomotion_wp_reached)
	_connect_waypoint(wp_thrusters, _on_thrusters_wp_reached)
	_connect_waypoint(wp_weapons, _on_weapons_wp_reached)
	_connect_waypoint(wp_rover_bay, _on_rover_bay_wp_reached)
	_connect_waypoint(wp_slalom_1, _on_slalom_1_wp_reached)
	_connect_waypoint(wp_slalom_2, _on_slalom_2_wp_reached)
	_connect_waypoint(wp_rover_park, _on_rover_park_wp_reached)
	_connect_waypoint(wp_combat_arena, _on_combat_arena_wp_reached)
	_connect_waypoint(wp_extraction, _on_extraction_wp_reached)

	# Connect target dummies
	if targets_container != null:
		for child in targets_container.get_children():
			if child is TrainingTarget:
				child.target_destroyed.connect(_on_target_destroyed)

	# Deactivate all waypoints initially
	_deactivate_all_waypoints()

	# Start Phase 1
	call_deferred("_start_phase_1")

func _connect_waypoint(wp: TutorialWaypoint, callback: Callable) -> void:
	if wp != null:
		wp.reached.connect(func(_id): callback.call())

func _deactivate_all_waypoints() -> void:
	for wp in [wp_locomotion, wp_thrusters, wp_weapons, wp_rover_bay, wp_slalom_1, wp_slalom_2, wp_rover_park, wp_combat_arena, wp_extraction]:
		if wp != null:
			wp.deactivate()

func _process(delta: float) -> void:
	if current_phase == Phase.COMPLETED or current_phase == Phase.NONE:
		return
	_elapsed_time += delta

	match current_phase:
		Phase.PHASE_1_LOCOMOTION:
			_process_phase_1()
		Phase.PHASE_2_THRUSTERS:
			_process_phase_2()
		Phase.PHASE_3_WEAPONS:
			_process_phase_3()
		Phase.PHASE_4_VEHICLE:
			_process_phase_4()
		Phase.PHASE_5_COMBAT:
			_process_phase_5()

# -----------------------------------------------------------------------------
# Phase 1: Basic Locomotion & Jumping
# -----------------------------------------------------------------------------

func _start_phase_1() -> void:
	current_phase = Phase.PHASE_1_LOCOMOTION
	if wp_locomotion != null:
		wp_locomotion.activate()
	if _hud != null:
		_hud.track_waypoint(_player, wp_locomotion)
		_hud.set_objective(
			"CADET TRAINING // PHASE 1 OF 5",
			"LOCOMOTION & JUMPING",
			"Move with [W, A, S, D], hold [Shift] to Sprint, and press [Space] to vault over the training barrier.",
			[
				{"text": "Walk using [W, A, S, D]", "completed": false},
				{"text": "Sprint with [Shift]", "completed": false},
				{"text": "Vault over low barrier with [Space]", "completed": false},
				{"text": "Reach Checkpoint 1", "completed": false}
			]
		)

func _process_phase_1() -> void:
	if _player == null:
		return

	# Track walking distance
	var p_pos := _player.global_position
	var dist : float = Vector2(p_pos.x - _last_pos.x, p_pos.z - _last_pos.z).length()
	_moved_distance += dist
	_last_pos = p_pos

	if _moved_distance > 5.0 and _hud != null:
		_hud.update_task(0, true)

	# Check sprint
	if Input.is_action_pressed("sprint") or Input.is_key_pressed(KEY_SHIFT):
		if not _has_sprinted:
			_has_sprinted = true
			if _hud != null:
				_hud.update_task(1, true)

	# Check jump
	if not _player.is_on_floor() and _player.velocity.y > 1.0:
		if not _has_jumped:
			_has_jumped = true
			if _hud != null:
				_hud.update_task(2, true)

func _on_locomotion_wp_reached() -> void:
	if current_phase != Phase.PHASE_1_LOCOMOTION:
		return
	if _hud != null:
		_hud.update_task(0, true)
		_hud.update_task(1, true)
		_hud.update_task(2, true)
		_hud.update_task(3, true)
	wp_locomotion.deactivate()
	call_deferred("_start_phase_2")

# -----------------------------------------------------------------------------
# Phase 2: Thrusters & Flight
# -----------------------------------------------------------------------------

func _start_phase_2() -> void:
	current_phase = Phase.PHASE_2_THRUSTERS
	if wp_thrusters != null:
		wp_thrusters.activate()
	if _hud != null:
		_hud.track_waypoint(_player, wp_thrusters)
		_hud.set_objective(
			"CADET TRAINING // PHASE 2 OF 5",
			"THRUSTERS & FLIGHT",
			"Perform a high-speed Dash with [Shift + Movement]. Hold [Space] mid-air to engage pressurized thrusters and hover up to the platform.",
			[
				{"text": "Execute directional Dash [Shift + Movement]", "completed": false},
				{"text": "Hover with pressurized thrusters [Hold Space]", "completed": false},
				{"text": "Reach Upper Platform Checkpoint", "completed": false}
			]
		)

func _process_phase_2() -> void:
	if _player == null:
		return

	# Check if player is dashing
	if _player.get("is_dashing") == true and not _has_dashed:
		_has_dashed = true
		if _hud != null:
			_hud.update_task(0, true)

	# Check if player is hovering / flying with pressurized air
	if _player.get("is_flying") == true and not _has_hovered:
		_has_hovered = true
		if _hud != null:
			_hud.update_task(1, true)

func _on_thrusters_wp_reached() -> void:
	if current_phase != Phase.PHASE_2_THRUSTERS:
		return
	if _hud != null:
		_hud.update_task(0, true)
		_hud.update_task(1, true)
		_hud.update_task(2, true)
	wp_thrusters.deactivate()
	call_deferred("_start_phase_3")

# -----------------------------------------------------------------------------
# Phase 3: Weapons, Alt-Fire & Marksmanship
# -----------------------------------------------------------------------------

func _start_phase_3() -> void:
	current_phase = Phase.PHASE_3_WEAPONS
	if wp_weapons != null:
		wp_weapons.activate()
	if _hud != null:
		_hud.track_waypoint(_player, wp_weapons)
		_hud.set_objective(
			"CADET TRAINING // PHASE 3 OF 5",
			"WEAPONS & MARKSMANSHIP",
			"Switch weapons with [1, 2, Q]. Fire your weapon with [Left Click] and Alt-Fire with [Right Click] to neutralize the 3 target dummies.",
			[
				{"text": "Switch Weapon [1, 2, Q]", "completed": false},
				{"text": "Neutralize Target Dummies (0/3)", "completed": false},
				{"text": "Advance to Firing Range Depot", "completed": false}
			]
		)

func _process_phase_3() -> void:
	if Input.is_key_pressed(KEY_1) or Input.is_key_pressed(KEY_2) or Input.is_key_pressed(KEY_Q):
		_on_weapon_switched()

func _on_weapon_switched() -> void:
	if current_phase == Phase.PHASE_3_WEAPONS and not _has_switched_weapon:
		_has_switched_weapon = true
		if _hud != null:
			_hud.update_task(0, true)

func _on_target_destroyed(_tgt: TrainingTarget) -> void:
	if current_phase != Phase.PHASE_3_WEAPONS:
		return
	_targets_destroyed_count += 1
	if _hud != null:
		_hud.update_task(1, _targets_destroyed_count >= 3, "Neutralize Target Dummies (%d/3)" % min(_targets_destroyed_count, 3))
	if _targets_destroyed_count >= 3:
		if wp_weapons != null:
			wp_weapons.activate()

func _on_weapons_wp_reached() -> void:
	if current_phase != Phase.PHASE_3_WEAPONS:
		return
	if _targets_destroyed_count < 3:
		return # Require targets to be destroyed first
	if _hud != null:
		_hud.update_task(2, true)
	wp_weapons.deactivate()
	call_deferred("_start_phase_4")

# -----------------------------------------------------------------------------
# Phase 4: Vehicle Operations (Rover)
# -----------------------------------------------------------------------------

func _start_phase_4() -> void:
	current_phase = Phase.PHASE_4_VEHICLE
	if wp_rover_bay != null:
		wp_rover_bay.activate()
	if _hud != null:
		_hud.track_waypoint(_player, wp_rover_bay)
		_hud.set_objective(
			"CADET TRAINING // PHASE 4 OF 5",
			"VEHICLE OPERATIONS",
			"Board the Space Rover with [E]. Drive through the slalom course [WASD, Shift Boost, Space Handbrake] and park at the terminal.",
			[
				{"text": "Board the Space Rover [E]", "completed": false},
				{"text": "Navigate Slalom Waypoint 1", "completed": false},
				{"text": "Navigate Slalom Waypoint 2", "completed": false},
				{"text": "Park at Terminal & Dismount [E]", "completed": false}
			]
		)

func _process_phase_4() -> void:
	pass

func _on_rover_bay_wp_reached() -> void:
	# Reached vehicle area
	pass

func _on_rover_boarded() -> void:
	if current_phase == Phase.PHASE_4_VEHICLE and not _has_boarded_rover:
		_has_boarded_rover = true
		if wp_rover_bay != null:
			wp_rover_bay.deactivate()
		if wp_slalom_1 != null:
			wp_slalom_1.activate()
		if _hud != null:
			_hud.update_task(0, true)
			_hud.track_waypoint(_rover, wp_slalom_1)

func _on_slalom_1_wp_reached() -> void:
	if current_phase == Phase.PHASE_4_VEHICLE and not _passed_slalom_1:
		_passed_slalom_1 = true
		if wp_slalom_1 != null:
			wp_slalom_1.deactivate()
		if wp_slalom_2 != null:
			wp_slalom_2.activate()
		if _hud != null:
			_hud.update_task(1, true)
			_hud.track_waypoint(_rover, wp_slalom_2)

func _on_slalom_2_wp_reached() -> void:
	if current_phase == Phase.PHASE_4_VEHICLE and not _passed_slalom_2:
		_passed_slalom_2 = true
		if wp_slalom_2 != null:
			wp_slalom_2.deactivate()
		if wp_rover_park != null:
			wp_rover_park.activate()
		if _hud != null:
			_hud.update_task(2, true)
			_hud.track_waypoint(_rover, wp_rover_park)

func _on_rover_park_wp_reached() -> void:
	# Inside parking bay
	pass

func _on_rover_dismounted() -> void:
	if current_phase == Phase.PHASE_4_VEHICLE and _passed_slalom_2:
		_has_exited_rover = true
		if wp_rover_park != null:
			wp_rover_park.deactivate()
		if _hud != null:
			_hud.update_task(3, true)
		call_deferred("_start_phase_5")

# -----------------------------------------------------------------------------
# Phase 5: Combat Arena & Final Extraction
# -----------------------------------------------------------------------------

func _start_phase_5() -> void:
	current_phase = Phase.PHASE_5_COMBAT
	if wp_combat_arena != null:
		wp_combat_arena.activate()
	if _hud != null:
		_hud.track_waypoint(_player, wp_combat_arena)
		_hud.set_objective(
			"CADET TRAINING // PHASE 5 OF 5",
			"COMBAT ARENA & EXTRACTION",
			"Enter the combat simulation arena, neutralize the training hostiles using cover and alt-fire, then reach the extraction beacon.",
			[
				{"text": "Enter Combat Arena", "completed": false},
				{"text": "Neutralize Training Hostiles (0/3)", "completed": false},
				{"text": "Proceed to Extraction Beacon", "completed": false}
			]
		)

func _on_combat_arena_wp_reached() -> void:
	if current_phase != Phase.PHASE_5_COMBAT:
		return
	if wp_combat_arena != null:
		wp_combat_arena.deactivate()
	if _hud != null:
		_hud.update_task(0, true)

	_spawn_combat_enemies()

func _spawn_combat_enemies() -> void:
	if enemies_container == null:
		return
	# Spawn 3 training hostiles at marked locations
	for marker in enemies_container.get_children():
		if marker is Marker3D:
			var enemy : CharacterBody3D = ENEMY_SCENE.instantiate() as CharacterBody3D
			enemies_container.add_child(enemy)
			enemy.global_position = marker.global_position
			enemy.set("move_speed", 2.2) # Friendly tutorial pace
			var hc : HealthComponent = enemy.get_node_or_null("HealthComponent") as HealthComponent
			if hc != null:
				hc.health = 50
				hc.health_depleted.connect(_on_enemy_neutralized)

func _on_enemy_neutralized() -> void:
	if current_phase != Phase.PHASE_5_COMBAT:
		return
	_enemies_cleared_count += 1
	if _hud != null:
		_hud.update_task(1, _enemies_cleared_count >= 3, "Neutralize Training Hostiles (%d/3)" % min(_enemies_cleared_count, 3))
	if _enemies_cleared_count >= 3:
		if wp_extraction != null:
			wp_extraction.activate()
		if _hud != null:
			_hud.track_waypoint(_player, wp_extraction)

func _process_phase_5() -> void:
	pass

func _on_extraction_wp_reached() -> void:
	if current_phase != Phase.PHASE_5_COMBAT or _enemies_cleared_count < 3:
		return
	current_phase = Phase.COMPLETED
	if wp_extraction != null:
		wp_extraction.deactivate()
	if _hud != null:
		_hud.update_task(2, true)
		_hud.show_victory(_elapsed_time, _targets_destroyed_count, _enemies_cleared_count)

# -----------------------------------------------------------------------------
# Completion Navigation Handlers
# -----------------------------------------------------------------------------

func _on_replay_requested() -> void:
	get_tree().reload_current_scene()

func _on_menu_requested() -> void:
	var snd : Node = get_node_or_null("/root/UiSound")
	if snd != null and snd.has_method("play_music"):
		snd.play_music("menu")
	var loader : Node = get_node_or_null("/root/LoadingScreen")
	if loader != null and loader.has_method("load_scene"):
		loader.call("load_scene", MAIN_MENU_SCENE_PATH, "RETURNING TO COMMAND", "INTERFACE // 00", Color(1.0, 1.0, 1.0, 1.0))
	else:
		get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)

func _on_proceed_to_game_requested() -> void:
	var loader : Node = get_node_or_null("/root/LoadingScreen")
	if loader != null and loader.has_method("load_scene"):
		loader.call("load_scene", GAME_SCENE_PATH, "DEPLOYING SURVIVAL SECTOR", "PROTOCOL // 01", Color(0.92, 0.22, 0.32, 1.0))
	else:
		get_tree().change_scene_to_file(GAME_SCENE_PATH)
