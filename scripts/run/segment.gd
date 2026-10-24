class_name Segment
extends Node3D
## مقطع واحد من المسار (36 م): أرضية + ديكور + عوائق + عملات + تعزيزات.
## تُعاد تدوير 6 مقاطع فقط طوال اللعب (لا إنشاء/حذف أثناء الجري).

const MAX_OBS := 14
const MAX_COINS := 44
const MAX_PICKUPS := 3


class Obs extends RefCounted:
	var node: MeshInstance3D
	var kind := 0
	var family := 0
	var cx := 0.0
	var half_w := 1.0
	var z := 0.0
	var half_d := 0.6
	var passed := false
	var hit := false
	var graze := false
	var ghosted := false
	var smashed := false
	var vx := 0.0
	var active := false


class Pick extends RefCounted:
	var node: MeshInstance3D
	var type := 0
	var pos := Vector3.ZERO
	var alive := false


var biome := 0
var spawn_dist := 0.0
var ground: MeshInstance3D
var decor: MeshInstance3D
var obs: Array[Obs] = []
var _obs_nodes: Array[MeshInstance3D] = []
var _obs_used := 0

var coin_mm: MultiMesh
var coin_mmi: MultiMeshInstance3D
var shard_mm: MultiMesh
var shard_mmi: MultiMeshInstance3D
var coin_pos := PackedVector3Array()
var coin_alive := PackedByteArray()
var coin_n := 0
var shard_pos := PackedVector3Array()
var shard_alive := PackedByteArray()
var shard_n := 0
var picks: Array[Pick] = []

var got_coins := 0
var got_shards := 0
var got_pickups: Array[int] = []
var last_collect_pos := Vector3.ZERO


func _init() -> void:
	ground = MeshInstance3D.new()
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)
	decor = MeshInstance3D.new()
	decor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(decor)
	for i in MAX_OBS:
		var n := MeshInstance3D.new()
		n.visible = false
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(n)
		_obs_nodes.append(n)
	coin_mm = MultiMesh.new()
	coin_mm.transform_format = MultiMesh.TRANSFORM_3D
	coin_mm.instance_count = MAX_COINS
	coin_mm.mesh = Meshes.coin()
	coin_mmi = MultiMeshInstance3D.new()
	coin_mmi.multimesh = coin_mm
	coin_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	coin_mmi.custom_aabb = AABB(Vector3(-6, -1, -Cfg.SEG_LEN - 2), Vector3(12, 5, Cfg.SEG_LEN + 4))
	add_child(coin_mmi)
	shard_mm = MultiMesh.new()
	shard_mm.transform_format = MultiMesh.TRANSFORM_3D
	shard_mm.instance_count = MAX_COINS
	shard_mm.mesh = Meshes.shard()
	shard_mmi = MultiMeshInstance3D.new()
	shard_mmi.multimesh = shard_mm
	shard_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shard_mmi.custom_aabb = coin_mmi.custom_aabb
	add_child(shard_mmi)
	coin_pos.resize(MAX_COINS)
	coin_alive.resize(MAX_COINS)
	shard_pos.resize(MAX_COINS)
	shard_alive.resize(MAX_COINS)
	for i in MAX_PICKUPS:
		var p := Pick.new()
		p.node = MeshInstance3D.new()
		p.node.visible = false
		p.node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(p.node)
		picks.append(p)


# ───────────────────────── بناء المحتوى ─────────────────────────
func clear_content(new_biome: int, variant: int) -> void:
	biome = new_biome
	ground.mesh = Meshes.ground(new_biome)
	decor.mesh = Meshes.decor(new_biome, variant)
	for o in obs:
		o.node.visible = false
		o.node.rotation = Vector3.ZERO
	obs.clear()
	_obs_used = 0
	coin_n = 0
	shard_n = 0
	got_coins = 0
	got_shards = 0
	got_pickups.clear()
	for p in picks:
		p.alive = false
		p.node.visible = false


## يضيف عائقاً. lane_a..lane_b: المسارات التي يغطيها (-1..1).
func add_obstacle(kind: int, family: int, variant: int, lane_a: int, lane_b: int, z: float) -> void:
	if _obs_used >= MAX_OBS:
		return
	var o := Obs.new()
	o.node = _obs_nodes[_obs_used]
	_obs_used += 1
	o.kind = kind
	o.family = family
	o.cx = (lane_a + lane_b) * 0.5 * Cfg.LANE_W
	var nlanes := lane_b - lane_a + 1
	o.half_w = (nlanes * Cfg.LANE_W - 0.4) * 0.5
	o.z = z
	o.half_d = Cfg.HALF_DEPTH[kind]
	o.node.mesh = Meshes.obstacle(kind, family, variant)
	o.node.position = Vector3(o.cx, 0.0, z)
	o.node.visible = true
	obs.append(o)


