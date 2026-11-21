class_name Equipment
## Equipamento e perfis de arma (eqStats, wpn e applyEquip do HTML v6.0).
## Bônus de armadura e relíquias: aditivos, exceto spd, as, rollc e pryw, que são multiplicativos.


static func default_equip() -> Dictionary:
	return {"arma": "pulsor", "arm": null, "rel": [null, null], "cons": "kit"}


static func stats(equip: Dictionary) -> Dictionary:
	var o := {"hp": 0.0, "spd": 1.0, "as": 1.0, "reg": 0.0, "mag": 0, "crit": 0.0, "stm": 0.0,
		"rev": 0, "loot": 0.0, "rollc": 1.0, "vort": 0, "pryw": 1.0, "tess": 0.0, "refl": 0}
	var ids: Array = [equip.get("arm")]
	ids.append_array(equip.get("rel", [null, null]))
	for id in ids:
		if id == null or not ItemData.ITEMS.has(id):
			continue
		var st: Dictionary = ItemData.ITEMS[id].get("st", {})
		for k in st:
			if k in ["spd", "as", "rollc", "pryw"]:
				o[k] = float(o[k]) * float(st[k])
			else:
				o[k] = o[k] + st[k]
	return o


## Aplica o equipamento e o modo ao jogador no início da partida (applyEquip do HTML).
static func apply(p: PlayerState, equip: Dictionary, mode: Dictionary) -> Dictionary:
	var q := stats(equip)
	p.max_hp = 100.0 + float(q.hp)
	p.speed = 220.0 * float(q.spd)
	p.attack_speed = 900.0 * float(q.as)
	p.regen = 0.0 if mode.get("noreg", false) else 0.5 + float(q.reg)
	if int(q.mag) > 0:
		p.mag = int(q.mag)
	if float(q.crit) > 0.0:
		p.crit = 0.1 + float(q.crit)
	p.st_max = 100.0 + float(q.stm)
	p.st = p.st_max
	p.hp = p.max_hp
	return q


## Perfil de disparo da arma equipada, com o nível de melhoria (+12% de dano por nível).
static func weapon(id, lv: int = 0) -> Dictionary:
	var it: Dictionary = ItemData.ITEMS.get(id, {})
	if it.get("t", "") != "arma":
		return {}
	var w: Dictionary = (it.get("wp", {}) as Dictionary).duplicate()
	if lv > 0:
		w.dm = float(w.get("dm", 1.0)) * (1.0 + 0.12 * lv)
	return w
