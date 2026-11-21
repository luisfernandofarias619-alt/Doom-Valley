class_name BossRhino
extends BossBase
## RHINO (v4.2 do HTML): máquina de estados entry → track ⇄ prep → (charge | attack) → recover → track;
## stun (parede/pilar); rage (transformação Berserker ≤50%); surto ≤20%.
## Golpes: investida, investida pesada, derrapagem, finta, pisão, chifrada ascendente, varredura, lascas,
## fissura e chuva de pedras. Escolha ponderada por distância, espaço, histórico, recarga e vida; combos na fase 2.
## Só sprites laterais espelhados; poses vêm de d.fr (golpes) ou da velocidade.

const RHC := {
	"walk": [88.0, 108.0, 122.0], "trot": [165.0, 190.0, 208.0], "runAt": 140.0, "accel": 340.0, "ideal": [240.0, 200.0, 170.0], "gap": [0.9, 0.55, 0.35],
	"vuln": {"rec": 1.3, "stun": 1.55},
	"rec": {"charge": 0.75, "heavy": 1.3, "drift": 0.9, "feint": 0.8, "stomp": 0.85, "gore": 0.7, "upper": 0.65, "shards": 0.55, "fissure": 0.5, "rocks": 0.5},
	"ch": {"wind": 0.95, "lock": 0.3, "v0": 130.0, "vmax": 520.0, "acc": 640.0, "turn": 1.15, "max": 1.9, "dmg": 30.0, "hit": 0.78, "wall": 1.3, "ring": 150.0, "rocks": 4, "feint": 0.36},
	"hv": {"wind": 1.45, "lock": 0.35, "v0": 110.0, "vmax": 650.0, "acc": 760.0, "turn": 0.55, "max": 2.1, "dmg": 48.0, "hit": 0.95, "wall": 2.0, "ring": 195.0, "rocks": 6, "feint": 0.0},
	"sk": {"wind": 0.9, "r": [185.0, 200.0, 215.0], "dmg": 20.0, "gap2": 0.55, "reach": 120.0},
	"up": {"wind": [0.62, 0.5, 0.42], "reach": 135.0, "r": 92.0, "dmg": 26.0, "rocks": [3, 4, 5], "lunge": 380.0},
	"gore": {"wind": [0.85, 0.72, 0.62], "om": [2.7, 3.1, 3.4], "dmg": 52.0},
	"rage": {"t": 2.4, "push": 300.0, "pushR": 240.0}, "lean": 0.2,
}
## [id, distância mínima, máxima, peso, recarga, fase mínima]
const RHP := [["charge", 190.0, 1e4, 3.0, 5.0, 0], ["heavy", 300.0, 1e4, 1.5, 16.0, 0], ["drift", 210.0, 1e4, 0.55, 22.0, 1],
	["feint", 190.0, 1e4, 1.8, 10.0, 1], ["stomp", 0.0, 330.0, 2.1, 7.0, 0], ["gore", 0.0, 250.0, 2.6, 5.0, 0], ["upper", 0.0, 215.0, 2.6, 5.0, 0],
	["shards", 230.0, 1e4, 1.9, 7.0, 0], ["fissure", 150.0, 1e4, 1.6, 9.0, 0], ["rocks", 0.0, 1e4, 1.1, 14.0, 0]]
const CHF := ["charge", "heavy", "drift", "feint"]
const COMBO := {"gore": ["upper", "stomp"], "upper": ["gore"], "stomp": ["gore", "upper"]}
const DUST := Color("#c9b28a")

var ground: Array[Dictionary] = []   # RHG: linhas de velocidade e explosões no chão
var deaths: Array[Dictionary] = []   # DFX: quadros de morte onde ele caiu
static var tint_tex: Texture2D = null
static var _tinting := false


func _init(game) -> void:
	super(game)
	_make_tint()


## Berserker: versão "aquecida" do atlas (rhTint): runas mais quentes, armadura mais escura. Gerada numa thread.
static func _make_tint() -> void:
	if tint_tex != null or _tinting or Assets.rhino_tex == null:
		return
	_tinting = true
	var img := Assets.rhino_tex.get_image()
	if img == null:
		return
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	WorkerThreadPool.add_task(func():
		var d := img.get_data()
		var n := d.size()
		var i := 0
		while i < n:
			if d[i + 3] != 0:
				var r := d[i]
				var gg := d[i + 1]
				var b := d[i + 2]
				if r > gg * 1.5 and r > b * 1.5:
					d[i] = mini(255, int(r * 1.12 + 45))
					d[i + 1] = mini(255, int(gg + r * 0.4))
					d[i + 2] = int(b * 0.55)
				else:
					d[i] = mini(255, int(r * 1.1 + 12))
					d[i + 1] = int(gg * 0.8)
					d[i + 2] = int(b * 0.78)
			i += 4
		var out := Image.create_from_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, d)
		BossRhino._tint_ready.call_deferred(out))


static func _tint_ready(img: Image) -> void:
	tint_tex = ImageTexture.create_from_image(img)


func clear_visuals() -> void:
	ground.clear()
	deaths.clear()


func on_spawn(b: Enemy) -> void:
	b.d = {"st": "entry", "sT": 0.0, "s": 0, "cur": "", "pt": 0.0, "fr": null, "vx": 0.0, "vy": 0.0, "fa": 0.0, "hist": [], "last": {},
		"pvx": 0.0, "pvy": 0.0, "in": false, "rg": false, "bt": 0.0, "sw": -1, "fx": 1.0, "nx": "", "jx": 0.0}


# ======================================================================
# utilidades
# ======================================================================
func _S(b: Enemy, s: String) -> void:
	if b.d.st != s:
		b.d.st = s
		b.d.sT = 0.0


func _vel(b: Enemy, dt: float, tx: float, ty: float, ac: float) -> void:
	var ax: float = tx - b.d.vx
	var ay: float = ty - b.d.vy
	var l := sqrt(ax * ax + ay * ay)
	if l > 0.001:
		var m := minf(l, ac * dt) / l
		b.d.vx += ax * m
		b.d.vy += ay * m


