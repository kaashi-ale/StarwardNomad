shader_type sky;

uniform sampler2D cloud_noise : filter_linear_mipmap, repeat_enable;
uniform vec4 zenith : source_color = vec4(0.18, 0.53, 0.82, 1.0);
uniform vec4 horizon : source_color = vec4(0.76, 0.88, 0.96, 1.0);
uniform vec4 below_horizon : source_color = vec4(0.37, 0.59, 0.69, 1.0);
uniform vec3 local_up = vec3(0.0, 1.0, 0.0);
uniform vec3 sun_direction = vec3(0.2, 0.7, 0.6);
uniform float air = 1.0;
uniform float cloud_cover = 0.48;

void sky() {
	float altitude = dot(EYEDIR, local_up);
	float daylight = pow(clamp(altitude, 0.0, 1.0), 0.44);
	vec3 atmosphere = mix(horizon.rgb, zenith.rgb, daylight);
	atmosphere = mix(atmosphere, below_horizon.rgb, smoothstep(0.02, 0.67, -altitude));

	vec3 color = mix(vec3(0.006, 0.009, 0.022), atmosphere, air);
	float sun = max(dot(EYEDIR, sun_direction), 0.0);
	color += vec3(1.0, 0.72, 0.47) * pow(sun, 26.0) * air * 0.21;
	color += vec3(1.0, 0.93, 0.78) * smoothstep(0.9985, 0.9995, sun);
	if (air > 0.03 && altitude > 0.015) {
		vec3 reference = abs(local_up.y) > 0.96 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0);
		vec3 east = normalize(cross(reference, local_up));
		vec3 north = cross(local_up, east);
		vec2 uv = vec2(dot(EYEDIR, east), dot(EYEDIR, north)) * (0.23 / (altitude + 0.27)) + vec2(0.21, 0.59);
		float body = texture(cloud_noise, uv).r;
		float detail = texture(cloud_noise, uv * 3.7 + vec2(0.49, 0.18)).r;
		float density = body * 0.82 + detail * 0.18;
		float cloud = smoothstep(cloud_cover, cloud_cover + 0.085, density);
		float veil = smoothstep(0.045, 0.26, altitude) * air;
		vec3 shaded_cloud = mix(horizon.rgb * 0.88, vec3(1.0, 0.98, 0.92), smoothstep(0.38, 0.71, body));
		color = mix(color, shaded_cloud, cloud * veil * 0.96);
	}
	COLOR = color;
}
