extends Node
## Save, progression, star, reward, shop and ad-reward tests against the real
## autoloads, using a throwaway save file and the simulated store.
##
##   godot --headless --path . res://tests/profile_test.tscn

const TEST_SAVE: String = "user://test_profile_save.json"

var t: Check = Check.new("PROFILE")


func _ready() -> void:
	_use_fresh_save()
	Store.simulate = true
	_coins_and_free_hints()
	_stars_and_rewards()
	_unlocks_keys_and_chapters()
	_chapter_keys()
	_daily_streaks()
	_achievements_pay_once()
	_video_rewards()
	_store_purchases()
	_trials_and_looks()
	_reset_keeps_purchases()
	_restart_keeps_progress()
	_corrupt_save_recovers()
	_streak_achievements()
	_glyphs()
	_cleanup()
	get_tree().quit(t.report())


func _use_fresh_save() -> void:
	_cleanup()
	Save.path = TEST_SAVE
	Save.load_data()


func _cleanup() -> void:
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE + suffix))


## A cleared level with `bumps` bumps along the way.
func _state(id: String, bumps: int = 0) -> PlayState:
	var s: PlayState = PlayState.new(Catalog.level_by_id(id))
	for i: int in MirrorSolver.solve(s.rules):
		s.tap(i)
	s.bounces = bumps
	return s


func _coins_and_free_hints() -> void:
	t.eq(Profile.coins(), Economy.START_COINS, "new players start with coins")
	t.ok(not Profile.spend(Economy.START_COINS + 1), "cannot overspend")
	t.eq(Profile.coins(), Economy.START_COINS, "a failed spend changes nothing")
	t.ok(Profile.spend(Economy.HINT_COST), "can pay for a hint")
	t.eq(Profile.coins(), Economy.START_COINS - Economy.HINT_COST, "hint cost deducted")
	t.eq(Profile.free_hints_left(), Economy.FREE_HINTS, "three free hints a day")
	for i: int in Economy.FREE_HINTS:
		t.ok(Profile.use_free_hint(), "free hint %d" % (i + 1))
	t.ok(not Profile.use_free_hint(), "no more free hints today")
	Save.data["hints"]["day"] = "2000-01-01"
	t.eq(Profile.free_hints_left(), Economy.FREE_HINTS, "free hints refill on a new day")
	Profile.add_coins(-50)
	t.eq(Profile.coins(), Economy.START_COINS - Economy.HINT_COST, "negative rewards are ignored")


func _stars_and_rewards() -> void:
	var before: int = Profile.coins()
	var r: Dictionary = Profile.complete_level("reflect-01", _state("reflect-01", 1))
	t.eq(r["stars"], 2, "one bump: 2 stars")
	t.eq(r["coins"], Economy.LEVEL_REWARD + 2 * Economy.STAR_REWARD, "first clear pays the level and each star")
	t.eq(Profile.coins(), before + r["coins"], "coins added")
	var better: Dictionary = Profile.complete_level("reflect-01", _state("reflect-01"))
	t.eq(better["stars"], 3, "clean replay: 3 stars")
	t.eq(better["coins"], Economy.STAR_REWARD, "improving pays only the new star")
	var worse: Dictionary = Profile.complete_level("reflect-01", _state("reflect-01", 2))
	t.eq(worse["coins"], 0, "a worse replay pays nothing")
	t.eq(Profile.stars_for("reflect-01"), 3, "the best stars are kept")
	t.eq(Profile.stat("stars"), 3, "star stat counts each star once")
	t.eq(Profile.stat("levels"), 1, "levels stat counted once")
	t.eq(Profile.stat("perfect"), 1, "clean clears counted once")
	t.eq(Profile.total_stars(), 3, "total stars")


