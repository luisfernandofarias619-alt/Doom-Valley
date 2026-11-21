extends Node
## Recordes e salvamento da partida Classic (equivalente a REC 'nexus_rec_v3' e SK 'nexus_save_v1' do HTML).
## O arquivo é gravado com soma de verificação (FNV-1a, como os slots v2) e uma cópia de segurança.

const REC_PATH := "user://records.json"
const SAVE_PATH := "user://classic_save.json"
const BAK_PATH := "user://classic_save.bak.json"


func records() -> Dictionary:
	var d := {"kills": 0, "level": 0, "runs": 0, "score": 0, "time": 0, "wins": 0, "fenda": 0}
	var r = _read_json(REC_PATH)
	if r is Dictionary:
		for k in d.keys():
			if r.has(k) and (r[k] is int or r[k] is float):
				d[k] = int(r[k])
	return d


func write_records(d: Dictionary) -> void:
	_write_json(REC_PATH, d)


static func fnv(s: String) -> String:
	var h: int = 2166136261
	for b in s.to_utf8_buffer():
		h = (h ^ b) & 0xffffffff
		h = (h * 16777619) & 0xffffffff
	return String.num_int64(h, 36)


func has_save() -> bool:
	return read_save().get("st", "") == "ok"


## Lê o salvamento; se o principal estiver corrompido, tenta a cópia de segurança.
func read_save() -> Dictionary:
	var r := _read_rec(SAVE_PATH)
	if r.st != "ok":
		var b := _read_rec(BAK_PATH)
		if b.st == "ok":
			b["rec"] = 1
			return b
	return r


func _read_rec(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"st": "vazio"}
	var o = _read_json(path)
	if not (o is Dictionary) or o.get("app") != "DOOMVALLEY" or not (o.get("d") is Dictionary):
		return {"st": "corrompido"}
	if fnv(JSON.stringify(o.d, "", true)) != o.get("sum", ""):
		return {"st": "corrompido"}
	return {"st": "ok", "d": o.d, "t": o.get("t", 0)}


func write_save(d: Dictionary) -> bool:
	if FileAccess.file_exists(SAVE_PATH) and _read_rec(SAVE_PATH).st == "ok":
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH), ProjectSettings.globalize_path(BAK_PATH))
	# a soma é calculada sobre a forma já normalizada pelo JSON (inteiros voltam como float na leitura)
	var norm = JSON.parse_string(JSON.stringify(d))
	var rec := {"app": "DOOMVALLEY", "v": 1, "t": int(Time.get_unix_time_from_system()), "sum": fnv(JSON.stringify(norm, "", true)), "d": norm}
	return _write_json(SAVE_PATH, rec)


func save_info() -> String:
	var r := read_save()
	if r.st != "ok":
		return ""
	var dt := Time.get_datetime_dict_from_unix_time(int(r.t) + _tz_offset())
	var d: Dictionary = r.d
	return "%02d/%02d às %02d:%02d · setor %d · nível %d" % [dt.day, dt.month, dt.hour, dt.minute, int(d.get("sec", 0)) + 1, int(d.get("st", {}).get("level", 0))]


func _tz_offset() -> int:
	var tz := Time.get_time_zone_from_system()
	return int(tz.get("bias", 0)) * 60


func _read_json(path: String):
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	return JSON.parse_string(f.get_as_text())


func _write_json(path: String, d) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(d, "", true))
	return true
