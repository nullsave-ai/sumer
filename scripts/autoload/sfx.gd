extends Node
## مدير الصوت: مؤثرات قصيرة + موسيقى متكررة + صوت العاصفة.
## كل الملفات مولّدة برمجياً (tools/gen_audio.py) فلا توجد أصول مرخّصة.

const NAMES := [
	"coin", "shard", "jump", "land", "slide", "lane", "hit", "shift_in",
	"shift_out", "powerup", "graze", "gameover", "click", "buy",
]
const POOL_SIZE := 10

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _storm: AudioStreamPlayer
var _music_target_db := -8.0
var _storm_target_db := -60.0

var sfx_on := true
var music_on := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in NAMES:
		var path := "res://assets/audio/%s.wav" % n
		if ResourceLoader.exists(path):
			_streams[n] = load(path)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	_music = _make_loop("res://assets/audio/music.wav", -60.0)
	_storm = _make_loop("res://assets/audio/storm.wav", -60.0)


func _make_loop(path: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	add_child(p)
	if ResourceLoader.exists(path):
		var s = load(path)
		if s is AudioStreamWAV:
			var w := s as AudioStreamWAV
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			# 16-bit mono: عدد العينات = حجم البيانات / 2
			w.loop_end = int(w.data.size() / 2)
		p.stream = s
	p.volume_db = db
	return p


func apply_settings(sfx: bool, music: bool) -> void:
	sfx_on = sfx
	music_on = music
	if _music == null:
		return
	if music_on:
		if not _music.playing and _music.stream:
			_music.play()
	else:
		_music.stop()


func play(name: String, pitch := 1.0, db := 0.0) -> void:
	if not sfx_on or not _streams.has(name):
		return
	var p := _players[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = _streams[name]
	p.pitch_scale = pitch
	p.volume_db = db
	p.play()


func start_music() -> void:
	if music_on and _music.stream and not _music.playing:
		_music.play()


func set_music_level(db: float) -> void:
	_music_target_db = db


## شدة العاصفة 0..1 (تقترب = أعلى)
func set_storm(intensity: float) -> void:
	if not sfx_on or _storm.stream == null:
		_storm_target_db = -60.0
	else:
		_storm_target_db = lerpf(-40.0, -3.0, clampf(intensity, 0.0, 1.0)) if intensity > 0.02 else -60.0
	if _storm_target_db > -50.0 and not _storm.playing:
		_storm.play()


func _process(delta: float) -> void:
	var k := 1.0 - exp(-delta * 3.0)
	if _music:
		var tgt := _music_target_db if music_on else -60.0
		_music.volume_db = lerpf(_music.volume_db, tgt, k)
	if _storm:
		_storm.volume_db = lerpf(_storm.volume_db, _storm_target_db, k)
		if _storm_target_db <= -55.0 and _storm.playing and _storm.volume_db < -55.0:
			_storm.stop()
