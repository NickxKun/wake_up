class_name GantryCrane
extends Node3D

## Heavy Industrial Rail Gantry Crane for Map 3 (Transport Dock).
## Features twin A-frame steel support towers, horizontal boom bridge,
## motorized trolley, steel hoist cables, and a suspended cargo container.
## Includes industrial amber beacon lights and ground clearance for rovers and trucks.

@export var crane_span : float = 11.0
@export var crane_height : float = 6.2
@export var crane_depth : float = 3.5
@export var crane_color : Color = Color(0.88, 0.64, 0.10, 1.0) # Industrial yellow
@export var steel_color : Color = Color(0.22, 0.25, 0.28, 1.0)  # Structural dark steel

var _strobe_light_1 : OmniLight3D = null
var _strobe_light_2 : OmniLight3D = null
var _time_elapsed : float = 0.0

func _ready() -> void:
	_build_crane()

func _process(delta: float) -> void:
	_time_elapsed += delta
	var flash : float = 1.0 if fmod(_time_elapsed, 1.0) < 0.25 else 0.1
	if _strobe_light_1 != null:
		_strobe_light_1.light_energy = 2.5 * flash
	if _strobe_light_2 != null:
		_strobe_light_2.light_energy = 2.5 * flash

func _build_crane() -> void:
	var yellow_mat := StandardMaterial3D.new()
	yellow_mat.albedo_color = crane_color
	yellow_mat.roughness = 0.45
	yellow_mat.metallic = 0.7

	var steel_mat := StandardMaterial3D.new()
	steel_mat.albedo_color = steel_color
	steel_mat.roughness = 0.35
	steel_mat.metallic = 0.85

	var beacon_mat := StandardMaterial3D.new()
	beacon_mat.albedo_color = Color(1.0, 0.75, 0.1, 1.0)
	beacon_mat.emission_enabled = true
	beacon_mat.emission = Color(1.0, 0.70, 0.08)
	beacon_mat.emission_energy_multiplier = 3.0

	var container_mat := StandardMaterial3D.new()
	container_mat.albedo_color = Color(0.18, 0.45, 0.75, 1.0) # Logistics blue
	container_mat.roughness = 0.4
	container_mat.metallic = 0.65

	var half_span : float = crane_span * 0.5
	var half_d : float = crane_depth * 0.5

	# 1. Twin A-Frame Leg Towers (Left and Right)
	for sign_x in [-1.0, 1.0]:
		var leg_x : float = sign_x * half_span

		# Wheel Bogies at ground level
		var bogie := MeshInstance3D.new()
		var b_box := BoxMesh.new()
		b_box.size = Vector3(0.9, 0.6, crane_depth + 0.6)
		bogie.mesh = b_box
		bogie.material_override = steel_mat
		bogie.position = Vector3(leg_x, 0.3, 0.0)
		add_child(bogie)

		# Forward and Rear Inclined Steel Box Truss Legs
		for sign_z in [-1.0, 1.0]:
			var leg := MeshInstance3D.new()
			var leg_mesh := BoxMesh.new()
			leg_mesh.size = Vector3(0.35, crane_height, 0.35)
			leg.mesh = leg_mesh
			leg.material_override = yellow_mat

			# Angle slightly inward toward center
			var base_z : float = sign_z * half_d
			var top_z : float = sign_z * half_d * 0.5
			var mid_z : float = (base_z + top_z) * 0.5
			leg.position = Vector3(leg_x, crane_height * 0.5, mid_z)
			leg.rotation_degrees.x = sign_z * -6.0
			add_child(leg)

		# Horizontal cross brace between the legs
		var brace := MeshInstance3D.new()
		var br_box := BoxMesh.new()
		br_box.size = Vector3(0.28, 0.28, crane_depth * 0.8)
		brace.mesh = br_box
		brace.material_override = yellow_mat
		brace.position = Vector3(leg_x, crane_height * 0.55, 0.0)
		add_child(brace)

		# Add StaticBody collider for each A-frame leg tower
		var sb_leg := StaticBody3D.new()
		sb_leg.collision_layer = 1
		sb_leg.collision_mask = 1
		sb_leg.add_to_group("navigation_geometry")
		var col_leg := CollisionShape3D.new()
		var leg_shape := BoxShape3D.new()
		leg_shape.size = Vector3(1.1, crane_height, crane_depth + 0.6)
		col_leg.shape = leg_shape
		col_leg.position = Vector3(leg_x, crane_height * 0.5, 0.0)
		sb_leg.add_child(col_leg)
		add_child(sb_leg)

	# 2. Main Horizontal Overhead Gantry Boom (Span)
	var boom_y : float = crane_height
	var boom_front := MeshInstance3D.new()
	var boom_box := BoxMesh.new()
	boom_box.size = Vector3(crane_span + 2.0, 0.65, 0.45)
	boom_front.mesh = boom_box
	boom_front.material_override = yellow_mat
	boom_front.position = Vector3(0.0, boom_y, -0.6)
	add_child(boom_front)

	var boom_rear := MeshInstance3D.new()
	boom_rear.mesh = boom_box
	boom_rear.material_override = yellow_mat
	boom_rear.position = Vector3(0.0, boom_y, 0.6)
	add_child(boom_rear)

	# Cross walk / catwalk deck
	var catwalk := MeshInstance3D.new()
	var cat_box := BoxMesh.new()
	cat_box.size = Vector3(crane_span + 2.0, 0.08, 1.6)
	catwalk.mesh = cat_box
	catwalk.material_override = steel_mat
	catwalk.position = Vector3(0.0, boom_y + 0.35, 0.0)
	add_child(catwalk)

	# 3. Flashing Industrial Amber Warning Strobes on Boom Ends
	var strobe_1 := MeshInstance3D.new()
	var sph1 := SphereMesh.new()
	sph1.radius = 0.14
	sph1.height = 0.28
	strobe_1.mesh = sph1
	strobe_1.material_override = beacon_mat
	strobe_1.position = Vector3(-half_span - 0.9, boom_y + 0.55, 0.0)
	add_child(strobe_1)

	var light1 := OmniLight3D.new()
	light1.light_color = Color(1.0, 0.72, 0.1)
	light1.omni_range = 8.0
	strobe_1.add_child(light1)
	_strobe_light_1 = light1

	var strobe_2 := MeshInstance3D.new()
	strobe_2.mesh = sph1
	strobe_2.material_override = beacon_mat
	strobe_2.position = Vector3(half_span + 0.9, boom_y + 0.55, 0.0)
	add_child(strobe_2)

	var light2 := OmniLight3D.new()
	light2.light_color = Color(1.0, 0.72, 0.1)
	light2.omni_range = 8.0
	strobe_2.add_child(light2)
	_strobe_light_2 = light2

	# 4. Motorized Trolley & Hoist
	var trolley_x : float = 1.2 # slightly off-center for realism
	var trolley := MeshInstance3D.new()
	var tr_box := BoxMesh.new()
	tr_box.size = Vector3(1.4, 0.5, 1.5)
	trolley.mesh = tr_box
	trolley.material_override = steel_mat
	trolley.position = Vector3(trolley_x, boom_y - 0.3, 0.0)
	add_child(trolley)

	# Downward working spotlight on trolley
	var work_light := SpotLight3D.new()
	work_light.light_color = Color(1.0, 0.95, 0.85)
	work_light.light_energy = 2.2
	work_light.spot_range = 14.0
	work_light.spot_angle = 35.0
	work_light.rotation_degrees.x = -90.0
	work_light.position = Vector3(trolley_x, boom_y - 0.5, 0.0)
	add_child(work_light)

	# 5. Hoist Cables (4 vertical wire lines)
	var spreader_y : float = boom_y - 2.8 # 3.4m above ground
	for cx in [-0.9, 0.9]:
		for cz in [-0.5, 0.5]:
			var cable := MeshInstance3D.new()
			var cyl_c := CylinderMesh.new()
			cyl_c.top_radius = 0.015
			cyl_c.bottom_radius = 0.015
			cyl_c.height = 2.5
			cable.mesh = cyl_c
			cable.material_override = steel_mat
			cable.position = Vector3(trolley_x + cx * 0.7, (boom_y - 0.3 + spreader_y) * 0.5, cz * 0.7)
			add_child(cable)

	# 6. Spreader Bar
	var spreader := MeshInstance3D.new()
	var sp_box := BoxMesh.new()
	sp_box.size = Vector3(2.6, 0.2, 1.4)
	spreader.mesh = sp_box
	spreader.material_override = yellow_mat
	spreader.position = Vector3(trolley_x, spreader_y, 0.0)
	add_child(spreader)

	# 7. Suspended 20ft Shipping Container
	var container_y : float = spreader_y - 0.85 # mid-air suspended container
	var container := MeshInstance3D.new()
	var con_box := BoxMesh.new()
	con_box.size = Vector3(2.5, 1.5, 1.3)
	container.mesh = con_box
	container.material_override = container_mat
	container.position = Vector3(trolley_x, container_y, 0.0)
	add_child(container)

	# StaticBody collider for the suspended container (provides elevated tactical cover)
	var sb_con := StaticBody3D.new()
	sb_con.name = "SuspendedContainerStaticBody"
	sb_con.collision_layer = 1
	sb_con.collision_mask = 1
	sb_con.add_to_group("navigation_geometry")
	sb_con.position = Vector3(trolley_x, container_y, 0.0)
	var col_con := CollisionShape3D.new()
	var con_shape := BoxShape3D.new()
	con_shape.size = Vector3(2.5, 1.5, 1.3)
	col_con.shape = con_shape
	sb_con.add_child(col_con)
	add_child(sb_con)
