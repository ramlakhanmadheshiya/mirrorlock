extends SceneTree
## Renders the PNG launcher icons Android needs from the SVG sources, the web
## icon, the boot splash and the Play Store icon.
##
##   godot --headless --path . -s res://tools/render_icons.gd

const JOBS: Array = [
	["res://assets/icon.svg", "res://assets/android/icon_main.png", 192],
	["res://assets/android/icon_foreground.svg", "res://assets/android/icon_foreground.png", 432],
	["res://assets/android/icon_background.svg", "res://assets/android/icon_background.png", 432],
	["res://assets/icon.svg", "res://web/images/icon-512.png", 512],
]


func _init() -> void:
	for job: Array in JOBS:
		var img: Image = Image.new()
		var svg: String = FileAccess.get_file_as_string(job[0])
		var err: Error = img.load_svg_from_string(svg, float(job[2]) / 1024.0)
		if err != OK:
			push_error("cannot render %s" % job[0])
			quit(1)
			return
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(str(job[1]).get_base_dir()))
		img.save_png(job[1])
		print("wrote %s (%dx%d)" % [job[1], img.get_width(), img.get_height()])
	# Play icon: a full-bleed square (Play rounds the corners itself), no transparency.
	var play: Image = Image.new()
	play.load_svg_from_string(FileAccess.get_file_as_string("res://assets/icon.svg").replace('rx="232"', 'rx="0"'), 0.5)
	play.convert(Image.FORMAT_RGB8)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://store"))
	play.save_png("res://store/icon_512.png")
	print("wrote res://store/icon_512.png")
	# Boot splash: the icon's twins on the splash colour, centred on a tall canvas.
	var splash: Image = Image.create(720, 1280, false, Image.FORMAT_RGBA8)
	splash.fill(Color("0B0C24"))
	var mark: Image = Image.new()
	mark.load_svg_from_string(FileAccess.get_file_as_string("res://assets/android/icon_foreground.svg"), 340.0 / 1024.0)
	splash.blend_rect(mark, Rect2i(Vector2i.ZERO, mark.get_size()), Vector2i((720 - mark.get_width()) / 2, (1280 - mark.get_height()) / 2 - 70))
	splash.save_png("res://assets/splash.png")
	print("wrote res://assets/splash.png")
	quit(0)
