class_name World
extends Node3D
## العالم: البيئة، السماء، الخلفيات البعيدة، المقاطع المتدوّرة، والمطارد.

var env: Environment
var light: DirectionalLight3D
var sky: MeshInstance3D
var far_nodes: Array[MeshInstance3D] = []
var segs: Array[Segment] = []
var gen := Generator.new()
var next_spawn_dist := 0.0     # مسافة بداية المقطع التالي
var scroll := 0.0              # كم تحرّك العالم (م)
var biome_now := 0
var chaser: Node3D
var chaser_eyes: Array[MeshInstance3D] = []
var _decor_counter := 0
var _t := 0.0
var _sky_mat: ShaderMaterial
var _cur: Dictionary
var gate_nodes: Array[MeshInstance3D] = []
var _gate_mesh: ArrayMesh


func _ready() -> void:
	Mats.setup()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_curve = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	light = DirectionalLight3D.new()
	light.shadow_enabled = false
	add_child(light)

	# السماء: مجسّم يتبع الكاميرا
	sky = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 500.0
	sm.height = 1000.0
	sm.radial_segments = 20
	sm.rings = 10
	sky.mesh = sm
	_sky_mat = Mats.sky
	sky.material_override = _sky_mat
	sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sky.extra_cull_margin = 16384.0
	add_child(sky)

	for i in 3:
		var n := MeshInstance3D.new()
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.extra_cull_margin = 16384.0
		add_child(n)
		far_nodes.append(n)

	_gate_mesh = _build_gate()
	for i in Cfg.NUM_SEGS:
		var s := Segment.new()
		add_child(s)
		segs.append(s)
		var g := MeshInstance3D.new()
		g.mesh = _gate_mesh
		g.visible = false
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.add_child(g)
		gate_nodes.append(g)

	_build_chaser()
	apply_biome_immediate(0)


func _build_gate() -> ArrayMesh:
	var b := MeshBuilder.new()
	var st := Color(0.5, 0.42, 0.55)
	for sx in [-6.0, 6.0]:
		Meshes.box(b, Vector3(sx, 4.5, 0), Vector3(2.0, 9.0, 2.0), st)
		Meshes.box(b, Vector3(sx, 9.3, 0), Vector3(2.8, 0.6, 2.8), st.lightened(0.15))
	Meshes.box(b, Vector3(0, 9.0, 0), Vector3(14.4, 1.6, 2.2), st)
	Meshes.box(b, Vector3(0, 8.9, 1.12), Vector3(12.0, 0.25, 0.05), Color(1.0, 0.85, 0.4), Vector3.ZERO, true, 0.0)
	for i in 4:
		Meshes.box(b, Vector3(0, 10.6, 0), Vector3(0.28, 3.0, 0.28), Color(1.0, 0.8, 0.4), Vector3(0, 0, i * 45.0), true, 0.0)
	Meshes.cyl(b, Vector3(0, 10.6, 0), 0.5, 0.5, 0.3, Color(0.3, 0.6, 1.0), 8, Vector3(90, 0, 0), true, 0.0)
	return b.build(Mats.world, Mats.glow)


func _build_chaser() -> void:
	# ثور السماء (من ملحمة جلجامش): ثور ناري ضخم يطارد البطل
	chaser = Node3D.new()
	var b := MeshBuilder.new()
	var hide := Color(0.2, 0.08, 0.1)
	var flame := Color(1.0, 0.45, 0.12)
	Meshes.box(b, Vector3(0, 2.2, 0), Vector3(2.6, 2.5, 4.6), hide)
	Meshes.box(b, Vector3(0, 3.4, -1.0), Vector3(2.4, 1.3, 1.9), hide.lightened(0.05))
	Meshes.box(b, Vector3(0, 2.8, -2.7), Vector3(1.5, 1.5, 1.6), hide.lightened(0.08))
	for sx in [-1.0, 1.0]:
		Meshes.box(b, Vector3(sx * 1.3, 3.8, -3.1), Vector3(1.6, 0.3, 0.3), Color(0.95, 0.9, 0.78), Vector3(0, 0, sx * 35.0), false, 0.0)
		Meshes.box(b, Vector3(sx * 2.2, 4.5, -3.1), Vector3(0.3, 1.4, 0.3), Color(0.95, 0.9, 0.78), Vector3(0, 0, -sx * 10.0), false, 0.0)
		Meshes.box(b, Vector3(sx * 0.45, 3.2, -3.55), Vector3(0.4, 0.14, 0.05), flame, Vector3.ZERO, true, 0.0)
		for sz in [-1.5, 1.5]:
			Meshes.box(b, Vector3(sx * 0.9, 0.7, sz), Vector3(0.6, 1.5, 0.6), hide.darkened(0.2))
	# لهب ناري على السنام والذيل
	for i in 7:
		var fx := -0.9 + i * 0.3
		Meshes.cyl(b, Vector3(fx, 4.4 + (i % 3) * 0.3, -1.0 + (i % 2) * 0.5), 0.2, 0.0, 1.2 + (i % 3) * 0.4, flame, 4, Vector3.ZERO, true, 0.0)
	Meshes.cyl(b, Vector3(0, 3.0, 2.8), 0.25, 0.0, 2.0, flame, 4, Vector3(-40, 0, 0), true, 0.0)
	var mi := MeshInstance3D.new()
	mi.mesh = b.build(Mats.world, Mats.glow)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chaser.add_child(mi)
	chaser.visible = false
	add_child(chaser)


# ───────────────────────── البيئة ─────────────────────────
func apply_biome_immediate(i: int) -> void:
	biome_now = i
	_cur = Palette.biome(i)
	_apply_env(_cur, _cur, 0.0, 0.0)


