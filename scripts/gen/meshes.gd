class_name Meshes
extends RefCounted
## مصنع المجسّمات: كل شيء يُبنى بالكود من بدائيات ويُدمج في شبكات صغيرة.

static var _cache: Dictionary = {}


# ───────────────────────── أدوات ─────────────────────────
static func _jit(c: Color, pos: Vector3, amt: float) -> Color:
	var h := sin(pos.x * 12.9898 + pos.y * 78.233 + pos.z * 37.719) * 43758.5453
	h = h - floor(h)
	var f := 1.0 + (h - 0.5) * 2.0 * amt
	return Color(c.r * f, c.g * f, c.b * f, c.a)


static func box(b: MeshBuilder, pos: Vector3, size: Vector3, col: Color, rot := Vector3.ZERO, glow := false, jit := 0.06) -> void:
	b.add(MeshBuilder.prim("box"), pos, size, _jit(col, pos, jit), rot, glow)


## أسطوانة/مخروط: نصف قطر القاعدة والقمة والارتفاع.
static func cyl(b: MeshBuilder, pos: Vector3, r_bot: float, r_top: float, h: float, col: Color, segs := 6, rot := Vector3.ZERO, glow := false, jit := 0.06) -> void:
	var ratio := 0.0
	if r_bot > 0.0001:
		ratio = clampf(r_top / r_bot, 0.0, 1.0)
	b.add(MeshBuilder.prim("cyl", segs, 1, ratio), pos, Vector3(r_bot * 2.0, h, r_bot * 2.0), _jit(col, pos, jit), rot, glow)


## كرة/إهليلج: الأقطار على المحاور الثلاثة.
static func sph(b: MeshBuilder, pos: Vector3, size: Vector3, col: Color, segs := 8, rings := 4, rot := Vector3.ZERO, glow := false, jit := 0.06) -> void:
	b.add(MeshBuilder.prim("sph", segs, rings), pos, size, _jit(col, pos, jit), rot, glow)


static func _mat_for(family: int) -> Array:
	match family:
		Cfg.Family.SUN:
			return [Mats.sun_body, Mats.sun_glow]
		Cfg.Family.MIR:
			return [Mats.mir_body, Mats.mir_glow]
		_:
			return [Mats.world, Mats.glow]


# ───────────────────────── الأرضية ─────────────────────────
static func ground(biome: int) -> ArrayMesh:
	var key := "ground%d" % biome
	if _cache.has(key):
		return _cache[key]
	var P := Palette.biome(biome)
	var b := MeshBuilder.new()
	var L := Cfg.SEG_LEN
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234 + biome

	box(b, Vector3(0, -0.5, -L * 0.5), Vector3(Cfg.ROAD_HALF * 2.0, 1.0, L + 0.06), (P["road_a"] as Color).darkened(0.12), Vector3.ZERO, false, 0.0)
	for lane in range(-1, 2):
		for k in 6:
			var col: Color = P["road_a"] if (k + lane + 1) % 2 == 0 else P["road_b"]
			box(b, Vector3(lane * Cfg.LANE_W, 0.0, -(k + 0.5) * 6.0), Vector3(Cfg.LANE_W - 0.12, 0.05, 5.88), col, Vector3.ZERO, false, 0.05)
	for sx in [-1.2, 1.2]:
		box(b, Vector3(sx, 0.03, -L * 0.5), Vector3(0.07, 0.04, L), P["line"], Vector3.ZERO, true, 0.0)
	for side in [-1.0, 1.0]:
		for k in 6:
			var ec: Color = P["edge"]
			if k % 2 == 1:
				ec = ec.lightened(0.12)
			box(b, Vector3(side * (Cfg.ROAD_HALF + 0.45), 0.12, -(k + 0.5) * 6.0), Vector3(0.9, 0.62, 5.88), ec, Vector3.ZERO, false, 0.05)
		var top_y := -0.1
		var col_side: Color = P["side"]
		if biome == 1:
			top_y = -0.55
		box(b, Vector3(side * (Cfg.ROAD_HALF + 0.9 + 32.0), top_y - 0.7, -L * 0.5), Vector3(64.0, 1.4, L + 0.06), col_side, Vector3.ZERO, false, 0.0)
		# حواف ملوّنة بالقرب من الطريق
		box(b, Vector3(side * (Cfg.ROAD_HALF + 2.6), top_y + 0.01, -L * 0.5), Vector3(3.0, 0.04, L + 0.06), P["side2"], Vector3.ZERO, false, 0.0)
		if biome == 1:
			for n in 14:
				var p := Vector3(side * rng.randf_range(8.0, 40.0), top_y + 0.03, -rng.randf_range(1.0, L - 1.0))
				box(b, p, Vector3(rng.randf_range(0.6, 1.8), 0.03, 0.18), Color(1.0, 1.0, 0.9), Vector3(0, rng.randf_range(-20, 20), 0), true, 0.0)
	var mesh := b.build(Mats.world, Mats.glow)
	_cache[key] = mesh
	return mesh


# ───────────────────────── الديكور الجانبي ─────────────────────────
static func decor(biome: int, variant: int) -> ArrayMesh:
	var key := "decor%d_%d" % [biome, variant]
	if _cache.has(key):
		return _cache[key]
	var P := Palette.biome(biome)
	var b := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 777 + biome * 1000 + variant * 31
	match biome:
		0:
			_decor_dunes(b, P, rng, variant)
		1:
			_decor_marsh(b, P, rng, variant)
		_:
			_decor_city(b, P, rng, variant)
	var mesh := b.build(Mats.world, Mats.glow)
	_cache[key] = mesh
	return mesh


