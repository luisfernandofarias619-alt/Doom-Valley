class_name ItemData
## Catálogo de itens do HTML v6.0 (ITM, RAR e TIPO). Nomes, textos e valores são os do original.
## t: tipo (res, seed, arma, arm, rel, cons, esp) · r: raridade · w: peso na mochila (padrão 0,1 kg)
## wp: perfil de disparo da arma · st: bônus de armadura/relíquia · boss: chefe que dá o item

const RARITY := {
	"c": ["Comum", "#c8d0d8"], "i": ["Incomum", "#3dff7a"], "r": ["Raro", "#3da0ff"],
	"e": ["Épico", "#c070ff"], "l": ["Lendário", "#ffb020"], "u": ["Único", "#ff4d6d"],
}
const TYPE_NAME := {"res": "Recurso", "seed": "Semente", "arma": "Arma", "arm": "Armadura",
	"rel": "Relíquia", "cons": "Consumível", "esp": "Especial"}

const ITEMS := {
	"sucata": {"n": "Sucata", "t": "res", "r": "c", "w": 0.2, "ic": "gear", "c": "#9aa4b0", "d": "Restos de máquinas. Base de quase tudo na oficina."},
	"circuito": {"n": "Circuito", "t": "res", "r": "i", "w": 0.2, "ic": "chip", "c": "#3dff7a", "d": "Placas tiradas de inimigos mecânicos."},
	"cristal": {"n": "Cristal de dados", "t": "res", "r": "i", "w": 0.3, "ic": "gem", "c": "#5fd7ff", "d": "Memória cristalizada. Brota nos mundos abertos."},
	"essencia": {"n": "Essência neural", "t": "res", "r": "r", "w": 0.1, "ic": "orb", "c": "#c070ff", "d": "Pulso de consciência. Elites e chefes deixam cair."},
	"cinza": {"n": "Cinza de Cinderfall", "t": "res", "r": "r", "w": 0.1, "ic": "dust", "c": "#b8a99a", "d": "O que restou da biblioteca de Vesperon. Também serve de adubo."},
	"sangue": {"n": "Sangue antigo", "t": "res", "r": "r", "w": 0.2, "ic": "drop", "c": "#ff2b55", "d": "Colhido na Cripta Carmesim. Adubo que muda as plantas."},
	"ouro": {"n": "Ouro áureo", "t": "res", "r": "r", "w": 0.4, "ic": "tri", "c": "#ffd23d", "d": "Metal do Templo do Olho."},
	"fragmento": {"n": "Fragmento anômalo", "t": "res", "r": "e", "w": 0.1, "ic": "cube", "c": "#9b5cff", "d": "Um pedaço de espaço que não obedece regras. Adubo dimensional."},
	"vidro": {"n": "Vidro refletido", "t": "res", "r": "e", "w": 0.3, "ic": "shard", "c": "#ffd6ff", "d": "Reflete o que você fez, não o que você é."},
	"petala": {"n": "Pétala de néon", "t": "res", "r": "i", "w": 0.05, "ic": "leaf", "c": "#ff5ad8", "d": "Colhida no canteiro. Energiza estimulantes."},
	"folha": {"n": "Folha de ferro", "t": "res", "r": "i", "w": 0.05, "ic": "leaf", "c": "#9fb7a3", "d": "Colhida no canteiro. Vai nos kits de reparo e no adubo comum."},
	"eco": {"n": "Eco", "t": "res", "r": "r", "w": 0.05, "ic": "orb", "c": "#7fe0ff", "d": "Som guardado de uma lembrança. Os visitantes do jardim aceitam como moeda."},
	"brasa": {"n": "Brasa viva", "t": "res", "r": "r", "w": 0.05, "ic": "dust", "c": "#ff8a3d", "d": "Calor que não se apaga."},
	"prisma": {"n": "Prisma de aço", "t": "res", "r": "e", "w": 0.1, "ic": "gem", "c": "#e0f0ff", "d": "Planta mutante cristalizada."},
	"selo": {"n": "Marca de selo", "t": "res", "r": "e", "w": 0.05, "ic": "ring", "c": "#ffe08a", "d": "Prova de uma dimensão concluída sem chefe. Substitui os itens dos chefes nas receitas."},

	"s_neon": {"n": "Semente de néon", "t": "seed", "r": "c", "w": 0.02, "ic": "seed", "c": "#ff5ad8", "pl": "neon", "d": "Planta a Flor de néon."},
	"s_ferro": {"n": "Semente de ferro", "t": "seed", "r": "c", "w": 0.02, "ic": "seed", "c": "#9fb7a3", "pl": "ferro", "d": "Planta a Erva-de-ferro."},
	"s_eco": {"n": "Semente de eco", "t": "seed", "r": "r", "w": 0.02, "ic": "seed", "c": "#7fe0ff", "pl": "eco", "d": "Planta o Lírio-eco."},
	"s_brasa": {"n": "Semente de brasa", "t": "seed", "r": "r", "w": 0.02, "ic": "seed", "c": "#ff8a3d", "pl": "brasa", "d": "Planta a Brasa-viva."},
	"s_anom": {"n": "Semente anômala", "t": "seed", "r": "e", "w": 0.02, "ic": "seed", "c": "#9b5cff", "pl": "anom", "d": "Encontrada num ladrilho que só existe na neblina. Planta o Broto anômalo."},

	"pulsor": {"n": "Pulsor", "t": "arma", "r": "c", "ic": "gun", "c": "#00f2ff", "d": "A arma de sempre: equilibrada.", "wp": {}},
	"dispersor": {"n": "Dispersor", "t": "arma", "r": "i", "ic": "gun", "c": "#ffaa00", "d": "+2 projéteis em leque, 40% menos dano por projétil e menos alcance.", "wp": {"n": 2, "dm": 0.6, "rg": 0.75, "sd": 0.22}},
	"agulheiro": {"n": "Agulheiro", "t": "arma", "r": "i", "ic": "gun", "c": "#3dff7a", "d": "Dispara 60% mais rápido com 35% menos dano. Atravessa 1 inimigo.", "wp": {"cd": 0.62, "dm": 0.65, "pr": 1, "sp": 1.25}},
	"lanca": {"n": "Lança de plasma", "t": "arma", "r": "r", "ic": "gun", "c": "#3da0ff", "d": "Tiro lento e pesado (+80% de dano) que atravessa 3 inimigos.", "wp": {"cd": 1.35, "dm": 1.8, "pr": 3, "sp": 1.4, "sz": 1.5}},
	"chifre": {"n": "Chifre do Rhino", "t": "arma", "r": "e", "ic": "horn", "c": "#ff3344", "d": "Tiros pesados: +60% de dano e empurrão. Disparo 20% mais lento.", "wp": {"cd": 1.2, "dm": 1.6, "kb": 240, "sz": 1.3}, "boss": "rhino"},
	"presa": {"n": "Presa carmesim", "t": "arma", "r": "e", "ic": "fang", "c": "#ff2b55", "d": "Cada acerto cura 0,6 de vida.", "wp": {"ls": 0.6}, "boss": "dracula"},
	"codice": {"n": "Códice Queimado", "t": "arma", "r": "l", "ic": "book", "c": "#ff9a3d", "d": "Páginas cortantes que atravessam 2 inimigos; a cada 5 disparos, uma rajada de 5 páginas.", "wp": {"pr": 2, "dm": 0.9, "burst": 5}, "boss": "vesperon"},
	"olho": {"n": "Olho áureo", "t": "arma", "r": "e", "ic": "eye", "c": "#ffd23d", "d": "Tiros que curvam em direção ao inimigo mais próximo.", "wp": {"hm": 1, "dm": 0.95}, "boss": "illuminati"},

	"jaqueta": {"n": "Jaqueta de lona", "t": "arm", "r": "c", "ic": "coat", "c": "#9aa4b0", "d": "+10 de vida máxima.", "st": {"hp": 10}},
	"placas": {"n": "Placas de contenção", "t": "arm", "r": "i", "ic": "coat", "c": "#ff6a6a", "d": "+30 de vida máxima, 5% mais lento.", "st": {"hp": 30, "spd": 0.95}},
	"sobrecasaca": {"n": "Sobrecasaca do Arquivista", "t": "arm", "r": "l", "ic": "coat", "c": "#b8a99a", "d": "+20 de vida e disparos 12% mais rápidos.", "st": {"hp": 20, "as": 0.88}, "boss": "vesperon"},
	"manto": {"n": "Manto carmesim", "t": "arm", "r": "e", "ic": "coat", "c": "#ff2b55", "d": "+15 de vida e +0,8 de regeneração.", "st": {"hp": 15, "reg": 0.8}, "boss": "dracula"},

	"ima": {"n": "Ímã de dados", "t": "rel", "r": "i", "ic": "mag", "c": "#5fd7ff", "d": "Atrai itens e orbes de mais longe.", "st": {"mag": 1}},
	"lente": {"n": "Lente prismática", "t": "rel", "r": "r", "ic": "eye", "c": "#e0f0ff", "d": "+10% de chance de crítico.", "st": {"crit": 0.1}},
	"bateria": {"n": "Bateria extra", "t": "rel", "r": "r", "ic": "bat", "c": "#ccff00", "d": "+40 de estamina máxima.", "st": {"stm": 40}},
	"coracao": {"n": "Coração de reserva", "t": "rel", "r": "e", "ic": "heart", "c": "#ff4d6d", "d": "Uma vez por expedição, o Nick volta com 35% da vida ao cair.", "st": {"rev": 1}},
	"amuleto": {"n": "Amuleto de sorte", "t": "rel", "r": "r", "ic": "tri", "c": "#ffd23d", "d": "+25% de recursos coletados.", "st": {"loot": 0.25}},
	"luva": {"n": "Luva de aparar", "t": "rel", "r": "r", "ic": "glove", "c": "#ffe08a", "d": "Janela de aparo 40% maior.", "st": {"pryw": 1.4}},
	"selobib": {"n": "Selo do Bibliotecário", "t": "rel", "r": "l", "ic": "ring", "c": "#ff9a3d", "d": "Rolar custa 30% menos estamina.", "st": {"rollc": 0.7}},
	"vortice": {"n": "Vórtice de Cinzas", "t": "rel", "r": "l", "ic": "swirl", "c": "#ff9a3d", "d": "A cada 6 s, uma tempestade de brasas fere e empurra quem estiver perto.", "st": {"vort": 1}},
	"tesseract": {"n": "Tesseract partido", "t": "rel", "r": "l", "ic": "cube", "c": "#9b5cff", "d": "20% dos tiros que acertam reaparecem atrás do alvo e acertam de novo.", "st": {"tess": 0.2}, "boss": "anomalia"},
	"reflexo": {"n": "Reflexo", "t": "rel", "r": "l", "ic": "shard", "c": "#ffd6ff", "d": "A cada 3 disparos, um eco seu atira para o lado oposto.", "st": {"refl": 1}, "boss": "espelho"},

	"kit": {"n": "Kit de reparo", "t": "cons", "r": "c", "w": 0.5, "ic": "kit", "c": "#ff0055", "d": "Recupera 40% da vida."},
	"pulso": {"n": "Bomba de pulso", "t": "cons", "r": "i", "w": 0.5, "ic": "bomb", "c": "#00f2ff", "d": "Apaga os tiros inimigos por perto e fere quem estiver no raio."},
	"estim": {"n": "Estimulante", "t": "cons", "r": "i", "w": 0.3, "ic": "vial", "c": "#ccff00", "d": "Enche a estamina e dá +20% de velocidade por 6 s."},
	"cha": {"n": "Chá de ferro", "t": "cons", "r": "r", "w": 0.3, "ic": "vial", "c": "#9fb7a3", "d": "+4 de regeneração por 12 s. Feito da Erva medicinal."},

	"memoria": {"n": "Memória de Cinderfall", "t": "esp", "r": "l", "w": 0.1, "ic": "orb", "c": "#ff9a3d", "d": "A alma de Vesperon. Na oficina, vira o Vórtice de Cinzas ou o Selo do Bibliotecário.", "boss": "vesperon"},
}


static func get_item(id: String) -> Dictionary:
	return ITEMS.get(id, {})


static func weight(id: String) -> float:
	return float(ITEMS.get(id, {}).get("w", 0.1))
