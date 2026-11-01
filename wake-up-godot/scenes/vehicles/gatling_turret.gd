class_name GatlingTurret
extends Node3D

## Heavy motorized rotary Gatling Cannon turret mounted in the rear bed of the Space Truck.
## Inspired by the M12 Warthog from Halo:
## Features motorized hydraulic bed deployment, dynamic 360-degree target tracking,
## quad-barrel rotary spin, muzzle flashes, and devastating kinetic projectile fire.

signal deployed()
signal retracted()
signal fired(bullet: Area3D)

const BULLET_SCENE : PackedScene = preload("res://scenes/projectiles/bullet.tscn")
const FIRE_RATE_INTERVAL : float = 0.09 # ~660 RPM heavy rotary fire
const ROTOR_MAX_SPEED : float = 38.0 # Radians per second peak spin
const DEPLOY_HEIGHT : float = 0.18
const STOW_HEIGHT : float = 0.02
const STOW_PITCH : float = -0.45

var is_deployed : bool = false
var is_deploying : bool = false
var is_retracting : bool = false

var _fire_cooldown : float = 0.0
var _rotor_spin_speed : float = 0.0
var _recoil_offset : float = 0.0
var _vehicle : CharacterBody3D = null

# Node references
var hatch_left : MeshInstance3D = null
var hatch_right : MeshInstance3D = null
var mount_base : Node3D = null
var hydraulic_riser : Node3D = null
var turret_swivel : Node3D = null
var elevation_yoke : Node3D = null
var gun_chassis : MeshInstance3D = null
var ammo_drum : MeshInstance3D = null
var rotor_hub : Node3D = null
var muzzle_marker : Marker3D = null
var muzzle_flash : MeshInstance3D = null
var flash_light : OmniLight3D = null
var flash_timer : float = 0.0

func _ready() -> void:
	var p : Node = get_parent()
	while p != null:
		if p is CharacterBody3D:
			_vehicle = p as CharacterBody3D
			break
		p = p.get_parent()
	_build_turret_geometry()
	_apply_stow_posture()

