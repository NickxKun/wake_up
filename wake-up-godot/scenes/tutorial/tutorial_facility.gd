class_name TutorialFacility
extends Node3D

## Builds rich sci-fi architectural dressing, directional ground chevron guides,
## illuminated gantry portals, sector divider bulkheads, and facility props.
## Transforms the tutorial proving grounds from an empty space into an immersive,
## high-tech tactical training compound.

# Shared Materials
var _mat_dark_alloy : StandardMaterial3D
var _mat_floor_trim : StandardMaterial3D
var _mat_cyan_glow : StandardMaterial3D
var _mat_amber_glow : StandardMaterial3D
var _mat_hazard_stripe : StandardMaterial3D
var _mat_crate_orange : StandardMaterial3D
var _mat_crate_blue : StandardMaterial3D
var _mat_barrier : StandardMaterial3D
var _mat_helipad : StandardMaterial3D
var _mat_green_glow : StandardMaterial3D

func _ready() -> void:
	_init_materials()
	_build_ground_chevrons()
	_build_sector_portals()
	_build_facility_partitions()
	_build_platform_trims()
	_build_tech_props()
	_build_extraction_helipad()

func _init_materials() -> void:
	_mat_dark_alloy = StandardMaterial3D.new()
	_mat_dark_alloy.albedo_color = Color(0.11, 0.13, 0.17, 1.0)
	_mat_dark_alloy.metallic = 0.85
	_mat_dark_alloy.roughness = 0.35

	_mat_floor_trim = StandardMaterial3D.new()
	_mat_floor_trim.albedo_color = Color(0.18, 0.22, 0.28, 1.0)
	_mat_floor_trim.metallic = 0.5
	_mat_floor_trim.roughness = 0.45

	_mat_cyan_glow = StandardMaterial3D.new()
	_mat_cyan_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_cyan_glow.albedo_color = Color(0.2, 0.88, 1.0, 0.95)

	_mat_amber_glow = StandardMaterial3D.new()
	_mat_amber_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_amber_glow.albedo_color = Color(1.0, 0.72, 0.16, 0.95)

	_mat_green_glow = StandardMaterial3D.new()
	_mat_green_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_green_glow.albedo_color = Color(0.3, 0.95, 0.45, 0.95)

	_mat_hazard_stripe = StandardMaterial3D.new()
	_mat_hazard_stripe.albedo_color = Color(0.92, 0.7, 0.12, 1.0)
	_mat_hazard_stripe.roughness = 0.4

	_mat_crate_orange = StandardMaterial3D.new()
	_mat_crate_orange.albedo_color = Color(0.85, 0.42, 0.12, 1.0)
	_mat_crate_orange.metallic = 0.4
	_mat_crate_orange.roughness = 0.45

	_mat_crate_blue = StandardMaterial3D.new()
	_mat_crate_blue.albedo_color = Color(0.15, 0.38, 0.62, 1.0)
	_mat_crate_blue.metallic = 0.4
	_mat_crate_blue.roughness = 0.45

	_mat_barrier = StandardMaterial3D.new()
	_mat_barrier.albedo_color = Color(0.28, 0.32, 0.38, 1.0)
	_mat_barrier.roughness = 0.5

	_mat_helipad = StandardMaterial3D.new()
	_mat_helipad.albedo_color = Color(0.16, 0.18, 0.22, 1.0)
	_mat_helipad.roughness = 0.6

# -----------------------------------------------------------------------------
# 1. Ground Directional Chevron Guides (Pointing Path Across Facility)
# -----------------------------------------------------------------------------

