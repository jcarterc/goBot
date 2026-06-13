class_name RollerBot
extends Bot
# BB-8-style droid: a white ball body (with orange panels) that rolls, topped by
# a domed head that stays upright and turns toward the direction of travel.

var _ball: CSGSphere3D
var _head: Node3D

func _build_body() -> void:
	bot_type = "roller"
	var white := _matte(Color(0.92, 0.93, 0.96))
	var orange := _matte(Color(0.95, 0.55, 0.15))
	var dark := _matte(Color(0.15, 0.16, 0.2))

	# Rolling ball body.
	_ball = CSGSphere3D.new()
	_ball.radius = 0.7
	_ball.radial_segments = 18
	_ball.rings = 12
	_ball.position = Vector3(0, 0.7, 0)
	_ball.material = white
	add_child(_ball)
	# Orange ring panels on the body (children roll with the ball).
	for ang in [0.0, TAU / 3.0, 2.0 * TAU / 3.0]:
		var ring := CSGTorus3D.new()
		ring.inner_radius = 0.14
		ring.outer_radius = 0.24
		ring.sides = 8
		ring.ring_sides = 10
		ring.material = orange
		ring.position = Vector3(sin(ang) * 0.55, 0.18, cos(ang) * 0.55)
		_ball.add_child(ring)

	# Upright head (not parented to the ball, so it never spins with it).
	_head = Node3D.new()
	_head.position = Vector3(0, 1.42, 0)
	add_child(_head)
	var dome := CSGSphere3D.new()
	dome.radius = 0.44
	dome.radial_segments = 16
	dome.rings = 8
	dome.material = white
	_head.add_child(dome)
	var band := CSGCylinder3D.new()
	band.radius = 0.42
	band.height = 0.12
	band.sides = 16
	band.position = Vector3(0, -0.12, 0)
	band.material = orange
	_head.add_child(band)
	# Eye (lens) facing forward (+Z).
	var lens := CSGCylinder3D.new()
	lens.radius = 0.13
	lens.height = 0.08
	lens.sides = 14
	lens.rotation = Vector3(deg_to_rad(90), 0, 0)
	lens.position = Vector3(0, 0.04, 0.4)
	lens.material = dark
	_head.add_child(lens)
	var glint := CSGSphere3D.new()
	glint.radius = 0.05
	glint.position = Vector3(0.05, 0.08, 0.46)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.5, 0.85, 1.0)
	gm.emission_enabled = true
	gm.emission = Color(0.4, 0.8, 1.0)
	gm.emission_energy_multiplier = 2.0
	glint.material = gm
	_head.add_child(glint)
	# Two antennas.
	for x in [-0.1, 0.1]:
		var ant := CSGCylinder3D.new()
		ant.radius = 0.02
		ant.height = 0.35
		ant.sides = 6
		ant.position = Vector3(x, 0.6, 0)
		ant.material = dark
		_head.add_child(ant)

	_add_trail(Color(1.0, 0.6, 0.2), Vector3(0, 0.3, 0))

func _constrain(delta: float) -> void:
	var gx := floori(global_position.x)
	var gz := floori(global_position.z)
	var ahead := global_position + Vector3(velocity.x, 0, velocity.z).normalized() * 1.5
	var slope := world.ground_y(gx, gz) - world.ground_y(floori(ahead.x), floori(ahead.z))
	speed_mult *= clampf(1.0 + slope * 0.08, 0.6, 1.4)
	var gy := world.ground_y(gx, gz)
	global_position.y = lerpf(global_position.y, gy, clampf(delta * 12.0, 0.0, 1.0))

	var flat := Vector3(velocity.x, 0, velocity.z)
	var speed := flat.length()
	if _ball:
		_ball.rotate_x(speed * delta * 0.7)
	# Head stays upright; turns toward travel and leans slightly into it.
	if _head and speed > 0.2:
		var yaw := atan2(flat.x, flat.z)
		_head.rotation.y = lerp_angle(_head.rotation.y, yaw, clampf(delta * 8.0, 0.0, 1.0))
		_head.rotation.x = lerpf(_head.rotation.x, -clampf(speed * 0.03, 0.0, 0.3), 0.1)

func _matte(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = 0.2
	m.roughness = 0.5
	return m
