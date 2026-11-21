class_name Draw
## Primitivas de desenho que reproduzem o Canvas 2D do HTML sobre a API de CanvasItem do Godot.

const TAU_ := TAU


static func segs_for(r: float) -> int:
	return clampi(int(r * 0.6), 12, 72)


## Círculo cheio. Até 64 px de raio usa uma textura de disco (uma chamada, sem gerar polígono, em lote).
static func circle(ci: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	if r <= 0.0 or col.a <= 0.0:
		return
	if r <= 64.0 and Assets.disc != null:
		ci.draw_texture_rect(Assets.disc, Rect2(p.x - r, p.y - r, r * 2.0, r * 2.0), false, col)
	else:
		ci.draw_circle(p, r, col)


static var _units := {}


## Polígono regular de raio 1 (em cache): use com draw_set_transform para escalar e girar.
static func unit(n: int, a: float = 0.0) -> PackedVector2Array:
	var k := Vector2(n, a)
	if not _units.has(k):
		_units[k] = reg(n, 1.0, a)
	return _units[k]


static func ring(ci: CanvasItem, p: Vector2, r: float, col: Color, w: float = 1.0) -> void:
	if r <= 0.0 or col.a <= 0.0:
		return
	ci.draw_arc(p, r, 0.0, TAU, segs_for(r), col, w, true)


static func arc(ci: CanvasItem, p: Vector2, r: float, a0: float, a1: float, col: Color, w: float = 1.0) -> void:
	if r <= 0.0 or col.a <= 0.0 or is_equal_approx(a0, a1):
		return
	var n := maxi(4, int(segs_for(r) * absf(a1 - a0) / TAU) + 2)
	ci.draw_arc(p, r, a0, a1, n, col, w, true)


## Arco tracejado (setLineDash + lineDashOffset). offset em px ao longo do arco.
static func dashed_arc(ci: CanvasItem, p: Vector2, r: float, a0: float, a1: float, dash: float, gap: float, offset: float, col: Color, w: float = 1.0) -> void:
	if r <= 1.0 or col.a <= 0.0:
		return
	var total := (a1 - a0) * r
	var period := dash + gap
	var s := -fposmod(offset, period)
	while s < total:
		var d0 := maxf(s, 0.0)
		var d1 := minf(s + dash, total)
		if d1 > d0:
			arc(ci, p, r, a0 + d0 / r, a0 + d1 / r, col, w)
		s += period


static func dashed_ring(ci: CanvasItem, p: Vector2, r: float, dash: float, gap: float, offset: float, col: Color, w: float = 1.0) -> void:
	dashed_arc(ci, p, r, 0.0, TAU, dash, gap, offset, col, w)


static func dashed_line(ci: CanvasItem, a: Vector2, b: Vector2, dash: float, gap: float, offset: float, col: Color, w: float = 1.0) -> void:
	var L := a.distance_to(b)
	if L < 0.5:
		return
	var u := (b - a) / L
	var period := dash + gap
	var s := -fposmod(offset, period)
	while s < L:
		var d0 := maxf(s, 0.0)
		var d1 := minf(s + dash, L)
		if d1 > d0:
			ci.draw_line(a + u * d0, a + u * d1, col, w, true)
		s += period


static func dashed_rect(ci: CanvasItem, r: Rect2, dash: float, gap: float, offset: float, col: Color, w: float = 1.0) -> void:
	var p := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	var acc := offset
	for i in 4:
		var a: Vector2 = p[i]
		var b: Vector2 = p[(i + 1) % 4]
		dashed_line(ci, a, b, dash, gap, acc, col, w)
		acc -= a.distance_to(b)


## Polígono regular: n vértices, raio R, ângulo inicial a.
static func reg(n: int, R: float, a: float = 0.0, c: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.resize(n)
	for i in n:
		var q := a + i * TAU / n
		pts[i] = c + Vector2(cos(q) * R, sin(q) * R)
	return pts


static func ellipse_pts(c: Vector2, rx: float, ry: float, rot: float = 0.0, n: int = 32) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.resize(n)
	var cr := cos(rot)
	var sr := sin(rot)
	for i in n:
		var a := i * TAU / n
		var x := cos(a) * rx
		var y := sin(a) * ry
		pts[i] = c + Vector2(x * cr - y * sr, x * sr + y * cr)
	return pts


static func ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, rot: float = 0.0) -> void:
	if rx <= 0.0 or ry <= 0.0 or col.a <= 0.0:
		return
	ci.draw_colored_polygon(ellipse_pts(c, rx, ry, rot, clampi(int((rx + ry) * 0.5), 12, 48)), col)


static func ellipse_ring(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, w: float = 1.0, rot: float = 0.0) -> void:
	if rx <= 0.0 or ry <= 0.0 or col.a <= 0.0:
		return
	var pts := ellipse_pts(c, rx, ry, rot, clampi(int((rx + ry) * 0.5), 12, 48))
	pts.append(pts[0])
	ci.draw_polyline(pts, col, w, true)


static func poly(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	if pts.size() < 3 or col.a <= 0.0:
		return
	ci.draw_colored_polygon(pts, col)


static func poly_stroke(ci: CanvasItem, pts: PackedVector2Array, col: Color, w: float = 1.0) -> void:
	if pts.size() < 2 or col.a <= 0.0:
		return
	var p := pts.duplicate()
	p.append(pts[0])
	ci.draw_polyline(p, col, w, true)


## Amostra uma curva quadrática (quadraticCurveTo) e acrescenta os pontos em pts.
static func quad_to(pts: PackedVector2Array, p0: Vector2, c: Vector2, p1: Vector2, n: int = 8) -> void:
	for i in range(1, n + 1):
		var t := float(i) / n
		var a := p0.lerp(c, t)
		var b := c.lerp(p1, t)
		pts.append(a.lerp(b, t))


## Setor (moveTo centro + arc + closePath).
static func sector(ci: CanvasItem, c: Vector2, r: float, a0: float, a1: float, col: Color) -> void:
	if r <= 0.0 or col.a <= 0.0:
		return
	var n := maxi(3, int(segs_for(r) * absf(a1 - a0) / TAU) + 2)
	var pts := PackedVector2Array([c])
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / n)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	ci.draw_colored_polygon(pts, col)


## Gradiente radial (createRadialGradient do centro r0 → r1) desenhado como textura.
static func radial(ci: CanvasItem, c: Vector2, r: float, c0: Color, c1: Color) -> void:
	if r <= 0.0:
		return
	ci.draw_texture_rect(Assets.radial(c0, c1), Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false)


static func text(ci: CanvasItem, font: Font, s: String, pos: Vector2, size: int, col: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	if col.a <= 0.0 or s.is_empty():
		return
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var x := pos.x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		x -= w * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		x -= w
	ci.draw_string(font, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


static func text_width(font: Font, s: String, size: int) -> float:
	return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


static func alpha(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * clampf(a, 0.0, 1.0))


## Cor HSL (usada pelo Prisma e pelo cubo da Anomalia).
static func hsl(h: float, s: float, l: float, a: float = 1.0) -> Color:
	h = fposmod(h, 360.0) / 360.0
	var q := l * (1.0 + s) if l < 0.5 else l + s - l * s
	var p := 2.0 * l - q
	return Color(_h2c(p, q, h + 1.0 / 3.0), _h2c(p, q, h), _h2c(p, q, h - 1.0 / 3.0), a)


static func _h2c(p: float, q: float, t: float) -> float:
	t = fposmod(t, 1.0)
	if t < 1.0 / 6.0:
		return p + (q - p) * 6.0 * t
	if t < 0.5:
		return q
	if t < 2.0 / 3.0:
		return p + (q - p) * (2.0 / 3.0 - t) * 6.0
	return p


## Leque com cor no centro e outra na borda (gradiente radial exato por interpolação de vértices).
## Usa uma lista de triângulos direto no RenderingServer (um leque fechado não é um polígono simples).
static func radial_fan(ci: CanvasItem, c: Vector2, r: float, c_center: Color, c_rim: Color, a0: float = 0.0, a1: float = TAU) -> void:
	if r <= 0.0 or (c_center.a <= 0.0 and c_rim.a <= 0.0):
		return
	var n := maxi(8, int(segs_for(r) * absf(a1 - a0) / TAU) + 2)
	var pts := PackedVector2Array([c])
	var cols := PackedColorArray([c_center])
	var idx := PackedInt32Array()
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / n)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
		cols.append(c_rim)
		if i > 0:
			idx.append_array([0, i, i + 1])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, cols)


## Quadrilátero com uma cor por vértice (gradientes lineares).
static func quad(ci: CanvasItem, p: PackedVector2Array, cols: PackedColorArray) -> void:
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), PackedInt32Array([0, 1, 2, 0, 2, 3]), p, cols)
