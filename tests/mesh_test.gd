extends SceneTree
## اختبار بناء كل المجسّمات (يُشغّل بدون نافذة): godot --headless --script tests/mesh_test.gd

func _init() -> void:
	var t0 := Time.get_ticks_msec()
	Mats.setup()
	var n := 0
	var verts := 0
	for biome in 3:
		var g := Meshes.ground(biome)
		verts += _count(g)
		n += 1
		for v in 6:
			var d := Meshes.decor(biome, v)
			verts += _count(d)
			n += 1
		for l in 3:
			var f := Meshes.far_layer(biome, l)
			verts += _count(f)
			n += 1
	for kind in [Cfg.Kind.LOW, Cfg.Kind.HIGH, Cfg.Kind.FULL, Cfg.Kind.WALL]:
		for fam in [Cfg.Family.STONE, Cfg.Family.SUN, Cfg.Family.MIR]:
			for v in Meshes.obstacle_variants(kind):
				var m := Meshes.obstacle(kind, fam, v)
				verts += _count(m)
				n += 1
	Meshes.coin()
	Meshes.shard()
	for p in 5:
		Meshes.pickup(p)
	print("meshes built: ", n, "  total verts: ", verts, "  time ms: ", Time.get_ticks_msec() - t0)
	quit()


func _count(m: ArrayMesh) -> int:
	var c := 0
	for s in m.get_surface_count():
		c += (m.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return c
