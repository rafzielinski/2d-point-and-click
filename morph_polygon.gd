extends Polygon2D

## Configuration
@export var morph_duration: float = 1.0
@export var easing_type: Tween.EaseType = Tween.EASE_IN_OUT
@export var transition_type: Tween.TransitionType = Tween.TRANS_CUBIC

## Target polygon to morph into
var target_polygon: PackedVector2Array = []
var original_polygon: PackedVector2Array = []
var is_morphing: bool = false
var morph_tween: Tween

func _ready():
	# Store the initial polygon
	original_polygon = polygon.duplicate()

## Main function to morph to a new shape
func morph_to(new_polygon: PackedVector2Array):
	if is_morphing and morph_tween:
		morph_tween.kill()

	# Prepare polygons for morphing (equalize vertex counts)
	var from_poly = polygon.duplicate()
	var to_poly = new_polygon.duplicate()

	# Make both polygons have the same number of vertices
	_equalize_vertex_counts(from_poly, to_poly)

	# Create tween for smooth interpolation
	morph_tween = create_tween()
	morph_tween.set_ease(easing_type)
	morph_tween.set_trans(transition_type)

	is_morphing = true

	# Animate the morph
	morph_tween.tween_method(
		_update_morph,
		0.0,
		1.0,
		morph_duration
	)

	morph_tween.finished.connect(func():
		is_morphing = false
		polygon = to_poly
	)

	# Store interpolation data
	target_polygon = to_poly
	original_polygon = from_poly

## Update function called by tween
func _update_morph(t: float):
	var new_verts = PackedVector2Array()

	for i in range(original_polygon.size()):
		var from = original_polygon[i]
		var to = target_polygon[i]
		new_verts.append(from.lerp(to, t))

	polygon = new_verts

## Equalize vertex counts between two polygons
func _equalize_vertex_counts(poly1: PackedVector2Array, poly2: PackedVector2Array):
	var count1 = poly1.size()
	var count2 = poly2.size()

	if count1 == count2:
		return

	# Subdivide the polygon with fewer vertices
	if count1 < count2:
		_subdivide_polygon(poly1, count2)
		original_polygon = poly1
	else:
		_subdivide_polygon(poly2, count1)
		target_polygon = poly2

## Subdivide polygon to match target vertex count
func _subdivide_polygon(poly: PackedVector2Array, target_count: int):
	while poly.size() < target_count:
		var longest_edge_idx = _find_longest_edge(poly)
		_split_edge(poly, longest_edge_idx)

## Find the index of the longest edge
func _find_longest_edge(poly: PackedVector2Array) -> int:
	var max_length = 0.0
	var max_idx = 0

	for i in range(poly.size()):
		var next_i = (i + 1) % poly.size()
		var length = poly[i].distance_to(poly[next_i])

		if length > max_length:
			max_length = length
			max_idx = i

	return max_idx

## Split an edge by inserting a vertex at its midpoint
func _split_edge(poly: PackedVector2Array, edge_idx: int):
	var next_idx = (edge_idx + 1) % poly.size()
	var midpoint = (poly[edge_idx] + poly[next_idx]) / 2.0
	poly.insert(next_idx, midpoint)

## Helper function to create simple shapes
static func create_circle(center: Vector2, radius: float, segments: int = 32) -> PackedVector2Array:
	var verts = PackedVector2Array()
	for i in range(segments):
		var angle = (i / float(segments)) * TAU
		verts.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return verts

static func create_rectangle(center: Vector2, size: Vector2) -> PackedVector2Array:
	var half = size / 2.0
	return PackedVector2Array([
		center + Vector2(-half.x, -half.y),
		center + Vector2(half.x, -half.y),
		center + Vector2(half.x, half.y),
		center + Vector2(-half.x, half.y)
	])

static func create_star(center: Vector2, outer_radius: float, inner_radius: float, points: int = 5) -> PackedVector2Array:
	var verts = PackedVector2Array()
	for i in range(points * 2):
		var angle = (i / float(points * 2)) * TAU - PI / 2
		var radius = outer_radius if i % 2 == 0 else inner_radius
		verts.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return verts
