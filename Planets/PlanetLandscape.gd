extends RefCounted
## Deterministic regional fields sampled in planet-local coordinates.

const AURELIA_UP := Vector3(0.180171244, 0.960913302, 0.210199785)
const VILLAGE_OFFSET := Vector2(28.0, 104.0)

var data: PlanetData
var _continental: FastNoiseLite
var _ranges: FastNoiseLite
var _rolling: FastNoiseLite
var _surface: FastNoiseLite
var _wet: FastNoiseLite
var _legacy: FastNoiseLite
var _legacy_detail: FastNoiseLite
var _village_up := Vector3.ZERO


func _init(planet: PlanetData) -> void:
	data = planet
	_continental = _noise(13, 0.00115, 3)
	_ranges = _noise(381, 0.0032, 3)
	_rolling = _noise(53, data.noise_frequency, 3)
	_surface = _noise(777, 0.018, 2)
	_wet = _noise(81, 0.00255, 3)
	if data.landscape == PlanetData.Landscape.AURELIA:
		_legacy = _noise(0, data.noise_frequency, 4)
		_legacy.fractal_lacunarity = 2.05
		_legacy.fractal_gain = 0.48
		_legacy_detail = _noise(777, data.noise_frequency * 4.5, 2)
		var right := Vector3.RIGHT.cross(AURELIA_UP).normalized()
		_village_up = (AURELIA_UP * (data.radius + 9.0) + right * VILLAGE_OFFSET.x + AURELIA_UP.cross(right) * VILLAGE_OFFSET.y).normalized()


func height(direction: Vector3) -> float:
	var p := direction * data.radius
	var continental := _continental.get_noise_3dv(p)
	var mountain := _ranges.get_noise_3dv(p)
	var hills := _rolling.get_noise_3dv(p)
	var ground := _surface.get_noise_3dv(p)
	var ridge := pow(1.0 - absf(mountain), 5.0)
	var range_mask := smoothstep(-0.02, 0.48, continental + hills * 0.19)
	var relief := 0.0
	match data.landscape:
		PlanetData.Landscape.AURELIA:
			var shelf := smoothstep(-0.55, 0.29, continental)
			relief = -0.58 + shelf * 0.78 + range_mask * ridge * 0.68 + hills * 0.21 + ground * 0.027
		PlanetData.Landscape.PYROS:
			var canyon := pow(1.0 - absf(hills), 8.0) * smoothstep(-0.4, 0.21, -mountain)
			var volcanic := smoothstep(-0.02, 0.67, mountain + continental * 0.17)
			relief = continental * 0.33 + volcanic * volcanic * 1.02 - canyon * 0.30 + ground * 0.043
		PlanetData.Landscape.GLACIUS:
			var cirques := smoothstep(-0.39, 0.29, continental)
			relief = -0.59 + cirques * 0.76 + range_mask * ridge * 0.74 + hills * 0.17 + ground * 0.025
		PlanetData.Landscape.VERIDIAN:
			var terraces := smoothstep(-0.53, 0.30, continental)
			relief = -0.29 + terraces * 0.57 + range_mask * ridge * 0.40 + hills * 0.15 + ground * 0.023
		PlanetData.Landscape.DUSTHAVEN:
			var mesas := smoothstep(0.08, 0.31, continental + mountain * 0.38)
			var dunes := sin(p.dot(Vector3(0.48, 0.16, -0.83)) * 0.079 + mountain * 4.0 + hills * 1.9)
			relief = -0.22 + mesas * 0.66 + (1.0 - mesas) * dunes * 0.070 + hills * 0.14 + ground * 0.019
	var result := clampf(relief, -0.85, 1.19) * data.terrain_amplitude
	if data.landscape == PlanetData.Landscape.AURELIA:
		var distance := direction.distance_to(AURELIA_UP) * data.radius
		if distance < 275.0:
			result = lerpf(_authored_height(direction, p, distance), result, smoothstep(145.0, 275.0, distance))
	return result


func _authored_height(direction: Vector3, p: Vector3, distance: float) -> float:
	var coarse := _legacy.get_noise_3dv(p)
	var detail := _legacy_detail.get_noise_3dv(p) * 0.22
	var relief := (coarse + detail) * data.terrain_amplitude
	if relief < 0:
		relief *= 0.65
	var ridge_center := (AURELIA_UP + Vector3(0.055, -0.013, 0.032)).normalized()
	relief += (1.0 - smoothstep(7.0, 64.0, ridge_center.distance_to(direction) * data.radius)) * 26.0
	relief = lerpf(9.0 + coarse * 3.2 + detail * 9.0, relief, smoothstep(45.0, 140.0, distance))
	var village_distance := direction.distance_to(_village_up) * data.radius
	if village_distance < 77.0:
		relief = lerpf((data.radius + 9.0) / direction.dot(_village_up) - data.radius, relief, smoothstep(47.0, 77.0, village_distance))
	return relief


func moisture(direction: Vector3) -> float:
	return _wet.get_noise_3dv(direction * data.radius)


func biome(direction: Vector3, elevation: float, slope := 0.0) -> int:
	var relative := elevation / data.terrain_amplitude
	var wet := moisture(direction)
	var temperature := 1.0 - absf(direction.y) - maxf(relative, 0.0) * 0.38
	if data.has_ocean and elevation < data.ocean_level_offset + 6.0:
		return 3
	if relative > 0.44 or slope > 0.28:
		return 2
	if data.landscape in [PlanetData.Landscape.PYROS, PlanetData.Landscape.DUSTHAVEN]:
		return 1 if wet > 0.29 and slope < 0.15 else (4 if relative > 0.19 else 0)
	var woodland_threshold := -0.22 if data.landscape == PlanetData.Landscape.VERIDIAN else -0.08
	if wet > woodland_threshold and (data.landscape != PlanetData.Landscape.GLACIUS or temperature > 0.25):
		return 1
	return 4 if wet > -0.31 else 0


func tint(direction: Vector3, elevation: float, slope: float, orbital: bool) -> Color:
	var depth := elevation - data.ocean_level_offset
	var relative := elevation / data.terrain_amplitude
	if data.has_ocean and depth < 0.0 and orbital:
		return data.ocean_color.darkened(clampf(-depth / 180.0, 0.0, 0.43))
	var wet := moisture(direction)
	var woodland := data.lowland_color.lerp(data.tree_canopy_color.darkened(0.28), 0.72)
	if data.landscape == PlanetData.Landscape.PYROS:
		woodland = data.lowland_color.darkened(0.32)
	elif data.landscape == PlanetData.Landscape.DUSTHAVEN:
		woodland = data.lowland_color.lerp(data.highland_color, 0.39)
	var plains := data.lowland_color.lerp(woodland, smoothstep(-0.29, 0.25, wet))
	var stone := smoothstep(0.19, 0.54, relative) * 0.82 + smoothstep(0.13, 0.43, slope) * 0.61
	var result := plains.lerp(data.highland_color, clampf(stone, 0.0, 1.0))
	result = result.lerp(data.peak_color, smoothstep(0.52, 0.91, relative) * (1.0 - slope * 0.45))
	if data.has_ocean:
		result = result.lerp(data.shore_color, 1.0 - smoothstep(0.5, 8.0, depth))
	return result


func _noise(offset: int, frequency: float, octaves: int) -> FastNoiseLite:
	var field := FastNoiseLite.new()
	field.seed = data.seed_value + offset
	field.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	field.frequency = frequency
	field.fractal_octaves = octaves
	return field
