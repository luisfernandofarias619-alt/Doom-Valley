extends Node
## A ANOMALIA EM PRIMEIRA PESSOA (v6.0 do HTML) — câmara do chefe, usada pelo Classic.
## O HTML fazia raycasting por pixel em Canvas 2D (resolução baixa ampliada = pixel art). Aqui a mesma cena é
## montada em 3D nativo: paredes em MultiMesh com as texturas procedurais 32×32 do original, chão/teto com
## névoa em shader, sprites billboard 16×16 e áudio posicional 3D (o zumbido denuncia o Tesseract verdadeiro).
## A imagem é renderizada numa SubViewport pequena e ampliada sem filtro, como no original.
## Chefe: o Tesseract. Cópias sem sombra; Dobra (imagem de cabeça para baixo), Apagar (as paredes somem),
## Anel com uma falha, Orbes (o último é aparável), Fenda (investida marcada no chão, fase 2).

const W := 17
const H := 17
const FOG_K := 10.0

var game: Game
var on := false
var classic := false
var map := PackedByteArray()
var x := 8.5
var y := 14.5
var a := -PI / 2.0
var t := 0.0
var bob := 0.0
var kick := 0.0
var flip := 0.0
var erase := 0.0
var intro := 0.0
var glitch := 0.0
var dash := 0.0
var dcd := 0.0
var dvx := 0.0
var dvy := 0.0
var won := 0.0
var lock = null
var shots: Array[Dictionary] = []
var eshots: Array[Dictionary] = []
var boss = null          # Dictionary do Tesseract
var cpi := false
var mouse_dx := 0.0

var tex := {}            # tipo de parede -> ImageTexture
var spr := {}            # nome -> ImageTexture
var layer: CanvasLayer
var svc: SubViewportContainer
var sv: SubViewport
var root3d: Node3D
var cam: Camera3D
var walls := {}          # tipo -> MultiMeshInstance3D
var floor_mat: ShaderMaterial
var ceil_mat: ShaderMaterial
var sprite_pool: Array[Sprite3D] = []
var hud_layer: CanvasLayer
var hud: Node2D
var hum: AudioStreamPlayer3D
var sfx3d: Array[AudioStreamPlayer3D] = []


func bind(g) -> void:
	game = g


# ======================================================================
# texturas e sprites procedurais (fpTex / fpSpr do HTML)
# ======================================================================
func _textures() -> void:
	if not tex.is_empty():
		return
	var mk := func(fill: Color) -> Image:
		var im := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		im.fill(fill)
		return im
	var t1: Image = mk.call(Color("#120c1e"))
	for yy in range(0, 32, 8):
		t1.fill_rect(Rect2i(0, yy, 32, 1), Color("#1c1430"))
	for xx in range(0, 32, 16):
		t1.fill_rect(Rect2i(xx, 0, 1, 32), Color("#1c1430"))
	for r in [Rect2i(4, 12, 10, 1), Rect2i(14, 12, 1, 8), Rect2i(14, 20, 12, 1), Rect2i(26, 5, 1, 15)]:
		PixelArt.fill(t1, r.position.x, r.position.y, r.size.x, r.size.y, Color(0, 0.95, 1, 0.6))
	t1.fill_rect(Rect2i(25, 4, 3, 3), Color("#9b5cff"))
	var t2: Image = mk.call(Color("#2a0f2a"))
	var cs := [Color("#3a1640"), Color("#4a1a4a"), Color("#24092a")]
	for i in 40:
		t2.fill_rect(Rect2i((i * 13) % 32, (i * 7) % 32, 3 + (i % 4), 2), cs[i % 3])
	for yy in range(3, 32, 9):
		PixelArt.fill(t2, 0, yy, 32, 1, Color(1, 0.24, 0.95, 0.4))
	var t3: Image = mk.call(Color.BLACK)
	for yy in 32:
		for xx in 32:
			var k := (xx + yy) / 62.0
			var c := Color("#3a2a5a").lerp(Color("#ffd6ff"), k * 2.0) if k < 0.5 else Color("#ffd6ff").lerp(Color("#2a1a40"), (k - 0.5) * 2.0)
			t3.set_pixel(xx, yy, c)
	for r in [Rect2i(0, 0, 32, 2), Rect2i(0, 30, 32, 2), Rect2i(0, 0, 2, 32), Rect2i(30, 0, 2, 32)]:
		t3.fill_rect(r, Color("#0b0814"))
	var t4: Image = mk.call(Color("#05030a"))
	for i in 14:
		t4.set_pixel((i * 11 + 3) % 32, (i * 17 + 5) % 32, Color.WHITE if i % 3 else Color("#9b5cff"))
	var t5: Image = mk.call(Color("#1a0a2a"))
	t5.fill_rect(Rect2i(6, 2, 20, 30), Color("#9b5cff"))
	t5.fill_rect(Rect2i(8, 4, 16, 28), Color("#2a1440"))
	t5.fill_rect(Rect2i(20, 16, 2, 3), Color("#ffd23d"))
	for pair in [[1, t1], [2, t2], [3, t3], [4, t4], [5, t5]]:
		tex[pair[0]] = ImageTexture.create_from_image(pair[1])
	var orb := func(c: Color) -> ImageTexture:
		var im := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		for yy in 16:
			for xx in 16:
				var d := Vector2(xx + 0.5 - 8.0, yy + 0.5 - 8.0).length() / 7.0
				var col := Color.WHITE.lerp(c, clampf(d / 0.4, 0.0, 1.0)) if d < 0.4 else Color(c, clampf(1.0 - (d - 0.4) / 0.6, 0.0, 1.0))
				im.set_pixel(xx, yy, col if d <= 1.0 else Color(0, 0, 0, 0))
		return ImageTexture.create_from_image(im)
	spr.orb = orb.call(Color("#c070ff"))
	spr.my = orb.call(Color("#00f2ff"))
	spr.gold = orb.call(Color("#ffe08a"))