static func _palm(b: MeshBuilder, P: Dictionary, pos: Vector3, rng: RandomNumberGenerator, scale: float) -> void:
	var h := rng.randf_range(4.8, 7.4) * scale
	var ang := deg_to_rad(rng.randf_range(-10.0, 10.0))
	var p := pos
	var n := 3
	for s in n:
		var seg_h := h / n
		var dir := Vector3(sin(ang), cos(ang), 0.0)
		var mid := p + dir * seg_h * 0.5
		var rb := 0.26 * scale * (1.0 - 0.17 * s)
		var rt := 0.26 * scale * (1.0 - 0.17 * (s + 1))
		cyl(b, mid, rb, rt, seg_h + 0.05, P["trunk"], 6, Vector3(0, 0, -rad_to_deg(ang)))
		p += dir * seg_h
		ang += 0.05
	var green: Color = P["green"]
	for i in 8:
		var yaw := i * 45.0 + rng.randf_range(-12, 12)
		var droop := rng.randf_range(18.0, 38.0)
		var len := 2.9 * scale
		var yr := deg_to_rad(yaw)
		var dr := deg_to_rad(droop)
		var out := Vector3(cos(yr), 0.0, sin(yr))
		var center := p + out * (len * 0.5 * cos(dr)) + Vector3(0, 0.15 - len * 0.5 * sin(dr), 0)
		box(b, center, Vector3(len, 0.07, 0.55 * scale), green.lightened(rng.randf_range(-0.05, 0.12)), Vector3(0, -yaw, -droop), false, 0.1)
	sph(b, p + Vector3(0.12, -0.15, 0.1), Vector3(0.28, 0.28, 0.28), Color(0.4, 0.26, 0.14), 6, 3)
	sph(b, p + Vector3(-0.1, -0.2, -0.1), Vector3(0.26, 0.26, 0.26), Color(0.4, 0.26, 0.14), 6, 3)


static func _column(b: MeshBuilder, P: Dictionary, pos: Vector3, h: float, broken: bool, rng: RandomNumberGenerator) -> void:
	# مسلّة سومرية: لوح حجري عليه أسطر مسمارية متوهجة
	var st: Color = P["stone"]
	var st2: Color = P["stone2"]
	var wedge := Color(1.0, 0.82, 0.4)
	box(b, pos + Vector3(0, 0.25, 0), Vector3(1.0, 0.5, 1.8), st2)
	if broken:
		box(b, pos + Vector3(0, 0.5 + h * 0.3, 0), Vector3(0.45, h * 0.6, 1.1), st)
		box(b, pos + Vector3(rng.randf_range(1.0, 2.0), 0.45, rng.randf_range(-1.0, 1.0)), Vector3(h * 0.4, 0.4, 1.1), st, Vector3(0, rng.randf_range(0, 60), 0))
	else:
		box(b, pos + Vector3(0, 0.5 + h * 0.5, 0), Vector3(0.45, h, 1.1), st)
		cyl(b, pos + Vector3(0, 0.5 + h + 0.28, 0), 0.62, 0.0, 0.56, st2, 4, Vector3(0, 0, 0))
		for i in 6:
			var yy := 0.9 + i * (h - 0.8) / 6.0
			for sx in [-0.235, 0.235]:
				box(b, pos + Vector3(sx, yy, 0), Vector3(0.04, 0.07, 0.8 - (i % 2) * 0.25), wedge, Vector3.ZERO, true, 0.0)


static func _ziggurat(b: MeshBuilder, P: Dictionary, pos: Vector3, s: float, glow_col: Color) -> void:
	# زقورة أور-نمو: ثلاث طبقات من الطوب اللبن، سلالم أمامية، معبد نانا في القمة
	var st: Color = P["stone"]
	var st2: Color = P["stone2"]
	var tiers := [[28.0, 5.0], [20.0, 5.0], [13.0, 4.5]]
	var y := 0.0
	for i in tiers.size():
		var w: float = tiers[i][0] * s
		var hh: float = tiers[i][1] * s
		box(b, pos + Vector3(0, y + hh * 0.5, 0), Vector3(w, hh, w * 1.25), st if i % 2 == 0 else st2)
		# تجاويف الجدران (ميزة الزقورة)
		for k in 5:
			var nx := -w * 0.5 + (k + 0.5) * (w / 5.0)
			box(b, pos + Vector3(nx, y + hh * 0.55, w * 0.625 + 0.03), Vector3(0.5 * s, hh * 0.7, 0.06), st2.darkened(0.25), Vector3.ZERO, false, 0.0)
		y += hh
	box(b, pos + Vector3(0, y + 1.3 * s, 0), Vector3(5.0 * s, 2.6 * s, 5.0 * s), Color(0.12, 0.3, 0.7))
	box(b, pos + Vector3(0, y + 2.75 * s, 0), Vector3(5.4 * s, 0.3 * s, 5.4 * s), Color(0.95, 0.78, 0.3))
	box(b, pos + Vector3(0, y + 1.0 * s, 2.55 * s), Vector3(1.4 * s, 1.8 * s, 0.1), glow_col, Vector3.ZERO, true, 0.0)
	# ثلاثة سلالم
	for sx in [-1.0, 0.0, 1.0]:
		box(b, pos + Vector3(sx * 5.0 * s, 7.4 * s, 17.0 * s), Vector3(2.6 * s, 0.7, 20.0 * s), st2, Vector3(-32, 0, 0))


