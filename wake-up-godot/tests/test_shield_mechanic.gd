extends SceneTree

var passes : int = 0
var failures : int = 0

var shield_changes : Array = []
var health_changes : Array = []
var shield_depleted_count : int = 0
var shield_broken_count : int = 0
var shield_full_count : int = 0
var shield_regen_start_count : int = 0

func check(condition : bool, label : String) -> void:
	if condition:
		passes += 1
		print("PASS: ", label)
	else:
		failures += 1
		print("FAIL: ", label)

func _on_shield_changed(new_s: float, old_s: float) -> void:
	shield_changes.append([new_s, old_s])

func _on_health_changed(new_h: int, old_h: int) -> void:
	health_changes.append([new_h, old_h])

func _on_shield_depleted() -> void:
	shield_depleted_count += 1

func _on_shield_broken() -> void:
	shield_broken_count += 1

func _on_shield_full() -> void:
	shield_full_count += 1

func _on_shield_regen_started() -> void:
	shield_regen_start_count += 1

func _clear_records() -> void:
	shield_changes.clear()
	health_changes.clear()
	shield_depleted_count = 0
	shield_broken_count = 0
	shield_full_count = 0
	shield_regen_start_count = 0

func _initialize() -> void:
	print("--- BEGIN SHIELD MECHANIC TEST SUITE ---")
	test_shield_absorption()
	test_shield_overflow()
	test_shield_zero_direct_health_damage()
	test_shield_regen_delay_and_rate()
	test_shield_damage_resets_timer_and_halts_regen()
	test_player_scene_integration()
	await test_health_bar_ui_binding()

	print("\n--- TEST COMPLETE ---")
	print("Passed: ", passes, " Failed: ", failures)
	quit(0 if failures == 0 else 1)

func test_shield_absorption() -> void:
	print("\n[Test 1] Shield absorbs damage first, preserving health")
	var hc : HealthComponent = HealthComponent.new()
	hc.has_shield = true
	hc.shield_changed.connect(_on_shield_changed)
	hc.health_changed.connect(_on_health_changed)
	hc.shield_depleted.connect(_on_shield_depleted)
	hc.shield_broken.connect(_on_shield_broken)

	check(hc.shield == 100.0, "Shield starts at 100.0")
	check(hc.health == 100, "Health starts at 100")
	check(hc.is_shield_full(), "is_shield_full() returns true initially")

	_clear_records()
	var dmg_taken : int = hc.decrease_health(30)
	check(dmg_taken == 30, "decrease_health(30) returns 30 applied damage")
	check(hc.shield == 70.0, "Shield reduced from 100.0 to 70.0")
	check(hc.health == 100, "Health remains untouched at 100")
	check(shield_changes.size() == 1 and shield_changes[0][0] == 70.0 and shield_changes[0][1] == 100.0, "shield_changed emitted with (70.0, 100.0)")
	check(health_changes.is_empty(), "health_changed was NOT emitted")
	check(shield_depleted_count == 0, "shield_depleted was NOT emitted")
	check(is_equal_approx(hc.shield_regen_timer, 5.0), "Taking damage sets shield_regen_timer to 5.0 seconds")

	hc.free()

func test_shield_overflow() -> void:
	print("\n[Test 2] Shield partial absorption and damage overflow to health")
	var hc : HealthComponent = HealthComponent.new()
	hc.has_shield = true
	hc.shield = 25.0
	hc.shield_changed.connect(_on_shield_changed)
	hc.health_changed.connect(_on_health_changed)
	hc.shield_depleted.connect(_on_shield_depleted)
	hc.shield_broken.connect(_on_shield_broken)

	_clear_records()
	# Incoming 60 damage: 25 absorbed by shield, 35 spills over to health
	var dmg_taken : int = hc.decrease_health(60)
	check(dmg_taken == 60, "decrease_health(60) returns 60 applied damage")
	check(hc.shield == 0.0, "Shield reduced to 0.0")
	check(hc.health == 65, "Health reduced from 100 to 65 (100 - 35)")
	check(hc.is_shield_broken(), "is_shield_broken() returns true when shield is 0")
	check(shield_depleted_count == 1, "shield_depleted signal emitted on depletion")
	check(shield_broken_count == 1, "shield_broken signal emitted on depletion")
	check(health_changes.size() == 1 and health_changes[0][0] == 65 and health_changes[0][1] == 100, "health_changed emitted for overflow damage")

	hc.free()

