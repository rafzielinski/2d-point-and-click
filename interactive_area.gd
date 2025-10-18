extends Area2D

# Interactive Area - Registers with CursorManager to show different cursor on hover
# This script should be attached to Area2D nodes that you want to be interactive

func _ready() -> void:
	# Enable input pickable so mouse signals work
	input_pickable = true
	monitoring = true
	monitorable = true
	
	# Register this area with the CursorManager
	CursorManager.register_interactive_area(self)
	
	# Optional: Set a name for debugging
	if name == "Area2D":
		name = "InteractiveArea"
	
	print("Interactive area registered: ", name, " (input_pickable: ", input_pickable, ")")