## Assembles the procedural Warthog-style Gatling Cannon turret model.
func _build_turret_geometry() -> void:
	# Materials
	var dark_metal := StandardMaterial3D.new()
	dark_metal.albedo_color = Color(0.18, 0.20, 0.24)
	dark_metal.metallic = 0.92
	dark_metal.roughness = 0.22

	var chrome_mat := StandardMaterial3D.new()
	chrome_mat.albedo_color = Color(0.85, 0.88, 0.92)
	chrome_mat.metallic = 0.98
	chrome_mat.roughness = 0.12

	var olive_drum_mat := StandardMaterial3D.new()
	olive_drum_mat.albedo_color = Color(0.32, 0.36, 0.28)
	olive_drum_mat.metallic = 0.65
	olive_drum_mat.roughness = 0.42

	var flash_mat := StandardMaterial3D.new()
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.albedo_color = Color(1.0, 0.88, 0.35)

	# 1. Deck Hatch Doors (flush with truck bed)
	var hatch_mat := StandardMaterial3D.new()
	hatch_mat.albedo_color = Color(0.22, 0.25, 0.28)
	hatch_mat.metallic = 0.8
	hatch_mat.roughness = 0.35

	hatch_left = MeshInstance3D.new()
	hatch_left.name = "HatchLeft"
	var h_box_l := BoxMesh.new()
	h_box_l.size = Vector3(0.18, 0.02, 0.42)
	hatch_left.mesh = h_box_l
	hatch_left.material_override = hatch_mat
	hatch_left.position = Vector3(-0.09, 0.02, 0.0)
	add_child(hatch_left)

	hatch_right = MeshInstance3D.new()
	hatch_right.name = "HatchRight"
	var h_box_r := BoxMesh.new()
	h_box_r.size = Vector3(0.18, 0.02, 0.42)
	hatch_right.mesh = h_box_r
	hatch_right.material_override = hatch_mat
	hatch_right.position = Vector3(0.09, 0.02, 0.0)
	add_child(hatch_right)

	# 2. Base Mount & Hydraulic Riser
	mount_base = Node3D.new()
	mount_base.name = "MountBase"
	add_child(mount_base)

	# Bed mounting socket collar deeply grounded in truck chassis
	var pedestal := MeshInstance3D.new()
	pedestal.name = "MountPedestal"
	var cyl_pedestal := CylinderMesh.new()
	cyl_pedestal.top_radius = 0.19
	cyl_pedestal.bottom_radius = 0.22
	cyl_pedestal.height = 0.12
	pedestal.mesh = cyl_pedestal
	pedestal.material_override = dark_metal
	pedestal.position.y = -0.04
	mount_base.add_child(pedestal)

	var flange := MeshInstance3D.new()
	flange.name = "BaseFlange"
	var cyl_flange := CylinderMesh.new()
	cyl_flange.top_radius = 0.16
	cyl_flange.bottom_radius = 0.18
	cyl_flange.height = 0.04
	flange.mesh = cyl_flange
	flange.material_override = dark_metal
	flange.position.y = 0.02
	mount_base.add_child(flange)

	hydraulic_riser = Node3D.new()
	hydraulic_riser.name = "HydraulicRiser"
	hydraulic_riser.position.y = STOW_HEIGHT
	mount_base.add_child(hydraulic_riser)

	var piston := MeshInstance3D.new()
	piston.name = "PistonShaft"
	var cyl_piston := CylinderMesh.new()
	cyl_piston.top_radius = 0.065
	cyl_piston.bottom_radius = 0.075
	cyl_piston.height = 0.22
	piston.mesh = cyl_piston
	piston.material_override = chrome_mat
	piston.position.y = 0.11
	hydraulic_riser.add_child(piston)

	# 3. Turret Azimuth Swivel (Yaw 360)
	turret_swivel = Node3D.new()
	turret_swivel.name = "TurretSwivel"
	turret_swivel.position.y = 0.22
	hydraulic_riser.add_child(turret_swivel)

	# Forward gunner armor shield (Halo Warthog-inspired frontal plate)
	var shield := MeshInstance3D.new()
	shield.name = "ArmorShield"
	var s_box := BoxMesh.new()
	s_box.size = Vector3(0.36, 0.28, 0.03)
	shield.mesh = s_box
	shield.material_override = dark_metal
	shield.position = Vector3(0.0, 0.10, 0.12)
	turret_swivel.add_child(shield)

	# 4. Elevation Yoke (Pitch -25 to +40)
	elevation_yoke = Node3D.new()
	elevation_yoke.name = "ElevationYoke"
	elevation_yoke.position.y = 0.12
	turret_swivel.add_child(elevation_yoke)

	# Receiver chassis
	gun_chassis = MeshInstance3D.new()
	gun_chassis.name = "GunChassis"
	var c_box := BoxMesh.new()
	c_box.size = Vector3(0.18, 0.18, 0.38)
	gun_chassis.mesh = c_box
	gun_chassis.material_override = dark_metal
	gun_chassis.position = Vector3(0.0, 0.0, 0.0)
	elevation_yoke.add_child(gun_chassis)

	# Heavy side cylindrical ammo drum
	ammo_drum = MeshInstance3D.new()
	ammo_drum.name = "AmmoDrum"
	var drum_cyl := CylinderMesh.new()
	drum_cyl.top_radius = 0.10
	drum_cyl.bottom_radius = 0.10
	drum_cyl.height = 0.14
	ammo_drum.mesh = drum_cyl
	ammo_drum.material_override = olive_drum_mat
	ammo_drum.position = Vector3(-0.16, 0.0, -0.04)
	ammo_drum.rotation_degrees = Vector3(0, 0, 90)
	elevation_yoke.add_child(ammo_drum)

	# 5. Rotor Hub & Quad Gatling Barrels
	rotor_hub = Node3D.new()
	rotor_hub.name = "BarrelsRotor"
	rotor_hub.position = Vector3(0.0, 0.0, 0.19)
	elevation_yoke.add_child(rotor_hub)

	var hub_mesh := MeshInstance3D.new()
	hub_mesh.name = "HubCore"
	var hub_cyl := CylinderMesh.new()
	hub_cyl.top_radius = 0.06
	hub_cyl.bottom_radius = 0.06
	hub_cyl.height = 0.08
	hub_mesh.mesh = hub_cyl
	hub_mesh.material_override = dark_metal
	hub_mesh.rotation_degrees = Vector3(90, 0, 0)
	rotor_hub.add_child(hub_mesh)

	# 4 heavy rotating barrels arranged radially
	for i in range(4):
		var angle : float = float(i) * (PI * 0.5)
		var b_mesh := MeshInstance3D.new()
		b_mesh.name = "Barrel_%d" % i
		var b_cyl := CylinderMesh.new()
		b_cyl.top_radius = 0.016
		b_cyl.bottom_radius = 0.016
		b_cyl.height = 0.44
		b_cyl.radial_segments = 8
		b_mesh.mesh = b_cyl
		b_mesh.material_override = dark_metal
		b_mesh.position = Vector3(cos(angle) * 0.046, sin(angle) * 0.046, 0.22)
		b_mesh.rotation_degrees = Vector3(90, 0, 0)
		rotor_hub.add_child(b_mesh)

	# Stabilizing clamp ring & muzzle brake
	var clamp_mesh := MeshInstance3D.new()
	clamp_mesh.name = "SupportRing"
	var ring_cyl := CylinderMesh.new()
	ring_cyl.top_radius = 0.068
	ring_cyl.bottom_radius = 0.068
	ring_cyl.height = 0.025
	clamp_mesh.mesh = ring_cyl
	clamp_mesh.material_override = chrome_mat
	clamp_mesh.position = Vector3(0.0, 0.0, 0.28)
	clamp_mesh.rotation_degrees = Vector3(90, 0, 0)
	rotor_hub.add_child(clamp_mesh)

	var brake_mesh := MeshInstance3D.new()
	brake_mesh.name = "MuzzleBrake"
	var brake_cyl := CylinderMesh.new()
	brake_cyl.top_radius = 0.07
	brake_cyl.bottom_radius = 0.07
	brake_cyl.height = 0.035
	brake_mesh.mesh = brake_cyl
	brake_mesh.material_override = dark_metal
	brake_mesh.position = Vector3(0.0, 0.0, 0.44)
	brake_mesh.rotation_degrees = Vector3(90, 0, 0)
	rotor_hub.add_child(brake_mesh)

	# 6. Muzzle Marker & Flash
	muzzle_marker = Marker3D.new()
	muzzle_marker.name = "MuzzleMarker"
	muzzle_marker.position = Vector3(0.0, 0.0, 0.68)
	elevation_yoke.add_child(muzzle_marker)

	muzzle_flash = MeshInstance3D.new()
	muzzle_flash.name = "MuzzleFlash"
	var f_mesh := BoxMesh.new()
	f_mesh.size = Vector3(0.14, 0.14, 0.14)
	muzzle_flash.mesh = f_mesh
	muzzle_flash.material_override = flash_mat
	muzzle_flash.position = Vector3(0.0, 0.0, 0.70)
	muzzle_flash.visible = false
	elevation_yoke.add_child(muzzle_flash)

	flash_light = OmniLight3D.new()
	flash_light.name = "FlashLight"
	flash_light.light_color = Color(1.0, 0.85, 0.4)
	flash_light.light_energy = 0.0
	flash_light.omni_range = 3.5
	flash_light.position = Vector3(0.0, 0.0, 0.72)
	elevation_yoke.add_child(flash_light)

