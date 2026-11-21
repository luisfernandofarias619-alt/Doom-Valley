class_name EnemyLogic
## Comportamento e desenho dos inimigos comuns (Enemy.update/shoot/fire e a silhueta por classe do Overdrive).


static func update(g, e: Enemy, dt: float) -> void:
	var P: PlayerState = g.player
	if e.hit_timer > 0.0:
		e.hit_timer -= dt
	var dx := P.x - e.x
	var dy := P.y - e.y
	var dist := sqrt(dx * dx + dy * dy)
	if dist == 0.0:
		dist = 1.0
	var mx := dx / dist
	var my := dy / dist
	var sp := e.speed
	e.ang = atan2(my, mx)
	if e.charge > 0.0:
		e.charge -= dt
		if e.charge <= 0.0:
			fire(g, e)
	match e.type:
		"shooter":
			if dist < 300.0:
				mx *= -0.5
				my *= -0.5
				if g.game_time - e.last_shot > 2.0:
					shoot(e, dx, dy, dist)
		"fast":
			var w := sin(g.game_time * 5.0 + e.anim_phase) * 0.9
			var c := cos(w)
			var s := sin(w)
			var n := mx * c - my * s
			my = mx * s + my * c
			mx = n
		"tank":
			if e.rush > 0.0:
				e.rush -= dt
				mx = e.rx
				my = e.ry
				sp *= 3.2
			elif e.tw > 0.0:
				e.tw -= dt
				sp = 0.0
				e.rx = mx
				e.ry = my
				if e.tw <= 0.0:
					e.rush = 0.45
			elif dist < 300.0 and g.game_time - e.last_shot > 4.0:
				e.tw = 0.6
				e.last_shot = g.game_time
		"rifter":
			if e.bl > 0.0:
				e.bl -= dt
				sp = 0.0
				if e.bl <= 0.0:
					var a := e.ang + (1.0 if randf() < 0.5 else -1.0) * 1.3
					var B: Rect2 = g.world_rect()
					e.x = clampf(e.x + cos(a) * 100.0, B.position.x + 10.0, B.end.x - 10.0)
					e.y = clampf(e.y + sin(a) * 100.0, B.position.y + 10.0, B.end.y - 10.0)
					e.last_shot = g.game_time
					g.fx.burst(e.x, e.y, e.color, 8, 180.0)
					g.fx.ripple(e.x, e.y, 6.0, 24.0, e.color, 0.7)
					Sfx.play("blink")
			elif dist < 340.0 and dist > 120.0 and g.game_time - e.last_shot > 2.4:
				e.bl = 0.4
		"gunner":
			if dist < 250.0:
				mx *= -0.6
				my *= -0.6
			elif dist < 340.0:
				sp *= 0.15
			if dist < 400.0 and g.game_time - e.last_shot > 2.6:
				shoot(e, dx, dy, dist)
		"leech":
			if dist < 180.0:
				sp *= 1.5
	var cs := -sp if e.hit_timer > 0.0 else sp
	e.x += mx * cs * dt
	e.y += my * cs * dt
	if dist < e.radius + P.radius:
		g.contact(54.0 if e.rush > 0.0 else 18.0, e)
		if e.type == "leech":
			g.slow_t = 2.0


static func shoot(e: Enemy, dx: float, dy: float, dist: float) -> void:
	if e.charge > 0.0:
		return
	e.charge = 0.45
	e.ax = dx / dist
	e.ay = dy / dist


static func fire(g, e: Enemy) -> void:
	e.last_shot = g.game_time
	if e.type == "gunner":
		for o in [-0.28, 0.0, 0.28]:
			var a: float = atan2(e.ay, e.ax) + o
			g.enemy_projectiles.append(Projectile.new(e.x, e.y, cos(a) * 270.0, sin(a) * 270.0, Color("#ff8a2b"), true))
	else:
		g.enemy_projectiles.append(Projectile.new(e.x, e.y, e.ax * 300.0, e.ay * 300.0, Color("#ff00ff"), true))


## Halo de brilho (shadowBlur) — desenhado numa camada aditiva atrás das silhuetas.
static func draw_glow(g, ci: CanvasItem, e: Enemy) -> void:
	var gm := Settings.glow_mul()
	if gm <= 0.0:
		return
	var blur := 5.0 if g.enemies.size() > 40 else 15.0
	Draw.radial(ci, Vector2(e.x, e.y), e.radius + blur * gm * 1.6, Draw.alpha(e.color, 0.55 * gm), Color(e.color, 0.0))


