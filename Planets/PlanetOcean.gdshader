shader_type spatial;
render_mode diffuse_lambert, vertex_lighting;

uniform vec4 deep : source_color;
uniform vec4 shallows : source_color;
uniform bool ice = false;
varying vec3 world_grid;
varying float depth;

void vertex() {
	world_grid = VERTEX;
	depth = COLOR.r * 105.0 - 32.0;
}

void fragment() {
	vec2 waves = world_grid.xz + world_grid.y * vec2(0.41, 0.23);
	float ripples = sin(waves.x * 0.31 + waves.y * 0.19 + TIME * (ice ? 0.0 : 0.88));
	float bands = sin(waves.y * 0.67 - waves.x * 0.30 + TIME * (ice ? 0.0 : -0.52));
	float edge = 1.0 - smoothstep(0.3, 2.6, max(depth, 0.0) + ripples * 0.47);
	vec3 tint = mix(shallows.rgb, deep.rgb, smoothstep(0.8, 34.0, depth));
	tint = mix(tint, vec3(0.79, 0.88, 0.86), edge * (ice ? 0.38 : 0.33));
	ALBEDO = tint * (0.98 + ripples * bands * (ice ? 0.065 : 0.038));
	ROUGHNESS = ice ? 0.68 : 0.33;
	SPECULAR = 0.28;
}