static func _shrine(b: MeshBuilder, P: Dictionary, pos: Vector3, s: float) -> void:
	# معبد طيني قديم على منصّة: جدران بدعامات بارزة ومدخل مضيء
	var st: Color = P["stone"]
	var st2: Color = P["stone2"]
	box(b, pos + Vector3(0, 0.8 * s, 0), Vector3(12.0 * s, 1.6 * s, 16.0 * s), st2)
	box(b, pos + Vector3(0, 3.0 * s, 0), Vector3(9.0 * s, 2.8 * s, 12.0 * s), st)
	for k in 6:
		var zz := -5.0 * s + k * 2.0 * s
		for sx in [-4.6, 4.6]:
			box(b, pos + Vector3(sx * s, 3.0 * s, zz), Vector3(0.6 * s, 2.8 * s, 0.9 * s), st2)
	box(b, pos + Vector3(0, 4.7 * s, 0), Vector3(9.6 * s, 0.5 * s, 12.6 * s), st2)
	box(b, pos + Vector3(0, 2.6 * s, 6.05 * s), Vector3(1.6 * s, 2.0 * s, 0.1), Color(1.0, 0.72, 0.3), Vector3.ZERO, true, 0.0)


static func _decor_dunes(b: MeshBuilder, P: Dictionary, rng: RandomNumberGenerator, variant: int) -> void:
	var L := Cfg.SEG_LEN
	for side in [-1.0, 1.0]:
		for n in 3:
			var r := rng.randf_range(5.0, 11.0)
			var x: float = side * rng.randf_range(14.0, 42.0)
			var z := -rng.randf_range(8.0, L - 8.0)
			var c: Color = P["dune"] if rng.randf() > 0.4 else P["dune2"]
			sph(b, Vector3(x, -r * 0.06, z), Vector3(r * 2.0, r * 0.7, r * 2.6), c, 10, 4, Vector3(0, rng.randf_range(0, 60), 0), false, 0.04)
		var palms := 1 + (variant + (1 if side > 0 else 0)) % 2
		for n in palms:
			_palm(b, P, Vector3(side * rng.randf_range(7.6, 14.0), -0.1, -rng.randf_range(4.0, L - 4.0)), rng, rng.randf_range(0.85, 1.2))
		match (variant + (0 if side < 0 else 2)) % 4:
			0:
				var x0: float = side * 9.0
				for k in 3:
					_column(b, P, Vector3(x0 + side * k * 0.4, -0.1, -8.0 - k * 6.0), 3.6 + rng.randf() * 1.6, k == 1, rng)
			1:
				_ziggurat(b, P, Vector3(side * 38.0, -0.1, -L * 0.5), 0.8, Color(1.0, 0.8, 0.4))
			2:
				_shrine(b, P, Vector3(side * 20.0, -0.1, -L * 0.5), 0.9)
			_:
				# سور من الطوب اللبن + برج مراقبة
				var x2: float = side * 12.0
				box(b, Vector3(x2, 1.2, -14.0), Vector3(1.4, 2.8, 13.0), P["stone"])
				for k in 6:
					box(b, Vector3(x2, 2.85, -8.5 - k * 2.1), Vector3(1.4, 0.5, 1.0), P["stone"])
				box(b, Vector3(x2 + side * 1.0, 3.6, -22.0), Vector3(3.2, 7.2, 3.2), P["stone2"])
				box(b, Vector3(x2 + side * 1.0, 7.6, -22.0), Vector3(3.8, 0.6, 3.8), P["stone"])
				box(b, Vector3(x2 - side * 0.72, 4.6, -22.0), Vector3(0.1, 1.2, 0.8), Color(1.0, 0.7, 0.3), Vector3.ZERO, true, 0.0)
	# مواقد/مباخر قرب الطريق
	for k in Cfg.ROWS_PER_SEG:
		for side in [-1.0, 1.0]:
			if (k + variant + (1 if side > 0 else 0)) % 2 == 0:
				var x: float = side * (Cfg.ROAD_HALF + 1.5)
				var z := -(k * Cfg.ROW_STEP + 4.5)
				cyl(b, Vector3(x, 0.7, z), 0.35, 0.28, 1.4, P["stone2"], 6)
				cyl(b, Vector3(x, 1.55, z), 0.55, 0.38, 0.3, P["stone"], 8)
				sph(b, Vector3(x, 2.0, z), Vector3(0.55, 0.8, 0.55), Color(1.0, 0.62, 0.2), 6, 3, Vector3.ZERO, true, 0.0)


static func _reeds(b: MeshBuilder, P: Dictionary, pos: Vector3, rng: RandomNumberGenerator, n: int) -> void:
	for i in n:
		var h := rng.randf_range(2.0, 4.2)
		var o := Vector3(rng.randf_range(-1.4, 1.4), 0, rng.randf_range(-1.4, 1.4))
		var col: Color = (P["green"] as Color).lerp(Color(0.75, 0.7, 0.35), rng.randf() * 0.55)
		cyl(b, pos + o + Vector3(0, h * 0.5, 0), 0.08, 0.0, h, col, 4, Vector3(rng.randf_range(-14, 14), 0, rng.randf_range(-14, 14)))


static func _mudhif(b: MeshBuilder, P: Dictionary, pos: Vector3, rng: RandomNumberGenerator, facing: float) -> void:
	var reed := Color(0.82, 0.7, 0.45)
	sph(b, pos + Vector3(0, 0.2, 0), Vector3(5.0, 4.6, 11.0), reed, 10, 4, Vector3.ZERO, false, 0.05)
	for k in 7:
		var z := -4.6 + k * 1.55
		box(b, pos + Vector3(0, 1.6, z), Vector3(5.1, 0.12, 0.2), Color(0.55, 0.42, 0.24), Vector3.ZERO, false, 0.1)
	box(b, pos + Vector3(0, 1.1, 5.5 * facing), Vector3(2.2, 2.6, 0.2), Color(0.22, 0.14, 0.1))
	box(b, pos + Vector3(0, 1.3, 5.55 * facing), Vector3(1.4, 1.6, 0.05), Color(1.0, 0.72, 0.3), Vector3.ZERO, true, 0.0)


