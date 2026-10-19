extends SceneTree
## Validates every shipped level and the daily puzzle:
## - 9 chapters of 40, ids in order, boards that fit a phone screen;
## - each level well formed (pieces on the board, no overlaps, nothing on a
##   stone, the right board shape for its mirror, groups that are real twins);
## - every level solvable, and played to the end through the real PlayState
##   with the solver's taps and no bumps;
## - not trivial, and the chapter's idea matters in every level after the first;
## - difficulty follows the chapter curve: every level harder than the one
##   before, each tier harder on average, level 40 the peak;
## - a full year of daily puzzles is valid, solvable and stable.
##
##   godot --headless --path . -s res://tests/levels_test.gd

## The 2026-10-15 daily as built by this version of the generator.
const PINNED_DAILY: String = "2431a326ccaadd8b2d7e0553670ec8da"
const IDEAS: Dictionary = {"stones": "stones", "solo": "lonely", "vault": "locks"}


func _init() -> void:
	var t: Check = Check.new("LEVELS")
	var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/chapters.json"))
	var per: int = int(plan["levels_per_chapter"])
	var chapters: Array = plan["chapters"]
	t.eq(chapters.size(), 9, "9 chapters")
	t.eq(per, 40, "40 levels per chapter")
	var tiers: Array = plan["difficulty"]["tiers"]
	var ids: Dictionary = {}
	var total: int = 0
	for ci: int in chapters.size():
		var ch: Dictionary = chapters[ci]
		var levels: Array = _load(t, ch["id"])
		t.eq(levels.size(), per, "%s has %d levels" % [ch["id"], per])
		var scores: Array[float] = []
		for i: int in levels.size():
			var lv: MirrorLevel = MirrorLevel.from_dict(levels[i])
			var n: int = i + 1
			t.eq(lv.id, "%s-%02d" % [ch["id"], n], "level id order")
			t.ok(not ids.has(lv.id), "unique id %s" % lv.id)
			ids[lv.id] = true
			_check_level(t, lv, ci, n)
			var a: Dictionary = MirrorSolver.analyse(MirrorRules.new(lv))
			var score: float = LevelGenerator.score_of(lv, a)
			t.ok(absf(score - lv.score) < 0.011, "%s: stored score matches (%.2f vs %.2f)" % [lv.id, lv.score, score])
			if n >= 2:
				var feats: Dictionary = {}
				if IDEAS.has(ch["id"]):
					feats[IDEAS[ch["id"]]] = true
				var why: String = LevelGenerator.check(lv, a, n, feats)
				t.ok(why.is_empty(), "%s passes the generator's checks (%s)" % [lv.id, why])
			scores.append(score)
			total += 1
		# Every level is a little harder than the one before it, and each tier
		# is harder on average than the tier before.
		for k: int in range(1, scores.size()):
			t.ok(scores[k] > scores[k - 1], "%s: level %d is harder than level %d (%.2f > %.2f)" % [ch["id"], k + 1, k, scores[k], scores[k - 1]])
		var prev_mean: float = -1.0
		for tier: Dictionary in tiers:
			var sum: float = 0.0
			var cnt: int = 0
			for lv_n: int in range(int(tier["from"]), int(tier["to"]) + 1):
				sum += scores[lv_n - 1]
				cnt += 1
			t.ok(sum / cnt > prev_mean, "%s: %s levels are harder than the tier before" % [ch["id"], tier["name"]])
			prev_mean = sum / cnt
		t.eq(scores.max(), scores[39], "%s: level 40 is the hardest" % ch["id"])
	t.eq(total, 360, "360 levels in all")
	_check_daily(t, plan)
	quit(t.report())


func _load(t: Check, id: String) -> Array:
	var path: String = "res://data/levels/%s.json" % id
	t.ok(FileAccess.file_exists(path), "missing %s" % path)
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	t.ok(v is Dictionary, "%s parses" % path)
	return v.get("levels", []) if v is Dictionary else []


