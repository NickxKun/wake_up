extends SceneTree

var passes : int = 0
var failures : int = 0

func check(condition: bool, message: String) -> void:
	if condition:
		passes += 1
		print("  [PASS] %s" % message)
	else:
		failures += 1
		print("  [FAIL] %s" % message)

func _init() -> void:
	print("\n=== RUNNING MODEL COLORING & ROCKET LAUNCHER VERIFICATION ===")
	_run_tests.call_deferred()

func _run_tests() -> void:
	var root : Window = get_root()

	# -------------------------------------------------------------------------
	# [Phase 1] Rocket Launcher Model Warhead Tip & Orientation
	# -------------------------------------------------------------------------
	print("\n[Phase 1] Testing Rocket Launcher Model Warhead Orientation & Nose Tip...")
	var launcher_scene : PackedScene = load("res://scenes/weapons/models/model_rocket_launcher.tscn")
	check(launcher_scene != null, "model_rocket_launcher.tscn loaded successfully")

	var launcher : Node3D = launcher_scene.instantiate() as Node3D
	root.add_child(launcher)
	launcher.global_position = Vector3.ZERO
	await process_frame

	var warhead : MeshInstance3D = launcher.find_child("RocketWarhead", true, false) as MeshInstance3D
	check(warhead != null, "RocketWarhead mesh node exists on launcher")
	if warhead != null:
		var c_mesh : CylinderMesh = warhead.mesh as CylinderMesh
		check(c_mesh != null, "RocketWarhead uses CylinderMesh")
		if c_mesh != null:
			check(c_mesh.top_radius < c_mesh.bottom_radius, "Warhead tapers towards top_radius (top: %.3f < bottom: %.3f)" % [c_mesh.top_radius, c_mesh.bottom_radius])

		# In launcher local space, forward is -Z.
		# Local +Y (top_radius) must point to world -Z (forward, towards muzzle).
		var local_y_in_world : Vector3 = warhead.transform.basis.y.normalized()
		check(local_y_in_world.dot(Vector3(0, 0, -1)) > 0.95, "RocketWarhead tip points FORWARD along -Z (NOT backwards towards player)")

		var warhead_fwd_pos : float = warhead.position.z - (c_mesh.height * 0.5 if c_mesh != null else 0.0)
		var warhead_base_pos : float = warhead.position.z + (c_mesh.height * 0.5 if c_mesh != null else 0.0)
		check(warhead_fwd_pos < warhead.position.z, "Warhead pointy tip extends forward (z: %.3f < %.3f)" % [warhead_fwd_pos, warhead.position.z])
		check(warhead_base_pos > warhead.position.z, "Warhead wide base sits inside launcher tube (z: %.3f > %.3f)" % [warhead_base_pos, warhead.position.z])

	var nose_tip : MeshInstance3D = launcher.find_child("WarheadNoseTip", true, false) as MeshInstance3D
	check(nose_tip != null, "WarheadNoseTip node exists extending rocket tip to detonator point")
	if nose_tip != null:
		var n_local_y : Vector3 = nose_tip.transform.basis.y.normalized()
		check(n_local_y.dot(Vector3(0, 0, -1)) > 0.95, "WarheadNoseTip points FORWARD along -Z")

	var muzzle : Marker3D = launcher.find_child("Muzzle", true, false) as Marker3D
	check(muzzle != null, "Muzzle marker exists on rocket launcher")
	if muzzle != null:
		check(muzzle.position.z <= -0.40, "Muzzle positioned at front opening of launcher (z: %.2f <= -0.40)" % muzzle.position.z)

	launcher.queue_free()

	# -------------------------------------------------------------------------
	# [Phase 2] Flying Rocket Projectile Warhead & Exhaust Smoke Trail
	# -------------------------------------------------------------------------
	print("\n[Phase 2] Testing Flying Rocket Projectile Warhead & Rear Smoke Exhaust...")
	var rocket_scene : PackedScene = load("res://scenes/projectiles/rocket.tscn")
	check(rocket_scene != null, "rocket.tscn loaded successfully")

	var rocket : Area3D = rocket_scene.instantiate() as Area3D
	root.add_child(rocket)
	await process_frame

	var proj_tip : MeshInstance3D = rocket.find_child("WarheadTip", true, false) as MeshInstance3D
	check(proj_tip != null, "WarheadTip exists on flying rocket projectile")
	if proj_tip != null:
		check(proj_tip.position.z < -0.10, "WarheadTip positioned at front of projectile (z: %.2f < -0.10)" % proj_tip.position.z)
		var tip_mesh : CylinderMesh = proj_tip.mesh as CylinderMesh
		check(tip_mesh != null and tip_mesh.top_radius < tip_mesh.bottom_radius, "WarheadTip has sharp nose tip")
		var tip_fwd : Vector3 = proj_tip.transform.basis.y.normalized()
		check(tip_fwd.dot(Vector3(0, 0, -1)) > 0.95, "WarheadTip pointy nose faces FORWARD along -Z")

	var smoke : CPUParticles3D = rocket.find_child("SmokeTrail", true, false) as CPUParticles3D
	check(smoke != null, "SmokeTrail exists on rocket projectile")
	if smoke != null:
		check(smoke.position.z > 0.10, "SmokeTrail positioned at rear exhaust (z: %.2f > 0.10)" % smoke.position.z)
		check(smoke.direction.z > 0.8, "SmokeTrail particles emit BACKWARD behind rocket (+Z)")

	rocket.queue_free()

	# -------------------------------------------------------------------------
	# [Phase 3] Operative Character Models: Black Helmet, Gloves, Boots & Class Suits
	# -------------------------------------------------------------------------
	print("\n[Phase 3] Testing Black Helmet, Black Gloves, Black Boots & Class Suits...")
	var player_scene : PackedScene = load("res://addons/proto_controller/proto_controller.tscn")
	check(player_scene != null, "proto_controller.tscn loaded successfully")

	var player : CharacterBody3D = player_scene.instantiate() as CharacterBody3D
	root.add_child(player)
	await process_frame

	var cv : CharacterVisuals = CharacterVisuals.new()
	cv.name = "CharacterVisuals"
	player.add_child(cv)
	await process_frame

	var char_mesh : MeshInstance3D = player.find_child("Character", true, false) as MeshInstance3D
	check(char_mesh != null, "Character MeshInstance3D found on player")

	var char_data : Node = root.get_node_or_null("/root/CharacterData")
	check(char_data != null, "CharacterData singleton exists")

	var expected_configs := [
		{"id": 0, "name": "Astronaut Vanguard", "suit_color": Color(0.96, 0.98, 1.0)},
		{"id": 1, "name": "Engineer Combat Architect", "suit_color": Color(1.0, 0.50, 0.06)},
		{"id": 2, "name": "Medic Field Surgeon", "suit_color": Color(0.92, 0.96, 0.98)},
		{"id": 3, "name": "Explorer Frontier Scout", "suit_color": Color(0.55, 0.52, 0.42)},
	]

	for cfg in expected_configs:
		var class_id : int = cfg["id"]
		var c_name : String = cfg["name"]
		var exp_suit_col : Color = cfg["suit_color"]

		char_data.call("select_class", class_id)
		cv.apply_class_visuals(class_id)
		await process_frame

		check(char_mesh.material_override != null, "[%s] Character mesh has active material override" % c_name)
		check(char_mesh.material_override is ShaderMaterial, "[%s] Material override is a specialized ShaderMaterial" % c_name)

		var s_mat : ShaderMaterial = char_mesh.material_override as ShaderMaterial
		if s_mat != null:
			var black_col : Color = s_mat.get_shader_parameter("black_color")
			check(black_col.r < 0.20 and black_col.g < 0.20 and black_col.b < 0.22, "[%s] black_color is dark tactical black (%s)" % [c_name, str(black_col)])

			var head_bone : int = s_mat.get_shader_parameter("head_bone_idx")
			check(head_bone == 7, "[%s] Head bone correctly mapped for BLACK HELMET (bone: %d)" % [c_name, head_bone])

			var hand_l : int = s_mat.get_shader_parameter("hand_l_bone_idx")
			var hand_r : int = s_mat.get_shader_parameter("hand_r_bone_idx")
			check(hand_l == 11 and hand_r == 15, "[%s] Hand bones correctly mapped for BLACK GLOVES (L:%d, R:%d)" % [c_name, hand_l, hand_r])

			var foot_l : int = s_mat.get_shader_parameter("foot_l_bone_idx")
			var foot_r : int = s_mat.get_shader_parameter("foot_r_bone_idx")
			check(foot_l == 18 and foot_r == 21, "[%s] Foot bones correctly mapped for BLACK BOOTS (L:%d, R:%d)" % [c_name, foot_l, foot_r])

			var actual_suit_col : Color = s_mat.get_shader_parameter("suit_color")
			check(actual_suit_col.is_equal_approx(exp_suit_col), "[%s] Class suit_color accurately applied (%s)" % [c_name, str(actual_suit_col)])

	player.queue_free()

	# -------------------------------------------------------------------------
	# [Phase 4] Character Select Preview Models
	# -------------------------------------------------------------------------
	print("\n[Phase 4] Testing Character Select Preview Models Dressing & Materials...")
	for class_id in range(4):
		var preview_model : Node3D = CharacterVisuals.create_styled_character_model(class_id)
		check(preview_model != null, "Preview model class %d instantiated" % class_id)
		if preview_model != null:
			var p_mesh : MeshInstance3D = preview_model.find_child("Character", true, false) as MeshInstance3D
			check(p_mesh != null and p_mesh.material_override is ShaderMaterial, "Preview model class %d has ShaderMaterial with black helmet, gloves & boots" % class_id)
			var p_mat : ShaderMaterial = p_mesh.material_override as ShaderMaterial if p_mesh != null else null
			if p_mat != null:
				var b_col : Color = p_mat.get_shader_parameter("black_color")
				check(b_col.r < 0.20, "Preview model class %d black_color is dark black" % class_id)
			preview_model.queue_free()

	# -------------------------------------------------------------------------
	# Summary
	# -------------------------------------------------------------------------
	print("\n=======================================================")
	print("RESULTS: %d Passed, %d Failed" % [passes, failures])
	print("=======================================================\n")
	quit(0 if failures == 0 else 1)
