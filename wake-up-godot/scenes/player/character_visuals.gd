class_name CharacterVisuals
extends Node

## Manages custom 3D model customization, materials, accessories, backpacks,
## and lighting fixtures for each playable operative class.
## Attached to ProtoController, synchronizes dynamically with Skeleton3D and CharacterData.

const MAT_ALBEDO_PALETTE : Texture2D = preload("res://assets/textures/ImphenziaPalette02-Albedo.png")

var _player : CharacterBody3D = null
var _skeleton : Skeleton3D = null
var _char_mesh : MeshInstance3D = null

# Preview mode configuration
@export var is_preview : bool = false
@export var preview_class_id : int = -1

# Bone attachments
var _spine_attachment : BoneAttachment3D = null
var _head_attachment : BoneAttachment3D = null
var _pelvis_attachment : BoneAttachment3D = null
var _gun_attachment : BoneAttachment3D = null

# Active accessory and weapon instances
var _active_backpack : Node3D = null
var _active_visor : Node3D = null
var _active_belt : Node3D = null
var _shoulder_lights : Node3D = null
var _shoulder_armor : Node3D = null
var _signature_weapon : Node3D = null

# Preview animation and pose state
var _aim_pose : Quaternion = Quaternion.IDENTITY
var _upper_r_idx : int = -1
var _hand_r_idx : int = -1
var _upper_l_idx : int = -1
var _lower_l_idx : int = -1
var _spine1_idx : int = -1
var _spine2_idx : int = -1
var _head_idx : int = -1

## Factory helper to instantiate and dress a standalone 3D character model for UI preview banners.
static func create_styled_character_model(class_id: int) -> Node3D:
	var blend_scene : PackedScene = load("res://assets/models/player.blend")
	if blend_scene == null:
		return null
	var model : Node3D = blend_scene.instantiate() as Node3D
	model.scale = Vector3.ONE * 0.1

	var visuals : CharacterVisuals = CharacterVisuals.new()
	visuals.name = "CharacterVisuals"
	visuals.is_preview = true
	visuals.preview_class_id = class_id
	model.add_child(visuals)

	var skeletons : Array[Node] = model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return model
	visuals._skeleton = skeletons[0] as Skeleton3D

	var meshes : Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
	for m in meshes:
		var mi := m as MeshInstance3D
		if mi.name.to_lower().contains("character") or mi.name.to_lower() == "mesh":
			visuals._char_mesh = mi
			break

	var spine := BoneAttachment3D.new()
	spine.name = "SpineAttachment"
	spine.bone_name = "Spine2"
	visuals._skeleton.add_child(spine)
	visuals._spine_attachment = spine

	var head := BoneAttachment3D.new()
	head.name = "HeadAttachment"
	head.bone_name = "Head"
	visuals._skeleton.add_child(head)
	visuals._head_attachment = head

	var pelvis := BoneAttachment3D.new()
	pelvis.name = "PelvisAttachment"
	pelvis.bone_name = "Pelvis"
	visuals._skeleton.add_child(pelvis)
	visuals._pelvis_attachment = pelvis

	visuals.apply_class_visuals(class_id)
	visuals.setup_preview_pose_and_weapon(class_id)
	return model

func _ready() -> void:
	if is_preview:
		_cache_preview_bones()
		return

	_player = get_parent() as CharacterBody3D
	_setup_visuals.call_deferred()

	var char_data : Node = get_node_or_null("/root/CharacterData")
	if char_data != null and char_data.has_signal("class_changed"):
		char_data.class_changed.connect(_on_class_changed)

func _cache_preview_bones() -> void:
	if _skeleton == null:
		return
	_upper_r_idx = _skeleton.find_bone("UpperArm.R")
	_hand_r_idx = _skeleton.find_bone("Hand.R")
	_upper_l_idx = _skeleton.find_bone("UpperArm.L")
	_lower_l_idx = _skeleton.find_bone("LowerArm.L")
	_spine1_idx = _skeleton.find_bone("Spine1")
	_spine2_idx = _skeleton.find_bone("Spine2")
	_head_idx = _skeleton.find_bone("Head")

