class_name RunController
extends Node3D
## قلب اللعبة: الإدخال، السرعة، التصادم، السراب، التعزيزات، المطارد، الكاميرا، النتيجة.

signal run_started
signal run_ended(summary: Dictionary)
signal toast(text: String, color: Color)
signal power_changed
signal hit_feedback(strength: float)

enum State { MENU, RUN, DEAD }

const SWIPE_PX := 46.0
const MIRAGE_MIN := 18.0
const MIRAGE_DRAIN := 15.0
const MIRAGE_REGEN := 6.5

var state := State.MENU
var world: World
var runner: Runner
var fx: Fx
var cam: Camera3D

# إحصائيات الجولة
var distance := 0.0
var speed := 0.0
var speed_ramp := 0.0
var run_coins := 0
var run_shards := 0
var run_grazes := 0
var run_ghost_passes := 0
var run_powerups := 0
var run_shifts := 0
var score_f := 0.0
var revived := false
var run_time := 0.0

# السراب
var energy := 100.0
var energy_cap := 100.0
var mirage_target := false
var mirage_t := 0.0
var exit_pending := false
var orb_t := 0.0

# تعزيزات: الوقت المتبقي
var magnet_t := 0.0
var shield_n := 0
var shield_t := 0.0
var boost_t := 0.0
var double_t := 0.0
var post_boost_t := 0.0

# المطارد
var trouble := 0.0

# كاميرا
var menu_blend := 1.0
var _shake := 0.0
var _shake_t := 0.0
var _menu_yaw := 0.0
var cam_menu_pos := Vector3(2.3, 1.7, -5.4)
var preview_mode := false
var _touch_start := {}
var _touch_done := {}
var _last_tap := -10.0
var _dust_t := 0.0
var _toast_flags := {}
var _end_timer := 0.0
var _time := 0.0
var _kb_dir_cd := 0.0


func _ready() -> void:
	world = World.new()
	add_child(world)
	runner = Runner.new()
	add_child(runner)
	fx = Fx.new()
	add_child(fx)
	cam = Camera3D.new()
	cam.fov = 62.0
	cam.near = 0.15
	cam.far = 380.0
	cam.current = true
	add_child(cam)
	runner.jumped.connect(_on_jump)
	runner.landed.connect(_on_land)
	runner.slid.connect(_on_slide)
	runner.lane_changed.connect(_on_lane)
	rebuild_character()
	world.reset(randi(), Game.settings.get("adaptive", true))
	enter_menu()


func rebuild_character() -> void:
	runner.build(Game.current_char(), Game.current_colorway())


func enter_menu() -> void:
	state = State.MENU
	runner.reset_run()
	runner.running = false
	world.reset(randi(), Game.settings.get("adaptive", true))
	distance = 0.0
	menu_blend = 1.0
	mirage_t = 0.0
	mirage_target = false
	Mats.set_dimension(0.0)
	trouble = 0.0
	world.chaser.visible = false
	Sfx.set_storm(0.0)
	_update_camera(0.016)


# ───────────────────────── بدء الجولة ─────────────────────────
func start_run() -> void:
	Game.begin_run()
	world.reset(randi(), Game.settings.get("adaptive", true))
	runner.reset_run()
	runner.running = true
	state = State.RUN
	distance = 0.0
	speed = 0.0
	speed_ramp = 0.0
	run_coins = 0
	run_shards = 0
	run_grazes = 0
	run_ghost_passes = 0
	run_powerups = 0
	run_shifts = 0
	score_f = 0.0
	revived = false
	run_time = 0.0
	energy_cap = Game.upgrade_value("shift_cap")
	energy = energy_cap
	mirage_target = false
	mirage_t = 0.0
	exit_pending = false
	orb_t = 0.0
	magnet_t = 0.0
	shield_n = 0
	shield_t = 0.0
	boost_t = 0.0
	double_t = 0.0
	post_boost_t = 0.0
	trouble = 0.0
	_toast_flags.clear()
	_last_biome_idx = 0
	Mats.set_dimension(0.0)
	Sfx.start_music()
	Sfx.set_music_level(-8.0)
	run_started.emit()
	power_changed.emit()


