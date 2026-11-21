class_name ArenaContencao
extends RefCounted
## Instalação de Contenção (arena do Rhino): piso e paredes montados em pixel art a partir do atlas da v4.3,
## porta de contenção, lâmpadas de emergência, grades de vapor, pilares, caixas, barris explosivos e entulho.
## Mesmo gerador (semente 7) e mesma ordem de sorteios do HTML (arBuildC/arWalls/arBand/arFloor/obContencao).

const ARP := PixelArt.ARP
const ARY := PixelArt.ARY

var g
var ar
var obs := {}
var vignette_mat: ShaderMaterial


func _init(game, arena) -> void:
	g = game
	ar = arena


func build(A: Dictionary) -> void:
	if Assets.arena_img == null:
		return
	var px := 2
	var aw := ceili(A.w / px)
	var ah := ceili(A.h / px)
	var t := 22
	var rn := PixelArt.Lcg.new(7)
	A.px = px
	A.aw = aw
	A.ah = ah
	A.ta = t
	A.door = {"u": (aw >> 1) - 20, "w": 40}
	var W := _walls(aw, ah, t, rn, A.door)
	var F := _floor(aw, ah, t, rn, W.lamps)
	F.img.blend_rect(W.img, Rect2i(0, 0, aw, ah), Vector2i.ZERO)
	A.img = F.img
	A.tex = ImageTexture.create_from_image(F.img)
	A.lamps = W.lamps
	A.vents = []
	for v in F.vents:
		A.vents.append(Vector2(v.x * px, v.y * px))
	A.painted = true


func obstacles(A: Dictionary) -> Array:
	if not A.has("tex"):
		return []
	var Wd: float = A.w
	var Hd: float = A.h
	var o: Array = []
	for q in [[0.27, 0.3], [0.73, 0.3], [0.27, 0.7], [0.73, 0.7]]:
		o.append({"k": "pilar", "x": Wd * q[0], "y": Hd * q[1], "hw": 34.0, "hh": 34.0, "solid": true, "dm": 0, "hits": 0})
	for q in [[0.11, 0.12], [0.142, 0.12], [0.89, 0.14], [0.89, 0.165], [0.075, 0.5], [0.925, 0.56], [0.13, 0.9], [0.87, 0.885], [0.84, 0.885]]:
		o.append({"k": "caixa", "x": roundf(Wd * q[0]), "y": roundf(Hd * q[1]), "hw": 22.0, "hh": 22.0, "solid": true, "brk": true, "hp": 90.0, "mhp": 90.0})
	for q in [[0.355, 0.255], [0.645, 0.745], [0.075, 0.36]]:
		o.append({"k": "barril", "x": Wd * q[0], "y": Hd * q[1], "r": 18.0, "solid": true, "brk": true, "hp": 30.0, "mhp": 30.0})
	for v in A.vents:
		o.append({"k": "vapor", "x": v.x, "y": v.y, "r": 58.0, "t": 2.0 + randf() * 4.0, "st": 0})
	return o


