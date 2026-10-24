class_name GameUI
extends CanvasLayer
## كل الواجهات تُبنى بالكود: الشاشة الرئيسية، HUD، الشخصيات، الترقيات، المهام، الإعدادات، النتيجة.

signal play_pressed
signal resume_pressed
signal quit_to_menu
signal character_changed
signal revive_pressed

const VIGNETTE := """
shader_type canvas_item;
uniform float mirage = 0.0;
uniform float trouble = 0.0;
uniform float flash = 0.0;
void fragment() {
	vec2 uv = UV - 0.5;
	float d = length(uv * vec2(1.0, 1.25));
	float v = smoothstep(0.28, 0.78, d);
	vec3 c = mix(vec3(0.2, 0.9, 0.9), vec3(0.25, 0.0, 0.0), step(0.001, trouble) * 0.0);
	float a = v * (mirage * 0.5 + trouble * 0.7);
	vec3 col = mix(vec3(0.15, 0.85, 0.95) * mirage, vec3(0.6, 0.05, 0.05), clamp(trouble * 1.4, 0.0, 1.0));
	col = mix(col, vec3(1.0), flash);
	COLOR = vec4(col, a + flash * 0.35);
}
"""

const C_BG := Color(0.07, 0.05, 0.16, 0.92)
const C_PANEL := Color(0.14, 0.10, 0.28, 0.96)
const C_GOLD := Color(1.0, 0.78, 0.25)
const C_CYAN := Color(0.4, 0.95, 1.0)
const C_TEXT := Color(0.97, 0.94, 0.88)

var ctl: RunController
var theme_main: Theme
var font: FontFile
var font_b: FontFile

var root: Control
var hud: Control
var menu: Control
var sub: Control          # شاشات فرعية (شخصيات…)
var pause_panel: Control
var over: Control
var vignette: ColorRect
var vig_mat: ShaderMaterial

var lbl_score: Label
var lbl_coins: Label
var lbl_dist: Label
var lbl_mult: Label
var bar_energy: ProgressBar
var btn_mirage: Button
var power_box: HBoxContainer
var toast_lbl: Label
var _toast_t := 0.0
var menu_coins: Label
var menu_best: Label
var _flash := 0.0
var _power_lbls := {}


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = load("res://assets/fonts/DejaVuSans.ttf")
	font_b = load("res://assets/fonts/DejaVuSans-Bold.ttf")
	theme_main = Theme.new()
	theme_main.default_font = font
	theme_main.default_font_size = 40
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = theme_main
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	vignette = ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vig_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = VIGNETTE
	vig_mat.shader = sh
	vignette.material = vig_mat
	root.add_child(vignette)

	_build_hud()
	_build_menu()
	_build_pause()
	hud.visible = false
	Game.coins_changed.connect(_refresh_coins)


func bind(c: RunController) -> void:
	ctl = c
	ctl.toast.connect(show_toast)
	ctl.run_ended.connect(_on_run_ended)
	ctl.run_started.connect(_on_run_started)
	ctl.hit_feedback.connect(func(_s: float): _flash = 1.0)
	ctl.power_changed.connect(_refresh_powers)
	Game.mission_completed.connect(func(m: Dictionary): show_toast("مهمة مكتملة! +%d" % int(m["reward"]), C_GOLD))
	show_menu()


# ───────────────────────── أدوات ─────────────────────────
func _style(col: Color, radius := 28, border := Color(0, 0, 0, 0), bw := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(bw)
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	return s


func _label(text: String, size := 40, col := C_TEXT, align := HORIZONTAL_ALIGNMENT_CENTER, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("outline_size", 6 if size >= 40 else 4)
	if bold:
		l.add_theme_font_override("font", font_b)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _btn(text: String, cb: Callable, col := Color(0.42, 0.25, 0.85), size := 46, min_h := 120) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_font_override("font", font_b)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", _style(col, 36, col.lightened(0.35), 3))
	b.add_theme_stylebox_override("hover", _style(col.lightened(0.1), 36, col.lightened(0.45), 3))
	b.add_theme_stylebox_override("pressed", _style(col.darkened(0.2), 36, col.lightened(0.2), 3))
	b.add_theme_stylebox_override("disabled", _style(Color(0.25, 0.22, 0.32), 36))
	b.custom_minimum_size = Vector2(0, min_h)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func():
		Sfx.play("click")
		cb.call())
	return b


func _panel(col := C_PANEL) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style(col, 40, Color(1, 1, 1, 0.12), 2))
	return p


