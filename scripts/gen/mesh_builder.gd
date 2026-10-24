class_name MeshBuilder
extends RefCounted
## يدمج مجسّمات بدائية كثيرة في شبكة واحدة بألوان رؤوس وتظليل مسطّح (Low-Poly).
## سطحان: 0 = مضاء، 1 = متوهج (غير مضاء).

static var _prims: Dictionary = {}

var _v: Array = [PackedVector3Array(), PackedVector3Array()]
var _c: Array = [PackedColorArray(), PackedColorArray()]
var _i: Array = [PackedInt32Array(), PackedInt32Array()]


## بدائيات موحّدة الحجم (صندوق 1×1×1، أسطوانة نصف قطر 0.5 وارتفاع 1، كرة قطرها 1)
static func prim(kind: String, segs := 6, rings := 3, top := 1.0) -> Array:
	var key := "%s_%d_%d_%d" % [kind, segs, rings, int(top * 100.0)]
	if _prims.has(key):
		return _prims[key]
	var m: Mesh
	match kind:
		"box":
			var b := BoxMesh.new()
			b.size = Vector3.ONE
			m = b
		"cyl":
			var c := CylinderMesh.new()
			c.top_radius = 0.5 * top
			c.bottom_radius = 0.5
			c.height = 1.0
			c.radial_segments = segs
			c.rings = 1
			m = c
		_:
			var s := SphereMesh.new()
			s.radius = 0.5
			s.height = 1.0
			s.radial_segments = segs
			s.rings = rings
			m = s
	var arrays := m.surface_get_arrays(0)
	var out := [arrays[Mesh.ARRAY_VERTEX], arrays[Mesh.ARRAY_INDEX]]
	_prims[key] = out
	return out


func add(p: Array, pos: Vector3, size: Vector3, col: Color, rot_deg := Vector3.ZERO, glow := false) -> void:
	var g := 1 if glow else 0
	var basis := Basis.from_euler(Vector3(deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z))) * Basis.from_scale(size)
	var xf := Transform3D(basis, pos)
	var src_v: PackedVector3Array = p[0]
	var src_i: PackedInt32Array = p[1]
	var base: int = (_v[g] as PackedVector3Array).size()
	var vv: PackedVector3Array = _v[g]
	var cc: PackedColorArray = _c[g]
	var ii: PackedInt32Array = _i[g]
	for v in src_v:
		vv.append(xf * v)
		cc.append(col)
	for k in src_i:
		ii.append(base + k)


func build(lit_mat: Material, glow_mat: Material = null) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for g in 2:
		var vv: PackedVector3Array = _v[g]
		if vv.is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vv
		arrays[Mesh.ARRAY_COLOR] = _c[g]
		arrays[Mesh.ARRAY_INDEX] = _i[g]
		var st := SurfaceTool.new()
		st.create_from_arrays(arrays)
		st.deindex()
		st.generate_normals()
		st.commit(mesh)
		var idx := mesh.get_surface_count() - 1
		mesh.surface_set_material(idx, lit_mat if g == 0 else (glow_mat if glow_mat else lit_mat))
	return mesh
