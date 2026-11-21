class_name FxLayer
extends RefCounted
## NEXUS FX: partículas e efeitos registrados (Layer(), reg('arc'|'ripple'|'burst'|'blackhole') do HTML).
## Partículas ficam em arrays compactos (sem um Node por partícula) e são desenhadas num único CanvasItem.

const STRIDE := 7   # x, y, vx, vy, t, vida, tamanho

var P := PackedFloat32Array()
var PC := PackedColorArray()
var n := 0
var E: Array[Dictionary] = []


func clear() -> void:
	n = 0
	E.clear()


func cap() -> int:
	return int(Settings.quality().cap)


func p(x: float, y: float, vx: float, vy: float, l: float, s: float, c: Color) -> void:
	if not Settings.s.particles:
		return
	var cp := cap()
	if n >= cp:
		_remove(0)
	if P.size() < (n + 1) * STRIDE:
		P.resize((n + 64) * STRIDE)
		PC.resize(n + 64)
	var i := n * STRIDE
	P[i] = x; P[i + 1] = y; P[i + 2] = vx; P[i + 3] = vy; P[i + 4] = 0.0; P[i + 5] = l; P[i + 6] = s
	PC[n] = c
	n += 1


func _remove(k: int) -> void:
	n -= 1
	if k != n:
		var a := k * STRIDE
		var b := n * STRIDE
		for j in STRIDE:
			P[a + j] = P[b + j]
		PC[k] = PC[n]


## Explosão de partículas (burst): quantidade escalada pela qualidade e pela intensidade.
func burst(x: float, y: float, c: Color, count: float, speed: float = 220.0, size: float = -1.0) -> void:
	var k := int(round(count * float(Settings.quality().k) * float(Settings.s.intensity)))
	for i in k:
		var a := randf() * TAU
		var s := 40.0 + randf() * speed
		p(x, y, cos(a) * s, sin(a) * s, 0.3 + randf() * 0.5, size if size > 0.0 else 2.0 + randf() * 2.0, c)


## Efeito registrado. tipos: 'arc', 'ripple', 'blackhole'. ('burst' é instantâneo: use burst()).
func fx(type: String, o: Dictionary) -> void:
	var d := {"arc": 0.14, "ripple": 0.45, "blackhole": 2.4}
	var e := o.duplicate()
	e.type = type
	e.t = 0.0
	e.d = float(o.get("duration", d.get(type, 0.5)))
	E.append(e)
	if E.size() > 60:
		E.pop_front()


func ripple(x: float, y: float, r: float, grow: float, col: Color, power: float = 0.6, duration: float = 0.45) -> void:
	fx("ripple", {"x": x, "y": y, "r": r, "grow": grow, "color": col, "power": power, "duration": duration})


func update(dt: float) -> void:
	var cp := cap()
	while n > cp:
		_remove(0)
	var i := n - 1
	while i >= 0:
		var b := i * STRIDE
		P[b + 4] += dt
		if P[b + 4] >= P[b + 5]:
			_remove(i)
		else:
			P[b] += P[b + 2] * dt
			P[b + 1] += P[b + 3] * dt
		i -= 1
	for j in range(E.size() - 1, -1, -1):
		var e: Dictionary = E[j]
		e.t += dt
		if e.t >= e.d:
			E.remove_at(j)


## Desenha partículas e efeitos. Em qualidade > 0 o nó usa mistura aditiva ('lighter').
func render(ci: CanvasItem) -> void:
	for i in n:
		var b := i * STRIDE
		var c := PC[i]
		c.a *= 1.0 - P[b + 4] / P[b + 5]
		var s := P[b + 6]
		ci.draw_rect(Rect2(P[b] - s * 0.5, P[b + 1] - s * 0.5, s, s), c)
	for e in E:
		match e.type:
			"ripple":
				var k: float = e.t / e.d
				var col: Color = e.get("color", Color("#00f2ff"))
				col.a = (1.0 - k) * float(e.get("power", 0.6))
				Draw.ring(ci, Vector2(e.x, e.y), float(e.get("r", 24.0)) + k * float(e.get("grow", 26.0)), col, 1.0 + 3.0 * (1.0 - k))
			"arc":
				jag(ci, Vector2(e.x1, e.y1), Vector2(e.x2, e.y2), e.get("color", Color("#7000ff")), 1.0 - e.t / e.d, float(e.get("w", 2.0)))
			"blackhole":
				draw_black_hole(ci, Vector2(e.x, e.y), float(e.get("r", 90.0)), e.t, e.d)


