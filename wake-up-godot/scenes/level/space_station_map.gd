class_name SpaceStationMap
extends Node3D

## Space Station & Planetary Outpost Map Manager.
## Manages 3 distinct themed maps:
##   0 = CANYON WASTELAND (Pure natural desert terrain & rocks, zero equipment)
##   1 = SPACE BASE (Colony research outpost with habitation, science labs & power grid)
##   2 = TRANSPORT DOCK (Planetary logistics terminal, shuttle pads & mining quarry)
## Features smooth outer desert lands, seamless contour slope geometry,
## height-adapted demarcation lines, and navigation meshes.

enum MapTheme {
	CANYON_WASTELAND = 0,
	SPACE_BASE = 1,
	TRANSPORT_DOCK = 2,
}

@export var map_theme : MapTheme = MapTheme.SPACE_BASE:
	set(val):
		map_theme = val
		if _is_ready:
			_update_theme_visuals()

@export var ground_size : Vector2 = Vector2(80.0, 80.0)
@export var safe_zone_half_size : float = 15.5

# Natural Desert Terrain & Rock Asset Preloads
const SCENE_ROCK_A : PackedScene = preload("res://assets/models/fbx/rock_A.fbx")
const SCENE_ROCK_B : PackedScene = preload("res://assets/models/fbx/rock_B.fbx")
const SCENE_ROCKS_A : PackedScene = preload("res://assets/models/fbx/rocks_A.fbx")
const SCENE_ROCKS_B : PackedScene = preload("res://assets/models/fbx/rocks_B.fbx")
const SCENE_TERRAIN_MINING : PackedScene = preload("res://assets/models/fbx/terrain_mining.fbx")
const SCENE_TERRAIN_SLOPE : PackedScene = preload("res://assets/models/fbx/terrain_slope.fbx")
const SCENE_TERRAIN_SLOPE_INNER : PackedScene = preload("res://assets/models/fbx/terrain_slope_inner_corner.fbx")
const SCENE_TERRAIN_SLOPE_OUTER : PackedScene = preload("res://assets/models/fbx/terrain_slope_outer_corner.fbx")
const SCENE_TERRAIN_TALL : PackedScene = preload("res://assets/models/fbx/terrain_tall.fbx")
const SCENE_TERRAIN_LOW : PackedScene = preload("res://assets/models/fbx/terrain_low.fbx")

# POI Equipment Preloads for dynamic map themes
const SCENE_DRILL : PackedScene = preload("res://assets/models/fbx/drill_structure.fbx")
const SCENE_SPACETRUCK : PackedScene = preload("res://assets/models/fbx/spacetruck.fbx")
const SCENE_SPACETRUCK_LARGE : PackedScene = preload("res://assets/models/fbx/spacetruck_large.fbx")
const SCENE_ROVER : PackedScene = preload("res://scenes/vehicles/rover.tscn")
const SCENE_WEAPONS_BOX : PackedScene = preload("res://scenes/weapons/weapons_box.tscn")
const SCENE_CARGO_PACKED : PackedScene = preload("res://assets/models/fbx/cargo_B_packed.fbx")
const SCENE_CARGO_STACKED : PackedScene = preload("res://assets/models/fbx/cargo_A_stacked.fbx")
const SCENE_CARGO_B_STACKED : PackedScene = preload("res://assets/models/fbx/cargo_B_stacked.fbx")
const SCENE_CARGODEPOT_A : PackedScene = preload("res://assets/models/fbx/cargodepot_A.fbx")
const SCENE_CONTAINERS_A : PackedScene = preload("res://assets/models/fbx/containers_A.fbx")
const SCENE_CONTAINERS_B : PackedScene = preload("res://assets/models/fbx/containers_B.fbx")
const SCENE_LIGHTS : PackedScene = preload("res://assets/models/fbx/lights.fbx")
const SCENE_SOLARPANEL : PackedScene = preload("res://assets/models/fbx/solarpanel.fbx")
const SCENE_WINDTURBINE_TALL : PackedScene = preload("res://assets/models/fbx/windturbine_tall.fbx")
const SCENE_WINDTURBINE_LOW : PackedScene = preload("res://assets/models/fbx/windturbine_low.fbx")
const SCENE_TRUCK_TRAILER : PackedScene = preload("res://assets/models/fbx/spacetruck_trailer.fbx")
const SCENE_TARGET : PackedScene = preload("res://scenes/tutorial/training_target.tscn")
const SCENE_BOSS_MECH : PackedScene = preload("res://scenes/enemy/boss_mech.tscn")

# Custom Landmark Preloads
const SCRIPT_NATURAL_ARCH : Script = preload("res://scenes/level/landmarks/natural_arch.gd")
const SCRIPT_HOODOO_PILLAR : Script = preload("res://scenes/level/landmarks/hoodoo_pillar.gd")
const SCRIPT_SATELLITE_DISH : Script = preload("res://scenes/level/landmarks/satellite_dish.gd")
const SCRIPT_PIPELINE : Script = preload("res://scenes/level/landmarks/pipeline_system.gd")
const SCRIPT_GANTRY_CRANE : Script = preload("res://scenes/level/landmarks/gantry_crane.gd")
const SCRIPT_FUEL_DEPOT : Script = preload("res://scenes/level/landmarks/fuel_depot.gd")

@export var boss_spawn_interval : float = 300.0 # 5 minutes
var _boss_spawn_timer : float = 300.0
var _boss_spawn_active : bool = false

var _ground_material : StandardMaterial3D = null
var _perimeter_material : StandardMaterial3D = null
var _stripe_material : StandardMaterial3D = null
var _laser_material : StandardMaterial3D = null
var _mist_material : StandardMaterial3D = null

# Terrain Grid Constants (21x21 tiles, 2m modular grid covering -20m to +20m)
const TERRAIN_GRID_W : int = 21
const TERRAIN_GRID_D : int = 21
const TERRAIN_TILE_SIZE : float = 2.0
const TERRAIN_ORIGIN_X : float = -20.0
const TERRAIN_ORIGIN_Z : float = -20.0

# Lookup mapping 4 corner heights (NW, NE, SW, SE) to exact FBX scene and Y-rotation
const TILE_LOOKUP := {
	Vector4i(0,0,0,0): {"scene": SCENE_TERRAIN_LOW, "rot": 0},
	Vector4i(1,1,1,1): {"scene": SCENE_TERRAIN_TALL, "rot": 0},
	# Outer corners (1 high corner, 3 low corners)
	Vector4i(0,1,0,0): {"scene": SCENE_TERRAIN_SLOPE_OUTER, "rot": 0},
	Vector4i(1,0,0,0): {"scene": SCENE_TERRAIN_SLOPE_OUTER, "rot": 90},
	Vector4i(0,0,1,0): {"scene": SCENE_TERRAIN_SLOPE_OUTER, "rot": 180},
	Vector4i(0,0,0,1): {"scene": SCENE_TERRAIN_SLOPE_OUTER, "rot": 270},
	# Inner corners (3 high corners, 1 low corner)
	Vector4i(1,1,0,1): {"scene": SCENE_TERRAIN_SLOPE_INNER, "rot": 0},
	Vector4i(1,1,1,0): {"scene": SCENE_TERRAIN_SLOPE_INNER, "rot": 90},
	Vector4i(1,0,1,1): {"scene": SCENE_TERRAIN_SLOPE_INNER, "rot": 180},
	Vector4i(0,1,1,1): {"scene": SCENE_TERRAIN_SLOPE_INNER, "rot": 270},
	# Straight slopes (2 high corners along an edge, 2 low along opposite)
	Vector4i(0,1,0,1): {"scene": SCENE_TERRAIN_SLOPE, "rot": 0},    # High East (+X)
	Vector4i(1,1,0,0): {"scene": SCENE_TERRAIN_SLOPE, "rot": 90},   # High North (-Z)
	Vector4i(1,0,1,0): {"scene": SCENE_TERRAIN_SLOPE, "rot": 180},  # High West (-X)
	Vector4i(0,0,1,1): {"scene": SCENE_TERRAIN_SLOPE, "rot": 270},  # High South (+Z)
}

var _terrain_H : Array[Array] = []
var _is_ready : bool = false

func _ready() -> void:
	add_to_group("navigation_geometry")

	# Pull active theme from global HUD singleton if available
	var hud : Node = get_node_or_null("/root/PlayerHealthHud")
	if hud != null and "selected_map_theme" in hud:
		if map_theme != MapTheme.SPACE_BASE:
			hud.selected_map_theme = int(map_theme)
		else:
			map_theme = hud.selected_map_theme as MapTheme

	_build_ground()
	_build_terrain()
	_configure_sectors_for_theme()
	_spawn_weapons_box()
	_spawn_map_targets()
	_build_demarcation_line()
	_build_outer_sectors()
	_build_outer_fog()
	_build_perimeter_boundaries()
	_apply_theme_environment_and_sky()
	_setup_prop_collisions(self)
	_snap_enemy_spawners()
	_ensure_player_spawn_safe()
	_start_boss_director()
	_is_ready = true

func _process(delta: float) -> void:
	if _boss_spawn_active:
		_boss_spawn_timer -= delta
		if _boss_spawn_timer <= 0.0:
			_boss_spawn_timer = boss_spawn_interval
			spawn_boss_mech()

## Initiates the periodic 5-minute boss director for Survival and Rocket Mayhem
func _start_boss_director() -> void:
	var hud : Node = get_node_or_null("/root/PlayerHealthHud")
	# Run in Survival or Rocket Mayhem (skip in tutorial)
	if hud != null and "is_tutorial_mode" in hud and hud.is_tutorial_mode:
		_boss_spawn_active = false
		return
	_boss_spawn_active = true
	_boss_spawn_timer = boss_spawn_interval

## Spawns the Goliath-class Titan Combat Mech boss
func spawn_boss_mech() -> Node3D:
	if SCENE_BOSS_MECH == null or not is_inside_tree():
		return null
	var tree : SceneTree = get_tree()
	if tree != null:
		var existing_bosses := tree.get_nodes_in_group("boss")
		if not existing_bosses.is_empty():
			return null

	var spawn_pos := Vector3(0.0, 0.0, 16.5)
	spawn_pos.y = get_terrain_height(spawn_pos.x, spawn_pos.z) + 0.1

	var boss : Node3D = SCENE_BOSS_MECH.instantiate() as Node3D
	if boss != null:
		add_child(boss)
		boss.global_position = spawn_pos
		if boss.has_signal("boss_defeated"):
			boss.connect("boss_defeated", Callable(self, "_on_boss_defeated"))
		_show_boss_incoming_warning()
	return boss

func _on_boss_defeated(_b: Node) -> void:
	_boss_spawn_timer = boss_spawn_interval

func _show_boss_incoming_warning() -> void:
	var snd : Node = get_node_or_null("/root/UiSound")
	if snd != null and snd.has_method("play_warning_tick"):
		snd.play_warning_tick()
	var ss : Node = get_node_or_null("/root/ScreenShake")
	if ss != null and ss.has_method("shake"):
		ss.shake(0.7)

## Returns true once all level collisions are established.
func is_geometry_ready() -> bool:
	return _is_ready