# ---------------- construção ----------------
## Faixa horizontal de parede: v=0 borda externa … v=17 início do lábio … v=22 piso.
func _band(length: int, t: int, rn: PixelArt.Lcg, door) -> Dictionary:
	var img := PixelArt.make(length, t)
	var lamps: Array[int] = []
	var last := -1
	var u := -rn.i(24)
	while u < length:
		var k := rn.i(6)
		while k == last:
			k = rn.i(6)
		last = k
		PixelArt.sp(img, "wp%d" % k, u, -1)
		u += 24
	PixelArt.fill(img, 0, 0, length, 2, ARP[1])
	u = 3
	while u < length:
		PixelArt.fill(img, u, 0, 1, 1, ARP[6])
		u += 6
	PixelArt.fill(img, 0, 3, length, 1, ARP[6])
	PixelArt.fill(img, 0, 4, length, 1, ARP[4])
	PixelArt.fill(img, 0, 5, length, 1, ARP[3])
	PixelArt.fill(img, 0, 6, length, 1, ARP[1])
	u = 10 + rn.i(20)
	while u < length - 8:
		PixelArt.fill(img, u, 2, 3, 8, ARP[4])
		PixelArt.fill(img, u, 2, 3, 1, ARP[6])
		PixelArt.fill(img, u + 2, 3, 1, 7, ARP[1])
		PixelArt.fill(img, u + 1, 4, 1, 1, ARP[7])
		PixelArt.fill(img, u + 1, 7, 1, 1, ARP[7])
		u += 34 + rn.i(18)
	var u0: int = door.u - 6 if door != null else -9
	var u1: int = door.u + door.w + 6 if door != null else -9
	var PR := [["cr0", 9], ["cr1", 9], ["cr2", 5], ["br0", 7], ["br1", 5], ["cb0", 7], ["cb1", 5], ["vn0", 6], ["gn0", 5], ["cl0", 4], ["tm0", 3], ["rp0", 9]]
	var TW := 0
	for p in PR:
		TW += p[1]
	u = 6 + rn.i(10)
	while u < length - 26:
		if u + 22 > u0 and u < u1:
			u = u1
			continue
		if rn.next() < 0.26:
			u += 8 + rn.i(16)
			continue
		var r := rn.next() * TW
		var n: String = PR[0][0]
		for p in PR:
			r -= p[1]
			if r <= 0.0:
				n = p[0]
				break
		var s: Array = Assets.arena_rects[n]
		PixelArt.sp(img, n, u, 17 - int(s[3]) - rn.i(2))
		u += int(s[2]) + 2 + rn.i(7)
	u = 40 + rn.i(60)
	while u < length - 30:
		if not (u > u0 - 10 and u < u1 + 10):
			PixelArt.sp(img, "vl0", u, 1)
		u += 110 + rn.i(70)
	PixelArt.fill(img, 0, 17, length, 1, ARP[6])
	PixelArt.fill(img, 0, 18, length, 3, ARP[3])
	PixelArt.fill(img, 0, 21, length, 1, ARP[1])
	u = 20 + rn.i(40)
	while u < length - 30:
		if not (u > u0 - 24 and u < u1 + 10):
			for i in 20:
				for v in range(18, 21):
					if rn.next() < 0.12:
						continue
					PixelArt.fill(img, u + i, v, 1, 1, ARY[2] if ((i + v) >> 1) & 1 else "#0a0a0d")
		u += 90 + rn.i(60)
	u = 24 + rn.i(14)
	while u < length - 20:
		if not (u > u0 - 8 and u < u1 + 8):
			PixelArt.sp(img, "lp0", u - 7, 17)
			lamps.append(u)
		u += 46 + rn.i(10)
	if door != null:
		PixelArt.fill(img, door.u, 2, door.w, 15, ARP[0])
		for i in door.w:
			var kc = ARY[2] if (i >> 1) & 1 else "#0a0a0d"
			PixelArt.fill(img, door.u + i, 2, 1, 1, kc)
			PixelArt.fill(img, door.u + i, 16, 1, 1, kc)
		for v in range(2, 17):
			var kc = ARY[2] if (v >> 1) & 1 else "#0a0a0d"
			PixelArt.fill(img, door.u, v, 1, 1, kc)
			PixelArt.fill(img, door.u + door.w - 1, v, 1, 1, kc)
	return {"img": img, "lamps": lamps}


func _walls(aw: int, ah: int, t: int, rn: PixelArt.Lcg, door: Dictionary) -> Dictionary:
	var img := PixelArt.make(aw, ah)
	var lamps: Array = []
	for side in [2, 3, 0, 1]:
		var length := ah if side >= 2 else aw
		var b := _band(length, t, rn, door if side == 0 else null)
		var bi: Image = b.img
		match side:
			0:
				img.blend_rect(bi, Rect2i(0, 0, length, t), Vector2i(0, 0))
			1:
				bi.flip_y()
				img.blend_rect(bi, Rect2i(0, 0, length, t), Vector2i(0, ah - t))
			2:
				bi.rotate_90(COUNTERCLOCKWISE)
				img.blend_rect(bi, Rect2i(0, 0, t, length), Vector2i(0, 0))
			3:
				bi.rotate_90(CLOCKWISE)
				img.blend_rect(bi, Rect2i(0, 0, t, length), Vector2i(aw - t, 0))
		for u in b.lamps:
			match side:
				0: lamps.append({"x": u, "y": 19, "o": 0})
				1: lamps.append({"x": u, "y": ah - 19, "o": 0})
				2: lamps.append({"x": 19, "y": ah - u, "o": 1})
				3: lamps.append({"x": aw - 19, "y": u, "o": 1})
	var cn := PixelArt.piece("cn0")
	if cn:
		var cw := cn.get_width()
		var chh := cn.get_height()
		img.blend_rect(cn, Rect2i(0, 0, cw, chh), Vector2i(0, 0))
		var fx := cn.duplicate() as Image
		fx.flip_x()
		img.blend_rect(fx, Rect2i(0, 0, cw, chh), Vector2i(aw - cw, 0))
		var fy := cn.duplicate() as Image
		fy.flip_y()
		img.blend_rect(fy, Rect2i(0, 0, cw, chh), Vector2i(0, ah - chh))
		var fxy := fx.duplicate() as Image
		fxy.flip_y()
		img.blend_rect(fxy, Rect2i(0, 0, cw, chh), Vector2i(aw - cw, ah - chh))
	return {"img": img, "lamps": lamps}


