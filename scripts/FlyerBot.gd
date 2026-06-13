class_name FlyerBot
extends Bot
# Saucer drone. Moves freely in 3D within a vertical band above the terrain.
# Can eat and be eaten by ground bots when vertically close (see Bot.overlaps).

const MIN_ALT := 5.0
const MAX_ALT := 30.0

var _bob := 0.0

func _build_body() -> void:
	bot_type = "flyer"
	var disc := CSGCylinder3D.new()
	disc.radius = 0.8
	disc.height = 0.22
	disc.sides = 16
	disc.material = _mat(Color(0.4, 0.55, 0.7))
	add_child(disc)
	var dome := CSGSphere3D.new()
	dome.radius = 0.42
	dome.radial_segments = 12
	dome.rings = 6
	dome.position = Vector3(0, 0.2, 0)
	dome.material = _mat(Color(0.7, 0.85, 0.95))
	add_child(dome)

func _ready() -> void:
	super._ready()
	_bob = randf() * TAU

func _flee_extra() -> void:
	# Climb toward the ceiling while fleeing.
	desired_dir.y = 1.0

func _constrain(delta: float) -> void:
	var gx := floori(global_position.x)
	var gz := floori(global_position.z)
	var base := world.ground_y(gx, gz)
	var lo := base + MIN_ALT
	var hi := base + MAX_ALT
	# Idle vertical drift so flyers don't sit at a fixed height.
	if not is_player_controlled and absf(desired_dir.y) < 0.01:
		_bob += delta
		global_position.y += sin(_bob) * delta * 1.5
	global_position.y = clampf(global_position.y, lo, hi)
	var flat := Vector3(velocity.x, 0, velocity.z)
	if flat.length() > 0.2:
		var yaw := atan2(flat.x, flat.z)
		rotation.y = lerp_angle(rotation.y, yaw, clampf(delta * 6.0, 0.0, 1.0))

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.5
	return m
