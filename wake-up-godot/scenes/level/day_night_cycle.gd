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

# Sun colors across the day
const COLOR_DAY : Color = Color(1.0, 0.96, 0.90, 1.0)
const COLOR_SUNRISE : Color = Color(1.0, 0.65, 0.35, 1.0)
const COLOR_SUNSET : Color = Color(0.98, 0.48, 0.22, 1.0)
const COLOR_NIGHT : Color = Color(0.28, 0.42, 0.75, 1.0) # Cool moonlight

# Sky colors across the day
const SKY_DAY_TOP : Color = Color(0.32, 0.48, 0.75, 1.0)
const SKY_DAY_HORIZON : Color = Color(0.72, 0.55, 0.42, 1.0)

const SKY_SUNSET_TOP : Color = Color(0.25, 0.18, 0.42, 1.0)
const SKY_SUNSET_HORIZON : Color = Color(0.85, 0.35, 0.22, 1.0)

const SKY_NIGHT_TOP : Color = Color(0.03, 0.04, 0.10, 1.0)
const SKY_NIGHT_HORIZON : Color = Color(0.08, 0.12, 0.22, 1.0)

func _ready() -> void:
	add_to_group("day_night_cycle")
	_find_nodes()
	_configure_lighting()
	_update_lighting(0.0)

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
		light_col = COLOR_DAY
		light_energy = 1.35
	elif elevation > 0.0:
		# Sunrise / Sunset transition
		var dawn_ratio : float = elevation / 0.3
		var horizon_col : Color = COLOR_SUNRISE if time_of_day < 0.5 else COLOR_SUNSET
		light_col = horizon_col.lerp(COLOR_DAY, dawn_ratio)
		light_energy = lerpf(0.9, 1.35, dawn_ratio)
	elif elevation > -0.2:
		# Twilight dusk into night
		var dusk_ratio : float = (elevation + 0.2) / 0.2
		var twilight_col : Color = COLOR_SUNSET if time_of_day > 0.5 else COLOR_SUNRISE
		light_col = COLOR_NIGHT.lerp(twilight_col, dusk_ratio)
		light_energy = lerpf(0.38, 0.9, dusk_ratio)
	else:
		# Night (moonlight)
		light_col = COLOR_NIGHT
		light_energy = 0.38

	sun_light.light_color = light_col
	sun_light.light_energy = light_energy

	# Modulate sky colors if available
	if sky_material != null:
		var sky_top : Color
		var sky_horiz : Color
		if elevation > 0.2:
			sky_top = SKY_DAY_TOP
			sky_horiz = SKY_DAY_HORIZON
		elif elevation > 0.0:
			var t : float = elevation / 0.2
			sky_top = SKY_SUNSET_TOP.lerp(SKY_DAY_TOP, t)
			sky_horiz = SKY_SUNSET_HORIZON.lerp(SKY_DAY_HORIZON, t)
		elif elevation > -0.25:
			var t : float = (elevation + 0.25) / 0.25
			sky_top = SKY_NIGHT_TOP.lerp(SKY_SUNSET_TOP, t)
			sky_horiz = SKY_NIGHT_HORIZON.lerp(SKY_SUNSET_HORIZON, t)
		else:
			sky_top = SKY_NIGHT_TOP
			sky_horiz = SKY_NIGHT_HORIZON

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