## Poses the character model out of T-pose into a hero ready stance and equips their signature weapon.
func setup_preview_pose_and_weapon(class_id: int) -> void:
	if _skeleton == null:
		return
	_cache_preview_bones()
	if _upper_r_idx == -1 or _hand_r_idx == -1:
		return

	# Precompute right-arm aiming pose and gun orientation basis
	var aim_pitch : float = 0.12
	var parent_idx : int = _skeleton.get_bone_parent(_upper_r_idx)
	var parent_rest : Quaternion = _skeleton.get_bone_global_rest(parent_idx).basis.get_rotation_quaternion()
	var upper_rest : Quaternion = _skeleton.get_bone_global_rest(_upper_r_idx).basis.get_rotation_quaternion()
	var hand_rest : Quaternion = _skeleton.get_bone_global_rest(_hand_r_idx).basis.get_rotation_quaternion()
	var aim_direction : Vector3 = Vector3(0.0, -sin(aim_pitch), -cos(aim_pitch))
	var swing : Quaternion = Quaternion((hand_rest * Vector3.UP).normalized(), aim_direction)
	var aimed_upper : Quaternion = swing * upper_rest
	_aim_pose = parent_rest.inverse() * aimed_upper
	var aimed_hand : Quaternion = swing * hand_rest
	var gun_basis : Basis = Basis(aimed_hand.inverse()) * Basis.looking_at(aim_direction, Vector3.UP)

	# Set right arm holding weapon forward
	_skeleton.set_bone_pose_rotation(_upper_r_idx, _aim_pose)

	# Set left arm lowered naturally from T-pose (down by 1.18 rads, slight bend)
	if _upper_l_idx != -1:
		var rest_l : Quaternion = _skeleton.get_bone_rest(_upper_l_idx).basis.get_rotation_quaternion()
		_skeleton.set_bone_pose_rotation(_upper_l_idx, rest_l * Quaternion(Vector3.BACK, -1.18) * Quaternion(Vector3.RIGHT, 0.15))
	if _lower_l_idx != -1:
		var rest_lower_l : Quaternion = _skeleton.get_bone_rest(_lower_l_idx).basis.get_rotation_quaternion()
		_skeleton.set_bone_pose_rotation(_lower_l_idx, rest_lower_l * Quaternion(Vector3.RIGHT, -0.22))

	# Attach GunAttachment to Hand.R
	if _gun_attachment == null or not is_instance_valid(_gun_attachment):
		_gun_attachment = _skeleton.get_node_or_null("GunAttachment") as BoneAttachment3D
		if _gun_attachment == null:
			_gun_attachment = BoneAttachment3D.new()
			_gun_attachment.name = "GunAttachment"
			_gun_attachment.bone_name = "Hand.R"
			_skeleton.add_child(_gun_attachment)

	if _signature_weapon != null and is_instance_valid(_signature_weapon):
		if _signature_weapon.get_parent() != null:
			_signature_weapon.get_parent().remove_child(_signature_weapon)
		_signature_weapon.queue_free()
		_signature_weapon = null

	var weapon_path : String = "res://scenes/weapons/models/model_pistol.tscn"
	match class_id:
		CharacterDataSingleton.CharacterClass.ENGINEER:
			weapon_path = "res://scenes/weapons/models/model_wrench.tscn"
		CharacterDataSingleton.CharacterClass.MEDIC:
			weapon_path = "res://scenes/weapons/models/model_shotgun.tscn"
		CharacterDataSingleton.CharacterClass.EXPLORER:
			weapon_path = "res://scenes/weapons/models/model_sniper.tscn"
		_:
			weapon_path = "res://scenes/weapons/models/model_pistol.tscn"

	var p_scene : PackedScene = load(weapon_path)
	if p_scene != null:
		var w_inst : Node3D = p_scene.instantiate() as Node3D
		if w_inst != null:
			_signature_weapon = w_inst
			_gun_attachment.add_child(w_inst)
			var scale_mult : float = 10.0
			var parent_node := get_parent() as Node3D
			if parent_node != null and parent_node.scale.x > 0.0001:
				scale_mult = 1.0 / parent_node.scale.x
			w_inst.transform = Transform3D(gun_basis.scaled(Vector3.ONE * scale_mult), Vector3(0.0, 0.2, 0.0))

			# Medic Bio-Blaster conduit emerald tint
			if class_id == CharacterDataSingleton.CharacterClass.MEDIC:
				var conduit : MeshInstance3D = w_inst.find_child("Conduit", true, false) as MeshInstance3D
				if conduit != null:
					var bio_mat := StandardMaterial3D.new()
					bio_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
					bio_mat.albedo_color = Color(0.1, 0.95, 0.55)
					conduit.material_override = bio_mat

func _process(delta: float) -> void:
	if not is_preview:
		return
	_process_preview_animation(delta)

func _process_preview_animation(_delta: float) -> void:
	if _skeleton == null:
		return
	var t : float = Time.get_ticks_msec() / 1000.0
	var offset : float = float(preview_class_id) * 1.5

	# 1. Subtle breathing in spine (chest expansion / rise)
	var breath : float = sin(t * 2.2 + offset) * 0.03
	if _spine1_idx >= 0:
		var rest_s1 : Quaternion = _skeleton.get_bone_rest(_spine1_idx).basis.get_rotation_quaternion()
		_skeleton.set_bone_pose_rotation(_spine1_idx, rest_s1 * Quaternion(Vector3.RIGHT, breath))
	if _spine2_idx >= 0:
		var rest_s2 : Quaternion = _skeleton.get_bone_rest(_spine2_idx).basis.get_rotation_quaternion()
		_skeleton.set_bone_pose_rotation(_spine2_idx, rest_s2 * Quaternion(Vector3.RIGHT, breath * 0.6))

	# 2. Right arm holding weapon: gentle ready sway/drift with breath
	if _upper_r_idx >= 0:
		var weapon_drift : float = sin(t * 1.8 + offset * 0.7) * 0.018
		_skeleton.set_bone_pose_rotation(_upper_r_idx, _aim_pose * Quaternion(Vector3.RIGHT, weapon_drift))

	# 3. Left arm resting naturally at side: breathing sway
	if _upper_l_idx >= 0:
		var rest_l : Quaternion = _skeleton.get_bone_rest(_upper_l_idx).basis.get_rotation_quaternion()
		var arm_sway : float = sin(t * 2.2 + offset) * 0.02
		_skeleton.set_bone_pose_rotation(_upper_l_idx, rest_l * Quaternion(Vector3.BACK, -1.18 + arm_sway) * Quaternion(Vector3.RIGHT, 0.15))

	# 4. Head subtle gaze motion
	if _head_idx >= 0:
		var rest_head : Quaternion = _skeleton.get_bone_rest(_head_idx).basis.get_rotation_quaternion()
		var head_sway : float = sin(t * 1.3 + offset * 2.0) * 0.025
		_skeleton.set_bone_pose_rotation(_head_idx, rest_head * Quaternion(Vector3.UP, head_sway))

