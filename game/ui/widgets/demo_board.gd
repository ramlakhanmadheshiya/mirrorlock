class_name DemoBoard
extends PanelContainer
## A small board on a soft card that plays itself: a ghost finger taps a piece,
## the twins zip off (or bump, if the script says so), and when the board is
## clear it celebrates and starts again. Used for the home screen's attract
## mode, How to play and the chapter cards.

## The home screen's demo: four pairs that must leave in the right order.
const HOME: Dictionary = {"w": 4, "h": 5, "axis": "v", "pieces": [
	[1, 2, "L", 2], [2, 2, "R", 2], [0, 4, "U", 2], [3, 4, "U", 2],
	[1, 0, "U", 1], [2, 0, "U", 1], [1, 4, "D", 1], [2, 4, "D", 1]]}

var board: BoardView
var level_data: Dictionary = HOME
## Pieces to tap, in order ([] = the solver's solution).
var script_taps: Array = []
var accent: Color = Style.AMBER
var beat: float = 1.5
var _state: PlayState
var _step: int = 0
var _timer: Timer
var _taps: Array = []


func _init(data: Dictionary = HOME, taps: Array = [], acc: Color = Style.AMBER) -> void:
	level_data = data
	script_taps = taps
	accent = acc
	name = "DemoCard"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(300, 260)
	var sb: StyleBoxFlat = UIKit.box(Color(Style.INK, 0.04), 44, Color(Style.INK, 0.07), 2, Vector2(8, 8))
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 24
	sb.shadow_offset = Vector2(0, 10)
	add_theme_stylebox_override("panel", sb)
	board = BoardView.new()
	board.input_enabled = false
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board)
	resized.connect(func() -> void:
		var l: Dictionary = level_data
		var want: float = clampf(size.y * float(l["w"]) / float(l["h"]), 260.0, 520.0)
		if absf(custom_minimum_size.x - want) > 2.0:
			custom_minimum_size.x = want
	)


func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = beat
	_timer.timeout.connect(_tick)
	add_child(_timer)
	_restart()
	_timer.start()


func _restart() -> void:
	_state = PlayState.new(MirrorLevel.from_dict(level_data))
	_taps = script_taps.duplicate() if not script_taps.is_empty() else Array(MirrorSolver.solve(_state.rules))
	_step = 0
	board.setup(_state, accent)
	board.show_ghost(int(_taps[0]) if not _taps.is_empty() else -1)


## One beat: tap the piece the finger is on, then point at the next one.
func _tick() -> void:
	if _step >= _taps.size():
		_restart()
		return
	var i: int = int(_taps[_step])
	var r: Dictionary = _state.tap(i)
	if bool(r.get("ok", false)):
		board.play_exit(r["group"])
	elif not bool(r.get("ignored", false)):
		board.play_bump(r["group"], float(r["travel"]), r["obstacles"])
	_step += 1
	if _step < _taps.size():
		board.show_ghost(int(_taps[_step]))
	else:
		board.show_ghost(-1)
		if _state.is_complete():
			board.celebrate()
