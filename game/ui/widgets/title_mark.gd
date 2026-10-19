class_name TitleMark
extends Control
## The name with its own reflection under a thin glowing line: "Mirrorlock",
## then the same word upside down and faint, as if on still water.

var text: String = "Mirrorlock"
var font_size: int = 80
var _t: float = 0.0


func _init(t: String = "Mirrorlock", fs: int = 80) -> void:
	text = t
	font_size = fs
	custom_minimum_size = Vector2(0, fs * 1.62)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var f: Font = UIKit.font(700)
	var fs: int = font_size
	var w: float = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var base: float = fs * 0.92
	var x: float = (size.x - w) * 0.5
	var acc: Color = Style.AMBER
	# Soft glow behind the word.
	draw_texture_rect(Style.glow_texture(), Rect2(Vector2(size.x * 0.5 - w * 0.6, base - fs * 0.9), Vector2(w * 1.2, fs * 1.2)), false, Color(acc, 0.16 if Style.DARK else 0.1))
	draw_string(f, Vector2(x, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Style.INK)
	# The mirror line, with a spark running along it.
	var ly: float = base + fs * 0.12
	draw_line(Vector2(x - 12, ly), Vector2(x + w + 12, ly), Color(acc, 0.9), 3.0, true)
	var sx: float = lerpf(x - 12, x + w + 12, fmod(_t * 0.25, 1.0))
	draw_texture_rect(Style.glow_texture(), Rect2(Vector2(sx - 22, ly - 22), Vector2(44, 44)), false, Color(acc, 0.7))
	# The reflection.
	# The reflection: squashed and faint, like a mirror seen at an angle.
	draw_set_transform(Vector2(0, ly + 0.55 * (ly + fs * 0.02)), 0.0, Vector2(1, -0.55))
	draw_string(f, Vector2(x, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(acc, 0.22))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
