extends CanvasLayer
## Interface (equivale ao HUD/DOM do HTML: barras, modal de EVOLUÇÃO, tela inicial, pausa, painel NX de
## opções, TERMINATED, vitória, avisos do NeonCore e botões de toque). Tudo em Control/Containers com Theme.

const PRIMARY := Color("#00f2ff")
const ENEMY := Color("#ff0055")
const GOLD := Color("#ffcc00")
const BG := Color("#050508")

var game: Game
var root: Control
var hud: Control
var hp_bar: ColorRect
var xp_bar: ColorRect
var st_box: Control
var st_bar: ColorRect
var lvl_lbl: Label
var kill_lbl: Label
var flash: ColorRect
var toast_box: VBoxContainer
var pause_btn: Button
var joy_base: Control
var joy_stick: Control
var touch_btns: VBoxContainer
var roll_btn: Button
var parry_btn: Button

var title_scr: Control
var cont_btn: Button
var rec_lbl: Label
var lvl_modal: Control
var lvl_opts: VBoxContainer
var lvl_info: Label
var pause_scr: Control
var pause_msg: Label
var pause_list: Label
var pause_np: Label
var restart_btn: Button
var over_scr: Control
var over_stats: Label
var win_scr: Control
var win_stats: Label
var opt_panel: Control
var opt_tabs: HBoxContainer
var opt_body: VBoxContainer
var opt_cur := "fx"
var _picked := false
var _confirm := false
var _flash_t := 0.0
var _hud_cache := ["", "", -1, -1]


func _ready() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _theme()
	root.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(root)
	_build_hud()
	_build_title()
	_build_levelup()
	_build_pause()
	_build_over()
	_build_win()
	_build_options()
	Events.notify.connect(toast)
	Events.player_damaged.connect(_on_damaged)


func bind(g: Game) -> void:
	game = g
	g.level_up_requested.connect(show_levelup)
	g.game_ended.connect(show_over)
	g.victory_reached.connect(show_win)
	g.pause_changed.connect(_on_pause)
	refresh_title()


# ======================================================================
# tema
# ======================================================================
func _sb(bg: Color, border: Color = Color(0, 0, 0, 0), radius: int = 10, bw: int = 0, pad: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.6
	s.content_margin_bottom = pad * 0.6
	s.anti_aliasing = true
	return s


func _theme() -> Theme:
	var t := Theme.new()
	t.default_font = Assets.font_ui
	t.default_font_size = 14
	t.set_color("font_color", "Label", Color.WHITE)
	t.set_stylebox("normal", "Button", _sb(PRIMARY, Color(0, 0, 0, 0), 30, 0, 22))
	t.set_stylebox("hover", "Button", _sb(PRIMARY.lightened(0.25), Color(0, 0, 0, 0), 30, 0, 22))
	t.set_stylebox("pressed", "Button", _sb(PRIMARY.darkened(0.2), Color(0, 0, 0, 0), 30, 0, 22))
	t.set_stylebox("focus", "Button", _sb(Color(0, 0, 0, 0), Color.WHITE, 30, 2, 22))
	t.set_stylebox("disabled", "Button", _sb(Color(PRIMARY, 0.3), Color(0, 0, 0, 0), 30, 0, 22))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(k, "Button", Color.BLACK)
	t.set_font("font", "Button", Assets.font_ui_bold)
	t.set_font_size("font_size", "Button", 15)
	for k in ["normal", "hover", "pressed", "focus", "hover_pressed", "disabled"]:
		t.set_stylebox(k, "CheckButton", StyleBoxEmpty.new())
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(k, "OptionButton", Color("#d8e0ea"))
	t.set_stylebox("normal", "OptionButton", _sb(Color(0.02, 0.02, 0.04, 1), Color(1, 1, 1, 0.13), 8, 1, 8))
	t.set_stylebox("hover", "OptionButton", _sb(Color(0.05, 0.05, 0.09, 1), Color(0, 0.95, 1, 0.5), 8, 1, 8))
	t.set_stylebox("pressed", "OptionButton", _sb(Color(0.05, 0.05, 0.09, 1), Color(0, 0.95, 1, 0.5), 8, 1, 8))
	t.set_stylebox("focus", "OptionButton", _sb(Color(0, 0, 0, 0), Color(0, 0.95, 1, 0.5), 8, 1, 8))
	t.set_font("font", "OptionButton", Assets.font_ui)
	t.set_font_size("font_size", "OptionButton", 13)
	t.set_stylebox("panel", "PanelContainer", _sb(Color(0.043, 0.043, 0.078, 0.96), Color(1, 1, 1, 0.13), 14, 1, 14))
	t.set_stylebox("slider", "HSlider", _sb(Color(1, 1, 1, 0.1), Color(0, 0, 0, 0), 3, 0, 2))
	t.set_stylebox("grabber_area", "HSlider", _sb(Color(PRIMARY, 0.6), Color(0, 0, 0, 0), 3, 0, 2))
	t.set_stylebox("grabber_area_highlight", "HSlider", _sb(PRIMARY, Color(0, 0, 0, 0), 3, 0, 2))
	return t


func _btn(text: String, cb: Callable, small: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func():
		Sfx.play("blink")
		cb.call())
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(0, 44)
	if small:
		b.add_theme_font_size_override("font_size", 13)
	b.pivot_offset = Vector2(60, 22)
	b.mouse_entered.connect(func(): b.scale = Vector2(1.04, 1.04))
	b.mouse_exited.connect(func(): b.scale = Vector2.ONE)
	return b


func _ghost(text: String, cb: Callable) -> Button:
	var b := _btn(text, cb, true)
	b.add_theme_stylebox_override("normal", _sb(Color(0, 0, 0, 0), Color(1, 1, 1, 0.13), 8, 1, 11))
	b.add_theme_stylebox_override("hover", _sb(Color(0, 0.95, 1, 0.12), Color(0, 0.95, 1, 0.53), 8, 1, 11))
	b.add_theme_stylebox_override("pressed", _sb(Color(0, 0.95, 1, 0.2), Color(0, 0.95, 1, 0.53), 8, 1, 11))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, Color("#d8e0ea"))
	b.add_theme_font_override("font", Assets.font_ui)
	b.custom_minimum_size = Vector2(0, 36)
	return b


