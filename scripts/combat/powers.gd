class_name Powers
extends RefCounted
## Evoluções e poderes (blocos 'GAMEPLAY (correções das evoluções)' e 'OVERDRIVE' do HTML).
## Cada poder é obtido no level up; para subir de nível ele precisa ser "liberado" derrotando um inimigo
## com o próprio poder (o golpe final é marcado em Enemy.fatal).

## [chave, nome, rótulo curto, como liberar]
const PUK := [
	["shock", "ELECTRO-SHOCK", "SHOCK", "o raio"],
	["bh", "BLACK HOLE", "BURACO", "o campo do buraco negro"],
	["shield", "NANO-SHIELD", "ESCUDO", "um tiro disparado com o escudo ativo"],
	["wings", "NEON WINGS", "ASAS", "um tiro disparado em movimento"],
	["prism", "PRISM BLAST", "PRISMA", "um tiro prismático"],
	["turret", "TORRETA NEON", "TORRETA", "um tiro da Torreta"],
	["rico", "RICOCHETE", "RICOCHETE", "um tiro que já ricocheteou"],
	["luck", "SORTE NEON", "SORTE", "um abate com drop duplo"],
	["crit", "CRÍTICO", "CRÍTICO", "um acerto crítico"],
	["mag", "MAGNETO", "MAGNETO", "um abate cujo drop o Magneto puxa"],
	["vamp", "VAMPIRISMO", "VAMPIRO", "um abate que cura"],
]

const CFG := {"bhBase": 0.15, "bhLvl": 0.07}

var g   # Game
var nx := {"shock": 0, "bh": 0, "shield": 0, "wings": 0, "prism": 0, "rico": 0, "luck": 0, "turret": 0}
var PU := {}   # k -> {lv, st}  st: 0 nunca, 1 obtido (bloqueado), 2 evolução liberada
var PL := {}   # k -> pulso visual do chip
var BH: Array[Dictionary] = []
var TR: Array[Dictionary] = []
var TRL := PackedVector2Array()
var sk_target: Enemy = null
var sk_s := 1.0
var hue := 0.0
var mv := 0.0          # velocidade suavizada do jogador (visual)
var px := 0.0
var py := 0.0
var wt := 0.0
var sa := 0.0
var slr := 0.0
var was_crit := false
var upgrades: Array[Dictionary] = []


func _init(game) -> void:
	g = game
	_build_list()
	for e in PUK:
		PU[e[0]] = {"lv": 0, "st": 0}


func reset() -> void:
	for k in nx.keys():
		nx[k] = 0
	for k in PU.keys():
		PU[k] = {"lv": 0, "st": 0}
	PL.clear()
	BH.clear()
	TR.clear()
	TRL.clear()
	sk_target = null
	sk_s = 1.0
	mv = 0.0


func _build_list() -> void:
	var P = func(): return g.player
	upgrades = [
		{"n": "OVERCLOCK", "d": "Dano +40%", "f": func(): P.call().damage *= 1.4},
		{"n": "TURBO", "d": "Velocidade +30%", "f": func(): P.call().speed *= 1.3},
		{"n": "RAPID FIRE", "d": "Velocidade de Ataque +25%", "f": func(): P.call().attack_speed *= 0.75},
		{"n": "SPLIT SHOT", "d": "+1 Projétil", "f": func(): P.call().projectiles += 1},
		{"n": "EXPANSION", "d": "Área dos seus tiros +50%", "f": func(): P.call().area_scale += 0.5},
		{"n": "REGEN", "d": "Reparo +0.75/s (nerf)", "f": func(): P.call().regen += 0.75},
		{"n": "ELECTRO-SHOCK", "d": "Raio que ganha dano ao focar o alvo", "k": "shock", "f": func(): nx.shock += 1},
		{"n": "BLACK HOLE", "d": "Ao matar, chance de criar um campo estático que puxa e fere", "k": "bh", "f": func(): nx.bh += 1},
		{"n": "NANO-SHIELD", "d": "Escudo +25 e +5 de vida máxima", "k": "shield", "f": _nano_shield},
		{"n": "NEON WINGS", "d": "Asas de energia e +12% de velocidade de ataque", "k": "wings", "f": _wings},
		{"n": "PRISM BLAST", "d": "Tiros coloridos que atravessam inimigos", "k": "prism", "f": _prism},
		{"n": "TORRETA NEON", "d": "Torreta automática por 90 s", "k": "turret", "f": _turret},
		{"n": "RICOCHETE", "d": "Parte dos tiros quica na borda (até 3×)", "k": "rico", "f": func(): nx.rico += 1},
		{"n": "SORTE NEON", "d": "50% de chance de drop duplo", "k": "luck", "f": func(): nx.luck += 1},
		{"n": "CRÍTICO", "d": "+10% de chance de crítico (dano ×2)", "k": "crit", "f": func(): P.call().crit += 0.1},
		{"n": "MAGNETO", "d": "Atrai itens de mais longe", "k": "mag", "f": func(): P.call().mag += 1},
		{"n": "VAMPIRISMO", "d": "Cada abate cura 0.6 de vida", "k": "vamp", "f": func(): P.call().vamp += 1},
	]


