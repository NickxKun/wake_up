class_name HoodooPillar
extends Node3D

## Procedurally generated sandstone hoodoo monolith spire.
## Features stepped eroded rock cylinders, horizontal strata striations,
## and a wider protective capstone rock at the top.

@export var pillar_height : float = 5.5
@export var base_radius : float = 1.3
@export var cap_radius : float = 1.6
@export var stone_color : Color = Color(0.66, 0.32, 0.18, 1.0)
@export var strata_color : Color = Color(0.50, 0.22, 0.12, 1.0)
@export var cap_color : Color = Color(0.72, 0.40, 0.22, 1.0)

func _ready() -> void:
	_build_hoodoo()

func _build_hoodoo() -> void:
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = stone_color
	base_mat.roughness = 0.95

	var strata_mat := StandardMaterial3D.new()
	strata_mat.albedo_color = strata_color
	strata_mat.roughness = 0.95

	var cap_mat := StandardMaterial3D.new()
	cap_mat.albedo_color = cap_color
	cap_mat.roughness = 0.90

	# 1. Lower Base Tier
	var tier1_h : float = pillar_height * 0.38
	var tier1 := MeshInstance3D.new()
	var cyl1 := CylinderMesh.new()
	cyl1.top_radius = base_radius * 0.85
	cyl1.bottom_radius = base_radius
	cyl1.height = tier1_h
	cyl1.radial_segments = 12
	tier1.mesh = cyl1
	tier1.material_override = base_mat
	tier1.position = Vector3(0.0, tier1_h * 0.5, 0.0)
	add_child(tier1)

	# 2. Mid Strata Belt
	var belt_h : float = pillar_height * 0.14
	var belt := MeshInstance3D.new()
	var cyl_b := CylinderMesh.new()
	cyl_b.top_radius = base_radius * 0.72
	cyl_b.bottom_radius = base_radius * 0.85
	cyl_b.height = belt_h
	cyl_b.radial_segments = 12
	belt.mesh = cyl_b
	belt.material_override = strata_mat
	belt.position = Vector3(0.0, tier1_h + belt_h * 0.5, 0.0)
	add_child(belt)

	# 3. Upper Shaft
	var tier2_h : float = pillar_height * 0.35
	var tier2 := MeshInstance3D.new()
	var cyl2 := CylinderMesh.new()
	cyl2.top_radius = base_radius * 0.60
	cyl2.bottom_radius = base_radius * 0.72
	cyl2.height = tier2_h
	cyl2.radial_segments = 12
	tier2.mesh = cyl2
	tier2.material_override = base_mat
	tier2.position = Vector3(0.0, tier1_h + belt_h + tier2_h * 0.5, 0.0)
	add_child(tier2)

	# 4. Overhanging Capstone Rock
	var cap_h : float = pillar_height * 0.13
	var cap := MeshInstance3D.new()
	var cyl_c := CylinderMesh.new()
	cyl_c.top_radius = cap_radius * 0.9
	cyl_c.bottom_radius = cap_radius
	cyl_c.height = cap_h
	cyl_c.radial_segments = 10
	cap.mesh = cyl_c
	cap.material_override = cap_mat
	cap.position = Vector3(0.0, tier1_h + belt_h + tier2_h + cap_h * 0.5, 0.0)
	add_child(cap)

	# Consolidated StaticBody collision for the hoodoo
	var sb := StaticBody3D.new()
	sb.name = "HoodooStaticBody"
	sb.collision_layer = 1
	sb.collision_mask = 1
	sb.add_to_group("navigation_geometry")

	var col_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = base_radius * 0.95
	capsule.height = pillar_height
	col_shape.shape = capsule
	col_shape.position = Vector3(0.0, pillar_height * 0.5, 0.0)
	sb.add_child(col_shape)

	add_child(sb)
