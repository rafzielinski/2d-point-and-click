extends Button

# SceneExitButton - A button that makes the character walk to it and changes scene
# When clicked, the character navigates to this button, and upon arrival, changes to the target scene

# The scene to load when the character reaches this button
@export_file("*.tscn") var target_scene: String = ""

# Reference to the character (will be found automatically)
var character: CharacterBody2D = null

# Track if character is navigating to this button
var is_navigating_to_button: bool = false

# The position the character should navigate to (center of button in world space)
var target_position: Vector2


func _ready() -> void:
	# Connect the button's pressed signal
	pressed.connect(_on_button_pressed)
	
	# Find the character in the scene
	await get_tree().process_frame  # Wait for scene to be fully loaded
	character = _find_character()
	
	if character == null:
		push_warning("SceneExitButton: Could not find CharacterBody2D in scene")
	
	# Calculate the target position (center of button in world space)
	target_position = global_position + size / 2


func _process(_delta: float) -> void:
	# If character is navigating to this button, check if they've arrived
	if is_navigating_to_button and character != null:
		# Check if character is close enough to the button
		var distance = character.global_position.distance_to(target_position)
		
		# If within a reasonable distance, trigger scene change
		if distance < 30.0:  # 30 pixels threshold
			_on_character_arrived()


func _on_button_pressed() -> void:
	if character == null:
		push_error("SceneExitButton: No character found to navigate")
		return
	
	if target_scene.is_empty():
		push_error("SceneExitButton: No target scene specified")
		return
	
	print("SceneExitButton clicked - navigating character to button at ", target_position)
	
	# Set the character's navigation target to this button's position
	if character.has_node("NavigationAgent2D"):
		var nav_agent = character.get_node("NavigationAgent2D") as NavigationAgent2D
		nav_agent.target_position = target_position
		is_navigating_to_button = true
	else:
		push_error("SceneExitButton: Character does not have NavigationAgent2D")


func _on_character_arrived() -> void:
	print("Character arrived at button - changing scene to: ", target_scene)
	
	# Reset navigation flag
	is_navigating_to_button = false
	
	# Change the scene using GameManager
	GameManager.change_scene(target_scene)


# Find the CharacterBody2D in the scene (assumes there's only one)
func _find_character() -> CharacterBody2D:
	# Get the root node of the current scene
	var root = get_tree().current_scene
	
	# Search for CharacterBody2D
	return _find_character_recursive(root)


# Recursively search for CharacterBody2D
func _find_character_recursive(node: Node) -> CharacterBody2D:
	# Check if this node is a CharacterBody2D
	if node is CharacterBody2D:
		return node
	
	# Search children
	for child in node.get_children():
		var result = _find_character_recursive(child)
		if result != null:
			return result
	
	return null
