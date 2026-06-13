class_name TitleScreen
extends Node3D
# Animated title: the word "goBot" built from voxel cubes coloured with the
# game's terrain block palette. Cubes drop in and assemble, then the word bobs.
# Any key / tap / click starts the game.

signal start_pressed

# 5x7 pixel fonts for the letters in "goBot".
const GLYPHS := {
	"g": [".###.", "#...#", "#...#", ".####", "....#", "#...#", ".###."],
	"o": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
	"t": ["..#..", "..#..", "#####", "..#..", "..#..", "..#..", "..##."],
}
const WORD := ["g", "o", "B", "o", "t"]

var _word: Node3D
var _time := 0.0
var _base_y := 0.0
var _started := false

func _ready() -> void:
	_setup_scene()
	_build_word()
	_build_overlay()

func _setup_scene() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.10, 0.12, 0.22)
	sm.sky_horizon_color = Color(0.25, 0.30, 0.45)
	sm.ground_bottom_color = Color(0.06, 0.07, 0.12)
	sm.ground_horizon_color = Color(0.25, 0.30, 0.45)
	sky.sky_material = sm
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.8
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(35), 0)
	sun.light_energy = 1.2
	add_child(sun)

	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.5, 26)
	cam.current = true
	add_child(cam)

func _build_word() -> void:
	_word = Node3D.new()
	add_child(_word)
	var palette := _palette()
	# Total width to centre the word.
	var letter_w := 5
	var spacing := 1
	var total := WORD.size() * (letter_w + spacing) - spacing
	var x_off := -total / 2.0
	var ci := 0
	var cursor := 0
	for letter in WORD:
		var rows: Array = GLYPHS[letter]
		for row in rows.size():
			var line: String = rows[row]
			for col in line.length():
				if line[col] != "#":
					continue
				var target := Vector3(x_off + cursor + col, (6 - row) - 3.0, 0)
				_spawn_cube(target, palette[(ci + row + col) % palette.size()], ci, row, col)
		cursor += letter_w + spacing
		ci += 1

func _spawn_cube(target: Vector3, color: Color, ci: int, row: int, col: int) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.92, 0.92, 0.92)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mesh.material_override = mat
	_word.add_child(mesh)
	# Start above and scaled to nothing, then drop/assemble with a bounce.
	mesh.position = target + Vector3(0, randf_range(10.0, 22.0), 0)
	mesh.scale = Vector3.ZERO
	var delay := ci * 0.18 + col * 0.03 + row * 0.02
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(mesh, "position", target, 0.7).set_delay(delay) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(mesh, "scale", Vector3.ONE, 0.5).set_delay(delay) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _palette() -> Array:
	return [
		Blocks.COLORS[Blocks.GRASS]["top"],
		Blocks.COLORS[Blocks.DIRT]["side"],
		Blocks.COLORS[Blocks.STONE]["side"],
		Blocks.COLORS[Blocks.WOOD]["side"],
		Blocks.COLORS[Blocks.LEAVES]["top"],
		Blocks.COLORS[Blocks.SAND]["top"],
		Blocks.COLORS[Blocks.WATER]["side"],
	]

func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var subtitle := Label.new()
	subtitle.text = "one AI bot's journey from birth to domination and death"
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	subtitle.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	subtitle.add_theme_constant_override("outline_size", 5)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	subtitle.position = Vector2(-360, 90)
	subtitle.custom_minimum_size = Vector2(720, 0)
	layer.add_child(subtitle)

	var prompt := Label.new()
	prompt.text = "press any key  •  tap to begin"
	prompt.add_theme_font_size_override("font_size", 16)
	prompt.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.position = Vector2(-150, -70)
	prompt.custom_minimum_size = Vector2(300, 0)
	layer.add_child(prompt)
	var tw := create_tween().set_loops()
	tw.tween_property(prompt, "modulate:a", 0.25, 0.8)
	tw.tween_property(prompt, "modulate:a", 1.0, 0.8)

func _process(delta: float) -> void:
	_time += delta
	if _word:
		_word.rotation.y = sin(_time * 0.4) * 0.22
		_word.position.y = _base_y + sin(_time * 1.4) * 0.3

func _unhandled_input(event: InputEvent) -> void:
	if _started:
		return
	var go: bool = (event is InputEventKey and event.pressed) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed)
	if go:
		_started = true
		start_pressed.emit()
