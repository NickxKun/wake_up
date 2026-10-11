extends NavigationRegion3D

## Bakes the navigation mesh at runtime from the level CSG geometry.

## Frames to wait for the CSG meshes to be built before baking anyway.
const MAX_WAIT_FRAMES : int = 30

func _ready() -> void:
	# CSG meshes are built deferred, so wait until every root CSG shape has a mesh.
	var frames : int = 0
	while not _is_geometry_ready() and frames < MAX_WAIT_FRAMES:
		await get_tree().process_frame
		frames += 1
	bake_navigation_mesh(false)
	if navigation_mesh.get_polygon_count() == 0:
		push_warning("LevelNavigation: baked navigation mesh is empty, enemies will move directly.")

func _is_geometry_ready() -> bool:
	for node in get_tree().get_nodes_in_group(navigation_mesh.geometry_source_group_name):
		var shape : CSGShape3D = node as CSGShape3D
		if shape != null and shape.is_root_shape() and shape.get_meshes().is_empty():
			return false
	return true
