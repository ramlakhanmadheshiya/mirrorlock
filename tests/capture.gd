extends Node
## Screenshots of every screen and card at a given window size, for visual
## review. Runs the real app with a throwaway save and the mock ad banner.
## Needs a display (not --headless):
##
##   godot --path . res://tests/capture.tscn -- <out_dir> [width] [height] [clean|store]
##
## "clean" hides the test ad banner (website pictures). "store" renders the
## Google Play phone screenshots at 1080 x 1920 into <out_dir>.

const SAVE: String = "user://capture_save.json"

var out_dir: String = "/tmp/mirrorlock_shots"
var app: App
var mode: String = ""
var _n: int = 0
var _vp: SubViewport


func _ready() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() >= 1:
		out_dir = a[0]
	var win: Vector2i = Vector2i(450, 800)
	if a.size() >= 3:
		win = Vector2i(int(a[1]), int(a[2]))
	if a.size() >= 4:
		mode = a[3]
	DisplayServer.window_set_size(win)
	DirAccess.make_dir_recursive_absolute(out_dir)
	for s: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + s))
	Save.path = SAVE
	Save.load_data()
	Profile.set_setting("music_volume", 0.0)
	Profile.set_setting("sound_volume", 0.0)
	Store.simulate = true
	Profile.set_setting("appearance", "dark")
	App.skip_splash = true
	if mode == "clean" or mode == "store":
		AdManager.use_provider(null)
	_seed_progress()
	app = (load("res://game/scenes/main.tscn") as PackedScene).instantiate()
	if mode == "store":
		# A full 1080 x 1920 phone screen, whatever the monitor.
		_vp = SubViewport.new()
		_vp.size = Vector2i(1080, 1920)
		_vp.size_2d_override = Vector2i(720, 1280)
		_vp.size_2d_override_stretch = true
		_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_vp)
		_vp.add_child(app)
		await _store()
	else:
		add_child(app)
		await _all()
	for s: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + s))
	print("CAPTURE: %d screenshots in %s" % [_n, out_dir])
	get_tree().quit()


func _all() -> void:
	await _wait(1.4)
	await _shot("home")
	await _splash_frames()
	app.go("chapters")
	await _wait(0.9)
	await _shot("chapters")
	app.go("levels", {"chapter": 4})
	await _wait(0.9)
	await _shot("levels")
	app.open(_locked(4, 30))
	await _wait(0.6)
	await _shot("locked")
	app.close_overlays()
	# A mid-chapter level, part way, with a piece pressed (its twin lights up).
	await _open_level(4, 22)
	var play: Node = app.screen
	var sol: Array[int] = MirrorSolver.solve(play.state.rules)
	play.board.tapped.emit(sol[0])
	await _wait(0.7)
	var pick: int = sol[1]
	play.board._pressed = play.state.rules.group(pick, play.state.present, play.state.moves)
	await _wait(0.35)
	await _shot("play")
	play.board._pressed = 0
	# A bump: the obstacle flashes and the board shakes.
	var b: int = _blocked(play.state)
	if b >= 0:
		play.board.tapped.emit(b)
		await _wait(0.14)
		await _shot("bump")
	await _wait(0.6)
	play.use_hint()
	await _wait(0.5)
	await _shot("hint")
	play.board.clear_hint()
	for i: int in MirrorSolver.solve_from(play.state.rules, play.state.present, play.state.moves):
		play.board.tapped.emit(i)
		await _wait(0.12)
	await _wait(0.9)
	await _shot("celebrate")
	await _wait(1.4)
	await _shot("result")
	var result: ResultCard = app.top_overlay() as ResultCard
	result.open_child(result.share_card())
	await _wait(2.0)
	await _shot("share")
	app.close_overlays()
	# Out of hearts.
	await _open_level(1, 12)
	var p2: Node = app.screen
	for k: int in 3:
		var bb: int = _blocked(p2.state)
		if bb >= 0:
			p2.board.tapped.emit(bb)
			await _wait(0.25)
	await _wait(1.3)
	await _shot("out_of_hearts")
	app.close_overlays()
	# Every chapter's idea on a real level.
	for spec: Array in [[0, 18], [1, 20], [2, 16], [3, 18], [4, 24], [5, 14], [6, 20], [7, 16], [8, 24]]:
		await _open_level(spec[0], spec[1])
		var lp: Node = app.screen
		var s2: Array[int] = MirrorSolver.solve(lp.state.rules)
		if s2.size() > 3:
			lp.board.tapped.emit(s2[0])
			await _wait(0.8)
		await _shot("chapter_%s" % Catalog.chapter(spec[0])["id"])
	# A chapter card the first time its level 1 opens.
	Save.data["seen"].erase("chapter_kaleido")
	app.go("play", {"chapter": 6, "level": 1})
	await _wait(1.6)
	await _shot("chapter_card")
	app.close_overlays()
	# The first-play tutorial.
	Save.data["seen"].erase("tutorial")
	Save.data["progress"].erase("reflect-01")
	app.go("play", {"chapter": 0, "level": 1})
	await _wait(1.5)
	await _shot("tutorial")
	Profile.mark_seen("tutorial")
	app.go("play", {"daily": Catalog.today_key()})
	await _wait(1.2)
	await _shot("daily")
	# Out of free hints and coins in a level.
	Save.data["hints"] = {"day": Catalog.today_key(), "used": 9}
	Save.data["coins"] = 10
	app.screen.use_hint()
	await _wait(0.7)
	await _shot("out_of_coins")
	app.close_overlays()
	Save.data["coins"] = 1240
	app.go("shop")
	await _wait(1.0)
	await _shot("shop")
	var scroll: TouchScroll = app.screen.find_child("Scroll", true, false)
	scroll.scroll_to(900)
	await _wait(0.4)
	await _shot("shop_more")
	for o: Overlay in [_product("complete_pack"), _product("style_pack"), ChapterKeyCard.new(), CoinsCard.new(), KeysCard.new(), TipCard.new(), _picker("themes"), _picker("styles"), SettingsCard.new(), AchievementsCard.new(), AboutCard.new(), CreditsCard.new()]:
		app.open(o)
		await _wait(0.8)
		await _shot(o.name.to_lower() + ("_" + str(o.get("mode")) if o is PickerCard else ("_" + str(o.get("product")) if o is ProductCard else "")))
		o.close()
		await _wait(0.35)
	for page: String in ["basics", "bumps", "turn"]:
		var how: HowToCard = HowToCard.new()
		how.pages = [page]
		app.open(how)
		await _wait(1.0)
		await _shot("howto_" + page)
		how.close()
		await _wait(0.3)
	# A bought theme and mirror style.
	Save.data["owned"]["theme_pack"] = true
	Save.data["owned"]["style_pack"] = true
	Profile.set_setting("theme", "sunset")
	Profile.set_setting("style", "prism")
	await _open_level(2, 25)
	await _shot("play_themed")
	app.go("home")
	await _wait(1.0)
	await _shot("home_themed")
	Profile.set_setting("theme", "paper")
	Profile.set_setting("style", "candy")
	app.go("home")
	await _wait(1.0)
	await _shot("home_paper")
	await _open_level(6, 18)
	await _shot("play_paper")
	Profile.set_setting("theme", "chapters")
	Profile.set_setting("style", "neon")
	Profile.set_setting("appearance", "light")
	app.go("home")
	await _wait(1.0)
	await _shot("home_light")
	await _open_level(4, 22)
	await _shot("play_light")


