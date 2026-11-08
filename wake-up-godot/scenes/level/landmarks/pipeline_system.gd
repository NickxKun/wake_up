class_name PipelineSystem
extends Node3D

## Modular industrial pipeline conduit segment with support stanchions,
## flanges, and pressure indicator rings for Space Base.

@export var length : float = 8.0
@export var pipe_radius : float = 0.22
@export var pipe_height : float = 0.45
@export var pipe_color : Color = Color(0.70, 0.74, 0.78, 1.0)
@export var support_color : Color = Color(0.25, 0.28, 0.32, 1.0)
@export var stripe_color : Color = Color(0.15, 0.82, 0.95, 1.0)

func _ready() -> void:
	_build_pipeline()

func _build_pipeline() -> void:
	var pipe_mat := StandardMaterial3D.new()
	pipe_mat.albedo_color = pipe_color
	pipe_mat.metallic = 0.8
	pipe_mat.roughness = 0.3

	var support_mat := StandardMaterial3D.new()
	support_mat.albedo_color = support_color
	support_mat.metallic = 0.9
	support_mat.roughness = 0.4

	var stripe_mat := StandardMaterial3D.new()
	stripe_mat.albedo_color = stripe_color
	stripe_mat.emission_enabled = true
	stripe_mat.emission = stripe_color
	stripe_mat.emission_energy_multiplier = 2.0

	# 1. Main Horizontal Conduit Pipe
	var pipe_mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = pipe_radius
	cyl.bottom_radius = pipe_radius
	cyl.height = length
	cyl.radial_segments = 12
	pipe_mesh.mesh = cyl
	pipe_mesh.material_override = pipe_mat
	pipe_mesh.position = Vector3(0.0, pipe_height, 0.0)
	pipe_mesh.rotation_degrees.z = 90.0
	add_child(pipe_mesh)

	# 2. Support Stanchions every 2.5m
	var num_supports : int = clampi(int(length / 2.5) + 1, 2, 8)
	var half_len : float = length * 0.5
	for i in range(num_supports):
		var frac : float = float(i) / float(num_supports - 1)
		var sx : float = -half_len + length * frac

		# Vertical support pillar
		var stanchion := MeshInstance3D.new()
		var s_box := BoxMesh.new()
		s_box.size = Vector3(0.18, pipe_height, 0.24)
		stanchion.mesh = s_box
		stanchion.material_override = support_mat
		stanchion.position = Vector3(sx, pipe_height * 0.5, 0.0)
		add_child(stanchion)

		# Ground foot pad
		var pad := MeshInstance3D.new()
		var pad_box := BoxMesh.new()
		pad_box.size = Vector3(0.36, 0.06, 0.42)
		pad.mesh = pad_box
		pad.material_override = support_mat
		pad.position = Vector3(sx, 0.03, 0.0)
		add_child(pad)

		# Pipe Flange Ring
		var flange := MeshInstance3D.new()
		var cyl_f := CylinderMesh.new()
		cyl_f.top_radius = pipe_radius * 1.25
		cyl_f.bottom_radius = pipe_radius * 1.25
		cyl_f.height = 0.08
		flange.mesh = cyl_f
		flange.material_override = stripe_mat
		flange.position = Vector3(sx, pipe_height, 0.0)
		flange.rotation_degrees.z = 90.0
		add_child(flange)

	# StaticBody collision so rovers and players collide with the pipe
	var sb := StaticBody3D.new()
	sb.name = "PipelineStaticBody"
	sb.collision_layer = 1
	sb.collision_mask = 1
	sb.add_to_group("navigation_geometry")

	var col := CollisionShape3D.new()
	var box_col := BoxShape3D.new()
	box_col.size = Vector3(length, pipe_height + pipe_radius, pipe_radius * 2.2)
	col.shape = box_col
	col.position = Vector3(0.0, (pipe_height + pipe_radius) * 0.5, 0.0)
	sb.add_child(col)

	add_child(sb)