func _full() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	return c


func _margin(parent: Control, m := 48) -> MarginContainer:
	var mc := MarginContainer.new()
	mc.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + s, m)
	parent.add_child(mc)
	return mc


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _clear(c: Control) -> void:
	for ch in c.get_children():
		ch.queue_free()


func _fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var cnt := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		cnt += 1
		if cnt % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out


# ───────────────────────── HUD ─────────────────────────
func _build_hud() -> void:
	hud = _full()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	var m := _margin(hud, 40)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(vb)

	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(top)
	var pause := _btn("II", func(): _pause(), Color(0.2, 0.16, 0.4, 0.85), 40, 96)
	pause.custom_minimum_size = Vector2(110, 96)
	top.add_child(pause)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(mid)
	lbl_score = _label("0", 84, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
	mid.add_child(lbl_score)
	lbl_mult = _label("", 34, C_GOLD)
	mid.add_child(lbl_mult)
	var side := VBoxContainer.new()
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(side)
	lbl_coins = _label("0", 52, C_GOLD, HORIZONTAL_ALIGNMENT_RIGHT, true)
	side.add_child(lbl_coins)
	lbl_dist = _label("0 م", 36, C_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	side.add_child(lbl_dist)

	power_box = HBoxContainer.new()
	power_box.alignment = BoxContainer.ALIGNMENT_CENTER
	power_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	power_box.add_theme_constant_override("separation", 14)
	vb.add_child(power_box)

	toast_lbl = _label("", 52, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
	toast_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_lbl.custom_minimum_size = Vector2(0, 150)
	vb.add_child(toast_lbl)

	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(filler)

	var bottom := HBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_theme_constant_override("separation", 24)
	vb.add_child(bottom)
	var ev := VBoxContainer.new()
	ev.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(ev)
	ev.add_child(_label("طاقة الأبزو", 32, C_CYAN, HORIZONTAL_ALIGNMENT_LEFT))
	bar_energy = ProgressBar.new()
	bar_energy.show_percentage = false
	bar_energy.custom_minimum_size = Vector2(0, 38)
	bar_energy.max_value = 100.0
	bar_energy.add_theme_stylebox_override("background", _style(Color(0, 0, 0, 0.5), 20))
	bar_energy.add_theme_stylebox_override("fill", _style(C_CYAN, 20))
	bar_energy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ev.add_child(bar_energy)
	btn_mirage = _btn("أبزو", func(): ctl.toggle_mirage(), Color(0.15, 0.55, 0.7), 46, 190)
	btn_mirage.custom_minimum_size = Vector2(300, 190)
	bottom.add_child(btn_mirage)
	bottom.add_child(_spacer(0))


func _pause() -> void:
	if ctl.state != RunController.State.RUN:
		return
	get_tree().paused = true
	pause_panel.visible = true


func _build_pause() -> void:
	pause_panel = _full()
	pause_panel.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_panel.add_child(dim)
	var m := _margin(pause_panel, 120)
	var cc := CenterContainer.new()
	m.add_child(cc)
	var p := _panel()
	cc.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 28)
	v.custom_minimum_size = Vector2(700, 0)
	p.add_child(v)
	v.add_child(_label("إيقاف مؤقت", 70, C_GOLD, HORIZONTAL_ALIGNMENT_CENTER, true))
	v.add_child(_btn("متابعة", func():
		get_tree().paused = false
		pause_panel.visible = false, Color(0.2, 0.6, 0.35)))
	v.add_child(_btn("إنهاء الجولة", func():
		get_tree().paused = false
		pause_panel.visible = false
		ctl._die(), Color(0.7, 0.25, 0.25)))
	root.add_child(pause_panel)


func show_toast(text: String, col: Color) -> void:
	toast_lbl.text = text
	toast_lbl.add_theme_color_override("font_color", col)
	_toast_t = 2.2


func _refresh_coins() -> void:
	if lbl_coins:
		lbl_coins.text = _fmt(Game.coins)
	if menu_coins:
		menu_coins.text = "◆ " + _fmt(Game.coins)


func _refresh_powers() -> void:
	if power_box == null or ctl == null:
		return
	_clear(power_box)
	_power_lbls.clear()
	var defs := [
		["magnet", "جاذب", Color(1.0, 0.45, 0.55)], ["shield", "درع", Color(0.5, 0.8, 1.0)],
		["boost", "اندفاع", Color(1.0, 0.8, 0.3)], ["double", "×2", Color(1.0, 0.9, 0.4)],
		["orb", "أبزو حر", Color(0.7, 0.6, 1.0)],
	]
	for d in defs:
		var l := _label("", 32, d[2])
		l.add_theme_stylebox_override("normal", _style(Color(0, 0, 0, 0.45), 18))
		power_box.add_child(l)
		_power_lbls[d[0]] = [l, d[1]]
		l.visible = false


func _process(dt: float) -> void:
	if ctl == null:
		return
	if _toast_t > 0.0:
		_toast_t -= dt
		toast_lbl.modulate.a = clampf(_toast_t / 0.5, 0.0, 1.0)
	_flash = maxf(0.0, _flash - dt * 3.0)
	vig_mat.set_shader_parameter("mirage", smoothstep(0.0, 1.0, ctl.mirage_t))
	vig_mat.set_shader_parameter("trouble", clampf(ctl.trouble, 0.0, 1.0) * (0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.008)))
	vig_mat.set_shader_parameter("flash", _flash)
	if hud.visible:
		lbl_score.text = _fmt(ctl.score())
		lbl_dist.text = "%s م" % _fmt(int(ctl.distance))
		var mult := Game.score_multiplier() * (2 if ctl.double_t > 0.0 else 1)
		lbl_mult.text = "×%d" % mult if mult > 1 else ""
		bar_energy.max_value = ctl.energy_cap
		bar_energy.value = ctl.energy
		var ready := ctl.energy >= RunController.MIRAGE_MIN or ctl.orb_t > 0.0
		btn_mirage.text = "الأرض" if ctl.mirage_target else "أبزو"
		btn_mirage.modulate = Color.WHITE if (ready or ctl.mirage_target) else Color(0.6, 0.6, 0.7)
		var times := {"magnet": ctl.magnet_t, "shield": ctl.shield_t if ctl.shield_n > 0 else 0.0, "boost": ctl.boost_t, "double": ctl.double_t, "orb": ctl.orb_t}
		for k in _power_lbls.keys():
			var t: float = times[k]
			var l: Label = _power_lbls[k][0]
			l.visible = t > 0.0
			if t > 0.0:
				l.text = "%s %d" % [_power_lbls[k][1], ceili(t)]
		lbl_coins.text = _fmt(Game.coins)


func _on_run_started() -> void:
	menu.visible = false
	if sub:
		sub.queue_free()
		sub = null
	if over:
		over.queue_free()
		over = null
	hud.visible = true
	_refresh_powers()
	_refresh_coins()


# ───────────────────────── القائمة الرئيسية ─────────────────────────
func _build_menu() -> void:
	menu = _full()
	menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(menu)


func show_menu() -> void:
	if sub:
		sub.queue_free()
		sub = null
	if over:
		over.queue_free()
		over = null
	hud.visible = false
	_clear(menu)
	menu.visible = true
	ctl.preview_mode = false
	var m := _margin(menu, 48)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 20)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(v)

	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	menu_coins = _label("◆ " + _fmt(Game.coins), 54, C_GOLD, HORIZONTAL_ALIGNMENT_LEFT, true)
	menu_coins.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(menu_coins)
	menu_best = _label("أفضل: " + _fmt(Game.best_score), 40, C_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	top.add_child(menu_best)

	var title := _label("سومر", 190, C_GOLD, HORIZONTAL_ALIGNMENT_CENTER, true)
	title.add_theme_constant_override("outline_size", 16)
	v.add_child(title)
	v.add_child(_label("أرض الرافدين… اركض يا بطل", 42, C_CYAN))
	var ch := Game.current_char()
	v.add_child(_label("%s — %s" % [ch["name"], ch["title"]], 44, C_TEXT))

	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(fill)

	# مهام مختصرة
	var mp := _panel(Color(0.1, 0.07, 0.22, 0.85))
	var mv := VBoxContainer.new()
	mp.add_child(mv)
	mv.add_child(_label("المضاعف الحالي ×%d" % Game.score_multiplier(), 36, C_GOLD))
	for mm in Game.missions:
		var txt: String = "%s  (%d/%d)" % [mm["text"], int(mm["progress"]), int(mm["target"])]
		var l := _label(txt, 30, C_TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mv.add_child(l)
	v.add_child(mp)

	v.add_child(_btn("▶  العب", func(): play_pressed.emit(), Color(0.15, 0.65, 0.4), 70, 170))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	for def in [["الأبطال", show_characters], ["الترقيات", show_upgrades], ["الخريطة", show_map], ["المهام", show_missions], ["الإعدادات", show_settings]]:
		var b := _btn(def[0], def[1], Color(0.16, 0.34, 0.62), 28, 110)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)


# ───────────────────────── شاشة فرعية عامة ─────────────────────────
func _open_sub(title_text: String) -> VBoxContainer:
	if sub:
		sub.queue_free()
	sub = _full()
	var dim := ColorRect.new()
	dim.color = C_BG
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	sub.add_child(dim)
	var m := _margin(sub, 48)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 20)
	m.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var back := _btn("رجوع", func(): _close_sub(), Color(0.5, 0.2, 0.3), 40, 100)
	back.custom_minimum_size = Vector2(220, 100)
	top.add_child(back)
	var t := _label(title_text, 64, C_GOLD, HORIZONTAL_ALIGNMENT_CENTER, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	var cl := _label("◆ " + _fmt(Game.coins), 44, C_GOLD, HORIZONTAL_ALIGNMENT_RIGHT, true)
	cl.name = "CoinLbl"
	top.add_child(cl)
	root.add_child(sub)
	menu.visible = false
	return v


func _close_sub() -> void:
	if sub:
		sub.queue_free()
		sub = null
	ctl.preview_mode = false
	show_menu()


func _scroll_list(v: VBoxContainer) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 18)
	sc.add_child(inner)
	return inner


