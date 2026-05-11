shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_always;

uniform vec3 source_positions[8];
uniform float source_radii[8];
uniform int source_count = 0;
uniform vec3 albedo_color : source_color = vec3(1.0, 1.0, 1.0);

varying vec3 world_pos;


void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}


void fragment() {
	float best = 0.0;
	for (int i = 0; i < 8; i++) {
		if (i >= source_count) break;
		float dist = distance(world_pos, source_positions[i]);
		float cov = 1.0 - smoothstep(source_radii[i] * 0.75, source_radii[i], dist);
		best = max(best, cov);
	}

	if (best <= 0.0) {
		discard;
	}

	ALBEDO = albedo_color + vec3(best * 0.2); // Add a bit of white to the glow
	ALPHA = best;
	EMISSION = albedo_color * best * 0.3;
	ROUGHNESS = 0.5;
	METALLIC = 0.0;
}
