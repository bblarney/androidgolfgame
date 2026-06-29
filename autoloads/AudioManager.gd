extends Node
# Single audio hub for the whole game. Owns the bus layout (built in code -- there is no
# default_bus_layout.tres), the procedurally generated SFX/music streams (see audio_synth.gd), a
# small pool of players so overlapping sounds don't cut each other, and the menu<->course music
# crossfade. Gameplay code never touches AudioStreamPlayers directly -- it calls play_sfx() and
# play_music() on this autoload, which survives scene changes so music continues seamlessly across
# menu transitions.
#
# Loaded after SaveManager (see project.godot [autoload] order) because it reads persisted volumes
# on boot.

const Synth := preload("res://scripts/audio_synth.gd")

const SFX_VOICES := 6        # simultaneous one-shot SFX before the oldest is recycled
const FADE := 0.8            # music crossfade seconds

var _sfx_bus := 0
var _music_bus := 0

var _sfx : Dictionary = {}   # name -> AudioStreamWAV (generated eagerly at boot; all tiny)
var _sfx_pool : Array[AudioStreamPlayer] = []
var _sfx_next := 0

# Two music players we crossfade between; _music_other is whichever is currently silent.
var _music_a : AudioStreamPlayer
var _music_b : AudioStreamPlayer
var _music_active : AudioStreamPlayer
var _current_track := ""
var _music_cache : Dictionary = {}   # track -> AudioStreamWAV
var _music_thread : Thread
var _generating := ""                # track a worker thread is currently building (guards re-entry)

func _ready() -> void:
	_setup_buses()
	_build_sfx()
	_build_players()
	_apply_saved_volumes()

func _exit_tree() -> void:
	# Join any in-flight music-generation worker so the engine doesn't warn about a Thread being
	# destroyed before completion at quit.
	if _music_thread != null and _music_thread.is_started():
		_music_thread.wait_to_finish()

# Master already exists at index 0; add SFX and Music as children of it so the Master slider
# governs everything while Music/SFX sliders trim their own group.
func _setup_buses() -> void:
	_sfx_bus = AudioServer.bus_count
	AudioServer.add_bus(_sfx_bus)
	AudioServer.set_bus_name(_sfx_bus, "SFX")
	AudioServer.set_bus_send(_sfx_bus, "Master")
	_music_bus = AudioServer.bus_count
	AudioServer.add_bus(_music_bus)
	AudioServer.set_bus_name(_music_bus, "Music")
	AudioServer.set_bus_send(_music_bus, "Master")

func _build_sfx() -> void:
	# Tiny streams (~0.1-0.4 s) -- cheap to generate eagerly so the first shot/splash is instant.
	_sfx = {
		"club_hit": Synth.make_club_hit(),
		"bounce":   Synth.make_bounce(),
		"splash":   Synth.make_splash(),
		"cup_drop": Synth.make_cup_drop(),
	}

func _build_players() -> void:
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_pool.append(p)

	_music_a = _new_music_player()
	_music_b = _new_music_player()
	_music_active = _music_a

func _new_music_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Music"
	p.volume_db = -80.0
	add_child(p)
	return p

# --- SFX --------------------------------------------------------------------

# Play a one-shot. pitch>1 = brighter/higher; volume_db trims this hit relative to the SFX bus.
func play_sfx(sfx_name: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	var stream : AudioStream = _sfx.get(sfx_name)
	if stream == null:
		return
	var p := _sfx_pool[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_pool.size()
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()

# --- music ------------------------------------------------------------------

# Request an ambient track ("menu" or "golf"). No-op if it's already the active track, so moving
# between menu screens never restarts the music. The loop is generated on a worker thread the first
# time it's asked for (then cached), so boot and scene loads aren't blocked by synthesis.
func play_music(track: String) -> void:
	if track == _current_track:
		return
	_current_track = track
	if _music_cache.has(track):
		_crossfade_to(_music_cache[track])
	elif _generating != track:
		_generating = track
		if _music_thread != null and _music_thread.is_started():
			_music_thread.wait_to_finish()
		_music_thread = Thread.new()
		_music_thread.start(_generate_music.bind(track))

func _generate_music(track: String) -> void:
	var wav := Synth.make_music(track)
	# Hop back to the main thread to mutate node/cache state.
	call_deferred("_on_music_ready", track, wav)

func _on_music_ready(track: String, wav: AudioStreamWAV) -> void:
	_music_cache[track] = wav
	_generating = ""
	# Only start it if it's still the track we want (the player may have moved on while we built it).
	if track == _current_track:
		_crossfade_to(wav)

func _crossfade_to(stream: AudioStream) -> void:
	var incoming := _music_b if _music_active == _music_a else _music_a
	var outgoing := _music_active
	incoming.stream = stream
	incoming.volume_db = -80.0
	incoming.play()
	var tin := create_tween()
	tin.tween_property(incoming, "volume_db", 0.0, FADE)
	if outgoing.playing:
		var tout := create_tween()
		tout.tween_property(outgoing, "volume_db", -80.0, FADE)
		tout.tween_callback(outgoing.stop)
	_music_active = incoming

# --- volumes ----------------------------------------------------------------

func _apply_saved_volumes() -> void:
	_apply_bus("master_volume", AudioServer.get_bus_index("Master"))
	_apply_bus("music_volume", _music_bus)
	_apply_bus("sfx_volume", _sfx_bus)

func _apply_bus(key: String, bus: int) -> void:
	AudioServer.set_bus_volume_db(bus, _to_db(SaveManager.get_volume(key)))

func _to_db(linear: float) -> float:
	return -80.0 if linear <= 0.001 else linear_to_db(linear)

# Slider hooks: update the live bus and persist. linear is 0..1.
func set_master_volume(linear: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), _to_db(linear))
	SaveManager.set_volume("master_volume", linear)

func set_music_volume(linear: float) -> void:
	AudioServer.set_bus_volume_db(_music_bus, _to_db(linear))
	SaveManager.set_volume("music_volume", linear)

func set_sfx_volume(linear: float) -> void:
	AudioServer.set_bus_volume_db(_sfx_bus, _to_db(linear))
	SaveManager.set_volume("sfx_volume", linear)
