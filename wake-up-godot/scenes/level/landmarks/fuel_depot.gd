class_name FuelDepot
extends Node3D

## Cryogenic propellant fueling depot and storage tank farm for Transport Dock.
## Includes dual pressurized tanks, safety relief valves, containment berm,
## and hazard warning lights.

@export var tank_radius : float = 0.9
@export var tank_length : float = 4.2

func _ready() -> void:
	_build_depot()

func _build_depot() -> void:
	var tank_mat := StandardMaterial3D.new()
	tank_mat.albedo_color = Color(0.85, 0.88, 0.90, 1.0)
	tank_mat.metallic = 0.75
	tank_mat.roughness = 0.25

	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = Color(0.28, 0.30, 0.34, 1.0)
	frame_mat.metallic = 0.9
	frame_mat.roughness = 0.4

	var hazard_mat := StandardMaterial3D.new()
	hazard_mat.albedo_color = Color(1.0, 0.65, 0.05, 1.0)
	hazard_mat.emission_enabled = true
	hazard_mat.emission = Color(1.0, 0.60, 0.04)
	hazard_mat.emission_energy_multiplier = 2.0

	# 1. Concrete Containment Foundation Berm
	var berm := MeshInstance3D.new()
	var b_box := BoxMesh.new()
	b_box.size = Vector3(tank_length + 1.2, 0.25, 4.4)
	berm.mesh = b_box
	berm.material_override = frame_mat
	berm.position = Vector3(0.0, 0.125, 0.0)
	add_child(berm)

	# 2. Dual Horizontal Pressure Tanks
	for sign_z in [-1.0, 1.0]:
		var tank_z : float = sign_z * 1.2
		var tank_y : float = tank_radius + 0.35

		# Main cylinder body
		var tank := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = tank_radius
		cyl.bottom_radius = tank_radius
		cyl.height = tank_length
		cyl.radial_segments = 14
		tank.mesh = cyl
		tank.material_override = tank_mat
		tank.position = Vector3(0.0, tank_y, tank_z)
		tank.rotation_degrees.z = 90.0
		add_child(tank)

		# Hemispherical End Caps
		for sign_x in [-1.0, 1.0]:
			var cap := MeshInstance3D.new()
			var sph := SphereMesh.new()
			sph.radius = tank_radius
			sph.height = tank_radius * 2.0
			cap.mesh = sph
			cap.material_override = tank_mat
			cap.position = Vector3(sign_x * (tank_length * 0.5), tank_y, tank_z)
			add_child(cap)

		# Saddle support cradles
		for sign_x in [-1.0, 1.0]:
			var saddle := MeshInstance3D.new()
			var s_box := BoxMesh.new()
			s_box.size = Vector3(0.35, tank_y, tank_radius * 2.2)
			saddle.mesh = s_box
			saddle.material_override = frame_mat
			saddle.position = Vector3(sign_x * (tank_length * 0.35), tank_y * 0.5, tank_z)
			add_child(saddle)

		# Top relief valve & hazard beacon
		var valve := MeshInstance3D.new()
		var v_box := BoxMesh.new()
		v_box.size = Vector3(0.3, 0.4, 0.3)
		valve.mesh = v_box
		valve.material_override = hazard_mat
		valve.position = Vector3(0.0, tank_y + tank_radius + 0.2, tank_z)
		add_child(valve)

	# StaticBody collider for the fuel depot
	var sb := StaticBody3D.new()
	sb.name = "FuelDepotStaticBody"
	sb.collision_layer = 1
	sb.collision_mask = 1
	sb.add_to_group("navigation_geometry")

	var col := CollisionShape3D.new()
	var box_col := BoxShape3D.new()
	box_col.size = Vector3(tank_length + 1.2, tank_radius * 2.0 + 0.6, 4.4)
	col.shape = box_col
	col.position = Vector3(0.0, (tank_radius * 2.0 + 0.6) * 0.5, 0.0)
	sb.add_child(col)

	add_child(sb)
