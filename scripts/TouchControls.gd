class_name TouchControls
extends CanvasLayer
# On-screen controls for phones/tablets. Left half is a dynamic virtual
# joystick (movement); right half is a look-drag region. Bottom-right buttons
# toggle the camera view and, for flyers, climb/descend. Auto-shown on touch
# devices; can be toggled from the lobby or with the T key.

signal view_toggled
signal dash_pressed
signal ability_pressed

const JOY_RADIUS := 90.0

var bot_type := "roller"

# Consumed by CameraController each frame.
var move_vec := Vector2.ZERO   # x = strafe, y = forward(+)/back(-)
var look_delta := Vector2.ZERO
var vertical := 0.0

var _move_finger := -1
var _look_finger := -1
var _btn_finger := -1
var _move_origin := Vector2.ZERO

var _joy_base: Panel
var _joy_knob: Panel
var _view_btn: Panel
var _dash_btn: Panel
var _ability_btn: Panel
var _up_btn: Panel
var _down_btn: Panel

func setup(p_player: Bot) -> void:
	if p_player:
		bot_type = p_player.bot_type

func _ready() -> void:
	layer = 5
	_joy_base = _circle(JOY_RADIUS * 2.0, Color(1, 1, 1, 0.12))
	_joy_base.visible = false
	add_child(_joy_base)
	_joy_knob = _circle(70.0, Color(1, 1, 1, 0.30))
	_joy_knob.visible = false
	add_child(_joy_knob)

	_view_btn = _button("VIEW")
	add_child(_view_btn)
	_dash_btn = _button("DASH")
	add_child(_dash_btn)
	_ability_btn = _button("POWER")
	add_child(_ability_btn)
	if bot_type == "flyer":
		_up_btn = _button("▲")
		add_child(_up_btn)
		_down_btn = _button("▼")
		add_child(_down_btn)
	_layout_buttons()

func _circle(diameter: float, color: Color) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(diameter, diameter)
	p.size = Vector2(diameter, diameter)
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(diameter / 2.0))
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

func _button(text: String) -> Panel:
	var p := Panel.new()
	p.size = Vector2(96, 70)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.18)
	sb.set_corner_radius_all(12)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 22)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p

func _layout_buttons() -> void:
	var s := get_viewport().get_visible_rect().size
	_view_btn.position = Vector2(s.x - 116, s.y - 90)
	_dash_btn.position = Vector2(s.x - 224, s.y - 90)
	_ability_btn.position = Vector2(s.x - 224, s.y - 170)
	if _up_btn:
		_up_btn.position = Vector2(s.x - 116, s.y - 250)
		_down_btn.position = Vector2(s.x - 116, s.y - 170)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_layout_buttons()
		if event.pressed:
			_on_press(event.index, event.position)
		else:
			_on_release(event.index)
	elif event is InputEventScreenDrag:
		_on_drag(event.index, event.position, event.relative)

func _on_press(index: int, pos: Vector2) -> void:
	if _hit(_view_btn, pos):
		view_toggled.emit()
		return
	if _hit(_dash_btn, pos):
		dash_pressed.emit()
		return
	if _hit(_ability_btn, pos):
		ability_pressed.emit()
		return
	if _up_btn and _hit(_up_btn, pos):
		_btn_finger = index
		vertical = 1.0
		return
	if _down_btn and _hit(_down_btn, pos):
		_btn_finger = index
		vertical = -1.0
		return
	var half := get_viewport().get_visible_rect().size.x * 0.5
	if pos.x < half and _move_finger == -1:
		_move_finger = index
		_move_origin = pos
		_joy_base.position = pos - _joy_base.size * 0.5
		_joy_knob.position = pos - _joy_knob.size * 0.5
		_joy_base.visible = true
		_joy_knob.visible = true
	elif _look_finger == -1:
		_look_finger = index

func _on_release(index: int) -> void:
	if index == _move_finger:
		_move_finger = -1
		move_vec = Vector2.ZERO
		_joy_base.visible = false
		_joy_knob.visible = false
	elif index == _look_finger:
		_look_finger = -1
	elif index == _btn_finger:
		_btn_finger = -1
		vertical = 0.0

func _on_drag(index: int, pos: Vector2, relative: Vector2) -> void:
	if index == _move_finger:
		var off := pos - _move_origin
		if off.length() > JOY_RADIUS:
			off = off.normalized() * JOY_RADIUS
		_joy_knob.position = _move_origin + off - _joy_knob.size * 0.5
		move_vec = Vector2(off.x / JOY_RADIUS, -off.y / JOY_RADIUS)
	elif index == _look_finger:
		look_delta += relative

func _hit(panel: Panel, pos: Vector2) -> bool:
	return panel != null and Rect2(panel.position, panel.size).has_point(pos)

# Camera consumes and clears the accumulated look each frame.
func consume_look() -> Vector2:
	var d := look_delta
	look_delta = Vector2.ZERO
	return d
