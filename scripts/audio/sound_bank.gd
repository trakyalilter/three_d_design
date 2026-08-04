class_name SoundBank
extends RefCounted
## Every sound in the game, synthesised at runtime.
##
## The project has no binary assets — the furniture is welded from primitives
## and the thumbnails are rendered rather than loaded — and the audio follows
## the same rule. There are no samples to ship: each cue is a few hundred
## milliseconds of PCM built here from oscillators, noise and envelopes.
##
## Everything is mono at 22 kHz. That is plenty for blips and thuds, and it
## keeps both the memory and the arithmetic down: the whole bank is well under
## a megabyte and takes a few milliseconds a cue to build.
##
## Nothing here makes an AudioStreamWAV. The builders return raw PCM, because
## they run on a worker thread and a Resource is not a thing to hand between
## threads. Audio wraps them with stream() once they arrive on the main one.

const RATE := 22050
## Nothing is allowed to reach full scale. Cues stack — a purchase can land on
## top of a level-up — and headroom is what stops the sum clipping.
const CEILING := 0.72
## Cues are levelled by loudness rather than by peak. A square-wave buzz and a
## struck bell with the same peak are nothing like as loud as each other: the
## buzz spends all its time at full swing and the bell almost none. Matching
## the average instead is what stops "you cannot afford that" shouting.
const LOUDNESS := 0.15
## Silent frames written past the end of every buffer. The mixer interpolates
## between a sample and the one after it, so at the last frame — and at the far
## side of a loop point — it reads one frame beyond what was asked for. On a
## desktop that lands in slack memory and nobody notices. On Android it is an
## out-of-bounds read on the thread feeding AudioTrack, and the app goes down.
const GUARD := 16

## Equal temperament from A4, so the chimes below can be written as note names
## rather than frequencies.
const A4 := 440.0
const NOTES := {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}


## "A4", "C5", "F#3" -> Hz.
static func hz(note: String) -> float:
	var name := note.substr(0, 1)
	var sharp := note.contains("#")
	var octave := int(note.substr(note.length() - 1, 1))
	var semitone: int = int(NOTES[name]) + (1 if sharp else 0) + (octave - 4) * 12
	return A4 * pow(2.0, float(semitone) / 12.0)


# ------------------------------------------------------------------ the cues

## Every cue the game may ask for. Kept as a list of its own so the smoke test
## can check the names the game uses against the names the bank builds without
## having to synthesise anything.
const CUES: PackedStringArray = [
	"tap", "open", "close", "deny",
	"lift", "place", "drop", "rotate", "paint", "undo",
	"buy", "sell",
	"star_one", "star_two", "star_three", "levelup", "quarter",
]


## Everything the game can ask to hear, as raw PCM. Safe to call off the main
## thread; pass each buffer through stream() before playing it.
static func build_all() -> Dictionary:
	return {
		# Interface. Short, dry and quiet — these fire on every tap, so
		# anything with a tail would pile up.
		"tap": _blip(hz("A5"), 0.055, 0.16, 2.0),
		"open": _sweep_blip(hz("E5"), hz("B5"), 0.10, 0.14),
		"close": _sweep_blip(hz("B5"), hz("E5"), 0.10, 0.12),
		"deny": _buzz(hz("A3"), 0.16, 0.20),

		# The room. A piece meeting the floor is a thud with a little body to
		# it; picking one up is the same shape played backwards and thinner.
		"lift": _blip(hz("E5"), 0.06, 0.13, 3.0),
		"place": _thud(96.0, 0.20, 0.34),
		"drop": _thud(70.0, 0.26, 0.26),
		"rotate": _blip(hz("B4"), 0.045, 0.09, 4.0),
		"paint": _swish(0.34, 0.16),
		"undo": _sweep_blip(hz("D5"), hz("G4"), 0.13, 0.11),

		# Money.
		"buy": _chime([hz("D5"), hz("A5")], [0.0, 0.055], 0.40, 0.20),
		"sell": _chime([hz("A5"), hz("D5")], [0.0, 0.055], 0.36, 0.16),

		# The rewards, in the order the game hands them out.
		"star_one": _chime([hz("D5")], [0.0], 0.70, 0.24),
		"star_two": _chime([hz("D5"), hz("F#5")], [0.0, 0.13], 0.80, 0.24),
		"star_three": _chime([hz("D5"), hz("F#5"), hz("A5")], [0.0, 0.13, 0.26], 1.00, 0.26),
		"levelup": _chime(
			[hz("A4"), hz("D5"), hz("F#5"), hz("A5")],
			[0.0, 0.09, 0.18, 0.27], 1.10, 0.24),
		"quarter": _chime(
			[hz("D4"), hz("A4"), hz("D5"), hz("F#5"), hz("A5")],
			[0.0, 0.10, 0.20, 0.30, 0.42], 1.60, 0.26),
	}


