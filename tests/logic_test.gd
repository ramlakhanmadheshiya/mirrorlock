extends SceneTree
## Rules, mirroring, solver, generator and play-state tests (no autoload state
## is changed).
##
##   godot --headless --path . -s res://tests/logic_test.gd

var t: Check = Check.new("LOGIC")


func _init() -> void:
	_mirroring()
	_moves_and_twins()
	_head_on_crash()
	_diagonal()
	_kaleidoscope()
	_turning_mirror()
	_stones()
	_locks()
	_lonely()
	_solver()
	_play_state()
	_save_restore()
	_generator()
	quit(t.report())


func _lvl(d: Dictionary) -> MirrorLevel:
	return MirrorLevel.from_dict(d)


## Every mirror maps cells and directions correctly, and twice is the identity.
func _mirroring() -> void:
	var l: MirrorLevel = _lvl({"w": 6, "h": 4, "axis": "v", "pieces": []})
	t.eq(l.mirror_cell(Vector2i(0, 1), "V"), Vector2i(5, 1), "V mirrors left-right")
	t.eq(l.mirror_cell(Vector2i(2, 0), "H"), Vector2i(2, 3), "H mirrors top-bottom")
	t.eq(l.mirror_cell(Vector2i(1, 3), "D"), Vector2i(3, 1), "D swaps x and y")
	t.eq(l.mirror_cell(Vector2i(0, 0), "R"), Vector2i(5, 3), "R is a half turn")
	t.eq(MirrorLevel.mirror_dir(0, "V"), 2, "V: right becomes left")
	t.eq(MirrorLevel.mirror_dir(3, "V"), 3, "V: up stays up")
	t.eq(MirrorLevel.mirror_dir(3, "H"), 1, "H: up becomes down")
	t.eq(MirrorLevel.mirror_dir(0, "H"), 0, "H: right stays right")
	t.eq(MirrorLevel.mirror_dir(0, "D"), 1, "D: right becomes down")
	t.eq(MirrorLevel.mirror_dir(2, "D"), 3, "D: left becomes up")
	t.eq(MirrorLevel.mirror_dir(1, "R"), 3, "R: down becomes up")
	for op: String in ["V", "H", "D", "R"]:
		var sq: MirrorLevel = _lvl({"w": 5, "h": 5, "axis": "v", "pieces": []})
		for d: int in 4:
			t.eq(MirrorLevel.mirror_dir(MirrorLevel.mirror_dir(d, op), op), d, "%s twice is the identity for direction %d" % [op, d])
		var p: Dictionary = MirrorLevel.make_piece(1, 0, 0, 2)
		t.ok(MirrorLevel.same_piece(sq.mirror_piece(sq.mirror_piece(p, op), op), p), "%s twice gives back the piece" % op)
	# A mirrored piece keeps its cells reflected (tail stays tail).
	var m: Dictionary = l.mirror_piece(MirrorLevel.make_piece(1, 1, 2, 2), "V")
	var cells: Array[Vector2i] = MirrorLevel.piece_cells(m)
	t.eq(cells, [Vector2i(4, 1), Vector2i(5, 1)] as Array[Vector2i], "a 2-long piece pointing left mirrors to one pointing right")
	t.eq(l.ops_at(0), ["V"] as Array[String], "the vertical mirror's operation")
	var k: MirrorLevel = _lvl({"w": 4, "h": 4, "axis": "k", "pieces": []})
	t.eq(k.ops_at(3), ["V", "H", "R"] as Array[String], "the kaleidoscope uses both mirrors and the half turn")


## Tapping either twin moves both; a blocked twin bumps both back.
func _moves_and_twins() -> void:
	# Pair A (row 2) is free; pair B (bottom) is blocked by A on both sides.
	var l: MirrorLevel = _lvl({"w": 4, "h": 5, "axis": "v", "pieces": [[1, 2, "L", 2], [2, 2, "R", 2], [0, 4, "U", 1], [3, 4, "U", 1]]})
	var r: MirrorRules = MirrorRules.new(l)
	t.eq(r.images["V"][0], 1, "piece 0's mirror image is piece 1")
	t.eq(r.images["V"][2], 3, "piece 2's mirror image is piece 3")
	t.eq(r.group(1, r.full_mask, 0), 0b11, "tapping the right twin selects both")
	var s: PlayState = PlayState.new(l)
	var bump: Dictionary = s.tap(3)
	t.ok(not bool(bump["ok"]), "a blocked pair bumps")
	t.eq(bump["group"], [2, 3] as Array[int], "both twins bump together")
	t.eq(bump["reason"], "piece", "blocked by a piece")
	t.eq(float(bump["travel"]), 1.0, "they get one cell before the bump")
	t.eq(s.bounces, 1, "a bump is counted")
	t.eq(s.hearts_left(), 2, "a bump costs a heart")
	t.eq(s.pieces_left(), 4, "a bump changes nothing on the board")
	var ok: Dictionary = s.tap(1)
	t.ok(bool(ok["ok"]), "the free pair escapes")
	t.eq(ok["group"], [0, 1] as Array[int], "tapping one twin moves both")
	t.eq(s.pieces_left(), 2, "both twins left the board")
	t.ok(bool(s.tap(2)["ok"]), "the pair behind is free now")
	t.ok(s.is_complete(), "every piece gone: complete")
	t.eq(s.stars(), 2, "one bump: two stars")
	t.ok(s.tap(0).get("ignored", false), "taps after the end are ignored")