func _build_ground_chevrons() -> void:
	var guides_node := Node3D.new()
	guides_node.name = "FloorDirectionGuides"
	add_child(guides_node)

	# Leg 1: Sector 1 Locomotion to Vault Barrier (Eastbound: -23 to -17, y = 0.02)
	for x in [-23.0, -21.0, -19.0, -17.0]:
		_create_chevron(guides_node, Vector3(x, 0.02, 0.0), 0.0, _mat_cyan_glow)

	# Leg 2: Vault Barrier to Thruster Platform Zone (-13.5 to -9.8, y = 0.02)
	for x in [-13.5, -11.5, -9.8]:
		_create_chevron(guides_node, Vector3(x, 0.02, 0.0), 0.0, _mat_cyan_glow)

	# Leg 3: Stepped Thruster Platform Traversal
	# West Approach Step (X = -8.0, Y = 0.52)
	_create_chevron(guides_node, Vector3(-8.0, 0.52, 0.0), 0.0, _mat_cyan_glow)
	# Platform Main Deck Elevated Guides (Y = 1.02)
	_create_chevron(guides_node, Vector3(-6.0, 1.02, 0.0), 0.0, _mat_cyan_glow)
	_create_chevron(guides_node, Vector3(-2.0, 1.02, 0.0), 0.0, _mat_cyan_glow)
	# East Descent Step (X = 0.0, Y = 0.52)
	_create_chevron(guides_node, Vector3(0.0, 0.52, -0.4), deg_to_rad(-15.0), _mat_cyan_glow)

	# Leg 4: Firing Range Entrance & Weapons Box (Y = 0.02)
	_create_chevron(guides_node, Vector3(1.5, 0.02, -1.2), deg_to_rad(-22.0), _mat_cyan_glow)
	_create_chevron(guides_node, Vector3(3.0, 0.02, -2.0), deg_to_rad(-12.0), _mat_cyan_glow)

	# Leg 4: Firing Range Lane Guidance (Towards Targets)
	for x in [6.5, 9.0, 11.5, 14.0]:
		_create_dash_line(guides_node, Vector3(x, 0.02, -2.5), Vector3(1.2, 0.01, 0.12), _mat_cyan_glow)
		_create_dash_line(guides_node, Vector3(x, 0.02, 0.0), Vector3(1.2, 0.01, 0.12), _mat_cyan_glow)
		_create_dash_line(guides_node, Vector3(x, 0.02, 2.5), Vector3(1.2, 0.01, 0.12), _mat_cyan_glow)

	# Leg 5: Armory to Rover Bay (Southbound: Z = 0 to 12.5 at X = 4)
	for z in [0.0, 2.2, 4.4, 6.6, 8.8, 11.0]:
		_create_chevron(guides_node, Vector3(4.0, 0.02, z), deg_to_rad(90.0), _mat_amber_glow)

	# Leg 6: Rover Slalom Track (Amber Vehicle Nav Guides)
	# Start Depot (4, 13) -> Slalom 1 (14, 14)
	for x in [6.5, 9.0, 11.5]:
		_create_chevron(guides_node, Vector3(x, 0.02, 13.5), 0.0, _mat_amber_glow, 1.4)

	# Slalom 1 (14, 14) to Slalom 2 (22, 10) (Curving Northeast)
	_create_chevron(guides_node, Vector3(16.0, 0.02, 13.0), deg_to_rad(-25.0), _mat_amber_glow, 1.4)
	_create_chevron(guides_node, Vector3(18.0, 0.02, 12.0), deg_to_rad(-30.0), _mat_amber_glow, 1.4)
	_create_chevron(guides_node, Vector3(20.0, 0.02, 11.0), deg_to_rad(-25.0), _mat_amber_glow, 1.4)

	# Slalom 2 (22, 10) to Rover Park (25, 10)
	_create_chevron(guides_node, Vector3(23.5, 0.02, 10.0), 0.0, _mat_amber_glow, 1.4)

	# Leg 7: Rover Park to Combat Arena Entrance (Northbound: from 25, 10 to 26, 0)
	for z in [8.5, 6.5, 4.5, 2.5, 1.0]:
		_create_chevron(guides_node, Vector3(25.5, 0.02, z), deg_to_rad(-90.0), _mat_cyan_glow)

	# Leg 8: Combat Arena to Extraction Helipad (Eastbound: 27 to 37 at Z = 0)
	for x in [28.0, 30.5, 33.0, 35.5]:
		_create_chevron(guides_node, Vector3(x, 0.02, 0.0), 0.0, _mat_green_glow)