func _setup_visuals() -> void:
	if _player == null:
		return

	var skeletons : Array[Node] = _player.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return
	_skeleton = skeletons[0] as Skeleton3D

	var meshes : Array[Node] = _player.find_children("*", "MeshInstance3D", true, false)
	for m in meshes:
		var mi := m as MeshInstance3D
		if mi.name.to_lower().contains("character") or mi.name.to_lower() == "mesh":
			_char_mesh = mi
			break

	if _skeleton != null:
		_spine_attachment = _skeleton.get_node_or_null("SpineAttachment") as BoneAttachment3D
		if _spine_attachment == null:
			_spine_attachment = BoneAttachment3D.new()
			_spine_attachment.name = "SpineAttachment"
			_skeleton.add_child(_spine_attachment)
			_spine_attachment.bone_name = "Spine2"

		_head_attachment = _skeleton.get_node_or_null("HeadAttachment") as BoneAttachment3D
		if _head_attachment == null:
			_head_attachment = BoneAttachment3D.new()
			_head_attachment.name = "HeadAttachment"
			_skeleton.add_child(_head_attachment)
		_head_attachment.bone_name = "Head"

		_pelvis_attachment = _skeleton.get_node_or_null("PelvisAttachment") as BoneAttachment3D
		if _pelvis_attachment == null:
			_pelvis_attachment = BoneAttachment3D.new()
			_pelvis_attachment.name = "PelvisAttachment"
			_skeleton.add_child(_pelvis_attachment)
			_pelvis_attachment.bone_name = "Pelvis"

	# Apply initial class visual identity
	var char_data : Node = get_node_or_null("/root/CharacterData")
	var initial_class : int = 0
	if char_data != null and "current_class" in char_data:
		initial_class = int(char_data.current_class)

	apply_class_visuals(initial_class)

func _on_class_changed(new_class: int, _class_info: Dictionary) -> void:
	if is_preview:
		return
	apply_class_visuals(new_class)

## Applies custom materials, unique accessories, and specialized equipment per class.
func apply_class_visuals(class_id: int) -> void:
	if is_preview and preview_class_id >= 0 and class_id != preview_class_id:
		return
	_clear_accessories()

	match class_id:
		CharacterDataSingleton.CharacterClass.ENGINEER:
			_apply_engineer_visuals()
		CharacterDataSingleton.CharacterClass.MEDIC:
			_apply_medic_visuals()
		CharacterDataSingleton.CharacterClass.EXPLORER:
			_apply_explorer_visuals()
		_:
			_apply_astronaut_visuals()

func _clear_accessories() -> void:
	if _active_backpack != null and is_instance_valid(_active_backpack):
		if _active_backpack.get_parent() != null:
			_active_backpack.get_parent().remove_child(_active_backpack)
		_active_backpack.queue_free()
		_active_backpack = null

	if _active_visor != null and is_instance_valid(_active_visor):
		if _active_visor.get_parent() != null:
			_active_visor.get_parent().remove_child(_active_visor)
		_active_visor.queue_free()
		_active_visor = null

	if _active_belt != null and is_instance_valid(_active_belt):
		if _active_belt.get_parent() != null:
			_active_belt.get_parent().remove_child(_active_belt)
		_active_belt.queue_free()
		_active_belt = null

	if _shoulder_lights != null and is_instance_valid(_shoulder_lights):
		if _shoulder_lights.get_parent() != null:
			_shoulder_lights.get_parent().remove_child(_shoulder_lights)
		_shoulder_lights.queue_free()
		_shoulder_lights = null

	if _shoulder_armor != null and is_instance_valid(_shoulder_armor):
		if _shoulder_armor.get_parent() != null:
			_shoulder_armor.get_parent().remove_child(_shoulder_armor)
		_shoulder_armor.queue_free()
		_shoulder_armor = null

	if _signature_weapon != null and is_instance_valid(_signature_weapon):
		if _signature_weapon.get_parent() != null:
			_signature_weapon.get_parent().remove_child(_signature_weapon)
		_signature_weapon.queue_free()
		_signature_weapon = null

