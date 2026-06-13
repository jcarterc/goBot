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
var _death_focus: Bot

func setup(p_player: Bot) -> void:
	player = p_player

func add_trauma(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)

func death_focus(target: Bot) -> void:
	_death_focus = target

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
	# On touch devices the on-screen controls own look/move; ignore mouse here
	# so emulated/stray pointer events can't double-rotate the camera.
	var touch_mode := GameState.touch_enabled
	if not touch_mode and event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif event.button_index == MOUSE_BUTTON_RIGHT and player != null:
			player.try_dash()
	elif not touch_mode and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENS)
		pitch = clampf(pitch - event.relative.y * MOUSE_SENS, -1.3, 0.9)
		_apply_view()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_CTRL and player != null:
			player.try_dash()
		elif (event.keycode == KEY_Q or event.keycode == KEY_E) and player != null:
			player.use_ability()
		elif event.keycode == KEY_F1 or event.keycode == KEY_V:
			toggle_view()
		elif event.keycode == KEY_T:
			GameState.touch_enabled = not GameState.touch_enabled
			if touch:
				touch.visible = GameState.touch_enabled
		elif event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	# Death cam: frame the killer during the slow-mo beat.
	if _death_focus != null and is_instance_valid(_death_focus):
		var mid := (player.global_position + _death_focus.global_position) * 0.5
		global_position = global_position.lerp(mid, 0.1)
		_apply_view()
		var look := _death_focus.global_position
		if camera.global_position.distance_to(look) > 0.6:
			camera.look_at(look, Vector3.UP)
		_apply_shake(delta)
		return
	if not player.alive:
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
	_clamp_camera()
	_drive_player()

# Keep the camera from dipping below the terrain (which made the ground look
# see-through from underneath).
func _clamp_camera() -> void:
	if camera == null or player == null or player.world == null:
		return
	var cg := camera.global_position
	var floor_y := player.world.ground_y(floori(cg.x), floori(cg.z)) + 1.2
	if cg.y < floor_y:
		camera.global_position.y = floor_y

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
		# Katamari-style: the camera pulls way out as the player grows.
		var back := clampf(8.0 + size * 3.2, 8.0, 64.0)
		var up := clampf(4.0 + size * 1.6, 5.0, 34.0)
		camera.position = Vector3(0, up, back)
		camera.rotation = Vector3(pitch, 0, 0)
		camera.far = maxf(400.0, back * 8.0)
	else:
		camera.position = Vector3(0, clampf(1.2 * size, 1.0, 6.0), 0)
		camera.rotation = Vector3(pitch, 0, 0)
	# FOV widens as the player grows for a sense of scale.
	camera.fov = clampf(68.0 + size * 2.2, 68.0, 102.0)

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