## Returns the exact ground elevation at world coordinate (x, z) using bilinear interpolation.
func get_terrain_height(x: float, z: float) -> float:
	if _terrain_H.is_empty():
		return 0.0
	var v_origin_x : float = TERRAIN_ORIGIN_X - 1.0
	var v_origin_z : float = TERRAIN_ORIGIN_Z - 1.0
	var gx : float = (x - v_origin_x) / TERRAIN_TILE_SIZE
	var gz : float = (z - v_origin_z) / TERRAIN_TILE_SIZE
	if gx < 0.0 or gx >= float(TERRAIN_GRID_W) or gz < 0.0 or gz >= float(TERRAIN_GRID_D):
		return 0.0
	var ix : int = clampi(int(floor(gx)), 0, TERRAIN_GRID_W - 1)
	var iz : int = clampi(int(floor(gz)), 0, TERRAIN_GRID_D - 1)
	var u : float = clampf(gx - float(ix), 0.0, 1.0)
	var v : float = clampf(gz - float(iz), 0.0, 1.0)
	var nw : float = float(_terrain_H[iz][ix])
	var ne : float = float(_terrain_H[iz][ix + 1])
	var sw : float = float(_terrain_H[iz + 1][ix])
	var se : float = float(_terrain_H[iz + 1][ix + 1])
	return (1.0 - u) * (1.0 - v) * nw + u * (1.0 - v) * ne + (1.0 - u) * v * sw + u * v * se

## Creates a solid, seamless ground foundation extending across the entire expanded sector.
func _build_ground() -> void:
	var ground_body := StaticBody3D.new()
	ground_body.name = "GroundBase"
	ground_body.collision_layer = 1
	ground_body.collision_mask = 1
	ground_body.add_to_group("navigation_geometry")

	var col_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(ground_size.x, 1.0, ground_size.y)
	col_shape.shape = box
	col_shape.position = Vector3(0.0, -0.5, 0.0)
	ground_body.add_child(col_shape)

	# Visual extended ground floor tailored to the active theme palette
	# Sized 260m x 260m so the floor extends far into the horizon with zero gaps
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "GroundVisual"
	mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var plane := PlaneMesh.new()
	plane.size = Vector2(260.0, 260.0)
	mesh_inst.mesh = plane

	var mat := StandardMaterial3D.new()
	_ground_material = mat
	_update_ground_material_albedo()
	mesh_inst.material_override = mat
	mesh_inst.position = Vector3(0.0, -0.01, 0.0)
	ground_body.add_child(mesh_inst)

	add_child(ground_body)

## Configures level sectors based on the selected theme, completely removing unused facilities
## so that structures sit naturally on flat foundations without clipping into elevated terrain.
func _configure_sectors_for_theme() -> void:
	var hab : Node = get_node_or_null("Sector_Habitation")
	var logist : Node = get_node_or_null("Sector_Logistics")
	var quarry : Node = get_node_or_null("Sector_MiningQuarry")
	var power : Node = get_node_or_null("Sector_PowerGrid")
	var court : Node = get_node_or_null("Sector_Courtyard")
	var checkp : Node = get_node_or_null("Sector_Checkpoint")

	match map_theme:
		MapTheme.CANYON_WASTELAND:
			# Pure natural desert canyon: zero equipment, only terrain and rocks
			_remove_nodes([hab, logist, quarry, power, checkp])
			if court != null:
				for c in court.get_children():
					if not c.name.begins_with("Cover_Rock"):
						c.queue_free()
			_spawn_wasteland_tactical_rocks()

		MapTheme.SPACE_BASE:
			# Colony research outpost: Habitation Complex, Power Grid, Excavation Dig Site, and Courtyard
			_remove_nodes([logist, quarry, checkp])
			_spawn_spacebase_pois()

		MapTheme.TRANSPORT_DOCK:
			# Freight terminal & logistics: Landing Pads, Shuttles, Haulers, Quarry, and Checkpoint
			_remove_nodes([hab, power])
			_spawn_transportdock_pois()

func _remove_nodes(nodes: Array) -> void:
	for n in nodes:
		if is_instance_valid(n):
			n.queue_free()

