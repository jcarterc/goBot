class_name HUD
extends CanvasLayer

var _slots: Array[Panel] = []
var _selected := 0

func _ready() -> void:
	_build_crosshair()
	_build_hotbar()
	_build_help()

func _build_crosshair() -> void:
	var cross := Label.new()
	cross.text = "+"
	cross.add_theme_font_size_override("font_size", 28)
	cross.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cross.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cross.position = Vector2(-8, -18)
	add_child(cross)

func _build_hotbar() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	row.position = Vector2(-((Blocks.PLACEABLE.size() * 52) / 2.0), -70)
	add_child(row)
	for i in Blocks.PLACEABLE.size():
		var id: int = Blocks.PLACEABLE[i]
		var panel := Panel.new()
		panel.custom_minimum_size = Vector2(46, 46)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Blocks.COLORS[id]["side"]
		sb.border_color = Color(0.1, 0.1, 0.1)
		sb.set_border_width_all(2)
		panel.add_theme_stylebox_override("panel", sb)
		var num := Label.new()
		num.text = str(i + 1)
		num.add_theme_font_size_override("font_size", 12)
		num.position = Vector2(3, 1)
		panel.add_child(num)
		row.add_child(panel)
		_slots.append(panel)
	set_selected(0)

func _build_help() -> void:
	var help := Label.new()
	help.text = "Click to capture mouse  •  WASD move  •  Space jump  •  Shift sprint\nLeft-click break  •  Right-click place  •  1-7 / wheel select block  •  Esc release"
	help.add_theme_font_size_override("font_size", 13)
	help.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	help.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	help.add_theme_constant_override("outline_size", 4)
	help.set_anchors_preset(Control.PRESET_TOP_WIDE)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.position = Vector2(0, 8)
	add_child(help)

func set_selected(index: int) -> void:
	_selected = index
	for i in _slots.size():
		var sb: StyleBoxFlat = _slots[i].get_theme_stylebox("panel")
		if i == index:
			sb.border_color = Color(1, 1, 0.4)
			sb.set_border_width_all(4)
		else:
			sb.border_color = Color(0.1, 0.1, 0.1)
			sb.set_border_width_all(2)