# -----------------------------------------------------------------------------
# 0. ASTRONAUT (Standard Vanguard)
# -----------------------------------------------------------------------------
func _apply_astronaut_visuals() -> void:
	if _char_mesh != null:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.96, 0.98, 1.0) # Crisp white space suit
		mat.metallic = 0.2
		mat.roughness = 0.4
		_char_mesh.material_override = mat

	# 1. Sleek EVA life-support backpack (ergonomically contoured to back - no front clipping!)
	if _spine_attachment != null:
		var pack := Node3D.new()
		pack.name = "AstronautPack"

		var pack_mat := StandardMaterial3D.new()
		pack_mat.albedo_color = Color(0.92, 0.94, 0.96)
		pack_mat.roughness = 0.45
		pack_mat.metallic = 0.2

		var canister_mat := StandardMaterial3D.new()
		canister_mat.albedo_color = Color(0.20, 0.24, 0.28)
		canister_mat.metallic = 0.85
		canister_mat.roughness = 0.25

		var led_cyan := StandardMaterial3D.new()
		led_cyan.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		led_cyan.albedo_color = Color(0.15, 0.88, 1.0)

		# Contoured EVA Pack Main Chassis
		var chassis := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.62, 0.74, 0.20)
		chassis.mesh = box
		chassis.material_override = pack_mat
		chassis.position = Vector3(0.0, 0.28, 0.96)
		pack.add_child(chassis)

		# Dual Compact High-Pressure Oxygen Canisters
		for side in [-0.18, 0.18]:
			var can := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.085
			cyl.bottom_radius = 0.085
			cyl.height = 0.56
			cyl.radial_segments = 10
			can.mesh = cyl
			can.material_override = canister_mat
			can.position = Vector3(side, 0.28, 1.05)
			pack.add_child(can)

			# Glowing Cyan O2 Level Indicator Strip
			var strip := MeshInstance3D.new()
			var s_box := BoxMesh.new()
			s_box.size = Vector3(0.02, 0.32, 0.02)
			strip.mesh = s_box
			strip.material_override = led_cyan
			strip.position = Vector3(side, 0.28, 1.14)
			pack.add_child(strip)

		_spine_attachment.add_child(pack)
		_active_backpack = pack

	# 2. Sleek mirrored gold bubble solar visor (flawlessly seated on front face)
	if _head_attachment != null:
		var visor := Node3D.new()
		visor.name = "AstronautVisor"
		visor.position = Vector3(0.0, -0.08, -1.45)

		var frame_mat := StandardMaterial3D.new()
		frame_mat.albedo_color = Color(0.22, 0.25, 0.28)
		frame_mat.metallic = 0.88
		frame_mat.roughness = 0.25

		var gold_glass_mat := StandardMaterial3D.new()
		gold_glass_mat.albedo_color = Color(0.98, 0.82, 0.22)
		gold_glass_mat.metallic = 0.96
		gold_glass_mat.roughness = 0.12

		# Titanium Brow Rim Trim
		var brow_mesh := MeshInstance3D.new()
		var b_box := BoxMesh.new()
		b_box.size = Vector3(0.92, 0.10, 0.12)
		brow_mesh.mesh = b_box
		brow_mesh.material_override = frame_mat
		brow_mesh.position = Vector3(0, 0.12, 0.02)
		visor.add_child(brow_mesh)

		# Convex Gold Solar Bubble Visor
		var glass_mesh := MeshInstance3D.new()
		var g_box := BoxMesh.new()
		g_box.size = Vector3(0.86, 0.26, 0.10)
		glass_mesh.mesh = g_box
		glass_mesh.material_override = gold_glass_mat
		glass_mesh.position = Vector3(0, 0.0, 0.0)
		visor.add_child(glass_mesh)

		# Temple Comms Seals
		for side in [-0.45, 0.45]:
			var seal := MeshInstance3D.new()
			var s_box := BoxMesh.new()
			s_box.size = Vector3(0.08, 0.18, 0.14)
			seal.mesh = s_box
			seal.material_override = frame_mat
			seal.position = Vector3(side, 0.02, 0.06)
			visor.add_child(seal)

		_head_attachment.add_child(visor)
		_active_visor = visor

	# 3. Tactical Belt with Cute Little Frag Grenades
	if _pelvis_attachment != null:
		var belt := Node3D.new()
		belt.name = "AstronautBelt"
		belt.position = Vector3(0.0, 0.30, 0.0)

		var belt_mat := StandardMaterial3D.new()
		belt_mat.albedo_color = Color(0.16, 0.19, 0.22)
		belt_mat.roughness = 0.85

		var buckle_mat := StandardMaterial3D.new()
		buckle_mat.albedo_color = Color(0.96, 0.82, 0.24)
		buckle_mat.metallic = 0.92
		buckle_mat.roughness = 0.2

		# Waist Belt Ring
		var b_ring := MeshInstance3D.new()
		var ring_box := BoxMesh.new()
		ring_box.size = Vector3(0.98, 0.14, 0.84)
		b_ring.mesh = ring_box
		b_ring.material_override = belt_mat
		belt.add_child(b_ring)

		# Gold Front Buckle
		var buckle := MeshInstance3D.new()
		var bk_box := BoxMesh.new()
		bk_box.size = Vector3(0.20, 0.18, 0.04)
		buckle.mesh = bk_box
		buckle.material_override = buckle_mat
		buckle.position = Vector3(0.0, 0.0, 0.43)
		belt.add_child(buckle)

		# Cute Little Grenades clipped to belt
		# Grenade 1: Right front hip
		var g1 := _create_cute_grenade()
		g1.name = "CuteGrenade1"
		g1.position = Vector3(0.38, 0.02, 0.32)
		g1.rotation_degrees = Vector3(10.0, 25.0, -8.0)
		belt.add_child(g1)

		# Grenade 2: Right flank
		var g2 := _create_cute_grenade()
		g2.name = "CuteGrenade2"
		g2.position = Vector3(0.48, 0.01, 0.14)
		g2.rotation_degrees = Vector3(5.0, 65.0, -12.0)
		belt.add_child(g2)

		# Grenade 3: Left front hip
		var g3 := _create_cute_grenade()
		g3.name = "CuteGrenade3"
		g3.position = Vector3(-0.38, 0.02, 0.32)
		g3.rotation_degrees = Vector3(10.0, -25.0, 8.0)
		belt.add_child(g3)

		_pelvis_attachment.add_child(belt)
		_active_belt = belt

## Creates a miniature stylized sci-fi hand grenade for the Astronaut's utility belt.
func _create_cute_grenade() -> Node3D:
	var root_node := Node3D.new()

	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.18, 0.36, 0.28) # Tactical military olive green
	body_mat.metallic = 0.55
	body_mat.roughness = 0.4

	var band_mat := StandardMaterial3D.new()
	band_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	band_mat.albedo_color = Color(0.15, 0.88, 1.0) # Glowing cyan safety LED band

	var silver_mat := StandardMaterial3D.new()
	silver_mat.albedo_color = Color(0.85, 0.88, 0.92)
	silver_mat.metallic = 0.95
	silver_mat.roughness = 0.18

	# 1. Grenade rounded canister body
	var body := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.075
	cyl.bottom_radius = 0.075
	cyl.height = 0.18
	cyl.radial_segments = 12
	body.mesh = cyl
	body.material_override = body_mat
	root_node.add_child(body)

	# 2. Glowing cyan LED energy band around middle
	var band := MeshInstance3D.new()
	var b_cyl := CylinderMesh.new()
	b_cyl.top_radius = 0.082
	b_cyl.bottom_radius = 0.082
	b_cyl.height = 0.035
	b_cyl.radial_segments = 12
	band.mesh = b_cyl
	band.material_override = band_mat
	root_node.add_child(band)

	# 3. Metallic safety cap & fuse collar
	var cap := MeshInstance3D.new()
	var c_cyl := CylinderMesh.new()
	c_cyl.top_radius = 0.052
	c_cyl.bottom_radius = 0.052
	c_cyl.height = 0.04
	c_cyl.radial_segments = 10
	cap.mesh = c_cyl
	cap.material_override = silver_mat
	cap.position = Vector3(0.0, 0.10, 0.0)
	root_node.add_child(cap)

	# 4. Safety spoon / lever
	var lever := MeshInstance3D.new()
	var l_box := BoxMesh.new()
	l_box.size = Vector3(0.03, 0.12, 0.02)
	lever.mesh = l_box
	lever.material_override = silver_mat
	lever.position = Vector3(0.065, 0.04, 0.0)
	root_node.add_child(lever)

	# 5. Pull ring
	var ring := MeshInstance3D.new()
	var r_torus := TorusMesh.new()
	r_torus.inner_radius = 0.015
	r_torus.outer_radius = 0.032
	ring.mesh = r_torus
	ring.material_override = silver_mat
	ring.position = Vector3(0.0, 0.13, 0.02)
	ring.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	root_node.add_child(ring)

	return root_node

