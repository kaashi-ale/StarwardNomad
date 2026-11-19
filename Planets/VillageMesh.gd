extends RefCounted
## Packs colored settlement props into one mesh per building or articulated part.

var _surface := SurfaceTool.new()
var _box := BoxMesh.new()
var _roof := PrismMesh.new()
var _sphere := SphereMesh.new()


func _init() -> void:
	_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	_sphere.radial_segments = 7
	_sphere.rings = 3


func box(at: Vector3, size: Vector3, tint: Color, tilt := 0.0) -> void:
	_add(_box.get_mesh_arrays(), at, size, tint, tilt)


func roof(at: Vector3, size: Vector3, tint: Color) -> void:
	_add(_roof.get_mesh_arrays(), at, size, tint, 0.0)


func oval(at: Vector3, size: Vector3, tint: Color, tilt := 0.0) -> void:
	_add(_sphere.get_mesh_arrays(), at, size, tint, tilt)


func bake(parent: Node3D, at := Vector3.ZERO) -> MeshInstance3D:
	_surface.index()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.9
	_surface.set_material(material)
	var model := MeshInstance3D.new()
	model.mesh = _surface.commit()
	parent.add_child(model)
	model.position = at
	return model


func _add(arrays: Array, at: Vector3, size: Vector3, tint: Color, tilt: float) -> void:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var rotation := Basis(Vector3.BACK, tilt)
	for index in indices:
		_surface.set_color(tint)
		_surface.set_normal((rotation * (normals[index] / size)).normalized())
		_surface.add_vertex(rotation * (vertices[index] * size) + at)
