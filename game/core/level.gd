class_name MirrorLevel
extends RefCounted
## One level: the board size, the mirror (axis), the pieces and the stones.
##
## Cells are (x, y) with x to the right and y down. A piece is a straight
## capsule `n` cells long (1-3) lying along its direction `d`; (x, y) is its
## tail and the cells run tail -> head. When it moves it slides head first, in
## its direction, until it leaves the board.
##
## Axis kinds:
##   "v"  vertical mirror down the middle (left <-> right)
##   "h"  horizontal mirror across the middle (top <-> bottom)
##   "d"  diagonal mirror from the top-left corner to the bottom-right (square boards)
##   "k"  kaleidoscope: both the vertical and the horizontal mirror (four copies)
##   "t"  turning mirror: vertical and horizontal take turns, switching after
##        every successful move (`start` says which comes first)

const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
const DIR_NAMES: Array[String] = ["R", "D", "L", "U"]
const AXES: Array[String] = ["v", "h", "d", "k", "t"]

var id: String = ""
var w: int = 4
var h: int = 4
var axis: String = "v"
## For the turning mirror: "v" or "h", the mirror for the first move.
var start: String = "v"
## Each piece: {"x", "y", "d" (0 R, 1 D, 2 L, 3 U), "n" (length), "lock" (-1 or
## a lock id), "key" (-1 or a key id)}.
var pieces: Array[Dictionary] = []
## Stones: (x, y, t). A stone blocks its cell until `t` moves have been made.
var stones: Array[Vector3i] = []
## Difficulty score written by the generator (tests recompute it).
var score: float = 0.0


static func make_piece(x: int, y: int, d: int, n: int, lock: int = -1, key: int = -1) -> Dictionary:
	return {"x": x, "y": y, "d": d, "n": n, "lock": lock, "key": key}


static func from_dict(v: Dictionary) -> MirrorLevel:
	var l: MirrorLevel = MirrorLevel.new()
	l.id = str(v.get("id", ""))
	l.w = int(v.get("w", 4))
	l.h = int(v.get("h", 4))
	l.axis = str(v.get("axis", "v"))
	l.start = str(v.get("start", "v"))
	l.score = float(v.get("score", 0.0))
	for p: Variant in v.get("pieces", []):
		var a: Array = p
		l.pieces.append(make_piece(int(a[0]), int(a[1]), DIR_NAMES.find(str(a[2])), int(a[3]),
			int(a[4]) if a.size() > 4 else -1, int(a[5]) if a.size() > 5 else -1))
	for s: Variant in v.get("stones", []):
		var a: Array = s
		l.stones.append(Vector3i(int(a[0]), int(a[1]), int(a[2])))
	return l


## Compact JSON form: pieces as [x, y, "R", n] (plus lock and key when set).
func to_dict() -> Dictionary:
	var ps: Array = []
	for p: Dictionary in pieces:
		var a: Array = [p["x"], p["y"], DIR_NAMES[int(p["d"])], p["n"]]
		if int(p["lock"]) >= 0 or int(p["key"]) >= 0:
			a.append(p["lock"])
			a.append(p["key"])
		ps.append(a)
	var ss: Array = []
	for s: Vector3i in stones:
		ss.append([s.x, s.y, s.z])
	var out: Dictionary = {"id": id, "w": w, "h": h, "axis": axis, "pieces": ps}
	if axis == "t":
		out["start"] = start
	if not ss.is_empty():
		out["stones"] = ss
	out["score"] = snappedf(score, 0.01)
	return out


func cell_count() -> int:
	return w * h


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < w and c.y < h


func index(c: Vector2i) -> int:
	return c.y * w + c.x


func cell_of(i: int) -> Vector2i:
	return Vector2i(i % w, i / w)


## The cells of a piece, tail first.
static func piece_cells(p: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var d: Vector2i = DIRS[int(p["d"])]
	for k: int in int(p["n"]):
		out.append(Vector2i(int(p["x"]), int(p["y"])) + d * k)
	return out


## The cells a piece sweeps on its way off the board, nearest first.
func piece_path(p: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var d: Vector2i = DIRS[int(p["d"])]
	var c: Vector2i = Vector2i(int(p["x"]), int(p["y"])) + d * int(p["n"])
	while in_bounds(c):
		out.append(c)
		c += d
	return out


## Number of pairs, lonely pieces and so on, for labels.
func has_locks() -> bool:
	for p: Dictionary in pieces:
		if int(p["lock"]) >= 0:
			return true
	return false


func feature_list() -> PackedStringArray:
	var f: PackedStringArray = PackedStringArray()
	if not stones.is_empty():
		f.append("stones")
	if has_locks():
		f.append("locks")
	return f


## Mirrors a cell with one of the mirror operations: "V" (left-right),
## "H" (top-bottom), "D" (the diagonal) or "R" (half turn, V then H).
func mirror_cell(c: Vector2i, op: String) -> Vector2i:
	match op:
		"V":
			return Vector2i(w - 1 - c.x, c.y)
		"H":
			return Vector2i(c.x, h - 1 - c.y)
		"D":
			return Vector2i(c.y, c.x)
		"R":
			return Vector2i(w - 1 - c.x, h - 1 - c.y)
	return c


## Mirrors a direction (0 R, 1 D, 2 L, 3 U) with the same operation.
static func mirror_dir(d: int, op: String) -> int:
	match op:
		"V":
			return [2, 1, 0, 3][d]
		"H":
			return [0, 3, 2, 1][d]
		"D":
			return [1, 0, 3, 2][d]
		"R":
			return (d + 2) % 4
	return d


## The mirror image of a piece: its cells and its direction both reflected.
## The tail stays the tail, because the reflection is linear.
func mirror_piece(p: Dictionary, op: String) -> Dictionary:
	var c: Vector2i = mirror_cell(Vector2i(int(p["x"]), int(p["y"])), op)
	return make_piece(c.x, c.y, mirror_dir(int(p["d"]), op), int(p["n"]), int(p["lock"]), int(p["key"]))


static func same_piece(a: Dictionary, b: Dictionary) -> bool:
	return int(a["x"]) == int(b["x"]) and int(a["y"]) == int(b["y"]) and int(a["d"]) == int(b["d"]) \
		and int(a["n"]) == int(b["n"]) and int(a["lock"]) == int(b["lock"]) and int(a["key"]) == int(b["key"])


## The mirror operations in force after `moves` successful moves.
func ops_at(moves: int) -> Array[String]:
	var out: Array[String] = []
	match axis:
		"v":
			out.append("V")
		"h":
			out.append("H")
		"d":
			out.append("D")
		"k":
			out.append_array(["V", "H", "R"])
		"t":
			var v_now: bool = (moves % 2 == 0) == (start == "v")
			out.append("V" if v_now else "H")
	return out


## "v", "h" or "d": the mirror line drawn after `moves` moves ("k" draws both).
func axis_at(moves: int) -> String:
	if axis == "t":
		return "v" if ops_at(moves)[0] == "V" else "h"
	return axis
