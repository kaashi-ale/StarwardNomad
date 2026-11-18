class_name PlanetData
extends RefCounted
## Procedural planet biome & physical parameter blueprint.

var planet_name: String = "Aurelia Prime"
var seed_value: int = 1001
var radius: float = 460.0
var atmosphere_height: float = 320.0
var terrain_amplitude: float = 34.0
var noise_frequency: float = 0.0085
var has_ocean: bool = true
var ocean_level_offset: float = -3.5
var gravity_strength: float = 18.0
var has_hostiles: bool = false
var wildlife_count: int = 10
var ruin_count: int = 4

# Visual palette
var sky_zenith: Color = Color(0.12, 0.42, 0.82)
var sky_horizon: Color = Color(0.55, 0.84, 0.95)
var atmosphere_rim: Color = Color(0.32, 0.72, 1.0)
var ocean_color: Color = Color(0.06, 0.45, 0.65, 0.84)

var shore_color: Color = Color(0.84, 0.79, 0.58)
var lowland_color: Color = Color(0.18, 0.58, 0.34)
var highland_color: Color = Color(0.36, 0.42, 0.38)
var peak_color: Color = Color(0.88, 0.92, 0.95)

var tree_canopy_color: Color = Color(0.15, 0.75, 0.48)
var tree_trunk_color: Color = Color(0.38, 0.26, 0.22)
var crystal_color: Color = Color(0.25, 0.95, 0.85)


