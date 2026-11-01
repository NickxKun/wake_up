class_name WeaponIcon
extends Control

## Crisp procedural vector icon renderer for sci-fi weapons.
## Mathematically locks aspect ratio to 2:1 and centers within bounding box
## so icons NEVER stretch or squish, regardless of container size or layout.

var weapon_type : int = 0
var accent_color : Color = Color(0.45, 0.88, 1.0)

const CANVAS_W : float = 56.0
const CANVAS_H : float = 28.0

func set_weapon(type: int, color: Color) -> void:
	weapon_type = type
	accent_color = color
	queue_redraw()

func _draw() -> void:
	var s : float = minf(size.x / CANVAS_W, size.y / CANVAS_H)
	if s <= 0.001:
		return
	var ox : float = (size.x - CANVAS_W * s) * 0.5
	var oy : float = (size.y - CANVAS_H * s) * 0.5

	match weapon_type:
		1: # SHOTGUN
			_draw_shotgun(ox, oy, s)
		2: # SNIPER
			_draw_sniper(ox, oy, s)
		3: # DOUBLE PISTOLS
			_draw_double_pistols(ox, oy, s)
		4: # ROCKET LAUNCHER
			_draw_rocket_launcher(ox, oy, s)
		5: # TITANIUM HYDRO-WRENCH
			_draw_wrench(ox, oy, s)
		_: # BASIC PISTOL (0)
			_draw_pistol(ox, oy, s)

# Helper: Transform canvas coordinate (x, y) to viewport space
func _pt(ox: float, oy: float, s: float, x: float, y: float) -> Vector2:
	return Vector2(ox + x * s, oy + y * s)

# Helper: Transform canvas rectangle to viewport space
func _rc(ox: float, oy: float, s: float, x: float, y: float, w: float, h: float) -> Rect2:
	return Rect2(ox + x * s, oy + y * s, w * s, h * s)

## 0: Basic Pistol (Semi-automatic energy sidearm)
func _draw_pistol(ox: float, oy: float, s: float) -> void:
	# Slide / Upper Receiver
	draw_rect(_rc(ox, oy, s, 14.0, 8.0, 26.0, 6.5), accent_color, true)
	draw_line(_pt(ox, oy, s, 14.0, 8.0), _pt(ox, oy, s, 40.0, 8.0), Color.WHITE, 1.2 * s)
	
	# Ejection Port / Chamber Heat Sink
	draw_rect(_rc(ox, oy, s, 23.0, 9.5, 6.0, 3.0), accent_color.lerp(Color.BLACK, 0.45), true)
	
	# Extended Barrel Tip
	draw_rect(_rc(ox, oy, s, 40.0, 9.0, 3.5, 4.5), accent_color, true)
	draw_circle(_pt(ox, oy, s, 45.0, 11.25), 1.6 * s, Color.WHITE)

	# Lower Receiver & Frame
	draw_rect(_rc(ox, oy, s, 18.0, 14.5, 12.0, 2.5), accent_color.lerp(Color.BLACK, 0.25), true)

	# Trigger Guard & Trigger
	draw_line(_pt(ox, oy, s, 22.0, 17.0), _pt(ox, oy, s, 28.0, 17.0), accent_color, 1.2 * s)
	draw_line(_pt(ox, oy, s, 28.0, 17.0), _pt(ox, oy, s, 29.0, 14.5), accent_color, 1.2 * s)
	draw_line(_pt(ox, oy, s, 24.5, 14.5), _pt(ox, oy, s, 23.5, 16.5), Color.WHITE, 1.2 * s)

	# Ergonomic Pistol Grip
	var grip : PackedVector2Array = [
		_pt(ox, oy, s, 15.0, 14.5),
		_pt(ox, oy, s, 21.0, 14.5),
		_pt(ox, oy, s, 18.0, 24.5),
		_pt(ox, oy, s, 12.0, 24.5)
	]
	draw_colored_polygon(grip, accent_color.lerp(Color.BLACK, 0.35))
	# Magazine Baseplate
	draw_rect(_rc(ox, oy, s, 11.0, 24.5, 8.0, 1.8), Color.WHITE, true)

