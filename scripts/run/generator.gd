class_name Generator
extends RefCounted
## مولّد المسار اللانهائي المتوازن.
##
## كل صف (كل 9 م) يُختار من قوالب، ثم يُتحقق منه بخوارزمية «قابلية الوصول»:
## لكل بُعد (واقع / سراب) نحتفظ بمجموعة المسارات التي قد يكون اللاعب فيها بأمان،
## ولا يُقبل صف إلا إذا أمكن الوصول إلى مسار آمن فيه بتبديل مسار واحد (أو اثنين عند البطء).
## «بوابات السراب» (جدران لا تُعبر إلا في بُعد واحد) محدودة بتباعد أدنى وتتبعها دائماً فسحة.

const R := Cfg.ROWS_PER_SEG
const STEP := Cfg.ROW_STEP

var rng := RandomNumberGenerator.new()
var skill := 0.5               # 0..1 تكيّف مع أداء اللاعب
var reach: Array = [[true, true, true], [true, true, true]]   # [بُعد][مسار]
var rows_since_gate := 99
var rows_since_action := 99
var rows_since_pickup := 0
var rows_since_mover := 99
var must_recover := false
var distance_row := 0.0
var biome_gate_pending := false
var adaptive := true

var _empty_streak := 0


func reset(seed_val: int) -> void:
	rng.seed = seed_val
	skill = 0.5
	reach = [[true, true, true], [true, true, true]]
	rows_since_gate = 99
	rows_since_action = 99
	rows_since_pickup = 0
	rows_since_mover = 99
	must_recover = false
	_empty_streak = 0


# ───────────────────────── مساعدات الخلايا ─────────────────────────
static func cell(k: int, f: int, v := 0) -> Dictionary:
	return {"k": k, "f": f, "v": v}


## هل يمكن عبور الخلية في البُعد dim (0 واقع، 1 سراب)؟ جزء «بالفعل مع إجراء قفز/انزلاق» مسموح.
static func passable(c, dim: int) -> bool:
	if c == null:
		return true
	var k: int = c["k"]
	var f: int = c["f"]
	if k == Cfg.Kind.LOW or k == Cfg.Kind.HIGH:
		return true
	# FULL / WALL
	if f == Cfg.Family.SUN:
		return dim == 1
	if f == Cfg.Family.MIR:
		return dim == 0
	return false


static func is_action(c) -> bool:
	if c == null:
		return false
	return c["k"] == Cfg.Kind.LOW or c["k"] == Cfg.Kind.HIGH


## يحسب مجموعات المسارات الآمنة لصف ما بعد الوصول من الصف السابق.
func _evaluate(cells: Array, maxshift: int) -> Array:
	var out: Array = [[false, false, false], [false, false, false]]
	for d in 2:
		for l in 3:
			if not passable(cells[l], d):
				continue
			var ok := false
			for p in 3:
				if reach[d][p] and absi(p - l) <= maxshift:
					ok = true
					break
			out[d][l] = ok
	return out


static func _any(a: Array) -> bool:
	return a[0] or a[1] or a[2]


func _difficulty(dist: float) -> float:
	var d := clampf((dist - 120.0) / 4200.0, 0.0, 1.0)
	if adaptive:
		d = clampf(d + (skill - 0.5) * 0.35, 0.0, 1.0)
	return d


func speed_at(dist: float) -> float:
	return 13.0 + 17.0 * (1.0 - exp(-dist / 2600.0))


# ───────────────────────── القوالب ─────────────────────────
func _rand_stone_kind(diff: float) -> int:
	var r := rng.randf()
	if r < 0.34:
		return Cfg.Kind.LOW
	elif r < 0.62:
		return Cfg.Kind.HIGH
	return Cfg.Kind.FULL


func _fam_flavor(allow_special: bool) -> int:
	if not allow_special:
		return Cfg.Family.STONE
	var r := rng.randf()
	if r < 0.5:
		return Cfg.Family.STONE
	elif r < 0.78:
		return Cfg.Family.SUN
	return Cfg.Family.MIR


func _rv(kind: int) -> int:
	return rng.randi() % Meshes.obstacle_variants(kind)


