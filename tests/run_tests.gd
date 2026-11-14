extends SceneTree
## Runner propio. Uso: godot --headless --path . -s res://tests/run_tests.gd [--filter=texto]
## Descubre tests/**/test_*.gd, crea una instancia por método `test_*` y sale con código != 0 si algo falla.


func _initialize() -> void:
	var filter: String = ""
	for arg: String in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if arg.begins_with("--filter="):
			filter = arg.substr(9)
	var files: Array[String] = []
	_collect("res://tests", files)
	files.sort()
	var passed: int = 0
	var failed: int = 0
	var report_lines: Array[String] = []
	for path: String in files:
		var script: GDScript = load(path) as GDScript
		if script == null:
			failed += 1
			report_lines.append("FALLO  %s: no se pudo cargar el script" % path)
			continue
		for method: Dictionary in script.get_script_method_list():
			var mname: String = method["name"]
			if not mname.begins_with("test_"):
				continue
			var label: String = "%s::%s" % [path.get_file().get_basename(), mname]
			if filter != "" and not label.contains(filter):
				continue
			var tc: TestCase = script.new() as TestCase
			if tc == null:
				failed += 1
				report_lines.append("FALLO  %s: la clase no extiende TestCase" % label)
				break
			tc.before_each()
			tc.call(mname)
			if tc.failures.is_empty():
				passed += 1
				print("ok     ", label)
			else:
				failed += 1
				print("FALLO  ", label)
				for f: String in tc.failures:
					print("         - ", f)
	for l: String in report_lines:
		print(l)
	print("")
	print("Resultado: %d ok, %d fallos" % [passed, failed])
	quit(1 if failed > 0 or passed == 0 else 0)


func _collect(dir_path: String, out: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_collect("%s/%s" % [dir_path, sub], out)
	for f: String in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd") and f != "test_case.gd":
			out.append("%s/%s" % [dir_path, f])
