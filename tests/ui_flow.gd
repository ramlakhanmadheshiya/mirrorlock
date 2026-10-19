extends Node
## End-to-end flow through the real app with a throwaway save, the simulated
## store and the mock ad provider: home, chapters, levels, the first-play
## tutorial, a level with a bump (2★), Again for 3★, Next, a locked level and a
## key, hints (free, paid, by video), Undo, running out of hearts, Restart, the
## shop, settings, the daily, chapter cards, sharing, the banner's reserved
## space, and an app restart.
##
##   godot --headless --path . res://tests/ui_flow.tscn

const SAVE: String = "user://ui_flow_save.json"
const MockProvider: GDScript = preload("res://game/ads/providers/mock_ad_provider.gd")

var t: Check = Check.new("UI FLOW")
var app: App
var mock: Node


func _ready() -> void:
	_wipe()
	App.skip_splash = true
	Save.path = SAVE
	Save.load_data()
	Profile.set_setting("music_volume", 0.0)
	Profile.set_setting("sound_volume", 0.0)
	Store.simulate = true
	mock = MockProvider.new()
	mock.auto_finish = true
	AdManager.use_provider(mock)
	await _boot()
	await _banner_space()
	await _menus()
	await _first_level()
	await _locked_and_keys()
	await _hints_and_ads()
	await _undo()
	await _out_of_hearts()
	await _restart_button()
	await _banner_refresh()
	await _shop()
	await _settings()
	await _daily()
	await _restart_app()
	await _chapter_key_unlock()
	await _chapter_intro()
	await _extras()
	await _reset_progress()
	_wipe()
	get_tree().quit(t.report())


func _wipe() -> void:
	for s: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + s))


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _boot() -> void:
	app = (load("res://game/scenes/main.tscn") as PackedScene).instantiate()
	add_child(app)
	await _wait(1.0)
	t.eq(app.screen_name, "home", "boots to the home screen")


func _find(root: Node, n: String) -> Node:
	return root.find_child(n, true, false) if root != null else null


func _press(root: Node, n: String) -> bool:
	var b: BaseButton = _find(root, n) as BaseButton
	if b == null:
		t.ok(false, "button %s exists" % n)
		return false
	b.pressed.emit()
	return true


func _play() -> Node:
	return app.screen


func _tap(play: Node, i: int) -> void:
	play.board.tapped.emit(i)


func _solve(play: Node) -> void:
	for i: int in MirrorSolver.solve_from(play.state.rules, play.state.present, play.state.moves):
		_tap(play, i)
		await _wait(0.05)


## A piece whose tap would bump right now (-1 if every piece is free).
func _blocked_piece(s: PlayState) -> int:
	for i: int in s.rules.count:
		if s.is_present(i) and not s.rules.can_tap(i, s.present, s.moves):
			return i
	return -1


func _banner_space() -> void:
	t.ok(AdManager.banner_height > 0.0, "the banner is showing")
	var frame: MarginContainer = app.screen.get_child(0) as MarginContainer
	t.ok(frame.get_theme_constant("margin_bottom") >= int(AdManager.banner_height), "screens keep room for the banner")
	for n: String in ["Play", "Shop", "SettingsButton", "Chapters", "Awards", "Daily", "Keys", "Coins", "DemoCard", "Title"]:
		t.ok(_find(app.screen, n) != null, "home has %s" % n)
	var where: Label = _find(app.screen, "NextLevel") as Label
	t.eq(where.text, "Reflect · Level 1", "home shows only the chapter and level")


