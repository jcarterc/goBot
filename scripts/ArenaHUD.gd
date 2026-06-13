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
var powerups: PowerUpManager

var _size_label: Label
var _score_label: Label
var _power_label: Label
var _perk_label: Label
var _combo_label: Label
var _crosshair: Label
var _danger: ColorRect
var _vignette: TextureRect
var _minimap: MiniMap
var _boss_bar: ProgressBar
var _boss_label: Label

signal respawn_requested

func setup(p_player: Bot, p_spawner: BotSpawner, p_camera: CameraController, p_powerups: PowerUpManager) -> void:
	player = p_player
	spawner = p_spawner
	camera = p_camera
	powerups = p_powerups

func _ready() -> void:
	_size_label = _label(Control.PRESET_TOP_LEFT, Vector2(16, 12), 18, HORIZONTAL_ALIGNMENT_LEFT)
	_power_label = _label(Control.PRESET_TOP_LEFT, Vector2(16, 40), 16, HORIZONTAL_ALIGNMENT_LEFT)
	_perk_label = _label(Control.PRESET_TOP_LEFT, Vector2(16, 64), 13, HORIZONTAL_ALIGNMENT_LEFT)
	_perk_label.add_theme_color_override("font_color", Color(0.7, 0.95, 0.75))
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

	var vp := get_viewport().get_visible_rect().size
	_danger = ColorRect.new()
	_danger.color = Color(0.8, 0.1, 0.1, 0.0)
	_danger.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_danger.custom_minimum_size = Vector2(0, 8)
	_danger.size = Vector2(vp.x, 8)
	_danger.position = Vector2(0, vp.y - 8)
	add_child(_danger)

	# Full-screen red vignette that intensifies with danger.
	_vignette = TextureRect.new()
	_vignette.texture = _make_vignette()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.modulate = Color(1, 0.1, 0.1, 0.0)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vignette)

	# Combo banner (centre-top).
	_combo_label = Label.new()
	_combo_label.add_theme_font_size_override("font_size", 30)
	_combo_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
	_combo_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_combo_label.add_theme_constant_override("outline_size", 5)
	_combo_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_combo_label.position = Vector2(-100, 60)
	_combo_label.custom_minimum_size = Vector2(200, 0)
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_combo_label)

	# Radar (bottom-right) + expand button.
	_minimap = MiniMap.new()
	_minimap.setup(player, spawner, powerups)
	add_child(_minimap)
	var expand := UITheme.make_button("Map (M)", UITheme.ACCENT, Vector2(96, 32))
	expand.position = Vector2(vp.x - 116, vp.y - 196)
	expand.pressed.connect(_toggle_map)
	add_child(expand)

	# Respawn button (top-right) — recovers a stuck/frozen bot.
	var respawn := UITheme.make_button("Respawn", Color(1.0, 0.5, 0.4), Vector2(120, 40))
	respawn.position = Vector2(vp.x - 136, 50)
	respawn.set_anchors_preset(Control.PRESET_TOP_RIGHT, false)
	respawn.position = Vector2(vp.x - 136, 50)
	respawn.pressed.connect(func(): respawn_requested.emit())
	add_child(respawn)

	# Boss health bar (top-centre, hidden until a boss is active).
	_boss_label = Label.new()
	_boss_label.text = "BOSS"
	_boss_label.add_theme_font_size_override("font_size", 16)
	_boss_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.5))
	_boss_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_boss_label.position = Vector2(-40, 8)
	_boss_label.visible = false
	add_child(_boss_label)
	_boss_bar = ProgressBar.new()
	_boss_bar.show_percentage = false
	_boss_bar.custom_minimum_size = Vector2(280, 14)
	_boss_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_boss_bar.position = Vector2(-140, 28)
	_boss_bar.visible = false
	add_child(_boss_bar)

	if not GameState.score_changed.is_connected(_on_score_changed):
		GameState.score_changed.connect(_on_score_changed)

func _toggle_map() -> void:
	_minimap.toggle_expand()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		_toggle_map()

# A soft radial vignette texture: transparent centre, opaque edges.
func _make_vignette() -> ImageTexture:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := Vector2(n, n) * 0.5
	var maxd := c.length()
	for y in n:
		for x in n:
			var d := Vector2(x, y).distance_to(c) / maxd
			var a := clampf((d - 0.55) / 0.45, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)

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
	_perk_label.text = ("perks: " + ", ".join(player.perks)) if not player.perks.is_empty() else ""
	if camera != null:
		_crosshair.visible = not camera.third_person
	_danger.color.a = lerpf(_danger.color.a, 0.55 if _danger_near() else 0.0, 0.1)
	var threat: float = spawner.threat_level() if spawner != null else 0.0
	_vignette.modulate.a = lerpf(_vignette.modulate.a, threat * 0.6, 0.1)
	if GameState.combo > 1:
		_combo_label.text = "COMBO  x%d" % GameState.combo
		_combo_label.modulate.a = 1.0
	else:
		_combo_label.modulate.a = lerpf(_combo_label.modulate.a, 0.0, 0.1)
	# Keep the radar pinned bottom-right as its size changes on expand.
	var vp := get_viewport().get_visible_rect().size
	_minimap.position = Vector2(vp.x - _minimap.size.x - 16, vp.y - _minimap.size.y - 16)
	# Boss health bar.
	var boss: Bot = spawner.current_boss() if spawner != null else null
	if boss != null and is_instance_valid(boss):
		_boss_bar.visible = true
		_boss_label.visible = true
		_boss_bar.max_value = boss.max_hp
		_boss_bar.value = boss.hp
	else:
		_boss_bar.visible = false
		_boss_label.visible = false

func _power_text() -> String:
	var parts: Array[String] = []
	if player.speed_boost_t > 0.0:
		parts.append("SPEED %ds" % ceili(player.speed_boost_t))
	if player.invincible_t > 0.0:
		parts.append("INVINCIBLE %ds" % ceili(player.invincible_t))
	if player.magnet_t > 0.0:
		parts.append("MAGNET %ds" % ceili(player.magnet_t))
	parts.append("DASH" if player.dash_cd <= 0.0 else "DASH %.0fs" % ceil(player.dash_cd))
	parts.append("POWER" if player.ability_cd <= 0.0 else "POWER %.0fs" % ceil(player.ability_cd))
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