func _label(text: String, size: int = 14, col: Color = Color.WHITE, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if font:
		l.add_theme_font_override("font", font)
	return l


func _screen(bg_center: Color) -> Control:
	var s := Control.new()
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var gt := GradientTexture2D.new()
	var gr := Gradient.new()
	gr.offsets = PackedFloat32Array([0.0, 0.7])
	gr.colors = PackedColorArray([bg_center, Color(0.02, 0.02, 0.03, 0.93)])
	gt.gradient = gr
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.4)
	gt.fill_to = Vector2(1.1, 0.4)
	bg.texture = gt
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.add_child(bg)
	root.add_child(s)
	return s


func _center_box(parent: Control, width: float = 420.0) -> VBoxContainer:
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(cc)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(minf(width, 640.0), 0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 8)
	cc.add_child(v)
	return v


func _center_label(v: VBoxContainer, text: String, size: int, col: Color, font: Font) -> Label:
	var l := _label(text, size, col, font)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	return l


# ======================================================================
# HUD
# ======================================================================
func _build_hud() -> void:
	flash = ColorRect.new()
	flash.color = Color(1, 0, 0, 0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash)
	hud = VBoxContainer.new()
	hud.position = Vector2(20, 20)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(hud as VBoxContainer).add_theme_constant_override("separation", 6)
	root.add_child(hud)
	hp_bar = _bar(hud, [ENEMY, Color("#ff4488")])
	xp_bar = _bar(hud, [Color("#ccff00"), Color("#eeff88")])
	st_bar = _bar(hud, [Color("#9fe8ff"), Color("#ccff00")], 6.0)
	st_box = st_bar.get_parent().get_parent()
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 20)
	lvl_lbl = _label("LVL 0", 12, Color.WHITE, Assets.font_ui_black)
	kill_lbl = _label("KILLS 0", 12, Color.WHITE, Assets.font_ui_black)
	stats.add_child(lvl_lbl)
	stats.add_child(kill_lbl)
	hud.add_child(stats)
	toast_box = VBoxContainer.new()
	toast_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_box.position = Vector2(-200, 20)
	toast_box.custom_minimum_size = Vector2(400, 0)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.add_child(toast_box)
	pause_btn = _round_btn("II", func(): if game: game.toggle_pause())
	pause_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_btn.position = Vector2(-44, 10)
	pause_btn.size = Vector2(34, 34)
	root.add_child(pause_btn)
	joy_base = Control.new()
	joy_base.size = Vector2(100, 100)
	joy_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joy_base.visible = false
	joy_base.draw.connect(func():
		joy_base.draw_circle(Vector2(50, 50), 50, Color(1, 1, 1, 0.05))
		joy_base.draw_arc(Vector2(50, 50), 50, 0, TAU, 48, Color(1, 1, 1, 0.1), 2.0, true))
	root.add_child(joy_base)
	joy_stick = Control.new()
	joy_stick.size = Vector2(50, 50)
	joy_stick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joy_stick.draw.connect(func():
		joy_stick.draw_circle(Vector2(25, 25), 25, PRIMARY))
	joy_base.add_child(joy_stick)
	touch_btns = VBoxContainer.new()
	touch_btns.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	touch_btns.position = Vector2(-90, -170)
	touch_btns.add_theme_constant_override("separation", 10)
	root.add_child(touch_btns)
	parry_btn = _round_btn("APARAR", func(): if game: game.do_parry())
	parry_btn.custom_minimum_size = Vector2(68, 68)
	parry_btn.add_theme_color_override("font_color", Color("#ffe08a"))
	roll_btn = _round_btn("ROLAR", func(): if game: game.do_roll())
	roll_btn.custom_minimum_size = Vector2(68, 68)
	touch_btns.add_child(parry_btn)
	touch_btns.add_child(roll_btn)
	set_hud_visible(false)


