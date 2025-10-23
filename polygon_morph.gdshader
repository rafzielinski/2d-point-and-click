shader_type canvas_item;

uniform float fade_progress : hint_range(0.0, 1.0) = 1.0;
uniform bool is_fading_out = false;

void fragment() {
	vec4 color = COLOR;
	
	if (is_fading_out) {
		// Fade out with slight scale effect
		color.a *= (1.0 - fade_progress);
	} else {
		// Fade in with slight scale effect
		color.a *= fade_progress;
	}
	
	COLOR = color;
}