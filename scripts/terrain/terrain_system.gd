extends Node3D
## Destructible terrain system (S05) — architecture.md §5 as a scene node.
##
## Owns the pure mask (terrain_grid.gd) and keeps chunked visual + collision
## geometry in sync with it (terrain_mesher.gd builds both from the same
## triangles, so they cannot drift). Gameplay only calls apply_explosion /
## restore / query_surface_y — the mask stays an internal representation
## (implementation-guide §9), except that serialize()/deserialize() expose it
## byte-exact for future replay and multiplayer sync.

const TerrainGridScript := preload("res://scripts/terrain/terrain_grid.gd")
const TerrainMesher := preload("res://scripts/terrain/terrain_mesher.gd")

const CHUNK_CELLS := 32

@export var world_width := 60.0
@export var world_top_y := 8.0
@export var world_bottom_y := -4.0
@export var ground_top_y := 0.0
@export var ground_bottom_y := -4.0
@export var cell_size := 0.25

var grid

var _chunks: Dictionary = {}
var _material: StandardMaterial3D

@onready var _surface: Node3D = $Surface
@onready var _collision: StaticBody3D = $Collision


func _ready() -> void:
	add_to_group("terrain")
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	# Unshaded + no culling: flat readable colors, and geometry can never
	# disappear due to winding; physics uses backface collision for the same
	# reason. Shading/lighting pass comes later (S45).
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	grid = TerrainGridScript.new()
	restore()


## Carves a crater and rebuilds only the chunks it touched.
## Returns the number of cells removed.
func apply_explosion(world_pos: Vector3, radius: float) -> int:
	var removed: int = grid.destroy_circle(Vector2(world_pos.x, world_pos.y), radius)
	if removed > 0:
		_rebuild(_chunks_overlapping_circle(Vector2(world_pos.x, world_pos.y), radius))
	return removed


## Refills the initial ground and rebuilds every chunk.
func restore() -> void:
	grid.create(
		int(round(world_width / cell_size)),
		int(round((world_top_y - world_bottom_y) / cell_size)),
		cell_size,
		-world_width * 0.5,
		world_top_y,
	)
	grid.fill_ground(ground_top_y, ground_bottom_y)
	_rebuild(_all_chunk_coords())


func query_surface_y(x: float) -> float:
	return grid.query_surface_y(x)


func is_solid_world(p: Vector2) -> bool:
	return grid.is_solid_world(p)


func serialize() -> Dictionary:
	return grid.serialize()


func deserialize(data: Dictionary) -> void:
	grid.deserialize(data)
	_rebuild(_all_chunk_coords())


func _all_chunk_coords() -> Array:
	var coords: Array = []
	var chunks_x := int(ceil(grid.width / float(CHUNK_CELLS)))
	var chunks_y := int(ceil(grid.rows / float(CHUNK_CELLS)))
	for cy in chunks_y:
		for cx in chunks_x:
			coords.append(Vector2i(cx, cy))
	return coords


func _chunks_overlapping_circle(center: Vector2, radius: float) -> Array:
	var coords: Array = []
	# Same inverted-row caution as destroy_circle: min/max per axis.
	var lo: Vector2i = grid.world_to_cell(center - Vector2(radius, radius))
	var hi: Vector2i = grid.world_to_cell(center + Vector2(radius, radius))
	var c0 := Vector2i(mini(lo.x, hi.x) / CHUNK_CELLS, mini(lo.y, hi.y) / CHUNK_CELLS)
	var c1 := Vector2i(maxi(lo.x, hi.x) / CHUNK_CELLS, maxi(lo.y, hi.y) / CHUNK_CELLS)
	for cy in range(maxi(c0.y, 0), c1.y + 1):
		for cx in range(maxi(c0.x, 0), c1.x + 1):
			coords.append(Vector2i(cx, cy))
	return coords


func _rebuild(coords: Array) -> void:
	for chunk in coords:
		_rebuild_chunk(chunk)


func _rebuild_chunk(chunk: Vector2i) -> void:
	var data: Dictionary = TerrainMesher.build_chunk(grid, chunk, CHUNK_CELLS)
	var nodes: Dictionary = _chunk_nodes(chunk)
	var mesh_inst: MeshInstance3D = nodes["mesh"]
	var col_shape: CollisionShape3D = nodes["shape"]
	var verts: PackedVector3Array = data["positions"]
	if verts.is_empty():
		mesh_inst.mesh = null
		col_shape.shape = null
		return
	mesh_inst.mesh = _build_mesh(data)
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(verts)
	col_shape.shape = shape


func _chunk_nodes(chunk: Vector2i) -> Dictionary:
	if _chunks.has(chunk):
		return _chunks[chunk]
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "Chunk_%d_%d" % [chunk.x, chunk.y]
	mesh_inst.material_override = _material
	_surface.add_child(mesh_inst)
	var col_shape := CollisionShape3D.new()
	col_shape.name = "Chunk_%d_%d" % [chunk.x, chunk.y]
	_collision.add_child(col_shape)
	var nodes := {"mesh": mesh_inst, "shape": col_shape}
	_chunks[chunk] = nodes
	return nodes


func _build_mesh(data: Dictionary) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var verts: PackedVector3Array = data["positions"]
	var colors: PackedColorArray = data["colors"]
	for i in verts.size():
		st.set_color(colors[i])
		st.add_vertex(verts[i])
	st.generate_normals()
	return st.commit()
