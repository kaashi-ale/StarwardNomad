shader_type spatial;
render_mode vertex_lighting, diffuse_lambert;

uniform sampler2D surface_grain : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float meadow = 0.0;
varying vec3 ground_position;
varying float flatness;

void vertex() {
	ground_position = VERTEX;
	flatness = dot(normalize(VERTEX), NORMAL);
}

void fragment() {
	vec2 ground = ground_position.xz + ground_position.y * vec2(0.31, 0.19);
	float patches = texture(surface_grain, ground * 0.13).r - 0.5;
	float fibers = texture(surface_grain, ground * vec2(1.8, 3.8) + vec2(0.13, 0.54)).r - 0.5;
	float turf = meadow * smoothstep(0.79, 0.96, flatness);
	vec3 grass = mix(vec3(0.79, 0.90, 0.63), vec3(1.01, 1.13, 0.86), smoothstep(-0.19, 0.25, patches));
	vec3 stone = COLOR.rgb * (1.0 + patches * 0.35);
	ALBEDO = mix(stone, COLOR.rgb * grass * (1.0 + fibers * 0.24), turf);
	ROUGHNESS = 0.98;
	SPECULAR = 0.10;
}
