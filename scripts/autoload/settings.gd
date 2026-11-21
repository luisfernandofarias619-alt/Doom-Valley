extends Node
## Configurações persistentes (equivalente ao objeto S / chave 'nexus_fx_v3' do HTML).
## Salvas em user://settings.cfg. Os nomes das chaves são os mesmos do original.

const PATH := "user://settings.cfg"

## Tabela de qualidade gráfica: limite de partículas, multiplicador de quantidade e de brilho.
const Q := [
	{"cap": 120, "k": 0.4, "g": 0.35},
	{"cap": 300, "k": 0.7, "g": 0.7},
	{"cap": 600, "k": 1.0, "g": 1.0},
]

var is_touch: bool = false

var DEF := {
	"q": 2, "bloom": true, "particles": true, "shake": true, "distort": true, "trails": true,
	"flash": true, "reduce": false, "intensity": 1.0, "diag": true, "sound": true, "tl": 8,
	"auto": true, "vol": 0.8, "music": 0.5, "mreal": true, "mmap": "", "dev": false,
	"aim": "auto", "sens": 1.0, "vibr": true, "hud": 1.0, "bsz": 1.0, "bop": 0.85,
	"sfxv": 1.0, "cb": false, "hint": true, "cine": true, "amb": true,
}
var s := {}


func _ready() -> void:
	is_touch = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	DEF["aim"] = "auto" if is_touch else "man"
	s = DEF.duplicate()
	load_settings()


func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	for k in DEF.keys():
		if cf.has_section_key("s", k):
			var v = cf.get_value("s", k)
			if typeof(v) == typeof(DEF[k]) or (typeof(DEF[k]) == TYPE_FLOAT and typeof(v) == TYPE_INT):
				s[k] = v
	_sanitize()


func _sanitize() -> void:
	s.q = clampi(int(s.q), 0, 2)
	s.tl = clampi(int(s.tl), 3, 14)
	s.vol = clampf(float(s.vol), 0.0, 1.0)
	s.music = clampf(float(s.music), 0.0, 1.0)
	s.intensity = clampf(float(s.intensity), 0.3, 1.5)
	if s.aim != "man" and s.aim != "auto":
		s.aim = DEF.aim
	s.sens = clampf(float(s.sens), 0.4, 2.2)
	s.hud = clampf(float(s.hud), 0.8, 1.4)
	s.bsz = clampf(float(s.bsz), 0.7, 1.5)
	s.bop = clampf(float(s.bop), 0.3, 1.0)
	s.sfxv = clampf(float(s.sfxv), 0.0, 1.0)


func persist() -> void:
	_sanitize()
	var cf := ConfigFile.new()
	for k in s.keys():
		cf.set_value("s", k, s[k])
	cf.save(PATH)
	Events.settings_changed.emit()


func set_value(k: String, v) -> void:
	s[k] = v
	persist()


func restore_defaults() -> void:
	s = DEF.duplicate()
	persist()


func quality() -> Dictionary:
	return Q[int(s.q)]


## Volume final dos efeitos (window.NXVOL no original).
func sfx_volume() -> float:
	return float(s.vol) * float(s.sfxv) if s.sound else 0.0


## Multiplicador do brilho neon (substitui a redefinição de ctx.shadowBlur).
func glow_mul() -> float:
	return float(quality().g) * float(s.intensity) if s.bloom else 0.0