# ───────────────────────── الشخصيات ─────────────────────────
func show_characters() -> void:
	var v := _open_sub("أبطال سومر")
	var list := _scroll_list(v)
	for c in Game.CHARACTERS:
		var card := _panel()
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 12)
		card.add_child(cv)
		var unlocked := Game.is_unlocked(c["id"])
		cv.add_child(_label("%s — %s" % [c["name"], c["title"]], 50, C_GOLD, HORIZONTAL_ALIGNMENT_CENTER, true))
		cv.add_child(_label("الميزة: " + c["perk"], 34, C_CYAN))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		cv.add_child(row)
		var cws: Array = c["colorways"]
		for i in cws.size():
			var cw: Dictionary = cws[i]
			var owned := Game.has_colorway(c["id"], i) and unlocked
			var sel: bool = Game.selected_char == c["id"] and int(Game.selected_colorway[c["id"]]) == i
			var label: String = cw["name"]
			if not owned:
				label += "  ◆%d" % int(cw["price"])
			var b := _btn(label, func(): _on_colorway(c["id"], i), (cw["tunic"] as Color).darkened(0.1) if owned else Color(0.3, 0.27, 0.38), 30, 100)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if sel:
				b.add_theme_stylebox_override("normal", _style((cw["tunic"] as Color).darkened(0.1), 36, Color.WHITE, 6))
			row.add_child(b)
		if not unlocked:
			cv.add_child(_btn("افتح الشخصية  ◆%s" % _fmt(int(c["price"])), func(): _on_buy_char(c["id"]), Color(0.75, 0.5, 0.1), 40, 100))
		list.add_child(card)