func _bar(parent: Control, cols: Array, h: float = 10.0) -> ColorRect:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(250, h)
	box.add_theme_stylebox_override("panel", _sb(Color(1, 1, 1, 0.05), Color(1, 1, 1, 0.1), 5, 1, 0))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var clip := Control.new()
	clip.clip_contents = true
	clip.custom_minimum_size = Vector2(248, h - 2)
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(clip)
	var f := ColorRect.new()
	f.size = Vector2(248, h - 2)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := CanvasItemMaterial.new()
	f.material = mat
	f.color = cols[0]
	clip.add_child(f)
	var grad := TextureRect.new()
	var gt := GradientTexture2D.new()
	var gr := Gradient.new()
	gr.colors = PackedColorArray([cols[0], cols[1]])
	gt.gradient = gr
	gt.width = 64
	gt.height = 4
	grad.texture = gt
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	grad.set_anchors_preset(Control.PRESET_FULL_RECT)
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.add_child(grad)
	parent.add_child(box)
	return f


func _round_btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", _sb(Color(0.043, 0.043, 0.078, 0.8), Color(1, 1, 1, 0.2), 40, 1, 2))
	b.add_theme_stylebox_override("hover", _sb(Color(0.08, 0.08, 0.14, 0.9), Color(0, 0.95, 1, 0.6), 40, 1, 2))
	b.add_theme_stylebox_override("pressed", _sb(Color(0, 0.95, 1, 0.25), Color(0, 0.95, 1, 0.8), 40, 1, 2))
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, PRIMARY)
	b.add_theme_font_size_override("font_size", 11)
	b.pressed.connect(cb)
	return b


func set_hud_visible(v: bool) -> void:
	hud.visible = v
	pause_btn.visible = v


func toast(text: String, col: Color) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(Color(0, 0, 0, 0.85), col, 5, 1, 12))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _label("[NEONCORE] " + text, 13, col, Assets.font_mono)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.modulate.a = 0.0
	toast_box.add_child(p)
	var tw := create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.4)
	tw.tween_interval(1.2)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)


func _on_damaged(a: float) -> void:
	if not Settings.s.flash:
		return
	flash.color.a = minf(0.3, 0.06 + a * 0.03)
	_flash_t = 0.09


func _process(delta: float) -> void:
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			flash.color.a = 0.0
	if game == null:
		return
	var P := game.player
	var a := "%.1f" % (maxf(0.0, P.hp / P.max_hp * 100.0))
	var b := "%.1f" % minf(100.0, P.xp / P.xp_to_next * 100.0)
	if a != _hud_cache[0]:
		_hud_cache[0] = a
		hp_bar.size.x = 248.0 * float(a) / 100.0
	if b != _hud_cache[1]:
		_hud_cache[1] = b
		xp_bar.size.x = 248.0 * float(b) / 100.0
	if P.level != _hud_cache[2]:
		_hud_cache[2] = P.level
		lvl_lbl.text = "LVL %d" % P.level
	if P.kills != _hud_cache[3]:
		_hud_cache[3] = P.kills
		kill_lbl.text = "KILLS %d" % P.kills
	var play := game.in_play()
	var ro := (game.has_unlock("roll") or game.has_unlock("parry")) and play
	st_box.visible = ro and hud.visible
	if ro:
		var k := P.st / game.st_max_eff()
		st_bar.size.x = 248.0 * clampf(k, 0.0, 1.0)
		st_bar.color = Color("#ff9a3d") if k < 0.35 else Color("#9fe8ff")
	hud.visible = game.started and game.active and title_scr.visible == false
	pause_btn.visible = game.active and not title_scr.visible
	hud.modulate.a = 0.0 if game.cine.on else 1.0
	var touch := Settings.is_touch and play and not game.cine.on
	touch_btns.visible = touch
	roll_btn.visible = game.has_unlock("roll")
	parry_btn.visible = game.has_unlock("parry")
	touch_btns.scale = Vector2.ONE * float(Settings.s.bsz)
	touch_btns.modulate.a = float(Settings.s.bop)
	joy_base.visible = game.joy.active and play
	if joy_base.visible:
		joy_base.position = game.joy.start - Vector2(50, 50)
		var v: Vector2 = game.joy.v
		joy_stick.position = Vector2(25, 25) + v * 50.0
	if pause_scr.visible:
		pause_np.text = Music.now_playing()