func update_environment(distance: float, mirage_t: float) -> void:
	var bi := int(distance / Palette.BIOME_LEN)
	var into := distance - bi * Palette.BIOME_LEN
	var a := Palette.biome(bi)
	var b := Palette.biome(bi + 1)
	var blend_len := 260.0
	var t := 0.0
	if into > Palette.BIOME_LEN - blend_len:
		t = smoothstep(0.0, 1.0, (into - (Palette.BIOME_LEN - blend_len)) / blend_len)
	biome_now = (bi + (1 if t > 0.5 else 0)) % Palette.BIOME_COUNT
	_apply_env(a, b, t, mirage_t)


func _apply_env(a: Dictionary, b: Dictionary, t: float, m: float) -> void:
	var fog := Palette.lerp_biome_color(a, b, "fog", t)
	var top := Palette.lerp_biome_color(a, b, "sky_top", t)
	var hor := Palette.lerp_biome_color(a, b, "sky_horizon", t)
	var amb := Palette.lerp_biome_color(a, b, "ambient", t)
	var lc := Palette.lerp_biome_color(a, b, "light", t)
	var sun := Palette.lerp_biome_color(a, b, "sun", t)
	fog = fog.lerp(Palette.to_mirage(fog), m)
	top = top.lerp(Palette.to_mirage(top, 1.0).darkened(0.1), m)
	hor = hor.lerp(Palette.to_mirage(hor, 1.0), m)
	amb = amb.lerp(Palette.to_mirage(amb), m * 0.8)
	lc = lc.lerp(Palette.to_mirage(lc), m * 0.7)
	env.fog_light_color = fog
	env.fog_depth_begin = lerpf(a["fog_begin"], b["fog_begin"], t) * lerpf(1.0, 0.8, m)
	env.fog_depth_end = lerpf(a["fog_end"], b["fog_end"], t) * lerpf(1.0, 0.85, m)
	env.ambient_light_color = amb
	env.ambient_light_energy = lerpf(a["ambient_energy"], b["ambient_energy"], t)
	env.background_color = hor
	light.light_color = lc
	light.light_energy = lerpf(a["light_energy"], b["light_energy"], t)
	light.rotation_degrees = (a["light_rot"] as Vector3).lerp(b["light_rot"], t)
	_sky_mat.set_shader_parameter("top_color", top)
	_sky_mat.set_shader_parameter("horizon_color", hor)
	_sky_mat.set_shader_parameter("sun_color", sun.lerp(Color(0.6, 1.0, 1.0), m))
	_sky_mat.set_shader_parameter("sun_dir", (a["sun_dir"] as Vector3).lerp(b["sun_dir"], t))
	var night_a := 1.0 if a["night"] else 0.0
	var night_b := 1.0 if b["night"] else 0.0
	_sky_mat.set_shader_parameter("star_amount", lerpf(night_a, night_b, t) * 0.9)
	_sky_mat.set_shader_parameter("shift", m)
	for i in 3:
		var key := "far%d" % (i + 1)
		var c := Palette.lerp_biome_color(a, b, key, t)
		c = c.lerp(Palette.to_mirage(c), m)
		Mats.far_layers[i].albedo_color = c.lerp(fog, 0.12 * (2 - i))


func _set_far(i: int) -> void:
	for l in 3:
		far_nodes[l].mesh = Meshes.far_layer(i, l)


# ───────────────────────── المقاطع ─────────────────────────
func reset(seed_val: int, adaptive: bool) -> void:
	gen.reset(seed_val)
	gen.adaptive = adaptive
	scroll = 0.0
	next_spawn_dist = 0.0
	_decor_counter = 0
	var biome := 0
	for i in segs.size():
		var s := segs[i]
		s.position = Vector3(0, 0, -Cfg.SEG_LEN * i + Cfg.SEG_LEN)
		_fill(s)
	_set_far(0)
	_far_biome = 0
	apply_biome_immediate(0)
	chaser.visible = false


var _far_biome := -1


func _biome_of(dist: float) -> int:
	return int(dist / Palette.BIOME_LEN) % Palette.BIOME_COUNT


func _fill(s: Segment) -> void:
	var dist := next_spawn_dist
	var bi := _biome_of(dist)
	gen.fill_segment(s, dist, bi, _decor_counter)
	_decor_counter += 1
	var idx := segs.find(s)
	var first_of_biome := dist > 1.0 and int(dist / Palette.BIOME_LEN) != int((dist - Cfg.SEG_LEN) / Palette.BIOME_LEN)
	gate_nodes[idx].visible = first_of_biome
	next_spawn_dist += Cfg.SEG_LEN


## يحرّك العالم بمقدار dz نحو الكاميرا ويعيد تدوير المقاطع.
func advance(dz: float, dist: float) -> void:
	scroll += dz
	for s in segs:
		s.position.z += dz
	for s in segs:
		if s.position.z - Cfg.SEG_LEN > Cfg.RECYCLE_Z:
			# أبعد مقطع
			var far_z := INF
			for o in segs:
				far_z = minf(far_z, o.position.z)
			s.position.z = far_z - Cfg.SEG_LEN
			_fill(s)
	var bi := _biome_of(dist + 120.0)
	if bi != _far_biome:
		_far_biome = bi
		_set_far(bi)


func follow_camera(cam_pos: Vector3) -> void:
	sky.global_position = cam_pos
	for i in 3:
		var n := far_nodes[i]
		n.global_position = Vector3(cam_pos.x * (0.02 + i * 0.02), 0.0, cam_pos.z - 330.0 + i * 55.0)
		n.scale = Vector3(1.0 + (2 - i) * 0.05, 1.0 + i * 0.1, 1.0)
	_t += get_process_delta_time()
