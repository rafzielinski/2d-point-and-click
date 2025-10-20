extends Node

# GameManager - Singleton for managing scene transitions
# This autoload script handles scene changing throughout the game

# Signal emitted when a scene change is requested
signal scene_change_requested(scene_path: String)

# Current scene path
var current_scene_path: String = ""

# Flag to prevent multiple scene changes at once
var is_changing_scene: bool = false


func _ready() -> void:
	# Store the initial scene path
	var root = get_tree().root
	current_scene_path = root.get_child(root.get_child_count() - 1).scene_file_path
	print("GameManager initialized. Current scene: ", current_scene_path)


# Change to a new scene
func change_scene(scene_path: String) -> void:
	# Prevent multiple scene changes
	if is_changing_scene:
		print("Scene change already in progress")
		return
	
	# Validate scene path
	if not ResourceLoader.exists(scene_path):
		push_error("Scene does not exist: " + scene_path)
		return
	
	print("Changing scene to: ", scene_path)
	is_changing_scene = true
	
	# Emit signal for any listeners
	scene_change_requested.emit(scene_path)
	
	# Use deferred call to change scene after current frame
	call_deferred("_deferred_change_scene", scene_path)


# Actually perform the scene change (called deferred)
func _deferred_change_scene(scene_path: String) -> void:
	# Get the current scene using Godot's maintained reference
	var root = get_tree().root
	var current_scene = get_tree().current_scene
	
	if current_scene == null:
		push_error("No current scene found")
		is_changing_scene = false
		return
	
	# IMPORTANT: Remove the scene from tree FIRST, then free it
	# This ensures it's not in the tree when we add the new scene
	root.remove_child(current_scene)
	current_scene.queue_free()
	
	# Load the new scene
	var new_scene = load(scene_path).instantiate()
	
	# Add the new scene to the tree
	root.add_child(new_scene)
	
	# Set it as the current scene
	get_tree().current_scene = new_scene
	current_scene_path = scene_path
	
	is_changing_scene = false
	print("Scene changed successfully to: ", scene_path)


# Get the current scene path
func get_current_scene_path() -> String:
	return current_scene_path