# ======================================================================
# tela inicial
# ======================================================================
func _build_title() -> void:
	title_scr = _screen(Color(0, 0.95, 1, 0.1))
	var v := _center_box(title_scr, 460.0)
	var h := _center_label(v, "DOOM VALLEY", 56, PRIMARY, Assets.font_ui_black)
	h.add_theme_constant_override("outline_size", 0)
	h.add_theme_color_override("font_shadow_color", Color(0, 0.95, 1, 0.5))
	h.add_theme_constant_override("shadow_outline_size", 12)
	_center_label(v, "N.E.X.U.S.\nNeural Extension for X-scale Upgrade Software", 12, Color(1, 1, 1, 0.6), Assets.font_ui)
	v.add_child(_spacer(12))
	v.add_child(_btn("JOGAR", func(): start_game()))
	cont_btn = _btn("CONTINUAR PARTIDA", func(): _continue())
	v.add_child(cont_btn)
	v.add_child(_btn("OPÇÕES", func(): open_options(true)))
	rec_lbl = _center_label(v, "", 12, Color(1, 0.8, 0, 0.85), Assets.font_mono_bold)
	var hint := "Arraste do lado esquerdo para mover. Os tiros são automáticos. Derrote inimigos com cada poder para liberar a evolução dele." if Settings.is_touch else "WASD move · Espaço rola · F apara · P/Esc pausa · Enter começa. Derrote inimigos com cada poder para liberar a evolução dele."
	_center_label(v, hint, 12, Color(1, 1, 1, 0.55), Assets.font_ui)


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func refresh_title() -> void:
	var r := SaveSystem.records()
	var t := ""
	if r.runs > 0 or r.wins > 0:
		t = "RECORDE: %d kills, %d pts, %s" % [r.kills, r.score, Game.fmt_time(r.time)]
		if r.wins > 0:
			t += " | VITÓRIAS: %d" % r.wins
		if r.fenda > 0:
			t += " | FENDA: %d" % r.fenda
	rec_lbl.text = t
	var info := SaveSystem.save_info()
	cont_btn.visible = info != ""
	cont_btn.text = "CONTINUAR PARTIDA\nsalva em " + info if info != "" else "CONTINUAR PARTIDA"


func show_title() -> void:
	refresh_title()
	title_scr.visible = true
	over_scr.visible = false
	win_scr.visible = false
	pause_scr.visible = false
	lvl_modal.visible = false
	Music.context = "title"


func start_game() -> void:
	title_scr.visible = false
	over_scr.visible = false
	win_scr.visible = false
	game.start_classic()


func _continue() -> void:
	title_scr.visible = false
	var m := game.load_game()
	game.set_paused_menu(false)
	toast(m, GOLD)


func _unhandled_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("confirm") and title_scr.visible and not opt_panel.visible:
		start_game()
		get_viewport().set_input_as_handled()
	elif ev.is_action_pressed("pause") and opt_panel.visible:
		open_options(false)
		get_viewport().set_input_as_handled()


# ======================================================================
# EVOLUÇÃO (level up)
# ======================================================================
func _build_levelup() -> void:
	lvl_modal = Control.new()
	lvl_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	lvl_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(lvl_modal)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	lvl_modal.add_child(cc)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(Color(0.02, 0.02, 0.04, 0.95), PRIMARY, 20, 2, 30))
	cc.add_child(p)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(300, 0)
	v.add_theme_constant_override("separation", 15)
	p.add_child(v)
	_center_label(v, "EVOLUÇÃO", 22, Color.WHITE, Assets.font_ui_black)
	lvl_opts = VBoxContainer.new()
	lvl_opts.add_theme_constant_override("separation", 12)
	v.add_child(lvl_opts)
	lvl_info = _label("", 11, Color(1, 1, 1, 0.75))
	lvl_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lvl_info.custom_minimum_size = Vector2(300, 0)
	v.add_child(lvl_info)
	lvl_modal.visible = false