## Spawns dense natural rock clusters, crags, and towering boulders across Map 1 (Canyon Wasteland)
## to provide tactical cover, winding canyon passes, and dramatic alien geological vistas.
func _spawn_wasteland_tactical_rocks() -> void:
	var rocks_root : Node3D = get_node_or_null("Sector_NaturalRocks") as Node3D
	if rocks_root == null:
		rocks_root = Node3D.new()
		rocks_root.name = "Sector_NaturalRocks"
		add_child(rocks_root)

	# 1. Soaring Natural Sandstone Rock Arch Bridge (spanning central gorge at z = -2.0)
	var arch : Node3D = SCRIPT_NATURAL_ARCH.new() as Node3D
	arch.name = "NaturalSandstoneArch"
	arch.position = Vector3(0.0, 0.0, -2.0)
	rocks_root.add_child(arch)

	# 2. Towering Canyon Hoodoos (Mesa rim sentry spires matching canyon vista banner)
	var hoodoo_spires := [
		{"pos": Vector3(-13.5, 0.0, -13.5), "height": 6.2, "rot": 15.0},
		{"pos": Vector3(13.5, 0.0, -13.5), "height": 6.5, "rot": -45.0},
		{"pos": Vector3(-13.5, 0.0, 13.5), "height": 5.8, "rot": 60.0},
		{"pos": Vector3(13.5, 0.0, 13.5), "height": 6.8, "rot": -110.0},
		{"pos": Vector3(-15.0, 0.0, 0.0), "height": 5.4, "rot": 30.0},
		{"pos": Vector3(15.0, 0.0, 0.0), "height": 5.6, "rot": -75.0},
		{"pos": Vector3(-9.5, 0.0, -7.5), "height": 5.0, "rot": 40.0},
		{"pos": Vector3(9.5, 0.0, -7.5), "height": 5.2, "rot": -50.0},
	]
	for h in hoodoo_spires:
		var hoodoo : Node3D = SCRIPT_HOODOO_PILLAR.new() as Node3D
		hoodoo.set("pillar_height", h["height"])
		var gy : float = get_terrain_height(h["pos"].x, h["pos"].z)
		hoodoo.position = Vector3(h["pos"].x, gy, h["pos"].z)
		hoodoo.rotation_degrees.y = h["rot"]
		rocks_root.add_child(hoodoo)

	var extra_rock_coords := [
		# 1. Central Arroyo Arena (Mid-range tactical cover for firefights)
		{"pos": Vector3(0.0, 0.0, 0.0), "scene": SCENE_ROCKS_A, "rot": 45.0, "scale": Vector3(1.2, 1.1, 1.2)},
		{"pos": Vector3(-2.8, 0.0, -2.0), "scene": SCENE_ROCK_A, "rot": 15.0, "scale": Vector3(1.0, 1.0, 1.0)},
		{"pos": Vector3(2.8, 0.0, 2.0), "scene": SCENE_ROCK_B, "rot": -75.0, "scale": Vector3(1.1, 1.0, 1.1)},
		{"pos": Vector3(-6.5, 0.0, 3.5), "scene": SCENE_ROCK_B, "rot": 120.0, "scale": Vector3(0.9, 0.9, 0.9)},
		{"pos": Vector3(3.5, 0.0, -2.5), "scene": SCENE_ROCK_A, "rot": -45.0, "scale": Vector3(1.0, 1.0, 1.0)},
		{"pos": Vector3(-1.8, 0.0, 4.2), "scene": SCENE_ROCK_B, "rot": 85.0, "scale": Vector3(0.85, 0.85, 0.85)},
		{"pos": Vector3(1.8, 0.0, -4.2), "scene": SCENE_ROCK_A, "rot": -110.0, "scale": Vector3(0.95, 0.95, 0.95)},
		{"pos": Vector3(-5.0, 0.0, 0.0), "scene": SCENE_ROCKS_B, "rot": 30.0, "scale": Vector3(1.1, 1.2, 1.1)},
		{"pos": Vector3(5.0, 0.0, 0.0), "scene": SCENE_ROCKS_A, "rot": -60.0, "scale": Vector3(1.1, 1.1, 1.1)},

		# 2. North-West Mesa Bluff & Overhangs (Elevated rock rim)
		{"pos": Vector3(-13.5, 0.0, -13.5), "scene": SCENE_ROCKS_B, "rot": 45.0, "scale": Vector3(2.2, 2.4, 2.2)},
		{"pos": Vector3(-11.0, 0.0, -14.0), "scene": SCENE_ROCKS_A, "rot": -30.0, "scale": Vector3(1.8, 1.9, 1.8)},
		{"pos": Vector3(-14.0, 0.0, -10.5), "scene": SCENE_ROCKS_A, "rot": 90.0, "scale": Vector3(1.7, 1.8, 1.7)},
		{"pos": Vector3(-8.5, 0.0, -12.5), "scene": SCENE_ROCKS_B, "rot": 15.0, "scale": Vector3(1.3, 1.4, 1.3)},
		{"pos": Vector3(-12.5, 0.0, -7.0), "scene": SCENE_ROCK_A, "rot": -75.0, "scale": Vector3(1.2, 1.3, 1.2)},
		{"pos": Vector3(-6.5, 0.0, -10.5), "scene": SCENE_ROCK_B, "rot": 135.0, "scale": Vector3(1.1, 1.1, 1.1)},
		{"pos": Vector3(-10.0, 0.0, -6.5), "scene": SCENE_ROCK_A, "rot": 60.0, "scale": Vector3(1.0, 1.0, 1.0)},
		{"pos": Vector3(-4.5, 0.0, -13.5), "scene": SCENE_ROCK_B, "rot": -20.0, "scale": Vector3(1.0, 1.0, 1.0)},

		# 3. North Canyon Pass (Defile portal boulders)
		{"pos": Vector3(-3.5, 0.0, -9.0), "scene": SCENE_ROCKS_A, "rot": 35.0, "scale": Vector3(1.4, 1.5, 1.4)},
		{"pos": Vector3(3.5, 0.0, -9.0), "scene": SCENE_ROCKS_B, "rot": -45.0, "scale": Vector3(1.4, 1.6, 1.4)},
		{"pos": Vector3(-3.2, 0.0, -12.0), "scene": SCENE_ROCK_A, "rot": 70.0, "scale": Vector3(1.2, 1.2, 1.2)},
		{"pos": Vector3(3.2, 0.0, -12.0), "scene": SCENE_ROCK_B, "rot": -80.0, "scale": Vector3(1.2, 1.2, 1.2)},

		# 4. North-East Ridge & Stone Crests
		{"pos": Vector3(13.5, 0.0, -13.5), "scene": SCENE_ROCKS_B, "rot": -60.0, "scale": Vector3(2.0, 2.2, 2.0)},
		{"pos": Vector3(11.0, 0.0, -14.0), "scene": SCENE_ROCKS_A, "rot": 120.0, "scale": Vector3(1.7, 1.8, 1.7)},
		{"pos": Vector3(14.0, 0.0, -10.0), "scene": SCENE_ROCKS_B, "rot": -15.0, "scale": Vector3(1.8, 1.9, 1.8)},
		{"pos": Vector3(8.5, 0.0, -12.5), "scene": SCENE_ROCKS_A, "rot": 45.0, "scale": Vector3(1.4, 1.4, 1.4)},
		{"pos": Vector3(7.0, 0.0, -10.0), "scene": SCENE_ROCK_A, "rot": -90.0, "scale": Vector3(1.2, 1.2, 1.2)},
		{"pos": Vector3(10.0, 0.0, -7.0), "scene": SCENE_ROCK_B, "rot": 160.0, "scale": Vector3(1.1, 1.1, 1.1)},
		{"pos": Vector3(12.5, 0.0, -6.0), "scene": SCENE_ROCK_A, "rot": 30.0, "scale": Vector3(1.1, 1.1, 1.1)},

		# 5. South-West Ravine & Dry Gulch
		{"pos": Vector3(-13.5, 0.0, 13.5), "scene": SCENE_ROCKS_A, "rot": 120.0, "scale": Vector3(2.1, 2.2, 2.1)},
		{"pos": Vector3(-10.5, 0.0, 13.5), "scene": SCENE_ROCKS_B, "rot": -45.0, "scale": Vector3(1.7, 1.9, 1.7)},
		{"pos": Vector3(-14.0, 0.0, 10.0), "scene": SCENE_ROCKS_B, "rot": 75.0, "scale": Vector3(1.8, 2.0, 1.8)},
		{"pos": Vector3(-7.5, 0.0, 8.5), "scene": SCENE_ROCKS_A, "rot": -30.0, "scale": Vector3(1.3, 1.3, 1.3)},
		{"pos": Vector3(-11.0, 0.0, 6.5), "scene": SCENE_ROCK_A, "rot": 105.0, "scale": Vector3(1.2, 1.2, 1.2)},
		{"pos": Vector3(-6.5, 0.0, 11.5), "scene": SCENE_ROCK_B, "rot": -60.0, "scale": Vector3(1.1, 1.1, 1.1)},
		{"pos": Vector3(-9.5, 0.0, 11.0), "scene": SCENE_ROCK_A, "rot": 40.0, "scale": Vector3(1.0, 1.0, 1.0)},

		# 6. South Canyon Pass (Portal boulders)
		{"pos": Vector3(-3.5, 0.0, 9.0), "scene": SCENE_ROCKS_B, "rot": -45.0, "scale": Vector3(1.4, 1.5, 1.4)},
		{"pos": Vector3(3.5, 0.0, 9.0), "scene": SCENE_ROCKS_A, "rot": 60.0, "scale": Vector3(1.4, 1.5, 1.4)},
		{"pos": Vector3(-3.2, 0.0, 12.0), "scene": SCENE_ROCK_B, "rot": -100.0, "scale": Vector3(1.2, 1.2, 1.2)},
		{"pos": Vector3(3.2, 0.0, 12.0), "scene": SCENE_ROCK_A, "rot": 85.0, "scale": Vector3(1.2, 1.2, 1.2)},

		# 7. South-East Twin Spires & Boulder Scree
		{"pos": Vector3(8.5, 0.0, 8.5), "scene": SCENE_ROCKS_B, "rot": 35.0, "scale": Vector3(2.4, 2.8, 2.4)},
		{"pos": Vector3(12.0, 0.0, 10.5), "scene": SCENE_ROCKS_B, "rot": -80.0, "scale": Vector3(2.5, 3.0, 2.5)},
		{"pos": Vector3(6.5, 0.0, 11.0), "scene": SCENE_ROCKS_A, "rot": 140.0, "scale": Vector3(1.5, 1.5, 1.5)},
		{"pos": Vector3(10.0, 0.0, 13.5), "scene": SCENE_ROCKS_A, "rot": -25.0, "scale": Vector3(1.6, 1.7, 1.6)},
		{"pos": Vector3(13.5, 0.0, 13.5), "scene": SCENE_ROCKS_A, "rot": 90.0, "scale": Vector3(2.0, 2.1, 2.0)},
		{"pos": Vector3(7.0, 0.0, 6.5), "scene": SCENE_ROCK_A, "rot": -45.0, "scale": Vector3(1.2, 1.2, 1.2)},
		{"pos": Vector3(10.5, 0.0, 6.0), "scene": SCENE_ROCK_B, "rot": 115.0, "scale": Vector3(1.1, 1.1, 1.1)},
		{"pos": Vector3(13.5, 0.0, 7.5), "scene": SCENE_ROCK_A, "rot": -15.0, "scale": Vector3(1.3, 1.3, 1.3)},

		# 8. West and East Flanking Escarpments
		{"pos": Vector3(-10.5, 0.0, -3.5), "scene": SCENE_ROCKS_A, "rot": 75.0, "scale": Vector3(1.5, 1.6, 1.5)},
		{"pos": Vector3(-13.0, 0.0, -0.5), "scene": SCENE_ROCKS_B, "rot": -110.0, "scale": Vector3(1.9, 2.2, 1.9)},
		{"pos": Vector3(-10.5, 0.0, 3.5), "scene": SCENE_ROCKS_A, "rot": 30.0, "scale": Vector3(1.4, 1.5, 1.4)},
		{"pos": Vector3(-7.5, 0.0, 0.0), "scene": SCENE_ROCK_B, "rot": -65.0, "scale": Vector3(1.1, 1.1, 1.1)},

		{"pos": Vector3(10.5, 0.0, -3.5), "scene": SCENE_ROCKS_B, "rot": -75.0, "scale": Vector3(1.5, 1.7, 1.5)},
		{"pos": Vector3(13.0, 0.0, 0.5), "scene": SCENE_ROCKS_A, "rot": 110.0, "scale": Vector3(1.9, 2.0, 1.9)},
		{"pos": Vector3(10.5, 0.0, 3.5), "scene": SCENE_ROCKS_B, "rot": -30.0, "scale": Vector3(1.4, 1.6, 1.4)},
		{"pos": Vector3(7.5, 0.0, 0.0), "scene": SCENE_ROCK_A, "rot": 65.0, "scale": Vector3(1.1, 1.1, 1.1)},

		# 9. Additional Arroyo Meanders, Scree Slopes & Flanking Boulders
		{"pos": Vector3(-1.0, 0.0, 7.5), "scene": SCENE_ROCK_A, "rot": 45.0, "scale": Vector3(1.15, 1.2, 1.15)},
		{"pos": Vector3(1.5, 0.0, 7.0), "scene": SCENE_ROCK_B, "rot": -60.0, "scale": Vector3(1.05, 1.1, 1.05)},
		{"pos": Vector3(-4.5, 0.0, 8.5), "scene": SCENE_ROCKS_A, "rot": 15.0, "scale": Vector3(1.4, 1.5, 1.4)},
		{"pos": Vector3(4.5, 0.0, 8.5), "scene": SCENE_ROCKS_B, "rot": -105.0, "scale": Vector3(1.3, 1.4, 1.3)},
		{"pos": Vector3(15.5, 0.0, 3.5), "scene": SCENE_ROCKS_A, "rot": 85.0, "scale": Vector3(1.8, 1.9, 1.8)},
		{"pos": Vector3(16.0, 0.0, -3.5), "scene": SCENE_ROCKS_B, "rot": -25.0, "scale": Vector3(1.7, 1.8, 1.7)},
		{"pos": Vector3(-15.5, 0.0, 3.5), "scene": SCENE_ROCKS_B, "rot": -115.0, "scale": Vector3(1.8, 2.0, 1.8)},
		{"pos": Vector3(-16.0, 0.0, -3.5), "scene": SCENE_ROCKS_A, "rot": 35.0, "scale": Vector3(1.7, 1.9, 1.7)},
		{"pos": Vector3(-1.2, 0.0, 2.0), "scene": SCENE_ROCK_B, "rot": 50.0, "scale": Vector3(0.9, 0.9, 0.9)},
		{"pos": Vector3(1.2, 0.0, -2.0), "scene": SCENE_ROCK_A, "rot": -130.0, "scale": Vector3(0.95, 0.95, 0.95)},
		{"pos": Vector3(-3.5, 0.0, 1.5), "scene": SCENE_ROCK_A, "rot": 20.0, "scale": Vector3(1.0, 1.0, 1.0)},
		{"pos": Vector3(3.5, 0.0, -1.5), "scene": SCENE_ROCK_B, "rot": -80.0, "scale": Vector3(1.0, 1.0, 1.0)},
		{"pos": Vector3(0.0, 0.0, 15.5), "scene": SCENE_ROCKS_B, "rot": 180.0, "scale": Vector3(2.2, 2.4, 2.2)},
		{"pos": Vector3(0.0, 0.0, -15.5), "scene": SCENE_ROCKS_A, "rot": 0.0, "scale": Vector3(2.0, 2.2, 2.0)},

		# 10. Towering Sandstone Monoliths & Canyon Hoodoos (matches Canyon Vista Banner)
		{"pos": Vector3(-17.5, 0.0, -17.5), "scene": SCENE_ROCKS_A, "rot": 15.0, "scale": Vector3(2.4, 3.6, 2.4)},
		{"pos": Vector3(17.5, 0.0, -17.5), "scene": SCENE_ROCKS_B, "rot": -75.0, "scale": Vector3(2.5, 3.8, 2.5)},
		{"pos": Vector3(-17.5, 0.0, 17.5), "scene": SCENE_ROCKS_B, "rot": 110.0, "scale": Vector3(2.4, 3.5, 2.4)},
		{"pos": Vector3(17.5, 0.0, 17.5), "scene": SCENE_ROCKS_A, "rot": -40.0, "scale": Vector3(2.6, 3.9, 2.6)},
	]
	for r in extra_rock_coords:
		var sc : Vector3 = r["scale"] if r.has("scale") else Vector3.ONE
		_spawn_prop(rocks_root, r["scene"], r["pos"], r["rot"], sc)

