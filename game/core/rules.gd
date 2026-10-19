class_name MirrorRules
extends RefCounted
## The move rule, compiled once per level into bit masks so the game, the
## solver, the generator and the tests all share one fast, deterministic answer.
##
## The rule:
## - Tapping a piece moves its whole group at once: the piece plus every piece
##   that is its exact mirror image (same length, cells and direction reflected)
##   under the mirror in force. A piece with no image moves alone.
## - Every piece in the group slides straight ahead until it leaves the board.
## - The move is blocked if any path holds another piece or an active stone, if
##   a piece is locked (its key is still on the board), or if two pieces of the
##   group would meet (twins heading into each other across the mirror always
##   crash). A blocked move changes nothing: the group bumps and slides back.
##
## The set of pieces still on the board is a bit mask (`present`); `moves` is
## the number of successful moves so far (stones and the turning mirror use it).

var level: MirrorLevel
var count: int = 0
var cells: Array[PackedInt32Array] = []
var paths: Array[PackedInt32Array] = []
## Pieces whose cells lie on piece i's path.
var block_mask: Array[int] = []
## Pieces that piece i would hit if they moved together (path through their
## cells, or paths that cross).
var collide_mask: Array[int] = []
## The move count piece i must wait for (the largest stone count on its path).
var stone_wait: Array[int] = []
var lock_of: Array[int] = []
## Key id -> mask of the key pieces with that id.
var key_masks: Dictionary = {}
## op -> for each piece, the index of its mirror image (or -1).
var images: Dictionary = {}
var full_mask: int = 0
## Cell index -> piece index at the start (-1 for empty).
var start_owner: PackedInt32Array = PackedInt32Array()


func _init(l: MirrorLevel) -> void:
	level = l
	count = l.pieces.size()
	full_mask = (1 << count) - 1
	start_owner.resize(l.cell_count())
	start_owner.fill(-1)
	for i: int in count:
		var cs: PackedInt32Array = PackedInt32Array()
		for c: Vector2i in MirrorLevel.piece_cells(l.pieces[i]):
			cs.append(l.index(c) if l.in_bounds(c) else -1)
			if l.in_bounds(c):
				start_owner[l.index(c)] = i
		cells.append(cs)
		var ps: PackedInt32Array = PackedInt32Array()
		for c: Vector2i in l.piece_path(l.pieces[i]):
			ps.append(l.index(c))
		paths.append(ps)
		lock_of.append(int(l.pieces[i]["lock"]))
		var key: int = int(l.pieces[i]["key"])
		if key >= 0:
			key_masks[key] = int(key_masks.get(key, 0)) | (1 << i)
	for i: int in count:
		var bm: int = 0
		var cm: int = 0
		for j: int in count:
			if j == i:
				continue
			var on_path: bool = _meets(paths[i], cells[j])
			if on_path:
				bm |= 1 << j
			if on_path or _meets(paths[j], cells[i]) or _meets(paths[i], paths[j]):
				cm |= 1 << j
		block_mask.append(bm)
		collide_mask.append(cm)
		var wait: int = 0
		for s: Vector3i in l.stones:
			if paths[i].has(l.index(Vector2i(s.x, s.y))):
				wait = maxi(wait, s.z)
		stone_wait.append(wait)
	for op: String in ["V", "H", "D", "R"]:
		var img: PackedInt32Array = PackedInt32Array()
		img.resize(count)
		img.fill(-1)
		for i: int in count:
			var m: Dictionary = l.mirror_piece(l.pieces[i], op)
			for j: int in count:
				if j != i and MirrorLevel.same_piece(m, l.pieces[j]):
					img[i] = j
					break
		images[op] = img


static func _meets(a: PackedInt32Array, b: PackedInt32Array) -> bool:
	for x: int in a:
		if b.has(x):
			return true
	return false


static func bits(mask: int) -> Array[int]:
	var out: Array[int] = []
	var i: int = 0
	var m: int = mask
	while m != 0:
		if m & 1:
			out.append(i)
		m >>= 1
		i += 1
	return out