func show_levelup(opts: Array, locked: String) -> void:
	for c in lvl_opts.get_children():
		c.queue_free()
	_picked = false
	for u in opts:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_ALL
		b.custom_minimum_size = Vector2(300, 64)
		b.add_theme_stylebox_override("normal", _sb(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.1), 12, 1, 15))
		b.add_theme_stylebox_override("hover", _sb(Color(0, 0.95, 1, 0.1), PRIMARY, 12, 1, 15))
		b.add_theme_stylebox_override("pressed", _sb(Color(0, 0.95, 1, 0.18), PRIMARY, 12, 1, 15))
		b.add_theme_stylebox_override("focus", _sb(Color(0, 0.95, 1, 0.1), PRIMARY, 12, 1, 15))
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 15
		v.offset_top = 10
		v.offset_right = -15
		var n := _label(u.n, 16, PRIMARY, Assets.font_ui_bold)
		var d := _label(u.d, 12, Color(1, 1, 1, 0.7))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(n)
		v.add_child(d)
		b.add_child(v)
		var uu: Dictionary = u
		b.pressed.connect(func():
			if _picked:
				return
			_picked = true
			lvl_modal.visible = false
			game.pick_upgrade(uu))
		lvl_opts.add_child(b)
	lvl_info.text = locked
	lvl_info.visible = locked != ""
	lvl_modal.visible = true
	if lvl_opts.get_child_count() > 0:
		(lvl_opts.get_child(0) as Control).call_deferred("grab_focus")


# ======================================================================
# pausa
# ======================================================================
func _build_pause() -> void:
	pause_scr = Control.new()
	pause_scr.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_scr.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.03, 0.84)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_scr.add_child(dim)
	root.add_child(pause_scr)
	var v := _center_box(pause_scr, 420.0)
	_center_label(v, "PAUSADO", 22, PRIMARY, Assets.font_ui_black)
	var g1 := HFlowContainer.new()
	g1.alignment = FlowContainer.ALIGNMENT_CENTER
	g1.add_theme_constant_override("h_separation", 6)
	g1.add_theme_constant_override("v_separation", 6)
	v.add_child(g1)
	g1.add_child(_btn("CONTINUAR", func(): game.toggle_pause(), true))
	g1.add_child(_btn("SALVAR", func(): _save(), true))
	g1.add_child(_btn("CARREGAR", func(): _load(), true))
	g1.add_child(_btn("OPÇÕES", func(): open_options(true), true))
	restart_btn = _btn("REINICIAR", func(): _restart(), true)
	g1.add_child(restart_btn)
	g1.add_child(_btn("TELA INICIAL", func(): _to_title(), true))
	pause_msg = _center_label(v, "", 12, Color(1, 0.8, 0), Assets.font_mono_bold)
	pause_list = _label("", 12, Color(1, 1, 1, 0.85))
	pause_list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(pause_list)
	pause_np = _center_label(v, "", 12, Color(1, 1, 1, 0.7), Assets.font_ui)
	pause_scr.visible = false


func _on_pause(on: bool) -> void:
	pause_scr.visible = on
	if on:
		_confirm = false
		restart_btn.text = "REINICIAR"
		var info := SaveSystem.save_info()
		pause_msg.text = ("Último salvamento: " + info) if info != "" else "Nenhuma partida salva"
		pause_list.text = _powers_text()


func _powers_text() -> String:
	var L: Array[String] = []
	for x in Powers.PUK:
		var s: Dictionary = game.powers.PU[x[0]]
		if s.lv <= 0:
			continue
		var st: String = "Habilidade maximizada" if s.lv >= 5 else ("Evolução liberada: escolha no próximo level up" if s.st == 2 else "Evolução bloqueada: derrote um inimigo com " + x[3])
		L.append("%s  Nv %d/5\n   %s" % [x[1], s.lv, st])
	return "\n".join(L) if not L.is_empty() else "Nenhuma habilidade especial obtida ainda."


func _save() -> void:
	var r := game.save_game()
	pause_msg.text = ("Partida salva: " + SaveSystem.save_info()) if r == "Partida salva." else r


func _load() -> void:
	pause_msg.text = game.load_game()
	pause_list.text = _powers_text()


func _restart() -> void:
	if _confirm:
		_confirm = false
		pause_scr.visible = false
		game.start_classic()
		return
	_confirm = true
	restart_btn.text = "CONFIRMAR?"
	get_tree().create_timer(2.5).timeout.connect(func():
		_confirm = false
		restart_btn.text = "REINICIAR")


func _to_title() -> void:
	pause_scr.visible = false
	game.active = false
	game.started = false
	game.paused = true
	game.paused_menu = false
	game.arena.reset()
	if game.fp_active:
		get_node("../AnomaliaFP").fp_exit()
	show_title()