func revive_cost() -> int:
	return 400 + int(distance / 10.0)


func revive() -> bool:
	if revived or state != State.DEAD:
		return false
	if not Game.spend(revive_cost()):
		return false
	revived = true
	state = State.RUN
	_end_timer = 0.0
	runner.dead = false
	runner.stumble_t = 0.0
	runner.invuln_t = 3.0
	runner.running = true
	trouble = 0.0
	speed_ramp = 0.3
	shield_n = 1
	shield_t = 4.0
	for s in world.segs:
		for o in s.obs:
			var wz := s.position.z + o.z
			if wz > -6.0 and wz < 40.0:
				o.node.visible = false
				o.hit = true
				o.passed = true
	power_changed.emit()
	Sfx.play("powerup")
	return true


# ───────────────────────── الإدخال ─────────────────────────
func _unhandled_input(e: InputEvent) -> void:
	if state == State.MENU and not preview_mode:
		return
	if e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_LEFT, KEY_A:
				cmd_left()
			KEY_RIGHT, KEY_D:
				cmd_right()
			KEY_UP, KEY_W:
				cmd_jump()
			KEY_DOWN, KEY_S:
				cmd_slide()
			KEY_SPACE, KEY_SHIFT:
				toggle_mirage()
	elif e is InputEventScreenTouch:
		if e.pressed:
			_touch_start[e.index] = e.position
			_touch_done[e.index] = false
			var now := Time.get_ticks_msec() / 1000.0
			if now - _last_tap < 0.28 and _touch_start.size() == 1:
				toggle_mirage()
				_last_tap = -10.0
				_touch_done[e.index] = true
			else:
				_last_tap = now
			if _touch_start.size() >= 2:
				toggle_mirage()
				_touch_done[e.index] = true
		else:
			_touch_start.erase(e.index)
			_touch_done.erase(e.index)
	elif e is InputEventScreenDrag:
		if not _touch_start.has(e.index) or _touch_done.get(e.index, true):
			return
		var d: Vector2 = e.position - _touch_start[e.index]
		if d.length() >= SWIPE_PX:
			_touch_done[e.index] = true
			_last_tap = -10.0
			if absf(d.x) > absf(d.y):
				if d.x > 0:
					cmd_right()
				else:
					cmd_left()
			else:
				if d.y < 0:
					cmd_jump()
				else:
					cmd_slide()


func cmd_left() -> void:
	if state == State.RUN:
		runner.move_left()


func cmd_right() -> void:
	if state == State.RUN:
		runner.move_right()


func cmd_jump() -> void:
	if state == State.RUN:
		runner.jump()


func cmd_slide() -> void:
	if state == State.RUN:
		runner.slide()


func toggle_mirage() -> void:
	if state != State.RUN:
		return
	if mirage_target:
		mirage_target = false
		exit_pending = true
		Sfx.play("shift_out")
		run_shifts += 1
		Game.mission_add("shifts")
		fx.burst(runner.position + Vector3(0, 1, 0), 18, 4.0, 0.5, 0.35, Color(1.0, 0.8, 0.5, 0.9))
	else:
		if energy < MIRAGE_MIN and orb_t <= 0.0:
			toast.emit("طاقة الأبزو غير كافية", Color(1.0, 0.5, 0.4))
			Sfx.play("click", 0.7)
			return
		mirage_target = true
		exit_pending = false
		Sfx.play("shift_in")
		run_shifts += 1
		Game.mission_add("shifts")
		fx.burst(runner.position + Vector3(0, 1, 0), 22, 5.0, 0.6, 0.4, Color(0.5, 1.0, 1.0, 0.9))
		_shake = maxf(_shake, 0.1)
		_shake_t = 0.2
	power_changed.emit()


