extends Node
## الحالة العامة للّعبة: الحفظ، الشخصيات، الترقيات، المهام، الإعدادات.

signal coins_changed
signal mission_completed(mission: Dictionary)
signal settings_changed

const SAVE_PATH := "user://sumer_save.json"
const SAVE_VERSION := 1

# ───────────────────────── الشخصيات ─────────────────────────
# كل شخصية: هيئة مختلفة + ميزة تلعب دوراً حقيقياً في الأداء.
const CHARACTERS := [
	{
		"id": "gilgamesh", "name": "جلجامش", "title": "ملك أوروك", "price": 0,
		"perk": "شحن الأبزو أسرع 30%", "perk_key": "shift_regen", "perk_val": 1.3,
		"head": "king", "height": 1.06, "shoulder": 1.15,
		"colorways": [
			{"name": "تاج أوروك", "skin": Color(0.76, 0.54, 0.38), "hood": Color(0.10, 0.07, 0.07), "tunic": Color(0.92, 0.88, 0.76), "pants": Color(0.76, 0.54, 0.38), "boots": Color(0.45, 0.28, 0.16), "scarf": Color(0.15, 0.30, 0.72), "accent": Color(0.98, 0.78, 0.25), "price": 0},
			{"name": "لازورد", "skin": Color(0.76, 0.54, 0.38), "hood": Color(0.10, 0.07, 0.07), "tunic": Color(0.14, 0.28, 0.70), "pants": Color(0.76, 0.54, 0.38), "boots": Color(0.2, 0.15, 0.12), "scarf": Color(0.95, 0.80, 0.30), "accent": Color(0.60, 0.90, 1.0), "price": 600},
			{"name": "عقيق أحمر", "skin": Color(0.76, 0.54, 0.38), "hood": Color(0.10, 0.07, 0.07), "tunic": Color(0.72, 0.18, 0.14), "pants": Color(0.76, 0.54, 0.38), "boots": Color(0.3, 0.16, 0.1), "scarf": Color(0.95, 0.85, 0.5), "accent": Color(1.0, 0.7, 0.3), "price": 900},
		],
	},
	{
		"id": "enkidu", "name": "أنكيدو", "title": "ابن البرية", "price": 2500,
		"perk": "مدى قرن الثور أكبر 40%", "perk_key": "magnet_range", "perk_val": 1.4,
		"head": "wild", "height": 1.1, "shoulder": 1.25,
		"colorways": [
			{"name": "ابن الوحش", "skin": Color(0.62, 0.42, 0.30), "hood": Color(0.28, 0.17, 0.09), "tunic": Color(0.55, 0.38, 0.2), "pants": Color(0.62, 0.42, 0.30), "boots": Color(0.35, 0.22, 0.12), "scarf": Color(0.72, 0.5, 0.25), "accent": Color(0.85, 0.7, 0.4), "price": 0},
			{"name": "غبار الرافدين", "skin": Color(0.62, 0.42, 0.30), "hood": Color(0.55, 0.5, 0.42), "tunic": Color(0.7, 0.62, 0.48), "pants": Color(0.62, 0.42, 0.30), "boots": Color(0.4, 0.3, 0.2), "scarf": Color(0.45, 0.6, 0.35), "accent": Color(0.9, 0.85, 0.6), "price": 800},
			{"name": "ظل الغابة", "skin": Color(0.62, 0.42, 0.30), "hood": Color(0.08, 0.1, 0.07), "tunic": Color(0.2, 0.3, 0.18), "pants": Color(0.62, 0.42, 0.30), "boots": Color(0.15, 0.12, 0.08), "scarf": Color(0.5, 0.75, 0.3), "accent": Color(0.7, 0.9, 0.5), "price": 1100},
		],
	},
	{
		"id": "inanna", "name": "إنانا", "title": "سيدة السماء", "price": 6000,
		"perk": "هدايا الآلهة تدوم أطول 35%", "perk_key": "powerup_time", "perk_val": 1.35,
		"head": "priestess", "height": 1.0, "shoulder": 0.9,
		"colorways": [
			{"name": "نجمة الصباح", "skin": Color(0.84, 0.64, 0.5), "hood": Color(0.08, 0.05, 0.07), "tunic": Color(0.15, 0.30, 0.72), "pants": Color(0.84, 0.64, 0.5), "boots": Color(0.85, 0.65, 0.2), "scarf": Color(0.98, 0.82, 0.3), "accent": Color(1.0, 0.88, 0.45), "price": 0},
			{"name": "صوف أبيض", "skin": Color(0.84, 0.64, 0.5), "hood": Color(0.08, 0.05, 0.07), "tunic": Color(0.95, 0.92, 0.84), "pants": Color(0.84, 0.64, 0.5), "boots": Color(0.85, 0.85, 0.9), "scarf": Color(0.35, 0.65, 0.9), "accent": Color(0.7, 0.9, 1.0), "price": 1200},
			{"name": "عقيق ووردة", "skin": Color(0.84, 0.64, 0.5), "hood": Color(0.08, 0.05, 0.07), "tunic": Color(0.78, 0.2, 0.3), "pants": Color(0.84, 0.64, 0.5), "boots": Color(0.35, 0.1, 0.15), "scarf": Color(1.0, 0.6, 0.45), "accent": Color(1.0, 0.85, 0.5), "price": 1500},
		],
	},
]