## 1: Shotgun (Tactical pump-action shotgun with spread pellets)
func _draw_shotgun(ox: float, oy: float, s: float) -> void:
	# Main Long Barrel
	draw_rect(_rc(ox, oy, s, 16.0, 9.0, 34.0, 4.0), accent_color, true)
	draw_line(_pt(ox, oy, s, 16.0, 9.0), _pt(ox, oy, s, 50.0, 9.0), Color.WHITE, 1.2 * s)

	# Under-Barrel Magazine Tube
	draw_rect(_rc(ox, oy, s, 18.0, 13.0, 28.0, 3.0), accent_color.lerp(Color.BLACK, 0.35), true)

	# Muzzle Choke Ring
	draw_rect(_rc(ox, oy, s, 48.0, 8.5, 2.5, 5.0), Color.WHITE, true)

	# Pump Slide Forend
	draw_rect(_rc(ox, oy, s, 28.0, 12.5, 10.0, 4.2), Color.WHITE, true)

	# Receiver
	draw_rect(_rc(ox, oy, s, 12.0, 9.0, 10.0, 7.5), accent_color.lerp(Color.BLACK, 0.2), true)

	# Tactical Shoulder Stock
	var stock : PackedVector2Array = [
		_pt(ox, oy, s, 12.0, 10.0),
		_pt(ox, oy, s, 2.5, 14.0),
		_pt(ox, oy, s, 2.5, 22.0),
		_pt(ox, oy, s, 9.5, 19.5),
		_pt(ox, oy, s, 12.0, 16.5)
	]
	draw_colored_polygon(stock, accent_color.lerp(Color.BLACK, 0.45))

	# 3 Buckshot Spread Pellets
	draw_circle(_pt(ox, oy, s, 53.0, 7.0), 1.5 * s, accent_color)
	draw_circle(_pt(ox, oy, s, 55.0, 11.0), 1.8 * s, Color.WHITE)
	draw_circle(_pt(ox, oy, s, 53.0, 15.0), 1.5 * s, accent_color)

## 2: Sniper Rifle (Anti-material precision rifle with scope & crosshair)
func _draw_sniper(ox: float, oy: float, s: float) -> void:
	# Long Precision Barrel
	draw_rect(_rc(ox, oy, s, 18.0, 13.0, 34.0, 2.8), accent_color, true)
	draw_line(_pt(ox, oy, s, 18.0, 13.0), _pt(ox, oy, s, 52.0, 13.0), Color.WHITE, 1.0 * s)

	# Heavy Muzzle Brake
	draw_rect(_rc(ox, oy, s, 52.0, 11.5, 3.5, 5.8), Color.WHITE, true)

	# Elevated Scope Mount Rail & Tube
	draw_line(_pt(ox, oy, s, 16.0, 13.0), _pt(ox, oy, s, 28.0, 13.0), Color.WHITE, 1.0 * s)
	draw_rect(_rc(ox, oy, s, 14.0, 7.5, 15.0, 3.2), accent_color, true)
	# Objective Bell (front) & Ocular Bell (rear)
	draw_rect(_rc(ox, oy, s, 27.5, 6.5, 3.0, 5.2), Color.WHITE, true)
	draw_rect(_rc(ox, oy, s, 12.5, 6.5, 2.5, 5.2), Color.WHITE, true)

	# Receiver & Mag Well
	draw_rect(_rc(ox, oy, s, 12.0, 12.0, 12.0, 5.5), accent_color.lerp(Color.BLACK, 0.25), true)
	draw_rect(_rc(ox, oy, s, 17.5, 17.5, 5.0, 4.5), accent_color.lerp(Color.BLACK, 0.4), true)

	# Skeletal Sniper Stock
	draw_line(_pt(ox, oy, s, 12.0, 13.0), _pt(ox, oy, s, 3.0, 15.0), accent_color, 2.2 * s)
	draw_line(_pt(ox, oy, s, 3.0, 15.0), _pt(ox, oy, s, 3.0, 23.0), Color.WHITE, 2.2 * s)
	draw_line(_pt(ox, oy, s, 3.0, 23.0), _pt(ox, oy, s, 9.0, 20.0), accent_color, 1.6 * s)
	draw_line(_pt(ox, oy, s, 9.0, 20.0), _pt(ox, oy, s, 13.0, 17.0), accent_color, 2.0 * s)

	# Crosshair Reticle Cue
	draw_arc(_pt(ox, oy, s, 42.0, 6.5), 3.8 * s, 0, TAU, 16, Color(1, 1, 1, 0.8), 1.0 * s)
	draw_circle(_pt(ox, oy, s, 42.0, 6.5), 1.0 * s, Color.WHITE)

