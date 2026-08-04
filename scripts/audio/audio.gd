extends Node
## The game's sound, autoloaded as `Audio`.
##
## Holds the synthesised bank, a small pool of players to fire cues through,
## and the two switches the player gets: effects and music. Everything here is
## a no-op when there is no audio device — headless runs and the smoke test go
## through the same calls and simply hear nothing.
##
## The switches live in their own file rather than the career profile, so
## starting a new career does not turn the sound back on behind you.

const SETTINGS_PATH := "user://audio.json"

## How many cues can overlap. Handing a job over can land a chime, a level-up
## and a purchase within a second of each other, and a tap on top of that.
const VOICES := 6

## Cues fire slightly off-pitch each time so a run of taps does not sound like
## a machine. Roughly a semitone either way.
const WOBBLE := 0.06

## The music sits well under the effects — it is a bed, not a soundtrack.
const MUSIC_DB := -19.0
const SFX_DB := -7.0

var _sfx_on := true
var _music_on := true

var _bank: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _music_stream: AudioStreamWAV
var _wanted := false
var _silent := false

## Synthesis is not free — the whole bank is about a third of a second on a
## desktop and several times that on a phone, and the music is longer again.
## Both are built on a worker thread and picked up when they are ready; until
## then play() simply does nothing, which costs the first tap or two on the
## front page and nothing after that.
var _bank_task := -1
var _music_task := -1
var _built: Dictionary = {}
var _built_music: AudioStreamWAV


func _ready() -> void:
	_load_settings()
	# A headless run has no mixer, and building the bank would be time spent on
	# silence. The smoke test takes this path, so every call below still has to
	# be safe with nothing behind it.
	_silent = DisplayServer.get_name() == "headless"
	if _silent:
		set_process(false)
		return

	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.name = "Voice%d" % i
		player.volume_db = SFX_DB
		add_child(player)
		_voices.append(player)

	_music = AudioStreamPlayer.new()
	_music.name = "Music"
	_music.volume_db = MUSIC_DB
	add_child(_music)

	_bank_task = WorkerThreadPool.add_task(_synthesise_bank)


func _process(_delta: float) -> void:
	if _bank_task >= 0 and WorkerThreadPool.is_task_completed(_bank_task):
		WorkerThreadPool.wait_for_task_completion(_bank_task)
		_bank_task = -1
		_bank = _built
		_built = {}
		# The music is the expensive half, so it does not start until the cues
		# are in — a screen that wants both gets the responsive one first.
		if _wanted and _music_on:
			_music_task = WorkerThreadPool.add_task(_synthesise_music)

	if _music_task >= 0 and WorkerThreadPool.is_task_completed(_music_task):
		WorkerThreadPool.wait_for_task_completion(_music_task)
		_music_task = -1
		_music_stream = _built_music
		_built_music = null
		if _wanted and _music_on:
			_music.stream = _music_stream
			_music.play()

	if _bank_task < 0 and _music_task < 0:
		set_process(false)


## Quitting while a buffer is still being built would leave the pool holding a
## task nobody ever collects.
func _exit_tree() -> void:
	for task in [_bank_task, _music_task]:
		if task >= 0:
			WorkerThreadPool.wait_for_task_completion(task)
	_bank_task = -1
	_music_task = -1


func _synthesise_bank() -> void:
	_built = SoundBank.build_all()


func _synthesise_music() -> void:
	_built_music = SoundBank.build_music()


# --------------------------------------------------------------- the effects

## Plays a cue by name. Unknown names are ignored rather than raising, so a
## screen can ask for a sound the bank does not have yet without breaking.
func play(cue: String, volume_scale: float = 1.0) -> void:
	if _silent or not _sfx_on or not _bank.has(cue):
		return
	var player := _voices[_next]
	_next = (_next + 1) % _voices.size()
	player.stream = _bank[cue]
	player.pitch_scale = 1.0 + randf_range(-WOBBLE, WOBBLE)
	player.volume_db = SFX_DB + linear_to_db(clampf(volume_scale, 0.05, 1.0))
	player.play()


## The hand-over chime, matched to what the client thought of the room.
func stars(count: int) -> void:
	match clampi(count, 1, 3):
		1: play("star_one")
		2: play("star_two")
		_: play("star_three")


# ----------------------------------------------------------------- the music

## Asks for the bed. The music is a hundred times the work of a blip to build,
## so it is not made until the first screen that wants it — which puts the cost
## behind the loading screen on the way to the map.
func start_music() -> void:
	_wanted = true
	if _silent or not _music_on:
		return
	if _music_stream == null:
		# Still queued behind the cues, or not started yet. _process picks it
		# up and plays it as soon as it is there.
		if _music_task < 0 and _bank_task < 0:
			_music_task = WorkerThreadPool.add_task(_synthesise_music)
			set_process(true)
		return
	_music.stream = _music_stream
	if not _music.playing:
		_music.play()


## Quiets the bed without forgetting that a screen wanted it, so coming back
## from a room picks it up again.
func stop_music() -> void:
	_wanted = false
	if _music != null:
		_music.stop()


# --------------------------------------------------------------- the switches

func sfx_on() -> bool:
	return _sfx_on


func music_on() -> bool:
	return _music_on


func set_sfx_on(value: bool) -> void:
	_sfx_on = value
	_save_settings()
	if value:
		play("tap")


func set_music_on(value: bool) -> void:
	_music_on = value
	_save_settings()
	if _silent:
		return
	if value:
		start_music()
	elif _music != null:
		_music.stop()


## True when there is no audio device at all, so a settings panel can leave
## out switches that would do nothing.
func is_silent() -> bool:
	return _silent


func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	_sfx_on = bool(data.get("sfx", true))
	_music_on = bool(data.get("music", true))


func _save_settings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"sfx": _sfx_on, "music": _music_on}, "\t"))
	file.close()