func _wings() -> void:
	nx.wings += 1
	g.player.attack_speed *= 0.88


func _prism() -> void:
	nx.prism += 1
	g.player.prism_active = true


func _nano_shield() -> void:
	var p: PlayerState = g.player
	nx.shield += 1
	p.shield_max += 25.0
	p.shield = p.shield_max
	p.max_hp += 5.0
	p.hp = minf(p.max_hp, p.hp + 5.0)


func _turret() -> void:
	var p: PlayerState = g.player
	nx.turret += 1
	TR.append({"x": p.x + (randf() - 0.5) * 120.0, "y": p.y + (randf() - 0.5) * 120.0, "t": 0.0, "d": 90.0, "l": 0.0, "a": 0.0, "lk": 0.0, "rc": 0.0})
	Events.skill_activated.emit("turret", p.x, p.y)


## Três opções do level up (filtro NF.offer: poderes bloqueados ou no nível 5 não aparecem).
func offer(no_regen: bool = false) -> Array:
	var L: Array = []
	for u in upgrades:
		if no_regen and u.n == "REGEN":
			continue
		if u.has("k"):
			var s: Dictionary = PU[u.k]
			if s.st == 1 or s.lv >= 5:
				continue
			if s.lv > 0:
				var c: Dictionary = u.duplicate()
				c.d = "EVOLUÇÃO Nv %d: %s" % [s.lv + 1, u.d]
				L.append(c)
				continue
		L.append(u)
	L.shuffle()
	return L.slice(0, 3)


func apply(u: Dictionary) -> void:
	(u.f as Callable).call()
	if u.has("k"):
		var s: Dictionary = PU[u.k]
		s.lv += 1
		s.st = 1
		Events.power_acquired.emit(u.k, u.n, s.lv)
	Events.upgrade_applied.emit(u.n)


func locked_info() -> String:
	var L: Array[String] = []
	for x in PUK:
		if PU[x[0]].st == 1:
			L.append("· %s: %s" % [x[2], x[3]])
	return ("Derrote um inimigo utilizando o poder para liberar a evolução:\n" + "\n".join(L)) if not L.is_empty() else ""


func unlock(k: String) -> void:
	var s: Dictionary = PU.get(k, {})
	if s.is_empty() or s.st != 1:
		return
	s.st = 2
	PL[k] = 1.0
	var n := ""
	for x in PUK:
		if x[0] == k:
			n = x[1]
	Events.power_unlocked.emit(k, n, s.lv)


## Marca o tiro do jogador com o estado dos poderes (NF.tag do HTML).
func tag(p: Projectile) -> void:
	if p.color == Color("#eeff00"):
		return
	p.ally = true
	p.wg = nx.wings > 0 and mv > 40.0
	p.shield_shot = g.player.shield > 0.0
	if nx.prism > 0:
		hue = fmod(hue + 41.0, 360.0)
		p.color = Draw.hsl(hue, 1.0, 0.6)
		p.pr = true
	if nx.rico > 0 and randf() < minf(0.6, 0.25 + 0.1 * nx.rico):
		p.rb = mini(3, nx.rico + 1)