func _solid(b: Enemy) -> int:
	var ar: ArenaSystem = g.arena
	if ar.near.is_empty():
		return 0
	var r := b.radius * 0.78
	var res := 0
	for o in ar.near.duplicate():
		if not o.get("solid", false) or o.get("dead", false):
			continue
		var q = ArenaSystem.push_out(o, b.x, b.y, r)
		if q == null:
			continue
		if b.chg2 and float(b.d.get("cv", 0.0)) > 60.0 and (o.k == "caixa" or o.k == "barril"):
			ar.obj_break(o)   # atropela caixas e barris durante a investida
			b.d.cv *= 0.82
			g.shake(3.0)
			continue
		b.x += q[0] * q[2]
		b.y += q[1] * q[2]
		var vn: float = b.d.vx * q[0] + b.d.vy * q[1]
		if vn < 0.0:
			b.d.vx -= vn * q[0]
			b.d.vy -= vn * q[1]
		if b.chg2 and float(b.d.get("cv", 0.0)) > 120.0:
			b.d.hitO = o
			b.d.hitN = [q[0], q[1]]
			res = 2   # pilar ou entulho: bate de verdade
	return res


func _move(b: Enemy, dt: float) -> int:
	var A := box()
	var m := maxf(40.0, b.radius * 0.9)
	var x0 := A.position.x + m
	var x1 := A.end.x - m
	var y0 := A.position.y + m
	var y1 := A.end.y - m
	b.x += b.d.vx * dt
	b.y += b.d.vy * dt
	var w := 0
	if b.x < x0:
		b.x = x0; w = 1; b.d.hitN = [1.0, 0.0]
		if b.d.vx < 0.0: b.d.vx = 0.0
	elif b.x > x1:
		b.x = x1; w = 1; b.d.hitN = [-1.0, 0.0]
		if b.d.vx > 0.0: b.d.vx = 0.0
	if b.y < y0:
		b.y = y0; w = 1; b.d.hitN = [0.0, 1.0]
		if b.d.vy < 0.0: b.d.vy = 0.0
	elif b.y > y1:
		b.y = y1; w = 1; b.d.hitN = [0.0, -1.0]
		if b.d.vy > 0.0: b.d.vy = 0.0
	if w:
		b.d.hitO = null
	var s := _solid(b)
	return w if w else s


func _stand(b: Enemy, dt: float) -> void:
	_vel(b, dt, 0.0, 0.0, RHC.accel * 3.0)
	_move(b, dt)


static func _atk(t: float, tf: float) -> int:
	if t < tf:
		return mini(2, int(t / tf * 3.0))
	if t < tf + 0.45:
		return 3 + mini(2, int((t - tf) / 0.45 * 3.0))
	return 6 + (int((t - tf - 0.45) * 4.0) & 1)


func _floor_y(b: Enemy) -> float:
	return b.y + 38.0 * b.sc


func _crack(x: float, y: float, n: int, length: float) -> void:
	g.arena.crack(x, y, 2 if n >= 6 else 1, n, length)


func _streak(x: float, y: float, a: float) -> void:
	if Settings.s.q < 1:
		return
	var n := 0
	for gq in ground:
		if gq.k == 1:
			n += 1
	if n < 18:
		ground.append({"k": 1, "x": x, "y": y, "a": a, "l": 50.0 + randf() * 60.0, "t": 0.0, "life": 0.3})


func _bang(x: float, y: float, s: float) -> void:
	ground.append({"k": 2, "x": x, "y": y, "s": s, "t": 0.0, "life": 0.45})


func _obs(b: Enemy, dt: float) -> void:
	var P: PlayerState = g.player
	if b.d.has("px"):
		var k := minf(1.0, dt * 6.0)
		var vx := clampf((P.x - b.d.px) / maxf(dt, 0.001), -400.0, 400.0)
		var vy := clampf((P.y - b.d.py) / maxf(dt, 0.001), -400.0, 400.0)
		b.d.pvx += (vx - b.d.pvx) * k
		b.d.pvy += (vy - b.d.pvy) * k
	b.d.px = P.x
	b.d.py = P.y


func _steps(b: Enemy) -> void:
	var sp := b.spd
	if sp < 35.0:
		return
	var w := int(b.wph / 4.0)
	if w != b.d.sw:
		b.d.sw = w
		g.sfx("rhstep")
		var fast: bool = sp > RHC.runAt
		g.fx.burst(b.x - cos(b.d.fa) * 30.0, _floor_y(b), DUST, 4 if fast else 2, 130.0 if fast else 70.0, 3.0)
		if fast:
			g.shake(0.5)


# ======================================================================
# investidas
# ======================================================================
func _drift_check(b: Enemy, V: Dictionary) -> bool:
	var dx: float = g.player.x - b.x
	var dy: float = g.player.y - b.y
	var c := cos(b.d.ca)
	var s := sin(b.d.ca)
	var al := dx * c + dy * s
	var la := -dx * s + dy * c
	return al > -110.0 and al < 300.0 and absf(la) > b.radius * V.hit + g.player.radius + 6.0


func _impact(b: Enemy, V: Dictionary) -> void:
	var n: Array = b.d.get("hitN", [0.0, 0.0])
	var o = b.d.get("hitO")
	var hv: bool = V == RHC.hv
	var cx: float = b.x - n[0] * b.radius * 0.9
	var cy: float = b.y - n[1] * b.radius * 0.9
	if o != null:
		if o.k == "pilar":
			o.hits = int(o.get("hits", 0)) + 1
			if o.hits >= 2:
				_pillar_falls(o, n)
			else:
				o.dm = mini(3, int(o.get("dm", 0)) + (2 if hv else 1))
				o.fl = 0.15
		else:
			o.dead = true
			g.fx.burst(o.x, o.y, Color("#8a8f99"), 22, 260.0, 4.0)
		g.fx.burst(cx, cy, DUST, 16, 240.0, 3.0)
	else:
		g.arena.wall_hit(cx, cy, 3.0 if hv else 1.5)
	_crack(cx + n[0] * 6.0, cy + n[1] * 6.0, 6, 130.0)
	_bang(cx, cy, 1.3)
	b.d.hitO = null


