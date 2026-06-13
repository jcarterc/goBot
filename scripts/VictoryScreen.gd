class_name VictoryScreen
extends CanvasLayer
# Shown when the player reaches apex size. The arc's "domination" beat: keep
# playing (the world keeps escalating, so death is still possible) or restart.

signal keep_playing
signal new_game

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.06, 0.02, 0.62)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel_style())
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-220, -170)
	panel.custom_minimum_size = Vector2(440, 0)
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	box.add_child(UITheme.title("DOMINATION", 46, UITheme.ACCENT_WARM))
	box.add_child(UITheme.heading("Nothing in the world rivals you now.", 16, UITheme.TEXT))
	box.add_child(UITheme.heading("SCORE   %s" % _commas(GameState.score), 22, UITheme.TEXT))
	box.add_child(UITheme.heading("BEST    %s" % _commas(GameState.best), 16, Color(0.8, 0.85, 0.95)))
	box.add_child(UITheme.heading("But apex predators still rise. How long can you reign?", 13, Color(0.75, 0.8, 0.9)))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	var keep := UITheme.make_button("Keep Dominating", UITheme.ACCENT_WARM, Vector2(180, 50))
	keep.pressed.connect(func(): keep_playing.emit())
	row.add_child(keep)
	var restart := UITheme.make_button("New Game", UITheme.ACCENT, Vector2(150, 50))
	restart.pressed.connect(func(): new_game.emit())
	row.add_child(restart)

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
