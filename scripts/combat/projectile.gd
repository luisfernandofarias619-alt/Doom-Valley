class_name Projectile
extends RefCounted
## Projétil (class Projectile do HTML). Os nomes dos campos seguem o original para facilitar a conferência.

var x := 0.0
var y := 0.0
var vx := 0.0
var vy := 0.0
var radius := 4.0
var color := Color("#00f2ff")
var foe := false
var history := PackedVector2Array()

# tiros do jogador
var hit := {}            # inimigos já atravessados (prisma/perfuração)
var pc := 0              # perfurações restantes
var ally := false
var wg := false          # disparado em movimento com Asas
var shield_shot := false # disparado com escudo ativo
var pr := false          # prismático
var rb := 0              # ricochetes restantes
var bn := 0              # ricochetes feitos
var tu := false          # da torreta
var nerfed := false
var dm6 := 1.0           # multiplicador de dano da arma
var lf := -1.0           # tempo de vida (<0 = sem limite)
var kb := 0.0            # empurrão
var hm := false          # teleguiado
var ls := 0.0            # roubo de vida
var ts := false          # cópia do Tesseract
var refl := false        # tiro aparado devolvido
var mr := false          # já refletido por painel espelhado

# tiros inimigos
var dmg := 10.0
var bp := false          # tiro de chefe (sprite brilhante)
var shard := false       # formato de lasca
var pry := false         # aparável (contorno dourado)
var src = null           # quem atirou (Enemy)
var spr := ""            # quadro da folha 'ilu'
var ss := 0.3
var stop := -1.0         # pirâmides: tempo até parar
var split := -1.0
var sd := false


func _init(px := 0.0, py := 0.0, pvx := 0.0, pvy := 0.0, col := Color("#00f2ff"), is_foe := false, area_scale := 1.0) -> void:
	x = px
	y = py
	vx = pvx
	vy = pvy
	color = col
	foe = is_foe
	radius = 4.0 * (1.0 if is_foe else area_scale)


func update(dt: float) -> void:
	history.insert(0, Vector2(x, y))
	if history.size() > 5:
		history.resize(5)
	x += vx * dt
	y += vy * dt
