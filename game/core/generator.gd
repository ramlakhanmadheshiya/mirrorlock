class_name LevelGenerator
extends RefCounted
## Builds levels backwards from an empty board, so every level is solvable by
## construction, then checks and grades them with MirrorSolver.
##
## Backward construction: the groups are added in reverse removal order. The
## group added k-th will be the k-th from last to leave, so when it is placed
## every piece already on the board is still there when it moves: its paths
## must be clear of all of them (and of stones still standing at that move).
## Its own cells may sit on the paths of pieces already placed, which is what
## makes them wait for it. Placements that block the most are preferred, so
## levels get long "this before that" chains instead of loose pieces.
##
## Everything is seeded, so the same plan always gives the same levels (CI
## regenerates them and fails on any difference), and the daily puzzle is the
## same for every player on the same date.

const TRIES_PER_GROUP: int = 70
const CANDIDATES: int = 30

var plan: Dictionary = {}


func _init(p: Dictionary = {}) -> void:
	plan = p


# --- One level -----------------------------------------------------------------

## Builds one candidate from parameters, or null if it couldn't be built:
##   w, h, axis ("v" "h" "d" "k" "t"), start ("v"/"h" for "t"), groups (how
##   many groups to place), lonely (how many of them have no twin), stones,
##   locks (0-2 lock colours), max_len (1-3), tangle (0..1, how strongly to
##   prefer placements that block other pieces).
static func build(rng: RandomNumberGenerator, prm: Dictionary) -> MirrorLevel:
	var l: MirrorLevel = MirrorLevel.new()
	l.w = int(prm.get("w", 4))
	l.h = int(prm.get("h", 4))
	l.axis = str(prm.get("axis", "v"))
	l.start = str(prm.get("start", "v"))
	l.id = str(prm.get("id", ""))
	var m: int = int(prm.get("groups", 3))
	var lonely_left: int = int(prm.get("lonely", 0))
	var max_len: int = clampi(int(prm.get("max_len", 2)), 1, 3)
	var tangle: float = float(prm.get("tangle", 0.7))
	var occ: PackedInt32Array = PackedInt32Array()
	occ.resize(l.cell_count())
	occ.fill(-1)
	# Stones first: they sit on one side only, so they break the symmetry.
	var n_stones: int = int(prm.get("stones", 0))
	for s: int in n_stones:
		for attempt: int in 30:
			var c: Vector2i = Vector2i(rng.randi_range(0, l.w - 1), rng.randi_range(0, l.h - 1))
			if occ[l.index(c)] != -1 or _on_axis(l, c):
				continue
			var t: int = rng.randi_range(1, maxi(1, mini(m - 1, 2 + s * 2)))
			l.stones.append(Vector3i(c.x, c.y, t))
			occ[l.index(c)] = -2
			break
	var groups: Array = []  # construction order: each an Array of piece dicts
	var stone_used: Dictionary = {}
	# Which constructed groups are lonely (decided up front, spread out).
	var lonely_at: Dictionary = {}
	if lonely_left > 0:
		var slots: Array[int] = []
		for k: int in range(1, m + 1):
			slots.append(k)
		_shuffle(rng, slots)
		for k: int in mini(lonely_left, m - 1):
			lonely_at[slots[k]] = true
	for k: int in range(1, m + 1):
		var moves_before: int = m - k  # this group leaves on move m - k + 1
		var ops: Array[String] = l.ops_at(moves_before)
		var lonely: bool = lonely_at.has(k)
		var best: Array = []
		var best_score: float = -1.0e9
		for attempt: int in TRIES_PER_GROUP:
			var n: int = _pick_len(rng, max_len)
			var d: int = rng.randi_range(0, 3)
			var dv: Vector2i = MirrorLevel.DIRS[d]
			var tail: Vector2i = Vector2i(rng.randi_range(0, l.w - 1), rng.randi_range(0, l.h - 1))
			var head: Vector2i = tail + dv * (n - 1)
			if not l.in_bounds(head):
				continue
			var p: Dictionary = MirrorLevel.make_piece(tail.x, tail.y, d, n)
			var members: Array = [p]
			if not lonely:
				for op: String in ops:
					var img: Dictionary = l.mirror_piece(p, op)
					var dup: bool = false
					for q: Dictionary in members:
						if MirrorLevel.same_piece(q, img):
							dup = true
					if not dup:
						members.append(img)
				if members.size() == 1:
					continue
			var sc: float = _placement_score(l, occ, members, groups, ops, moves_before, stone_used)
			if sc <= -1.0e8:
				continue
			sc += rng.randf() * (1.0 - tangle) * 4.0
			if sc > best_score:
				best_score = sc
				best = members
		if best.is_empty():
			break
		groups.append(best)
		for p: Dictionary in best:
			for c: Vector2i in MirrorLevel.piece_cells(p):
				occ[l.index(c)] = 1
			for c: Vector2i in l.piece_path(p):
				for s: Vector3i in l.stones:
					if Vector2i(s.x, s.y) == c and s.z <= moves_before:
						stone_used[c] = true
	if groups.size() < maxi(2, m - 1):
		return null
	# Locks: a group that would be free at once is locked until a key group,
	# which must leave first, has escaped.
	var n_locks: int = int(prm.get("locks", 0))
	if n_locks > 0 and not _place_locks(l, rng, groups, n_locks):
		return null
	# Shuffle piece order so indices give nothing away.
	var flat: Array[Dictionary] = []
	for g: Array in groups:
		for p: Dictionary in g:
			flat.append(p)
	_shuffle(rng, flat)
	l.pieces = flat
	return l