static func _boat(b: MeshBuilder, P: Dictionary, pos: Vector3, rng: RandomNumberGenerator) -> void:
	var wood := Color(0.34, 0.22, 0.14)
	box(b, pos + Vector3(0, 0.15, 0), Vector3(1.3, 0.5, 4.8), wood)
	box(b, pos + Vector3(0, 0.55, -2.5), Vector3(1.0, 0.4, 1.2), wood, Vector3(32, 0, 0))
	box(b, pos + Vector3(0, 0.55, 2.5), Vector3(1.0, 0.4, 1.2), wood, Vector3(-32, 0, 0))
	box(b, pos + Vector3(0, 1.2, 0.5), Vector3(0.1, 1.6, 0.1), wood)
	sph(b, pos + Vector3(0, 2.1, 0.5), Vector3(0.4, 0.5, 0.4), Color(1.0, 0.75, 0.35), 6, 3, Vector3.ZERO, true, 0.0)


static func _decor_marsh(b: MeshBuilder, P: Dictionary, rng: RandomNumberGenerator, variant: int) -> void:
	var L := Cfg.SEG_LEN
	for side in [-1.0, 1.0]:
		# جزر عشب
		for n in 2:
			var r := rng.randf_range(3.0, 7.0)
			sph(b, Vector3(side * rng.randf_range(9.0, 26.0), -0.55, -rng.randf_range(4.0, L - 4.0)), Vector3(r * 2.0, r * 0.5, r * 2.2), P["dune"], 8, 3, Vector3.ZERO, false, 0.06)
		# قصب
		for n in 2:
			_reeds(b, P, Vector3(side * rng.randf_range(6.8, 18.0), -0.3, -rng.randf_range(3.0, L - 3.0)), rng, 10)
		# نخيل
		if (variant + (1 if side > 0 else 0)) % 2 == 0:
			_palm(b, P, Vector3(side * rng.randf_range(8.0, 15.0), -0.3, -rng.randf_range(5.0, L - 5.0)), rng, 1.0)
		# مضيف/قارب
		match (variant + (0 if side < 0 else 1)) % 3:
			0:
				_mudhif(b, P, Vector3(side * 17.0, -0.3, -L * 0.5), rng, 1.0 if side < 0 else 1.0)
			1:
				_boat(b, P, Vector3(side * rng.randf_range(10.0, 14.0), -0.5, -rng.randf_range(8.0, L - 8.0)), rng)
			_:
				for k in 2:
					_boat(b, P, Vector3(side * (11.0 + k * 3.5), -0.5, -8.0 - k * 14.0), rng)
	# فوانيس القصب قرب الطريق
	for k in Cfg.ROWS_PER_SEG:
		for side in [-1.0, 1.0]:
			if (k + variant + (1 if side > 0 else 0)) % 2 == 0:
				var x: float = side * (Cfg.ROAD_HALF + 1.4)
				var z := -(k * Cfg.ROW_STEP + 4.5)
				cyl(b, Vector3(x, 1.4, z), 0.07, 0.07, 2.8, Color(0.5, 0.38, 0.2), 4)
				sph(b, Vector3(x, 2.95, z), Vector3(0.55, 0.7, 0.55), Color(0.4, 1.0, 0.8), 6, 3, Vector3.ZERO, true, 0.0)
				for q in 3:
					cyl(b, Vector3(x + rng.randf_range(-0.5, 0.5), 1.0, z + rng.randf_range(-0.5, 0.5)), 0.06, 0.0, 2.0, P["green"], 4, Vector3(rng.randf_range(-15, 15), 0, rng.randf_range(-15, 15)))


static func _building(b: MeshBuilder, P: Dictionary, pos: Vector3, w: float, h: float, d: float, side: float, rng: RandomNumberGenerator) -> void:
	# بيت/مبنى من الطوب اللبن: سطح مستوٍ، طابق علوي متراجع، فتحات مضيئة
	var st: Color = (P["stone"] as Color).lerp(P["stone2"], rng.randf())
	box(b, pos + Vector3(0, h * 0.5, 0), Vector3(w, h, d), st)
	box(b, pos + Vector3(0, h + 0.2, 0), Vector3(w + 0.5, 0.4, d + 0.5), P["stone2"])
	if h > 8.0:
		box(b, pos + Vector3(0, h + 1.4, 0), Vector3(w * 0.62, 2.0, d * 0.62), st.lightened(0.05))
		box(b, pos + Vector3(0, h + 2.6, 0), Vector3(w * 0.7, 0.4, d * 0.7), P["stone2"])
	var face_x := -side * (w * 0.5 + 0.03)
	var rows := int(h / 2.6)
	var cols := int(d / 2.4)
	for r in range(1, rows):
		for c in cols:
			if rng.randf() < 0.5:
				var wc := Color(1.0, 0.72, 0.35)
				box(b, pos + Vector3(face_x, r * 2.6, (c - (cols - 1) * 0.5) * 2.4), Vector3(0.08, 0.9, 0.5), wc, Vector3.ZERO, true, 0.0)
	box(b, pos + Vector3(face_x, 1.1, 0), Vector3(0.1, 2.0, 1.1), Color(1.0, 0.7, 0.3), Vector3.ZERO, true, 0.0)


static func _dome(b: MeshBuilder, pos: Vector3, r: float, col: Color) -> void:
	# مظلّة قصب/خيمة سطح بدل القباب (لا قباب في سومر)
	box(b, pos + Vector3(0, 0.5, 0), Vector3(r * 1.6, 1.0, r * 1.6), col)


static func _minaret(b: MeshBuilder, P: Dictionary, pos: Vector3, h: float) -> void:
	_ziggurat(b, P, pos, 0.55, Color(0.4, 0.7, 1.0))


