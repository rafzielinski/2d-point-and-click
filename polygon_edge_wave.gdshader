shader_type canvas_item;

uniform float wave_amplitude : hint_range(0.0, 10.0) = 4.0;
uniform float wave_frequency : hint_range(0.0, 10.0) = 2.5;
uniform float wave_speed : hint_range(0.0, 5.0) = 1.0;
uniform float corner_smoothness : hint_range(0.0, 20.0) = 8.0;
uniform float fluid_spread : hint_range(0.0, 1.0) = 0.3;
uniform float morph_progress : hint_range(0.0, 1.0) = 0.0;
uniform float shape_variation : hint_range(0.0, 1.0) = 0.3;
uniform float random_seed = 0.0;

// Edge offsets (top, right, bottom, left)
uniform vec4 edge_offsets = vec4(100.0, 100.0, 100.0, 100.0);
// Whether each edge uses percentage (1.0) or pixels (0.0)
uniform vec4 edge_is_percentage = vec4(0.0, 0.0, 0.0, 0.0);

uniform vec2 viewport_size = vec2(1920.0, 1080.0);
uniform vec2 polygon_center = vec2(0.0, 0.0);
uniform vec4 shape_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

// Calculate actual pixel offset from percentage or pixel value
float calculate_offset(float offset_value, float is_percentage, float viewport_dimension) {
	if (is_percentage > 0.5) {
		// Percentage mode: offset is 0-100, convert to pixels
		return (offset_value / 100.0) * viewport_dimension;
	} else {
		// Pixel mode: use value directly
		return offset_value;
	}
}

// Elastic ease out with bounce
float ease_elastic_out(float t) {
	float c4 = (2.0 * 3.14159) / 3.0;
	if (t == 0.0) return 0.0;
	if (t == 1.0) return 1.0;
	return pow(2.0, -10.0 * t) * sin((t * 10.0 - 0.75) * c4) + 1.0;
}

// Smooth ease in with back (anticipation)
float ease_back_in(float t) {
	float c1 = 1.70158;
	float c3 = c1 + 1.0;
	return c3 * t * t * t - c1 * t * t;
}

// Combined ease with overshoot and bounce
float ease_bouncy(float t) {
	if (t < 0.5) {
		return ease_back_in(t * 2.0) * 0.5;
	} else {
		return 0.5 + ease_elastic_out((t - 0.5) * 2.0) * 0.5;
	}
}

// Rotation during morph
float morph_rotation(float progress) {
	// Rotate during transition, then settle back
	return sin(progress * 3.14159) * 0.3 * (1.0 - progress * 0.5);
}

// Asymmetric distortion for organic feel
vec2 asymmetric_distortion(vec2 pos, float progress, float time) {
	float angle = atan(pos.y, pos.x);

	// Different distortion on different sides
	float distort_x = sin(angle * 3.0 + progress * 6.28) * progress * (1.0 - progress);
	float distort_y = cos(angle * 2.0 - progress * 6.28) * progress * (1.0 - progress);

	// Add time-based wobble
	distort_x += sin(time * 2.0 + angle) * 0.1 * progress * (1.0 - progress);
	distort_y += cos(time * 1.5 - angle) * 0.1 * progress * (1.0 - progress);

	return vec2(distort_x, distort_y);
}

