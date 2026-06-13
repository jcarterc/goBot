class_name Chunk
extends StaticBody3D

# A vertical column of voxels. World stacks these on a 2D grid.
const W := 16
const H := 64
const D := 16

# Cube face definitions: 6 faces, each = normal + 4 corner offsets (CCW seen from outside).
const FACES := [
	{"n": Vector3i(0, 0, 1), "v": [Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1)]},   # +Z
	{"n": Vector3i(0, 0, -1), "v": [Vector3(1, 0, 0), Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0)]},  # -Z
	{"n": Vector3i(1, 0, 0), "v": [Vector3(1, 0, 1), Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 1)]},   # +X
	{"n": Vector3i(-1, 0, 0), "v": [Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0)]},  # -X
	{"n": Vector3i(0, 1, 0), "v": [Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0), Vector3(0, 1, 0)]},   # +Y
	{"n": Vector3i(0, -1, 0), "v": [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)]},  # -Y
]

var cx: int
var cz: int
var world: Node3D
var material: Material
var blocks := PackedByteArray()

var _mesh_instance: MeshInstance3D
var _collision: CollisionShape3D

static func index(x: int, y: int, z: int) -> int:
	return x + W * (z + D * y)

func _init() -> void:
	blocks.resize(W * H * D)

func setup(chunk_x: int, chunk_z: int, world_ref: Node3D) -> void:
	cx = chunk_x
	cz = chunk_z
	world = world_ref
	position = Vector3(cx * W, 0, cz * D)
	_mesh_instance = MeshInstance3D.new()
	add_child(_mesh_instance)
	_collision = CollisionShape3D.new()
	add_child(_collision)

func get_local(x: int, y: int, z: int) -> int:
	if y < 0 or y >= H:
		return Blocks.AIR
	if x < 0 or x >= W or z < 0 or z >= D:
		# Defer to the world for cross-chunk neighbor lookups.
		return world.get_block(cx * W + x, y, cz * D + z)
	return blocks[index(x, y, z)]

func set_local(x: int, y: int, z: int, id: int) -> void:
	if x < 0 or x >= W or y < 0 or y >= H or z < 0 or z >= D:
		return
	blocks[index(x, y, z)] = id

func rebuild_mesh() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if material:
		st.set_material(material)
	for y in H:
		for z in D:
			for x in W:
				var id := blocks[index(x, y, z)]
				if id == Blocks.AIR:
					continue
				_emit_block(st, x, y, z, id)
	st.generate_normals()
	var mesh := st.commit()
	_mesh_instance.mesh = mesh
	# Player collision is handled by AABB-vs-voxel-grid math in Player.gd,
	# so chunks carry no physics colliders.

func _emit_block(st: SurfaceTool, x: int, y: int, z: int, id: int) -> void:
	var base := Vector3(x, y, z)
	for face in FACES:
		var n: Vector3i = face["n"]
		var neighbor := get_local(x + n.x, y + n.y, z + n.z)
		if Blocks.is_solid(neighbor):
			continue  # hidden face, skip it
		var col := Blocks.face_color(id, n)
		st.set_color(col)
		var v: Array = face["v"]
		# two triangles per quad
		_vert(st, base + v[0])
		_vert(st, base + v[1])
		_vert(st, base + v[2])
		_vert(st, base + v[0])
		_vert(st, base + v[2])
		_vert(st, base + v[3])

func _vert(st: SurfaceTool, p: Vector3) -> void:
	st.add_vertex(p)