## O pilar da contenção cai depois de duas batidas do Rhino (NF.pilarCai).
func _pillar_falls(o: Dictionary, n: Array) -> void:
	o.dead = true
	g.sfx("rhslam")
	g.shake(9.0)
	g.hitstop(0.06)
	g.fx.burst(o.x, o.y, Color("#8a8f99"), 34, 300.0, 4.0)
	g.fx.burst(o.x, o.y, DUST, 16, 200.0, 3.0)
	g.arena.crack(o.x, o.y, 2, 6, 90.0)
	var A = g.arena.cur
	if A != null:
		A.obj.append({"k": "entulho", "x": o.x - n[0] * 30.0, "y": o.y - n[1] * 30.0, "r": 30.0, "solid": true, "v": randi() % 3})
	g.banner("O PILAR DESABOU", DUST, 1.4)


func _wall(b: Enemy, V: Dictionary, ph: int) -> void:
	b.stun = V.wall
	_S(b, "stun")
	b.chg2 = false
	b.d.cv = 0.0
	b.d.vx = 0.0
	b.d.vy = 0.0
	b.d.fr = null
	g.shake(15.0 if V == RHC.hv else 11.0)
	g.hitstop(0.09)
	g.sfx("rhslam")
	g.sfx("rhstun")
	hz({"k": "r", "x": b.x, "y": b.y, "r": V.ring, "tw": 0.0, "ta": 0.5, "dmg": 18.0, "col": Color("#ffb36b")})
	var B := box()
	for i in int(V.rocks) + ph:
		var a := randf() * TAU
		var d := 90.0 + randf() * 240.0
		hz({"k": "c", "x": clampf(b.x + cos(a) * d, B.position.x + 50.0, B.end.x - 50.0), "y": clampf(b.y + sin(a) * d, B.position.y + 50.0, B.end.y - 50.0), "r": 36.0, "tw": 0.8 + i * 0.1, "ta": 0.22, "dmg": 14.0, "col": DUST})
	hz({"k": "c", "x": g.player.x, "y": g.player.y, "r": 36.0, "tw": 1.15, "ta": 0.22, "dmg": 14.0, "col": DUST})   # uma pedra cai onde o jogador está
	g.fx.burst(b.x, b.y, DUST, 26, 280.0, 4.0)
	g.fx.ripple(b.x, b.y, 20.0, V.ring, Color("#ffb36b"), 0.8, 0.5)
	_impact(b, V)


## Investida com rumo fixo: a mira acompanha o jogador só na preparação; ao travar, a faixa fica vermelha.
## Derrapagem: freia sem virar, mira de novo e corre outra vez. Batida em parede ou pilar: fica preso.
func _charge(b: Enemy, dt: float, ph: int, V: Dictionary, kind: String) -> bool:
	var D: Dictionary = b.d
	var wind: float = V.wind * (0.85 if ph > 0 else 1.0)
	var heavy := kind == "heavy"
	var lock: float = maxf(V.lock, 0.5 if heavy else 0.42)
	var lw: float = 2.0 * (b.radius * V.hit + g.player.radius * 0.6)
	if D.s == 0:
		D.s = 1
		b.chg2 = true
		_S(b, "prep")
		D.ca = ang_to_player(b)
		D.fa = D.ca
		D.cv = 0.0
		D.hitc = false
		D.dr = false
		D.rt = 0.0
		D.lk = false
		D.lane = hz({"k": "b", "src": b, "ang": D.ca, "om": 0.0, "len": 1400.0, "w": lw, "tw": wind, "ta": 0.02, "dmg": 0.0, "col": Color("#ff7a3a") if heavy else Color("#ffb36b")})
		g.sfx("rhroar" if heavy else "rhsnort")
	if D.s == 1 or D.s == 7:
		_stand(b, dt)
		var re: bool = D.s == 7
		var W: float = 0.62 if re else wind
		var L: float = 0.26 if re else lock
		var pt: float
		if re:
			D.at += dt
			pt = D.at
		else:
			pt = D.pt
		if pt < W - L:
			var m: float = V.turn * 2.0 * dt
			D.ca += clampf(angle_difference(D.ca, ang_to_player(b)), -m, m)
		elif not D.lk:
			D.lk = true
			if not D.lane.is_empty():
				D.lane.col = Color("#ff2244")
			g.sfx("rhdrift")
		D.fa = D.ca
		if not D.lane.is_empty():
			D.lane.ang = D.ca
		D.fr = ["attack", 2] if re else (["extras", 0] if heavy and D.pt < 0.55 else ["attack", mini(2, int(pt / W * 3.0))])
		if randf() < dt * 14.0:
			g.fx.burst(b.x + (randf() - 0.5) * 50.0, _floor_y(b), DUST, 2, 90.0, 3.0)
		if pt >= W:
			D.s = 2
			D.rt = 0.0
			D.lk = false
			D.cv = V.v0 * 1.5 if re else V.v0
			_S(b, "charge")
			g.sfx("rhrush")
			g.shake(3.0)
	if D.s == 2:
		D.rt += dt
		D.cv = minf(V.vmax * (0.9 if D.dr else 1.0), D.cv + V.acc * dt)
		D.fa = D.ca
		D.vx = cos(D.ca) * D.cv
		D.vy = sin(D.ca) * D.cv
		var wall := _move(b, dt)
		D.fr = ["charge", 0 if D.rt < 0.15 else (3 if D.cv / V.vmax > 0.72 else 1) + (int(b.t * 13.0) & 1)]
		if randf() < dt * 34.0:
			g.fx.burst(b.x - cos(D.ca) * 40.0, _floor_y(b), DUST, 2, 110.0, 3.0)
		if randf() < dt * 50.0:
			var bk := 50.0 + randf() * 30.0
			var lat := (randf() - 0.5) * 110.0
			_streak(b.x - cos(D.ca) * bk - sin(D.ca) * lat, b.y - sin(D.ca) * bk + cos(D.ca) * lat, D.ca + PI)
		if not D.hitc and dist_to_player(b) < b.radius * V.hit + g.player.radius * 0.6:
			D.hitc = true
			g.take_damage(V.dmg * (1.0 + 0.12 * ph) * float(g.cfg.bossDmg), "melee")
			g.shake(9.0)
			g.hitstop(0.07)
			g.fx.burst(g.player.x, g.player.y, Color("#ff3344"), 10, 220.0)
			g.sfx("rhslam")
		for t in g.powers.TR:   # atropela as torretas
			if t.t < t.d and Vector2(t.x - b.x, t.y - b.y).length() < b.radius + 24.0:
				t.t = t.d
				g.fx.burst(t.x, t.y, Color("#00f2ff"), 16, 240.0)
				g.fx.ripple(t.x, t.y, 8.0, 46.0, Color("#00f2ff"), 0.8, 0.4)
				g.sfx("rhslam")
		if wall:
			_wall(b, V, ph)
			D.s = 4
		elif kind == "drift" and not D.dr and D.rt > 0.4 and _drift_check(b, V):
			D.dr = true
			D.s = 5
			g.sfx("rhdrift")
			g.shake(4.0)
		elif kind == "feint" and D.rt > V.feint:
			D.s = 6
			g.sfx("rhdrift")
		elif D.rt > (V.max * 0.65 if D.dr else V.max):
			D.s = 3
	if D.s == 3 or D.s == 5 or D.s == 6:
		D.cv = maxf(0.0, D.cv - (1700.0 if D.s == 3 else 2600.0) * dt)
		D.vx = cos(D.ca) * D.cv
		D.vy = sin(D.ca) * D.cv
		var wall := _move(b, dt)
		D.fr = ["charge", 1]
		if randf() < dt * 60.0:
			g.fx.burst(b.x - cos(D.ca) * 40.0, _floor_y(b), DUST, 3, 170.0, 3.0)
		if D.s == 5 and randf() < dt * 45.0:
			_streak(b.x + (randf() - 0.5) * 60.0, _floor_y(b), D.ca + PI)
		if wall and D.s != 6:
			_wall(b, V, ph)
			D.s = 4
		elif D.cv < 70.0:
			if D.s == 3:
				return true
			if D.s == 5:
				D.s = 7
				D.at = 0.0
				D.lk = false
				D.lane = hz({"k": "b", "src": b, "ang": D.ca, "om": 0.0, "len": 1400.0, "w": lw, "tw": 0.62, "ta": 0.02, "dmg": 0.0, "col": Color("#ff7a3a")})
				g.sfx("rhsnort")
			else:
				var d := dist_to_player(b)
				var nxt := "upper" if d < 150.0 else ("gore" if d < 260.0 else "stomp")
				_push_hist(b, nxt)
				D.cur = nxt
				D.pt = 0.0
				D.s = 0
				b.chg2 = false
				D.lane = {}
				return false
	if D.s == 4:
		D.vx = 0.0
		D.vy = 0.0
		if not D.has("stT") or D.stT == 0.0:
			D.stT = b.stun if b.stun > 0.0 else 1.0
		var T: float = D.stT
		var e := T - b.stun
		var n: Array = D.get("hitN", [0.0, 0.0])
		if e < 0.12:
			D.fr = ["hurt", 0]
		elif e < 0.26:
			D.fr = ["hurt", 1]
		elif b.stun > 0.32:
			D.fr = ["hurt", 2 + (int(e * 7.0) & 1)]
			D.jx = (randf() - 0.5) * 4.0
			if randf() < dt * 7.0:
				g.fx.burst(b.x - n[0] * (b.radius + 10.0), _floor_y(b), DUST, 2, 70.0, 3.0)
		else:
			D.fr = ["hurt", 4]
			D.jx = 0.0
			if not D.get("po", false):
				D.po = true
				D.pox = b.x
				D.poy = b.y
				g.sfx("rhstep")
				g.fx.burst(b.x - n[0] * (b.radius + 16.0), b.y - n[1] * (b.radius + 16.0), Color("#8a8f99"), 9, 160.0, 3.0)
			var k := 1.0 - maxf(0.0, b.stun) / 0.32
			var q := k * (2.0 - k)
			b.x = D.pox + n[0] * 30.0 * q
			b.y = D.poy + n[1] * 30.0 * q
		if b.stun <= 0.0:
			D.jx = 0.0
			D.po = false
			D.stT = 0.0
			return true
	return false


