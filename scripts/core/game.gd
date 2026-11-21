class_name Game
extends Node2D
## Orquestrador da partida (update()/draw() do jogo base + a cadeia NF.pre/NF.post do NEXUS FX do HTML).
## A ordem de atualização reproduz a do original; cada sistema vive no próprio script.

signal level_up_requested(options: Array, locked: String)
signal game_ended(stats: Dictionary)
signal victory_reached(stats: Dictionary)
signal pause_changed(on: bool)

const PRIMARY := Color("#00f2ff")
const ZONE_NAMES := ["NÚCLEO", "VÓRTEX", "FORJA", "ABISMO", "SINGULARIDADE"]
const BOSS_AT := [35, 50, 65, 80, 95, 110]
const ROLL := {"dur": 0.34, "dist": 170.0, "cost": 32.0, "ifA": 0.03, "ifB": 0.25, "rec": 0.16}
const PRYC := {"win": 0.2, "rec": 0.45, "cost": 14.0}

# ---- estado ----
var player := PlayerState.new()
var enemies: Array[Enemy] = []
var projectiles: Array[Projectile] = []
var enemy_projectiles: Array[Projectile] = []
var pickups: Array[Dictionary] = []
var fx := FxLayer.new()
var gp := FxLayer.GameParticles.new()
var powers: Powers
var hazards: Hazards
var arena: ArenaSystem
var enc: BossEncounter
var cine: BossCinematic
var sector_bg: SectorBackground

var active := false
var started := false
var paused := true          # isPaused
var paused_menu := false    # pausedM
var game_time := 0.0
var grid_offset := 0.0
var slow_t := 0.0
var cfg := {"elite": 0.04, "bosses": true, "bossHp": 1.0, "bossDmg": 1.0, "bossRate": 1.0, "ifr": 0.5}
var flags := {}             # roll / parry liberados
var score := 0
var combo := {"n": 0, "t": 0.0, "max": 0, "pop": 0.0}
var banner_d := {"txt": "", "col": Color.WHITE, "t": 0.0}
var floats: Array[Dictionary] = []
var hud_msgs: Array[Dictionary] = []
var hs := 0.0               # hitstop
var kp := 0.0               # pulso de abate (fundos)
var intensity := 0.0        # IN: densidade de inimigos (fundos)
var sec := 0
var pk := 0
var ht := 60.0              # próxima horda
var won := false
var win_t := 0.0
var mb := 0
var shk := 0.0
var shake_off := Vector2.ZERO
var vw := 1280.0
var vh := 720.0
var mir_x := false
var fp_active := false
var show_hitboxes := false   # Diagnóstico → Ver hitboxes

# modo, slot e equipamento da partida (Fase B: modos, slots v2, equipamento e armas)
var mode: Dictionary = Modes.get_mode("classico")
var slot_n := 0
var slot: Dictionary = {}
var equip: Dictionary = Equipment.default_equip()
var eq_q: Dictionary = Equipment.stats(equip)
var weapon_lv := 0
var _burst := 0
var _refl := 0

# rolamento / aparar
var rl := {"on": false, "t": 0.0, "dx": 1.0, "dy": 0.0, "cd": 0.0, "gh": []}
var pry := {"on": false, "t": 0.0, "cd": 0.0, "ok": false, "fx": 0.0, "fa": 0.0}
var slow_p := 0.0
var st_flash := 0.0
var st_cut := 0.0
var st_cut_t := 0.0

# entrada
var joy := {"active": false, "id": -1, "start": Vector2.ZERO, "v": Vector2.ZERO}
var aim := {"id": -1, "on": false, "ang": 0.0, "fire": false, "s": Vector2.ZERO, "c": Vector2.ZERO, "mouse": Vector2.ZERO, "md": false, "ddx": 0.0}
var _prev := Vector2.ZERO
var _aq := {"s": 0.0, "n": 0, "b": 0}

# camadas de desenho
@onready var bg_layer: Node2D = $Background/BG
@onready var world: Node2D = $World
@onready var floor_tex: Node2D = $World/FloorTex
@onready var floor_layer: Node2D = $World/Floor
@onready var under_add: Node2D = $World/UnderAdd
@onready var ents_layer: Node2D = $World/Ents
@onready var sprite_layer: Node2D = $World/Sprites
@onready var fx_add: Node2D = $World/FxAdd
@onready var fx_top: Node2D = $World/FxTop
@onready var dark_layer: Node2D = $World/Dark
@onready var after_dark: Node2D = $World/AfterDark
@onready var overlay: Node2D = $Overlay/Screen


func _ready() -> void:
	powers = Powers.new(self)
	hazards = Hazards.new(self)
	arena = ArenaSystem.new(self)
	enc = BossEncounter.new(self)
	cine = BossCinematic.new(self)
	sector_bg = SectorBackground.new(self)
	bg_layer.painter = _draw_background
	floor_tex.painter = func(c: CanvasItem): arena.draw_floor_tex(c)
	floor_layer.painter = _draw_floor
	under_add.painter = _draw_under_add
	ents_layer.painter = _draw_ents
	sprite_layer.painter = _draw_sprites
	fx_add.painter = _draw_fx_add
	fx_top.painter = _draw_fx_top
	dark_layer.painter = func(c: CanvasItem): arena.draw_dark(c)
	after_dark.painter = func(c: CanvasItem): enc.draw_after_dark(c)
	overlay.painter = _draw_overlay
	_connect_events()
	_resize()
	get_viewport().size_changed.connect(_resize)


func _resize() -> void:
	var s := get_viewport_rect().size
	vw = s.x
	vh = s.y
	if not arena.on():
		player.x = clampf(player.x, player.radius, vw - player.radius)
		player.y = clampf(player.y, player.radius, vh - player.radius)


# ======================================================================
# fluxo
# ======================================================================
## Partida Classic rápida (sem slot): modo Classic, equipamento padrão e sem progresso salvo em slot.
func start_classic(load_data: Dictionary = {}) -> void:
	slot_n = 0
	slot = {}
	equip = Equipment.default_equip()
	set_mode("classico")
	_start_run(load_data)


## Começa uma partida com o slot n: usa o modo, o equipamento e os desbloqueios guardados nele.
func start_slot(n: int) -> String:
	var r := SlotStore.read(n)
	if r.st != "ok":
		return r.st
	slot_n = n
	slot = r.d
	equip = slot.equip
	set_mode(String(slot.mode))
	SlotStore.set_last(n)
	_start_run({})
	return ""


## Novo jogo num slot (apaga o que havia nele).
func new_slot_game(n: int, mode_id: String) -> String:
	SlotStore.delete(n)
	SlotStore.write(n, SlotStore.new_slot(mode_id))
	return start_slot(n)


func set_mode(id: String) -> void:
	mode = Modes.get_mode(id)
	cfg.elite = float(mode.elite)
	cfg.bossHp = float(mode.ehp)
	cfg.bossRate = float(mode.brate)
	cfg.ifr = 0.15 if mode.get("noif", false) else 0.5


## Desbloqueio permanente de um chefe (rolamento, aparar). Vale também para o slot.
func grant(k: String) -> void:
	flags[k] = true
	if slot_n > 0:
		(slot.prog.unl as Dictionary)[k] = 1
		SlotStore.write(slot_n, slot)


func _start_run(load_data: Dictionary) -> void:
	_run_reset()
	active = true
	started = true
	paused = false
	paused_menu = false
	player.x = vw / 2.0
	player.y = vh / 2.0
	arena.exit_now()
	flags = (slot.prog.unl as Dictionary).duplicate() if slot_n > 0 else {}   # como no HTML: sem slot, rolamento e aparar voltam a exigir os chefes
	eq_q = Equipment.apply(player, equip, mode)
	weapon_lv = int((slot.get("wlv", {}) as Dictionary).get(equip.get("arma"), 0)) if slot_n > 0 else 0
	if not load_data.is_empty():
		_apply_save(load_data)
	sfx("start")
	Events.scene_changed.emit("classic")


func _run_reset() -> void:
	player.reset()
	powers.reset()
	enemies.clear()
	projectiles.clear()
	enemy_projectiles.clear()
	pickups.clear()
	fx.clear()
	gp.clear()
	hazards.clear()
	floats.clear()
	hud_msgs.clear()
	enc.reset()
	arena.reset()
	cine.stop()
	score = 0
	combo = {"n": 0, "t": 0.0, "max": 0, "pop": 0.0}
	game_time = 0.0
	won = false
	win_t = 0.0
	slow_t = 0.0
	ht = 60.0
	sec = 0
	pk = 0
	mb = 0
	mir_x = false
	hs = 0.0
	st_cut = 0.0
	rl.on = false
	rl.cd = 0.0
	(rl.gh as Array).clear()
	pry.on = false
	pry.cd = 0.0
	slow_p = 0.0
	sector_bg.reset()