## Twins sliding toward each other across the mirror always crash.
func _head_on_crash() -> void:
	var l: MirrorLevel = _lvl({"w": 6, "h": 3, "axis": "v", "pieces": [[0, 1, "R", 1], [5, 1, "L", 1]]})
	var s: PlayState = PlayState.new(l)
	var r: Dictionary = s.tap(0)
	t.ok(not bool(r["ok"]), "twins heading into each other are blocked")
	t.eq(r["reason"], "twins", "they crash into each other")
	t.eq(float(r["travel"]), 2.0, "they meet in the middle")
	t.ok(MirrorSolver.solve(s.rules).is_empty(), "a head-on pair can never leave")
	# The same twins pointing away from the mirror leave at once.
	var away: MirrorLevel = _lvl({"w": 6, "h": 3, "axis": "v", "pieces": [[2, 1, "L", 1], [3, 1, "R", 1]]})
	t.ok(bool(PlayState.new(away).tap(0)["ok"]), "twins pointing away from the mirror escape")
	# Horizontal mirror: twins moving up and down toward the line crash too.
	var h: MirrorLevel = _lvl({"w": 3, "h": 6, "axis": "h", "pieces": [[1, 0, "D", 1], [1, 5, "U", 1]]})
	t.eq(PlayState.new(h).tap(1)["reason"], "twins", "lying mirror: twins meeting across the line crash")


func _diagonal() -> void:
	var l: MirrorLevel = _lvl({"w": 4, "h": 4, "axis": "d", "pieces": [[3, 1, "R", 1], [1, 3, "D", 1], [2, 1, "R", 1], [1, 2, "D", 1]]})
	var r: MirrorRules = MirrorRules.new(l)
	t.eq(r.images["D"][0], 1, "diagonal twin of a right-pointer is a down-pointer")
	t.eq(r.group(2, r.full_mask, 0), 0b1100, "diagonal pairs move together")
	var s: PlayState = PlayState.new(l)
	t.ok(not bool(s.tap(2)["ok"]), "the inner pair is blocked by the outer one")
	t.ok(bool(s.tap(1)["ok"]) and bool(s.tap(2)["ok"]), "outer pair first, then inner")
	# Paths that cross on the diagonal crash.
	var x: MirrorLevel = _lvl({"w": 4, "h": 4, "axis": "d", "pieces": [[0, 2, "R", 1], [2, 0, "D", 1]]})
	t.eq(PlayState.new(x).tap(0)["reason"], "twins", "diagonal twins racing to the same cell crash")


func _kaleidoscope() -> void:
	var l: MirrorLevel = _lvl({"w": 4, "h": 4, "axis": "k", "pieces": [[1, 1, "L", 1], [2, 1, "R", 1], [1, 2, "L", 1], [2, 2, "R", 1], [0, 1, "U", 1], [3, 1, "U", 1], [0, 2, "D", 1], [3, 2, "D", 1]]})
	var r: MirrorRules = MirrorRules.new(l)
	t.eq(MirrorRules.popcount(r.group(0, r.full_mask, 0)), 4, "a kaleidoscope piece moves with three twins")
	var s: PlayState = PlayState.new(l)
	t.ok(not bool(s.tap(3)["ok"]), "all four bump when one is blocked")
	t.ok(bool(s.tap(6)["ok"]), "the outer four leave together")
	t.eq(s.pieces_left(), 4, "four pieces left at once")
	t.ok(bool(s.tap(0)["ok"]) and s.is_complete(), "then the inner four")


