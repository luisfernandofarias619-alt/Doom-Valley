class_name BossEncounter
extends RefCounted
## Encontros de chefe (ENC, BD, bossAI, startEnc, spawnBoss, bossDead, encUpd do HTML v3.6 + v6.0).
## Ordem: Rhino → Drácula → Vesperon → Illuminatti → Anomalia (1ª pessoa) → Espelho.

## Tabela dos chefes (valores finais do HTML depois de todas as camadas da v6).
const BD := [
	{"id": "rhino", "n": "RHINO", "c": "#ff3344", "r": 54.0, "hp": 3200.0, "t": 55.0, "cd": 45.0, "phs": [0.5, 0.2], "stride": 0.075},
	{"id": "dracula", "n": "DRÁCULA", "c": "#ff2b55", "r": 34.0, "hp": 3400.0, "t": 48.0, "cd": 16.0, "phs": [0.5, 0.18]},
	{"id": "vesperon", "n": "VESPERON", "c": "#ff9a3d", "r": 40.0, "hp": 3800.0, "t": 55.0, "cd": 14.0, "phs": [0.5, 0.12]},
	{"id": "illuminati", "n": "ILLUMINATTI", "c": "#3dff7a", "r": 54.0, "hp": 4600.0, "t": 45.0, "cd": 20.0, "phs": [0.66, 0.33]},
	{"id": "anomalia", "n": "ANOMALIA DIMENSIONAL", "c": "#9b5cff", "r": 44.0, "hp": 1400.0, "t": 35.0, "cd": 28.0, "phs": [0.66, 0.33]},
	{"id": "espelho", "n": "ESPELHO", "c": "#ff3df2", "r": 26.0, "hp": 6000.0, "t": 80.0, "cd": 26.0, "phs": [0.5, 0.2]},
]
## Força × estranheza: pontuação de progressão = força + 1,5 × estranheza.
const FE := {"rhino": [5, 1], "dracula": [6, 3], "vesperon": [7, 4], "illuminati": [7, 6], "anomalia": [5, 9], "espelho": [6, 10]}

var g
var st := "none"      # none | prep | active | dead | fp
var t := 0.0
var boss: Enemy = null
var behaviors := {}


func _init(game) -> void:
	g = game
	behaviors = {
		"rhino": BossRhino.new(game),
		"dracula": BossDracula.new(game),
		"vesperon": BossVesperon.new(game),
		"illuminati": BossIlluminati.new(game),
		"espelho": BossEspelho.new(game),
	}


func reset() -> void:
	st = "none"
	t = 0.0
	boss = null
	clear_visuals()


func clear_visuals() -> void:
	for k in behaviors.keys():
		if behaviors[k].has_method("clear_visuals"):
			behaviors[k].clear_visuals()


func boss_index(id: String) -> int:
	for i in BD.size():
		if BD[i].id == id:
			return i
	return -1


func boss_id() -> String:
	var s: int = g.sec
	return BD[s].id if s >= 0 and s < BD.size() else ""


func entry_y() -> float:
	var A = g.arena.cur
	if A != null and A.id == "contencao" and A.has("tex"):
		return A.t + 130.0
	return hover_y()


func hover_y() -> float:
	var A = g.arena.cur
	if A == null or A.inf:
		return minf(150.0, g.world_rect().size.y * 0.25)
	var B: Rect2 = g.arena.box()
	return clampf(g.player.y - minf(300.0, g.vh / g.arena.cam.z * 0.36), B.position.y + 110.0, B.end.y - 110.0)


func _spawn_pos() -> Vector2:
	var A = g.arena.cur
	if A == null or A.inf:
		return Vector2(g.world_rect().size.x / 2.0, -90.0)
	if A.id == "contencao" and A.has("tex"):
		return Vector2(A.w / 2.0, A.t - 40.0)
	var B: Rect2 = g.arena.box()
	return Vector2(clampf(g.player.x, B.position.x + 90.0, B.end.x - 90.0), maxf(B.position.y - 70.0, g.player.y - g.vh / g.arena.cam.z * 0.5 - 90.0))


# ---------------- fluxo ----------------
func start() -> void:
	var d: Dictionary = BD[g.sec]
	if d.id == "anomalia":
		st = "fp"
		t = 0.0
		g.arena.transition(func(): g.start_fp_boss(), "A ANOMALIA", "primeira pessoa", Color("#9b5cff"))
		return
	st = "prep"
	t = 0.0
	for e in g.enemies:
		g.fx.burst(e.x, e.y, e.color, 6, 200.0)
	g.enemies.clear()
	g.enemy_projectiles.clear()
	g.hazards.clear()
	g.powers.BH.clear()
	g.powers.sk_target = null
	g.banner("SETOR %d: %s" % [g.sec + 1, d.n], Color(d.c), 2.2)
	g.shake(5.0)
	g.sfx("phase")
	g.fx.ripple(g.player.x, g.player.y, 10.0, 300.0, Color(d.c), 0.8, 0.8)
	Events.boss_start.emit(g.sec)
	var aid: String = ArenaSystem.BOSS_ARENA.get(d.id, "")
	if aid != "":
		g.arena.go(aid, true)
	g.cine.start(d.id, false)


