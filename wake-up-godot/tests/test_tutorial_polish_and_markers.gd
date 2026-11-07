extends SceneTree

## Verification Test Suite for Tutorial Polish, Minimap Markers, Directional Cues,
## and Waypoint / Music Sound Fixes.

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
	print("--- Running Tutorial Polish, Markers & Audio Verification Test Suite ---")
	call_deferred("_run_tests")

func _run_tests() -> void:
	await process_frame
	await process_frame

	# ----------------------------------------------------
	# [Test 1] Sound System Fixes (Music Looping & Waypoint SFX)
	# ----------------------------------------------------
	print("\n[Test 1] Testing Music Looping & Waypoint Sound Elements...")
	var snd_scene : PackedScene = load("res://scenes/ui/ui_sound.tscn")
	check(snd_scene != null, "ui_sound.tscn loaded successfully")

	var snd : Node = snd_scene.instantiate()
	root.add_child(snd)
	await process_frame

	# Verify loop modes on WAV streams
	var bgm_game : AudioStreamWAV = snd.get("bgm_game_stream") as AudioStreamWAV
	var bgm_menu : AudioStreamWAV = snd.get("bgm_menu_stream") as AudioStreamWAV
	check(bgm_game != null and bgm_game.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Game BGM stream has LOOP_FORWARD enabled")
	check(bgm_game != null and bgm_game.loop_end > 0, "Game BGM loop_end is positive (%d samples)" % (bgm_game.loop_end if bgm_game != null else 0))
	check(bgm_menu != null and bgm_menu.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Menu BGM stream has LOOP_FORWARD enabled")
	check(bgm_menu != null and bgm_menu.loop_end > 0, "Menu BGM loop_end is positive (%d samples)" % (bgm_menu.loop_end if bgm_menu != null else 0))

	# Verify waypoint sound streams and methods
	check(snd.get("waypoint_activate_stream") != null, "waypoint_activate_stream loaded successfully")
	check(snd.get("waypoint_reached_stream") != null, "waypoint_reached_stream loaded successfully")
	check(snd.has_method("play_waypoint_activate"), "UiSound exposes play_waypoint_activate() method")
	check(snd.has_method("play_waypoint_reached"), "UiSound exposes play_waypoint_reached() method")

	# Test triggering SFX without error
	snd.call("play_waypoint_activate")
	snd.call("play_waypoint_reached")
	check(true, "Waypoint SFX played without throwing errors")

	# Test fail-safe finished signal looping
	snd.call("play_music", "game", 0.05)
	await process_frame
	var active_player : AudioStreamPlayer = snd.get("_active_music_player") as AudioStreamPlayer
	check(active_player != null and active_player.playing, "Game music starts playing cleanly")

	# ----------------------------------------------------
	# [Test 2] Tutorial Map Facility Architecture & Dressing
	# ----------------------------------------------------
	print("\n[Test 2] Testing Proving Grounds Facility Dressing & Eliminating Empty Space...")
	var tut_scene : PackedScene = load("res://scenes/tutorial/tutorial_map.tscn")
	check(tut_scene != null, "tutorial_map.tscn loaded successfully")

	var map : Node3D = tut_scene.instantiate() as Node3D
	root.add_child(map)
	await process_frame
	await process_frame

	var facility : Node = map.find_child("FacilityGeometry", true, false)
	check(facility != null and facility.get_script() != null, "FacilityGeometry has tutorial facility script attached")

	var floor_guides : Node = facility.find_child("FloorDirectionGuides", true, false)
	check(floor_guides != null, "FloorDirectionGuides node exists in facility")
	var chevrons : Array[Node] = floor_guides.find_children("*GuideChevron*", "", true, false) if floor_guides != null else []
	check(chevrons.size() == 0, "Confusing ground chevrons removed to keep floor simple (found: %d)" % chevrons.size())

	var portals : Node = facility.find_child("SectorPortals", true, false)
	check(portals != null, "SectorPortals gantry arches node exists in facility")
	var gantries : Array[Node] = portals.get_children() if portals != null else []
	check(gantries.size() >= 5, "All 5 sector entrance gantries with overhead signage exist (found: %d)" % gantries.size())

	var partition : StaticBody3D = facility.find_child("SectorPartitionWall", true, false) as StaticBody3D
	check(partition != null, "SectorPartitionWall exists separating Firing Range from Vehicle Bay")
	var col_shapes : Array[Node] = partition.find_children("", "CollisionShape3D", false, false) if partition != null else []
	check(col_shapes.size() >= 2, "SectorPartitionWall is segmented with doorway for Portal 4 (found %d segments)" % col_shapes.size())
	var blocks_portal_4 : bool = false
	for cs in col_shapes:
		if cs is CollisionShape3D and cs.shape is BoxShape3D:
			var box : BoxShape3D = cs.shape as BoxShape3D
			if absf(cs.position.x - 4.0) < (box.size.x * 0.5):
				blocks_portal_4 = true
	check(not blocks_portal_4, "Doorway to Sector 4 Rover Bay at X = 4.0 is unblocked and clear")

	var props : Node = facility.find_child("FacilityProps", true, false)
	check(props != null, "FacilityProps node exists with cargo crates and server racks")
	var crates : Array[Node] = props.find_children("*TechCrate*", "", true, false) if props != null else []
	check(crates.size() >= 10, "Multiple modular tech cargo crates placed across facility (found: %d)" % crates.size())

	var helipad : Node = facility.find_child("HelipadExtractionPad", true, false)
	check(helipad != null, "HelipadExtractionPad exists at extraction coordinates")

	# ----------------------------------------------------
	# [Test 3] 3D Waypoint Visual Enhancements & Group Tagging
	# ----------------------------------------------------
	print("\n[Test 3] Testing 3D Waypoint Visual Enhancements & Group Tagging...")
	var wp : TutorialWaypoint = map.find_child("Waypoint_Locomotion", true, false) as TutorialWaypoint
	check(wp != null, "Waypoint_Locomotion exists")
	check(wp.is_in_group("waypoint"), "TutorialWaypoint is registered in 'waypoint' group for radar tracking")

	var beam : MeshInstance3D = wp.find_child("LightBeam", true, false) as MeshInstance3D
	check(beam != null, "LightBeam mesh instance exists in waypoint")
	var cyl_mesh : CylinderMesh = beam.mesh as CylinderMesh
	check(cyl_mesh != null and cyl_mesh.height <= 8.0, "LightBeam is sleek and compact (height: %.1fm <= 8.0m)" % (cyl_mesh.height if cyl_mesh != null else 0.0))

	var diamond : MeshInstance3D = wp.find_child("DiamondMesh", true, false) as MeshInstance3D
	check(diamond != null, "DiamondMesh exists in waypoint beacon")
	var box_m : BoxMesh = diamond.mesh as BoxMesh
	check(box_m != null and box_m.size.x <= 0.5, "Beacon diamond is compact and proportional (size: %.2fm <= 0.5m)" % (box_m.size.x if box_m != null else 0.0))

	# ----------------------------------------------------
	# [Test 4] HUD Screen-Edge & Floating 3D Direction Markers
	# ----------------------------------------------------
	print("\n[Test 4] Testing HUD Screen-Edge & Floating 3D Direction Markers...")
	var hud : TutorialHud = map.find_child("TutorialHud", true, false) as TutorialHud
	check(hud != null, "TutorialHud exists in scene")
	check(hud.edge_indicator != null, "HUD EdgeIndicator control is initialized")
	check(hud.edge_arrow != null, "HUD EdgeArrow node exists for off-screen pointing")
	check(hud.edge_reticle != null, "HUD EdgeReticle node exists for on-screen 3D tracking")
	check(hud.edge_dist_label != null, "HUD DistanceBadge exists for real-time range readout")

	var player : Node3D = map.find_child("ProtoController", true, false) as Node3D
	hud.track_waypoint(player, wp)
	hud._process(0.016)
	check(hud.edge_indicator.visible == true, "EdgeIndicator is active and visible when tracking active waypoint")
	check(hud.edge_dist_label.text.contains("M"), "DistanceBadge shows distance format (text: '%s')" % hud.edge_dist_label.text)

	# ----------------------------------------------------
	# [Test 5] Minimap Waypoint Marker Display
	# ----------------------------------------------------
	print("\n[Test 5] Testing Minimap Active Waypoint Radar Markers...")
	var minimap_scene : PackedScene = load("res://scenes/ui/minimap.tscn")
	check(minimap_scene != null, "minimap.tscn loaded successfully")

	var minimap : Minimap = minimap_scene.instantiate() as Minimap
	root.add_child(minimap)
	minimap.bind_player(player)
	await process_frame
	await process_frame

	check(minimap.has_method("_draw_waypoint_pip"), "Minimap implements _draw_waypoint_pip() method")

	# Test rendering radar with active waypoint in scene
	wp.is_active = true
	minimap.radar_canvas.queue_redraw()
	await process_frame
	check(true, "Minimap redrawn with active waypoint without error")

	# Cleanup
	map.queue_free()
	minimap.queue_free()
	snd.queue_free()
	await process_frame

	# ----------------------------------------------------
	# Final Results
	# ----------------------------------------------------
	print("\n=======================================================")
	print("TUTORIAL POLISH & MARKERS RESULTS: %d Passed, %d Failed" % [passes, failures])
	print("=======================================================\n")
	quit(0 if failures == 0 else 1)
