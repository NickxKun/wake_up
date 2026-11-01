class_name TacticalMap
extends CanvasLayer

## Fullscreen tactical schematic modal matching the Destiny / Valorant minimal aesthetic.
## Provides blueprint visualization of all sectors, safe zones, out-of-bounds hazard areas,
## physical containment barriers, and live hostiles.

signal opened
signal closed

@export var map_world_size : float = 80.0
@export var safe_zone_half_size : float = 15.5
@export var wall_half_size : float = 38.4

var _is_open : bool = false
var _player_ref : WeakRef = null
var _ping_phase : float = 0.0
var _was_paused_before_open : bool = false
var _previous_mouse_mode : Input.MouseMode = Input.MOUSE_MODE_VISIBLE

@onready var modal_backdrop : Control = $ModalBackdrop
@onready var map_canvas : Control = $ModalBackdrop/CenterLayout/MainVBox/HBox/MapPanel/VBox/MapCanvas
@onready var title_label : Label = $ModalBackdrop/CenterLayout/MainVBox/TopBar/TitleGroup/Title
@onready var subtitle_label : Label = $ModalBackdrop/CenterLayout/MainVBox/TopBar/TitleGroup/Subtitle
@onready var pos_label : Label = $ModalBackdrop/CenterLayout/MainVBox/HBox/Sidebar/VBox/Telemetry/PosValue
@onready var zone_label : Label = $ModalBackdrop/CenterLayout/MainVBox/HBox/Sidebar/VBox/Telemetry/ZoneValue
@onready var hostiles_label : Label = $ModalBackdrop/CenterLayout/MainVBox/HBox/Sidebar/VBox/Telemetry/HostilesValue
@onready var close_btn : Button = $ModalBackdrop/CenterLayout/MainVBox/HBox/Sidebar/VBox/CloseButton

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	modal_backdrop.modulate.a = 0.0
	modal_backdrop.scale = Vector2(0.98, 0.98)

	if map_canvas != null:
		map_canvas.draw.connect(_on_map_draw)
	if close_btn != null:
		close_btn.pressed.connect(close_map)

func bind_player(player: Node3D) -> void:
	_player_ref = weakref(player)

func is_map_open() -> bool:
	return _is_open

func toggle_map() -> void:
	if _is_open:
		close_map()
	else:
		open_map()

func open_map() -> void:
	if _is_open:
		return
	_is_open = true
	visible = true

	_update_header_for_theme()

	_was_paused_before_open = get_tree().paused
	get_tree().paused = true
	_previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_play_sound_map_open()

	var tween : Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(modal_backdrop, "modulate:a", 1.0, 0.16)
	tween.tween_property(modal_backdrop, "scale", Vector2.ONE, 0.16)

	opened.emit()

func _get_current_theme() -> int:
	var hud_node : Node = get_node_or_null("/root/PlayerHealthHud")
	if hud_node != null and "selected_map_theme" in hud_node:
		return int(hud_node.selected_map_theme)
	return 1

func _update_header_for_theme() -> void:
	var theme_id : int = _get_current_theme()
	if title_label != null:
		match theme_id:
			0:
				title_label.text = "TACTICAL SCHEMATIC // DESOLATE CANYON (SECTOR 01)"
				if subtitle_label != null:
					subtitle_label.text = "NATURAL TERRAIN & ARROYO  |  SURFACE RADAR: 80.0M x 80.0M"
			1:
				title_label.text = "TACTICAL SCHEMATIC // SPACE BASE COLONY (SECTOR 02)"
				if subtitle_label != null:
					subtitle_label.text = "RESEARCH OUTPOST & POWER GRID  |  SURFACE RADAR: 80.0M x 80.0M"
			2:
				title_label.text = "TACTICAL SCHEMATIC // TRANSPORT DOCK (SECTOR 03)"
				if subtitle_label != null:
					subtitle_label.text = "FREIGHT TERMINAL & EXTRACTION DRILL  |  SURFACE RADAR: 80.0M x 80.0M"

