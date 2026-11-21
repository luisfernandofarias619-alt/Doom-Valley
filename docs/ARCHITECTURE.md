# Arquitetura da versão Godot

## Visão geral

```
res://
├── project.godot                 # 1280×720, stretch canvas_items/expand, GL Compatibility, InputMap
├── original/doom-valley.html     # referência (ignorada pelo Godot via .gdignore)
├── tools/                        # extratores Python (assets e SFX) — .gdignore
├── assets/
│   ├── sprites/                  # atlas do Rhino e da Contenção, folhas WebP, ícones
│   ├── audio/music/              # 17 faixas Ogg Vorbis (convertidas do Opus embutido)
│   └── shaders/                  # vinheta, escuridão, paredes/chão da 1ª pessoa
├── scenes/core/main.tscn         # cena única: Game + AnomaliaFP + UI
├── scripts/
│   ├── autoload/                 # Events, Settings, Assets, SaveSystem
│   ├── audio/                    # Sfx (síntese), Music (diretor), sfx_defs (gerado)
│   ├── core/                     # Game (orquestrador), main, draw_layer
│   ├── player/  enemies/  combat/  fx/
│   ├── bosses/                   # framework + um script por chefe + Anomalia 3D
│   ├── world/                    # ArenaSystem, um tema por arena, Fenda, fundos de setor
│   ├── data/atlas_data.gd        # tabelas geradas (atlas, quadros, faixas)
│   ├── ui/ui.gd                  # toda a interface em Control/Containers/Theme
│   └── utilities/                # Draw (primitivas de canvas), PixelArt (Image), Lcg
└── tests/                        # suíte funcional, capturas, carga
```

## Por que entidades não são Nodes

O jogo tem até 150 inimigos, centenas de tiros e ~600 partículas, todos desenhados proceduralmente (o HTML não usa sprites para
eles). Um `Node`/`CharacterBody2D` por entidade multiplicaria o custo de árvore e física sem ganho: as colisões do original são
círculo × círculo e retângulo × círculo. Por isso:

- Entidades são objetos `RefCounted` leves (`Enemy`, `Projectile`) em arrays; partículas são arrays compactos (`PackedFloat32Array`).
- Colisão tiro × inimigo usa uma grade espacial reconstruída a cada quadro (mesma prioridade de acertos do laço original).
- O desenho acontece em poucas camadas (`Node2D` com `draw_layer.gd`), cada uma com o material certo:

| Camada | Conteúdo | Material/filtro |
|--------|----------|-----------------|
| `Background/BG` (CanvasLayer −1) | fundos animados dos setores (coordenadas de tela) | — |
| `World/FloorTex` | textura base da arena | shader da vinheta, *nearest* |
| `World/Floor` | portas, rachaduras, objetos, marcas do Rhino | *nearest* |
| `World/UnderAdd` | halos de brilho, lâmpadas, brasas, tiros dos chefes | ADD |
| `World/Ents` | pickups, tiros, inimigos, chefes vetoriais, Rhino, jogador | *nearest* |
| `World/Sprites` | folhas pintadas (Vesperon, Illuminatti, quadros de morte) | *linear* |
| `World/FxAdd` | partículas e efeitos do NEXUS FX, prisma, Julgamento | ADD |
| `World/FxTop` | perigos, números de dano, poderes, vapor, cinzas | — |
| `World/Dark` / `AfterDark` | escuridão da Lua de Sangue / olhos do Drácula | shader / ADD |
| `Overlay/Screen` (CanvasLayer 5) | HUD desenhado, banners, indicadores, transição, cinema | — |

A câmera é a transformação do nó `World` (posição, zoom e espelhamento do Espelho), calculada pelo `ArenaSystem` com a mesma lógica do HTML.

## Fluxo de um quadro

`Game._process` → (transição | hitstop | 1ª pessoa | `_update`)

`_update`: movimento → disparo → `_pre` (rolamento, aparar, ricochete, lentidão, paredes/obstáculos, vida dos tiros, teleguiado, painéis)
→ tiros × inimigos → inimigos (IA comum ou `BossEncounter.boss_ai`) → abates → tiros inimigos × jogador (aparo) → partículas
→ `_post` (poderes, FX, combo/hordas/coleta, setor, vitória, encontro + perigos, arena + câmera, cinemática) → spawn.

## Chefes

- `BossEncounter` guarda a tabela `BD`, inicia o encontro ao atingir `BOSS_AT[setor]` abates, leva o jogador à arena do chefe,
  cria o chefe, roda o motor comum (tempo, invulnerabilidade, fases por limiar, descida de entrada, contato) e trata a morte.
- Cada chefe estende `BossBase` e implementa `ai`, `on_phase`, `on_hit` (refletir/anular dano), `on_dead` e os desenhos por camada.
- Para criar um chefe novo: um script `boss_x.gd`, uma entrada em `BossEncounter.BD`, o comportamento em `behaviors`,
  a arena em `ArenaSystem.ARX` + `BOSS_ARENA` e a música em `Music.BMUS`.

## Arenas

`ArenaSystem` cuida de tamanho, paredes, câmera, transição, objetos (colisão, quebra, barris, vapor), rachaduras e indicadores.
Cada tema (`arena_contencao.gd`, `arena_catedral.gd`, …) implementa `build`, `obstacles`, `post` e os desenhos (`draw_floor_tex`,
`draw_floor`, `draw_floor_add`, `draw_objects`, `draw_after`). A Contenção é gerada em `Image` com o mesmo gerador pseudoaleatório
do HTML (`PixelArt.Lcg`), então a mesma semente produz o mesmo cenário.

## Áudio

- `Sfx`: as 52 receitas do HTML (frequência, forma de onda, duração, volume, atraso) são sintetizadas uma vez para `AudioStreamWAV`
  numa thread; a reprodução respeita tiers, *duck* e limite de vozes.
- `Music`: três *decks*, crossfade com os tempos do HTML, faixas por momento (configuráveis em Opções → Música), loop nativo a partir
  do ponto de entrada, *duck* na pausa, ambiência sintetizada do Vesperon.
- A Anomalia usa `AudioStreamPlayer3D` (zumbido e efeitos posicionais).

## Persistência

`Settings` (`user://settings.cfg`), recordes (`user://records.json`) e o salvamento do Classic (`user://classic_save.json` com soma
FNV-1a e cópia de segurança `.bak`, como os slots v2 do HTML).