## Spawns dynamic Points of Interest across Map 2 (Space Base):
## 1. Geological Crater Excavation Dig Site on the elevated South-East ridge with drill rig, rover, and floodlights.
## 2. Southwest Auxiliary Staging Yard with delivery rover, cargo containers, and service floodlight.
## 3. High-ground tactical lookout points along the perimeter bluffs.
## 4. Habitation & Laboratory Perimeter and Central Corridor Logistics.
func _spawn_spacebase_pois() -> void:
	var dig_root : Node3D = get_node_or_null("Sector_ResearchDig") as Node3D
	if dig_root == null:
		dig_root = Node3D.new()
		dig_root.name = "Sector_ResearchDig"
		add_child(dig_root)

	# 1. Giant Deep-Space Planetary Communications Array Dish (Perched on Northern Bluff)
	var dish : Node3D = SCRIPT_SATELLITE_DISH.new() as Node3D
	dish.name = "OutpostSatelliteDish"
	var dish_gy : float = get_terrain_height(0.0, -14.0)
	dish.position = Vector3(0.0, dish_gy, -14.0)
	dig_root.add_child(dish)

	# 2. Heavy Industrial Pipeline Conduits (connecting Habitation to Power Grid & Dig Site)
	var pipe_main : Node3D = SCRIPT_PIPELINE.new() as Node3D
	pipe_main.name = "Pipeline_HabToPower"
	pipe_main.set("length", 6.0)
	pipe_main.position = Vector3(4.2, 0.0, -2.5)
	dig_root.add_child(pipe_main)

	var pipe_quarry : Node3D = SCRIPT_PIPELINE.new() as Node3D
	pipe_quarry.name = "Pipeline_PowerToQuarry"
	pipe_quarry.set("length", 4.5)
	pipe_quarry.position = Vector3(4.5, 0.0, 7.8)
	pipe_quarry.rotation_degrees.y = 90.0
	dig_root.add_child(pipe_quarry)

	var poi_props := [
		# 1. Geological Crater Excavation Dig Site (perched on the South-East Ridge at (10, 8))
		{"scene": SCENE_DRILL, "pos": Vector3(7.5, 0.06, 6.5), "rot": 40.0, "scale": Vector3.ONE},
		{"scene": SCENE_ROVER, "pos": Vector3(7.0, 0.14, 10.0), "rot": -45.0, "scale": Vector3.ONE},
		{"scene": SCENE_CARGO_PACKED, "pos": Vector3(8.5, 0.06, 9.5), "rot": 15.0, "scale": Vector3.ONE},
		{"scene": SCENE_CONTAINERS_A, "pos": Vector3(6.5, 0.06, 8.0), "rot": 0.0, "scale": Vector3.ONE},
		{"scene": SCENE_LIGHTS, "pos": Vector3(8.0, 0.06, 7.5), "rot": 35.0, "scale": Vector3.ONE},
		{"scene": SCENE_ROCKS_A, "pos": Vector3(12.5, 0.0, 11.5), "rot": -60.0, "scale": Vector3(1.3, 1.4, 1.3)},
		{"scene": SCENE_ROCK_B, "pos": Vector3(6.0, 0.0, 11.5), "rot": 120.0, "scale": Vector3(1.1, 1.1, 1.1)},

		# 2. Southwest Auxiliary Staging Yard
		{"scene": SCENE_ROVER, "pos": Vector3(-3.5, 0.14, 5.0), "rot": 20.0, "scale": Vector3.ONE},
		{"scene": SCENE_CARGO_PACKED, "pos": Vector3(-4.8, 0.06, 4.5), "rot": -15.0, "scale": Vector3.ONE},
		{"scene": SCENE_CONTAINERS_A, "pos": Vector3(-2.5, 0.06, 5.5), "rot": 90.0, "scale": Vector3.ONE},
		{"scene": SCENE_LIGHTS, "pos": Vector3(-3.0, 0.06, 3.8), "rot": 180.0, "scale": Vector3.ONE},

		# 3. Perimeter Overlook Tactical Outposts
		{"scene": SCENE_ROCKS_B, "pos": Vector3(-14.0, 0.0, -14.0), "rot": 45.0, "scale": Vector3(1.6, 1.8, 1.6)},
		{"scene": SCENE_ROCKS_A, "pos": Vector3(14.0, 0.0, -14.0), "rot": -45.0, "scale": Vector3(1.5, 1.7, 1.5)},
		{"scene": SCENE_ROCK_A, "pos": Vector3(13.5, 0.0, 0.0), "rot": 90.0, "scale": Vector3(1.2, 1.2, 1.2)},

		# 4. Habitation & Laboratory Perimeter Dressing
		{"scene": SCENE_CONTAINERS_A, "pos": Vector3(-9.2, 0.06, -7.5), "rot": 0.0, "scale": Vector3.ONE},
		{"scene": SCENE_CARGO_STACKED, "pos": Vector3(-11.0, 0.06, -4.5), "rot": 90.0, "scale": Vector3.ONE},
		{"scene": SCENE_LIGHTS, "pos": Vector3(-6.5, 0.06, -11.0), "rot": 135.0, "scale": Vector3.ONE},
		{"scene": SCENE_SOLARPANEL, "pos": Vector3(-7.5, 0.06, -12.5), "rot": 20.0, "scale": Vector3.ONE},
		{"scene": SCENE_SOLARPANEL, "pos": Vector3(-9.0, 0.06, -12.5), "rot": 20.0, "scale": Vector3.ONE},

		# 5. Central Crossroads & South Corridor Logistics Support
		{"scene": SCENE_CARGO_STACKED, "pos": Vector3(2.2, 0.06, 1.5), "rot": -30.0, "scale": Vector3.ONE},
		{"scene": SCENE_CONTAINERS_A, "pos": Vector3(-2.2, 0.06, 2.2), "rot": 45.0, "scale": Vector3.ONE},
		{"scene": SCENE_LIGHTS, "pos": Vector3(1.8, 0.06, 3.5), "rot": -90.0, "scale": Vector3.ONE},
		{"scene": SCENE_CARGO_PACKED, "pos": Vector3(-1.5, 0.06, 8.5), "rot": 15.0, "scale": Vector3.ONE},
		{"scene": SCENE_CONTAINERS_A, "pos": Vector3(1.5, 0.06, 12.0), "rot": -45.0, "scale": Vector3.ONE},

		# 6. High-Ground Power Grid Turbines & Solar Tracking (matches Space Base Vista Banner)
		{"scene": SCENE_WINDTURBINE_TALL, "pos": Vector3(14.0, 0.0, -8.0), "rot": 15.0, "scale": Vector3.ONE},
		{"scene": SCENE_WINDTURBINE_LOW, "pos": Vector3(14.5, 0.0, -11.0), "rot": -45.0, "scale": Vector3.ONE},
		{"scene": SCENE_SOLARPANEL, "pos": Vector3(12.0, 0.0, -12.5), "rot": 30.0, "scale": Vector3.ONE},
	]

	for p in poi_props:
		var sc : Vector3 = p["scale"] if p.has("scale") else Vector3.ONE
		_spawn_prop(dig_root, p["scene"], p["pos"], p["rot"], sc)

## Spawns dynamic Points of Interest across Map 3 (Transport Dock):
## Heavy logistics freight staging, launchpad fueling canisters, hauler trailer parking,
## and mining quarry equipment.
func _spawn_transportdock_pois() -> void:
	var dock_root : Node3D = get_node_or_null("Sector_DockLogistics") as Node3D
	if dock_root == null:
		dock_root = Node3D.new()
		dock_root.name = "Sector_DockLogistics"
		add_child(dock_root)

	# 1. Massive Rail-Mounted Orbital Gantry Crane (spanning freight corridor)
	var crane : Node3D = SCRIPT_GANTRY_CRANE.new() as Node3D
	crane.name = "HeavyOrbitalGantryCrane"
	crane.position = Vector3(-3.5, 0.0, -2.5)
	dock_root.add_child(crane)

	# 2. Pressurized Cryogenic Propellant Fuel Depot & Berm (adjacent to Shuttle Apron)
	var fuel : Node3D = SCRIPT_FUEL_DEPOT.new() as Node3D
	fuel.name = "CryoFuelDepot"
	fuel.position = Vector3(-13.5, 0.0, 8.0)
	dock_root.add_child(fuel)

	var dock_props := [
		# 1. Shuttle Apron Staging & Refueling Depot
		{"scene": SCENE_CONTAINERS_A, "pos": Vector3(-11.5, 0.06, 6.0), "rot": 0.0, "scale": Vector3.ONE},
		{"scene": SCENE_CARGO_PACKED, "pos": Vector3(-11.5, 0.06, 4.5), "rot": 90.0, "scale": Vector3.ONE},
		{"scene": SCENE_CARGO_STACKED, "pos": Vector3(-3.2, 0.06, 7.5), "rot": -45.0, "scale": Vector3.ONE},
		{"scene": SCENE_LIGHTS, "pos": Vector3(-3.5, 0.06, 11.0), "rot": 45.0, "scale": Vector3.ONE},

		# 2. Heavy Transport Truck Staging Area
		{"scene": SCENE_SPACETRUCK, "pos": Vector3(-6.5, 0.20, -6.5), "rot": 90.0, "scale": Vector3.ONE},
		{"scene": SCENE_TRUCK_TRAILER, "pos": Vector3(-4.0, 0.21, -6.5), "rot": 90.0, "scale": Vector3.ONE},
		{"scene": SCENE_CARGO_STACKED, "pos": Vector3(-8.5, 0.06, -7.5), "rot": 0.0, "scale": Vector3.ONE},
		{"scene": SCENE_CONTAINERS_A, "pos": Vector3(-2.2, 0.06, -5.5), "rot": -30.0, "scale": Vector3.ONE},
		{"scene": SCENE_LIGHTS, "pos": Vector3(-5.0, 0.06, -8.5), "rot": 0.0, "scale": Vector3.ONE},

		# 3. Mining Quarry Extended Perimeter Support
		{"scene": SCENE_CARGO_PACKED, "pos": Vector3(11.5, 0.06, 5.0), "rot": 25.0, "scale": Vector3.ONE},
		{"scene": SCENE_CONTAINERS_A, "pos": Vector3(11.5, 0.06, 7.5), "rot": -60.0, "scale": Vector3.ONE},
		{"scene": SCENE_LIGHTS, "pos": Vector3(9.5, 0.06, 9.5), "rot": 135.0, "scale": Vector3.ONE},
		{"scene": SCENE_CARGO_STACKED, "pos": Vector3(5.5, 0.06, 6.0), "rot": 15.0, "scale": Vector3.ONE},

		# 4. Central Freight Corridor Support
		{"scene": SCENE_CARGO_PACKED, "pos": Vector3(2.5, 0.06, 0.8), "rot": -15.0, "scale": Vector3.ONE},
		{"scene": SCENE_CONTAINERS_A, "pos": Vector3(-2.5, 0.06, -0.8), "rot": 75.0, "scale": Vector3.ONE},
		{"scene": SCENE_LIGHTS, "pos": Vector3(2.2, 0.06, -2.5), "rot": -45.0, "scale": Vector3.ONE},

		# 5. Aerospace Apron Staging & Freight Stacks (matches Transport Dock Vista Banner)
		{"scene": SCENE_CARGODEPOT_A, "pos": Vector3(-13.5, 0.06, -0.5), "rot": 90.0, "scale": Vector3.ONE},
		{"scene": SCENE_CONTAINERS_B, "pos": Vector3(-13.5, 0.06, 2.0), "rot": 0.0, "scale": Vector3.ONE},
		{"scene": SCENE_CARGO_B_STACKED, "pos": Vector3(-7.5, 0.06, 12.0), "rot": 45.0, "scale": Vector3.ONE},
		{"scene": SCENE_LIGHTS, "pos": Vector3(-13.0, 0.06, 10.0), "rot": -45.0, "scale": Vector3.ONE},
		{"scene": SCENE_LIGHTS, "pos": Vector3(-9.0, 0.06, -8.5), "rot": 90.0, "scale": Vector3.ONE},
	]

	for p in dock_props:
		var sc : Vector3 = p["scale"] if p.has("scale") else Vector3.ONE
		_spawn_prop(dock_root, p["scene"], p["pos"], p["rot"], sc)

## Evaluates the height at grid vertex (x, z) for the active theme.
## Ensures outer boundaries drop smoothly to Y = 0.0 for seamless outer desert continuity,
## and guarantees building foundations are 100% flat at Y = 0.0 to prevent any clipping.
func _get_elevation_raw(x: float, z: float) -> int:
	# Ensure the outer perimeter of the 21x21 grid is flat (Y = 0) everywhere
	# This creates a mathematically perfect, seamless transition to the outer desert floor
	if absf(x) >= 19.0 or absf(z) >= 19.0:
		return 0

	match map_theme:
		MapTheme.CANYON_WASTELAND:
			return _get_elev_wasteland(x, z)
		MapTheme.SPACE_BASE:
			return _get_elev_spacebase(x, z)
		MapTheme.TRANSPORT_DOCK:
			return _get_elev_transportdock(x, z)
		_:
			return _get_elev_spacebase(x, z)

