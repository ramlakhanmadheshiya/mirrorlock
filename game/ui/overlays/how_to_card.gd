class_name HowToCard
extends Overlay
## How to play, one page per idea, each with a small live board that plays
## itself (a ghost finger taps, twins zip off or bump). `pages` picks which
## ideas to show.

const ALL_PAGES: Array[String] = ["basics", "bumps", "stars", "hints", "horizon", "stones", "lonely", "diagonal", "locks", "kaleido", "turn"]

const REFLECT: Dictionary = {"w": 4, "h": 5, "axis": "v", "pieces": [[1, 2, "L", 2], [2, 2, "R", 2], [0, 4, "U", 1], [3, 4, "U", 1], [1, 0, "U", 1], [2, 0, "U", 1]]}

const PAGES: Dictionary = {
	"basics": {
		"title": "Mirror twins",
		"text": "Every piece has a twin across the glowing mirror, in the same colour. Tap either one and both slide straight ahead, off the board. Clear every piece to win.",
		"level": REFLECT, "taps": [],
	},
	"bumps": {
		"title": "Bumps and hearts",
		"text": "If anything stands in either twin's way, both bump and slide back, and you lose a heart. Twins heading toward each other across the mirror always crash. Three hearts per level: plan before you tap.",
		"level": REFLECT, "taps": [2, 0, 2, 4],
	},
	"stars": {
		"title": "Three stars",
		"text": "Clear a level with no bumps for three stars, with one bump for two, and with more for one. Using a hint makes two stars the most. Each new star pays %d coins, and Restart brings back every heart and star." % Economy.STAR_REWARD,
		"level": REFLECT, "taps": [],
	},
	"hints": {
		"title": "Hints and Undo",
		"text": "Stuck? A hint lights up a safe pair. You get %d free hints a day; after that a hint costs %d coins, or watch a short video. Undo takes back your last move (it doesn't give back hearts)." % [Economy.FREE_HINTS, Economy.HINT_COST],
		"level": REFLECT, "taps": [],
	},
	"horizon": {
		"title": "A level mirror",
		"text": "When the mirror lies across the board, twins sit above and below it and up becomes down.",
		"level": {"w": 5, "h": 4, "axis": "h", "pieces": [[2, 1, "U", 2], [2, 2, "D", 2], [4, 1, "L", 1], [4, 2, "L", 1], [0, 0, "R", 1], [0, 3, "R", 1]]}, "taps": [],
	},
	"stones": {
		"title": "Stones",
		"text": "A stone sits on one side only, so twins no longer see the same board. Its number is how many moves it lasts: every move chips it, and at zero it crumbles.",
		"level": {"w": 4, "h": 4, "axis": "v", "stones": [[0, 1, 1]], "pieces": [[1, 0, "U", 1], [2, 0, "U", 1], [1, 1, "L", 1], [2, 1, "R", 1], [0, 2, "U", 1], [3, 2, "U", 1]]}, "taps": [2, 0, 2, 4],
	},
	"lonely": {
		"title": "Lonely pieces",
		"text": "White pieces have no twin. They move alone and block only one side of the mirror, so free them at the right moment.",
		"level": {"w": 4, "h": 4, "axis": "v", "pieces": [[0, 1, "D", 1], [1, 1, "L", 1], [2, 1, "R", 1], [1, 3, "D", 1], [2, 3, "D", 1]]}, "taps": [1, 0, 1, 3],
	},
	"diagonal": {
		"title": "The diagonal mirror",
		"text": "A mirror from corner to corner turns a twin a quarter turn: right becomes down and left becomes up.",
		"level": {"w": 4, "h": 4, "axis": "d", "pieces": [[3, 1, "R", 1], [1, 3, "D", 1], [2, 1, "R", 1], [1, 2, "D", 1], [2, 0, "U", 1], [0, 2, "L", 1]]}, "taps": [],
	},
	"locks": {
		"title": "Locks and keys",
		"text": "A locked pair can't move, even with a clear path, until the pair carrying its key has escaped.",
		"level": {"w": 4, "h": 5, "axis": "v", "pieces": [[1, 0, "U", 1, 0, -1], [2, 0, "U", 1, 0, -1], [0, 3, "U", 1, -1, 0], [3, 3, "U", 1, -1, 0], [1, 2, "L", 2], [2, 2, "R", 2]]}, "taps": [0, 4, 2, 0],
	},
	"kaleido": {
		"title": "The kaleidoscope",
		"text": "Two mirrors at once: every piece has three twins, one in each corner. Tap any of the four and all four move.",
		"level": {"w": 4, "h": 4, "axis": "k", "pieces": [[1, 1, "L", 1], [2, 1, "R", 1], [1, 2, "L", 1], [2, 2, "R", 1], [0, 1, "U", 1], [3, 1, "U", 1], [0, 2, "D", 1], [3, 2, "D", 1]]}, "taps": [],
	},
	"turn": {
		"title": "The turning mirror",
		"text": "After every move the mirror turns a quarter, and the twins change with it. A piece with no twin in the current mirror moves alone. Order matters: Undo if you get stuck.",
		"level": {"w": 4, "h": 4, "axis": "t", "start": "v", "pieces": [[0, 1, "U", 1], [3, 1, "U", 1], [0, 2, "D", 1], [3, 2, "D", 1]]}, "taps": [],
	},
	"finale": {
		"title": "Everything at once",
		"text": "The last chapter mixes every mirror and every idea: stones, lonely pieces, locks and keys, the kaleidoscope and the turning mirror. Read the board before you tap.",
		"level": {"w": 4, "h": 4, "axis": "v", "stones": [[0, 1, 1]], "pieces": [[1, 0, "U", 1], [2, 0, "U", 1], [1, 1, "L", 1], [2, 1, "R", 1], [0, 2, "U", 1], [3, 2, "U", 1]]}, "taps": [],
	},
}