static func _decor_city(b: MeshBuilder, P: Dictionary, rng: RandomNumberGenerator, variant: int) -> void:
	var L := Cfg.SEG_LEN
	for side in [-1.0, 1.0]:
		var z := -4.0
		var n := 0
		while z > -L + 3.0 and n < 4:
			var w := rng.randf_range(5.0, 9.0)
			var d := rng.randf_range(6.0, 10.0)
			var h := rng.randf_range(5.0, 17.0)
			var x: float = side * (Cfg.ROAD_HALF + 4.5 + w * 0.5 + rng.randf_range(0.0, 5.0))
			_building(b, P, Vector3(x, -0.1, z - d * 0.5), w, h, d, side, rng)
			if rng.randf() < 0.4:
				_dome(b, Vector3(x, h + 0.5, z - d * 0.5), minf(w, d) * 0.4, Color(0.55, 0.42, 0.28))
			z -= d + rng.randf_range(0.5, 3.0)
			n += 1
		if (variant + (0 if side < 0 else 1)) % 3 == 0:
			_ziggurat(b, P, Vector3(side * rng.randf_range(34.0, 46.0), -0.1, -rng.randf_range(10.0, L - 10.0)), 0.7, Color(0.4, 0.7, 1.0))
		_building(b, P, Vector3(side * rng.randf_range(34.0, 48.0), -0.1, -rng.randf_range(6.0, L - 6.0)), 9.0, rng.randf_range(12.0, 24.0), 9.0, side, rng)
	# مباخر من الفخار على أعمدة قرب الطريق
	for k in Cfg.ROWS_PER_SEG:
		for side in [-1.0, 1.0]:
			var x: float = side * (Cfg.ROAD_HALF + 1.3)
			var zz := -(k * Cfg.ROW_STEP + 4.5)
			cyl(b, Vector3(x, 0.9, zz), 0.28, 0.2, 1.8, Color(0.5, 0.36, 0.26), 8)
			cyl(b, Vector3(x, 1.95, zz), 0.55, 0.32, 0.34, Color(0.58, 0.42, 0.3), 8)
			sph(b, Vector3(x, 2.5, zz), Vector3(0.6, 0.95, 0.6), Color(1.0, 0.6, 0.25), 8, 4, Vector3.ZERO, true, 0.0)
			if (k + variant) % 2 == 0:
				box(b, Vector3(x + side * 0.1, 1.2, zz + 2.0), Vector3(1.2, 0.1, 1.6), Color(0.3, 0.45, 0.8).lerp(Color(0.85, 0.7, 0.3), (k % 3) * 0.5), Vector3(0, 0, -side * 15.0))


# ───────────────────────── الخلفية البعيدة (ظلال) ─────────────────────────
static func far_layer(biome: int, layer: int) -> ArrayMesh:
	var key := "far%d_%d" % [biome, layer]
	if _cache.has(key):
		return _cache[key]
	var b := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 99 + biome * 50 + layer * 7
	var col := Color.WHITE
	var x := -520.0
	match biome:
		0:
			# كثبان متتالية + زقورة + نخيل بعيد
			while x < 520.0:
				var r := rng.randf_range(40.0, 110.0) * (1.0 - layer * 0.18)
				sph(b, Vector3(x, 0, 0), Vector3(r * 2.0, r * (0.28 + layer * 0.05), 14.0), col, 10, 4, Vector3.ZERO, false, 0.0)
				x += r * rng.randf_range(0.9, 1.5)
			if layer == 1:
				var tiers := [[70.0, 12.0], [52.0, 12.0], [36.0, 11.0], [22.0, 9.0]]
				var y := 0.0
				for t in tiers:
					box(b, Vector3(-120.0, y + t[1] * 0.5, 0), Vector3(t[0], t[1], 20.0), col, Vector3.ZERO, false, 0.0)
					y += t[1]
			if layer == 0:
				for i in 14:
					var px := rng.randf_range(-450.0, 450.0)
					cyl(b, Vector3(px, 14.0, 0), 1.2, 0.8, 30.0, col, 5)
					sph(b, Vector3(px, 30.0, 0), Vector3(20.0, 6.0, 20.0), col, 6, 3)
		1:
			while x < 520.0:
				var r := rng.randf_range(30.0, 90.0)
				sph(b, Vector3(x, 0, 0), Vector3(r * 2.0, r * (0.22 + layer * 0.04), 14.0), col, 10, 4, Vector3.ZERO, false, 0.0)
				x += r * rng.randf_range(0.8, 1.4)
			for i in 24:
				var px := rng.randf_range(-480.0, 480.0)
				var hh := rng.randf_range(10.0, 26.0)
				cyl(b, Vector3(px, hh * 0.5, 0), 0.9, 0.5, hh, col, 5)
				for f in 5:
					box(b, Vector3(px + (f - 2) * 3.2, hh + 1.0 - absf(f - 2) * 1.0, 0), Vector3(7.0, 0.8, 1.0), col, Vector3(0, 0, (f - 2) * -14.0), false, 0.0)
		_:
			while x < 520.0:
				var w := rng.randf_range(14.0, 40.0)
				var h := rng.randf_range(10.0, 34.0) * (1.0 + layer * 0.2)
				box(b, Vector3(x, h * 0.5, 0), Vector3(w, h, 14.0), col, Vector3.ZERO, false, 0.0)
				box(b, Vector3(x, h + 3.0, 0), Vector3(w * 0.6, 6.0, 12.0), col, Vector3.ZERO, false, 0.0)
				if rng.randf() < 0.22:
					var zw := 46.0
					var yy := 0.0
					for tier in 3:
						var tw := zw * (1.0 - tier * 0.28)
						box(b, Vector3(x + w, yy + 6.0, 0), Vector3(tw, 12.0, 16.0), col, Vector3.ZERO, false, 0.0)
						yy += 12.0
				x += w + rng.randf_range(-4.0, 6.0)
	var mesh := b.build(Mats.far_layers[layer])
	_cache[key] = mesh
	return mesh