func _menus() -> void:
	_press(app.screen, "Chapters")
	await _wait(0.6)
	t.eq(app.screen_name, "chapters", "Chapters opens")
	var list: Node = _find(app.screen, "List")
	var cards: int = 0
	for c: Node in list.get_children():
		if c is ChapterCard:
			cards += 1
	t.eq(cards, 9, "9 chapter cards")
	_press(list, "Chapter_horizon")
	await _wait(0.6)
	t.eq(app.screen_name, "chapters", "a locked chapter does not open")
	t.ok(app.top_overlay() is LockedChapterCard, "a locked chapter explains how it opens")
	app.top_overlay().close()
	await _wait(0.3)
	_press(list, "Chapter_reflect")
	await _wait(0.6)
	t.eq(app.screen_name, "levels", "an open chapter shows its levels")
	var grid: Node = _find(app.screen, "Grid")
	t.eq(grid.get_child_count(), 40, "all 40 levels are shown, locked ones too")
	var locked: int = 0
	for tile: LevelTile in grid.get_children():
		if not tile.open:
			locked += 1
	t.eq(locked, 39, "39 locked levels are visible")
	t.ok((_find(app.screen, "Legend") as Label).text.contains("39 locked"), "the hero card counts locked levels")
	app.handle_back()
	await _wait(0.6)
	t.eq(app.screen_name, "chapters", "Back returns to chapters")
	app.handle_back()
	await _wait(0.6)
	t.eq(app.screen_name, "home", "Back returns home")


func _first_level() -> void:
	var coins0: int = Profile.coins()
	_press(app.screen, "Play")
	await _wait(1.0)
	t.eq(app.screen_name, "play", "Play opens the first level")
	var play: Node = _play()
	t.eq(play.level.id, "reflect-01", "it is Reflect 1")
	t.ok(play._tutorial, "the first level runs the hands-on tutorial")
	t.ok(play.board._ghost_piece >= 0, "a ghost finger points at a piece")
	t.ok(play.state.rules.can_tap(play.board._ghost_piece, play.state.present, 0), "the finger points at a safe piece")
	t.ok(play._msg.text.contains("twin"), "the tutorial explains twins")
	for n: String in ["LevelsButton", "Hint", "Undo", "Restart", "SettingsButton", "Back", "Hud"]:
		t.ok(_find(play, n) != null, "the game screen has %s" % n)
	var b: int = _blocked_piece(play.state)
	t.ok(b >= 0, "the first level has a blocked pair")
	_tap(play, b)
	await _wait(0.2)
	t.eq(play.state.hearts_left(), 2, "a bump costs a heart")
	t.eq(play.state.stars(), 2, "a bump costs a star")
	t.ok(play._msg.text.contains("Blocked"), "the tutorial explains the bump")
	t.eq(Profile.coins(), coins0, "a bump costs no coins")
	t.ok(play._hud.hearts == 2, "the HUD shows two hearts")
	await _solve(play)
	await _wait(2.4)
	var card: Overlay = app.top_overlay()
	t.ok(card is ResultCard, "the result card appears")
	t.eq((_find(card, "ResultTitle") as Label).text, "Nicely done", "2-star title")
	t.eq(Profile.stars_for("reflect-01"), 2, "2 stars recorded")
	t.ok(Profile.seen("tutorial"), "the tutorial is marked done")
	t.ok(Profile.coins() >= coins0 + Economy.LEVEL_REWARD + 2 * Economy.STAR_REWARD, "clear reward paid")
	_press(card, "Again")
	await _wait(0.8)
	play = _play()
	t.eq(play.state.stars(), 3, "Again starts fresh with 3 stars on offer")
	t.ok(not play._tutorial, "the tutorial runs only once")
	await _solve(play)
	await _wait(2.4)
	t.eq(Profile.stars_for("reflect-01"), 3, "a clean replay records 3 stars")
	t.eq((_find(app.top_overlay(), "ResultTitle") as Label).text, "Flawless!", "3-star title")
	_press(app.top_overlay(), "Next")
	await _wait(0.9)
	t.eq(_play().level.id, "reflect-02", "Next opens level 2")


