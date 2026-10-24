extends Node
## يلتقط لقطات شاشة: godot --path . --rendering-method gl_compatibility --fixed-fps 30 res://tests/shot.tscn
var main_node: Node
var ctl: RunController
var f := 0
var shots := {20: "menu", 150: "run_a", 330: "run_b", 470: "mirage", 560: "marsh", 650: "city"}
func _ready() -> void:
	main_node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(main_node)
func _process(_d: float) -> void:
	if main_node == null or not main_node.is_inside_tree() or main_node.get("ctl") == null:
		return
	ctl = main_node.get("ctl")
	f += 1
	if f == 40:
		ctl.start_run()
	if f > 40 and ctl.state == RunController.State.RUN:
		ctl.runner.invuln_t = 999.0
		ctl.runner.vis.visible = true
		_bot()
	if f == 440:
		ctl.energy = 100.0
		ctl.toggle_mirage()
	if f == 500 or f == 600:
		ctl.distance = 1450.0 if f == 500 else 2900.0
		ctl.world.next_spawn_dist = ctl.distance + 40.0
		for sg in ctl.world.segs:
			ctl.world._fill(sg)
		ctl.mirage_target = false
		ctl.exit_pending = false
	if shots.has(f):
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png("/tmp/sumer_%s.png" % shots[f])
		print("saved ", shots[f], " dist=", int(ctl.distance))
	if f >= 720:
		get_tree().quit()
func _bot() -> void:
	if f % 40 == 0:
		ctl.cmd_jump()
