extends RefCounted
## Addresses the collision mesh in planet-local space. A cell owns 2×2 terrain quads.
const SPAN := 2
const BLOCK := 4
var vertices: PackedVector3Array
var resolution: int
var groups: Array[Dictionary] = []
var centers := {}


func _init(points: PackedVector3Array, side: int) -> void:
	vertices = points
	resolution = side
	var cells := (side - 1) / SPAN
	for face in range(6):
		for by in range(0, cells, BLOCK):
			for bx in range(0, cells, BLOCK):
				var keys: Array[Vector3i] = []
				var middle := _vertex(face, (bx + 2) * SPAN, (by + 2) * SPAN).normalized()
				var extent := 0.0
				for y in range(by, mini(cells, by + BLOCK)):
					for x in range(bx, mini(cells, bx + BLOCK)):
						var key := Vector3i(face, x, y)
						var center := _vertex(face, x * SPAN + 1, y * SPAN + 1).normalized()
						centers[key] = center
						keys.append(key)
						extent = maxf(extent, center.distance_to(middle))
				groups.append({"center":middle, "extent":extent, "keys":keys})


func _vertex(face: int, x: int, y: int) -> Vector3:
	return vertices[(face * resolution + y) * resolution + x]


func candidates(up: Vector3, lead: Vector3, reach: float) -> Dictionary:
	var found := {}
	for group in groups:
		var middle: Vector3 = group.center
		if minf(up.distance_to(middle), lead.distance_to(middle)) > reach + float(group.extent):
			continue
		for key: Vector3i in group.keys:
			var center: Vector3 = centers[key]
			var here := up.distance_to(center)
			var ahead := lead.distance_to(center)
			if minf(here, ahead) <= reach:
				found[key] = minf(here, ahead + 0.025)
	return found


func point(key: Vector3i, u: float, v: float) -> Vector3:
	# Exactly the two triangles emitted by PlanetTerrainMesh, including their diagonal.
	var x := mini(int(u), SPAN - 1)
	var y := mini(int(v), SPAN - 1)
	var index := (key.x * resolution + key.z * SPAN + y) * resolution + key.y * SPAN + x
	var a := vertices[index]
	var b := vertices[index + 1]
	var c := vertices[index + resolution]
	var fx := u - x
	var fy := v - y
	if fx + fy <= 1.0:
		return a + (b - a) * fx + (c - a) * fy
	var d := vertices[index + resolution + 1]
	return d + (c - d) * (1.0 - fx) + (b - d) * (1.0 - fy)


func normal(key: Vector3i, u: float, v: float) -> Vector3:
	var x := mini(int(u), SPAN - 1)
	var y := mini(int(v), SPAN - 1)
	var index := (key.x * resolution + key.z * SPAN + y) * resolution + key.y * SPAN + x
	var b := vertices[index + 1]
	var c := vertices[index + resolution]
	if u - x + v - y <= 1.0:
		return (b - vertices[index]).cross(c - vertices[index]).normalized()
	var d := vertices[index + resolution + 1]
	return (c - d).cross(b - d).normalized()