func set_paused_menu(v: bool) -> void:
	if not active:
		return
	if v and paused:
		return
	paused_menu = v
	paused = v
	pause_changed.emit(v)


func toggle_pause() -> void:
	if not active or cine.on:
		return
	if paused_menu:
		set_paused_menu(false)
	elif not paused:
		set_paused_menu(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if active and not paused:
			set_paused_menu(true)


# ======================================================================
# loop
# ======================================================================
func _process(delta: float) -> void:
	var dt := minf(delta, 0.1)
	_auto_quality(delta)
	_update_music_context()
	if active and not paused:
		if fp_active:
			if arena.trs.on:
				arena.transition_update(minf(dt, 0.05))
			else:
				$"../AnomaliaFP".fp_update(dt)
				_post(dt)
		elif not _hitstop(dt):
			if DrawLayerProf.on():
				var t0 := Time.get_ticks_usec()
				_update(dt)
				DrawLayerProf.add("_update", Time.get_ticks_usec() - t0)
			else:
				_update(dt)
	shk *= pow(0.0005, dt)
	if shk < 0.1:
		shk = 0.0
	shake_off = Vector2((randf() - 0.5) * shk, (randf() - 0.5) * shk) if shk > 0.0 else Vector2.ZERO
	_apply_camera()
	for n in [bg_layer, floor_tex, floor_layer, under_add, ents_layer, sprite_layer, fx_add, fx_top, dark_layer, after_dark, overlay]:
		n.queue_redraw()


func _hitstop(dt: float) -> bool:
	if arena.trs.on:
		arena.transition_update(minf(dt, 0.05))
		return true
	if hs > 0.0:
		hs -= dt
		return true
	return false


func _update(dt: float) -> void:
	game_time += dt
	grid_offset = fmod(grid_offset + dt * 20.0, 50.0)
	_prev = Vector2(player.x, player.y)
	# movimento
	var mv := _move_input()
	if mv != Vector2.ZERO and not player.rolling:
		var sp := player.speed * spd_mul()
		var n := mv.normalized() if mv.length() > 1.0 else mv / mv.length()
		player.x += n.x * sp * dt
		player.y += n.y * sp * dt
		player.angle = atan2(n.y, n.x)
	var W := world_rect()
	player.x = clampf(player.x, W.position.x + player.radius, W.end.x - player.radius)
	player.y = clampf(player.y, W.position.y + player.radius, W.end.y - player.radius)
	player.hp = minf(player.max_hp, player.hp + player.regen * dt)
	_fire()
	_pre(dt)
	_update_projectiles(dt)
	_update_enemies(dt)
	_update_enemy_projectiles(dt)
	gp.update(dt, int(Settings.quality().cap))
	_post(dt)
	var rate := arena.spawn_rate()
	if rate < 0.0:
		rate = minf(0.045, 0.015 + pk * 0.00009 + sec * 0.003)
	if enc.st == "none" and randf() < rate * dt * 60.0:
		spawn_enemy()


func _move_input() -> Vector2:
	if cine.on:
		return Vector2.ZERO
	var m := Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_up", "move_down"))
	if joy.active:
		m = joy.v
	if mir_x and m != Vector2.ZERO:
		m.x = -m.x
	return m


func spd_mul() -> float:
	return (0.6 if slow_p > 0.0 else 1.0)


## NF.pre (ordem do HTML: rolamento, aparar, ricochete, lentidão da sanguessuga, invulnerabilidade, paredes, tiros).
func _pre(dt: float) -> void:
	_roll_pre(dt)
	_parry_pre(dt)
	powers.pre(dt)
	if slow_t > 0.0:
		slow_t -= dt
		player.x = _prev.x + (player.x - _prev.x) * 0.55
		player.y = _prev.y + (player.y - _prev.y) * 0.55
	player.iv = maxf(0.0, player.iv - dt)
	arena.pre(dt)
	for i in range(projectiles.size() - 1, -1, -1):
		var p := projectiles[i]
		if p.lf >= 0.0:
			p.lf -= dt
			if p.lf <= 0.0:
				projectiles.remove_at(i)
				continue
		if p.hm:
			_home(p, dt)
	enc.pre(dt)


func _home(p: Projectile, dt: float) -> void:
	var b: Enemy = null
	var md := 1e9
	for e in enemies:
		if e.vis == 0 or e.hid:
			continue
		var d := (e.x - p.x) ** 2 + (e.y - p.y) ** 2
		if d < md:
			md = d
			b = e
	if b and md < 360.0 * 360.0:
		var a := atan2(p.vy, p.vx)
		var df := atan2(b.y - p.y, b.x - p.x) - a
		df = atan2(sin(df), cos(df))
		var na := a + clampf(df, -4.0 * dt, 4.0 * dt)
		var s := Vector2(p.vx, p.vy).length()
		p.vx = cos(na) * s
		p.vy = sin(na) * s


const GRID := 96.0
var _grid := {}


## Grade espacial dos inimigos (reconstruída a cada quadro): cada tiro testa só as células vizinhas.
## Os candidatos são processados na ordem do array de inimigos, então a prioridade dos acertos é a mesma
## do laço original (o primeiro inimigo da lista que o tiro toca).
func _build_grid() -> void:
	_grid.clear()
	for i in enemies.size():
		var e := enemies[i]
		if e.vis == 0:
			continue
		var r := e.radius
		var x0 := floori((e.x - r) / GRID)
		var x1 := floori((e.x + r) / GRID)
		var y0 := floori((e.y - r) / GRID)
		var y1 := floori((e.y + r) / GRID)
		for gy in range(y0, y1 + 1):
			for gx in range(x0, x1 + 1):
				var k := Vector2i(gx, gy)
				if _grid.has(k):
					(_grid[k] as Array).append(i)
				else:
					_grid[k] = [i]


func _update_projectiles(dt: float) -> void:
	var W := world_rect()
	_build_grid()
	for i in range(projectiles.size() - 1, -1, -1):
		var p := projectiles[i]
		if p.color == Color("#eeff00") and not p.nerfed:   # ajuste da Sentinela (torreta) do original
			p.radius *= 0.8
			p.nerfed = true
		p.update(dt)
		if p.x < W.position.x or p.x > W.end.x or p.y < W.position.y or p.y > W.end.y:
			projectiles.remove_at(i)
			continue
		var cand: Array = []
		var cx := floori(p.x / GRID)
		var cy := floori(p.y / GRID)
		for gy in range(cy - 1, cy + 2):
			for gx in range(cx - 1, cx + 2):
				var k := Vector2i(gx, gy)
				if _grid.has(k):
					for idx in _grid[k]:
						if not cand.has(idx):
							cand.append(idx)
		if cand.is_empty():
			continue
		cand.sort()
		for idx in cand:
			if idx >= enemies.size():
				continue
			var e := enemies[idx]
			if p.hit.has(e) or e.vis == 0:
				continue
			var dx := p.x - e.x
			var dy := p.y - e.y
			var rr := p.radius + e.radius
			if dx * dx + dy * dy < rr * rr:
				var dmg := hit(p, e, player.damage)
				e.hp -= dmg if dmg != 0.0 else player.damage
				e.hit_timer = 0.1
				if player.prism_active or p.pc > 0:
					p.hit[e] = true
					if not player.prism_active:
						p.pc -= 1
				else:
					projectiles.remove_at(i)
					break


## Cadeia NF.hit: gancho do chefe → arma (dm6, empurrão, roubo de vida) → vulnerabilidade → crítico/guarda.
func hit(p: Projectile, e: Enemy, dmg: float) -> float:
	if e.ai != null:
		var r = e.ai.on_hit(e, p, dmg)
		if r != null:
			return r
	dmg *= p.dm6
	if e.vuln > 1.0:
		dmg *= e.vuln
	if e.inv > 0.0:
		return 1e-6
	if not e.bd.is_empty():
		e.flash = 1.0
	var cr := randf() < player.crit
	var d0 := dmg * 2.0 if cr else dmg
	var fr := e.type == "guard" and cos(atan2(p.vy, p.vx) - e.ang - PI) > 0.35
	var d := d0 * 0.25 if fr else d0
	if fr:
		fx.burst(e.x, e.y, Color("#9db4ff"), 4, 160.0)
	sfx("crit" if cr else "hit")
	fatal(e, d, {"pr": p.pr, "rico": p.bn > 0, "tu": p.tu, "wg": p.wg, "sh": p.shield_shot, "cr": cr})
	if cr:
		hitstop(0.03)
	if Settings.s.particles:
		if floats.size() >= 40:
			floats.pop_front()
		floats.append({"x": e.x + (randf() - 0.5) * 14.0, "y": e.y - e.radius, "t": 0.0, "txt": str(roundi(d)) + ("!" if cr else ""), "col": Color("#ffcc00") if cr else Color.WHITE, "big": cr})
	fx.burst(e.x, e.y, e.color, 6 if cr else 3, 110.0, 2.0)
	if cr:
		shake(1.2)
	if p.kb > 0.0 and e.bd.is_empty():
		var a := atan2(p.vy, p.vx)
		e.x += cos(a) * p.kb * 0.08
		e.y += sin(a) * p.kb * 0.08
	if p.ls > 0.0:
		player.hp = minf(player.max_hp, player.hp + p.ls)
	return d


func fatal(e: Enemy, d: float, s: Dictionary) -> void:
	if e.hp > 0.0 and e.hp - d <= 0.0 and e.fatal == null:
		e.fatal = s


## Dano direto (raio, buraco negro, vapor, barril...): respeita invulnerabilidade e vulnerabilidade.
func dmg_e(e: Enemy, a: float, s: Dictionary = {}) -> void:
	if e.inv > 0.0:
		return
	if e.vuln > 1.0:
		a *= e.vuln
	fatal(e, a, s)
	e.hp -= a


func _update_enemies(dt: float) -> void:
	for ei in range(enemies.size() - 1, -1, -1):
		if ei >= enemies.size():
			continue
		var e := enemies[ei]
		if e.ai != null:
			enc.boss_ai(e, dt)
		else:
			EnemyLogic.update(self, e, dt)
		if e.hp <= 0.0:
			_kill(e, ei)


func _kill(e: Enemy, ei: int) -> void:
	sfx("kill")
	gp.add(e.x, e.y, e.color, 40 if e.is_boss else 15, 3.0)
	var n0 := pickups.size()
	if e.elite or randf() < 0.15:
		var sh := player.shield_max > 0.0 and randf() < 0.1
		add_pickup(e.x, e.y, "shield" if sh else ("hp" if randf() < 0.3 else "xp"))
	player.kills += 1
	player.xp += (500.0 if e.is_boss else (80.0 if e.elite else 20.0)) * float(mode.xp)
	enemies.remove_at(ei)
	if e.bd.is_empty() and enc.st == "none":
		pk += 1
	var drops := pickups.slice(n0)
	Events.enemy_killed.emit({"x": e.x, "y": e.y, "color": e.color, "boss": e.is_boss, "tough": e.radius >= 25.0, "type": e.type, "elite": e.elite})
	powers.on_kill(e, drops)
	if e.type == "splitter" and enemies.size() < 140:
		for i in 2:
			enemies.append(Enemy.new(e.x + (12.0 if i else -12.0), e.y, "fragment"))
	if e.is_ultra and not won:
		won = true
		win_t = 1.6
		banner("VITÓRIA!", Color("#ffcc00"), 3.0)
		sfx("victory")
		hitstop(0.2)
	if not e.bd.is_empty():
		enc.boss_dead(e)
	check_level_up()


func _update_enemy_projectiles(dt: float) -> void:
	var W := world_rect()
	for i in range(enemy_projectiles.size() - 1, -1, -1):
		if i >= enemy_projectiles.size():
			continue
		var p := enemy_projectiles[i]
		p.update(dt)
		var d := Vector2(p.x - player.x, p.y - player.y).length()
		if d < p.radius + player.radius:
			if not _parry_projectile(p, i):
				take_damage(p.dmg, "proj")
				if i < enemy_projectiles.size() and enemy_projectiles[i] == p:
					enemy_projectiles.remove_at(i)
		elif p.x < W.position.x - 200.0 or p.x > W.end.x + 200.0 or p.y < W.position.y - 200.0 or p.y > W.end.y + 200.0:
			enemy_projectiles.remove_at(i)


## NF.post: poderes, combo/hordas, vitória, encontro, arenas, chefes, interface.
func _post(dt: float) -> void:
	powers.post(dt)
	fx.update(dt)
	if not Settings.s.particles:
		gp.clear()
	_fupd(dt)
	sector_bg.update(dt)
	kp *= pow(0.03, dt)
	if win_t > 0.0:
		win_t -= dt
		if win_t <= 0.0:
			_victory()
	enc.update(dt)
	arena.post(dt)
	cine.update(dt)
	if st_cut_t > 0.0:
		st_cut_t -= dt
		if st_cut_t <= 0.0:
			st_cut = 0.0
	for i in range(hud_msgs.size() - 1, -1, -1):
		hud_msgs[i].k -= dt
		if hud_msgs[i].k <= 0.0:
			hud_msgs.remove_at(i)
	if player.hp <= 0.0 and active:
		end_game()


func _fupd(dt: float) -> void:
	if pickups.size() > 150:
		pickups = pickups.slice(pickups.size() - 150)
	if combo.t > 0.0:
		combo.t -= dt
		if combo.t <= 0.0:
			combo.n = 0
	combo.pop *= pow(0.01, dt)
	banner_d.t -= dt
	for i in range(floats.size() - 1, -1, -1):
		var f := floats[i]
		f.y -= 36.0 * dt
		f.t += dt
		if f.t > 0.7:
			floats.remove_at(i)
	ht -= dt
	if ht <= 0.0:
		ht = 50.0
		if enc.st == "none" and enemies.size() < 100 and not arena.is_fenda():
			var n := mini(5 + sec * 3, 20)
			var v := view_rect()
			var R := v.size.length() / 2.0 + 40.0
			var c := v.get_center()
			for i in n:
				var a := float(i) / n * TAU
				enemies.append(Enemy.new(c.x + cos(a) * R, c.y + sin(a) * R, "fast" if player.kills > 20 and randf() < 0.3 else "basic"))
			banner("HORDA!", Color("#ffcc00"), 1.5)
			shake(4.0)
			vibrate(60)
	# pickups: coleta e magneto
	var R2 := 90.0 + 50.0 * player.mag
	for pi in range(pickups.size() - 1, -1, -1):
		var p := pickups[pi]
		var dx: float = player.x - p.x
		var dy: float = player.y - p.y
		var d := sqrt(dx * dx + dy * dy)
		if player.mag > 0 and d < R2 and d > 1.0:
			p.x += dx / d * 300.0 * dt
			p.y += dy / d * 300.0 * dt
		if d < player.radius + 10.0 + 10.0:
			match p.type:
				"hp":
					player.hp = minf(player.max_hp, player.hp + 15.0)
					sfx("pickHp")
				"xp":
					player.xp += 25.0
					sfx("pickXp")
				"shield":
					player.shield = minf(player.shield_max, player.shield + 15.0)
					sfx("pickHp")
			gp.add(p.x, p.y, Color("#ff0055") if p.type == "hp" else Color("#ccff00"), 5, 2.0)
			pickups.remove_at(pi)
			check_level_up()


# ======================================================================
# inimigos e drops
# ======================================================================
func spawn_enemy() -> void:
	if paused or not active or enemies.size() >= 150:
		return
	var side := randi() % 4
	var W := world_rect()
	var x := 0.0
	var y := 0.0
	match side:
		0: x = W.position.x + randf() * W.size.x; y = W.position.y - 50.0
		1: x = W.end.x + 50.0; y = W.position.y + randf() * W.size.y
		2: x = W.position.x + randf() * W.size.x; y = W.end.y + 50.0
		_: x = W.position.x - 50.0; y = W.position.y + randf() * W.size.y
	var sp = arena.spawn_point(side)
	if sp != null:
		x = sp.x
		y = sp.y
	var dk := arena.danger_kills()
	if dk < 0:
		dk = sec * 40 + pk
	var type := "basic"
	var r := randf()
	if dk > 80 and r < 0.15:
		type = "tank"
	elif dk > 40 and r < 0.2:
		type = "shooter"
	elif dk > 20 and r < 0.3:
		type = "fast"
	if type == "basic":
		var q := randf()
		if dk > 30 and q < 0.08: type = "splitter"
		elif dk > 50 and q < 0.15: type = "gunner"
		elif dk > 60 and q < 0.22: type = "guard"
		elif dk > 90 and q < 0.28: type = "rifter"
		elif dk > 110 and q < 0.34: type = "leech"
	var en := Enemy.new(x, y, type)
	Modes.apply_enemy(mode, en)
	if dk > 40 and randf() < float(cfg.elite):
		en.elite = true
		en.hp *= 2.5
		en.max_hp = en.hp
		en.radius *= 1.3
		en.speed *= 1.1
	enemies.append(en)


func add_pickup(x: float, y: float, type: String) -> void:
	pickups.append({"x": x, "y": y, "type": type, "r": 10.0})


func check_level_up() -> void:
	if player.xp >= player.xp_to_next:
		player.xp -= player.xp_to_next
		player.level += 1
		player.xp_to_next *= 1.4
		paused = true
		level_up_requested.emit(powers.offer(), powers.locked_info())


func pick_upgrade(u: Dictionary) -> void:
	powers.apply(u)
	paused = false


# ======================================================================
# dano no jogador
# ======================================================================
func take_damage(amt: float, kind: String = "proj") -> void:
	if player.is_dashing or not active:
		return
	if cine.on:
		return
	if not (amt > 0.0):
		return
	amt = Modes.incoming(mode, player.hp, amt)   # dano do modo (dificuldade, Baby, One Hit)
	if mode.get("one", false):
		player.shield = 0.0   # One Hit: escudos não protegem
	if not (amt > 0.0):
		return
	var ml := kind == "melee"
	if ml and player.iv > 0.0:
		return
	var ifr: float = cfg.ifr
	if player.shield > 0.0:
		var s0 := player.shield
		player.shield -= amt * 2.0
		var over := 0.0
		if player.shield < 0.0:
			# BUG CORRIGIDO: o escudo ficava negativo e o excedente sumia; agora o resto passa para a vida
			over = -player.shield / 2.0
			player.shield = 0.0
		Events.shield_absorbed.emit(s0 - player.shield)
		if ml and amt >= 4.0:
			player.iv = ifr
		if over <= 0.0:
			return
		amt = over
	player.hp -= amt
	if ml and amt >= 4.0:
		player.iv = ifr
	Events.player_damaged.emit(amt)
	if player.hp <= 0.0 and active:
		end_game()


## Contato corpo a corpo / área contínua: um golpe por intervalo; durante o aparo, o golpe é desviado.
func contact(dps: float, src = null) -> void:
	if player.iv > 0.0 or player.is_dashing:
		return
	if src != null and parry_active():
		parry_win(src, "golpe")
		return
	take_damage(dps * 0.45, "melee")


func end_game() -> void:
	if not active:
		return
	active = false
	_slot_progress()
	var r := SaveSystem.records()
	r.runs += 1
	r.kills = maxi(r.kills, player.kills)
	r.score = maxi(r.score, score)
	r.time = maxi(r.time, int(game_time))
	r.level = maxi(r.level, player.level)
	SaveSystem.write_records(r)
	Events.game_over.emit()
	game_ended.emit({"level": player.level, "kills": player.kills, "score": score, "time": game_time, "record": r.kills})


## Progresso do slot ao cair. No modo Hardcore (perma) o slot é apagado para sempre.
func _slot_progress() -> void:
	if slot_n <= 0:
		return
	var pr: Dictionary = slot.prog
	pr.runs = int(pr.get("runs", 0)) + 1
	pr.deaths = int(pr.get("deaths", 0)) + 1
	pr.kills = int(pr.get("kills", 0)) + player.kills
	if mode.get("perma", false):
		SlotStore.delete(slot_n)
		slot_n = 0
		slot = {}
		return
	SlotStore.write(slot_n, slot)


func _victory() -> void:
	if not active:
		return
	var r := SaveSystem.records()
	r.wins += 1
	r.kills = maxi(r.kills, player.kills)
	r.score = maxi(r.score, score)
	SaveSystem.write_records(r)
	paused = true
	Events.victory.emit()
	victory_reached.emit({"time": game_time, "score": score, "kills": player.kills, "level": player.level, "combo": combo.max})


func continue_after_victory() -> void:
	paused = false
	arena.go("fenda", false)


# ======================================================================
# disparo, rolamento, aparar
# ======================================================================
func _fire() -> void:
	if cine.on:
		return
	var now := game_time * 1000.0
	var W := Equipment.weapon(equip.get("arma"), weapon_lv)
	if now - player.last_attack <= player.attack_speed * float(W.get("cd", 1.0)):
		return
	if pry.on or rl.on:
		return
	var ang := 0.0
	if manual():
		_aim_update()
		if not aim.fire:
			return
		ang = aim.ang
		if mir_x and aim.id != -1:
			ang = PI - ang
	else:
		var best: Enemy = null
		var md := 500.0 * 500.0
		for e in enemies:
			if e.vis == 0 or e.no_aim or e.hid:
				continue
			var d := (e.x - player.x) ** 2 + (e.y - player.y) ** 2
			if d < md:
				md = d
				best = e
		if best == null:
			return
		ang = atan2(best.y - player.y, best.x - player.x)
	sfx("shoot")
	var n: int = player.projectiles + int(W.get("n", 0))
	var sd := float(W.get("sd", 0.15))
	var sp := 600.0 * float(W.get("sp", 1.0))
	for i in n:
		_spawn_shot(ang + (i - (n - 1) / 2.0) * sd, sp, W)
	if W.has("burst"):   # Códice: a cada N disparos, uma rajada de 5 páginas
		_burst += 1
		if _burst >= int(W.burst):
			_burst = 0
			for i in 5:
				var a := ang + (i - 2) * 0.32
				_spawn_shot(a, sp * 0.8, W, Color("#ff9a3d"))
	if int(eq_q.get("refl", 0)) > 0:   # Reflexo: a cada 3 disparos, um eco atira para trás
		_refl += 1
		if _refl >= 3:
			_refl = 0
			_spawn_shot(ang + PI, sp, W, Color("#ffd6ff"))
	player.last_attack = now


func _spawn_shot(a: float, sp: float, W: Dictionary, col: Color = PRIMARY) -> void:
	var p := Projectile.new(player.x, player.y, cos(a) * sp, sin(a) * sp, col, false, player.area_scale)
	_shot_tag(p, W)
	projectiles.append(p)


## Perfil da arma no projétil: dano, perfuração, empurrão, teleguiado, roubo de vida e alcance.
func _shot_tag(p: Projectile, W: Dictionary) -> void:
	if W.has("sz"):
		p.radius *= float(W.sz)
	p.dm6 = float(W.get("dm", 1.0))
	p.pc = int(W.get("pr", 0))
	p.kb = float(W.get("kb", 0.0))
	p.hm = W.has("hm")
	p.ls = float(W.get("ls", 0.0))
	p.lf = 1.7 * float(W.get("rg", 1.0)) / float(W.get("sp", 1.0))
	powers.tag(p)


func manual() -> bool:
	return bool(mode.get("man", false)) or Settings.s.aim == "man"   # modo Hardcore: tiro manual (V6.M.man)


func _aim_update() -> void:
	if aim.id == -1 and not Settings.is_touch:
		var z: float = arena.cam.z
		var sx: float = vw - aim.mouse.x if mir_x else aim.mouse.x
		var w := Vector2(arena.cam.x + sx / z, arena.cam.y + aim.mouse.y / z)
		aim.ang = atan2(w.y - player.y, w.x - player.x)
		aim.fire = aim.md


func has_unlock(k: String) -> bool:
	return flags.get(k, false)


func do_roll() -> bool:
	if not has_unlock("roll") or rl.on or rl.cd > 0.0 or pry.cd > 0.2 or not in_play() or player.hp <= 0.0:
		return false
	if fp_active:
		return $"../AnomaliaFP".fp_dash()
	var c: float = ROLL.cost
	if player.st < c:
		hud_msg("Sem estamina", Color("#ffb36b"))
		sfx("exhaust")
		st_flash = 0.5
		return false
	var m := Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_up", "move_down"))
	if joy.active:
		m = joy.v
	if mir_x:
		m.x = -m.x
	if m.length() < 0.2:
		m = Vector2(cos(player.angle), sin(player.angle))
	else:
		m = m.normalized()
	rl.on = true
	rl.t = 0.0
	rl.dx = m.x
	rl.dy = m.y
	player.st -= c
	player.st_t = 0.65
	player.rolling = true
	(rl.gh as Array).clear()
	sfx("roll")
	fx.burst(player.x, player.y, Color("#c9d6e3"), 8, 150.0, 2.0)
	Events.player_roll.emit(player.x + m.x * ROLL.dist, player.y + m.y * ROLL.dist)
	return true


func st_max_eff() -> float:
	return maxf(30.0, player.st_max - st_cut)


func _roll_pre(dt: float) -> void:
	if rl.cd > 0.0:
		rl.cd -= dt
	if st_flash > 0.0:
		st_flash -= dt
	if rl.on:
		rl.t += dt
		var k := minf(1.0, rl.t / ROLL.dur)
		var v: float = ROLL.dist / ROLL.dur * 1.6 * (1.0 - k) * (1.0 - k * 0.25)
		player.x += rl.dx * v * dt
		player.y += rl.dy * v * dt
		player.angle += dt * 22.0
		player.is_dashing = rl.t >= ROLL.ifA and rl.t <= ROLL.ifB
		var gh: Array = rl.gh
		if gh.size() < 6 and int(rl.t * 40.0) > gh.size():
			gh.append([player.x, player.y, player.angle])
		if rl.t >= ROLL.dur:
			rl.on = false
			rl.cd = ROLL.rec
			player.is_dashing = false
			player.rolling = false
			player.angle = atan2(rl.dy, rl.dx)
	if player.st_t > 0.0:
		player.st_t -= dt
	else:
		player.st = minf(st_max_eff(), player.st + 30.0 * dt)
	player.st = minf(player.st, st_max_eff())
	if slow_p > 0.0:
		slow_p -= dt


func parry_active() -> bool:
	return pry.on and pry.t <= PRYC.win


func do_parry() -> bool:
	if not has_unlock("parry") or pry.on or pry.cd > 0.0 or rl.on or not in_play() or player.hp <= 0.0:
		return false
	if player.st < PRYC.cost:
		hud_msg("Sem estamina", Color("#ffb36b"))
		sfx("exhaust")
		st_flash = 0.5
		return false
	player.st -= PRYC.cost
	player.st_t = 0.5
	pry.on = true
	pry.t = 0.0
	pry.ok = false
	pry.fa = player.angle
	sfx("swish")
	return true


func parry_win(src, kind: String) -> void:
	pry.ok = true
	pry.fx = 0.35
	player.iv = maxf(player.iv, 0.25)
	player.st = minf(st_max_eff(), player.st + PRYC.cost + 10.0)
	sfx("parry")
	hitstop(0.09)
	shake(4.0)
	var pos := Vector2(player.x, player.y)
	if src != null and src is Enemy:
		pos = (pos + Vector2(src.x, src.y)) / 2.0
	fx.burst(pos.x, pos.y, Color("#ffe08a"), 18, 300.0, 3.0)
	fx.ripple(pos.x, pos.y, 6.0, 70.0, Color("#ffe08a"), 1.0, 0.3)
	if src != null and src is Enemy:
		if not src.bd.is_empty():
			src.stg += 1
			Events.boss_parried.emit(kind)
		else:
			var a := atan2(src.y - player.y, src.x - player.x)
			src.x += cos(a) * 50.0
			src.y += sin(a) * 50.0
			src.hit_timer = 0.6
			src.hp -= player.damage * 1.5
	Events.player_parried.emit(kind)
	hud_msg("APARADO!", Color("#ffe08a"))


## Golpe de área aparável (NF.pry).
func try_parry_hazard(h: Dictionary) -> bool:
	if not parry_active() or h.get("pd", false) or not (h.get("ml", false) or h.get("slash", false) or h.get("pry", false)):
		return false
	h.pd = true
	h.hit = true
	parry_win(h.get("bsrc", enc.boss), "golpe")
	return true


## Tiros dourados aparados voltam contra quem atirou (NF.pHit).
func _parry_projectile(p: Projectile, i: int) -> bool:
	if not p.pry or not parry_active():
		return false
	enemy_projectiles.remove_at(i)
	var s = p.src if (p.src != null and enemies.has(p.src)) else enc.boss
	var a := atan2(s.y - p.y, s.x - p.x) if s != null else atan2(-p.vy, -p.vx)
	var sp := Vector2(p.vx, p.vy).length() * 1.4 + 120.0
	var q := Projectile.new(p.x, p.y, cos(a) * sp, sin(a) * sp, Color("#ffe08a"), false, 1.0)
	q.radius = maxf(5.0, p.radius)
	q.dm6 = 3.0
	q.lf = 2.0
	q.refl = true
	projectiles.append(q)
	parry_win(null, "tiro")
	return true


func _parry_pre(dt: float) -> void:
	if pry.cd > 0.0:
		pry.cd -= dt
	if pry.fx > 0.0:
		pry.fx -= dt
	if pry.on:
		pry.t += dt
		if pry.t > PRYC.win:
			pry.on = false
			if pry.ok:
				pry.cd = 0.12
			else:
				pry.cd = PRYC.rec
				slow_p = PRYC.rec
				sfx("pfail")
				Events.player_parry_miss.emit()


func in_play() -> bool:
	return active and not paused


# ======================================================================
# utilidades usadas pelos sistemas
# ======================================================================
func world_rect() -> Rect2:
	return arena.world_rect()


func view_rect() -> Rect2:
	return arena.view_rect()


func ricochet_box() -> Rect2:
	return arena.ricochet_box()


func shake(p: float) -> void:
	if Settings.s.shake and not Settings.s.reduce:
		shk = minf(15.0, shk + p * float(Settings.s.intensity))


func hitstop(v: float) -> void:
	if Settings.s.shake and not Settings.s.reduce:
		hs = maxf(hs, v)


func banner(t: String, c: Color, s: float) -> void:
	banner_d.txt = t
	banner_d.col = c
	banner_d.t = s


func hud_msg(t: String, c: Color = Color.WHITE) -> void:
	if not hud_msgs.is_empty() and hud_msgs[-1].t == t and hud_msgs[-1].k > 0.4:
		return
	hud_msgs.append({"t": t, "c": c, "k": 1.6})
	if hud_msgs.size() > 4:
		hud_msgs.pop_front()


func sfx(n: String) -> void:
	Sfx.play(n)


func vibrate(ms: int) -> void:
	if Settings.s.shake and not Settings.s.reduce and Settings.s.vibr:
		Input.vibrate_handheld(ms)


func boss_shot(x: float, y: float, a: float, sp: float, col: Color, dmg: float, r: float = 5.0) -> Projectile:
	var p := Projectile.new(x, y, cos(a) * sp, sin(a) * sp, col, true)
	p.radius = r
	p.bp = true
	p.dmg = dmg * float(cfg.bossDmg)
	enemy_projectiles.append(p)
	return p


func rhino_fx(c: CanvasItem, k: int, x: float, y: float, s: float, al: float) -> void:
	var f := Assets.rhino_frame("extras", k)
	if f.is_empty() or Assets.rhino_tex == null:
		return
	var w: float = f[2] * s
	var h: float = f[3] * s
	var top := y - h * 0.85 if k == 3 else y - h / 2.0
	c.draw_texture_rect_region(Assets.rhino_tex, Rect2(x - w / 2.0, top, w, h), Rect2(f[0], f[1], f[2], f[3]), Color(1, 1, 1, al))


func _apply_camera() -> void:
	var z: float = arena.cam.z
	var cx: float = roundf(arena.cam.x * z) / z
	var cy: float = roundf(arena.cam.y * z) / z
	if mir_x and arena.on():
		# O MUNDO SE INVERTE (Espelho): a imagem do mundo é espelhada e os controles também, como no HTML.
		# CORRIGIDO: no Classic o HTML invertia só os controles (o espelho da tela exigia a cena 'arena').
		world.scale = Vector2(-z, z)
		world.position = Vector2(vw + cx * z, -cy * z) + shake_off
	else:
		world.scale = Vector2(z, z)
		world.position = -Vector2(cx, cy) * z + shake_off


func screen_to_world(p: Vector2) -> Vector2:
	return (p - world.position) / world.scale


func world_to_screen(p: Vector2) -> Vector2:
	return p * world.scale + world.position


# ======================================================================
# eventos e reações (os on('...') do HTML)
# ======================================================================
func _connect_events() -> void:
	Events.player_damaged.connect(func(a: float):
		shake(minf(9.0, a * 0.5))
		if combo.n >= 3:
			banner("COMBO PERDIDO", Color("#ff6b8f"), 0.9)
		combo.n = 0
		combo.t = 0.0
		if a >= 5.0:
			vibrate(40)
		if a >= 3.0:
			sfx("hurt"))
	Events.shield_absorbed.connect(_on_shield_absorbed)
	Events.projectile_ricochet.connect(func(x: float, y: float, c: Color):
		fx.burst(x, y, c, 4, 120.0, 2.0)
		fx.ripple(x, y, 3.0, 11.0, c, 0.7, 0.25))
	Events.luck_double.connect(func(x: float, y: float):
		fx.burst(x, y, Color("#ccff00"), 8, 150.0)
		fx.ripple(x, y, 5.0, 20.0, Color("#ccff00"), 0.8))
	Events.turret_expired.connect(func(x: float, y: float):
		fx.burst(x, y, Color("#eeff00"), 14, 200.0)
		fx.ripple(x, y, 10.0, 30.0, Color("#eeff00")))
	Events.skill_activated.connect(func(id: String, x: float, y: float):
		if id == "blackhole":
			fx.ripple(x, y, 8.0, 40.0, Color("#7000ff"), 0.8))
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.upgrade_applied.connect(func(n: String):
		sfx("unlock")
		Events.notify.emit("UPGRADE ATIVADO: " + n, Color("#ffcc00"))
		fx.burst(player.x, player.y, Color("#ffcc00"), 20, 260.0)
		shake(3.0)
		vibrate(20))
	Events.power_unlocked.connect(func(_k: String, n: String, _lv: int):
		banner("EVOLUÇÃO LIBERADA: " + n, Color("#ffcc00"), 2.2)
		Events.notify.emit("EVOLUÇÃO LIBERADA: " + n, Color("#ffcc00"))
		sfx("unlock")
		fx.burst(player.x, player.y, Color("#ffcc00"), 24, 300.0)
		fx.ripple(player.x, player.y, 10.0, 60.0, Color("#ffcc00"), 0.9)
		shake(2.0)
		vibrate(30))


var _sa := 0.0
var _slr := 0.0


func _on_shield_absorbed(a: float) -> void:
	sfx("shield")
	_sa += a
	var t := Time.get_ticks_msec()
	if t - _slr < 110:
		return
	_slr = t
	var pw := minf(1.0, _sa / 10.0)
	_sa = 0.0
	fx.ripple(player.x, player.y, player.radius + 10.0, 14.0 + 18.0 * pw, PRIMARY, 0.35 + 0.5 * pw)
	fx.burst(player.x, player.y, PRIMARY, 4 + roundi(8 * pw), 140.0)
	shake(1.0 + 3.0 * pw)


func _on_enemy_killed(d: Dictionary) -> void:
	var boss: bool = d.boss
	var tough: bool = d.tough
	shake(10.0 if boss else (4.0 if tough else 1.5))
	if boss or tough:
		fx.burst(d.x, d.y, d.color, 30 if boss else 12, 380.0 if boss else 240.0)
		fx.ripple(d.x, d.y, 8.0, 70.0 if boss else 36.0, d.color)
	combo.n += 1
	combo.t = 2.5
	combo.pop = 0.4
	combo.max = maxi(combo.max, combo.n)
	score += roundi((500.0 if boss else (30.0 if tough else 10.0)) * (1.0 + minf(combo.n, 50) / 20.0))
	if player.vamp > 0:
		if player.hp < player.max_hp:
			powers.unlock("vamp")
		player.hp = minf(player.max_hp, player.hp + 0.6 * player.vamp)
	if combo.n % 10 == 0:
		banner("COMBO x%d" % combo.n, Color("#ffcc00"), 1.0)
	kp = minf(1.0, kp + 0.3)
	if boss:
		hitstop(0.09)
		sfx("bosskill")
	else:
		if not tough:
			var tp: String = d.type
			fx.ripple(d.x, d.y, 5.0, 16.0 if tp == "fast" else (30.0 if tp == "shooter" else 22.0), d.color, 0.5, 0.35 if tp == "shooter" else 0.25)
	if d.elite:
		fx.burst(d.x, d.y, Color("#ffd966"), 14, 260.0)
		fx.ripple(d.x, d.y, 8.0, 46.0, Color("#ffd966"), 0.8)


# ======================================================================
# salvar / carregar (Classic)
# ======================================================================
func save_game() -> String:
	if not active:
		return "Partida encerrada."
	if enc.st != "none" or arena.on():
		return "Não é possível salvar durante o chefe."
	var pu := {}
	for k in powers.PU.keys():
		pu[k] = powers.PU[k].duplicate()
	var d := {"v": 1, "st": player.snapshot(), "nx": powers.nx.duplicate(), "pu": pu, "sc": score, "gt": game_time, "cm": combo.max,
		"mb": mb, "won": won, "sec": sec, "pk": pk, "flags": flags.duplicate()}
	return "Partida salva." if SaveSystem.write_save(d) else "Falha ao salvar: armazenamento indisponível."


func load_game() -> String:
	var r := SaveSystem.read_save()
	if r.st == "vazio":
		return "Nenhuma partida salva."
	if r.st != "ok":
		return "Salvamento corrompido."
	start_classic(r.d)
	paused = true
	paused_menu = true
	return "Partida carregada. Inimigos, torretas e buracos negros ativos recomeçam."


func _apply_save(d: Dictionary) -> void:
	if not (d.get("st") is Dictionary):
		return
	player.apply(d.st)
	for k in powers.nx.keys():
		if d.get("nx", {}).has(k):
			powers.nx[k] = int(d.nx[k])
	for k in powers.PU.keys():
		var q = d.get("pu", {}).get(k)
		if q is Dictionary:
			powers.PU[k] = {"lv": int(q.get("lv", 0)), "st": int(q.get("st", 0))}
	score = int(d.get("sc", 0))
	game_time = float(d.get("gt", 0.0))
	combo.max = int(d.get("cm", 0))
	won = bool(d.get("won", false))
	sec = clampi(int(d.get("sec", 0)), 0, BOSS_AT.size() - 1)
	pk = maxi(0, int(d.get("pk", 0)))
	var fl = d.get("flags", {})
	if fl is Dictionary:
		flags = fl.duplicate()
	sector_bg.reset()


# ======================================================================
# trilha: momento do jogo
# ======================================================================
func _update_music_context() -> void:
	Music.paused = paused_menu
	Music.soft_paused = paused and not paused_menu
	if not started:
		return
	if not active:
		Music.context = "over"
		return
	if won and (enc.st == "dead" or win_t > 0.0 or paused):
		Music.context = "win"
		return
	if fp_active:
		Music.context = "b%d" % enc.boss_index("anomalia") if enc.st == "fp" else "rest"
		return
	if arena.is_fenda():
		Music.context = "sx_fenda"
		return
	match enc.st:
		"prep", "active":
			var b := enc.boss
			if enc.boss_id() == "vesperon" and (b == null or b.ph == 0):
				Music.context = "bv1"
			else:
				Music.context = "b%d" % sec
		"dead":
			Music.context = "rest"
		_:
			Music.context = "s%d" % sec


func _auto_quality(delta: float) -> void:
	if not active or paused:
		return
	_aq.s += delta
	_aq.n += 1
	if _aq.n >= 120:
		var av: float = _aq.s / _aq.n
		_aq.s = 0.0
		_aq.n = 0
		if Settings.s.auto and Settings.s.q > 0 and av > 1.0 / 36.0:
			_aq.b += 1
			if _aq.b >= 2:
				_aq.b = 0
				Settings.s.q -= 1
				Settings.persist()
				Events.notify.emit("Qualidade ajustada para manter o FPS", Color("#ccff00"))
		else:
			_aq.b = 0


# ======================================================================
# entrada (teclado, mouse, toque)
# ======================================================================
func _unhandled_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("pause"):
		if cine.on and not ev.is_echo():
			return
		toggle_pause()
		return
	if cine.on and active and not paused:
		if (ev is InputEventKey and ev.pressed and not ev.echo) or (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
			cine.skip()
			return
	if not in_play():
		return
	if ev.is_action_pressed("roll"):
		do_roll()
	elif ev.is_action_pressed("parry"):
		do_parry()
	if ev is InputEventMouseMotion and ev.device != InputEvent.DEVICE_ID_EMULATION:
		aim.mouse = ev.position
	elif ev is InputEventMouseButton and ev.device != InputEvent.DEVICE_ID_EMULATION:
		aim.mouse = ev.position
		if ev.button_index == MOUSE_BUTTON_LEFT:
			aim.md = ev.pressed
	elif ev is InputEventScreenTouch:
		_touch(ev.index, ev.position, ev.pressed, true)
	elif ev is InputEventScreenDrag:
		_touch(ev.index, ev.position, true, false)


func _touch(id: int, pos: Vector2, pressed: bool, is_start: bool) -> void:
	var man := manual() or fp_active
	if is_start and pressed:
		if man and pos.x > vw * 0.5 and aim.id == -1:
			aim.id = id
			aim.s = pos
			aim.c = pos
			aim.on = true
			aim.fire = false
		elif joy.id == -1 and (pos.x <= vw * 0.5 or not man):
			joy.id = id
			joy.active = true
			joy.start = pos
			joy.v = Vector2.ZERO
	elif is_start and not pressed:
		if id == aim.id:
			aim.id = -1
			aim.on = false
			aim.fire = false
		if id == joy.id:
			joy.id = -1
			joy.active = false
			joy.v = Vector2.ZERO
	else:
		if id == aim.id:
			aim.ddx += pos.x - aim.c.x
			aim.c = pos
			var d: Vector2 = pos - aim.s
			if d.length() > 14.0:
				aim.ang = d.angle()
				aim.fire = true
		elif id == joy.id:
			var d: Vector2 = pos - joy.start
			var dl := minf(d.length(), 50.0)
			joy.v = Vector2(cos(d.angle()), sin(d.angle())) * (dl / 50.0) if d.length() > 0.0 else Vector2.ZERO


# ======================================================================
# desenho (camadas)
# ======================================================================
func _draw_background(c: CanvasItem) -> void:
	if arena.covers():
		c.draw_rect(Rect2(-30, -30, vw + 60, vh + 60), Color("#030305"))
	else:
		sector_bg.draw(c)


func _draw_floor(c: CanvasItem) -> void:
	if arena.on():
		arena.draw_floor(c)
	else:
		var v := view_rect()
		var x0 := maxf(0.0, v.position.x)
		var x1 := minf(vw, v.end.x)
		var y0 := maxf(0.0, v.position.y)
		var y1 := minf(vh, v.end.y)
		var col := Color(0, 0.95, 1, 0.05)
		var x := grid_offset + maxf(0.0, floorf((x0 - grid_offset) / 50.0)) * 50.0
		while x < x1:
			c.draw_line(Vector2(x, y0), Vector2(x, y1), col, 1.0)
			x += 50.0
		var y := grid_offset + maxf(0.0, floorf((y0 - grid_offset) / 50.0)) * 50.0
		while y < y1:
			c.draw_line(Vector2(x0, y), Vector2(x1, y), col, 1.0)
			y += 50.0
	enc.draw_ground(c)


func _draw_under_add(c: CanvasItem) -> void:
	if arena.on():
		arena.draw_floor_add(c)
	var gm := Settings.glow_mul()
	# brilho (shadowBlur) de pickups, inimigos e jogador
	if gm > 0.0:
		for p in pickups:
			var glow := absf(sin(game_time * 5.0)) * 15.0
			var col := _pickup_color(p.type)
			Draw.radial(c, Vector2(p.x, p.y), 6.0 + glow * gm, Draw.alpha(col, 0.6 * gm), Color(col, 0.0))
		for e in enemies:
			if e.bd.is_empty():
				EnemyLogic.draw_glow(self, c, e)
		var pg := (10.0 + absf(sin(game_time * 3.0)) * 20.0) * gm
		Draw.radial(c, Vector2(player.x, player.y), player.radius + pg, Color(0, 0.95, 1, 0.45 * gm), Color(0, 0.95, 1, 0))
	# tiros dos chefes ('lighter' na qualidade média/alta)
	for p in enemy_projectiles:
		if p.bp and p.spr == "":
			_draw_boss_bullet(c, p)


func _pickup_color(t: String) -> Color:
	return Color("#ff0055") if t == "hp" else (Color("#00f2ff") if t == "shield" else Color("#ccff00"))


func _draw_ents(c: CanvasItem) -> void:
	for p in pickups:
		Draw.circle(c, Vector2(p.x, p.y), 6.0, _pickup_color(p.type))
	var many := projectiles.size() > 60
	for p in projectiles:
		_draw_projectile(c, p, many)
	for p in enemy_projectiles:
		if not p.bp:
			_draw_projectile(c, p, false)
	for e in enemies:
		if e.ai != null:
			e.ai.draw(c, e)
		else:
			EnemyLogic.draw(self, c, e)
	gp.render(c)
	_draw_roll_ghosts(c)
	powers.draw_trail(c)
	if active or started:
		_draw_player(c)


func _draw_sprites(c: CanvasItem) -> void:
	for e in enemies:
		if e.ai != null:
			e.ai.draw_sprites(c, e)
	for p in enemy_projectiles:
		if p.spr != "":
			Assets.draw_atl(c, "ilu", p.spr, 0, p.x, p.y, p.ss, 1.0)
	enc.draw_sprites(c)


func _draw_projectile(c: CanvasItem, p: Projectile, many: bool) -> void:
	var lim := 2 if many else 5
	for i in p.history.size():
		if i >= lim or not Settings.s.trails:
			break
		Draw.circle(c, p.history[i], p.radius * (1.0 - i / 6.0), Draw.alpha(p.color, 0.5 - i * 0.1))
	Draw.circle(c, Vector2(p.x, p.y), p.radius + 2.0 * Settings.glow_mul(), Draw.alpha(p.color, 0.5))
	Draw.circle(c, Vector2(p.x, p.y), p.radius, Color.WHITE)


func _draw_boss_bullet(c: CanvasItem, p: Projectile) -> void:
	var r := p.radius * 2.6
	var tex := Assets.bullet_sprite(p.color)
	if p.shard:
		var a := atan2(p.vy, p.vx)
		for i in range(p.history.size() - 1, -1, -1):
			if not Settings.s.trails:
				break
			var h := p.history[i]
			c.draw_texture_rect(tex, Rect2(h.x - r * 0.8, h.y - r * 0.8, r * 1.6, r * 1.6), false, Color(1, 1, 1, 0.35 - i * 0.06))
		var L := p.radius * 4.2
		var w := p.radius * 1.5
		c.draw_set_transform(Vector2(p.x, p.y), a, Vector2.ONE)
		Draw.poly(c, PackedVector2Array([Vector2(L, 0), Vector2(0, -w), Vector2(-L * 0.7, 0), Vector2(0, w)]), p.color)
		Draw.poly(c, PackedVector2Array([Vector2(L * 0.8, 0), Vector2(0, -w * 0.35), Vector2(-L * 0.3, 0), Vector2(0, w * 0.35)]), Color(1, 1, 1, 0.9))
		c.draw_set_transform_matrix(Transform2D.IDENTITY)
	else:
		for i in range(p.history.size() - 1, -1, -1):
			if not Settings.s.trails:
				break
			var h := p.history[i]
			var q := r * (1.0 - i / 7.0)
			c.draw_texture_rect(tex, Rect2(h.x - q, h.y - q, q * 2.0, q * 2.0), false, Color(1, 1, 1, 0.5 - i * 0.09))
		c.draw_texture_rect(tex, Rect2(p.x - r, p.y - r, r * 2.0, r * 2.0), false)
	if p.pry:
		Draw.ring(c, Vector2(p.x, p.y), p.radius + 5.0, Color(1, 0.88, 0.54, 0.6 + 0.4 * sin(game_time * 20.0)), 2.0)


func _draw_roll_ghosts(c: CanvasItem) -> void:
	var gh: Array = rl.gh
	if not rl.on and gh.is_empty():
		return
	var R := player.radius
	for i in gh.size():
		var g: Array = gh[i]
		c.draw_set_transform(Vector2(g[0], g[1]), g[2], Vector2.ONE)
		Draw.poly(c, _ship(R), Color(0.62, 0.91, 1, 0.28 - i * 0.04))
	c.draw_set_transform_matrix(Transform2D.IDENTITY)
	if not rl.on:
		gh.clear()


static func _ship(R: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(R, 0), Vector2(-R, R * 0.8), Vector2(-R * 0.5, 0), Vector2(-R, -R * 0.8)])


func _draw_player(c: CanvasItem) -> void:
	if fp_active:
		return
	var al := 1.0
	if player.iv > 0.0 and active:
		al = 0.35 if int(game_time * 16.0) % 2 else 0.95
	c.draw_set_transform(Vector2(player.x, player.y), player.angle, Vector2.ONE)
	Draw.poly(c, _ship(player.radius), Draw.alpha(PRIMARY, al))
	c.draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_fx_add(c: CanvasItem) -> void:
	if Settings.s.q > 0:
		fx.render(c)
	powers.draw_add(c)
	enc.draw_add(c)


func _draw_fx_top(c: CanvasItem) -> void:
	powers.draw_world(c)
	if Settings.s.q == 0:
		fx.render(c)
	# números de dano e barras de vida de inimigos fortes
	for f in floats:
		var sz := 18 if f.big else 12
		Draw.text(c, Assets.font_mono_bold, f.txt, Vector2(f.x, f.y), sz, Draw.alpha(f.col, 1.0 - f.t / 0.7), HORIZONTAL_ALIGNMENT_CENTER)
	for e in enemies:
		if not e.is_boss and (e.radius >= 25.0 or e.elite) and e.hp < e.max_hp:
			c.draw_rect(Rect2(e.x - e.radius, e.y - e.radius - 9.0, e.radius * 2.0, 3.0), Color(1, 1, 1, 0.15 * 0.9))
			c.draw_rect(Rect2(e.x - e.radius, e.y - e.radius - 9.0, e.radius * 2.0 * maxf(0.0, e.hp / e.max_hp), 3.0), Color(1, 0, 0.33, 0.9))
	if slow_t > 0.0:
		Draw.dashed_ring(c, Vector2(player.x, player.y), player.radius + 9.0, 5.0, 5.0, 0.0, Color(0.49, 1, 0.42, 0.6), 2.0)
	hazards.draw(c)
	if show_hitboxes:
		for e in enemies:
			Draw.ring(c, Vector2(e.x, e.y), e.radius, Color.RED, 1.0)
		Draw.ring(c, Vector2(player.x, player.y), player.radius, Color.CYAN, 1.0)
	enc.draw_top(c)
	arena.draw_after(c)
	_draw_parry(c)


func _draw_parry(c: CanvasItem) -> void:
	var o := Vector2(player.x, player.y)
	if pry.on:
		var k := minf(1.0, pry.t / PRYC.win)
		Draw.arc(c, o, player.radius + 10.0 + k * 6.0, pry.fa - 1.3, pry.fa + 1.3, Color(1, 0.88, 0.54, 0.85 - k * 0.5), 3.0)
		Draw.arc(c, o, player.radius + 10.0 + k * 6.0, pry.fa - 1.3, pry.fa + 1.3, Color(1, 0.88, 0.54, (0.85 - k * 0.5) * 0.4), 8.0)
	if pry.fx > 0.0:
		for i in 8:
			var a: float = i * TAU / 8.0 + pry.fx * 6.0
			var r0 := player.radius + 12.0
			var r1: float = r0 + 18.0 * (1.0 - pry.fx / 0.35) + 10.0
			c.draw_line(o + Vector2(cos(a), sin(a)) * r0, o + Vector2(cos(a), sin(a)) * r1, Color(1, 1, 1, pry.fx / 0.35), 2.0, true)


func _draw_overlay(c: CanvasItem) -> void:
	if fp_active:
		return
	_draw_crit(c)
	if not started:
		return
	var mono := Assets.font_mono_bold
	if active:
		Draw.text(c, mono, "%s  %d pts" % [fmt_time(game_time), score], Vector2(vw - 54.0, 28.0), 14, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_RIGHT)
		if combo.n > 1:
			var k := minf(1.0, combo.t / 2.5)
			var col := Color("#ffcc00") if combo.n >= 20 else PRIMARY
			col.a = 0.4 + 0.6 * k
			Draw.text(c, mono, "x%d COMBO" % combo.n, Vector2(vw - 54.0, 50.0), int(18.0 * (1.0 + minf(0.4, combo.pop))), col, HORIZONTAL_ALIGNMENT_RIGHT)
			c.draw_rect(Rect2(vw - 54.0 - 90.0 * k, 56.0, 90.0 * k, 3.0), col)
		enc.draw_boss_bar(c)
		powers.draw_chips(c, 108.0)
	if banner_d.t > 0.0:
		var col: Color = banner_d.col
		col.a = minf(1.0, banner_d.t * 2.0)
		Draw.text(c, Assets.font_ui_black, banner_d.txt, Vector2(vw / 2.0, vh * 0.28), 28, col, HORIZONTAL_ALIGNMENT_CENTER)
	enc.draw_screen(c)
	if mir_x and arena.on():
		c.draw_rect(Rect2(2, 2, vw - 4, vh - 4), Color(1, 0.24, 0.95, 0.5 + 0.2 * sin(game_time * 4.0)), false, 4.0)
	arena.draw_screen(c)
	_draw_hud_msgs(c)
	_draw_aim(c)
	cine.draw(c)


func _draw_crit(c: CanvasItem) -> void:
	if not active or player.hp >= player.max_hp * 0.2:
		return
	var sev := 1.0 - player.hp / (player.max_hp * 0.2)
	var p := 1.0
	if Settings.s.distort and not Settings.s.reduce and Settings.s.flash:
		p = 0.75 + 0.25 * sin(Time.get_ticks_msec() / (160.0 - 90.0 * sev))
	var a := minf(0.6, (0.18 + 0.3 * sev) * p * float(Settings.s.intensity))
	# vinheta: bordas vermelhas (gradiente radial do centro para fora)
	var ctr := Vector2(vw / 2.0, vh / 2.0)
	var r_out := Vector2(vw, vh).length() / 2.0
	var r_in := minf(vw, vh) * 0.38
	var n := 48
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for i in n:
		var ang := float(i) / n * TAU
		var dir := Vector2(cos(ang), sin(ang))
		pts.append(ctr + dir * r_in)
		cols.append(Color(1, 0, 0.24, 0))
		pts.append(ctr + dir * r_out)
		cols.append(Color(1, 0, 0.24, a))
	for i in n:
		var a0 := i * 2
		var b0 := ((i + 1) % n) * 2
		idx.append_array([a0, a0 + 1, b0 + 1, a0, b0 + 1, b0])
	RenderingServer.canvas_item_add_triangle_array(c.get_canvas_item(), idx, pts, cols)
	if Settings.s.distort:
		var w := 4.0 + 6.0 * sev
		c.draw_rect(Rect2(w / 2.0, w / 2.0, vw - w, vh - w), Color(1, 0.16, 0.31, 0.25 * p), false, w)


func _draw_hud_msgs(c: CanvasItem) -> void:
	for i in hud_msgs.size():
		var m := hud_msgs[i]
		var al := minf(1.0, m.k * 2.0)
		var y := vh * 0.7 - i * 22.0
		var w := Draw.text_width(Assets.font_ui_bold, m.t, 14) + 18.0
		c.draw_rect(Rect2(vw / 2.0 - w / 2.0, y - 15.0, w, 21.0), Color(0, 0, 0, 0.67 * al))
		Draw.text(c, Assets.font_ui_bold, m.t, Vector2(vw / 2.0, y), 14, Draw.alpha(m.c, al), HORIZONTAL_ALIGNMENT_CENTER)


func _draw_aim(c: CanvasItem) -> void:
	if not manual() or not started or fp_active:
		return
	var orange := Color("#ff9a3d")
	if aim.on:
		Draw.ring(c, aim.s, 50.0, Draw.alpha(orange, 0.25), 2.0)
		var d: Vector2 = aim.c - aim.s
		var dl := minf(50.0, d.length())
		Draw.circle(c, aim.s + Vector2(cos(d.angle()), sin(d.angle())) * dl, 22.0, Draw.alpha(orange, 0.7))
	elif Settings.is_touch and in_play():
		var p := Vector2(vw * 0.75, vh * 0.62)
		Draw.dashed_ring(c, p, 46.0, 6.0, 6.0, 0.0, Draw.alpha(orange, 0.16), 1.0)
		Draw.text(c, Assets.font_mono_bold, "MIRA", p + Vector2(0, 4), 10, Draw.alpha(orange, 0.4), HORIZONTAL_ALIGNMENT_CENTER)
	if not Settings.is_touch and in_play():
		var s: Vector2 = aim.mouse
		var col := orange if aim.md else Color.WHITE
		col.a = 0.85
		Draw.ring(c, s, 9.0, col, 2.0)
		for v in [[Vector2(-15, 0), Vector2(-5, 0)], [Vector2(5, 0), Vector2(15, 0)], [Vector2(0, -15), Vector2(0, -5)], [Vector2(0, 5), Vector2(0, 15)]]:
			c.draw_line(s + v[0], s + v[1], col, 2.0)


static func fmt_time(s: float) -> String:
	return "%02d:%02d" % [int(s / 60.0), int(fmod(s, 60.0))]


# ======================================================================
# modo desenvolvedor e Anomalia
# ======================================================================
func dev_boss(i: int) -> void:
	if not active:
		start_classic()
	_run_reset()
	active = true
	started = true
	paused = false
	paused_menu = false
	player.x = vw / 2.0
	player.y = vh / 2.0
	sec = i
	pk = 0
	enc.st = "none"
	enc.start()


func dev_arena(id: String) -> void:
	if not active:
		start_classic()
	paused = false
	paused_menu = false
	arena.go(id, false)


func start_fp_boss() -> void:
	$"../AnomaliaFP".boss_start(true)


## Quebra os ciclos de referência entre sistemas (RefCounted) ao sair da árvore, para não vazar memória.
func _exit_tree() -> void:
	for s in Events.get_signal_list():
		for con in Events.get_signal_connection_list(s.name):
			var cb: Callable = con.callable
			var obj := cb.get_object()
			if obj == null or obj is RefCounted or obj == self:
				Events.disconnect(s.name, cb)
	if arena:
		arena.themes.clear()
		arena.fenda = null
		arena.cracks.clear()
		arena.cur = null
	if enc:
		enc.behaviors.clear()
		enc.boss = null
	enemies.clear()
	projectiles.clear()
	enemy_projectiles.clear()
	if powers:
		powers.upgrades.clear()
	BossRhino.wait_tasks()
	BossRhino.tint_tex = null
	PixelArt._pieces.clear()
