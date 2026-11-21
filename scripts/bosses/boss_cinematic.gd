class_name BossCinematic
extends RefCounted
## Entrada dos chefes: barras de cinema, câmera no chefe e fala antes da batalha (CINE/BSAY do HTML v6.0).
## Primeiro encontro: fala completa; revanche: fala curta. Toque/clique/tecla completa o texto; de novo, pula.
## Durante a cena o jogador não anda, não atira e não toma dano; a IA do chefe espera.

const BSAY := {
	"rhino": ["Cheiro de superfície. Aqui dentro, quem corre bate na parede.", "De novo? As paredes ainda lembram de você."],
	"dracula": ["Um visitante da sala da frente... e ainda quente. Sente-se. A noite é longa.", "Você de novo. O sangue tem memória, sabia?"],
	"vesperon": ["Silêncio. Cada página aqui queima por um motivo. Você é só uma nota de rodapé.", "Reli o seu capítulo. Termina do mesmo jeito."],
	"illuminati": ["Eu vi você chegar antes de você decidir vir.", "Previsível. Eu já tinha visto esta parte."],
	"anomalia": ["VOCÊ TEM UM LADO DE DENTRO. EU QUERO VER.", "NÃO EXISTE O MESMO LADO DUAS VEZES."],
	"espelho": ["Eu ando como você. Atiro como você. Só não hesito.", "Eu lembro como você venceu. E você?"],
}
const POSE := {"illuminati": {"an": "alerta", "fps": 5.0}}
const SEEN_PATH := "user://intro_seen.json"

var g
var on := false
var t := 0.0
var id := ""
var txt := ""
var name := ""
var c := Color.WHITE
var say0 := 0.0
var say1 := 0.0
var end := 0.0
var fp := false
var out := 0.0
var _seen := {}


func _init(game) -> void:
	g = game
	var f := FileAccess.open(SEEN_PATH, FileAccess.READ)
	if f:
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			_seen = d


func start(boss_id: String, is_fp: bool) -> void:
	if not BSAY.has(boss_id) or not Settings.s.cine:
		return
	var seen: bool = _seen.get(boss_id, false)
	var bd: Dictionary = {}
	for b in BossEncounter.BD:
		if b.id == boss_id:
			bd = b
	on = true
	t = 0.0
	id = boss_id
	fp = is_fp
	name = bd.get("n", boss_id.to_upper())
	c = Color(bd.get("c", "#ffffff"))
	txt = BSAY[boss_id][1 if seen else 0]
	say0 = 1.3 if is_fp else 2.5
	say1 = say0 + txt.length() / 38.0
	end = say1 + (1.1 if seen else 1.6)
	_seen[boss_id] = true
	var fw := FileAccess.open(SEEN_PATH, FileAccess.WRITE)
	if fw:
		fw.store_string(JSON.stringify(_seen))


func stop() -> void:
	if not on:
		return
	on = false
	out = 0.4
	var L = g.arena.cam.look
	if L != null and L.get("cine", false):
		L.t = maxf(L.t, L.a + L.h)


func skip() -> void:
	if not on or t < 0.4:
		return
	if t < say0 and not fp and g.enc.st == "prep":
		g.enc.t = maxf(g.enc.t, 2.2)
		t = say0 - 0.2
		return
	if t < say1:
		t = say1
		return
	stop()


## Segura a IA do chefe enquanto a cena roda (a descida de entrada continua).
func hold(b: Enemy, dt: float) -> bool:
	if not on:
		return false
	b.t = minf(b.t, 1.2)
	b.inv = maxf(b.inv, 0.3)
	var P: Dictionary = POSE.get(b.bd.get("id", ""), {})
	if not P.is_empty():
		if b.an != P.an:
			b.an = P.an
			b.af = 0.0
		b.af += dt * float(P.fps)
	return true


func update(dt: float) -> void:
	if out > 0.0:
		out -= dt
	if not on:
		return
	if g.paused and not fp:
		return
	t += dt
	if not fp:
		var b: Enemy = g.enc.boss
		var cam: Dictionary = g.arena.cam
		if b != null and cam.look == null and t < end - 0.6:
			cam.look = {"x": b.x, "y": b.y + 40.0, "t": 0.0, "a": 0.7, "h": maxf(0.6, end - t - 1.2), "d": 0.6, "cine": true}
		if b != null and cam.look != null and cam.look.get("cine", false):
			cam.look.x = b.x
			cam.look.y = b.y + 30.0
		if g.enc.st != "prep" and g.enc.st != "active":
			stop()
			return
	elif not g.fp_active:
		stop()
		return
	if t >= end:
		stop()


func draw(cv: CanvasItem) -> void:
	var a := minf(1.0, t / 0.35) if on else maxf(0.0, out / 0.4)
	if a <= 0.0:
		return
	var vw: float = g.vw
	var vh: float = g.vh
	var e := a * a * (3.0 - 2.0 * a)
	var h1 := vh * 0.085 * e
	var h2 := maxf(vh * 0.15, 92.0) * e
	cv.draw_rect(Rect2(0, 0, vw, h1), Color.BLACK)
	cv.draw_rect(Rect2(0, vh - h2, vw, h2), Color.BLACK)
	if on and t >= say0:
		var n := mini(txt.length(), floori((t - say0) * 38.0))
		var fs := roundi(maxf(14.0, minf(19.0, vw / 38.0)))
		var x0 := maxf(16.0, vw * 0.06)
		var mw := vw - x0 * 2.0
		Draw.text(cv, Assets.font_mono_bold, name, Vector2(x0, vh - h2 + 12.0 + fs - 2), fs - 2, Draw.alpha(c, minf(1.0, (t - say0) * 4.0)), HORIZONTAL_ALIGNMENT_LEFT)
		var font := Assets.font_ui_bold
		var ws := txt.substr(0, n).split(" ")
		var ln := ""
		var y := vh - h2 + 14.0 + fs * 2.0
		for w in ws:
			var t2 := (ln + " " + w) if ln != "" else w
			if Draw.text_width(font, t2, fs) > mw and ln != "":
				Draw.text(cv, font, ln, Vector2(x0, y), fs, Color("#f2f2f2"))
				y += fs * 1.3
				ln = w
			else:
				ln = t2
		Draw.text(cv, font, ln, Vector2(x0, y), fs, Color("#f2f2f2"))
		if n >= txt.length() and int(t * 2.0) % 2:
			Draw.text(cv, Assets.font_mono_bold, "TOQUE PARA SEGUIR" if Settings.is_touch else "CLIQUE OU TECLA PARA SEGUIR", Vector2(vw - x0, vh - 18.0), 11, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_RIGHT)
