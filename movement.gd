extends CharacterBody2D

# Movement properties
@export var speed: float = 300.0

# Squish animation properties
@export var squish_scale: Vector2 = Vector2(1.2, 0.8)
@export var animation_duration: float = 0.2

# References
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: Sprite2D = $Sprite2D

# Tween reference
var tween: Tween

# Track if currently on a squish link
var is_on_squish_link: bool = false

# Track current navigation layer
var current_nav_layer: int = 1
var target_nav_layer: int = 1
var transitioning_to_layer: bool = false
var final_target_position: Vector2 = Vector2.ZERO
var is_animating_transition: bool = false


func _ready() -> void:
	# Configure NavigationAgent properties
	nav_agent.path_desired_distance = 4.0
	nav_agent.target_desired_distance = 10.0
	
	# Wait for the first physics frame so the NavigationServer can sync
	await get_tree().physics_frame
	
	# Initialize cursor for current layer
	CursorManager.update_cursor_for_layer(current_nav_layer)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("click"):
		# Don't accept new clicks while animating transition
		if is_animating_transition:
			return
			
		# Get the clicked position in world coordinates
		var target_position = get_global_mouse_position()
		
		# Check if the clicked position is within any valid navigation polygon
		if not is_position_on_navigation_map(target_position):
			print("Clicked outside navigation regions - ignoring click")
			return
		
		# Check if click is on Window region (layer 2)
		var clicked_layer = get_clicked_navigation_layer(target_position)
		
		if clicked_layer != current_nav_layer:
			# Clicked on different layer - set up transition
			target_nav_layer = clicked_layer
			transitioning_to_layer = true
			final_target_position = target_position
			
			# Navigate as far as possible on current layer
			# The navigation will stop at the edge of the current layer
			nav_agent.target_position = target_position
			print("Clicked layer: ", clicked_layer, " - transitioning from layer ", current_nav_layer)
		else:
			# Clicked on same layer - normal navigation
			nav_agent.target_position = target_position
			print("Clicked on current layer: ", clicked_layer)


func _physics_process(delta: float) -> void:
	# Don't process navigation if we're animating a transition
	if is_animating_transition:
		return
	
	# Check if navigation is finished
	if nav_agent.is_navigation_finished():
		# If we were on a squish link and finished navigating, unsquish
		if is_on_squish_link:
			unsquish_player()
			is_on_squish_link = false
		
		# Check if we should transition to another layer
		if transitioning_to_layer:
			animate_layer_transition()
			transitioning_to_layer = false
		
		return
	
	# Get the next point in the path
	var next_path_position: Vector2 = nav_agent.get_next_path_position()
	
	# Calculate the direction to the next point
	var direction: Vector2 = global_position.direction_to(next_path_position)
	
	# Set velocity directly and move
	velocity = direction * speed
	move_and_slide()

func squish_player():
	# Cancel any existing tween
	if tween:
		tween.kill()
	
	# Create a new tween
	tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	
	# Animate the sprite scale to squished
	tween.tween_property(sprite, "scale", squish_scale, animation_duration)

func unsquish_player():
	# Cancel any existing tween
	if tween:
		tween.kill()
	
	# Create a new tween
	tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	
	# Animate the sprite scale back to normal
	tween.tween_property(sprite, "scale", Vector2.ONE, animation_duration)

func _on_navigation_agent_2d_link_reached(details: Dictionary) -> void:
	# Get the link object from the details (it's stored as "owner")
	var link = details.get("owner")
	
	if link == null:
		return
	
	# Check if the link has a 'link_type' metadata
	if link.has_meta("link_type"):
		var link_type = link.get_meta("link_type")
		
		# If it's a squish link, apply squish animation
		if link_type == "squish":
			is_on_squish_link = true
			squish_player()
		
		# If it's a window transition link, switch navigation layers
		elif link_type == "window_transition":
			# Toggle between layer 1 and 2
			if current_nav_layer == 1:
				switch_to_layer(2)
			else:
				switch_to_layer(1)
			
			print("Transitioning through window link")

