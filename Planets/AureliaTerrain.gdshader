shader_type spatial;

uniform sampler2D surface_grain : hint_default_white, filter_linear_mipmap, repeat_enable;
varying vec3 ground_position;

void vertex() {
	ground_position = VERTEX;
}

void fragment() {
	vec2 uv = (ground_position.xz + ground_position.y * vec2(0.31, 0.19)) * 0.18;
	float grain = texture(surface_grain, uv).r - 0.5;
	vec3 stone = mix(COLOR.rgb, COLOR.rgb * vec3(1.14, 0.94, 0.75), smoothstep(0.0, 0.3, grain));
	ALBEDO = stone * (1.0 + grain * 0.44);
	ROUGHNESS = 0.94;
	SPECULAR = 0.18;
}
