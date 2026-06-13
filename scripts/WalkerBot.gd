class_name WalkerBot
extends Bot
# Blocky bipedal bot. Stays on the terrain surface, follows ground elevation
# each frame. Slowest type but steers tightly through dense terrain.

func _build_body() -> void:
	bot_type = "walker"
	var col := Color(0.55, 0.58, 0.62)
	var mat := _mat(col)
	_box(Vector3(0.9, 0.7, 0.6), Vector3(0, 1.05, 0), mat)      # torso
	_box(Vector3(0.42, 0.42, 0.42), Vector3(0, 1.62, 0), _mat(Color(0.7, 0.5, 0.3)))  # head
	_box(Vector3(0.25, 0.7, 0.25), Vector3(-0.3, 0.35, 0), mat) # left leg
	_box(Vector3(0.25, 0.7, 0.25), Vector3(0.3, 0.35, 0), mat)  # right leg
	_box(Vector3(0.18, 0.6, 0.18), Vector3(-0.6, 1.1, 0), mat)  # left arm
	_box(Vector3(0.18, 0.6, 0.18), Vector3(0.6, 1.1, 0), mat)   # right arm

func _constrain(delta: float) -> void:
	var gx := floori(global_position.x)
	var gz := floori(global_position.z)
	var gy := world.ground_y(gx, gz)
	global_position.y = lerpf(global_position.y, gy, clampf(delta * 10.0, 0.0, 1.0))
	# Face the direction of travel.
	var flat := Vector3(velocity.x, 0, velocity.z)
	if flat.length() > 0.2:
		var yaw := atan2(flat.x, flat.z)
		rotation.y = lerp_angle(rotation.y, yaw, clampf(delta * 8.0, 0.0, 1.0))

func _box(size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> void:
	var b := CSGBox3D.new()
	b.size = size
	b.position = pos
	b.material = mat
	add_child(b)

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	return m
