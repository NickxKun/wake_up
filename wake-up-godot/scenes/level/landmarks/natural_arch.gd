class_name NaturalArch
extends Node3D

## Procedurally generated Natural Sandstone Arch Bridge for Canyon Wasteland.
## Spans across the central canyon chasm, providing both a scenic geological
## landmark matching the canyon vista banner, and a functional two-tier tactical bridge:
## - Underneath: Arch portal tunnel with clearance for rovers and infantry.
## - Top: Walkable natural stone bridge deck connecting elevated canyon ridges.

@export var arch_span : float = 10.0
@export var arch_height : float = 4.2
@export var arch_width : float = 3.6
@export var stone_color : Color = Color(0.68, 0.35, 0.20, 1.0)
@export var stone_accent : Color = Color(0.54, 0.26, 0.14, 1.0)

func _ready() -> void:
	_build_arch_mesh()

func _build_arch_mesh() -> void:
	# Build the sandstone material
	var mat := StandardMaterial3D.new()
	mat.albedo_color = stone_color
	mat.roughness = 0.95
	mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(mat)

	# Generate arch profile cross-sections along the arch curve
	# The arch spans from x = -arch_span/2 to +arch_span/2
	var segments : int = 16
	var half_span : float = arch_span * 0.5
	var half_w : float = arch_width * 0.5

	# Generate rings of vertices along the arch curve
	# For each segment i from 0 to segments:
	# theta goes from PI to 0
	# inner arch curve: y = sin(theta) * (arch_height - 1.0)
	# outer arch curve: y = arch_height + (1.0 - sin(theta)) * 0.3
	var rings : Array[Array] = [] # Array of 4-point arrays: [outer_left, outer_right, inner_right, inner_left]

	for i in range(segments + 1):
		var frac : float = float(i) / float(segments)
		var theta : float = PI * (1.0 - frac) # PI to 0
		var x : float = -half_span + arch_span * frac

		# Parabolic / sinusoidal arch profile
		var sin_t : float = sin(theta)
		var inner_y : float = maxf(0.0, sin_t * (arch_height - 1.1))
		var outer_y : float = arch_height - (1.0 - sin_t) * 0.4
		var w : float = half_w + (1.0 - sin_t) * 0.8 # wider at abutments

		var v_outer_l := Vector3(x, outer_y, -w)
		var v_outer_r := Vector3(x, outer_y, w)
		var v_inner_r := Vector3(x, inner_y, w * 0.82)
		var v_inner_l := Vector3(x, inner_y, -w * 0.82)

		rings.append([v_outer_l, v_outer_r, v_inner_r, v_inner_l])

	# Stitch quads between adjacent rings
	for i in range(segments):
		var r0 : Array = rings[i]
		var r1 : Array = rings[i + 1]

		var o_l0 : Vector3 = r0[0]
		var o_r0 : Vector3 = r0[1]
		var i_r0 : Vector3 = r0[2]
		var i_l0 : Vector3 = r0[3]

		var o_l1 : Vector3 = r1[0]
		var o_r1 : Vector3 = r1[1]
		var i_r1 : Vector3 = r1[2]
		var i_l1 : Vector3 = r1[3]

		# 1. Top bridge deck (walkable)
		_add_quad(st, o_l0, o_l1, o_r1, o_r0)

		# 2. Bottom arch ceiling (walkable underneath)
		_add_quad(st, i_l0, i_r0, i_r1, i_l1)

		# 3. North vertical cliff face (-Z)
		_add_quad(st, o_l0, i_l0, i_l1, o_l1)

		# 4. South vertical cliff face (+Z)
		_add_quad(st, o_r0, o_r1, i_r1, i_r0)

	# Abutment solid foundations at West (i=0) and East (i=segments)
	# West abutment wall down to y = 0
	var w_ring : Array = rings[0]
	var w_ol : Vector3 = w_ring[0]
	var w_or : Vector3 = w_ring[1]
	_add_quad(st, Vector3(w_ol.x, 0.0, w_ol.z), w_ol, w_or, Vector3(w_or.x, 0.0, w_or.z))

	# East abutment wall down to y = 0
	var e_ring : Array = rings[segments]
	var e_ol : Vector3 = e_ring[0]
	var e_or : Vector3 = e_ring[1]
	_add_quad(st, e_ol, Vector3(e_ol.x, 0.0, e_ol.z), Vector3(e_or.x, 0.0, e_or.z), e_or)

	st.generate_normals()
	var arch_mesh : ArrayMesh = st.commit()

	var mi := MeshInstance3D.new()
	mi.name = "ArchMesh"
	mi.mesh = arch_mesh
	add_child(mi)

	# Generate trimesh concave static body collision so players can walk
	# over the top bridge and through the bottom tunnel
	mi.create_trimesh_collision()
	for c in mi.get_children():
		if c is StaticBody3D:
			var sb := c as StaticBody3D
			sb.collision_layer = 1
			sb.collision_mask = 1
			sb.add_to_group("navigation_geometry")

	# Add rock strata accent bands along the abutments for visual detail
	_build_strata_accents(mat)

func _add_quad(st: SurfaceTool, v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3) -> void:
	# Triangle 1
	st.add_vertex(v0)
	st.add_vertex(v1)
	st.add_vertex(v2)
	# Triangle 2
	st.add_vertex(v0)
	st.add_vertex(v2)
	st.add_vertex(v3)

func _build_strata_accents(_base_mat: StandardMaterial3D) -> void:
	var accent_mat := StandardMaterial3D.new()
	accent_mat.albedo_color = stone_accent
	accent_mat.roughness = 0.98

	# Buttress rock pillars at each side of the arch spans
	var buttress_positions := [
		Vector3(-arch_span * 0.44, 0.0, -arch_width * 0.55),
		Vector3(-arch_span * 0.44, 0.0, arch_width * 0.55),
		Vector3(arch_span * 0.44, 0.0, -arch_width * 0.55),
		Vector3(arch_span * 0.44, 0.0, arch_width * 0.55),
	]

	for pos in buttress_positions:
		var p_mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(2.2, arch_height * 0.75, 1.8)
		p_mesh.mesh = box
		p_mesh.material_override = accent_mat
		p_mesh.position = pos + Vector3(0.0, arch_height * 0.375, 0.0)
		add_child(p_mesh)
		p_mesh.create_convex_collision(true, false)
		for c in p_mesh.get_children():
			if c is StaticBody3D:
				var sb := c as StaticBody3D
				sb.collision_layer = 1
				sb.collision_mask = 1
				sb.add_to_group("navigation_geometry")