static func _pick_len(rng: RandomNumberGenerator, max_len: int) -> int:
	var r: float = rng.randf()
	if max_len >= 3 and r < 0.18:
		return 3
	if max_len >= 2 and r < 0.68:
		return 2
	return 1


static func _shuffle(rng: RandomNumberGenerator, a: Array) -> void:
	for i: int in range(a.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Variant = a[i]
		a[i] = a[j]
		a[j] = tmp


## Cells on a mirror line that pieces never use for one-sided things (stones).
static func _on_axis(l: MirrorLevel, c: Vector2i) -> bool:
	if l.axis == "d":
		return c.x == c.y
	return false


## How good a placement is (higher is better), or -1e9 if it breaks a rule.
static func _placement_score(l: MirrorLevel, occ: PackedInt32Array, members: Array, groups: Array, ops: Array[String], moves_before: int, stone_used: Dictionary) -> float:
	var mine: Dictionary = {}
	for p: Dictionary in members:
		for c: Vector2i in MirrorLevel.piece_cells(p):
			if not l.in_bounds(c) or occ[l.index(c)] != -1 or mine.has(c):
				return -1.0e9
			mine[c] = true
	var score: float = 0.0
	var paths: Array = []
	for p: Dictionary in members:
		var path: Array[Vector2i] = l.piece_path(p)
		for c: Vector2i in path:
			var o: int = occ[l.index(c)]
			if o >= 0:
				return -1.0e9
			if o == -2:
				for s: Vector3i in l.stones:
					if Vector2i(s.x, s.y) == c:
						if s.z > moves_before:
							return -1.0e9
						# A stone that has crumbled by now: it made this group wait.
						score += 4.0 if not stone_used.has(c) else 0.8
			if mine.has(c):
				return -1.0e9
		paths.append(path)
	# Members must not cross each other's paths (twins heading into each other crash).
	for a: int in paths.size():
		for b: int in range(a + 1, paths.size()):
			for c: Vector2i in paths[a]:
				if (paths[b] as Array).has(c):
					return -1.0e9
	# No piece already placed may be an exact mirror image of a new piece:
	# it would join the group when it moves.
	for p: Dictionary in members:
		for op: String in ops:
			var img: Dictionary = l.mirror_piece(p, op)
			for g: Array in groups:
				for q: Dictionary in g:
					if MirrorLevel.same_piece(q, img):
						return -1.0e9
	# Turning mirror: reward pieces that pair with someone else when the mirror
	# is the other way round, so timing matters.
	if l.axis == "t":
		var other: String = "H" if ops[0] == "V" else "V"
		for p: Dictionary in members:
			var img: Dictionary = l.mirror_piece(p, other)
			for g: Array in groups:
				for q: Dictionary in g:
					if MirrorLevel.same_piece(q, img):
						score += 2.0
	# Reward blocking pieces placed earlier (they leave later, so they wait).
	var blocked: int = 0
	for g: Array in groups:
		for q: Dictionary in g:
			for c: Vector2i in l.piece_path(q):
				if mine.has(c):
					blocked += 1
					break
	score += float(blocked) * 1.6
	# Prefer long paths a little (a piece deep in the board is harder to read).
	for path: Array in paths:
		score += 0.08 * float(path.size())
	return score


## Locks one early-leaving-is-tempting group behind a key group that leaves
## before it. Returns false if no fitting pair was found.
static func _place_locks(l: MirrorLevel, rng: RandomNumberGenerator, groups: Array, n_locks: int) -> bool:
	# Group indices in construction order: higher index = leaves earlier.
	var tmp: MirrorLevel = MirrorLevel.new()
	tmp.w = l.w
	tmp.h = l.h
	tmp.axis = l.axis
	tmp.start = l.start
	tmp.stones = l.stones
	var owner: Array[int] = []
	for gi: int in groups.size():
		for p: Dictionary in groups[gi]:
			tmp.pieces.append(p)
			owner.append(gi)
	var rules: MirrorRules = MirrorRules.new(tmp)
	var free_at_start: Dictionary = {}
	var blocked_at_start: Dictionary = {}
	for gf: Array in rules.groups_now(rules.full_mask, 0):
		var gi: int = owner[MirrorRules.bits(int(gf[0]))[0]]
		if bool(gf[1]):
			free_at_start[gi] = true
		else:
			blocked_at_start[gi] = true
	var used: Dictionary = {}
	for lock_id: int in n_locks:
		var lock_g: int = -1
		var order: Array[int] = []
		for gi: int in groups.size():
			order.append(gi)
		_shuffle(rng, order)
		for gi: int in order:
			if free_at_start.has(gi) and not used.has(gi) and gi < groups.size() - 1:
				lock_g = gi
				break
		if lock_g < 0:
			return false
		var key_g: int = -1
		for gi: int in range(groups.size() - 1, lock_g, -1):
			if not used.has(gi) and blocked_at_start.has(gi):
				key_g = gi
				break
		if key_g < 0:
			for gi: int in range(groups.size() - 1, lock_g, -1):
				if not used.has(gi):
					key_g = gi
					break
		if key_g < 0:
			return false
		used[lock_g] = true
		used[key_g] = true
		for p: Dictionary in groups[lock_g]:
			p["lock"] = lock_id
		for p: Dictionary in groups[key_g]:
			p["key"] = lock_id
	return true


# --- Grading -------------------------------------------------------------------

## A level's difficulty score: more taps, longer chains, more pieces that bump,
## fewer safe choices and (on the turning mirror) more dead ends all add to it.
## Uses only + * / and sqrt, so it is identical on every platform.
static func difficulty(l: MirrorLevel) -> float:
	return score_of(l, MirrorSolver.analyse(MirrorRules.new(l)))


static func score_of(l: MirrorLevel, a: Dictionary) -> float:
	if not bool(a.get("solvable", false)):
		return -1.0
	var s: float = 0.0
	s += 0.42 * float(a["moves"])
	s += 0.18 * float(a["pieces"])
	s += 1.0 * float(a["depth"])
	s += 4.0 * float(a["blocked"])
	s += 0.3 * float(a["forced"])
	s += 1.8 * float(a["traps"])
	s += 0.7 * sqrt(float(a["dead_ends"]))
	s += 0.9 * sqrt(float(a.get("timing", 0)))
	s += 0.012 * float(l.cell_count())
	s += 0.35 * float(l.stones.size())
	s += 0.6 if l.has_locks() else 0.0
	# Finer grain: denser boards and longer paths take longer to read.
	var cells: int = 0
	var path: int = 0
	for p: Dictionary in l.pieces:
		cells += int(p["n"])
		path += l.piece_path(p).size()
	s += 0.03 * float(cells) + 0.012 * float(path)
	return s


## Checks a candidate against the rules for its slot. Returns "" if it passes,
## else the reason it was rejected.
static func check(l: MirrorLevel, a: Dictionary, n: int, features: Dictionary) -> String:
	if not bool(a.get("solvable", false)):
		return "unsolvable"
	if l.pieces.size() < 4:
		return "too few pieces"
	var rules: MirrorRules = MirrorRules.new(l)
	var gs: Array = rules.groups_now(rules.full_mask, 0)
	var free: int = 0
	for gf: Array in gs:
		if bool(gf[1]):
			free += 1
	if n >= 2 and free == gs.size():
		return "trivial: everything is free at the start"
	var min_depth: int = 1 if n <= 1 else (2 if n <= 12 else 3)
	if l.axis != "t" and int(a["depth"]) < min_depth:
		return "too shallow"
	if l.axis == "t" and n >= 2 and int(a.get("timing", 0)) < (1 if n < 12 else 3):
		return "the turning mirror doesn't matter"
	if bool(features.get("stones", false)) and not stones_matter(l):
		return "stones don't matter"
	if bool(features.get("lonely", false)) and not lonely_matters(l):
		return "lonely pieces don't matter"
	if bool(features.get("locks", false)) and not locks_matter(l):
		return "locks don't matter"
	return ""


## A stone matters if some group is held back by a stone alone at the start.
static func stones_matter(l: MirrorLevel) -> bool:
	if l.stones.is_empty():
		return false
	var rules: MirrorRules = MirrorRules.new(l)
	for gf: Array in rules.groups_now(rules.full_mask, 0):
		if bool(gf[1]):
			continue
		var g: int = int(gf[0])
		var only_stone: bool = true
		var waits: bool = false
		for i: int in MirrorRules.bits(g):
			if rules.block_mask[i] & rules.full_mask & ~g or rules.collide_mask[i] & g or rules.is_locked(i, rules.full_mask):
				only_stone = false
			if rules.stone_wait[i] > 0:
				waits = true
		if only_stone and waits:
			return true
	return false


## A lonely piece matters if it stands in the way of a twin.
static func lonely_matters(l: MirrorLevel) -> bool:
	var rules: MirrorRules = MirrorRules.new(l)
	var lonely: int = 0
	var paired: int = 0
	for gf: Array in rules.groups_now(rules.full_mask, 0):
		var g: int = int(gf[0])
		if MirrorRules.popcount(g) == 1:
			lonely |= g
		else:
			paired |= g
	for i: int in MirrorRules.bits(paired):
		if rules.block_mask[i] & lonely:
			return true
	return false


## A lock matters if a locked group has a clear path at the start (only the
## lock holds it back).
static func locks_matter(l: MirrorLevel) -> bool:
	var rules: MirrorRules = MirrorRules.new(l)
	for gf: Array in rules.groups_now(rules.full_mask, 0):
		var g: int = int(gf[0])
		var locked: bool = false
		var clear: bool = true
		for i: int in MirrorRules.bits(g):
			if rules.lock_of[i] >= 0:
				locked = true
			if rules.block_mask[i] & rules.full_mask & ~g or rules.collide_mask[i] & g or rules.stone_wait[i] > 0:
				clear = false
		if locked and clear:
			return true
	return false


# --- Chapters ------------------------------------------------------------------

## The generation parameters for level n (1-40) of chapter ci.
func params(ci: int, n: int) -> Dictionary:
	var ch: Dictionary = plan["chapters"][ci]
	var g: Dictionary = ch["gen"]
	var sizes: Array = g["sizes"]
	var idx: int = (n - 1) * (sizes.size() - 1) / 39
	var size: Array = sizes[idx]
	var axes: Array = g["axes"]
	var axis: String = str(axes[(n - 1) % axes.size()])
	if n >= int(g.get("mix_from", 99)) and g.has("mix_axes"):
		var mix: Array = g["mix_axes"]
		if n % 3 == 0:
			axis = str(mix[(n / 3) % mix.size()])
	var w: int = int(size[0])
	var h: int = int(size[1])
	if axis == "d" or axis == "t":
		w = mini(w, h)
		h = w
	if axis == "v" and w % 2 == 1:
		w -= 1
	if axis == "h" and h % 2 == 1:
		h -= 1
	if axis == "k" or axis == "t":
		w -= w % 2
		h -= h % 2
	var gr: Array = g["groups"]
	var groups: int = int(gr[0]) + (int(gr[1]) - int(gr[0])) * (n - 1) / 39
	var cells_per_group: int = 6 if axis == "k" else 3
	var cap: int = (w * h * (55 + n / 2)) / (100 * cells_per_group)
	groups = clampi(groups, 2, maxi(2, cap))
	var prm: Dictionary = {
		"w": w, "h": h, "axis": axis, "start": "v" if n % 2 == 1 else "h", "groups": groups,
		"max_len": 1 if n <= 3 else (2 if n < int(g.get("len3_from", 12)) else 3),
		"tangle": 0.55 + 0.4 * float(n) / 40.0, "lonely": 0, "stones": 0, "locks": 0,
	}
	for f: String in ["lonely", "stones", "locks"]:
		if not g.has(f):
			continue
		var spec: Array = g[f]  # [from level, count at that level, count at level 40]
		if n >= int(spec[0]):
			var k: int = int(spec[1]) + (int(spec[2]) - int(spec[1])) * (n - int(spec[0])) / maxi(1, 40 - int(spec[0]))
			if f == "locks":
				k = mini(k, 2)
			prm[f] = k
	# The chapter's own idea must matter in every level after the tutorial.
	var features: Dictionary = {}
	var idea: String = str(g.get("idea", ""))
	if idea in ["lonely", "stones", "locks"] and n >= 2:
		features[idea] = true
		prm[idea] = maxi(1, int(prm[idea]))
	if axis == "t":
		prm["max_len"] = mini(int(prm["max_len"]), 2)
		prm["groups"] = mini(groups, 9)
	prm["features"] = features
	return prm


## The 40 levels of chapter ci, each a little harder than the one before.
## Each level gets a pool of valid candidates built from its own plan; then a
## small dynamic programme picks one per level so that scores rise strictly
## from level to level while each pick stays as close as possible to the
## typical (median) difficulty of its pool. Level 40 takes the hardest pick.
func chapter_levels(ci: int) -> Array[MirrorLevel]:
	var ch: Dictionary = plan["chapters"][ci]
	var pools: Array = []
	for n: int in range(1, 41):
		if n == 1 and ch.has("tutorial"):
			var tut: MirrorLevel = MirrorLevel.from_dict(ch["tutorial"])
			tut.score = difficulty(tut)
			pools.append([tut])
		else:
			pools.append(_pool(ci, n, 0))
	for extra: int in range(1, 4):
		var picks: Array = _choose(pools)
		if not picks.is_empty():
			var out: Array[MirrorLevel] = []
			for n: int in range(1, 41):
				var lv: MirrorLevel = picks[n - 1]
				lv.id = "%s-%02d" % [ch["id"], n]
				out.append(lv)
			return out
		# No rising sequence yet: widen every pool with a harder plan and retry.
		for n: int in range(2, 41):
			(pools[n - 1] as Array).append_array(_pool(ci, n, extra))
	push_error("could not build a rising chapter for %s" % ch["id"])
	return []


## Valid candidates for level n (plan borrowed from level n + `ahead` when the
## pool needs widening), each scored.
func _pool(ci: int, n: int, ahead: int) -> Array:
	var prm: Dictionary = params(ci, mini(40, n + ahead))
	prm["features"] = params(ci, n)["features"]
	if n == 40:
		prm["groups"] = int(prm["groups"]) + 1
		prm["tangle"] = 1.0
	var out: Array = []
	for c: int in CANDIDATES * (2 if n == 40 else 1):
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 1000003 * (ci + 1) + 7919 * n + 131 * c + 977 * ahead
		var lv: MirrorLevel = build(rng, prm)
		if lv == null:
			continue
		var a: Dictionary = MirrorSolver.analyse(MirrorRules.new(lv))
		if not check(lv, a, n, prm["features"]).is_empty():
			continue
		lv.score = score_of(lv, a)
		out.append(lv)
	return out


## Picks one level per pool with strictly rising scores, closest to each
## pool's median (level 40: as hard as possible). [] if impossible.
func _choose(pools: Array) -> Array:
	var cost: Array = []
	var back: Array = []
	for n: int in pools.size():
		var pool: Array = pools[n]
		var scores: Array[float] = []
		for lv: MirrorLevel in pool:
			scores.append(lv.score)
		scores.sort()
		var med: float = scores[scores.size() / 2] if not scores.is_empty() else 0.0
		var c_row: Array[float] = []
		var b_row: Array[int] = []
		for k: int in pool.size():
			var s: float = (pool[k] as MirrorLevel).score
			var own: float = -s if n == pools.size() - 1 else absf(s - med)
			if n == 0:
				c_row.append(own)
				b_row.append(-1)
				continue
			var best: float = INF
			var arg: int = -1
			var prev_pool: Array = pools[n - 1]
			for j: int in prev_pool.size():
				if (prev_pool[j] as MirrorLevel).score + 0.05 < s and float(cost[n - 1][j]) < best:
					best = float(cost[n - 1][j])
					arg = j
			c_row.append(own + best if arg >= 0 else INF)
			b_row.append(arg)
		cost.append(c_row)
		back.append(b_row)
	var last: int = pools.size() - 1
	var end_k: int = -1
	var end_c: float = INF
	for k: int in (cost[last] as Array).size():
		if float(cost[last][k]) < end_c:
			end_c = float(cost[last][k])
			end_k = k
	if end_k < 0:
		return []
	var picks: Array = []
	picks.resize(pools.size())
	var k2: int = end_k
	for n: int in range(last, -1, -1):
		picks[n] = pools[n][k2]
		k2 = int(back[n][k2])
	return picks


# --- Daily ---------------------------------------------------------------------

## Days since the daily epoch (1 Oct 2026) for a "YYYY-MM-DD" key.
static func day_number(date_key: String) -> int:
	var parts: PackedStringArray = date_key.split("-")
	if parts.size() != 3:
		return 0
	var t: int = Time.get_unix_time_from_datetime_dict({"year": int(parts[0]), "month": int(parts[1]), "day": int(parts[2]), "hour": 12})
	var t0: int = Time.get_unix_time_from_datetime_dict({"year": 2026, "month": 10, "day": 1, "hour": 12})
	return int(round(float(t - t0) / 86400.0))


## 0 = Sunday ... 6 = Saturday.
static func weekday_of(date_key: String) -> int:
	# 1 Oct 2026 was a Thursday.
	return posmod(day_number(date_key) + 4, 7)


## The daily Mirror for a date, built on the phone from the date alone: no
## server and no stored pool, so it never runs out. The mirror kind rotates
## through all five, and difficulty follows the week (Monday gentlest, Sunday
## hardest). Same date, same puzzle, for everyone.
func daily(date_key: String) -> MirrorLevel:
	var day: int = day_number(date_key)
	var wd: int = weekday_of(date_key)
	var d: Dictionary = plan.get("daily", {})
	var levels: Array = d.get("weekday_levels", [36, 8, 14, 20, 26, 30, 33])
	var chapters: Array = d.get("chapters", [0, 1, 2, 3, 4, 5, 6, 7, 8])
	var ci: int = int(chapters[posmod(day, chapters.size())])
	var n: int = int(levels[wd])
	var prm: Dictionary = params(ci, n)
	for attempt: int in 40:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 90001 + day * 7919 + attempt * 104729
		var lv: MirrorLevel = build(rng, prm)
		if lv == null:
			continue
		var a: Dictionary = MirrorSolver.analyse(MirrorRules.new(lv))
		if not check(lv, a, n, prm["features"]).is_empty():
			continue
		lv.score = score_of(lv, a)
		lv.id = "daily-" + date_key
		return lv
	return null
