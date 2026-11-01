class_name ExplosionEffect
extends Node3D

## Concussive stylized low-poly mushroom cloud explosion.
## Features:
## - Faceted low-poly mushroom stalk column and billowing crown canopy
## - Upward-erupting stem and cap particle billows
## - Low-poly central fireball flash, shockwave ring, tumbling debris
## - Distance-falloff AoE damage affecting both player and enemies
## - Screen shake trauma on impact

@onready var smoke_cloud : CPUParticles3D = $SmokeCloud
@onready var mushroom_stem : CPUParticles3D = get_node_or_null("MushroomStem") as CPUParticles3D
@onready var embers : CPUParticles3D = $Embers
@onready var fireball : MeshInstance3D = $Fireball
@onready var flash_light : OmniLight3D = $FlashLight
@onready var shockwave : MeshInstance3D = get_node_or_null("Shockwave") as MeshInstance3D

func _ready() -> void:
	# Heavy screen shake for large concussive explosion
	var ss : Node = get_node_or_null("/root/ScreenShake")
	if ss != null and ss.has_method("shake"):
		ss.shake(0.85)

	# Trigger low-poly particle emitters
	if smoke_cloud != null:
		smoke_cloud.emitting = true
	if mushroom_stem != null:
		mushroom_stem.emitting = true
	if embers != null:
		embers.emitting = true

	# Construct and animate the iconic low-poly mushroom cloud stalk and umbrella canopy
	_build_low_poly_mushroom_cloud()

	# Animate expanding low-poly fireball
	if fireball != null:
		fireball.scale = Vector3(0.2, 0.2, 0.2)
		var fb_mat : Material = fireball.get_active_material(0)
		if fb_mat is StandardMaterial3D:
			var mat : StandardMaterial3D = (fb_mat as StandardMaterial3D).duplicate() as StandardMaterial3D
			fireball.material_override = mat
			var tween := create_tween().set_parallel(true)
			tween.tween_property(fireball, "scale", Vector3(2.5, 2.5, 2.5), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(mat, "albedo_color:a", 0.0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween.chain().tween_callback(fireball.hide)

	# Animate low-poly shockwave ring
	if shockwave != null:
		shockwave.scale = Vector3(0.1, 0.1, 0.1)
		var sw_mat : Material = shockwave.get_active_material(0)
		if sw_mat is StandardMaterial3D:
			var mat : StandardMaterial3D = (sw_mat as StandardMaterial3D).duplicate() as StandardMaterial3D
			shockwave.material_override = mat
			var sw_tween := create_tween().set_parallel(true)
			sw_tween.tween_property(shockwave, "scale", Vector3(4.5, 0.1, 4.5), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			sw_tween.tween_property(mat, "albedo_color:a", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			sw_tween.chain().tween_callback(shockwave.hide)

	# Concussive light flash fade
	if flash_light != null:
		var light_tween := create_tween()
		light_tween.tween_property(flash_light, "light_energy", 0.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Free after the mushroom cloud concludes its full billow lifecycle
	var tree : SceneTree = get_tree()
	if tree != null:
		tree.create_timer(1.9).timeout.connect(queue_free)
	else:
		queue_free()

## Builds an iconic stylized low-poly mushroom cloud with a rising stalk and expanding domed canopy.
func _build_low_poly_mushroom_cloud() -> void:
	var mushroom_root := Node3D.new()
	mushroom_root.name = "LowPolyMushroomCloud"
	add_child(mushroom_root)

	# Base shared low-poly smoke material with flat shading
	var smoke_mat := StandardMaterial3D.new()
	smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	smoke_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	smoke_mat.roughness = 0.95
	smoke_mat.albedo_color = Color(0.24, 0.25, 0.28, 0.95)

	var cap_mat := StandardMaterial3D.new()
	cap_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cap_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	cap_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	cap_mat.roughness = 0.92
	cap_mat.albedo_color = Color(0.28, 0.27, 0.31, 0.92)

	# 1. Rising Central Stalk (3 stacked low-poly puffs)
	var stalk := Node3D.new()
	stalk.name = "Stalk"
	mushroom_root.add_child(stalk)

	var stalk_heights : Array[float] = [0.35, 0.85, 1.45]
	var stalk_radii : Array[float] = [0.28, 0.33, 0.38]
	for i in range(stalk_heights.size()):
		var puff := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = stalk_radii[i]
		mesh.height = stalk_radii[i] * 1.9
		mesh.radial_segments = 5
		mesh.rings = 3
		mesh.material = smoke_mat
		puff.mesh = mesh
		puff.position = Vector3(randf_range(-0.06, 0.06), stalk_heights[i], randf_range(-0.06, 0.06))
		stalk.add_child(puff)

	# 2. Expanding Mushroom Cap / Crown Canopy
	var cap := Node3D.new()
	cap.name = "Cap"
	cap.position = Vector3(0.0, 1.85, 0.0)
	mushroom_root.add_child(cap)

	# Central crown dome
	var dome := MeshInstance3D.new()
	var dome_mesh := SphereMesh.new()
	dome_mesh.radius = 0.65
	dome_mesh.height = 0.75
	dome_mesh.radial_segments = 6
	dome_mesh.rings = 4
	dome_mesh.material = cap_mat
	dome.mesh = dome_mesh
	dome.position = Vector3(0.0, 0.2, 0.0)
	cap.add_child(dome)

	# Radial ring of 6 faceted billow puffs forming the mushroom umbrella edge
	var puff_count : int = 6
	var ring_radius : float = 0.85
	for i in range(puff_count):
		var angle : float = float(i) * TAU / float(puff_count)
		var edge_puff := MeshInstance3D.new()
		var edge_mesh := SphereMesh.new()
		edge_mesh.radius = 0.42
		edge_mesh.height = 0.65
		edge_mesh.radial_segments = 5
		edge_mesh.rings = 3
		edge_mesh.material = cap_mat
		edge_puff.mesh = edge_mesh
		edge_puff.position = Vector3(cos(angle) * ring_radius, -0.08, sin(angle) * ring_radius)
		cap.add_child(edge_puff)

	# Animations:
	# Stalk shoots up from ground zero
	stalk.scale = Vector3(0.15, 0.05, 0.15)
	var stalk_tween := create_tween()
	stalk_tween.tween_property(stalk, "scale", Vector3(1.0, 1.0, 1.0), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Cap pops out and expands horizontally into the wide mushroom umbrella
	cap.scale = Vector3(0.08, 0.08, 0.08)
	var cap_tween := create_tween()
	cap_tween.tween_property(cap, "scale", Vector3(1.35, 0.95, 1.35), 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.06)

	# Entire mushroom cloud drifts upward over time
	var drift_tween := create_tween()
	drift_tween.tween_property(mushroom_root, "position:y", 0.75, 1.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Cloud fades and dissolves cleanly toward the end of its life
	var fade_tween := create_tween().set_parallel(true)
	fade_tween.tween_property(smoke_mat, "albedo_color:a", 0.0, 0.65).set_delay(1.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fade_tween.tween_property(cap_mat, "albedo_color:a", 0.0, 0.65).set_delay(1.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fade_tween.tween_property(mushroom_root, "scale", Vector3(0.3, 0.3, 0.3), 0.65).set_delay(1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

## Applies distance-falloff AoE damage and physics knockback to all entities within blast radius.
## Affects both enemies and player (with player taking reduced damage).
## Vehicle explosions also damage nearby enemies and players.
static func apply_explosion_damage(
	tree: SceneTree,
	epicenter: Vector3,
	radius: float,
	base_damage: int,
	knockback: float,
	source_shooter: Node3D = null,
	player_damage_mult: float = 0.38
) -> Array[Node3D]:
	if tree == null:
		return []

	var damaged_entities : Array[Node3D] = []

	# Collect all damageable target candidates across player, enemies, and vehicles
	var candidates : Array[Node3D] = []

	# 1. Player
	for p in tree.get_nodes_in_group("player"):
		if is_instance_valid(p) and (p is Node3D) and not candidates.has(p):
			candidates.append(p as Node3D)

	# 2. Enemies
	for e in tree.get_nodes_in_group("enemy"):
		if is_instance_valid(e) and (e is Node3D) and not candidates.has(e):
			candidates.append(e as Node3D)

	# 3. Drivable Vehicles
	for v in tree.get_nodes_in_group("vehicles"):
		if is_instance_valid(v) and (v is Node3D) and not candidates.has(v):
			candidates.append(v as Node3D)
	for v in tree.get_nodes_in_group("vehicle"):
		if is_instance_valid(v) and (v is Node3D) and not candidates.has(v):
			candidates.append(v as Node3D)

	for target in candidates:
		if not is_instance_valid(target) or target.is_queued_for_deletion():
			continue

		# Skip damaging the explosion source itself if it's already destroyed
		if target == source_shooter and (target.is_in_group("vehicles") or target.is_in_group("vehicle")):
			continue

		var dist : float = epicenter.distance_to(target.global_position)
		if dist > radius:
			continue

		# Strictly monotonic distance falloff:
		# 100% damage at epicenter (d = 0), down to 15% at outer blast perimeter (d = radius).
		# Farther away = always lesser damage.
		var norm_dist : float = clampf(dist / radius, 0.0, 1.0)
		var falloff : float = clampf(1.0 - norm_dist * 0.85, 0.15, 1.0)

		# The player takes lesser damage from explosions, but is affected nonetheless
		var is_player : bool = target.is_in_group("player") or target.name.to_lower().contains("proto_controller") or target.name.to_lower().contains("protocontroller")
		var target_mult : float = player_damage_mult if is_player else 1.0
		var calculated_damage : int = maxi(1, roundi(float(base_damage) * falloff * target_mult))

		var hc : HealthComponent = target.get_node_or_null("HealthComponent") as HealthComponent
		if hc == null and target.get_parent() != null:
			hc = target.get_parent().get_node_or_null("HealthComponent") as HealthComponent

		if hc != null:
			hc.decrease_health(calculated_damage)
			damaged_entities.append(target)

		# Blast impulse knockback away from explosion epicenter
		if target is CharacterBody3D:
			var cb := target as CharacterBody3D
			var blast_dir : Vector3 = (cb.global_position - epicenter).normalized()
			if blast_dir.is_zero_approx():
				blast_dir = Vector3.UP
			var impulse : float = knockback * (1.0 - norm_dist * 0.5)
			cb.velocity += blast_dir * impulse + Vector3.UP * 3.5

	return damaged_entities
