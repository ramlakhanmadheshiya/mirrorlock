extends Screen
## Playing one level (args {chapter, level}) or a Daily Mirror (args {daily:
## "YYYY-MM-DD"}). Laid out like Single Shot's game screen: header, a HEARTS /
## STARS strip, a message line, the board, and a bottom bar with Levels, Hint,
## Undo and Restart. Progress is saved after every tap.

const MONTHS: Array[String] = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
const BUMP_TEXT: Dictionary = {
	"piece": "Blocked! Both twins bounce back",
	"twins": "Twins crash into each other",
	"stone": "A stone is in the way",
	"lock": "Locked: its key pair must escape first",
}

var level: MirrorLevel
var state: PlayState
var board: BoardView
var chapter_idx: int = -1
var level_n: int = 0
var daily_key: String = ""

var _hud: HeartsHud
var _msg: Label
var _msg_box: PanelContainer
var _msg_tween: Tween
var _hint_btn: Button
var _hint_badge: Label
var _undo_btn: Button
var _done: bool = false
## First play of Reflect 1: a hands-on tutorial with a ghost finger.
var _tutorial: bool = false


func chapter_info() -> Dictionary:
	if args.has("daily"):
		var ch: Dictionary = Catalog.chapter(Catalog.daily_chapter(str(args["daily"]))).duplicate()
		ch["sky_top"] = Color("2B1748")
		ch["sky_bottom"] = Color("0B0718")
		ch["accent"] = Color("FF5FD2")
		return ch
	return Catalog.chapter(int(args.get("chapter", 0)))


func in_game() -> bool:
	return true


func build() -> void:
	daily_key = str(args.get("daily", ""))
	if daily_key.is_empty():
		chapter_idx = int(args.get("chapter", 0))
		level_n = int(args.get("level", 1))
		level = Catalog.level(chapter_idx, level_n)
	else:
		level = Catalog.daily_level(daily_key)
	if level == null:
		_build_error()
		return
	state = PlayState.new(level)
	state.restore(Profile.saved_progress(level.id))
	if state.is_failed():
		state = PlayState.new(level)
	Profile.set_last_level(level.id)
	Audio.music("play")
	_build_ui()
	_refresh()
	_intro_if_needed.call_deferred()


func _build_error() -> void:
	body.add_child(header("Level unavailable"))
	body.add_child(UIKit.gap(120))
	body.add_child(UIKit.icon_rect("info", 96, Style.MUTED))
	body.add_child(UIKit.para("This level could not be loaded. %s" % Catalog.last_error, Style.SIZE_BODY))
	var b: Button = UIKit.button("Back", "soft")
	b.pressed.connect(app.back)
	body.add_child(b)


func _title() -> String:
	return "Daily Mirror" if not daily_key.is_empty() else "Level %d" % level_n


func _caption() -> String:
	if not daily_key.is_empty():
		return "%s · %s" % [_pretty_date(daily_key), _axis_name()]
	return "%s · %s" % [Catalog.chapter(chapter_idx)["name"], Catalog.tier_name(level_n)]


func _axis_name() -> String:
	return {"v": "Standing mirror", "h": "Lying mirror", "d": "Diagonal", "k": "Kaleidoscope", "t": "Turning mirror"}.get(level.axis, "")


