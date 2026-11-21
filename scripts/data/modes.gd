class_name Modes
## Os 11 modos de dificuldade do HTML v6.0 (MODES, MORD e MDF). Valores padrão em DEFAULTS.
## ehp: vida dos inimigos · edmg: dano dos inimigos · pdmg: dano que o Nick recebe · xp: multiplicador de XP
## brate: cadência dos chefes · elite: chance de elite · espd: velocidade dos inimigos · heal: cura de consumíveis
## perma: morte apaga o slot · man: tiro manual · noreg: sem regeneração · one: qualquer dano é fatal
## imm: a vida nunca chega a zero · noif: invulnerabilidade curta de 0,15 s · boss/noboss/classic/noevo: estrutura

const ORDER := ["normal", "facil", "baby", "dificil", "hardcore", "hardcorex", "onehit", "impossivel", "noboss", "classico", "noevo"]

const DEFAULTS := {"ehp": 1.0, "edmg": 1.0, "pdmg": 1.0, "xp": 1.0, "brate": 1.0, "elite": 0.04, "espd": 1.0, "heal": 1.0}

const DATA := {
	"normal": {"n": "Normal", "d": "O jogo como foi pensado: jardim, dimensões e chefes."},
	"facil": {"n": "Fácil", "d": "Inimigos com 30% menos vida e dano. XP +25%.", "ehp": 0.7, "edmg": 0.7, "xp": 1.25},
	"baby": {"n": "Baby Mode", "d": "Sem pressão: você recebe 25% do dano e a vida nunca chega a zero.", "pdmg": 0.25, "imm": true, "ehp": 0.6, "espd": 0.85},
	"dificil": {"n": "Difícil", "d": "Inimigos com +35% de vida e +30% de dano. Chefes atacam com mais frequência.", "ehp": 1.35, "edmg": 1.3, "brate": 1.2, "elite": 0.06},
	"hardcore": {"n": "Hardcore", "d": "Morte permanente e tiro manual. Dano recebido +25%.", "perma": true, "pdmg": 1.25, "man": true,
		"warn": "Se o Nick cair numa dimensão, este slot é apagado para sempre, com jardim, itens e progresso. O tiro é manual no toque e no mouse."},
	"hardcorex": {"n": "Hardcore Extra", "d": "Hardcore sem regeneração, com menos cura e inimigos 50% mais resistentes.", "perma": true, "pdmg": 1.4, "man": true,
		"noreg": true, "heal": 0.4, "ehp": 1.5, "edmg": 1.25, "elite": 0.08,
		"warn": "Tudo do Hardcore (slot apagado se o Nick cair, tiro manual), sem regeneração de vida, 60% menos cura e inimigos mais fortes."},
	"onehit": {"n": "One Hit", "d": "Qualquer dano é fatal. Escudos não protegem.", "one": true,
		"warn": "Um único golpe, tiro ou área encerra a expedição. O slot não é apagado: você volta ao jardim com a mochila inteira."},
	"impossivel": {"n": "Impossible", "d": "Inimigos com o dobro da vida e +75% de dano, chefes 50% mais rápidos, invulnerabilidade mínima. Tiro manual.",
		"ehp": 2.0, "edmg": 1.75, "brate": 1.5, "elite": 0.12, "noif": true, "man": true,
		"warn": "Para quem já domina o jogo: a invulnerabilidade depois de golpes cai para 0,15 s e o tiro é manual."},
	"noboss": {"n": "No Boss", "d": "Sem chefes: cada dimensão termina num Selo final. Os selos liberam as próximas dimensões, o rolamento, o aparo e receitas que substituem os itens dos chefes.", "noboss": true},
	"classico": {"n": "Classic", "d": "As ondas originais em campo aberto, com setores e chefes por abates. Sem jardim.", "classic": true},
	"noevo": {"n": "No Evolution", "d": "Sem menu de evolução: cada nível vira recursos. O equipamento decide a expedição.", "noevo": true},
}


## Modo completo (valores padrão + modificadores).
static func get_mode(id: String) -> Dictionary:
	var m := DEFAULTS.duplicate()
	m.merge(DATA.get(id, DATA.classico), true)
	m.id = id if DATA.has(id) else "classico"
	return m


## Dano efetivo que o Nick recebe (dmgIn do HTML). Retorna hp + 1 quando o modo é One Hit (morte certa).
static func incoming(m: Dictionary, hp: float, amt: float) -> float:
	var a := amt * float(m.edmg) * float(m.pdmg)
	if m.get("one", false) and a > 0.0:
		return hp + 1.0
	if m.get("imm", false) and hp - a < 1.0:
		a = maxf(0.0, hp - 1.0)
	return a


## Vida e velocidade de um inimigo comum neste modo (mkEnemy do HTML).
static func apply_enemy(m: Dictionary, e: Enemy) -> void:
	if e.is_boss:
		return
	e.max_hp = roundf(e.max_hp * float(m.ehp))
	e.hp = e.max_hp
	e.speed *= float(m.espd)