## Google Play phone screenshots, in listing order.
func _store() -> void:
	Save.data["owned"]["supporter_pack"] = true
	await _wait(1.4)
	await _shot("01_home", true)
	for spec: Array in [[0, 24, "02_reflect"], [6, 20, "03_kaleido"], [5, 16, "04_vault"], [7, 18, "05_turn"]]:
		await _open_level(spec[0], spec[1])
		var lp: Node = app.screen
		var s2: Array[int] = MirrorSolver.solve(lp.state.rules)
		lp.board.tapped.emit(s2[0])
		await _wait(0.33)
		await _shot(spec[2], true)
		await _wait(0.6)
	await _open_level(4, 12)
	var p: Node = app.screen
	for i: int in MirrorSolver.solve(p.state.rules):
		p.board.tapped.emit(i)
		await _wait(0.1)
	await _wait(2.6)
	await _shot("06_result", true)
	app.go("chapters")
	await _wait(1.2)
	await _shot("07_chapters", true)
	app.go("levels", {"chapter": 1})
	await _wait(1.2)
	await _shot("08_levels", true)


func _splash_frames() -> void:
	for t: float in [0.7, 1.15, 2.1]:
		var s: Splash = Splash.new()
		s.manual = true
		s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		app.add_child(s)
		s.show_at(t)
		await _wait(0.15)
		await _shot("splash_%d" % int(t * 100))
		s.queue_free()


func _open_level(ci: int, n: int) -> void:
	app.go("play", {"chapter": ci, "level": n})
	await _wait(1.1)
	var o: Overlay = app.top_overlay()
	if o != null:
		o.close()
		await _wait(0.3)


func _blocked(s: PlayState) -> int:
	for i: int in s.rules.count:
		if s.is_present(i) and not s.rules.can_tap(i, s.present, s.moves):
			return i
	return -1


func _locked(ci: int, n: int) -> LockedCard:
	var o: LockedCard = LockedCard.new()
	o.chapter_idx = ci
	o.level = n
	return o


func _product(id: String) -> ProductCard:
	var o: ProductCard = ProductCard.new()
	o.product = id
	return o


func _picker(m: String) -> PickerCard:
	var o: PickerCard = PickerCard.new()
	o.mode = m
	return o


## A believable mid-game save: four chapters done with mixed stars, the fifth
## half way, some keys and coins.
func _seed_progress() -> void:
	for ci: int in 9:
		var id: String = Catalog.chapter(ci)["id"]
		var upto: int = 40 if ci < 4 else (21 if ci == 4 else 15)
		if ci > 5:
			upto = 0
		for n: int in range(1, upto + 1):
			Save.data["cleared"][Catalog.level_id(id, n)] = {"stars": 3 if n % 4 != 0 else (2 if n % 3 != 0 else 1)}
	Save.data["chapters_opened"] = {"kaleido": true, "turn": true, "finale": true}
	Save.data["coins"] = 1240
	Save.data["keys"] = 3
	Save.data["chapter_keys"] = 1
	Save.data["stats"]["levels"] = 196
	Save.data["stats"]["stars"] = Profile.total_stars()
	Save.data["stats"]["twins"] = 1320
	Save.data["daily"]["streak"] = 3
	Save.data["daily"]["last_date"] = Catalog.date_key_from_day(Catalog.day_number(Catalog.today_key()) - 1)
	var seen: Dictionary = {"tutorial": true}
	for ci: int in 9:
		seen["chapter_" + str(Catalog.chapter(ci)["id"])] = true
	Save.data["seen"] = seen
	Save.data["last_level"] = "slant-22"
	Profile.check_achievements()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(name: String, numbered: bool = false) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = (_vp if _vp != null else get_viewport()).get_texture().get_image()
	_n += 1
	if numbered:
		img.save_png("%s/%s.png" % [out_dir, name])
	else:
		img.save_png("%s/%02d_%s.png" % [out_dir, _n, name])