## Chamado quando um inimigo morre (drops = pickups que ele soltou).
func on_kill(e: Enemy, drops: Array) -> void:
	if nx.bh > 0 and BH.size() < mini(4, 1 + nx.bh) and randf() < minf(0.6, CFG.bhBase + CFG.bhLvl * (nx.bh - 1)):
		var near := false
		for b in BH:
			if Vector2(b.x - e.x, b.y - e.y).length() < b.r * 0.7:
				near = true
		if not near:
			BH.append({"x": e.x, "y": e.y, "t": 0.0, "d": 2.2 + 0.4 * nx.bh, "r": 100.0 + 20.0 * nx.bh, "a": 0.0})
			Events.skill_activated.emit("blackhole", e.x, e.y)
	if nx.luck > 0:
		for q in drops:
			if randf() < 0.5:
				g.add_pickup(q.x + randf() * 24.0 - 12.0, q.y + randf() * 24.0 - 12.0, q.type)
				Events.luck_double.emit(q.x, q.y)
				unlock("luck")
	var f: Dictionary = e.fatal if e.fatal is Dictionary else {}
	for pair in [["shock", "shock"], ["bh", "bh"], ["sh", "shield"], ["wg", "wings"], ["pr", "prism"], ["tu", "turret"], ["rico", "rico"], ["cr", "crit"]]:
		if f.get(pair[0], false):
			unlock(pair[1])
	if g.player.mag > 0:
		var R: float = 90.0 + 50.0 * g.player.mag
		for q in drops:
			if Vector2(q.x - g.player.x, q.y - g.player.y).length() < R:
				unlock("mag")
				break


## Ricochete nas bordas (arena fechada usa as paredes dela).
func pre(dt: float) -> void:
	var box: Rect2 = g.ricochet_box()
	for p in g.projectiles:
		if p.rb <= 0:
			continue
		var nx_: float = p.x + p.vx * dt
		var ny_: float = p.y + p.vy * dt
		var h := false
		if (nx_ < box.position.x and p.vx < 0.0) or (nx_ > box.end.x and p.vx > 0.0):
			p.vx = -p.vx
			p.x = clampf(p.x, box.position.x + 3.0, box.end.x - 3.0)
			h = true
		if (ny_ < box.position.y and p.vy < 0.0) or (ny_ > box.end.y and p.vy > 0.0):
			p.vy = -p.vy
			p.y = clampf(p.y, box.position.y + 3.0, box.end.y - 3.0)
			h = true
		if h:
			p.rb -= 1
			p.bn += 1
			Events.projectile_ricochet.emit(p.x, p.y, p.color)


func post(dt: float) -> void:
	var pl: PlayerState = g.player
	if mv > 20.0:
		TRL.append(Vector2(pl.x, pl.y))
	elif TRL.size() > 0:
		TRL.remove_at(0)
	while TRL.size() > int(Settings.s.tl):
		TRL.remove_at(0)
	# Electro-shock: foca o inimigo mais próximo e ganha dano enquanto mantém o alvo
	if nx.shock > 0:
		var c: Enemy = null
		var m: float = 115.0 + 15.0 * nx.shock
		for e in g.enemies:
			if e.vis == 0:
				continue
			var d := Vector2(e.x - pl.x, e.y - pl.y).length()
			if d < m:
				m = d
				c = e
		if c:
			if sk_target == c:
				sk_s += dt * 2.5 * nx.shock
			else:
				sk_target = c
				sk_s = 1.0
			g.dmg_e(c, 36.0 * sk_s * dt, {"shock": true})
		else:
			sk_target = null
			sk_s = 1.0
	for i in range(BH.size() - 1, -1, -1):
		var b: Dictionary = BH[i]
		b.t += dt
		if b.t > b.d:
			BH.remove_at(i)
			continue
		for e in g.enemies:
			var dx: float = b.x - e.x
			var dy: float = b.y - e.y
			var d := sqrt(dx * dx + dy * dy)
			if d < b.r:
				var f: float = 1.0 - d / b.r
				var v := 0.0
				if d > 6.0:
					v = (120.0 + 40.0 * nx.bh) * f * (0.0 if not e.bd.is_empty() else (0.2 if e.is_boss else 1.0)) * dt
				if v != 0.0:
					e.x += dx / d * v
					e.y += dy / d * v
				g.dmg_e(e, (10.0 + 8.0 * nx.bh) * (0.4 + f) * dt, {"bh": true})
	for i in range(TR.size() - 1, -1, -1):
		var s: Dictionary = TR[i]
		s.t += dt
		if s.t >= s.d:
			TR.remove_at(i)
			Events.turret_expired.emit(s.x, s.y)
			continue
		var b: Enemy = null
		var m := 200.0
		for e in g.enemies:
			if e.vis == 0:
				continue
			var d := Vector2(e.x - s.x, e.y - s.y).length()
			if d < m:
				m = d
				b = e
		s.lk = minf(1.0, s.lk + dt * 4.0) if b else maxf(0.0, s.lk - dt * 3.0)
		s.rc = maxf(0.0, s.rc - dt * 8.0)
		if b:
			var df := atan2(b.y - s.y, b.x - s.x) - float(s.a)
			df = atan2(sin(df), cos(df))
			s.a += df * minf(1.0, dt * 14.0)
		s.l += dt
		if s.l > 0.4 / nx.turret and b and s.t > 0.4:
			var q := Projectile.new(s.x, s.y, cos(s.a) * 500.0, sin(s.a) * 500.0, Color("#eeff00"), false, pl.area_scale)
			q.tu = true
			g.projectiles.append(q)
			s.l = 0.0
			s.rc = 1.0
	# ---- só visual a partir daqui ----
	mv += (Vector2(pl.x - px, pl.y - py).length() / maxf(dt, 0.001) - mv) * 0.25
	px = pl.x
	py = pl.y
	var fx: FxLayer = g.fx
	var qk: float = Settings.quality().k
	if nx.wings > 0 and Settings.s.trails and mv > 40.0:
		wt += dt
		if wt > 0.035:
			wt = 0.0
			if randf() < qk:
				var a := pl.angle
				var ca := cos(a)
				var sn := sin(a)
				var L := 14.0 + 6.0 * mini(nx.wings, 4)
				for sg in [-1.0, 1.0]:
					var lx := -L * 1.3
					var ly: float = sg * L * 0.9
					fx.p(pl.x + lx * ca - ly * sn, pl.y + lx * sn + ly * ca, -ca * 50.0, -sn * 50.0, 0.45, 3.0, Color("#00f2ff") if sg > 0.0 else Color("#c07bff"))
	for b in BH:
		b.a += dt
		if b.a > 0.07:
			b.a = 0.0
			if randf() < qk * float(Settings.s.intensity):
				var th := randf() * TAU
				var r0: float = b.r * (0.7 + randf() * 0.3)
				var v := r0 / 0.7
				fx.p(b.x + cos(th) * r0, b.y + sin(th) * r0, -cos(th) * v - sin(th) * 70.0, -sin(th) * v + cos(th) * 70.0, 0.65, 2.5, Color("#7000ff") if randf() < 0.5 else Color("#c07bff"))
	if nx.shock > 0 and sk_target and Settings.s.q > 0 and randf() < 0.5 * qk:
		fx.p(sk_target.x, sk_target.y, (randf() - 0.5) * 220.0, (randf() - 0.5) * 220.0, 0.25, 2.0, Color("#7000ff"))
	var cr := pl.hp < pl.max_hp * 0.2
	if cr != was_crit:
		was_crit = cr
		Events.player_critical_health.emit(cr)
	for k in PL.keys():
		PL[k] = maxf(0.0, PL[k] - dt * 2.0)


