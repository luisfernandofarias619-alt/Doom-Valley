class_name ArenaSystem
extends RefCounted
## Arenas, câmera e transições (bloco 'v5.0: câmera, mundo independente da tela e sistema de arenas' do HTML).
## Fora de arena o mundo é a própria tela (modo Classic idêntico às versões antigas); numa arena o mundo tem o
## tamanho dela e a câmera acompanha o jogador com antecipação, enquadra o chefe e nunca mostra além das paredes.

const ASZ := {
	"pequena": [760.0, 760.0, "ARENA PEQUENA"], "media": [1100.0, 1200.0, "ARENA MÉDIA"],
	"grande": [1440.0, 1760.0, "ARENA GRANDE"], "extra": [2240.0, 2640.0, "ARENA EXTRA GRANDE"],
	"infinita": [200000.0, 200000.0, "ARENA INFINITA"],
}
const ARX := {
	"contencao": {"n": "Contenção", "tipo": "grande", "tema": "contencao", "cor": "#ff3344", "limites": "paredes", "jog": [0.5, 0.8]},
	"nucleo": {"n": "Núcleo", "tipo": "media", "tema": "energia", "cor": "#00f2ff", "limites": "energia", "jog": [0.5, 0.72]},
	"vortex": {"n": "Vórtex", "tipo": "grande", "tema": "energia", "cor": "#a06bff", "limites": "energia", "jog": [0.5, 0.7]},
	"abismo": {"n": "Abismo", "tipo": "extra", "tema": "energia", "cor": "#19e6b8", "limites": "energia", "jog": [0.5, 0.75]},
	"espelho": {"n": "Câmara dos Espelhos", "tipo": "pequena", "tema": "energia", "cor": "#ffd966", "limites": "energia", "jog": [0.5, 0.7]},
	"fenda": {"n": "Fenda Infinita", "tipo": "infinita", "tema": "fenda", "cor": "#b78cff", "limites": "nenhum", "jog": [0.5, 0.5]},
	"catedral": {"n": "Catedral Carmesim", "tipo": "grande", "tema": "catedral", "cor": "#ff2b55", "limites": "paredes", "jog": [0.5, 0.86]},
	"galeria": {"n": "Galeria dos Reflexos", "tipo": "pequena", "tema": "galeria", "cor": "#ff3df2", "limites": "energia", "jog": [0.5, 0.75]},
	"rotunda": {"n": "Rotunda dos Manuscritos", "tipo": "media", "w": 1200.0, "h": 1200.0, "tema": "biblioteca", "cor": "#ff9a3d", "limites": "paredes", "jog": [0.5, 0.8]},
	"templo": {"n": "Templo do Olho", "tipo": "grande", "tema": "templo", "cor": "#ffd23d", "limites": "paredes", "jog": [0.5, 0.86]},
}
## arena de cada chefe (ARB)
const BOSS_ARENA := {"rhino": "contencao", "dracula": "catedral", "vesperon": "rotunda", "illuminati": "templo", "espelho": "galeria"}

var g
var cur = null            # Dictionary da arena atual (A) ou null
var near: Array = []      # objetos sólidos próximos (ARN.near)
var cam := {"x": 0.0, "y": 0.0, "z": 1.0, "lx": null, "ly": 0.0, "vx": 0.0, "vy": 0.0, "look": null}
var trs := {"on": false, "t": 0.0, "ph": 0, "fn": Callable(), "txt": "", "sub": "", "cor": Color("#00f2ff"), "show": 0.0, "st": "", "ss": ""}
var cracks: Array[Dictionary] = []
var exp_list: Array[Dictionary] = []
var fenda: Fenda
var last_boss = null
var themes := {}
var _ind_n := 0


func _init(game) -> void:
	g = game
	fenda = Fenda.new(game, self)
	themes = {
		"contencao": ArenaContencao.new(game, self),
		"catedral": ArenaCatedral.new(game, self),
		"galeria": ArenaGaleria.new(game, self),
		"rotunda": ArenaRotunda.new(game, self),
		"templo": ArenaTemplo.new(game, self),
	}


func reset() -> void:
	cur = null
	near = []
	cracks.clear()
	exp_list.clear()
	cam.look = null
	cam.lx = null
	trs.on = false
	trs.show = 0.0
	last_boss = null
	fenda.on = false
	_cam_update(0.0, true)


func on() -> bool:
	return cur != null


func is_fenda() -> bool:
	return cur != null and cur.inf


func covers() -> bool:
	return cur != null and (cur.get("painted", false) or cur.inf)


func theme():
	return themes.get(cur.id) if cur != null else null


## Área jogável dentro das paredes (AB).
func box() -> Rect2:
	var t: float = cur.t if cur != null else 0.0
	var W := world_size()
	return Rect2(t, t, W.x - 2.0 * t, W.y - 2.0 * t)


func world_size() -> Vector2:
	if cur == null:
		return Vector2(g.vw, g.vh)
	return Vector2(cur.w, cur.h)


func world_rect() -> Rect2:
	if cur != null and cur.inf:
		return Rect2(-1e9, -1e9, 2e9, 2e9)
	return Rect2(Vector2.ZERO, world_size())


func ricochet_box() -> Rect2:
	if cur != null and not cur.inf:
		return box()
	if cur != null and cur.inf:
		return view_rect()
	return Rect2(0, 0, g.vw, g.vh)


