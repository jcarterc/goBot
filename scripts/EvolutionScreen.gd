class_name EvolutionScreen
extends CanvasLayer
# Shown at a size milestone. Offers a choice of perks; the picked perk id is
# emitted and applied to the player, then the run resumes.

signal perk_chosen(perk_id: String)

var _perks: Array = []

func configure(perks: Array) -> void:
	_perks = perks

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.06, 0.12, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel_style())
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-240, -150)
	panel.custom_minimum_size = Vector2(480, 0)
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(UITheme.title("EVOLVE", 40, UITheme.ACCENT_WARM))
	box.add_child(UITheme.heading("Choose an upgrade", 16, UITheme.TEXT))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	for perk in _perks:
		row.add_child(_perk_card(perk))

func _perk_card(perk: Dictionary) -> Control:
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 6)
	card.custom_minimum_size = Vector2(140, 0)
	var btn := UITheme.make_button(perk["name"], UITheme.ACCENT, Vector2(140, 50))
	btn.pressed.connect(func(): perk_chosen.emit(perk["id"]))
	card.add_child(btn)
	var desc := UITheme.heading(perk["desc"], 12, Color(0.78, 0.83, 0.92))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(140, 44)
	card.add_child(desc)
	return card
