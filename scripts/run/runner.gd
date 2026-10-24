class_name Runner
extends Node3D
## الشخصية: نموذج ثلاثي الأبعاد مبني بالكود + هيكل عظمي إجرائي + منطق الحركة.
## الحركة هنا (مسارات، قفز، انزلاق) والتصادم يقرره RunController.

signal jumped
signal landed(hard: bool)
signal slid
signal lane_changed(dir: int)

enum Pose { IDLE, RUN, JUMP, FALL, SLIDE, STUMBLE, DEAD }

const GRAVITY := 31.0
const JUMP_V := 11.2
const FASTFALL_V := -26.0
const SLIDE_TIME := 0.78
const BUFFER_TIME := 0.16

# مفاتيح مصفوفة الوضعيات
const J_HIP_X := 0
const J_HIP_ROLL := 1
const J_HIP_YAW := 2
const J_HEAD_X := 3
const J_ARM_L_X := 4
const J_ARM_L_Z := 5
const J_FORE_L := 6
const J_ARM_R_X := 7
const J_ARM_R_Z := 8
const J_FORE_R := 9
const J_THIGH_L := 10
const J_SHIN_L := 11
const J_THIGH_R := 12
const J_SHIN_R := 13
const J_HIP_Y := 14
const J_HIP_Z := 15
const J_COUNT := 16

# منطق
var lane := 0
var x := 0.0
var y := 0.0
var vy := 0.0
var on_ground := true
var slide_t := 0.0
var stumble_t := 0.0
var invuln_t := 0.0
var dead := false
var running := false
var pose := Pose.IDLE
var speed_vis := 0.0

var _buf_action := -1   # 0 jump, 1 slide
var _buf_t := 0.0
var _fastfall := false
var prev_lane := 0
var lane_change_age := 9.0

# مرئيات
var vis: Node3D
var hips: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var fore_l: Node3D
var fore_r: Node3D
var thigh_l: Node3D
var thigh_r: Node3D
var shin_l: Node3D
var shin_r: Node3D
var scarf: Array[Node3D] = []
var blob: MeshInstance3D
var shield_fx: MeshInstance3D
var _cur := PackedFloat32Array()
var _tgt := PackedFloat32Array()
var _phase := 0.0
var _t := 0.0
var _stumble_el := 0.0
var _flash_t := 0.0
var _hip_base_y := 0.92
var _sh := 1.0
var _parts: Array[MeshInstance3D] = []
var _veil := false


func _init() -> void:
	_cur.resize(J_COUNT)
	_tgt.resize(J_COUNT)


func _ready() -> void:
	vis = Node3D.new()
	add_child(vis)
	blob = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.3, 1.3)
	q.material = Mats.blob
	blob.mesh = q
	blob.rotation_degrees = Vector3(-90, 0, 0)
	blob.position = Vector3(0, 0.04, 0)
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(blob)

	shield_fx = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.15
	sm.height = 2.3
	sm.radial_segments = 14
	sm.rings = 8
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(0.3, 0.7, 1.0, 0.22)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_fog = true
	sm.material = mat
	shield_fx.mesh = sm
	shield_fx.position = Vector3(0, 1.0, 0)
	shield_fx.visible = false
	shield_fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shield_fx)