## Map 1: Desolate Canyon - Dramatic alien canyon amphitheater, natural rock bridge & passes
func _get_elev_wasteland(x: float, z: float) -> int:
	# Central open canyon amphitheater and sunken arroyo floor
	if Vector2(x, z - 1.0).length() < 5.8:
		return 0
	# North and South canyon entrance passes
	if absf(x) <= 3.8 and absf(z) >= 8.5:
		return 0
	# Walkway under the sandstone arch bridge (z around -2.0, x between -4.5 and 4.5)
	if absf(x) <= 4.5 and absf(z + 2.0) <= 2.8:
		return 0

	# West and East canyon bluffs & mesa escarpments
	if (x <= -6.5 or x >= 6.5) and absf(z) <= 16.5:
		return 1
	# Northern and Southern defensive mesa walls
	if absf(z) >= 12.5 and (x <= -4.0 or x >= 4.0):
		return 1
	if x <= -12.5 or x >= 12.5:
		return 1
	return 0

## Map 2: Space Base - Tactical colony outpost with elevated geological research ridges,
## dramatic perimeter cliff bluffs, and flat foundations for the modular base and power grid.
func _get_elev_spacebase(x: float, z: float) -> int:
	# Flat building foundation for Habitation Complex (-12..1, -12..1)
	if -12.0 <= x and x <= 1.0 and -12.0 <= z and z <= 1.0:
		return 0
	# Flat building foundation for Power Grid (3..12, -12..-3)
	if 3.0 <= x and x <= 12.0 and -12.0 <= z and z <= -3.0:
		return 0
	# Flat central crossroads plaza (-3..4, -3..3)
	if -3.0 <= x and x <= 4.0 and -3.0 <= z and z <= 3.0:
		return 0
	# Flat south canyon corridor (-4..4, 3..18)
	if -4.0 <= x and x <= 4.0 and z >= 3.0:
		return 0

	# 1. Northern mountain ridge shielding the base from the north
	if z <= -13.0:
		return 1
	# 2. Northwest protective mesa cliff
	if x <= -13.0 and z <= -7.0:
		return 1
	# 3. Eastern overlook escarpment
	if x >= 13.0 and z <= 14.0:
		return 1
	# 4. Southeast Excavation & Geological Ridge (houses the crater pit)
	if 5.0 <= x and x <= 13.0 and 5.0 <= z and z <= 13.0:
		return 1
	# 5. Southwest crags & high ground
	if -14.0 <= x and x <= -6.0 and 6.0 <= z and z <= 14.0:
		return 1
	if x <= -14.0 or z >= 15.0 or x >= 15.0:
		return 1
	return 0

## Map 3: Transport Dock - Shuttle landing pads, logistics tarmac & mining quarry
func _get_elev_transportdock(x: float, z: float) -> int:
	# Flat flight tarmac & logistics runway: covers Landing Pads (-12..-4, -3..11), Drill floor (5..11, 2..8), Checkpoint (-3..3, 7..10)
	if -14.0 <= x and x <= 12.0 and -3.5 <= z and z <= 12.0:
		return 0
	# Courtyard transit
	if -4.5 <= x and x <= 4.5 and -5.0 <= z and z <= 5.0:
		return 0
	# Northern mountain rim behind runway
	if z <= -7.0:
		return 1
	# Eastern quarry escarpment rising behind the extraction drill
	if x >= 12.5 and z >= 1.0:
		return 1
	# West buffer crags
	if x <= -14.0 and z >= -3.0:
		return 1
	if z >= 13.0 and (x <= -7.0 or x >= 7.0):
		return 1
	return 0

## Builds the varied, seamlessly connected modular terrain grid using slopes and raised plateaus.
func _build_terrain() -> void:
	var terrain_node : Node3D = get_node_or_null("Sector_Terrain") as Node3D
	if terrain_node == null:
		terrain_node = Node3D.new()
		terrain_node.name = "Sector_Terrain"
		add_child(terrain_node)
	else:
		# Clear any previous placeholder nodes
		for child in terrain_node.get_children():
			child.queue_free()

	# Compute 22x22 vertex heightfield
	_terrain_H.clear()
	for vz in range(TERRAIN_GRID_D + 1):
		var row : Array[int] = []
		for vx in range(TERRAIN_GRID_W + 1):
			var x : float = TERRAIN_ORIGIN_X - 1.0 + float(vx) * TERRAIN_TILE_SIZE
			var z : float = TERRAIN_ORIGIN_Z - 1.0 + float(vz) * TERRAIN_TILE_SIZE
			row.append(_get_elevation_raw(x, z))
		_terrain_H.append(row)

	# Topological saddle resolution (ensures every single tile matches valid geometry)
	for vz in range(TERRAIN_GRID_D):
		for vx in range(TERRAIN_GRID_W):
			var nw : int = _terrain_H[vz][vx]
			var ne : int = _terrain_H[vz][vx + 1]
			var sw : int = _terrain_H[vz + 1][vx]
			var se : int = _terrain_H[vz + 1][vx + 1]
			if nw == 1 and ne == 0 and sw == 0 and se == 1:
				_terrain_H[vz + 1][vx + 1] = 0
			elif nw == 0 and ne == 1 and sw == 1 and se == 0:
				_terrain_H[vz + 1][vx] = 0

	# Instantiate matching modular tiles for each 2x2m cell
	for vz in range(TERRAIN_GRID_D):
		for vx in range(TERRAIN_GRID_W):
			var nw : int = _terrain_H[vz][vx]
			var ne : int = _terrain_H[vz][vx + 1]
			var sw : int = _terrain_H[vz + 1][vx]
			var se : int = _terrain_H[vz + 1][vx + 1]
			var key := Vector4i(nw, ne, sw, se)

			if not TILE_LOOKUP.has(key):
				continue

			var data : Dictionary = TILE_LOOKUP[key]
			var scene : PackedScene = data["scene"]
			var rot : float = float(data["rot"])
			var tile_x : float = TERRAIN_ORIGIN_X + float(vx) * TERRAIN_TILE_SIZE
			var tile_z : float = TERRAIN_ORIGIN_Z + float(vz) * TERRAIN_TILE_SIZE

			# On Map 2 (Space Base), exactly one crater excavation pit tile is placed at (10.0, 8.0)
			if map_theme == MapTheme.SPACE_BASE and key == Vector4i(1,1,1,1) and absf(tile_x - 10.0) < 0.5 and absf(tile_z - 8.0) < 0.5:
				scene = SCENE_TERRAIN_MINING

			# On Map 3 (Transport Dock), elevated quarry terraces use mining excavation tiles sparingly
			if map_theme == MapTheme.TRANSPORT_DOCK and key == Vector4i(1,1,1,1) and absf(tile_x - 14.0) < 0.5 and (absf(tile_z - 4.0) < 0.5 or absf(tile_z - 6.0) < 0.5):
				scene = SCENE_TERRAIN_MINING

			var inst : Node3D = scene.instantiate() as Node3D
			inst.name = "%s_%d_%d" % [scene.resource_path.get_file().get_basename(), vx, vz]
			inst.position = Vector3(tile_x, 0.0, tile_z)
			inst.rotation_degrees.y = rot
			terrain_node.add_child(inst)

## Creates the visual demarcation line and perimeter tripwire beacons indicating where the safe zone ends.
## Uses SurfaceTool to generate continuous, pitch-adapted surface ribbons that hug slopes, ridges, and corners
## with 100% precision, zero gaps, zero clipping, and zero hovering.
func _build_demarcation_line() -> void:
	var demarcation := Node3D.new()
	demarcation.name = "DemarcationLine"

	var hz : float = safe_zone_half_size # 15.5m

	# Luminous Theme-aware Warning Stripe Material
	var stripe_mat := StandardMaterial3D.new()
	stripe_mat.emission_enabled = true
	stripe_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_stripe_material = stripe_mat

	# Tripwire Laser Beam Material
	var laser_mat := StandardMaterial3D.new()
	laser_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	laser_mat.emission_enabled = true
	laser_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_laser_material = laser_mat

	_update_demarcation_materials()

	# Compute continuous perimeter sample loop (clockwise: North -> East -> South -> West)
	var steps_per_side : int = 62
	var perimeter_pts : Array[Vector3] = []
	var perimeter_tangents : Array[Vector3] = []

	# 1. North Edge: (-hz, -hz) -> (+hz, -hz)
	for i in range(steps_per_side):
		var frac : float = float(i) / float(steps_per_side)
		var x : float = -hz + 2.0 * hz * frac
		var z : float = -hz
		perimeter_pts.append(Vector3(x, get_terrain_height(x, z), z))
		perimeter_tangents.append(Vector3(1, 0, 0))

	# 2. East Edge: (+hz, -hz) -> (+hz, +hz)
	for i in range(steps_per_side):
		var frac : float = float(i) / float(steps_per_side)
		var x : float = hz
		var z : float = -hz + 2.0 * hz * frac
		perimeter_pts.append(Vector3(x, get_terrain_height(x, z), z))
		perimeter_tangents.append(Vector3(0, 0, 1))

	# 3. South Edge: (+hz, +hz) -> (-hz, +hz)
	for i in range(steps_per_side):
		var frac : float = float(i) / float(steps_per_side)
		var x : float = hz - 2.0 * hz * frac
		var z : float = hz
		perimeter_pts.append(Vector3(x, get_terrain_height(x, z), z))
		perimeter_tangents.append(Vector3(-1, 0, 0))

	# 4. West Edge: (-hz, +hz) -> (-hz, -hz)
	for i in range(steps_per_side):
		var frac : float = float(i) / float(steps_per_side)
		var x : float = -hz
		var z : float = hz - 2.0 * hz * frac
		perimeter_pts.append(Vector3(x, get_terrain_height(x, z), z))
		perimeter_tangents.append(Vector3(0, 0, -1))

	var total_pts : int = perimeter_pts.size()

	# Generate continuous ground stripe ribbon mesh
	var st_stripe := SurfaceTool.new()
	st_stripe.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_stripe.set_material(stripe_mat)

	var half_w : float = 0.08
	for i in range(total_pts):
		var next_i : int = (i + 1) % total_pts
		var p0 : Vector3 = perimeter_pts[i]
		var p1 : Vector3 = perimeter_pts[next_i]

		var t0 : Vector3 = perimeter_tangents[i]
		var t1 : Vector3 = perimeter_tangents[next_i]
		var n0 : Vector3 = Vector3(-t0.z, 0.0, t0.x).normalized()
		var n1 : Vector3 = Vector3(-t1.z, 0.0, t1.x).normalized()

		# Ground offset of 0.02 avoids z-fighting with the underlying terrain surface
		var v0_l : Vector3 = p0 - n0 * half_w + Vector3(0.0, 0.02, 0.0)
		var v0_r : Vector3 = p0 + n0 * half_w + Vector3(0.0, 0.02, 0.0)
		var v1_l : Vector3 = p1 - n1 * half_w + Vector3(0.0, 0.02, 0.0)
		var v1_r : Vector3 = p1 + n1 * half_w + Vector3(0.0, 0.02, 0.0)

		# Quad triangles
		st_stripe.add_vertex(v0_l)
		st_stripe.add_vertex(v1_l)
		st_stripe.add_vertex(v1_r)

		st_stripe.add_vertex(v0_l)
		st_stripe.add_vertex(v1_r)
		st_stripe.add_vertex(v0_r)

	st_stripe.generate_normals()
	var stripe_mesh : ArrayMesh = st_stripe.commit()
	var stripe_inst := MeshInstance3D.new()
	stripe_inst.name = "GroundStripeMesh"
	stripe_inst.mesh = stripe_mesh
	stripe_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	demarcation.add_child(stripe_inst)

	# Generate continuous vertical laser beam curtain
	var st_laser := SurfaceTool.new()
	st_laser.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_laser.set_material(laser_mat)

	for i in range(total_pts):
		var next_i : int = (i + 1) % total_pts
		var p0 : Vector3 = perimeter_pts[i]
		var p1 : Vector3 = perimeter_pts[next_i]

		var v0_bot : Vector3 = p0 + Vector3(0.0, 0.28, 0.0)
		var v0_top : Vector3 = p0 + Vector3(0.0, 0.36, 0.0)
		var v1_bot : Vector3 = p1 + Vector3(0.0, 0.28, 0.0)
		var v1_top : Vector3 = p1 + Vector3(0.0, 0.36, 0.0)

		st_laser.add_vertex(v0_bot)
		st_laser.add_vertex(v1_bot)
		st_laser.add_vertex(v1_top)

		st_laser.add_vertex(v0_bot)
		st_laser.add_vertex(v1_top)
		st_laser.add_vertex(v0_top)

	st_laser.generate_normals()
	var laser_mesh : ArrayMesh = st_laser.commit()
	var laser_inst := MeshInstance3D.new()
	laser_inst.name = "TripwireLaserMesh"
	laser_inst.mesh = laser_mesh
	laser_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	demarcation.add_child(laser_inst)

	# Regular Sensor Pylon Stakes along the perimeter (corners + evenly spaced every 5m)
	var pylon_coords : Array[Vector3] = []
	# 4 true corner stakes
	pylon_coords.append(Vector3(-hz, get_terrain_height(-hz, -hz), -hz))
	pylon_coords.append(Vector3(hz, get_terrain_height(hz, -hz), -hz))
	pylon_coords.append(Vector3(hz, get_terrain_height(hz, hz), hz))
	pylon_coords.append(Vector3(-hz, get_terrain_height(-hz, hz), hz))

	# Intermediate edge stakes
	for offset in [-10.0, -5.0, 0.0, 5.0, 10.0]:
		pylon_coords.append(Vector3(offset, get_terrain_height(offset, -hz), -hz)) # North
		pylon_coords.append(Vector3(offset, get_terrain_height(offset, hz), hz))   # South
		pylon_coords.append(Vector3(-hz, get_terrain_height(-hz, offset), offset)) # West
		pylon_coords.append(Vector3(hz, get_terrain_height(hz, offset), offset))   # East

	var pylon_body_mat := StandardMaterial3D.new()
	pylon_body_mat.albedo_color = Color(0.18, 0.22, 0.28, 1.0)
	pylon_body_mat.metallic = 0.8
	pylon_body_mat.roughness = 0.4

	for pt in pylon_coords:
		var pylon_node := Node3D.new()
		pylon_node.position = pt

		# Metal Stake post
		var post_mesh := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.04
		cyl.bottom_radius = 0.05
		cyl.height = 0.44
		post_mesh.mesh = cyl
		post_mesh.position = Vector3(0.0, 0.22, 0.0)
		post_mesh.material_override = pylon_body_mat
		post_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pylon_node.add_child(post_mesh)

		# Glowing Beacon Sensor Head
		var beacon_mesh := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.055
		sph.height = 0.11
		beacon_mesh.mesh = sph
		beacon_mesh.position = Vector3(0.0, 0.45, 0.0)
		beacon_mesh.material_override = stripe_mat
		beacon_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pylon_node.add_child(beacon_mesh)

		demarcation.add_child(pylon_node)

	add_child(demarcation)