# ======================================================================
# fim de jogo e vitória
# ======================================================================
func _build_over() -> void:
	over_scr = Control.new()
	over_scr.set_anchors_preset(Control.PRESET_FULL_RECT)
	over_scr.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(over_scr)
	var v := _center_box(over_scr, 560.0)
	var h := _center_label(v, "TERMINATED", 60, ENEMY, Assets.font_ui_black)
	h.add_theme_color_override("font_shadow_color", Color(1, 0, 0.33, 0.5))
	h.add_theme_constant_override("shadow_outline_size", 14)
	over_stats = _center_label(v, "", 17, Color(1, 1, 1, 0.8), Assets.font_ui)
	v.add_child(_btn("REBOOT SYSTEM", func(): start_game()))
	v.add_child(_ghost("TELA INICIAL", func(): _to_title()))
	over_scr.visible = false


func show_over(s: Dictionary) -> void:
	over_stats.text = "SYSTEM LEVEL: %d | DATA COLLECTED: %d KILLS | SCORE: %d | TEMPO: %s | RECORDE: %d KILLS" % [s.level, s.kills, s.score, Game.fmt_time(s.time), s.record]
	lvl_modal.visible = false
	pause_scr.visible = false
	over_scr.visible = true


func _build_win() -> void:
	win_scr = _screen(Color(1, 0.8, 0, 0.12))
	var v := _center_box(win_scr, 520.0)
	_center_label(v, "SISTEMA ESTABILIZADO", 44, GOLD, Assets.font_ui_black)
	_center_label(v, "O chefe final foi derrotado", 12, Color(1, 1, 1, 0.6), Assets.font_ui)
	win_stats = _center_label(v, "", 12, Color(1, 0.8, 0, 0.85), Assets.font_mono_bold)
	v.add_child(_btn("ENTRAR NA FENDA", func():
		win_scr.visible = false
		game.continue_after_victory()))
	# BUG CORRIGIDO: no HTML o handler deste botão ficou dentro de um comentário e ele não fazia nada
	v.add_child(_btn("JOGAR DE NOVO", func():
		win_scr.visible = false
		start_game()))
	win_scr.visible = false


func show_win(s: Dictionary) -> void:
	win_stats.text = "TEMPO %s | PONTOS %d\nABATES %d | NÍVEL %d | COMBO MÁX x%d" % [Game.fmt_time(s.time), s.score, s.kills, s.level, s.combo]
	win_scr.visible = true


# ======================================================================
# painel de opções (HUB NX)
# ======================================================================
func _build_options() -> void:
	opt_panel = Control.new()
	opt_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	opt_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	opt_panel.add_child(dim)
	root.add_child(opt_panel)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	opt_panel.add_child(cc)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(600, 500)
	cc.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var head := HBoxContainer.new()
	var t := _label("DOOM VALLEY", 14, PRIMARY, Assets.font_ui_bold)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(_ghost("✕", func(): open_options(false)))
	v.add_child(head)
	opt_tabs = HBoxContainer.new()
	opt_tabs.add_theme_constant_override("separation", 4)
	v.add_child(opt_tabs)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	opt_body = VBoxContainer.new()
	opt_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt_body.add_theme_constant_override("separation", 2)
	sc.add_child(opt_body)
	opt_panel.visible = false


var _opt_prev_pause := false


func open_options(v: bool) -> void:
	if v == opt_panel.visible:
		return
	opt_panel.visible = v
	if v:
		if game:
			_opt_prev_pause = game.paused
			game.paused = true
		_tab(opt_cur)
	else:
		Music.preview = ""
		if game:
			game.paused = _opt_prev_pause


func _tab(k: String) -> void:
	var dev: bool = Settings.s.dev
	var tabs := [["fx", "Efeitos"], ["mu", "Música"], ["ct", "Controles"], ["ab", "Sobre"]]
	if dev:
		tabs += [["dg", "Diagnóstico"], ["ch", "Chefes"], ["ar", "Arenas"]]
	if not dev and k in ["dg", "ch", "ar"]:
		k = "fx"
	opt_cur = k
	for c in opt_tabs.get_children():
		c.queue_free()
	for tb in tabs:
		var b := _ghost(tb[1], _tab.bind(tb[0]))
		if tb[0] == k:
			b.add_theme_stylebox_override("normal", _sb(Color(0, 0.95, 1, 0.12), Color(0, 0.95, 1, 0.53), 8, 1, 11))
			b.add_theme_color_override("font_color", PRIMARY)
		opt_tabs.add_child(b)
	for c in opt_body.get_children():
		c.queue_free()
	match k:
		"fx": _tab_fx()
		"mu": _tab_music()
		"ct": _tab_controls()
		"ab": _tab_about()
		"dg": _tab_diag()
		"ch": _tab_bosses()
		"ar": _tab_arenas()


func _row(title: String, sub: String, ctrl: Control) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_label(title, 13, Color("#d8e0ea")))
	if sub != "":
		var s := _label(sub, 11, Color(0.85, 0.88, 0.92, 0.6))
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(s)
	h.add_child(v)
	if ctrl:
		ctrl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ctrl)
	opt_body.add_child(h)
	var sep := HSeparator.new()
	sep.add_theme_color_override("separator", Color(1, 1, 1, 0.07))
	opt_body.add_child(sep)