func view_rect() -> Rect2:
	var z: float = cam.z
	return Rect2(cam.x, cam.y, g.vw / z, g.vh / z)


## Zona de combate: parte visível da arena (czR).
func combat_rect() -> Rect2:
	var v := view_rect()
	var B := box() if cur != null and not cur.inf else v
	var x0 := maxf(v.position.x, B.position.x)
	var y0 := maxf(v.position.y, B.position.y)
	var x1 := minf(v.end.x, B.end.x)
	var y1 := minf(v.end.y, B.end.y)
	if x1 - x0 < 240.0:
		var c := (x0 + x1) / 2.0
		x0 = c - 120.0
		x1 = c + 120.0
	if y1 - y0 < 240.0:
		var c := (y0 + y1) / 2.0
		y0 = c - 120.0
		y1 = c + 120.0
	return Rect2(x0, y0, x1 - x0, y1 - y0)


func view_diag() -> float:
	return Vector2(g.vw, g.vh).length() / float(cam.z)


func spawn_rate() -> float:
	if fenda.on:
		return fenda.rate()
	return -1.0


func danger_kills() -> int:
	if fenda.on:
		return 160 + fenda.dep * 30
	return -1


func spawn_point(side: int):
	if cur == null:
		return null
	var v := view_rect()
	var m := 60.0
	var x := 0.0
	var y := 0.0
	match side:
		0: x = v.position.x + randf() * v.size.x; y = v.position.y - m
		1: x = v.end.x + m; y = v.position.y + randf() * v.size.y
		2: x = v.position.x + randf() * v.size.x; y = v.end.y + m
		_: x = v.position.x - m; y = v.position.y + randf() * v.size.y
	if not cur.inf:
		var B := box()
		x = clampf(x, B.position.x + 20.0, B.end.x - 20.0)
		y = clampf(y, B.position.y + 20.0, B.end.y - 20.0)
	var q := {"x": x, "y": y}
	for o in near:
		if not o.get("solid", false) or o.get("dead", false):
			continue
		var p = push_out(o, q.x, q.y, 20.0)
		if p != null:
			q.x += p[0] * p[2]
			q.y += p[1] * p[2]
	return Vector2(q.x, q.y)


# ======================================================================
# câmera
# ======================================================================
func dev_zoom() -> float:
	return clampf(minf(g.vw, g.vh) / 640.0, 1.0, 1.8)


func _cam_update(dt: float, snap: bool) -> void:
	var A = cur
	var P: PlayerState = g.player
	var zt: float = dev_zoom() if A != null else 1.0
	cam.z = zt if (snap or A == null) else cam.z + (zt - cam.z) * minf(1.0, dt * 3.0)
	var vw: float = g.vw / cam.z
	var vh: float = g.vh / cam.z
	if cam.lx == null or snap:
		cam.lx = P.x
		cam.ly = P.y
		cam.vx = 0.0
		cam.vy = 0.0
	var idt := 1.0 / maxf(dt, 0.001)
	var k4 := minf(1.0, dt * 4.0)
	cam.vx += (clampf((P.x - cam.lx) * idt, -420.0, 420.0) - cam.vx) * k4
	cam.vy += (clampf((P.y - cam.ly) * idt, -420.0, 420.0) - cam.vy) * k4
	cam.lx = P.x
	cam.ly = P.y
	var tx := P.x
	var ty := P.y
	if A != null:
		tx += clampf(cam.vx * 0.24, -vw * 0.15, vw * 0.15)
		ty += clampf(cam.vy * 0.24, -vh * 0.15, vh * 0.15)
		var b: Enemy = g.enc.boss
		if b != null and g.enc.st == "active" and b.hp > 0.0 and b.vis != 0:
			var dx := b.x - P.x
			var dy := b.y - P.y
			if absf(dx) < vw * 1.4 and absf(dy) < vh * 1.4:
				tx += dx * 0.3
				ty += dy * 0.3
		tx = clampf(tx, P.x - vw * 0.3, P.x + vw * 0.3)
		ty = clampf(ty, P.y - vh * 0.3, P.y + vh * 0.3)
		if cam.look != null:
			var L: Dictionary = cam.look
			L.t += dt
			var w := 0.0
			if L.t < L.a:
				w = L.t / L.a
			elif L.t < L.a + L.h:
				w = 1.0
			else:
				w = maxf(0.0, 1.0 - (L.t - L.a - L.h) / L.d)
			var e := w * w * (3.0 - 2.0 * w)
			tx += (L.x - tx) * e
			ty += (L.y - ty) * e
			if L.t >= L.a + L.h + L.d:
				cam.look = null
	var W := world_size()
	var cx := tx - vw / 2.0
	var cy := ty - vh / 2.0
	var fixed: bool = not (A != null and A.inf)
	if fixed:
		cx = (W.x - vw) / 2.0 if vw >= W.x else clampf(cx, 0.0, W.x - vw)
		cy = (W.y - vh) / 2.0 if vh >= W.y else clampf(cy, 0.0, W.y - vh)
	if snap or A == null:
		cam.x = cx
		cam.y = cy
		return
	var k := 1.0 - exp(-dt * 7.0)
	cam.x += (cx - cam.x) * k
	cam.y += (cy - cam.y) * k
	if cam.look == null:
		var m := P.radius + 10.0
		if vw < W.x or not fixed:
			if P.x < cam.x + m:
				cam.x = P.x - m
			elif P.x > cam.x + vw - m:
				cam.x = P.x - vw + m
		if vh < W.y or not fixed:
			if P.y < cam.y + m:
				cam.y = P.y - m
			elif P.y > cam.y + vh - m:
				cam.y = P.y - vh + m


