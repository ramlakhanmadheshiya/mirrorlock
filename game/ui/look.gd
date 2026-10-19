class_name Look
extends RefCounted
## The player's chosen look: a colour theme (sky, accent and board; Theme pack)
## and a mirror style (the twins' colours and shape; Mirror styles pack).
## "chapters" (Original) and "neon" are free; Original keeps each chapter's colours.

const THEMES: Dictionary = {
	"midnight": {"name": "Midnight", "top": "#1B1D2B", "bottom": "#0B0C12", "accent": "#7AA2F7"},
	"nord": {"name": "Nord", "top": "#3B4252", "bottom": "#242933", "accent": "#88C0D0"},
	"dracula": {"name": "Dracula", "top": "#343746", "bottom": "#1B1C24", "accent": "#BD93F9"},
	"ocean": {"name": "Ocean", "top": "#14405A", "bottom": "#06121C", "accent": "#4FC3F7"},
	"forest": {"name": "Forest", "top": "#23402C", "bottom": "#0A140E", "accent": "#7BC67E"},
	"sunset": {"name": "Sunset", "top": "#7A3B57", "bottom": "#2B1B3D", "accent": "#FF8C61"},
	"sakura": {"name": "Sakura", "top": "#5A2E4C", "bottom": "#1A0E18", "accent": "#FF9EC4"},
	"ember": {"name": "Ember", "top": "#4A1E0C", "bottom": "#120704", "accent": "#FF7A3D"},
	"royal": {"name": "Royal", "top": "#3A1F73", "bottom": "#0C0620", "accent": "#FFD45C"},
	"paper": {"name": "Paper", "top": "#FBF6EC", "bottom": "#EADBC2", "accent": "#E8603F", "ink": "#2D2A4A", "light": true},
	"daylight": {"name": "Daylight", "top": "#E8F4FF", "bottom": "#B9D9F5", "accent": "#2F80D9", "ink": "#1E3A55", "light": true},
}

## Twin colours (one per group, in order), the capsule's roundness (fraction of
## its thickness) and how strongly it glows.
const STYLES: Dictionary = {
	"neon": {"name": "Neon", "radius": 0.5, "glow": 1.0, "colors": ["#4FE3FF", "#FF5FD2", "#B6FF5C", "#FFC24F", "#9D7BFF", "#FF7A6B", "#4FFFC1", "#5C8DFF", "#FF5F8F", "#F5F56B", "#7AF0FF", "#D98CFF"]},
	"prism": {"name": "Prism", "radius": 0.34, "glow": 1.3, "colors": ["#FF4D6D", "#FF9F1C", "#FFE14D", "#4DFF88", "#4DD8FF", "#7A5CFF", "#FF5CE1", "#5CFFE4", "#FFB86B", "#B4FF5C"]},
	"candy": {"name": "Candy", "radius": 0.5, "glow": 0.8, "colors": ["#FF8FB1", "#7FD8FF", "#B9F18C", "#FFD36E", "#C79BFF", "#FF9E7A", "#7FFFD4", "#FFB3E6", "#9FB8FF", "#F7F58A"]},
	"ember": {"name": "Ember", "radius": 0.3, "glow": 1.4, "colors": ["#FF6A2B", "#FFC145", "#FF3D5A", "#FF9F1C", "#FFD27A", "#E8513A", "#FFB070", "#FF7F50", "#F9E26B", "#FF5E8A"]},
	"glass": {"name": "Glass", "radius": 0.42, "glow": 0.55, "colors": ["#9AD0F5", "#B8E3D6", "#D6C8F5", "#F5C8D9", "#F5E3B8", "#C8F0F5", "#E0F5C8", "#F5D0B8", "#B8C8F5", "#E3B8F5"]},
	"jewel": {"name": "Jewel", "radius": 0.22, "glow": 1.2, "colors": ["#1ED37A", "#E0307A", "#2E7BFF", "#A23BFF", "#FFC21E", "#12C7B4", "#FF5A2E", "#5EA8FF", "#FF3BB0", "#9BE22E"]},
	"mono": {"name": "Mono", "radius": 0.12, "glow": 0.7, "colors": ["#FFFFFF", "#C9CEF5", "#9AA3E8", "#E0E3FF", "#B3B9F0", "#D6DAFF", "#8E97E0", "#F0F2FF", "#A9B0EE", "#C2C7F7"]},
}


static func theme_id() -> String:
	var id: String = str(Profile.setting("theme", "chapters"))
	return id if THEMES.has(id) and Profile.owns("theme_pack") else "chapters"


static func style_id() -> String:
	var id: String = str(Profile.setting("style", "neon"))
	return id if STYLES.has(id) and (id == "neon" or Profile.owns("style_pack")) else "neon"