# ======================================================================
# golpes de impacto e de zona
# ======================================================================
func _stomp(b: Enemy, dt: float, ph: int) -> bool:
	var D: Dictionary = b.d
	var K: Dictionary = RHC.sk
	var B := box()
	var r: float = minf(K.r[ph], B.size.y * 0.46)
	var wind: float = K.wind * (0.88 if ph > 0 else 1.0)
	var slam := func(rr: float) -> void:
		hz({"k": "r", "x": b.x, "y": b.y, "r": rr, "tw": 0.0, "ta": 0.7, "dmg": K.dmg, "col": Color("#ff3344"), "rng": true})
		g.shake(11.0)
		g.hitstop(0.06)
		g.sfx("rhslam")
		g.fx.burst(b.x, b.y + 30.0, DUST, 30, 300.0, 4.0)
		_crack(b.x, _floor_y(b), 6, rr * 0.5)
	if D.s == 0:
		D.s = 1
		b.chg2 = true
		_S(b, "prep")
		var a := ang_to_player(b)
		var adv := minf(maxf(0.0, dist_to_player(b) - K.reach), 170.0)
		D.fa = a
		D.sx = clampf(b.x + cos(a) * adv, B.position.x + 60.0, B.end.x - 60.0)
		D.sy = clampf(b.y + sin(a) * adv, B.position.y + 60.0, B.end.y - 60.0)
		hz({"k": "c", "x": D.sx, "y": D.sy, "r": r, "tw": wind, "ta": 0.01, "dmg": 0.0, "col": Color("#ffb36b")})   # o aviso tem o raio real da onda
		g.sfx("rhsnort")
	if D.s == 1:
		D.vx = (D.sx - b.x) * 3.2
		D.vy = (D.sy - b.y) * 3.2
		_move(b, dt)
		D.fr = ["attack", mini(2, int(D.pt / wind * 3.0))]
		b.sc = 1.0 + 0.12 * minf(1.0, D.pt / wind)
		if D.pt >= wind:
			D.s = 2
			b.sc = 1.0
			D.vx = 0.0
			D.vy = 0.0
			_S(b, "attack")
			slam.call(r)
			if ph > 0:
				hz({"k": "c", "x": b.x, "y": b.y, "r": r + 35.0, "tw": K.gap2, "ta": 0.01, "dmg": 0.0, "col": Color("#ffb36b")})
	if D.s == 2:
		_stand(b, dt)
		D.fr = ["attack", 3 + mini(1, int((D.pt - wind) / 0.2))]
		if ph > 0 and D.pt >= wind + K.gap2:
			slam.call(r + 35.0)
			D.s = 3
		elif ph == 0 and D.pt >= wind + 0.55:
			b.chg2 = false
			return true
	if D.s == 3:
		_stand(b, dt)
		D.fr = ["attack", 5]
		if D.pt >= wind + K.gap2 + 0.45:
			b.chg2 = false
			return true
	return false