func _floor(aw: int, ah: int, t: int, rn: PixelArt.Lcg, lamps: Array) -> Dictionary:
	var f := PixelArt.make(aw, ah)
	f.fill(Color(ARP[0]))
	var TS := 24
	var iw := aw - 2 * t
	var ih := ah - 2 * t
	var mx := (iw % TS) >> 1
	var my := (ih % TS) >> 1
	var ox := t + mx - TS
	var oy := t + my - TS
	var nc := ceili(float(aw - ox) / TS)
	var nr := ceili(float(ah - oy) / TS)
	var NC := floori(float(iw) / TS)
	var NR := floori(float(ih) / TS)
	var gr: Array = []
	for j in nr:
		gr.append([])
		for i in nc:
			var k := rn.i(10)
			while (i > 0 and gr[j][i - 1] == k) or (j > 0 and gr[j - 1][i] == k):
				k = rn.i(10)
			gr[j].append(k)
			PixelArt.sp(f, "ft%d" % k, ox + i * TS, oy + j * TS)
	var T := func(n: String, i: int, j: int, rot: int) -> void: PixelArt.sp(f, n, ox + i * TS, oy + j * TS, rot)
	var cx := aw >> 1
	var cy := ah >> 1
	var cc := roundi(float(cx - ox) / TS - 0.5)
	var mr := (NR >> 1) + 1
	for d in range(-1, 2):
		T.call("fhz", cc + d, 1, 0)
		T.call("fhz", cc + d, NR, 2)
	for d in 2:
		T.call("fhz", 1, mr + d - 1, 3)
		T.call("fhz", NC, mr + d - 1, 1)
	var VG := [[2, maxi(2, roundi(NR * 0.28)), "fgr0"], [NC - 1, maxi(2, roundi(NR * 0.72)), "fgr1"], [2, maxi(3, roundi(NR * 0.8)), "fgr1"], [NC - 1, maxi(2, roundi(NR * 0.2)), "fgr0"]]
	var vents: Array = []
	for v in VG:
		T.call(v[2], v[0], v[1], 0)
		vents.append(Vector2(ox + v[0] * TS + 12, oy + v[1] * TS + 12))
	var R := roundi(minf(iw, ih) * 0.3)
	_ring(f, cx, cy, R, 3, rn)
	_ring(f, cx, cy, R - 7, 1, rn)
	for ab in [[0, -R - 8], [0, R + 6], [-R - 8, 0], [R + 6, 0]]:
		var a: int = ab[0]
		var b: int = ab[1]
		PixelArt.fill(f, cx + a - (0 if a else 3), cy + b - (3 if a else 0), 2 if a else 6, 6 if a else 2, ARY[2])
	var nm := mini(40, roundi(10.0 * iw * ih / 150000.0))
	for k in nm:
		var x := t + 14 + rn.next() * (iw - 28)
		var y := t + 14 + rn.next() * (ih - 28)
		if Vector2(x - cx, y - cy).length() < R + 14:
			continue
		var r := rn.next()
		if r < 0.45:
			var nn := "fc%d" % rn.i(4)
			PixelArt.stamp(f, nn, x, y, rn.i(4), 0.55)
		elif r < 0.8:
			PixelArt.stamp(f, "sc0", x, y, 0, 0.6)
		else:
			PixelArt.stamp(f, "cr_a", x, y, 0, 0.8)
	for l in lamps:
		var gx: float = (t + 3 if l.x < aw / 2.0 else aw - t - 3) if l.o else l.x
		var gy: float = l.y if l.o else (t + 3 if l.y < ah / 2.0 else ah - t - 3)
		PixelArt.stamp(f, "gl1", gx, gy, l.o)
	var sh := [0.38, 0.26, 0.16, 0.08]
	for i in 4:
		var c := Color(0, 0, 0, sh[i])
		PixelArt.fill(f, t, t + i, iw, 1, c)
		PixelArt.fill(f, t, ah - t - 1 - i, iw, 1, c)
		PixelArt.fill(f, t + i, t, 1, ih, c)
		PixelArt.fill(f, aw - t - 1 - i, t, 1, ih, c)
	# vinheta com dither ordenado: aplicada no shader do piso (mesma fórmula do HTML), sem custo de CPU
	return {"img": f, "vents": vents}


