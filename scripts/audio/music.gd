extends Node
## Diretor da trilha (MX do HTML v4.4 + trilha por momento v6.0).
## Escolhe a faixa pelo momento do jogo, faz crossfade com os tempos do original (FD), lembra a posição das
## faixas de setor, abaixa o volume na pausa (duck) e repete as faixas sem emenda (loop nativo a partir do
## ponto de entrada) ou com crossfade (faixas sem ponto de loop).

const BOSS_IDS := ["rhino", "dracula", "vesperon", "illuminati", "anomalia", "espelho"]
const MDEF := {"title": "fountain", "s0": "runners", "s1": "runners", "s2": "runners", "s3": "runners", "s4": "runners",
	"b0": "crimson", "win": "rise", "over": "fountain"}
const BMUS := {"rhino": "bipedal", "dracula": "magicfx7", "vesperon": "bossbattle", "illuminati": "battleenc",
	"anomalia": "pipesunder", "espelho": "bossrev"}
const MDF6 := {"bv1": "-", "sx_fenda": "runners"}
const AMBC := {"bv1": "cinza"}

var tracks := {}          # id -> {title, d, lp, a, ln}
var order: Array[String] = []
var context := "title"    # definido pelo jogo a cada quadro
var paused := false       # pausa com menu
var soft_paused := false  # level up / painéis
var preview := ""

var _streams := {}
var _decks: Array[Dictionary] = []
var _ci := 0
var _cx := ""
var _pc := ""
var _mpos := {}
var _duck := 1.0
var _zt := 0.0
var _sus := false

# ambiência sintetizada (Vesperon fase 1)
var _amb_player: AudioStreamPlayer
var _amb_stream: AudioStreamWAV
var _amb_crackles: Array[AudioStreamWAV] = []
var _amb_lvl := 0.0
var _amb_next := 0.0
var _amb_building := false
var _amb_pool: Array[AudioStreamPlayer] = []
var _amb_task := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var d: Dictionary = AtlasData.TRACKS
	if true:
		for id in d.keys():
			var t: Dictionary = d[id]
			var lp: bool = t.get("loop", "0") == "1"
			tracks[id] = {"title": t.get("title", id), "d": float(t.get("dur", 0)), "lp": lp,
				"a": float(t.get("lead", 0)) if lp else 0.0, "ln": float(t.get("len", t.get("dur", 0))) if lp else float(t.get("dur", 0))}
			order.append(id)
	for i in 3:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		add_child(p)
		_decks.append({"p": p, "id": "", "g": 0.0, "tg": 0.0, "sp": 1.0, "fin": false, "c": ""})
	_amb_player = AudioStreamPlayer.new()
	_amb_player.bus = "Ambience"
	add_child(_amb_player)
	for i in 4:
		var q := AudioStreamPlayer.new()
		q.bus = "Ambience"
		add_child(q)
		_amb_pool.append(q)


func _exit_tree() -> void:
	if _amb_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_amb_task)
		_amb_task = -1
	for d in _decks:
		(d.p as AudioStreamPlayer).stop()
		(d.p as AudioStreamPlayer).stream = null
	_streams.clear()


func stream_for(id: String) -> AudioStream:
	if _streams.has(id):
		return _streams[id]
	var path := "res://assets/audio/music/%s.ogg" % id
	var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
	if s is AudioStreamOggVorbis:
		var t: Dictionary = tracks.get(id, {})
		s.loop = bool(t.get("lp", false))
		s.loop_offset = float(t.get("a", 0.0))
	_streams[id] = s
	return s


# ---------- escolha da faixa ----------
func _user_map() -> Dictionary:
	var um := {}
	for p in String(Settings.s.mmap).split(",", false):
		var i := p.find(":")
		if i > 0:
			um[p.substr(0, i)] = p.substr(i + 1)
	return um


func default_for(c: String) -> String:
	if MDF6.has(c):
		return MDF6[c]
	if c.begins_with("b") and c.length() > 1 and c.substr(1).is_valid_int():
		var i := int(c.substr(1))
		if i >= 0 and i < BOSS_IDS.size() and BMUS.has(BOSS_IDS[i]):
			return BMUS[BOSS_IDS[i]]
		return MDEF.b0
	if MDEF.has(c):
		return MDEF[c]
	if c.begins_with("s") and c.substr(1).is_valid_int():
		return MDEF["s%d" % (int(c.substr(1)) % 5)]
	return ""


func pick(c: String) -> String:
	var um := _user_map()
	if um.has(c):
		var id: String = um[c]
		if id == "-" or tracks.has(id):
			return id
	return default_for(c)