# Check if a position is within any navigation polygon on the map
func is_position_on_navigation_map(position: Vector2) -> bool:
	var map = nav_agent.get_navigation_map()
	
	# Use NavigationServer2D to get the closest point on the navigation mesh
	var closest_point = NavigationServer2D.map_get_closest_point(map, position)
	
	# If the closest point is very close to our target position, we're on the nav mesh
	# Use a small threshold to account for floating point precision
	var distance_threshold = 5.0  # pixels
	var distance = position.distance_to(closest_point)
	
	return distance < distance_threshold

# Helper function to detect which navigation layer was clicked
# Returns: 1 = layer 1, 2 = layer 2, etc.
func get_clicked_navigation_layer(position: Vector2) -> int:
	var map = nav_agent.get_navigation_map()
	
	# Get all navigation regions in the scene
	var scene_root = get_tree().current_scene
	var nav_regions = find_navigation_regions(scene_root)
	
	# Check each navigation region to see if the position is within it
	for region in nav_regions:
		if region is NavigationRegion2D:
			var nav_poly = region.navigation_polygon
			if nav_poly == null:
				continue
			
			# Transform the world position to the region's local space
			var local_pos = region.to_local(position)
			
			# Check if the position is inside any polygon of this region
			if is_point_in_navigation_polygon(local_pos, nav_poly):
				# Get the navigation layers for this region
				var layers = region.navigation_layers
				
				# Return the first enabled layer (1-indexed)
				for i in range(32):  # Navigation layers are 32-bit
					if layers & (1 << i):
						return i + 1
				
				# If no specific layer is set, return 1 (default layer)
				return 1
	
	# Default to layer 1 if not found in any specific region
	return 1

# Helper function to recursively find all NavigationRegion2D nodes
func find_navigation_regions(node: Node) -> Array:
	var regions = []
	
	if node is NavigationRegion2D:
		regions.append(node)
	
	for child in node.get_children():
		regions.append_array(find_navigation_regions(child))
	
	return regions

# Check if a point is inside a navigation polygon
func is_point_in_navigation_polygon(point: Vector2, nav_poly: NavigationPolygon) -> bool:
	var polygons = nav_poly.polygons
	var vertices = nav_poly.vertices
	
	# Check each polygon
	for polygon in polygons:
		var poly_points = []
		for idx in polygon:
			if idx < vertices.size():
				poly_points.append(vertices[idx])
		
		# Use point-in-polygon test
		if is_point_in_polygon(point, poly_points):
			return true
	
	return false

# Point-in-polygon algorithm (ray casting)
func is_point_in_polygon(point: Vector2, polygon: Array) -> bool:
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

# Animate the transition from current position to target position on new layer
func animate_layer_transition() -> void:
	is_animating_transition = true
	
	# Calculate transition duration based on distance
	var distance = global_position.distance_to(final_target_position)
	var transition_duration = distance / speed
	
	# Cancel any existing tween
	if tween:
		tween.kill()
	
	# Create a new tween for the transition
	tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	# Animate position to the target
	tween.tween_property(self, "global_position", final_target_position, transition_duration)
	
	# When transition completes, switch layers and reset state
	tween.finished.connect(_on_transition_finished)
	
	print("Animating transition from ", global_position, " to ", final_target_position)

# Called when the layer transition animation finishes
func _on_transition_finished() -> void:
	# Switch to the new navigation layer
	switch_to_layer(target_nav_layer)
	is_animating_transition = false
	
	print("Transition animation completed")

# Switch the player to a different navigation layer
func switch_to_layer(layer: int) -> void:
	current_nav_layer = layer
	
	# Update the NavigationAgent to use the new layer
	nav_agent.set_navigation_layer_value(1, layer == 1)
	nav_agent.set_navigation_layer_value(2, layer == 2)
	
	# Update cursor manager
	CursorManager.update_cursor_for_layer(layer)
	
	print("Switched to navigation layer: ", layer)