## The bed that plays under the map and the front page: eight bars of slow
## chords, looped. Built on its own because it costs a hundred times what a
## blip does and is not wanted until something is on screen to play it under.
static func build_music() -> PackedByteArray:
	return _pad()


## Wraps a buffer from one of the builders above in a stream that can be
## played. Main thread only — this is the one place a Resource is made.
static func stream(data: PackedByteArray, looping: bool = false) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	if looping:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		# Inclusive, and the guard frames sit beyond it, so the mixer always
		# has a real sample to interpolate towards at the loop point.
		wav.loop_end = maxi(data.size() / 2 - GUARD - 1, 1)
	return wav


# ------------------------------------------------------------- the generators

## A plain tone with a fast attack and an exponential tail. `curve` is how
## sharply it decays — higher is shorter and more percussive.
static func _blip(freq: float, seconds: float, gain: float, curve: float) -> PackedByteArray:
	var n := int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	var step := TAU * freq / RATE
	for i in n:
		var t := float(i) / n
		# A touch of second harmonic keeps a sine from sounding like a test
		# tone without making it buzz.
		var s := sin(step * i) + 0.22 * sin(step * i * 2.0)
		out[i] = s * gain * _attack(t, 0.06) * exp(-curve * t * 3.2)
	return _wav(out)


## A blip that slides from one pitch to another. Rising reads as opening,
## falling as closing or undoing.
static func _sweep_blip(from_hz: float, to_hz: float, seconds: float, gain: float) -> PackedByteArray:
	var n := int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		phase += TAU * lerpf(from_hz, to_hz, t * t) / RATE
		out[i] = (sin(phase) + 0.18 * sin(phase * 2.0)) \
			* gain * _attack(t, 0.10) * exp(-3.0 * t)
	return _wav(out)


## Something solid meeting the floor: a low tone dropping about a fifth as it
## lands, with a short burst of soft noise on the front for the contact.
static func _thud(freq: float, seconds: float, gain: float) -> PackedByteArray:
	var n := int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	var noise := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = int(freq * 1000.0)
	for i in n:
		var t := float(i) / n
		phase += TAU * (freq * (1.0 - 0.34 * t)) / RATE
		# One-pole lowpass on white noise, so the contact is a knock rather
		# than a hiss.
		noise = lerpf(noise, rng.randf_range(-1.0, 1.0), 0.22)
		var body := sin(phase) * exp(-4.2 * t)
		var knock := noise * exp(-38.0 * t) * 0.7
		out[i] = (body + knock) * gain * _attack(t, 0.02)
	return _wav(out)


## A brush across a wall: noise under a filter that opens and closes again.
static func _swish(seconds: float, gain: float) -> PackedByteArray:
	var n := int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	var low := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7717
	for i in n:
		var t := float(i) / n
		low = lerpf(low, rng.randf_range(-1.0, 1.0), lerpf(0.04, 0.30, sin(t * PI)))
		out[i] = low * gain * sin(t * PI) * 1.4
	return _wav(out)


## Two short square pulses, low and slightly detuned. Reads as "no".
static func _buzz(freq: float, seconds: float, gain: float) -> PackedByteArray:
	var n := int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	var step := TAU * freq / RATE
	for i in n:
		var t := float(i) / n
		# Two pulses with a gap between them.
		var pulse := 1.0 if t < 0.34 else (1.0 if t > 0.52 and t < 0.86 else 0.0)
		if pulse == 0.0:
			out[i] = 0.0
			continue
		var s: float = signf(sin(step * i)) * 0.5 + signf(sin(step * i * 1.007)) * 0.5
		out[i] = s * gain * 0.5 * _attack(fmod(t, 0.34) / 0.34, 0.12)
	return _wav(out)