# ───────────────────────── العوائق ─────────────────────────
static func _fam_colors(family: int) -> Dictionary:
	match family:
		Cfg.Family.SUN:
			return {"body": Color(0.86, 0.45, 0.22), "body2": Color(0.7, 0.3, 0.16), "trim": Color(0.55, 0.22, 0.12), "glow": Color(1.0, 0.82, 0.3)}
		Cfg.Family.MIR:
			return {"body": Color(0.5, 0.38, 1.0), "body2": Color(0.34, 0.22, 0.8), "trim": Color(0.2, 0.12, 0.5), "glow": Color(0.35, 0.95, 1.0)}
		_:
			return {"body": Color(0.66, 0.6, 0.5), "body2": Color(0.5, 0.45, 0.38), "trim": Color(0.36, 0.32, 0.27), "glow": Color(0.8, 0.8, 0.7)}


static func obstacle(kind: int, family: int, variant: int) -> ArrayMesh:
	var key := "obs_%d_%d_%d" % [kind, family, variant]
	if _cache.has(key):
		return _cache[key]
	var b := MeshBuilder.new()
	var C := _fam_colors(family)
	var body: Color = C["body"]
	var body2: Color = C["body2"]
	var trim: Color = C["trim"]
	var gl: Color = C["glow"]
	var zf := 0.0
	match kind:
		Cfg.Kind.LOW:
			zf = 0.5
			match variant:
				0:
					box(b, Vector3(0, 0.3, 0), Vector3(1.95, 0.6, 1.0), body)
					box(b, Vector3(0, 0.75, 0), Vector3(1.5, 0.35, 0.8), body2)
					if family == Cfg.Family.MIR:
						for i in 4:
							cyl(b, Vector3(-0.6 + i * 0.4, 1.05, 0), 0.16, 0.0, 0.55 + (i % 2) * 0.2, gl, 5, Vector3(0, 0, (i - 1.5) * 8), true, 0.0)
					elif family == Cfg.Family.SUN:
						box(b, Vector3(0, 0.45, zf + 0.02), Vector3(1.3, 0.1, 0.04), gl, Vector3.ZERO, true, 0.0)
				1:
					# جرار
					for i in 3:
						var x := -0.62 + i * 0.62
						var hh := 0.75 + (i % 2) * 0.12
						if family == Cfg.Family.MIR:
							cyl(b, Vector3(x, hh * 0.5, 0), 0.34, 0.0, hh + 0.2, body, 5)
							cyl(b, Vector3(x, hh * 0.5, 0), 0.18, 0.0, hh + 0.35, gl, 5, Vector3.ZERO, true, 0.0)
						else:
							sph(b, Vector3(x, 0.38, 0), Vector3(0.7, 0.76, 0.7), body, 8, 4)
							cyl(b, Vector3(x, 0.84, 0), 0.2, 0.26, 0.2, body2, 8)
							if family == Cfg.Family.SUN:
								cyl(b, Vector3(x, 0.4, 0), 0.355, 0.355, 0.07, gl, 8, Vector3.ZERO, true, 0.0)
				_:
					box(b, Vector3(0, 0.35, 0), Vector3(1.95, 0.7, 0.7), body)
					for i in 3:
						box(b, Vector3(-0.65 + i * 0.65, 0.82, 0), Vector3(0.5, 0.26, 0.7), body2)
					if family == Cfg.Family.SUN:
						box(b, Vector3(0, 0.4, 0.37), Vector3(0.28, 0.4, 0.04), gl, Vector3.ZERO, true, 0.0)
					elif family == Cfg.Family.MIR:
						box(b, Vector3(0, 0.12, 0), Vector3(2.0, 0.08, 0.9), gl, Vector3.ZERO, true, 0.0)
		Cfg.Kind.HIGH:
			zf = 0.4
			for sx in [-0.98, 0.98]:
				box(b, Vector3(sx, 1.3, 0), Vector3(0.4, 2.6, 0.7), body2)
				box(b, Vector3(sx, 0.12, 0), Vector3(0.6, 0.24, 0.9), trim)
			if family == Cfg.Family.MIR:
				cyl(b, Vector3(0, 1.85, 0), 0.5, 0.5, 2.1, body, 6, Vector3(0, 0, 90))
				cyl(b, Vector3(0, 1.85, 0), 0.26, 0.26, 2.3, gl, 6, Vector3(0, 0, 90), true, 0.0)
			else:
				box(b, Vector3(0, 1.85, 0), Vector3(2.35, 0.9, 0.9), body)
				box(b, Vector3(0, 2.4, 0), Vector3(2.55, 0.22, 1.0), trim)
				if family == Cfg.Family.SUN:
					box(b, Vector3(0, 1.62, 0.46), Vector3(1.8, 0.1, 0.04), gl, Vector3.ZERO, true, 0.0)
				else:
					box(b, Vector3(0, 1.62, 0.46), Vector3(0.9, 0.06, 0.04), gl, Vector3.ZERO, true, 0.0)
		Cfg.Kind.FULL:
			zf = 0.9
			match variant:
				0:
					box(b, Vector3(0, 1.3, 0), Vector3(1.9, 2.6, 1.6), body)
					for i in 3:
						box(b, Vector3(0, 0.55 + i * 0.85, 0.83), Vector3(1.9, 0.12, 0.08), trim)
					if family == Cfg.Family.SUN:
						cyl(b, Vector3(0, 1.5, 0.83), 0.45, 0.45, 0.05, gl, 10, Vector3(90, 0, 0), true, 0.0)
					elif family == Cfg.Family.MIR:
						for i in 3:
							cyl(b, Vector3(-0.55 + i * 0.55, 2.7, 0), 0.22, 0.0, 0.8, gl, 5, Vector3.ZERO, true, 0.0)
				1:
					for i in 3:
						var x := -0.62 + i * 0.62
						var hh := 2.3 + (i % 2) * 0.35
						if family == Cfg.Family.MIR:
							cyl(b, Vector3(x, hh * 0.5, (i - 1) * 0.2), 0.42, 0.0, hh, body, 5)
							cyl(b, Vector3(x, hh * 0.5, (i - 1) * 0.2), 0.2, 0.0, hh + 0.1, gl, 5, Vector3.ZERO, true, 0.0)
						else:
							cyl(b, Vector3(x, hh * 0.5, (i - 1) * 0.2), 0.4, 0.34, hh, body, 8)
							box(b, Vector3(x, hh + 0.12, (i - 1) * 0.2), Vector3(0.9, 0.26, 0.9), body2)
							if family == Cfg.Family.SUN:
								cyl(b, Vector3(x, hh * 0.55, (i - 1) * 0.2), 0.43, 0.43, 0.08, gl, 8, Vector3.ZERO, true, 0.0)
					box(b, Vector3(0, 0.15, 0), Vector3(2.0, 0.3, 1.5), trim)
				_:
					# عربة تاجر بمظلة
					box(b, Vector3(0, 0.8, 0), Vector3(1.8, 0.8, 1.5), body2)
					box(b, Vector3(0, 2.45, 0), Vector3(2.0, 0.22, 1.7), body)
					for sx in [-0.85, 0.85]:
						for sz in [-0.65, 0.65]:
							box(b, Vector3(sx, 1.6, sz), Vector3(0.1, 1.7, 0.1), trim)
					for sx in [-1.0, 1.0]:
						cyl(b, Vector3(sx, 0.45, 0.0), 0.45, 0.45, 0.16, trim, 8, Vector3(0, 0, 90))
					box(b, Vector3(0, 1.4, 0), Vector3(1.6, 0.6, 1.3), body)
					if family == Cfg.Family.SUN:
						box(b, Vector3(0, 2.2, 0.86), Vector3(1.7, 0.1, 0.04), gl, Vector3.ZERO, true, 0.0)
					elif family == Cfg.Family.MIR:
						sph(b, Vector3(0, 1.8, 0), Vector3(0.9, 0.9, 0.9), gl, 6, 3, Vector3.ZERO, true, 0.0)
		Cfg.Kind.MOVER:
			# ثور سومري يعبر الطريق
			var hide := Color(0.46, 0.3, 0.2)
			var dark := Color(0.3, 0.19, 0.12)
			box(b, Vector3(0, 0.95, 0), Vector3(0.8, 0.95, 1.7), hide)
			box(b, Vector3(0, 1.3, -0.45), Vector3(0.8, 0.55, 0.7), hide.lightened(0.05))
			box(b, Vector3(0, 1.1, -1.05), Vector3(0.5, 0.5, 0.6), hide.lightened(0.08))
			box(b, Vector3(0, 0.95, -1.35), Vector3(0.4, 0.3, 0.25), Color(0.85, 0.7, 0.6))
			for sx in [-0.4, 0.4]:
				box(b, Vector3(sx * 1.0, 1.55, -1.1), Vector3(0.5, 0.1, 0.1), Color(0.92, 0.88, 0.78), Vector3(0, 0, sx * 70.0))
				box(b, Vector3(sx * 1.25, 1.7, -1.1), Vector3(0.1, 0.3, 0.1), Color(0.92, 0.88, 0.78))
			box(b, Vector3(0, 0.5, 0.88), Vector3(0.08, 0.7, 0.08), dark)
			for sx in [-0.28, 0.28]:
				for sz in [-0.6, 0.6]:
					box(b, Vector3(sx, 0.3, sz), Vector3(0.16, 0.62, 0.16), dark)
			box(b, Vector3(0.0, 1.45, 0.0), Vector3(0.9, 0.05, 0.9), Color(0.15, 0.3, 0.7))
			box(b, Vector3(0.0, 1.0, 0.0), Vector3(0.9, 0.04, 0.5), Color(1.0, 0.8, 0.3), Vector3.ZERO, true, 0.0)
		_:
			# جدار عريض يسدّ المسارات الثلاثة
			zf = 0.8
			var w := Cfg.LANE_W * 3.0 - 0.2
			if family == Cfg.Family.MIR:
				box(b, Vector3(0, 0.15, 0), Vector3(w, 0.3, 1.6), trim)
				var n := 11
				for i in n:
					var x := -w * 0.5 + (i + 0.5) * (w / n)
					var hh := 2.2 + ((i * 7) % 5) * 0.35
					cyl(b, Vector3(x, hh * 0.5, 0.0), 0.5, 0.0, hh, body if i % 2 == 0 else body2, 5)
					cyl(b, Vector3(x, hh * 0.5, 0.0), 0.22, 0.0, hh + 0.1, gl, 5, Vector3.ZERO, true, 0.0)
			else:
				box(b, Vector3(0, 1.7, 0), Vector3(w, 3.4, 1.4), body)
				box(b, Vector3(0, 3.55, 0), Vector3(w + 0.3, 0.3, 1.6), trim)
				for i in 6:
					box(b, Vector3(-w * 0.5 + 0.7 + i * ((w - 1.4) / 5.0), 3.95, 0), Vector3(0.7, 0.5, 1.2), body2)
				cyl(b, Vector3(0, 1.8, 0.72), 1.15, 1.15, 0.08, gl, 14, Vector3(90, 0, 0), true, 0.0)
				cyl(b, Vector3(0, 1.8, 0.7), 1.4, 1.4, 0.06, trim, 14, Vector3(90, 0, 0))
				for i in 12:
					var a := i * 30.0
					box(b, Vector3(sin(deg_to_rad(a)) * 1.6, 1.8 + cos(deg_to_rad(a)) * 1.6, 0.74), Vector3(0.12, 0.5, 0.04), gl, Vector3(0, 0, -a), true, 0.0)
	var mats := _mat_for(family)
	var mesh := b.build(mats[0], mats[1])
	_cache[key] = mesh
	return mesh