# ---------------- desenho ----------------
func draw_trail(ci: CanvasItem) -> void:
	if not Settings.s.trails or TRL.is_empty():
		return
	var n := TRL.size()
	for i in n:
		var k := float(i + 1) / n
		Draw.circle(ci, TRL[i], g.player.radius * (0.4 + 0.5 * k), Color(0, 0.95, 1, k * 0.35))


func draw_world(ci: CanvasItem) -> void:
	for b in BH:
		FxLayer.draw_black_hole(ci, Vector2(b.x, b.y), b.r, b.t, b.d)
	_draw_turrets(ci)
	_draw_wings(ci)
	_draw_shield(ci)
	_draw_shock(ci)


func draw_add(ci: CanvasItem) -> void:
	# Prisma: halo colorido aditivo em volta dos tiros prismáticos
	if nx.prism > 0 and Settings.s.bloom and Settings.s.q > 0:
		for p in g.projectiles:
			if p.pr:
				Draw.circle(ci, Vector2(p.x, p.y), p.radius * 2.4, Draw.alpha(p.color, 0.3))


func _draw_turrets(c: CanvasItem) -> void:
	for s in TR:
		var k := minf(1.0, s.t / 0.5) * clampf((s.d - s.t) / 1.2, 0.0, 1.0)
		var a: float = s.a
		var rc: float = s.rc * 5.0
		var al := 0.55 + 0.45 * sin(s.t * 12.0) if s.d - s.t < 10.0 else 1.0
		var sc := 0.4 + 0.6 * k
		var o := Vector2(s.x, s.y)
		c.draw_set_transform(o, 0.0, Vector2(sc, sc))
		var hexp := Draw.reg(6, 15.0, 0.52)
		Draw.poly(c, hexp, Color(0.1, 0.11, 0.15, al))
		Draw.poly_stroke(c, hexp, Color(0.93, 1, 0, al), 2.0)
		var pc := Color(0.17, 0.19, 0.25, al)
		c.draw_rect(Rect2(-17, -3, 5, 6), pc)
		c.draw_rect(Rect2(12, -3, 5, 6), pc)
		c.draw_rect(Rect2(-3, -17, 6, 5), pc)
		c.draw_rect(Rect2(-3, 12, 6, 5), pc)
		c.draw_set_transform(o, a, Vector2(sc, sc))
		c.draw_rect(Rect2(-4 - rc, -7, 14, 14), Color(0.23, 0.25, 0.34, al))
		c.draw_rect(Rect2(8 - rc, -3, 13, 6), Color(0.93, 1, 0, al))
		c.draw_rect(Rect2(19 - rc, -4, 4, 8), Color(0.04, 0.04, 0.08, al))
		if s.rc > 0.5:
			Draw.poly(c, PackedVector2Array([Vector2(23, 0), Vector2(33, -4), Vector2(33, 4)]), Color(1, 1, 1, s.rc))
		c.draw_set_transform(o, 0.0, Vector2(sc, sc))
		Draw.circle(c, Vector2.ZERO, 4.0 + s.rc * 2.0, Color.WHITE if s.lk > 0.5 else Color("#eeff00"))
		c.draw_set_transform_matrix(Transform2D.IDENTITY)
		if s.lk > 0.0:
			Draw.dashed_ring(c, o, 26.0 + 8.0 * (1.0 - s.lk), 3.0, 4.0, 0.0, Color(0.93, 1, 0, 0.4 * s.lk), 1.0)
		Draw.arc(c, o, 22.0, -PI / 2.0, -PI / 2.0 + TAU * (1.0 - s.t / s.d), Color(0, 0.95, 1, 0.55 * 0.6), 2.0)