## Raio elétrico em zigue-zague (jag do HTML).
static func jag(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, al: float, w: float) -> void:
	var nn := int(float(Settings.quality().k) * 8.0 + 2.0)
	var d := b - a
	var l := maxf(d.length(), 1.0)
	var u := Vector2(-d.y, d.x) / l
	var am := minf(16.0, l * 0.12)
	var pts := PackedVector2Array([a])
	for i in range(1, nn):
		var t := float(i) / nn
		pts.append(a + d * t + u * (randf() - 0.5) * 2.0 * am)
	pts.append(b)
	var c := col
	c.a *= al
	var gm := Settings.glow_mul()
	if gm > 0.0:
		ci.draw_polyline(pts, Draw.alpha(col, al * 0.25 * gm), w * 4.0, true)
	ci.draw_polyline(pts, c, w, true)
	if Settings.s.q > 0:
		ci.draw_polyline(pts, Color(1, 1, 1, al), w * 0.4, true)


## Buraco negro (drawBH do HTML): núcleo, disco de acreção inclinado, braços espirais e anel tracejado.
static func draw_black_hole(ci: CanvasItem, c: Vector2, R: float, t: float, d: float) -> void:
	var a := minf(1.0, minf(t * 4.0, (d - t) * 3.0))
	var m := 0.0 if Settings.s.reduce else 1.0
	if a <= 0.0:
		return
	Draw.radial(ci, c, R * 0.5, Color(0, 0, 0, 0.95 * a), Color(0.44, 0, 1, 0))
	Draw.circle(ci, c, R * 0.28, Color(0.1, 0, 0.24, 0.6 * a))
	var rot := -0.35 + m * t * 0.25
	for i in 3:
		var col := Color("#ffd6a0") if i == 0 else Color("#8a3dff")
		col.a = a * (0.85 - i * 0.22)
		var pts := Draw.ellipse_pts(c, R * (0.26 + i * 0.1), R * (0.26 + i * 0.1) * 0.32, rot, 40)
		pts.append(pts[0])
		ci.draw_polyline(pts, col, 5.0 - i, true)
	for k in 3:
		var sp := PackedVector2Array()
		for s in 15:
			var f := s / 14.0
			var ang := k * 2.094 + m * t * 0.9 + f * 4.2
			var rr := R * (1.0 - f * 0.8)
			sp.append(c + Vector2(cos(ang), sin(ang)) * rr)
		ci.draw_polyline(sp, Color(0.75, 0.48, 1.0, a * 0.35), 1.5, true)
	Draw.circle(ci, c, R * 0.13, Color(0, 0, 0, a))
	Draw.ring(ci, c, R * 0.14, Color(1, 1, 1, a * 0.5), 1.5)
	Draw.dashed_ring(ci, c, R, 6.0, 10.0, b_offset(t, m), Color(0.75, 0.48, 1.0, a * 0.18), 1.0)


static func b_offset(t: float, m: float) -> float:
	return t * 30.0 * m


## Partículas simples do jogo base (Particle): quadrados que desbotam, vida 0,5 s.
class GameParticles:
	var P := PackedFloat32Array()   # x, y, vx, vy, vida, tamanho
	var C := PackedColorArray()
	var n := 0

	func add(x: float, y: float, c: Color, count: int, size: float) -> void:
		for i in count:
			if P.size() < (n + 1) * 6:
				P.resize((n + 64) * 6)
				C.resize(n + 64)
			var b := n * 6
			P[b] = x; P[b + 1] = y; P[b + 2] = (randf() - 0.5) * 400.0; P[b + 3] = (randf() - 0.5) * 400.0; P[b + 4] = 1.0; P[b + 5] = size
			C[n] = c
			n += 1

	func clear() -> void:
		n = 0

	func update(dt: float, cap: int) -> void:
		var i := n - 1
		while i >= 0:
			var b := i * 6
			P[b] += P[b + 2] * dt
			P[b + 1] += P[b + 3] * dt
			P[b + 4] -= dt * 2.0
			if P[b + 4] <= 0.0:
				_rm(i)
			i -= 1
		while n > cap:
			_rm(0)

	func _rm(k: int) -> void:
		n -= 1
		if k != n:
			for j in 6:
				P[k * 6 + j] = P[n * 6 + j]
			C[k] = C[n]

	func render(ci: CanvasItem) -> void:
		for i in n:
			var b := i * 6
			var c := C[i]
			c.a *= clampf(P[b + 4], 0.0, 1.0)
			ci.draw_rect(Rect2(P[b], P[b + 1], P[b + 5], P[b + 5]), c)