## 3: Double Pistols (Akimbo energy sidearms)
func _draw_double_pistols(ox: float, oy: float, s: float) -> void:
	# Upper Pistol (slightly rearward and elevated)
	draw_rect(_rc(ox, oy, s, 16.0, 4.5, 25.0, 5.5), accent_color, true)
	draw_line(_pt(ox, oy, s, 16.0, 4.5), _pt(ox, oy, s, 41.0, 4.5), Color.WHITE, 1.0 * s)
	var grip_top : PackedVector2Array = [
		_pt(ox, oy, s, 18.0, 10.0),
		_pt(ox, oy, s, 23.5, 10.0),
		_pt(ox, oy, s, 21.0, 18.0),
		_pt(ox, oy, s, 15.5, 18.0)
	]
	draw_colored_polygon(grip_top, accent_color.lerp(Color.BLACK, 0.35))
	draw_circle(_pt(ox, oy, s, 43.5, 7.25), 1.5 * s, Color.WHITE)

	# Lower Pistol (slightly forward and stepped down)
	draw_rect(_rc(ox, oy, s, 23.0, 13.5, 25.0, 5.5), Color.WHITE, true)
	draw_line(_pt(ox, oy, s, 23.0, 13.5), _pt(ox, oy, s, 48.0, 13.5), accent_color, 1.0 * s)
	var grip_bot : PackedVector2Array = [
		_pt(ox, oy, s, 25.0, 19.0),
		_pt(ox, oy, s, 30.5, 19.0),
		_pt(ox, oy, s, 28.0, 26.5),
		_pt(ox, oy, s, 22.5, 26.5)
	]
	draw_colored_polygon(grip_bot, Color(0.2, 0.22, 0.26))
	draw_circle(_pt(ox, oy, s, 50.5, 16.25), 1.6 * s, accent_color)