# ───────────────────────── الترقيات ─────────────────────────
const UPGRADES := [
	{"key": "shift_cap", "name": "سعة الأبزو", "desc": "طاقة أكبر للبقاء في عالم الأبزو", "max": 5, "base": 100.0, "step": 12.0, "unit": ""},
	{"key": "magnet", "name": "قرن الثور", "desc": "يسحب الشواقل القريبة", "max": 5, "base": 7.0, "step": 1.5, "unit": "ث"},
	{"key": "shield", "name": "درع إنانا", "desc": "يمتص اصطدامين", "max": 5, "base": 9.0, "step": 1.5, "unit": "ث"},
	{"key": "boost", "name": "ريح إنليل", "desc": "انطلاق سريع لا يُقهر", "max": 5, "base": 4.5, "step": 0.8, "unit": "ث"},
	{"key": "double", "name": "اللوح الذهبي", "desc": "نقاط مضاعفة", "max": 5, "base": 10.0, "step": 2.0, "unit": "ث"},
]

# ───────────────────────── قوالب المهام ─────────────────────────
const MISSION_TEMPLATES := [
	{"key": "coins_run", "scope": "run", "text": "اجمع %d شيقل في جولة واحدة", "targets": [100, 180, 300, 480], "rewards": [150, 230, 340, 500]},
	{"key": "dist_run", "scope": "run", "text": "اركض %d متراً في جولة واحدة", "targets": [700, 1300, 2100, 3400], "rewards": [150, 250, 360, 520]},
	{"key": "shards_run", "scope": "run", "text": "اجمع %d دمعة أبزو في جولة", "targets": [6, 12, 22, 36], "rewards": [200, 300, 420, 560]},
	{"key": "shifts", "scope": "total", "text": "انتقل بين الأرض والأبزو %d مرة", "targets": [10, 20, 40, 80], "rewards": [120, 200, 320, 480]},
	{"key": "grazes", "scope": "total", "text": "انجُ من %d اصطدامات بشعرة", "targets": [5, 10, 20, 40], "rewards": [180, 280, 400, 560]},
	{"key": "jumps", "scope": "total", "text": "اقفز %d مرة", "targets": [25, 50, 100, 200], "rewards": [100, 180, 280, 420]},
	{"key": "slides", "scope": "total", "text": "انزلق %d مرة", "targets": [25, 50, 100, 200], "rewards": [100, 180, 280, 420]},
	{"key": "powerups", "scope": "total", "text": "التقط %d هدايا من الآلهة", "targets": [3, 6, 12, 20], "rewards": [140, 220, 340, 480]},
	{"key": "ghost_pass", "scope": "total", "text": "اعبر %d عائقاً وأنت في الأبزو", "targets": [6, 12, 25, 45], "rewards": [200, 300, 440, 600]},
]

# ───────────────────────── البيانات المحفوظة ─────────────────────────
var coins := 0
var best_score := 0
var best_distance := 0
var total_runs := 0
var total_distance := 0.0
var selected_char := "gilgamesh"
var unlocked_chars: Array = ["gilgamesh"]
var selected_colorway := {"gilgamesh": 0, "enkidu": 0, "inanna": 0}
var owned_colorways := {"gilgamesh": [0], "enkidu": [0], "inanna": [0]}
var upgrades := {"shift_cap": 0, "magnet": 0, "shield": 0, "boost": 0, "double": 0}
var missions: Array = []
var missions_done := 0
var settings := {
	"quality": 1, "fps60": true, "sfx": true, "music": true,
	"haptics": true, "tutorial_done": false, "adaptive": true,
}