# ───────────────────────── أحداث الحركة ─────────────────────────
func _on_jump() -> void:
	Sfx.play("jump", randf_range(0.97, 1.05))
	Game.mission_add("jumps")
	fx.burst(runner.position + Vector3(0, 0.1, 0), 6, 2.5, 0.35, 0.3, _dust_color())


func _on_land(hard: bool) -> void:
	Sfx.play("land", 1.0, -6.0 if not hard else 0.0)
	fx.burst(runner.position + Vector3(0, 0.1, 0), 8 if hard else 4, 3.0, 0.4, 0.35, _dust_color())
	if hard:
		_shake = maxf(_shake, 0.08)
		_shake_t = 0.15


func _on_slide() -> void:
	Sfx.play("slide")
	Game.mission_add("slides")


func _on_lane(dir: int) -> void:
	Sfx.play("lane", 1.0 + dir * 0.06, -8.0)


func _dust_color() -> Color:
	if mirage_t > 0.5:
		return Color(0.5, 0.9, 1.0, 0.7)
	var P := Palette.biome(world.biome_now)
	return (P["dune"] as Color).lightened(0.2)


# ───────────────────────── الحلقة الرئيسية ─────────────────────────
func _process(dt: float) -> void:
	dt = minf(dt, 0.05)
	_time += dt
	match state:
		State.MENU:
			_menu_step(dt)
		State.RUN:
			_run_step(dt)
		State.DEAD:
			_dead_step(dt)
	fx.update(dt, speed)
	_update_camera(dt)
	world.follow_camera(cam.global_position)


func _menu_step(dt: float) -> void:
	runner.idle_step(dt)
	menu_blend = move_toward(menu_blend, 1.0, dt * 3.0)
	world.update_environment(0.0, 0.0)
	for s in world.segs:
		s.spin(_time)
	_menu_yaw += dt * 0.0
	runner.vis.rotation.y = lerp_angle(runner.vis.rotation.y, 0.0, dt * 4.0) + sin(_time * 0.7) * 0.004


func _run_step(dt: float) -> void:
	run_time += dt
	menu_blend = move_toward(menu_blend, 0.0, dt * 2.2)
	speed_ramp = move_toward(speed_ramp, 1.0, dt * 1.2)
	var base := world.gen.speed_at(distance)
	var boost_mul := 1.0
	if boost_t > 0.0:
		boost_mul = 1.7
	speed = base * boost_mul * (0.35 + 0.65 * speed_ramp)
	var dz := speed * dt
	distance += dz
	world.advance(dz, distance)
	_update_powers(dt)
	_update_mirage(dt)
	runner.step(dt, speed)
	_collisions(dt)
	_update_trouble(dt)
	_update_score()
	_trail(dt)
	_hints()
	world.update_environment(distance, mirage_t)
	_biome_toast()
	for s in world.segs:
		if s.position.z > -90.0 and s.position.z - Cfg.SEG_LEN < 20.0:
			s.spin(_time)
	# تكيّف الصعوبة: تحسّن عند الركض بلا أخطاء
	world.gen.skill = clampf(world.gen.skill + dt * 0.004 * (1.0 if trouble < 0.05 else -3.0), 0.0, 1.0)


var _last_biome_idx := -1


func _biome_toast() -> void:
	var idx := int(distance / Palette.BIOME_LEN)
	if idx != _last_biome_idx:
		_last_biome_idx = idx
		if idx > 0:
			toast.emit(Palette.biome(idx)["name"], Color(1.0, 0.9, 0.6))


func _dead_step(dt: float) -> void:
	speed = move_toward(speed, 0.0, dt * 28.0)
	world.advance(speed * dt, distance)
	runner.step(dt, 0.0)
	_end_timer += dt
	trouble = maxf(trouble, 1.0)
	world.update_environment(distance, mirage_t)
	menu_blend = 0.0
	if _end_timer > 1.1:
		state = State.MENU
		_finish()