# ======================================================================
# transição e entrada/saída
# ======================================================================
func transition(fn: Callable, txt: String, sub: String, cor: Color) -> void:
	if trs.on and (trs.fn as Callable).is_valid():
		var f: Callable = trs.fn
		trs.fn = Callable()
		f.call()
	trs.on = true
	trs.t = 0.0
	trs.ph = 0
	trs.fn = fn
	trs.txt = txt
	trs.sub = sub
	trs.cor = cor
	g.sfx("trgo")


func transition_update(dt: float) -> void:
	trs.t += dt
	if trs.ph == 0 and trs.t >= 0.38:
		trs.ph = 1
		trs.t = 0.0
		var f: Callable = trs.fn
		trs.fn = Callable()
		if f.is_valid():
			f.call()
	elif trs.ph == 1 and trs.t >= 0.5:
		trs.on = false
		trs.show = 2.4
		trs.st = trs.txt
		trs.ss = trs.sub


func go(id: String, boss: bool) -> void:
	var d: Dictionary = ARX.get(id, {})
	var z := mini(SectorBackground.ZN.size() - 1, g.sec)
	var txt: String = String(d.n).to_upper() if not d.is_empty() else "SETOR %d: %s" % [z + 1, SectorBackground.ZN[z].n]
	var sub: String = ASZ[d.tipo][2] if not d.is_empty() else "campo aberto"
	var cor := Color(d.cor) if not d.is_empty() else Color(SectorBackground.ZN[z].c)
	transition(_go_cb.bind(id, boss), txt, sub, cor)


func _go_cb(id: String, boss: bool) -> void:
	if id != "":
		enter_now(id, boss)
	else:
		exit_now()


func enter_now(id: String, boss: bool) -> bool:
	var d: Dictionary = ARX.get(id, {})
	if d.is_empty():
		return false
	var sz: Array = ASZ[d.tipo]
	var ox: float = g.player.x
	var oy: float = g.player.y
	if cur != null and cur.inf:
		fenda.leave()
	var A := {"id": id, "d": d, "n": d.n, "tipo": d.tipo, "inf": d.tipo == "infinita", "boss": boss, "zoom": 1.0,
		"w": float(d.get("w", sz[0])), "h": float(d.get("h", sz[1])),
		"t": 44.0 if d.limites == "paredes" else (24.0 if d.limites == "energia" else 0.0),
		"obj": [], "tm": 0.0, "fl": [], "sp": [], "wd": {}, "dk": 0.0, "dkT": 0, "alarm": 0, "painted": false, "cor": Color(d.cor)}
	cur = A
	var th = theme()
	if th != null:
		th.build(A)
	if A.inf:
		fenda.reset()
	else:
		fenda.on = false
	var j := Vector2(fenda.o) if A.inf else Vector2(A.w * d.jog[0], A.h * d.jog[1])
	g.player.x = j.x
	g.player.y = j.y
	var dp := j - Vector2(ox, oy)
	for q in g.powers.TR:
		q.x += dp.x
		q.y += dp.y
	for q in g.powers.BH:
		q.x += dp.x
		q.y += dp.y
	_clear_field()
	for p in g.pickups:
		p.x = g.player.x
		p.y = g.player.y
	A.obj = th.obstacles(A) if th != null else []
	near = [] if A.inf else A.obj
	cam.look = null
	_cam_update(0.0, true)
	Events.arena_enter.emit(id)
	return true


func exit_now() -> void:
	var A = cur
	if A == null:
		_cam_update(0.0, true)
		return
	cur = null
	near = []
	if A.inf:
		fenda.leave()
	var ox: float = g.player.x
	var oy: float = g.player.y
	g.player.x = g.vw / 2.0
	g.player.y = g.vh / 2.0
	var dp := Vector2(g.player.x - ox, g.player.y - oy)
	for q in g.powers.TR:
		q.x += dp.x
		q.y += dp.y
	for q in g.powers.BH:
		q.x += dp.x
		q.y += dp.y
	_clear_field()
	for p in g.pickups:
		p.x = g.player.x
		p.y = g.player.y
	cam.look = null
	_cam_update(0.0, true)
	Events.arena_exit.emit(A.id)


func _clear_field() -> void:
	g.enemies.clear()
	g.projectiles.clear()
	g.enemy_projectiles.clear()
	g.hazards.clear()
	g.gp.clear()
	g.fx.clear()
	exp_list.clear()
	cracks.clear()
	g.enc.clear_visuals()


# ======================================================================
# atualização
# ======================================================================
func pre(_dt: float) -> void:
	var A = cur
	if A == null:
		return
	var P: PlayerState = g.player
	if not A.inf:
		var B := box()
		P.x = clampf(P.x, B.position.x + P.radius, B.end.x - P.radius)
		P.y = clampf(P.y, B.position.y + P.radius, B.end.y - P.radius)
	collide(P, P.radius)
	var th = theme()
	if th != null and th.has_method("pre"):
		th.pre(_dt)