func test_shield_zero_direct_health_damage() -> void:
	print("\n[Test 3] When shield is 0, player takes direct damage to health")
	var hc : HealthComponent = HealthComponent.new()
	hc.has_shield = true
	hc.shield = 0.0
	hc.health = 65
	hc.health_changed.connect(_on_health_changed)
	hc.shield_changed.connect(_on_shield_changed)

	_clear_records()
	var dmg_taken : int = hc.decrease_health(20)
	check(dmg_taken == 20, "decrease_health(20) returns 20")
	check(hc.shield == 0.0, "Shield remains 0.0")
	check(hc.health == 45, "Health reduced directly from 65 to 45")
	check(shield_changes.is_empty(), "shield_changed not emitted when shield was already 0")
	check(health_changes.size() == 1 and health_changes[0][0] == 45, "health_changed emitted with 45")
	check(is_equal_approx(hc.shield_regen_timer, 5.0), "shield_regen_timer reset to 5.0s on health damage")

	hc.free()

func test_shield_regen_delay_and_rate() -> void:
	print("\n[Test 4] 5-second delay before regen and 0-100 in 5s (20 HP/s) recovery rate")
	var hc : HealthComponent = HealthComponent.new()
	hc.has_shield = true
	hc.shield = 0.0
	hc.shield_regen_timer = 5.0
	hc.shield_regen_started.connect(_on_shield_regen_started)
	hc.shield_full.connect(_on_shield_full)

	_clear_records()
	# Step 1: Simulate 2.5 seconds of delta
	hc._process(2.5)
	check(hc.shield == 0.0, "Shield remains 0.0 after 2.5s (within 5.0s delay window)")
	check(is_equal_approx(hc.shield_regen_timer, 2.5), "shield_regen_timer decreased to 2.5s")
	check(shield_regen_start_count == 0, "shield_regen_started not fired before 5s")

	# Step 2: Simulate 2.5 seconds more to reach 5.0 seconds
	hc._process(2.5)
	check(is_equal_approx(hc.shield_regen_timer, 0.0), "shield_regen_timer reached 0.0")
	check(shield_regen_start_count == 1, "shield_regen_started emitted exactly when 5.0s delay finishes")

	# Step 3: Now regen begins! Test rate of 20.0 HP/s
	# 1.0 second of process should restore 20.0 shield
	hc._process(1.0)
	check(is_equal_approx(hc.shield, 20.0), "After 1.0s of active regen, shield restored to 20.0 (20/s)")

	# 2.0 more seconds should restore 40.0 more (total 60.0)
	hc._process(2.0)
	check(is_equal_approx(hc.shield, 60.0), "After 3.0s of active regen, shield restored to 60.0")

	# 2.0 more seconds (total 5.0s active regen) should reach 100.0 (full recovery 0-100 in 5s)
	hc._process(2.0)
	check(is_equal_approx(hc.shield, 100.0), "After 5.0s of active regen, shield fully recovered to 100.0")
	check(shield_full_count == 1, "shield_full emitted when shield reaches 100.0")

	# Extra time should clamp at 100.0
	hc._process(1.0)
	check(hc.shield == 100.0, "Shield clamped at MAX_SHIELD (100.0)")

	hc.free()

