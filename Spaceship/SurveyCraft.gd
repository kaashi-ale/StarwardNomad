extends Node3D
## A courier retrofitted for survey work, with an inset canopy and twin engine pods.


func _ready() -> void:
	var ivory := _finish(Color("#beb8a4"), 0.42, 0.25)
	var ceramic := _finish(Color("#2a3945"), 0.53, 0.20)
	var copper := _finish(Color("#bc623f"), 0.47, 0.28)
	var glass := _finish(Color("#214658"), 0.18, 0.58)
	var lamp := _finish(Color("#92f0d8"), 0.37, 0.0)
	lamp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	_loft([Vector4(-3.0, 0.14, 0.55, 0.26), Vector4(-1.62, 0.25, 1.15, 0.58),
		Vector4(0.24, 0.28, 1.36, 0.68), Vector4(2.4, 0.14, 0.96, 0.55)], ivory)
	_loft([Vector4(-2.23, 0.48, 0.46, 0.18), Vector4(-0.63, 0.77, 0.83, 0.44),
		Vector4(0.57, 0.7, 0.7, 0.31)], glass)
	_loft([Vector4(-2.68, -0.18, 0.43, 0.19), Vector4(-0.5, -0.22, 1.12, 0.37),
		Vector4(2.45, -0.18, 0.96, 0.33)], ceramic)
	for side: float in [-1.0, 1.0]:
		var wing := BoxMesh.new()
		wing.size = Vector3(1.95, 0.16, 1.36)
		var spar := _part(wing, copper, Vector3(side * 1.9, 0.1, 0.58))
		spar.rotation.y = -side * 0.45
		var pod := CylinderMesh.new()
		pod.top_radius = 0.35
		pod.bottom_radius = 0.46
		pod.height = 2.9
		pod.radial_segments = 8
		var nacelle := _part(pod, ceramic, Vector3(side * 2.32, 0.14, 0.78))
		nacelle.rotation.x = PI * 0.5
		var nozzle := CylinderMesh.new()
		nozzle.top_radius = 0.37
		nozzle.bottom_radius = 0.4
		nozzle.height = 0.26
		nozzle.radial_segments = 8
		_part(nozzle, copper, Vector3(side * 2.32, 0.14, 2.13)).rotation.x = PI * 0.5
		var lens := BoxMesh.new()
		lens.size = Vector3(0.38, 0.12, 0.05)
		_part(lens, lamp, Vector3(side * 2.32, 0.14, 2.27))

	var stripe := BoxMesh.new()
	stripe.size = Vector3(0.055, 0.1, 0.72)
	_part(stripe, lamp, Vector3(1.31, 0.18, 0.24))
	var boarding := BoxMesh.new()
	boarding.size = Vector3(0.64, 0.14, 0.8)
	_part(boarding, ceramic, Vector3(1.30, -0.65, 0.24))


func _loft(sections: Array[Vector4], material: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	var vertices: Array[Vector3] = []
	for section in sections:
		for side in range(8):
			var angle := (side + 0.5) * TAU / 8.0
			vertices.append(Vector3(cos(angle) * section.z, section.y + sin(angle) * section.w, section.x))
	for ring in range(sections.size() - 1):
		for side in range(8):
			var a := ring * 8 + side
			var b := ring * 8 + (side + 1) % 8
			for index: int in [a, a + 8, b, b, a + 8, b + 8]:
				surface.add_vertex(vertices[index])
	var back := (sections.size() - 1) * 8
	for side in range(1, 7):
		for index: int in [0, side, side + 1, back, back + side + 1, back + side]:
			surface.add_vertex(vertices[index])
	surface.generate_normals()
	var engine_part := MeshInstance3D.new()
	engine_part.mesh = surface.commit()
	engine_part.material_override = material
	add_child(engine_part)


func _finish(color: Color, roughness: float, metal: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metal
	return mat


func _part(mesh: PrimitiveMesh, material: Material, offset: Vector3) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	mesh.material = material
	piece.mesh = mesh
	add_child(piece)
	piece.position = offset
	return piece