func post(dt: float) -> void:
	if trs.show > 0.0:
		trs.show -= dt
	for k in cracks:
		if k.has("h"):
			k.t += dt
			if k.t >= 1.0:
				k.erase("h")
	var A = cur
	if A != null:
		A.tm += dt
		near = fenda.near() if A.inf else A.obj
		if not A.inf:
			var B := box()
			_cull(g.projectiles, B, false)
			_cull(g.enemy_projectiles, B, true)
			var m := 14.0
			var vv := 420.0 * dt
			for p in g.pickups:
				var tx := clampf(p.x, B.position.x + m, B.end.x - m)
				var ty := clampf(p.y, B.position.y + m, B.end.y - m)
				if tx != p.x:
					p.x += clampf(tx - p.x, -vv, vv)
				if ty != p.y:
					p.y += clampf(ty - p.y, -vv, vv)
		_objects_update(dt, A)
		_object_shots()
		if not near.is_empty():
			for e in g.enemies:
				if e.bd.is_empty():
					collide(e, e.radius * 0.9)
			for p in g.pickups:
				var q := {"x": p.x, "y": p.y}
				_collide_dict(q, 9.0)
				p.x = q.x
				p.y = q.y
		for f in A.fl:
			f.t -= dt
		A.fl = A.fl.filter(func(f): return f.t > 0.0)
		for s in A.sp:
			s.t -= dt
			if s.t <= 0.0:
				s.t = 0.5 + randf() * 0.9
				g.fx.burst(s.x, s.y, Color("#ff9a4a"), 3, 130.0, 2.0)
		var th = theme()
		if th != null:
			th.post(dt, A)
		if A.inf:
			fenda.update(dt)
		var b: Enemy = g.enc.boss
		if b != null and b != last_boss and g.enc.st == "active":
			last_boss = b
			var v := view_rect()
			var ey: float = g.enc.entry_y()
			if b.x < v.position.x or b.x > v.end.x or ey < v.position.y or ey > v.end.y:
				cam.look = {"x": b.x, "y": ey, "t": 0.0, "a": 0.45, "h": 0.85, "d": 0.5, "cine": false}
		if A.boss and g.enc.st == "none" and not g.won and not trs.on:
			A.boss = false
			go("", false)
	_cam_update(dt, false)


func _cull(arr: Array, B: Rect2, sparks: bool) -> void:
	for i in range(arr.size() - 1, -1, -1):
		var p: Projectile = arr[i]
		if p.x < B.position.x or p.x > B.end.x or p.y < B.position.y or p.y > B.end.y:
			if sparks and (i & 1):
				g.fx.burst(clampf(p.x, B.position.x, B.end.x), clampf(p.y, B.position.y, B.end.y), Color("#ffb36b"), 2, 110.0, 2.0)
			arr.remove_at(i)


# ======================================================================
# objetos: colisão, dano, quebra, barris, vapor
# ======================================================================
## Empurra um círculo (x, y, r) para fora do objeto. Retorna [nx, ny, profundidade] ou null.
static func push_out(o: Dictionary, x: float, y: float, r: float):
	if o.has("r") and not o.has("hw"):
		var dx: float = x - o.x
		var dy: float = y - o.y
		var d := sqrt(dx * dx + dy * dy)
		var m: float = o.r + r
		if d >= m:
			return null
		if d < 0.001:
			return [0.0, -1.0, m]
		return [dx / d, dy / d, m - d]
	var qx := clampf(x, o.x - o.hw, o.x + o.hw)
	var qy := clampf(y, o.y - o.hh, o.y + o.hh)
	var dx := x - qx
	var dy := y - qy
	var d := sqrt(dx * dx + dy * dy)
	if d >= r:
		return null
	if d > 0.001:
		return [dx / d, dy / d, r - d]
	var l: float = x - (o.x - o.hw)
	var rr: float = (o.x + o.hw) - x
	var t: float = y - (o.y - o.hh)
	var b: float = (o.y + o.hh) - y
	var mm := minf(minf(l, rr), minf(t, b))
	if mm == l:
		return [-1.0, 0.0, l + r]
	if mm == rr:
		return [1.0, 0.0, rr + r]
	if mm == t:
		return [0.0, -1.0, t + r]
	return [0.0, 1.0, b + r]


func collide(e, r: float):
	var hit = null
	for o in near:
		if not o.get("solid", false) or o.get("dead", false):
			continue
		var q = push_out(o, e.x, e.y, r)
		if q != null:
			e.x += q[0] * q[2]
			e.y += q[1] * q[2]
			hit = o
	return hit


func _collide_dict(e: Dictionary, r: float) -> void:
	for o in near:
		if not o.get("solid", false) or o.get("dead", false):
			continue
		var q = push_out(o, e.x, e.y, r)
		if q != null:
			e.x += q[0] * q[2]
			e.y += q[1] * q[2]


## Objeto sólido no ponto (sem alocar: roda para cada tiro a cada quadro).
func ob_at(x: float, y: float, r: float):
	for o in near:
		if not o.get("solid", false) or o.get("dead", false):
			continue
		if o.has("r") and not o.has("hw"):
			var dx: float = x - o.x
			var dy: float = y - o.y
			var m: float = o.r + r
			if dx * dx + dy * dy < m * m:
				return o
		elif x > o.x - o.hw - r and x < o.x + o.hw + r and y > o.y - o.hh - r and y < o.y + o.hh + r:
			var dx := x - clampf(x, o.x - o.hw, o.x + o.hw)
			var dy := y - clampf(y, o.y - o.hh, o.y + o.hh)
			if dx * dx + dy * dy < r * r:
				return o
	return null


