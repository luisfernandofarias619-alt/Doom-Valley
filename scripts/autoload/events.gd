extends Node
## Barramento de eventos do jogo (substitui o NF.on/NF.emit e o NeonEngine.Events do HTML).
## Os nomes seguem os eventos originais para facilitar a comparação com o código de referência.

signal player_damaged(amount: float)            # 'player:damaged'
signal shield_absorbed(amount: float)           # 'shield:absorbed'
signal player_critical_health(active: bool)     # 'player:critical-health'
signal enemy_killed(info: Dictionary)           # 'enemy:killed' {x,y,color,boss,tough,type,elite}
signal projectile_ricochet(x: float, y: float, color: Color)
signal skill_activated(id: String, x: float, y: float)
signal turret_expired(x: float, y: float)
signal upgrade_applied(name: String)
signal luck_double(x: float, y: float)
signal power_acquired(key: String, name: String, lv: int)
signal power_unlocked(key: String, name: String, lv: int)
signal boss_start(index: int)
signal boss_defeated(index: int, name: String)
signal boss_parried(kind: String)
signal player_parried(kind: String)
signal player_parry_miss()
signal player_roll(x: float, y: float)
signal arena_enter(id: String)
signal arena_exit(id: String)
signal arena_boom(x: float, y: float)
signal fenda_anchor(depth: int)
signal fp_boss()
signal scene_changed(scene: String)
signal hud_message(text: String, color: Color)
signal notify(text: String, color: Color)
signal settings_changed()
signal game_over()
signal victory()