func _on_buy_char(id: String) -> void:
	if Game.buy_char(id):
		Sfx.play("buy")
		Game.select_char(id)
		ctl.rebuild_character()
	else:
		show_toast("شواقل غير كافية", Color(1, 0.5, 0.4))
	show_characters()


func _on_colorway(id: String, idx: int) -> void:
	if not Game.is_unlocked(id):
		show_toast("افتح الشخصية أولاً", Color(1, 0.6, 0.4))
		return
	if not Game.has_colorway(id, idx):
		if Game.buy_colorway(id, idx):
			Sfx.play("buy")
		else:
			show_toast("شواقل غير كافية", Color(1, 0.5, 0.4))
			return
	Game.select_char(id)
	Game.select_colorway(id, idx)
	ctl.rebuild_character()
	show_characters()


# ───────────────────────── الترقيات ─────────────────────────
func show_upgrades() -> void:
	var v := _open_sub("الترقيات")
	var list := _scroll_list(v)
	for u in Game.UPGRADES:
		var card := _panel()
		var cv := VBoxContainer.new()
		card.add_child(cv)
		var lvl: int = int(Game.upgrades[u["key"]])
		cv.add_child(_label("%s  —  المستوى %d/%d" % [u["name"], lvl, int(u["max"])], 44, C_GOLD, HORIZONTAL_ALIGNMENT_CENTER, true))
		cv.add_child(_label(u["desc"], 32, C_TEXT))
		cv.add_child(_label("القيمة الحالية: %s %s" % [str(snappedf(Game.upgrade_value(u["key"]), 0.1)), u["unit"]], 32, C_CYAN))
		var pb := ProgressBar.new()
		pb.max_value = u["max"]
		pb.value = lvl
		pb.show_percentage = false
		pb.custom_minimum_size = Vector2(0, 26)
		pb.add_theme_stylebox_override("background", _style(Color(0, 0, 0, 0.5), 14))
		pb.add_theme_stylebox_override("fill", _style(C_GOLD, 14))
		cv.add_child(pb)
		if lvl < int(u["max"]):
			var key: String = u["key"]
			cv.add_child(_btn("ترقية  ◆%s" % _fmt(Game.upgrade_cost(key)), func():
				if Game.buy_upgrade(key):
					Sfx.play("buy")
				else:
					show_toast("شواقل غير كافية", Color(1, 0.5, 0.4))
				show_upgrades(), Color(0.75, 0.5, 0.1), 40, 96))
		else:
			cv.add_child(_label("أقصى مستوى", 36, C_CYAN))
		list.add_child(card)