func _build_ui() -> void:
	body.add_child(header(_title(), _caption()))
	var strip: HBoxContainer = UIKit.hbox(8, BoxContainer.ALIGNMENT_BEGIN)
	strip.name = "Strip"
	_hud = HeartsHud.new()
	_hud.name = "Hud"
	_hud.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip.add_child(_hud)
	var coins: CounterChip = UIKit.coin_chip()
	coins.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	strip.add_child(coins)
	var strip_panel: PanelContainer = PanelContainer.new()
	strip_panel.add_theme_stylebox_override("panel", UIKit.lip_box(Style.PANEL, 28, Style.LIP, 5, Vector2(14, 2)))
	strip_panel.add_child(strip)
	body.add_child(strip_panel)

	# The message line: hints, bumps and tips, on their own line above the
	# board (it keeps its height so nothing jumps).
	var line: CenterContainer = CenterContainer.new()
	line.name = "MessageLine"
	line.custom_minimum_size.y = 62
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_msg_box = PanelContainer.new()
	_msg_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_msg_box.add_theme_stylebox_override("panel", UIKit.box(Color(0, 0, 0, 0.32), 30, Color(Style.INK, 0.08), 2, Vector2(26, 6)))
	_msg = UIKit.label("", 26, Style.INK, 700)
	_msg.name = "Message"
	_msg_box.add_child(_msg)
	_msg_box.modulate.a = 0.0
	line.add_child(_msg_box)
	body.add_child(line)

	board = BoardView.new()
	board.name = "Board"
	board.setup(state, accent())
	board.tapped.connect(_on_tapped)
	body.add_child(board)

	var bar: HBoxContainer = UIKit.hbox(26)
	bar.name = "Bar"
	bar.custom_minimum_size.y = 128
	bar.add_child(_action("layout-grid", "LEVELS" if daily_key.is_empty() else "HOME", "LevelsButton", 80, func() -> void: app.back()))
	var hint: VBoxContainer = _action("art:hint", "HINT", "Hint", 96, use_hint)
	_hint_btn = hint.get_child(0)
	_hint_badge = UIKit.label("", 17, Style.PAPER_INK, 800)
	_hint_badge.name = "Badge"
	_hint_badge.add_theme_stylebox_override("normal", UIKit.box(Style.GOLD, 14, Color.TRANSPARENT, 0, Vector2(8, 1)))
	_hint_badge.position = Vector2(58, -6)
	_hint_btn.add_child(_hint_badge)
	bar.add_child(hint)
	var undo: VBoxContainer = _action("undo-2", "UNDO", "Undo", 80, do_undo)
	_undo_btn = undo.get_child(0)
	bar.add_child(undo)
	bar.add_child(_action("rotate-ccw", "RESTART", "Restart", 80, ask_restart))
	body.add_child(bar)


## A round icon button with a small caption under it.
func _action(icon_name: String, caption: String, node_name: String, size_px: float, cb: Callable) -> VBoxContainer:
	var box: VBoxContainer = UIKit.vbox(6)
	var b: Button = UIKit.icon_button(icon_name, size_px)
	b.name = node_name
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(cb)
	box.add_child(b)
	box.add_child(UIKit.caption(caption, Style.MUTED, 16))
	return box


func _pretty_date(key: String) -> String:
	var parts: PackedStringArray = key.split("-")
	if parts.size() != 3:
		return key
	return "%s %d" % [MONTHS[clampi(int(parts[1]) - 1, 0, 11)], int(parts[2])]


func _refresh() -> void:
	_hud.accent = accent()
	_hud.set_state(state.hearts_left(), PlayState.HEARTS + state.extra_hearts, state.stars(), state.pieces_left())
	var free: int = Profile.free_hints_left()
	_hint_badge.text = ("FREE %d" % free) if free > 0 else str(Economy.HINT_COST)
	_hint_badge.reset_size()
	_hint_btn.disabled = _done
	_undo_btn.disabled = _done or not state.can_undo()


# --- Taps ----------------------------------------------------------------------

func _on_tapped(i: int) -> void:
	if _done:
		return
	var r: Dictionary = state.tap(i)
	if bool(r.get("ignored", false)):
		return
	var group: Array[int] = r["group"]
	if bool(r["ok"]):
		board.play_exit(group)
		Audio.play("zip", 1.0 + 0.05 * randf() - 0.06 * float(group.size() - 1), -2.0)
		if group.size() >= 2:
			get_tree().create_timer(0.16).timeout.connect(func() -> void: Audio.play("chime", [1.0, 1.122, 1.26, 1.335, 1.498][posmod(state.moves, 5)], -3.0))
		Haptics.success()
		Profile.record_move(group.size())
		if state.is_complete():
			_complete()
		else:
			Profile.store_progress(level.id, state)
			Profile.check_achievements()
			if _tutorial:
				_tutorial_step(true)
			elif state.level.axis == "t":
				show_message("The mirror turned", 1.0, Style.MUTED)
			else:
				hide_message()
	else:
		board.play_bump(group, float(r["travel"]), r["obstacles"])
		Audio.play("bump", 1.0, -1.0)
		get_tree().create_timer(0.12).timeout.connect(func() -> void: Audio.play("heart", 1.0, -4.0))
		Haptics.error()
		Profile.record_bump()
		show_message(str(BUMP_TEXT.get(str(r["reason"]), "Blocked!")), 1.8, Style.ERROR)
		Profile.store_progress(level.id, state)
		if _tutorial:
			_tutorial_step(false)
		if state.is_failed():
			_fail()
	_refresh()


