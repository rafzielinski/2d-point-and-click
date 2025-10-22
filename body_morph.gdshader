shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float time = 0.0;
uniform float wave_amplitude : hint_range(0.0, 0.05) = 0.02;
uniform float wave_frequency : hint_range(0.0, 15.0) = 8.0;
uniform float wave_speed : hint_range(0.0, 3.0) = 1.5;
uniform vec4 base_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

// Noise-like function for irregular edges
float noise(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// Smooth noise for organic deformation
float smooth_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	
	float a = noise(i);
	float b = noise(i + vec2(1.0, 0.0));
	float c = noise(i + vec2(0.0, 1.0));
	float d = noise(i + vec2(1.0, 1.0));
	
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Generate irregular edge distortion like magnetic fluid
float magnetic_fluid_edge(vec2 uv, float angle, float prog) {
	// Multiple layers of noise at different frequencies for complex organic shapes
	float n1 = smooth_noise(vec2(angle * wave_frequency + time * wave_speed, prog * 2.0));
	float n2 = smooth_noise(vec2(angle * wave_frequency * 0.5 - time * wave_speed * 0.7, prog * 3.0));
	float n3 = smooth_noise(vec2(angle * wave_frequency * 1.5 + time * wave_speed * 1.2, prog));
	
	// Combine noises for irregular but smooth edges
	float distortion = (n1 * 0.5 + n2 * 0.3 + n3 * 0.2) - 0.5;
	
	// Scale distortion based on progress (more irregular when expanded)
	return distortion * wave_amplitude * prog;
}

// Generate organic blob shape
float generate_shape(vec2 uv, float prog) {
	vec2 centered = uv - vec2(0.5);
	
	// Get angle for edge distortion
	float angle = atan(centered.y, centered.x);
	float dist = length(centered);
	
	// Original organic blob shape
	float organic_noise = smooth_noise(vec2(angle * 3.0, time * 0.3));
	float organic_radius = 0.28 + organic_noise * 0.05;
	
	// Expanded rectangular-ish shape with irregular edges
	vec2 abs_centered = abs(centered);
	float rect_dist = max(abs_centered.x * 1.0, abs_centered.y * 0.5);
	float rect_radius = 0.48;
	
	// Morph between shapes
	float target_radius = mix(organic_radius, rect_radius, prog);
	float target_dist = mix(dist, rect_dist, prog);
	
	// Add magnetic fluid-like edge distortion
	float edge_distortion = magnetic_fluid_edge(uv, angle, prog);
	target_radius += edge_distortion;
	
	// Create smooth shape with subtle anti-aliasing
	float edge_width = 0.005;
	float shape = smoothstep(target_radius + edge_width, target_radius - edge_width, target_dist);
	
	return shape;
}

void fragment() {
	vec2 uv = UV;
	
	// Generate the shape
	float shape = generate_shape(uv, progress);
	
	// Plain black color, no gradients or effects
	COLOR = vec4(base_color.rgb, shape);
}