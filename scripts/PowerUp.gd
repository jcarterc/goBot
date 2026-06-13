class_name PowerUp
extends Node3D
# A collectible floating power-up: speed boost, invincibility, or magnet.
# Spins and bobs; the manager handles pickup detection.

const INFO := {
	"speed": {"color": Color(1.0, 0.85, 0.2), "label": "SPEED BOOST"},
	"invincible": {"color": Color(0.4, 0.9, 1.0), "label": "INVINCIBLE"},
	"magnet": {"color": Color(1.0, 0.4, 0.9), "label": "MAGNET"},
	"shrink": {"color": Color(0.6, 1.0, 0.5), "label": "SHRINK RAY"},
	"decoy": {"color": Color(0.9, 0.6, 1.0), "label": "DECOY"},
}

var kind := "speed"
var _spin := 0.0
var _bob := 0.0

func setup(p_kind: String) -> void:
	kind = p_kind

func color() -> Color:
	return INFO[kind]["color"]

func label() -> String:
	return INFO[kind]["label"]

func radius() -> float:
	return 1.4

func _ready() -> void:
	var c: Color = color()
	# Glowing core.
	var core := CSGSphere3D.new()
	core.radius = 0.45
	core.radial_segments = 12
	core.rings = 8
	core.material = _emissive(c, 3.0)
	add_child(core)
	# Orbiting ring.
	var ring := CSGCylinder3D.new()
	ring.radius = 0.8
	ring.height = 0.1
	ring.sides = 18
	ring.rotation = Vector3(deg_to_rad(70), 0, 0)
	ring.material = _emissive(c, 2.0)
	add_child(ring)
	# Light to make it pop in the world.
	var light := OmniLight3D.new()
	light.light_color = c
	light.light_energy = 2.0
	light.omni_range = 8.0
	add_child(light)
	_bob = randf() * TAU

func _process(delta: float) -> void:
	_spin += delta * 1.6
	_bob += delta * 2.0
	rotation.y = _spin
	for child in get_children():
		if child is CSGSphere3D:
			child.position.y = sin(_bob) * 0.2

func _emissive(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m