func add_mover(z: float, dirn: float, speed: float) -> void:
	if _obs_used >= MAX_OBS:
		return
	var o := Obs.new()
	o.node = _obs_nodes[_obs_used]
	_obs_used += 1
	o.kind = Cfg.Kind.MOVER
	o.family = Cfg.Family.STONE
	o.half_w = 0.55
	o.half_d = Cfg.HALF_DEPTH[Cfg.Kind.MOVER]
	o.z = z
	o.cx = -dirn * (Cfg.ROAD_HALF + 1.6)
	o.vx = dirn * speed
	o.node.mesh = Meshes.obstacle(Cfg.Kind.MOVER, Cfg.Family.STONE, 0)
	o.node.position = Vector3(o.cx, 0.0, z)
	o.node.rotation_degrees = Vector3(0, 90.0 * dirn, 0)
	o.node.visible = true
	obs.append(o)


func add_coin(p: Vector3) -> void:
	if coin_n >= MAX_COINS:
		return
	coin_pos[coin_n] = p
	coin_alive[coin_n] = 1
	coin_n += 1


func add_shard(p: Vector3) -> void:
	if shard_n >= MAX_COINS:
		return
	shard_pos[shard_n] = p
	shard_alive[shard_n] = 1
	shard_n += 1


func add_pickup(type: int, p: Vector3) -> void:
	for pk in picks:
		if not pk.alive:
			pk.alive = true
			pk.type = type
			pk.pos = p
			pk.node.mesh = Meshes.pickup(type)
			pk.node.position = p
			pk.node.visible = true
			return


func finalize() -> void:
	# إخفاء العملات غير المستخدمة
	var zero := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
	for i in MAX_COINS:
		if i >= coin_n:
			coin_alive[i] = 0
			coin_mm.set_instance_transform(i, zero)
		if i >= shard_n:
			shard_alive[i] = 0
			shard_mm.set_instance_transform(i, zero)
	spin(0.0)


## تدوير العملات وكتابة المصفوفات (يُستدعى للمقاطع القريبة فقط).
func spin(t: float) -> void:
	for i in coin_n:
		if coin_alive[i] == 1:
			coin_mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, t * 4.0 + i * 0.6), coin_pos[i]))
	for i in shard_n:
		if shard_alive[i] == 1:
			var p := shard_pos[i]
			p.y += sin(t * 3.0 + i) * 0.08
			shard_mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, t * 2.4 + i), p))
	for pk in picks:
		if pk.alive:
			pk.node.rotation.y = t * 2.2
			pk.node.position.y = pk.pos.y + sin(t * 3.0) * 0.12


## تجميع العملات: px,py موضع اللاعب (عالمي)، ph الارتفاع، mag = نصف قطر الجاذب (0 = معطّل)
func collect(px: float, py: float, ph: float, mag: float, mirage: bool, dt: float) -> void:
	var zw := position.z
	var lo := py - 0.45
	var hi := py + ph + 0.35
	var zero := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
	var pull := 1.0 - exp(-dt * 9.0)
	var target := Vector3(px, py + ph * 0.5, -zw)
	for i in coin_n:
		if coin_alive[i] == 0:
			continue
		var p := coin_pos[i]
		var wz := zw + p.z
		if mag > 0.0 and wz > -16.0 and wz < 3.0 and absf(p.x - px) < mag:
			p = p.lerp(target, pull)
			coin_pos[i] = p
			wz = zw + p.z
		if wz > -0.9 and wz < 0.9 and absf(p.x - px) < 0.85 and p.y > lo and p.y < hi:
			coin_alive[i] = 0
			coin_mm.set_instance_transform(i, zero)
			got_coins += 1
			last_collect_pos = Vector3(p.x, p.y, wz)
	if mirage:
		for i in shard_n:
			if shard_alive[i] == 0:
				continue
			var p := shard_pos[i]
			var wz := zw + p.z
			if mag > 0.0 and wz > -14.0 and wz < 3.0 and absf(p.x - px) < mag:
				p = p.lerp(target, pull)
				shard_pos[i] = p
				wz = zw + p.z
			if wz > -1.0 and wz < 1.0 and absf(p.x - px) < 0.95 and p.y > lo - 0.2 and p.y < hi + 0.2:
				shard_alive[i] = 0
				shard_mm.set_instance_transform(i, zero)
				got_shards += 1
				last_collect_pos = Vector3(p.x, p.y, wz)
	for pk in picks:
		if not pk.alive:
			continue
		var wz := zw + pk.pos.z
		if wz > -1.1 and wz < 1.1 and absf(pk.pos.x - px) < 1.1 and pk.pos.y > lo - 0.4 and pk.pos.y < hi + 0.4:
			pk.alive = false
			pk.node.visible = false
			got_pickups.append(pk.type)
			last_collect_pos = Vector3(pk.pos.x, pk.pos.y, wz)
