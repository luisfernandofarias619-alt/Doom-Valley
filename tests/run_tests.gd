extends Node
## Testes funcionais automatizados (headless). Rodam o jogo de verdade, quadro a quadro, e conferem regras,
## correções de bugs e o fluxo completo do Classic (6 chefes, Anomalia em 1ª pessoa, vitória e Fenda).
## Uso: godot --headless --path . --fixed-fps 60 -- --test
## Sai com código 0 se tudo passar, 1 se algum teste falhar.

var main
var game: Game
var fails := 0
var passes := 0
var log_lines: Array[String] = []


func _ready() -> void:
	main = get_parent()
	game = main.get_node("Game")
	Settings.s.cine = false
	Settings.s.sound = false
	call_deferred("_run")


func check(cond: bool, name: String, info: String = "") -> void:
	if cond:
		passes += 1
		_out("  PASS  " + name)
	else:
		fails += 1
		_out("  FAIL  " + name + ("  (" + info + ")" if info != "" else ""))


func _out(s: String) -> void:
	print(s)
	log_lines.append(s)


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Roda quadros até a condição valer (ou estourar o limite). Retorna se valeu.
func until(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


func god() -> void:
	game.player.max_hp = 1e7
	game.player.hp = 1e7
	game.player.regen = 1e5


func _run() -> void:
	_out("== DOOM VALLEY · testes funcionais ==")
	await _t_enemies()
	await _t_shield()
	await _t_upgrades()
	await _t_level_and_combo()
	await _t_synth_and_tracks()
	await _t_save_roundtrip()
	await _t_contencao()
	await _t_boss_flow()
	await _t_fenda()
	_out("== %d passaram, %d falharam ==" % [passes, fails])
	var f := FileAccess.open("user://test_report.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
	get_tree().quit(1 if fails > 0 else 0)


func _t_enemies() -> void:
	_out("[inimigos]")
	var t := Enemy.new(0, 0, "tank")
	check(t.hp == 180.0 and t.max_hp == 180.0, "tanque nasce com 180 de vida (bug do maxHp=40 corrigido)", "hp=%s max=%s" % [t.hp, t.max_hp])
	var f := Enemy.new(0, 0, "fast")
	check(f.hp == 20.0 and f.max_hp == 20.0 and f.speed == 170.0, "fast: 20 de vida, velocidade 170")
	var types := ["basic", "fast", "tank", "shooter", "splitter", "fragment", "guard", "gunner", "rifter", "leech"]
	var ok := true
	for tp in types:
		var e := Enemy.new(0, 0, tp)
		ok = ok and e.hp > 0.0 and e.radius > 0.0
	check(ok, "os 10 arquétipos do campo existem com atributos válidos")
	await frames(1)


func _t_shield() -> void:
	_out("[dano e escudo]")
	main.ui.start_game()
	await frames(2)
	var P := game.player
	P.hp = 100.0
	P.shield_max = 25.0
	P.shield = 10.0
	game.take_damage(20.0, "proj")
	check(P.shield == 0.0, "escudo não fica negativo", "shield=%s" % P.shield)
	check(absf(P.hp - 85.0) < 0.01, "excedente do escudo passa para a vida (20 de dano, 10 de escudo absorvem 5)", "hp=%s" % P.hp)
	P.iv = 0.0
	game.take_damage(10.0, "melee")
	check(P.iv > 0.0, "golpe corpo a corpo ≥ 4 dá invulnerabilidade curta")
	var hp0 := P.hp
	game.take_damage(10.0, "melee")
	check(P.hp == hp0, "durante a invulnerabilidade o corpo a corpo não fere")
	await frames(1)


func _t_upgrades() -> void:
	_out("[evoluções]")
	var pw := game.powers
	var opts := pw.offer()
	check(opts.size() == 3, "level up oferece 3 opções")
	var shock: Dictionary = {}
	for u in pw.upgrades:
		if u.n == "ELECTRO-SHOCK":
			shock = u
	pw.apply(shock)
	check(pw.PU.shock.lv == 1 and pw.PU.shock.st == 1, "poder obtido fica bloqueado até liberar")
	var offered := false
	for i in 30:
		for u in pw.offer():
			if u.n == "ELECTRO-SHOCK":
				offered = true
	check(not offered, "poder bloqueado não aparece no level up")
	var e := Enemy.new(game.player.x + 30.0, game.player.y, "basic")
	e.fatal = {"shock": true}
	pw.on_kill(e, [])
	check(pw.PU.shock.st == 2, "abate com o próprio poder libera a evolução")
	var evo := false
	for i in 40:
		for u in pw.offer():
			if u.n == "ELECTRO-SHOCK" and String(u.d).begins_with("EVOLUÇÃO Nv 2"):
				evo = true
	check(evo, "evolução liberada aparece como 'EVOLUÇÃO Nv 2'")
	await frames(1)


func _t_level_and_combo() -> void:
	_out("[nível, combo e pontuação]")
	game.paused = false
	var got := []
	var cb := func(o: Array, _l: String): got.append(o.size())
	game.level_up_requested.connect(cb)
	game.player.xp = game.player.xp_to_next
	var lv := game.player.level
	game.check_level_up()
	check(game.player.level == lv + 1 and game.paused and got.size() == 1, "XP cheio sobe de nível e pausa com o menu de evolução")
	game.level_up_requested.disconnect(cb)
	game.pick_upgrade(game.powers.offer()[0])
	check(not game.paused, "escolher a evolução despausa")
	var sc := game.score
	game.combo.n = 0
	Events.enemy_killed.emit({"x": 0.0, "y": 0.0, "color": Color.RED, "boss": false, "tough": false, "type": "basic", "elite": false})
	check(game.combo.n == 1 and game.score == sc + 11, "abate soma combo e pontos (10 × (1 + 1/20))", "score=%d" % (game.score - sc))
	await frames(1)


func _t_synth_and_tracks() -> void:
	_out("[áudio]")
	var w := Sfx.synth_notes([[440.0, "square", 0.1, 0.1, 0.0]])
	var nz := false
	for i in range(0, w.data.size(), 2):
		if w.data.decode_s16(i) != 0:
			nz = true
			break
	check(w.data.size() > 4000 and nz, "SFX sintetizado gera áudio não silencioso")
	check(SfxDefs.DEFS.size() == 52, "52 efeitos da tabela do HTML")
	var ok := true
	var loops := true
	for id in Music.order:
		var s = Music.stream_for(id)
		ok = ok and s != null
		if Music.tracks[id].lp:
			loops = loops and s.loop and absf(s.loop_offset - 1.0) < 0.001
	check(Music.order.size() == 17 and ok, "17 faixas carregam (Opus convertido para Vorbis)")
	check(loops, "faixas com loop repetem a partir do ponto de entrada (1 s)")
	check(Music.default_for("b0") == "bipedal" and Music.default_for("b5") == "bossrev" and Music.default_for("s3") == "runners", "trilha padrão por momento igual à do HTML")
	await frames(1)


func _t_save_roundtrip() -> void:
	_out("[salvar e carregar]")
	game.score = 1234
	game.sec = 2
	game.pk = 7
	game.flags = {"roll": true}
	var r := game.save_game()
	check(r == "Partida salva.", "salvar no campo aberto", r)
	game.save_game()   # o segundo salvamento guarda o anterior como cópia de segurança
	var rd := SaveSystem.read_save()
	check(rd.st == "ok" and int(rd.d.sc) == 1234, "leitura confere a soma de verificação")
	var f := FileAccess.open(SaveSystem.SAVE_PATH, FileAccess.READ)
	var txt := f.get_as_text()
	f = null
	var bad := FileAccess.open(SaveSystem.SAVE_PATH, FileAccess.WRITE)
	bad.store_string(txt.replace("1234", "9999"))
	bad = null
	var rd2 := SaveSystem.read_save()
	check(rd2.st == "ok" and rd2.get("rec", 0) == 1, "arquivo adulterado é recusado e a cópia de segurança assume")
	var w := FileAccess.open(SaveSystem.SAVE_PATH, FileAccess.WRITE)
	w.store_string(txt)
	w = null
	game.score = 0
	game.sec = 0
	game.load_game()
	check(game.score == 1234 and game.sec == 2 and game.pk == 7 and game.has_unlock("roll"), "carregar restaura pontos, setor, abates e desbloqueios")
	game.set_paused_menu(false)
	await frames(1)


func _t_contencao() -> void:
	_out("[arena da Contenção]")
	game.arena.enter_now("contencao", false)
	await frames(2)
	var A = game.arena.cur
	check(A != null and A.has("tex") and A.aw == 720 and A.ah == 880, "piso e paredes montados em pixel art (720×880, 2 px por pixel)")
	var n := {}
	for o in A.obj:
		n[o.k] = int(n.get(o.k, 0)) + 1
	check(n.get("pilar", 0) == 4 and n.get("caixa", 0) == 9 and n.get("barril", 0) == 3 and n.get("vapor", 0) == 4, "obstáculos: 4 pilares, 9 caixas, 3 barris, 4 vapores", str(n))
	var barrel: Dictionary
	for o in A.obj:
		if o.k == "barril":
			barrel = o
	game.arena.obj_break(barrel)
	await frames(30)
	check(barrel.get("dead", false), "barril quebrado explode depois do pavio")
	game.arena.exit_now()
	await frames(1)


func _auto_pick(o: Array, _l: String) -> void:
	# o menu de EVOLUÇÃO pausa o jogo (como no HTML); nos testes a primeira opção é escolhida
	main.ui.lvl_modal.visible = false
	game.pick_upgrade.call_deferred(o[0])


func _t_boss_flow() -> void:
	_out("[fluxo do Classic: 6 chefes]")
	main.ui.start_game()
	await frames(2)
	god()
	if not game.level_up_requested.is_connected(_auto_pick):
		game.level_up_requested.connect(_auto_pick)
	var won_sig := []
	var vcb := func(_s: Dictionary): won_sig.append(true)
	game.victory_reached.connect(vcb)
	for i in 6:
		var id: String = BossEncounter.BD[i].id
		game.sec = i
		game.pk = Game.BOSS_AT[i]
		god()
		var started := await until(func(): return game.enc.st == "active" or (game.enc.st == "fp" and game.fp_active), 900)
		check(started, "chefe %d (%s) começa ao atingir %d abates no setor" % [i + 1, id, Game.BOSS_AT[i]], "st=" + game.enc.st)
		if id == "anomalia":
			var fp = main.get_node("AnomaliaFP")
			check(fp.on and fp.boss != null, "Anomalia abre a câmara em primeira pessoa (3D)")
			check(fp.walls[3].multimesh.instance_count == 64 and fp.walls[2].multimesh.instance_count == 4, "câmara 17×17 com 4 pilares de carne")
			await frames(120)
			fp.boss.hp = 0.0
		else:
			var aid: String = ArenaSystem.BOSS_ARENA[id]
			await until(func(): return game.arena.cur != null, 120)
			check(game.arena.cur != null and game.arena.cur.id == aid, "%s luta na arena própria (%s)" % [id, aid])
			check(game.enc.boss != null and game.enc.boss.bd.id == id, "chefe certo em campo: " + id)
			await frames(240)   # deixa a IA atacar por 4 s
			god()
			check(game.enc.boss != null and game.enc.boss.ai != null, "%s: IA rodou 4 s sem erro" % id)
			game.enc.boss.hp = game.enc.boss.max_hp * 0.4
			await frames(180)
			check(game.enc.boss == null or game.enc.boss.ph >= 1, "%s entra na fase 2 abaixo do limiar" % id)
			if game.enc.boss:
				game.enc.boss.hp = 0.0
		if i < 5:
			var next := await until(func(): return game.enc.st == "none" and game.sec == i + 1 and not game.arena.on() and not game.fp_active, 900)
			check(next, "depois de %s: volta ao campo e avança para o setor %d" % [id, i + 2], "st=%s sec=%d arena=%s" % [game.enc.st, game.sec, game.arena.on()])
			if id == "rhino":
				check(game.has_unlock("roll"), "Rhino derrotado libera o rolamento")
			if id == "dracula":
				check(game.has_unlock("parry"), "Drácula derrotado libera o aparar")
		else:
			var win := await until(func(): return won_sig.size() > 0, 600)
			check(win, "Espelho (chefe final) derrotado mostra a vitória")
	game.victory_reached.disconnect(vcb)
	await frames(1)


func _t_fenda() -> void:
	_out("[Fenda Infinita]")
	main.ui.win_scr.visible = false
	game.continue_after_victory()
	var inside := await until(func(): return game.arena.is_fenda(), 120)
	check(inside, "ENTRAR NA FENDA leva à arena infinita")
	god()
	var fe: Fenda = game.arena.fenda
	fe.nt = 0.0
	var det := await until(func(): return not fe.anc.is_empty(), 60)
	check(det, "uma âncora é detectada")
	if not det:
		return
	fe.anc.need = 1.0
	game.player.x = fe.anc.x
	game.player.y = fe.anc.y
	var dep := await until(func(): return fe.dep >= 1, 240)
	check(dep, "sincronizar a âncora aumenta a profundidade")
	check(SaveSystem.records().fenda >= 1, "recorde da Fenda é salvo")