## يبني صفاً مرشحاً. يعيد {cells, tag, gate}
func _candidate(diff: float, dist: float, allow_mirage: bool) -> Dictionary:
	var cells: Array = [null, null, null]
	var tag := "empty"
	var w := {
		"empty": 0.7 - diff * 0.4,
		"single": 2.2,
		"double": 1.0 + diff * 2.4,
		"low_wall": 1.0 + diff * 0.6,
		"high_gate": 1.0 + diff * 0.6,
		"mixed": 0.4 + diff * 1.8,
		"mover": 0.6 + diff * 0.8 if rows_since_mover > 3 and dist > 260.0 else 0.0,
	}
	if allow_mirage and dist > 220.0:
		w["sun_cover"] = 1.5 + diff * 1.0
		w["mir_cover"] = 0.8 + diff * 0.8
		w["phase_lane"] = 0.9 + diff * 1.2
		if rows_since_gate > 7:
			w["wall_sun"] = 0.9 + diff * 0.7
			w["wall_mir"] = 0.35 + diff * 0.5
	if _empty_streak >= 1:
		w["empty"] = 0.0
	var total := 0.0
	for k in w.keys():
		total += w[k]
	var pick := rng.randf() * total
	for k in w.keys():
		pick -= w[k]
		if pick <= 0.0:
			tag = k
			break
	var gate := false
	match tag:
		"empty":
			pass
		"single":
			var k := _rand_stone_kind(diff)
			var fam := _fam_flavor(allow_mirage and dist > 220.0)
			if fam != Cfg.Family.STONE and k != Cfg.Kind.FULL and rng.randf() < 0.6:
				fam = Cfg.Family.STONE
			cells[rng.randi() % 3] = cell(k, fam, _rv(k))
		"double":
			var free := rng.randi() % 3
			for l in 3:
				if l == free:
					continue
				var k := _rand_stone_kind(diff)
				cells[l] = cell(k, Cfg.Family.STONE, _rv(k))
			if rng.randf() < 0.45 and allow_mirage and dist > 220.0:
				var l2 := (free + 1 + rng.randi() % 2) % 3
				cells[l2] = cell(Cfg.Kind.FULL, Cfg.Family.SUN if rng.randf() < 0.6 else Cfg.Family.MIR, _rv(Cfg.Kind.FULL))
		"low_wall":
			var v := rng.randi() % 3
			var fam := Cfg.Family.STONE
			if allow_mirage and dist > 220.0 and rng.randf() < 0.35:
				fam = Cfg.Family.SUN if rng.randf() < 0.5 else Cfg.Family.MIR
			for l in 3:
				cells[l] = cell(Cfg.Kind.LOW, fam, v)
		"high_gate":
			var fam2 := Cfg.Family.STONE
			if allow_mirage and dist > 220.0 and rng.randf() < 0.35:
				fam2 = Cfg.Family.SUN if rng.randf() < 0.5 else Cfg.Family.MIR
			for l in 3:
				cells[l] = cell(Cfg.Kind.HIGH, fam2, 0)
		"mixed":
			var kinds := [Cfg.Kind.LOW, Cfg.Kind.HIGH, Cfg.Kind.FULL]
			kinds.shuffle()
			for l in 3:
				var kk: int = kinds[l]
				cells[l] = cell(kk, Cfg.Family.STONE, _rv(kk))
		"mover":
			pass   # يُضاف المتحرّك لاحقاً
		"sun_cover":
			# عوائق شمس صلبة في مسارين؛ المسار الثالث حر؛ لآلئ السراب خلف الشمس
			var free2 := rng.randi() % 3
			for l in 3:
				if l != free2:
					cells[l] = cell(Cfg.Kind.FULL, Cfg.Family.SUN, _rv(Cfg.Kind.FULL))
		"mir_cover":
			var free3 := rng.randi() % 3
			for l in 3:
				if l != free3:
					cells[l] = cell(Cfg.Kind.FULL, Cfg.Family.MIR, _rv(Cfg.Kind.FULL))
		"phase_lane":
			# مسار شمس صلب في الوسط بين حجرين: لا عبور في الواقع (بوابة سراب)
			var mid := 1
			cells[mid] = cell(Cfg.Kind.FULL, Cfg.Family.SUN, _rv(Cfg.Kind.FULL))
			cells[0] = cell(Cfg.Kind.FULL, Cfg.Family.STONE, _rv(Cfg.Kind.FULL))
			cells[2] = cell(Cfg.Kind.FULL, Cfg.Family.STONE, _rv(Cfg.Kind.FULL))
			if rng.randf() < 0.5:
				cells[2] = cell(Cfg.Kind.LOW, Cfg.Family.STONE, 0)
			gate = true
		"wall_sun":
			for l in 3:
				cells[l] = null
			cells[0] = cell(Cfg.Kind.WALL, Cfg.Family.SUN, 0)
			gate = true
		"wall_mir":
			cells[0] = cell(Cfg.Kind.WALL, Cfg.Family.MIR, 0)
			gate = true
	return {"cells": cells, "tag": tag, "gate": gate}


