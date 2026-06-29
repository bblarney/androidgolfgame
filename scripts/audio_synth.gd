extends RefCounted
# Procedural audio synthesis. The game ships no audio asset files -- every sound (SFX and the two
# ambient music loops) is generated as an AudioStreamWAV here at runtime, matching the codebase's
# "generate it in code" approach (procedural holes, items, UI styling). AudioManager owns the
# generated streams; this file is pure, stateless factories in the ui_palette.gd idiom:
#   const Synth := preload("res://scripts/audio_synth.gd")  ->  Synth.make_club_hit()
#
# All output is mono 16-bit PCM. Mix rate is modest (mobile-friendly) and SFX are tiny; the music
# loops are a few seconds each (~1 MB) and are deliberately built to loop seamlessly (see _to_wav
# and make_music).

const SR := 22050   # mix rate for everything below

# --- low-level helpers ------------------------------------------------------

# Triangle wave from a running phase (cycles, not radians). Softer-edged than a saw, brighter than
# a sine -- used for the music pluck so it cuts through the pad without sounding harsh.
static func _tri(phase: float) -> float:
	var p := phase - floorf(phase)
	return 4.0 * absf(p - 0.5) - 1.0

# Snap a frequency so it completes a whole number of cycles across `total` seconds. A buffer whose
# every oscillator is periodic over its own length loops with zero seam -- this is how make_music
# avoids a click at the wrap point. The detune is sub-cent and inaudible.
static func _snap(freq: float, total: float) -> float:
	return maxf(1.0, roundf(freq * total)) / total

# Scale a buffer so its loudest sample hits `peak`, then pack to a (optionally looping) WAV. Peak
# is kept under 1.0 so the sum of voices never clips after the per-bus volume is applied.
static func _to_wav(samples: PackedFloat32Array, peak: float, loop: bool) -> AudioStreamWAV:
	var n := samples.size()
	var hi := 0.0
	for i in n:
		hi = maxf(hi, absf(samples[i]))
	var gain := (peak / hi) if hi > 0.0001 else 0.0
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		var s := clampf(samples[i] * gain, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(roundf(s * 32767.0)))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SR
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = n
	return wav

# --- SFX --------------------------------------------------------------------

# The clunk of clubface on ball: a tight low-passed noise tick for the contact, then a fat low
# "wooden" body that dominates -- lower and longer-decaying than a sharp crack so it reads as a
# solid clunk rather than a snap. ~150 ms. Loudness/pitch with shot power are applied at playback
# via pitch_scale, so one neutral stream serves every shot.
static func make_club_hit() -> AudioStreamWAV:
	var n := int(SR * 0.15)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / SR
		# Muffled contact tick: noise rolled off so it thuds instead of clicking.
		lp += clampf(TAU * 1600.0 / SR, 0.0, 1.0) * ((randf() * 2.0 - 1.0) - lp)
		var tick := lp * exp(-t / 0.012) * 0.5
		# Two low, close detuned sines = the woody body; the slightly slower decay is what makes
		# it land as a clunk.
		var body := (sin(TAU * 95.0 * t) + sin(TAU * 128.0 * t) * 0.7) * exp(-t / 0.07) * 0.7
		buf[i] = tick + body
	return _to_wav(buf, 0.9, false)

# A short soft thud for the ball landing/bouncing on turf. Low damped sine + a touch of noise;
# impact speed and surface drive pitch/volume at playback so this one click covers every bounce.
static func make_bounce() -> AudioStreamWAV:
	var n := int(SR * 0.09)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var t := float(i) / SR
		buf[i] = sin(TAU * 120.0 * t) * exp(-t / 0.025) * 0.7 \
			+ (randf() * 2.0 - 1.0) * exp(-t / 0.01) * 0.2
	return _to_wav(buf, 0.8, false)

# Water splash: a noise burst pushed through a low-pass whose cutoff sweeps downward (bright spray
# settling into a low gulp), with a couple of sine "bloops" for the plop. ~420 ms.
static func make_splash() -> AudioStreamWAV:
	var n := int(SR * 0.42)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / SR
		# Cutoff glides 3500 Hz -> 350 Hz; convert to a one-pole coefficient per sample.
		var fc := lerpf(3500.0, 350.0, clampf(t / 0.42, 0.0, 1.0))
		var alpha := clampf(TAU * fc / SR, 0.0, 1.0)
		lp += alpha * ((randf() * 2.0 - 1.0) - lp)
		var env := (t / 0.02) if t < 0.02 else exp(-(t - 0.02) / 0.16)
		var bloop := sin(TAU * 220.0 * t) * exp(-t / 0.08) * 0.25
		buf[i] = lp * env * 0.9 + bloop
	return _to_wav(buf, 0.85, false)