func _unlocks_keys_and_chapters() -> void:
	t.ok(Profile.level_unlocked(0, 2), "level 2 opens after level 1")
	t.ok(not Profile.level_unlocked(0, 3), "level 3 stays locked")
	t.ok(not Profile.use_key("reflect-05"), "no keys, no key unlock")
	Profile.add_keys(2)
	t.ok(Profile.use_key("reflect-05"), "a key opens a locked level")
	t.ok(Profile.level_unlocked(0, 5), "the keyed level is open")
	t.ok(not Profile.level_unlocked(0, 4), "levels before it stay locked")
	t.ok(not Profile.use_key("reflect-05"), "a key is not spent twice on one level")
	t.eq(Profile.keys(), 1, "one key left")
	t.eq(Profile.next_level(), [0, 2] as Array[int], "Play continues at the first open level")
	t.ok(not Profile.chapter_unlocked(1), "chapter 2 starts locked")
	var before: int = Profile.coins()
	var paid: int = 0
	var opened: bool = false
	var done: bool = false
	for n: int in range(2, 41):
		var r: Dictionary = Profile.complete_level(Catalog.level_id("reflect", n), _state(Catalog.level_id("reflect", n)))
		paid += int(r["coins"])
		if n == Catalog.unlock_clears:
			opened = r["chapter_unlocked"]
		if n == 40:
			done = r["chapter_done"]
	t.ok(opened, "chapter 2 opens at the 15th clear")
	t.ok(done, "clearing all 40 completes the chapter")
	t.eq(paid, 39 * (Economy.LEVEL_REWARD + 3 * Economy.STAR_REWARD) + Economy.CHAPTER_BONUS, "exact coins for the chapter, bonus included")
	t.eq(Profile.coins(), before + paid, "coins match")
	t.eq(Profile.chapter_stars(0), 120, "120 stars in a perfect chapter")
	t.ok(not Profile.complete_level("reflect-40", _state("reflect-40"))["chapter_done"], "the chapter bonus is never paid twice")
	t.eq(Profile.stat("ch_reflect"), 1, "chapter completion recorded")
	t.eq(Profile.next_level(), [1, 1] as Array[int], "Play moves to the next chapter")


## Chapter keys: earned once per chapter for level 40, open a locked chapter
## at level 1 only, limited free ones from videos, and sold in packs.
func _chapter_keys() -> void:
	t.eq(Profile.chapter_keys(), 1, "clearing level 40 earned a chapter key")
	Profile.complete_level("reflect-40", _state("reflect-40"))
	t.eq(Profile.chapter_keys(), 1, "replaying level 40 pays no second chapter key")
	t.ok(not Profile.chapter_unlocked(5), "chapter 6 is locked")
	t.ok(not Profile.use_chapter_key(1), "a chapter key is not spent on an open chapter")
	t.ok(Profile.use_chapter_key(5), "a chapter key opens a locked chapter")
	t.eq(Profile.chapter_keys(), 0, "the chapter key is spent")
	t.ok(Profile.chapter_unlocked(5), "chapter 6 is open")
	t.ok(Profile.level_unlocked(5, 1), "its level 1 is open")
	t.ok(not Profile.level_unlocked(5, 2), "but only level 1")
	t.ok(not Profile.use_chapter_key(6), "no chapter keys left")
	t.ok(Profile.add_video_chapter_key(), "one free chapter key from a video")
	t.ok(not Profile.add_video_chapter_key(), "only one a day")
	Store.buy("chapter_keys_3")
	t.eq(Profile.chapter_keys(), 4, "3 chapter keys bought")


func _daily_streaks() -> void:
	var l: MirrorLevel = Catalog.daily_level("2026-03-01")
	t.ok(l != null, "daily level loads")
	t.eq(l.id, "daily-2026-03-01", "daily id carries the date")
	t.eq(str(Catalog.daily_level("2026-03-01").to_dict()), str(l.to_dict()), "the cached daily is the same puzzle")
	t.eq(Catalog.date_key_from_day(Catalog.day_number("2026-10-15")), "2026-10-15", "day numbers round-trip")
	var s: PlayState = PlayState.new(l)
	var r1: Dictionary = Profile.complete_daily("2026-03-01", s)
	t.eq(r1["streak"], 1, "first daily starts a streak")
	t.eq(r1["coins"], Economy.daily_reward(1), "daily reward")
	t.eq(Profile.complete_daily("2026-03-01", s)["coins"], 0, "the same daily never pays twice")
	t.eq(Profile.complete_daily("2026-03-02", s)["streak"], 2, "next day extends the streak")
	t.eq(Profile.complete_daily("2026-03-04", s)["streak"], 1, "a missed day restarts the streak")
	t.eq(Profile.stat("best_streak"), 2, "best streak kept")