## يوسّع خلية WALL إلى المسارات الثلاثة (تُخزّن في الخلية 0 فقط، يعامل كعائق عريض).
static func expand_wall(cells: Array) -> Array:
	var c0 = cells[0]
	if c0 != null and c0["k"] == Cfg.Kind.WALL:
		return [c0, c0, c0]
	return cells


# ───────────────────────── المقطع ─────────────────────────
## يملأ مقطعاً. dist = مسافة بداية المقطع من خط البداية.
func fill_segment(seg: Segment, dist: float, biome: int, variant: int) -> void:
	seg.spawn_dist = dist
	seg.clear_content(biome, variant)
	var diff := _difficulty(dist)
	var spd := speed_at(dist)
	var allow_mirage := true
	var maxshift := 1 if spd > 19.0 else 2

	for r in R:
		var z := -(r * STEP + 4.5)
		var row_dist := dist + r * STEP + 4.5
		var cells: Array = [null, null, null]
		var tag := "empty"
		var gate := false
		var grace := row_dist < 75.0
		if not grace:
			if must_recover:
				# فسحة: صف بلا عوائق مُلزِمة (قفز/انزلاق اختياري فقط) بعد البوابة
				tag = "recover"
				must_recover = false
				rows_since_gate = 0
				reach = [[true, true, true], [true, true, true]]
			else:
				var best: Dictionary = {}
				var ok_eval: Array = []
				for attempt in 8:
					var cand := _candidate(diff, row_dist, allow_mirage)
					var ccells: Array = expand_wall(cand["cells"])
					var ev := _evaluate(ccells, maxshift)
					var need_real := _any(ev[0])
					var need_mir := _any(ev[1])
					var is_gate: bool = not (need_real and need_mir)
					if is_gate:
						# بوابة: مسموحة فقط إن كان التباعد كافياً وأحد البُعدين عابر
						if rows_since_gate < 6 or (not need_real and not need_mir):
							continue
						# يجب أن يكون هناك بُعد قابل للعبور على الأقل
					# منع تتابع الإجراءات القاسية
					var all_action := true
					for l in 3:
						if ccells[l] != null and not is_action(ccells[l]) and passable(ccells[l], 0):
							pass
					if rows_since_action < 1 and cand["tag"] in ["low_wall", "high_gate", "mixed"] and spd > 17.0:
						continue
					best = cand
					best["cells"] = ccells
					ok_eval = ev
					break
				if best.is_empty():
					best = {"cells": [null, null, null], "tag": "empty", "gate": false}
					ok_eval = _evaluate(best["cells"], 2)
				cells = best["cells"]
				tag = best["tag"]
				var gate_dims_real: bool = _any(ok_eval[0])
				var gate_dims_mir: bool = _any(ok_eval[1])
				gate = not (gate_dims_real and gate_dims_mir)
				# تحديث الوصول
				if gate:
					# اللاعب في البُعد العابر فقط
					reach[0] = ok_eval[0]
					reach[1] = ok_eval[1]
					rows_since_gate = 0
					must_recover = true
				else:
					reach[0] = ok_eval[0]
					reach[1] = ok_eval[1]
					rows_since_gate += 1
				var had_action := false
				for l in 3:
					if is_action(cells[l]):
						had_action = true
				if had_action:
					rows_since_action = 0
				else:
					rows_since_action += 1
				if tag == "empty":
					_empty_streak += 1
				else:
					_empty_streak = 0
		# أنشئ العوائق
		var placed_any := false
		var l := 0
		while l < 3:
			var c = cells[l]
			if c != null:
				if c["k"] == Cfg.Kind.WALL:
					seg.add_obstacle(Cfg.Kind.WALL, c["f"], 0, -1, 1, z)
					placed_any = true
					l = 3
					continue
				seg.add_obstacle(c["k"], c["f"], c["v"], l - 1, l - 1, z)
				placed_any = true
			l += 1
		rows_since_mover += 1
		if tag == "mover":
			rows_since_mover = 0
			var dirn := -1.0 if rng.randf() < 0.5 else 1.0
			seg.add_mover(z, dirn, 3.4 + diff * 1.8 + rng.randf() * 0.6)
		_place_collectibles(seg, cells, tag, gate, z, r, row_dist, diff)
	seg.finalize()


