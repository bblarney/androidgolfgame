extends Control

# Basic loading screen: title + a status bar that fills as SceneManager.target_scene loads
# on a background thread. A small minimum on-screen time keeps the bar visible even when the
# target is already cached and "loads" instantly.

@onready var bar : ProgressBar = $Center/Bar

const MIN_TIME := 0.4

var _target  : String
var _elapsed : float = 0.0
var _done    : bool  = false

func _ready() -> void:
	_target = SceneManager.target_scene
	bar.value = 0.0
	ResourceLoader.load_threaded_request(_target)

func _process(delta: float) -> void:
	_elapsed += delta

	var progress : Array = []
	var status := ResourceLoader.load_threaded_get_status(_target, progress)
	var ratio  : float = progress[0] if progress.size() > 0 else 0.0

	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			bar.value = ratio * 100.0
		ResourceLoader.THREAD_LOAD_LOADED:
			bar.value = 100.0
			if not _done and _elapsed >= MIN_TIME:
				_done = true
				var packed := ResourceLoader.load_threaded_get(_target) as PackedScene
				get_tree().change_scene_to_packed(packed)
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("Loading screen failed to load: %s" % _target)
			set_process(false)