## Anel de contenção pintado no centro (arRing): percorre só o anel, com falhas e listras.
func _ring(f: Image, cx: int, cy: int, r: int, th: int, rn: PixelArt.Lcg) -> void:
	var R2 := (r + th) * (r + th)
	var r2 := r * r
	for y in range(-r - th, r + th + 1):
		var y2 := y * y
		if y2 >= R2:
			continue
		var xo := floori(sqrt(R2 - y2))
		var xi := maxi(0, floori(sqrt(r2 - y2))) if y2 < r2 else 0
		for sg in [-1, 1]:
			for ax in range(xi, xo + 1):
				if sg > 0 and ax == 0:
					continue
				var x: int = sg * ax
				var d := Vector2(x, y).length()
				if d < r or d >= r + th or rn.next() < 0.16:
					continue
				var a := atan2(y, x)
				var s := floori(a * r / 5.0) & 1
				var c = "#0a0a0d"
				if s:
					c = ARY[1] if rn.next() < 0.2 else ARY[2]
				f.set_pixel(cx + x, cy + y, Color(c))


# ---------------- objetos (sprites gerados uma vez) ----------------
func _sprites() -> void:
	if obs.has("ok"):
		return
	obs.ok = true
	var R := PixelArt.Lcg.new(19)
	obs.pilar = []
	for s in 4:
		var g2 := PixelArt.make(40, 40)
		PixelArt.fill(g2, 5, 5, 34, 34, Color(0, 0, 0, 0.42))
		PixelArt.fill(g2, 0, 0, 34, 34, ARP[2])
		PixelArt.fill(g2, 0, 0, 34, 1, ARP[6])
		PixelArt.fill(g2, 0, 1, 1, 33, ARP[5])
		PixelArt.fill(g2, 0, 33, 34, 1, ARP[0])
		PixelArt.fill(g2, 33, 1, 1, 32, ARP[1])
		for i in 34:
			var k = ARY[2] if (i >> 1) & 1 else "#0a0a0d"
			PixelArt.fill(g2, i, 2, 1, 2, k)
			PixelArt.fill(g2, i, 30, 1, 2, k)
		PixelArt.fill(g2, 4, 5, 26, 24, ARP[3])
		PixelArt.fill(g2, 4, 5, 26, 1, ARP[4])
		PixelArt.fill(g2, 4, 5, 1, 24, ARP[4])
		PixelArt.fill(g2, 4, 28, 26, 1, ARP[1])
		PixelArt.fill(g2, 29, 5, 1, 24, ARP[1])
		PixelArt.fill(g2, 11, 11, 12, 12, ARP[1])
		PixelArt.fill(g2, 12, 12, 10, 10, "#07080b")
		PixelArt.fill(g2, 11, 23, 12, 1, ARP[6])
		PixelArt.fill(g2, 23, 11, 1, 12, ARP[6])
		for q in [[6, 7], [27, 7], [6, 26], [27, 26]]:
			PixelArt.fill(g2, q[0], q[1], 1, 1, ARP[7])
		var rn := PixelArt.Lcg.new(31 + s)
		if s > 0:
			PixelArt.crack_paint(g2, 7 + rn.i(20), 7 + rn.i(18), 2 + s, 4 + s * 4, rn, 2 if s > 1 else 1)
		if s > 1:
			g2.fill_rect(Rect2i(30, 0, 4, 4), Color(0, 0, 0, 0))
			g2.fill_rect(Rect2i(31, 4, 3, 2), Color(0, 0, 0, 0))
			PixelArt.fill(g2, 29, 1, 1, 4, ARP[0])
			PixelArt.fill(g2, 30, 4, 1, 2, ARP[0])
		if s > 2:
			g2.fill_rect(Rect2i(0, 30, 5, 4), Color(0, 0, 0, 0))
			PixelArt.fill(g2, 2, 29, 1, 3, "#7a4a2a")
			PixelArt.fill(g2, 4, 31, 2, 1, "#7a4a2a")
			PixelArt.crack_paint(g2, 20, 18, 4, 10, rn, 2)
		obs.pilar.append(ImageTexture.create_from_image(g2))
	obs.caixa = []
	for s in 2:
		var g2 := PixelArt.make(26, 26)
		PixelArt.fill(g2, 3, 4, 22, 22, Color(0, 0, 0, 0.4))
		PixelArt.fill(g2, 0, 0, 22, 22, ARP[4])
		PixelArt.fill(g2, 0, 0, 22, 1, ARP[6])
		PixelArt.fill(g2, 0, 0, 1, 22, ARP[6])
		PixelArt.fill(g2, 0, 21, 22, 1, ARP[1])
		PixelArt.fill(g2, 21, 0, 1, 22, ARP[1])
		for i in range(2, 20):
			PixelArt.fill(g2, i, i, 1, 1, ARP[5])
			PixelArt.fill(g2, 21 - i, i, 1, 1, ARP[5])
		PixelArt.fill(g2, 2, 2, 18, 1, ARP[2])
		PixelArt.fill(g2, 2, 19, 18, 1, ARP[2])
		PixelArt.fill(g2, 7, 9, 8, 4, ARY[2])
		PixelArt.fill(g2, 8, 10, 6, 1, "#0a0a0d")
		PixelArt.fill(g2, 9, 12, 4, 1, "#0a0a0d")
		if s:
			for i in 9:
				PixelArt.fill(g2, 3 + int(R.next() * 16), 3 + int(R.next() * 16), 1 + (1 if R.next() < 0.4 else 0), 1, ARP[1])
			g2.fill_rect(Rect2i(19, 0, 3, 3), Color(0, 0, 0, 0))
			PixelArt.fill(g2, 18, 1, 1, 3, ARP[0])
		obs.caixa.append(ImageTexture.create_from_image(g2))
	obs.barril = []
	for s in 2:
		var g2 := PixelArt.make(22, 22)
		PixelArt.fill_circle(g2, 12, 13, 9, Color(0, 0, 0, 0.4))
		for y in 19:
			for x in 19:
				var d := Vector2(x - 9, y - 9).length()
				if d > 9.0:
					continue
				var c = "#3a070d"
				if d > 8.0:
					c = "#ffe2e6" if s else "#c8323f"
				elif d > 6.5:
					c = "#7d1420"
				elif d > 5.2:
					c = ARY[2] if (int(atan2(y - 9, x - 9) * 3.0) & 1) else "#0a0a0d"
				elif d > 2.6:
					c = "#9a1a28"
				PixelArt.fill(g2, x, y, 1, 1, c)
		PixelArt.fill(g2, 4, 5, 2, 1, "#ff8c96")
		PixelArt.fill(g2, 5, 4, 1, 1, "#ff8c96")
		obs.barril.append(ImageTexture.create_from_image(g2))
	obs.entulho = []
	for v in 3:
		var g2 := PixelArt.make(32, 32)
		var rn := PixelArt.Lcg.new(57 + v)
		PixelArt.fill_ellipse(g2, 17, 18, 14, 12, Color(0, 0, 0, 0.35))
		for i in 16:
			var a := rn.next() * TAU
			var d := rn.next() * 9.0
			var x := 15.0 + cos(a) * d
			var y := 15.0 + sin(a) * d
			var w := 3 + rn.i(5)
			var h := 3 + rn.i(4)
			var k := 2 + rn.i(4)
			var xx := int(x - w / 2.0)
			var yy := int(y - h / 2.0)
			PixelArt.fill(g2, xx, yy, w, h, ARP[k])
			PixelArt.fill(g2, xx, yy, w, 1, ARP[mini(7, k + 2)])
			PixelArt.fill(g2, xx, int(y + h / 2.0) - 1, w, 1, ARP[0])
		PixelArt.fill(g2, 9, 12, 1, 6, "#7a4a2a")
		PixelArt.fill(g2, 20, 9, 5, 1, "#7a4a2a")
		obs.entulho.append(ImageTexture.create_from_image(g2))


