class_name Splash
extends Control
## The opening moment: a glowing mirror line draws itself, two twin capsules
## appear on either side, zip away from it together, then the name appears and
## everything fades into the game. Matches the boot splash colour so the
## hand-off is seamless. Tap to skip.

signal finished

const BG_TOP: Color = Color("#1B1F4F")
const BG_BOTTOM: Color = Color("#0B0C24")
const CYAN: Color = Color("#4FE3FF")
const PINK: Color = Color("#FF5FD2")
const LENGTH: float = 2.5

var _t: float = 0.0
## Driven frame by frame (e.g. for recording) instead of by the clock.
var manual: bool = false
var _done: bool = false
var _zipped: bool = false


func show_at(t: float) -> void:
	_t = t
	queue_redraw()


func _ready() -> void:
	if manual:
		set_process(false)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_finish()
	)


func _process(delta: float) -> void:
	_t += delta
	if not _zipped and _t > 0.95:
		_zipped = true
		Audio.play("zip", 1.0, -6.0)
		get_tree().create_timer(0.28).timeout.connect(func() -> void: Audio.play("chime", 1.0, -6.0))
	if _t >= LENGTH:
		_finish()
	queue_redraw()


func _finish() -> void:
	if _done:
		return
	_done = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		finished.emit()
		queue_free()
	)


func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, 0), r.end, Vector2(0, r.end.y)]),
		PackedColorArray([BG_TOP, BG_TOP, BG_BOTTOM, BG_BOTTOM]))
	var u: float = minf(size.x, size.y) / 720.0
	var c: Vector2 = size * Vector2(0.5, 0.42)
	var glow: Texture2D = Style.glow_texture()
	# The mirror line grows from the middle.
	var grow: float = clampf(_t / 0.45, 0.0, 1.0)
	grow = 1.0 - pow(1.0 - grow, 3.0)
	var half: float = 200.0 * u * grow
	var line_col: Color = CYAN.lerp(Color.WHITE, 0.3)
	draw_line(c - Vector2(0, half), c + Vector2(0, half), Color(line_col, 0.12), 34.0 * u, true)
	draw_line(c - Vector2(0, half), c + Vector2(0, half), Color(line_col, 0.25), 12.0 * u, true)
	draw_line(c - Vector2(0, half), c + Vector2(0, half), Color(line_col, 0.95), 4.0 * u, true)
	# Two pairs of twins: cyan pointing out sideways, pink pointing up.
	var appear: float = clampf((_t - 0.35) / 0.3, 0.0, 1.0)
	var zip: float = clampf((_t - 0.95) / 0.55, 0.0, 1.0)
	var fly: float = zip * zip * 520.0 * u
	var fade: float = 1.0 - clampf((_t - 1.3) / 0.25, 0.0, 1.0)
	for side: float in [-1.0, 1.0]:
		var base: Vector2 = c + Vector2(side * 105.0 * u, 40.0 * u)
		_capsule(base + Vector2(side * fly, 0), Vector2(side, 0), 150.0 * u, 64.0 * u, CYAN, appear * fade)
		var up: Vector2 = c + Vector2(side * 70.0 * u, -95.0 * u)
		var fly2: float = clampf((_t - 1.05) / 0.5, 0.0, 1.0)
		_capsule(up + Vector2(0, -fly2 * fly2 * 460.0 * u), Vector2(0, -1), 64.0 * u, 64.0 * u, PINK, appear * (1.0 - clampf((_t - 1.4) / 0.25, 0.0, 1.0)))
	if zip > 0.0 and zip < 1.0:
		for side: float in [-1.0, 1.0]:
			var p: Vector2 = c + Vector2(side * (105.0 * u + fly), 40.0 * u)
			draw_texture_rect(glow, Rect2(p - Vector2(90, 90) * u, Vector2(180, 180) * u), false, Color(CYAN, 0.35 * (1.0 - zip)))
	# Title.
	var ta: float = clampf((_t - 1.45) / 0.45, 0.0, 1.0)
	if ta > 0.0:
		var f: Font = UIKit.font(700)
		var fs: int = int(clampf(size.x * 0.12, 48.0, 100.0))
		var title: String = "mirrorlock"
		var w: float = f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var y: float = c.y + 310.0 * u + 20.0 * (1.0 - ta)
		draw_string(f, Vector2(size.x * 0.5 - w * 0.5, y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#EEF1FF", ta))
		# Its reflection, faint, upside down.
		draw_set_transform(Vector2(0, (y + fs * 0.12) * 1.55), 0.0, Vector2(1, -0.55))
		draw_string(f, Vector2(size.x * 0.5 - w * 0.5, y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(CYAN, 0.16 * ta))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var f3: Font = UIKit.font(500)
		var tag: String = "a mirrored twin escape puzzle"
		var tw2: float = f3.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		draw_string(f3, Vector2(size.x * 0.5 - tw2 * 0.5, y + 96.0 * u), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 1, 1, 0.55 * ta))


## A glowing capsule centred at c, `length` long along d and `thick` across,
## with a chevron pointing along d.
func _capsule(c: Vector2, d: Vector2, length: float, thick: float, col: Color, a: float) -> void:
	if a <= 0.0:
		return
	var sz: Vector2 = Vector2(length, thick) if absf(d.x) > 0.5 else Vector2(thick, length)
	var r: Rect2 = Rect2(c - sz / 2.0, sz)
	draw_texture_rect(Style.glow_texture(), r.grow(thick * 0.7), false, Color(col, 0.45 * a))
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(col, a)
	sb.set_corner_radius_all(int(thick * 0.5))
	sb.anti_aliasing = true
	draw_style_box(sb, r)
	var n: Vector2 = Vector2(-d.y, d.x)
	var s: float = thick * 0.26
	var ink: Color = Color("#12143A", 0.85 * a)
	draw_polyline(PackedVector2Array([c - d * s * 0.55 + n * s, c + d * s * 0.45, c - d * s * 0.55 - n * s]), ink, thick * 0.1, true)