func close_map() -> void:
	if not _is_open:
		return
	_is_open = false

	_play_sound_map_close()

	var tween : Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(modal_backdrop, "modulate:a", 0.0, 0.12)
	tween.tween_property(modal_backdrop, "scale", Vector2(0.98, 0.98), 0.12)
	tween.chain().tween_callback(func() -> void:
		if not _is_open:
			visible = false
			get_tree().paused = _was_paused_before_open
			Input.mouse_mode = _previous_mouse_mode
	)

	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE or event.keycode == KEY_M or event.physical_keycode == KEY_M:
			close_map()
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not _is_open:
		return

	_ping_phase = wrapf(_ping_phase + delta * 1.5, 0.0, 1.0)
	_update_telemetry()

	if map_canvas != null:
		map_canvas.queue_redraw()

func _update_telemetry() -> void:
	if _player_ref == null:
		return
	var player : Node3D = _player_ref.get_ref() as Node3D
	if player == null or not is_instance_valid(player) or not player.is_inside_tree():
		return

	var p_pos : Vector3 = player.global_position
	if pos_label != null:
		pos_label.text = "X: %+05.1f  |  Y: %+04.1f  |  Z: %+05.1f" % [p_pos.x, p_pos.y, p_pos.z]

	var is_oob : bool = absf(p_pos.x) > safe_zone_half_size or absf(p_pos.z) > safe_zone_half_size
	if zone_label != null:
		if is_oob:
			zone_label.text = "RESTRICTED HAZARD SECTOR"
			zone_label.modulate = Color(0.96, 0.25, 0.32, 1.0)
		else:
			match _get_current_theme():
				0:
					zone_label.text = "CENTRAL ARROYO BASIN"
				1:
					zone_label.text = "RESEARCH OUTPOST PERIMETER"
				2:
					zone_label.text = "TRANSPORT DOCK PERIMETER"
			zone_label.modulate = Color(0.2, 0.88, 0.95, 1.0)

	if hostiles_label != null:
		var tree : SceneTree = get_tree()
		var count : int = 0
		if tree != null:
			var enemies : Array[Node] = tree.get_nodes_in_group("enemy")
			for e in enemies:
				if is_instance_valid(e):
					count += 1
		hostiles_label.text = "%d BIO-SIGNALS ACTIVE" % count

func _on_map_draw() -> void:
	if map_canvas == null:
		return

	var canvas_size : Vector2 = map_canvas.size
	var map_dim : float = minf(canvas_size.x, canvas_size.y) - 16.0
	if map_dim <= 50.0:
		return

	var center : Vector2 = canvas_size * 0.5
	var scale_px : float = map_dim / map_world_size # Pixels per meter

	# 1. Blueprint dark canvas background
	var canvas_rect := Rect2(center - Vector2(map_dim * 0.5, map_dim * 0.5), Vector2(map_dim, map_dim))
	map_canvas.draw_rect(canvas_rect, Color(0.03, 0.04, 0.06, 0.95), true)

	# 2. Subtle grid lines (every 10 meters)
	var grid_step : float = 10.0 * scale_px
	var start_coord : float = -map_world_size * 0.5 * scale_px
	var end_coord : float = map_world_size * 0.5 * scale_px

	var cur : float = start_coord
	while cur <= end_coord + 0.1:
		# Vertical grid line
		map_canvas.draw_line(Vector2(center.x + cur, canvas_rect.position.y), Vector2(center.x + cur, canvas_rect.end.y), Color(0.12, 0.18, 0.25, 0.25), 1.0)
		# Horizontal grid line
		map_canvas.draw_line(Vector2(canvas_rect.position.x, center.y + cur), Vector2(canvas_rect.end.x, center.y + cur), Color(0.12, 0.18, 0.25, 0.25), 1.0)
		cur += grid_step

	# 3. Out-of-Bounds Hazard Zone (everything outside the central safe perimeter)
	var safe_px_half : float = safe_zone_half_size * scale_px
	var safe_rect := Rect2(center - Vector2(safe_px_half, safe_px_half), Vector2(safe_px_half * 2.0, safe_px_half * 2.0))

	# Shaded hazard area
	map_canvas.draw_rect(canvas_rect, Color(0.85, 0.12, 0.18, 0.08), true)
	# Clear out central safe zone interior
	map_canvas.draw_rect(safe_rect, Color(0.04, 0.06, 0.09, 0.95), true)

	# 4. Physical Containment Barrier (outer true wall)
	var wall_px_half : float = wall_half_size * scale_px
	var wall_rect := Rect2(center - Vector2(wall_px_half, wall_px_half), Vector2(wall_px_half * 2.0, wall_px_half * 2.0))
	map_canvas.draw_rect(wall_rect, Color(0.45, 0.52, 0.62, 0.65), false, 1.5)

	# 5. Station Outpost Safe Perimeter (Demarcation Line: amber/gold glowing frame)
	map_canvas.draw_rect(safe_rect, Color(1.0, 0.62, 0.15, 0.9), false, 2.0)
	_draw_corner_brackets(map_canvas, safe_rect, 14.0, Color(1.0, 0.75, 0.25, 1.0), 2.5)

	# 6. Sector Blueprint Schematics & Outpost Modules
	_draw_station_modules(map_canvas, center, scale_px)

	# 7. Sector Text Labels
	var font : Font = ThemeDB.fallback_font
	if font != null:
		_draw_sector_labels(map_canvas, center, safe_px_half, font)

	# 8. Active Hostile Enemies
	var tree : SceneTree = get_tree()
	if tree != null:
		var enemies : Array[Node] = tree.get_nodes_in_group("enemy")
		for e in enemies:
			if is_instance_valid(e) and (e is Node3D) and (e as Node3D).is_inside_tree():
				var e_pos : Vector3 = (e as Node3D).global_position
				var e_screen : Vector2 = center + Vector2(e_pos.x, e_pos.z) * scale_px
				_draw_hostile_blip(map_canvas, e_screen)

	# 9. Live Player Beacon
	if _player_ref != null:
		var player : Node3D = _player_ref.get_ref() as Node3D
		if player != null and is_instance_valid(player) and player.is_inside_tree():
			var p_pos : Vector3 = player.global_position
			var p_screen : Vector2 = center + Vector2(p_pos.x, p_pos.z) * scale_px
			_draw_player_beacon(map_canvas, p_screen, player.rotation.y, scale_px)