# ---------------- atualização ----------------
func post(_dt: float, A: Dictionary) -> void:
	if not A.has("tex"):
		return
	var b: Enemy = g.enc.boss
	var dk := 1 if (A.boss and g.enc.st == "active" and b != null and b.t < 1.5) else 0
	if dk != A.dkT:
		A.dkT = dk
		g.sfx("ardoor")
	A.dk += (dk - A.dk) * minf(1.0, _dt * 5.0)
	A.alarm = 1 if (b != null and b.d.get("rg", false) and g.enc.st == "active") else 0
	if b != null and b.ai is BossRhino and b.ph >= 1 and not A.get("cl", false):
		A.cl = true
		ar.collapse()


## Batidas do Rhino amassam, rasgam e racham a própria parede (o rasgo solta faíscas).
func wall_hit(A: Dictionary, x: float, y: float, pw: float) -> void:
	if not A.has("img"):
		A.fl.append({"x": x, "y": y, "t": 0.5})
		return
	var px: int = A.px
	var ax := x / px
	var ay := y / px
	var aw: int = A.aw
	var ah: int = A.ah
	var m := minf(minf(ay, ah - ay), minf(ax, aw - ax))
	var side := 0 if m == ay else (1 if m == ah - ay else (2 if m == ax else 3))
	var u := ax if side < 2 else (ah - ay if side == 2 else ay)
	var key := "%d:%d" % [side, int(u / 48.0)]
	A.wd[key] = float(A.wd.get(key, 0.0)) + pw
	var n: float = A.wd[key]
	var uu := roundi(u + (randf() - 0.5) * 14.0)
	var t: int = A.ta
	var length := aw if side < 2 else ah
	var band := PixelArt.make(length, t)
	var img: Image = A.img
	# recorta a faixa da parede atual, carimba o dano na orientação dela e devolve
	var src := _band_region(img, side, aw, ah, t)
	band.blit_rect(src, Rect2i(0, 0, length, t), Vector2i.ZERO)
	if n < 2.0:
		PixelArt.stamp(band, "wd0", uu, 13)
	elif n < 3.5:
		PixelArt.stamp(band, "wd1", uu, 13)
		PixelArt.stamp(band, "sc0", uu, 12, 0, 0.5)
	else:
		PixelArt.stamp(band, "wd2", uu, 13)
		PixelArt.stamp(band, "wt%d" % (randi() % 2), uu, 11)
		var p := Vector2(uu, 11) if side == 0 else (Vector2(uu, ah - 11) if side == 1 else (Vector2(11, ah - uu) if side == 2 else Vector2(aw - 11, uu)))
		if A.sp.size() < 8:
			A.sp.append({"x": p.x * px, "y": p.y * px, "t": 0.0})
	PixelArt.crack_paint(band, uu, 12, 3, 5 + pw * 3, RandomNumberGenerator.new(), 2 if pw > 2 else 1)
	_band_put(img, band, side, aw, ah, t)
	(A.tex as ImageTexture).update(img)