# ───────────────────────── المهام ─────────────────────────
func show_missions() -> void:
	var v := _open_sub("المهام")
	v.add_child(_label("المضاعف ×%d — كل 3 مهام تزيد المضاعف" % Game.score_multiplier(), 38, C_GOLD))
	var list := _scroll_list(v)
	for m in Game.missions:
		var card := _panel()
		var cv := VBoxContainer.new()
		card.add_child(cv)
		var t := _label(m["text"], 40, C_TEXT)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cv.add_child(t)
		var pb := ProgressBar.new()
		pb.max_value = m["target"]
		pb.value = m["progress"]
		pb.show_percentage = false
		pb.custom_minimum_size = Vector2(0, 30)
		pb.add_theme_stylebox_override("background", _style(Color(0, 0, 0, 0.5), 16))
		pb.add_theme_stylebox_override("fill", _style(C_CYAN, 16))
		cv.add_child(pb)
		cv.add_child(_label("%d / %d     الجائزة ◆%d" % [int(m["progress"]), int(m["target"]), int(m["reward"])], 32, C_GOLD))
		list.add_child(card)
	v.add_child(_label("المهام المنجزة: %d" % Game.missions_done, 34, C_TEXT))


# ───────────────────────── الإعدادات ─────────────────────────
func show_settings() -> void:
	var v := _open_sub("الإعدادات")
	var list := _scroll_list(v)
	var q_names := ["منخفضة (بطارية)", "متوسطة", "عالية"]
	var qb := _btn("الجودة: " + q_names[int(Game.settings["quality"])], func():
		Game.set_setting("quality", (int(Game.settings["quality"]) + 1) % 3)
		get_tree().root.get_node("Main").call("apply_quality")
		show_settings(), Color(0.38, 0.24, 0.72), 40, 110)
	list.add_child(qb)
	var toggles := [["fps60", "60 إطار في الثانية"], ["sfx", "المؤثرات الصوتية"], ["music", "الموسيقى"], ["haptics", "الاهتزاز"], ["adaptive", "صعوبة تكيّفية"]]
	for t in toggles:
		var key: String = t[0]
		var on: bool = bool(Game.settings[key])
		list.add_child(_btn("%s: %s" % [t[1], "مفعّل" if on else "متوقف"], func():
			Game.set_setting(key, not bool(Game.settings[key]))
			show_settings(), Color(0.2, 0.55, 0.35) if on else Color(0.45, 0.25, 0.3), 40, 110))
	list.add_child(_btn("إعادة ضبط التقدم", func():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.SAVE_PATH))
		get_tree().quit(), Color(0.6, 0.2, 0.2), 36, 100))
	list.add_child(_label("اللعبة تُغلق بعد إعادة الضبط", 28, C_TEXT))