# -----------------------------------------------------------------------------
# 1. THE ENGINEER (Combat Architect)
# -----------------------------------------------------------------------------
func _apply_engineer_visuals() -> void:
	if _char_mesh != null:
		# High-visibility industrial hazard orange suit with charcoal Kevlar armor
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.50, 0.06) # Hazard Orange
		mat.metallic = 0.38
		mat.roughness = 0.35
		_char_mesh.material_override = mat

	# 1. Heavy Turret Fabrication Pack (Ergonomically contoured to back - no arm clipping)
	if _spine_attachment != null:
		var pack := Node3D.new()
		pack.name = "EngineerTurretRig"
		pack.position = Vector3(0.0, 0.22, 1.12) # Securely mounted on back (+Z in Spine2 space)

		var dark_metal_mat := StandardMaterial3D.new()
		dark_metal_mat.albedo_color = Color(0.14, 0.16, 0.19)
		dark_metal_mat.metallic = 0.92
		dark_metal_mat.roughness = 0.26

		var hazard_amber_mat := StandardMaterial3D.new()
		hazard_amber_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		hazard_amber_mat.albedo_color = Color(1.0, 0.65, 0.12) # Pulsating Amber glow

		var brass_mat := StandardMaterial3D.new()
		brass_mat.albedo_color = Color(0.85, 0.65, 0.25)
		brass_mat.metallic = 0.95
		brass_mat.roughness = 0.20

		# A. Spine Harness Mounting Plate
		var harness_mesh := MeshInstance3D.new()
		var h_box := BoxMesh.new()
		h_box.size = Vector3(0.92, 1.05, 0.10)
		harness_mesh.mesh = h_box
		harness_mesh.material_override = dark_metal_mat
		harness_mesh.position = Vector3(0, 0, -0.10)
		pack.add_child(harness_mesh)

		# B. Main Fabrication Generator Core (Compact 0.96m width leaves >5cm arm clearance)
		var core_mesh := MeshInstance3D.new()
		var c_box := BoxMesh.new()
		c_box.size = Vector3(0.96, 1.05, 0.38)
		core_mesh.mesh = c_box
		core_mesh.material_override = dark_metal_mat
		core_mesh.position = Vector3(0, 0, 0.14)
		pack.add_child(core_mesh)

		# C. Amber Hazard Chevron Inset
		var chevron_mesh := MeshInstance3D.new()
		var ch_box := BoxMesh.new()
		ch_box.size = Vector3(0.68, 0.45, 0.02)
		chevron_mesh.mesh = ch_box
		chevron_mesh.material_override = hazard_amber_mat
		chevron_mesh.position = Vector3(0, 0.05, 0.34)
		pack.add_child(chevron_mesh)

		# D. Folded Micro Sentry Turret Deployer Bay (mounted on top of rig)
		var turret_bay := Node3D.new()
		turret_bay.name = "MicroTurretBay"

		var base_dome := MeshInstance3D.new()
		var dome_cyl := CylinderMesh.new()
		dome_cyl.top_radius = 0.20
		dome_cyl.bottom_radius = 0.22
		dome_cyl.height = 0.12
		base_dome.mesh = dome_cyl
		base_dome.material_override = dark_metal_mat
		base_dome.position = Vector3(0, 0.58, 0.14)
		turret_bay.add_child(base_dome)

		var turret_head := MeshInstance3D.new()
		var th_box := BoxMesh.new()
		th_box.size = Vector3(0.32, 0.20, 0.28)
		turret_head.mesh = th_box
		var th_mat := StandardMaterial3D.new()
		th_mat.albedo_color = Color(1.0, 0.52, 0.08)
		th_mat.metallic = 0.5
		th_mat.roughness = 0.3
		turret_head.material_override = th_mat
		turret_head.position = Vector3(0, 0.72, 0.14)
		turret_bay.add_child(turret_head)

		# Twin miniature sentry barrels pointing back & up
		for side in [-0.07, 0.07]:
			var barrel := MeshInstance3D.new()
			var b_cyl := CylinderMesh.new()
			b_cyl.top_radius = 0.025
			b_cyl.bottom_radius = 0.025
			b_cyl.height = 0.32
			barrel.mesh = b_cyl
			barrel.material_override = brass_mat
			barrel.position = Vector3(side, 0.82, 0.24)
			barrel.rotation_degrees = Vector3(-45, 0, 0)
			turret_bay.add_child(barrel)

		pack.add_child(turret_bay)

		# E. Dual Amber Power Cells (docked in recessed side brackets)
		for side in [-0.36, 0.36]:
			var cell_mesh := MeshInstance3D.new()
			var cell := CylinderMesh.new()
			cell.top_radius = 0.10
			cell.bottom_radius = 0.10
			cell.height = 0.75
			cell_mesh.mesh = cell
			cell_mesh.material_override = hazard_amber_mat
			cell_mesh.position = Vector3(side, 0.0, 0.28)
			pack.add_child(cell_mesh)

			var clamp_mesh := MeshInstance3D.new()
			var clamp_cyl := CylinderMesh.new()
			clamp_cyl.top_radius = 0.12
			clamp_cyl.bottom_radius = 0.12
			clamp_cyl.height = 0.14
			clamp_mesh.mesh = clamp_cyl
			clamp_mesh.material_override = dark_metal_mat
			clamp_mesh.position = Vector3(side, 0.28, 0.28)
			pack.add_child(clamp_mesh)

		# F. Articulated Servomotor Robotic Crane Arm (neatly folded, zero clipping)
		var crane_mesh := MeshInstance3D.new()
		var crane := BoxMesh.new()
		crane.size = Vector3(0.10, 0.60, 0.10)
		crane_mesh.mesh = crane
		crane_mesh.material_override = dark_metal_mat
		crane_mesh.position = Vector3(0.34, 0.70, 0.12)
		crane_mesh.rotation_degrees = Vector3(-18, 12, -10)
		pack.add_child(crane_mesh)

		_spine_attachment.add_child(pack)
		_active_backpack = pack

		# G. Reinforced Shoulder Pauldrons (angled deltoid armor)
		var pauldrons := Node3D.new()
		pauldrons.name = "EngineerPauldrons"
		for side in [-1.0, 1.0]:
			var p_mesh := MeshInstance3D.new()
			var p_box := BoxMesh.new()
			p_box.size = Vector3(0.34, 0.14, 0.42)
			p_mesh.mesh = p_box
			var p_mat := StandardMaterial3D.new()
			p_mat.albedo_color = Color(0.95, 0.48, 0.06)
			p_mat.metallic = 0.5
			p_mat.roughness = 0.35
			p_mesh.material_override = p_mat
			p_mesh.position = Vector3(side * 0.64, 0.66, 0.0)
			p_mesh.rotation_degrees = Vector3(0, 0, -side * 18)
			pauldrons.add_child(p_mesh)

		_spine_attachment.add_child(pauldrons)
		_shoulder_armor = pauldrons

	# 2. Heavy Combat Blast Welding Visor & Respirator (Properly seated on front face)
	if _head_attachment != null:
		var visor := Node3D.new()
		visor.name = "EngineerVisor"
		visor.position = Vector3(0.0, -0.08, -1.45) # Centered on helmet face (-Z in Head space)

		var titanium_mat := StandardMaterial3D.new()
		titanium_mat.albedo_color = Color(0.14, 0.16, 0.19)
		titanium_mat.metallic = 0.9
		titanium_mat.roughness = 0.24

		var amber_slit_mat := StandardMaterial3D.new()
		amber_slit_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		amber_slit_mat.albedo_color = Color(1.0, 0.74, 0.16) # Tactical amber optical glow

		# A. Reinforced Brow Plate / Protective Cowl
		var brow_mesh := MeshInstance3D.new()
		var b_box := BoxMesh.new()
		b_box.size = Vector3(0.94, 0.12, 0.14)
		brow_mesh.mesh = b_box
		brow_mesh.material_override = titanium_mat
		brow_mesh.position = Vector3(0, 0.14, 0.02)
		visor.add_child(brow_mesh)

		# B. Amber Optical Scanner Slit
		var slit_mesh := MeshInstance3D.new()
		var s_box := BoxMesh.new()
		s_box.size = Vector3(0.82, 0.12, 0.08)
		slit_mesh.mesh = s_box
		slit_mesh.material_override = amber_slit_mat
		slit_mesh.position = Vector3(0, 0.02, -0.02)
		visor.add_child(slit_mesh)

		# C. Dual Temple Hinges
		for side in [-0.46, 0.46]:
			var hinge := MeshInstance3D.new()
			var hg_box := BoxMesh.new()
			hg_box.size = Vector3(0.08, 0.20, 0.16)
			hinge.mesh = hg_box
			hinge.material_override = titanium_mat
			hinge.position = Vector3(side, 0.04, 0.08)
			visor.add_child(hinge)

		# D. Lower Rebreather Respirator Unit
		var resp_mesh := MeshInstance3D.new()
		var r_box := BoxMesh.new()
		r_box.size = Vector3(0.38, 0.20, 0.16)
		resp_mesh.mesh = r_box
		resp_mesh.material_override = titanium_mat
		resp_mesh.position = Vector3(0, -0.22, 0.02)
		visor.add_child(resp_mesh)

		# Dual intake canister valves
		for side in [-0.18, 0.18]:
			var intake := MeshInstance3D.new()
			var in_cyl := CylinderMesh.new()
			in_cyl.top_radius = 0.06
			in_cyl.bottom_radius = 0.06
			in_cyl.height = 0.10
			intake.mesh = in_cyl
			intake.material_override = titanium_mat
			intake.position = Vector3(side, -0.22, 0.04)
			intake.rotation_degrees = Vector3(0, 0, 90)
			visor.add_child(intake)

		_head_attachment.add_child(visor)
		_active_visor = visor

	# 3. Heavy Tool Belt & Wrench Holster Bracket (Equipped at waist)
	if _pelvis_attachment != null:
		var belt := Node3D.new()
		belt.name = "EngineerBelt"
		belt.position = Vector3(0.0, 0.30, 0.0)

		var belt_mat := StandardMaterial3D.new()
		belt_mat.albedo_color = Color(0.10, 0.12, 0.14)
		belt_mat.roughness = 0.85

		var buckle_mat := StandardMaterial3D.new()
		buckle_mat.albedo_color = Color(1.0, 0.58, 0.10)
		buckle_mat.metallic = 0.8

		# Waist Utility Belt
		var b_ring := MeshInstance3D.new()
		var ring_box := BoxMesh.new()
		ring_box.size = Vector3(1.02, 0.16, 0.85)
		b_ring.mesh = ring_box
		b_ring.material_override = belt_mat
		belt.add_child(b_ring)

		# Hazard Buckle
		var buckle := MeshInstance3D.new()
		var bk_box := BoxMesh.new()
		bk_box.size = Vector3(0.22, 0.20, 0.05)
		buckle.mesh = bk_box
		buckle.material_override = buckle_mat
		buckle.position = Vector3(0, 0, -0.44)
		belt.add_child(buckle)

		# Modular Tool Pouch (Left Hip)
		var pouch := MeshInstance3D.new()
		var p_box := BoxMesh.new()
		p_box.size = Vector3(0.18, 0.25, 0.22)
		pouch.mesh = p_box
		pouch.material_override = belt_mat
		pouch.position = Vector3(-0.52, -0.04, 0.0)
		belt.add_child(pouch)

		# Titanium Wrench Holster Clip (Right Hip)
		var holster := MeshInstance3D.new()
		var h_box := BoxMesh.new()
		h_box.size = Vector3(0.14, 0.22, 0.18)
		holster.mesh = h_box
		holster.material_override = buckle_mat
		holster.position = Vector3(0.52, -0.04, 0.0)
		belt.add_child(holster)

		_pelvis_attachment.add_child(belt)
		_active_belt = belt

