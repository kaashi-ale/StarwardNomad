shader_type spatial;
render_mode vertex_lighting, diffuse_lambert;

uniform sampler2D surface_grain : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float meadow = 0.0;
uniform bool grove_enabled = false;
uniform vec3 grove_right = vec3(1.0, 0.0, 0.0);
uniform vec3 grove_forward = vec3(0.0, 0.0, -1.0);
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
	if (grove_enabled) {
		vec2 site = vec2(dot(ground_position, grove_right), dot(ground_position, grove_forward));
		float rim = length((site - vec2(25.0, 63.0)) / vec2(28.0, 29.0));
		float side = dot(normalize(ground_position), cross(grove_right, grove_forward));
		float grove = (1.0 - smoothstep(0.74, 1.01, rim)) * smoothstep(0.90, 0.99, side);
		if (grove > 0.001) {
			float coarse = texture(surface_grain, site * 0.44 + vec2(0.8, 0.3)).r;
			float delta = site.y - 61.0;
			float center = 25.0 + delta * 0.68 + sin(delta * 0.105) * 3.1;
			float trail = 1.0 - smoothstep(1.1, 2.65, abs(site.x - center) + (coarse - 0.5) * 1.9);
			float glade = 1.0 - smoothstep(3.2, 8.0, length(site - vec2(12.5, 69.0)));
			vec3 litter = mix(vec3(0.32, 0.37, 0.19), vec3(0.44, 0.48, 0.29), coarse);
			vec3 dust = mix(vec3(0.43, 0.33, 0.22), vec3(0.60, 0.49, 0.33), coarse);
			vec3 floor_tint = mix(litter, ALBEDO * 1.07, glade * 0.81);
			ALBEDO = mix(ALBEDO, mix(floor_tint, dust, trail), grove * 0.83);
		}
	}
	ROUGHNESS = 0.98;
	SPECULAR = 0.10;
}