## Sets every Style colour from the chosen theme ("Original" keeps the night
## palette). Called at start-up, on every screen change (so an ended trial
## reverts) and whenever the player picks a theme.
static func apply() -> void:
	var t: String = theme_id()
	if t == "chapters" and original_is_light():
		# Original colours in daylight: a soft lavender sky, dark text.
		_set_palette(Color("F3F4FF"), Color("D8DBF6"), Color("2A7BE0"), false, Color("1B1E4B"))
		return
	if t == "chapters":
		_set_palette(Color("1B1F4F"), Color("0A0B22"), Color("4FE3FF"), true, Color("EEF1FF"))
		Style.CARD = Color("1A1D4D")
		Style.SURFACE = Color("242862")
		Style.PANEL = Color("171A45")
		Style.LIP = Color("080920")
		Style.BOARD = Color("0C0E2A")
		Style.MUTED = Color("A9AEE0")
		Style.DIM = Color(0.02, 0.02, 0.08, 0.66)
		return
	var th: Dictionary = THEMES[t]
	var light: bool = bool(th.get("light", false))
	_set_palette(Color(th["top"]), Color(th["bottom"]), Color(th["accent"]), not light, Color(th["ink"]) if light else Color("F4F1FF"))


static func _set_palette(top: Color, bottom: Color, accent: Color, dark: bool, ink: Color) -> void:
	Style.DARK = dark
	Style.DEFAULT_SKY_TOP = top
	Style.DEFAULT_SKY_BOTTOM = bottom
	Style.AMBER = accent
	Style.INK = ink
	if dark:
		var mid: Color = top.lerp(bottom, 0.4)
		Style.MUTED = ink.lerp(top, 0.3)
		Style.CARD = mid.lightened(0.07)
		Style.SURFACE = mid.lightened(0.14)
		Style.PANEL = mid.lightened(0.04)
		Style.LIP = bottom.darkened(0.5)
		Style.BOARD = bottom.darkened(0.25)
		Style.FIELD = Color(ink, 0.07)
		Style.CARD_EDGE = Color(1, 1, 1, 0.10)
		Style.DIM = Color(bottom.darkened(0.6), 0.62)
	else:
		Style.MUTED = ink.lerp(top, 0.42)
		Style.CARD = top.lerp(Color.WHITE, 0.55)
		Style.SURFACE = Color.WHITE
		Style.PANEL = top.lerp(Color.WHITE, 0.4)
		Style.LIP = bottom.darkened(0.22)
		# The board stays a dark glass so the neon twins always read.
		Style.BOARD = ink.darkened(0.35)
		Style.FIELD = Color(ink, 0.07)
		Style.CARD_EDGE = Color(ink, 0.12)
		Style.DIM = Color(ink, 0.45)


## Settings › Appearance for the Original colours: "auto" follows the phone's
## dark mode, "dark" is the night look, "light" the daytime look.
static func appearance() -> String:
	var a: String = str(Profile.setting("appearance", "auto"))
	return a if a in ["auto", "dark", "light"] else "auto"


static func original_is_light() -> bool:
	match appearance():
		"light":
			return true
		"dark":
			return false
	return DisplayServer.is_dark_mode_supported() and not DisplayServer.is_dark_mode()


static func theme_ids() -> Array:
	return ["chapters"] + THEMES.keys()


static func style_ids() -> Array:
	return STYLES.keys()


static func theme_name(id: String) -> String:
	return "Original" if id == "chapters" else str(THEMES.get(id, {}).get("name", id))


static func style_name(id: String) -> String:
	return str(STYLES.get(id, {}).get("name", id))


## Sky colours for a chapter (or the home screen when chapter is empty).
static func sky(chapter: Dictionary) -> Array[Color]:
	var t: String = theme_id()
	if t != "chapters":
		return [Color(THEMES[t]["top"]), Color(THEMES[t]["bottom"])]
	if chapter.is_empty() or not chapter.has("sky_top"):
		return [Style.DEFAULT_SKY_TOP, Style.DEFAULT_SKY_BOTTOM]
	if original_is_light():
		# Each chapter keeps its hue, as a daytime sky.
		var hue: Color = chapter.get("accent", Style.AMBER)
		return [hue.lerp(Color.WHITE, 0.86), hue.lerp(Color.WHITE, 0.64)]
	return [chapter["sky_top"], chapter["sky_bottom"]]


static func accent(chapter: Dictionary) -> Color:
	var t: String = theme_id()
	if t != "chapters":
		return Color(THEMES[t]["accent"])
	var a: Color = chapter.get("accent", Style.AMBER)
	# Deeper on daytime skies so captions and bars keep their contrast.
	return a.darkened(0.35) if original_is_light() else a


## The twin colour for group i.
static func pair_color(i: int, style: String = "") -> Color:
	var s: Dictionary = STYLES[style if STYLES.has(style) else style_id()]
	var cols: Array = s["colors"]
	return Color(str(cols[posmod(i, cols.size())]))


## Capsule roundness as a fraction of its thickness.
static func radius(style: String = "") -> float:
	return float(STYLES[style if STYLES.has(style) else style_id()]["radius"])


static func glow(style: String = "") -> float:
	return float(STYLES[style if STYLES.has(style) else style_id()]["glow"])