func _upper(b: Enemy, dt: float, ph: int) -> bool:
	var D: Dictionary = b.d
	var K: Dictionary = RHC.up
	var wind: float = K.wind[ph]
	var B := box()
	if D.s == 0:
		D.s = 1
		b.chg2 = true
		_S(b, "prep")
		var a := ang_to_player(b)
		D.fa = a
		D.ua = a
		D.ux = clampf(b.x + cos(a) * K.reach, B.position.x + 40.0, B.end.x - 40.0)
		D.uy = clampf(b.y + sin(a) * K.reach, B.position.y + 40.0, B.end.y - 40.0)
		hz({"k": "c", "x": D.ux, "y": D.uy, "r": K.r, "tw": wind, "ta": 0.14, "dmg": K.dmg, "col": Color("#ff7a3a"), "spk": true})
		g.sfx("rhsnort")
	if D.s == 1:
		_stand(b, dt)
		D.fr = ["attack", mini(2, int(D.pt / wind * 3.0))]
		if D.pt >= wind:
			D.s = 2
			_S(b, "attack")
			D.vx = cos(D.ua) * K.lunge
			D.vy = sin(D.ua) * K.lunge
			g.shake(8.0)
			g.hitstop(0.05)
			g.sfx("rhslam")
			g.fx.burst(D.ux, D.uy, DUST, 22, 320.0, 4.0)
			_crack(D.ux, D.uy, 4, 70.0)
			for i in int(K.rocks[ph]):
				var a2: float = D.ua + (randf() - 0.5) * 1.8
				var dd := 110.0 + randf() * 150.0
				hz({"k": "c", "x": clampf(b.x + cos(a2) * dd, B.position.x + 40.0, B.end.x - 40.0), "y": clampf(b.y + sin(a2) * dd, B.position.y + 40.0, B.end.y - 40.0), "r": 30.0, "tw": 0.5 + i * 0.09, "ta": 0.2, "dmg": 12.0, "col": DUST})
	if D.s == 2:
		_vel(b, dt, 0.0, 0.0, 1500.0)
		_move(b, dt)
		D.fr = ["attack", 4 + mini(1, int((D.pt - wind) / 0.22))]
		if D.pt >= wind + 0.6:
			b.chg2 = false
			return true
	return false


func _gore(b: Enemy, dt: float, ph: int) -> bool:
	var D: Dictionary = b.d
	var K: Dictionary = RHC.gore
	var wind: float = K.wind[ph]
	var om: float = K.om[ph]
	if D.s == 0:
		D.s = 1
		b.chg2 = true
		_S(b, "prep")
		D.fa = ang_to_player(b)
		hz({"k": "w", "src": b, "ang": D.fa, "om": 0.0, "len": 200.0, "r": 200.0, "half": 1.15, "tw": wind, "ta": 0.01, "dmg": 0.0, "col": Color("#ff7a3a")})
		g.sfx("rhsnort")
	if D.s == 1:
		_stand(b, dt)
		D.fr = ["attack", mini(2, int(D.pt / wind * 3.0))]
		if D.pt >= wind:
			D.s = 2
			_S(b, "attack")
			hz({"k": "b", "src": b, "ang": D.fa - 1.15, "om": om, "len": 200.0, "w": 70.0, "tw": 0.0, "ta": 2.3 / om, "dps": K.dmg, "col": Color("#ff3344"), "slash": true})
			D.vx = cos(D.fa) * 300.0
			D.vy = sin(D.fa) * 300.0
			g.shake(6.0)
			g.sfx("rhswing")
	if D.s == 2:
		_vel(b, dt, 0.0, 0.0, 900.0)
		_move(b, dt)
		D.fr = ["attack", 3 + mini(2, int((D.pt - wind) / 0.5 * 3.0))]
		if D.pt >= wind + 2.3 / om + 0.1:
			b.chg2 = false
			return true
	return false


func _shards(b: Enemy, dt: float, ph: int) -> bool:
	var D: Dictionary = b.d
	if D.s == 0:
		D.s = 1
		b.chg = 0.7
		_S(b, "prep")
		D.fa = ang_to_player(b)
		var n := 7 + ph * 2
		hz({"k": "w", "src": b, "ang": D.fa, "om": 0.0, "len": 520.0, "r": 520.0, "half": (n - 1) / 2.0 * 0.17 + 0.06, "tw": 0.7, "ta": 0.01, "dmg": 0.0, "col": Color("#ff3344")})
		g.sfx("rhsnort")
	_stand(b, dt)
	D.fr = ["attack", _atk(D.pt, 0.7)]
	if D.s == 1 and D.pt > 0.7:
		D.s = 2
		_S(b, "attack")
		var n := 7 + ph * 2
		for i in n:
			var p := bolt(b.x, b.y, D.fa + (i - (n - 1) / 2.0) * 0.17, 330.0 + (i % 2) * 60.0, Color("#ff3344"), 12.0, 6.0)
			p.shard = true
		g.shake(5.0)
		g.fx.burst(b.x, b.y, Color("#ff3344"), 14, 300.0)
	if D.s == 2 and D.pt > 1.25 and ph > 0:
		D.s = 3
		var n := 5 + ph * 2
		for i in n:
			var p := bolt(b.x, b.y, D.fa + (i - (n - 1) / 2.0) * 0.3, 300.0, Color("#ff7a3a"), 10.0, 6.0)
			p.shard = true
	return D.pt > 1.7


func _fissure(b: Enemy, dt: float, ph: int) -> bool:
	var D: Dictionary = b.d
	if D.s == 0:
		D.s = 1
		b.chg = 0.5
		_S(b, "prep")
		D.fa = ang_to_player(b)
		var a: float = D.fa
		var n := 6 + ph
		var st: float = g.arena.view_diag() / (n + 2)
		var B := box()
		for i in range(1, n + 1):
			hz({"k": "c", "x": clampf(b.x + cos(a) * st * i, B.position.x + 40.0, B.end.x - 40.0), "y": clampf(b.y + sin(a) * st * i, B.position.y + 40.0, B.end.y - 40.0), "r": 38.0, "tw": 0.6 + i * 0.12, "ta": 0.25, "dmg": 20.0, "col": Color("#ff3344"), "spk": true})
		g.sfx("rhsnort")
	_stand(b, dt)
	D.fr = ["attack", _atk(D.pt, 0.5)]
	if D.pt > 0.5:
		_S(b, "attack")
	return D.pt > 2.2


