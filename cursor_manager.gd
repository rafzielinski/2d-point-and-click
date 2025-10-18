extends Node

# CursorManager - Singleton for managing custom cursor appearance
# This autoload script handles cursor changes based on navigation layers and interactive areas

# Cursor types
enum CursorType {
	DEFAULT,      # Normal cursor
	LAYER_1,      # Cursor on navigation layer 1 (floor)
	LAYER_2,      # Cursor on navigation layer 2 (window)
	INTERACTIVE   # Cursor over interactive elements
}

# Current cursor state
var current_cursor_type: CursorType = CursorType.DEFAULT
var current_navigation_layer: int = 1

# Cursor colors for testing (easily visible colors)
var cursor_colors: Dictionary = {
	CursorType.DEFAULT: Color.BLACK,
	CursorType.LAYER_1: Color.GREEN,
	CursorType.LAYER_2: Color.BLUE,
	CursorType.INTERACTIVE: Color.YELLOW
}

# Reference to the cursor node (will be set up later)
var cursor_node: Node2D = null
var cursor_rect: ColorRect = null

# Track areas we're hovering over
var hovering_areas: Array[Area2D] = []


func _ready() -> void:
	# Hide the system cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	
	# Wait a frame to ensure the scene tree is ready
	await get_tree().process_frame
	
	# Create the custom cursor
	_create_cursor()
	
	print("CursorManager initialized - cursor created")


func _process(delta: float) -> void:
	# Update cursor position to follow mouse
	if cursor_node:
		var mouse_pos = get_viewport().get_mouse_position()
		cursor_node.global_position = mouse_pos
	
	# Check what's under the cursor
	_check_cursor_state()


# Check cursor state based on what's under it
func _check_cursor_state() -> void:
	# If hovering over interactive area, keep it yellow
	if hovering_areas.size() > 0:
		return
	
	# Otherwise check navigation layer
	var layer = get_layer_under_cursor()
	if layer != current_navigation_layer:
		current_navigation_layer = layer
		if layer == 1:
			_set_cursor_type(CursorType.LAYER_1)
		elif layer == 2:
			_set_cursor_type(CursorType.LAYER_2)
		else:
			_set_cursor_type(CursorType.DEFAULT)


# Create the custom cursor node
func _create_cursor() -> void:
	# Create a CanvasLayer to ensure cursor is always on top
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "CursorCanvasLayer"
	canvas_layer.layer = 100  # High layer number to be on top
	
	# Create a Node2D as the cursor root
	cursor_node = Node2D.new()
	cursor_node.name = "CustomCursor"
	
	# Create a ColorRect for visual representation
	cursor_rect = ColorRect.new()
	cursor_rect.size = Vector2(20, 20)
	cursor_rect.position = Vector2(-10, -10)  # Center the cursor
	cursor_rect.color = cursor_colors[CursorType.DEFAULT]
	cursor_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block mouse input!
	
	# Build the hierarchy: CanvasLayer -> Node2D -> ColorRect
	cursor_node.add_child(cursor_rect)
	canvas_layer.add_child(cursor_node)
	
	# Add to the root scene
	get_tree().root.call_deferred("add_child", canvas_layer)
	
	print("Cursor node created and added to scene tree")


# Update cursor based on navigation layer
func update_cursor_for_layer(layer: int) -> void:
	current_navigation_layer = layer
	
	# Don't change if hovering over interactive area
	if hovering_areas.size() > 0:
		return
	
	# Update cursor type based on layer
	if layer == 1:
		_set_cursor_type(CursorType.LAYER_1)
	elif layer == 2:
		_set_cursor_type(CursorType.LAYER_2)
	else:
		_set_cursor_type(CursorType.DEFAULT)


# Register an interactive area
func register_interactive_area(area: Area2D) -> void:
	# Connect signals
	if not area.mouse_entered.is_connected(_on_area_mouse_entered):
		area.mouse_entered.connect(_on_area_mouse_entered.bind(area))
		print("Connected mouse_entered for: ", area.name)
	if not area.mouse_exited.is_connected(_on_area_mouse_exited):
		area.mouse_exited.connect(_on_area_mouse_exited.bind(area))
		print("Connected mouse_exited for: ", area.name)


