class_name Blocks
extends RefCounted

# Block type ids. AIR is empty space.
enum {
	AIR,
	GRASS,
	DIRT,
	STONE,
	WOOD,
	LEAVES,
	SAND,
	WATER,
	PLANKS,
}

# Top, side, bottom colors per block. Top/bottom let grass look right.
const COLORS := {
	GRASS: {"top": Color(0.36, 0.62, 0.24), "side": Color(0.45, 0.55, 0.27), "bottom": Color(0.45, 0.30, 0.18)},
	DIRT: {"top": Color(0.45, 0.30, 0.18), "side": Color(0.45, 0.30, 0.18), "bottom": Color(0.45, 0.30, 0.18)},
	STONE: {"top": Color(0.50, 0.50, 0.52), "side": Color(0.46, 0.46, 0.48), "bottom": Color(0.44, 0.44, 0.46)},
	WOOD: {"top": Color(0.55, 0.40, 0.22), "side": Color(0.40, 0.28, 0.15), "bottom": Color(0.55, 0.40, 0.22)},
	LEAVES: {"top": Color(0.24, 0.50, 0.20), "side": Color(0.22, 0.46, 0.18), "bottom": Color(0.20, 0.42, 0.16)},
	SAND: {"top": Color(0.85, 0.79, 0.55), "side": Color(0.83, 0.77, 0.53), "bottom": Color(0.81, 0.75, 0.51)},
	WATER: {"top": Color(0.25, 0.45, 0.78), "side": Color(0.25, 0.45, 0.78), "bottom": Color(0.25, 0.45, 0.78)},
	PLANKS: {"top": Color(0.66, 0.50, 0.30), "side": Color(0.64, 0.48, 0.28), "bottom": Color(0.62, 0.46, 0.26)},
}

# Blocks the player can place, in hotbar order.
const PLACEABLE := [GRASS, DIRT, STONE, WOOD, LEAVES, SAND, PLANKS]

static func is_solid(id: int) -> bool:
	return id != AIR and id != WATER

static func face_color(id: int, normal: Vector3i) -> Color:
	var c: Dictionary = COLORS.get(id, COLORS[STONE])
	if normal.y > 0:
		return c["top"]
	if normal.y < 0:
		return c["bottom"]
	return c["side"]
