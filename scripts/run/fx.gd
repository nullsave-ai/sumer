class_name Fx
extends Node3D
## نظام جسيمات خفيف (MultiMesh واحد = دفعة رسم واحدة): غبار، شرارات، تحوّل السراب.

const N := 192

var mm: MultiMesh
var mmi: MultiMeshInstance3D
var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _life := PackedFloat32Array()
var _max := PackedFloat32Array()
var _size := PackedFloat32Array()
var _col := PackedColorArray()
var _grav := PackedFloat32Array()
var _next := 0
var _live := 0


func _ready() -> void:
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	var mat := Mats.particle_add.duplicate() as StandardMaterial3D
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	q.material = mat
	mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.instance_count = N
	mm.mesh = q
	mmi = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-30, -5, -80), Vector3(60, 40, 120))
	add_child(mmi)
	_pos.resize(N)
	_vel.resize(N)
	_life.resize(N)
	_max.resize(N)
	_size.resize(N)
	_col.resize(N)
	_grav.resize(N)
	var zero := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
	for i in N:
		_life[i] = 0.0
		mm.set_instance_transform(i, zero)
		mm.set_instance_color(i, Color(0, 0, 0, 0))


func emit(p: Vector3, v: Vector3, life: float, size: float, col: Color, grav := 0.0) -> void:
	var i := _next
	_next = (_next + 1) % N
	_pos[i] = p
	_vel[i] = v
	_life[i] = life
	_max[i] = life
	_size[i] = size
	_col[i] = col
	_grav[i] = grav


func burst(p: Vector3, count: int, speed: float, life: float, size: float, col: Color, grav := 2.0) -> void:
	for k in count:
		var d := Vector3(randf_range(-1, 1), randf_range(-0.2, 1.2), randf_range(-1, 1)).normalized()
		emit(p, d * speed * randf_range(0.4, 1.0), life * randf_range(0.6, 1.0), size * randf_range(0.6, 1.2), col, grav)


func update(dt: float, world_speed: float) -> void:
	var zero := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
	for i in N:
		var l := _life[i]
		if l <= 0.0:
			continue
		l -= dt
		_life[i] = l
		if l <= 0.0:
			mm.set_instance_transform(i, zero)
			continue
		_vel[i].y -= _grav[i] * dt
		_pos[i] += _vel[i] * dt
		_pos[i].z += world_speed * dt   # العالم يتحرك نحو الكاميرا
		var t := l / _max[i]
		var c := _col[i]
		c.a *= t
		var s := _size[i] * (0.4 + 0.6 * t)
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(s, s, s)), _pos[i]))
		mm.set_instance_color(i, c)
