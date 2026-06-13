class_name WalkerBot
extends Bot
# Blocky bipedal bot with articulating limbs. Legs and arms swing on hip/shoulder
# pivots in proportion to walking speed. Stays on the terrain surface.

var _l_leg: Node3D
var _r_leg: Node3D
var _l_arm: Node3D
var _r_arm: Node3D
var _walk_phase := 0.0

func _build_body() -> void:
	bot_type = "walker"
	var body_mat := _metal(Color(0.52, 0.56, 0.62))
	var joint_mat := _metal(Color(0.30, 0.33, 0.38))

	_box(Vector3(0.9, 0.7, 0.6), Vector3(0, 1.05, 0), body_mat)        # torso
	var head_mat := _metal(Color(0.62, 0.66, 0.72))
	_box(Vector3(0.5, 0.46, 0.46), Vector3(0, 1.64, 0), head_mat)      # head
	# Glowing eyes.
	_eye(Vector3(-0.12, 1.66, 0.24))
	_eye(Vector3(0.12, 1.66, 0.24))

	_l_leg = _limb(Vector3(-0.26, 0.72, 0), Vector3(0.24, 0.72, 0.24), joint_mat)
	_r_leg = _limb(Vector3(0.26, 0.72, 0), Vector3(0.24, 0.72, 0.24), joint_mat)
	_l_arm = _limb(Vector3(-0.58, 1.4, 0), Vector3(0.18, 0.6, 0.18), body_mat)
	_r_arm = _limb(Vector3(0.58, 1.4, 0), Vector3(0.18, 0.6, 0.18), body_mat)

func _constrain(delta: float) -> void:
	var gx := floori(global_position.x)
	var gz := floori(global_position.z)
	var gy := world.ground_y(gx, gz)
	global_position.y = lerpf(global_position.y, gy, clampf(delta * 10.0, 0.0, 1.0))

	var flat := Vector3(velocity.x, 0, velocity.z)
	if flat.length() > 0.2:
		var yaw := atan2(flat.x, flat.z)
		rotation.y = lerp_angle(rotation.y, yaw, clampf(delta * 8.0, 0.0, 1.0))

	# Articulated walk cycle: limb swing scales with horizontal speed.
	var spd := flat.length()
	_walk_phase += delta * (4.0 + spd * 0.9)
	var amp := clampf(spd * 0.13, 0.0, 0.7)
	var s := sin(_walk_phase) * amp
	if _l_leg:
		_l_leg.rotation.x = s
		_r_leg.rotation.x = -s
		_l_arm.rotation.x = -s
		_r_arm.rotation.x = s

# A limb pivoting from its top: the box hangs below the pivot point.
func _limb(pivot_pos: Vector3, size: Vector3, mat: StandardMaterial3D) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pivot_pos
	add_child(pivot)
	var b := CSGBox3D.new()
	b.size = size
	b.position = Vector3(0, -size.y * 0.5, 0)
	b.material = mat
	pivot.add_child(b)
	return pivot

func _box(size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> void:
	var b := CSGBox3D.new()
	b.size = size
	b.position = pos
	b.material = mat
	add_child(b)

func _eye(pos: Vector3) -> void:
	var e := CSGBox3D.new()
	e.size = Vector3(0.1, 0.1, 0.06)
	e.position = pos
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.6, 1.0, 1.0)
	m.emission_enabled = true
	m.emission = Color(0.4, 1.0, 1.0)
	m.emission_energy_multiplier = 3.0
	e.material = m
	add_child(e)

func _metal(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = 0.5
	m.roughness = 0.45
	return m