## Linha de visão contra obstáculos (segHit).
func seg_hit(x0: float, y0: float, x1: float, y1: float, r: float = 2.0):
	var n := ceili(Vector2(x1 - x0, y1 - y0).length() / 14.0)
	for k in range(1, n):
		var o = ob_at(x0 + (x1 - x0) * k / n, y0 + (y1 - y0) * k / n, r)
		if o != null:
			return o
	return null


func obj_hit(o: Dictionary, d: float) -> void:
	if not o.get("brk", false) or o.get("dead", false) or o.get("st", "") == "fuse":
		return
	o.hp -= d
	o.fl = 0.08
	if o.hp <= 0.0:
		obj_break(o)


func obj_break(o: Dictionary) -> void:
	if o.get("dead", false) or o.get("st", "") == "fuse":
		return
	if o.k == "barril":
		o.st = "fuse"
		o.t = 0.3
		g.sfx("blink")
		return
	o.dead = true
	if o.k == "caixa":
		g.sfx("crate")
		g.fx.burst(o.x, o.y, Color("#8a8f99"), 16, 220.0, 3.0)
		g.fx.burst(o.x, o.y, Color("#b08a1e"), 5, 160.0, 2.0)
		if randf() < 0.35:
			g.add_pickup(o.x, o.y, "hp" if randf() < 0.4 else "xp")
	else:
		g.fx.burst(o.x, o.y, Color("#8a8f99"), 22, 260.0, 4.0)
	if o.has("onBreak"):
		(o.onBreak as Callable).call(o)


func boom(o: Dictionary) -> void:
	var x: float = o.x
	var y: float = o.y
	var R := 125.0
	g.sfx("boom")
	g.shake(10.0)
	g.hitstop(0.06)
	g.fx.burst(x, y, Color("#ff7a3a"), 28, 340.0, 4.0)
	g.fx.burst(x, y, Color("#ffe08a"), 12, 200.0, 3.0)
	g.fx.ripple(x, y, 16.0, R, Color("#ff7a3a"), 0.95, 0.45)
	g.hazards.add({"k": "c", "x": x, "y": y, "r": R, "tw": 0.0, "ta": 0.12, "dmg": 18.0, "col": Color("#ff7a3a")})
	crack(x, y, 2, 6, 80.0)
	var b: Enemy = g.enc.boss
	if b != null and b.hp > 0.0 and Vector2(b.x - x, b.y - y).length() < R + b.radius * 0.5:
		g.dmg_e(b, b.max_hp * 0.06, {})
		b.flash = 0.15
		g.fx.burst(b.x, b.y, Color("#ffcc00"), 10, 200.0)
	for e in g.enemies:
		if e.bd.is_empty() and Vector2(e.x - x, e.y - y).length() < R + e.radius:
			e.hp -= 220.0
	if cur != null:
		for q in cur.obj:
			if q == o or q.get("dead", false):
				continue
			if Vector2(q.x - x, q.y - y).length() < R:
				if q.k == "barril" and q.get("st", "") != "fuse":
					q.st = "fuse"
					q.t = 0.18
				elif q.k == "caixa":
					obj_hit(q, 70.0)
	Events.arena_boom.emit(x, y)


func _objects_update(dt: float, A: Dictionary) -> void:
	var dead := false
	for o in A.obj:
		if o.get("fl", 0.0) > 0.0:
			o.fl -= dt
		if o.k == "barril" and o.get("st", "") == "fuse":
			o.t -= dt
			if o.t <= 0.0:
				o.dead = true
				boom(o)
		if o.k == "vapor":
			_vent_update(o, dt)
		if o.get("dead", false):
			dead = true
	if dead:
		A.obj = A.obj.filter(func(o): return not o.get("dead", false))
		near = A.obj if not A.inf else near
	for i in range(exp_list.size() - 1, -1, -1):
		var e: Dictionary = exp_list[i]
		e.t -= dt
		if e.t <= 0.0:
			exp_list.remove_at(i)
			A.obj.append({"k": "entulho", "x": e.x, "y": e.y, "r": 30.0, "solid": true, "v": randi() % 3})
			g.fx.burst(e.x, e.y, Color("#8a8f99"), 24, 260.0, 4.0)
			g.shake(6.0)
			g.sfx("rhslam")


func _vent_update(o: Dictionary, dt: float) -> void:
	o.t -= dt
	var b: Enemy = g.enc.boss
	var fury: bool = b != null and b.d.get("rg", false)
	if o.st == 0 and o.t <= 0.0:
		o.st = 1
		o.t = 0.9
		g.sfx("vapor")
	elif o.st == 1 and o.t <= 0.0:
		o.st = 2
		o.t = 1.4
		g.fx.burst(o.x, o.y, Color("#e8eef5"), 10, 120.0, 4.0)
	elif o.st == 2:
		if o.t <= 0.0:
			o.st = 0
			o.t = (2.4 if fury else 4.0) + randf() * 3.0
		else:
			var P: PlayerState = g.player
			if Vector2(P.x - o.x, P.y - o.y).length() < o.r + P.radius * 0.5:
				g.take_damage(26.0 * float(g.cfg.bossDmg) * dt, "area")
			if b != null and b.hp > 0.0 and Vector2(b.x - o.x, b.y - o.y).length() < o.r + b.radius * 0.4:
				g.dmg_e(b, b.max_hp * 0.012 * dt, {})
			for e in g.enemies:
				if e.bd.is_empty() and Vector2(e.x - o.x, e.y - o.y).length() < o.r:
					e.hp -= 40.0 * dt