func _apply_stow_posture() -> void:
	is_deployed = false
	is_deploying = false
	is_retracting = false
	if hydraulic_riser != null:
		hydraulic_riser.position.y = STOW_HEIGHT
	if elevation_yoke != null:
		elevation_yoke.rotation.x = STOW_PITCH
	if turret_swivel != null:
		turret_swivel.rotation.y = 0.0
	if hatch_left != null:
		hatch_left.position.x = -0.09
	if hatch_right != null:
		hatch_right.position.x = 0.09
	visible = false

## Triggers the dramatic deployment animation when the Explorer operative boards the Space Truck.
func deploy() -> void:
	if is_deployed or is_deploying:
		return
	is_deploying = true
	is_retracting = false
	visible = true

	var snd : Node = get_node_or_null("/root/UiSound")
	if snd != null and snd.has_method("play_turret_deploy"):
		snd.call("play_turret_deploy", 0.01)

	var tween : Tween = create_tween().set_parallel(true)

	# 1. Slide open the bed deck hatches
	if hatch_left != null:
		tween.tween_property(hatch_left, "position:x", -0.24, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if hatch_right != null:
		tween.tween_property(hatch_right, "position:x", 0.24, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# 2. Hydraulic column powers up from the bed
	if hydraulic_riser != null:
		tween.tween_property(hydraulic_riser, "position:y", DEPLOY_HEIGHT, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# 3. Gatling elevation tilts up into combat ready posture
	if elevation_yoke != null:
		tween.tween_property(elevation_yoke, "rotation:x", 0.0, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# 4. Spool test spin on barrels
	if rotor_hub != null:
		tween.tween_property(rotor_hub, "rotation:z", TAU * 1.5, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tween.chain().tween_callback(func():
		is_deployed = true
		is_deploying = false
		deployed.emit()
	)

## Smoothly retracts the Gatling Turret back into the rear truck bed when the driver exits.
func retract() -> void:
	if not is_deployed and not is_deploying:
		return
	is_retracting = true
	is_deploying = false

	var tween : Tween = create_tween().set_parallel(true)

	# 1. Swivel centers forward
	if turret_swivel != null:
		tween.tween_property(turret_swivel, "rotation:y", 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	# 2. Elevation tilts down to stow
	if elevation_yoke != null:
		tween.tween_property(elevation_yoke, "rotation:x", STOW_PITCH, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# 3. Hydraulic column descends into truck bed
	if hydraulic_riser != null:
		tween.tween_property(hydraulic_riser, "position:y", STOW_HEIGHT, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	# 4. Slide deck hatch doors closed
	if hatch_left != null:
		tween.chain().tween_property(hatch_left, "position:x", -0.09, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if hatch_right != null:
		tween.chain().tween_property(hatch_right, "position:x", 0.09, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tween.chain().tween_callback(func():
		is_deployed = false
		is_retracting = false
		visible = false
		retracted.emit()
	)

func _process(delta: float) -> void:
	if _fire_cooldown > 0.0:
		_fire_cooldown = maxf(_fire_cooldown - delta, 0.0)

	# Flash decay
	if flash_timer > 0.0:
		flash_timer = maxf(flash_timer - delta, 0.0)
		if flash_timer <= 0.0:
			if muzzle_flash != null: muzzle_flash.visible = false
			if flash_light != null: flash_light.light_energy = 0.0

	# Barrel spin inertia
	if rotor_hub != null and _rotor_spin_speed > 0.001:
		rotor_hub.rotation.z += _rotor_spin_speed * delta
		_rotor_spin_speed = move_toward(_rotor_spin_speed, 0.0, 16.0 * delta)

	# Recoil recovery
	if elevation_yoke != null and absf(_recoil_offset) > 0.0001:
		_recoil_offset = move_toward(_recoil_offset, 0.0, 0.35 * delta)
		elevation_yoke.position.z = _recoil_offset

## Dynamically tracks the mouse cursor / aim target in 3D world space.
func track_aim(aim_target: Vector3, delta: float) -> void:
	if not is_deployed or is_retracting or turret_swivel == null or elevation_yoke == null:
		return

	# Calculate heading vector from turret swivel in truck local coordinates
	var local_target : Vector3 = turret_swivel.get_parent().to_local(aim_target) - turret_swivel.position
	if local_target.length_squared() < 0.001:
		return

	var target_yaw : float = atan2(local_target.x, local_target.z)
	turret_swivel.rotation.y = lerp_angle(turret_swivel.rotation.y, target_yaw, minf(16.0 * delta, 1.0))

	# Calculate pitch elevation
	var dist_xz : float = Vector2(local_target.x, local_target.z).length()
	var target_pitch : float = -atan2(local_target.y, dist_xz)
	target_pitch = clampf(target_pitch, deg_to_rad(-22.0), deg_to_rad(38.0))
	elevation_yoke.rotation.x = lerpf(elevation_yoke.rotation.x, target_pitch, minf(14.0 * delta, 1.0))

## Fires rapid heavy kinetic Gatling rounds with spinning barrels, flash, and recoil.
func fire(aim_target: Vector3) -> Area3D:
	if not is_deployed or is_retracting or _fire_cooldown > 0.0:
		return null

	_fire_cooldown = FIRE_RATE_INTERVAL
	_rotor_spin_speed = ROTOR_MAX_SPEED

	var spawn_pos : Vector3 = muzzle_marker.global_position if muzzle_marker != null else global_position
	var aim_dir : Vector3 = (aim_target - spawn_pos).normalized()
	if aim_dir.is_zero_approx():
		aim_dir = -elevation_yoke.global_transform.basis.z

	var bullet : Area3D = BULLET_SCENE.instantiate() as Area3D
	bullet.shooter = _vehicle if _vehicle != null else self
	bullet.direction = aim_dir
	bullet.damage = 32
	bullet.speed = 24.0
	bullet.decal_scale = 0.40
	get_tree().root.add_child(bullet)
	bullet.global_position = spawn_pos

	# Visual effects
	if muzzle_flash != null:
		muzzle_flash.visible = true
		muzzle_flash.rotation.z = randf() * TAU
	if flash_light != null:
		flash_light.light_energy = 3.2
	flash_timer = 0.04

	# Physical recoil kick
	_recoil_offset = -0.04
	if elevation_yoke != null:
		elevation_yoke.position.z = _recoil_offset

	# Audio feedback
	var snd : Node = get_node_or_null("/root/UiSound")
	if snd != null and snd.has_method("play_vehicle_cannon"):
		snd.call("play_vehicle_cannon", 0.08)

	fired.emit(bullet)
	return bullet