static func create_presets() -> Array[PlanetData]:
	var list: Array[PlanetData] = []

	# 1. Aurelia Prime (Starting Lush Forest & Archipelago World)
	var p1 := PlanetData.new()
	p1.planet_name = "Aurelia Prime"
	p1.seed_value = 1042
	p1.radius = 480.0
	p1.atmosphere_height = 330.0
	p1.terrain_amplitude = 32.0
	p1.noise_frequency = 0.0078
	p1.has_ocean = true
	p1.ocean_level_offset = -4.0
	p1.gravity_strength = 18.0
	p1.has_hostiles = false
	p1.wildlife_count = 12
	p1.ruin_count = 5
	p1.sky_zenith = Color(0.11, 0.44, 0.84)
	p1.sky_horizon = Color(0.54, 0.86, 0.94)
	p1.atmosphere_rim = Color(0.30, 0.78, 1.0)
	p1.ocean_color = Color(0.05, 0.48, 0.68, 0.84)
	p1.shore_color = Color(0.86, 0.80, 0.58)
	p1.lowland_color = Color(0.16, 0.56, 0.33)
	p1.highland_color = Color(0.35, 0.40, 0.37)
	p1.peak_color = Color(0.92, 0.95, 0.98)
	p1.tree_canopy_color = Color(0.14, 0.78, 0.52)
	p1.crystal_color = Color(0.22, 0.95, 0.82)
	list.append(p1)

	# 2. Pyros V (Crimson Basalt Canyons & Sentinel Ruins)
	var p2 := PlanetData.new()
	p2.planet_name = "Pyros V"
	p2.seed_value = 2089
	p2.radius = 420.0
	p2.atmosphere_height = 300.0
	p2.terrain_amplitude = 42.0
	p2.noise_frequency = 0.0095
	p2.has_ocean = false
	p2.gravity_strength = 19.5
	p2.has_hostiles = true
	p2.wildlife_count = 6
	p2.ruin_count = 5
	p2.sky_zenith = Color(0.42, 0.12, 0.09)
	p2.sky_horizon = Color(0.92, 0.46, 0.24)
	p2.atmosphere_rim = Color(1.0, 0.42, 0.20)
	p2.shore_color = Color(0.52, 0.22, 0.16)
	p2.lowland_color = Color(0.68, 0.28, 0.17)
	p2.highland_color = Color(0.32, 0.22, 0.22)
	p2.peak_color = Color(0.88, 0.62, 0.38)
	p2.tree_canopy_color = Color(0.95, 0.42, 0.16)
	p2.crystal_color = Color(1.0, 0.32, 0.18)
	list.append(p2)

	# 3. Glacius IX (Crystalline Tundra & Frozen Seas)
	var p3 := PlanetData.new()
	p3.planet_name = "Glacius IX"
	p3.seed_value = 3371
	p3.radius = 510.0
	p3.atmosphere_height = 340.0
	p3.terrain_amplitude = 38.0
	p3.noise_frequency = 0.0082
	p3.has_ocean = true
	p3.ocean_level_offset = -5.0
	p3.gravity_strength = 16.5
	p3.has_hostiles = true
	p3.wildlife_count = 8
	p3.ruin_count = 4
	p3.sky_zenith = Color(0.08, 0.24, 0.48)
	p3.sky_horizon = Color(0.66, 0.90, 0.98)
	p3.atmosphere_rim = Color(0.50, 0.92, 1.0)
	p3.ocean_color = Color(0.18, 0.66, 0.82, 0.88)
	p3.shore_color = Color(0.72, 0.88, 0.95)
	p3.lowland_color = Color(0.82, 0.92, 0.97)
	p3.highland_color = Color(0.45, 0.62, 0.78)
	p3.peak_color = Color(0.98, 0.99, 1.0)
	p3.tree_canopy_color = Color(0.32, 0.85, 0.95)
	p3.crystal_color = Color(0.40, 0.95, 1.0)
	list.append(p3)

	# 4. Veridian Mire (Bioluminescent Violet Jungle)
	var p4 := PlanetData.new()
	p4.planet_name = "Veridian Mire"
	p4.seed_value = 4912
	p4.radius = 450.0
	p4.atmosphere_height = 320.0
	p4.terrain_amplitude = 30.0
	p4.noise_frequency = 0.0090
	p4.has_ocean = true
	p4.ocean_level_offset = -2.0
	p4.gravity_strength = 17.5
	p4.has_hostiles = true
	p4.wildlife_count = 12
	p4.ruin_count = 4
	p4.sky_zenith = Color(0.24, 0.11, 0.46)
	p4.sky_horizon = Color(0.74, 0.48, 0.88)
	p4.atmosphere_rim = Color(0.78, 0.42, 1.0)
	p4.ocean_color = Color(0.28, 0.14, 0.52, 0.85)
	p4.shore_color = Color(0.56, 0.44, 0.68)
	p4.lowland_color = Color(0.32, 0.18, 0.48)
	p4.highland_color = Color(0.22, 0.36, 0.34)
	p4.peak_color = Color(0.84, 0.72, 0.96)
	p4.tree_canopy_color = Color(0.88, 0.32, 0.82)
	p4.crystal_color = Color(0.92, 0.42, 1.0)
	list.append(p4)

	# 5. Dusthaven (Ochre Desert & Ancient Relays)
	var p5 := PlanetData.new()
	p5.planet_name = "Dusthaven"
	p5.seed_value = 5507
	p5.radius = 390.0
	p5.atmosphere_height = 280.0
	p5.terrain_amplitude = 28.0
	p5.noise_frequency = 0.0072
	p5.has_ocean = false
	p5.gravity_strength = 15.0
	p5.has_hostiles = false
	p5.wildlife_count = 7
	p5.ruin_count = 6
	p5.sky_zenith = Color(0.36, 0.26, 0.14)
	p5.sky_horizon = Color(0.94, 0.78, 0.52)
	p5.atmosphere_rim = Color(0.96, 0.76, 0.44)
	p5.shore_color = Color(0.82, 0.64, 0.38)
	p5.lowland_color = Color(0.88, 0.68, 0.38)
	p5.highland_color = Color(0.64, 0.46, 0.28)
	p5.peak_color = Color(0.95, 0.86, 0.68)
	p5.tree_canopy_color = Color(0.55, 0.68, 0.32)
	p5.crystal_color = Color(0.98, 0.82, 0.30)
	list.append(p5)

	return list
