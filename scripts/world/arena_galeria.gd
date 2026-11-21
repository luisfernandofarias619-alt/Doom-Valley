class_name ArenaGaleria
extends RefCounted
## Galeria dos Reflexos (arena do Espelho): piso escuro em ladrilhos, eixo e círculo magenta, cerca de energia
## e quatro painéis espelhados que devolvem os tiros do Nick (uma vez por tiro).

var g
var ar


func _init(game, arena) -> void:
	g = game
	ar = arena


func build(A: Dictionary) -> void:
	A.t = 24.0
	var px := 2
	var aw := ceili(A.w / px)
	var ah := ceili(A.h / px)
	var t := int(A.t / 2)
	var img := PixelArt.make(aw, ah)
	for y in range(0, ah, 16):
		for x in range(0, aw, 16):
			var h := Fenda.fh(x / 16, y / 16, 9)
			img.fill_rect(Rect2i(x, y, 16, 16), Color("#100c18") if h < 0.5 else Color("#140f1e"))
			img.fill_rect(Rect2i(x, y, 16, 1), Color("#1d1530"))
			if (x / 16 + y / 16) % 5 == 0:
				PixelArt.fill(img, x + 2, y + 2, 1, 12, Color(1, 0.84, 1, 0.063))
	var dark := Color("#07050b")
	img.fill_rect(Rect2i(0, 0, aw, t), dark)
	img.fill_rect(Rect2i(0, ah - t, aw, t), dark)
	img.fill_rect(Rect2i(0, 0, t, ah), dark)
	img.fill_rect(Rect2i(aw - t, 0, t, ah), dark)
	A.tex = ImageTexture.create_from_image(img)
	A.px = px
	A.aw = aw
	A.ah = ah
	A.painted = true


func obstacles(A: Dictionary) -> Array:
	var W: float = A.w
	var H: float = A.h
	return [
		{"k": "painel", "x": W * 0.25, "y": H * 0.3, "hw": 40.0, "hh": 8.0, "solid": true},
		{"k": "painel", "x": W * 0.75, "y": H * 0.3, "hw": 40.0, "hh": 8.0, "solid": true},
		{"k": "painel", "x": W * 0.25, "y": H * 0.72, "hw": 8.0, "hh": 40.0, "solid": true},
		{"k": "painel", "x": W * 0.75, "y": H * 0.72, "hw": 8.0, "hh": 40.0, "solid": true},
	]


## Painéis espelhados devolvem os tiros do Nick (galPre).
func pre(_dt: float) -> void:
	var A = ar.cur
	if A == null:
		return
	for p in g.projectiles:
		for o in A.obj:
			if o.k != "painel":
				continue
			if absf(p.x - o.x) < o.hw + p.radius and absf(p.y - o.y) < o.hh + p.radius and not p.mr:
				p.mr = true
				if o.hw > o.hh:
					p.vy = -p.vy
				else:
					p.vx = -p.vx
				p.x += p.vx * 0.02
				p.y += p.vy * 0.02
				g.fx.burst(p.x, p.y, Color("#ffd6ff"), 3, 100.0)


func post(_dt: float, _A: Dictionary) -> void:
	pass


func draw_floor_tex(c: CanvasItem, A: Dictionary) -> void:
	var px: int = A.px
	c.draw_texture_rect(A.tex, Rect2(0, 0, A.aw * px, A.ah * px), false)
	var col := Color(1, 0.24, 0.95, 0.2)
	c.draw_line(Vector2(A.w / 2.0, A.t), Vector2(A.w / 2.0, A.h - A.t), col, 2.0)
	Draw.ring(c, Vector2(A.w / 2.0, A.h / 2.0), minf(A.w, A.h) * 0.3, col, 2.0)


func draw_floor(_c: CanvasItem, _A: Dictionary) -> void:
	pass


func draw_objects(c: CanvasItem, A: Dictionary) -> void:
	for o in A.obj:
		if o.k != "painel":
			continue
		c.draw_rect(Rect2(o.x - o.hw - 3, o.y - o.hh - 3, o.hw * 2 + 6, o.hh * 2 + 6), Color("#3a2a4a"))
		var a := Color(1, 0.84, 1, 0.75)
		var b := Color(0.5, 0.82, 1, 0.75)
		Draw.quad(c, PackedVector2Array([Vector2(o.x - o.hw, o.y - o.hh), Vector2(o.x + o.hw, o.y - o.hh), Vector2(o.x + o.hw, o.y + o.hh), Vector2(o.x - o.hw, o.y + o.hh)]),
			PackedColorArray([a, a.lerp(b, 0.5), b, a.lerp(b, 0.5)]))
		var k := fmod(A.tm * 0.6, 1.0)
		c.draw_rect(Rect2(o.x - o.hw + k * o.hw * 2.0, o.y - o.hh, 3, o.hh * 2), Color(1, 1, 1, 0.9))