## Fleshes out all 4 outer sectors purely with smooth, natural desert rocks and boulders.
## Eliminates all disconnected cubic blocks on the outer lands, creating a genuinely smooth,
## vast alien desert landscape with continuous dunes and weathered rock formations.
func _build_outer_sectors() -> void:
	var outer_root := Node3D.new()
	outer_root.name = "OuterSectors"

	# -------------------------------------------------------------------------
	# Sector 1: North Desert (Smooth Boulder Fields & Weathered Rocks)
	# -------------------------------------------------------------------------
	var sec_north := Node3D.new()
	sec_north.name = "Sector_Outer_North"

	_spawn_prop(sec_north, SCENE_ROCKS_A, Vector3(-20.0, 0.0, -22.0), 45.0)
	_spawn_prop(sec_north, SCENE_ROCKS_A, Vector3(-10.0, 0.0, -25.0), -30.0)
	_spawn_prop(sec_north, SCENE_ROCKS_A, Vector3(14.0, 0.0, -24.0), 75.0)
	_spawn_prop(sec_north, SCENE_ROCKS_A, Vector3(25.0, 0.0, -26.0), -60.0)
	_spawn_prop(sec_north, SCENE_ROCKS_B, Vector3(-15.0, 0.0, -28.0), 15.0)
	_spawn_prop(sec_north, SCENE_ROCKS_B, Vector3(8.0, 0.0, -22.0), 120.0)
	_spawn_prop(sec_north, SCENE_ROCKS_B, Vector3(20.0, 0.0, -28.0), -90.0)
	_spawn_prop(sec_north, SCENE_ROCKS_B, Vector3(-28.0, 0.0, -25.0), 35.0)

	_spawn_prop(sec_north, SCENE_ROCK_A, Vector3(-5.0, 0.0, -21.0), 60.0)
	_spawn_prop(sec_north, SCENE_ROCK_A, Vector3(2.0, 0.0, -22.0), -45.0)
	_spawn_prop(sec_north, SCENE_ROCK_A, Vector3(22.0, 0.0, -21.0), 90.0)
	_spawn_prop(sec_north, SCENE_ROCK_A, Vector3(-22.0, 0.0, -21.0), -120.0)
	_spawn_prop(sec_north, SCENE_ROCK_B, Vector3(-26.0, 0.0, -20.0), 15.0)
	_spawn_prop(sec_north, SCENE_ROCK_B, Vector3(16.0, 0.0, -20.0), -70.0)
	_spawn_prop(sec_north, SCENE_ROCK_B, Vector3(0.0, 0.0, -24.0), 180.0)
	_spawn_prop(sec_north, SCENE_ROCK_B, Vector3(-12.0, 0.0, -21.0), 40.0)

	outer_root.add_child(sec_north)

	# -------------------------------------------------------------------------
	# Sector 2: South Desert (Ancient Canyon Wash Boulders)
	# -------------------------------------------------------------------------
	var sec_south := Node3D.new()
	sec_south.name = "Sector_Outer_South"

	_spawn_prop(sec_south, SCENE_ROCKS_A, Vector3(-22.0, 0.0, 23.0), 120.0)
	_spawn_prop(sec_south, SCENE_ROCKS_A, Vector3(-12.0, 0.0, 21.0), -45.0)
	_spawn_prop(sec_south, SCENE_ROCKS_A, Vector3(10.0, 0.0, 22.0), 30.0)
	_spawn_prop(sec_south, SCENE_ROCKS_A, Vector3(26.0, 0.0, 26.0), -110.0)
	_spawn_prop(sec_south, SCENE_ROCKS_B, Vector3(-18.0, 0.0, 26.0), 45.0)
	_spawn_prop(sec_south, SCENE_ROCKS_B, Vector3(4.0, 0.0, 22.0), -60.0)
	_spawn_prop(sec_south, SCENE_ROCKS_B, Vector3(18.0, 0.0, 25.0), 100.0)
	_spawn_prop(sec_south, SCENE_ROCKS_B, Vector3(-28.0, 0.0, 24.0), -30.0)

	_spawn_prop(sec_south, SCENE_ROCK_A, Vector3(-6.0, 0.0, 21.0), 45.0)
	_spawn_prop(sec_south, SCENE_ROCK_A, Vector3(14.0, 0.0, 21.0), -85.0)
	_spawn_prop(sec_south, SCENE_ROCK_A, Vector3(22.0, 0.0, 23.0), 15.0)
	_spawn_prop(sec_south, SCENE_ROCK_A, Vector3(-24.0, 0.0, 21.0), -70.0)
	_spawn_prop(sec_south, SCENE_ROCK_B, Vector3(-15.0, 0.0, 21.0), 90.0)
	_spawn_prop(sec_south, SCENE_ROCK_B, Vector3(2.0, 0.0, 21.0), 0.0)
	_spawn_prop(sec_south, SCENE_ROCK_B, Vector3(20.0, 0.0, 21.0), 140.0)
	_spawn_prop(sec_south, SCENE_ROCK_B, Vector3(-2.0, 0.0, 25.0), -20.0)

	outer_root.add_child(sec_south)

	# -------------------------------------------------------------------------
	# Sector 3: East Desert (Crater Ridge Rock Outcrops)
	# -------------------------------------------------------------------------
	var sec_east := Node3D.new()
	sec_east.name = "Sector_Outer_East"

	_spawn_prop(sec_east, SCENE_ROCKS_A, Vector3(21.0, 0.0, -6.0), 30.0)
	_spawn_prop(sec_east, SCENE_ROCKS_A, Vector3(22.0, 0.0, 7.0), -75.0)
	_spawn_prop(sec_east, SCENE_ROCKS_A, Vector3(27.0, 0.0, -2.0), 120.0)
	_spawn_prop(sec_east, SCENE_ROCKS_A, Vector3(30.0, 0.0, 6.0), -40.0)
	_spawn_prop(sec_east, SCENE_ROCKS_B, Vector3(21.0, 0.0, 2.0), 45.0)
	_spawn_prop(sec_east, SCENE_ROCKS_B, Vector3(26.0, 0.0, -10.0), -30.0)
	_spawn_prop(sec_east, SCENE_ROCKS_B, Vector3(26.0, 0.0, 11.0), 85.0)
	_spawn_prop(sec_east, SCENE_ROCKS_B, Vector3(32.0, 0.0, -6.0), -110.0)

	_spawn_prop(sec_east, SCENE_ROCK_A, Vector3(20.0, 0.0, -10.0), 0.0)
	_spawn_prop(sec_east, SCENE_ROCK_A, Vector3(20.0, 0.0, 12.0), 90.0)
	_spawn_prop(sec_east, SCENE_ROCK_A, Vector3(24.0, 0.0, -1.0), -45.0)
	_spawn_prop(sec_east, SCENE_ROCK_A, Vector3(29.0, 0.0, 2.0), 60.0)
	_spawn_prop(sec_east, SCENE_ROCK_B, Vector3(20.0, 0.0, -2.0), -90.0)
	_spawn_prop(sec_east, SCENE_ROCK_B, Vector3(20.0, 0.0, 5.0), 45.0)
	_spawn_prop(sec_east, SCENE_ROCK_B, Vector3(25.0, 0.0, 0.0), 180.0)
	_spawn_prop(sec_east, SCENE_ROCK_B, Vector3(28.0, 0.0, -12.0), -60.0)

	outer_root.add_child(sec_east)

	# -------------------------------------------------------------------------
	# Sector 4: West Desert (Sandstone Plateau Boulders)
	# -------------------------------------------------------------------------
	var sec_west := Node3D.new()
	sec_west.name = "Sector_Outer_West"

	_spawn_prop(sec_west, SCENE_ROCKS_A, Vector3(-21.0, 0.0, -5.0), -45.0)
	_spawn_prop(sec_west, SCENE_ROCKS_A, Vector3(-22.0, 0.0, 6.0), 60.0)
	_spawn_prop(sec_west, SCENE_ROCKS_A, Vector3(-27.0, 0.0, -2.0), -120.0)
	_spawn_prop(sec_west, SCENE_ROCKS_A, Vector3(-30.0, 0.0, 7.0), 35.0)
	_spawn_prop(sec_west, SCENE_ROCKS_B, Vector3(-21.0, 0.0, 2.0), -45.0)
	_spawn_prop(sec_west, SCENE_ROCKS_B, Vector3(-26.0, 0.0, -10.0), 60.0)
	_spawn_prop(sec_west, SCENE_ROCKS_B, Vector3(-26.0, 0.0, 11.0), -85.0)
	_spawn_prop(sec_west, SCENE_ROCKS_B, Vector3(-32.0, 0.0, -6.0), 110.0)

	_spawn_prop(sec_west, SCENE_ROCK_A, Vector3(-20.0, 0.0, -10.0), 180.0)
	_spawn_prop(sec_west, SCENE_ROCK_A, Vector3(-20.0, 0.0, 12.0), -90.0)
	_spawn_prop(sec_west, SCENE_ROCK_A, Vector3(-24.0, 0.0, -1.0), 45.0)
	_spawn_prop(sec_west, SCENE_ROCK_A, Vector3(-29.0, 0.0, 2.0), -60.0)
	_spawn_prop(sec_west, SCENE_ROCK_B, Vector3(-20.0, 0.0, -2.0), 90.0)
	_spawn_prop(sec_west, SCENE_ROCK_B, Vector3(-20.0, 0.0, 5.0), -45.0)
	_spawn_prop(sec_west, SCENE_ROCK_B, Vector3(-25.0, 0.0, 0.0), 0.0)
	_spawn_prop(sec_west, SCENE_ROCK_B, Vector3(-28.0, 0.0, -12.0), 60.0)

	outer_root.add_child(sec_west)

	# -------------------------------------------------------------------------
	# Outer Corner Natural Rock Formations
	# -------------------------------------------------------------------------
	_spawn_prop(outer_root, SCENE_ROCKS_A, Vector3(-32.0, 0.0, -32.0), 0.0)
	_spawn_prop(outer_root, SCENE_ROCKS_B, Vector3(32.0, 0.0, -32.0), 90.0)
	_spawn_prop(outer_root, SCENE_ROCKS_B, Vector3(-32.0, 0.0, 32.0), -90.0)
	_spawn_prop(outer_root, SCENE_ROCKS_A, Vector3(32.0, 0.0, 32.0), 180.0)

	add_child(outer_root)

