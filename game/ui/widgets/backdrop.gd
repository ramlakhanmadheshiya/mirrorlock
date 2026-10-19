class_name Backdrop
extends Control
## The sky behind every screen: a vertical gradient that eases between chapter
## colours, faint stars, and pairs of soft lights drifting in mirror image on
## either side of the screen's middle.

const STAR_COUNT: int = 60
const MOTE_PAIRS: int = 7

var top: Color = Style.DEFAULT_SKY_TOP
var bottom: Color = Style.DEFAULT_SKY_BOTTOM
var _stars: Array[Vector4] = []    # x, y (0..1), radius, phase
var _motes: Array[Dictionary] = []
var _t: float = 0.0
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Offsets too: anchors alone keep the empty rect it was added with.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	for i: int in STAR_COUNT:
		_stars.append(Vector4(rng.randf(), rng.randf(), rng.randf_range(0.8, 2.2), rng.randf() * TAU))
	for i: int in MOTE_PAIRS:
		_motes.append({
			"x": rng.randf_range(0.04, 0.44), "y": rng.randf(), "speed": rng.randf_range(0.008, 0.02),
			"size": rng.randf_range(10.0, 26.0), "phase": rng.randf() * TAU, "color": i,
		})


## Eases the sky to a chapter's colours.
func set_sky(new_top: Color, new_bottom: Color, seconds: float = 0.8) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel()
	_tween.tween_property(self, "top", new_top, seconds)
	_tween.tween_property(self, "bottom", new_bottom, seconds)


func _process(delta: float) -> void:
	_t += delta
	for m: Dictionary in _motes:
		m["y"] = float(m["y"]) - float(m["speed"]) * delta
		if float(m["y"]) < -0.08:
			m["y"] = 1.08
	queue_redraw()


func _draw() -> void:
	var s: Vector2 = size
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]),
		PackedColorArray([top, top, bottom, bottom]))
	var glow: Texture2D = Style.glow_texture()
	var star: Color = Color("EEF1FF") if Style.DARK else Color(1, 1, 1)
	for st: Vector4 in _stars:
		var a: float = (0.18 + 0.4 * (0.5 + 0.5 * sin(_t * 1.1 + st.w))) * (1.0 if Style.DARK else 0.6)
		draw_circle(Vector2(st.x * s.x, st.y * s.y), st.z, Color(star, a))
	# A faint mirror line down the middle of the sky.
	var mid: float = s.x * 0.5
	draw_line(Vector2(mid, 0), Vector2(mid, s.y), Color(Style.AMBER, 0.03 if Style.DARK else 0.05), 26.0)
	draw_line(Vector2(mid, 0), Vector2(mid, s.y), Color(Style.AMBER, 0.07 if Style.DARK else 0.1), 2.0)
	# Twin motes: each light has a reflection on the other side.
	for m: Dictionary in _motes:
		var x: float = (float(m["x"]) + 0.02 * sin(_t * 0.5 + float(m["phase"]))) * s.x
		var y: float = float(m["y"]) * s.y
		var r: float = m["size"]
		var col: Color = Look.pair_color(int(m["color"]), "neon")
		var flick: float = 0.8 + 0.2 * sin(_t * 2.0 + float(m["phase"]))
		var a2: float = (0.22 if Style.DARK else 0.3) * flick
		for px: float in [x, s.x - x]:
			draw_texture_rect(glow, Rect2(Vector2(px, y) - Vector2(r, r) * 2.4, Vector2(r, r) * 4.8), false, Color(col, a2))
			draw_circle(Vector2(px, y), r * 0.22, Color(col, 0.55 * flick), true, -1.0, true)