func spawn() -> Enemy:
	var d: Dictionary = BD[g.sec]
	var sp := _spawn_pos()
	var b := Enemy.new(sp.x, sp.y, "boss")
	b.bd = d
	b.name = d.n
	b.is_boss = true
	b.is_ultra = g.sec == BD.size() - 1
	b.radius = d.r
	b.color = Color(d.c)
	var P: PlayerState = g.player
	var dps := P.damage * P.projectiles / (P.attack_speed / 1000.0)
	b.hp = roundf(maxf(maxf(d.hp, d.t * dps * 0.6), P.max_hp * 2.0 if b.is_ultra else 0.0) * float(g.cfg.bossHp))
	b.max_hp = b.hp
	b.t = 0.0
	b.cd = 2.0
	b.inv = 1.6
	b.al = 0.0
	b.sc = 1.6
	b.ph = 0
	b.seen = true
	b.vis = 1
	b.ai = behaviors.get(d.id)
	if b.ai and b.ai.has_method("on_spawn"):
		b.ai.on_spawn(b)
	g.enemies.append(b)
	return b


func boss_dead(e: Enemy) -> void:
	if st != "active":
		return
	if e.ai != null:
		e.ai.on_dead(e)
	st = "dead"
	t = 0.0
	g.hazards.clear()
	g.enemy_projectiles.clear()
	g.fx.burst(e.x, e.y, e.color, 60, 420.0)
	for i in 3:
		g.fx.ripple(e.x, e.y, 10.0, 120.0 + i * 90.0, e.color, 0.9, 0.6 + i * 0.25)
	g.shake(12.0)
	g.hitstop(0.25)
	var P: PlayerState = g.player
	P.max_hp += 10.0
	P.hp = minf(P.max_hp, P.hp + P.max_hp * 0.5)
	g.banner("VITÓRIA!" if e.is_ultra else "CHEFE DERROTADO", Color("#ffcc00"), 3.0)
	_defeated(g.sec, e.name)


func _defeated(i: int, n: String) -> void:
	var id: String = BD[i].id
	if id == "rhino":
		g.flags.roll = true
	if id == "dracula":
		g.flags.parry = true
	g.cine.stop()
	g.mir_x = false
	Events.boss_defeated.emit(i, n)
	if id == "rhino" or id == "dracula":
		g.get_tree().create_timer(2.6).timeout.connect(func():
			g.banner("ROLAMENTO LIBERADO" if id == "rhino" else "APARAR LIBERADO", Color("#9fe8ff"), 2.6))


## A Anomalia em 1ª pessoa terminou (vitória): volta ao campo e segue para o próximo setor.
func fp_defeated() -> void:
	st = "dead"
	t = 0.0
	_defeated(boss_index("anomalia"), "ANOMALIA DIMENSIONAL")


func update(dt: float) -> void:
	if not g.hazards.list.is_empty():
		g.hazards.update(dt)
	for k in behaviors.keys():
		behaviors[k].update_always(dt)
	if st == "none":
		if g.active and not g.won and g.cfg.bosses and g.pk >= Game.BOSS_AT[g.sec] and not g.arena.is_fenda():
			start()
		return
	t += dt
	if st == "prep" and t >= 2.2:
		st = "active"
		t = 0.0
		boss = spawn()
	elif st == "dead" and t >= 3.0:
		st = "none"
		boss = null
		if g.sec < BD.size() - 1:
			g.sec += 1
			g.pk = 0
			g.ht = 60.0
		else:
			g.pk = -1000000000


func pre(dt: float) -> void:
	if boss != null and boss.ai != null and boss.ai.has_method("pre"):
		boss.ai.pre(dt)


