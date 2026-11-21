# DOOM VALLEY — Status da migração HTML5 → Godot 4

Fonte de referência: `original/doom-valley.html` (v6.0, 10,7 MB, ~540 KB de JS + assets embutidos). Arquivo preservado sem alterações.
Motor alvo: **Godot 4.4.1** (GDScript). Testado com o binário oficial `4.4.1.stable.official.49a5bc7b6` em modo headless.

Legenda: `[ ]` pendente · `[~]` em desenvolvimento · `[!]` problema encontrado · `[x]` concluído e testado

---

## 1. Auditoria — inventário dos sistemas do HTML

O HTML é um único arquivo com 9 blocos `<script>`. O núcleo (`JOGO BASE`) é o jogo original de ondas; tudo
depois dele é o **NEXUS FX** (linhas 139–3598), que se pendura no núcleo por *hooks* (`hook('nome')`) e por
*monkey-patching* encadeado (`const _p=NF.post;NF.post=function(){_p();...}` — mais de 40 camadas).

| # | Sistema | Linhas (HTML) | Responsabilidade | Dependências | Estratégia Godot |
|---|---------|---------------|------------------|--------------|------------------|
| 1 | NeonEngine / ModAPI / ModLoader | 29–39 | registro de mods, eventos, console `/` com `prompt()` | DOM, `eval` | **Não migrado de propósito**: executa código arbitrário (eval). Substituído por arquitetura modular + sinais (`Events`). Documentado. |
| 2 | Jogo base (loop, jogador, Enemy, Projectile, Particle, Pickup, HUD DOM) | 40–115 | movimento, tiro automático, 10 tipos de inimigo, coleta, level-up | Canvas, DOM | `scripts/core/*`, `scripts/enemies/*` (dados + desenho procedural em `_draw`) |
| 3 | Coleta de itens / nerf da torreta | 116–120 | pickups hp/xp/shield | ModAPI | `pickup_system.gd` |
| 4 | NeonCore 2.0 | 129–137 | paleta, raridade, `notify()` | DOM | toasts no HUD (`hud.gd`) |
| 5 | NEXUS FX: camadas, partículas, efeitos (arc, ripple, burst, blackhole), bloom por `shadowBlur` | 156–192 | todo o “juice” visual | Canvas | `fx_layer.gd` (pool de partículas em arrays + efeitos registrados), bloom via `WorldEnvironment` glow |
| 6 | Evoluções (11 poderes: shock, black hole, nano-shield, wings, prism, turret, ricochete, sorte, crítico, magneto, vampirismo) + desbloqueio por abate | 193–260, 383–437 | upgrades e evolução Nv 1–5 | eventos | `powers.gd` |
| 7 | HUB NX (opções, música, arenas, mods, editor, diagnóstico, sobre) | 293–370, 1350–1355, 1498–1506, 2963–2967 | painel de opções e ferramentas de dev | DOM | `options_panel.gd` (Efeitos, Música, Sobre, Diagnóstico, Chefes/Arenas em modo dev). Mods/Editor (eval) não migrados. |
| 8 | v3.2: combo, números de dano, hordas, estrelas, pausa | 371–415 | pontuação, feedback | — | `game.gd`, `overlay.gd` |
| 9 | Overdrive: setores visuais (5 fundos animados), silhuetas por classe | 416–467 | ambientes do campo | — | `sector_background.gd`, `enemy_system.gd::draw` |
| 10 | v3.4: tela inicial, vitória, SFX hierárquico, arquétipos | 468–499 | fluxo e áudio | WebAudio | `title_screen.gd`, `audio/sfx.gd` (síntese pré-renderizada em `AudioStreamWAV`) |
| 11 | v3.5: salvar/carregar, config, elites | 500–528 | save v1 | localStorage | `save_system.gd` (`user://`) |
| 12 | v3.6: encontros de chefe, perigos (HZ), padrões, chefes vetoriais | 529–694 | framework de chefes | — | `hazard_system.gd`, `boss_encounter.gd`, `boss_base.gd` |
| 13 | v3.8: trilha sintetizada (sequenciador WebAudio) | 695–732 | música fallback | WebAudio | [ ] fase seguinte (faixas reais cobrem todos os momentos) |
| 14 | v4.2: Rhino (máquina de estados, 10 golpes, 2 fases, sprites) | 733–962 | chefe 1 | atlas PNG | `bosses/boss_rhino.gd` |
| 15 | v5.0: câmera, mundo ≠ tela, arenas, Contenção (pixel art procedural), objetos, Fenda Infinita | 964–1356 | arenas | Canvas offscreen | `world/arena_*.gd`, `world/camera_rig.gd`, `world/fenda.gd` |
| 16 | v4.4: diretor de faixas reais (3 decks, crossfade, loop sem emenda) | 1357–1496 | música | `<audio>`, AudioBuffer | `audio/music.gd` (2 `AudioStreamPlayer` + crossfade; loop via `loop_offset`) |
| 17 | v6.0 atlas (vesp/ilu/rot/tmp/mob) | 1508–1517 | sprites | WebP base64 | `assets/sprites/sheets/*.webp` + `resources/atlas/atlas.json` |
| 18 | v6.0 núcleo: cenas, modos (11), itens (40+), slots v2 com checksum, inventário, mochila, rolamento, aparar, mira manual, consumíveis | 1520–1891 | meta-jogo | localStorage | rolamento/aparar/mira/dano por tipo **nesta fase**; slots/itens/modos [ ] fase B |
| 19 | v6.0 interface (painéis, slots, modos, pausa, morte, recompensas, botões de toque) | 1893–2045 | UI | DOM | pausa, botões de toque **nesta fase**; slots/modos [ ] fase B |
| 20 | Jardim (plantas, mutações, missões, oficina, visitantes, clima, invasões) | 2047–2525 | base do jogador | Canvas | [ ] fase B |
| 21 | Dimensões (Dungeon, Mundo, salas espelhadas, selos, minimapa) | 2526–2813 | expedições | Canvas | [ ] fase C |
| 22 | Chefes v6: Drácula (Catedral), Espelho (Galeria), Vesperon (Rotunda), Illuminatti (Templo), recompensas | 2814–3176 | chefes 2–6 | atlas | `bosses/*` + `world/arena_*` |
| 23 | Anomalia em 1ª pessoa (raycasting por pixel em Canvas) | 3178–3370 | chefe 5 + dimensão | ImageData | reconstruída em **3D nativo** (`scenes/bosses/anomalia_fp.tscn`) |
| 24 | Entrada cinematográfica dos chefes (falas, barras) + quadros de morte | 3373–3431 | narrativa | — | `boss_cinematic.gd` |
| 25 | Inimigos dos pacotes (vespa, vespão, escaravelho, aranha, cão, gosma) | 3433–3511 | fauna das dimensões | atlas `mob` | [ ] fase C (só aparecem nas dimensões) |
| 26 | Trilha por momento + ambiências sintetizadas | 3512–3584 | áudio | WebAudio | mapeamento de momentos + ambiência `cinza` **nesta fase** |
| 27 | Créditos de terceiros | 3585–3597 | licenças | — | `options_panel.gd` aba Sobre + `docs/CREDITS.md` |

