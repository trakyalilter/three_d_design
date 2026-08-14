class_name LayoutStore
extends RefCounted
## Reads and writes room layouts as JSON under user://layouts/.

const DIR := "user://layouts"
const AUTOSAVE := "user://autosave.json"
## A room the player is part way through, one file per house. These used to be
## written into the profile, which meant putting one chair down re-serialised
## every other room in the game along with it — see Game.store_layout().
const ROOMS := "user://rooms"
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


# --------------------------------------------------------------- client rooms

static func _room_path(house_id: String) -> String:
	return "%s/%s.json" % [ROOMS, sanitize(house_id)]


static func save_room(house_id: String, data: Dictionary) -> bool:
	if not DirAccess.dir_exists_absolute(ROOMS):
		DirAccess.make_dir_recursive_absolute(ROOMS)
	return _write(_room_path(house_id), data)


static func load_room(house_id: String) -> Dictionary:
	return _read(_room_path(house_id))


static func delete_room(house_id: String) -> void:
	var path := _room_path(house_id)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## Every house with a room saved against it.
static func room_ids() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(ROOMS)
	if dir == null:
		return out
	for file in dir.get_files():
		if file.ends_with(".json"):
			out.append(file.get_basename())
	out.sort()
	return out


static func clear_rooms() -> void:
	for house_id in room_ids():
		delete_room(house_id)


## Writes one layout beside itself and then moves it into place.
##
## Opening the file itself empties it first, so an app killed part way through
## a write leaves half a layout — and half a layout is not JSON, so the room is
## gone. The autosave is written on every change to a free-build room, which
## makes that a matter of time rather than bad luck.
##
## The profile keeps a spare of the save it replaces; this does not. One move
## rather than two leaves no moment with no file at all, and a sandbox room is
## one room to build again rather than a career — worth not losing to a torn
## write, not worth keeping two of.
static func _write(path: String, data: Dictionary) -> bool:
	data["version"] = FORMAT_VERSION
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write %s (%d)" % [path, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	# A disk with no room left fails out here, beside the layout rather than
	# through it, so whatever was saved before is still whole.
	var wrote := file.get_error()
	file.close()
	if wrote != OK:
		push_warning("Could not write %s (%d); the last save is untouched" % [path, wrote])
		DirAccess.remove_absolute(temp)
		return false
	if DirAccess.rename_absolute(temp, path) != OK:
		push_warning("Could not move %s into place" % path)
		DirAccess.remove_absolute(temp)
		return false
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