# حالة الجولة الحالية (تُصفّر عند begin_run)
var run_completed: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	load_game()
	if missions.size() < 3:
		_fill_missions()
	apply_runtime_settings()


# ───────────────────────── الحفظ ─────────────────────────
func save_game() -> void:
	var d := {
		"v": SAVE_VERSION,
		"coins": coins, "best_score": best_score, "best_distance": best_distance,
		"total_runs": total_runs, "total_distance": total_distance,
		"selected_char": selected_char, "unlocked_chars": unlocked_chars,
		"selected_colorway": selected_colorway, "owned_colorways": owned_colorways,
		"upgrades": upgrades, "missions": missions, "missions_done": missions_done,
		"settings": settings,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))
		f.close()


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var d: Dictionary = parsed
	coins = int(d.get("coins", 0))
	best_score = int(d.get("best_score", 0))
	best_distance = int(d.get("best_distance", 0))
	total_runs = int(d.get("total_runs", 0))
	total_distance = float(d.get("total_distance", 0.0))
	selected_char = str(d.get("selected_char", "gilgamesh"))
	var uc = d.get("unlocked_chars", ["gilgamesh"])
	if typeof(uc) == TYPE_ARRAY:
		unlocked_chars = uc
	for k in ["selected_colorway", "owned_colorways", "upgrades", "settings"]:
		var v = d.get(k, null)
		if typeof(v) == TYPE_DICTIONARY:
			var target: Dictionary = get(k)
			for kk in v.keys():
				target[kk] = v[kk]
	# JSON يحوّل الأعداد إلى float → نعيدها int
	for k in selected_colorway.keys():
		selected_colorway[k] = int(selected_colorway[k])
	for k in upgrades.keys():
		upgrades[k] = int(upgrades[k])
	for k in owned_colorways.keys():
		var arr: Array = owned_colorways[k]
		for i in arr.size():
			arr[i] = int(arr[i])
	var ms = d.get("missions", [])
	if typeof(ms) == TYPE_ARRAY:
		missions = []
		for m in ms:
			if typeof(m) == TYPE_DICTIONARY:
				m["target"] = int(m.get("target", 1))
				m["reward"] = int(m.get("reward", 100))
				m["progress"] = int(m.get("progress", 0))
				missions.append(m)
	missions_done = int(d.get("missions_done", 0))
	if not unlocked_chars.has(selected_char):
		selected_char = "gilgamesh"


func apply_runtime_settings() -> void:
	Engine.max_fps = 60 if settings["fps60"] else 30
	Sfx.apply_settings(settings["sfx"], settings["music"])
	settings_changed.emit()


func set_setting(key: String, value) -> void:
	settings[key] = value
	apply_runtime_settings()
	save_game()


# ───────────────────────── العملات ─────────────────────────
func add_coins(n: int) -> void:
	coins += n
	coins_changed.emit()


func spend(n: int) -> bool:
	if coins < n:
		return false
	coins -= n
	coins_changed.emit()
	save_game()
	return true


# ───────────────────────── الشخصيات ─────────────────────────
func char_data(id: String) -> Dictionary:
	for c in CHARACTERS:
		if c["id"] == id:
			return c
	return CHARACTERS[0]


func current_char() -> Dictionary:
	return char_data(selected_char)


func current_colorway() -> Dictionary:
	var c := current_char()
	var idx: int = int(selected_colorway.get(c["id"], 0))
	var cws: Array = c["colorways"]
	return cws[clampi(idx, 0, cws.size() - 1)]


func is_unlocked(id: String) -> bool:
	return unlocked_chars.has(id)


func buy_char(id: String) -> bool:
	var c := char_data(id)
	if is_unlocked(id):
		return true
	if spend(int(c["price"])):
		unlocked_chars.append(id)
		save_game()
		return true
	return false


func select_char(id: String) -> void:
	if is_unlocked(id):
		selected_char = id
		save_game()