func _locked_and_keys() -> void:
	app.go("levels", {"chapter": 0})
	await _wait(0.7)
	_press(_find(app.screen, "Grid"), "Level9")
	await _wait(0.5)
	var card: Overlay = app.top_overlay()
	t.ok(card is LockedCard, "a locked level explains how it opens")
	t.ok((_find(card, "UseKey") as Button).disabled, "no keys: Use a key is disabled")
	card.close()
	await _wait(0.4)
	Profile.add_keys(1)
	_press(_find(app.screen, "Grid"), "Level9")
	await _wait(0.5)
	_press(app.top_overlay(), "UseKey")
	await _wait(0.9)
	t.eq(app.screen_name, "play", "a key opens the level and plays it")
	t.eq(_play().level.id, "reflect-09", "it is level 9")
	t.eq(Profile.keys(), 0, "the key is spent")


func _hints_and_ads() -> void:
	var play: Node = _play()
	Save.data["hints"]["day"] = ""
	play._refresh()
	t.ok(play._hint_badge.text.begins_with("FREE"), "the hint badge shows free hints")
	var coins0: int = Profile.coins()
	_press(play, "Hint")
	await _wait(0.1)
	t.eq(Profile.coins(), coins0, "free hints cost nothing")
	t.ok(play.board._hint != 0, "the hint lights up a group")
	t.eq(play.state.stars(), 2, "a hint caps the stars at two")
	var lit: int = MirrorRules.bits(play.board._hint)[0]
	t.ok(play.state.rules.can_tap(lit, play.state.present, play.state.moves), "the lit group is safe")
	for k: int in Economy.FREE_HINTS - 1:
		_press(play, "Hint")
	await _wait(0.1)
	t.eq(Profile.free_hints_left(), 0, "the free hints are used up")
	_press(play, "Hint")
	await _wait(0.1)
	t.eq(Profile.coins(), coins0 - Economy.HINT_COST, "the next hint costs coins")
	# Out of coins: the game offers a video for the hint.
	Save.data["coins"] = 5
	var hints: int = play.state.hints_used
	_press(play, "Hint")
	await _wait(0.5)
	var card: Overlay = app.top_overlay()
	t.ok(card is MessageCard and card.name == "OutOfCoins", "out of coins: a video is offered")
	t.eq(play.state.hints_used, hints, "no hint before the video")
	_press(card, "Watchavideo")
	await _wait(0.5)
	t.eq(play.state.hints_used, hints + 1, "after the video, the hint is given")
	t.eq(Profile.coins(), 5, "and no coins are taken")
	mock.earn = false
	_press(play, "Hint")
	await _wait(0.4)
	_press(app.top_overlay(), "Watchavideo")
	await _wait(0.5)
	t.eq(play.state.hints_used, hints + 1, "a skipped video gives no hint")
	mock.earn = true
	Save.data["coins"] = 500


func _undo() -> void:
	app.go("play", {"chapter": 0, "level": 3})
	await _wait(0.8)
	var play: Node = _play()
	t.ok((_find(play, "Undo") as Button).disabled, "nothing to undo at the start")
	var before: int = play.state.present
	var first: int = MirrorSolver.solve(play.state.rules)[0]
	_tap(play, first)
	await _wait(0.4)
	t.ok(play.state.present != before, "a move takes pieces off")
	t.ok(not (_find(play, "Undo") as Button).disabled, "Undo is available after a move")
	_press(play, "Undo")
	await _wait(0.5)
	t.eq(play.state.present, before, "Undo brings the pieces back")
	t.eq(play.state.moves, 0, "and the move count")


