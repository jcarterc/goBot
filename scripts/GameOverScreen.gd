class_name GameOverScreen
extends CanvasLayer
# Overlay shown on death. Play Again restarts with the same bot + density;
# Change Bot returns to the lobby.

signal play_again
signal change_bot

var killer_type := "bot"

func configure(p_killer: String) -> void:
	killer_type = p_killer

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-180, -150)
	box.custom_minimum_size = Vector2(360, 0)
	add_child(box)

	box.add_child(_label("GAME OVER", 44, Color(1, 0.4, 0.4)))
	box.add_child(_label("You were eaten by a %s" % killer_type, 18, Color.WHITE))
	box.add_child(_label("SCORE      %s" % _commas(GameState.score), 22, Color.WHITE))
	box.add_child(_label("YOUR BEST  %s" % _commas(GameState.best), 18, Color(0.8, 0.85, 0.95)))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	var again := Button.new()
	again.text = "Play Again"
	again.custom_minimum_size = Vector2(150, 50)
	again.pressed.connect(func(): play_again.emit())
	row.add_child(again)
	var change := Button.new()
	change.text = "Change Bot"
	change.custom_minimum_size = Vector2(150, 50)
	change.pressed.connect(func(): change_bot.emit())
	row.add_child(change)

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

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