# -----------------------------------------------------------------------------
# 2. THE MEDIC (Field Surgeon)
# -----------------------------------------------------------------------------
func _apply_medic_visuals() -> void:
	if _char_mesh != null:
		# Sterile clinical white medical armor with cyan surgical trim
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.92, 0.96, 0.98)
		mat.metallic = 0.25
		mat.roughness = 0.35
		_char_mesh.material_override = mat

	if _spine_attachment != null:
		# Nanite Life-Support Defibrillator Rig (ergonomically mounted on back)
		var pack := Node3D.new()
		pack.name = "MedicDefibRig"
		pack.position = Vector3(0.0, 0.22, 1.10)

		# Central life-support console
		var console_mesh := MeshInstance3D.new()
		var c_box := BoxMesh.new()
		c_box.size = Vector3(1.02, 1.10, 0.36)
		console_mesh.mesh = c_box
		var c_mat := StandardMaterial3D.new()
		c_mat.albedo_color = Color(0.88, 0.92, 0.95)
		c_mat.metallic = 0.3
		c_mat.roughness = 0.4
		console_mesh.material_override = c_mat
		console_mesh.position = Vector3(0, 0, 0.12)
		pack.add_child(console_mesh)

		# Dual glowing emerald nanite fluid canisters
		for side in [-0.36, 0.36]:
			var tube_mesh := MeshInstance3D.new()
			var tube := CylinderMesh.new()
			tube.top_radius = 0.10
			tube.bottom_radius = 0.10
			tube.height = 0.85
			tube_mesh.mesh = tube
			var tube_mat := StandardMaterial3D.new()
			tube_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			tube_mat.albedo_color = Color(0.15, 0.95, 0.55) # Emerald vitals glow
			tube_mesh.material_override = tube_mat
			tube_mesh.position = Vector3(side, 0.0, 0.26)
			pack.add_child(tube_mesh)

		# Glowing Medical Cross Symbol on rear of pack
		var cross_v := MeshInstance3D.new()
		var cv := BoxMesh.new()
		cv.size = Vector3(0.20, 0.55, 0.04)
		cross_v.mesh = cv
		var cross_mat := StandardMaterial3D.new()
		cross_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		cross_mat.albedo_color = Color(0.98, 0.25, 0.35) # Bright red medical cross
		cross_v.material_override = cross_mat
		cross_v.position = Vector3(0, 0, 0.32)
		pack.add_child(cross_v)

		var cross_h := MeshInstance3D.new()
		var ch := BoxMesh.new()
		ch.size = Vector3(0.55, 0.20, 0.04)
		cross_h.mesh = ch
		cross_h.material_override = cross_mat
		cross_h.position = Vector3(0, 0, 0.32)
		pack.add_child(cross_h)

		_spine_attachment.add_child(pack)
		_active_backpack = pack

	# Holographic bio-scanner HUD visor & comms antenna (properly seated on front face)
	if _head_attachment != null:
		var visor := Node3D.new()
		visor.name = "MedicVisor"
		visor.position = Vector3(0.0, -0.08, -1.45)

		var white_mat := StandardMaterial3D.new()
		white_mat.albedo_color = Color(0.92, 0.95, 0.98)
		white_mat.metallic = 0.3
		white_mat.roughness = 0.35

		var cyan_glow_mat := StandardMaterial3D.new()
		cyan_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		cyan_glow_mat.albedo_color = Color(0.18, 0.95, 0.65) # Cyan-emerald bio-scanner

		# Brow sensor housing
		var brow_mesh := MeshInstance3D.new()
		var b_box := BoxMesh.new()
		b_box.size = Vector3(0.92, 0.08, 0.12)
		brow_mesh.mesh = b_box
		brow_mesh.material_override = white_mat
		brow_mesh.position = Vector3(0, 0.12, 0.02)
		visor.add_child(brow_mesh)

		# Holographic cyan-emerald scanner lens
		var visor_mesh := MeshInstance3D.new()
		var v_box := BoxMesh.new()
		v_box.size = Vector3(0.86, 0.20, 0.08)
		visor_mesh.mesh = v_box
		visor_mesh.material_override = cyan_glow_mat
		visor_mesh.position = Vector3(0, 0.0, -0.01)
		visor.add_child(visor_mesh)

		# Field comms earpiece & antenna
		var comms := MeshInstance3D.new()
		var ant := CylinderMesh.new()
		ant.top_radius = 0.015
		ant.bottom_radius = 0.02
		ant.height = 0.35
		comms.mesh = ant
		comms.material_override = white_mat
		comms.position = Vector3(-0.46, 0.18, 0.06)
		comms.rotation_degrees = Vector3(-15, 0, -8)
		visor.add_child(comms)

		_head_attachment.add_child(visor)
		_active_visor = visor