func _band_region(img: Image, side: int, aw: int, ah: int, t: int) -> Image:
	match side:
		0:
			return img.get_region(Rect2i(0, 0, aw, t))
		1:
			var r := img.get_region(Rect2i(0, ah - t, aw, t))
			r.flip_y()
			return r
		2:
			var r := img.get_region(Rect2i(0, 0, t, ah))
			r.rotate_90(CLOCKWISE)
			return r
		_:
			var r := img.get_region(Rect2i(aw - t, 0, t, ah))
			r.rotate_90(COUNTERCLOCKWISE)
			return r


func _band_put(img: Image, band: Image, side: int, aw: int, ah: int, t: int) -> void:
	match side:
		0:
			img.blit_rect(band, Rect2i(0, 0, aw, t), Vector2i(0, 0))
		1:
			band.flip_y()
			img.blit_rect(band, Rect2i(0, 0, aw, t), Vector2i(0, ah - t))
		2:
			band.rotate_90(COUNTERCLOCKWISE)
			img.blit_rect(band, Rect2i(0, 0, t, ah), Vector2i(0, 0))
		_:
			band.rotate_90(CLOCKWISE)
			img.blit_rect(band, Rect2i(0, 0, t, ah), Vector2i(aw - t, 0))


# ---------------- desenho ----------------
## Textura base (piso + paredes) num nó próprio, com o shader da vinheta.
func draw_floor_tex(c: CanvasItem, A: Dictionary) -> void:
	if not A.has("tex"):
		return
	var mat := c.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("enabled", true)
		mat.set_shader_parameter("art_size", Vector2(A.aw, A.ah))
		mat.set_shader_parameter("wall", float(A.ta))
	var v: Rect2 = ar.view_rect()
	var px: int = A.px
	var sx := maxi(0, floori(v.position.x / px))
	var sy := maxi(0, floori(v.position.y / px))
	var ex := mini(A.aw, ceili(v.end.x / px) + 1)
	var ey := mini(A.ah, ceili(v.end.y / px) + 1)
	if ex > sx and ey > sy:
		# a região inteira é enviada; o shader precisa do UV da arte completa, então desenhamos a textura toda
		c.draw_texture_rect(A.tex, Rect2(0, 0, A.aw * px, A.ah * px), false)