## The turning mirror swaps between standing and lying after each move, and
## the twins change with it.
func _turning_mirror() -> void:
	var l: MirrorLevel = _lvl({"w": 4, "h": 4, "axis": "t", "start": "v", "pieces": [[0, 1, "U", 1], [3, 1, "U", 1], [0, 2, "D", 1], [3, 2, "D", 1]]})
	var s: PlayState = PlayState.new(l)
	t.eq(s.axis_now(), "v", "it starts standing")
	t.eq(s.rules.group(0, s.present, 0), 0b0011, "standing: left-right twins")
	t.eq(s.rules.group(0, s.present, 1), 0b0101, "lying: top-bottom twins")
	t.ok(bool(s.tap(0)["ok"]), "the first pair leaves")
	t.eq(s.axis_now(), "h", "after a move the mirror lies down")
	var r: Dictionary = s.tap(2)
	t.eq(r["group"], [2] as Array[int], "a piece whose twin has gone moves alone")
	t.eq(s.axis_now(), "v", "and it stands up again")
	s.undo()
	t.eq(s.axis_now(), "h", "Undo turns it back")
	# A position that strands a piece: only reachable on the turning mirror.
	var trap: MirrorLevel = _lvl({"w": 4, "h": 4, "axis": "t", "start": "v", "pieces": [[1, 1, "L", 1], [2, 1, "R", 1], [0, 1, "D", 1], [1, 2, "L", 1]]})
	var a: Dictionary = MirrorSolver.analyse(MirrorRules.new(trap))
	t.ok(a.has("dead_ends") and a.has("timing"), "turning levels report dead ends and timing")


func _stones() -> void:
	var l: MirrorLevel = _lvl({"w": 4, "h": 4, "axis": "v", "stones": [[0, 1, 1]], "pieces": [[1, 0, "U", 1], [2, 0, "U", 1], [1, 1, "L", 1], [2, 1, "R", 1]]})
	var s: PlayState = PlayState.new(l)
	var r: Dictionary = s.tap(3)
	t.ok(not bool(r["ok"]), "a stone on one side blocks the pair")
	t.eq(r["reason"], "stone", "the stone is the reason")
	t.ok(bool(s.tap(0)["ok"]), "another pair moves")
	t.eq(s.rules.active_stones(s.moves).size(), 0, "one move later the stone has crumbled")
	t.ok(bool(s.tap(2)["ok"]), "and the pair is free")
	t.ok(LevelGenerator.stones_matter(l), "the stone matters here")


func _locks() -> void:
	var l: MirrorLevel = _lvl({"w": 4, "h": 5, "axis": "v", "pieces": [[1, 0, "U", 1, 0, -1], [2, 0, "U", 1, 0, -1], [0, 3, "U", 1, -1, 0], [3, 3, "U", 1, -1, 0], [1, 2, "L", 2], [2, 2, "R", 2]]})
	var s: PlayState = PlayState.new(l)
	var r: Dictionary = s.tap(0)
	t.ok(not bool(r["ok"]), "a locked pair can't move even with a clear path")
	t.eq(r["reason"], "lock", "the lock is the reason")
	t.ok(not bool(s.tap(2)["ok"]), "the key pair is blocked at first")
	t.ok(bool(s.tap(4)["ok"]), "free the way to the key")
	t.ok(bool(s.tap(2)["ok"]), "the key pair escapes")
	t.ok(bool(s.tap(1)["ok"]) and s.is_complete(), "now the lock opens")
	t.ok(LevelGenerator.locks_matter(l), "the lock matters here")


func _lonely() -> void:
	var l: MirrorLevel = _lvl({"w": 4, "h": 4, "axis": "v", "pieces": [[0, 1, "D", 1], [1, 1, "L", 1], [2, 1, "R", 1], [1, 3, "D", 1], [2, 3, "D", 1]]})
	var r: MirrorRules = MirrorRules.new(l)
	t.eq(r.group(0, r.full_mask, 0), 1, "a lonely piece moves alone")
	var s: PlayState = PlayState.new(l)
	t.ok(not bool(s.tap(2)["ok"]), "the lonely piece blocks one twin, so both bump")
	t.ok(bool(s.tap(0)["ok"]) and s.pieces_left() == 4, "the lonely piece leaves by itself")
	t.ok(LevelGenerator.lonely_matters(l), "the lonely piece matters here")


func _solver() -> void:
	var l: MirrorLevel = _lvl({"w": 4, "h": 5, "axis": "v", "pieces": [[1, 2, "L", 2], [2, 2, "R", 2], [0, 4, "U", 1], [3, 4, "U", 1], [1, 0, "U", 1], [2, 0, "U", 1]]})
	var r: MirrorRules = MirrorRules.new(l)
	var sol: Array[int] = MirrorSolver.solve(r)
	t.eq(sol.size(), 3, "three pairs: three taps")
	var s: PlayState = PlayState.new(l)
	for i: int in sol:
		t.ok(bool(s.tap(i)["ok"]), "every solver tap is safe")
	t.ok(s.is_complete(), "the solution clears the level")
	var a: Dictionary = MirrorSolver.analyse(r)
	t.ok(bool(a["solvable"]), "analyse: solvable")
	t.eq(int(a["depth"]), 2, "analyse: two rounds deep")
	t.eq(int(a["groups"]), 3, "analyse: three groups")
	var s2: PlayState = PlayState.new(l)
	var h: int = s2.hint_piece()
	t.ok(h >= 0 and s2.rules.can_tap(h, s2.present, 0), "a hint is always a safe tap")
	var stuck: MirrorLevel = _lvl({"w": 6, "h": 3, "axis": "v", "pieces": [[0, 1, "R", 1], [5, 1, "L", 1]]})
	t.eq(PlayState.new(stuck).hint_piece(), -1, "no hint when nothing can be cleared")
	t.ok(not bool(MirrorSolver.analyse(MirrorRules.new(stuck))["solvable"]), "analyse spots an impossible level")


