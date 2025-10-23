extends Node2D

@onready var morph_polygon: Polygon2D = $MorphPolygon

var is_morphing: bool = false
var morph_duration: float = 1.5
var current_state: bool = true  # true = showing P1, false = showing P2

# Store original shapes
var original_p1: PackedVector2Array
var original_p2: PackedVector2Array

func _ready() -> void:
	# Store original shapes
	original_p1 = morph_polygon.polygon
	original_p2 = PackedVector2Array([29, 25, 309, 43, 568, 36, 820, 155, 1081, 31, 1171, 73, 1174, 773, 20, 770])

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not is_morphing:
			# Check if click is inside the current morph polygon
			var local_pos = morph_polygon.to_local(event.position)
			if Geometry2D.is_point_in_polygon(local_pos, morph_polygon.polygon):
				toggle_morph()

func toggle_morph() -> void:
	is_morphing = true

	# Determine start and end shapes
	var end_shape: PackedVector2Array

	if current_state:
		end_shape = original_p2
	else:
		end_shape = original_p1

	# Use the morph_to function from the MorphPolygon script
	morph_polygon.morph_to(end_shape)

	# Toggle state after morphing
	var tween = create_tween()
	tween.tween_callback(func():
		current_state = !current_state
		is_morphing = false
	).set_delay(morph_polygon.morph_duration)