func _achievements_pay_once() -> void:
	var before: int = Profile.coins()
	var got: Array[Dictionary] = Profile.check_achievements()
	var ids: Array = got.map(func(a: Dictionary) -> String: return a["id"])
	t.ok(ids.has("first_escape"), "First Escape unlocked")
	t.ok(ids.has("chapter_reflect"), "the chapter achievement unlocked")
	t.ok(ids.has("stars_50"), "the star achievement unlocked")
	t.ok(not ids.has("chapter_horizon"), "other chapters not yet")
	var paid: int = 0
	for a: Dictionary in got:
		paid += int(a["reward"])
	t.eq(Profile.coins(), before + paid, "achievement rewards paid")
	t.eq(Profile.check_achievements().size(), 0, "achievements unlock only once")
	t.eq(Achievements.all().size(), Achievements.BASE.size() + 9, "one achievement per chapter")


func _video_rewards() -> void:
	var before: int = Profile.coins()
	for i: int in Economy.VIDEO_COINS_PER_DAY:
		t.ok(Profile.claim_video_coins(), "video coins %d" % (i + 1))
	t.ok(not Profile.claim_video_coins(), "video coins are limited per day")
	t.eq(Profile.coins(), before + Economy.VIDEO_COINS * Economy.VIDEO_COINS_PER_DAY, "exact video coins")
	var keys: int = Profile.keys()
	for i: int in Economy.VIDEO_KEYS_PER_DAY:
		Profile.add_video_key()
	t.ok(not Profile.add_video_key(), "video keys are limited per day")
	t.eq(Profile.keys(), keys + Economy.VIDEO_KEYS_PER_DAY, "exact video keys")