func _out_of_hearts() -> void:
	var play: Node = _play()
	Save.data["coins"] = 500
	for k: int in 3:
		var b: int = _blocked_piece(play.state)
		_tap(play, b)
		await _wait(0.15)
	t.ok(play.state.is_failed(), "three bumps: out of hearts")
	await _wait(1.1)
	var card: Overlay = app.top_overlay()
	t.ok(card is MessageCard and card.name == "OutOfHearts", "the out-of-hearts card appears")
	var coins: int = Profile.coins()
	_press(card, "+1heartfor%dcoins" % Economy.HEART_COST)
	await _wait(0.4)
	t.eq(Profile.coins(), coins - Economy.HEART_COST, "a heart costs coins")
	t.eq(play.state.hearts_left(), 1, "one heart to carry on")
	t.ok(play.board.input_enabled, "the board takes taps again")
	_tap(play, _blocked_piece(play.state))
	await _wait(1.1)
	card = app.top_overlay()
	t.ok(card is MessageCard and card.name == "OutOfHearts", "out of hearts again")
	_press(card, "Tryagain")
	await _wait(0.9)
	t.eq(_play().state.hearts_left(), 3, "Try again brings back three hearts")
	t.eq(_play().state.moves, 0, "and every piece")


func _restart_button() -> void:
	var play: Node = _play()
	_tap(play, MirrorSolver.solve(play.state.rules)[0])
	await _wait(0.3)
	_press(play, "Restart")
	await _wait(0.4)
	t.ok(app.top_overlay() is MessageCard, "Restart asks first")
	_press(app.top_overlay(), "Restart")
	await _wait(0.9)
	t.eq(_play().state.moves, 0, "Restart brings every piece back")
	t.eq(_play().state.stars(), 3, "Restart puts 3 stars back on offer")
	t.ok(Profile.saved_progress("reflect-03").is_empty(), "Restart clears saved progress")


## A fresh banner ad when moving between screens (at most every 30 seconds),
## and no full-screen ads between levels.
func _banner_refresh() -> void:
	AdManager._last_banner_load_msec = -1000000
	var reloads: int = mock.reloads
	app.go("home")
	await _wait(0.7)
	t.eq(mock.reloads, reloads + 1, "moving to another screen loads a fresh banner ad")
	app.go("chapters")
	await _wait(0.7)
	t.eq(mock.reloads, reloads + 1, "but not again within 30 seconds")
	var frame: MarginContainer = app.screen.get_child(0) as MarginContainer
	t.ok(frame.get_theme_constant("margin_bottom") >= int(AdManager.banner_height), "the banner space stays reserved")
	t.ok(not AdManager.has_method("after_level"), "no videos between levels")


func _shop() -> void:
	app.go("shop")
	await _wait(0.7)
	t.eq(app.screen_name, "shop", "the shop opens")
	for id: String in Store.PRODUCTS:
		t.ok(_find(app.screen, "Product_" + id) != null, "the shop lists %s" % id)
	_press(app.screen, "Product_coins")
	await _wait(0.5)
	var coin_card: Overlay = app.top_overlay()
	t.ok(coin_card is CoinsCard, "the Coins row opens its card")
	var coins: int = Profile.coins()
	_press(coin_card, "Buy_coins_300")
	await _wait(0.2)
	t.eq(Profile.coins(), coins + 300, "buying a coin bag adds coins")
	_press(coin_card, "FreeCoins")
	await _wait(0.3)
	t.eq(Profile.coins(), coins + 300 + Economy.VIDEO_COINS, "a free-coins video pays")
	coin_card.close()
	await _wait(0.3)
	_press(app.screen, "Product_style_pack")
	await _wait(0.5)
	var card: Overlay = app.top_overlay()
	t.ok(card is ProductCard, "a pack opens its card")
	_press(card, "Trial")
	await _wait(0.6)
	t.ok(Profile.owns("style_pack") and not Profile.bought("style_pack"), "the video starts a trial")
	t.ok(app.top_overlay() is PickerCard, "and opens the style picker")
	_press(app.top_overlay(), "Pick_prism")
	await _wait(1.0)
	t.eq(Look.style_id(), "prism", "a mirror style can be picked during the trial")
	t.eq(Look.pair_color(0), Color(Look.STYLES["prism"]["colors"][0]), "the twins take the style's colours")
	app.close_overlays()
	await _wait(0.2)
	Save.data["owned"]["theme_pack"] = true
	Profile.set_setting("theme", "ocean")
	app.repaint_and_reopen("themes")
	await _wait(1.0)
	t.eq(Style.DEFAULT_SKY_TOP, Color(Look.THEMES["ocean"]["top"]), "a theme recolours the sky")
	var restyled: Button = _find(app.screen, "SettingsButton") as Button
	t.eq((restyled.get_theme_stylebox("normal") as StyleBoxFlat).bg_color, Style.SURFACE, "the screen was rebuilt in the new colours")
	app.close_overlays()
	Profile.set_setting("theme", "paper")
	app.repaint_and_reopen("themes")
	await _wait(1.0)
	t.ok(not Style.DARK and Style.INK.get_luminance() < 0.4, "a light theme switches to dark text")
	t.ok(Style.BOARD.get_luminance() < 0.3, "but the board stays dark glass")
	app.close_overlays()
	Profile.set_setting("theme", "chapters")
	Profile.set_setting("style", "neon")
	Save.data["owned"].erase("theme_pack")
	app.reload_screen()
	await _wait(0.8)
	_press(app.screen, "Product_supporter_pack")
	await _wait(0.4)
	_press(app.top_overlay(), "Buy")
	await _wait(0.3)
	t.ok(Profile.is_supporter(), "the Supporter pack can be bought")
	t.eq(AdManager.banner_height, 0.0, "supporters see no banner")
	app.top_overlay().close()
	await _wait(0.3)