## 4: Rocket Launcher (Heavy shoulder-fired ordnance tube)
func _draw_rocket_launcher(ox: float, oy: float, s: float) -> void:
	# Heavy Main Launch Tube
	draw_rect(_rc(ox, oy, s, 11.0, 9.0, 31.0, 8.0), accent_color, true)
	draw_line(_pt(ox, oy, s, 11.0, 9.0), _pt(ox, oy, s, 42.0, 9.0), Color.WHITE, 1.2 * s)

	# Rear Venturi Exhaust Bell
	var bell : PackedVector2Array = [
		_pt(ox, oy, s, 11.0, 9.0),
		_pt(ox, oy, s, 4.0, 6.5),
		_pt(ox, oy, s, 4.0, 19.5),
		_pt(ox, oy, s, 11.0, 17.0)
	]
	draw_colored_polygon(bell, accent_color.lerp(Color.BLACK, 0.3))

	# Muzzle Reinforcement Ring
	draw_rect(_rc(ox, oy, s, 39.0, 8.0, 3.0, 10.0), Color.WHITE, true)

	# High-Explosive Rocket Warhead Protruding From Muzzle
	var warhead : PackedVector2Array = [
		_pt(ox, oy, s, 42.0, 9.5),
		_pt(ox, oy, s, 51.0, 13.0),
		_pt(ox, oy, s, 42.0, 16.5)
	]
	draw_colored_polygon(warhead, Color.WHITE)
	draw_circle(_pt(ox, oy, s, 51.5, 13.0), 1.4 * s, accent_color)

	# Dual Under-Slung Grips
	draw_line(_pt(ox, oy, s, 18.0, 17.0), _pt(ox, oy, s, 16.0, 24.5), accent_color, 2.2 * s)
	draw_line(_pt(ox, oy, s, 30.0, 17.0), _pt(ox, oy, s, 30.0, 24.5), accent_color, 2.0 * s)

	# Top Optical Sighting Unit
	draw_rect(_rc(ox, oy, s, 23.0, 6.5, 8.0, 2.5), Color.WHITE, true)

## 5: Titanium Hydro-Wrench (Melee wrench with hydraulic jaws)
func _draw_wrench(ox: float, oy: float, s: float) -> void:
	# Heavy Angled Handle Shaft
	var shaft : PackedVector2Array = [
		_pt(ox, oy, s, 10.0, 21.0),
		_pt(ox, oy, s, 13.0, 24.0),
		_pt(ox, oy, s, 34.0, 11.0),
		_pt(ox, oy, s, 31.0, 8.0)
	]
	draw_colored_polygon(shaft, accent_color.lerp(Color.BLACK, 0.2))

	# Knurled Grip Base
	var grip : PackedVector2Array = [
		_pt(ox, oy, s, 8.0, 22.5),
		_pt(ox, oy, s, 11.0, 25.5),
		_pt(ox, oy, s, 19.0, 20.5),
		_pt(ox, oy, s, 16.0, 17.5)
	]
	draw_colored_polygon(grip, Color(0.12, 0.14, 0.18, 1.0))
	draw_line(_pt(ox, oy, s, 10.0, 21.0), _pt(ox, oy, s, 17.0, 16.5), Color.WHITE, 1.2 * s)

	# Glowing Hydraulic Conduit along shaft
	draw_line(_pt(ox, oy, s, 15.0, 20.5), _pt(ox, oy, s, 31.0, 10.5), accent_color, 1.5 * s)

	# Open-Jaw Head Housing
	var head_pts : PackedVector2Array = [
		_pt(ox, oy, s, 31.0, 8.0),
		_pt(ox, oy, s, 34.0, 11.0),
		_pt(ox, oy, s, 39.0, 8.0),
		_pt(ox, oy, s, 45.0, 12.0),
		_pt(ox, oy, s, 48.0, 9.0),
		_pt(ox, oy, s, 42.0, 3.0),
		_pt(ox, oy, s, 36.0, 5.0)
	]
	draw_colored_polygon(head_pts, accent_color)

	# Jaw Cutout (Hex Vice recess)
	var jaw_cutout : PackedVector2Array = [
		_pt(ox, oy, s, 39.0, 8.0),
		_pt(ox, oy, s, 44.0, 5.0),
		_pt(ox, oy, s, 48.0, 9.0),
		_pt(ox, oy, s, 43.0, 12.0)
	]
	draw_colored_polygon(jaw_cutout, Color(0.04, 0.05, 0.08, 1.0))

	# Metallic Edge Highlight
	draw_line(_pt(ox, oy, s, 36.0, 5.0), _pt(ox, oy, s, 42.0, 3.0), Color.WHITE, 1.2 * s)
	draw_line(_pt(ox, oy, s, 42.0, 3.0), _pt(ox, oy, s, 48.0, 9.0), Color.WHITE, 1.2 * s)