func _store_purchases() -> void:
	t.ok(Store.available(), "the simulated store is available in tests")
	t.ok(not Profile.is_supporter(), "not a supporter yet")
	Store.buy("supporter_pack")
	t.ok(Profile.is_supporter(), "Supporter pack bought")
	Save.data["hints"]["day"] = ""
	t.eq(Profile.free_hints_left(), Economy.SUPPORTER_FREE_HINTS, "supporters get more free hints")
	var coins: int = Profile.coins()
	var keys: int = Profile.keys()
	Store.buy("complete_pack")
	t.eq(Profile.coins(), coins + Store.COMPLETE_COINS, "the Complete pack adds its coins")
	t.eq(Profile.keys(), keys + Store.COMPLETE_KEYS, "and its keys")
	t.ok(Profile.bought("theme_pack") and Profile.bought("style_pack"), "and every pack")
	Store.buy("complete_pack")
	t.eq(Profile.coins(), coins + Store.COMPLETE_COINS, "buying it again adds nothing")
	Store.buy("coins_1000")
	t.eq(Profile.coins(), coins + Store.COMPLETE_COINS + 1000, "a coin bag adds its coins")
	Store.buy("keys_5")
	t.eq(Profile.keys(), keys + Store.COMPLETE_KEYS + 5, "keys bought")
	Store.buy("tip_50")
	t.eq(Profile.tips_given(), 1, "a tip is counted")
	t.eq(Store.all_ids().size(), 4 + 10 + 5 + 10 + 190, "product catalogue size")
	var amounts: Array = Store.tip_amounts()
	t.eq(amounts.size(), 190, "190 tip amounts")
	t.eq(int(amounts[0]), 10, "the smallest tip is ₹10")
	t.eq(int(amounts[-1]), 10000, "the largest tip is ₹10,000")
	t.ok(amounts.has(1000) and amounts.has(1100) and not amounts.has(1010) and not amounts.has(1050), "steps of 10 up to ₹1,000, then 100")
	t.eq(Store.tip_ids().size(), 190, "every tip has an id")
	var all: Array = Store.all_ids()
	var tips_queried: bool = true
	for id: String in Store.tip_ids():
		tips_queried = tips_queried and all.has(id) and Store.prices.has(id)
	t.ok(tips_queried, "every tip id is queried from Play and has a fallback price")
	t.eq(Store.snap_tip(347), 350, "snap rounds to the nearest 10 below ₹1,000")
	t.eq(Store.snap_tip(1349), 1300, "and to the nearest 100 above")
	t.eq(Store.snap_tip(5), 10, "snap keeps the minimum")
	t.eq(Store.snap_tip(99999), 10000, "snap keeps the maximum")
	t.eq(Store.nudge_tip(1000, 1), 1100, "+ from ₹1,000 goes to ₹1,100")
	t.eq(Store.nudge_tip(1100, -1), 1000, "− from ₹1,100 goes back to ₹1,000")
	t.eq(Store.nudge_tip(1000, -1), 990, "− from ₹1,000 goes to ₹990")
	t.ok(Store.chapter_key_ids().size() == Store.CHAPTER_KEY_MAX and Store.CHAPTER_KEY_MAX == 5, "chapter keys are sold 1 to 5 at a time")
	var coin_ids: Array = Store.COIN_PACKS.keys()
	for k: int in range(1, coin_ids.size()):
		t.ok(int(Store.COIN_PACKS[coin_ids[k]][0]) > int(Store.COIN_PACKS[coin_ids[k - 1]][0]), "coin bags are listed smallest first")
		t.ok(float(Store.COIN_PACKS[coin_ids[k]][0]) / float(Store.COIN_PACKS[coin_ids[k]][2]) >= float(Store.COIN_PACKS[coin_ids[k - 1]][0]) / float(Store.COIN_PACKS[coin_ids[k - 1]][2]), "bigger bags give at least as many coins per rupee")
	t.ok(Store.complete_saving() > 0, "the Complete pack is cheaper than its parts")
	Store.simulate = false
	var msg: Array[String] = [""]
	var cb: Callable = func(_ok: bool, m: String, _id: String) -> void: msg[0] = m
	Store.purchase_finished.connect(cb)
	Store.buy("coins_300")
	t.ok(msg[0].contains("Android"), "outside Android, purchases explain where they work")
	Store.purchase_finished.disconnect(cb)
	Store.simulate = true


func _trials_and_looks() -> void:
	# Undo the Complete pack to test trials on their own.
	Save.data["owned"] = {}
	Profile.set_setting("theme", "ocean")
	t.eq(Look.theme_id(), "chapters", "a locked theme falls back to chapter colours")
	Profile.start_trial("theme_pack")
	t.ok(Profile.owns("theme_pack") and not Profile.bought("theme_pack"), "a video trial grants the pack, not a purchase")
	t.eq(Look.theme_id(), "ocean", "the trial theme applies")
	t.ok(Profile.trial_clock("theme_pack").begins_with("59:") or Profile.trial_clock("theme_pack").begins_with("60:"), "an hour on the clock")
	Save.data["trials"]["theme_pack"] = 1
	t.eq(Look.theme_id(), "chapters", "when the trial ends the theme reverts")
	Profile.set_setting("style", "prism")
	t.eq(Look.style_id(), "neon", "a locked style falls back to Neon")
	t.ok(Look.pair_color(0, "neon") != Look.pair_color(1, "neon"), "neighbouring pairs get different colours")


func _reset_keeps_purchases() -> void:
	Store.buy("supporter_pack")
	Save.data["coins_bought"] = 2000
	var keys: int = Profile.keys()
	var chapter_keys: int = Profile.chapter_keys()
	Profile.reset_all()
	t.ok(Profile.is_supporter(), "a reset keeps packs")
	t.eq(Profile.chapter_keys(), chapter_keys, "a reset keeps chapter keys")
	t.eq(Profile.keys(), keys, "a reset keeps keys")
	t.eq(Profile.coins(), Economy.START_COINS + 2000, "a reset keeps bought coins, not earned ones")
	t.eq(Profile.stat("levels"), 0, "a reset clears progress")
	t.ok(not Profile.achievement_done("first_escape"), "a reset clears achievements")


