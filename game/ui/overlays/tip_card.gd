class_name TipCard
extends Overlay
## The tip jar, like Single Shot's: four quick amounts, or pick your own with
## − / + and a slider. Every amount is its own Google Play product (see
## Store.tip_amounts()), and every price shown is the player's local price from
## Store.price(), so the picker works the same in any currency.

var _status: Label
var _price: Label
var _slider: HSlider
var _custom: Button
var _presets: Dictionary = {}
## Index into Store.tip_amounts() of the selected tip.
var _index: int = 0


func build() -> void:
	name = "Tips"
	add_title("Tip jar")
	body.add_child(UIKit.para("Say thanks, as often as you like. A tip opens nothing new: it all goes into making the next chapter.", Style.SIZE_SMALL))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	body.add_child(grid)
	for amount: int in Store.TIP_PRESETS:
		var b: Button = UIKit.button(Store.price("tip_%d" % amount), "soft", Style.AMBER, 84, 28)
		b.name = "Tip_%d" % amount
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void: _tip(amount))
		grid.add_child(b)
		_presets[amount] = b
	body.add_child(UIKit.caption("Or pick your own"))
	var row: HBoxContainer = UIKit.hbox(14)
	var minus: Button = UIKit.icon_button("minus", 68)
	minus.name = "TipMinus"
	minus.pressed.connect(func() -> void: _select(_index - 1))
	row.add_child(minus)
	_price = UIKit.label("", 34, Style.INK, 600)
	_price.name = "TipPrice"
	_price.custom_minimum_size = Vector2(220, 76)
	row.add_child(_price)
	var plus: Button = UIKit.icon_button("plus", 68)
	plus.name = "TipPlus"
	plus.pressed.connect(func() -> void: _select(_index + 1))
	row.add_child(plus)
	body.add_child(row)
	_slider = UIKit.bar_slider(Style.AMBER)
	_slider.name = "TipSlider"
	_slider.min_value = 0
	_slider.max_value = Store.tip_amounts().size() - 1
	_slider.step = 1
	_slider.value_changed.connect(func(v: float) -> void:
		if int(v) != _index:
			_select(int(v))
			Audio.play("tap", 1.0 + v / _slider.max_value * 0.5, -8.0)
	)
	body.add_child(_slider)
	_custom = UIKit.button("", "primary", Style.AMBER, 88, 28, "art:heart")
	_custom.name = "TipCustom"
	_custom.pressed.connect(func() -> void: _tip(selected()))
	body.add_child(_custom)
	body.add_child(UIKit.refund_note())
	_status = UIKit.para(_thanks(), Style.SIZE_SMALL, Style.AMBER)
	_status.name = "Status"
	body.add_child(_status)
	Store.purchase_finished.connect(func(ok: bool, msg: String, id: String) -> void:
		if is_inside_tree() and (Store.is_tip(id) or id.is_empty()):
			_status.text = msg if not ok else _thanks()
			if ok:
				Audio.play("unlock", 1.0, -3.0)
	)
	Store.price_updated.connect(func(_id: String, _p: String) -> void: _refresh())
	_select(maxi(0, Store.tip_amounts().find(Store.TIP_DEFAULT)))


## The selected tip amount (the rupee value in its product id).
func selected() -> int:
	return int(Store.tip_amounts()[_index])


func _select(i: int) -> void:
	_index = clampi(i, 0, Store.tip_amounts().size() - 1)
	_slider.set_value_no_signal(_index)
	_refresh()


func _refresh() -> void:
	if _custom == null:
		return
	var p: String = Store.price("tip_%d" % selected())
	_price.text = p
	_custom.text = "Tip %s" % p
	for amount: int in _presets:
		(_presets[amount] as Button).text = Store.price("tip_%d" % amount)


func _tip(amount: int) -> void:
	_status.text = "Opening Google Play…"
	Store.buy("tip_%d" % amount)


func _thanks() -> String:
	var n: int = Profile.tips_given()
	return "" if n == 0 else "You've tipped %d %s. Thank you ♥" % [n, "time" if n == 1 else "times"]
