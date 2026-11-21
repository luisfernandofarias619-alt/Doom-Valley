extends Node
## Efeitos sonoros sintetizados (sfx()/playSfx() do HTML).
## O original criava osciladores Web Audio a cada som. Aqui cada efeito da tabela é sintetizado UMA vez
## (mesmas frequências, formas de onda, envelopes exponenciais e atrasos) para um AudioStreamWAV, numa
## thread de trabalho, e tocado por um pool de AudioStreamPlayer. A hierarquia (tiers, duck, intervalo
## mínimo e limite de vozes) é a mesma do original.

const RATE := 44100
const POOL := 18
const MIN_GAP := [70.0, 45.0, 0.0]   # ms entre repetições do mesmo som, por tier
const ALIASES := {"rhswipe": "rhswing"}   # 'rhswipe' é chamado no HTML mas nunca foi definido (bug)

var streams := {}
var _players: Array[AudioStreamPlayer] = []
var _last := {}
var _duck := 0.0
var _voices: Array[float] = []   # instantes (ms) em que cada nota termina
var _tones := {}
var _mutex := Mutex.new()


func _ready() -> void:
	_ensure_buses()
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	WorkerThreadPool.add_task(_prerender_all, false, "sfx prerender")


func _ensure_buses() -> void:
	for b in ["Music", "SFX", "Ambience"]:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	var mi := AudioServer.get_bus_index("Music")
	if AudioServer.get_bus_effect_count(mi) == 0:
		var c := AudioEffectCompressor.new()   # DynamicsCompressor do grafo de música (threshold -16, ratio 6)
		c.threshold = -16.0
		c.ratio = 6.0
		AudioServer.add_bus_effect(mi, c)


func _prerender_all() -> void:
	for k in SfxDefs.DEFS.keys():
		_get_stream(k)


func _get_stream(n: String) -> AudioStreamWAV:
	_mutex.lock()
	var s: AudioStreamWAV = streams.get(n)
	_mutex.unlock()
	if s:
		return s
	var d: Array = SfxDefs.DEFS.get(n, [])
	if d.is_empty():
		return null
	s = synth_notes(d[1])
	_mutex.lock()
	streams[n] = s
	_mutex.unlock()
	return s


## Sintetiza uma lista de notas [freq, tipo, duração, volume, atraso] em um único WAV mono 16 bits.
static func synth_notes(notes: Array) -> AudioStreamWAV:
	var total := 0.0
	for nt in notes:
		total = maxf(total, float(nt[4]) + float(nt[2]))
	var n := int(ceil(total * RATE)) + 32
	var buf := PackedFloat32Array()
	buf.resize(n)
	for nt in notes:
		_render_note(buf, float(nt[0]), String(nt[1]), float(nt[2]), float(nt[3]), float(nt[4]))
	return _to_wav(buf)


static func _render_note(buf: PackedFloat32Array, f: float, ty: String, du: float, vo: float, dl: float) -> void:
	var start := int(dl * RATE)
	var len := int(du * RATE)
	var ph := 0.0
	var inc := f / RATE
	# rampa exponencial do volume até 0,01 (exponentialRampToValueAtTime) e corte no fim da nota
	var floor_ratio := 0.01 / maxf(vo, 0.0101)
	var k := pow(floor_ratio, 1.0 / maxf(1.0, float(len)))
	var g := vo
	var end := mini(buf.size(), start + len)
	match ty:
		"sine":
			for i in range(start, end):
				buf[i] += sin(ph * TAU) * g
				ph += inc
				g *= k
		"square":
			for i in range(start, end):
				var v := 1.0 if ph < 0.5 else -1.0
				v += _blep(ph, inc) - _blep(fposmod(ph + 0.5, 1.0), inc)
				buf[i] += v * g
				ph += inc
				if ph >= 1.0:
					ph -= 1.0
				g *= k
		"sawtooth":
			for i in range(start, end):
				var v := 2.0 * ph - 1.0 - _blep(ph, inc)
				buf[i] += v * g
				ph += inc
				if ph >= 1.0:
					ph -= 1.0
				g *= k
		_:
			for i in range(start, end):
				var v := 4.0 * absf(ph - 0.5) - 1.0
				buf[i] += -v * g
				ph += inc
				if ph >= 1.0:
					ph -= 1.0
				g *= k


## PolyBLEP: suaviza as descontinuidades de quadrada e dente de serra (os osciladores do Web Audio são limitados em banda).
static func _blep(t: float, dt: float) -> float:
	if t < dt:
		t /= dt
		return t + t - t * t - 1.0
	if t > 1.0 - dt:
		t = (t - 1.0) / dt
		return t * t + t + t + 1.0
	return 0.0


static func _to_wav(buf: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w


## Toca um efeito da tabela respeitando tiers, duck e limite de vozes.
func play(n: String, vol_mul: float = 1.0) -> void:
	n = ALIASES.get(n, n)
	var d: Array = SfxDefs.DEFS.get(n, [])
	if d.is_empty() or not Settings.s.sound:
		return
	var tier: int = d[0]
	var t := Time.get_ticks_msec() * 1.0
	if t < _duck and tier < 2:
		return
	if t - float(_last.get(n, -1e9)) < MIN_GAP[tier]:
		return
	_voices = _voices.filter(func(e): return e > t)
	if _voices.size() > 10 and tier < 2:
		return
	var s := _get_stream(n)
	if s == null:
		return
	_last[n] = t
	if tier == 2:
		_duck = t + 180.0
	for nt in d[1]:
		_voices.append(t + (float(nt[4]) + float(nt[2])) * 1000.0)
	_play_stream(s, Settings.sfx_volume() * vol_mul)


## Tom avulso (playSfx/fpSfx do HTML), com cache por parâmetros.
func tone(f: float, ty: String, du: float, vo: float, vol_mul: float = 1.0) -> void:
	if not Settings.s.sound:
		return
	var key := "%d|%s|%.3f|%.3f" % [int(f), ty, du, vo]
	var s: AudioStreamWAV = _tones.get(key)
	if s == null:
		s = synth_notes([[f, ty, du, vo, 0.0]])
		_tones[key] = s
	_play_stream(s, Settings.sfx_volume() * vol_mul)


func _play_stream(s: AudioStream, vol: float) -> void:
	if vol <= 0.0001:
		return
	var best: AudioStreamPlayer = null
	for p in _players:
		if not p.playing:
			best = p
			break
	if best == null:
		best = _players[0]
		_players.push_back(_players.pop_front())
	best.stream = s
	best.volume_db = linear_to_db(vol)
	best.play()
