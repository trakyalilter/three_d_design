class_name LayoutStore
extends RefCounted
## Reads and writes room layouts as JSON under user://layouts/.

const DIR := "user://layouts"
const AUTOSAVE := "user://autosave.json"
const FORMAT_VERSION := 1


static func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(DIR):
		DirAccess.make_dir_recursive_absolute(DIR)


static func _path_for(layout_name: String) -> String:
	return "%s/%s.json" % [DIR, sanitize(layout_name)]


## Strips anything that would be awkward in a file name.
static func sanitize(layout_name: String) -> String:
	const ALLOWED := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -_"
	var out := ""
	for c in layout_name.strip_edges():
		if ALLOWED.contains(c):
			out += c
	out = out.strip_edges()
	return out if out != "" else "layout"


static func list_layouts() -> Array[String]:
	_ensure_dir()
	var out: Array[String] = []
	var dir := DirAccess.open(DIR)
	if dir == null:
		return out
	for file in dir.get_files():
		if file.ends_with(".json"):
			out.append(file.get_basename())
	out.sort()
	return out


static func exists(layout_name: String) -> bool:
	return FileAccess.file_exists(_path_for(layout_name))


static func save_layout(layout_name: String, data: Dictionary) -> bool:
	_ensure_dir()
	return _write(_path_for(layout_name), data)


static func load_layout(layout_name: String) -> Dictionary:
	return _read(_path_for(layout_name))


static func delete_layout(layout_name: String) -> void:
	var path := _path_for(layout_name)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


static func save_autosave(data: Dictionary) -> bool:
	return _write(AUTOSAVE, data)


static func load_autosave() -> Dictionary:
	return _read(AUTOSAVE)


static func _write(path: String, data: Dictionary) -> bool:
	data["version"] = FORMAT_VERSION
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write %s (%d)" % [path, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true


static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Malformed layout file: %s" % path)
		return {}
	return parsed