# ───────────────────────── بناء الشخصية ─────────────────────────
func _mi(parent: Node3D, mesh: Mesh, pos := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.position = pos
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	_parts.append(m)
	return m


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


func build(ch: Dictionary, cw: Dictionary) -> void:
	for c in vis.get_children():
		c.queue_free()
	_parts.clear()
	scarf.clear()
	_sh = float(ch["shoulder"])
	vis.scale = Vector3.ONE * float(ch["height"])
	var skin: Color = cw["skin"]
	var hair: Color = cw["hood"]
	var cloth: Color = cw["tunic"]
	var legc: Color = cw["pants"]
	var sandal: Color = cw["boots"]
	var ribbon: Color = cw["scarf"]
	var acc: Color = cw["accent"]
	var style: String = ch["head"]
	_veil = style == "priestess"
	var sh := _sh
	var female := style == "priestess"

	hips = _pivot(vis, Vector3(0, _hip_base_y, 0))

	# جذع: صدر عارٍ للأبطال (كما في النقوش السومرية) وثوب لإنانا
	var b := MeshBuilder.new()
	if female:
		Meshes.box(b, Vector3(0, 0.30, 0), Vector3(0.36 * sh, 0.54, 0.24), cloth, Vector3.ZERO, false, 0.03)
		Meshes.box(b, Vector3(0, 0.50, -0.125), Vector3(0.30 * sh, 0.06, 0.02), acc, Vector3.ZERO, true, 0.0)
		Meshes.sph(b, Vector3(0, 0.52, 0), Vector3(0.38 * sh, 0.2, 0.26), skin, 8, 3)
	else:
		Meshes.box(b, Vector3(0, 0.30, 0), Vector3(0.42 * sh, 0.54, 0.25), skin, Vector3.ZERO, false, 0.03)
		Meshes.box(b, Vector3(-0.1 * sh, 0.38, -0.13), Vector3(0.16 * sh, 0.16, 0.03), skin.lightened(0.07), Vector3.ZERO, false, 0.0)
		Meshes.box(b, Vector3(0.1 * sh, 0.38, -0.13), Vector3(0.16 * sh, 0.16, 0.03), skin.lightened(0.07), Vector3.ZERO, false, 0.0)
		Meshes.box(b, Vector3(0.0, 0.32, -0.135), Vector3(0.09, 0.62, 0.025), ribbon, Vector3(0, 0, -38), false, 0.0)
		Meshes.box(b, Vector3(0.0, 0.32, 0.135), Vector3(0.09, 0.62, 0.025), ribbon, Vector3(0, 0, -38), false, 0.0)
	Meshes.box(b, Vector3(-0.22 * sh, 0.52, 0), Vector3(0.18, 0.18, 0.18), skin, Vector3.ZERO, false, 0.0)
	Meshes.box(b, Vector3(0.22 * sh, 0.52, 0), Vector3(0.18, 0.18, 0.18), skin, Vector3.ZERO, false, 0.0)
	Meshes.box(b, Vector3(0, 0.03, 0), Vector3(0.44 * sh, 0.1, 0.28), acc, Vector3.ZERO, true, 0.0)
	# تنّورة «كاوناكس» متعددة الطبقات
	var skirt_h := 0.5 if female else 0.36
	var skirt_y := -0.2 if female else -0.13
	Meshes.cyl(b, Vector3(0, skirt_y, 0), 0.31 * sh, 0.22 * sh, skirt_h, cloth, 10, Vector3.ZERO, false, 0.03)
	Meshes.cyl(b, Vector3(0, skirt_y - skirt_h * 0.18, 0), 0.34 * sh, 0.27 * sh, skirt_h * 0.5, cloth.darkened(0.08), 10, Vector3.ZERO, false, 0.03)
	Meshes.cyl(b, Vector3(0, skirt_y - skirt_h * 0.5 + 0.02, 0), 0.345 * sh, 0.345 * sh, 0.06, acc, 10, Vector3.ZERO, true, 0.0)
	_mi(hips, b.build(Mats.world, Mats.glow))

	# رأس
	head = _pivot(hips, Vector3(0, 0.62, 0))
	var hb := MeshBuilder.new()
	Meshes.sph(hb, Vector3(0, 0.16, 0), Vector3(0.31, 0.33, 0.31), skin, 8, 5, Vector3.ZERO, false, 0.0)
	Meshes.box(hb, Vector3(-0.065, 0.18, -0.145), Vector3(0.05, 0.05, 0.03), Color(0.06, 0.04, 0.05), Vector3.ZERO, false, 0.0)
	Meshes.box(hb, Vector3(0.065, 0.18, -0.145), Vector3(0.05, 0.05, 0.03), Color(0.06, 0.04, 0.05), Vector3.ZERO, false, 0.0)
	Meshes.box(hb, Vector3(0, 0.215, -0.15), Vector3(0.22, 0.025, 0.02), hair, Vector3.ZERO, false, 0.0)
	match style:
		"king":
			# جلجامش: شعر مجعّد ولحية مجدولة وعصابة ذهبية
			Meshes.sph(hb, Vector3(0, 0.26, 0.05), Vector3(0.38, 0.3, 0.38), hair, 8, 4, Vector3.ZERO, false, 0.04)
			for i in 5:
				Meshes.sph(hb, Vector3(-0.15 + i * 0.075, 0.07 - (i % 2) * 0.03, 0.16), Vector3(0.1, 0.16, 0.1), hair, 5, 3)
			Meshes.sph(hb, Vector3(0, 0.03, -0.1), Vector3(0.22, 0.26, 0.14), hair, 8, 4, Vector3.ZERO, false, 0.04)
			Meshes.cyl(hb, Vector3(0, 0.28, 0), 0.2, 0.2, 0.05, acc, 10, Vector3.ZERO, true, 0.0)
			Meshes.sph(hb, Vector3(0, 0.28, -0.2), Vector3(0.07, 0.07, 0.04), Color(0.3, 0.6, 1.0), 6, 3, Vector3.ZERO, true, 0.0)
		"wild":
			# أنكيدو: شعر طويل أشعث وجسد مكسوّ بالوبر
			Meshes.sph(hb, Vector3(0, 0.25, 0.06), Vector3(0.42, 0.34, 0.42), hair, 7, 4, Vector3.ZERO, false, 0.08)
			Meshes.box(hb, Vector3(0, -0.12, 0.2), Vector3(0.36, 0.75, 0.1), hair, Vector3(10, 0, 0), false, 0.08)
			Meshes.box(hb, Vector3(-0.2, 0.02, 0.08), Vector3(0.08, 0.4, 0.14), hair, Vector3(0, 0, 8), false, 0.08)
			Meshes.box(hb, Vector3(0.2, 0.02, 0.08), Vector3(0.08, 0.4, 0.14), hair, Vector3(0, 0, -8), false, 0.08)
			Meshes.sph(hb, Vector3(0, 0.05, -0.11), Vector3(0.18, 0.12, 0.1), hair.lightened(0.05), 6, 3)
		_:
			# إنانا: تاج القرنين ونجمة وشعر طويل
			Meshes.sph(hb, Vector3(0, 0.24, 0.05), Vector3(0.36, 0.3, 0.37), hair, 8, 4, Vector3.ZERO, false, 0.03)
			Meshes.box(hb, Vector3(0, -0.12, 0.17), Vector3(0.32, 0.8, 0.08), hair, Vector3(6, 0, 0), false, 0.03)
			Meshes.cyl(hb, Vector3(0, 0.3, 0), 0.2, 0.2, 0.08, acc, 10, Vector3.ZERO, true, 0.0)
			for sx in [-1.0, 1.0]:
				Meshes.cyl(hb, Vector3(sx * 0.12, 0.44, 0), 0.06, 0.015, 0.3, Color(0.96, 0.92, 0.82), 5, Vector3(0, 0, -sx * 24.0))
				Meshes.cyl(hb, Vector3(sx * 0.2, 0.62, 0), 0.04, 0.01, 0.16, Color(0.96, 0.92, 0.82), 5, Vector3(0, 0, -sx * 48.0))
			Meshes.sph(hb, Vector3(0, 0.34, -0.2), Vector3(0.09, 0.09, 0.04), Color(0.4, 0.8, 1.0), 6, 3, Vector3.ZERO, true, 0.0)
	_mi(head, hb.build(Mats.world, Mats.glow))

	# أذرع: عارية مع أساور ذهبية
	arm_l = _pivot(hips, Vector3(-0.3 * sh, 0.52, 0))
	arm_r = _pivot(hips, Vector3(0.3 * sh, 0.52, 0))
	fore_l = _pivot(arm_l, Vector3(0, -0.3, 0))
	fore_r = _pivot(arm_r, Vector3(0, -0.3, 0))
	for pair in [[arm_l, fore_l], [arm_r, fore_r]]:
		var ab := MeshBuilder.new()
		Meshes.cyl(ab, Vector3(0, -0.15, 0), 0.075, 0.062, 0.3, skin, 6)
		Meshes.cyl(ab, Vector3(0, -0.08, 0), 0.085, 0.085, 0.045, acc, 6, Vector3.ZERO, true, 0.0)
		_mi(pair[0], ab.build(Mats.world, Mats.glow))
		var fb := MeshBuilder.new()
		Meshes.cyl(fb, Vector3(0, -0.14, 0), 0.062, 0.055, 0.28, skin, 6)
		Meshes.cyl(fb, Vector3(0, -0.04, 0), 0.07, 0.07, 0.06, acc, 6, Vector3.ZERO, true, 0.0)
		Meshes.sph(fb, Vector3(0, -0.3, 0), Vector3(0.13, 0.13, 0.13), skin, 6, 3)
		_mi(pair[1], fb.build(Mats.world, Mats.glow))

	# أرجل: عارية مع صنادل
	thigh_l = _pivot(hips, Vector3(-0.12 * sh, -0.08, 0))
	thigh_r = _pivot(hips, Vector3(0.12 * sh, -0.08, 0))
	shin_l = _pivot(thigh_l, Vector3(0, -0.42, 0))
	shin_r = _pivot(thigh_r, Vector3(0, -0.42, 0))
	for pair in [[thigh_l, shin_l], [thigh_r, shin_r]]:
		var tb := MeshBuilder.new()
		Meshes.cyl(tb, Vector3(0, -0.21, 0), 0.098, 0.078, 0.44, legc, 6)
		_mi(pair[0], tb.build(Mats.world))
		var sb := MeshBuilder.new()
		Meshes.cyl(sb, Vector3(0, -0.2, 0), 0.075, 0.062, 0.4, legc, 6)
		Meshes.box(sb, Vector3(0, -0.46, -0.04), Vector3(0.15, 0.05, 0.3), sandal, Vector3.ZERO, false, 0.04)
		Meshes.box(sb, Vector3(0, -0.4, -0.05), Vector3(0.14, 0.04, 0.12), acc, Vector3.ZERO, false, 0.0)
		Meshes.box(sb, Vector3(0, -0.32, 0), Vector3(0.13, 0.035, 0.13), sandal)
		_mi(pair[1], sb.build(Mats.world))

	# شريط/عباءة صوفية ترفرف خلف الظهر
	var prev := _pivot(hips, Vector3(0, 0.6, 0.1))
	var seg_n := 6
	var w := 0.2 if not _veil else 0.3
	for i in seg_n:
		var seg := Node3D.new()
		if i > 0:
			seg.position = Vector3(0, 0, 0.2)
		prev.add_child(seg)
		var sbm := MeshBuilder.new()
		var tw := w * (1.0 - i * 0.07)
		Meshes.box(sbm, Vector3(0, 0, 0.1), Vector3(tw, 0.035, 0.22), ribbon.lightened(0.05 * (i % 2)), Vector3.ZERO, false, 0.0)
		_mi(seg, sbm.build(Mats.world))
		scarf.append(seg)
		prev = seg
	apply_pose_immediate()


func apply_pose_immediate() -> void:
	_compute_pose(0.0)
	for i in J_COUNT:
		_cur[i] = _tgt[i]
	_apply()


# ───────────────────────── المنطق ─────────────────────────
func reset_run() -> void:
	lane = 0
	x = 0.0
	y = 0.0
	vy = 0.0
	on_ground = true
	slide_t = 0.0
	stumble_t = 0.0
	invuln_t = 0.0
	dead = false
	running = false
	_buf_action = -1
	_fastfall = false
	_stumble_el = 0.0
	position = Vector3.ZERO
	if vis:
		vis.rotation = Vector3.ZERO
		visible = true
	if shield_fx:
		shield_fx.visible = false
	apply_pose_immediate()


func is_sliding() -> bool:
	return slide_t > 0.0 and on_ground


func body_height() -> float:
	return Cfg.SLIDE_H if is_sliding() else Cfg.PLAYER_H


func move_left() -> void:
	if dead:
		return
	if lane > -1:
		prev_lane = lane
		lane_change_age = 0.0
		lane -= 1
		lane_changed.emit(-1)
	else:
		_bump(-1)


func move_right() -> void:
	if dead:
		return
	if lane < 1:
		prev_lane = lane
		lane_change_age = 0.0
		lane += 1
		lane_changed.emit(1)
	else:
		_bump(1)


func _bump(dir: int) -> void:
	# اصطدام بحافة الطريق: اهتزاز بصري بسيط
	_flash_t = 0.0
	vis.rotation.z = -dir * 0.3


func jump() -> void:
	if dead:
		return
	if on_ground:
		_do_jump()
	else:
		_buf_action = 0
		_buf_t = BUFFER_TIME


func _do_jump() -> void:
	on_ground = false
	slide_t = 0.0
	vy = JUMP_V
	_fastfall = false
	jumped.emit()


func slide() -> void:
	if dead:
		return
	if on_ground:
		_do_slide()
	else:
		vy = FASTFALL_V
		_fastfall = true
		_buf_action = 1
		_buf_t = 0.5


func _do_slide() -> void:
	slide_t = SLIDE_TIME
	slid.emit()


func hit() -> void:
	stumble_t = 0.75
	_stumble_el = 0.0
	invuln_t = 1.9
	slide_t = 0.0


func die() -> void:
	dead = true
	slide_t = 0.0
	stumble_t = 0.0


func step(dt: float, spd: float) -> void:
	speed_vis = spd
	_t += dt
	lane_change_age += dt
	# مسار
	var tx := lane * Cfg.LANE_W
	var k := 1.0 - exp(-dt * 21.0)
	var prev_x := x
	x = lerpf(x, tx, k)
	if absf(x - tx) < 0.004:
		x = tx
	var vx := (x - prev_x) / maxf(dt, 0.0001)
	# عمودي
	if not on_ground:
		vy -= GRAVITY * dt
		y += vy * dt
		if y <= 0.0:
			var hard := vy < -18.0
			y = 0.0
			vy = 0.0
			on_ground = true
			landed.emit(hard)
			if _buf_action == 0 and _buf_t > 0.0:
				_do_jump()
				_buf_action = -1
			elif _buf_action == 1 and _buf_t > 0.0:
				_do_slide()
				_buf_action = -1
			_fastfall = false
	if slide_t > 0.0:
		slide_t -= dt
	if stumble_t > 0.0:
		stumble_t -= dt
		_stumble_el += dt
	if invuln_t > 0.0:
		invuln_t -= dt
	if _buf_t > 0.0:
		_buf_t -= dt
		if _buf_t <= 0.0:
			_buf_action = -1
	position = Vector3(x, y, 0.0)
	# وضعية
	if dead:
		pose = Pose.DEAD
	elif stumble_t > 0.0:
		pose = Pose.STUMBLE
	elif not on_ground:
		pose = Pose.JUMP if vy > 0.0 else Pose.FALL
	elif slide_t > 0.0:
		pose = Pose.SLIDE
	else:
		pose = Pose.RUN if running else Pose.IDLE
	# طور الجري
	if pose == Pose.RUN or pose == Pose.STUMBLE:
		var f := 1.45 + (spd - 12.0) * 0.045
		_phase += TAU * f * dt
	_compute_pose(vx)
	var stiff := 30.0 if pose == Pose.RUN else 16.0
	var kk := 1.0 - exp(-dt * stiff)
	for i in J_COUNT:
		_cur[i] = lerpf(_cur[i], _tgt[i], kk)
	_apply()
	_update_vis(dt, vx)


func idle_step(dt: float) -> void:
	# وضع القائمة: وقفة تنفّس
	_t += dt
	pose = Pose.IDLE
	_compute_pose(0.0)
	var kk := 1.0 - exp(-dt * 10.0)
	for i in J_COUNT:
		_cur[i] = lerpf(_cur[i], _tgt[i], kk)
	_apply()
	_update_vis(dt, 0.0)


func _compute_pose(vx: float) -> void:
	var t := _tgt
	for i in J_COUNT:
		t[i] = 0.0
	t[J_HIP_Y] = 0.0
	match pose:
		Pose.RUN, Pose.STUMBLE:
			var p := _phase
			var s := sin(p)
			var c := cos(p)
			t[J_THIGH_L] = s * 1.0
			t[J_THIGH_R] = -s * 1.0
			t[J_SHIN_L] = -(0.25 + 1.25 * maxf(0.0, c))
			t[J_SHIN_R] = -(0.25 + 1.25 * maxf(0.0, -c))
			t[J_ARM_L_X] = -s * 0.95
			t[J_ARM_R_X] = s * 0.95
			t[J_FORE_L] = 1.15 + 0.35 * s
			t[J_FORE_R] = 1.15 - 0.35 * s
			t[J_ARM_L_Z] = -0.12
			t[J_ARM_R_Z] = 0.12
			t[J_HIP_X] = -0.2
			t[J_HIP_YAW] = s * 0.14
			t[J_HEAD_X] = 0.14
			t[J_HIP_Y] = absf(s) * 0.075 - 0.05
			if pose == Pose.STUMBLE:
				var u := clampf(_stumble_el / 0.75, 0.0, 1.0)
				var bump := sin(u * PI)
				t[J_HIP_X] = -0.2 - 0.75 * bump
				t[J_ARM_L_X] = -s * 0.5 + 1.5 * bump
				t[J_ARM_R_X] = s * 0.5 + 1.5 * bump
				t[J_ARM_L_Z] = -0.7 * bump
				t[J_ARM_R_Z] = 0.7 * bump
				t[J_HEAD_X] = 0.14 + 0.5 * bump
				t[J_HIP_Y] = -0.1 * bump - 0.04
		Pose.JUMP:
			t[J_THIGH_L] = 1.15
			t[J_SHIN_L] = -0.55
			t[J_THIGH_R] = -0.45
			t[J_SHIN_R] = -1.35
			t[J_ARM_L_X] = -1.0
			t[J_ARM_R_X] = 2.3
			t[J_FORE_L] = 0.5
			t[J_FORE_R] = 0.4
			t[J_ARM_L_Z] = -0.35
			t[J_ARM_R_Z] = 0.35
			t[J_HIP_X] = -0.12
			t[J_HEAD_X] = 0.1
			t[J_HIP_Y] = 0.0
		Pose.FALL:
			t[J_THIGH_L] = 0.6
			t[J_SHIN_L] = -0.3
			t[J_THIGH_R] = 0.2
			t[J_SHIN_R] = -0.5
			t[J_ARM_L_X] = 0.4
			t[J_ARM_R_X] = 0.4
			t[J_ARM_L_Z] = -1.1
			t[J_ARM_R_Z] = 1.1
			t[J_FORE_L] = 0.3
			t[J_FORE_R] = 0.3
			t[J_HIP_X] = 0.0
			t[J_HEAD_X] = 0.0
		Pose.SLIDE:
			t[J_HIP_X] = 1.22
			t[J_HIP_Y] = -0.46
			t[J_HIP_Z] = 0.28
			t[J_THIGH_L] = -0.1
			t[J_THIGH_R] = 0.05
			t[J_SHIN_L] = -0.1
			t[J_SHIN_R] = -0.2
			t[J_ARM_L_X] = -1.1
			t[J_ARM_R_X] = -1.0
			t[J_ARM_L_Z] = -0.5
			t[J_ARM_R_Z] = 0.5
			t[J_FORE_L] = 0.2
			t[J_FORE_R] = 0.2
			t[J_HEAD_X] = -1.0
		Pose.DEAD:
			t[J_HIP_X] = -1.5
			t[J_HIP_Y] = -0.62
			t[J_HIP_Z] = -0.2
			t[J_THIGH_L] = 0.3
			t[J_THIGH_R] = -0.1
			t[J_SHIN_L] = -0.4
			t[J_SHIN_R] = -0.2
			t[J_ARM_L_X] = 2.6
			t[J_ARM_R_X] = 2.3
			t[J_ARM_L_Z] = -0.4
			t[J_ARM_R_Z] = 0.4
			t[J_HEAD_X] = 0.6
		_:
			# وقفة (قائمة)
			var br := sin(_t * 2.0) * 0.03
			t[J_ARM_L_X] = br
			t[J_ARM_R_X] = -br
			t[J_ARM_L_Z] = -0.1
			t[J_ARM_R_Z] = 0.1
			t[J_FORE_L] = 0.15
			t[J_FORE_R] = 0.15
			t[J_HIP_Y] = br * 0.5
			t[J_HEAD_X] = -0.02
			t[J_THIGH_L] = -0.04
			t[J_THIGH_R] = 0.04
	# ميلان جانبي أثناء تبديل المسار
	t[J_HIP_ROLL] = clampf(-vx * 0.02, -0.4, 0.4)


func _apply() -> void:
	if hips == null:
		return
	var c := _cur
	hips.rotation = Vector3(c[J_HIP_X], c[J_HIP_YAW], c[J_HIP_ROLL])
	hips.position = Vector3(0, _hip_base_y + c[J_HIP_Y], c[J_HIP_Z])
	head.rotation.x = c[J_HEAD_X]
	arm_l.rotation = Vector3(c[J_ARM_L_X], 0, c[J_ARM_L_Z])
	arm_r.rotation = Vector3(c[J_ARM_R_X], 0, c[J_ARM_R_Z])
	fore_l.rotation.x = c[J_FORE_L]
	fore_r.rotation.x = c[J_FORE_R]
	thigh_l.rotation.x = c[J_THIGH_L]
	thigh_r.rotation.x = c[J_THIGH_R]
	shin_l.rotation.x = c[J_SHIN_L]
	shin_r.rotation.x = c[J_SHIN_R]


func _update_vis(dt: float, vx: float) -> void:
	# وشاح يرفرف
	var sf := clampf(speed_vis / 24.0, 0.2, 1.3)
	var wave := _t * 10.0
	for i in scarf.size():
		var s := scarf[i]
		var base := -0.16 if pose != Pose.SLIDE else 0.1
		s.rotation.x = base + sin(wave - i * 0.85) * 0.2 * sf
		s.rotation.y = clampf(-vx * 0.012, -0.3, 0.3) + sin(wave * 0.7 - i * 0.6) * 0.12 * sf
	# ميل/التفاف بصري
	if vis:
		vis.rotation.z = lerpf(vis.rotation.z, 0.0, 1.0 - exp(-dt * 12.0))
		vis.rotation.y = lerpf(vis.rotation.y, clampf(-vx * 0.018, -0.3, 0.3), 1.0 - exp(-dt * 14.0))
	# وميض أثناء الحصانة
	if invuln_t > 0.0 and not dead:
		_flash_t += dt
		vis.visible = int(_flash_t * 14.0) % 2 == 0
	else:
		vis.visible = true
	# ظل
	var sc := clampf(1.0 - y * 0.18, 0.4, 1.0)
	blob.position = Vector3(0, 0.04 - y, 0)
	blob.scale = Vector3(sc, sc, sc)