func _settings() -> void:
	app.go("home")
	await _wait(0.6)
	_press(app.screen, "SettingsButton")
	await _wait(0.5)
	var card: Overlay = app.top_overlay()
	t.ok(card is SettingsCard, "settings opens")
	var music: HSlider = _find(card, "MusicSlider") as HSlider
	t.ok(music != null, "music is a slider")
	t.ok(_find(card, "SoundSlider") is HSlider, "sound is a slider")
	music.value = 0.4
	t.eq(float(Profile.setting("music_volume")), 0.4, "moving the slider sets the volume")
	t.ok(_find(card, "Screenshake") != null, "screen shake can be turned off")
	t.ok(_find(card, "Reset") != null, "Reset progress is offered from home")
	_press(card, "PickTwins")
	await _wait(0.5)
	t.ok(app.top_overlay() is PickerCard, "the mirror style picker opens")
	app.top_overlay().close()
	await _wait(0.4)
	_press(card, "HowToPlay")
	await _wait(0.5)
	var how: Overlay = app.top_overlay()
	t.ok(how is HowToCard, "How to play opens")
	t.ok(_find(how, "DemoCard") != null, "with a live demo board")
	how.close()
	await _wait(0.4)
	_press(card, "Credits")
	await _wait(0.5)
	t.ok(app.top_overlay() is CreditsCard, "Credits opens from Settings")
	t.ok(not card.visible, "Settings steps aside while Credits is open")
	app.top_overlay().close()
	await _wait(0.4)
	t.ok(app.top_overlay() == card and card.visible, "closing Credits returns to Settings")
	_press(card, "About")
	await _wait(0.5)
	app.handle_back()
	await _wait(0.4)
	t.ok(app.top_overlay() == card and card.visible, "Back from About returns to Settings")
	card.close()
	await _wait(0.3)
	# Top-bar buttons are the same size on every screen.
	var sizes: Array[Vector2] = []
	for route: Array in [["home", {}], ["chapters", {}], ["levels", {"chapter": 0}], ["shop", {}], ["play", {"chapter": 0, "level": 1}]]:
		app.go(route[0], route[1])
		await _wait(0.7)
		app.close_overlays()
		var sb: Button = _find(app.screen, "SettingsButton") as Button
		sizes.append(sb.size)
	for k: int in sizes.size():
		t.eq(sizes[k], Vector2(Style.TOP_BUTTON, Style.TOP_BUTTON), "the Settings button is %dpx on screen %d" % [int(Style.TOP_BUTTON), k])
	_press(app.screen, "SettingsButton")
	await _wait(0.5)
	t.ok(_find(app.top_overlay(), "Reset") == null, "Reset progress is hidden in a level")
	app.top_overlay().close()
	await _wait(0.3)