## A short message on the line above the board (0 s = until replaced).
func show_message(text: String, seconds: float, color: Color = Style.INK) -> void:
	_msg.text = text
	_msg.add_theme_color_override("font_color", color)
	_msg_box.reset_size()
	if _msg_tween != null:
		_msg_tween.kill()
	_msg_tween = create_tween()
	_msg_tween.tween_property(_msg_box, "modulate:a", 1.0, 0.12)
	if seconds > 0.0:
		_msg_tween.tween_interval(seconds)
		_msg_tween.tween_property(_msg_box, "modulate:a", 0.0, 0.3)


func hide_message() -> void:
	if _msg_tween != null:
		_msg_tween.kill()
	_msg_tween = create_tween()
	_msg_tween.tween_property(_msg_box, "modulate:a", 0.0, 0.2)


# --- Hints and undo ------------------------------------------------------------

## A hint lights up the next safe group. Free hints first (3 a day), then
## coins; with too few coins the player is offered a video. Nothing is charged
## when there is nothing to show.
func use_hint() -> void:
	if _done:
		return
	if state.hint_piece() < 0:
		show_message("No safe move from here: Undo or Restart", 2.4, Style.AMBER)
		return
	if Profile.use_free_hint() or Profile.spend(Economy.HINT_COST):
		_give_hint()
	else:
		_out_of_coins()


func _give_hint() -> void:
	var i: int = state.use_hint()
	if i < 0:
		return
	Profile.record_hint()
	Audio.play("hint")
	board.show_hint(i)
	show_message("Tap the glowing piece", 2.0, Style.GOLD)
	Profile.store_progress(level.id, state)
	_refresh()


## Not enough coins: watch a video for this hint, get coins, or carry on.
## Where no video can be shown at all (e.g. the web), the hint is free.
func _out_of_coins() -> void:
	if AdManager.provider == null:
		show_message("Here's a free hint", 1.8, Style.GOLD)
		_give_hint()
		return
	var o: MessageCard = MessageCard.new()
	o.name = "OutOfCoins"
	o.title_text = "Out of free hints"
	o.icon_name = "coin"
	o.icon_color = Style.GOLD
	o.message = "Free hints come back at midnight. A hint costs %d coins and you have %d.\nWatch a short video to get this one free?" % [Economy.HINT_COST, Profile.coins()]
	o.buttons = [
		["Watch a video", "primary", func() -> void:
			o.close()
			if not AdManager.rewarded_ready():
				show_message("No video available right now", 2.4, Style.MUTED)
				return
			AdManager.show_rewarded(func(ok: bool) -> void:
				if not is_inside_tree():
					return
				if ok:
					Audio.play("unlock", 1.2, -4.0)
					_give_hint()
				else:
					show_message("Video closed early: no hint this time", 2.4, Style.MUTED)
			)],
		["Get coins", "soft", func() -> void:
			o.close()
			app.go("shop")],
		["Not now", "ghost", func() -> void: o.close()],
	]
	app.open(o)


func do_undo() -> void:
	if _done or not state.can_undo():
		return
	var g: int = state.undo()
	board.play_undo(g)
	board.clear_hint()
	Audio.play("undo", 1.0, -4.0)
	Profile.store_progress(level.id, state)
	_refresh()


func _unhandled_key_input(e: InputEvent) -> void:
	if app.top_overlay() != null or not e.is_pressed():
		return
	if e.is_action_pressed("hint"):
		use_hint()
	elif e.is_action_pressed("undo"):
		do_undo()
	elif e is InputEventKey and (e as InputEventKey).keycode == KEY_R:
		ask_restart()


# --- Restart, failing and completing --------------------------------------------

## A fresh start with all three hearts and stars (asks first if there is progress).
func ask_restart() -> void:
	if _done or level == null:
		return
	board.cancel_press()
	if state.moves == 0 and state.bounces == 0 and state.hints_used == 0:
		show_message("Fresh start", 1.2, Style.MUTED)
		return
	MessageCard.confirm(app, "Restart this level?", "Every piece comes back, with three hearts and all three stars on offer again. Coins spent on hints are not refunded.", "Restart", restart)


func restart() -> void:
	Profile.clear_progress(level.id)
	app.reload_screen()


