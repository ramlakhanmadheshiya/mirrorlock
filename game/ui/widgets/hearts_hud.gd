class_name HeartsHud
extends Control
## HEARTS and STARS side by side over the board, like Single Shot's TRY / STARS.
## Every bump costs a heart; the stars still on offer drop (with a pulse) as
## bumps add up. Pieces left are shown as a small count.

var hearts: int = 3
var max_hearts: int = 3
var stars: int = 3
var left: int = 0
var accent: Color = Style.AMBER
var _bump: float = 0.0
var _heart_pop: float = 0.0


func _init() -> void:
	custom_minimum_size = Vector2(0, 84)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_state(h: int, max_h: int, s: int, pieces_left: int) -> void:
	if is_inside_tree():
		if s < stars:
			_bump = 1.0
		if h < hearts:
			_heart_pop = 1.0
	hearts = h
	max_hearts = max_h
	stars = s
	left = pieces_left
	queue_redraw()


func _process(delta: float) -> void:
	if _bump > 0.0 or _heart_pop > 0.0:
		_bump = maxf(0.0, _bump - delta * 2.5)
		_heart_pop = maxf(0.0, _heart_pop - delta * 2.0)
		queue_redraw()


func _draw() -> void:
	var cap_font: FontVariation = (UIKit.font(600) as FontVariation).duplicate()
	cap_font.spacing_glyph = 3
	var cols: Array[float] = [size.x * 0.2, size.x * 0.52, size.x * 0.84]
	var caps: Array[String] = ["HEARTS", "STARS", "LEFT"]
	for i: int in 3:
		var w: float = cap_font.get_string_size(caps[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		draw_string(cap_font, Vector2(cols[i] - w * 0.5, 22), caps[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Style.MUTED)
	var n: int = maxi(max_hearts, 3)
	var gap: float = 38.0 if n <= 3 else 30.0
	for k: int in n:
		var on: bool = k < hearts
		var s: float = 32.0 * (1.0 + (0.45 * _heart_pop if k == hearts else 0.0))
		var c: Vector2 = Vector2(cols[0] + (float(k) - float(n - 1) * 0.5) * gap, 55)
		var r: Rect2 = Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s))
		if on:
			draw_texture_rect(Style.glow_texture(), r.grow(s * 0.3), false, Color(Style.HEART, 0.3))
			draw_texture_rect(UIKit.art("heart"), r, false)
		else:
			draw_texture_rect(UIKit.art("heart"), r, false, Color(0.25, 0.22, 0.45, 0.55 + 0.45 * (_heart_pop if k == hearts else 0.0)))
	for k: int in 3:
		var s2: float = 32.0 * (1.0 + (0.35 * _bump if k == stars else 0.0))
		var c2: Vector2 = Vector2(cols[1] + (float(k) - 1.0) * 40.0, 55)
		var r2: Rect2 = Rect2(c2 - Vector2(s2, s2) * 0.5, Vector2(s2, s2))
		if k < stars:
			draw_texture_rect(UIKit.art("star"), r2, false)
		else:
			draw_texture_rect(UIKit.art("star"), r2, false, Color(0.25, 0.22, 0.45, 0.7 + 0.3 * (_bump if k == stars else 0.0)))
	var nf: Font = UIKit.font(600)
	var txt: String = str(left)
	var tw: float = nf.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 38).x
	draw_string(nf, Vector2(cols[2] - tw * 0.5, 70), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Style.INK)