# -----------------------------------------------------------------------------
# 3. THE EXPLORER (Frontier Scout)
# -----------------------------------------------------------------------------
func _apply_explorer_visuals() -> void:
	if _char_mesh != null:
		# Weathered olive khaki / slate bronze expedition armor
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.55, 0.52, 0.42) # Olive Khaki
		mat.metallic = 0.35
		mat.roughness = 0.55
		_char_mesh.material_override = mat

	if _spine_attachment != null:
		# Long-Range Comms Array & Telemetry Rig (mounted on back)
		var pack := Node3D.new()
		pack.name = "ExplorerCommsRig"
		pack.position = Vector3(0.0, 0.22, 1.10)

		var frame_mesh := MeshInstance3D.new()
		var f_box := BoxMesh.new()
		f_box.size = Vector3(1.02, 1.10, 0.36)
		frame_mesh.mesh = f_box
		var f_mat := StandardMaterial3D.new()
		f_mat.albedo_color = Color(0.24, 0.28, 0.25)
		f_mat.metallic = 0.8
		f_mat.roughness = 0.3
		frame_mesh.material_override = f_mat
		frame_mesh.position = Vector3(0, 0, 0.12)
		pack.add_child(frame_mesh)

		# Dual high-gain telemetry antennae
		for side in [-0.36, 0.36]:
			var ant_mesh := MeshInstance3D.new()
			var ant := CylinderMesh.new()
			ant.top_radius = 0.03
			ant.bottom_radius = 0.04
			ant.height = 1.4
			ant_mesh.mesh = ant
			ant_mesh.material_override = f_mat
			ant_mesh.position = Vector3(side, 0.95, 0.12)
			pack.add_child(ant_mesh)

		# Dual Active Shoulder Searchlights / Flashlights (rotated 180 to point forward with player facing)
		var lights_node := Node3D.new()
		lights_node.name = "ShoulderSearchlights"

		var house_mat := StandardMaterial3D.new()
		house_mat.albedo_color = Color(0.2, 0.22, 0.25)
		house_mat.metallic = 0.9

		var lens_mat := StandardMaterial3D.new()
		lens_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		lens_mat.albedo_color = Color(1.0, 0.98, 0.85) # High-intensity warm searchlight lens

		for side in [-0.58, 0.58]:
			var fixture := Node3D.new()
			fixture.name = "FlashlightFixture_%s" % ("L" if side < 0 else "R")
			fixture.position = Vector3(side, 0.58, -0.45) # Over shoulders
			fixture.rotation_degrees = Vector3(0, 180, 0) # Rotated 180 degrees so light & housing face forward
			lights_node.add_child(fixture)

			# Cylindrical flashlight housing
			var house_mesh := MeshInstance3D.new()
			house_mesh.name = "FlashlightHousing"
			var house := CylinderMesh.new()
			house.top_radius = 0.12
			house.bottom_radius = 0.12
			house.height = 0.28
			house_mesh.mesh = house
			house_mesh.material_override = house_mat
			house_mesh.position = Vector3(0.0, 0.0, 0.0)
			house_mesh.rotation_degrees = Vector3(90, 0, 0)
			fixture.add_child(house_mesh)

			# Emissive lens face at front of cylinder
			var lens_mesh := MeshInstance3D.new()
			lens_mesh.name = "FlashlightLens"
			var lens := CylinderMesh.new()
			lens.top_radius = 0.10
			lens.bottom_radius = 0.10
			lens.height = 0.04
			lens_mesh.mesh = lens
			lens_mesh.material_override = lens_mat
			lens_mesh.position = Vector3(0.0, 0.0, -0.15)
			lens_mesh.rotation_degrees = Vector3(90, 0, 0)
			fixture.add_child(lens_mesh)

			# Functional SpotLight3D shining forward into the darkness
			var spot := SpotLight3D.new()
			spot.name = "FlashlightSpot"
			spot.position = Vector3(0.0, 0.0, -0.17)
			spot.rotation_degrees = Vector3(0, 0, 0) # Shines forward through the front lens along fixture -Z
			spot.light_color = Color(1.0, 0.95, 0.85)
			spot.light_energy = 2.8
			spot.spot_range = 22.0
			spot.spot_angle = 38.0
			spot.shadow_enabled = true
			fixture.add_child(spot)

		pack.add_child(lights_node)
		_shoulder_lights = lights_node

		_spine_attachment.add_child(pack)
		_active_backpack = pack

	# Panoramic gold solar radiation scanner visor (properly seated on front face)
	if _head_attachment != null:
		var visor := Node3D.new()
		visor.name = "ExplorerVisor"
		visor.position = Vector3(0.0, -0.08, -1.45)

		var bronze_mat := StandardMaterial3D.new()
		bronze_mat.albedo_color = Color(0.42, 0.38, 0.30)
		bronze_mat.metallic = 0.85
		bronze_mat.roughness = 0.35

		var gold_mat := StandardMaterial3D.new()
		gold_mat.albedo_color = Color(0.95, 0.78, 0.22) # Reflective gold
		gold_mat.metallic = 0.95
		gold_mat.roughness = 0.12

		var cyan_telemetry_mat := StandardMaterial3D.new()
		cyan_telemetry_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		cyan_telemetry_mat.albedo_color = Color(0.2, 0.9, 1.0) # Rangefinder laser diodes

		# Armored brow mount
		var brow_mesh := MeshInstance3D.new()
		var b_box := BoxMesh.new()
		b_box.size = Vector3(0.94, 0.10, 0.14)
		brow_mesh.mesh = b_box
		brow_mesh.material_override = bronze_mat
		brow_mesh.position = Vector3(0, 0.14, 0.02)
		visor.add_child(brow_mesh)

		# Panoramic gold scanner faceplate
		var visor_mesh := MeshInstance3D.new()
		var v_box := BoxMesh.new()
		v_box.size = Vector3(0.88, 0.24, 0.10)
		visor_mesh.mesh = v_box
		visor_mesh.material_override = gold_mat
		visor_mesh.position = Vector3(0, 0.0, 0.0)
		visor.add_child(visor_mesh)

		# Dual optical rangefinder lenses on left temple
		for y_off in [0.08, -0.04]:
			var rf_lens := MeshInstance3D.new()
			var rf_cyl := CylinderMesh.new()
			rf_cyl.top_radius = 0.03
			rf_cyl.bottom_radius = 0.03
			rf_cyl.height = 0.08
			rf_lens.mesh = rf_cyl
			rf_lens.material_override = cyan_telemetry_mat
			rf_lens.position = Vector3(0.48, y_off, -0.02)
			rf_lens.rotation_degrees = Vector3(90, 0, 0)
			visor.add_child(rf_lens)

		_head_attachment.add_child(visor)
		_active_visor = visor