func _rocks(b: Enemy, dt: float, ph: int) -> bool:
	var D: Dictionary = b.d
	if D.s == 0:
		D.s = 1
		_S(b, "prep")
		g.sfx("rhroar")
		var z: Rect2 = g.arena.combat_rect()
		for i in 5 + ph * 2:
			hz({"k": "c", "x": z.position.x + 60.0 + randf() * (z.size.x - 120.0), "y": z.position.y + 60.0 + randf() * (z.size.y - 120.0), "r": 40.0, "tw": 0.9 + i * 0.08, "ta": 0.25, "dmg": 20.0, "col": DUST})
		hz({"k": "c", "x": g.player.x, "y": g.player.y, "r": 40.0, "tw": 1.2, "ta": 0.25, "dmg": 20.0, "col": DUST})
	_stand(b, dt)
	D.fr = ["extras", 0] if D.pt < 1.0 else null
	if D.pt > 1.0:
		_S(b, "attack")
	return D.pt > 2.2


func _run(b: Enemy, dt: float, ph: int) -> bool:
	match String(b.d.cur):
		"charge": return _charge(b, dt, ph, RHC.ch, "charge")
		"heavy": return _charge(b, dt, ph, RHC.hv, "heavy")
		"drift": return _charge(b, dt, ph, RHC.ch, "drift")
		"feint": return _charge(b, dt, ph, RHC.ch, "feint")
		"stomp": return _stomp(b, dt, ph)
		"upper": return _upper(b, dt, ph)
		"gore": return _gore(b, dt, ph)
		"shards": return _shards(b, dt, ph)
		"fissure": return _fissure(b, dt, ph)
		"rocks": return _rocks(b, dt, ph)
	return true


# ======================================================================
# decisão
# ======================================================================
func _push_hist(b: Enemy, id: String) -> void:
	var H: Array = b.d.hist
	H.append(id)
	if H.size() > 6:
		H.pop_front()
	b.d.last[id] = b.t


func _pick(b: Enemy, ph: int) -> String:
	var D: Dictionary = b.d
	var d := dist_to_player(b)
	var H: Array = D.hist
	var L: Dictionary = D.last
	var now := b.t
	var a := ang_to_player(b)
	var la: String = H[-1] if not H.is_empty() else ""
	var la2: String = H[-2] if H.size() >= 2 else ""
	var away: float = D.pvx * cos(a) + D.pvy * sin(a)
	var co := cos(a)
	var si := sin(a)
	var B := box()
	var dwx := 1e9
	if co > 0.001:
		dwx = (B.end.x - 50.0 - b.x) / co
	elif co < -0.001:
		dwx = (b.x - B.position.x - 50.0) / -co
	var dwy := 1e9
	if si > 0.001:
		dwy = (B.end.y - 50.0 - b.y) / si
	elif si < -0.001:
		dwy = (b.y - B.position.y - 50.0) / -si
	var room := minf(dwx, dwy) >= 130.0
	if ph > 0 and D.nx != "" and d < 330.0:
		var nx: String = D.nx
		D.nx = ""
		_push_hist(b, nx)
		return nx
	var tot := 0.0
	var w: Array[float] = []
	for e in RHP:
		var id: String = e[0]
		var d0: float = e[1]
		var d1: float = e[2]
		var s: float = e[3]
		if ph < e[5] or (la == id and la2 == id):   # nunca o mesmo golpe 3x seguidas
			w.append(0.0)
			continue
		if d < d0:
			s *= maxf(0.05, 1.0 - (d0 - d) / 90.0)
		elif d > d1:
			s *= maxf(0.05, 1.0 - (d - d1) / 160.0)
		if now - float(L.get(id, -99.0)) < e[4]:
			s *= 0.08
		if la == id:
			s *= 0.25
		elif H.slice(-3).has(id):
			s *= 0.6
		var cf := CHF.has(id)
		if cf and CHF.has(la) and CHF.has(la2):
			s *= 0.1
		if cf and not room:
			s *= 0.05
		if away > 90.0 and d > 260.0 and (cf or id == "shards"):
			s *= 1.45
		if d < 150.0 and (id == "upper" or id == "stomp" or id == "gore"):
			s *= 1.4
		if d < 150.0 and cf:
			s *= 0.4
		if b.hp < b.max_hp * 0.25 and (id == "drift" or id == "feint"):
			s *= 1.3
		tot += s
		w.append(s)
	if tot <= 0.0:
		return "charge"
	var r := randf() * tot
	var i := 0
	while i < w.size() - 1:
		r -= w[i]
		if r <= 0.0:
			break
		i += 1
	var pick: String = RHP[i][0]
	_push_hist(b, pick)
	if ph > 0 and COMBO.has(pick) and randf() < (0.55 if ph > 1 else 0.4):
		var c: Array = COMBO[pick]
		D.nx = c[randi() % c.size()]
	return pick


