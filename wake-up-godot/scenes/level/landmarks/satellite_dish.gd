class_name SatelliteDish
extends Node3D

## Deep Space Planetary Communications Dish Antenna for Map 2 (Space Base).
## High-detail outpost landmark featuring a concrete/metal foundation pedestal,
## azimuth-elevation yoke, parabolic dish reflector, sub-reflector feed horn,
## and a pulsing cyan transceiver beacon.

@export var dish_radius : float = 2.4
@export var dish_tilt_degrees : float = 38.0
@export var dish_yaw_degrees : float = -30.0

var _beacon_light : OmniLight3D = null
var _time_elapsed : float = 0.0

func _ready() -> void:
	_build_dish()

func _process(delta: float) -> void:
	if _beacon_light != null:
		_time_elapsed += delta
		_beacon_light.light_energy = 1.2 + 0.8 * sin(_time_elapsed * 4.0)

func _build_dish() -> void:
	var base_metal := StandardMaterial3D.new()
	base_metal.albedo_color = Color(0.24, 0.28, 0.35, 1.0)
	base_metal.metallic = 0.85
	base_metal.roughness = 0.35

	var dish_mat := StandardMaterial3D.new()
	dish_mat.albedo_color = Color(0.85, 0.88, 0.92, 1.0)
	dish_mat.metallic = 0.6
	dish_mat.roughness = 0.25

	var accent_mat := StandardMaterial3D.new()
	accent_mat.albedo_color = Color(0.12, 0.75, 0.95, 1.0)
	accent_mat.emission_enabled = true
	accent_mat.emission = Color(0.10, 0.70, 0.92)
	accent_mat.emission_energy_multiplier = 2.5

	# 1. Foundation Pedestal (Octagonal concrete/metal base)
	var ped := MeshInstance3D.new()
	var cyl_p := CylinderMesh.new()
	cyl_p.top_radius = 1.4
	cyl_p.bottom_radius = 1.6
	cyl_p.height = 0.8
	cyl_p.radial_segments = 8
	ped.mesh = cyl_p
	ped.material_override = base_metal
	ped.position = Vector3(0.0, 0.4, 0.0)
	add_child(ped)

	# 2. Electronics Equipment Cabinet at base
	var cab := MeshInstance3D.new()
	var box_c := BoxMesh.new()
	box_c.size = Vector3(0.8, 0.9, 0.8)
	cab.mesh = box_c
	cab.material_override = base_metal
	cab.position = Vector3(0.8, 0.85, 0.0)
	add_child(cab)

	# 3. Yoke Mount Pylon
	var yoke_pylon := MeshInstance3D.new()
	var cyl_y := CylinderMesh.new()
	cyl_y.top_radius = 0.45
	cyl_y.bottom_radius = 0.6
	cyl_y.height = 1.6
	cyl_y.radial_segments = 10
	yoke_pylon.mesh = cyl_y
	yoke_pylon.material_override = base_metal
	yoke_pylon.position = Vector3(0.0, 1.6, 0.0)
	add_child(yoke_pylon)

	# 4. Articulated Head Node (handles yaw and pitch tilt)
	var head_node := Node3D.new()
	head_node.name = "DishHead"
	head_node.position = Vector3(0.0, 2.4, 0.0)
	head_node.rotation_degrees = Vector3(dish_tilt_degrees, dish_yaw_degrees, 0.0)
	add_child(head_node)

	# 5. Parabolic Dish Reflector (SurfaceTool curved mesh)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(dish_mat)

	var rad_steps : int = 18
	var ring_steps : int = 6
	var dish_depth : float = 0.6

	# Generate concentric rings
	var rings : Array[Array] = []
	for r in range(ring_steps + 1):
		var r_frac : float = float(r) / float(ring_steps)
		var current_r : float = dish_radius * r_frac
		var current_z : float = dish_depth * (r_frac * r_frac) # Parabolic: z = k * r^2
		var ring_pts : Array[Vector3] = []
		for a in range(rad_steps):
			var angle : float = float(a) / float(rad_steps) * TAU
			var px : float = cos(angle) * current_r
			var py : float = sin(angle) * current_r
			ring_pts.append(Vector3(px, py, -current_z))
		rings.append(ring_pts)

	# Stitch quads between rings
	for r in range(ring_steps):
		var ring0 : Array = rings[r]
		var ring1 : Array = rings[r + 1]
		for a in range(rad_steps):
			var next_a : int = (a + 1) % rad_steps
			var v0 : Vector3 = ring0[a]
			var v1 : Vector3 = ring0[next_a]
			var v2 : Vector3 = ring1[next_a]
			var v3 : Vector3 = ring1[a]

			if r == 0:
				# Center apex triangles
				st.add_vertex(v0)
				st.add_vertex(v3)
				st.add_vertex(v2)
			else:
				st.add_vertex(v0)
				st.add_vertex(v3)
				st.add_vertex(v2)

				st.add_vertex(v0)
				st.add_vertex(v2)
				st.add_vertex(v1)

	st.generate_normals()
	var dish_mesh : ArrayMesh = st.commit()

	var dish_inst := MeshInstance3D.new()
	dish_inst.name = "DishReflector"
	dish_inst.mesh = dish_mesh
	head_node.add_child(dish_inst)

	# 6. Feed Horn Tripod Struts and Sub-Reflector
	var feed_z : float = 1.3
	for strut_idx in range(3):
		var ang : float = float(strut_idx) * (TAU / 3.0)
		var strut := MeshInstance3D.new()
		var cyl_s := CylinderMesh.new()
		cyl_s.top_radius = 0.03
		cyl_s.bottom_radius = 0.04
		cyl_s.height = 2.4
		strut.mesh = cyl_s
		strut.material_override = base_metal

		var strut_pos := Vector3(cos(ang) * dish_radius * 0.75, sin(ang) * dish_radius * 0.75, -dish_depth * 0.5)
		var feed_tip := Vector3(0.0, 0.0, feed_z)
		var mid_pt : Vector3 = (strut_pos + feed_tip) * 0.5
		strut.position = mid_pt
		strut.look_at_from_position(mid_pt, feed_tip, Vector3.UP)
		strut.rotate_object_local(Vector3.RIGHT, deg_to_rad(90.0))
		head_node.add_child(strut)

	# 7. Feed Horn Transceiver Head & Beacon Light
	var feed_mesh := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.18
	sph.height = 0.36
	feed_mesh.mesh = sph
	feed_mesh.material_override = accent_mat
	feed_mesh.position = Vector3(0.0, 0.0, feed_z)
	head_node.add_child(feed_mesh)

	var light := OmniLight3D.new()
	light.name = "TransceiverBeacon"
	light.position = Vector3(0.0, 0.0, feed_z + 0.1)
	light.omni_range = 6.0
	light.light_color = Color(0.15, 0.85, 1.0)
	light.light_energy = 1.5
	head_node.add_child(light)
	_beacon_light = light

	# 8. StaticBody collision
	var sb := StaticBody3D.new()
	sb.name = "DishStaticBody"
	sb.collision_layer = 1
	sb.collision_mask = 1
	sb.add_to_group("navigation_geometry")

	var col_ped := CollisionShape3D.new()
	var cyl_col := CylinderShape3D.new()
	cyl_col.radius = 1.5
	cyl_col.height = 1.2
	col_ped.shape = cyl_col
	col_ped.position = Vector3(0.0, 0.6, 0.0)
	sb.add_child(col_ped)

	var col_dish := CollisionShape3D.new()
	var box_col := BoxShape3D.new()
	box_col.size = Vector3(dish_radius * 1.8, dish_radius * 1.8, 1.6)
	col_dish.shape = box_col
	col_dish.position = Vector3(0.0, 2.6, 0.0)
	sb.add_child(col_dish)

	add_child(sb)
