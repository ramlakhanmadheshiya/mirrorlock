class_name Achievements
extends RefCounted
## Achievement definitions. Each unlocks once when `stat` reaches `goal` and
## pays its reward exactly once (see Profile.check_achievements). Every chapter
## also has its own "chapter complete" achievement, built from the catalogue.

const BASE: Array[Dictionary] = [
	{"id": "first_escape", "title": "First Escape", "desc": "Clear your first level", "stat": "levels", "goal": 1, "reward": 20, "icon": "trophy"},
	{"id": "escapist", "title": "Escape Artist", "desc": "Clear 50 levels", "stat": "levels", "goal": 50, "reward": 60, "icon": "trophy"},
	{"id": "locksmith", "title": "Locksmith", "desc": "Clear 150 levels", "stat": "levels", "goal": 150, "reward": 150, "icon": "trophy"},
	{"id": "all_free", "title": "Every Twin Free", "desc": "Clear all 360 levels", "stat": "levels", "goal": 360, "reward": 1000, "icon": "trophy"},
	{"id": "stars_50", "title": "Starlit", "desc": "Earn 50 stars", "stat": "stars", "goal": 50, "reward": 40, "icon": "star"},
	{"id": "stars_300", "title": "Constellation", "desc": "Earn 300 stars", "stat": "stars", "goal": 300, "reward": 150, "icon": "star"},
	{"id": "stars_all", "title": "Every Star", "desc": "Earn all 1,080 stars", "stat": "stars", "goal": 1080, "reward": 1000, "icon": "star"},
	{"id": "perfect_10", "title": "Steady Hand", "desc": "Clear 10 levels with no bumps", "stat": "perfect", "goal": 10, "reward": 50, "icon": "star"},
	{"id": "perfect_100", "title": "Clear Mind", "desc": "Clear 100 levels with no bumps", "stat": "perfect", "goal": 100, "reward": 200, "icon": "star"},
	{"id": "twins_100", "title": "Double Act", "desc": "Free 100 pairs of twins", "stat": "twins", "goal": 100, "reward": 60, "icon": "sparkles"},
	{"id": "twins_1000", "title": "Hall of Mirrors", "desc": "Free 1,000 pairs of twins", "stat": "twins", "goal": 1000, "reward": 250, "icon": "sparkles"},
	{"id": "pieces_5000", "title": "Great Escape", "desc": "Send 5,000 pieces off the board", "stat": "pieces", "goal": 5000, "reward": 300, "icon": "sparkles"},
	{"id": "daily_1", "title": "Daily Reflection", "desc": "Finish a Daily Mirror", "stat": "dailies", "goal": 1, "reward": 20, "icon": "calendar"},
	# Daily streaks count days in a row: missing a day starts the count again.
	{"id": "streak_3", "title": "Three Days Bright", "desc": "Play the Daily Mirror 3 days in a row", "stat": "best_streak", "goal": 3, "reward": 40, "icon": "flame"},
	{"id": "streak_7", "title": "A Week of Mirrors", "desc": "Play the Daily Mirror 7 days in a row", "stat": "best_streak", "goal": 7, "reward": 100, "icon": "flame"},
	{"id": "streak_14", "title": "Two Weeks Twinned", "desc": "Play the Daily Mirror 14 days in a row", "stat": "best_streak", "goal": 14, "reward": 250, "icon": "flame"},
	{"id": "streak_30", "title": "A Month of Mirrors", "desc": "Play the Daily Mirror 30 days in a row", "stat": "best_streak", "goal": 30, "reward": 600, "icon": "flame"},
]

const CHAPTER_REWARD: int = 50


## Base achievements plus one per chapter ("Reflect complete").
static func all() -> Array[Dictionary]:
	var out: Array[Dictionary] = BASE.duplicate()
	for i: int in Catalog.chapter_count():
		var ch: Dictionary = Catalog.chapter(i)
		out.append({
			"id": "chapter_" + str(ch["id"]), "title": "%s complete" % ch["name"],
			"desc": "Clear all %d levels of chapter %d" % [Catalog.levels_per_chapter, i + 1],
			"stat": "ch_" + str(ch["id"]), "goal": 1, "reward": CHAPTER_REWARD, "icon": "trophy",
		})
	return out


static func by_id(id: String) -> Dictionary:
	for a: Dictionary in all():
		if a["id"] == id:
			return a
	return {}