static func popcount(mask: int) -> int:
	var n: int = 0
	var m: int = mask
	while m != 0:
		m &= m - 1
		n += 1
	return n


## The group that moves when piece i is tapped.
func group(i: int, present: int, moves: int) -> int:
	return group_for(i, present, level.ops_at(moves))


## The group piece i would move with under the given mirror operations.
func group_for(i: int, present: int, ops: Array[String]) -> int:
	var g: int = 1 << i
	for op: String in ops:
		var j: int = (images[op] as PackedInt32Array)[i]
		if j >= 0 and present & (1 << j):
			g |= 1 << j
	return g


func is_locked(i: int, present: int) -> bool:
	var k: int = lock_of[i]
	return k >= 0 and (present & int(key_masks.get(k, 0))) != 0


## True if the group can slide off the board right now.
func group_free(g: int, present: int, moves: int) -> bool:
	var m: int = g
	var i: int = 0
	while m != 0:
		if m & 1:
			if block_mask[i] & present & ~g:
				return false
			if collide_mask[i] & g:
				return false
			if moves < stone_wait[i]:
				return false
			if is_locked(i, present):
				return false
		m >>= 1
		i += 1
	return true


func can_tap(i: int, present: int, moves: int) -> bool:
	return present & (1 << i) and group_free(group(i, present, moves), present, moves)


## Every distinct group that could be tapped now, as [group mask, free].
## Each group is listed once, by its lowest piece.
func groups_now(present: int, moves: int) -> Array:
	var out: Array = []
	var seen: int = 0
	for i: int in count:
		if not (present & (1 << i)) or seen & (1 << i):
			continue
		var g: int = group(i, present, moves)
		seen |= g
		out.append([g, group_free(g, present, moves)])
	return out


## Cells a stone blocks after `moves` moves.
func active_stones(moves: int) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for s: Vector3i in level.stones:
		if moves < s.z:
			out.append(s)
	return out


## Why a group is blocked and how far each piece gets, for the bump animation.
## Returns {"travel": cells every piece moves before the bump (they move in
## step), "obstacles": cell indices to flash, "reason": "piece" / "stone" /
## "twins" / "lock" / ""}.
func explain(g: int, present: int, moves: int) -> Dictionary:
	var travel: float = 1000.0
	var obstacles: Array[int] = []
	var reason: String = ""
	var members: Array[int] = bits(g)
	var stone_cells: Dictionary = {}
	for s: Vector3i in active_stones(moves):
		stone_cells[level.index(Vector2i(s.x, s.y))] = true
	var owner: Dictionary = {}
	for j: int in count:
		if present & (1 << j) and not (g & (1 << j)):
			for c: int in cells[j]:
				owner[c] = j
	for i: int in members:
		if is_locked(i, present):
			travel = 0.0
			reason = "lock"
			obstacles.append(cells[i][0])
			continue
		var p: PackedInt32Array = paths[i]
		for k: int in p.size():
			if owner.has(p[k]) or stone_cells.has(p[k]):
				if float(k) < travel:
					travel = float(k)
				reason = "stone" if stone_cells.has(p[k]) else ("piece" if reason != "lock" else reason)
				obstacles.append(p[k])
				break
		for j: int in members:
			if j == i:
				continue
			var hit: int = -1
			for k: int in p.size():
				if cells[j].has(p[k]):
					hit = k
					break
			if hit >= 0:
				# Heading into each other: they meet half way.
				travel = minf(travel, float(hit) / 2.0)
				if reason.is_empty():
					reason = "twins"
				obstacles.append(p[hit])
				continue
			for k: int in p.size():
				if paths[j].has(p[k]):
					# Crossing paths: they reach the same cell together.
					travel = minf(travel, float(k) + 0.1)
					if reason.is_empty():
						reason = "twins"
					obstacles.append(p[k])
					break
	if travel >= 1000.0:
		travel = 0.0
	return {"travel": travel, "obstacles": obstacles, "reason": reason}
