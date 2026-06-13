class_name CameraController
extends Node3D
# Yaw pivot carrying the Camera3D. Soft-follows the player bot in third person
# (default) or sits inside it in first person (F1 / V). Translates WASD + mouse
# into the player's steering direction; the bot moves where the camera faces.

const MOUSE_SENS := 0.0025
const FOLLOW_LAG := 0.12

var player: Bot
var camera: Camera3D
var touch: TouchControls
var third_person := true
var pitch := -0.25
var _trauma := 0.0

func setup(p_player: Bot) -> void:
	player = p_player

func add_trauma(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)

func toggle_view() -> void:
	third_person = not third_person
	_apply_view()

func _ready() -> void:
	camera = Camera3D.new()
	camera.far = 400.0
	camera.current = true
	add_child(camera)
	if player:
		global_position = player.global_position
	_apply_view()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENS)
		pitch = clampf(pitch - event.relative.y * MOUSE_SENS, -1.3, 0.9)
		_apply_view()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1 or event.keycode == KEY_V:
			toggle_view()
		elif event.keycode == KEY_T:
			GameState.touch_enabled = not GameState.touch_enabled
			if touch:
				touch.visible = GameState.touch_enabled
		elif event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player) or not player.alive:
		return
	# Follow the player; third person lags slightly for feel.
	var follow := FOLLOW_LAG if third_person else 1.0
	global_position = global_position.lerp(player.global_position, follow)
	# Touch look-drag rotates the camera the same way mouse motion does.
	if touch != null and is_instance_valid(touch) and GameState.touch_enabled:
		var d := touch.consume_look()
		if d != Vector2.ZERO:
			rotate_y(-d.x * MOUSE_SENS)
			pitch = clampf(pitch - d.y * MOUSE_SENS, -1.3, 0.9)
	_apply_view()
	_apply_shake(delta)
	_drive_player()

func _apply_shake(delta: float) -> void:
	if _trauma <= 0.0:
		return
	_trauma = maxf(_trauma - delta * 1.6, 0.0)
	var s := _trauma * _trauma
	camera.rotation += Vector3(
		randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 0.06 * s

func _apply_view() -> void:
	if camera == null:
		return
	var size: float = player.size_tier if player else 1.0
	if third_person:
		var back := clampf(8.0 + size * 2.0, 8.0, 24.0)
		var up := clampf(4.0 + size, 5.0, 13.0)
		camera.position = Vector3(0, up, back)
		camera.rotation = Vector3(pitch, 0, 0)
	else:
		camera.position = Vector3(0, clampf(1.2 * size, 1.0, 6.0), 0)
		camera.rotation = Vector3(pitch, 0, 0)
	# FOV widens slightly as the player grows for a sense of scale.
	camera.fov = clampf(70.0 + size * 2.5, 70.0, 100.0)

func _drive_player() -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# Touch joystick overrides when active (y is forward-positive there).
	if touch != null and GameState.touch_enabled and touch.move_vec != Vector2.ZERO:
		input = Vector2(touch.move_vec.x, -touch.move_vec.y)
	var dir := (global_transform.basis * Vector3(input.x, 0, input.y))
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.ZERO
	# Flyers climb/descend with Space / Shift or the on-screen buttons.
	if player.bot_type == "flyer":
		var vy := 0.0
		if Input.is_key_pressed(KEY_SPACE):
			vy += 1.0
		if Input.is_key_pressed(KEY_SHIFT):
			vy -= 1.0
		if touch != null and GameState.touch_enabled:
			vy += touch.vertical
		dir.y = clampf(vy, -1.0, 1.0)
	player.desired_dir = dir
