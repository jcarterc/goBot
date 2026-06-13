class_name ArenaHUD
extends CanvasLayer
# Minimal in-game HUD: size tier (top-left), score/best (top-right),
# a first-person crosshair, and a danger bar that reddens when a Large or
# Massive bot is within 30 units.

const DANGER_RANGE := 30.0
const DANGER_TIER := 2.6  # Large and above

var player: Bot
var spawner: BotSpawner
var camera: CameraController

var _size_label: Label
var _score_label: Label
var _power_label: Label
var _crosshair: Label
var _danger: ColorRect

func setup(p_player: Bot, p_spawner: BotSpawner, p_camera: CameraController) -> void:
	player = p_player
	spawner = p_spawner
	camera = p_camera

func _ready() -> void:
	_size_label = _label(Control.PRESET_TOP_LEFT, Vector2(16, 12), 18, HORIZONTAL_ALIGNMENT_LEFT)
	_power_label = _label(Control.PRESET_TOP_LEFT, Vector2(16, 40), 16, HORIZONTAL_ALIGNMENT_LEFT)
	_score_label = _label(Control.PRESET_TOP_RIGHT, Vector2(-16, 12), 18, HORIZONTAL_ALIGNMENT_RIGHT)
	_score_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_score_label.position = Vector2(-260, 12)
	_score_label.custom_minimum_size = Vector2(244, 0)

	_crosshair = Label.new()
	_crosshair.text = "•"
	_crosshair.add_theme_font_size_override("font_size", 22)
	_crosshair.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.position = Vector2(-6, -16)
	_crosshair.visible = false
	add_child(_crosshair)

	_danger = ColorRect.new()
	_danger.color = Color(0.8, 0.1, 0.1, 0.0)
	_danger.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_danger.custom_minimum_size = Vector2(0, 8)
	_danger.size = Vector2(get_viewport().get_visible_rect().size.x, 8)
	_danger.position = Vector2(0, get_viewport().get_visible_rect().size.y - 8)
	add_child(_danger)

	if not GameState.score_changed.is_connected(_on_score_changed):
		GameState.score_changed.connect(_on_score_changed)

func _label(preset: int, pos: Vector2, font_size: int, align: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = align
	l.set_anchors_and_offsets_preset(preset)
	l.position = pos
	add_child(l)
	return l

func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_size_label.text = "%s   size %.2f" % [_tier_name(player.size_tier), player.size_tier]
	_score_label.text = "SCORE %s\nBEST  %s" % [_commas(GameState.score), _commas(GameState.best)]
	_power_label.text = _power_text()
	if camera != null:
		_crosshair.visible = not camera.third_person
	_danger.color.a = lerpf(_danger.color.a, 0.55 if _danger_near() else 0.0, 0.1)

func _power_text() -> String:
	var parts: Array[String] = []
	if player.speed_boost_t > 0.0:
		parts.append("SPEED %ds" % ceili(player.speed_boost_t))
	if player.invincible_t > 0.0:
		parts.append("INVINCIBLE %ds" % ceili(player.invincible_t))
	if player.magnet_t > 0.0:
		parts.append("MAGNET %ds" % ceili(player.magnet_t))
	return "   ".join(parts)

func _danger_near() -> bool:
	if spawner == null:
		return false
	for b in spawner.bots:
		if not is_instance_valid(b) or b == player or not b.alive:
			continue
		if b.size_tier >= DANGER_TIER and b.can_eat(player):
			if b.global_position.distance_to(player.global_position) <= DANGER_RANGE:
				return true
	return false

func _on_score_changed(_score: int) -> void:
	var tw := create_tween()
	_score_label.pivot_offset = _score_label.size * 0.5
	tw.tween_property(_score_label, "scale", Vector2(1.18, 1.18), 0.08)
	tw.tween_property(_score_label, "scale", Vector2.ONE, 0.12)

func _tier_name(s: float) -> String:
	if s < 0.7: return "TINY"
	if s < 1.3: return "SMALL"
	if s < 2.6: return "MEDIUM"
	if s < 4.6: return "LARGE"
	return "MASSIVE"

func _commas(n: int) -> String:
	var s := str(n)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return out