func _create_chevron(parent: Node3D, pos: Vector3, rot_y: float, mat: Material, scale_mult: float = 1.0) -> void:
	var chevron := Node3D.new()
	chevron.name = "GuideChevron_%d" % parent.get_child_count()
	chevron.position = pos
	chevron.rotation.y = rot_y
	chevron.scale = Vector3(scale_mult, 1.0, scale_mult)
	parent.add_child(chevron)

	# Left wing
	var left := MeshInstance3D.new()
	var box_l := BoxMesh.new()
	box_l.size = Vector3(0.55, 0.015, 0.12)
	left.mesh = box_l
	left.material_override = mat
	left.position = Vector3(0.08, 0.0, -0.18)
	left.rotation.y = deg_to_rad(35.0)
	chevron.add_child(left)

	# Right wing
	var right := MeshInstance3D.new()
	var box_r := BoxMesh.new()
	box_r.size = Vector3(0.55, 0.015, 0.12)
	right.mesh = box_r
	right.material_override = mat
	right.position = Vector3(0.08, 0.0, 0.18)
	right.rotation.y = deg_to_rad(-35.0)
	chevron.add_child(right)

	# Center arrow tip
	var tip := MeshInstance3D.new()
	var box_tip := BoxMesh.new()
	box_tip.size = Vector3(0.2, 0.016, 0.2)
	tip.mesh = box_tip
	tip.material_override = mat
	tip.position = Vector3(0.28, 0.0, 0.0)
	tip.rotation.y = deg_to_rad(45.0)
	chevron.add_child(tip)

