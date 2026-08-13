@tool
class_name PhysicsBlock
extends RigidBody2D

## Reusable, indestructible construction block.
## Its mass is calculated from the selected material density and 2D area.

enum BlockShape {
	SQUARE,
	HALF_SQUARE,
	RECTANGLE,
	LARGE,
	PLATFORM,
	ROD,
	SLOPE,
}

enum BlockMaterial {
	WOOD,
	STONE,
	METAL,
}

const MATERIAL_COLORS := {
	BlockMaterial.WOOD: Color("#8b5a2b"),
	BlockMaterial.STONE: Color("#8a8f98"),
	BlockMaterial.METAL: Color("#3f4650"),
}

const MATERIAL_DENSITIES := {
	BlockMaterial.WOOD: 1.0,
	BlockMaterial.STONE: 2.5,
	BlockMaterial.METAL: 5.0,
}

@export var block_shape: BlockShape = BlockShape.SQUARE:
	set(value):
		block_shape = value
		if is_inside_tree():
			_refresh_block()

@export var block_material: BlockMaterial = BlockMaterial.WOOD:
	set(value):
		block_material = value
		if is_inside_tree():
			_refresh_block()

## Pixel size of one design unit. The planned sizes are expressed in these units.
@export_range(16.0, 128.0, 1.0) var unit_size := 64.0:
	set(value):
		unit_size = value
		if is_inside_tree():
			_refresh_block()


func _ready() -> void:
	_refresh_block()


func _draw() -> void:
	var points := _get_polygon()
	if points.size() < 3:
		return
	var color: Color = MATERIAL_COLORS[block_material]
	draw_colored_polygon(points, color)
	var outline := PackedVector2Array(points)
	outline.append(points[0])
	draw_polyline(outline, color.lightened(0.28), 3.0, true)


func _refresh_block() -> void:
	queue_redraw()
	mass = _get_area_units() * float(MATERIAL_DENSITIES[block_material])
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null:
		return
	var polygon_shape := ConvexPolygonShape2D.new()
	polygon_shape.points = _get_polygon()
	collision.shape = polygon_shape


func _get_polygon() -> PackedVector2Array:
	var dimensions := _get_dimensions_units() * unit_size
	var half := dimensions * 0.5
	if block_shape == BlockShape.SLOPE:
		return PackedVector2Array([
			Vector2(-half.x, half.y),
			Vector2(half.x, half.y),
			Vector2(half.x, -half.y),
		])
	return PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	])


func _get_dimensions_units() -> Vector2:
	match block_shape:
		BlockShape.SQUARE:
			return Vector2(1.0, 1.0)
		BlockShape.HALF_SQUARE:
			return Vector2(1.0, 0.5)
		BlockShape.RECTANGLE:
			return Vector2(2.0, 1.0)
		BlockShape.LARGE:
			return Vector2(2.0, 2.0)
		BlockShape.PLATFORM:
			return Vector2(0.5, 3.0)
		BlockShape.ROD:
			return Vector2(0.25, 3.0)
		BlockShape.SLOPE:
			return Vector2(3.0, 2.0)
	return Vector2.ONE


func _get_area_units() -> float:
	var dimensions := _get_dimensions_units()
	var area := dimensions.x * dimensions.y
	if block_shape == BlockShape.SLOPE:
		area *= 0.5
	return area
