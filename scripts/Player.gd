class_name Player
extends CharacterBody3D

const SPEED := 6.0
const SPRINT := 10.0
const JUMP_VELOCITY := 8.0
const GRAVITY := 24.0
const TERMINAL := 30.0
const JUMP_BUFFER := 0.12  # seconds a jump press stays queued waiting to land
const MOUSE_SENSITIVITY := 0.0025
const REACH := 6.0

# Player AABB: feet at `position`, half-width horizontally, full height up.
const HALF_W := 0.3
const HEIGHT := 1.8

@onready var camera: Camera3D = $Camera3D
@onready var world: World = get_parent()

var pitch := 0.0
var selected_index := 0
var hud: HUD
var grounded := false
var _jump_buffer := 0.0

func _ready() -> void:
	# Spawn above the terrain column at origin.
	var sy := world.spawn_height(0, 0)
	position = Vector3(0.5, sy, 0.5)
	add_to_group("player")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			_break_block()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_place_block()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cycle_hotbar(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cycle_hotbar(1)
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		pitch = clampf(pitch - event.relative.y * MOUSE_SENSITIVITY, -1.5, 1.5)
		camera.rotation.x = pitch
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif event.keycode >= KEY_1 and event.keycode <= KEY_7:
			selected_index = event.keycode - KEY_1
			_update_hud()

func _physics_process(delta: float) -> void:
	# Buffer the jump press so a slightly-early tap still fires on landing.
	if Input.is_action_just_pressed("jump"):
		_jump_buffer = JUMP_BUFFER
	_jump_buffer = maxf(_jump_buffer - delta, 0.0)

	velocity.y = maxf(velocity.y - GRAVITY * delta, -TERMINAL)
	if _jump_buffer > 0.0 and grounded:
		velocity.y = JUMP_VELOCITY
		_jump_buffer = 0.0
		grounded = false

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var speed := SPRINT if Input.is_key_pressed(KEY_SHIFT) else SPEED
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	# Manual AABB-vs-voxel collision: move each axis independently and resolve
	# against the block grid. Avoids capsule-vs-trimesh edge-normal artifacts.
	grounded = false
	_move_axis(1, velocity.y * delta)
	_move_axis(0, velocity.x * delta)
	_move_axis(2, velocity.z * delta)

	# Fell out of the world — respawn.
	if position.y < -10:
		position = Vector3(0.5, world.spawn_height(0, 0), 0.5)
		velocity = Vector3.ZERO

	_publish_state()

# Move along one axis (0=X,1=Y,2=Z) and snap out of any solid voxel hit.
func _move_axis(axis: int, amount: float) -> void:
	if amount == 0.0:
		return
	var p := position
	p[axis] += amount
	position = p
	if not _overlaps_solid():
		return
	# Collision: snap flush to the block boundary we crossed.
	if axis == 1:
		if amount < 0.0:
			position.y = floorf(position.y) + 1.0
			grounded = true
		else:
			position.y = ceilf(position.y + HEIGHT) - HEIGHT - 1.0
		velocity.y = 0.0
	elif axis == 0:
		position.x = (floorf(position.x + HALF_W) - HALF_W) if amount > 0.0 else (floorf(position.x - HALF_W) + 1.0 + HALF_W)
		velocity.x = 0.0
	else:
		position.z = (floorf(position.z + HALF_W) - HALF_W) if amount > 0.0 else (floorf(position.z - HALF_W) + 1.0 + HALF_W)
		velocity.z = 0.0

# True if the player's AABB overlaps any solid voxel.
func _overlaps_solid() -> bool:
	var minx := floori(position.x - HALF_W)
	var maxx := floori(position.x + HALF_W)
	var miny := floori(position.y + 0.02)
	var maxy := floori(position.y + HEIGHT - 0.02)
	var minz := floori(position.z - HALF_W)
	var maxz := floori(position.z + HALF_W)
	for gx in range(minx, maxx + 1):
		for gy in range(miny, maxy + 1):
			for gz in range(minz, maxz + 1):
				if Blocks.is_solid(world.get_block(gx, gy, gz)):
					return true
	return false

# --- Block interaction ---

func _break_block() -> void:
	var hit := _raycast_voxel()
	if hit.is_empty():
		return
	world.set_block(hit.block.x, hit.block.y, hit.block.z, Blocks.AIR)

func _place_block() -> void:
	var hit := _raycast_voxel()
	if hit.is_empty():
		return
	var p: Vector3i = hit.block + hit.normal
	# Don't place a block inside the player's own body.
	var feet := Vector3i(floori(position.x), floori(position.y), floori(position.z))
	var head := feet + Vector3i(0, 1, 0)
	if p == feet or p == head:
		return
	world.set_block(p.x, p.y, p.z, Blocks.PLACEABLE[selected_index])

# DDA voxel traversal from the camera along its forward vector.
func _raycast_voxel() -> Dictionary:
	var origin := camera.global_position
	var dir := -camera.global_transform.basis.z.normalized()
	var voxel := Vector3i(floori(origin.x), floori(origin.y), floori(origin.z))
	var step := Vector3i(signf(dir.x), signf(dir.y), signf(dir.z))
	var t_delta := Vector3(
		INF if dir.x == 0 else abs(1.0 / dir.x),
		INF if dir.y == 0 else abs(1.0 / dir.y),
		INF if dir.z == 0 else abs(1.0 / dir.z))
	var t_max := Vector3(
		_first_cross(origin.x, dir.x),
		_first_cross(origin.y, dir.y),
		_first_cross(origin.z, dir.z))
	var normal := Vector3i.ZERO
	var dist := 0.0
	while dist <= REACH:
		if Blocks.is_solid(world.get_block(voxel.x, voxel.y, voxel.z)):
			return {"block": voxel, "normal": normal}
		if t_max.x < t_max.y and t_max.x < t_max.z:
			voxel.x += step.x
			dist = t_max.x
			t_max.x += t_delta.x
			normal = Vector3i(-step.x, 0, 0)
		elif t_max.y < t_max.z:
			voxel.y += step.y
			dist = t_max.y
			t_max.y += t_delta.y
			normal = Vector3i(0, -step.y, 0)
		else:
			voxel.z += step.z
			dist = t_max.z
			t_max.z += t_delta.z
			normal = Vector3i(0, 0, -step.z)
	return {}

func _first_cross(o: float, d: float) -> float:
	if d == 0:
		return INF
	var cell := floorf(o)
	if d > 0:
		return (cell + 1.0 - o) / d
	return (o - cell) / -d

func _cycle_hotbar(dir: int) -> void:
	selected_index = wrapi(selected_index + dir, 0, Blocks.PLACEABLE.size())
	_update_hud()

func _update_hud() -> void:
	if hud and hud.has_method("set_selected"):
		hud.set_selected(selected_index)

var _frame := 0

# Expose live state to the browser so Playwright can assert on real game logic.
func _publish_state() -> void:
	if not OS.has_feature("web"):
		return
	_frame += 1
	var iv := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var js := """
		window.__voxel = {
			x: %f, y: %f, z: %f,
			vy: %f,
			inx: %f, inz: %f,
			fwd: %s,
			onFloor: %s,
			selected: %d,
			frame: %d,
			ready: true
		};
	""" % [position.x, position.y, position.z, velocity.y, iv.x, iv.y,
		str(Input.is_action_pressed("move_forward")).to_lower(),
		str(grounded).to_lower(), selected_index, _frame]
	JavaScriptBridge.eval(js, true)