func draw_floor(c: CanvasItem, A: Dictionary) -> void:
	if not A.has("tex"):
		ar._draw_energy(c, A)
		return
	var v: Rect2 = ar.view_rect()
	var px: int = A.px
	# porta de contenção: as folhas deslizam para os lados enquanto o chefe entra
	var t: int = A.ta
	if A.door and v.position.y < t * px + 40:
		var d: Dictionary = A.door
		var dx: float = d.u * px
		var dw: float = d.w * px
		var y0 := 2.0 * px
		var y1 := 17.0 * px
		var lw := dw / 2.0
		var sh: float = A.dk * lw
		var clip := Rect2(dx, y0, dw, y1 - y0)
		_leaf(c, dx - sh, lw, y0, y1, px, false, clip)
		_leaf(c, dx + lw + sh, lw, y0, y1, px, true, clip)
	if A.alarm and not Settings.s.reduce:
		c.draw_rect(v, Color(150 / 255.0, 0, 12 / 255.0, 0.05 + 0.05 * sin(A.tm * 7.0)))


func _leaf(c: CanvasItem, x: float, lw: float, y0: float, y1: float, px: int, inner: bool, clip: Rect2) -> void:
	var R := func(r: Rect2, col) -> void:
		var q := r.intersection(clip)
		if q.size.x > 0.0 and q.size.y > 0.0:
			c.draw_rect(q, Color(col))
	R.call(Rect2(x, y0, lw, y1 - y0), ARP[3])
	R.call(Rect2(x, y0, lw, px), ARP[6])
	R.call(Rect2(x, y1 - px, lw, px), ARP[1])
	for q in range(2, 17):
		R.call(Rect2(x if inner else x + lw - 3 * px, q * px, 3 * px, px), ARY[2] if (q >> 1) & 1 else "#0a0a0d")
	R.call(Rect2(x + 3 * px if inner else x, y0 + px, lw - 3 * px, px), ARP[5])


## Brilhos aditivos: luz da porta aberta e poças de luz vermelha das lâmpadas (pulsam; mais rápidas no alarme).
func draw_floor_add(c: CanvasItem, A: Dictionary) -> void:
	if not A.has("tex"):
		return
	var v: Rect2 = ar.view_rect()
	var px: int = A.px
	var t: int = A.ta
	var aw: int = A.aw
	var ah: int = A.ah
	if A.door and A.dk > 0.0:
		var g0: Array = Assets.arena_rects.get("gl0", [])
		if not g0.is_empty():
			var d: Dictionary = A.door
			var dx: float = d.u * px
			var dw: float = d.w * px
			var gw := 64.0 * px
			var dst := Rect2(dx + dw / 2.0 - gw / 2.0, 2.0 * px - 8.0 * px, gw, gw)
			_blit_clipped(c, Rect2(g0[0], g0[1], g0[2], g0[3]), dst, Rect2(dx, 2.0 * px, dw, 15.0 * px), Color(1, 1, 1, 0.8 * A.dk))
	var gl: Array = Assets.arena_rects.get("gl1", [])
	if gl.is_empty() or Settings.s.q == 0:
		return
	var a0: bool = A.alarm
	var gw: float = gl[2] * px
	var gh: float = gl[3] * px
	var stp := 1 if (a0 or Settings.s.q >= 2) else 2
	var i := 0
	while i < A.lamps.size():
		var l: Dictionary = A.lamps[i]
		var o: int = l.o
		var gx: float = ((t + 3 if l.x < aw / 2.0 else aw - t - 3) if o else l.x) * px
		var gy: float = (l.y if o else (t + 3 if l.y < ah / 2.0 else ah - t - 3)) * px
		if gx > v.position.x - 120.0 and gx < v.end.x + 120.0 and gy > v.position.y - 120.0 and gy < v.end.y + 120.0:
			var pl := 0.8 if Settings.s.reduce else ((0.55 + 0.45 * sin(A.tm * 7.0 + i * 0.9)) if a0 else (0.62 + 0.38 * sin(A.tm * 2.1 + i * 1.7)))
			var al := minf(1.0, pl * (0.9 if a0 else 0.7))
			if o == 0:
				c.draw_texture_rect_region(Assets.arena_tex, Rect2(gx - gw / 2.0, gy - gh / 2.0, gw, gh), Rect2(gl[0], gl[1], gl[2], gl[3]), Color(1, 1, 1, al))
			else:
				c.draw_set_transform(Vector2(gx, gy), PI / 2.0, Vector2.ONE)
				c.draw_texture_rect_region(Assets.arena_tex, Rect2(-gw / 2.0, -gh / 2.0, gw, gh), Rect2(gl[0], gl[1], gl[2], gl[3]), Color(1, 1, 1, al))
				c.draw_set_transform_matrix(Transform2D.IDENTITY)
		i += stp