## Struck bells, one after another. Each note is three partials with their own
## decay, which is what makes a bell sound like metal rather than a flute.
static func _chime(freqs: Array, offsets: Array, seconds: float, gain: float) -> PackedByteArray:
	var n := int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	# Ratios a little off the harmonic series, the way a struck bar rings.
	var partials := [1.0, 2.76, 5.40]
	var levels := [1.0, 0.34, 0.12]

	for note in freqs.size():
		var freq: float = freqs[note]
		var start := int(RATE * float(offsets[note]))
		var length := n - start
		if length <= 0:
			continue
		for p in partials.size():
			var step: float = TAU * freq * float(partials[p]) / RATE
			var level: float = float(levels[p]) * gain
			# Higher partials die away first.
			var decay := 3.4 + 2.6 * p
			for i in length:
				var t := float(i) / length
				out[start + i] += sin(step * i) * level \
					* _attack(t, 0.008) * exp(-decay * t)
	return _wav(out)


## Eight bars of slow chords to sit under the map. Four voices a chord, gently
## detuned against each other so the pad drifts instead of sitting still, and
## each chord fades in and out of the next.
static func _pad() -> PackedByteArray:
	# D major, B minor, G major, A major — the same four the chimes are drawn
	# from, so the cues land inside the music rather than against it.
	var chords := [
		[hz("D3"), hz("A3"), hz("D4"), hz("F#4")],
		[hz("B2"), hz("F#3"), hz("B3"), hz("D4")],
		[hz("G2"), hz("D3"), hz("G3"), hz("B3")],
		[hz("A2"), hz("E3"), hz("A3"), hz("C#4")],
	]
	var bar := 4.0
	var n := int(RATE * bar * chords.size())
	var out := PackedFloat32Array()
	out.resize(n)

	var per_bar := int(RATE * bar)
	for c in chords.size():
		var chord: Array = chords[c]
		var start := c * per_bar
		# Chords overlap by a quarter of a bar so one dissolves into the next.
		var length := per_bar + per_bar / 4
		for voice in chord.size():
			var freq: float = chord[voice]
			var detune := 1.0 + (voice - 1.5) * 0.0012
			var step := TAU * freq * detune / RATE
			var level := 0.13 / (1.0 + voice * 0.35)
			for i in length:
				var at := (start + i) % n
				var t := float(i) / length
				# Raised cosine in and out, so nothing clicks at a seam.
				var swell := 0.5 - 0.5 * cos(clampf(t * 4.0, 0.0, 1.0) * PI)
				var fall := 0.5 - 0.5 * cos(clampf((1.0 - t) * 5.0, 0.0, 1.0) * PI)
				out[at] += (sin(step * i) + 0.30 * sin(step * i * 2.0)
					+ 0.10 * sin(step * i * 3.0)) * level * swell * fall

	return _wav(out)


# ----------------------------------------------------------------- machinery

## A short raised-cosine fade in, so nothing starts with a click.
static func _attack(t: float, length: float) -> float:
	if t >= length:
		return 1.0
	return 0.5 - 0.5 * cos(t / length * PI)


## Floats to a 16-bit stream, levelled so a cue built from a dozen summed
## partials does not come out louder than one built from two. The target is an
## average, with the peak pulled back under the ceiling if that would clip.
static func _wav(frames: PackedFloat32Array) -> PackedByteArray:
	var peak := 0.0
	var sum := 0.0
	for value in frames:
		peak = maxf(peak, absf(value))
		sum += value * value
	if peak <= 0.0001:
		return _pack(frames, 0.0)
	var rms := sqrt(sum / float(frames.size()))
	var scale: float = LOUDNESS / maxf(rms, 0.0001)
	scale = minf(scale, CEILING / peak)

	return _pack(frames, scale)


static func _pack(frames: PackedFloat32Array, scale: float) -> PackedByteArray:
	var data := PackedByteArray()
	data.resize((frames.size() + GUARD) * 2)
	for i in frames.size():
		data.encode_s16(i * 2, int(clampf(frames[i] * scale, -1.0, 1.0) * 32767.0))
	return data
