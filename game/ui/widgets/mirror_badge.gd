class_name MirrorBadge
extends Control
## A small glass tile showing a chapter's mirror: the line (standing, lying,
## diagonal, both, or turning) and a pair of twins zipping away from it. Used
## on chapter cards, the chapter hero and the loading moment. `lit` (0..1)
## dims it for locked or unstarted chapters.

var axis: String = "v"
var color: Color = Style.AMBER
var lit: float = 1.0
var number: String = ""
var _t: float = 0.0


func _init(px: float = 120.0) -> void:
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var s: float = minf(size.x, size.y)
	var box: Rect2 = Rect2((size - Vector2(s, s)) / 2.0, Vector2(s, s))
	var c: Vector2 = box.get_center()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color("0C0E2A", 0.85)
	sb.set_corner_radius_all(int(s * 0.24))
	sb.border_color = Color(color, 0.35 * lit + 0.1)
	sb.set_border_width_all(2)
	sb.anti_aliasing = true
	draw_style_box(sb, box)
	var line_col: Color = Color(color.lerp(Color.WHITE, 0.25), 0.25 + 0.7 * lit)
	var ang: float = 0.0
	match axis:
		"h":
			ang = PI / 2.0
		"d":
			ang = -PI / 4.0
		"t":
			ang = (PI / 2.0) * (0.5 + 0.5 * sin(_t * 1.2))
	var lines: Array[float] = [ang]
	if axis == "k":
		lines = [0.0, PI / 2.0]
	for a: float in lines:
		var d: Vector2 = Vector2(sin(a), cos(a))
		var half: float = s * (0.5 if axis == "d" else 0.38)
		draw_line(c - d * half, c + d * half, Color(line_col, line_col.a * 0.3), s * 0.1, true)
		draw_line(c - d * half, c + d * half, line_col, maxf(2.0, s * 0.025), true)
	# Twins: a capsule on each side, pointing away from the line.
	var zip: float = 0.06 * s * (0.5 + 0.5 * sin(_t * 2.0)) * lit
	var a0: float = lines[0]
	var normal: Vector2 = Vector2(cos(a0), -sin(a0))
	var col: Color = Color(color, 0.3 + 0.7 * lit)
	for side: float in [-1.0, 1.0]:
		var p: Vector2 = c + normal * side * (s * 0.2 + zip)
		_cap(p, normal * side, s * 0.2, s * 0.14, col)
	if axis == "k":
		var n2: Vector2 = Vector2(0, 1)
		for side: float in [-1.0, 1.0]:
			_cap(c + n2 * side * (s * 0.2 + zip) + Vector2(s * 0.16, 0), n2 * side, s * 0.14, s * 0.12, Color(col, col.a * 0.8))
	if not number.is_empty():
		var f: Font = UIKit.font(800)
		var fs: int = int(s * 0.2)
		var w: float = f.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, Vector2(box.end.x - w - s * 0.1, box.end.y - s * 0.1), number, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Style.INK, 0.5 + 0.4 * lit))


func _cap(c: Vector2, d: Vector2, length: float, thick: float, col: Color) -> void:
	var dd: Vector2 = d.normalized()
	var n: Vector2 = Vector2(-dd.y, dd.x)
	var a: Vector2 = c - dd * (length - thick) * 0.5
	var b: Vector2 = c + dd * (length - thick) * 0.5
	draw_texture_rect(Style.glow_texture(), Rect2(c - Vector2(length, length) * 0.9, Vector2(length, length) * 1.8), false, Color(col, 0.25 * col.a))
	draw_line(a, b, col, thick, true)
	draw_circle(a, thick * 0.5, col, true, -1.0, true)
	draw_circle(b, thick * 0.5, col, true, -1.0, true)
	var s: float = thick * 0.3
	draw_polyline(PackedVector2Array([c - dd * s * 0.5 + n * s, c + dd * s * 0.5, c - dd * s * 0.5 - n * s]), Color(Style.PAPER_INK, 0.8 * col.a), maxf(1.5, thick * 0.14), true)
