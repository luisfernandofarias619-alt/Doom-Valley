extends Node
## Carrega texturas, tabelas de recorte (atlas) e fontes. Equivale a atl()/atlDraw()/RF/ARJ do HTML.

var atl := {}            # id -> {anim -> [[x, y, w, h, ax, ay], ...]}
var sheets := {}         # id -> Texture2D (folhas WebP enviadas pelo criador)
var rhino_tex: Texture2D
var rhino_frames := {}   # anim -> [[x, y, w, h, ax, ay], ...]
var gyr := 40            # linha do chão no atlas do Rhino
var arena_tex: Texture2D
var arena_img: Image
var arena_rects := {}    # nome -> [x, y, w, h]
var icons := {}

var font_ui: SystemFont
var font_ui_bold: SystemFont
var font_ui_black: SystemFont
var font_mono: SystemFont
var font_mono_bold: SystemFont

var _radials := {}
var disc: ImageTexture   # disco branco com borda suavizada (círculos pequenos em lote)
var _bullets := {}


func _ready() -> void:
	atl = AtlasData.ATL
	for id in atl.keys():
		sheets[id] = load("res://assets/sprites/sheets/%s.webp" % id)
	rhino_frames = AtlasData.RF
	gyr = AtlasData.GYR
	rhino_tex = load("res://assets/sprites/rhino_atlas.png")
	arena_rects = AtlasData.ARJ
	arena_tex = load("res://assets/sprites/arena_atlas.png")
	if arena_tex:
		arena_img = arena_tex.get_image()
		if arena_img and arena_img.is_compressed():
			arena_img.decompress()
		if arena_img:
			arena_img.convert(Image.FORMAT_RGBA8)
	for n in ["codice", "memoria", "olho", "selobib", "sobrecasaca", "vortice"]:
		icons[n] = load("res://assets/sprites/icons/%s.png" % n)
	var ui_names := PackedStringArray(["Segoe UI", "Roboto", "Helvetica", "Arial", "Noto Sans", "DejaVu Sans", "sans-serif"])
	var mono_names := PackedStringArray(["Consolas", "DejaVu Sans Mono", "Roboto Mono", "Noto Sans Mono", "Courier New", "monospace"])
	disc = _make_disc(64)
	font_ui = _sysfont(ui_names, 400)
	font_ui_bold = _sysfont(ui_names, 700)
	font_ui_black = _sysfont(ui_names, 900)
	font_mono = _sysfont(mono_names, 400)
	font_mono_bold = _sysfont(mono_names, 700)


func _make_disc(n: int) -> ImageTexture:
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := n / 2.0
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5 - c, y + 0.5 - c).length()
			img.set_pixel(x, y, Color(1, 1, 1, clampf(c - d, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


func _sysfont(names: PackedStringArray, weight: int) -> SystemFont:
	var f := SystemFont.new()
	f.font_names = names
	f.font_weight = weight
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return f


## Quadro i (com repetição) da animação anim da folha id. Vazio se não existir.
func frame(id: String, anim: String, i: int) -> Array:
	var T: Dictionary = atl.get(id, {})
	var L: Array = T.get(anim, [])
	if L.is_empty():
		return []
	var n := L.size()
	return L[((i % n) + n) % n]


func anim_len(id: String, anim: String) -> int:
	return (atl.get(id, {}).get(anim, []) as Array).size()


## Desenha um quadro: âncora no ponto (x, y), escala s, espelhado se fx < 0 (atlDraw do HTML).
func draw_atl(ci: CanvasItem, id: String, anim: String, i: int, x: float, y: float, s: float, fx: float, alpha: float = 1.0, mod: Color = Color.WHITE) -> bool:
	var tex: Texture2D = sheets.get(id)
	if tex == null:
		return false
	var f := frame(id, anim, i)
	if f.is_empty():
		return false
	ci.draw_set_transform(Vector2(roundf(x), roundf(y)), 0.0, Vector2(-1.0 if fx < 0.0 else 1.0, 1.0))
	var c := mod
	c.a *= alpha
	ci.draw_texture_rect_region(tex, Rect2(-float(f[4]) * s, -float(f[5]) * s, float(f[2]) * s, float(f[3]) * s), Rect2(f[0], f[1], f[2], f[3]), c)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	return true


func rhino_frame(anim: String, i: int) -> Array:
	var L: Array = rhino_frames.get(anim, [])
	if L.is_empty():
		return []
	var n := L.size()
	return L[((i % n) + n) % n]


## Textura de gradiente radial (createRadialGradient do canvas) com cache por par de cores.
func radial(c0: Color, c1: Color, stops: PackedFloat32Array = PackedFloat32Array()) -> GradientTexture2D:
	var key := "%s|%s|%s" % [c0.to_html(), c1.to_html(), str(stops)]
	if _radials.has(key):
		return _radials[key]
	var g := Gradient.new()
	g.set_color(0, c0)
	g.set_color(1, c1)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 128
	t.height = 128
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	_radials[key] = t
	return t


## Sprite dos tiros dos chefes (spr(col) do HTML): branco → cor → cor 40% → transparente.
func bullet_sprite(col: Color) -> GradientTexture2D:
	var key := col.to_html()
	if _bullets.has(key):
		return _bullets[key]
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.22, 0.55, 1.0])
	g.colors = PackedColorArray([Color.WHITE, col, Color(col, 0.4), Color(col, 0.0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 48
	t.height = 48
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	_bullets[key] = t
	return t


## Recorte do atlas da arena como Image (para montar o cenário em pixel art).
func arena_piece(n: String) -> Image:
	var r: Array = arena_rects.get(n, [])
	if r.is_empty() or arena_img == null:
		return null
	return arena_img.get_region(Rect2i(r[0], r[1], r[2], r[3]))
