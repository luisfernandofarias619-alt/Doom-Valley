extends Node
## Teste de carga: 150 inimigos, muitos tiros e partículas. Mede tempo de processo e de quadro.
## Uso: godot --path . -- --bench
var game: Game
var t := 0
var acc_proc := 0.0
var acc_frame := 0.0
var n := 0
var last := 0

var upd_us := 0

func _ready() -> void:
	game = get_parent().get_node("Game")
	load("res://scripts/core/draw_layer.gd").profiling = true
	get_parent().ui.start_game()
	Settings.s.aim = "auto"

func _process(_dt: float) -> void:
	t += 1
	if t == 5:
		game.player.max_hp = 1e9
		game.player.hp = 1e9
		game.player.regen = 1e6
		game.player.projectiles = 8
		game.player.attack_speed = 60.0
		game.powers._turret()
		game.powers.nx.prism = 1
		game.player.prism_active = true
		game.powers.nx.shock = 3
		game.powers.nx.bh = 3
		game.powers.nx.wings = 2
		game.ht = 1e9
	if t > 5 and t < 700:
		while game.enemies.size() < 150:
			var tp: String = ["basic", "fast", "tank", "shooter", "gunner", "guard", "splitter", "rifter", "leech"][randi() % 9]
			var a := randf() * TAU
			var e := Enemy.new(game.player.x + cos(a) * 420.0, game.player.y + sin(a) * 300.0, tp)
			e.hp = 1e5
			e.max_hp = 1e5
			game.enemies.append(e)
	if t > 120 and t < 700:
		var now := Time.get_ticks_usec()
		if last > 0:
			acc_frame += (now - last) / 1000.0
		last = now
		acc_proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		n += 1
	if t == 700:
		print("BENCH enemies=%d proj=%d fx_particles=%d game_particles=%d hazards=%d" % [game.enemies.size(), game.projectiles.size() + game.enemy_projectiles.size(), game.fx.n, game.gp.n, game.hazards.list.size()])
		var prof: Dictionary = load("res://scripts/core/draw_layer.gd").profile
		for k in prof.keys():
			print("BENCH layer %-10s %.2f ms/quadro" % [k, prof[k] / 1000.0 / t])
		print("BENCH avg process=%.2f ms  avg frame=%.2f ms (%.0f fps)  draw_calls=%d" % [acc_proc / n, acc_frame / n, 1000.0 / (acc_frame / n), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
		get_tree().quit()
