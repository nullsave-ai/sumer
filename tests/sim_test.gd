extends Node
## محاكاة آلية: روبوت يلعب جولات كاملة. التشغيل:
## godot --headless --path . --fixed-fps 60 --script tests/sim_test.gd

var ctl: RunController
var frames := 0
var run_idx := 0
var results: Array = []
var max_frames := 60 * 150
var cd := 0
var main_node: Node


func _ready() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	main_node = packed.instantiate()
	get_tree().root.add_child.call_deferred(main_node)


func _process(_dt: float) -> void:
	if main_node == null or not main_node.is_inside_tree():
		return
	if ctl == null:
		if main_node.get("ctl") == null:
			return
		ctl = main_node.get("ctl")
		Engine.max_fps = 0
		ctl.start_run()
		return
	frames += 1
	cd -= 1
	if ctl.state == RunController.State.RUN:
		_bot()
	if ctl.state == RunController.State.MENU or frames > max_frames:
		results.append({"dist": int(ctl.distance), "score": ctl.score(), "coins": ctl.run_coins, "shards": ctl.run_shards, "grazes": ctl.run_grazes, "shifts": ctl.run_shifts, "ghost": ctl.run_ghost_passes, "t": snappedf(ctl.run_time, 0.1)})
		run_idx += 1
		frames = 0
		if run_idx >= 3:
			for r in results:
				print("RUN ", r)
			get_tree().quit()
			return
		ctl.start_run()


func _threat(lane: int, mir: bool) -> Array:
	# يعيد [مسافة أقرب عائق صلب، نوعه]
	var best := 999.0
	var kind := -1
	var x := lane * Cfg.LANE_W
	for s in ctl.world.segs:
		for o in s.obs:
			if not o.node.visible or o.hit:
				continue
			var wz: float = s.position.z + o.z
			if wz > 1.5 or wz < -45.0:
				continue
			var solid := true
			if o.family == Cfg.Family.SUN and mir:
				solid = false
			elif o.family == Cfg.Family.MIR and not mir:
				solid = false
			if not solid:
				continue
			if absf(x - o.cx) < o.half_w + 0.4:
				if -wz < best:
					best = -wz
					kind = o.kind
	return [best, kind]


func _bot() -> void:
	var mir := ctl.in_mirage()
	var lane := ctl.runner.lane
	var th := _threat(lane, mir)
	var dist: float = th[0]
	var kind: int = th[1]
	var horizon := 9.0 + ctl.speed * 0.45
	if dist > horizon:
		# إن كنا في السراب ولا حاجة له نعد
		if ctl.mirage_target and ctl.energy < 40.0 and cd <= 0:
			ctl.toggle_mirage()
			cd = 20
		return
	if kind == Cfg.Kind.LOW and dist < 4.5 + ctl.speed * 0.17:
		ctl.cmd_jump()
		return
	if kind == Cfg.Kind.HIGH and dist < 5.0 + ctl.speed * 0.17:
		ctl.cmd_slide()
		return
	if kind == Cfg.Kind.LOW or kind == Cfg.Kind.HIGH:
		return
	if cd > 0:
		return
	# حاول تغيير المسار
	var options := [lane - 1, lane + 1]
	options.shuffle()
	for l in options:
		if l < -1 or l > 1:
			continue
		var t2 := _threat(l, mir)
		if t2[0] > dist + 4.0 or t2[1] == Cfg.Kind.LOW or t2[1] == Cfg.Kind.HIGH:
			if l > lane:
				ctl.cmd_right()
			else:
				ctl.cmd_left()
			cd = 4
			return
	# بدّل البُعد
	var tm := _threat(lane, not mir)
	if tm[0] > dist + 3.0 and (mir or ctl.energy >= RunController.MIRAGE_MIN):
		ctl.toggle_mirage()
		cd = 15