static func obstacle_variants(kind: int) -> int:
	match kind:
		Cfg.Kind.LOW:
			return 3
		Cfg.Kind.FULL:
			return 3
		_:
			return 1


# ───────────────────────── العملات والتعزيزات ─────────────────────────
static func coin() -> ArrayMesh:
	if _cache.has("coin"):
		return _cache["coin"]
	var b := MeshBuilder.new()
	cyl(b, Vector3.ZERO, 0.4, 0.4, 0.09, Color(1.0, 0.72, 0.15), 10, Vector3(90, 0, 0), false, 0.0)
	cyl(b, Vector3(0, 0, 0.0), 0.3, 0.3, 0.13, Color(1.0, 0.86, 0.38), 10, Vector3(90, 0, 0), false, 0.0)
	var m := b.build(Mats.coin)
	_cache["coin"] = m
	return m


static func shard() -> ArrayMesh:
	if _cache.has("shard"):
		return _cache["shard"]
	var b := MeshBuilder.new()
	sph(b, Vector3.ZERO, Vector3(0.5, 0.95, 0.5), Color(0.45, 0.9, 1.0), 4, 2, Vector3.ZERO, true, 0.0)
	sph(b, Vector3.ZERO, Vector3(0.28, 0.6, 0.28), Color(1.0, 1.0, 1.0), 4, 2, Vector3.ZERO, true, 0.0)
	var m := b.build(Mats.shard, Mats.shard)
	_cache["shard"] = m
	return m