## Out of hearts: try again, or buy one more heart (coins or a video) and carry on.
func _fail() -> void:
	board.input_enabled = false
	Audio.play("fail", 1.0, -3.0)
	await get_tree().create_timer(0.8).timeout
	if not is_inside_tree():
		return
	var o: MessageCard = MessageCard.new()
	o.name = "OutOfHearts"
	o.dismissable = false
	o.title_text = "Out of hearts"
	o.icon_name = "heart"
	o.message = "Three bumps and the mirror locks. Try the level again, or take one more heart and carry on from here."
	var buttons: Array = [["Try again", "primary", func() -> void:
		o.close()
		restart()]]
	if Profile.coins() >= Economy.HEART_COST:
		buttons.append(["+1 heart for %d coins" % Economy.HEART_COST, "soft", func() -> void:
			if Profile.spend(Economy.HEART_COST):
				o.close()
				_revive()])
	elif AdManager.provider != null:
		buttons.append(["Watch a video for a heart", "soft", func() -> void:
			o.close()
			if not AdManager.rewarded_ready():
				_fail()
				return
			AdManager.show_rewarded(func(ok: bool) -> void:
				if not is_inside_tree():
					return
				if ok:
					_revive()
				else:
					_fail()
			)])
	buttons.append(["Levels" if daily_key.is_empty() else "Home", "ghost", func() -> void:
		o.close()
		Profile.clear_progress(level.id)
		app.back()])
	o.buttons = buttons
	app.open(o)


func _revive() -> void:
	state.add_heart()
	board.input_enabled = true
	Audio.play("unlock", 1.2, -4.0)
	Profile.store_progress(level.id, state)
	show_message("One more heart: careful now", 1.8, Style.HEART)
	_refresh()


func _complete() -> void:
	_done = true
	board.input_enabled = false
	board.clear_hint()
	var reward: Dictionary
	if daily_key.is_empty():
		reward = Profile.complete_level(level.id, state)
	else:
		reward = Profile.complete_daily(daily_key, state)
	reward["achievements"] = Profile.check_achievements()
	if _tutorial:
		Profile.mark_seen("tutorial")
		_tutorial = false
		board.show_ghost(-1)
	_refresh()
	await get_tree().create_timer(0.55).timeout
	board.celebrate()
	Audio.play("complete", 1.0, -3.0)
	show_message("Every twin is free!", 1.6, Style.GOLD)
	await get_tree().create_timer(1.2).timeout
	if not is_inside_tree():
		return
	var card: ResultCard = ResultCard.new()
	card.play = self
	card.reward = reward
	app.open(card)


## Where "Next" goes after a clear: the next level, the next chapter, or home.
func go_next() -> void:
	if not daily_key.is_empty():
		app.go("home")
	elif level_n < Catalog.levels_per_chapter and Profile.level_unlocked(chapter_idx, level_n + 1):
		app.go("play", {"chapter": chapter_idx, "level": level_n + 1})
	elif level_n >= Catalog.levels_per_chapter and Profile.chapter_unlocked(chapter_idx + 1):
		app.go("levels", {"chapter": chapter_idx + 1})
	else:
		app.go("levels", {"chapter": chapter_idx})


func on_back() -> bool:
	if level != null and not _done:
		board.cancel_press()
	return false


# --- Tutorial and chapter cards ---------------------------------------------------

## Reflect 1 the first time: the hands-on tutorial. Level 1 of any other
## chapter the first time: a card explaining the chapter's new idea.
func _intro_if_needed() -> void:
	if not daily_key.is_empty() or level_n != 1 or state.moves > 0:
		return
	if chapter_idx == 0 and not Profile.seen("tutorial"):
		_tutorial = true
		_tutorial_step(true)
		return
	var key: String = "chapter_" + str(Catalog.chapter(chapter_idx)["id"])
	if chapter_idx > 0 and not Profile.seen(key):
		Profile.mark_seen(key)
		await get_tree().create_timer(0.35).timeout
		if not is_inside_tree():
			return
		var o: ChapterIntroCard = ChapterIntroCard.new()
		o.chapter_idx = chapter_idx
		app.open(o)


## Points the ghost finger at a safe piece and says what to do.
func _tutorial_step(after_success: bool) -> void:
	var i: int = state.hint_piece()
	board.show_ghost(i)
	if state.moves == 0 and after_success:
		show_message("Tap a piece: its twin moves too!", 0.0, Style.GOLD)
	elif not after_success:
		show_message("Blocked! Both bump back: a heart lost", 0.0, Style.ERROR)
	else:
		show_message("Both escaped together! Clear them all", 0.0, Style.GOLD)