var pages: Array = ALL_PAGES
var heading: String = ""
var _index: int = 0
var _holder: VBoxContainer
var _prev: Button
var _next: Button
var _dots: HBoxContainer


func build() -> void:
	if name.is_empty() or name.begins_with("@"):
		name = "HowTo"
	add_title(heading if not heading.is_empty() else "How to play")
	_holder = UIKit.vbox(14)
	body.add_child(_holder)
	var nav: HBoxContainer = UIKit.hbox(16)
	_prev = UIKit.icon_button("chevron-left", 80)
	_prev.pressed.connect(func() -> void: _show(_index - 1))
	nav.add_child(_prev)
	_dots = UIKit.hbox(10)
	_dots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(_dots)
	_next = UIKit.button("Next", "primary", Style.AMBER, 80, 28)
	_next.name = "Next"
	_next.custom_minimum_size.x = 200
	_next.pressed.connect(func() -> void:
		if _index >= pages.size() - 1:
			close()
		else:
			_show(_index + 1)
	)
	nav.add_child(_next)
	body.add_child(nav)
	_show(0)


func _show(i: int) -> void:
	_index = clampi(i, 0, pages.size() - 1)
	for c: Node in _holder.get_children():
		c.queue_free()
	var page: Dictionary = PAGES[pages[_index]]
	var demo: DemoBoard = DemoBoard.new(page["level"], page["taps"], Style.AMBER)
	demo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l: Dictionary = page["level"]
	demo.custom_minimum_size = Vector2(300.0 * float(l["w"]) / float(l["h"]) + 40.0, 320)
	_holder.add_child(demo)
	_holder.add_child(UIKit.label(page["title"], Style.SIZE_H2, Style.AMBER, 600))
	_holder.add_child(UIKit.para(page["text"], Style.SIZE_BODY - 2, Style.INK))
	_prev.visible = pages.size() > 1
	_prev.disabled = _index == 0
	_next.text = "Got it" if _index == pages.size() - 1 else "Next"
	for c: Node in _dots.get_children():
		c.queue_free()
	if pages.size() > 1:
		for k: int in pages.size():
			var dot: ColorRect = ColorRect.new()
			dot.custom_minimum_size = Vector2(12, 12) if k != _index else Vector2(30, 12)
			dot.color = Style.AMBER if k == _index else Color(Style.INK, 0.25)
			dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_dots.add_child(dot)
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	refit()
