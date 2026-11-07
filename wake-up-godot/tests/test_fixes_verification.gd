extends SceneTree

var _passed : int = 0
var _failed : int = 0

func check(condition: bool, msg: String) -> void:
	if condition:
		_passed += 1
		print("  [PASS] %s" % msg)
	else:
		_failed += 1
		print("  [FAIL] %s" % msg)

func _initialize() -> void:
	print("\n--- Running Comprehensive Fixes Verification Suite ---")

	# -------------------------------------------------------------------------
	# 1. TEST TURRET ORIENTATION & DEPLOYMENT
	# -------------------------------------------------------------------------
	print("\n[Phase 1] Testing Sentry Turret Visuals & Aiming...")
	var turret_scene : PackedScene = load("res://scenes/entities/sentry_turret.tscn")
	check(turret_scene != null, "Loaded sentry_turret.tscn")
	var turret : Node3D = turret_scene.instantiate() as Node3D
	root.add_child(turret)
	await process_frame
	await process_frame

	var swivel : Node3D = turret.get_node_or_null("TurretBase/SwivelHead") as Node3D
	check(swivel != null, "SwivelHead node exists")
	var optic : MeshInstance3D = turret.get_node_or_null("TurretBase/SwivelHead/TargetingOptic") as MeshInstance3D
	check(optic != null, "TargetingOptic exists on SwivelHead")
	check(optic != null and optic.position.z < 0.0, "TargetingOptic positioned on front of turret head (z: %.3f < 0.0)" % (optic.position.z if optic else 0.0))
	
	var muzzle_l : Marker3D = turret.get_node_or_null("TurretBase/SwivelHead/MuzzleL") as Marker3D
	check(muzzle_l != null and muzzle_l.position.z < 0.0, "Barrels and Muzzles positioned on front (z: %.3f < 0.0)" % (muzzle_l.position.z if muzzle_l else 0.0))

	# Verify Heavy Quad Outrigger Platform and Chassis Details
	var ring : MeshInstance3D = turret.get_node_or_null("TurretBase/TurntableRing") as MeshInstance3D
	check(ring != null, "TurntableRing collar base exists")
	var out1 : Node3D = turret.get_node_or_null("TurretBase/Outrigger1") as Node3D
	var out2 : Node3D = turret.get_node_or_null("TurretBase/Outrigger2") as Node3D
	var out3 : Node3D = turret.get_node_or_null("TurretBase/Outrigger3") as Node3D
	var out4 : Node3D = turret.get_node_or_null("TurretBase/Outrigger4") as Node3D
	check(out1 != null and out2 != null and out3 != null and out4 != null, "Turret features reinforced quad outrigger stabilizer base (Outrigger1..4)")
	if out1 != null:
		check(out1.get_node_or_null("FootPad") != null, "Outrigger features heavy magnetic foot pad on ground")
		check(out1.get_node_or_null("HydraulicStrut") != null, "Outrigger features hydraulic compression strut")

	var fins : MeshInstance3D = turret.get_node_or_null("TurretBase/SwivelHead/HeatSinkFins") as MeshInstance3D
	var drum : MeshInstance3D = turret.get_node_or_null("TurretBase/SwivelHead/PowerDrum") as MeshInstance3D
	var chute : MeshInstance3D = turret.get_node_or_null("TurretBase/SwivelHead/AmmoChute") as MeshInstance3D
	var comp_l : MeshInstance3D = turret.get_node_or_null("TurretBase/SwivelHead/CompensatorL") as MeshInstance3D
	var comp_r : MeshInstance3D = turret.get_node_or_null("TurretBase/SwivelHead/CompensatorR") as MeshInstance3D
	var laser : MeshInstance3D = turret.get_node_or_null("TurretBase/SwivelHead/TargetingLaser") as MeshInstance3D
	check(fins != null, "Turret SwivelHead features rear heat sink cooling radiator fins")
	check(drum != null and chute != null, "Turret SwivelHead features side ammo drum and feed chute")
	check(comp_l != null and comp_r != null, "Turret barrels feature slotted compensator muzzle brakes")
	check(laser != null, "Turret SwivelHead features targeting laser emitter")

	# Test Aiming East (+X)
	var enemy := Node3D.new()
	enemy.add_to_group("enemy")
	var hc := HealthComponent.new()
	enemy.add_child(hc)
	root.add_child(enemy)
	enemy.global_position = turret.global_position + Vector3(6.0, 0.0, 0.0)

	for _i in range(15):
		turret.call("_physics_process", 0.033)
		await process_frame

	var fwd_east : Vector3 = -swivel.global_transform.basis.z.normalized()
	check(fwd_east.x > 0.85, "Turret front points towards East target (fwd.x: %.2f > 0.85)" % fwd_east.x)
	check(abs(fwd_east.z) < 0.4, "Turret is horizontally aligned with East target")

	# Test bullet fire forward towards target
	turret.set("_fire_timer", 0.0)
	turret.call("_physics_process", 0.033)
	await process_frame

	var bullets := root.find_children("*", "Area3D", true, false)
	var spawned_b : Area3D = null
	for b in bullets:
		if (b as Node).get("shooter") == turret:
			spawned_b = b as Area3D
			break
	check(spawned_b != null, "Turret discharged kinetic round")
	if spawned_b != null:
		var b_dir : Vector3 = spawned_b.get("direction")
		check(b_dir.x > 0.85, "Bullet fired forward towards target (dir.x: %.2f > 0.85, NOT backwards)" % b_dir.x)

	# Test Player deploying turret in front of player
	var pc_scene : PackedScene = load("res://addons/proto_controller/proto_controller.tscn")
	var pc : CharacterBody3D = pc_scene.instantiate() as CharacterBody3D
	root.add_child(pc)
	await process_frame
	await process_frame

	var char_data : Node = root.get_node_or_null("/root/CharacterData")
	char_data.call("select_class", 1) # Engineer
	var combat : Node = pc.get_node_or_null("PlayerCombat")
	if combat == null:
		var combat_script : Script = load("res://scenes/player/player_combat.gd")
		combat = Node.new()
		combat.name = "PlayerCombat"
		combat.set_script(combat_script)
		pc.add_child(combat)
	check(combat != null, "PlayerCombat found")

	# Player facing East (-basis.z points East, rotation.y = -PI/2)
	pc.global_position = Vector3(10.0, 0.0, 10.0)
	pc.global_rotation.y = deg_to_rad(-90.0)
	combat.call("_deploy_sentry_turret")
	await process_frame

	var turrets := root.find_children("*", "StaticBody3D", true, false)
	var deployed : Node3D = null
	for t in turrets:
		if t != turret and (t as Node).is_in_group("turret"):
			deployed = t as Node3D
			break
	check(deployed != null, "Engineer deployed turret into world")
	if deployed != null:
		var offset : Vector3 = deployed.global_position - pc.global_position
		check(offset.x > 0.5, "Turret deployed IN FRONT of player towards target (offset.x: %.2f > 0.5)" % offset.x)
		check(abs(deployed.global_rotation.y - pc.global_rotation.y) < 0.1, "Deployed turret rotation matches player facing")

		# Test Wrench Repair Range Nerf
		var dep_hc : HealthComponent = deployed.get_node_or_null("HealthComponent") as HealthComponent
		if dep_hc != null:
			dep_hc.health = 50
			# Player stands 2.5m away (out of melee reach)
			pc.global_position = deployed.global_position + Vector3(2.5, 0.0, 0.0)
			combat.call("_fire_wrench", pc.global_position, Vector3(-1.0, 0.0, 0.0), false)
			check(dep_hc.health == 50, "Mechanic CANNOT repair turret from far away (dist 2.5m > 1.35m limit)")

			# Player approaches to point-blank contact (1.1m)
			pc.global_position = deployed.global_position + Vector3(1.1, 0.0, 0.0)
			combat.call("_fire_wrench", pc.global_position, Vector3(-1.0, 0.0, 0.0), false)
			check(dep_hc.health == 75, "Mechanic repairs turret at close melee contact (dist 1.1m <= 1.35m)")

	# -------------------------------------------------------------------------
	# 2. TEST EXPLORER SEARCHLIGHT & WEAPON PICKUP ZOOM
	# -------------------------------------------------------------------------
	print("\n[Phase 2] Testing Explorer Searchlights & Camera Zoom...")
	char_data.call("select_class", 3) # Explorer
	pc.call("_update_explorer_perks", 3)
	await process_frame
	await process_frame

	# Verify shoulder lights point forward and fixtures are rotated 180 degrees
	var fix_l : Node3D = pc.find_child("FlashlightFixture_L", true, false) as Node3D
	var fix_r : Node3D = pc.find_child("FlashlightFixture_R", true, false) as Node3D
	check(fix_l != null and fix_r != null, "Explorer has dual flashlight fixtures")
	if fix_l != null:
		check(abs(fix_l.rotation_degrees.y - 180.0) < 1.0, "Flashlight fixture rotated by 180 degrees (%.1f deg)" % fix_l.rotation_degrees.y)

	var spots := pc.find_children("*", "SpotLight3D", true, false)
	check(spots.size() >= 2, "Explorer has dual shoulder searchlights")
	for i in range(spots.size()):
		var spot := spots[i] as SpotLight3D
		var light_fwd : Vector3 = -spot.global_transform.basis.z.normalized()
		var player_facing : Vector3 = Vector3(sin(pc.rotation.y), 0.0, cos(pc.rotation.y)).normalized()
		var light_dot : float = light_fwd.dot(player_facing)
		check(light_dot > 0.8, "Searchlight %d shines forward with player facing (dot: %.2f > 0.8, NOT backwards)" % [i + 1, light_dot])

	# Verify camera size starts at Explorer zoom (5.2)
	var cam : Camera3D = Camera3D.new()
	cam.add_to_group("camera")
	root.add_child(cam)
	cam.make_current()
	cam.size = 5.2
	await process_frame

	check(abs(char_data.call("get_camera_ortho_size") - 5.2) < 0.01, "CharacterData reports 5.2 ortho size for Explorer")

	# Simulate picking up a weapon (e.g. Shotgun, Rocket Launcher, etc.)
	combat.call("equip_special_weapon", 1, true) # WeaponType.SHOTGUN
	combat.call("_update_camera_sniper_zoom")
	for _i in range(15):
		await process_frame

	check(abs(cam.size - 5.2) < 0.1, "Explorer camera zoom NOT reset on weapon pickup (cam.size: %.2f == 5.2)" % cam.size)

	# Simulate equipping Sniper then swapping back
	combat.call("equip_special_weapon", 2, true) # WeaponType.SNIPER
	combat.call("_update_camera_sniper_zoom")
	for _i in range(15):
		await process_frame
	check(cam.size > 6.0, "Equipping Sniper zooms out (cam.size: %.2f > 6.0)" % cam.size)

	combat.call("equip_weapon", 0, true) # Back to basic weapon
	combat.call("_update_camera_sniper_zoom")
	for _i in range(30):
		await process_frame
	check(abs(cam.size - 5.2) < 0.1, "Switching away from Sniper returns cleanly to Explorer zoom (%.2f == 5.2)" % cam.size)

	# -------------------------------------------------------------------------
	# 3. TEST HEAD ATTACHMENT BONE & HEADGEAR POSITIONING FOR ALL CLASSES
	# -------------------------------------------------------------------------
	print("\n[Phase 3] Testing Head Attachment & Headgear Positioning...")
	var cv : Node = pc.get_node_or_null("CharacterVisuals")
	var head_att : BoneAttachment3D = pc.find_child("HeadAttachment", true, false) as BoneAttachment3D
	check(head_att != null, "HeadAttachment node exists")
	check(head_att.bone_name == "Head", "HeadAttachment is attached to bone 'Head' (NOT Spine2)")

	for class_id in range(4):
		char_data.call("select_class", class_id)
		cv.call("apply_class_visuals", class_id)
		await process_frame
		await process_frame

		var visor : Node3D = null
		match class_id:
			0: visor = pc.find_child("AstronautVisor", true, false) as Node3D
			1: visor = pc.find_child("EngineerVisor", true, false) as Node3D
			2: visor = pc.find_child("MedicVisor", true, false) as Node3D
			3: visor = pc.find_child("ExplorerVisor", true, false) as Node3D

		check(visor != null, "Class %d has headgear accessory attached" % class_id)
		if visor != null:
			# Verify visor sits on helmet face, not inside skull
			var head_bone_idx : int = 7
			var sk : Skeleton3D = pc.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
			var head_origin : Vector3 = (sk.global_transform * sk.get_bone_global_pose(head_bone_idx)).origin
			var offset : Vector3 = visor.global_position - head_origin
			var fwd_dist : float = offset.dot(-pc.global_transform.basis.z.normalized())
			check(fwd_dist > 0.10 and fwd_dist < 0.20, "Class %d headgear sits flush on front face (dist: %.3f m, NOT inside skull)" % [class_id, fwd_dist])

	# Also verify create_styled_character_model creates HeadAttachment on "Head"
	for class_id in range(4):
		var banner_model : Node3D = CharacterVisuals.create_styled_character_model(class_id)
		var b_head : BoneAttachment3D = banner_model.find_child("HeadAttachment", true, false) as BoneAttachment3D
		check(b_head != null and b_head.bone_name == "Head", "Banner model class %d has HeadAttachment on 'Head'" % class_id)
		banner_model.free()

	# -------------------------------------------------------------------------
	# 4. TEST CHARACTER SELECT BANNER ORIENTATION, SIGNATURE WEAPONS, ANIMATION & ISOLATION
	# -------------------------------------------------------------------------
	print("\n[Phase 4] Testing Character Select Banners, Facing, Weapons, Poses & Isolation...")
	var menu_scene : PackedScene = load("res://scenes/ui/main_menu.tscn")
	var menu : Node = menu_scene.instantiate()
	root.add_child(menu)
	if menu.has_method("_setup_operative_banners"):
		menu.call("_setup_operative_banners")

	await process_frame
	await process_frame

	var card_names := ["AstronautCard", "EngineerCard", "MedicCard", "ExplorerCard"]
	var expected_visors := ["AstronautVisor", "EngineerVisor", "MedicVisor", "ExplorerVisor"]
	var expected_weapons := ["ModelPistol", "ModelWrench", "ModelShotgun", "ModelSniper"]

	for i in range(card_names.size()):
		var cname : String = card_names[i]
		var card : Button = menu.find_child(cname, true, false) as Button
		check(card != null, "Card button %s found" % cname)

		var pivot : Node3D = card.find_child("ModelPivot", true, false) as Node3D
		check(pivot != null, "ModelPivot found in %s" % cname)
		if pivot != null:
			# Verify model faces the camera (+Z) with hero angle (approx -12 degrees / 348 degrees)
			var y_deg : float = fposmod(pivot.rotation_degrees.y, 360.0)
			check(abs(y_deg - 348.0) < 6.0 or abs(y_deg - 168.0) < 6.0 or abs(pivot.rotation_degrees.y + 12.0) < 6.0, "%s ModelPivot faces camera (+Z) at hero angle (%.1f deg)" % [cname, y_deg])

			check(pivot.get_child_count() > 0, "%s has 3D character model attached" % cname)
			var model : Node3D = pivot.get_child(0) as Node3D
			if model != null:
				var visuals : CharacterVisuals = model.find_child("CharacterVisuals", true, false) as CharacterVisuals
				check(visuals != null and visuals.is_preview == true, "%s has CharacterVisuals with is_preview=true" % cname)
				check(visuals != null and visuals.preview_class_id == i, "%s CharacterVisuals is locked to class %d" % [cname, i])

				# Verify distinct visual identity
				var visor : Node3D = model.find_child(expected_visors[i], true, false) as Node3D
				check(visor != null, "%s displays correct distinct class headgear (%s)" % [cname, expected_visors[i]])

				# Verify GunAttachment and signature weapon
				var gun_att : BoneAttachment3D = model.find_child("GunAttachment", true, false) as BoneAttachment3D
				check(gun_att != null and gun_att.bone_name == "Hand.R", "%s has GunAttachment mounted on 'Hand.R'" % cname)

				var weapon : Node3D = gun_att.get_child(0) if gun_att != null and gun_att.get_child_count() > 0 else null
				check(weapon != null and weapon.name == expected_weapons[i], "%s has signature weapon '%s' equipped in hand" % [cname, expected_weapons[i]])

				# Verify model is NOT in T-pose (UpperArm.L is lowered, UpperArm.R is aimed)
				var skel : Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
				var u_l_idx : int = skel.find_bone("UpperArm.L")
				var u_r_idx : int = skel.find_bone("UpperArm.R")
				var u_l_rot : Quaternion = skel.get_bone_pose_rotation(u_l_idx)
				var rest_l_rot : Quaternion = skel.get_bone_rest(u_l_idx).basis.get_rotation_quaternion()
				check(u_l_rot != rest_l_rot, "%s arm is posed (NOT in default horizontal T-pose)" % cname)

	# Test Card Isolation: Selecting another operative MUST NOT duplicate/overwrite other cards!
	print("\n[Phase 4.1] Testing Card Isolation against duplicate overwrite...")
	char_data.call("select_class", 1) # Select Engineer
	await process_frame
	await process_frame

	var astro_card : Button = menu.find_child("AstronautCard", true, false) as Button
	var astro_model : Node3D = astro_card.find_child("ModelPivot", true, false).get_child(0) as Node3D
	check(astro_model.find_child("AstronautVisor", true, false) != null, "Selecting Engineer does NOT overwrite Astronaut card")
	check(astro_model.find_child("EngineerVisor", true, false) == null, "Astronaut card did NOT duplicate Engineer visuals")

	var medic_card : Button = menu.find_child("MedicCard", true, false) as Button
	var medic_model : Node3D = medic_card.find_child("ModelPivot", true, false).get_child(0) as Node3D
	check(medic_model.find_child("MedicVisor", true, false) != null, "Selecting Engineer does NOT overwrite Medic card")
	check(medic_model.find_child("EngineerVisor", true, false) == null, "Medic card did NOT duplicate Engineer visuals")

	char_data.call("select_class", 3) # Select Explorer
	await process_frame
	await process_frame
	check(astro_model.find_child("AstronautVisor", true, false) != null, "Selecting Explorer does NOT overwrite Astronaut card")
	check(medic_model.find_child("MedicVisor", true, false) != null, "Selecting Explorer does NOT overwrite Medic card")

	# Test animation updates over time
	var skel_astro : Skeleton3D = astro_model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var spine_rot_before : Quaternion = skel_astro.get_bone_pose_rotation(skel_astro.find_bone("Spine1"))
	for _f in range(20):
		await process_frame
	var spine_rot_after : Quaternion = skel_astro.get_bone_pose_rotation(skel_astro.find_bone("Spine1"))
	check(spine_rot_before != spine_rot_after, "Preview models actively animate over time (breathing/idle sway active)")

	menu.queue_free()

	# -------------------------------------------------------------------------
	# 5. TEST SPACE TRUCK GATLING GUN TURRET (WARTHOG-STYLE DEPLOYMENT & FIRING)
	# -------------------------------------------------------------------------
	print("\n[Phase 5] Testing Space Truck Gatling Gun Turret...")
	var truck_scene : PackedScene = load("res://scenes/vehicles/spacetruck.tscn")
	check(truck_scene != null, "Loaded spacetruck.tscn")
	var truck : CharacterBody3D = truck_scene.instantiate() as CharacterBody3D
	root.add_child(truck)
	truck.global_position = Vector3(10.0, 0.0, 10.0)
	await process_frame
	await process_frame

	var gatling : Node3D = truck.find_child("GatlingTurret", true, false) as Node3D
	check(gatling != null, "Space Truck has GatlingTurret node mounted in rear bed")
	if gatling != null:
		check(not gatling.is_deployed, "GatlingTurret starts stowed/retracted when unoccupied")

		# Explorer / Scout boards the Space Truck
		pc.set_meta("character_class", 3)
		char_data.call("select_class", 3)
		truck.board_vehicle(pc)
		check(truck.is_occupied, "Explorer successfully boarded Space Truck")
		check(gatling.is_deploying or gatling.is_deployed, "GatlingTurret triggered deployment animation on Explorer boarding")

		# Wait for deployment animation to finish (0.45s)
		if gatling.is_deploying:
			await gatling.deployed
		await process_frame

		check(gatling.is_deployed, "GatlingTurret successfully deployed into combat ready posture")
		check(gatling.position.y <= 0.20, "GatlingTurret mounted low in rear truck bed (y: %.2f <= 0.20)" % gatling.position.y)
		check(gatling.get_node_or_null("MountBase/MountPedestal") != null, "GatlingTurret features grounded MountPedestal collar")
		check(gatling.hydraulic_riser != null and gatling.hydraulic_riser.position.y >= 0.15, "Hydraulic riser elevated from bed (y: %.2f >= 0.15)" % gatling.hydraulic_riser.position.y)

		# Verify quad rotary barrels
		check(gatling.rotor_hub != null, "BarrelsRotor exists on turret")
		var barrel_count : int = 0
		for c in gatling.rotor_hub.get_children():
			if c.name.begins_with("Barrel"):
				barrel_count += 1
		check(barrel_count == 4, "GatlingTurret has 4 heavy rotary barrels")

		# Test aim tracking
		var aim_pos : Vector3 = truck.global_position + Vector3(15.0, 2.0, 5.0)
		gatling.track_aim(aim_pos, 0.2)
		await process_frame
		check(gatling.turret_swivel != null and abs(gatling.turret_swivel.rotation.y) > 0.01, "Turret swivel dynamically tracks target azimuth")

		# Test Gatling Gun firing
		var spin_before : float = gatling._rotor_spin_speed
		var bullet : Area3D = gatling.fire(aim_pos)
		check(bullet != null, "GatlingTurret fired heavy kinetic round directly from its barrels")
		check(gatling.muzzle_flash != null and gatling.muzzle_flash.visible, "GatlingTurret muzzle flash triggered on shot")
		check(gatling._rotor_spin_speed > spin_before, "Gatling rotor barrels spooled up to high speed (speed: %.1f rad/s)" % gatling._rotor_spin_speed)

		if bullet != null:
			check(bullet.shooter == truck, "Fired bullet shooter is correctly assigned to truck")
			check(bullet.damage >= 25, "Gatling bullet inflicts heavy damage (%d >= 25)" % bullet.damage)
			bullet.free()

		# Test dismount and retraction animation
		truck.exit_vehicle()
		check(not truck.is_occupied, "Explorer dismounted from Space Truck")
		check(gatling.is_retracting or not gatling.is_deployed, "GatlingTurret triggered retraction animation on dismount")

		if gatling.is_retracting:
			await gatling.retracted
		await process_frame

		check(not gatling.is_deployed, "GatlingTurret retracted back into truck bed flush")

	truck.queue_free()

	# -------------------------------------------------------------------------
	# 6. TEST ASTRONAUT BELT GRENADES & WAYPOINT-STYLE GRENADE WARNING INDICATOR
	# -------------------------------------------------------------------------
	print("\n[Phase 6] Testing Astronaut Belt Grenades & Grenade Warning Indicator...")
	char_data.call("select_class", 0) # Astronaut
	pc.call("_apply_class_perks", 0)
	await process_frame
	await process_frame

	var astro_belt : Node3D = pc.find_child("AstronautBelt", true, false) as Node3D
	check(astro_belt != null, "Astronaut has AstronautBelt equipped at waist")
	if astro_belt != null:
		var g1 : Node3D = astro_belt.find_child("CuteGrenade1", true, false) as Node3D
		var g2 : Node3D = astro_belt.find_child("CuteGrenade2", true, false) as Node3D
		var g3 : Node3D = astro_belt.find_child("CuteGrenade3", true, false) as Node3D
		check(g1 != null and g2 != null and g3 != null, "Astronaut wears 3 cute little frag grenades on belt")

	var astro_pack : Node3D = pc.find_child("AstronautPack", true, false) as Node3D
	check(astro_pack != null, "Astronaut has AstronautPack mounted on back")
	if astro_pack != null:
		var has_giant_cylinder : bool = false
		for c in astro_pack.get_children():
			if c is MeshInstance3D and (c as MeshInstance3D).mesh is CylinderMesh:
				var cyl_mesh := (c as MeshInstance3D).mesh as CylinderMesh
				if cyl_mesh.top_radius > 0.3 or cyl_mesh.height > 1.2:
					has_giant_cylinder = true
		check(not has_giant_cylinder, "Astronaut NO LONGER has giant awkward cylinder (replaced with sleek dual canisters)")

	# Test Grenade projectile & warning indicator
	var grenade_scene : PackedScene = load("res://scenes/projectiles/grenade.tscn")
	check(grenade_scene != null, "Loaded grenade.tscn")
	var grenade : Grenade = grenade_scene.instantiate() as Grenade
	grenade.shooter = pc
	root.add_child(grenade)
	grenade.global_position = pc.global_position + Vector3(3.0, 0.4, 0.0)
	await process_frame
	await process_frame

	# Verify in-world ground blast hazard ring
	var blast_ring : MeshInstance3D = grenade.find_child("GroundBlastRing", true, false) as MeshInstance3D
	check(blast_ring != null, "Live Grenade has GroundBlastRing matching explosion radius")
	if blast_ring != null and blast_ring.mesh is TorusMesh:
		var t_mesh := blast_ring.mesh as TorusMesh
		check(abs(t_mesh.outer_radius - grenade.explosion_radius) < 0.1, "GroundBlastRing outer radius matches grenade explosion radius (%.1f == %.1f)" % [t_mesh.outer_radius, grenade.explosion_radius])

	# Verify floating 3D warning beacon
	var beacon : Node3D = grenade.find_child("FloatingWarningBeacon", true, false) as Node3D
	check(beacon != null, "Live Grenade has FloatingWarningBeacon hovering above it")

	# Verify screen-space waypoint-style warning indicator
	var indicator : CanvasLayer = root.find_child("GrenadeIndicator", true, false) as CanvasLayer
	check(indicator != null, "Grenade instantiated Waypoint-Style GrenadeIndicator HUD")
	if indicator != null:
		check(indicator.edge_indicator != null, "GrenadeIndicator has edge_indicator root")
		check(indicator.edge_arrow != null, "GrenadeIndicator has edge_arrow for off-screen warnings")
		check(indicator.edge_reticle != null, "GrenadeIndicator has edge_reticle for on-screen tracking")
		check(indicator.edge_dist_label != null, "GrenadeIndicator has distance and fuse readout label")

	# Test detonation cleanup
	grenade.detonate(null, Vector3.UP)
	await process_frame
	await process_frame
	check(not is_instance_valid(grenade) or grenade.is_queued_for_deletion(), "Grenade detonated cleanly")

	# -------------------------------------------------------------------------
	# 7. TEST MEDIC AND SCOUT SIGNATURE STARTER WEAPONS
	# -------------------------------------------------------------------------
	print("\n[Phase 7] Testing Medic and Scout Signature Starter Weapons...")
	# 1. Medic: Compact Bio-Shotgun (low range, 5 pellets @ 16 dmg, 0.48s cooldown)
	char_data.call("select_class", 2) # Medic
	pc.call("_apply_class_perks", 2)
	await process_frame
	await process_frame
	check(combat.starter_slot1_weapon == 1, "Medic has Shotgun in Slot 1")
	check(combat.call("get_weapon_name") == "BIO-SHOTGUN", "Medic weapon name is BIO-SHOTGUN")
	check(abs(combat.shoot_cooldown - 0.48) < 0.01, "Medic Shotgun pump rate cooldown is 0.48s")

	# Clear any bullets before firing test
	for b in root.find_children("*", "Area3D", true, false):
		if (b as Node).is_in_group("bullet"):
			b.queue_free()
	await process_frame

	combat.call("_fire", false)
	await process_frame
	var medic_bullets := root.find_children("*", "Area3D", true, false)
	var medic_pellets : Array[Area3D] = []
	for b in medic_bullets:
		if (b as Node).is_in_group("bullet") and (b as Node).get("shooter") == pc:
			medic_pellets.append(b as Area3D)
	check(medic_pellets.size() == 5, "Medic starter shotgun fired 5 pellets (%d == 5)" % medic_pellets.size())
	if medic_pellets.size() > 0:
		var p0 : Area3D = medic_pellets[0]
		check(p0.get("damage") == 16, "Medic starter pellet inflicts 16 damage (compact shotgun)")
		check(abs(float(p0.get("lifetime")) - 0.35) < 0.05, "Medic starter pellet has short 0.35s lifetime (~6.3m range)")

	for p in medic_pellets:
		p.queue_free()

	# 2. Scout / Explorer: Marksman Rifle (high damage 110, 0.70s low fire rate, 2.2s lifetime)
	char_data.call("select_class", 3) # Explorer
	pc.call("_apply_class_perks", 3)
	await process_frame
	await process_frame
	check(combat.starter_slot1_weapon == 2, "Scout has Sniper in Slot 1")
	check(combat.call("get_weapon_name") == "MARKSMAN RIFLE", "Scout weapon name is MARKSMAN RIFLE")
	check(abs(combat.shoot_cooldown - 0.70) < 0.01, "Scout Marksman Rifle low fire rate cooldown is 0.70s")

	combat.call("_fire", false)
	await process_frame
	var scout_bullets := root.find_children("*", "Area3D", true, false)
	var scout_round : Area3D = null
	for b in scout_bullets:
		if (b as Node).is_in_group("bullet") and (b as Node).get("shooter") == pc:
			scout_round = b as Area3D
			break
	check(scout_round != null, "Scout fired marksman sniper round")
	if scout_round != null:
		check(scout_round.get("damage") == 110, "Scout marksman round inflicts 110 high damage")
		check(abs(float(scout_round.get("lifetime")) - 2.2) < 0.05, "Scout marksman round has extended 2.2s battlefield lifetime")
		scout_round.queue_free()

	print("\n==================================================")
	print("FIXES VERIFICATION RESULTS: %d Passed, %d Failed" % [_passed, _failed])
	print("==================================================")

	quit(1 if _failed > 0 else 0)