func _update_powers(dt: float) -> void:
	if magnet_t > 0.0:
		magnet_t -= dt
	if shield_t > 0.0:
		shield_t -= dt
		if shield_t <= 0.0:
			shield_n = 0
			power_changed.emit()
	if boost_t > 0.0:
		boost_t -= dt
		if boost_t <= 0.0:
			post_boost_t = 1.3
			runner.invuln_t = maxf(runner.invuln_t, 1.3)
			power_changed.emit()
	if double_t > 0.0:
		double_t -= dt
	if orb_t > 0.0:
		orb_t -= dt
		energy = minf(energy_cap, energy + dt * 30.0)
	runner.shield_fx.visible = shield_n > 0
	if shield_n > 0:
		runner.shield_fx.rotation.y += dt * 2.0
		runner.shield_fx.position.y = 0.95 + (0.0 if runner.is_sliding() else 0.0)
	if boost_t > 0.0:
		runner.running = true


func _update_mirage(dt: float) -> void:
	# تحقق من إمكانية الخروج (لا نخرج داخل عائق شمس صلب)
	if exit_pending and not mirage_target:
		if not _overlapping_sun():
			exit_pending = false
	var in_target := mirage_target or exit_pending
	if mirage_target and orb_t <= 0.0:
		energy -= MIRAGE_DRAIN * dt
		if energy <= 0.0:
			energy = 0.0
			mirage_target = false
			exit_pending = true
			Sfx.play("shift_out")
			toast.emit("نفدت طاقة الأبزو", Color(1.0, 0.7, 0.4))
			power_changed.emit()
	elif not in_target:
		energy = minf(energy_cap, energy + MIRAGE_REGEN * Game.perk("shift_regen") * dt)
	var tgt := 1.0 if (mirage_target or exit_pending) else 0.0
	var old := mirage_t
	mirage_t = move_toward(mirage_t, tgt, dt * 3.4)
	if absf(mirage_t - old) > 0.0001:
		Mats.set_dimension(smoothstep(0.0, 1.0, mirage_t))
	Sfx.set_music_level(-8.0 - 3.0 * mirage_t)


func in_mirage() -> bool:
	return mirage_t >= 0.5


func _overlapping_sun() -> bool:
	for s in world.segs:
		if s.position.z < -6.0 or s.position.z - Cfg.SEG_LEN > 6.0:
			continue
		for o in s.obs:
			if o.family != Cfg.Family.SUN or o.kind == Cfg.Kind.LOW and false:
				continue
			var wz := s.position.z + o.z
			if absf(wz) < o.half_d + 0.7 and absf(runner.x - o.cx) < o.half_w + 0.5:
				return true
	return false


func _is_solid(o: Segment.Obs) -> bool:
	if boost_t > 0.0:
		return false
	match o.family:
		Cfg.Family.STONE:
			return true
		Cfg.Family.SUN:
			return not in_mirage()
		_:
			return in_mirage()