func _draw_wings(c: CanvasItem) -> void:
	var l: int = nx.wings
	if l <= 0:
		return
	var L := 14.0 + 6.0 * mini(l, 4)
	var f := 0.0 if Settings.s.reduce else sin(g.game_time * 9.0) * (0.1 + minf(0.25, mv / 1200.0))
	var pl_ := 1.0 + minf(0.3, mv / 900.0)
	var P: PlayerState = g.player
	c.draw_set_transform(Vector2(P.x, P.y), P.angle, Vector2.ONE)
	for sg in [-1.0, 1.0]:
		var pts := PackedVector2Array([Vector2(-2, sg * 6), Vector2(-L * 1.1 * pl_, sg * L * 1.5 * (1 + f)), Vector2(-L * 0.7, sg * L * 0.6),
			Vector2(-L * 1.6 * pl_, sg * L * 0.55 * (1 + f)), Vector2(-L * 0.3, sg * L * 0.2)])
		Draw.poly(c, pts, Color(0.44, 0, 1, 0.28))
		Draw.poly_stroke(c, pts, Color("#00f2ff"), 1.5)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_shield(c: CanvasItem) -> void:
	var P: PlayerState = g.player
	if not (P.shield > 0.0) or P.shield_max <= 0.0:
		return
	var f := minf(1.0, P.shield / P.shield_max)
	var m := 0.0 if Settings.s.reduce else 1.0
	var r := P.radius + 11.0 + sin(g.game_time * 4.0) * 1.5 * m
	var hx := Draw.reg(6, r, g.game_time * 0.8 * m, Vector2(P.x, P.y))
	Draw.poly(c, hx, Color(0, 0.95, 1, 0.07 + 0.1 * f))
	Draw.poly_stroke(c, hx, Color(0, 0.95, 1, 0.25 + 0.5 * f), 2.0)


func _draw_shock(c: CanvasItem) -> void:
	if nx.shock <= 0 or sk_target == null:
		return
	var w := minf(2.0 + sk_s / 3.0, 8.0)
	var a := Vector2(g.player.x, g.player.y)
	var b := Vector2(sk_target.x, sk_target.y)
	FxLayer.jag(c, a, b, Color("#7000ff"), 0.9, w + 2.0)
	if Settings.s.q > 1:
		FxLayer.jag(c, a, b, Color("#00f2ff"), 0.8, w * 0.5)


## Chips das evoluções liberadas (rChips), em coordenadas de tela.
func draw_chips(c: CanvasItem, top: float) -> void:
	var y := top
	for x in PUK:
		var s: Dictionary = PU[x[0]]
		if s.st != 2:
			continue
		Draw.text(c, Assets.font_mono_bold, "✦ %s Nv%d PRONTO" % [x[2], s.lv], Vector2(20.0 + float(PL.get(x[0], 0.0)) * 6.0, y), 10, Color(1, 0.8, 0, 0.9))
		y += 13.0
