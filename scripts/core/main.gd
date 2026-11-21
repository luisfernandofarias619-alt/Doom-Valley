extends Node
## Raiz da cena: liga o jogo à interface e à Anomalia em 1ª pessoa.

@onready var game: Game = $Game
@onready var ui = $UI
@onready var fp = $AnomaliaFP


func _ready() -> void:
	ui.bind(game)
	fp.bind(game)
	ui.show_title()
	# testes automatizados (tests/run_tests.gd) podem iniciar a partida direto pela linha de comando
	if "--autostart" in OS.get_cmdline_user_args():
		ui.start_game()
	if "--test" in OS.get_cmdline_user_args():
		var tr = load("res://tests/run_tests.gd").new()
		tr.name = "Tests"
		add_child(tr)
	if "--trace" in OS.get_cmdline_user_args():
		var tr = load("res://tests/debug_trace.gd").new()
		add_child(tr)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			var r = load("res://tests/shot_runner.gd").new()
			r.name = "ShotRunner"
			add_child(r)
