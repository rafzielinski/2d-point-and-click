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


func _ready() -> void:	
	# Configure NavigationAgent properties
	nav_agent.path_desired_distance = 4.0
	nav_agent.target_desired_distance = 10.0
	
	# Wait for the first physics frame so the NavigationServer can sync
	await get_tree().physics_frame


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("click"):
		# Get the clicked position in world coordinates
		var target_position = get_global_mouse_position()
		
		# Check if click is on Window region (layer 2)
		var clicked_layer = get_clicked_navigation_layer(target_position)
		
		if clicked_layer != current_nav_layer:
			# Clicked on different layer - set up transition
			target_nav_layer = clicked_layer
			transitioning_to_layer = true
			# First navigate to a transition point in current region
			nav_agent.target_position = target_position
		else:
			# Clicked on same layer - normal navigation
			nav_agent.target_position = target_position

		print("Clicked layer: ", clicked_layer, " Current layer: ", current_nav_layer)


func _physics_process(delta: float) -> void:
	# Check if navigation is finished
	if nav_agent.is_navigation_finished():
		# If we were on a squish link and finished navigating, unsquish
		if is_on_squish_link:
			unsquish_player()
			is_on_squish_link = false
		
		# Check if we should transition to another layer
		if transitioning_to_layer:
			switch_to_layer(target_nav_layer)
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

# Helper function to detect which navigation layer was clicked
func get_clicked_navigation_layer(position: Vector2) -> int:
	# Get the navigation server
	var nav_server = NavigationServer2D
	
	# Query the map for the clicked position on both layers
	# Layer 2 (Window region)
	var map_layer_2 = nav_agent.get_navigation_map()
	
	# Create a query for layer 2 (window navigation)
	# Check if the position is within the window navigation region
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = position
	
	# For simplicity, we'll check proximity to known Window region
	# The Window region is roughly at position 1024, 507 based on the scene
	var window_center = Vector2(1050, 507)
	var distance_to_window = position.distance_to(window_center)
	
	# If click is near the window region (within 100 pixels), it's layer 2
	if distance_to_window < 100:
		return 2
	
	# Otherwise, it's the main navigation layer
	return 1

# Switch the player to a different navigation layer
func switch_to_layer(layer: int) -> void:
	current_nav_layer = layer
	
	# Update the NavigationAgent to use the new layer
	nav_agent.set_navigation_layer_value(1, layer == 1)
	nav_agent.set_navigation_layer_value(2, layer == 2)
	
	print("Switched to navigation layer: ", layer)
	
	# Optionally, you could trigger an animation or effect here
	# For example, a fade effect or a special transition animation