## Tiros contra obstáculos: quebram destrutíveis, ricocheteiam e são bloqueados (cobertura).
func _object_shots() -> void:
	if near.is_empty():
		return
	for i in range(g.projectiles.size() - 1, -1, -1):
		var p: Projectile = g.projectiles[i]
		var o = ob_at(p.x, p.y, p.radius)
		if o == null:
			continue
		if o.get("brk", false):
			obj_hit(o, g.player.damage)
		var q = push_out(o, p.x, p.y, p.radius + 0.5)
		if p.rb > 0 and q != null and not (o.get("brk", false) and o.get("dead", false)):
			var vn: float = p.vx * q[0] + p.vy * q[1]
			if vn < 0.0:
				p.vx -= 2.0 * vn * q[0]
				p.vy -= 2.0 * vn * q[1]
			p.x += q[0] * q[2]
			p.y += q[1] * q[2]
			p.rb -= 1
			p.bn += 1
			Events.projectile_ricochet.emit(p.x, p.y, p.color)
		else:
			if i & 1:
				g.fx.burst(p.x, p.y, Color("#ffb36b"), 2, 110.0, 2.0)
			g.projectiles.remove_at(i)
	for i in range(g.enemy_projectiles.size() - 1, -1, -1):
		var p: Projectile = g.enemy_projectiles[i]
		var o = ob_at(p.x, p.y, p.radius)
		if o == null:
			continue
		if o.get("brk", false):
			obj_hit(o, 6.0)
		if i & 1:
			g.fx.burst(p.x, p.y, Color("#c9b28a"), 2, 90.0, 2.0)
		g.enemy_projectiles.remove_at(i)


## Desabamento do teto (fase 2 do Rhino).
func collapse() -> void:
	if cur == null:
		return
	var B := box()
	g.banner("O TETO CEDE!", Color("#ffb36b"), 1.8)
	g.sfx("rhroar")
	g.shake(8.0)
	for i in 3:
		var x := 0.0
		var y := 0.0
		var ok := false
		var k := 0
		while k < 20 and not ok:
			x = B.position.x + 140.0 + randf() * (B.size.x - 280.0)
			y = B.position.y + 180.0 + randf() * (B.size.y - 360.0)
			ok = Vector2(x - g.player.x, y - g.player.y).length() > 150.0
			for o in cur.obj:
				if Vector2(o.x - x, o.y - y).length() < 130.0:
					ok = false
			k += 1
		g.hazards.add({"k": "c", "x": x, "y": y, "r": 46.0, "tw": 1.3 + i * 0.15, "ta": 0.2, "dmg": 16.0, "col": Color("#c9b28a")})
		exp_list.append({"x": x, "y": y, "t": 1.3 + i * 0.15})


# ======================================================================
# rachaduras em pixel art (decalques no piso)
# ======================================================================
func crack(x: float, y: float, pw: int, n: int = 5, length: float = 70.0) -> void:
	if cur == null:
		return
	n = mini(5 if pw > 1 else 3, n)
	var L := maxf(6.0, length / 2.0 * (1.0 if pw > 1 else 0.8))
	var R := ceili(L * 1.3) + 7
	var S := R * 2 + 1
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var heat := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var pts := PixelArt.crack_paint(img, R, R, n, L, RandomNumberGenerator.new(), pw)
	for p in pts:
		heat.set_pixel(p.x, p.y, Color("#ff5a2a"))
	var cp := 40 if Settings.s.q >= 2 else (24 if Settings.s.q == 1 else 12)
	while cracks.size() >= cp:
		cracks.pop_front()
	cracks.append({"x": x, "y": y, "R": R, "c": ImageTexture.create_from_image(img), "h": ImageTexture.create_from_image(heat), "t": 0.0})


func wall_hit(x: float, y: float, pw: float) -> void:
	var th = theme()
	if th != null and th.has_method("wall_hit"):
		th.wall_hit(cur, x, y, pw)
	elif cur != null and not cur.inf:
		cur.fl.append({"x": x, "y": y, "t": 0.5})


# ======================================================================
# desenho
# ======================================================================
func draw_floor_tex(c: CanvasItem) -> void:
	var mat := c.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("enabled", false)
	var th = theme()
	if th != null and th.has_method("draw_floor_tex"):
		th.draw_floor_tex(c, cur)


func draw_floor_add(c: CanvasItem) -> void:
	var th = theme()
	if th != null and th.has_method("draw_floor_add"):
		th.draw_floor_add(c, cur)


func draw_floor(c: CanvasItem) -> void:
	var A = cur
	if A == null:
		return
	var th = theme()
	if th != null:
		th.draw_floor(c, A)
	elif A.inf:
		fenda.draw_floor(c)
	else:
		_draw_energy(c, A)
	_draw_cracks(c)
	_draw_objects(c, A)
	if A.inf:
		fenda.draw_monoliths(c)