# ======================================================================
# IA
# ======================================================================
func ai(b: Enemy, dt: float, ph: int) -> void:
	var D: Dictionary = b.d
	b.radius = float(b.bd.r) * (1.06 if D.rg else 1.0)   # colisão acompanha o tamanho desenhado
	_obs(b, dt)
	D.sT += dt
	if not D.in:
		D.in = true
		_S(b, "track")
		b.cd = maxf(b.cd, 0.4)
		g.sfx("rhroar")
		g.shake(6.0)
	if D.rg and randf() < dt * 14.0:
		g.fx.p(b.x + (randf() - 0.5) * 90.0, b.y + 10.0, (randf() - 0.5) * 40.0, -70.0 - randf() * 60.0, 0.9, 3.0, Color("#ff5a3a"))
	if D.st == "rage":
		_rage(b, dt)
		return
	b.vuln = RHC.vuln.stun if D.st == "stun" else (RHC.vuln.rec if D.st == "recover" else 1.0)
	if D.cur != "":
		D.pt += dt
		if _run(b, dt, ph):
			var id: String = D.cur
			D.cur = ""
			D.s = 0
			D.fr = null
			b.chg2 = false
			D.lane = {}
			D.cv = 0.0
			_S(b, "recover")
			D.rt = 0.12 if D.nx != "" else float(RHC.rec.get(id, 0.75)) * (0.85 if ph else 1.0)
			b.cd = 0.05 if D.nx != "" else float(RHC.gap[ph]) * (0.85 + randf() * 0.3) / float(g.cfg.bossRate)
	elif D.st == "recover":
		_stand(b, dt)
		D.fa = ang_to_player(b)
		D.fr = ["attack", 6 + int(D.sT * 3.0) % 2]
		D.bt -= dt
		if D.bt <= 0.0:
			D.bt = 1.3
			g.sfx("rhbreath")
			g.fx.burst(b.x + (70.0 if D.fx < 0.0 else -70.0), b.y - 12.0, Color("#9aa3b8"), 2, 40.0, 3.0)
		if D.sT >= D.rt:
			D.fr = null
			_S(b, "track")
	else:
		_S(b, "track")
		var d := dist_to_player(b)
		var idl: float = RHC.ideal[ph]
		var a := atan2(g.player.y + D.pvy * 0.3 - b.y, g.player.x + D.pvx * 0.3 - b.x)
		D.fa = ang_to_player(b)
		var sp := 0.0
		if d > idl + 150.0:
			sp = RHC.trot[ph]
		elif d > idl:
			sp = float(RHC.walk[ph]) * clampf((d - idl) / 70.0, 0.35, 1.0)   # acelera longe, freia ao chegar
		_vel(b, dt, cos(a) * sp, sin(a) * sp, RHC.accel)
		_move(b, dt)
		_steps(b)
		if b.t > 1.6:
			b.cd -= dt
			if b.cd <= 0.0:
				D.cur = _pick(b, ph)
				D.pt = 0.0
				D.s = 0
	if b.vis != 0 and not b.chg2 and dist_to_player(b) < b.radius * 0.8 + g.player.radius:
		g.contact(float(b.bd.cd) * float(g.cfg.bossDmg), b)


## Fases: Força Bruta (>50%) → Berserker (≤50%, transformação) → surto (≤20%).
func on_phase(b: Enemy, ph: int) -> void:
	var D: Dictionary = b.d
	if not D.rg:
		_S(b, "rage")
		D.cur = ""
		D.s = 0
		D.fr = null
		b.chg2 = false
		D.lane = {}
		D.vx = 0.0
		D.vy = 0.0
		D.nx = ""
		D.rageT = RHC.rage.t
		D.rg = true
		b.inv = maxf(b.inv, RHC.rage.t)
		g.hazards.clear()
		g.enemy_projectiles.clear()
		g.banner("RHINO ENFURECIDO", Color("#ff3344"), 2.2)
		g.sfx("rhrage")
		g.shake(14.0)
		g.hitstop(0.14)
		D.rk = 0
	elif ph > 1:
		D.roarT = b.t + 0.9
		g.sfx("rhroar")
		g.shake(8.0)
		g.fx.ripple(b.x, b.y, 30.0, 260.0, Color("#ff3344"), 0.9, 0.7)
		g.fx.burst(b.x, b.y, Color("#ff5a3a"), 24, 300.0)


func _rage(b: Enemy, dt: float) -> void:
	var D: Dictionary = b.d
	var R: Dictionary = RHC.rage
	var k: float = 1.0 - D.rageT / R.t
	D.rageT -= dt
	b.inv = maxf(b.inv, 0.1)
	b.vuln = 1.0
	_stand(b, dt)
	D.fa = ang_to_player(b)
	b.sc = 1.0 + 0.12 * sin(minf(1.0, k * 2.5) * PI / 2.0)
	if randf() < dt * 45.0:
		g.fx.p(b.x + (randf() - 0.5) * 100.0, b.y + 10.0, (randf() - 0.5) * 60.0, -90.0 - randf() * 80.0, 1.0, 3.0, Color("#ff5a3a"))
	if k >= D.rk * 0.3 and D.rk < 3:
		D.rk += 1
		g.fx.ripple(b.x, b.y, 30.0, 200.0 + D.rk * 60.0, Color("#ff3344"), 0.9, 0.8)   # três ondas de choque visuais
		g.shake(5.0)
		_bang(b.x, b.y, 1.6)
	var d := dist_to_player(b)
	if d < R.pushR and k < 0.35:   # empurra o jogador para fora
		var f: float = (1.0 - d / R.pushR) * R.push * dt
		var a := ang_to_player(b)
		var B := box()
		g.player.x = clampf(g.player.x + cos(a) * f, B.position.x + 20.0, B.end.x - 20.0)
		g.player.y = clampf(g.player.y + sin(a) * f, B.position.y + 20.0, B.end.y - 20.0)
	if D.rageT <= 0.0:
		_S(b, "track")
		b.cd = 0.7
		b.sc = 1.0


func on_dead(b: Enemy) -> void:
	b.d.st = "dead"
	deaths.append({"x": b.x, "y": b.y, "fl": -1.0 if cos(b.d.fa) > 0.0 else 1.0, "t": 0.0})


func update_always(dt: float) -> void:
	for i in range(deaths.size() - 1, -1, -1):
		deaths[i].t += dt
		if deaths[i].t > 3.6:
			deaths.remove_at(i)
	for i in range(ground.size() - 1, -1, -1):
		var q: Dictionary = ground[i]
		q.t += dt
		if q.t >= q.life:
			ground.remove_at(i)


# ======================================================================
# desenho
# ======================================================================
func _frame(b: Enemy) -> Array:
	var D: Dictionary = b.d
	var t := b.t
	var st: String = D.st
	var sp := b.spd
	var wp := int(b.wph)
	if t < 1.3 or st == "rage" or (D.has("roarT") and t < D.roarT):
		return Assets.rhino_frame("extras", 0)
	if b.stun > 0.0:
		return Assets.rhino_frame(D.fr[0], D.fr[1]) if (D.s == 4 and D.fr != null) else Assets.rhino_frame("hurt", int(t * 6.0))
	if D.fr != null:
		return Assets.rhino_frame(D.fr[0], D.fr[1])
	if sp > 6.0:
		return Assets.rhino_frame("run", wp) if sp > RHC.runAt else Assets.rhino_frame("walk", wp)
	return Assets.rhino_frame("idle", int(t * 7.0))