## Builds subtle high-altitude horizon atmospheric dust bands in the far distance
## without discoloring or obscuring the outer terrain ground.
func _build_outer_fog() -> void:
	var fog_root := Node3D.new()
	fog_root.name = "OuterAtmosphere"

	var mist_mat := StandardMaterial3D.new()
	mist_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mist_mat.roughness = 1.0
	mist_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mist_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mist_material = mist_mat
	_update_mist_material()

	# Subtle horizon bands positioned along the far perimeter edge (36m out, high in the sky)
	var haze_zones := [
		{"pos": Vector3(0.0, 4.5, -36.0), "size": Vector2(72.0, 6.0)}, # North Horizon
		{"pos": Vector3(0.0, 4.5, 36.0), "size": Vector2(72.0, 6.0)},   # South Horizon
		{"pos": Vector3(-36.0, 4.5, 0.0), "size": Vector2(6.0, 72.0)},  # West Horizon
		{"pos": Vector3(36.0, 4.5, 0.0), "size": Vector2(6.0, 72.0)},   # East Horizon
	]

	for z in haze_zones:
		var mi := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = z["size"]
		mi.mesh = plane
		mi.position = z["pos"]
		mi.material_override = mist_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fog_root.add_child(mi)

	add_child(fog_root)

## Helper to instantiate an FBX prop safely with position, rotation, and scale.
## Automatically snaps the prop to local terrain elevation so it sits naturally on the ground.
func _spawn_prop(parent: Node, scene_res: PackedScene, pos: Vector3, rot_deg_y: float = 0.0, p_scale: Vector3 = Vector3.ONE) -> Node3D:
	if scene_res == null:
		return null
	var inst : Node3D = scene_res.instantiate() as Node3D
	if inst == null:
		return null
	var ground_y : float = get_terrain_height(pos.x, pos.z)
	inst.position = Vector3(pos.x, ground_y + pos.y, pos.z)
	inst.rotation_degrees.y = rot_deg_y
	inst.scale = p_scale
	parent.add_child(inst)

	# If this is a light pole fixture, add a warm/cool tactical floodlight to illuminate the surroundings
	if scene_res == SCENE_LIGHTS:
		var pole_light := OmniLight3D.new()
		pole_light.name = "PoleOmniLight"
		pole_light.position = Vector3(0.0, 3.2, 0.0)
		pole_light.omni_range = 11.0
		pole_light.omni_attenuation = 1.0
		pole_light.light_energy = 2.4
		pole_light.shadow_enabled = true
		pole_light.shadow_blur = 0.0
		pole_light.shadow_bias = 0.02
		match map_theme:
			MapTheme.CANYON_WASTELAND:
				pole_light.light_color = Color(1.0, 0.72, 0.38) # Warm halogen
			MapTheme.SPACE_BASE:
				pole_light.light_color = Color(0.40, 0.82, 1.0) # Outpost cyan
			MapTheme.TRANSPORT_DOCK:
				pole_light.light_color = Color(1.0, 0.85, 0.45) # Industrial amber
		inst.add_child(pole_light)

	return inst

## Snaps all enemy spawners in the scene to the local ground surface.
func _snap_enemy_spawners() -> void:
	var root_node : Node = get_parent()
	if root_node == null:
		return
	for c in root_node.get_children():
		if c.name.begins_with("EnemySpawner") and (c is Node3D):
			var n3d := c as Node3D
			var gy : float = get_terrain_height(n3d.global_position.x, n3d.global_position.z)
			n3d.global_position.y = gy + 0.1

## Guarantees the player spawns securely atop the terrain without colliding with rocks or underground geometry.
func _ensure_player_spawn_safe() -> void:
	var tree : SceneTree = get_tree()
	var player : Node3D = tree.get_first_node_in_group("player") as Node3D if tree != null else null
	if player == null and get_parent() != null:
		player = get_parent().find_child("ProtoController", true, false) as Node3D
	if player != null and is_instance_valid(player) and player.is_inside_tree():
		var gy : float = get_terrain_height(player.global_position.x, player.global_position.z)
		player.global_position.y = maxf(player.global_position.y, gy + 0.15)

## Creates the outer true boundary barriers at the edge of the expanded map to prevent falling off.
## Perfectly aligns North, South, East, and West walls so corners meet cleanly with zero overlapping tails.
func _build_perimeter_boundaries() -> void:
	var half_x : float = ground_size.x * 0.48 # 38.4m
	var half_z : float = ground_size.y * 0.48 # 38.4m
	var wall_height : float = 8.0
	var thickness : float = 2.0
	var span_x : float = half_x * 2.0 # 76.8m
	var span_z : float = half_z * 2.0 # 76.8m

	var boundaries := [
		{"pos": Vector3(0, wall_height * 0.5, -half_z), "size": Vector3(span_x, wall_height, thickness)}, # North
		{"pos": Vector3(0, wall_height * 0.5, half_z), "size": Vector3(span_x, wall_height, thickness)},  # South
		{"pos": Vector3(-half_x, wall_height * 0.5, 0), "size": Vector3(thickness, wall_height, span_z)}, # West
		{"pos": Vector3(half_x, wall_height * 0.5, 0), "size": Vector3(thickness, wall_height, span_z)},  # East
	]

	var walls_node := StaticBody3D.new()
	walls_node.name = "PerimeterBarriers"
	walls_node.collision_layer = 1
	walls_node.collision_mask = 1
	walls_node.add_to_group("navigation_geometry")

	var b_mat := StandardMaterial3D.new()
	b_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	b_mat.emission_enabled = true
	_perimeter_material = b_mat
	_update_perimeter_material()

	for b in boundaries:
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = b["size"]
		col.shape = box
		col.position = b["pos"]
		walls_node.add_child(col)

		# Visual containment barrier grid at the perimeter
		var barrier_mesh := MeshInstance3D.new()
		var box_mesh := BoxMesh.new()
		var b_size : Vector3 = b["size"]
		box_mesh.size = Vector3(b_size.x, 3.0, 0.08) if b_size.x > b_size.z else Vector3(0.08, 3.0, b_size.z)

		barrier_mesh.mesh = box_mesh
		barrier_mesh.position = Vector3(b["pos"].x, 1.5, b["pos"].z)
		barrier_mesh.material_override = b_mat
		barrier_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		walls_node.add_child(barrier_mesh)

	# Corner containment pylon columns at the 4 perimeter corners
	for corner in [Vector3(-half_x, 0, -half_z), Vector3(half_x, 0, -half_z), Vector3(half_x, 0, half_z), Vector3(-half_x, 0, half_z)]:
		var p_mesh := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.2
		cyl.bottom_radius = 0.2
		cyl.height = 3.4
		p_mesh.mesh = cyl
		p_mesh.position = Vector3(corner.x, 1.7, corner.z)
		p_mesh.material_override = b_mat
		p_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		walls_node.add_child(p_mesh)

	add_child(walls_node)

## Spawns the central Weapons Box Dispenser for the active map theme.
func _spawn_weapons_box() -> void:
	var box_pos := Vector3(0.0, 0.0, 0.0)
	match map_theme:
		MapTheme.CANYON_WASTELAND:
			box_pos = Vector3(0.0, 0.0, 2.5)
		MapTheme.SPACE_BASE:
			box_pos = Vector3(0.0, 0.0, 0.0)
		MapTheme.TRANSPORT_DOCK:
			box_pos = Vector3(0.0, 0.0, 0.0)

	# Failsafe: Ensure any overlapping prop or light at the spawner coordinates is cleared
	var courtyard : Node = get_node_or_null("Sector_Courtyard")
	if courtyard != null:
		var center_light : Node = courtyard.get_node_or_null("Center_Beacon_Light")
		if center_light != null:
			center_light.queue_free()

	_spawn_prop(self, SCENE_WEAPONS_BOX, box_pos)

