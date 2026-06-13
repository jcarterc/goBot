class_name UITheme
extends RefCounted
# Shared styling helpers for the menus: rounded buttons with hover/press states,
# headings, panels, and a click sound. Keeps Lobby / GameOver / Title consistent.

const BG := Color(0.05, 0.07, 0.12)
const ACCENT := Color(0.36, 0.72, 1.0)
const ACCENT_WARM := Color(1.0, 0.78, 0.3)
const TEXT := Color(0.92, 0.95, 1.0)

static func _sb(bg: Color, border: Color, border_w := 2, radius := 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb

static func style_button(btn: Button, accent := ACCENT) -> void:
	var base := Color(accent.r, accent.g, accent.b, 0.16)
	var hover := Color(accent.r, accent.g, accent.b, 0.34)
	var press := Color(accent.r, accent.g, accent.b, 0.5)
	btn.add_theme_stylebox_override("normal", _sb(base, accent))
	btn.add_theme_stylebox_override("hover", _sb(hover, accent, 2))
	btn.add_theme_stylebox_override("pressed", _sb(press, Color.WHITE, 2))
	btn.add_theme_stylebox_override("focus", _sb(hover, accent, 2))
	btn.add_theme_color_override("font_color", TEXT)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 18)
	# Click sound on press.
	btn.pressed.connect(play_click.bind(btn))

static func make_button(text: String, accent := ACCENT, min_size := Vector2(130, 46)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	style_button(b, accent)
	return b

static func heading(text: String, size := 14, color := ACCENT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

static func title(text: String, size: int, color := TEXT) -> Label:
	var l := heading(text, size, color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	return l

static func panel_style() -> StyleBoxFlat:
	var sb := _sb(Color(0.10, 0.13, 0.20, 0.92), Color(0.3, 0.45, 0.7, 0.6), 2, 16)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 24
	sb.content_margin_bottom = 24
	return sb

static func play_click(ctx: Node) -> void:
	if ctx == null or not ctx.is_inside_tree():
		return
	var p := AudioStreamPlayer.new()
	p.stream = SoundSynth.ui_click()
	p.bus = "Master"
	ctx.get_tree().root.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