# ======================================================================
# cena 3D
# ======================================================================
func _build() -> void:
	if layer != null:
		return
	_textures()
	layer = CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	svc = SubViewportContainer.new()
	svc.set_anchors_preset(Control.PRESET_FULL_RECT)
	svc.stretch = true
	svc.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(svc)
	sv = SubViewport.new()
	sv.handle_input_locally = false
	sv.msaa_3d = Viewport.MSAA_DISABLED
	sv.audio_listener_enable_3d = true
	svc.add_child(sv)
	root3d = Node3D.new()
	sv.add_child(root3d)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.016, 0.008, 0.024)
	var we := WorldEnvironment.new()
	we.environment = env
	root3d.add_child(we)
	cam = Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.fov = rad_to_deg(2.0 * atan(0.66))   # mesmo campo de visão do plano de câmera 0,66 do raycaster
	cam.near = 0.05
	cam.far = 40.0
	cam.current = true
	root3d.add_child(cam)
	for k in [1, 2, 3, 5]:
		var mmi := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE
		mm.mesh = bm
		mmi.multimesh = mm
		var mat := ShaderMaterial.new()
		mat.shader = load("res://assets/shaders/fp_wall.gdshader")
		mat.set_shader_parameter("tex", tex[k])
		mat.set_shader_parameter("breathe", k == 2)
		mmi.material_override = mat
		root3d.add_child(mmi)
		walls[k] = mmi
	var plane := PlaneMesh.new()
	plane.size = Vector2(W, H)
	var fl := MeshInstance3D.new()
	fl.mesh = plane
	floor_mat = ShaderMaterial.new()
	floor_mat.shader = load("res://assets/shaders/fp_floor.gdshader")
	fl.material_override = floor_mat
	fl.position = Vector3(W / 2.0, 0.0, H / 2.0)
	root3d.add_child(fl)
	var ce := MeshInstance3D.new()
	ce.mesh = plane
	ceil_mat = ShaderMaterial.new()
	ceil_mat.shader = load("res://assets/shaders/fp_floor.gdshader")
	ceil_mat.set_shader_parameter("is_ceiling", true)
	ce.material_override = ceil_mat
	ce.position = Vector3(W / 2.0, 1.0, H / 2.0)
	ce.rotation = Vector3(PI, 0, 0)
	root3d.add_child(ce)
	for i in 64:
		var s := Sprite3D.new()
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.shaded = false
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		s.visible = false
		root3d.add_child(s)
		sprite_pool.append(s)
	hum = AudioStreamPlayer3D.new()
	hum.stream = _hum_stream()
	hum.unit_size = 4.0
	hum.max_distance = 30.0
	hum.bus = "Ambience"
	root3d.add_child(hum)
	for i in 6:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 3.0
		p.max_distance = 20.0
		p.bus = "SFX"
		root3d.add_child(p)
		sfx3d.append(p)
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 6
	add_child(hud_layer)
	hud = Node2D.new()
	hud.set_script(load("res://scripts/core/draw_layer.gd"))
	hud.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	hud_layer.add_child(hud)
	hud.painter = _draw_hud
	_show(false)