## Spawns fixed reactive tactical targets across the map that trigger armor regen when hit
func _spawn_map_targets() -> void:
	if SCENE_TARGET == null:
		return
	var targets_root : Node3D = get_node_or_null("MapTrainingTargets") as Node3D
	if targets_root == null:
		targets_root = Node3D.new()
		targets_root.name = "MapTrainingTargets"
		add_child(targets_root)
	else:
		for c in targets_root.get_children():
			c.queue_free()

	var target_coords := [
		{"pos": Vector3(-6.5, 0.0, 0.0), "rot": 90.0},
		{"pos": Vector3(6.5, 0.0, 0.0), "rot": -90.0},
		{"pos": Vector3(0.0, 0.0, 6.5), "rot": 180.0},
		{"pos": Vector3(0.0, 0.0, -6.5), "rot": 0.0},
		{"pos": Vector3(-12.5, 0.0, 10.5), "rot": 45.0},
		{"pos": Vector3(12.5, 0.0, -10.5), "rot": -135.0},
	]

	for tc in target_coords:
		var target : TrainingTarget = SCENE_TARGET.instantiate() as TrainingTarget
		if target != null:
			target.regen_armor_on_hit = true
			target.auto_reset_delay = 5.0
			target.initial_health = 40
			var gy : float = get_terrain_height(tc["pos"].x, tc["pos"].z)
			target.position = Vector3(tc["pos"].x, gy, tc["pos"].z)
			target.rotation_degrees.y = tc["rot"]
			targets_root.add_child(target)

## Recursively creates convex collisions on all MeshInstance3Ds that lack colliders.
## Crater/mining hole tiles receive concave trimesh collisions so the hollow crater interior is walkable.
## Skips dynamic vehicles, weapons box, targets, and CharacterBodies so physics remains dynamic.
func _setup_prop_collisions(node: Node) -> void:
	if node == null:
		return
	if node.is_in_group("vehicle") or node.is_in_group("weapons_box") or node.is_in_group("target") or node is CharacterBody3D or node is TrainingTarget:
		return
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		# terrain_low tiles are visual floor blocks; GroundBase provides seamless continuous floor collision.
		# All other props (terrain_tall, terrain_slope, terrain_slope_inner_corner, terrain_slope_outer_corner, terrain_mining, rocks, modules) get colliders.
		if mi.mesh != null and not _has_static_body_child(mi) and not mi.name.begins_with("terrain_low"):
			# True concave trimesh collision for crater/excavation hole tiles so players and entities can walk inside the crater
			if mi.name.begins_with("terrain_mining") or "mining" in mi.name.to_lower():
				mi.create_trimesh_collision()
			else:
				mi.create_convex_collision(true, false)
			for c in mi.get_children():
				if c is StaticBody3D:
					c.collision_layer = 1
					c.collision_mask = 1
					c.add_to_group("navigation_geometry")

	for child in node.get_children():
		# Do not add collisions to ground plane, perimeter barrier lines, demarcation line, atmospheric mist, or targets
		if child.name != "GroundBase" and child.name != "PerimeterBarriers" and child.name != "DemarcationLine" and child.name != "OuterAtmosphere" and child.name != "MapTrainingTargets" and not child.is_in_group("weapons_box") and not child.is_in_group("target"):
			_setup_prop_collisions(child)

func _has_static_body_child(node: Node) -> bool:
	for c in node.get_children():
		if c is StaticBody3D:
			return true
	return false

## Dynamically updates all theme-specific materials, lighting, sky, and fog.
func _update_theme_visuals() -> void:
	_update_ground_material_albedo()
	_update_demarcation_materials()
	_update_perimeter_material()
	_update_mist_material()
	_apply_theme_environment_and_sky()
	_reconfigure_theme_pois()

func _reconfigure_theme_pois() -> void:
	var nat_rocks : Node = get_node_or_null("Sector_NaturalRocks")
	var dig : Node = get_node_or_null("Sector_ResearchDig")
	var dock : Node = get_node_or_null("Sector_DockLogistics")
	_remove_nodes([nat_rocks, dig, dock])

	match map_theme:
		MapTheme.CANYON_WASTELAND:
			_spawn_wasteland_tactical_rocks()
		MapTheme.SPACE_BASE:
			_spawn_spacebase_pois()
		MapTheme.TRANSPORT_DOCK:
			_spawn_transportdock_pois()

func _update_ground_material_albedo() -> void:
	if _ground_material == null:
		return
	match map_theme:
		MapTheme.CANYON_WASTELAND:
			_ground_material.albedo_color = Color(0.6196, 0.2863, 0.1725, 1.0)
			_ground_material.roughness = 1.0
		MapTheme.SPACE_BASE:
			_ground_material.albedo_color = Color(0.30, 0.32, 0.36, 1.0)
			_ground_material.roughness = 0.95
		MapTheme.TRANSPORT_DOCK:
			_ground_material.albedo_color = Color(0.22, 0.24, 0.27, 1.0)
			_ground_material.roughness = 0.88

func _update_demarcation_materials() -> void:
	if _stripe_material != null:
		match map_theme:
			MapTheme.CANYON_WASTELAND:
				_stripe_material.albedo_color = Color(1.0, 0.62, 0.14, 1.0)
				_stripe_material.emission = Color(1.0, 0.52, 0.08)
				_stripe_material.emission_energy_multiplier = 3.2
			MapTheme.SPACE_BASE:
				_stripe_material.albedo_color = Color(0.20, 0.85, 1.0, 1.0)
				_stripe_material.emission = Color(0.15, 0.80, 1.0)
				_stripe_material.emission_energy_multiplier = 3.2
			MapTheme.TRANSPORT_DOCK:
				_stripe_material.albedo_color = Color(1.0, 0.78, 0.12, 1.0)
				_stripe_material.emission = Color(0.98, 0.72, 0.08)
				_stripe_material.emission_energy_multiplier = 3.2

	if _laser_material != null:
		match map_theme:
			MapTheme.CANYON_WASTELAND:
				_laser_material.albedo_color = Color(1.0, 0.55, 0.12, 0.8)
				_laser_material.emission = Color(1.0, 0.48, 0.06)
				_laser_material.emission_energy_multiplier = 2.8
			MapTheme.SPACE_BASE:
				_laser_material.albedo_color = Color(0.18, 0.85, 1.0, 0.8)
				_laser_material.emission = Color(0.12, 0.78, 0.98)
				_laser_material.emission_energy_multiplier = 2.8
			MapTheme.TRANSPORT_DOCK:
				_laser_material.albedo_color = Color(1.0, 0.76, 0.10, 0.8)
				_laser_material.emission = Color(0.95, 0.68, 0.06)
				_laser_material.emission_energy_multiplier = 2.8

func _update_perimeter_material() -> void:
	if _perimeter_material == null:
		return
	match map_theme:
		MapTheme.CANYON_WASTELAND:
			_perimeter_material.albedo_color = Color(1.0, 0.55, 0.15, 0.28)
			_perimeter_material.emission = Color(1.0, 0.45, 0.10)
			_perimeter_material.emission_energy_multiplier = 1.0
		MapTheme.SPACE_BASE:
			_perimeter_material.albedo_color = Color(0.15, 0.85, 1.0, 0.28)
			_perimeter_material.emission = Color(0.10, 0.75, 0.98)
			_perimeter_material.emission_energy_multiplier = 1.0
		MapTheme.TRANSPORT_DOCK:
			_perimeter_material.albedo_color = Color(1.0, 0.75, 0.10, 0.28)
			_perimeter_material.emission = Color(0.95, 0.65, 0.05)
			_perimeter_material.emission_energy_multiplier = 1.0

func _update_mist_material() -> void:
	if _mist_material == null:
		return
	match map_theme:
		MapTheme.CANYON_WASTELAND:
			_mist_material.albedo_color = Color(0.78, 0.44, 0.26, 0.07)
		MapTheme.SPACE_BASE:
			_mist_material.albedo_color = Color(0.18, 0.24, 0.38, 0.04)
		MapTheme.TRANSPORT_DOCK:
			_mist_material.albedo_color = Color(0.24, 0.32, 0.44, 0.06)

func _apply_theme_environment_and_sky() -> void:
	var tree : SceneTree = get_tree()
	var root : Node = tree.current_scene if tree != null else get_parent()
	if root == null:
		root = get_parent()
	if root == null:
		return

	var world_env : WorldEnvironment = root.find_child("WorldEnvironment", true, false) as WorldEnvironment
	var sun_light : DirectionalLight3D = root.find_child("DirectionalLight3D", true, false) as DirectionalLight3D
	var dnc : Node = root.find_child("DayNightCycle", true, false)

	if dnc != null and dnc.has_method("apply_theme"):
		dnc.call("apply_theme", int(map_theme))

	# Configure hard pixel-art shadows and crisp shadow map range on the directional sun light
	if sun_light != null:
		sun_light.shadow_enabled = true
		sun_light.shadow_blur = 0.0
		sun_light.shadow_bias = 0.03
		sun_light.shadow_normal_bias = 1.2
		sun_light.directional_shadow_max_distance = 48.0
		sun_light.directional_shadow_blend_splits = false

	if world_env != null and world_env.environment != null:
		var env : Environment = world_env.environment
		var sky : Sky = env.sky
		var sky_mat : ProceduralSkyMaterial = sky.sky_material as ProceduralSkyMaterial if sky != null else null

		match map_theme:
			MapTheme.CANYON_WASTELAND:
				if sky_mat != null:
					sky_mat.sky_top_color = Color(0.28, 0.38, 0.55, 1.0)
					sky_mat.sky_horizon_color = Color(0.85, 0.48, 0.28, 1.0)
					sky_mat.ground_bottom_color = Color(0.55, 0.24, 0.14, 1.0)
					sky_mat.ground_horizon_color = Color(0.62, 0.29, 0.17, 1.0)
				env.fog_light_color = Color(0.78, 0.44, 0.26, 1.0)
				env.fog_density = 0.0035
				env.fog_aerial_perspective = 0.55
				env.fog_sky_affect = 0.6
				if sun_light != null:
					sun_light.light_color = Color(1.0, 0.88, 0.72, 1.0)
					sun_light.light_energy = 1.30

			MapTheme.SPACE_BASE:
				if sky_mat != null:
					sky_mat.sky_top_color = Color(0.04, 0.06, 0.12, 1.0)
					sky_mat.sky_horizon_color = Color(0.12, 0.18, 0.28, 1.0)
					sky_mat.ground_bottom_color = Color(0.08, 0.10, 0.14, 1.0)
					sky_mat.ground_horizon_color = Color(0.20, 0.22, 0.26, 1.0)
				env.fog_light_color = Color(0.16, 0.22, 0.32, 1.0)
				env.fog_density = 0.0018
				env.fog_aerial_perspective = 0.30
				env.fog_sky_affect = 0.4
				if sun_light != null:
					sun_light.light_color = Color(0.96, 0.98, 1.0, 1.0)
					sun_light.light_energy = 1.45

			MapTheme.TRANSPORT_DOCK:
				if sky_mat != null:
					sky_mat.sky_top_color = Color(0.08, 0.12, 0.20, 1.0)
					sky_mat.sky_horizon_color = Color(0.25, 0.35, 0.48, 1.0)
					sky_mat.ground_bottom_color = Color(0.10, 0.12, 0.15, 1.0)
					sky_mat.ground_horizon_color = Color(0.18, 0.22, 0.26, 1.0)
				env.fog_light_color = Color(0.22, 0.30, 0.40, 1.0)
				env.fog_density = 0.0028
				env.fog_aerial_perspective = 0.45
				env.fog_sky_affect = 0.5
				if sun_light != null:
					sun_light.light_color = Color(0.88, 0.92, 1.0, 1.0)
					sun_light.light_energy = 1.25
