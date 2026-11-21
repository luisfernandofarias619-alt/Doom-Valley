extends Node
## Rastreio de depuração: imprime posição do jogador e estado a cada 0,1 s depois de iniciar um chefe.
var game: Game
var t := 0.0
var last := Vector2.ZERO
var started := false

func _ready() -> void:
	game = get_parent().get_node("Game")

func _process(dt: float) -> void:
	t += dt
	if not started and t > 0.5:
		started = true
		get_parent().ui.start_game()
		game.dev_boss(0)
	if not started:
		return
	var p := Vector2(game.player.x, game.player.y)
	if p.distance_to(last) > 2.0:
		print("t=%.2f player=%s enc=%s trs=%s cine=%s paused=%s hs=%.2f rl=%s" % [t, p, game.enc.st, game.arena.trs.on, game.cine.on, game.paused, game.hs, game.rl.on])
		last = p
	if t > 6.0:
		get_tree().quit()
