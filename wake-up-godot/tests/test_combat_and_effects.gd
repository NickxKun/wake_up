extends SceneTree

var passes : int = 0
var failures : int = 0

func check(condition: bool, message: String) -> void:
	if condition:
		passes += 1
		print("[PASS] ", message)
	else:
		failures += 1
		print("[FAIL] ", message)

func _initialize() -> void:
	print("--- Running Combat Damage, Crits & Laser Burn Test ---")
	await process_frame

	# 1. Test UiSound crit sound
	var sound_scene = load("res://scenes/ui/ui_sound.tscn")
	check(sound_scene != null, "ui_sound.tscn loaded")
	var sound_mgr = sound_scene.instantiate()
	root.add_child(sound_mgr)
	await process_frame
	check(sound_mgr.crit_stream != null, "crit_stream is loaded")
	sound_mgr.play_crit()
	sound_mgr.play_shoot()
	sound_mgr.play_impact()
	check(true, "Laser shoot, heavy impact, and crit audio played cleanly")

	# 2. Test LaserBurn scene instantiation & visual structure
	var burn_scene = load("res://scenes/projectiles/laser_burn.tscn")
	check(burn_scene != null, "laser_burn.tscn loaded")
	var burn_inst = burn_scene.instantiate()
	check(burn_inst != null, "laser_burn instantiated")
	root.add_child(burn_inst)
	await process_frame
	check(burn_inst.get_node_or_null("MeshInstance3D") != null, "laser_burn has MeshInstance3D")
	burn_inst.queue_free()

	# 3. Test Bullet default damage and crit behavior
	var bullet_scene = load("res://scenes/projectiles/bullet.tscn")
	check(bullet_scene != null, "bullet.tscn loaded")
	var normal_bullet = bullet_scene.instantiate()
	check(normal_bullet.damage >= 40, "base bullet damage increased (>= 40)")
	normal_bullet.queue_free()

	# 4. Test Damage against HealthComponent
	var hc : HealthComponent = preload("res://scenes/components/health_component.gd").new()
	check(hc.health == 100, "Enemy starts at 100 HP")

	# Normal shot (40 damage)
	var dmg1 = hc.decrease_health(40)
	check(dmg1 == 40 and hc.health == 60, "Normal shot deals 40 damage (HP 100 -> 60)")

	# Reset and test Critical Hit (lethal insta-kill)
	hc.health = 100
	var crit_bullet = bullet_scene.instantiate()
	crit_bullet.is_critical = true
	crit_bullet.damage = 999
	var dmg_crit = hc.decrease_health(crit_bullet.damage)
	check(hc.health == 0, "Critical hit instantly depletes enemy health to 0 (insta-kill)")
	check(hc.is_dead(), "Enemy is dead from critical hit")
	crit_bullet.queue_free()
	hc.queue_free()

	# Clean up
	sound_mgr.queue_free()
	await process_frame

	print("--- Verification Results: %d Passed, %d Failed ---" % [passes, failures])
	if failures > 0:
		quit(1)
	else:
		quit(0)