## Structure, groups, and a full play-through with the solver's taps.
func _check_level(t: Check, lv: MirrorLevel, ci: int, n: int) -> void:
	var id: String = lv.id
	t.ok(lv.w >= 4 and lv.w <= 8 and lv.h >= 4 and lv.h <= 10, "%s fits a phone screen (%dx%d)" % [id, lv.w, lv.h])
	t.ok(lv.axis in MirrorLevel.AXES, "%s has a known mirror" % id)
	if lv.axis == "v" or lv.axis == "k" or lv.axis == "t":
		t.ok(lv.w % 2 == 0, "%s: even width for its mirror" % id)
	if lv.axis == "h" or lv.axis == "k" or lv.axis == "t":
		t.ok(lv.h % 2 == 0, "%s: even height for its mirror" % id)
	if lv.axis == "d" or lv.axis == "t":
		t.eq(lv.w, lv.h, "%s: square board for its mirror" % id)
	t.ok(lv.pieces.size() >= 4 or n == 1, "%s has at least two groups' worth of pieces" % id)
	var used: Dictionary = {}
	for s: Vector3i in lv.stones:
		t.ok(lv.in_bounds(Vector2i(s.x, s.y)) and s.z >= 1, "%s: stone on the board with a count" % id)
		used[Vector2i(s.x, s.y)] = true
	for p: Dictionary in lv.pieces:
		t.ok(int(p["n"]) >= 1 and int(p["n"]) <= 3, "%s: pieces are 1-3 long" % id)
		for c: Vector2i in MirrorLevel.piece_cells(p):
			t.ok(lv.in_bounds(c), "%s: piece inside the board" % id)
			t.ok(not used.has(c), "%s: no overlapping pieces or stones at %s" % [id, c])
			used[c] = true
	var rules: MirrorRules = MirrorRules.new(lv)
	if lv.axis != "t":
		for gf: Array in rules.groups_now(rules.full_mask, 0):
			var size: int = MirrorRules.popcount(int(gf[0]))
			var ok: bool = size == 1 or (size == 2 and lv.axis != "k") or (size == 4 and lv.axis == "k")
			t.ok(ok, "%s: groups are lonely pieces or complete twin sets (got %d)" % [id, size])
			if size == 1 and ci < 3:
				t.ok(false, "%s: no lonely pieces before chapter 4" % id)
	var sol: Array[int] = MirrorSolver.solve(rules)
	t.ok(not sol.is_empty(), "%s solvable" % id)
	var s2: PlayState = PlayState.new(lv)
	for i: int in sol:
		var r: Dictionary = s2.tap(i)
		t.ok(bool(r.get("ok", false)), "%s: solver tap %d is safe" % [id, i])
	t.ok(s2.is_complete(), "%s completes" % id)
	t.eq(s2.stars(), 3, "%s: a clean solve earns three stars" % id)


## Daily puzzles are built on the phone from the date. Check a full year:
## every day valid and solvable, the same puzzle every time for the same date,
## Sunday harder than Monday, every mirror kind appears, and a pinned puzzle so
## an accidental change to the generator (which would change everyone's daily)
## is caught.
func _check_daily(t: Check, plan: Dictionary) -> void:
	var gen: LevelGenerator = LevelGenerator.new(plan)
	var by_weekday: Array[float] = [0, 0, 0, 0, 0, 0, 0]
	var axes: Dictionary = {}
	var t0: int = Time.get_unix_time_from_datetime_dict({"year": 2026, "month": 10, "day": 1, "hour": 12})
	for d: int in 365:
		var key: String = Time.get_date_string_from_unix_time(t0 + d * 86400)
		var lv: MirrorLevel = gen.daily(key)
		t.ok(lv != null, "daily %s builds" % key)
		if lv == null:
			continue
		t.eq(lv.id, "daily-" + key, "daily id")
		_check_level(t, lv, 8, 20)
		axes[lv.axis] = true
		by_weekday[LevelGenerator.weekday_of(key)] += lv.score
	t.ok(by_weekday[0] > by_weekday[1], "Sunday dailies are harder than Monday dailies")
	t.eq(axes.size(), 5, "every mirror kind appears in the dailies")
	var a: MirrorLevel = gen.daily("2027-02-14")
	var b: MirrorLevel = LevelGenerator.new(plan).daily("2027-02-14")
	t.eq(str(a.to_dict()), str(b.to_dict()), "the same date always gives the same daily")
	t.eq(LevelGenerator.weekday_of("2026-10-19"), 1, "19 October 2026 is a Monday")
	var pinned: MirrorLevel = gen.daily("2026-10-15")
	var sig: String = JSON.stringify(pinned.to_dict()["pieces"]).md5_text()
	t.eq(sig, PINNED_DAILY, "the 2026-10-15 daily is unchanged (changing the generator changes every player's daily)")