func has_colorway(char_id: String, idx: int) -> bool:
	var arr: Array = owned_colorways.get(char_id, [0])
	return arr.has(idx)


func buy_colorway(char_id: String, idx: int) -> bool:
	if has_colorway(char_id, idx):
		return true
	var c := char_data(char_id)
	var price: int = int((c["colorways"] as Array)[idx]["price"])
	if spend(price):
		if not owned_colorways.has(char_id):
			owned_colorways[char_id] = [0]
		(owned_colorways[char_id] as Array).append(idx)
		save_game()
		return true
	return false


func select_colorway(char_id: String, idx: int) -> void:
	if has_colorway(char_id, idx):
		selected_colorway[char_id] = idx
		save_game()


# ───────────────────────── الترقيات ─────────────────────────
func upgrade_def(key: String) -> Dictionary:
	for u in UPGRADES:
		if u["key"] == key:
			return u
	return {}


func upgrade_value(key: String) -> float:
	var u := upgrade_def(key)
	if u.is_empty():
		return 0.0
	return float(u["base"]) + float(u["step"]) * int(upgrades.get(key, 0))


func upgrade_cost(key: String) -> int:
	var lvl: int = int(upgrades.get(key, 0))
	return 300 + lvl * 350


func buy_upgrade(key: String) -> bool:
	var u := upgrade_def(key)
	var lvl: int = int(upgrades.get(key, 0))
	if lvl >= int(u["max"]):
		return false
	if spend(upgrade_cost(key)):
		upgrades[key] = lvl + 1
		save_game()
		return true
	return false


func perk(key: String) -> float:
	var c := current_char()
	if c["perk_key"] == key:
		return float(c["perk_val"])
	return 1.0


# ───────────────────────── المهام ─────────────────────────
func mission_level() -> int:
	return int(missions_done / 3)


func score_multiplier() -> int:
	return mini(1 + mission_level(), 30)


func _fill_missions() -> void:
	var used := {}
	for m in missions:
		used[m["key"]] = true
	var tier := mini(int(mission_level() / 2), 3)
	var guard := 0
	while missions.size() < 3 and guard < 50:
		guard += 1
		var t: Dictionary = MISSION_TEMPLATES[_rng.randi() % MISSION_TEMPLATES.size()]
		if used.has(t["key"]):
			continue
		used[t["key"]] = true
		var ti := clampi(tier + (_rng.randi() % 2), 0, 3)
		missions.append({
			"key": t["key"], "scope": t["scope"],
			"text": t["text"] % int(t["targets"][ti]),
			"target": int(t["targets"][ti]), "reward": int(t["rewards"][ti]),
			"progress": 0,
		})


func begin_run() -> void:
	run_completed.clear()
	for m in missions:
		if m["scope"] == "run" and int(m["progress"]) < int(m["target"]):
			m["progress"] = 0


## يزيد تقدم مهام النوع «total».
func mission_add(key: String, amount: int = 1) -> void:
	for m in missions:
		if m["key"] == key and m["scope"] == "total":
			_advance(m, int(m["progress"]) + amount)


## يضبط قيمة مهام النوع «run» (أكبر قيمة في الجولة).
func mission_set_run(key: String, value: int) -> void:
	for m in missions:
		if m["key"] == key and m["scope"] == "run" and value > int(m["progress"]):
			_advance(m, value)


func _advance(m: Dictionary, value: int) -> void:
	if int(m["progress"]) >= int(m["target"]):
		return
	m["progress"] = mini(value, int(m["target"]))
	if int(m["progress"]) >= int(m["target"]):
		add_coins(int(m["reward"]))
		missions_done += 1
		run_completed.append(m.duplicate())
		mission_completed.emit(m)


## يستبدل المهام المنجزة بجديدة (يُستدعى بعد عرض نتائج الجولة).
func refresh_missions() -> void:
	var keep: Array = []
	for m in missions:
		if int(m["progress"]) < int(m["target"]):
			keep.append(m)
	missions = keep
	_fill_missions()
	save_game()


func finish_run(score: int, distance: float, coins_gained: int) -> void:
	total_runs += 1
	total_distance += distance
	best_score = maxi(best_score, score)
	best_distance = maxi(best_distance, int(distance))
	if coins_gained > 0:
		pass
	save_game()
