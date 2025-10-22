extends CharacterBody2D

@onready var polygon = $Polygon2D
@onready var anim = $AnimationPlayer

# Export variables for easy tweaking
@export_range(0.1, 3.0, 0.1) var morph_speed: float = 1.2
@export_range(0.0, 1.0, 0.05) var shape_variation: float = 0.3

# Edge offsets (can be percentage or pixels)
@export_group("Edge Offsets")
@export var top_offset: float = 10.0
@export var right_offset: float = 10.0
@export var bottom_offset: float = 10.0
@export var left_offset: float = 10.0

@export_group("Offset Mode (Percentage)")
@export var top_is_percentage: bool = true
@export var right_is_percentage: bool = true
@export var bottom_is_percentage: bool = true
@export var left_is_percentage: bool = true

var is_morphing: bool = false
var morph_progress: float = 0.0
var morph_direction: float = 1.0

func _ready() -> void:
	# Disable skeleton animation for now
	anim.stop()
	
	# Get viewport size and set shader parameters
	var viewport_size = get_viewport_rect().size
	var material = polygon.material as ShaderMaterial
	if material:
		material.set_shader_parameter("viewport_size", viewport_size)
		material.set_shader_parameter("polygon_center", Vector2.ZERO)
		material.set_shader_parameter("morph_progress", 0.0)
		
		# Set edge offsets
		material.set_shader_parameter("edge_offsets", Vector4(top_offset, right_offset, bottom_offset, left_offset))
		material.set_shader_parameter("edge_is_percentage", Vector4(
			1.0 if top_is_percentage else 0.0,
			1.0 if right_is_percentage else 0.0,
			1.0 if bottom_is_percentage else 0.0,
			1.0 if left_is_percentage else 0.0
		))
		material.set_shader_parameter("shape_variation", shape_variation)
		material.set_shader_parameter("random_seed", randf() * 1000.0)

func _process(delta: float) -> void:
	if is_morphing:
		morph_progress += morph_direction * morph_speed * delta
		morph_progress = clamp(morph_progress, 0.0, 1.0)
		
		var material = polygon.material as ShaderMaterial
		if material:
			material.set_shader_parameter("morph_progress", morph_progress)
		
		# Stop morphing when complete
		if morph_progress >= 1.0 or morph_progress <= 0.0:
			is_morphing = false

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Generate new random shape when morphing forward
		if morph_progress <= 0.0:
			var material = polygon.material as ShaderMaterial
			if material:
				material.set_shader_parameter("random_seed", randf() * 1000.0)
		
		# Toggle morph direction
		if morph_progress >= 1.0:
			morph_direction = -1.0
		elif morph_progress <= 0.0:
			morph_direction = 1.0
		
		is_morphing = true