// 2D noise function for organic motion
float noise2d(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// Organic bulge effect during morph with overshoot
float organic_bulge(float progress) {
	// Create dynamic bulge with overshoot
	float bulge = sin(progress * 3.14159) * 0.35;
	// Add overshoot at the end
	if (progress > 0.7) {
		bulge += sin((progress - 0.7) * 10.0) * 0.15 * (1.0 - progress);
	}
	return bulge;
}

// Generate random organic variation for final shape
float shape_randomness(float angle, float seed) {
	// Multiple noise layers for organic variety
	float n1 = noise2d(vec2(angle * 2.0 + seed, seed * 0.7));
	float n2 = noise2d(vec2(angle * 4.0 - seed, seed * 1.3));
	float n3 = noise2d(vec2(angle * 6.0 + seed * 0.5, seed * 2.1));

	// Combine with different weights
	return (n1 * 0.5 + n2 * 0.3 + n3 * 0.2 - 0.5);
}

// Smooth 2D noise
float smooth_noise2d(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);

	float a = noise2d(i);
	float b = noise2d(i + vec2(1.0, 0.0));
	float c = noise2d(i + vec2(0.0, 1.0));
	float d = noise2d(i + vec2(1.0, 1.0));

	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Generate fluid-like waves
float fluid_wave(float angle, vec2 pos, float time) {
	// Multiple wave layers for fluid motion
	float wave1 = sin(angle * wave_frequency + time * wave_speed) * 0.4;
	float wave2 = smooth_noise2d(vec2(angle * wave_frequency * 0.6, time * wave_speed * 0.7)) * 0.3;
	float wave3 = sin(angle * wave_frequency * 1.3 + time * wave_speed * 1.1) * 0.2;

	// Add position-based variation for more organic feel
	float pos_variation = smooth_noise2d(pos * 0.01 + vec2(time * 0.3, time * 0.2)) * 0.1;

	return (wave1 + wave2 + wave3 + pos_variation);
}

// Calculate vertex curvature for corner smoothing
float calculate_smoothing(vec2 vertex_pos, vec2 center) {
	vec2 dir = vertex_pos - center;
	float angle = atan(dir.y, dir.x);

	// Create smoother transitions at corners using multiple frequencies
	float smooth_factor = 1.0;
	smooth_factor += cos(angle * 4.0) * 0.3; // Helps smooth quadrilateral corners
	smooth_factor += cos(angle * 8.0) * 0.15; // Adds fine detail

	return smooth_factor;
}

void vertex() {
	vec2 center = polygon_center;
	vec2 original_vertex = VERTEX;
	vec2 direction = original_vertex - center;
	float distance = length(direction);

	// Apply bouncy easing to morph progress
	float eased_progress = ease_bouncy(morph_progress);

	// Apply rotation during morph
	float rotation = morph_rotation(morph_progress);
	float cos_rot = cos(rotation);
	float sin_rot = sin(rotation);
	vec2 rotated_dir = vec2(
		direction.x * cos_rot - direction.y * sin_rot,
		direction.x * sin_rot + direction.y * cos_rot
	);
	direction = rotated_dir;

	// Calculate target rectangle vertex position with individual edge offsets
	vec2 normalized_dir = vec2(0.0);
	if (distance > 0.0) {
		normalized_dir = normalize(direction);
	}

	// Calculate actual offsets for each edge
	float offset_top = calculate_offset(edge_offsets.x, edge_is_percentage.x, viewport_size.y);
	float offset_right = calculate_offset(edge_offsets.y, edge_is_percentage.y, viewport_size.x);
	float offset_bottom = calculate_offset(edge_offsets.z, edge_is_percentage.z, viewport_size.y);
	float offset_left = calculate_offset(edge_offsets.w, edge_is_percentage.w, viewport_size.x);

	// Target position: expand to viewport edges minus offsets
	float half_width = viewport_size.x * 0.5;
	float half_height = viewport_size.y * 0.5;

	// Calculate bounds with offsets
	float right_bound = half_width - offset_right;
	float left_bound = -half_width + offset_left;
	float top_bound = -half_height + offset_top;
	float bottom_bound = half_height - offset_bottom;

	// Use the tightest bounds
	float usable_width = right_bound - left_bound;
	float usable_height = bottom_bound - top_bound;
	half_width = usable_width * 0.5;
	half_height = usable_height * 0.5;

	// Adjust center based on offsets
	vec2 offset_center = center + vec2((left_bound + right_bound) * 0.5, (top_bound + bottom_bound) * 0.5);

	// Create rounded rectangle shape instead of sharp corners
	float corner_radius = min(half_width, half_height) * 0.15; // 15% corner radius

	// Map vertex to rounded rectangle
	vec2 rect_pos = offset_center;
	vec2 target_pos = offset_center;
	float abs_x = abs(normalized_dir.x);
	float abs_y = abs(normalized_dir.y);

	if (abs_x > abs_y) {
		// Primarily horizontal direction
		rect_pos.x = offset_center.x + sign(normalized_dir.x) * (half_width - corner_radius);
		float y_ratio = normalized_dir.y / abs_x;
		rect_pos.y = offset_center.y + y_ratio * (half_height - corner_radius);

		// Add corner rounding
		if (abs(y_ratio) > 0.7) {
			float corner_t = (abs(y_ratio) - 0.7) / 0.3;
			rect_pos.x += sign(normalized_dir.x) * corner_radius * (1.0 - sqrt(1.0 - corner_t * corner_t));
		}
	} else if (distance > 0.0) {
		// Primarily vertical direction
		rect_pos.y = offset_center.y + sign(normalized_dir.y) * (half_height - corner_radius);
		float x_ratio = normalized_dir.x / abs_y;
		rect_pos.x = offset_center.x + x_ratio * (half_width - corner_radius);

		// Add corner rounding
		if (abs(x_ratio) > 0.7) {
			float corner_t = (abs(x_ratio) - 0.7) / 0.3;
			rect_pos.y += sign(normalized_dir.y) * corner_radius * (1.0 - sqrt(1.0 - corner_t * corner_t));
		}
	}

	target_pos = rect_pos;

	// Add random organic variation to final shape (only when fully morphed)
	float angle = atan(normalized_dir.y, normalized_dir.x);
	float random_variation = shape_randomness(angle, random_seed);
	float variation_amount = shape_variation * eased_progress * min(half_width, half_height);
	vec2 variation_offset = normalized_dir * random_variation * variation_amount;

	// Apply variation keeping within bounds
	target_pos += variation_offset * 0.8; // 0.8 to ensure it stays safely within bounds

	// Add organic bulge effect with overshoot
	float bulge = organic_bulge(morph_progress);
	vec2 bulge_offset = normalize(direction) * bulge * min(half_width, half_height) * 0.4;

	// Add asymmetric distortion for organic warping
	vec2 distortion = asymmetric_distortion(direction, morph_progress, TIME);
	vec2 distortion_offset = distortion * min(half_width, half_height) * 0.15;

	// Interpolate between original (with rotation) and target
	vec2 rotated_vertex = center + direction;
	vec2 morphed_pos = mix(rotated_vertex, target_pos, eased_progress);

	// Apply bulge and distortion
	morphed_pos += bulge_offset * eased_progress * (1.0 - eased_progress) * 4.0;
	morphed_pos += distortion_offset;

	// Calculate wave effects on morphed position
	vec2 wave_direction = morphed_pos - center;
	float wave_distance = length(wave_direction);

	if (wave_distance > 0.0) {
		vec2 wave_normal = normalize(wave_direction);
		float angle = atan(wave_direction.y, wave_direction.x);

		// Calculate wave displacement (reduce during morph for cleaner animation)
		float wave_scale = 1.0 - eased_progress * 0.3; // Reduce waves slightly during morph
		float wave = fluid_wave(angle, morphed_pos, TIME) * wave_scale;

		// Calculate corner smoothing factor
		float smooth_factor = calculate_smoothing(morphed_pos, center);

		// Apply smoothing that rounds corners
		float smooth_displacement = smooth_factor * corner_smoothness;

		// Combine wave and smoothing
		float total_displacement = wave * wave_amplitude + smooth_displacement * fluid_spread;

		// Apply displacement to morphed position
		morphed_pos += wave_normal * total_displacement;
	}

	VERTEX = morphed_pos;
}

void fragment() {
	COLOR = shape_color;
}