### Assets embutidos (extraídos por `tools/extract_assets.py`)
- 5 folhas WebP (`vesp`, `ilu`, `rot`, `tmp`, `mob`) + tabela de recortes `ATL` → `assets/sprites/sheets/`, `resources/atlas/atlas.json`
- Atlas do Rhino (PNG 1500×645) + quadros `RF` (`GYR=40`) → `assets/sprites/rhino_atlas.png`, `resources/atlas/rhino_frames.json`
- Atlas da Contenção (PNG 520×116) + recortes `ARJ` → `assets/sprites/arena_atlas.png`, `resources/atlas/arena_atlas.json`
- 6 ícones PNG de itens → `assets/sprites/icons/`
- 17 faixas Ogg/**Opus** → convertidas para Ogg **Vorbis** (o Godot 4 não decodifica Opus) → `assets/audio/music/`, metadados em `resources/audio/tracks.json`
- Licenças: ver `docs/CREDITS.md`. Três faixas têm origem **pendente de verificação** pelo criador (registrado no próprio HTML).

### Bugs encontrados no HTML (corrigidos na versão Godot)
| Bug | Onde | Causa raiz | Correção |
|-----|------|-----------|----------|
| Botão **JOGAR DE NOVO** da vitória não faz nada | l. 490 | `wr.onclick=...` ficou dentro do comentário `// v5.0 ...` na mesma linha | botão ligado a `restart_classic()` |
| Anel dourado do **elite** desenhado no lugar errado | l. 465 | `arc(this.x,this.y,…)` depois de `translate(this.x,this.y)` (deslocamento dobrado) | anel desenhado na origem local |
| Escudo fica **negativo** e o excesso de dano some | l. 77 | `shield -= amt*2` sem clamp | escudo limitado a 0; excedente vai para a vida |
| Velas da Catedral não tremulam fora do Jardim | l. 2870 | usa `GL.t` (relógio do Jardim) | usa o relógio da arena |
| `NF.contact` redefinido 2× com assinaturas diferentes | l. 1309 e 1696 | camadas de patch | uma só função `contact(dps, src)` |
| Hitstop/transição/1ª pessoa competem pelo mesmo hook `hitstop` | l. 427, 1056, 3368 | encadeamento de patches | máquina de estados explícita no `game.gd` |
| Mods executam `eval` de URL/arquivo | l. 340–357 | — | removido (risco de segurança; sem equivalente seguro) |

---

## 2. Plano de fases

- **Fase A (esta entrega)**: projeto Godot, núcleo do modo **Classic** completo (campo, 5 setores, hordas, elites, 11 poderes com evolução, combo/pontuação), os **6 chefes** em suas arenas na ordem Rhino → Drácula → Vesperon → Illuminatti → Anomalia (1ª pessoa) → Espelho, cinemática, rolamento/aparar, mira manual/automática, toque, FX, SFX sintetizados, trilha real com diretor, opções, salvar/carregar, recordes, vitória e Fenda Infinita.
- **Fase B**: slots v2, modos de dificuldade, itens/inventário/equipamento/consumíveis, Jardim completo.
- **Fase C**: Dimensões (Dungeon, Mundo, especiais), inimigos dos pacotes, dimensão da Anomalia (labirinto), selos/No Boss, minimapa.
- **Fase D**: trilha sintetizada (fallback), ambiência da Anomalia, polimento Android (export, testes em aparelho).

---

## 3. Status por sistema (atualizado durante o trabalho)

(ver seções abaixo — preenchidas conforme cada sistema é integrado e testado)