func _collisions(dt: float) -> void:
	var px := runner.x
	var py := runner.y
	var ph := runner.body_height()
	var mag := 0.0
	if magnet_t > 0.0:
		mag = 5.0 * Game.perk("magnet_range")
	for s in world.segs:
		var top := s.position.z
		if top < -50.0 or top - Cfg.SEG_LEN > 18.0:
			continue
		# المتحرّكون
		for o in s.obs:
			if o.kind == Cfg.Kind.MOVER:
				var wzm := top + o.z
				if not o.active and wzm > -58.0:
					o.active = true
				if o.active and absf(o.cx) < Cfg.ROAD_HALF + 3.5 + 1.5:
					o.cx += o.vx * dt
					o.node.position.x = o.cx
		# العملات والتعزيزات
		if top > -4.0 and top - Cfg.SEG_LEN < 4.0 or mag > 0.0:
			s.collect(px, py, ph, mag, in_mirage(), dt)
			_apply_collected(s)
		for o in s.obs:
			if o.hit or not o.node.visible:
				continue
			var wz := top + o.z
			var dz := absf(wz)
			var reach_z: float = o.half_d + Cfg.PLAYER_HALF_D
			if wz > reach_z + 0.4 and not o.passed:
				o.passed = true
				if o.ghosted:
					run_ghost_passes += 1
					Game.mission_add("ghost_pass")
			if dz > reach_z + 0.05:
				continue
			var gap := absf(px - o.cx) - (o.half_w + Cfg.PLAYER_HALF_W * 0.85)
			var solid := _is_solid(o)
			if not solid:
				if gap < 0.0 and (o.family == Cfg.Family.SUN or o.family == Cfg.Family.MIR):
					o.ghosted = true
				continue
			if gap < 0.0:
				var collide := false
				match o.kind:
					Cfg.Kind.LOW:
						collide = py < Cfg.LOW_TOP - 0.12
					Cfg.Kind.HIGH:
						collide = (py + ph) > Cfg.HIGH_BOTTOM and py < Cfg.HIGH_TOP
					Cfg.Kind.MOVER:
						collide = py < Cfg.MOVER_TOP - 0.15
					_:
						collide = py < Cfg.FULL_TOP
				if collide:
					o.hit = true
					_on_hit(o)
				elif o.kind == Cfg.Kind.LOW or o.kind == Cfg.Kind.HIGH or o.kind == Cfg.Kind.MOVER:
					pass
			elif not o.graze and o.kind != Cfg.Kind.WALL and (gap < 0.3 or (runner.lane_change_age < 0.5 and absf(o.cx - runner.prev_lane * Cfg.LANE_W) < 0.6 and o.kind != Cfg.Kind.MOVER)):
				if runner.invuln_t <= 0.0 and runner.stumble_t <= 0.0:
					o.graze = true
					_on_graze(o)


func _apply_collected(s: Segment) -> void:
	if s.got_coins > 0:
		var n := s.got_coins
		s.got_coins = 0
		run_coins += n
		Game.add_coins(n)
		energy = minf(energy_cap, energy + 1.2 * n)
		Game.mission_set_run("coins_run", run_coins)
		Sfx.play("coin", 1.0 + minf(run_coins % 8, 7) * 0.035, -4.0)
		fx.burst(s.last_collect_pos + Vector3(0, 0.2, 0), 3, 2.2, 0.35, 0.22, Color(1.0, 0.85, 0.3, 0.95), 0.0)
	if s.got_shards > 0:
		var m := s.got_shards
		s.got_shards = 0
		run_shards += m
		energy = minf(energy_cap, energy + 6.0 * m)
		trouble = maxf(0.0, trouble - 0.06 * m)
		Game.mission_set_run("shards_run", run_shards)
		Sfx.play("shard", 1.0 + minf(run_shards % 6, 5) * 0.05, -2.0)
		fx.burst(s.last_collect_pos + Vector3(0, 0.2, 0), 5, 2.8, 0.45, 0.28, Color(0.5, 1.0, 1.0, 0.95), 0.0)
	if not s.got_pickups.is_empty():
		for t in s.got_pickups:
			_take_pickup(t, s.last_collect_pos)
		s.got_pickups.clear()