# ───────────────────────── جمع العملات والتعزيزات ─────────────────────────
func _lane_x(l: int) -> float:
	return (l - 1) * Cfg.LANE_W


func _place_collectibles(seg: Segment, cells: Array, tag: String, gate: bool, z: float, r: int, row_dist: float, diff: float) -> void:
	# مسار العملات: أوّل مسار مفتوح (بلا عائق صلب في الواقع) يعتمد على بذرة الصف
	var open_real: Array = []
	for l in 3:
		var c = cells[l]
		if c == null:
			open_real.append(l)
		elif c["k"] == Cfg.Kind.WALL:
			pass
	var coin_lane := 1
	if not open_real.is_empty():
		coin_lane = open_real[rng.randi() % open_real.size()]
	# اترك الصفوف المزدحمة بالعملات قليلاً
	if rng.randf() < 0.18 and tag != "empty" and tag != "recover":
		return
	var span := STEP - 2.0
	var n := 5
	match tag:
		"empty", "recover", "mover":
			# خط عملات طويل أو قوس
			for i in n:
				var zz := z + span * 0.5 - i * (span / (n - 1))
				seg.add_coin(Vector3(_lane_x(coin_lane), 0.85, zz))
		"low_wall":
			# قوس فوق الجدار المنخفض (يشجع القفز)
			for i in 7:
				var t := float(i) / 6.0
				var zz2 := z + 3.4 - t * 6.8
				seg.add_coin(Vector3(_lane_x(1), 0.85 + sin(t * PI) * 1.35, zz2))
		"high_gate":
			# عملات على الأرض تحت العارضة (انزلاق)
			for i in 6:
				var t2 := float(i) / 5.0
				seg.add_coin(Vector3(_lane_x(1), 0.55, z + 2.6 - t2 * 5.2))
		"sun_cover", "phase_lane":
			# لآلئ السراب داخل مسار الشمس الصلب (تُجمع في السراب فقط)
			for l2 in 3:
				var c2 = cells[l2]
				if c2 != null and c2["f"] == Cfg.Family.SUN:
					for i in 5:
						seg.add_shard(Vector3(_lane_x(l2), 0.9 + (0.0 if i % 2 == 0 else 0.0), z + 3.0 - i * 1.5))
			if tag == "sun_cover":
				for i in 3:
					seg.add_coin(Vector3(_lane_x(coin_lane), 0.85, z + 2.0 - i * 2.0))
		"mir_cover":
			for l3 in 3:
				var c3 = cells[l3]
				if c3 != null and c3["f"] == Cfg.Family.MIR:
					for i in 3:
						seg.add_coin(Vector3(_lane_x(l3), 0.85, z + 2.0 - i * 2.0))
		"wall_sun":
			for l4 in 3:
				for i in 3:
					seg.add_shard(Vector3(_lane_x(l4), 0.9, z + 2.4 - i * 2.4))
		"wall_mir":
			for l5 in 3:
				seg.add_coin(Vector3(_lane_x(l5), 0.85, z + 2.0 - 0.0))
		_:
			for i in 4:
				seg.add_coin(Vector3(_lane_x(coin_lane), 0.85, z + 3.0 - i * 2.0))
	# تعزيز كل بضعة مئات الأمتار
	rows_since_pickup += 1
	if rows_since_pickup > 34 and row_dist > 200.0 and tag in ["empty", "recover"] and rng.randf() < 0.5:
		rows_since_pickup = 0
		var tp := rng.randi() % 5
		if rng.randf() < 0.16:
			tp = Cfg.Power.ORB
		seg.add_pickup(tp, Vector3(_lane_x(coin_lane), 1.0, z + 1.0))