## Zumbido contínuo do Tesseract: serra de 55 Hz + seno de 77,8 Hz (loop de 5 s, ciclos inteiros = sem emenda).
func _hum_stream() -> AudioStreamWAV:
	var R := 22050
	var n := R * 5
	var b := PackedByteArray()
	b.resize(n * 2)
	for i in n:
		var tt := float(i) / R
		var s1 := 2.0 * fposmod(tt * 55.0, 1.0) - 1.0
		var s2 := sin(TAU * 77.8 * tt)
		b.encode_s16(i * 2, int(clampf((s1 * 0.5 + s2 * 0.5) * 0.6, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = R
	w.data = b
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = n
	return w


func _show(v: bool) -> void:
	if layer:
		layer.visible = v
		hud_layer.visible = v
		sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS if v else SubViewport.UPDATE_DISABLED


func _rebuild_walls() -> void:
	var by := {1: [], 2: [], 3: [], 5: []}
	for j in H:
		for i in W:
			var v := map[j * W + i]
			if v == 0:
				continue
			var k := v if by.has(v) else 1
			by[k].append(Transform3D(Basis(), Vector3(i + 0.5, 0.5, j + 0.5)))
	for k in by.keys():
		var mm: MultiMesh = walls[k].multimesh
		mm.instance_count = by[k].size()
		for n in by[k].size():
			mm.set_instance_transform(n, by[k][n])


# ======================================================================
# entrar e sair (fpBossStart / fpExit)
# ======================================================================
func boss_start(from_classic: bool) -> void:
	_build()
	if game.arena.on():
		game.arena.exit_now()
	on = true
	classic = from_classic
	game.fp_active = true
	map.resize(W * H)
	for j in H:
		for i in W:
			map[j * W + i] = 3 if (i == 0 or j == 0 or i == W - 1 or j == H - 1) else 0
	for q in [[4, 4], [12, 4], [4, 12], [12, 12]]:
		map[q[1] * W + q[0]] = 2
	_rebuild_walls()
	x = 8.5
	y = 14.5
	a = -PI / 2.0
	shots.clear()
	eshots.clear()
	flip = 0.0
	erase = 0.0
	intro = 1.2
	t = 0.0
	won = 0.0
	dash = 0.0
	var P: PlayerState = game.player
	var dps := P.damage * P.projectiles / (P.attack_speed / 1000.0)
	var hp := roundf(maxf(2800.0, 46.0 * dps) * float(game.cfg.bossHp))
	boss = {"x": 8.5, "y": 5.0, "hp": hp, "mhp": hp, "ph": 0, "cd": 2.0, "st": "idle", "t": 0.0, "cop": [], "hitT": 0.0, "name": "ANOMALIA", "lp": "", "st2": 0, "at": 0.0}
	game.sec = game.enc.boss_index("anomalia")
	game.enc.st = "fp"
	game.banner("A ANOMALIA", Color("#9b5cff"), 2.4)
	game.sfx("phase")
	_show(true)
	hum.play()
	Events.fp_boss.emit()
	game.cine.start("anomalia", true)


func fp_exit() -> void:
	on = false
	game.fp_active = false
	boss = null
	shots.clear()
	eshots.clear()
	if hum:
		hum.stop()
	_show(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if classic:
		classic = false
		game.arena.exit_now()
		game.player.x = game.vw / 2.0
		game.player.y = game.vh / 2.0


func _win() -> void:
	var b = boss
	game.sfx("victory")
	game.shake(8.0)
	game.banner("A ANOMALIA SE DESFAZ", Color("#9b5cff"), 2.6)
	boss = null
	won = 2.4
	if b != null:
		for i in 40:
			eshots.append({"x": b.x, "y": b.y, "vx": (randf() - 0.5) * 6.0, "vy": (randf() - 0.5) * 6.0, "t": 0.8, "fx": true, "d": 0.0})


# ======================================================================
# mapa e utilidades
# ======================================================================
func at(px: float, py: float) -> int:
	var i := floori(px)
	var j := floori(py)
	if i < 0 or j < 0 or i >= W or j >= H:
		return 1
	return map[j * W + i]


func los(x0: float, y0: float, x1: float, y1: float) -> bool:
	var n := ceili(Vector2(x1 - x0, y1 - y0).length() * 4.0)
	for k in range(1, n):
		if at(x0 + (x1 - x0) * k / n, y0 + (y1 - y0) * k / n):
			return false
	return true


func _sfx3d(f: float, ty: String, du: float, vo: float, px: float, py: float) -> void:
	if not Settings.s.sound or sfx3d.is_empty():
		return
	var p := sfx3d[0]
	for q in sfx3d:
		if not q.playing:
			p = q
			break
	p.stream = Sfx.synth_notes([[f, ty, du, vo, 0.0]])
	p.position = Vector3(px, 0.5, py)
	p.volume_db = linear_to_db(maxf(0.0001, Settings.sfx_volume()))
	p.play()


func _touch(d: float) -> void:
	if game.player.iv > 0.0 or dash > 0.0:
		return
	game.take_damage(d, "melee")
	glitch = 0.35
	game.shake(3.0)


# ======================================================================
# entrada
# ======================================================================
func _unhandled_input(ev: InputEvent) -> void:
	if not on or not game.in_play():
		return
	if ev is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mouse_dx += ev.relative.x
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and not Settings.is_touch:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED   # clique trava o ponteiro, como no original


func fp_dash() -> bool:
	if not game.has_unlock("roll") or dcd > 0.0:
		return false
	var c: float = Game.ROLL.cost
	var P: PlayerState = game.player
	if P.st < c:
		game.hud_msg("Sem estamina", Color("#ffb36b"))
		return false
	P.st -= c
	P.st_t = 0.65
	var f := 0.0
	var s := 0.0
	if Input.is_action_pressed("move_up"): f = 1.0
	if Input.is_action_pressed("move_down"): f = -1.0
	if Input.is_physical_key_pressed(KEY_A): s = -1.0
	if Input.is_physical_key_pressed(KEY_D): s = 1.0
	if game.joy.active:
		f = -game.joy.v.y
		s = game.joy.v.x
	if f == 0.0 and s == 0.0:
		s = 1.0
	var m := Vector2(f, s).length()
	var ca := cos(a)
	var sa := sin(a)
	dvx = (ca * f / m - sa * s / m) * 8.0
	dvy = (sa * f / m + ca * s / m) * 8.0
	dash = 0.22
	dcd = 0.5
	P.iv = maxf(P.iv, 0.25)
	game.sfx("roll")
	return true


func _input_move(dt: float) -> bool:
	var f := 0.0
	var s := 0.0
	var turn := 0.0
	# W/S andam, A/D andam de lado, setas giram (as setas ↑/↓ também andam)
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): f += 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): f -= 1.0
	if Input.is_physical_key_pressed(KEY_A): s -= 1.0
	if Input.is_physical_key_pressed(KEY_D): s += 1.0
	if Input.is_physical_key_pressed(KEY_LEFT): turn -= 1.0
	if Input.is_physical_key_pressed(KEY_RIGHT): turn += 1.0
	if game.joy.active:
		f = -game.joy.v.y
		s = game.joy.v.x
	var da: float = turn * 2.6 * dt + mouse_dx * 0.0026 * float(Settings.s.sens)
	mouse_dx = 0.0
	if game.aim.id != -1:
		da += float(game.aim.ddx) * 0.0075 * float(Settings.s.sens)
		game.aim.ddx = 0.0
	a += da
	var m := Vector2(f, s).length()
	if m > 1.0:
		f /= m
		s /= m
	var sp := (7.0 if dash > 0.0 else 3.1) * (0.6 if game.slow_p > 0.0 else 1.0)
	var ca := cos(a)
	var sa := sin(a)
	var vx := (ca * f - sa * s) * sp
	var vy := (sa * f + ca * s) * sp
	if dash > 0.0:
		vx = dvx
		vy = dvy
		dash -= dt
	var r := 0.22
	var nx := x + vx * dt
	var ny := y + vy * dt
	var sx := signf(vx)
	if not at(nx + sx * r, y) and not at(nx + sx * r, y + r * 0.7) and not at(nx + sx * r, y - r * 0.7):
		x = nx
	var sy := signf(vy)
	if not at(x, ny + sy * r) and not at(x + r * 0.7, ny + sy * r) and not at(x - r * 0.7, ny + sy * r):
		y = ny
	bob += m * dt * (0.0 if dash > 0.0 else 9.0)
	var fire := false
	if Settings.is_touch:
		fire = game.aim.on
	else:
		fire = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if not game.manual() and lock != null:
		fire = true
	return fire


# ======================================================================
# atualização (fpUpd)
# ======================================================================
func fp_update(dt: float) -> void:
	if not on:
		return
	t += dt
	game.game_time += dt
	if intro > 0.0:
		intro -= dt
	var cine: bool = game.cine.on
	var fire := false
	if cine:
		_input_move(0.0)
	else:
		fire = _input_move(dt)
	if dcd > 0.0: dcd -= dt
	if kick > 0.0: kick -= dt * 6.0
	if flip > 0.0: flip -= dt
	if erase > 0.0: erase -= dt
	if glitch > 0.0: glitch -= dt
	var P: PlayerState = game.player
	P.iv = maxf(0.0, P.iv - dt)
	P.hp = minf(P.max_hp, P.hp + P.regen * dt)
	game._roll_pre(dt)
	game._parry_pre(dt)
	# mira automática opcional: trava no alvo dentro de um cone estreito
	lock = null
	if not game.manual():
		var bd := 1e9
		var tg: Array = []
		if boss != null:
			tg.append(boss)
			tg.append_array(boss.cop)
		for e in tg:
			if e.get("hp", 1.0) <= 0.0:
				continue
			var ea := atan2(e.y - y, e.x - x)
			var df := absf(angle_difference(a, ea))
			var d := Vector2(e.x - x, e.y - y).length()
			if df < 0.16 and d < 10.0 and d < bd and los(x, y, e.x, e.y):
				bd = d
				lock = e
	var now := game.game_time * 1000.0
	if fire and now - P.last_attack > P.attack_speed:
		P.last_attack = now
		var n := P.projectiles
		var sd := 0.15 * 0.5
		for i in n:
			var aa := a + (i - (n - 1) / 2.0) * sd
			shots.append({"x": x + cos(aa) * 0.3, "y": y + sin(aa) * 0.3, "vx": cos(aa) * 11.0, "vy": sin(aa) * 11.0, "t": 1.4, "d": P.damage, "pc": 0})
		kick = 1.0
		game.sfx("shoot")
	for i in range(shots.size() - 1, -1, -1):
		var s: Dictionary = shots[i]
		s.x += s.vx * dt
		s.y += s.vy * dt
		s.t -= dt
		if s.t <= 0.0 or at(s.x, s.y):
			shots.remove_at(i)
			continue
		if boss != null:
			var T: Array = [boss]
			T.append_array(boss.cop)
			for e in T:
				if e.get("hp", 1.0) <= 0.0:
					continue
				if Vector2(e.x - s.x, e.y - s.y).length() < (0.7 if e == boss else 0.45):
					_hurt(e, s.d)
					if s.pc > 0:
						s.pc -= 1
					else:
						shots.remove_at(i)
					break
	for i in range(eshots.size() - 1, -1, -1):
		var s: Dictionary = eshots[i]
		s.x += s.vx * dt
		s.y += s.vy * dt
		s.t -= dt
		if s.t <= 0.0 or (not s.get("fx", false) and at(s.x, s.y)):
			eshots.remove_at(i)
			continue
		if s.get("fx", false):
			continue
		if Vector2(s.x - x, s.y - y).length() < 0.32:
			if s.get("pry", false) and game.parry_active():
				eshots.remove_at(i)
				shots.append({"x": s.x, "y": s.y, "vx": -s.vx * 1.5, "vy": -s.vy * 1.5, "t": 1.5, "d": P.damage * 3.0, "pc": 0})
				game.parry_win(null, "tiro")
				continue
			if dash <= 0.0:
				game.take_damage(s.d, "proj")
				glitch = 0.25
			eshots.remove_at(i)
	_boss_update(dt)
	if won > 0.0:
		won -= dt
		if won <= 0.0:
			won = 0.0
			var cls := classic
			fp_exit()
			if cls:
				game.enc.fp_defeated()
	_hum_update()
	if P.hp <= 0.0 and game.active:
		game.end_game()


func _hurt(e: Dictionary, d: float) -> void:
	if e == boss:
		e.hp -= d
		e.hitT = 0.12
		_sfx3d(180.0, "square", 0.08, 0.06, e.x, e.y)
		if e.hp <= 0.0:
			_win()
		elif e.ph == 0 and e.hp < e.mhp * 0.5:
			e.ph = 1
			game.banner("O TESSERACT SE DIVIDE", Color("#9b5cff"), 2.0)
			game.sfx("phase")
			game.shake(5.0)
		return
	if e.get("dec", false):   # cópia: some e solta um anel
		e.hp = 0.0
		_sfx3d(900.0, "triangle", 0.15, 0.06, e.x, e.y)
		for k in 6:
			var q := k * TAU / 6.0
			eshots.append({"x": e.x, "y": e.y, "vx": cos(q) * 2.6, "vy": sin(q) * 2.6, "t": 3.0, "d": 7.0})


func _boss_update(dt: float) -> void:
	var b = boss
	if b == null:
		return
	if b.hp <= 0.0:
		_win()
		return
	if game.cine.on:
		b.t = minf(b.t, 0.5)
		b.cd = maxf(b.cd, 1.2)
		return
	b.t += dt
	b.hitT = maxf(0.0, b.hitT - dt)
	var d := Vector2(b.x - x, b.y - y).length()
	var rate: float = game.cfg.bossRate
	if b.st == "idle":
		var aa: float = b.t * 0.4
		var tx: float = 8.5 + cos(aa) * (4.0 if b.ph else 3.0)
		var ty: float = 8.5 + sin(aa * 1.3) * (4.0 if b.ph else 3.0)
		b.x += (tx - b.x) * dt * 0.8
		b.y += (ty - b.y) * dt * 0.8
		b.cd -= dt
		if b.cd <= 0.0:
			var L := ["orbe", "anel", "copias", "dobra", "apagar", "fenda"] if b.ph else ["orbe", "anel", "copias", "dobra", "apagar"]
			var n: String = L[randi() % L.size()]
			while n == b.lp:
				n = L[randi() % L.size()]
			b.lp = n
			b.st = n
			b.st2 = 0
			b.at = 0.0
	else:
		b.at += dt
		var ang := atan2(y - b.y, x - b.x)
		match String(b.st):
			"orbe":
				if b.at > 0.7 and b.st2 < 3:
					b.st2 += 1
					b.at = 0.45
					for i in range(-1, 2):
						eshots.append({"x": b.x, "y": b.y, "vx": cos(ang + i * 0.16) * 4.2, "vy": sin(ang + i * 0.16) * 4.2, "t": 5.0, "d": 10.0, "pry": b.st2 == 3})
					_sfx3d(330.0, "square", 0.15, 0.07, b.x, b.y)
				if b.st2 >= 3 and b.at > 0.9:
					_end(b, rate)
			"anel":
				if b.st2 == 0 and b.at > 0.8:
					b.st2 = 1
					var n := 18
					var gap := randi() % n
					for i in n:
						if i == gap or i == (gap + 1) % n:
							continue
						var q := float(i) / n * TAU
						eshots.append({"x": b.x, "y": b.y, "vx": cos(q) * 2.8, "vy": sin(q) * 2.8, "t": 6.0, "d": 12.0})
					_sfx3d(200.0, "sawtooth", 0.3, 0.08, b.x, b.y)
					game.banner("ANEL · PROCURE A FALHA", Color("#c070ff"), 1.2)
				if b.at > 1.6:
					_end(b, rate)
			"copias":
				if b.st2 == 0:
					b.st2 = 1
					b.cop = []
					for i in 3:
						var q := i / 3.0 * TAU + randf()
						b.cop.append({"x": 8.5 + cos(q) * 4.0, "y": 8.5 + sin(q) * 4.0, "hp": 1.0, "dec": true, "cd": 1.5})
					var q2 := randf() * TAU
					b.x = 8.5 + cos(q2) * 4.0
					b.y = 8.5 + sin(q2) * 4.0
					_sfx3d(700.0, "triangle", 0.3, 0.06, b.x, b.y)
					if not cpi:
						cpi = true
						game.banner("SÓ O VERDADEIRO TEM SOMBRA (E O ZUMBIDO)", Color("#c070ff"), 2.4)
				for cc in b.cop:
					if cc.hp > 0.0:
						cc.cd -= dt
						if cc.cd <= 0.0:
							cc.cd = 2.4
							var q := atan2(y - cc.y, x - cc.x)
							eshots.append({"x": cc.x, "y": cc.y, "vx": cos(q) * 3.0, "vy": sin(q) * 3.0, "t": 4.0, "d": 7.0})
				if b.at > 7.0:
					b.cop = []
					_end(b, rate)
			"dobra":
				if b.st2 == 0:
					b.st2 = 1
					game.banner("O ESPAÇO DOBRA", Color("#c070ff"), 1.6)
					flip = 5.5
					game.sfx("phase")
				if b.at > 1.2 and b.at < 5.0 and randf() < dt * 2.5:
					eshots.append({"x": b.x, "y": b.y, "vx": cos(ang) * 3.8, "vy": sin(ang) * 3.8, "t": 4.0, "d": 9.0})
				if b.at > 5.5:
					_end(b, rate)
			"apagar":
				if b.st2 == 0:
					b.st2 = 1
					erase = 6.0
					game.banner("AS PAREDES SE APAGAM", Color("#c070ff"), 1.6)
					game.sfx("mut")
				if b.at > 1.0 and int(b.at * 2.0) != int(b.get("tq", -1)):
					b.tq = int(b.at * 2.0)
					var q := randf() * TAU
					b.x = 8.5 + cos(q) * 4.5
					b.y = 8.5 + sin(q) * 4.5
					eshots.append({"x": b.x, "y": b.y, "vx": cos(ang) * 3.6, "vy": sin(ang) * 3.6, "t": 4.0, "d": 9.0})
					glitch = 0.15
				if b.at > 6.0:
					_end(b, rate)
			"fenda":
				if b.st2 == 0:
					b.st2 = 1
					b.lx0 = b.x
					b.ly0 = b.y
					b.la = ang
					b.lx1 = b.x + cos(ang) * 16.0
					b.ly1 = b.y + sin(ang) * 16.0
					_sfx3d(90.0, "sawtooth", 0.8, 0.09, b.x, b.y)
				if b.at > 1.1 and b.st2 == 1:
					b.st2 = 2
				if b.st2 == 2:
					b.x += cos(b.la) * 11.0 * dt
					b.y += sin(b.la) * 11.0 * dt
					if Vector2(b.x - x, b.y - y).length() < 0.8:
						_touch(24.0)
					if b.x < 1.5 or b.y < 1.5 or b.x > 15.5 or b.y > 15.5 or b.at > 2.6:
						b.x = clampf(b.x, 1.5, 15.5)
						b.y = clampf(b.y, 1.5, 15.5)
						_end(b, rate)
						game.shake(4.0)
	if d < 0.9 and b.st != "fenda":
		_touch(16.0)


func _end(b: Dictionary, rate: float) -> void:
	b.st = "idle"
	b.cd = (1.1 if b.ph else 1.6) / rate
	b.erase("lx0")


func _hum_update() -> void:
	if hum == null:
		return
	var vol := 0.05 if boss != null else 0.012
	var nv: float = Settings.sfx_volume() * (float(Settings.s.music) + 0.2 if Settings.s.sound else 0.0)
	hum.volume_db = linear_to_db(maxf(0.00001, vol * nv * 6.0))
	if boss != null:
		hum.position = Vector3(boss.x, 0.5, boss.y)
	else:
		hum.position = Vector3(x, 0.5, y)
	hum.pitch_scale = (55.0 + (40.0 if erase > 0.0 else 0.0) + (-15.0 if flip > 0.0 else 0.0)) / 55.0


# ======================================================================
# desenho
# ======================================================================
func _process(_dt: float) -> void:
	if not on or cam == null:
		return
	var sh := clampi(int(round(get_viewport().get_visible_rect().size.x / 360.0)), 2, 4)
	svc.stretch_shrink = sh
	svc.scale = Vector2(1, -1) if flip > 0.0 else Vector2.ONE
	svc.position = Vector2(0, get_viewport().get_visible_rect().size.y) if flip > 0.0 else Vector2.ZERO
	var hz := 0.5 + (0.0 if flip > 0.0 else sin(bob) * 0.01)
	cam.position = Vector3(x, hz, y)
	cam.rotation = Vector3(0, -a - PI / 2.0, 0)
	walls[1].visible = erase <= 0.0
	walls[2].visible = erase <= 0.0
	walls[3].visible = erase <= 0.0
	floor_mat.set_shader_parameter("erase", erase > 0.0)
	ceil_mat.set_shader_parameter("erase", erase > 0.0)
	ceil_mat.set_shader_parameter("time_s", t)
	var fenda: bool = boss != null and boss.st == "fenda" and boss.st2 == 1 and boss.has("lx0")
	floor_mat.set_shader_parameter("fenda_on", fenda)
	if fenda:
		floor_mat.set_shader_parameter("fenda_seg", Vector4(boss.lx0, boss.ly0, boss.lx1, boss.ly1))
	_update_sprites()
	hud.queue_redraw()


func _update_sprites() -> void:
	var n := 0
	var put := func(px: float, py: float, tx: Texture2D, size: float, z: float, white: bool) -> void:
		if n >= sprite_pool.size() or tx == null:
			return
		var s := sprite_pool[n]
		n += 1
		s.visible = true
		s.texture = tx
		s.pixel_size = size / tx.get_height()
		s.position = Vector3(px, 0.5 - z, py)
		var dd := Vector2(px - x, py - y).length()
		var k := 1.0 - minf(1.0, dd / FOG_K)
		s.modulate = Color.WHITE if white else Color(k, k, k, 1.0)
	for s in shots:
		put.call(s.x, s.y, spr.my, 0.35, 0.1, false)
	for s in eshots:
		put.call(s.x, s.y, spr.gold if s.get("pry", false) else spr.orb, 0.25 if s.get("fx", false) else 0.4, 0.05, false)
	for i in range(n, sprite_pool.size()):
		sprite_pool[i].visible = false


## Projeta um ponto do mundo 3D para a tela (considerando a ampliação e a Dobra).
func _to_screen(p: Vector3) -> Vector2:
	var vp := cam.unproject_position(p)
	var vs := Vector2(sv.size)
	var ss := get_viewport().get_visible_rect().size
	var q := vp / vs * ss
	if flip > 0.0:
		q.y = ss.y - q.y
	return q


func _draw_hud(c: CanvasItem) -> void:
	if not on:
		return
	var ss := get_viewport().get_visible_rect().size
	var VW := ss.x
	var VH := ss.y
	# o Tesseract: desenhado em vetor por cima, com oclusão pelas paredes
	var b = boss
	if b != null:
		_draw_cube_at(c, b, true)
		for k in b.cop:
			if k.hp > 0.0:
				_draw_cube_at(c, k, false)
	# arma, mira e efeitos de tela
	var gx := VW * 0.5 + sin(bob * 0.5) * 8.0
	var gy := VH - maxf(0.0, kick) * 14.0 + absf(cos(bob * 0.5)) * 6.0
	var u := float(maxi(3, int(minf(VW, VH) / 110.0)))
	c.draw_rect(Rect2(gx - 6 * u, gy - 14 * u, 12 * u, 14 * u), Color("#1a2030"))
	c.draw_rect(Rect2(gx - 2 * u, gy - 20 * u, 4 * u, 8 * u), Color("#00f2ff"))
	c.draw_rect(Rect2(gx - 8 * u, gy - 6 * u, 16 * u, 6 * u), Color("#2a3448"))
	if kick > 0.5:
		Draw.circle(c, Vector2(gx, gy - 22 * u), 5 * u, Color(0.75, 0.96, 1, 0.8))
	var col := Color("#ffd23d") if lock != null else Color(1, 1, 1, 0.8)
	var m := Vector2(VW / 2.0, VH / 2.0)
	for seg in [[Vector2(-10, 0), Vector2(-4, 0)], [Vector2(4, 0), Vector2(10, 0)], [Vector2(0, -10), Vector2(0, -4)], [Vector2(0, 4), Vector2(0, 10)]]:
		c.draw_line(m + seg[0], m + seg[1], col, 2.0)
	if glitch > 0.0 or intro > 0.0:
		var k := maxf(glitch * 2.0, intro / 1.4)
		for i in 8:
			c.draw_rect(Rect2(0, randf() * VH, VW, 2 + randf() * 10), Color(0.61, 0.36, 1, 0.25 * k) if i % 2 else Color(0, 0.95, 1, 0.25 * k))
		if intro > 0.0:
			var e := minf(1.0, intro / 1.4)
			c.draw_rect(Rect2(0, 0, VW, VH * e * 0.5), Color(0.02, 0.01, 0.04, e))
			c.draw_rect(Rect2(0, VH - VH * e * 0.5, VW, VH), Color(0.02, 0.01, 0.04, e))
	if b != null:
		var w := maxf(160.0, minf(420.0, VW - 200.0))
		var bx := (VW - w) / 2.0
		var by := VH - 34.0
		c.draw_rect(Rect2(bx - 4, by - 16, w + 8, 26), Color(0, 0, 0, 0.55))
		c.draw_rect(Rect2(bx, by, w, 8), Color(1, 1, 1, 0.12))
		c.draw_rect(Rect2(bx, by, w * maxf(0.0, b.hp / b.mhp), 8), Color("#9b5cff"))
		Draw.text(c, Assets.font_mono_bold, b.name, Vector2(VW / 2.0, by - 5.0), 11, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	if game.player.iv > 0.0 and int(game.game_time * 16.0) % 2:
		c.draw_rect(Rect2(0, 0, VW, VH), Color(1, 0, 0.33, 0.2))
	var bn: Dictionary = game.banner_d
	if bn.t > 0.0:
		Draw.text(c, Assets.font_ui_black, bn.txt, Vector2(VW / 2.0, VH * 0.28), 18 if VW < 500 else 26, Draw.alpha(bn.col, minf(1.0, bn.t * 2.0)), HORIZONTAL_ALIGNMENT_CENTER)
	game._draw_hud_msgs(c)
	game.cine.draw(c)


func _draw_cube_at(c: CanvasItem, o: Dictionary, real: bool) -> void:
	var p := Vector3(o.x, 0.5, o.y)
	if cam.is_position_behind(p):
		return
	if not los(x, y, o.x, o.y) and erase <= 0.0:
		return
	var X := _to_screen(p)
	var top := _to_screen(Vector3(o.x, 1.0, o.y))
	var bot := _to_screen(Vector3(o.x, 0.0, o.y))
	var unit := absf(bot.y - top.y)
	var R := unit * 0.42
	if real:
		Draw.ellipse(c, Vector2(X.x, bot.y if flip <= 0.0 else top.y), R * 0.9, R * 0.22, Color(0, 0, 0, 0.5))
	draw_cube(c, X, t * (1.0 if real else 1.3), 1.0 if real else 0.75, R / 46.0)
	if real and o.hitT > 0.0:
		Draw.circle(c, X, R, Color(1, 1, 1, 0.5))


## O cubo da Anomalia (drawCube do HTML): cubo externo e interno girando, faces e arestas em HSL, núcleo e
## losangos orbitando, anéis na base.
static func draw_cube(c: CanvasItem, pos: Vector2, t: float, al: float, sc: float) -> void:
	var Hc := func(off: float) -> Color: return Draw.hsl(t * 50.0 + off, 0.9, 0.68)
	c.draw_set_transform(pos, 0.0, Vector2(sc, sc))
	for i in 3:
		Draw.ellipse_ring(c, Vector2(0, 56), 38.0 + i * 14.0 + sin(t * 3.0 + i) * 4.0, 9.0 + i * 3.0, Color(0.61, 0.36, 1, 0.3 * al), 2.0)
	var V := func(R: float, ax: float, ay: float) -> PackedVector2Array:
		var out := PackedVector2Array()
		for i in 8:
			var xx := 1.0 if i & 1 else -1.0
			var yy := 1.0 if i & 2 else -1.0
			var zz := 1.0 if i & 4 else -1.0
			var x1 := xx * cos(ay) + zz * sin(ay)
			var z1 := -xx * sin(ay) + zz * cos(ay)
			var y1 := yy * cos(ax) - z1 * sin(ax)
			var z2 := yy * sin(ax) + z1 * cos(ax)
			var k := 1.0 / (1.0 - z2 * 0.25)
			out.append(Vector2(x1 * R * k, y1 * R * k))
		return out
	var O: PackedVector2Array = V.call(46.0, t * 0.7, t * 0.5)
	var I: PackedVector2Array = V.call(21.0, -t * 0.9, -t * 0.6)
	var F := [[0, 1, 3, 2], [4, 5, 7, 6], [0, 1, 5, 4], [2, 3, 7, 6], [0, 2, 6, 4], [1, 3, 7, 5]]
	var E := [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]
	for f in 6:
		var pts := PackedVector2Array()
		for i in F[f]:
			pts.append(O[i])
		if not Geometry2D.triangulate_polygon(pts).is_empty():
			c.draw_colored_polygon(pts, Draw.alpha(Hc.call(f * 60.0), 0.1 * al))
	for e in E:
		c.draw_line(O[e[0]], O[e[1]], Draw.alpha(Hc.call(e[0] * 40.0), al * 0.35), 7.0, true)
		c.draw_line(O[e[0]], O[e[1]], Draw.alpha(Hc.call(e[0] * 40.0), al), 3.0, true)
	for e in E:
		c.draw_line(I[e[0]], I[e[1]], Color(0.91, 0.86, 1, al), 1.5, true)
	for i in 8:
		c.draw_line(O[i], I[i], Draw.alpha(Hc.call(i * 45.0), 0.45 * al), 1.0, true)
	var p := 1.0 + sin(t * 5.0) * 0.15
	Draw.radial_fan(c, Vector2.ZERO, 15.0 * p, Color(1, 1, 1, al), Color(0.61, 0.36, 1, 0.0))
	for i in 6:
		var aa := t * (0.5 + i * 0.17) + i * 1.1
		var s := 4.0 + sin(aa * 1.3) * 2.5
		var r := 62.0 + i * 5.0
		var px := cos(aa) * r
		var py := sin(aa) * r * 0.6
		Draw.poly(c, PackedVector2Array([Vector2(px, py - s), Vector2(px + s * 0.7, py), Vector2(px, py + s), Vector2(px - s * 0.7, py)]), Draw.alpha(Hc.call(i * 60.0), al))
	c.draw_set_transform_matrix(Transform2D.IDENTITY)
