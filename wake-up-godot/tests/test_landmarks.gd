extends SceneTree

func _init() -> void:
	print("--- Testing Landmark Instantiations ---")
	var arch_cls = load("res://scenes/level/landmarks/natural_arch.gd")
	var hoodoo_cls = load("res://scenes/level/landmarks/hoodoo_pillar.gd")
	var dish_cls = load("res://scenes/level/landmarks/satellite_dish.gd")
	var pipe_cls = load("res://scenes/level/landmarks/pipeline_system.gd")
	var crane_cls = load("res://scenes/level/landmarks/gantry_crane.gd")
	var fuel_cls = load("res://scenes/level/landmarks/fuel_depot.gd")

	assert(arch_cls != null, "NaturalArch script loaded")
	assert(hoodoo_cls != null, "HoodooPillar script loaded")
	assert(dish_cls != null, "SatelliteDish script loaded")
	assert(pipe_cls != null, "PipelineSystem script loaded")
	assert(crane_cls != null, "GantryCrane script loaded")
	assert(fuel_cls != null, "FuelDepot script loaded")

	var arch = arch_cls.new()
	root.add_child(arch)
	arch.call("_ready")

	var hoodoo = hoodoo_cls.new()
	root.add_child(hoodoo)
	hoodoo.call("_ready")

	var dish = dish_cls.new()
	root.add_child(dish)
	dish.call("_ready")

	var pipe = pipe_cls.new()
	root.add_child(pipe)
	pipe.call("_ready")

	var crane = crane_cls.new()
	root.add_child(crane)
	crane.call("_ready")

	var fuel = fuel_cls.new()
	root.add_child(fuel)
	fuel.call("_ready")

	print("[PASS] All 6 landmarks instantiated cleanly!")
	arch.queue_free()
	hoodoo.queue_free()
	dish.queue_free()
	pipe.queue_free()
	crane.queue_free()
	fuel.queue_free()
	quit(0)
