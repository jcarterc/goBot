class_name RollerBot
extends Bot
# Spherical bot that rolls across the ground. Fastest ground type on the flat;
# terrain slope nudges its speed. A contrasting band gives it a rolling read.

var _ball: CSGSphere3D

func _build_body() -> void:
	bot_type = "roller"
	_ball = CSGSphere3D.new()
	_ball.radius = 0.7
	_ball.radial_segments = 12
	_ball.rings = 8
	_ball.position = Vector3(0, 0.7, 0)
	_ball.material = _mat(Color(0.85, 0.35, 0.25))
	add_child(_ball)
	# Procedural stripe: a thin contrasting band around the equator.
	var band := CSGCylinder3D.new()
	band.radius = 0.74
	band.height = 0.22
	band.sides = 14
	band.position = Vector3(0, 0.7, 0)
	band.material = _mat(Color(0.95, 0.9, 0.3))
	add_child(band)

func _constrain(delta: float) -> void:
	var gx := floori(global_position.x)
	var gz := floori(global_position.z)
	# Slope influence: downhill speeds up, uphill slows down slightly.
	var ahead := global_position + Vector3(velocity.x, 0, velocity.z).normalized() * 1.5
	var slope := world.ground_y(gx, gz) - world.ground_y(floori(ahead.x), floori(ahead.z))
	speed_mult *= clampf(1.0 + slope * 0.08, 0.6, 1.4)
	var gy := world.ground_y(gx, gz)
	global_position.y = lerpf(global_position.y, gy, clampf(delta * 12.0, 0.0, 1.0))
	# Visually roll the ball around its travel axis.
	if _ball:
		var speed := Vector3(velocity.x, 0, velocity.z).length()
		_ball.rotate_x(speed * delta * 0.6)

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.6
	return m
