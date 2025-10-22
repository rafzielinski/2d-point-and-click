extends ColorRect

# State management
var is_expanded = false
var viewport_size: Vector2

# Animation parameters
var transition_speed = 2.0
var current_progress = 0.0

# Original state
var original_position: Vector2
var original_size: Vector2

# Target expanded state
var expanded_position: Vector2
var expanded_size: Vector2

func _ready():
	# Get viewport size
	viewport_size = get_viewport_rect().size
	
	# Set original size (blob size when not expanded)
	original_size = Vector2(150, 150)
	size = original_size
	
	# Store original position (center the rect)
	original_position = position
	
	# Calculate expanded state (half viewport)
	expanded_position = Vector2(viewport_size.x / 4, viewport_size.y / 4)
	expanded_size = Vector2(viewport_size.x / 2, viewport_size.y / 2)
	
	# Setup shader material
	var shader_material = ShaderMaterial.new()
	shader_material.shader = preload("res://body_morph.gdshader")
	material = shader_material
	
	# Center pivot
	pivot_offset = original_size / 2

func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Check if click is within the ColorRect
		var rect = Rect2(global_position, size)
		if rect.has_point(get_global_mouse_position()):
			toggle_state()

func toggle_state():
	is_expanded = !is_expanded

func _process(delta):
	# Animate transition
	if is_expanded and current_progress < 1.0:
		current_progress = min(current_progress + delta * transition_speed, 1.0)
	elif !is_expanded and current_progress > 0.0:
		current_progress = max(current_progress - delta * transition_speed, 0.0)
	
	# Update transform
	var t = ease_in_out(current_progress)
	
	# Update size
	size = original_size.lerp(expanded_size, t)
	
	# Update position (accounting for size change to keep centered)
	var target_pos = expanded_position
	position = original_position.lerp(target_pos, t)
	
	# Update pivot to keep centered
	pivot_offset = size / 2
	
	# Update shader parameters
	if material:
		material.set_shader_parameter("progress", current_progress)
		material.set_shader_parameter("time", Time.get_ticks_msec() / 1000.0)

func ease_in_out(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)