func _daily() -> void:
	app.go("home")
	await _wait(0.6)
	var coins0: int = Profile.coins()
	_press(app.screen, "Daily")
	await _wait(0.9)
	var play: Node = _play()
	t.ok(play.level != null and play.level.id == "daily-" + Catalog.today_key(), "the daily opens today's puzzle")
	await _solve(play)
	await _wait(2.4)
	t.ok(Profile.daily_done(Catalog.today_key()), "daily marked done")
	t.ok(Profile.coins() >= coins0 + Economy.daily_reward(1), "daily reward paid")
	_press(app.top_overlay(), "Next")
	await _wait(0.8)
	t.eq(app.screen_name, "home", "after the daily, Home")
	t.ok((_find(app.screen, "DailyStatus") as Label).text.begins_with("Done"), "home shows the daily as done")


func _restart_app() -> void:
	var coins: int = Profile.coins()
	Save.flush()
	app.queue_free()
	await _wait(0.2)
	Save.data = {}
	Save.load_data()
	await _boot()
	t.eq(Profile.coins(), coins, "coins survive a restart")
	t.eq(Profile.stars_for("reflect-01"), 3, "stars survive a restart")
	t.ok(Profile.is_supporter(), "purchases survive a restart")
	t.eq(float(Profile.setting("music_volume")), 0.4, "settings survive a restart")


## A locked chapter opened with a chapter key starts at its level 1.
func _chapter_key_unlock() -> void:
	app.go("chapters")
	await _wait(0.7)
	_press(_find(app.screen, "List"), "Chapter_solo")
	await _wait(0.5)
	var card: Overlay = app.top_overlay()
	t.ok(card is LockedChapterCard, "a locked chapter offers a chapter key")
	t.ok((_find(card, "UseChapterKey") as Button).disabled, "no chapter keys: the button is disabled")
	card.close()
	await _wait(0.3)
	Profile.add_chapter_keys(1)
	_press(_find(app.screen, "List"), "Chapter_solo")
	await _wait(0.5)
	_press(app.top_overlay(), "UseChapterKey")
	await _wait(0.9)
	t.eq(app.screen_name, "levels", "the opened chapter shows its levels")
	var grid: Node = _find(app.screen, "Grid")
	t.ok((grid.get_child(0) as LevelTile).open and not (grid.get_child(1) as LevelTile).open, "only its level 1 is open")
	t.eq(Profile.chapter_keys(), 0, "the chapter key is spent")


## The first time a chapter's level 1 opens, a card explains its new idea.
func _chapter_intro() -> void:
	app.go("play", {"chapter": 3, "level": 1})
	await _wait(1.2)
	var card: Overlay = app.top_overlay()
	t.ok(card is ChapterIntroCard, "Solo 1 opens with a chapter card")
	t.ok(_find(card, "DemoCard") != null, "the card shows the idea on a live board")
	card.close()
	await _wait(0.3)
	app.go("play", {"chapter": 3, "level": 1})
	await _wait(1.2)
	t.ok(app.top_overlay() == null, "the chapter card shows only once")


