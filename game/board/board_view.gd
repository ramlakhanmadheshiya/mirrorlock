class_name BoardView
extends Control
## The board: a dark glass card, the glowing mirror line(s), stones and the
## neon twin pieces. Handles taps (pressing a piece lights up its whole group),
## and plays the moves: twins zip off together with trails and sparks, blocked
## groups bump forward and spring back while the obstacle flashes and the board
## shakes. Twins breathe in step, so who belongs with whom reads at a glance.
## Everything is drawn in code (no textures beyond the shared glow and icons).

signal tapped(piece: int)

const MAX_CELL: float = 112.0
const PAD: float = 18.0

var state: PlayState
var accent: Color = Style.AMBER
var input_enabled: bool = true
## Set by tests and the share picture: draw without the idle breathing.
var still: bool = false

var _cell: float = 64.0
var _origin: Vector2 = Vector2.ZERO
var _colors: Array[Color] = []
var _target_colors: Array[Color] = []
var _phase: PackedFloat32Array = PackedFloat32Array()
var _offset: PackedFloat32Array = PackedFloat32Array()
var _alpha: PackedFloat32Array = PackedFloat32Array()
var _lift: PackedFloat32Array = PackedFloat32Array()
var _flying: Dictionary = {}
var _pressed: int = 0
var _press_piece: int = -1
var _press_pos: Vector2 = Vector2.ZERO
var _hint: int = 0
var _ghost_piece: int = -1
var _ghost_t: float = 0.0
var _flashes: Array = []
var _particles: Array = []
var _shake: float = 0.0
var _axis_angle: float = 0.0
var _axis_from: float = 0.0
var _axis_k: float = 1.0
var _t: float = 0.0
var _stone_fade: Dictionary = {}
var _lock_fade: float = 1.0
var _celebrate: float = 0.0
var _boxes: Dictionary = {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(200, 200)
	clip_contents = false


func setup(s: PlayState, acc: Color = Style.AMBER) -> void:
	state = s
	accent = acc
	var n: int = s.rules.count
	_colors.resize(n)
	_target_colors.resize(n)
	_phase.resize(n)
	_offset.resize(n)
	_alpha.resize(n)
	_lift.resize(n)
	_offset.fill(0.0)
	_alpha.fill(1.0)
	_lift.fill(0.0)
	_flying.clear()
	_particles.clear()
	_flashes.clear()
	_hint = 0
	_pressed = 0
	_stone_fade.clear()
	_assign_colors(false)
	_axis_angle = _angle_for(state.axis_now())
	_axis_k = 1.0
	_lock_fade = 0.0 if _any_locked() else 1.0
	queue_redraw()


# --- Layout ------------------------------------------------------------------

func _layout() -> void:
	if state == null:
		return
	var l: MirrorLevel = state.level
	var avail: Vector2 = size - Vector2(PAD, PAD) * 2.0
	_cell = floorf(minf(minf(avail.x / l.w, avail.y / l.h), MAX_CELL))
	_cell = maxf(_cell, 8.0)
	var grid: Vector2 = Vector2(l.w, l.h) * _cell
	_origin = ((size - grid) / 2.0).round()


func cell_size() -> float:
	_layout()
	return _cell


func cell_rect(c: Vector2i) -> Rect2:
	return Rect2(_origin + Vector2(c) * _cell, Vector2(_cell, _cell))


func cell_center(c: Vector2i) -> Vector2:
	_layout()
	return _origin + (Vector2(c) + Vector2(0.5, 0.5)) * _cell


func board_rect() -> Rect2:
	_layout()
	return Rect2(_origin, Vector2(state.level.w, state.level.h) * _cell)


## Centre of a piece (where its middle is now), in local coordinates.
func piece_center(i: int) -> Vector2:
	_layout()
	return _piece_rect(i).get_center()


func _piece_rect(i: int) -> Rect2:
	var p: Dictionary = state.level.pieces[i]
	var cells: Array[Vector2i] = MirrorLevel.piece_cells(p)
	var a: Rect2 = cell_rect(cells[0])
	var r: Rect2 = a.merge(cell_rect(cells[cells.size() - 1]))
	var d: Vector2 = Vector2(MirrorLevel.DIRS[int(p["d"])])
	r.position += d * _offset[i] * _cell
	var inset: float = _cell * 0.1
	return r.grow(-inset)


# --- Colours and pairing ------------------------------------------------------

## Colours by group: twins share one colour, pieces with no twin are white.
## With a fixed mirror the groups never change, so colours come from the start;
## with the turning mirror they follow the current pairing.
func _assign_colors(animated: bool) -> void:
	var present: int = state.present if state.level.axis == "t" else state.rules.full_mask
	var moves: int = state.moves if state.level.axis == "t" else 0
	var groups: Array = state.rules.groups_now(present, moves)
	# Reading order (top-left first) so colours run cyan, pink, lime...
	groups.sort_custom(func(a: Array, b: Array) -> bool: return _first_cell(int(a[0])) < _first_cell(int(b[0])))
	var k: int = 0
	for gf: Array in groups:
		var members: Array[int] = MirrorRules.bits(int(gf[0]))
		var col: Color = Style.LONELY
		if members.size() > 1:
			col = Look.pair_color(k)
			k += 1
		for i: int in members:
			_target_colors[i] = col
			_phase[i] = float(k) * 1.7
			if not animated:
				_colors[i] = col


func _first_cell(g: int) -> int:
	var best: int = 1 << 30
	for i: int in MirrorRules.bits(g):
		best = mini(best, state.rules.cells[i][0])
	return best


func _any_locked() -> bool:
	for i: int in state.rules.count:
		if state.is_present(i) and state.rules.is_locked(i, state.present):
			return true
	return false


static func _angle_for(axis: String) -> float:
	match axis:
		"h":
			return PI / 2.0
		"d":
			return -PI / 4.0
	return 0.0


# --- Input ------------------------------------------------------------------

func piece_at(pos: Vector2) -> int:
	_layout()
	var c: Vector2i = Vector2i(floori((pos.x - _origin.x) / _cell), floori((pos.y - _origin.y) / _cell))
	if not state.level.in_bounds(c):
		return -1
	var idx: int = state.level.index(c)
	for i: int in state.rules.count:
		if state.is_present(i) and not _flying.has(i) and state.rules.cells[i].has(idx):
			return i
	return -1


func _gui_input(e: InputEvent) -> void:
	if not input_enabled or state == null:
		return
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb: InputEventMouseButton = e
		if mb.pressed:
			_press_piece = piece_at(mb.position)
			_press_pos = mb.position
			if _press_piece >= 0:
				_pressed = state.rules.group(_press_piece, state.present, state.moves)
				Haptics.tick()
		else:
			var i: int = _press_piece
			_press_piece = -1
			_pressed = 0
			if i >= 0 and (piece_at(mb.position) == i or mb.position.distance_to(_press_pos) < _cell * 0.6):
				tapped.emit(i)
		accept_event()
	elif e is InputEventMouseMotion and _press_piece >= 0:
		if (e as InputEventMouseMotion).position.distance_to(_press_pos) > _cell * 1.2:
			_press_piece = -1
			_pressed = 0


## Cancels a press in progress (e.g. when a card opens).
func cancel_press() -> void:
	_press_piece = -1
	_pressed = 0


# --- Moves -------------------------------------------------------------------

## The group escapes: every piece zips off in its direction, together.
func play_exit(members: Array[int]) -> void:
	_hint = 0
	var longest: float = 0.0
	for i: int in members:
		var p: Dictionary = state.level.pieces[i]
		var dist: float = float(state.rules.paths[i].size() + int(p["n"])) + 1.2
		longest = maxf(longest, dist)
	for i: int in members:
		_flying[i] = true
		var p: Dictionary = state.level.pieces[i]
		var dist: float = float(state.rules.paths[i].size() + int(p["n"])) + 1.2
		var dur: float = 0.22 + 0.028 * longest
		var piece: int = i
		var tw: Tween = create_tween()
		tw.tween_method(func(v: float) -> void: _offset[piece] = v, 0.0, dist, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_method(func(v: float) -> void: _alpha[piece] = v, 1.0, 0.0, dur * 0.45).set_delay(dur * 0.55)
		tw.tween_callback(func() -> void:
			_flying.erase(piece)
			_offset[piece] = 0.0
			_alpha[piece] = 0.0
		)
		# Sparks where the piece leaves the board.
		var exit_t: float = dur * sqrt(clampf((dist - 1.2 - float(p["n"]) * 0.5) / dist, 0.0, 1.0))
		get_tree().create_timer(exit_t).timeout.connect(func() -> void: _burst_exit(piece))
	if state.level.axis == "t":
		_turn_axis()
	if _lock_fade < 1.0 and not _any_locked():
		create_tween().tween_property(self, "_lock_fade", 1.0, 0.45)
	_check_stones()


## The group is blocked: everyone nudges forward the same amount, bumps and
## springs back; the obstacle flashes and the board shakes.
func play_bump(members: Array[int], travel: float, obstacles: Array) -> void:
	var reach: float = clampf(travel, 0.0, 3.0) + 0.22
	for i: int in members:
		var piece: int = i
		var tw: Tween = create_tween()
		tw.tween_method(func(v: float) -> void: _offset[piece] = v, 0.0, reach, 0.07 + 0.06 * reach).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_method(func(v: float) -> void: _offset[piece] = v, reach, 0.0, 0.42).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var delay: float = 0.07 + 0.06 * reach
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		for c: Variant in obstacles:
			_flashes.append({"cell": int(c), "t": 0.0})
		_shake = 1.0 if bool(Profile.setting("shake", true)) else 0.0
		for i: int in members:
			var r: Rect2 = _piece_rect(i)
			var d: Vector2 = Vector2(MirrorLevel.DIRS[int(state.level.pieces[i]["d"])])
			_spray(r.get_center() + d * r.size * 0.5, 6, Style.ERROR, d * -120.0)
	)


## Undo: the group slides back in from the edge.
func play_undo(mask: int) -> void:
	for i: int in MirrorRules.bits(mask):
		var p: Dictionary = state.level.pieces[i]
		var dist: float = float(state.rules.paths[i].size() + int(p["n"])) + 1.2
		var piece: int = i
		_flying.erase(piece)
		_offset[piece] = dist
		_alpha[piece] = 0.0
		var tw: Tween = create_tween().set_parallel()
		tw.tween_method(func(v: float) -> void: _offset[piece] = v, dist, 0.0, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_method(func(v: float) -> void: _alpha[piece] = v, 0.0, 1.0, 0.2)
	if state.level.axis == "t":
		_turn_axis()
	_lock_fade = 0.0 if _any_locked() else 1.0
	_stone_fade.clear()


## Re-reads the state without animation (restart, restore).
func refresh() -> void:
	for i: int in state.rules.count:
		_offset[i] = 0.0
		_alpha[i] = 1.0 if state.is_present(i) else 0.0
	_flying.clear()
	_assign_colors(false)
	_axis_angle = _angle_for(state.axis_now())
	_lock_fade = 0.0 if _any_locked() else 1.0
	queue_redraw()


func _turn_axis() -> void:
	_assign_colors(true)
	var target: float = _angle_for(state.axis_now())
	_axis_from = _axis_angle
	_axis_k = 0.0
	var tw: Tween = create_tween()
	tw.tween_method(func(v: float) -> void:
		_axis_k = v
		_axis_angle = lerp_angle(_axis_from, target, v), 0.0, 1.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _check_stones() -> void:
	for s: Vector3i in state.level.stones:
		if s.z == state.moves:
			var key: int = state.level.index(Vector2i(s.x, s.y))
			_stone_fade[key] = 1.0
			var c: Vector2 = cell_center(Vector2i(s.x, s.y))
			get_tree().create_timer(0.12).timeout.connect(func() -> void:
				_spray(c, 14, Color("9AA3C7"), Vector2.ZERO)
				Audio.play("crumble", 1.0, -4.0)
			)


func show_hint(piece: int) -> void:
	_hint = state.rules.group(piece, state.present, state.moves) if piece >= 0 else 0


func clear_hint() -> void:
	_hint = 0


## A ghost finger tapping this piece (tutorial and demos); -1 hides it.
func show_ghost(piece: int) -> void:
	_ghost_piece = piece
	_ghost_t = 0.0


## The level is clear: a ripple of light from the mirror and a shower of sparks.
func celebrate() -> void:
	_celebrate = 0.001
	var r: Rect2 = board_rect()
	for k: int in 26:
		var x: float = r.position.x + r.size.x * (float(k) + 0.5) / 26.0
		_spray(Vector2(x, r.get_center().y), 1, Look.pair_color(k), Vector2(0, -260.0 - 140.0 * absf(sin(k * 1.7))))


# --- Particles ----------------------------------------------------------------

func _burst_exit(i: int) -> void:
	if not is_inside_tree():
		return
	var p: Dictionary = state.level.pieces[i]
	var d: Vector2 = Vector2(MirrorLevel.DIRS[int(p["d"])])
	var r: Rect2 = board_rect()
	var c: Vector2 = cell_center(Vector2i(int(p["x"]), int(p["y"])))
	# Where the piece's line meets the board edge.
	var edge: Vector2 = c
	if d.x > 0:
		edge.x = r.end.x
	elif d.x < 0:
		edge.x = r.position.x
	if d.y > 0:
		edge.y = r.end.y
	elif d.y < 0:
		edge.y = r.position.y
	_spray(edge, 10, _colors[i], d * 220.0)


func _spray(at: Vector2, n: int, col: Color, push: Vector2) -> void:
	for k: int in n:
		var ang: float = randf() * TAU
		var sp: float = randf_range(60.0, 240.0)
		_particles.append({"p": at, "v": Vector2(cos(ang), sin(ang)) * sp + push, "life": 0.0,
			"max": randf_range(0.4, 0.8), "c": col, "s": randf_range(2.5, 5.5)})
	if _particles.size() > 320:
		_particles = _particles.slice(_particles.size() - 320)


# --- Frame ------------------------------------------------------------------

func _process(delta: float) -> void:
	if state == null:
		return
	_t += delta
	if _ghost_piece >= 0:
		_ghost_t += delta
	_shake = maxf(0.0, _shake - delta * 3.2)
	for k: int in range(_flashes.size() - 1, -1, -1):
		_flashes[k]["t"] = float(_flashes[k]["t"]) + delta
		if float(_flashes[k]["t"]) > 0.6:
			_flashes.remove_at(k)
	for key: Variant in _stone_fade.keys():
		_stone_fade[key] = float(_stone_fade[key]) - delta * 2.2
		if float(_stone_fade[key]) <= 0.0:
			_stone_fade.erase(key)
	for k: int in range(_particles.size() - 1, -1, -1):
		var pt: Dictionary = _particles[k]
		pt["life"] = float(pt["life"]) + delta
		if float(pt["life"]) >= float(pt["max"]):
			_particles.remove_at(k)
			continue
		pt["v"] = (pt["v"] as Vector2) * (1.0 - 2.2 * delta) + Vector2(0, 220.0 * delta)
		pt["p"] = (pt["p"] as Vector2) + (pt["v"] as Vector2) * delta
	for i: int in state.rules.count:
		_colors[i] = _colors[i].lerp(_target_colors[i], minf(1.0, delta * 6.0))
		var want: float = 1.0 if (_pressed & (1 << i)) else 0.0
		_lift[i] = move_toward(_lift[i], want, delta * 9.0)
	if _celebrate > 0.0:
		_celebrate += delta
		if _celebrate > 1.4:
			_celebrate = 0.0
	queue_redraw()


func _draw() -> void:
	if state == null:
		return
	_layout()
	var l: MirrorLevel = state.level
	var jitter: Vector2 = Vector2.ZERO
	if _shake > 0.0:
		jitter = Vector2(sin(_t * 61.0), cos(_t * 47.0)) * 9.0 * _shake * _shake
	draw_set_transform(jitter, 0.0, Vector2.ONE)
	var grid: Rect2 = Rect2(_origin, Vector2(l.w, l.h) * _cell)
	_draw_glass(grid)
	_draw_mirror(grid)
	_draw_stones()
	# Trails under the pieces.
	for i: int in _flying:
		_draw_trail(i)
	for i: int in state.rules.count:
		if state.is_present(i) or _flying.has(i):
			_draw_piece(i)
	_draw_link()
	for f: Dictionary in _flashes:
		var r: Rect2 = cell_rect(l.cell_of(int(f["cell"])))
		var a: float = 1.0 - float(f["t"]) / 0.6
		draw_texture_rect(Style.glow_texture(), r.grow(_cell * 0.6), false, Color(Style.ERROR, 0.7 * a))
		draw_style_box(_box(Color(Style.ERROR, 0.0), Color(Style.ERROR, 0.9 * a), 3, int(_cell * 0.22)), r.grow(-_cell * 0.06))
	for pt: Dictionary in _particles:
		var k: float = 1.0 - float(pt["life"]) / float(pt["max"])
		draw_circle(pt["p"], float(pt["s"]) * (0.4 + 0.6 * k), Color(pt["c"] as Color, k), true, -1.0, true)
	if _ghost_piece >= 0 and state.is_present(_ghost_piece):
		_draw_ghost(piece_center(_ghost_piece))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _box(fill: Color, border: Color, bw: int, radius: int) -> StyleBoxFlat:
	var key: String = "%s|%s|%d|%d" % [fill.to_html(), border.to_html(), bw, radius]
	if _boxes.has(key):
		return _boxes[key]
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = fill
	s.set_corner_radius_all(radius)
	s.corner_detail = 8
	s.anti_aliasing = true
	if bw > 0:
		s.border_color = border
		s.set_border_width_all(bw)
	if _boxes.size() > 600:
		_boxes.clear()
	_boxes[key] = s
	return s


func _draw_glass(grid: Rect2) -> void:
	var outer: Rect2 = grid.grow(PAD * 0.7)
	draw_texture_rect(Style.glow_texture(), outer.grow(outer.size.x * 0.12), false, Color(accent, 0.07))
	draw_style_box(_box(Style.BOARD, Color(accent, 0.28), 2, 30), outer)
	# A faint sheen across the top half of the glass.
	var sheen: Rect2 = Rect2(outer.position + Vector2(4, 4), Vector2(outer.size.x - 8, outer.size.y * 0.42))
	draw_style_box(_box(Color(1, 1, 1, 0.025), Color(0, 0, 0, 0), 0, 26), sheen)
	var l: MirrorLevel = state.level
	var dot: Color = Color(1, 1, 1, 0.07)
	for y: int in l.h:
		for x: int in l.w:
			var r: Rect2 = cell_rect(Vector2i(x, y)).grow(-_cell * 0.08)
			draw_style_box(_box(Color(1, 1, 1, 0.022), Color(0, 0, 0, 0), 0, int(_cell * 0.18)), r)
			draw_circle(r.get_center(), maxf(1.5, _cell * 0.03), dot, true, -1.0, true)


func _draw_mirror(grid: Rect2) -> void:
	var c: Vector2 = grid.get_center()
	var axis: String = state.level.axis
	var lines: Array = []
	if axis == "k":
		lines = [0.0, PI / 2.0]
	elif axis == "d":
		lines = [-PI / 4.0]
	else:
		lines = [_axis_angle]
	var col: Color = accent.lerp(Color.WHITE, 0.25)
	var breath: float = 0.75 + 0.25 * sin(_t * 2.2)
	for ang: float in lines:
		var dir: Vector2 = Vector2(sin(ang), cos(ang))
		var half: float
		if axis == "d":
			half = grid.size.length() * 0.5
			dir = (grid.end - grid.position).normalized()
		else:
			# Long enough to cross the board whichever way it points.
			var hx: float = grid.size.x * 0.5 / maxf(0.001, absf(dir.x)) if absf(dir.x) > 0.001 else INF
			var hy: float = grid.size.y * 0.5 / maxf(0.001, absf(dir.y)) if absf(dir.y) > 0.001 else INF
			half = minf(hx, hy)
		var a: Vector2 = c - dir * (half + PAD * 0.5)
		var b: Vector2 = c + dir * (half + PAD * 0.5)
		draw_line(a, b, Color(col, 0.10 * breath), _cell * 0.5, true)
		draw_line(a, b, Color(col, 0.22 * breath), _cell * 0.16, true)
		draw_line(a, b, Color(col, 0.95), maxf(2.0, _cell * 0.045), true)
		# A spark of light running along the mirror.
		var k: float = fmod(_t * 0.32 + ang, 1.0)
		var sp: Vector2 = a.lerp(b, k)
		draw_texture_rect(Style.glow_texture(), Rect2(sp - Vector2(_cell, _cell) * 0.5, Vector2(_cell, _cell)), false, Color(col, 0.55))
		for end: Vector2 in [a, b]:
			draw_circle(end, maxf(3.0, _cell * 0.07), Color(col, 0.9), true, -1.0, true)


func _draw_stones() -> void:
	var l: MirrorLevel = state.level
	for s: Vector3i in l.stones:
		var key: int = l.index(Vector2i(s.x, s.y))
		var left: int = s.z - state.moves
		var fade: float = 1.0
		if left <= 0:
			if not _stone_fade.has(key):
				continue
			fade = float(_stone_fade[key])
		var r: Rect2 = cell_rect(Vector2i(s.x, s.y)).grow(-_cell * 0.12)
		var c: Vector2 = r.get_center()
		var rad: float = r.size.x * 0.5 * (1.0 + 0.3 * (1.0 - fade))
		var pts: PackedVector2Array = PackedVector2Array()
		for k: int in 7:
			var ang: float = TAU * float(k) / 7.0 + 0.3
			var wob: float = 0.88 + 0.12 * sin(float(k) * 2.3 + float(s.x * 3 + s.y))
			pts.append(c + Vector2(cos(ang), sin(ang)) * rad * wob)
		draw_colored_polygon(pts, Color("3A4066", fade))
		var hi: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in pts:
			hi.append(c + (p - c) * 0.78 + Vector2(0, -rad * 0.08))
		draw_colored_polygon(hi, Color("586091", fade))
		pts.append(pts[0])
		draw_polyline(pts, Color("1E2340", fade), 2.0, true)
		if left > 0:
			var f: Font = UIKit.font(800)
			var fs: int = int(_cell * 0.42)
			var txt: String = str(left)
			var w: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(f, Vector2(c.x - w * 0.5, c.y + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("E8EBFF", fade))


func _draw_piece(i: int) -> void:
	var p: Dictionary = state.level.pieces[i]
	var r: Rect2 = _piece_rect(i)
	var d: Vector2 = Vector2(MirrorLevel.DIRS[int(p["d"])])
	var col: Color = _colors[i]
	var a: float = _alpha[i]
	var lift: float = _lift[i]
	if lift > 0.0:
		r = r.grow(_cell * 0.05 * lift)
	var breath: float = 1.0 if still else 0.8 + 0.2 * sin(_t * 2.4 + _phase[i])
	var thick: float = minf(r.size.x, r.size.y)
	var radius: int = int(thick * Look.radius())
	var locked: bool = state.is_present(i) and state.rules.is_locked(i, state.present)
	var glow_a: float = (0.28 + 0.25 * lift) * Look.glow() * breath * a
	if locked:
		glow_a *= 0.4
	draw_texture_rect(Style.glow_texture(), r.grow(thick * 0.55), false, Color(col, glow_a))
	var body: Color = col if not locked else col.lerp(Color("2A2E55"), 0.55)
	draw_style_box(_box(Color(body.darkened(0.35), a), Color(0, 0, 0, 0), 0, radius), Rect2(r.position + Vector2(0, thick * 0.06), r.size))
	draw_style_box(_box(Color(body, a), Color(0, 0, 0, 0), 0, radius), r)
	# Top highlight.
	var hl: Rect2 = Rect2(r.position + Vector2(thick * 0.12, thick * 0.08), Vector2(r.size.x - thick * 0.24, r.size.y * 0.32))
	draw_style_box(_box(Color(1, 1, 1, 0.22 * a), Color(0, 0, 0, 0), 0, maxi(2, radius / 2)), hl)
	# Chevrons, one per cell, pointing the way it will slide.
	var ink: Color = Color(Style.PAPER_INK, 0.82 * a)
	var cells: int = int(p["n"])
	var step: Vector2 = d * _cell
	var first: Vector2 = r.get_center() - step * (float(cells) - 1.0) * 0.5
	for k: int in cells:
		var c: Vector2 = first + step * float(k)
		_chevron(c, d, _cell * (0.2 if k < cells - 1 else 0.26), ink, maxf(2.5, _cell * (0.07 if k < cells - 1 else 0.09)))
	# Locks and keys.
	if int(p["lock"]) >= 0:
		var la: float = a * (1.0 - _lock_fade if not locked else 1.0)
		if locked or la > 0.01:
			var s: float = _cell * 0.5 * (1.0 + 0.4 * (1.0 - la))
			var ctr: Vector2 = r.get_center()
			draw_circle(ctr, s * 0.62, Color("15183A", 0.92 * la), true, -1.0, true)
			draw_texture_rect(UIKit.art("lock"), Rect2(ctr - Vector2(s, s) * 0.5, Vector2(s, s)), false, Color(1, 1, 1, la))
	if int(p["key"]) >= 0:
		var s2: float = _cell * 0.46
		var kc: Vector2 = r.get_center() - d * _cell * 0.18 * float(cells - 1)
		draw_circle(kc, s2 * 0.62, Color("15183A", 0.85 * a), true, -1.0, true)
		draw_texture_rect(UIKit.art("key"), Rect2(kc - Vector2(s2, s2) * 0.5, Vector2(s2, s2)), false, Color(1, 1, 1, a))
	# Hint: a pulsing ring around the safe group.
	if _hint & (1 << i):
		var pulse: float = 0.5 + 0.5 * sin(_t * 6.0)
		draw_style_box(_box(Color(0, 0, 0, 0), Color(Style.GOLD, 0.55 + 0.4 * pulse), 4, radius + 6), r.grow(6.0 + 5.0 * pulse))


func _chevron(c: Vector2, d: Vector2, s: float, col: Color, width: float) -> void:
	var n: Vector2 = Vector2(-d.y, d.x)
	var pts: PackedVector2Array = PackedVector2Array([c - d * s * 0.55 + n * s, c + d * s * 0.45, c - d * s * 0.55 - n * s])
	draw_polyline(pts, col, width, true)


func _draw_trail(i: int) -> void:
	var p: Dictionary = state.level.pieces[i]
	var d: Vector2 = Vector2(MirrorLevel.DIRS[int(p["d"])])
	var r: Rect2 = _piece_rect(i)
	var thick: float = minf(r.size.x, r.size.y) * 0.62
	var back: Vector2 = r.get_center() - d * (r.size.x if absf(d.x) > 0.0 else r.size.y) * 0.5
	var len: float = minf(_offset[i], 4.0) * _cell
	var tail: Vector2 = back - d * len
	var n: Vector2 = Vector2(-d.y, d.x) * thick * 0.5
	var col: Color = _colors[i]
	draw_polygon(PackedVector2Array([tail + n * 0.3, back + n, back - n, tail - n * 0.3]),
		PackedColorArray([Color(col, 0.0), Color(col, 0.55 * _alpha[i]), Color(col, 0.55 * _alpha[i]), Color(col, 0.0)]))


## While a piece is pressed: a dotted line through the mirror to each twin.
func _draw_link() -> void:
	var members: Array[int] = MirrorRules.bits(_pressed | _hint)
	if members.size() < 2:
		return
	var col: Color = Color(Style.GOLD if _hint else _colors[members[0]], 0.8)
	var a: Vector2 = piece_center(members[0])
	for k: int in range(1, members.size()):
		var b: Vector2 = piece_center(members[k])
		var dist: float = a.distance_to(b)
		var steps: int = int(dist / 14.0)
		for s: int in steps:
			if s % 2 == 0:
				draw_line(a.lerp(b, float(s) / steps), a.lerp(b, float(s + 1) / steps), col, 3.0, true)


func _draw_ghost(target: Vector2) -> void:
	var cycle: float = fmod(_ghost_t, 1.8) / 1.8
	var press: float = clampf((cycle - 0.35) / 0.12, 0.0, 1.0) * (1.0 - clampf((cycle - 0.62) / 0.12, 0.0, 1.0))
	var arrive: float = clampf(cycle / 0.35, 0.0, 1.0)
	arrive = 1.0 - pow(1.0 - arrive, 3.0)
	var alpha: float = minf(arrive * 1.5, 1.0) * (1.0 - clampf((cycle - 0.85) / 0.15, 0.0, 1.0))
	var start: Vector2 = target + Vector2(_cell * 0.9, _cell * 1.2)
	var hand: Vector2 = start.lerp(target, arrive)
	if press > 0.0:
		draw_arc(target, _cell * (0.3 + 0.35 * press), 0.0, TAU, 32, Color(1, 1, 1, 0.7 * (1.0 - press * 0.5)), 3.0, true)
	var s: float = maxf(56.0, _cell * 0.9) * (1.0 - 0.12 * press)
	var r: Rect2 = Rect2(hand - Vector2(s * 0.3, s * 0.06), Vector2(s, s))
	draw_texture_rect(UIKit.icon("pointer-filled"), r, false, Color(1, 1, 1, alpha))
	draw_texture_rect(UIKit.icon("pointer"), r, false, Color(Style.PAPER_INK, alpha))
