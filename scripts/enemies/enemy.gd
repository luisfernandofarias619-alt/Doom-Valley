class_name Enemy
extends RefCounted
## Inimigo comum ou chefe (class Enemy do HTML). Chefes têm `bd` (definição) e `ai` (comportamento próprio).

const TYPES := {
	"basic": {"hp": 40, "speed": 80, "radius": 15, "color": "#ff0055"},
	"fast": {"hp": 20, "speed": 170, "radius": 12, "color": "#00ff88"},
	"tank": {"hp": 180, "speed": 50, "radius": 25, "color": "#7000ff"},
	"shooter": {"hp": 50, "speed": 70, "radius": 15, "color": "#ff00ff"},
	"boss": {"hp": 2000, "speed": 60, "radius": 50, "color": "#ffcc00"},
	"splitter": {"hp": 70, "speed": 62, "radius": 20, "color": "#ffaa00"},
	"fragment": {"hp": 14, "speed": 115, "radius": 9, "color": "#ffcc66"},
	"guard": {"hp": 150, "speed": 55, "radius": 22, "color": "#4d7cff"},
	"gunner": {"hp": 45, "speed": 70, "radius": 15, "color": "#ff8a2b"},
	"rifter": {"hp": 35, "speed": 105, "radius": 13, "color": "#d36bff"},
	"leech": {"hp": 30, "speed": 95, "radius": 11, "color": "#7dff6a"},
}

var x := 0.0
var y := 0.0
var type := "basic"
var hp := 40.0
var max_hp := 40.0
var speed := 80.0
var radius := 15.0
var color := Color("#ff0055")
var hit_timer := 0.0
var anim_phase := 0.0
var ang := 0.0
var last_shot := 0.0
var charge := 0.0
var ax := 0.0
var ay := 0.0
var elite := false
var is_boss := false
var is_ultra := false
var fatal = null          # Dictionary: com qual poder o golpe final aconteceu
var inv := 0.0            # invulnerável
var vuln := 1.0           # multiplicador de dano recebido
var fz := false           # já fortalecido pela Fenda

# arquétipos
var rush := 0.0
var tw := 0.0
var rx := 0.0
var ry := 0.0
var bl := 0.0

# ---- chefes ----
var bd: Dictionary = {}   # definição (tabela BD)
var ai = null             # BossBase
var name := ""
var t := 0.0
var cd := 0.0
var al := 0.0
var sc := 1.0
var ph := 0
var seen := false
var vis := 1
var flash := 0.0
var chg := 0.0
var chg2 := false
var stun := 0.0
var spd := 0.0
var lx = null
var ly = null
var wph := 0.0
var face := 1.0
var an := ""
var af := 0.0
var fps := 8.0
var stm := -1.0           # estamina do chefe (Vesperon)
var exh := 0.0
var stg := 0              # vezes que foi aparado
var no_touch := false
var no_aim := false
var hid := false
var d := {}               # estado próprio de cada IA de chefe


func _init(px := 0.0, py := 0.0, kind := "basic") -> void:
	x = px
	y = py
	type = kind
	anim_phase = randf() * TAU
	var c: Dictionary = TYPES.get(kind, TYPES.basic)
	hp = float(c.hp)
	max_hp = hp
	speed = float(c.speed)
	radius = float(c.radius)
	color = Color(c.color)
	if kind == "boss":
		is_boss = true
	# BUG CORRIGIDO: no HTML, fast/tank/shooter mudavam só `hp` e deixavam `maxHp=40`; a v6 recalcula
	# hp a partir de maxHp (NF.mkEnemy), então o tanque (180) nascia com 40 de vida. Aqui hp = maxHp sempre.
