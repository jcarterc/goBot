class_name FloatingText
extends Label3D
# A short-lived 3D label that floats upward and fades. Used for "+score" popups
# and power-up names. Always faces the camera.

func setup(content: String, color: Color) -> void:
	text = content
	modulate = color
	font_size = 96
	pixel_size = 0.01
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	outline_size = 12
	outline_modulate = Color(0, 0, 0, 0.8)

func _ready() -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position:y", position.y + 2.5, 1.0)
	tw.tween_property(self, "modulate:a", 0.0, 1.0).set_delay(0.2)
	tw.chain().tween_callback(queue_free)

static func spawn(host: Node, pos: Vector3, content: String, color: Color) -> void:
	if host == null:
		return
	var ft := FloatingText.new()
	host.add_child(ft)
	ft.global_position = pos
	ft.setup(content, color)