func _draw_corner_brackets(canvas: Control, rect: Rect2, arm_len: float, col: Color, width: float) -> void:
	var tl : Vector2 = rect.position
	var tr : Vector2 = Vector2(rect.end.x, rect.position.y)
	var bl : Vector2 = Vector2(rect.position.x, rect.end.y)
	var br : Vector2 = rect.end

	# Top-Left
	canvas.draw_line(tl, tl + Vector2(arm_len, 0), col, width)
	canvas.draw_line(tl, tl + Vector2(0, arm_len), col, width)
	# Top-Right
	canvas.draw_line(tr, tr + Vector2(-arm_len, 0), col, width)
	canvas.draw_line(tr, tr + Vector2(0, arm_len), col, width)
	# Bottom-Left
	canvas.draw_line(bl, bl + Vector2(arm_len, 0), col, width)
	canvas.draw_line(bl, bl + Vector2(0, -arm_len), col, width)
	# Bottom-Right
	canvas.draw_line(br, br + Vector2(-arm_len, 0), col, width)
	canvas.draw_line(br, br + Vector2(0, -arm_len), col, width)

func _draw_station_modules(canvas: Control, center: Vector2, scale_px: float) -> void:
	var col_module : Color = Color(0.2, 0.45, 0.6, 0.45)
	var col_outline : Color = Color(0.3, 0.65, 0.85, 0.7)
	var col_rock : Color = Color(0.55, 0.28, 0.18, 0.5)
	var col_rock_outline : Color = Color(0.75, 0.38, 0.22, 0.7)
	var theme_id : int = _get_current_theme()

	# 1. Playable Zone Interior Features per Theme
	match theme_id:
		0:
			# Map 1: Desolate Canyon - Natural alien rock formations ONLY (No human equipment)
			var mesa_nw := Rect2(center + Vector2(-13.0, -12.0) * scale_px, Vector2(9.0, 7.0) * scale_px)
			canvas.draw_rect(mesa_nw, col_rock, true)
			canvas.draw_rect(mesa_nw, col_rock_outline, false, 1.2)

			var arch_ne := Rect2(center + Vector2(6.0, -11.0) * scale_px, Vector2(7.0, 6.0) * scale_px)
			canvas.draw_rect(arch_ne, col_rock, true)
			canvas.draw_rect(arch_ne, col_rock_outline, false, 1.2)

			var spires := [
				Vector2(7.0, 6.0),
				Vector2(11.0, 8.5),
				Vector2(-8.0, 7.0)
			]
			for sp in spires:
				var sp_center : Vector2 = center + sp * scale_px
				canvas.draw_circle(sp_center, 2.8 * scale_px, col_rock)
				canvas.draw_arc(sp_center, 2.8 * scale_px, 0.0, TAU, 16, col_rock_outline, 1.2, true)

			# Central dried washbed contour
			var wash_pts := PackedVector2Array([
				center + Vector2(-14.0, -2.0) * scale_px,
				center + Vector2(-5.0, 1.0) * scale_px,
				center + Vector2(4.0, -1.0) * scale_px,
				center + Vector2(14.0, 3.0) * scale_px
			])
			canvas.draw_polyline(wash_pts, Color(0.65, 0.4, 0.2, 0.4), 2.0)

		1:
			# Map 2: Space Base - Modular Cruciform Station, Power Substation & Geological Crater Dig Site
			# 1. Central Command Hub & Attached Cruciform Corridors (North-West)
			var hub_rect := Rect2(center + Vector2(-7.0, -7.0) * scale_px, Vector2(2.0, 2.0) * scale_px)
			canvas.draw_rect(hub_rect, col_module, true)
			canvas.draw_rect(hub_rect, col_outline, false, 1.2)

			# North Corridor & Science Lab
			var corr_n := Rect2(center + Vector2(-6.5, -9.0) * scale_px, Vector2(1.0, 2.0) * scale_px)
			var lab_n := Rect2(center + Vector2(-7.0, -11.0) * scale_px, Vector2(2.0, 2.0) * scale_px)
			canvas.draw_rect(corr_n, col_module, true)
			canvas.draw_rect(corr_n, col_outline, false, 1.0)
			canvas.draw_rect(lab_n, col_module, true)
			canvas.draw_rect(lab_n, col_outline, false, 1.2)

			# South Corridor & Crew Quarters
			var corr_s := Rect2(center + Vector2(-6.5, -5.0) * scale_px, Vector2(1.0, 2.0) * scale_px)
			var crew_s := Rect2(center + Vector2(-7.0, -3.0) * scale_px, Vector2(2.0, 2.0) * scale_px)
			canvas.draw_rect(corr_s, col_module, true)
			canvas.draw_rect(corr_s, col_outline, false, 1.0)
			canvas.draw_rect(crew_s, col_module, true)
			canvas.draw_rect(crew_s, col_outline, false, 1.2)

			# West Corridor & MedBay
			var corr_w := Rect2(center + Vector2(-9.0, -6.5) * scale_px, Vector2(2.0, 1.0) * scale_px)
			var med_w := Rect2(center + Vector2(-11.0, -7.0) * scale_px, Vector2(2.0, 2.0) * scale_px)
			canvas.draw_rect(corr_w, col_module, true)
			canvas.draw_rect(corr_w, col_outline, false, 1.0)
			canvas.draw_rect(med_w, col_module, true)
			canvas.draw_rect(med_w, col_outline, false, 1.2)

			# East Corridor & Airlock
			var corr_e := Rect2(center + Vector2(-5.0, -6.5) * scale_px, Vector2(2.0, 1.0) * scale_px)
			var air_e := Rect2(center + Vector2(-3.0, -7.0) * scale_px, Vector2(2.0, 2.0) * scale_px)
			canvas.draw_rect(corr_e, col_module, true)
			canvas.draw_rect(corr_e, col_outline, false, 1.0)
			canvas.draw_rect(air_e, col_module, true)
			canvas.draw_rect(air_e, col_outline, false, 1.2)

			# Comms Spire at (-10, -10)
			var spire_pos : Vector2 = center + Vector2(-10.0, -10.0) * scale_px
			canvas.draw_circle(spire_pos, 1.2 * scale_px, Color(0.2, 0.7, 0.9, 0.6))
			canvas.draw_arc(spire_pos, 1.2 * scale_px, 0.0, TAU, 16, col_outline, 1.2, true)

			# 2. Power Substation & Solar Field (North-East)
			var power_sub := Rect2(center + Vector2(4.0, -10.0) * scale_px, Vector2(6.5, 6.0) * scale_px)
			canvas.draw_rect(power_sub, col_module, true)
			canvas.draw_rect(power_sub, col_outline, false, 1.2)

			# 3. Geological Crater Excavation Dig Site (South-East at (10, 8))
			var pit_center : Vector2 = center + Vector2(10.0, 8.0) * scale_px
			canvas.draw_circle(pit_center, 2.2 * scale_px, Color(0.45, 0.22, 0.15, 0.5))
			canvas.draw_arc(pit_center, 2.2 * scale_px, 0.0, TAU, 24, Color(0.85, 0.45, 0.2, 0.8), 1.4, true)
			# Drill Rig on Crater Rim
			var drill_rect := Rect2(center + Vector2(6.5, 5.5) * scale_px, Vector2(2.0, 2.0) * scale_px)
			canvas.draw_rect(drill_rect, Color(0.25, 0.5, 0.7, 0.6), true)
			canvas.draw_rect(drill_rect, col_outline, false, 1.0)

			# 4. Southwest Auxiliary Staging Yard
			var yard_rect := Rect2(center + Vector2(-5.5, 3.5) * scale_px, Vector2(3.5, 3.0) * scale_px)
			canvas.draw_rect(yard_rect, Color(0.18, 0.35, 0.45, 0.35), true)
			canvas.draw_rect(yard_rect, col_outline, false, 1.0)

		2:
			# Map 3: Transport Dock - Logistics Depot, Heavy Drill Rig & Pads
			# Cargo Depot & Warehouses (North-East)
			var cargo_depot := Rect2(center + Vector2(4.0, -12.0) * scale_px, Vector2(8.0, 6.0) * scale_px)
			canvas.draw_rect(cargo_depot, col_module, true)
			canvas.draw_rect(cargo_depot, col_outline, false, 1.2)

			# Heavy Extraction Drill Rig (South-East)
			var drill_pad := Rect2(center + Vector2(5.0, 4.0) * scale_px, Vector2(6.5, 6.5) * scale_px)
			canvas.draw_rect(drill_pad, col_module, true)
			canvas.draw_rect(drill_pad, col_outline, false, 1.2)

			# Rover Service Bay (North-West)
			var rover_bay := Rect2(center + Vector2(-12.0, -11.0) * scale_px, Vector2(6.0, 5.5) * scale_px)
			canvas.draw_rect(rover_bay, col_module, true)
			canvas.draw_rect(rover_bay, col_outline, false, 1.2)

			# Primary Freight Landing Dock (South)
			var pad_center : Vector2 = center + Vector2(0.0, 9.5) * scale_px
			canvas.draw_circle(pad_center, 4.2 * scale_px, Color(0.18, 0.38, 0.52, 0.4))
			canvas.draw_arc(pad_center, 4.2 * scale_px, 0.0, TAU, 32, col_outline, 1.5, true)
			canvas.draw_line(pad_center - Vector2(3.0 * scale_px, 0), pad_center + Vector2(3.0 * scale_px, 0), col_outline, 1.0)
			canvas.draw_line(pad_center - Vector2(0, 3.0 * scale_px), pad_center + Vector2(0, 3.0 * scale_px), col_outline, 1.0)

	# ---------------------------------------------------------
	# Outer Desert Terrain & Rock Formations (Common to all maps)
	# ---------------------------------------------------------
	# North: Mesa Ridge & Sandstone Formations
	var mesa_north := Rect2(center + Vector2(-18.0, -32.0) * scale_px, Vector2(36.0, 6.0) * scale_px)
	canvas.draw_rect(mesa_north, col_rock, true)
	canvas.draw_rect(mesa_north, col_rock_outline, false, 1.2)

	# South: Canyon Wash & Monolith Formations
	var mesa_south := Rect2(center + Vector2(-16.0, 26.0) * scale_px, Vector2(32.0, 6.0) * scale_px)
	canvas.draw_rect(mesa_south, col_rock, true)
	canvas.draw_rect(mesa_south, col_rock_outline, false, 1.2)

	# East: Crater Ridge
	var ridge_east := Rect2(center + Vector2(26.0, -14.0) * scale_px, Vector2(6.0, 28.0) * scale_px)
	canvas.draw_rect(ridge_east, col_rock, true)
	canvas.draw_rect(ridge_east, col_rock_outline, false, 1.2)

	# West: Sandstone Plateau
	var ridge_west := Rect2(center + Vector2(-32.0, -14.0) * scale_px, Vector2(6.0, 28.0) * scale_px)
	canvas.draw_rect(ridge_west, col_rock, true)
	canvas.draw_rect(ridge_west, col_rock_outline, false, 1.2)

	# Natural Corner Pinnacles
	var rock_corners := [
		Vector2(-34.0, -34.0),
		Vector2(34.0, -34.0),
		Vector2(-34.0, 34.0),
		Vector2(34.0, 34.0)
	]
	for c_pos in rock_corners:
		var r_center : Vector2 = center + c_pos * scale_px
		canvas.draw_circle(r_center, 2.5 * scale_px, col_rock)
		canvas.draw_arc(r_center, 2.5 * scale_px, 0.0, TAU, 16, col_rock_outline, 1.2, true)