func set_choice(c: String, id: String) -> void:
	var um := _user_map()
	if id == default_for(c):
		um.erase(c)
	else:
		um[c] = id
	var parts: Array[String] = []
	for k in um.keys():
		parts.append("%s:%s" % [k, um[k]])
	Settings.s.mmap = ",".join(parts)
	Settings.persist()


func contexts() -> Array:
	var L := [["title", "Tela inicial"]]
	var zn := ["NÚCLEO", "VÓRTEX", "FORJA", "ABISMO", "SINGULARIDADE"]
	for i in 5:
		L.append(["s%d" % i, "Setor %d · %s" % [i + 1, zn[i]]])
	var bn := ["RHINO", "DRÁCULA", "VESPERON", "ILLUMINATTI", "ANOMALIA", "ESPELHO"]
	for i in 6:
		L.append(["b%d" % i, "Chefe · " + bn[i]])
	L.append(["bv1", "Chefe · VESPERON (fase 1, ambiência)"])
	L.append(["sx_fenda", "Fenda Infinita"])
	L.append(["win", "Vitória"])
	L.append(["over", "Fim de jogo"])
	return L


func _id_for(c: String) -> String:
	if c == "pv":
		return preview
	if c == "" or c == "rest":
		return ""
	var id := pick(c)
	if id == "-" or not tracks.has(id) or stream_for(id) == null:
		return ""
	return id


## Tempos de saída/entrada conforme o momento novo e o anterior (FD do HTML).
func _fd(c: String, p: String) -> Array:
	if c == "pv" or p == "pv":
		return [0.3, 0.25]
	if c == "":
		return [0.6, 0.5]
	if c.begins_with("b"):
		return [0.6, 0.15]
	match c:
		"win": return [1.0, 0.4]
		"over": return [1.2, 2.5]
		"rest": return [2.6, 1.0]
		"title": return [1.0, 1.5]
	if p == "rest" or p == "title" or p == "":
		return [1.0, 1.0]
	return [1.8, 1.8]


func _free_deck() -> int:
	var k := -1
	for i in _decks.size():
		if i != _ci and (k < 0 or _decks[i].g < _decks[k].g):
			k = i
	return k


func _halt(d: Dictionary) -> void:
	(d.p as AudioStreamPlayer).stop()
	d.id = ""
	d.g = 0.0
	d.tg = 0.0
	d.fin = false


func _pos(d: Dictionary) -> float:
	var t: Dictionary = tracks.get(d.id, {})
	var p := (d.p as AudioStreamPlayer).get_playback_position()
	return maxf(0.0, p - float(t.get("a", 0.0)))


func _start(d: Dictionary, id: String, off: float) -> bool:
	_halt(d)
	var s := stream_for(id)
	if s == null:
		return false
	d.id = id
	var p: AudioStreamPlayer = d.p
	p.stream = s
	p.volume_db = -80.0
	p.play(float(tracks[id].a) + off)
	return true


func _go(id: String, c: String) -> void:
	var D: Dictionary = _decks[_ci]
	var f := _fd(c, _pc)
	if D.id != "" and D.tg > 0.0 and D.id != id:
		if D.c != "pv":
			_mpos[D.id] = _pos(D)
		D.tg = 0.0
		D.sp = 1.0 / f[0]
	if id == "":
		return
	var k := -1
	for i in _decks.size():
		if _decks[i].id == id and not _decks[i].fin:
			k = i
			break
	if k < 0:
		k = _free_deck()
		var t: Dictionary = tracks[id]
		var p: float = _mpos.get(id, 0.0)
		var off := p if ((c.begins_with("s") or c == "title") and p > 0.0 and p < float(t.ln) - 12.0) else 0.0
		if not _start(_decks[k], id, off):
			return
	_decks[k].c = c
	_decks[k].tg = 1.0
	_decks[k].sp = 1.0 / maxf(0.15, f[1])
	_ci = k


## Faixas sem ponto de loop: perto do fim, a mesma faixa entra em outro deck com crossfade.
func _loop_check(D: Dictionary) -> void:
	if D.fin or D.id == "":
		return
	var t: Dictionary = tracks[D.id]
	if t.lp:
		return
	var p: AudioStreamPlayer = D.p
	var du: float = p.stream.get_length() if p.stream else 0.0
	if du <= 0.0:
		return
	var x := minf(2.4, du * 0.1)
	var rem := du - p.get_playback_position()
	if not p.playing:
		p.play(0.0)
		return
	if rem > x:
		return
	var k := _free_deck()
	var N: Dictionary = _decks[k]
	if not _start(N, D.id, 0.0):
		return
	N.c = D.c
	N.tg = 1.0
	N.sp = 2.0
	D.tg = 0.0
	D.sp = 1.0 / x
	_ci = k


