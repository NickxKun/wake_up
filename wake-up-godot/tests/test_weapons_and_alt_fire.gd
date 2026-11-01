extends SceneTree

var passes : int = 0
var failures : int = 0

func check(condition: bool, message: String) -> void:
	if condition:
		passes += 1
		print("  [PASS] ", message)
	else:
		failures += 1
		print("  [FAIL] ", message)

func _initialize() -> void:
	print("=== RUNNING WEAPONS & ALT-FIRE TEST SUITE ===")
	await process_frame

	# -------------------------------------------------------------------------
	# 1. Test Alt-Fire Direction vs Primary Fire
	# -------------------------------------------------------------------------
	print("\n[Test 1] Testing Alt-Fire (Horizontal Facing) vs Primary Fire...")
	var player_node := CharacterBody3D.new()
	player_node.name = "ProtoController"
	player_node.add_to_group("player")
	root.add_child(player_node)

	var p_mesh := Node3D.new()
	p_mesh.name = "player"
	player_node.add_child(p_mesh)

	var hc_script = load("res://scenes/components/health_component.gd")
	var hc : Node = hc_script.new()
	hc.name = "HealthComponent"
	player_node.add_child(hc)

	var combat_script = load("res://scenes/player/player_combat.gd")
	var combat : Node = combat_script.new()
	combat.name = "PlayerCombat"
	player_node.add_child(combat)
	await process_frame

	# Facing in +Z direction
	player_node.rotation_degrees.y = 0.0
	check(combat.can_shoot == true, "Player can shoot initially")
	check(combat.current_weapon == combat.WeaponType.BASIC, "Initial weapon is BASIC pistol")
	check(combat.active_slot == combat.SLOT_BASIC, "Initial active slot is SLOT_BASIC (1)")

	# Test Alt-Fire trigger: fires in horizontal facing direction
	var bullets_before : int = 0
	for c in root.get_children():
		if c.name.begins_with("Bullet"):
			bullets_before += 1

	combat._fire(true) # Alt-fire (Right Click)
	await process_frame

	var alt_bullet : Area3D = null
	for c in root.get_children():
		if c.name.begins_with("Bullet"):
			alt_bullet = c as Area3D

	check(alt_bullet != null, "Alt-fire spawned bullet projectile")
	if alt_bullet != null:
		check(is_zero_approx(alt_bullet.direction.y), "Alt-fire bullet direction.y is 0.0 (horizontal parallel to floor)")
		check(alt_bullet.direction.z > 0.9, "Alt-fire bullet shoots along player facing direction (+Z)")

	# -------------------------------------------------------------------------
	# 2. Test Weapons Box Dispenser & 30-Second Replacement & 3D Model Display
	# -------------------------------------------------------------------------
	print("\n[Test 2] Testing Weapons Box Dispenser, Rotation & 3D Model Display...")
	var box_scene : PackedScene = load("res://scenes/weapons/weapons_box.tscn")
	check(box_scene != null, "weapons_box.tscn loaded successfully")
	var box : Node3D = box_scene.instantiate()
	root.add_child(box)
	await process_frame

	check(box.is_in_group("weapons_box"), "WeaponsBox is in group 'weapons_box'")
	check(box.current_weapon != -1, "WeaponsBox automatically dispensed a random weapon on start")
	var first_weapon : int = box.current_weapon
	check(first_weapon in [box.WeaponType.SHOTGUN, box.WeaponType.SNIPER, box.WeaponType.DOUBLE_PISTOLS, box.WeaponType.ROCKET_LAUNCHER], "Dispensed weapon is a valid special weapon")

	# Check that the dispenser instantiates the 3D model of the weapon inside HoloAnchor
	var holo_anchor : Node3D = box.get_node_or_null("HoloAnchor") as Node3D
	check(holo_anchor != null, "Dispenser has HoloAnchor")
	check(box._spawned_model != null, "Dispenser instantiated 3D weapon model in HoloAnchor")
	check(box._spawned_model is WeaponModel, "Spawned model in HoloAnchor is a WeaponModel instance")

	# Check non-colliding design
	var static_bodies : Array[Node] = box.find_children("*", "StaticBody3D", true, false)
	check(static_bodies.is_empty(), "WeaponsBox has NO StaticBody3D collision (non-blocking for vehicles/player/enemies)")

	# Test replacing existing weapon when new supply arrives
	box.spawn_random_weapon()
	check(box.current_weapon != -1, "New random weapon replaced the previous weapon in the dispenser")
	check(box.time_until_spawn == 30.0, "Dispenser timer reset to 30.0s")
	check(box._spawned_model != null, "Spawned model updated in HoloAnchor for new dispensed weapon")

	# -------------------------------------------------------------------------
	# 3. Test Dual Weapon Inventory (Pistol in Slot 1 AND Special in Slot 2)
	# -------------------------------------------------------------------------
	print("\n[Test 3] Testing Dual Weapon Inventory & Slot Switching...")
	check(combat.can_pickup_weapon() == true, "Player with basic gun can pick up special weapon")

	# Equip Shotgun (10 shells) into Slot 2
	combat.equip_weapon(combat.WeaponType.SHOTGUN)
	check(combat.active_slot == combat.SLOT_SPECIAL, "Equipping special weapon switches active slot to SLOT_SPECIAL (2)")
	check(combat.current_weapon == combat.WeaponType.SHOTGUN, "Active weapon is Shotgun")
	check(combat.current_ammo == 10, "Shotgun granted 10 shells")
	check(combat.special_ammo == 10, "Special ammo is 10")
	check(combat.can_pickup_weapon() == false, "Player CANNOT pick up another special weapon while special ammo remains")

	# Switch to Slot 1 (Basic Pistol)
	var switched_to_1 : bool = combat.switch_slot(combat.SLOT_BASIC)
	check(switched_to_1 == true, "Switched to Slot 1 (Basic Pistol)")
	check(combat.active_slot == combat.SLOT_BASIC, "Active slot is now 1")
	check(combat.current_weapon == combat.WeaponType.BASIC, "Current weapon is now BASIC pistol")
	check(combat.has_special_weapon() == true, "Player still retains special weapon in Slot 2!")
	check(combat.special_ammo == 10, "Shotgun in Slot 2 still has all 10 shells intact!")
	check(combat.can_pickup_weapon() == false, "Player still cannot pick up another weapon while Slot 2 has ammo")

	# Fire 5 shots with Basic Pistol in Slot 1
	for _i in range(5):
		combat._cooldown_left = 0.0
		combat._fire(false)
	check(combat.special_ammo == 10, "Firing basic pistol did NOT consume special weapon ammo (still 10)")

	# Switch back to Slot 2 (Special Weapon)
	var switched_to_2 : bool = combat.switch_slot(combat.SLOT_SPECIAL)
	check(switched_to_2 == true, "Switched back to Slot 2 (Shotgun)")
	check(combat.active_slot == combat.SLOT_SPECIAL, "Active slot is now 2")
	check(combat.current_weapon == combat.WeaponType.SHOTGUN, "Current weapon is Shotgun again")
	check(combat.current_ammo == 10, "Shotgun ammo is 10")

	# Fire 9 shots in Slot 2 -> 1 shell left
	for _i in range(9):
		combat._cooldown_left = 0.0
		combat._fire(false)
	check(combat.current_ammo == 1, "After 9 shotgun blasts, 1 shell remains")
	check(combat.special_ammo == 1, "Special ammo is 1")
	check(combat.current_weapon == combat.WeaponType.SHOTGUN, "Still holding Shotgun")

	# Fire final 10th shot -> ammo reaches 0 -> reverts to Basic Pistol in Slot 1!
	combat._cooldown_left = 0.0
	combat._fire(false)
	check(combat.active_slot == combat.SLOT_BASIC, "When special ammo hits 0, auto-switched to Slot 1")
	check(combat.current_weapon == combat.WeaponType.BASIC, "Current weapon reverted to BASIC pistol")
	check(combat.has_special_weapon() == false, "Slot 2 is now empty")
	check(combat.can_pickup_weapon() == true, "Player can now pick up a new special weapon from dispenser")

	# -------------------------------------------------------------------------
	# 4. Test All 5 Custom 3D Weapon Models
	# -------------------------------------------------------------------------
	print("\n[Test 4] Testing All 5 Custom 3D Weapon Models...")
	var model_paths : Dictionary = {
		"Pistol": "res://scenes/weapons/models/model_pistol.tscn",
		"Shotgun": "res://scenes/weapons/models/model_shotgun.tscn",
		"Sniper": "res://scenes/weapons/models/model_sniper.tscn",
		"Double Pistols": "res://scenes/weapons/models/model_double_pistols.tscn",
		"Rocket Launcher": "res://scenes/weapons/models/model_rocket_launcher.tscn",
	}

	for m_name in model_paths:
		var path : String = model_paths[m_name]
		var scn : PackedScene = load(path)
		check(scn != null, "%s model scene loads successfully" % m_name)
		if scn != null:
			var inst : Node3D = scn.instantiate() as Node3D
			check(inst != null, "%s instantiates as Node3D" % m_name)
			check(inst is WeaponModel, "%s inherits from WeaponModel" % m_name)
			var muz : Marker3D = inst.get_node_or_null("Muzzle") as Marker3D
			check(muz != null, "%s has Muzzle Marker3D" % m_name)
			var flash : CPUParticles3D = inst.get_node_or_null("Muzzle/Flash") as CPUParticles3D
			check(flash != null, "%s has Flash CPUParticles3D" % m_name)
			inst.queue_free()

	# -------------------------------------------------------------------------
	# 5. Test Other Special Weapons Equipping & Death Reset
	# -------------------------------------------------------------------------
	print("\n[Test 5] Testing Sniper, Double Pistols, Rocket Launcher & Death Reset...")
	combat.equip_weapon(combat.WeaponType.SNIPER)
	check(combat.current_weapon == combat.WeaponType.SNIPER, "Equipped Sniper Rifle")
	check(combat.current_ammo == 8, "Sniper has 8 rounds")
	combat._cooldown_left = 0.0
	combat._fire(true)
	check(combat.current_ammo == 7, "Sniper fired, 7 rounds remaining")

	combat.current_ammo = 0
	combat.current_weapon = combat.WeaponType.BASIC
	combat.equip_weapon(combat.WeaponType.DOUBLE_PISTOLS)
	check(combat.current_weapon == combat.WeaponType.DOUBLE_PISTOLS, "Equipped Double Pistols")
	check(combat.current_ammo == 30, "Double Pistols has 30 rounds")
	combat._cooldown_left = 0.0
	combat._fire(true)
	check(combat.current_ammo == 29, "Double Pistols fired, 29 rounds remaining")

	combat.current_ammo = 0
	combat.current_weapon = combat.WeaponType.BASIC
	combat.equip_weapon(combat.WeaponType.ROCKET_LAUNCHER)
	check(combat.current_weapon == combat.WeaponType.ROCKET_LAUNCHER, "Equipped Rocket Launcher")
	check(combat.current_ammo == 5, "Rocket Launcher has 5 rockets")

	# Death resets special weapon
	combat._on_player_died()
	check(combat.active_slot == combat.SLOT_BASIC, "On death, active slot is SLOT_BASIC (1)")
	check(combat.current_weapon == combat.WeaponType.BASIC, "On death, current weapon is BASIC pistol")
	check(combat.has_special_weapon() == false, "On death, special weapon is lost")

	# Cleanup
	player_node.queue_free()
	box.queue_free()
	await process_frame

	print("\n=======================================================")
	print("WEAPONS & ALT-FIRE VERIFICATION RESULTS: %d Passed, %d Failed" % [passes, failures])
	print("=======================================================")
	if failures > 0:
		quit(1)
	else:
		quit(0)