func _play_state() -> void:
	var l: MirrorLevel = _lvl({"w": 6, "h": 3, "axis": "v", "pieces": [[0, 1, "R", 1], [5, 1, "L", 1], [2, 0, "L", 1], [3, 0, "R", 1]]})
	var s: PlayState = PlayState.new(l)
	s.tap(0)
	s.tap(0)
	t.eq(s.stars(), 1, "two bumps: one star")
	s.tap(0)
	t.ok(s.is_failed(), "three bumps: out of hearts")
	t.ok(s.tap(2).get("ignored", false), "no taps after failing")
	s.add_heart()
	t.ok(not s.is_failed(), "an extra heart lets the player go on")
	t.eq(s.hearts_left(), 1, "with one heart")
	var ok: PlayState = PlayState.new(_lvl({"w": 4, "h": 5, "axis": "v", "pieces": [[1, 2, "L", 2], [2, 2, "R", 2]]}))
	ok.use_hint()
	ok.tap(0)
	t.eq(ok.stars(), 2, "a hint caps the stars at two")
	t.eq(Economy.stars_for(0), 3, "no bumps: three stars")
	t.eq(Economy.stars_for(1), 2, "one bump: two stars")
	t.eq(Economy.stars_for(5), 1, "more bumps: one star")


func _save_restore() -> void:
	var l: MirrorLevel = _lvl({"w": 4, "h": 5, "axis": "v", "pieces": [[1, 2, "L", 2], [2, 2, "R", 2], [0, 4, "U", 1], [3, 4, "U", 1], [1, 0, "U", 1], [2, 0, "U", 1]]})
	var s: PlayState = PlayState.new(l)
	s.tap(2)
	s.tap(0)
	s.use_hint()
	var d: Dictionary = JSON.parse_string(JSON.stringify(s.to_dict()))
	var back: PlayState = PlayState.new(l)
	back.restore(d)
	t.eq(back.present, s.present, "restore: pieces left")
	t.eq(back.moves, 1, "restore: moves")
	t.eq(back.bounces, 1, "restore: bumps")
	t.eq(back.hints_used, 1, "restore: hints")
	t.ok(back.can_undo(), "restore: undo history")
	var bad: PlayState = PlayState.new(l)
	bad.restore({"present": 0, "moves": 3, "history": [1]})
	t.eq(bad.present, bad.rules.full_mask, "a save that doesn't fit is ignored")
	var lv: MirrorLevel = MirrorLevel.from_dict(JSON.parse_string(JSON.stringify(l.to_dict())))
	t.eq(str(lv.to_dict()), str(l.to_dict()), "levels survive a JSON round trip")


func _generator() -> void:
	for axis: String in ["v", "h", "d", "k", "t"]:
		var built: int = 0
		var solved: int = 0
		for seed: int in 12:
			var rng: RandomNumberGenerator = RandomNumberGenerator.new()
			rng.seed = 4242 + seed
			var w: int = 6
			var lv: MirrorLevel = LevelGenerator.build(rng, {"w": w, "h": w if axis in ["d", "t"] else 8, "axis": axis, "groups": 5, "max_len": 2, "tangle": 0.8, "lonely": 1, "stones": 1})
			if lv == null:
				continue
			built += 1
			if bool(MirrorSolver.analyse(MirrorRules.new(lv))["solvable"]):
				solved += 1
		t.ok(built >= 6, "the generator builds %s levels (%d of 12)" % [axis, built])
		t.eq(solved, built, "every level built backwards is solvable (%s)" % axis)
	# Same seed, same level.
	var a: RandomNumberGenerator = RandomNumberGenerator.new()
	a.seed = 99
	var b: RandomNumberGenerator = RandomNumberGenerator.new()
	b.seed = 99
	var prm: Dictionary = {"w": 6, "h": 8, "axis": "v", "groups": 6, "locks": 1}
	var la: MirrorLevel = LevelGenerator.build(a, prm)
	var lb: MirrorLevel = LevelGenerator.build(b, prm)
	t.ok(la != null and lb != null and str(la.to_dict()) == str(lb.to_dict()), "the generator is deterministic")
	t.ok(la != null and la.has_locks(), "locks can be placed")
	t.ok(la != null and bool(MirrorSolver.analyse(MirrorRules.new(la))["solvable"]), "a locked level stays solvable")
