class_name PixelArt
## Desenho em pixel art sobre Image (substitui os canvas fora da tela do HTML: arMk, arSp, arStamp, crkPaint...).
## As cores e o gerador pseudoaleatório (arRng, LCG de Numerical Recipes) são os mesmos do original, então
## a mesma semente gera o mesmo cenário.

const ARP := ["#0d0f13", "#13161c", "#1a1e26", "#222832", "#2c3440", "#394351", "#4a5565", "#606c7d"]
const ARY := ["#3c2e0a", "#7a5e14", "#b08a1e"]

static var _pieces := {}


## LCG idêntico a arRng(s): s = (s*1664525 + 1013904223) >>> 0; retorna s/2^32.
class Lcg:
	var s: int

	func _init(seed_: int) -> void:
		s = seed_ & 0xffffffff

	func next() -> float:
		s = (s * 1664525 + 1013904223) & 0xffffffff
		return float(s) / 4294967296.0

	func i(n: int) -> int:
		return int(next() * n)


static func make(w: int, h: int) -> Image:
	return Image.create(maxi(1, w), maxi(1, h), false, Image.FORMAT_RGBA8)


static func col(c) -> Color:
	return c if c is Color else Color(c)


## fillRect com mistura (respeita a transparência da cor, como o canvas).
static func fill(img: Image, x: int, y: int, w: int, h: int, c) -> void:
	var cc := col(c)
	var r := Rect2i(x, y, w, h).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	if r.size.x <= 0 or r.size.y <= 0:
		return
	if cc.a >= 0.999:
		img.fill_rect(r, cc)
		return
	var tmp := Image.create(r.size.x, r.size.y, false, Image.FORMAT_RGBA8)
	tmp.fill(cc)
	img.blend_rect(tmp, Rect2i(Vector2i.ZERO, r.size), r.position)


static func px(img: Image, x: int, y: int, c) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	var cc := col(c)
	if cc.a >= 0.999:
		img.set_pixel(x, y, cc)
	else:
		img.set_pixel(x, y, img.get_pixel(x, y).blend(cc))


static func fill_circle(img: Image, cx: float, cy: float, r: float, c) -> void:
	fill_ellipse(img, cx, cy, r, r, c)


static func fill_ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, c) -> void:
	var cc := col(c)
	for y in range(int(floor(cy - ry)), int(ceil(cy + ry)) + 1):
		for x in range(int(floor(cx - rx)), int(ceil(cx + rx)) + 1):
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				px(img, x, y, cc)


## Recorte do atlas da Contenção (com cache), opcionalmente girado (quartos de volta) e com transparência.
static func piece(n: String, rot: int = 0, al: float = 1.0) -> Image:
	var key := "%s|%d|%.2f" % [n, rot, al]
	if _pieces.has(key):
		return _pieces[key]
	var base := Assets.arena_piece(n)
	if base == null:
		return null
	var im := base.duplicate() as Image
	for _k in posmod(rot, 4):
		im.rotate_90(CLOCKWISE)
	if al < 0.999:
		for y in im.get_height():
			for x in im.get_width():
				var p := im.get_pixel(x, y)
				p.a *= al
				im.set_pixel(x, y, p)
	_pieces[key] = im
	return im


## arSp: carimba a peça n com o canto em (x, y). Girada em torno do próprio centro.
static func sp(img: Image, n: String, x: int, y: int, rot: int = 0, al: float = 1.0) -> void:
	var p := piece(n, rot, al)
	if p == null:
		return
	var r: Array = Assets.arena_rects.get(n, [0, 0, p.get_width(), p.get_height()])
	var w: int = r[2]
	var h: int = r[3]
	var ox := x + (w >> 1) - (p.get_width() >> 1)
	var oy := y + (h >> 1) - (p.get_height() >> 1)
	if rot == 0:
		ox = x
		oy = y
	img.blend_rect(p, Rect2i(0, 0, p.get_width(), p.get_height()), Vector2i(ox, oy))


## arStamp: carimba centrado em (cx, cy).
static func stamp(img: Image, n: String, cx: float, cy: float, rot: int = 0, al: float = 1.0) -> void:
	var r: Array = Assets.arena_rects.get(n, [])
	if r.is_empty():
		return
	sp(img, n, roundi(cx - r[2] / 2.0), roundi(cy - r[3] / 2.0), rot, al)


## Fratura em pixel art (crkPaint): trechos retos com quebras de ângulo, ramos e lascas.
## rn: Lcg ou RandomNumberGenerator. Retorna os pixels da fenda.
static func crack_paint(img: Image, x0: float, y0: float, n: int, length: float, rn, pw: int) -> Array[Vector2i]:
	var P := {}
	var R := func() -> float: return rn.next() if rn is Lcg else rn.randf()
	var put := func(x: float, y: float) -> void:
		var k := Vector2i(roundi(x), roundi(y))
		P[k] = true
	if pw > 1:
		var r: float = 1.6 + R.call() * 1.2
		for y in range(-4, 5):
			for x in range(-4, 5):
				if Vector2(x, y).length() < r + R.call() * 0.7:
					put.call(x0 + x, y0 + y)
	else:
		put.call(x0, y0)
	var walk := func(self_ref: Callable, sx: float, sy: float, a: float, L: int, d: int) -> void:
		var k := 3 + int(R.call() * 5.0)
		var x := sx
		var y := sy
		for i in L:
			k -= 1
			if k <= 0:
				a += (R.call() - 0.5) * 1.1
				k = 3 + int(R.call() * 6.0)
			else:
				a += (R.call() - 0.5) * 0.18
			x += cos(a)
			y += sin(a)
			put.call(x, y)
			if pw > 1 and i < L * 0.22:
				put.call(x + sin(a) * 0.9, y - cos(a) * 0.9)
			if d < 1 and i > 3 and R.call() < 0.045:
				self_ref.call(self_ref, x, y, a + (1.0 if R.call() < 0.5 else -1.0) * (0.6 + R.call() * 0.5), int((L - i) * (0.35 + R.call() * 0.3)), d + 1)
	for i in n:
		walk.call(walk, x0, y0, float(i) / n * TAU + (R.call() - 0.5) * 1.1, int(length * (0.5 + R.call() * 0.5)), 0)
	for p in P.keys():
		if not P.has(p + Vector2i(1, 1)):
			px(img, p.x + 1, p.y + 1, ARP[6])
	for p in P.keys():
		px(img, p.x, p.y, "#050407")
	if pw > 1:
		for i in 10:
			var a: float = R.call() * TAU
			var dd: float = 4.0 + R.call() * 8.0
			fill(img, roundi(x0 + cos(a) * dd), roundi(y0 + sin(a) * dd), 1 + (1 if R.call() < 0.3 else 0), 1, ARP[5])
	var out: Array[Vector2i] = []
	for p in P.keys():
		out.append(p)
	return out