func now_playing() -> String:
	if _amb_lvl > 0.02 and _cx in AMBC:
		return "Ambiência sintetizada"
	if not Settings.s.mreal and _cx != "pv":
		return "Trilha real desligada"
	var D: Dictionary = _decks[_ci]
	if D.id == "" or D.tg <= 0.0:
		return "Silêncio" if Settings.s.sound and Settings.s.music > 0 else "Música sem volume"
	return "♪ " + String(tracks[D.id].title) + (" (prévia)" if _cx == "pv" else "")


func _process(delta: float) -> void:
	var dt := minf(0.25, delta)
	var on: bool = Settings.s.mreal
	var c := "pv" if preview != "" else (context if on else "")
	if c != _cx:
		_pc = _cx
		_cx = c
	var vol: float = float(Settings.s.music) if Settings.s.sound else 0.0
	if vol > 0.0:
		_zt = 0.0
	else:
		_zt += dt
	var ss := _zt > 0.6
	if ss != _sus:
		_sus = ss
		for d in _decks:
			if d.id != "":
				(d.p as AudioStreamPlayer).stream_paused = ss
	var id := _id_for(c)
	var D: Dictionary = _decks[_ci]
	if id != (D.id if D.tg > 0.0 else ""):
		_go(id, c)
	elif id != "" and not _sus:
		_loop_check(D)
	var dk := 1.0
	if (c.begins_with("s") or c.begins_with("b") or c == "rest") and (paused or soft_paused):
		dk = 0.35 if paused else 0.6
	_duck += (dk - _duck) * minf(1.0, dt * 7.0)
	for d in _decks:
		if d.id == "":
			continue
		if d.g != d.tg:
			var s: float = d.sp * dt
			d.g = minf(d.tg, d.g + s) if d.g < d.tg else maxf(d.tg, d.g - s)
		if d.g <= 0.0 and d.tg <= 0.0:
			_halt(d)
			continue
		var v := clampf(vol * _duck * sin(d.g * PI * 0.5), 0.0, 1.0)
		(d.p as AudioStreamPlayer).volume_db = linear_to_db(maxf(v, 0.00001))
	_amb_tick(dt, vol)


# ---------- ambiência 'cinza' (vento de cinzas, bordão grave e estalos de brasa) ----------
func _amb_tick(dt: float, vol: float) -> void:
	var want := ""
	if AMBC.has(_cx):
		var id := pick(_cx)
		if id == "-" or id == "" or not tracks.has(id):
			want = AMBC[_cx]
	var tgt := vol * 0.55 * (0.4 if paused else 1.0) * Settings.sfx_volume() if want != "" else 0.0
	if want != "" and _amb_stream == null and not _amb_building:
		_amb_building = true
		_amb_task = WorkerThreadPool.add_task(_amb_build)
	_amb_lvl += (tgt - _amb_lvl) * minf(1.0, dt * (0.9 if tgt > _amb_lvl else 1.6))
	if _amb_lvl < 0.0005 and tgt == 0.0:
		_amb_lvl = 0.0
	if _amb_stream != null:
		if _amb_lvl > 0.0 and not _amb_player.playing:
			_amb_player.stream = _amb_stream
			_amb_player.play()
		elif _amb_lvl <= 0.0 and _amb_player.playing:
			_amb_player.stop()
		_amb_player.volume_db = linear_to_db(maxf(_amb_lvl, 0.00001))
		if _amb_lvl > 0.01 and not paused and not _amb_crackles.is_empty():
			_amb_next -= dt
			if _amb_next <= 0.0:
				_amb_next = (0.03 + randf() * 0.05) if randf() < 0.25 else (0.15 + randf() * 0.6)
				var q: AudioStreamPlayer = _amb_pool[randi() % _amb_pool.size()]
				q.stream = _amb_crackles[randi() % _amb_crackles.size()]
				q.volume_db = linear_to_db(maxf(_amb_lvl, 0.00001))
				q.play()


