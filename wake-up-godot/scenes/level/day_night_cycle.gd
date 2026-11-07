class_name DayNightCycle
extends Node

## Dynamic Day / Night cycle system with atmospheric lighting transitions,
## rotating sun/moon directional lighting, dramatic shadows, and sky color modulation.

@export var day_duration : float = 120.0 # Seconds per full 24h cycle
@export var time_of_day : float = 0.38  # 0.0 = midnight, 0.25 = sunrise, 0.5 = noon, 0.75 = sunset
@export var is_paused : bool = false

var sun_light : DirectionalLight3D = null
var world_env : WorldEnvironment = null
var sky_material : ProceduralSkyMaterial = null

# Theme-aware Sun colors across the day
var color_day : Color = Color(1.0, 0.96, 0.90, 1.0)
var color_sunrise : Color = Color(1.0, 0.65, 0.35, 1.0)
var color_sunset : Color = Color(0.98, 0.48, 0.22, 1.0)
var color_night : Color = Color(0.28, 0.42, 0.75, 1.0) # Cool moonlight

var sun_energy_day : float = 1.35
var sun_energy_twilight : float = 0.90
var sun_energy_night : float = 0.38

# Theme-aware Sky colors across the day
var sky_day_top : Color = Color(0.32, 0.48, 0.75, 1.0)
var sky_day_horizon : Color = Color(0.72, 0.55, 0.42, 1.0)

var sky_sunset_top : Color = Color(0.25, 0.18, 0.42, 1.0)
var sky_sunset_horizon : Color = Color(0.85, 0.35, 0.22, 1.0)

var sky_night_top : Color = Color(0.03, 0.04, 0.10, 1.0)
var sky_night_horizon : Color = Color(0.08, 0.12, 0.22, 1.0)

var current_theme : int = 1

func _ready() -> void:
	add_to_group("day_night_cycle")
	_find_nodes()
	_detect_and_apply_theme()
	_configure_lighting()
	_update_lighting(0.0)

func _detect_and_apply_theme() -> void:
	var hud : Node = get_node_or_null("/root/PlayerHealthHud")
	if hud != null and "selected_map_theme" in hud:
		apply_theme(int(hud.selected_map_theme))
		return
	var root := get_tree().current_scene if get_tree() != null else get_parent()
	if root != null:
		var sm : Node = root.find_child("SpaceStationMap", true, false)
		if sm == null and root is SpaceStationMap:
			sm = root
		if sm != null and "map_theme" in sm:
			apply_theme(int(sm.map_theme))

## Applies lighting and atmospheric color palettes tailored to each map theme's visual identity.
func apply_theme(theme_id: int) -> void:
	current_theme = theme_id
	match theme_id:
		0: # CANYON_WASTELAND (Fiery sandstone canyon sunset & warm Martian skies)
			color_day = Color(1.0, 0.88, 0.72, 1.0)
			color_sunrise = Color(1.0, 0.62, 0.30, 1.0)
			color_sunset = Color(0.98, 0.46, 0.22, 1.0)
			color_night = Color(0.32, 0.28, 0.48, 1.0)
			sun_energy_day = 1.30
			sun_energy_twilight = 0.95
			sun_energy_night = 0.35
			sky_day_top = Color(0.28, 0.38, 0.55, 1.0)
			sky_day_horizon = Color(0.85, 0.48, 0.28, 1.0)
			sky_sunset_top = Color(0.24, 0.16, 0.38, 1.0)
			sky_sunset_horizon = Color(0.88, 0.38, 0.22, 1.0)
			sky_night_top = Color(0.04, 0.05, 0.12, 1.0)
			sky_night_horizon = Color(0.12, 0.15, 0.26, 1.0)

		1: # SPACE_BASE (Deep cosmic starry night sky & intense solar white daylight)
			color_day = Color(0.96, 0.98, 1.0, 1.0)
			color_sunrise = Color(0.88, 0.92, 1.0, 1.0)
			color_sunset = Color(0.72, 0.78, 0.95, 1.0)
			color_night = Color(0.20, 0.30, 0.55, 1.0)
			sun_energy_day = 1.45
			sun_energy_twilight = 0.88
			sun_energy_night = 0.30
			sky_day_top = Color(0.04, 0.06, 0.12, 1.0)
			sky_day_horizon = Color(0.12, 0.18, 0.28, 1.0)
			sky_sunset_top = Color(0.06, 0.08, 0.18, 1.0)
			sky_sunset_horizon = Color(0.16, 0.22, 0.35, 1.0)
			sky_night_top = Color(0.02, 0.03, 0.08, 1.0)
			sky_night_horizon = Color(0.05, 0.08, 0.16, 1.0)

		2: # TRANSPORT DOCK (Aerospace twilight, steel blue dusk & industrial tarmac)
			color_day = Color(0.88, 0.92, 1.0, 1.0)
			color_sunrise = Color(0.95, 0.78, 0.58, 1.0)
			color_sunset = Color(0.82, 0.58, 0.48, 1.0)
			color_night = Color(0.22, 0.32, 0.52, 1.0)
			sun_energy_day = 1.25
			sun_energy_twilight = 0.92
			sun_energy_night = 0.35
			sky_day_top = Color(0.08, 0.12, 0.20, 1.0)
			sky_day_horizon = Color(0.25, 0.35, 0.48, 1.0)
			sky_sunset_top = Color(0.12, 0.15, 0.25, 1.0)
			sky_sunset_horizon = Color(0.35, 0.38, 0.48, 1.0)
			sky_night_top = Color(0.03, 0.05, 0.10, 1.0)
			sky_night_horizon = Color(0.08, 0.12, 0.20, 1.0)