# ───────────────────────── نهاية الجولة ─────────────────────────
func _on_run_ended(s: Dictionary) -> void:
	hud.visible = false
	if over:
		over.queue_free()
	over = _full()
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.1, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	over.add_child(dim)
	var m := _margin(over, 60)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 20)
	m.add_child(v)
	v.add_child(_label("سقط البطل", 90, C_GOLD, HORIZONTAL_ALIGNMENT_CENTER, true))
	if s["new_best"]:
		v.add_child(_label("رقم قياسي جديد — عاش!", 54, C_CYAN, HORIZONTAL_ALIGNMENT_CENTER, true))
	v.add_child(_label(_fmt(int(s["score"])), 130, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true))
	var p := _panel()
	var pv := VBoxContainer.new()
	p.add_child(pv)
	var lines := [
		"المسافة: %s م" % _fmt(int(s["distance"])), "الشواقل: %d" % int(s["coins"]),
		"دموع الأبزو: %d" % int(s["shards"]), "نجاة بشعرة: %d" % int(s["grazes"]),
		"عبور في الأبزو: %d" % int(s["ghost"]), "أفضل نتيجة: %s" % _fmt(int(s["best"])),
	]
	for l in lines:
		pv.add_child(_label(l, 40, C_TEXT))
	v.add_child(p)
	var done: Array = s["missions"]
	if not done.is_empty():
		var mp := _panel(Color(0.2, 0.15, 0.4))
		var mv := VBoxContainer.new()
		mp.add_child(mv)
		mv.add_child(_label("مهام أُنجزت", 40, C_GOLD, HORIZONTAL_ALIGNMENT_CENTER, true))
		for mm in done:
			var ml := _label("✓ %s  (+%d)" % [mm["text"], int(mm["reward"])], 30, C_TEXT)
			ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			mv.add_child(ml)
		v.add_child(mp)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(fill)
	if s["can_revive"]:
		v.add_child(_btn("أكمل بـ ◆%d" % int(s["revive_cost"]), func(): _do_revive(), Color(0.75, 0.5, 0.1), 46, 120))
	v.add_child(_btn("العب مجدداً", func():
		Game.refresh_missions()
		play_pressed.emit(), Color(0.15, 0.65, 0.4), 56, 140))
	v.add_child(_btn("القائمة", func():
		Game.refresh_missions()
		ctl.enter_menu()
		show_menu(), Color(0.38, 0.24, 0.72), 44, 110))
	root.add_child(over)
	Sfx.play("click")


func _do_revive() -> void:
	if ctl.state == RunController.State.MENU:
		# نعيد الحالة إلى DEAD ليسمح revive
		ctl.state = RunController.State.DEAD
	if ctl.revive():
		if over:
			over.queue_free()
			over = null
		hud.visible = true
		_refresh_powers()
	else:
		ctl.state = RunController.State.MENU
		show_toast("شواقل غير كافية", Color(1, 0.5, 0.4))


# ───────────────────────── خريطة سومر ─────────────────────────
const MAP_CITIES := [
	{"name": "أور — أرض الزقورة", "from": 0, "text": "مدينة القمر ونانا. زقورة أور-نمو بُنيت نحو 2100 ق.م وما زالت قائمة قرب الناصرية.", "col": Color(0.95, 0.72, 0.4)},
	{"name": "الأهوار — أرض القصب والماء", "from": 1400, "text": "موطن بيوت القصب (المضيف) وقوارب المشحوف. ما زالت حيّة في جنوب العراق وهي مدرجة في قائمة التراث العالمي.", "col": Color(0.4, 0.8, 0.7)},
	{"name": "أوروك — مدينة جلجامش", "from": 2800, "text": "من أولى مدن العالم الكبرى، وفيها ظهرت الكتابة المسمارية نحو 3200 ق.م، وحكمها الملك جلجامش.", "col": Color(0.6, 0.5, 0.9)},
]


func show_map() -> void:
	var v := _open_sub("خريطة سومر")
	v.add_child(_label("أبعد مسافة وصلتها: %s م — تتبدّل المدينة كل 1,400 م" % _fmt(Game.best_distance), 34, C_TEXT))
	var list := _scroll_list(v)
	for c in MAP_CITIES:
		var reached: bool = Game.best_distance >= int(c["from"])
		var card := _panel(Color(0.14, 0.10, 0.28, 0.96) if reached else Color(0.1, 0.09, 0.16, 0.96))
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 10)
		card.add_child(cv)
		cv.add_child(_label(c["name"] if reached else "؟؟؟  (تُفتح عند %s م)" % _fmt(int(c["from"])), 46, c["col"] if reached else Color(0.5, 0.5, 0.6), HORIZONTAL_ALIGNMENT_CENTER, true))
		if reached:
			var t := _label(c["text"], 32, C_TEXT)
			t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			cv.add_child(t)
		list.add_child(card)
	var note := _label("الأبزو: المياه الأولى في الميثولوجيا السومرية. إنانا وأنكيدو وجلجامش وثور السماء من ملحمة جلجامش.", 28, Color(0.8, 0.8, 0.9))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(note)