func _draw_cracks(c: CanvasItem) -> void:
	var v := view_rect()
	for k in cracks:
		var s: float = k.R * 2.0
		if k.x + s < v.position.x or k.x - s > v.end.x or k.y + s < v.position.y or k.y - s > v.end.y:
			continue
		var w: float = (k.c as Texture2D).get_width() * 2.0
		c.draw_texture_rect(k.c, Rect2(k.x - s, k.y - s, w, w), false)
		if k.has("h"):
			c.draw_texture_rect(k.h, Rect2(k.x - s, k.y - s, w, w), false, Color(1, 1, 1, maxf(0.0, 1.0 - k.t) * 0.9))


func _draw_energy(c: CanvasItem, A: Dictionary) -> void:
	var v := view_rect()
	var B := box()
	var col: Color = A.cor
	var L := v.position.x - 4.0
	var T := v.position.y - 4.0
	var R := v.end.x + 4.0
	var D := v.end.y + 4.0
	var dark := Color(0.008, 0.008, 0.024, 0.8)
	if B.position.x > L:
		c.draw_rect(Rect2(L, T, B.position.x - L, D - T), dark)
	if B.end.x < R:
		c.draw_rect(Rect2(B.end.x, T, R - B.end.x, D - T), dark)
	var ix0 := maxf(L, B.position.x)
	var ix1 := minf(R, B.end.x)
	if B.position.y > T and ix1 > ix0:
		c.draw_rect(Rect2(ix0, T, ix1 - ix0, B.position.y - T), dark)
	if B.end.y < D and ix1 > ix0:
		c.draw_rect(Rect2(ix0, B.end.y, ix1 - ix0, D - B.end.y), dark)
	var G := 64.0
	var gx0 := maxf(B.position.x, v.position.x)
	var gx1 := minf(B.end.x, v.end.x)
	var gy0 := maxf(B.position.y, v.position.y)
	var gy1 := minf(B.end.y, v.end.y)
	if gx1 > gx0 and gy1 > gy0:
		var x := B.position.x + ceilf((gx0 - B.position.x) / G) * G
		while x < gx1:
			c.draw_line(Vector2(x, gy0), Vector2(x, gy1), Draw.alpha(col, 0.08), 1.0)
			x += G
		var y := B.position.y + ceilf((gy0 - B.position.y) / G) * G
		while y < gy1:
			c.draw_line(Vector2(gx0, y), Vector2(gx1, y), Draw.alpha(col, 0.08), 1.0)
			y += G
		x = B.position.x + ceilf((gx0 - B.position.x) / (G * 2.0)) * G * 2.0
		while x < gx1:
			y = B.position.y + ceilf((gy0 - B.position.y) / (G * 2.0)) * G * 2.0
			while y < gy1:
				c.draw_rect(Rect2(x - 3, y, 7, 1), Draw.alpha(col, 0.22))
				c.draw_rect(Rect2(x, y - 3, 1, 7), Draw.alpha(col, 0.22))
				y += G * 2.0
			x += G * 2.0
	var pu := 0.6 + 0.4 * sin(A.tm * 3.0)
	c.draw_rect(B, Draw.alpha(col, 0.16 * pu), false, 14.0)
	Draw.dashed_rect(c, B, 22.0, 10.0, -A.tm * 30.0, Draw.alpha(col, 0.9), 2.5)
	var P := 160.0
	var x := B.position.x
	while x <= B.end.x + 1.0:
		for yy in [B.position.y, B.end.y]:
			if x > v.position.x - 10.0 and x < v.end.x + 10.0:
				c.draw_rect(Rect2(x - 4, yy - 4, 8, 8), Draw.alpha(col, 0.9))
		x += P
	var y := B.position.y
	while y <= B.end.y + 1.0:
		for xx in [B.position.x, B.end.x]:
			if y > v.position.y - 10.0 and y < v.end.y + 10.0:
				c.draw_rect(Rect2(xx - 4, y - 4, 8, 8), Draw.alpha(col, 0.9))
		y += P
	for f in A.fl:
		Draw.circle(c, Vector2(f.x, f.y), 10.0 + (0.5 - f.t) * 40.0, Color(1, 1, 1, f.t * 1.6))


func _draw_objects(c: CanvasItem, A: Dictionary) -> void:
	var th = theme()
	if th != null and th.has_method("draw_objects"):
		th.draw_objects(c, A)


## Escuridão da Lua de Sangue (Catedral): shader com furos de luz (jogador, velas, rosácea, chefe).
func draw_dark(c: CanvasItem) -> void:
	var A = cur
	var mat := c.material as ShaderMaterial
	if A == null or not A.get("dark", false):
		if mat:
			mat.set_shader_parameter("strength", 0.0)
		return
	var th = theme()
	if th == null or not th.has_method("lights"):
		return
	if not A.get("cut", false):
		A.cut = true
		for o in A.obj:
			if o.k == "vela" and randf() < 0.67:
				o.lit = false
	A.dark_k = minf(1.0, float(A.get("dark_k", 0.0)) + 0.6 * g.get_process_delta_time())
	var L: Array = th.lights(A)
	var arr := PackedVector3Array()
	for l in L:
		if arr.size() >= 12:
			break
		arr.append(l)
	if mat:
		mat.set_shader_parameter("strength", 0.9 * float(A.dark_k))
		mat.set_shader_parameter("count", arr.size())
		mat.set_shader_parameter("lights", arr)
	var v := view_rect()
	c.draw_rect(v.grow(8.0), Color.WHITE)