func _take_pickup(t: int, p: Vector3) -> void:
	run_powerups += 1
	Game.mission_add("powerups")
	var mul := Game.perk("powerup_time")
	Sfx.play("powerup")
	fx.burst(p, 16, 4.0, 0.6, 0.3, Color(1.0, 1.0, 0.7, 0.95), 0.0)
	match t:
		Cfg.Power.MAGNET:
			magnet_t = Game.upgrade_value("magnet") * mul
			toast.emit("قرن الثور: يجذب الشواقل", Color(1.0, 0.5, 0.6))
		Cfg.Power.SHIELD:
			shield_n = 2
			shield_t = Game.upgrade_value("shield") * mul
			toast.emit("درع إنانا", Color(0.5, 0.8, 1.0))
		Cfg.Power.BOOST:
			boost_t = Game.upgrade_value("boost") * mul
			toast.emit("ريح إنليل!", Color(1.0, 0.8, 0.3))
			_shake = 0.15
			_shake_t = 0.3
		Cfg.Power.DOUBLE:
			double_t = Game.upgrade_value("double") * mul
			toast.emit("اللوح الذهبي: نقاط ×2", Color(1.0, 0.9, 0.4))
		_:
			orb_t = 6.0 * mul
			energy = energy_cap
			toast.emit("كرة الأبزو: أبزو مجاني", Color(0.7, 0.6, 1.0))
	power_changed.emit()


func _on_graze(o: Segment.Obs) -> void:
	run_grazes += 1
	Game.mission_add("grazes")
	trouble = maxf(0.0, trouble - 0.07)
	energy = minf(energy_cap, energy + 4.0)
	Sfx.play("graze")
	fx.burst(runner.position + Vector3(0, 1.0, 0), 6, 3.0, 0.3, 0.2, Color(1.0, 1.0, 1.0, 0.9), 0.0)
	toast.emit("عاش! نجوت بشعرة", Color(1.0, 0.95, 0.6))


func _on_hit(o: Segment.Obs) -> void:
	if runner.invuln_t > 0.0 or boost_t > 0.0:
		return
	if shield_n > 0:
		shield_n -= 1
		if shield_n <= 0:
			shield_t = 0.0
		runner.invuln_t = 1.0
		Sfx.play("hit", 1.4, -4.0)
		fx.burst(runner.position + Vector3(0, 1.0, 0), 20, 5.0, 0.5, 0.35, Color(0.5, 0.8, 1.0, 0.95), 0.0)
		_shake = 0.2
		_shake_t = 0.25
		o.node.visible = false
		power_changed.emit()
		return
	Sfx.play("hit")
	_shake = 0.35
	_shake_t = 0.4
	hit_feedback.emit(1.0)
	if Game.settings.get("haptics", true):
		Input.vibrate_handheld(60)
	if trouble >= 0.45:
		_die()
		return
	trouble += 0.58
	runner.hit()
	fx.burst(runner.position + Vector3(0, 1.0, 0), 14, 4.0, 0.5, 0.35, Color(1.0, 0.6, 0.3, 0.95))
	speed_ramp = 0.55


func _die() -> void:
	state = State.DEAD
	runner.die()
	runner.invuln_t = 0.0
	_end_timer = 0.0
	Sfx.play("gameover")
	Sfx.set_music_level(-24.0)
	Sfx.set_storm(0.0)
	fx.burst(runner.position + Vector3(0, 1.0, 0), 26, 6.0, 0.8, 0.4, Color(1.0, 0.7, 0.4, 0.95))
	mirage_target = false
	exit_pending = true


func _update_trouble(dt: float) -> void:
	if trouble > 0.0:
		trouble = maxf(0.0, trouble - 0.075 * dt)
	var ch := world.chaser
	if trouble > 0.02:
		ch.visible = true
		var k := clampf(trouble / 0.95, 0.0, 1.0)
		var z := lerpf(15.0, 5.6, k)
		ch.position = Vector3(lerpf(ch.position.x, runner.x, dt * 3.0), 0.0 + sin(_time * 5.0) * 0.15, z)
		ch.rotation.y = 0.0
		ch.scale = Vector3.ONE * lerpf(0.42, 0.52, k)
	else:
		ch.visible = false
	Sfx.set_storm(trouble)


