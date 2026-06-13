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
var _lb_box: Control

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
		var b := UITheme.make_button(t.capitalize(), UITheme.ACCENT, Vector2(130, 46))
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
		var b := UITheme.make_button(labels[d], UITheme.ACCENT, Vector2(100, 40))
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

	root.add_child(_heading("BOT SKIN"))
	var skin_row := HBoxContainer.new()
	skin_row.add_theme_constant_override("separation", 6)
	skin_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(skin_row)
	for i in GameState.SKINS.size():
		var info: Dictionary = GameState.SKINS[i]
		var unlocked := GameState.skin_unlocked(i)
		var b := UITheme.make_button(info["name"] if unlocked else "🔒 %d" % int(info["unlock"]), UITheme.ACCENT, Vector2(96, 36))
		b.disabled = not unlocked
		if unlocked:
			b.pressed.connect(func(): GameState.selected_skin = i)
		skin_row.add_child(b)

	_touch_check = CheckButton.new()
	_touch_check.text = "On-screen touch controls"
	_touch_check.button_pressed = GameState.touch_enabled
	_touch_check.toggled.connect(func(v): GameState.touch_enabled = v)
	root.add_child(_touch_check)

	var daily := CheckButton.new()
	daily.text = "Daily Challenge (today's seed)"
	daily.button_pressed = GameState.daily_mode
	daily.toggled.connect(_on_daily_toggled)
	root.add_child(daily)

	var metab := CheckButton.new()
	metab.text = "Metabolism (shrink when not eating)"
	metab.button_pressed = GameState.metabolism
	metab.toggled.connect(func(v): GameState.metabolism = v)
	root.add_child(metab)

	var play := UITheme.make_button("PLAY", UITheme.ACCENT_WARM, Vector2(0, 56))
	play.add_theme_font_size_override("font_size", 24)
	play.pressed.connect(_on_play)
	root.add_child(play)

	root.add_child(_build_stats())
	_lb_box = _build_leaderboard()
	root.add_child(_lb_box)

	_select_bot(_bot_type)
	_select_density(_density)

func _on_daily_toggled(v: bool) -> void:
	GameState.daily_mode = v
	# Rebuild the leaderboard to show the relevant board.
	if _lb_box != null and is_instance_valid(_lb_box):
		var parent := _lb_box.get_parent()
		var idx := _lb_box.get_index()
		_lb_box.queue_free()
		_lb_box = _build_leaderboard()
		parent.add_child(_lb_box)
		parent.move_child(_lb_box, idx)

func _build_stats() -> Control:
	var s := GameState.stats
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	box.add_child(_heading("LIFETIME", 12, Color(0.6, 0.7, 0.85)))
	box.add_child(_heading("games %d   eaten %d   biggest %.1f   best run %.0fs" % [
		int(s.get("games", 0)), int(s.get("bots_eaten", 0)),
		float(s.get("biggest", 0.0)), float(s.get("longest", 0.0))], 12, Color(0.7, 0.75, 0.85)))
	return box

func _build_leaderboard() -> Control:
	var board := GameState.active_leaderboard()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var title := "DAILY HIGH SCORES" if GameState.daily_mode else "HIGH SCORES"
	box.add_child(UITheme.heading(title, 13, UITheme.ACCENT_WARM))
	if board.is_empty():
		box.add_child(UITheme.heading("no records yet — be the first", 12, Color(0.6, 0.65, 0.75)))
	else:
		var n: int = mini(5, board.size())
		for i in n:
			var e: Dictionary = board[i]
			box.add_child(UITheme.heading("%d.  %s   %s" % [i + 1, e["name"], _commas(int(e["score"]))], 13, UITheme.TEXT))
	return box

func _commas(n: int) -> String:
	var s := str(n)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return out

func _title(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _heading(text: String, size := 14, color := Color(0.6, 0.75, 0.95)) -> Label:
	var l := _title(text, size)
	l.add_theme_color_override("font_color", color)
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