func draw_after(c: CanvasItem) -> void:
	var A = cur
	if A == null:
		return
	var th = theme()
	if th != null and th.has_method("draw_after"):
		th.draw_after(c, A)


# ======================================================================
# tela: indicadores fora da câmera, HUD da Fenda e transição
# ======================================================================
func draw_screen(c: CanvasItem) -> void:
	var vw: float = g.vw
	var vh: float = g.vh
	if cur != null and g.active:
		_draw_indicators(c)
	if cur != null and cur.inf and g.active:
		fenda.draw_hud(c)
	if not trs.on and trs.show > 0.0 and g.active:
		var al := minf(1.0, trs.show) * 0.9
		var by := maxf(112.0, vh * 0.17)
		Draw.text(c, Assets.font_ui_black, trs.st, Vector2(vw / 2.0, by), 15, Draw.alpha(trs.cor, al), HORIZONTAL_ALIGNMENT_CENTER)
		Draw.text(c, Assets.font_mono_bold, trs.ss, Vector2(vw / 2.0, by + 16.0), 10, Draw.alpha(trs.cor, al * 0.75), HORIZONTAL_ALIGNMENT_CENTER)
	if trs.on:
		var a: float = trs.t / 0.38 if trs.ph == 0 else 1.0 - trs.t / 0.5
		var e := clampf(a, 0.0, 1.0)
		c.draw_rect(Rect2(0, 0, vw, vh), Color(0.012, 0.012, 0.027, e))
		if not Settings.s.reduce:
			var y := fmod(Time.get_ticks_msec() / 7.0, 6.0)
			while y < vh:
				c.draw_rect(Rect2(0, y, vw, 1), Draw.alpha(trs.cor, e * 0.35))
				y += 6.0
		Draw.text(c, Assets.font_ui_black, trs.txt, Vector2(vw / 2.0, vh / 2.0), 20, Draw.alpha(trs.cor, e), HORIZONTAL_ALIGNMENT_CENTER)
		Draw.text(c, Assets.font_mono_bold, trs.sub, Vector2(vw / 2.0, vh / 2.0 + 20.0), 11, Draw.alpha(trs.cor, e * 0.75), HORIZONTAL_ALIGNMENT_CENTER)


func _draw_indicators(c: CanvasItem) -> void:
	var z: float = cam.z
	var vw: float = g.vw
	var vh: float = g.vh
	var list: Array = []
	var b: Enemy = g.enc.boss
	if b != null and g.enc.st == "active" and b.hp > 0.0 and b.vis != 0 and g.enemies.has(b):
		list.append([b.x, b.y, b.color, 1 if (b.chg2 or b.d.get("st", "") == "prep") else 0, -1.0])
	if fenda.on and not fenda.anc.is_empty():
		list.append([fenda.anc.x, fenda.anc.y, Color("#b78cff"), 0, Vector2(fenda.anc.x - g.player.x, fenda.anc.y - g.player.y).length()])
	var px: float = (g.player.x - cam.x) * z
	var py: float = (g.player.y - cam.y) * z
	_ind_n = 0
	for it in list:
		var sx: float = (it[0] - cam.x) * z
		var sy: float = (it[1] - cam.y) * z
		if sx > -8.0 and sx < vw + 8.0 and sy > -8.0 and sy < vh + 8.0:
			continue
		var a := atan2(sy - py, sx - px)
		var ca := cos(a)
		var sa := sin(a)
		var m := 26.0
		var t := 1e9
		if ca > 0.0: t = minf(t, (vw - m - px) / ca)
		if ca < 0.0: t = minf(t, (m - px) / ca)
		if sa > 0.0: t = minf(t, (vh - m - py) / sa)
		if sa < 0.0: t = minf(t, (m - py) / sa)
		_ind_n += 1
		var ex := px + ca * t
		var ey := py + sa * t
		var pu := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 55.0) if it[3] else 0.75
		c.draw_set_transform(Vector2(ex, ey), a, Vector2.ONE)
		Draw.poly(c, PackedVector2Array([Vector2(14, 0), Vector2(-7, -10), Vector2(-3, 0), Vector2(-7, 10)]), Draw.alpha(it[2], 0.55 + 0.45 * pu))
		c.draw_set_transform_matrix(Transform2D.IDENTITY)
		if it[4] >= 0.0:
			Draw.text(c, Assets.font_mono_bold, "%d m" % roundi(it[4] / 32.0), Vector2(ex - ca * 26.0, ey - sa * 26.0 + 3.0), 10, Draw.alpha(it[2], 0.9), HORIZONTAL_ALIGNMENT_CENTER)
	var n := 0
	for p in g.enemy_projectiles:
		if n > 14:
			break
		var sx: float = (p.x - cam.x) * z
		var sy: float = (p.y - cam.y) * z
		if sx >= 0.0 and sx <= vw and sy >= 0.0 and sy <= vh:
			continue
		if sx < -280.0 or sx > vw + 280.0 or sy < -280.0 or sy > vh + 280.0:
			continue
		if p.vx * (g.player.x - p.x) + p.vy * (g.player.y - p.y) <= 0.0:
			continue
		n += 1
		c.draw_rect(Rect2(clampf(sx, 6.0, vw - 6.0) - 3.0, clampf(sy, 6.0, vh - 6.0) - 3.0, 6, 6), Color(1, 0.35, 0.43, 0.75))


func indicator_count() -> int:
	return _ind_n