# Ball dropping into the cup: two bright descending "tinks" (rim) resolving into a low "plunk".
static func make_cup_drop() -> AudioStreamWAV:
	var n := int(SR * 0.30)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var t := float(i) / SR
		var s := 0.0
		s += _ping(t, 0.00, 1200.0, 0.012) * 0.5
		s += _ping(t, 0.055, 880.0, 0.014) * 0.45
		# the final settle into the bottom of the cup
		var t3 := t - 0.12
		if t3 >= 0.0:
			s += (sin(TAU * 175.0 * t3) * 0.8 + (randf() * 2.0 - 1.0) * 0.15) * exp(-t3 / 0.05) * 0.7
		buf[i] = s
	return _to_wav(buf, 0.85, false)

# A single decaying sine "ping" placed at time `at`; returns 0 before it starts.
static func _ping(t: float, at: float, freq: float, tau: float) -> float:
	var lt := t - at
	if lt < 0.0:
		return 0.0
	return sin(TAU * freq * lt) * exp(-lt / tau)

# --- music ------------------------------------------------------------------

# Generative ambient loop. "menu" is a calm pad-only swell; "golf" is the same harmony, a little
# faster, with a soft triangle pluck on top for gentle movement. Both run a I-V-vi-IV progression
# in C major and loop seamlessly because every oscillator is snapped to whole cycles over the loop
# (see _snap) and the chord crossfade / pluck envelopes tile the loop length exactly.
static func make_music(style: String) -> AudioStreamWAV:
	var chord_dur : float = 3.0 if style == "menu" else 2.2
	var total := chord_dur * 4.0
	var n := int(SR * total)

	# I-V-vi-IV triads (mixed octaves to keep the voicing in a warm mid range).
	var chords := [
		[130.81, 164.81, 196.00],   # C  (C3 E3 G3)
		[196.00, 246.94, 293.66],   # G  (G3 B3 D4)
		[220.00, 261.63, 329.63],   # Am (A3 C4 E4)
		[174.61, 220.00, 261.63],   # F  (F3 A3 C4)
	]
	# Pre-snap each chord's voices (root, a faintly detuned twin for chorus warmth, and a soft
	# octave) so the inner sample loop just sums sines.
	var voiced := []
	for chord in chords:
		var voices := []
		for f0 in chord:
			voices.append({"f": _snap(f0, total), "a": 1.0})
			voices.append({"f": _snap(f0 * 1.004, total), "a": 0.6})
			voices.append({"f": _snap(f0 * 2.0, total), "a": 0.3})
		voiced.append(voices)

	var is_golf := style == "golf"
	var beat := chord_dur / 2.0           # two plucks per chord
	var trem_f := _snap(0.18, total)      # slow breathing on the pad

	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var t := float(i) / SR
		var fseg := t / chord_dur
		var idx := int(fseg) % 4
		var local := fseg - floorf(fseg)   # 0..1 through the current chord
		# Crossfade into the next chord over the last third so changes glide (and the final chord
		# folds into the first, closing the loop).
		var blend := 0.0
		if local > 0.66:
			blend = (local - 0.66) / 0.34
		var pad := _voices_at(voiced[idx], t) * (1.0 - blend) \
			+ _voices_at(voiced[(idx + 1) % 4], t) * blend
		pad *= 1.0 + 0.08 * sin(TAU * trem_f * t)

		var s := pad * 0.5
		if is_golf:
			var bseg := t / beat
			var blocal := (bseg - floorf(bseg)) * beat   # seconds into this beat
			var note : float = float(chords[idx][int(bseg) % 3]) * 2.0
			var penv := minf(1.0, blocal / 0.008) * exp(-blocal / 0.18)
			s += _tri(_snap(note, total) * t) * penv * 0.32
		buf[i] = s
	return _to_wav(buf, 0.72, true)

static func _voices_at(voices: Array, t: float) -> float:
	var s := 0.0
	for v in voices:
		s += sin(TAU * float(v["f"]) * t) * float(v["a"])
	return s