func _restart_keeps_progress() -> void:
	Profile.complete_level("reflect-01", _state("reflect-01", 1))
	var s: PlayState = PlayState.new(Catalog.level_by_id("reflect-02"))
	s.tap(MirrorSolver.solve(s.rules)[0])
	Profile.store_progress("reflect-02", s)
	Profile.set_setting("music_volume", 0.25)
	var coins: int = Profile.coins()
	Save.flush()
	Save.data = {}
	Save.load_data()
	t.eq(Profile.coins(), coins, "coins survive a restart")
	t.eq(Profile.stars_for("reflect-01"), 2, "stars survive a restart")
	t.eq(float(Profile.setting("music_volume")), 0.25, "volume survives a restart")
	t.ok(Profile.is_supporter(), "purchases survive a restart")
	var s2: PlayState = PlayState.new(Catalog.level_by_id("reflect-02"))
	s2.restore(Profile.saved_progress("reflect-02"))
	t.eq(s2.moves, 1, "a half-played level resumes")
	t.eq(s2.present, s.present, "with the same pieces left")


func _corrupt_save_recovers() -> void:
	var coins: int = Profile.coins()
	Save.flush()
	Save.flush()
	var f: FileAccess = FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	Save.load_data()
	t.eq(Save.recovered_from, "backup", "a corrupt save falls back to the backup")
	t.eq(Profile.coins(), coins, "no coins lost to corruption")
	f = FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	f.store_string("[1, 2, 3]")
	f.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE + ".bak"))
	Save.load_data()
	t.eq(Save.recovered_from, "fresh", "an unreadable save without backup starts fresh")
	t.eq(Profile.coins(), Economy.START_COINS, "fresh save has starting coins")


## Every character the UI can show (including every fallback price) must be in
## Outfit or one of its bundled fallbacks, or the web build shows boxes.
func _glyphs() -> void:
	var base: FontFile = (UIKit.font(600) as FontVariation).base_font as FontFile
	var fonts: Array[Font] = [base]
	fonts.append_array(base.fallbacks)
	var text: String = "★☆♥✓…→–—×·%"
	for region: Variant in Store.REGIONAL_TIERS:
		for price: Variant in Store.REGIONAL_TIERS[region]:
			text += str(price)
	for region: Variant in Store.KEY_UNIT:
		text += str(Store.KEY_UNIT[region][0])
	for i: int in text.length():
		var code: int = text.unicode_at(i)
		var ok: bool = false
		for f: Font in fonts:
			if f.has_char(code):
				ok = true
				break
		t.ok(ok, "the fonts can draw '%s' (U+%04X)" % [text[i], code])


## Streak achievements need that many days in a row; a missed day starts over.
func _streak_achievements() -> void:
	Save.data = Save.defaults()
	var t0: int = Time.get_unix_time_from_datetime_dict({"year": 2026, "month": 1, "day": 1, "hour": 12})
	var s: PlayState = PlayState.new(Catalog.level_by_id("reflect-01"))
	for d: int in 9:
		Profile.complete_daily(Time.get_date_string_from_unix_time(t0 + d * 86400), s)
	# Day 10 is missed; then 5 more days.
	for d: int in range(10, 15):
		Profile.complete_daily(Time.get_date_string_from_unix_time(t0 + d * 86400), s)
	Profile.check_achievements()
	t.ok(Profile.achievement_done("streak_7"), "7 days in a row earns A Week of Mirrors")
	t.ok(not Profile.achievement_done("streak_14"), "9 days, a miss, then 5 more is not 14 in a row")
	for d: int in range(15, 24):
		Profile.complete_daily(Time.get_date_string_from_unix_time(t0 + d * 86400), s)
	Profile.check_achievements()
	t.ok(Profile.achievement_done("streak_14"), "14 days in a row after the miss earns Two Weeks Twinned")
	t.ok(not Profile.achievement_done("streak_30"), "a month needs 30 days in a row")
	for id: String in ["streak_3", "streak_7", "streak_14", "streak_30"]:
		t.ok(not Achievements.by_id(id).is_empty(), "%s exists" % id)
