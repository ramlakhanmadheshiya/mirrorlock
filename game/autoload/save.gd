extends Node
## Persistent player data as one JSON document in user://.
## Writes go to a temp file first and the previous save is kept as a backup,
## so a crash mid-write or a corrupt file never loses progress.

signal saved

const VERSION: int = 1
const DEFAULT_PATH: String = "user://mirrorlock_save.json"

var path: String = DEFAULT_PATH
var data: Dictionary = {}
## Set when the save could not be read and a backup or fresh save was used.
var recovered_from: String = ""

var _dirty: bool = false


func _ready() -> void:
	load_data()


static func defaults() -> Dictionary:
	return {
		"version": VERSION,
		"coins": Economy.START_COINS,
		# level id -> {"stars": 1..3}
		"cleared": {},
		# level id -> PlayState.to_dict() for half-played levels
		"progress": {},
		# level ids opened early with a level key
		"unlocked": {},
		"keys": 0,
		# chapter keys open a whole locked chapter (from level 1)
		"chapter_keys": 0,
		# chapter ids opened early with a chapter key
		"chapters_opened": {},
		# coins bought with real money (kept on a progress reset)
		"coins_bought": 0,
		"owned": {},
		"trials": {},
		"tips": 0,
		"video": {"day": "", "coins": 0, "keys": 0, "chapter_keys": 0},
		"hints": {"day": "", "used": 0},
		"daily": {"done": {}, "streak": 0, "best_streak": 0, "last_date": ""},
		"achievements": {},
		"stats": {"levels": 0, "stars": 0, "perfect": 0, "pieces": 0, "twins": 0, "bumps": 0, "dailies": 0, "best_streak": 0, "hints": 0},
		"settings": {"music_volume": 0.6, "sound_volume": 0.8, "haptics": true, "shake": true, "theme": "chapters", "style": "neon", "appearance": "auto"},
		"seen": {},
		"last_level": "",
		# levels cleared since the last video between levels
		"levels_since_video": 0,
	}


func load_data() -> void:
	recovered_from = ""
	var loaded: Variant = _read(path)
	if loaded == null and FileAccess.file_exists(path):
		loaded = _read(path + ".bak")
		recovered_from = "backup" if loaded != null else "fresh"
	var d: Dictionary = loaded if loaded is Dictionary else {}
	data = _merge(defaults(), d)
	data["version"] = VERSION


func _read(p: String) -> Variant:
	if not FileAccess.file_exists(p):
		return null
	var text: String = FileAccess.get_file_as_string(p)
	if text.is_empty():
		return null
	var json: JSON = JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		return null
	return json.data


## Fills in any keys a saved document lacks (older versions, partial files)
## and drops values of the wrong type.
static func _merge(base: Dictionary, over: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	for k: Variant in over:
		if not out.has(k):
			out[k] = over[k]
		elif out[k] is Dictionary and over[k] is Dictionary:
			out[k] = _merge(out[k], over[k])
		elif typeof(out[k]) == typeof(over[k]) or (out[k] is float and over[k] is int) or (out[k] is int and over[k] is float):
			out[k] = over[k]
	return out


## Saves soon (once per frame at most).
func mark_dirty() -> void:
	if not _dirty:
		_dirty = true
		flush.call_deferred()


func flush() -> void:
	_dirty = false
	var tmp: String = path + ".tmp"
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Save: cannot write %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		return
	f.store_string(JSON.stringify(data))
	f.close()
	var dir: DirAccess = DirAccess.open(path.get_base_dir())
	if dir == null:
		return
	if FileAccess.file_exists(path):
		dir.copy(path, path + ".bak")
	dir.rename(tmp, path)
	saved.emit()


## Erases progress (levels, stars, streaks, achievements, earned coins) but keeps
## settings and everything paid for: packs, trials, keys and bought coins.
func reset() -> void:
	var keep: Dictionary = {}
	for k: String in ["settings", "owned", "trials", "tips", "keys", "chapter_keys", "chapters_opened", "coins_bought"]:
		keep[k] = data.get(k)
	data = defaults()
	for k: String in keep:
		if keep[k] != null:
			data[k] = keep[k]
	data["coins"] = Economy.START_COINS + int(data["coins_bought"])
	flush()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _dirty:
			flush()