func _blit_clipped(c: CanvasItem, src: Rect2, dst: Rect2, clip: Rect2, mod: Color) -> void:
	var q := dst.intersection(clip)
	if q.size.x <= 0.0 or q.size.y <= 0.0:
		return
	var sx := src.size.x / dst.size.x
	var sy := src.size.y / dst.size.y
	var s := Rect2(src.position.x + (q.position.x - dst.position.x) * sx, src.position.y + (q.position.y - dst.position.y) * sy, q.size.x * sx, q.size.y * sy)
	c.draw_texture_rect_region(Assets.arena_tex, q, s, mod)


func draw_objects(c: CanvasItem, A: Dictionary) -> void:
	if A.obj.is_empty():
		return
	_sprites()
	var v: Rect2 = ar.view_rect()
	var m := 80.0
	for o in A.obj:
		if o.x < v.position.x - m or o.x > v.end.x + m or o.y < v.position.y - m or o.y > v.end.y + m:
			continue
		match o.k:
			"pilar":
				c.draw_texture_rect(obs.pilar[int(o.dm)], Rect2(o.x - 34, o.y - 34, 80, 80), false)
			"caixa":
				c.draw_texture_rect(obs.caixa[1 if o.hp < o.mhp * 0.5 else 0], Rect2(o.x - 22, o.y - 22, 52, 52), false)
			"barril":
				var fl := 1 if (o.get("st", "") == "fuse" and int(A.tm * 20.0) % 2) else 0
				c.draw_texture_rect(obs.barril[fl], Rect2(o.x - 19, o.y - 19, 44, 44), false)
			"entulho":
				c.draw_texture_rect(obs.entulho[int(o.v)], Rect2(o.x - 32, o.y - 32, 64, 64), false)
			"vapor":
				if o.st == 1:
					Draw.dashed_ring(c, Vector2(o.x, o.y), o.r, 8.0, 6.0, -A.tm * 30.0, Color(1, 0.7, 0.42, 0.35 + 0.35 * absf(sin(A.tm * 10.0))), 2.0)
		if o.get("fl", 0.0) > 0.0 and o.k != "vapor":
			if o.has("hw"):
				c.draw_rect(Rect2(o.x - o.hw, o.y - o.hh, o.hw * 2.0, o.hh * 2.0), Color(1, 1, 1, 0.6))
			else:
				Draw.circle(c, Vector2(o.x, o.y), o.r, Color(1, 1, 1, 0.6))


## Vapor por cima do mundo (drawSteam).
func draw_after(c: CanvasItem, A: Dictionary) -> void:
	var v: Rect2 = ar.view_rect()
	for o in A.obj:
		if o.k != "vapor" or o.st == 0:
			continue
		if o.x < v.position.x - 90.0 or o.x > v.end.x + 90.0 or o.y < v.position.y - 90.0 or o.y > v.end.y + 90.0:
			continue
		if o.st == 1:
			for i in 4:
				var k := fmod(A.tm * 1.3 + i / 4.0, 1.0)
				Draw.circle(c, Vector2(o.x + sin(i * 2.1 + A.tm * 3.0) * 14.0, o.y - k * 36.0), 4.0 + k * 8.0, Color(0.87, 0.91, 0.94, (1.0 - k) * 0.3))
		else:
			var k: float = 1.0 - o.t / 1.4
			var n := 7 if Settings.s.q >= 2 else 4
			for i in n:
				var a: float = i * TAU / n + A.tm * 0.7
				var d: float = o.r * (0.25 + 0.45 * fmod(i * 0.37 + A.tm * 0.6, 1.0))
				Draw.circle(c, Vector2(o.x + cos(a) * d, o.y + sin(a) * d), o.r * 0.42 * (1.0 + 0.3 * sin(A.tm * 5.0 + i)), Color(0.91, 0.93, 0.96, 0.22 * (1.0 - k * 0.6)))
			Draw.circle(c, Vector2(o.x, o.y), o.r * 0.35, Color(1, 1, 1, 0.3))
