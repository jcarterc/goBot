class_name Lobby
extends CanvasLayer
# Pre-game screen: pick a bot type and world density, then start. Also exposes
# the on-screen touch-controls toggle (auto-enabled on touch devices).

signal start_game

var _bot_type := "roller"
var _density := GameState.Density.DENSE
var _custom := 60

var _bot_buttons := {}
var _density_buttons := {}
var _slider: HSlider
var _slider_label: Label
var _touch_check: CheckButton

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.10, 0.14, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	root.set_anchors_preset(Control.PRESET_CENTER)
	root.position = Vector2(-220, -230)
	root.custom_minimum_size = Vector2(440, 0)
	add_child(root)

	root.add_child(_title("goBot ARENA", 40))
	root.add_child(_title("Eat smaller bots. Grow. Survive.", 16))

	root.add_child(_heading("CHOOSE YOUR BOT"))
	var bot_row := HBoxContainer.new()
	bot_row.add_theme_constant_override("separation", 10)
	bot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(bot_row)
	for t in ["walker", "roller", "flyer"]:
		var b := Button.new()
		b.text = t.capitalize()
		b.custom_minimum_size = Vector2(130, 46)
		b.pressed.connect(_select_bot.bind(t))
		bot_row.add_child(b)
		_bot_buttons[t] = b

	root.add_child(_heading("WORLD DENSITY"))
	var dens_row := HBoxContainer.new()
	dens_row.add_theme_constant_override("separation", 8)
	dens_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(dens_row)
	var labels := {
		GameState.Density.SPARSE: "Sparse",
		GameState.Density.DENSE: "Dense",
		GameState.Density.INDIA: "India",
		GameState.Density.CUSTOM: "Custom",
	}
	for d in labels:
		var b := Button.new()
		b.text = labels[d]
		b.custom_minimum_size = Vector2(100, 40)
		b.pressed.connect(_select_density.bind(d))
		dens_row.add_child(b)
		_density_buttons[d] = b

	_slider_label = _title("Custom: 60 bots", 15)
	root.add_child(_slider_label)
	_slider = HSlider.new()
	_slider.min_value = 10
	_slider.max_value = 250
	_slider.step = 1
	_slider.value = 60
	_slider.custom_minimum_size = Vector2(0, 24)
	_slider.value_changed.connect(_on_slider)
	root.add_child(_slider)

	_touch_check = CheckButton.new()
	_touch_check.text = "On-screen touch controls"
	_touch_check.button_pressed = GameState.touch_enabled
	_touch_check.toggled.connect(func(v): GameState.touch_enabled = v)
	root.add_child(_touch_check)

	var play := Button.new()
	play.text = "PLAY"
	play.custom_minimum_size = Vector2(0, 56)
	play.add_theme_font_size_override("font_size", 24)
	play.pressed.connect(_on_play)
	root.add_child(play)

	_select_bot(_bot_type)
	_select_density(_density)

func _title(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _heading(text: String) -> Label:
	var l := _title(text, 14)
	l.add_theme_color_override("font_color", Color(0.6, 0.75, 0.95))
	return l

func _select_bot(t: String) -> void:
	_bot_type = t
	for key in _bot_buttons:
		_bot_buttons[key].modulate = Color(1, 1, 0.5) if key == t else Color.WHITE

func _select_density(d: int) -> void:
	_density = d
	for key in _density_buttons:
		_density_buttons[key].modulate = Color(1, 1, 0.5) if key == d else Color.WHITE
	var is_custom := d == GameState.Density.CUSTOM
	_slider.visible = is_custom
	_slider_label.visible = is_custom

func _on_slider(v: float) -> void:
	_custom = int(v)
	_slider_label.text = "Custom: %d bots" % _custom

func _on_play() -> void:
	GameState.player_bot_type = _bot_type
	GameState.density_mode = _density
	GameState.custom_count = _custom
	start_game.emit()