## Motor comum dos chefes (bossAI).
func boss_ai(b: Enemy, dt: float) -> void:
	var d := b.bd
	b.t += dt
	var lx: float = b.x if b.lx == null else b.lx
	var ly: float = b.y if b.ly == null else b.ly
	var s := Vector2(b.x - lx, b.y - ly).length() / maxf(dt, 0.001)
	b.spd += (s - b.spd) * 0.35
	b.lx = b.x
	b.ly = b.y
	b.wph += minf(b.spd * float(d.get("stride", 0.125)), 22.0) * dt
	b.inv = maxf(0.0, b.inv - dt)
	b.stun = maxf(0.0, b.stun - dt)
	b.chg = maxf(0.0, b.chg - dt)
	b.flash = maxf(0.0, b.flash - dt * 5.0)
	b.al = minf(1.0, b.al + dt * 1.4)
	b.sc += (1.0 - b.sc) * minf(1.0, dt * 6.0)
	var f := b.hp / b.max_hp
	var pz: Array = d.phs
	var ph := 2 if f < pz[1] else (1 if f < pz[0] else 0)
	if ph != b.ph:
		b.ph = ph
		if ph > 0:
			g.sfx("phase")
			g.banner("CHEFE: FASE %d" % (ph + 1), Color("#ff0055"), 1.8)
			g.shake(7.0)
			g.hitstop(0.08)
			g.fx.ripple(b.x, b.y, b.radius, 120.0, Color("#ff0055"), 0.9)
			b.ai.on_phase(b, ph)
	if b.t < 1.2:
		b.y += (entry_y() - b.y) * minf(1.0, dt * 2.2)
	elif g.cine.hold(b, dt):
		return
	else:
		b.ai.ai(b, dt, ph)
		return
	if b.vis != 0 and not b.chg2 and not b.no_touch and Vector2(g.player.x - b.x, g.player.y - b.y).length() < b.radius * 0.8 + g.player.radius:
		g.contact(float(d.cd) * float(g.cfg.bossDmg), b)


# ---------------- desenho ----------------
func draw_ground(c: CanvasItem) -> void:
	for k in behaviors.keys():
		behaviors[k].draw_ground(c, boss)


func draw_add(c: CanvasItem) -> void:
	if boss != null and boss.ai != null and g.enemies.has(boss):
		# halo do chefe (bossDrawAll)
		if boss.vis != 0:
			var col := boss.color
			var r: float = float(boss.bd.r) * 2.8
			Draw.radial(c, Vector2(boss.x, boss.y), r, Draw.alpha(col, (0.3 + 0.1 * sin(boss.t * 3.0)) * boss.al * 0.67), Color(col, 0.0))
		boss.ai.draw_add(c, boss)
	for k in behaviors.keys():
		if behaviors[k].has_method("draw_add_always"):
			behaviors[k].draw_add_always(c)


func draw_sprites(c: CanvasItem) -> void:
	for k in behaviors.keys():
		if behaviors[k].has_method("draw_sprites_always"):
			behaviors[k].draw_sprites_always(c)


func draw_top(c: CanvasItem) -> void:
	if boss != null and boss.ai != null and g.enemies.has(boss):
		boss.ai.draw_top(c, boss)
		if boss.vis != 0 and (boss.flash > 0.0 or boss.inv > 0.0):
			var o := Vector2(boss.x, boss.y)
			var r: float = boss.bd.r
			if boss.flash > 0.0:
				Draw.ring(c, o, r * 1.5, Color(1, 1, 1, boss.flash * 0.8), 3.0)
			if boss.inv > 0.0:
				Draw.dashed_ring(c, o, r * 1.7, 4.0, 5.0, 0.0, Color(0.62, 0.85, 1, 0.5), 2.0)
	for k in behaviors.keys():
		if behaviors[k].has_method("draw_top_always"):
			behaviors[k].draw_top_always(c)


## Barra do chefe embaixo, centralizada (NF.bossBar).
func draw_boss_bar(c: CanvasItem) -> void:
	var b := boss
	if b == null or not g.enemies.has(b):
		return
	var vw: float = g.vw
	var vh: float = g.vh
	var w := maxf(160.0, minf(420.0, vw - 200.0))
	var x := (vw - w) / 2.0
	var y := vh - 34.0
	var has_stm := b.stm >= 0.0
	c.draw_rect(Rect2(x - 4.0, y - 16.0, w + 8.0, 32.0 if has_stm else 26.0), Color(0, 0, 0, 0.55))
	c.draw_rect(Rect2(x, y, w, 8.0), Color(1, 1, 1, 0.12))
	c.draw_rect(Rect2(x, y, w * maxf(0.0, b.hp / b.max_hp), 8.0), b.color)
	for f in b.bd.phs:
		c.draw_rect(Rect2(x + w * f - 1.0, y, 2.0, 8.0), Color.BLACK)
	Draw.text(c, Assets.font_mono_bold, b.name + ("  ·  VULNERÁVEL" if b.vuln > 1.0 else ""), Vector2(vw / 2.0, y - 5.0), 11, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	if has_stm:
		c.draw_rect(Rect2(x, y + 11.0, w, 4.0), Color(1, 1, 1, 0.12))
		c.draw_rect(Rect2(x, y + 11.0, w * maxf(0.0, b.stm / 100.0), 4.0), Color("#ff9a3d") if b.exh > 0.0 else Color("#ffe08a"))
