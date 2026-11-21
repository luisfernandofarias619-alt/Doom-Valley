class_name PlayerState
extends RefCounted
## Estado do Nick (objeto `player` do HTML). Valores iniciais idênticos aos do original.

var x := 0.0
var y := 0.0
var radius := 18.0
var speed := 220.0
var max_hp := 100.0
var hp := 100.0
var level := 0
var xp := 0.0
var xp_to_next := 50.0
var kills := 0
var damage := 25.0
var attack_speed := 900.0   # ms entre disparos
var last_attack := -1e9
var projectiles := 1
var area_scale := 1.0
var regen := 0.5
var shield := 0.0
var shield_max := 0.0
var is_dashing := false     # invulnerável (janela do rolamento)
var angle := 0.0
var prism_active := false
var crit := 0.1
var mag := 0
var vamp := 0
var iv := 0.0               # invulnerabilidade curta após golpe corpo a corpo
var rolling := false
var st := 100.0             # estamina
var st_max := 100.0
var st_t := 0.0             # atraso antes de recuperar estamina

const SAVE_KEYS := ["level", "xp", "xp_to_next", "kills", "hp", "max_hp", "damage", "speed", "attack_speed",
	"projectiles", "area_scale", "regen", "shield", "shield_max", "crit", "mag", "vamp", "prism_active", "st"]


func reset() -> void:
	radius = 18.0; speed = 220.0; max_hp = 100.0; hp = 100.0; level = 0; xp = 0.0; xp_to_next = 50.0
	kills = 0; damage = 25.0; attack_speed = 900.0; last_attack = -1e9; projectiles = 1; area_scale = 1.0
	regen = 0.5; shield = 0.0; shield_max = 0.0; is_dashing = false; prism_active = false; crit = 0.1
	mag = 0; vamp = 0; iv = 0.0; rolling = false; st_max = 100.0; st = st_max; st_t = 0.0


func snapshot() -> Dictionary:
	var d := {}
	for k in SAVE_KEYS:
		d[k] = get(k)
	return d


func apply(d: Dictionary) -> void:
	for k in SAVE_KEYS:
		if d.has(k):
			var v = d[k]
			if (v is float or v is int) and is_finite(float(v)):
				set(k, int(v) if typeof(get(k)) == TYPE_INT else float(v))
			elif v is bool:
				set(k, v)
