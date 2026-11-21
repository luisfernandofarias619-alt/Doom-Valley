extends Node
## Executor de testes visuais/funcionais: roda roteiros (cenários) e salva capturas em user://shots.
## Uso: godot --path . -- --shots=<cenario> [--out=<dir>]
## Cenários: title, classic, boss:<i>, arena:<id>, fenda, all

var main
var game: Game
var out_dir := "user://shots"
var steps: Array = []
var t := 0.0
var idx := 0
var errors: Array[String] = []


func _ready() -> void:
	main = get_parent()
	game = main.get_node("Game")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	Settings.s.aim = "auto"   # os roteiros não seguram o mouse
	var sc := "title"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			sc = a.substr(8)
	_build(sc)


func _build(sc: String) -> void:
	match sc:
		"title":
			steps = [[1.0, "shot", "title"], [0.2, "quit"]]
		"classic":
			steps = [[0.5, "start"], [3.0, "shot", "classic_3s"], [0.1, "levelup"], [0.6, "shot", "levelup"], [0.1, "pick"],
				[0.1, "god"], [0.1, "spawn_mix"], [4.0, "shot", "classic_mix"], [0.1, "pause"], [0.4, "shot", "pause"], [0.1, "unpause"],
				[0.1, "options"], [0.4, "shot", "options"], [0.1, "close_options"], [0.2, "quit"]]
		"fenda":
			steps = [[0.5, "start"], [0.1, "god"], [0.1, "arena", "fenda"], [3.0, "shot", "fenda"], [0.2, "quit"]]
		_:
			if sc.begins_with("boss:"):
				var i := int(sc.substr(5))
				steps = [[0.5, "start"], [0.1, "god"], [0.1, "boss", i], [1.5, "shot", "boss%d_enter" % i], [3.0, "shot", "boss%d_cine" % i],
					[0.1, "skipcine"], [0.1, "skipcine"], [0.1, "skipcine"], [4.0, "shot", "boss%d_fight" % i], [6.0, "shot", "boss%d_fight2" % i],
					[0.1, "phase2", i], [4.0, "shot", "boss%d_phase2" % i], [6.0, "shot", "boss%d_phase2b" % i], [0.1, "kill_boss"], [4.0, "shot", "boss%d_dead" % i], [0.2, "quit"]]
			elif sc.begins_with("arena:"):
				steps = [[0.5, "start"], [0.1, "god"], [0.1, "arena", sc.substr(6)], [2.0, "shot", "arena_" + sc.substr(6)], [0.2, "quit"]]


func _process(delta: float) -> void:
	if idx >= steps.size():
		return
	t += delta
	var s: Array = steps[idx]
	if t < s[0]:
		return
	t = 0.0
	idx += 1
	match s[1]:
		"start":
			main.ui.start_game()
		"god":
			game.player.max_hp = 1e7
			game.player.hp = 1e7
			game.player.regen = 1e5
		"levelup":
			game.player.xp = game.player.xp_to_next
			game.check_level_up()
		"pick":
			var opts: Array = game.powers.offer()
			if not opts.is_empty():
				main.ui.lvl_modal.visible = false
				game.pick_upgrade(opts[0])
		"spawn_mix":
			for tp in ["basic", "fast", "tank", "shooter", "splitter", "guard", "gunner", "rifter", "leech", "fragment"]:
				var e := Enemy.new(game.player.x + randf_range(-300, 300), game.player.y + randf_range(-200, 200), tp)
				game.enemies.append(e)
			game.enemies[0].elite = true
		"pause":
			game.toggle_pause()
		"unpause":
			game.toggle_pause()
		"options":
			main.ui.open_options(true)
		"close_options":
			main.ui.open_options(false)
		"boss":
			game.dev_boss(s[2])
		"arena":
			game.dev_arena(s[2])
		"skipcine":
			game.cine.skip()
		"phase2":
			var b: Enemy = game.enc.boss
			if b:
				b.hp = b.max_hp * 0.45
		"kill_boss":
			var b: Enemy = game.enc.boss
			if b:
				b.hp = 0.0
		"shot":
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			var p: String = out_dir + "/" + s[2] + ".png"
			img.save_png(p)
			print("SHOT ", p, " fps=", Engine.get_frames_per_second(), " enemies=", game.enemies.size(), " proj=", game.projectiles.size() + game.enemy_projectiles.size(), " st=", game.enc.st)
		"quit":
			get_tree().quit()