func _update_score() -> void:
	var raw := distance + run_coins * 3.0 + run_shards * 18.0 + run_grazes * 12.0
	var mul := float(Game.score_multiplier())
	if double_t > 0.0:
		mul *= 2.0
	score_f = raw * mul
	Game.mission_set_run("dist_run", int(distance))


func score() -> int:
	return int(score_f)


func _trail(dt: float) -> void:
	_dust_t -= dt
	if _dust_t > 0.0 or not runner.on_ground or state != State.RUN:
		return
	_dust_t = 0.045
	var c := _dust_color()
	fx.emit(runner.position + Vector3(randf_range(-0.2, 0.2), 0.1, 0.3), Vector3(randf_range(-0.6, 0.6), randf_range(0.4, 1.2), 1.0), 0.45, 0.4, Color(c.r, c.g, c.b, 0.55), 0.0)
	if mirage_t > 0.5:
		fx.emit(runner.position + Vector3(randf_range(-0.3, 0.3), randf_range(0.2, 1.6), 0.1), Vector3(0, 0.6, 1.0), 0.6, 0.18, Color(0.5, 1.0, 1.0, 0.9), 0.0)


func _hints() -> void:
	if Game.settings.get("tutorial_done", false):
		return
	var steps := [
		[8.0, "اسحب يميناً ويساراً لتغيير المسار"],
		[70.0, "اسحب للأعلى للقفز"],
		[130.0, "اسحب للأسفل للانزلاق"],
		[260.0, "اضغط زر «أبزو»: عوائق الشمس تصبح أشباحاً!"],
		[420.0, "اجمع دموع الأبزو لتشحن طاقتك"],
	]
	for i in steps.size():
		if distance >= steps[i][0] and not _toast_flags.has(i):
			_toast_flags[i] = true
			toast.emit(steps[i][1], Color(1, 1, 1))
	if distance > 520.0:
		Game.settings["tutorial_done"] = true


func _finish() -> void:
	Game.finish_run(score(), distance, run_coins)
	var sm := {
		"score": score(), "distance": int(distance), "coins": run_coins,
		"shards": run_shards, "grazes": run_grazes, "ghost": run_ghost_passes,
		"best": Game.best_score, "new_best": score() >= Game.best_score and score() > 0,
		"missions": Game.run_completed.duplicate(true),
		"can_revive": not revived and Game.coins >= revive_cost(),
		"revive_cost": revive_cost(),
	}
	run_ended.emit(sm)


# ───────────────────────── الكاميرا ─────────────────────────
func _update_camera(dt: float) -> void:
	var x := runner.x
	var run_pos := Vector3(x * 0.6, 4.7 - (0.7 if runner.is_sliding() else 0.0) + runner.y * 0.25, 7.6)
	var run_look := Vector3(x * 0.85, 1.35 + runner.y * 0.3, -9.0)
	var menu_pos := runner.position + cam_menu_pos
	var menu_look := runner.position + Vector3(0, 1.75, 0)
	var pos := run_pos.lerp(menu_pos, smoothstep(0.0, 1.0, menu_blend))
	var look := run_look.lerp(menu_look, smoothstep(0.0, 1.0, menu_blend))
	if _shake_t > 0.0:
		_shake_t -= dt
		var a := _shake * clampf(_shake_t / 0.4, 0.0, 1.0)
		pos += Vector3(randf_range(-a, a), randf_range(-a, a), 0)
	else:
		_shake = 0.0
	cam.global_position = pos
	cam.look_at(look, Vector3.UP)
	var target_fov := 62.0 + clampf((speed - 13.0) * 0.4, 0.0, 7.0) + (7.0 if boost_t > 0.0 else 0.0) + mirage_t * 4.0
	target_fov = lerpf(target_fov, 44.0, smoothstep(0.0, 1.0, menu_blend))
	cam.fov = lerpf(cam.fov, target_fov, 1.0 - exp(-dt * 6.0))
