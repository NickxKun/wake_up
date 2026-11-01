extends NavigationRegion3D

## Bakes the navigation mesh at runtime from the level CSG geometry.

## Frames to wait for the CSG meshes to be built before baking anyway.
const MAX_WAIT_FRAMES : int = 30

func _ready() -> void:
	var frames : int = 0
	while not _is_geometry_ready() and frames < MAX_WAIT_FRAMES:
		await get_tree().process_frame
		frames += 1
	# Allow static physics bodies to register in physics server
	await get_tree().process_frame
	await get_tree().process_frame
	bake_navigation_mesh(false)
	if navigation_mesh.get_polygon_count() == 0:
		push_warning("LevelNavigation: baked navigation mesh is empty, enemies will move directly.")

func _is_geometry_ready() -> bool:
	for node in get_tree().get_nodes_in_group(navigation_mesh.geometry_source_group_name):
		if node.has_method("is_geometry_ready"):
			if not node.is_geometry_ready():
				return false
		elif node is CSGShape3D:
			var shape : CSGShape3D = node as CSGShape3D
			if shape.is_root_shape() and shape.get_meshes().is_empty():
				return false
	return true