func test_shield_damage_resets_timer_and_halts_regen() -> void:
	print("\n[Test 5] Taking damage resets 5s timer and immediately halts mid-regen")
	var hc : HealthComponent = HealthComponent.new()
	hc.has_shield = true
	hc.shield = 50.0
	hc.shield_regen_timer = 0.0 # actively regenerating
	hc.shield_regen_started.connect(_on_shield_regen_started)

	_clear_records()
	# Mid-regen check: 1s regen adds 20
	hc._process(1.0)
	check(is_equal_approx(hc.shield, 70.0), "Shield rose from 50 to 70 mid-regen")

	# Now player takes damage mid-regen:
	hc.decrease_health(15)
	check(is_equal_approx(hc.shield, 55.0), "Shield absorbed 15 damage, dropping from 70 to 55")
	check(is_equal_approx(hc.shield_regen_timer, 5.0), "Timer reset to 5.0s immediately upon damage")

	# During next 3 seconds, regen MUST NOT occur (it halted immediately)
	hc._process(3.0)
	check(is_equal_approx(hc.shield, 55.0), "Shield halted mid-regen and stayed at 55.0 during the 5s cooldown")
	check(is_equal_approx(hc.shield_regen_timer, 2.0), "Timer counted down from 5.0s to 2.0s")

	# Taking damage again at 2.0s left:
	hc.decrease_health(10)
	check(is_equal_approx(hc.shield, 45.0), "Shield absorbed 10 damage, dropping to 45.0")
	check(is_equal_approx(hc.shield_regen_timer, 5.0), "Timer reset back to 5.0s after subsequent damage")

	hc.free()

func test_player_scene_integration() -> void:
	print("\n[Test 6] Player scene ProtoController has has_shield = true configured")
	var player_scene : PackedScene = preload("res://addons/proto_controller/proto_controller.tscn")
	var player : CharacterBody3D = player_scene.instantiate() as CharacterBody3D
	check(player != null, "ProtoController instantiated successfully")

	var hc : HealthComponent = player.get_node_or_null("HealthComponent") as HealthComponent
	check(hc != null, "Player has HealthComponent child")
	check(hc.has_shield == true, "Player HealthComponent has has_shield = true")
	check(hc.shield == 100.0, "Player starts with 100.0 personal shield")
	check(hc.shield_regen_delay == 5.0, "Player shield_regen_delay is 5.0s")
	check(hc.shield_regen_rate == 20.0, "Player shield_regen_rate is 20.0/s")

	player.free()

func test_health_bar_ui_binding() -> void:
	print("\n[Test 7] HealthBar HUD integrates ShieldRow and reflects shield states")
	var bar_scene : PackedScene = preload("res://scenes/ui/health_bar.tscn")
	var hud_bar : CanvasLayer = bar_scene.instantiate() as CanvasLayer
	var hc : HealthComponent = HealthComponent.new()
	hc.has_shield = true
	hud_bar.health_component = hc

	# Add to tree root temporarily to execute ready
	root.add_child(hud_bar)
	await process_frame

	var shield_row : HBoxContainer = hud_bar.get_node_or_null("MarginContainer/VBoxContainer/ShieldRow") as HBoxContainer
	var shield_val : Label = hud_bar.get_node_or_null("MarginContainer/VBoxContainer/ShieldRow/ShieldValue") as Label
	var shield_bar : ProgressBar = hud_bar.get_node_or_null("MarginContainer/VBoxContainer/ShieldRow/BarContainer/ProgressBar") as ProgressBar
	var shield_status : Label = hud_bar.get_node_or_null("MarginContainer/VBoxContainer/ShieldRow/ShieldStatus") as Label

	check(shield_row != null, "ShieldRow exists in HealthBar scene")
	check(shield_row.visible == true, "ShieldRow is visible when has_shield is true")
	check(shield_val != null and shield_val.text == "100", "ShieldValue displays '100' initially")
	check(shield_bar != null and shield_bar.value == 100.0, "Shield ProgressBar is at 100.0 initially")
	check(shield_status != null, "ShieldStatus label exists")

	# Damage shield to 40
	hc.decrease_health(60)
	check(shield_val.text == "40", "ShieldValue label updated to '40' on damage")
	hud_bar._process(0.016)
	check(shield_status.text.begins_with("REGEN IN"), "ShieldStatus shows 'REGEN IN 5.0s' countdown")

	hud_bar.queue_free()
	hc.free()