func _create_dash_line(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> void:
	var dash := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	dash.mesh = box
	dash.material_override = mat
	dash.position = pos
	parent.add_child(dash)

# -----------------------------------------------------------------------------
# 2. Sector Gantry Portals & Overhead Signage
# -----------------------------------------------------------------------------

func _build_sector_portals() -> void:
	var portals_node := Node3D.new()
	portals_node.name = "SectorPortals"
	add_child(portals_node)

	# Portal 1: Entrance Archway
	_create_gantry(portals_node, Vector3(-25.5, 0.0, 0.0), 0.0, 6.0, 3.6, "SECTOR 01 // LOCOMOTION & AGILITY", _mat_cyan_glow)

	# Portal 2: Thruster Training Area
	_create_gantry(portals_node, Vector3(-10.5, 0.0, 0.0), 0.0, 6.0, 3.6, "SECTOR 02 // RCS THRUSTERS & FLIGHT", _mat_cyan_glow)

	# Portal 3: Firing Range Entrance
	_create_gantry(portals_node, Vector3(1.5, 0.0, 0.0), 0.0, 6.5, 3.6, "SECTOR 03 // MARKSMANSHIP RANGE", _mat_cyan_glow)

	# Portal 4: Vehicle Bay Entrance (Z corridor)
	_create_gantry(portals_node, Vector3(4.0, 0.0, 5.5), deg_to_rad(90.0), 6.0, 3.6, "SECTOR 04 // VEHICLE PROVING TRACK", _mat_amber_glow)

	# Portal 5: Combat Simulation Arena
	_create_gantry(portals_node, Vector3(25.5, 0.0, 0.0), 0.0, 7.0, 3.8, "SECTOR 05 // LIVE COMBAT MATRIX", Color(0.95, 0.25, 0.35, 1.0))

func _create_gantry(parent: Node3D, pos: Vector3, rot_y: float, span: float, height: float, label_text: String, accent_color: Variant) -> void:
	var gantry := Node3D.new()
	gantry.name = "Gantry_" + label_text.substr(0, 9).replace(" ", "_")
	gantry.position = pos
	gantry.rotation.y = rot_y
	parent.add_child(gantry)

	var half_span : float = span * 0.5
	var pillar_mat : Material = _mat_dark_alloy

	# Left Pillar
	var p_left := MeshInstance3D.new()
	var mesh_p := BoxMesh.new()
	mesh_p.size = Vector3(0.45, height, 0.45)
	p_left.mesh = mesh_p
	p_left.material_override = pillar_mat
	p_left.position = Vector3(0.0, height * 0.5, -half_span)
	gantry.add_child(p_left)

	# Right Pillar
	var p_right := MeshInstance3D.new()
	p_right.mesh = mesh_p
	p_right.material_override = pillar_mat
	p_right.position = Vector3(0.0, height * 0.5, half_span)
	gantry.add_child(p_right)

	# Crossbeam Header
	var beam := MeshInstance3D.new()
	var mesh_b := BoxMesh.new()
	mesh_b.size = Vector3(0.55, 0.55, span + 0.5)
	beam.mesh = mesh_b
	beam.material_override = pillar_mat
	beam.position = Vector3(0.0, height - 0.25, 0.0)
	gantry.add_child(beam)

	# Glowing Accent Light Strip beneath crossbeam
	var strip := MeshInstance3D.new()
	var mesh_s := BoxMesh.new()
	mesh_s.size = Vector3(0.58, 0.08, span - 0.2)
	strip.mesh = mesh_s
	var glow_mat := StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if accent_color is Color:
		glow_mat.albedo_color = accent_color
	elif accent_color is Material:
		glow_mat = (accent_color as StandardMaterial3D).duplicate()
	strip.material_override = glow_mat
	strip.position = Vector3(0.0, height - 0.52, 0.0)
	gantry.add_child(strip)

	# 3D Illuminated Header Label
	var lbl := Label3D.new()
	lbl.text = label_text
	lbl.font_size = 28
	lbl.pixel_size = 0.007
	lbl.modulate = Color(1.0, 1.0, 1.0, 0.95)
	lbl.outline_modulate = Color(0.0, 0.0, 0.0, 0.85)
	lbl.outline_size = 4
	lbl.position = Vector3(-0.3, height - 0.22, 0.0)
	lbl.rotation.y = deg_to_rad(-90.0)
	gantry.add_child(lbl)

# -----------------------------------------------------------------------------
# 3. Sector Divider Partitions & Windows
# -----------------------------------------------------------------------------

func _build_facility_partitions() -> void:
	var partition_node := StaticBody3D.new()
	partition_node.name = "SectorPartitionWall"
	partition_node.collision_layer = 1
	partition_node.collision_mask = 0
	add_child(partition_node)

	# Dividing wall between Firing Range and Rover Track (Z = 5.0, X from -2.0 to 22.0)
	var wall_len : float = 24.0
	var wall_h : float = 2.4
	var wall_th : float = 0.45

	var col := CollisionShape3D.new()
	var c_box := BoxShape3D.new()
	c_box.size = Vector3(wall_len, wall_h, wall_th)
	col.shape = c_box
	col.position = Vector3(10.0, wall_h * 0.5, 5.0)
	partition_node.add_child(col)

	var mesh_inst := MeshInstance3D.new()
	var b_mesh := BoxMesh.new()
	b_mesh.size = Vector3(wall_len, wall_h, wall_th)
	mesh_inst.mesh = b_mesh
	mesh_inst.material_override = _mat_dark_alloy
	mesh_inst.position = col.position
	partition_node.add_child(mesh_inst)

	# Yellow Hazard Strip along base of partition wall
	var stripe := MeshInstance3D.new()
	var s_mesh := BoxMesh.new()
	s_mesh.size = Vector3(wall_len, 0.18, wall_th + 0.04)
	stripe.mesh = s_mesh
	stripe.material_override = _mat_hazard_stripe
	stripe.position = Vector3(10.0, 0.09, 5.0)
	partition_node.add_child(stripe)

	# Glowing Cyan Top Rail
	var rail := MeshInstance3D.new()
	var r_mesh := BoxMesh.new()
	r_mesh.size = Vector3(wall_len, 0.08, 0.15)
	rail.mesh = r_mesh
	rail.material_override = _mat_cyan_glow
	rail.position = Vector3(10.0, wall_h + 0.04, 5.0)
	partition_node.add_child(rail)

# -----------------------------------------------------------------------------
# 4. Elevated Flight Platform Trims & Hazard Markings
# -----------------------------------------------------------------------------

func _build_platform_trims() -> void:
	var trims_node := Node3D.new()
	trims_node.name = "PlatformTrims"
	add_child(trims_node)

	# Cyan Glowing Deck Perimeter Rails along north and south edges of the platform
	_create_dash_line(trims_node, Vector3(-4.0, 1.02, -3.0), Vector3(7.0, 0.03, 0.12), _mat_cyan_glow)
	_create_dash_line(trims_node, Vector3(-4.0, 1.02, 3.0), Vector3(7.0, 0.03, 0.12), _mat_cyan_glow)

	# Hazard Stripes on Step Risers
	# West Approach Step Riser (X = -8.76, Y = 0.25)
	_create_dash_line(trims_node, Vector3(-8.76, 0.25, 0.0), Vector3(0.04, 0.5, 4.0), _mat_hazard_stripe)
	# Platform Main Deck West Riser (X = -7.51, Y = 0.75)
	_create_dash_line(trims_node, Vector3(-7.51, 0.75, 0.0), Vector3(0.04, 0.5, 4.0), _mat_hazard_stripe)
	# Platform Main Deck East Riser (X = -0.49, Y = 0.75)
	_create_dash_line(trims_node, Vector3(-0.49, 0.75, 0.0), Vector3(0.04, 0.5, 4.0), _mat_hazard_stripe)
	# East Descent Step Riser (X = 0.76, Y = 0.25)
	_create_dash_line(trims_node, Vector3(0.76, 0.25, 0.0), Vector3(0.04, 0.5, 4.0), _mat_hazard_stripe)

# -----------------------------------------------------------------------------
# 5. Sci-Fi Dressing Props (Cargo Crates, Racks, Consoles)
# -----------------------------------------------------------------------------

func _build_tech_props() -> void:
	var props_root := Node3D.new()
	props_root.name = "FacilityProps"
	add_child(props_root)

	# Start Bay Equipment Dressing (North wall X = -24 to -18, Z = -13 to -15)
	_spawn_crate_stack(props_root, Vector3(-25.0, 0.0, -14.0))
	_spawn_server_rack(props_root, Vector3(-22.0, 0.0, -15.0), 0.0)
	_spawn_server_rack(props_root, Vector3(-20.5, 0.0, -15.0), 0.0)
	_spawn_crate_stack(props_root, Vector3(-17.5, 0.0, -14.5))

	# Sector 2 Thrusters Dressing (Perimeter tech consoles)
	_spawn_server_rack(props_root, Vector3(-11.0, 0.0, -15.0), 0.0)
	_spawn_server_rack(props_root, Vector3(-9.5, 0.0, -15.0), 0.0)
	_spawn_crate_stack(props_root, Vector3(-3.0, 0.0, -14.0))

	# Sector 3 Armory Stacks (Near WeaponsBox at X = 4, Z = -2.5)
	_spawn_crate(props_root, Vector3(2.5, 0.0, -4.5), Vector3(1.2, 0.8, 1.2), _mat_crate_orange)
	_spawn_crate(props_root, Vector3(4.0, 0.0, -5.0), Vector3(1.4, 1.0, 1.0), _mat_crate_blue)
	_spawn_crate(props_root, Vector3(5.5, 0.0, -4.5), Vector3(1.0, 0.8, 1.0), _mat_crate_orange)
	_spawn_crate(props_root, Vector3(4.0, 1.0, -5.0), Vector3(1.0, 0.7, 0.8), _mat_crate_blue)

	# Firing Line Safety Booth Dividers (Between targets)
	for lane_z in [-3.8, -1.25, 1.25, 3.8]:
		_spawn_barrier(props_root, Vector3(3.0, 0.5, lane_z), Vector3(2.5, 1.0, 0.18))

	# Sector 4 Rover Bay Charging Station (At X = 1.5, Z = 13.0)
	_spawn_server_rack(props_root, Vector3(1.5, 0.0, 15.0), deg_to_rad(-90.0))
	_spawn_server_rack(props_root, Vector3(1.5, 0.0, 13.5), deg_to_rad(-90.0))
	_spawn_crate_stack(props_root, Vector3(1.5, 0.0, 10.5))

	# Slalom Course Safety Road Curbs (Along outer perimeter)
	_spawn_barrier(props_root, Vector3(10.0, 0.25, 16.5), Vector3(14.0, 0.5, 0.35))
	_spawn_barrier(props_root, Vector3(20.0, 0.25, 16.5), Vector3(8.0, 0.5, 0.35))
	_spawn_barrier(props_root, Vector3(25.0, 0.25, 13.5), Vector3(0.35, 0.5, 6.0))

	# Combat Arena Tactical Barriers (Cover for firefights)
	_spawn_barrier(props_root, Vector3(31.0, 0.6, -2.5), Vector3(2.4, 1.2, 0.45))
	_spawn_barrier(props_root, Vector3(34.0, 0.6, 2.5), Vector3(2.4, 1.2, 0.45))

func _spawn_crate_stack(parent: Node3D, pos: Vector3) -> void:
	_spawn_crate(parent, pos + Vector3(-0.6, 0.0, 0.0), Vector3(1.1, 0.9, 1.1), _mat_crate_orange)
	_spawn_crate(parent, pos + Vector3(0.6, 0.0, 0.0), Vector3(1.1, 0.9, 1.1), _mat_crate_blue)
	_spawn_crate(parent, pos + Vector3(0.0, 0.9, 0.0), Vector3(1.0, 0.8, 1.0), _mat_crate_orange)

func _spawn_crate(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> void:
	var body := StaticBody3D.new()
	body.name = "TechCrate_%d" % parent.get_child_count()
	body.position = pos + Vector3(0.0, size.y * 0.5, 0.0)
	body.collision_layer = 1
	body.collision_mask = 0
	parent.add_child(body)

	var col := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	col.shape = box_shape
	body.add_child(col)

	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	body.add_child(mi)

	# Glowing frame corners
	var trim := MeshInstance3D.new()
	var t_mesh := BoxMesh.new()
	t_mesh.size = Vector3(size.x + 0.02, 0.04, size.z + 0.02)
	trim.mesh = t_mesh
	trim.material_override = _mat_cyan_glow
	trim.position.y = size.y * 0.5 - 0.03
	body.add_child(trim)

func _spawn_server_rack(parent: Node3D, pos: Vector3, rot_y: float) -> void:
	var body := StaticBody3D.new()
	body.name = "ServerRack"
	body.position = pos + Vector3(0.0, 1.2, 0.0)
	body.rotation.y = rot_y
	body.collision_layer = 1
	body.collision_mask = 0
	parent.add_child(body)

	var col := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(1.1, 2.4, 0.65)
	col.shape = box_shape
	body.add_child(col)

	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.1, 2.4, 0.65)
	mi.mesh = mesh
	mi.material_override = _mat_dark_alloy
	body.add_child(mi)

	# Blinking LED status lines
	for i in range(4):
		var led := MeshInstance3D.new()
		var l_mesh := BoxMesh.new()
		l_mesh.size = Vector3(0.85, 0.04, 0.02)
		led.mesh = l_mesh
		led.material_override = _mat_cyan_glow if i % 2 == 0 else _mat_amber_glow
		led.position = Vector3(0.0, -0.6 + float(i) * 0.4, 0.33)
		body.add_child(led)

func _spawn_barrier(parent: Node3D, pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "TacticalBarrier"
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	parent.add_child(body)

	var col := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	col.shape = box_shape
	body.add_child(col)

	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = _mat_barrier
	body.add_child(mi)

# -----------------------------------------------------------------------------
# 5. Extraction Helipad Marking & Pad Lighting
# -----------------------------------------------------------------------------

func _build_extraction_helipad() -> void:
	var pad_root := Node3D.new()
	pad_root.name = "HelipadExtractionPad"
	pad_root.position = Vector3(38.0, 0.02, 0.0)
	add_child(pad_root)

	# Circular Octagonal Landing Pad
	var pad := MeshInstance3D.new()
	var p_mesh := CylinderMesh.new()
	p_mesh.top_radius = 4.2
	p_mesh.bottom_radius = 4.4
	p_mesh.height = 0.04
	p_mesh.radial_segments = 16
	pad.mesh = p_mesh
	pad.material_override = _mat_helipad
	pad_root.add_child(pad)

	# Glowing Green/Cyan Perimeter Ring
	var ring := MeshInstance3D.new()
	var r_mesh := TorusMesh.new()
	r_mesh.inner_radius = 4.0
	r_mesh.outer_radius = 4.25
	r_mesh.rings = 32
	r_mesh.ring_segments = 6
	ring.mesh = r_mesh
	ring.material_override = _mat_green_glow
	ring.position.y = 0.02
	pad_root.add_child(ring)

	# Central "H" Helipad Marking
	var h_bar_l := MeshInstance3D.new()
	var h_mesh := BoxMesh.new()
	h_mesh.size = Vector3(2.4, 0.03, 0.35)
	h_bar_l.mesh = h_mesh
	h_bar_l.material_override = _mat_green_glow
	h_bar_l.position = Vector3(0.0, 0.03, -1.0)
	pad_root.add_child(h_bar_l)

	var h_bar_r := MeshInstance3D.new()
	h_bar_r.mesh = h_mesh
	h_bar_r.material_override = _mat_green_glow
	h_bar_r.position = Vector3(0.0, 0.03, 1.0)
	pad_root.add_child(h_bar_r)

	var h_cross := MeshInstance3D.new()
	var cross_mesh := BoxMesh.new()
	cross_mesh.size = Vector3(0.35, 0.03, 2.0)
	h_cross.mesh = cross_mesh
	h_cross.material_override = _mat_green_glow
	h_cross.position = Vector3(0.0, 0.03, 0.0)
	pad_root.add_child(h_cross)

	# 4 Corner Floodlight Pylons
	var corners := [
		Vector3(-3.5, 0.0, -3.5),
		Vector3(3.5, 0.0, -3.5),
		Vector3(-3.5, 0.0, 3.5),
		Vector3(3.5, 0.0, 3.5)
	]
	for c_pos in corners:
		var pylon := MeshInstance3D.new()
		var p_mesh_cyl := CylinderMesh.new()
		p_mesh_cyl.top_radius = 0.12
		p_mesh_cyl.bottom_radius = 0.2
		p_mesh_cyl.height = 1.6
		pylon.mesh = p_mesh_cyl
		pylon.material_override = _mat_dark_alloy
		pylon.position = c_pos + Vector3(0.0, 0.8, 0.0)
		pad_root.add_child(pylon)

		var beacon := MeshInstance3D.new()
		var b_box := BoxMesh.new()
		b_box.size = Vector3(0.25, 0.15, 0.25)
		beacon.mesh = b_box
		beacon.material_override = _mat_green_glow
		beacon.position = c_pos + Vector3(0.0, 1.65, 0.0)
		pad_root.add_child(beacon)
