class_name Mats
extends RefCounted
## مواد مشتركة (كل العالم يستخدم عدداً قليلاً جداً من المواد = دفعات رسم أقل).
## لا توجد صور مرجعية: كل شيء ألوان رؤوس (vertex colors) وتظليل بسيط.

const MIRAGE_TINT := Color(0.80, 0.72, 1.12)
const GHOST_MIN := 0.13

static var ready := false
static var world: StandardMaterial3D        # مضاء، ألوان رؤوس، يتلوّن في السراب
static var glow: StandardMaterial3D         # غير مضاء (نوافذ، فوانيس، رونات)
static var sun_body: StandardMaterial3D     # عوائق الشمس: صلبة في الواقع
static var sun_glow: StandardMaterial3D
static var mir_body: StandardMaterial3D     # عوائق السراب: صلبة في السراب
static var mir_glow: StandardMaterial3D
static var coin: StandardMaterial3D
static var shard: StandardMaterial3D
static var pickup: StandardMaterial3D
static var pickup_glow: StandardMaterial3D
static var sky: ShaderMaterial
static var far_layers: Array[StandardMaterial3D] = []
static var blob: StandardMaterial3D
static var particle: StandardMaterial3D
static var particle_add: StandardMaterial3D
static var storm_mat: StandardMaterial3D

const SKY_SHADER := """
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, fog_disabled;

uniform vec4 top_color : source_color = vec4(0.3, 0.5, 0.85, 1.0);
uniform vec4 horizon_color : source_color = vec4(1.0, 0.76, 0.5, 1.0);
uniform vec4 sun_color : source_color = vec4(1.0, 0.85, 0.55, 1.0);
uniform vec3 sun_dir = vec3(0.25, 0.28, -1.0);
uniform float star_amount = 0.0;
uniform float shift = 0.0;

varying vec3 dir;

void vertex() {
	dir = normalize(VERTEX);
}

void fragment() {
	vec3 d = normalize(dir);
	float h = clamp(d.y, 0.0, 1.0);
	vec3 c = mix(horizon_color.rgb, top_color.rgb, pow(h, 0.5));
	float s = max(dot(d, normalize(sun_dir)), 0.0);
	c += sun_color.rgb * (pow(s, 220.0) * 2.0 + pow(s, 14.0) * 0.35 + pow(s, 3.0) * 0.08);
	// نجوم
	vec3 q = floor(d * 140.0);
	float n = fract(sin(dot(q, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	float star = step(0.9962, n) * smoothstep(0.08, 0.4, d.y);
	c += vec3(star) * star_amount;
	// شفق السراب: شرائط لونية متموجة في الأعلى
	float band = sin(d.x * 9.0 + TIME * 0.35) * 0.5 + 0.5;
	band *= smoothstep(0.1, 0.5, d.y) * (1.0 - smoothstep(0.55, 0.95, d.y));
	c += vec3(0.25, 0.9, 0.85) * band * shift * 0.22;
	ALBEDO = c;
}
"""


static func _base(unshaded: bool, vcol := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = vcol
	m.roughness = 1.0
	m.metallic = 0.0
	m.metallic_specular = 0.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	else:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
		m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	return m


static func _hash_alpha(m: StandardMaterial3D) -> void:
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_BACK


static func setup() -> void:
	if ready:
		return
	ready = true

	world = _base(false)
	glow = _base(true)

	sun_body = _base(false)
	_hash_alpha(sun_body)
	sun_body.emission_enabled = true
	sun_body.emission = Color(1.0, 0.55, 0.15)
	sun_body.emission_energy_multiplier = 0.22
	sun_glow = _base(true)
	_hash_alpha(sun_glow)

	mir_body = _base(false)
	_hash_alpha(mir_body)
	mir_body.emission_enabled = true
	mir_body.emission = Color(0.45, 0.35, 1.0)
	mir_body.emission_energy_multiplier = 0.55
	mir_glow = _base(true)
	_hash_alpha(mir_glow)

	coin = _base(false)
	coin.emission_enabled = true
	coin.emission = Color(1.0, 0.7, 0.15)
	coin.emission_energy_multiplier = 0.5

	shard = _base(true)
	_hash_alpha(shard)

	pickup = _base(false)
	pickup.emission_enabled = true
	pickup.emission = Color(1.0, 1.0, 1.0)
	pickup.emission_energy_multiplier = 0.25
	pickup_glow = _base(true)

	sky = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SKY_SHADER
	sky.shader = sh
	sky.render_priority = -100

	for i in 3:
		var f := StandardMaterial3D.new()
		f.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		f.disable_fog = true
		f.cull_mode = BaseMaterial3D.CULL_DISABLED
		f.render_priority = -90 + i
		far_layers.append(f)

	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.55))
	grad.set_color(1, Color(0, 0, 0, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64
	gt.height = 64
	blob = StandardMaterial3D.new()
	blob.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blob.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blob.albedo_texture = gt
	blob.cull_mode = BaseMaterial3D.CULL_DISABLED
	blob.no_depth_test = false

	particle = StandardMaterial3D.new()
	particle.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	particle.vertex_color_use_as_albedo = true
	particle.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	particle.cull_mode = BaseMaterial3D.CULL_DISABLED

	var pg := Gradient.new()
	pg.set_color(0, Color(1, 1, 1, 1))
	pg.set_color(1, Color(1, 1, 1, 0))
	var pt := GradientTexture2D.new()
	pt.gradient = pg
	pt.fill = GradientTexture2D.FILL_RADIAL
	pt.fill_from = Vector2(0.5, 0.5)
	pt.fill_to = Vector2(1.0, 0.5)
	pt.width = 32
	pt.height = 32
	particle_add = StandardMaterial3D.new()
	particle_add.albedo_texture = pt
	particle_add.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	particle_add.vertex_color_use_as_albedo = true
	particle_add.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	particle_add.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	particle_add.cull_mode = BaseMaterial3D.CULL_DISABLED

	storm_mat = StandardMaterial3D.new()
	storm_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	storm_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	storm_mat.vertex_color_use_as_albedo = true
	storm_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	storm_mat.disable_fog = true

	set_dimension(0.0)


## t: 0 = الواقع، 1 = السراب. يُستدعى كل إطار أثناء الانتقال فقط.
static func set_dimension(t: float) -> void:
	world.albedo_color = Color(1, 1, 1, 1).lerp(MIRAGE_TINT, t)
	var real_a := lerpf(1.0, GHOST_MIN, t)
	var mir_a := lerpf(GHOST_MIN, 1.0, t)
	sun_body.albedo_color = Color(1, 1, 1, real_a)
	sun_glow.albedo_color = Color(1, 1, 1, real_a)
	mir_body.albedo_color = Color(1, 1, 1, mir_a)
	mir_glow.albedo_color = Color(1, 1, 1, mir_a)
	shard.albedo_color = Color(1, 1, 1, mir_a)
	glow.albedo_color = Color(1, 1, 1).lerp(Color(0.9, 0.8, 1.2), t)
