extends SceneTree

func _init() -> void:
	print("\n=== SCANNING ALL GDSCRIPT SCRIPTS FOR COMPILATION ISSUES ===")
	var files := []
	_scan_dir("res://", files)
	print("Found %d scripts to validate." % files.size())
	var err_count := 0
	for f in files:
		var scr : Script = load(f) as Script
		if scr == null:
			print("ERROR loading script: ", f)
			err_count += 1
		else:
			# Verify script can reload without errors
			var err = scr.reload()
			if err != OK:
				print("ERROR reloading script %s: %d" % [f, err])
				err_count += 1
	print("Scan complete. Errors found: ", err_count)
	quit(0 if err_count == 0 else 1)

func _scan_dir(dir_path: String, out_files: Array) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname == "." or fname == ".." or fname.begins_with("."):
			fname = dir.get_next()
			continue
		var full := dir_path.path_join(fname)
		if dir.current_is_dir():
			if fname != "tests":
				_scan_dir(full, out_files)
		elif fname.ends_with(".gd"):
			out_files.append(full)
		fname = dir.get_next()
	dir.list_dir_end()