func _switch(k: String) -> CheckButton:
	var c := CheckButton.new()
	c.button_pressed = Settings.s[k]
	c.toggled.connect(func(on: bool): Settings.set_value(k, on))
	return c


func _slider(k: String, a: float, b: float, step: float, cb: Callable = Callable()) -> HSlider:
	var s := HSlider.new()
	s.min_value = a
	s.max_value = b
	s.step = step
	s.value = float(Settings.s[k])
	s.custom_minimum_size = Vector2(170, 20)
	s.value_changed.connect(func(v: float):
		Settings.s[k] = int(v) if k in ["tl", "q"] else v
		Settings.persist()
		if cb.is_valid():
			cb.call(v))
	return s


func _tab_fx() -> void:
	var q := OptionButton.new()
	for n in ["Baixa", "Média", "Alta"]:
		q.add_item(n)
	q.selected = int(Settings.s.q)
	q.item_selected.connect(func(i: int): Settings.set_value("q", i))
	_row("Qualidade gráfica", "Não altera dano, alcance nem velocidade", q)
	_row("Intensidade", "%.1f×" % Settings.s.intensity, _slider("intensity", 0.3, 1.5, 0.1))
	_row("Rastro do jogador", "Comprimento", _slider("tl", 3, 14, 1))
	_row("Volume", "Efeitos sonoros", _slider("vol", 0, 1, 0.05))
	_row("Música", "Volume da trilha. As faixas ficam na aba Música", _slider("music", 0, 1, 0.05))
	for sw in [["bloom", "Brilho (bloom)", "Brilho neon em todo o jogo"], ["particles", "Partículas", "Partículas decorativas"],
			["shake", "Tremor de câmera", "Impactos balançam a tela"], ["distort", "Alerta de vida crítica", "Pulso e borda vermelha"],
			["trails", "Rastros", "Tiros e asas deixam rastro"], ["flash", "Flash de dano", "Flash vermelho ao levar dano"],
			["reduce", "Reduzir movimento", "Sem tremor, giros e pulsos"], ["sound", "Sons", "Efeitos sonoros do jogo"],
			["auto", "Qualidade automática", "Reduz sozinha se o FPS cair"], ["cb", "Alto contraste nos avisos", "Contorno branco em todas as áreas de perigo"],
			["cine", "Falas dos chefes", "Barras de cinema e fala antes de cada chefe"]]:
		_row(sw[1], sw[2], _switch(sw[0]))


func _tab_music() -> void:
	_row("Faixas reais", "Toca as músicas do jogo. Desligado: silêncio (a trilha sintetizada é uma fase seguinte)", _switch("mreal"))
	_row("Volume da música", "", _slider("music", 0, 1, 0.05))
	_row("Tocando agora", Music.now_playing(), null)
	opt_body.add_child(_label("FAIXAS", 11, Color(1, 1, 1, 0.6), Assets.font_mono_bold))
	for id in Music.order:
		var t: Dictionary = Music.tracks[id]
		var b := _ghost("■" if Music.preview == id else "▶", Callable())
		var iid: String = id
		b.pressed.connect(func():
			Music.preview = "" if Music.preview == iid else iid
			_tab("mu"))
		_row(t.title, Game.fmt_time(t.d) + (" · repete sem emenda" if t.lp else ""), b)
	opt_body.add_child(_label("QUANDO TOCAR", 11, Color(1, 1, 1, 0.6), Assets.font_mono_bold))
	for cx in Music.contexts():
		var ob := OptionButton.new()
		ob.custom_minimum_size = Vector2(220, 0)
		var ids: Array = ["-"] + Music.order
		var cur := Music.pick(cx[0])
		for i in ids.size():
			var id: String = ids[i]
			ob.add_item("(silêncio / ambiência)" if id == "-" else String(Music.tracks[id].title))
			if id == cur:
				ob.selected = i
		var c0: String = cx[0]
		ob.item_selected.connect(func(i: int): Music.set_choice(c0, ids[i]))
		_row(cx[1], "", ob)
	opt_body.add_child(_ghost("Restaurar trilha padrão", func():
		Settings.set_value("mmap", "")
		_tab("mu")))