func _extras() -> void:
	# Appearance: Auto / Dark / Light.
	app.go("home")
	await _wait(0.7)
	_press(app.screen, "SettingsButton")
	await _wait(0.5)
	var slider: SegmentedSlider = _find(app.top_overlay(), "Appearance") as SegmentedSlider
	t.ok(slider != null, "Settings has the Auto / Dark / Light slider")
	slider.select(2)
	await _wait(1.0)
	t.eq(str(Profile.setting("appearance")), "light", "Light is saved")
	t.ok(not Style.DARK, "Light makes the Original colours light")
	t.ok(app.top_overlay() is SettingsCard, "Settings is shown again after repainting")
	(_find(app.top_overlay(), "Appearance") as SegmentedSlider).select(1)
	await _wait(1.0)
	t.ok(Style.DARK, "Dark brings the night look back")
	app.close_overlays()
	# Tip jar: type any amount; − / + step by 10.
	app.go("shop")
	await _wait(0.7)
	_press(app.screen, "TipJar")
	await _wait(0.5)
	var tip: Overlay = app.top_overlay()
	var amount: LineEdit = _find(tip, "TipAmount") as LineEdit
	amount.text = "347"
	amount.text_changed.emit("347")
	t.ok((_find(tip, "TipCustom") as Button).text.contains("350"), "a typed amount rounds to the nearest 10")
	_press(tip, "TipPlus")
	t.eq(amount.text, "360", "+ adds 10")
	tip.close()
	await _wait(0.3)
	# Chapter keys: 1 to 5 at a time.
	_press(app.screen, "Product_chapter_keys")
	await _wait(0.5)
	var ck: Overlay = app.top_overlay()
	for k: int in 8:
		_press(ck, "Plus")
	t.ok((_find(ck, "BuyChapterKeys") as Button).text.begins_with("Get 5 "), "no more than 5 chapter keys at once")
	ck.close()
	await _wait(0.3)
	# Share after a clear.
	app.go("play", {"chapter": 0, "level": 2})
	await _wait(0.8)
	await _solve(_play())
	await _wait(2.4)
	_press(app.top_overlay(), "Share")
	await _wait(0.6)
	var share: Overlay = app.top_overlay()
	t.ok(share is ShareCardOverlay, "the result card can share the level")
	for n: String in ["ShareNow", "Save", "CopyLink"]:
		t.ok(_find(share, n) != null, "sharing offers %s" % n)
	var msg: String = ShareService.message_for(share.info)
	t.ok(msg.contains("theramlakhan.com/mirrorlock"), "the share message links to the game")
	t.ok(msg.contains("3/3 stars"), "and says how it went")
	share.close()
	await _wait(0.4)
	t.ok(app.top_overlay() is ResultCard, "closing Share returns to the result")


## Reset, like Single Shot: the first tap asks, the second erases. Progress goes;
## settings, packs, keys and bought coins stay.
func _reset_progress() -> void:
	app.go("home")
	await _wait(0.6)
	Profile.add_keys(2)
	var keys: int = Profile.keys()
	t.ok(Profile.stat("levels") > 0, "there is progress to reset")
	_press(app.screen, "SettingsButton")
	await _wait(0.5)
	var card: Overlay = app.top_overlay()
	var reset: Button = _find(card, "Reset") as Button
	reset.pressed.emit()
	await _wait(0.2)
	t.ok(Profile.stat("levels") > 0, "the first tap only asks")
	t.ok(reset.text.begins_with("Tap again"), "the button asks for a second tap")
	reset.pressed.emit()
	await _wait(1.0)
	t.eq(Profile.stat("levels"), 0, "the second tap erases progress")
	t.eq(Profile.stars_for("reflect-01"), 0, "stars are erased")
	t.ok(not Profile.daily_done(Catalog.today_key()), "the daily is reset")
	t.ok(Profile.is_supporter(), "packs are kept")
	t.eq(Profile.keys(), keys, "keys are kept")
	t.eq(float(Profile.setting("music_volume")), 0.4, "settings are kept")
	t.eq(app.screen_name, "home", "after a reset, home")
	t.eq((_find(app.screen, "NextLevel") as Label).text, "Reflect · Level 1", "Play starts again from Reflect 1")
	t.ok(app.top_overlay() == null, "no card is left open")