func _amb_build() -> void:
	var R := 22050
	var L := 30.0   # 30 s: as LFOs foram quantizadas para ciclos inteiros e o loop não tem emenda
	var n := int(R * L)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	# ruído rosado aproximado (w*.6 + p*2.2) como no ambNoise do HTML
	var noise := PackedFloat32Array()
	noise.resize(n)
	var pp := 0.0
	for i in n:
		var w := rng.randf() * 2.0 - 1.0
		pp = pp * 0.97 + w * 0.03
		noise[i] = w * 0.6 + pp * 2.2
	var bp := _Biquad.new()
	var hp := _Biquad.new()
	var lp := _Biquad.new()
	lp.set_lowpass(240.0, 0.707, R)
	hp.set_highpass(3200.0, 0.5, R)
	var f1 := 2.0 / L
	var f2 := 3.0 / L
	var f3 := 2.0 / L
	var f4 := 3.0 / L
	var ph55 := 0.0
	var ph82 := 0.0
	var ph554 := 0.0
	for i in n:
		var t := float(i) / R
		if i % 64 == 0:
			bp.set_bandpass(420.0 + 260.0 * sin(TAU * f1 * t), 0.7, R)
		var wind := bp.process(noise[i]) * (0.32 + 0.14 * sin(TAU * f2 * t))
		var hiss := hp.process(noise[(i * 7) % n]) * (0.035 + 0.02 * sin(TAU * f3 * t))
		var drone := sin(ph55 * TAU) * 0.22 + (4.0 * absf(ph82 - 0.5) - 1.0) * (0.09 + 0.06 * sin(TAU * f4 * t)) + sin(ph554 * TAU) * 0.12
		ph55 = fposmod(ph55 + 55.0 / R, 1.0)
		ph82 = fposmod(ph82 + 82.41 * pow(2.0, 6.0 / 1200.0) / R, 1.0)
		ph554 = fposmod(ph554 + 55.4 / R, 1.0)
		buf[i] = wind + hiss + lp.process(drone)
	# emenda: mistura os primeiros 0,5 s com o fim
	var xf := int(R * 0.5)
	for i in xf:
		var k := float(i) / xf
		buf[i] = buf[i] * k + buf[n - xf + i] * (1.0 - k)
	buf.resize(n - xf)
	var w := _wav(buf, R)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = buf.size()
	var cr: Array[AudioStreamWAV] = []
	for v in 6:
		var dur := 0.004 + rng.randf() * 0.012
		var m := int(dur * R) + 8
		var b := PackedFloat32Array()
		b.resize(m)
		var h := _Biquad.new()
		h.set_highpass(1500.0 + rng.randf() * 3000.0, 0.707, R)
		var vv := 0.05 + rng.randf() * 0.22
		for i in m:
			var env := vv * pow(0.0005 / vv, float(i) / m)
			b[i] = h.process(noise[(v * 9973 + i) % n]) * env
		cr.append(_wav(b, R))
	call_deferred("_amb_ready", w, cr)


func _amb_ready(w: AudioStreamWAV, cr: Array[AudioStreamWAV]) -> void:
	_amb_stream = w
	_amb_crackles = cr
	_amb_building = false


func _wav(buf: PackedFloat32Array, rate: int) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = bytes
	return w


## Filtro biquad (RBJ) usado na síntese da ambiência.
class _Biquad:
	var b0 := 1.0
	var b1 := 0.0
	var b2 := 0.0
	var a1 := 0.0
	var a2 := 0.0
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0

	func _coef(nb0: float, nb1: float, nb2: float, na0: float, na1: float, na2: float) -> void:
		b0 = nb0 / na0
		b1 = nb1 / na0
		b2 = nb2 / na0
		a1 = na1 / na0
		a2 = na2 / na0

	func set_lowpass(f: float, q: float, r: int) -> void:
		var w := TAU * f / r
		var al := sin(w) / (2.0 * q)
		var c := cos(w)
		_coef((1.0 - c) / 2.0, 1.0 - c, (1.0 - c) / 2.0, 1.0 + al, -2.0 * c, 1.0 - al)

	func set_highpass(f: float, q: float, r: int) -> void:
		var w := TAU * f / r
		var al := sin(w) / (2.0 * q)
		var c := cos(w)
		_coef((1.0 + c) / 2.0, -(1.0 + c), (1.0 + c) / 2.0, 1.0 + al, -2.0 * c, 1.0 - al)

	func set_bandpass(f: float, q: float, r: int) -> void:
		var w := TAU * f / r
		var al := sin(w) / (2.0 * q)
		var c := cos(w)
		_coef(al, 0.0, -al, 1.0 + al, -2.0 * c, 1.0 - al)

	func process(x: float) -> float:
		var y := b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		return y
