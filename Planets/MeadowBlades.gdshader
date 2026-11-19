shader_type spatial;
render_mode cull_disabled, vertex_lighting, diffuse_lambert;

void vertex() {
	float sway = sin(TIME * 1.65 + MODEL_MATRIX[3].x * 0.09 + MODEL_MATRIX[3].z * 0.07);
	VERTEX.x += sway * VERTEX.y * VERTEX.y * 0.18;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
}
