extends Node
## نقطة الدخول: ينشئ المتحكم والواجهة ويطبّق إعدادات الجودة.

var ctl: RunController
var ui: GameUI


func _ready() -> void:
	name = "Main"
	RenderingServer.set_default_clear_color(Color(0.07, 0.05, 0.16))
	ctl = RunController.new()
	add_child(ctl)
	ui = GameUI.new()
	add_child(ui)
	ui.bind(ctl)
	ui.play_pressed.connect(_on_play)
	apply_quality()
	get_tree().auto_accept_quit = false
	Game.mission_completed.connect(func(_m): pass)


func _on_play() -> void:
	ctl.start_run()


func apply_quality() -> void:
	var q: int = int(Game.settings.get("quality", 1))
	var vp := get_viewport()
	match q:
		0:
			vp.scaling_3d_scale = 0.7
			vp.msaa_3d = Viewport.MSAA_DISABLED
			ctl.world.env.fog_depth_end = 130.0
		1:
			vp.scaling_3d_scale = 0.88
			vp.msaa_3d = Viewport.MSAA_DISABLED
		_:
			vp.scaling_3d_scale = 1.0
			vp.msaa_3d = Viewport.MSAA_2X
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		Game.save_game()
		if what == NOTIFICATION_WM_CLOSE_REQUEST:
			get_tree().quit()
		elif ctl and ctl.state == RunController.State.RUN:
			ui._pause()
