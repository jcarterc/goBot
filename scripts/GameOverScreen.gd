class_name GameOverScreen
extends CanvasLayer
# Death overlay. On a qualifying score the player enters 3 initials for the
# persistent leaderboard, then the leaderboard and Play Again / Change Bot show.

signal play_again
signal change_bot

var killer_type := "bot"
var _content: VBoxContainer
var _initials: LineEdit

func configure(p_killer: String) -> void:
	killer_type = p_killer

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.62)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel_style())
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-220, -220)
	panel.custom_minimum_size = Vector2(440, 0)
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	box.add_child(UITheme.title("GAME OVER", 44, Color(1, 0.45, 0.45)))
	box.add_child(UITheme.heading("eaten by a %s" % killer_type, 16, UITheme.TEXT))
	box.add_child(UITheme.heading("SCORE   %s" % _commas(GameState.score), 22, UITheme.TEXT))

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 8)
	box.add_child(_content)

	if GameState.leaderboard_qualifies(GameState.score):
		_show_initials_entry()
	else:
		_show_leaderboard_and_actions()

func _show_initials_entry() -> void:
	_clear(_content)
	_content.add_child(UITheme.heading("NEW HIGH SCORE!  Enter your initials:", 15, UITheme.ACCENT_WARM))
	_initials = LineEdit.new()
	_initials.max_length = 3
	_initials.text = "AAA"
	_initials.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_initials.custom_minimum_size = Vector2(120, 44)
	_initials.add_theme_font_size_override("font_size", 24)
	_initials.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_initials.text_changed.connect(_upcase)
	_initials.text_submitted.connect(func(_t): _submit())
	_content.add_child(_initials)
	var submit := UITheme.make_button("Submit", UITheme.ACCENT_WARM, Vector2(140, 44))
	submit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	submit.pressed.connect(_submit)
	_content.add_child(submit)
	_initials.grab_focus()
	_initials.select_all()

func _upcase(t: String) -> void:
	var up := t.to_upper()
	if up != t:
		_initials.text = up
		_initials.caret_column = up.length()

func _submit() -> void:
	GameState.add_leaderboard_entry(_initials.text, GameState.score)
	_show_leaderboard_and_actions()

func _show_leaderboard_and_actions() -> void:
	_clear(_content)
	_content.add_child(UITheme.heading("LEADERBOARD", 14, UITheme.ACCENT_WARM))
	if GameState.leaderboard.is_empty():
		_content.add_child(UITheme.heading("no records yet", 13, Color(0.7, 0.75, 0.85)))
	else:
		var n: int = mini(8, GameState.leaderboard.size())
		for i in n:
			var e: Dictionary = GameState.leaderboard[i]
			var color := UITheme.ACCENT_WARM if int(e["score"]) == GameState.score else UITheme.TEXT
			_content.add_child(UITheme.heading("%d.   %s    %s" % [i + 1, e["name"], _commas(int(e["score"]))], 14, color))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(row)
	var again := UITheme.make_button("Play Again", UITheme.ACCENT, Vector2(150, 50))
	again.pressed.connect(func(): play_again.emit())
	row.add_child(again)
	var change := UITheme.make_button("Change Bot", UITheme.ACCENT, Vector2(150, 50))
	change.pressed.connect(func(): change_bot.emit())
	row.add_child(change)

func _clear(node: Node) -> void:
	for c in node.get_children():
		c.queue_free()

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
