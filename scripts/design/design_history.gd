class_name DesignHistory
extends RefCounted
## Undo and redo for the room.
##
## Every change serialises the whole room, which is a few hundred bytes of
## JSON-ish dictionaries — cheap enough that snapshots beat trying to invert
## each individual edit, and impossible to get subtly wrong.

const LIMIT := 40

var _past: Array[Dictionary] = []
var _future: Array[Dictionary] = []
var _current: Dictionary = {}


## Starts a fresh history at the given state.
func reset(state: Dictionary) -> void:
	_past.clear()
	_future.clear()
	_current = state.duplicate(true)


## Files the state the room has just moved to. Does nothing when it matches
## what is already on top, so idle taps do not fill the history.
func record(state: Dictionary) -> void:
	if _current == state:
		return
	_past.append(_current)
	if _past.size() > LIMIT:
		_past.pop_front()
	_future.clear()
	_current = state.duplicate(true)


func can_undo() -> bool:
	return not _past.is_empty()


func can_redo() -> bool:
	return not _future.is_empty()


## Steps back and returns the state to restore, or an empty dictionary.
func undo() -> Dictionary:
	if _past.is_empty():
		return {}
	_future.append(_current)
	_current = _past.pop_back()
	return _current


func redo() -> Dictionary:
	if _future.is_empty():
		return {}
	_past.append(_current)
	_current = _future.pop_back()
	return _current