func _tab_controls() -> void:
	var a := OptionButton.new()
	a.add_item("Automática")
	a.add_item("Manual")
	a.selected = 1 if Settings.s.aim == "man" else 0
	a.item_selected.connect(func(i: int): Settings.set_value("aim", "man" if i == 1 else "auto"))
	_row("Mira", "Manual: mouse no computador, segundo analógico (lado direito) no toque", a)
	_row("Sensibilidade (1ª pessoa)", "", _slider("sens", 0.4, 2.2, 0.1))
	_row("Vibração", "Celular vibra nos impactos", _switch("vibr"))
	_row("Tamanho dos botões de toque", "", _slider("bsz", 0.7, 1.5, 0.05))
	_row("Opacidade dos botões de toque", "", _slider("bop", 0.3, 1.0, 0.05))


func _tab_about() -> void:
	var r := SaveSystem.records()
	var l := _label("DOOM VALLEY · versão Godot (migração do HTML v6.0)\nConfigurações, saves e recordes ficam salvos neste aparelho.", 12, Color("#d8e0ea"))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	opt_body.add_child(l)
	_row("Recorde", "%d kills, %d pts, %s, nível %d, %d partidas, Fenda %d" % [r.kills, r.score, Game.fmt_time(r.time), r.level, r.runs, r.fenda], null)
	var cr := _label(CREDITS, 11, Color(0.85, 0.88, 0.92, 0.75))
	cr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	opt_body.add_child(cr)
	var dv := CheckButton.new()
	dv.button_pressed = Settings.s.dev
	dv.toggled.connect(func(on: bool):
		Settings.set_value("dev", on)
		_tab("ab"))
	_row("Modo desenvolvedor", "Mostra as abas Diagnóstico, Chefes e Arenas", dv)
	opt_body.add_child(_ghost("Restaurar padrões", func():
		Settings.restore_defaults()
		_tab("fx")))


const CREDITS := "Créditos\nMúsica: Action Pack 1, de Luis Zuno (Ansimuz): Cyberpunk Street, Long Preparation, Jump Run Duck, Mega Bot Bay, Mega Bot Pipes Forest, Cyber Runner, Bipedal Mech, Magic Fx 7, Boss Battle, Battle Encounter e Mega Bot Pipes Under. Licença do pacote: uso comercial e modificação permitidos. No jogo: volume nivelado, emendas de loop e duas versões invertidas.\nOutras faixas: crimson_circuits (gerada pelo criador no Google Gemini); runners after all, Fountain of ignorance e Rise Of The Hero (origem em verificação).\nSprites: Rhino, Vesperon, Illuminatti e peças do Templo do Olho e da Rotunda: material do criador. Robot Warfare (Matt Walkden, CC0), Hell Hound (Ansimuz, CC0) e Evolving Creatures (MEKAI Games) entram com as dimensões. Cenários desenhados pelo próprio jogo.\nSom: efeitos e ambiências sintetizados pelo jogo."


func _tab_diag() -> void:
	var l := _label("", 12, Color("#d8e0ea"))
	opt_body.add_child(l)
	var upd := func():
		if not is_instance_valid(l):
			return
		var g := game
		l.text = "FPS medido: %d\nPartículas (jogo e FX): %d\nProjéteis: %d\nInimigos: %d\nEfeitos ativos: %d\nPerigos: %d\nQualidade: %s" % [Engine.get_frames_per_second(), g.gp.n + g.fx.n, g.projectiles.size() + g.enemy_projectiles.size(), g.enemies.size(), g.fx.E.size(), g.hazards.list.size(), ["Baixa", "Média", "Alta"][int(Settings.s.q)]]
	upd.call()
	opt_body.add_child(_ghost("Ver hitboxes", func(): game.show_hitboxes = not game.show_hitboxes))
	var t := Timer.new()
	t.wait_time = 0.5
	t.autostart = true
	t.timeout.connect(upd)
	l.add_child(t)


func _tab_bosses() -> void:
	var l := _label("Teste dos chefes (modo desenvolvedor). Força e estranheza definem a ordem: pontuação = força + 1,5 × estranheza.", 11, Color(1, 1, 1, 0.6))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	opt_body.add_child(l)
	for i in BossEncounter.BD.size():
		var b: Dictionary = BossEncounter.BD[i]
		var fe: Array = BossEncounter.FE[b.id]
		var ii := i
		_row(b.n, "força %d · estranheza %d · pontuação %.1f" % [fe[0], fe[1], fe[0] + 1.5 * fe[1]], _ghost("Enfrentar", func():
			open_options(false)
			title_scr.visible = false
			pause_scr.visible = false
			game.dev_boss(ii)))


func _tab_arenas() -> void:
	for id in ArenaSystem.ARX.keys():
		var d: Dictionary = ArenaSystem.ARX[id]
		var z: Array = ArenaSystem.ASZ[d.tipo]
		var iid: String = id
		_row(d.n, "%s · tema %s" % [z[2], d.tema], _ghost("Entrar", func():
			open_options(false)
			title_scr.visible = false
			pause_scr.visible = false
			game.dev_arena(iid)))
