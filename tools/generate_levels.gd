extends SceneTree
## Builds every chapter's 40 levels with LevelGenerator and writes
## data/levels/<chapter>.json. Daily puzzles are not stored: the game builds
## each day's puzzle from the date (see LevelGenerator.daily).
##
##   godot --headless --path . -s res://tools/generate_levels.gd
##   godot --headless --path . -s res://tools/generate_levels.gd -- slant
##
## Deterministic: the same plan always gives the same levels. Within each
## chapter every level is a little harder than the one before it.

const OUT_DIR: String = "res://data/levels/"


func _init() -> void:
	var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/chapters.json"))
	var gen: LevelGenerator = LevelGenerator.new(plan)
	var only: PackedStringArray = OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var t0: int = Time.get_ticks_msec()
	var chapters: Array = plan["chapters"]
	for ci: int in chapters.size():
		var ch: Dictionary = chapters[ci]
		if not only.is_empty() and not only.has(ch["id"]):
			continue
		var t1: int = Time.get_ticks_msec()
		var levels: Array[MirrorLevel] = gen.chapter_levels(ci)
		if levels.is_empty():
			push_error("FAILED chapter %s" % ch["id"])
			quit(1)
			return
		var out: Array = []
		for lv: MirrorLevel in levels:
			out.append(lv.to_dict())
			var a: Dictionary = MirrorSolver.analyse(MirrorRules.new(lv))
			print("%s  %dx%d %s  pieces=%2d moves=%2d depth=%d blocked=%.2f forced=%d traps=%.2f dead=%d stones=%d locks=%s score=%.2f" % [
				lv.id, lv.w, lv.h, lv.axis, lv.pieces.size(), a["moves"], a["depth"], a["blocked"], a["forced"], a["traps"], a["dead_ends"], lv.stones.size(), lv.has_locks(), lv.score])
		var f: FileAccess = FileAccess.open(OUT_DIR + ch["id"] + ".json", FileAccess.WRITE)
		f.store_string(JSON.stringify({"chapter": ch["id"], "levels": out}, "\t", false))
		f.close()
		print("  %s in %.1fs" % [ch["id"], (Time.get_ticks_msec() - t1) / 1000.0])
	print("GENERATED in %.1fs" % ((Time.get_ticks_msec() - t0) / 1000.0))
	quit(0)
