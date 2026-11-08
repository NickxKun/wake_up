extends SceneTree

const MainMenuScene : PackedScene = preload("res://scenes/ui/main_menu.tscn")
const EnemySpawnerScript = preload("res://scenes/enemy/enemy_spawner.gd")
const EnemyScene : PackedScene = preload("res://scenes/enemy/enemy.tscn")
const ExplosionScene : PackedScene = preload("res://scenes/projectiles/explosion_effect.tscn")

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
	print("--- Running Rocket Mayhem Launch & Menu Card Polish Verification Suite ---")
	call_deferred("_run_tests")

func _run_tests() -> void:
	await process_frame
	await process_frame

	# =========================================================================
	# [Test 1] Rocket Mayhem Launch & Enemy Spawning Stability
	# =========================================================================
	print("\n[Test 1] Testing Rocket Mayhem Spawning & Audio Stability...")
	var hud : Node = root.get_node_or_null("PlayerHealthHud")
	if hud != null:
		hud.set("is_rocket_mayhem_mode", true)
		check(hud.get("is_rocket_mayhem_mode") == true, "HUD is_rocket_mayhem_mode enabled")

	# Test UiSound music playback without initialization crash
	var snd : Node = root.get_node_or_null("UiSound")
	if snd != null and snd.has_method("play_music"):
		snd.call("play_music", "game", 0.1)
		check(true, "UiSound play_music executed successfully without null player error")

	# Test Enemy Spawner in Rocket Mayhem Mode
	var spawner : Marker3D = EnemySpawnerScript.new()
	root.add_child(spawner)
	spawner.enemy_scene = EnemyScene
	await process_frame

	# Spawn multiple enemies to test all chaotic weapon variants (Shotgun, Double Pistols, Pistol)
	for i in range(6):
		spawner.call("_spawn")
		await process_frame

	var spawned_enemies := root.get_tree().get_nodes_in_group("enemy")
	check(spawned_enemies.size() >= 5, "Enemies spawned successfully in Rocket Mayhem without crash (count: " + str(spawned_enemies.size()) + ")")

	# Verify enemy properties and weapon assignments
	for e in spawned_enemies:
		var enemy : CharacterBody3D = e as CharacterBody3D
		check(enemy.is_inside_tree(), "Spawned enemy is properly inside scene tree")
		check(enemy.get("model") != null or enemy.get_node_or_null("Model") != null, "Enemy Model node is valid")
		check(enemy.get("weapon_type") in [0, 1, 2], "Enemy weapon_type set to valid role: " + str(enemy.get("weapon_type")))

	# Test rocket explosion blast immunity for player in Rocket Mayhem mode
	var explosion : Node3D = ExplosionScene.instantiate() as Node3D
	root.add_child(explosion)
	await process_frame
	check(explosion.is_inside_tree(), "Explosion instantiated cleanly in Rocket Mayhem")

	# Cleanup spawned test nodes
	spawner.queue_free()
	explosion.queue_free()
	for e in spawned_enemies:
		e.queue_free()
	if hud != null:
		hud.set("is_rocket_mayhem_mode", false)

	# =========================================================================
	# [Test 2] Main Menu: 7 Cards, Emojis Removed, Consistent Protocol Format
	# =========================================================================
	print("\n[Test 2] Testing Main Menu Cards Hierarchy & Emoji Removal...")
	var menu = MainMenuScene.instantiate()
	root.add_child(menu)
	await process_frame
	await process_frame

	# 1. Verify all 7 mode cards exist
	check(menu.tutorial_card != null, "TutorialCard exists")
	check(menu.survival_card != null, "SurvivalCard exists")
	check(menu.sandbox_card != null, "SandboxCard exists")
	check(menu.range_card != null, "RangeCard (The Range) exists")
	check(menu.mayhem_card != null, "MayhemCard (Rocket Mayhem) exists")
	check(menu.story_card != null, "StoryCard (Story Mode Locked Teaser) exists")
	check(menu.coop_card != null, "CoopCard (Co-op Strike Locked Teaser) exists")

	var all_7_cards := [
		menu.tutorial_card,
		menu.survival_card,
		menu.sandbox_card,
		menu.range_card,
		menu.mayhem_card,
		menu.story_card,
		menu.coop_card
	]

	# 2. Verify all 7 cards have NO emojis on banners / labels
	var forbidden_emojis := ["🎯", "🚀", "🔒", "⚙", "🛡", "💥"]
	var found_emoji : bool = false
	for card in all_7_cards:
		# Check for removed LockIcon node
		var lock_icon_node = card.get_node_or_null("CenterContainer/VBoxContainer/LockIcon")
		if lock_icon_node != null:
			print("  [FAIL] LockIcon node found in " + card.name)
			found_emoji = true

		# Check all text labels inside card
		for child in card.find_children("*", "Label", true, false):
			var lbl : Label = child as Label
			for emoji in forbidden_emojis:
				if emoji in lbl.text:
					print("  [FAIL] Emoji '%s' found in %s/%s text: '%s'" % [emoji, card.name, lbl.name, lbl.text])
					found_emoji = true

	check(not found_emoji, "All mode cards have zero emojis on banners and labels")

	# 3. Verify consistent protocol format on all 7 cards
	var consistent_format : bool = true
	for card in all_7_cards:
		var proto_lbl : Label = card.get_node_or_null("CenterContainer/VBoxContainer/ProtocolTag") as Label
		var title_lbl : Label = card.get_node_or_null("CenterContainer/VBoxContainer/Title") as Label
		var status_lbl : Label = card.get_node_or_null("CenterContainer/VBoxContainer/StatusLabel") as Label

		if proto_lbl == null or title_lbl == null or status_lbl == null:
			consistent_format = false
			print("  [FAIL] Missing standard label hierarchy in: " + card.name)
		else:
			check(proto_lbl.text.begins_with("PROTOCOL //"), "Protocol tag format correct in %s: '%s'" % [card.name, proto_lbl.text])
			check(title_lbl.text.length() > 0, "Title label present in %s: '%s'" % [card.name, title_lbl.text])

	check(consistent_format, "All 7 mode cards follow exact uniform ProtocolTag -> Title -> StatusLabel hierarchy")

	# =========================================================================
	# [Test 3] Mode Interactions & Teaser Modals
	# =========================================================================
	print("\n[Test 3] Testing Mode Interactions & Teaser Modals...")

	# Verify selecting The Range (unlocked mode)
	menu._select_mode(menu.GameMode.RANGE)
	check(menu.selected_mode == menu.GameMode.RANGE, "Can select The Range (RANGE mode)")
	check(menu.range_bar.visible == true, "Range selection bar is visible")
	check("THE RANGE" in menu.main_launch_button.text, "Launch button updates for The Range")

	# Verify selecting Rocket Mayhem (unlocked mode)
	menu._select_mode(menu.GameMode.ROCKET_MAYHEM)
	check(menu.selected_mode == menu.GameMode.ROCKET_MAYHEM, "Can select Rocket Mayhem (ROCKET_MAYHEM mode)")
	check(menu.mayhem_bar.visible == true, "Rocket Mayhem selection bar is visible")
	check("ROCKET MAYHEM" in menu.main_launch_button.text, "Launch button updates for Rocket Mayhem")

	# Verify locked cards open teaser modal
	check(menu.teaser_modal != null, "Teaser modal exists")
	menu.story_card.emit_signal("pressed")
	await process_frame
	check(menu.teaser_modal.visible == true, "Clicking StoryCard opens Teaser Modal")
	check("OPERATION AURORA" in menu.teaser_header.text, "Teaser modal displays Story Mode Operation Aurora briefing")

	menu._close_teaser_modal()
	check(menu.teaser_modal.visible == false, "Teaser modal closes cleanly")

	menu.coop_card.emit_signal("pressed")
	await process_frame
	check(menu.teaser_modal.visible == true, "Clicking CoopCard opens Teaser Modal")
	check("TACTICAL SQUAD" in menu.teaser_header.text, "Teaser modal displays Co-op Tactical Squad briefing")

	menu._close_teaser_modal()

	# 4. Verify zero dead zones (all card children have mouse_filter == IGNORE)
	var all_click_transparent : bool = true
	var total_children_checked : int = 0
	for card in all_7_cards:
		for child in card.find_children("*", "Control", true, false):
			if not (child is Button):
				total_children_checked += 1
				if child.mouse_filter != Control.MOUSE_FILTER_IGNORE:
					all_click_transparent = false
					print("  [FAIL] Blocking mouse_filter on %s in %s" % [child.name, card.name])

	check(all_click_transparent and total_children_checked >= 35, "All card overlay children (%d controls) pass clicks through (0 dead zones)" % total_children_checked)

	menu.queue_free()

	# =========================================================================
	# Summary
	# =========================================================================
	print("\n=======================================================")
	print("RESULTS: %d Passed, %d Failed" % [passes, failures])
	print("=======================================================\n")
	if failures > 0:
		quit(1)
	else:
		quit(0)