static func draw(g, c: CanvasItem, e: Enemy) -> void:
	var r := e.radius
	var t: float = g.game_time + e.anim_phase
	var hit := e.hit_timer > 0.0
	var bc := e.color
	var col := Color.WHITE if hit else bc
	var sc := 1.0 + sin(t * 10.0) * 0.05 + (0.12 if hit else 0.0)
	var o := Vector2(e.x, e.y)
	var T := e.type
	match T:
		"fast":
			c.draw_set_transform(o, e.ang, Vector2(sc, sc))
			Draw.poly(c, PackedVector2Array([Vector2(r * 1.5, 0), Vector2(-r, r * 0.8), Vector2(-r * 0.4, 0), Vector2(-r, -r * 0.8)]), col)
			c.draw_rect(Rect2(-r * 3.0, -1.5, r * 2.0, 3.0), Draw.alpha(col, 0.35))
		"tank":
			c.draw_set_transform(o, 0.0, Vector2(sc, sc) * r)
			var oc := Draw.unit(8, 0.3927)
			Draw.poly(c, oc, Draw.alpha(col, 0.25))
			Draw.poly_stroke(c, oc, col, 4.0 / r)
			c.draw_set_transform(o, 0.0, Vector2(sc, sc))
			c.draw_set_transform(o, t * 0.8, Vector2(sc, sc))
			for i in 4:
				Draw.arc(c, Vector2.ZERO, r * 0.62, i * 1.5708 + 0.3, i * 1.5708 + 1.2, col, 3.0)
			if e.tw > 0.0 or e.rush > 0.0:
				Draw.circle(c, Vector2.ZERO, r * 0.4, Color(1, 0, 0.33, 0.6 + 0.4 * sin(t * 40.0)))
		"shooter":
			c.draw_set_transform(o, 0.7854, Vector2(sc, sc))
			c.draw_rect(Rect2(-r * 0.75, -r * 0.75, r * 1.5, r * 1.5), col)
			c.draw_set_transform(o, 0.0, Vector2(sc, sc))
			Draw.circle(c, Vector2.ZERO, r * 0.38, Color("#050508"))
			Draw.circle(c, Vector2(cos(e.ang), sin(e.ang)) * r * 0.12, r * 0.2, Color.WHITE if e.charge > 0.0 else bc)
		"splitter":
			c.draw_set_transform(o, 0.0, Vector2(sc, sc))
			Draw.circle(c, Vector2(-r * 0.35, 0), r * 0.7, col)
			Draw.circle(c, Vector2(r * 0.35, 0), r * 0.7, col)
			c.draw_line(Vector2(0, -r * 0.7), Vector2(0, r * 0.7), Color("#050508"), 2.0, true)
		"fragment":
			c.draw_set_transform(o, t * 6.0, Vector2.ONE)
			Draw.poly(c, PackedVector2Array([Vector2(r, 0), Vector2(-r * 0.6, r * 0.7), Vector2(-r * 0.6, -r * 0.7)]), col)
		"guard":
			c.draw_set_transform(o, e.ang, Vector2(sc, sc) * r * 0.7)
			Draw.poly(c, Draw.unit(8), col)
			c.draw_set_transform(o, e.ang, Vector2(sc, sc))
			Draw.arc(c, Vector2.ZERO, r, -1.1, 1.1, col, 6.0)
			Draw.circle(c, Vector2(-r * 0.1, 0), r * 0.22, Color("#050508"))
		"gunner":
			c.draw_set_transform(o, e.ang, Vector2(sc, sc))
			Draw.poly(c, PackedVector2Array([Vector2(-r, -r * 0.8), Vector2(r * 0.5, 0), Vector2(-r, r * 0.8)]), col)
			c.draw_rect(Rect2(r * 0.2, -3, r * 1.1, 6), col)
		"rifter":
			var al := 0.35 + 0.65 * absf(sin(t * 40.0)) if e.bl > 0.0 else 1.0
			c.draw_set_transform(o, t * 0.8, Vector2(sc, sc) * r)
			Draw.poly(c, Draw.unit(4), Draw.alpha(col, al))
			c.draw_set_transform(o, t * 0.8, Vector2(sc, sc))
			c.draw_line(Vector2(-r, 0), Vector2(r, 0), Color(0.02, 0.02, 0.03, al), 1.5, true)
			c.draw_line(Vector2(0, -r), Vector2(0, r), Color(0.02, 0.02, 0.03, al), 1.5, true)
		"leech":
			c.draw_set_transform(o, e.ang, Vector2(sc, sc))
			Draw.circle(c, Vector2.ZERO, r * 0.7, col)
			var tail := PackedVector2Array([Vector2(-r * 0.6, 0)])
			for i in range(1, 5):
				tail.append(Vector2(-r * 0.6 - i * r * 0.4, sin(t * 12.0 + i) * r * 0.35))
			c.draw_polyline(tail, col, 3.0, true)
			for i in 3:
				var a := 0.9 + i * 0.45
				c.draw_line(Vector2(cos(a), sin(a)) * r * 0.6, Vector2(cos(a), sin(a)) * r, col, 3.0, true)
				c.draw_line(Vector2(cos(-a), sin(-a)) * r * 0.6, Vector2(cos(-a), sin(-a)) * r, col, 3.0, true)
		_:
			c.draw_set_transform(o, t * 0.6, Vector2(sc, sc) * r)
			Draw.poly(c, Draw.unit(6), col)
			c.draw_set_transform(o, t * 0.6, Vector2(sc, sc) * r * 0.45)
			Draw.poly(c, Draw.unit(6), Color("#050508"))
			c.draw_set_transform(o, t * 0.6, Vector2(sc, sc) * r * 0.25)
			Draw.poly(c, Draw.unit(3), col)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)
	if e.elite:
		# BUG CORRIGIDO: o HTML desenhava o anel em (x,y) depois de transladar para (x,y) (deslocamento dobrado)
		Draw.dashed_ring(c, o, r + 9.0, 6.0, 5.0, -t * 30.0, Color(1, 0.85, 0.4, 0.5 + 0.3 * sin(t * 6.0)), 2.0)
	if e.charge > 0.0:
		var k := maxf(0.0, e.charge / 0.45)
		Draw.ring(c, o, r + 6.0 + k * 26.0, Color(1, 1, 1, 0.85), 2.0)