static func pickup(type: int) -> ArrayMesh:
	var key := "pickup%d" % type
	if _cache.has(key):
		return _cache[key]
	var b := MeshBuilder.new()
	match type:
		Cfg.Power.MAGNET:
			# قرن الثور (هلال)
			for i in 6:
				var a := deg_to_rad(-70.0 + i * 28.0)
				box(b, Vector3(sin(a) * 0.4, cos(a) * 0.32 - 0.1, 0), Vector3(0.2, 0.2, 0.2), Color(0.93, 0.88, 0.76), Vector3(0, 0, -rad_to_deg(a)))
			sph(b, Vector3(0, 0, -0.02), Vector3(1.25, 1.25, 0.1), Color(1.0, 0.9, 0.5), 8, 3, Vector3.ZERO, true, 0.0)
		Cfg.Power.SHIELD:
			# نجمة إنانا ثمانية الرؤوس
			cyl(b, Vector3.ZERO, 0.22, 0.22, 0.14, Color(0.98, 0.82, 0.3), 8, Vector3(90, 0, 0), true, 0.0)
			for i in 8:
				var ang := i * 45.0
				box(b, Vector3(sin(deg_to_rad(ang)) * 0.33, cos(deg_to_rad(ang)) * 0.33, 0), Vector3(0.1, 0.46 if i % 2 == 0 else 0.3, 0.1), Color(0.3, 0.62, 1.0), Vector3(0, 0, -ang), true, 0.0)
			sph(b, Vector3(0, 0, 0.05), Vector3(0.16, 0.16, 0.16), Color(1, 1, 1), 6, 3, Vector3.ZERO, true, 0.0)
		Cfg.Power.BOOST:
			# ريح إنليل: دوّامة
			for i in 5:
				var a2 := i * 72.0
				box(b, Vector3(sin(deg_to_rad(a2)) * 0.3, cos(deg_to_rad(a2)) * 0.3, 0), Vector3(0.5, 0.12, 0.12), Color(1.0, 0.85 - i * 0.07, 0.3), Vector3(0, 0, -a2 + 60.0), true, 0.0)
			sph(b, Vector3.ZERO, Vector3(0.22, 0.22, 0.22), Color(1.0, 0.95, 0.6), 6, 3, Vector3.ZERO, true, 0.0)
		Cfg.Power.DOUBLE:
			# لوح طين ذهبي عليه علامات مسمارية
			box(b, Vector3.ZERO, Vector3(0.7, 0.9, 0.16), Color(0.95, 0.75, 0.25))
			for i in 4:
				box(b, Vector3(0, 0.28 - i * 0.18, 0.09), Vector3(0.5, 0.05, 0.02), Color(0.5, 0.3, 0.05), Vector3.ZERO, false, 0.0)
			box(b, Vector3(0, 0, -0.1), Vector3(0.95, 1.15, 0.04), Color(1.0, 0.9, 0.5), Vector3.ZERO, true, 0.0)
		_:
			sph(b, Vector3.ZERO, Vector3(0.7, 0.7, 0.7), Color(0.2, 0.6, 0.9), 10, 5, Vector3.ZERO, true, 0.0)
			sph(b, Vector3.ZERO, Vector3(0.38, 0.38, 0.38), Color(0.8, 1.0, 1.0), 8, 4, Vector3.ZERO, true, 0.0)
			cyl(b, Vector3.ZERO, 0.6, 0.6, 0.04, Color(0.4, 0.95, 1.0), 14, Vector3(75, 0, 0), true, 0.0)
	var m := b.build(Mats.pickup, Mats.pickup_glow)
	_cache[key] = m
	return m


