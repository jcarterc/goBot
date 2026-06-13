class_name RollerBot
extends Bot
# Spherical bot that rolls across the ground, leaving a glowing trail. Fastest
# ground type on the flat; terrain slope nudges its speed.

var _ball: CSGSphere3D

func _build_body() -> void:
	bot_type = "roller"
	_ball = CSGSphere3D.new()
	_ball.radius = 0.7
	_ball.radial_segments = 16
	_ball.rings = 10
	_ball.position = Vector3(0, 0.7, 0)
	_ball.material = _metal(Color(0.85, 0.32, 0.22))
	add_child(_ball)
	# Glowing equator band.
	var band := CSGCylinder3D.new()
	band.radius = 0.74
	band.height = 0.2
	band.sides = 18
	band.position = Vector3(0, 0.7, 0)
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(1.0, 0.85, 0.25)
	bm.emission_enabled = true
	bm.emission = Color(1.0, 0.7, 0.1)
	bm.emission_energy_multiplier = 2.5
	band.material = bm
	add_child(band)
	_add_trail(Color(1.0, 0.6, 0.2), Vector3(0, 0.3, 0))

func _constrain(delta: float) -> void:
	var gx := floori(global_position.x)
	var gz := floori(global_position.z)
	var ahead := global_position + Vector3(velocity.x, 0, velocity.z).normalized() * 1.5
	var slope := world.ground_y(gx, gz) - world.ground_y(floori(ahead.x), floori(ahead.z))
	speed_mult *= clampf(1.0 + slope * 0.08, 0.6, 1.4)
	var gy := world.ground_y(gx, gz)
	global_position.y = lerpf(global_position.y, gy, clampf(delta * 12.0, 0.0, 1.0))
	if _ball:
		var speed := Vector3(velocity.x, 0, velocity.z).length()
		_ball.rotate_x(speed * delta * 0.6)

func _metal(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = 0.45
	m.roughness = 0.4
	return m