func _draw_sector_labels(canvas: Control, center: Vector2, half_safe: float, font: Font) -> void:
	var label_col : Color = Color(0.65, 0.8, 0.9, 0.65)
	var desert_col : Color = Color(0.85, 0.52, 0.35, 0.7)
	var theme_id : int = _get_current_theme()

	# 1. Central Playable Zone Labels
	match theme_id:
		0:
			canvas.draw_string(font, center + Vector2(-half_safe + 12.0, -half_safe + 22.0), "SEC 01 // NORTH MESA BLUFF", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, label_col)
			canvas.draw_string(font, center + Vector2(half_safe - 140.0, -half_safe + 22.0), "SEC 02 // EAST STONE ARCH", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, label_col)
			canvas.draw_string(font, center + Vector2(-half_safe + 12.0, half_safe - 14.0), "SEC 03 // DRY CANYON GORGE", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, label_col)
			canvas.draw_string(font, center + Vector2(half_safe - 140.0, half_safe - 14.0), "SEC 04 // TWIN SPIRES", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, label_col)
			canvas.draw_string(font, center + Vector2(-48.0, -4.0), "CENTRAL ARROYO BASIN", HORIZONTAL_ALIGNMENT_CENTER, -1, 9, Color(0.7, 0.55, 0.45, 0.6))
		1:
			canvas.draw_string(font, center + Vector2(-half_safe + 12.0, -half_safe + 22.0), "SEC 01 // HABITATION DOME", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, label_col)
			canvas.draw_string(font, center + Vector2(half_safe - 140.0, -half_safe + 22.0), "SEC 02 // SCIENCE LABS", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, label_col)
			canvas.draw_string(font, center + Vector2(-half_safe + 12.0, half_safe - 14.0), "SEC 03 // POWER SUBSTATION", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, label_col)
			canvas.draw_string(font, center + Vector2(half_safe - 140.0, half_safe - 14.0), "SEC 04 // DEFENSE RADAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, label_col)
			canvas.draw_string(font, center + Vector2(-48.0, -4.0), "CENTRAL OUTPOST PLAZA", HORIZONTAL_ALIGNMENT_CENTER, -1, 9, Color(0.4, 0.55, 0.65, 0.5))
		2:
			canvas.draw_string(font, center + Vector2(-half_safe + 12.0, -half_safe + 22.0), "SEC 01 // ROVER SERVICE BAY", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, label_col)
			canvas.draw_string(font, center + Vector2(half_safe - 140.0, -half_safe + 22.0), "SEC 02 // FREIGHT LOGISTICS", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, label_col)
			canvas.draw_string(font, center + Vector2(-half_safe + 12.0, half_safe - 14.0), "SEC 03 // CARGO DOCK WING", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, label_col)
			canvas.draw_string(font, center + Vector2(half_safe - 140.0, half_safe - 14.0), "SEC 04 // MINING DRILL RIG", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, label_col)
			canvas.draw_string(font, center + Vector2(-48.0, -4.0), "CENTRAL LOGISTICS TARMAC", HORIZONTAL_ALIGNMENT_CENTER, -1, 9, Color(0.4, 0.55, 0.65, 0.5))

	# 2. Outer Desert Sectors
	canvas.draw_string(font, center + Vector2(-75.0, -half_safe - 24.0), "[DESERT-N] RED MESA RIDGE & DUNES", HORIZONTAL_ALIGNMENT_CENTER, -1, 8, desert_col)
	canvas.draw_string(font, center + Vector2(-75.0, half_safe + 36.0), "[DESERT-S] CANYON WASHLAND & CRAGS", HORIZONTAL_ALIGNMENT_CENTER, -1, 8, desert_col)
	canvas.draw_string(font, center + Vector2(half_safe + 16.0, -4.0), "[DESERT-E] CRATER RIDGES", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, desert_col)
	canvas.draw_string(font, center + Vector2(-half_safe - 120.0, -4.0), "[DESERT-W] SANDSTONE RIM", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, desert_col)

	# Demarcation Boundary Warning Tag
	canvas.draw_string(font, center + Vector2(-60.0, -half_safe - 5.0), "-- DEMARCATION LINE // HAZARD SECTOR BEYOND --", HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color(1.0, 0.62, 0.15, 0.9))

func _draw_hostile_blip(canvas: Control, pos: Vector2) -> void:
	var sz : float = 4.5
	var diamond := PackedVector2Array([
		pos + Vector2(0, -sz),
		pos + Vector2(sz, 0),
		pos + Vector2(0, sz),
		pos + Vector2(-sz, 0),
	])
	canvas.draw_colored_polygon(diamond, Color(0.96, 0.22, 0.32, 0.95))
	canvas.draw_circle(pos, 1.5, Color(1.0, 0.9, 0.92, 1.0))

func _draw_player_beacon(canvas: Control, pos: Vector2, facing_angle: float, scale_px: float) -> void:
	# Sonar ping ripple
	var ping_radius : float = (6.0 + _ping_phase * 18.0) * (scale_px / 7.0)
	var ping_alpha : float = (1.0 - _ping_phase) * 0.8
	canvas.draw_arc(pos, ping_radius, 0.0, TAU, 32, Color(0.2, 0.9, 1.0, ping_alpha), 1.5, true)

	# Vision FOV wedge
	var angle_2d : float = facing_angle - PI * 0.5
	var fov_span : float = deg_to_rad(45.0)
	var fov_len : float = 24.0 * (scale_px / 7.0)

	var left_pt : Vector2 = pos + Vector2(cos(angle_2d - fov_span), sin(angle_2d - fov_span)) * fov_len
	var right_pt : Vector2 = pos + Vector2(cos(angle_2d + fov_span), sin(angle_2d + fov_span)) * fov_len
	var fov_poly := PackedVector2Array([pos, left_pt, right_pt])
	canvas.draw_colored_polygon(fov_poly, Color(0.2, 0.85, 1.0, 0.12))
	canvas.draw_line(pos, left_pt, Color(0.2, 0.85, 1.0, 0.4), 1.0)
	canvas.draw_line(pos, right_pt, Color(0.2, 0.85, 1.0, 0.4), 1.0)

	# Player chevron
	var forward := Vector2(cos(angle_2d), sin(angle_2d)).normalized()
	var right := Vector2(-forward.y, forward.x)

	var tip : Vector2 = pos + forward * 8.0
	var left_wing : Vector2 = pos - forward * 5.0 - right * 5.0
	var right_wing : Vector2 = pos - forward * 5.0 + right * 5.0
	var inner_notch : Vector2 = pos - forward * 2.0

	var chevron := PackedVector2Array([tip, right_wing, inner_notch, left_wing])
	canvas.draw_colored_polygon(chevron, Color(1.0, 1.0, 1.0, 1.0))
	canvas.draw_polyline(PackedVector2Array([tip, right_wing, inner_notch, left_wing, tip]), Color(0.2, 0.95, 1.0, 1.0), 1.5, true)

func _play_sound_map_open() -> void:
	var snd : Node = get_node_or_null("/root/UiSound")
	if snd != null and snd.has_method("play_map_open"):
		snd.call("play_map_open")

func _play_sound_map_close() -> void:
	var snd : Node = get_node_or_null("/root/UiSound")
	if snd != null and snd.has_method("play_map_close"):
		snd.call("play_map_close")
