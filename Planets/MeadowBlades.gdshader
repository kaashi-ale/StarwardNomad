shader_type spatial;
render_mode cull_disabled, vertex_lighting, diffuse_lambert;

void vertex() {
	// Slot order is stable when the floating origin shifts the world.
	float sway = sin(TIME * 1.65 + float(INSTANCE_ID) * 2.39996);
	VERTEX.x += sway * VERTEX.y * VERTEX.y * 0.18;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
}