# Called when mouse enters an interactive area
func _on_area_mouse_entered(area: Area2D) -> void:
	print(">>> MOUSE ENTERED: ", area.name, " - hovering_areas count: ", hovering_areas.size())
	if not hovering_areas.has(area):
		hovering_areas.append(area)
	
	# Set cursor to interactive type
	_set_cursor_type(CursorType.INTERACTIVE)


# Called when mouse exits an interactive area
func _on_area_mouse_exited(area: Area2D) -> void:
	print("<<< MOUSE EXITED: ", area.name, " - hovering_areas count before erase: ", hovering_areas.size())
	hovering_areas.erase(area)
	
	# If no more areas being hovered, revert to layer cursor
	if hovering_areas.size() == 0:
		var layer = get_layer_under_cursor()
		if layer == 1:
			_set_cursor_type(CursorType.LAYER_1)
		elif layer == 2:
			_set_cursor_type(CursorType.LAYER_2)
		else:
			_set_cursor_type(CursorType.DEFAULT)
		print("Reverted to layer cursor: ", layer)


# Set the cursor type and update visuals
func _set_cursor_type(type: CursorType) -> void:
	if current_cursor_type == type:
		return
	
	current_cursor_type = type
	
	# Update the cursor color
	if cursor_rect:
		cursor_rect.color = cursor_colors[type]
	
	print("Cursor changed to: ", CursorType.keys()[type])


# Get the current cursor position in world coordinates
func get_cursor_world_position() -> Vector2:
	return get_viewport().get_mouse_position()


# Check which navigation layer is under the cursor
func get_layer_under_cursor() -> int:
	var mouse_pos = get_cursor_world_position()
	
	# Get the current scene
	var scene_root = get_tree().current_scene
	if not scene_root:
		return 1
	
	# Find all navigation regions
	var nav_regions = _find_navigation_regions(scene_root)
	
	# Check each region to see if cursor is over it
	for region in nav_regions:
		if region is NavigationRegion2D:
			var nav_poly = region.navigation_polygon
			if nav_poly == null:
				continue
			
			# Transform mouse position to region's local space
			var local_pos = region.to_local(mouse_pos)
			
			# Check if cursor is inside this region
			if _is_point_in_navigation_polygon(local_pos, nav_poly):
				# Get the navigation layers for this region
				var layers = region.navigation_layers
				
				# Return the first enabled layer
				for i in range(32):
					if layers & (1 << i):
						return i + 1
				
				return 1
	
	return 1


# Helper function to recursively find all NavigationRegion2D nodes
func _find_navigation_regions(node: Node) -> Array:
	var regions = []
	
	if node is NavigationRegion2D:
		regions.append(node)
	
	for child in node.get_children():
		regions.append_array(_find_navigation_regions(child))
	
	return regions


# Check if a point is inside a navigation polygon
func _is_point_in_navigation_polygon(point: Vector2, nav_poly: NavigationPolygon) -> bool:
	var polygons = nav_poly.polygons
	var vertices = nav_poly.vertices
	
	for polygon in polygons:
		var poly_points = []
		for idx in polygon:
			if idx < vertices.size():
				poly_points.append(vertices[idx])
		
		if _is_point_in_polygon(point, poly_points):
			return true
	
	return false


# Point-in-polygon algorithm (ray casting)
func _is_point_in_polygon(point: Vector2, polygon: Array) -> bool:
	var inside = false
	var j = polygon.size() - 1
	
	for i in range(polygon.size()):
		var vi = polygon[i]
		var vj = polygon[j]
		
		if ((vi.y > point.y) != (vj.y > point.y)) and \
		   (point.x < (vj.x - vi.x) * (point.y - vi.y) / (vj.y - vi.y) + vi.x):
			inside = !inside
		
		j = i
	
	return inside
