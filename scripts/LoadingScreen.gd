class_name LoadingScreen
extends CanvasLayer
# Shown while the arena world is being generated (a few seconds of blocking
# work). Gives immediate feedback instead of a frozen previous screen.

var _spinner: TextureRect

func _ready() -> void:
	layer = 30
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.07, 0.12, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_spinner = TextureRect.new()
	_spinner.texture = _make_ring()
	_spinner.custom_minimum_size = Vector2(72, 72)
	_spinner.size = Vector2(72, 72)
	_spinner.pivot_offset = Vector2(36, 36)
	_spinner.set_anchors_preset(Control.PRESET_CENTER)
	_spinner.position = Vector2(-36, -70)
	add_child(_spinner)

	var label := UITheme.title("GENERATING WORLD", 26, UITheme.ACCENT)
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.position = Vector2(-200, 10)
	label.custom_minimum_size = Vector2(400, 0)
	add_child(label)

func _process(delta: float) -> void:
	if _spinner:
		_spinner.rotation += delta * 6.0

# An open arc ring so rotation reads clearly.
func _make_ring() -> ImageTexture:
	var n := 72
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := Vector2(n, n) * 0.5
	for y in n:
		for x in n:
			var p := Vector2(x, y) - c
			var dist := p.length()
			var ang := atan2(p.y, p.x)
			var on := dist > 26.0 and dist < 34.0 and ang < 1.4
			img.set_pixel(x, y, Color(0.4, 0.75, 1.0, 1.0) if on else Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)
