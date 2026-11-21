class_name SlotStore
## Slots de save v2 (SV, slotRead, slotWrite, slotExport e slotImport do HTML v6.0).
## Três slots. Cada gravação guarda a versão anterior como cópia de segurança; uma leitura com soma
## de verificação errada (FNV-1a) ou dados inválidos cai para essa cópia, como no original.

const COUNT := 3
const VERSION := 2
const LAST_PATH := "user://mind_last_slot.txt"


static func path(n: int) -> String:
	return "user://mind_slot_%d.json" % n


static func bak_path(n: int) -> String:
	return "user://mind_slot_%d.bak.json" % n


static func fnv(s: String) -> String:
	var h: int = 2166136261
	for b in s.to_utf8_buffer():
		h = ((h ^ b) * 16777619) & 0xffffffff
	return String.num_int64(h, 36)


static func new_slot(mode_id: String) -> Dictionary:
	return {
		"v": VERSION, "mode": mode_id, "created": int(Time.get_unix_time_from_system()), "play": 0.0,
		"scene": "classic", "last": "",
		"prog": {"bosses": {}, "sealed": {}, "first": {}, "unl": {}, "deaths": 0, "runs": 0, "kills": 0,
			"rolls": 0, "parries": 0, "fenda": 0, "best": {}, "res": {}},
		"res": {"sucata": 10},
		"inv": [{"id": "s_neon", "q": 2}, {"id": "s_ferro", "q": 2}, {"id": "kit", "q": 1}],
		"equip": {"arma": "pulsor", "arm": null, "rel": [null, null], "cons": "kit"},
		"cap": {"bag": 30, "bau": 40, "beds": 3},
		"wlv": {},
	}


## Valida e corrige o que for possível. Retorna false se a estrutura não for de um slot.
static func valid(d) -> bool:
	if typeof(d) != TYPE_DICTIONARY or int(d.get("v", 0)) != VERSION:
		return false
	if not Modes.DATA.has(str(d.get("mode", ""))):
		return false
	for k in ["prog", "res", "equip", "cap", "wlv"]:
		if typeof(d.get(k)) != TYPE_DICTIONARY:
			return false
	if typeof(d.get("inv")) != TYPE_ARRAY:
		return false
	d.play = maxf(0.0, float(d.get("play", 0.0)))
	var inv2: Array = []
	for i in d.inv:
		if typeof(i) == TYPE_DICTIONARY and ItemData.ITEMS.has(i.get("id", "")) and ItemData.ITEMS[i.id].t != "res":
			var q := int(i.get("q", 0))
			if q > 0:
				inv2.append({"id": i.id, "q": mini(9999, q)})
	d.inv = inv2
	var E: Dictionary = d.equip
	for k in ["arma", "arm", "cons"]:
		if E.get(k) != null and not ItemData.ITEMS.has(E[k]):
			E[k] = null
	if E.get("arma") == null:
		E.arma = "pulsor"
	if typeof(E.get("rel")) != TYPE_ARRAY:
		E.rel = [null, null]
	E.rel = [E.rel[0] if E.rel.size() > 0 and ItemData.ITEMS.has(E.rel[0]) else null, E.rel[1] if E.rel.size() > 1 and ItemData.ITEMS.has(E.rel[1]) else null]
	return true


static func _parse(txt: String) -> Dictionary:
	var o = JSON.parse_string(txt)
	if typeof(o) != TYPE_DICTIONARY:
		return {"st": "arquivo inválido"}
	if o.get("app") != "MIND" or typeof(o.get("d")) != TYPE_DICTIONARY:
		return {"st": "não é um save do jogo"}
	if int(o.get("v", 0)) > VERSION:
		return {"st": "save de uma versão mais nova"}
	if fnv(JSON.stringify(o.d, "", true)) != str(o.get("sum", "")):
		return {"st": "arquivo alterado ou corrompido"}
	if not valid(o.d):
		return {"st": "dados incompletos"}
	return {"st": "ok", "d": o.d, "t": o.get("t", 0)}


static func _read_file(p: String) -> Dictionary:
	if not FileAccess.file_exists(p):
		return {"st": "vazio"}
	return _parse(FileAccess.get_file_as_string(p))


## Lê o slot n. Se o principal estiver corrompido, usa a cópia de segurança (rec = 1).
static func read(n: int) -> Dictionary:
	var r := _read_file(path(n))
	if r.st == "corrompido" or r.st == "futuro" or r.st == "arquivo alterado ou corrompido" or r.st == "dados incompletos" or r.st == "arquivo inválido":
		var b := _read_file(bak_path(n))
		if b.st == "ok":
			b.rec = 1
			b.why = r.st
			return b
	return r


static func _normalized(d: Dictionary) -> Dictionary:
	# a soma é calculada sobre a forma já normalizada pelo JSON (inteiros voltam como floats na leitura)
	return JSON.parse_string(JSON.stringify(d))


static func write(n: int, d: Dictionary) -> bool:
	if FileAccess.file_exists(path(n)) and _read_file(path(n)).st == "ok":
		DirAccess.copy_absolute(ProjectSettings.globalize_path(path(n)), ProjectSettings.globalize_path(bak_path(n)))
	var norm := _normalized(d)
	var rec := {"app": "MIND", "v": VERSION, "t": int(Time.get_unix_time_from_system()),
		"sum": fnv(JSON.stringify(norm, "", true)), "d": norm}
	var f := FileAccess.open(path(n), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(rec))
	return true


static func delete(n: int) -> void:
	if FileAccess.file_exists(path(n)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path(n)))
	if FileAccess.file_exists(bak_path(n)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(bak_path(n)))


## Texto do slot (arquivo .json de exportação, com soma de verificação).
static func export_text(n: int) -> String:
	if not FileAccess.file_exists(path(n)):
		return ""
	return FileAccess.get_file_as_string(path(n))


## Importa um texto para o slot n. O slot substituído fica como cópia de segurança. Retorna "" se deu certo.
static func import_text(n: int, txt: String) -> String:
	var r := _parse(txt)
	if r.st != "ok":
		return r.st
	if FileAccess.file_exists(path(n)):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(path(n)), ProjectSettings.globalize_path(bak_path(n)))
	var f := FileAccess.open(path(n), FileAccess.WRITE)
	if f == null:
		return "falha ao gravar"
	f.store_string(txt)
	return ""


static func last_slot() -> int:
	if not FileAccess.file_exists(LAST_PATH):
		return 0
	return int(FileAccess.get_file_as_string(LAST_PATH))


static func set_last(n: int) -> void:
	var f := FileAccess.open(LAST_PATH, FileAccess.WRITE)
	if f:
		f.store_string(str(n))