func _find_nodes() -> void:
	var root := get_tree().current_scene if get_tree() != null else get_parent()
	if root != null:
		sun_light = root.find_child("DirectionalLight3D", true, false) as DirectionalLight3D
		world_env = root.find_child("WorldEnvironment", true, false) as WorldEnvironment

	if world_env != null and world_env.environment != null:
		var sky : Sky = world_env.environment.sky
		if sky != null and sky.sky_material is ProceduralSkyMaterial:
			sky_material = sky.sky_material as ProceduralSkyMaterial

func _configure_lighting() -> void:
	if sun_light != null:
		sun_light.shadow_enabled = true
		sun_light.shadow_bias = 0.04
		sun_light.shadow_normal_bias = 1.5
		sun_light.shadow_blur = 0.8
		sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		sun_light.directional_shadow_max_distance = 90.0
		sun_light.directional_shadow_pancake_size = 0.0
		sun_light.directional_shadow_blend_splits = true

func _process(delta: float) -> void:
	if not is_paused and day_duration > 0.0:
		time_of_day = fmod(time_of_day + delta / day_duration, 1.0)
	_update_lighting(delta)

func _update_lighting(_delta: float) -> void:
	if sun_light == null:
		_find_nodes()
		if sun_light == null:
			return

	# Calculate sun angle across the sky (0.25 = sunrise, 0.5 = zenith, 0.75 = sunset)
	var sun_angle : float = (time_of_day - 0.25) * TAU
	var elevation : float = sin(sun_angle)
	var is_day : bool = elevation > 0.0

	# Pitch always comes down from the sky (-18 deg to -78 deg) so shadows are always cast downward onto ground
	var celestial_elev : float = maxf(elevation, 0.12) if is_day else maxf(-elevation, 0.12)
	var pitch : float = -lerpf(deg_to_rad(18.0), deg_to_rad(78.0), celestial_elev)
	# Continuous azimuth transition across the day without 180-degree snapping
	var yaw : float = deg_to_rad(-35.0) if is_day else deg_to_rad(145.0)
	# Smoothly blend yaw across horizon transition
	if absf(elevation) < 0.15:
		var blend_t : float = (elevation + 0.15) / 0.30
		yaw = lerp_angle(deg_to_rad(145.0), deg_to_rad(-35.0), blend_t)
	sun_light.rotation = Vector3(pitch, yaw, 0.0)

	# Dynamic sun energy & color blending
	var light_col : Color
	var light_energy : float

	if elevation > 0.3:
		# Midday
		light_col = color_day
		light_energy = sun_energy_day
	elif elevation > 0.0:
		# Sunrise / Sunset transition
		var dawn_ratio : float = elevation / 0.3
		var horizon_col : Color = color_sunrise if time_of_day < 0.5 else color_sunset
		light_col = horizon_col.lerp(color_day, dawn_ratio)
		light_energy = lerpf(sun_energy_twilight, sun_energy_day, dawn_ratio)
	elif elevation > -0.2:
		# Twilight dusk into night
		var dusk_ratio : float = (elevation + 0.2) / 0.2
		var twilight_col : Color = color_sunset if time_of_day > 0.5 else color_sunrise
		light_col = color_night.lerp(twilight_col, dusk_ratio)
		light_energy = lerpf(sun_energy_night, sun_energy_twilight, dusk_ratio)
	else:
		# Night (moonlight)
		light_col = color_night
		light_energy = sun_energy_night

	sun_light.light_color = light_col
	sun_light.light_energy = light_energy

	# Modulate sky colors if available
	if sky_material != null:
		var sky_top : Color
		var sky_horiz : Color
		if elevation > 0.2:
			sky_top = sky_day_top
			sky_horiz = sky_day_horizon
		elif elevation > 0.0:
			var t : float = elevation / 0.2
			sky_top = sky_sunset_top.lerp(sky_day_top, t)
			sky_horiz = sky_sunset_horizon.lerp(sky_day_horizon, t)
		elif elevation > -0.25:
			var t : float = (elevation + 0.25) / 0.25
			sky_top = sky_night_top.lerp(sky_sunset_top, t)
			sky_horiz = sky_night_horizon.lerp(sky_sunset_horizon, t)
		else:
			sky_top = sky_night_top
			sky_horiz = sky_night_horizon

		sky_material.sky_top_color = sky_top
		sky_material.sky_horizon_color = sky_horiz

## Preset time scrubber helpers (for sandbox mode)
func set_time_preset(preset: String) -> void:
	match preset.to_lower():
		"morning", "sunrise":
			time_of_day = 0.26
		"noon", "midday":
			time_of_day = 0.5
		"sunset", "dusk":
			time_of_day = 0.74
		"night", "midnight":
			time_of_day = 0.96
