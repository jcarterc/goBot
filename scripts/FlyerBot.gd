class_name FlyerBot
extends Bot
# Saucer drone. Moves freely in 3D within a vertical band above the terrain,
# with a glowing dome, under-glow and a vapor trail. Can eat and be eaten by
# ground bots when vertically close (see Bot.overlaps).

const MIN_ALT := 5.0
const MAX_ALT := 30.0

var _bob := 0.0

func _build_body() -> void:
	bot_type = "flyer"
	var disc := CSGCylinder3D.new()
	disc.radius = 0.85
	disc.height = 0.22
	disc.sides = 20
	disc.material = _metal(Color(0.42, 0.5, 0.6))
	add_child(disc)
	# Glowing dome.
	var dome := CSGSphere3D.new()
	dome.radius = 0.44
	dome.radial_segments = 14
	dome.rings = 8
	dome.position = Vector3(0, 0.2, 0)
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.5, 0.85, 1.0, 0.85)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.emission_enabled = true
	dm.emission = Color(0.3, 0.8, 1.0)
	dm.emission_energy_multiplier = 2.0
	dome.material = dm
	add_child(dome)
	# Under-glow ring.
	var glow := CSGCylinder3D.new()
	glow.radius = 0.5
	glow.height = 0.06
	glow.sides = 18
	glow.position = Vector3(0, -0.16, 0)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.4, 0.9, 1.0)
	gm.emission_enabled = true
	gm.emission = Color(0.3, 0.8, 1.0)
	gm.emission_energy_multiplier = 3.0
	glow.material = gm
	add_child(glow)
	_add_trail(Color(0.4, 0.8, 1.0), Vector3(0, -0.2, 0))

func _ready() -> void:
	super._ready()
	_bob = randf() * TAU

func _flee_extra() -> void:
	desired_dir.y = 1.0

func _constrain(delta: float) -> void:
	var gx := floori(global_position.x)
	var gz := floori(global_position.z)
	var base := world.ground_y(gx, gz)
	var lo := base + MIN_ALT
	var hi := base + MAX_ALT
	if not is_player_controlled and absf(desired_dir.y) < 0.01:
		_bob += delta
		global_position.y += sin(_bob) * delta * 1.5
	global_position.y = clampf(global_position.y, lo, hi)
	var flat := Vector3(velocity.x, 0, velocity.z)
	if flat.length() > 0.2:
		var yaw := atan2(flat.x, flat.z)
		rotation.y = lerp_angle(rotation.y, yaw, clampf(delta * 6.0, 0.0, 1.0))

func _metal(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = 0.55
	m.roughness = 0.35
	return m