func _base_xform(b: Enemy, f: Array) -> Transform2D:
	var D: Dictionary = b.d
	var cs := cos(D.fa)
	if absf(cs) > 0.25:
		D.fx = -1.0 if cs > 0.0 else 1.0
	var fl: float = D.fx
	var sp := b.spd
	var mvg := minf(1.0, sp / 200.0)
	var lean := 0.0 if Settings.s.reduce else -fl * RHC.lean * sin(atan2(D.vy, D.vx)) * mvg
	var bob := -absf(sin(int(b.wph) * 0.785)) * 2.2 if (sp > 6.0 and D.st != "charge") else sin(b.t * 2.4) * 1.1
	var bs := 1.06 if D.rg else 1.0
	return Transform2D(lean, Vector2(b.sc * bs, b.sc * bs), 0.0, Vector2(b.x + float(D.get("jx", 0.0)), b.y + bob))


func _blit(c: CanvasItem, M: Transform2D, f: Array, fl: float, ox: float, oy: float, al: float, tex: Texture2D) -> void:
	if f.is_empty() or tex == null:
		return
	var gyr: float = Assets.gyr
	c.draw_set_transform_matrix(M * Transform2D(0.0, Vector2(fl, 1.0), 0.0, Vector2(ox, oy)))
	c.draw_texture_rect_region(tex, Rect2(-float(f[4]), gyr - float(f[5]), f[2], f[3]), Rect2(f[0], f[1], f[2], f[3]), Color(1, 1, 1, al))


func draw(c: CanvasItem, b: Enemy) -> void:
	var f := _frame(b)
	if f.is_empty() or b.vis == 0:
		return
	var D: Dictionary = b.d
	var M := _base_xform(b, f)
	var fl: float = D.fx
	var gyr: float = Assets.gyr
	# sombra e anel dourado no chão (hora de bater)
	c.draw_set_transform_matrix(Transform2D(0.0, Vector2(b.sc * (1.06 if D.rg else 1.0), b.sc * (1.06 if D.rg else 1.0)), 0.0, M.origin))
	Draw.ellipse(c, Vector2(0, gyr - 1.0), f[2] * 0.3, 5.0, Color(0, 0, 0, 0.32 * b.al))
	if b.vuln > 1.0:
		Draw.ellipse_ring(c, Vector2(0, gyr - 1.0), f[2] * 0.42, 7.0, Draw.alpha(Color("#fff0a0") if D.st == "stun" else Color("#ffd27a"), (0.75 + 0.25 * sin(b.t * 12.0)) * b.al), 3.5)
	var tex: Texture2D = tint_tex if (D.rg and tint_tex != null) else Assets.rhino_tex
	if D.st == "charge":
		for j in [2, 1]:
			_blit(c, M, f, fl, -cos(D.fa) * 18.0 * j, -sin(D.fa) * 18.0 * j, 0.2 * b.al / j, tex)
	_blit(c, M, f, fl, 0.0, 0.0, b.al, tex)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)
	# atordoado: estrelas girando
	if D.st == "stun" and b.stun > 0.0:
		var tm: float = g.arena.cur.tm if g.arena.cur != null else b.t
		for i in 3:
			var a := tm * 5.0 + i * TAU / 3.0
			var x := roundf(b.x + cos(a) * 30.0)
			var y := roundf(b.y - 64.0 + sin(a) * 9.0)
			var al := 0.95 if sin(a) > 0.0 else 0.6
			c.draw_rect(Rect2(x - 5, y - 1, 11, 4), Color(0.23, 0.16, 0, al))
			c.draw_rect(Rect2(x - 1, y - 5, 4, 11), Color(0.23, 0.16, 0, al))
			c.draw_rect(Rect2(x - 4, y, 9, 2), Color(1, 0.88, 0.4, al))
			c.draw_rect(Rect2(x, y - 4, 2, 9), Color(1, 0.88, 0.4, al))
			c.draw_rect(Rect2(x, y, 2, 2), Color(1, 0.97, 0.76, al))


## Brilhos aditivos sobre o sprite: runas do Berserker, janela de dano extra e flash do acerto.
func draw_add(c: CanvasItem, b: Enemy) -> void:
	var f := _frame(b)
	if f.is_empty() or b.vis == 0:
		return
	var D: Dictionary = b.d
	var M := _base_xform(b, f)
	if D.rg and tint_tex != null:
		_blit(c, M, f, D.fx, 0.0, 0.0, 0.09 + 0.07 * sin(b.t * 9.0), tint_tex)
	if b.vuln > 1.0:
		_blit(c, M, f, D.fx, 0.0, 0.0, 0.2 + 0.15 * sin(b.t * 16.0), Assets.rhino_tex)
	if b.flash > 0.0:
		_blit(c, M, f, D.fx, 0.0, 0.0, b.flash * 0.7, Assets.rhino_tex)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)


## Linhas de velocidade e explosões no chão + quadros de morte.
func draw_ground(c: CanvasItem, _b) -> void:
	for q in ground:
		var u: float = q.t / q.life
		if q.k == 1:
			var e := Vector2(q.x + cos(q.a) * q.l * (1.0 - u * 0.5), q.y + sin(q.a) * q.l * (1.0 - u * 0.5))
			c.draw_line(Vector2(q.x, q.y), e, Color(1, 0.85, 0.75, (1.0 - u) * 0.5), 2.0, true)
		else:
			g.rhino_fx(c, 1, q.x, q.y, q.s * (0.6 + 0.6 * u), 1.0 - u)


func draw_top_always(c: CanvasItem) -> void:
	for d in deaths:
		var L: Array = Assets.rhino_frames.get("death", [])
		if L.is_empty():
			return
		var f: Array = L[mini(L.size() - 1, int(d.t / 0.42))]
		var al := clampf((3.6 - d.t) / 0.9, 0.0, 1.0)
		_blit(c, Transform2D(0.0, Vector2.ONE, 0.0, Vector2(d.x, d.y)), f, d.fl, 0.0, 0.0, al, Assets.rhino_tex)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)
