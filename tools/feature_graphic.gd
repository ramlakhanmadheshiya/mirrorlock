extends Control
## The Google Play feature graphic (1024 x 500): a glass board with its glowing
## mirror and twins zipping away from it, the name and a plain line about the
## game. Rendered by tools/render_feature_graphic.tscn.

const TOP: Color = Color("#262B78")
const BOTTOM: Color = Color("#0B0C24")
const WHITE: Color = Color("#EEF1FF")
const CYAN: Color = Color("#4FE3FF")
const PINK: Color = Color("#FF5FD2")
const LIME: Color = Color("#B6FF5C")
const AMBER: Color = Color("#FFC24F")


func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, 0), r.end, Vector2(0, r.end.y)]),
		PackedColorArray([TOP, BOTTOM, BOTTOM, TOP]))
	var glow: Texture2D = Style.glow_texture()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	for i: int in 50:
		draw_circle(Vector2(rng.randf() * size.x, rng.randf() * size.y), rng.randf_range(0.8, 2.0), Color(WHITE, 0.3), true, -1.0, true)
	# The board.
	var board: Rect2 = Rect2(70, 60, 380, 380)
	draw_texture_rect(glow, board.grow(80), false, Color(CYAN, 0.10))
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color("0C0E2A")
	sb.set_corner_radius_all(30)
	sb.border_color = Color(CYAN, 0.35)
	sb.set_border_width_all(2)
	sb.anti_aliasing = true
	draw_style_box(sb, board)
	var cell: float = 380.0 / 6.0
	for y: int in 6:
		for x: int in 6:
			draw_circle(board.position + (Vector2(x, y) + Vector2(0.5, 0.5)) * cell, 2.0, Color(1, 1, 1, 0.08), true, -1.0, true)
	var mx: float = board.get_center().x
	draw_line(Vector2(mx, board.position.y - 10), Vector2(mx, board.end.y + 10), Color(CYAN, 0.12), 34.0, true)
	draw_line(Vector2(mx, board.position.y - 10), Vector2(mx, board.end.y + 10), Color(CYAN, 0.25), 12.0, true)
	draw_line(Vector2(mx, board.position.y - 10), Vector2(mx, board.end.y + 10), Color("#E6FCFF"), 4.0, true)
	# Twins: a pair zipping out sideways with trails, others waiting.
	_cap(Vector2(board.position.x + 30, board.position.y + cell * 3), Vector2(-1, 0), cell * 2.0, cell * 0.72, CYAN, true)
	_cap(Vector2(board.end.x - 30, board.position.y + cell * 3), Vector2(1, 0), cell * 2.0, cell * 0.72, CYAN, true)
	_cap(board.position + Vector2(cell * 2.5, cell * 1.0), Vector2(0, -1), cell * 0.82, cell * 0.72, PINK, false)
	_cap(board.position + Vector2(cell * 3.5, cell * 1.0), Vector2(0, -1), cell * 0.82, cell * 0.72, PINK, false)
	_cap(board.position + Vector2(cell * 0.5, cell * 5.0), Vector2(0, 1), cell * 1.8, cell * 0.72, LIME, false)
	_cap(board.position + Vector2(cell * 5.5, cell * 5.0), Vector2(0, 1), cell * 1.8, cell * 0.72, LIME, false)
	_cap(board.position + Vector2(cell * 2.0, cell * 4.5), Vector2(-1, 0), cell * 1.82, cell * 0.72, AMBER, false)
	_cap(board.position + Vector2(cell * 4.0, cell * 4.5), Vector2(1, 0), cell * 1.82, cell * 0.72, AMBER, false)
	# Name and lines.
	var title: Font = UIKit.font(700)
	draw_string(title, Vector2(500, 230), "Mirrorlock", HORIZONTAL_ALIGNMENT_LEFT, -1, 92, WHITE)
	draw_line(Vector2(500, 248), Vector2(960, 248), Color(CYAN, 0.9), 3.0, true)
	draw_set_transform(Vector2(0, 248.0 * 1.55), 0.0, Vector2(1, -0.55))
	draw_string(title, Vector2(500, 230), "Mirrorlock", HORIZONTAL_ALIGNMENT_LEFT, -1, 92, Color(CYAN, 0.2))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var body: Font = UIKit.font(500)
	draw_string(body, Vector2(504, 340), "A mirrored twin escape puzzle.", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(1, 1, 1, 0.8))
	draw_string(body, Vector2(504, 388), "Tap one twin. Both escape.", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, PINK.lerp(Color.WHITE, 0.25))


func _cap(c: Vector2, d: Vector2, length: float, thick: float, col: Color, zipping: bool) -> void:
	var sz: Vector2 = Vector2(length, thick) if absf(d.x) > 0.5 else Vector2(thick, length)
	var r: Rect2 = Rect2(c - sz / 2.0, sz)
	if zipping:
		var back: Vector2 = c - d * length * 0.5
		var n: Vector2 = Vector2(-d.y, d.x) * thick * 0.3
		var tail: Vector2 = back - d * 150.0
		draw_polygon(PackedVector2Array([tail + n * 0.3, back + n, back - n, tail - n * 0.3]),
			PackedColorArray([Color(col, 0.0), Color(col, 0.6), Color(col, 0.6), Color(col, 0.0)]))
	draw_texture_rect(Style.glow_texture(), r.grow(thick * 0.6), false, Color(col, 0.4))
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(thick * 0.5))
	sb.anti_aliasing = true
	draw_style_box(sb, r)
	var nn: Vector2 = Vector2(-d.y, d.x)
	var s: float = thick * 0.26
	var cc: Vector2 = c + d * (length - thick) * 0.5
	draw_polyline(PackedVector2Array([cc - d * s * 0.55 + nn * s, cc + d * s * 0.45, cc - d * s * 0.55 - nn * s]), Color("#12143A", 0.85), thick * 0.12, true)
