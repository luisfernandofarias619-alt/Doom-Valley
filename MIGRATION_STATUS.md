# DOOM VALLEY — Status da migração HTML5 → Godot 4

Fonte de referência: `original/doom-valley.html` (v6.0, 10,7 MB: ~540 KB de JavaScript + assets embutidos). Preservado sem alterações.
Motor: **Godot 4.4.1** (GDScript, renderer *GL Compatibility* para Android/desktop). Validado com o binário oficial `4.4.1.stable.official.49a5bc7b6`.

Legenda: `[ ]` pendente · `[~]` em desenvolvimento · `[!]` problema encontrado · `[x]` concluído e testado

> **Resumo honesto:** o **modo Classic** do HTML está migrado por completo e testado (campo aberto, 5 setores, hordas, elites,
> 11 poderes com evolução, os **6 chefes** com IA própria em suas arenas — a Anomalia em primeira pessoa —, cinemáticas,
> vitória e Fenda Infinita). O **meta-jogo da v6** (slots com modos, itens/equipamento, Jardim, Dimensões e a fauna dos pacotes)
> ainda **não** foi migrado: está planejado nas fases B e C abaixo. A migração não está completa.

---

## 1. Auditoria — inventário dos sistemas do HTML

O HTML tem 9 blocos `<script>`. O núcleo (`JOGO BASE`) é o jogo de ondas original; tudo depois dele (linhas 139–3598) é o
**NEXUS FX**, pendurado no núcleo por *hooks* (`hook('nome')`) e por *monkey-patching* encadeado (`const _p=NF.post;NF.post=function(){_p();…}`,
mais de 40 camadas). Na versão Godot essa cadeia virou chamadas explícitas, em ordem, a sistemas separados.

| # | Sistema (HTML) | Linhas | Responsabilidade | Estratégia Godot | Estado |
|---|----------------|--------|------------------|------------------|--------|
| 1 | NeonEngine / ModAPI / ModLoader / console `/` | 29–39 | mods, eventos, `prompt()` | Sinais em `Events` (autoload). Mods com `eval` **não migrados** (risco de segurança, sem equivalente seguro) | [x] substituído |
| 2 | Jogo base: loop, jogador, `Enemy`, `Projectile`, `Particle`, `Pickup`, HUD DOM | 40–115 | movimento, tiro, 10 inimigos, coleta, level up | `scripts/core/game.gd`, `player/player_state.gd`, `enemies/*`, `combat/projectile.gd` | [x] |
| 3 | Coleta de itens / ajuste da Sentinela | 116–120 | pickups hp/xp/escudo | `game.gd::_fupd` | [x] |
| 4 | NeonCore 2.0 | 129–137 | paleta, raridade, `notify()` | toasts em `ui.gd` | [x] |
| 5 | NEXUS FX: camadas, partículas, efeitos (raio, ondulação, explosão, buraco negro), bloom por `shadowBlur` | 156–192 | todo o *juice* | `fx/fx_layer.gd` (arrays compactos, sem um Node por partícula); bloom por halos aditivos | [x] |
| 6 | Evoluções (11 poderes) + liberação por abate | 193–260, 383–437 | upgrades Nv 1–5 | `combat/powers.gd` | [x] |
| 7 | HUB NX (opções, música, arenas, mods, editor, diagnóstico, sobre) | 293–370, 1350–1355, 1498–1506, 2963–2967 | painel de opções/dev | `ui.gd`: Efeitos, Música, Controles, Sobre, Diagnóstico, Chefes, Arenas | [x] (sem Mods/Editor) |
| 8 | v3.2: combo, números de dano, hordas, estrelas, pausa | 371–415 | pontuação e feedback | `game.gd` + camada de tela | [x] |
| 9 | Overdrive: 5 setores visuais, silhuetas por classe | 416–467 | ambientes do campo | `world/sector_background.gd`, `enemies/enemy_logic.gd` | [x] |
| 10 | v3.4: tela inicial, vitória, SFX hierárquico | 468–499 | fluxo e áudio | `ui.gd`, `audio/sfx.gd` | [x] |
| 11 | v3.5: salvar/carregar, config central, elites | 500–528 | save v1 | `autoload/save_system.gd` (+ checksum e backup) | [x] |
| 12 | v3.6: encontros, perigos (HZ), chefes vetoriais antigos | 529–694 | framework de chefes | `combat/hazards.gd`, `bosses/boss_encounter.gd`, `boss_base.gd` | [x] |
| 13 | v3.8: trilha sintetizada (sequenciador Web Audio) | 695–732 | música *fallback* | — | [ ] Fase D |
| 14 | v4.2: Rhino | 733–962 | chefe 1 | `bosses/boss_rhino.gd` | [x] |
| 15 | v5.0: câmera, mundo ≠ tela, arenas, Contenção, objetos, Fenda | 964–1356 | arenas | `world/arena_system.gd`, `arena_contencao.gd`, `fenda.gd` | [x] |
| 16 | v4.4: diretor de faixas reais (3 decks, crossfade, loop sem emenda) | 1357–1496 | música | `audio/music.gd` | [x] |
| 17 | v6.0 atlas (folhas `vesp`, `ilu`, `rot`, `tmp`, `mob`) | 1508–1517 | sprites | `assets/sprites/sheets/*.webp` + `scripts/data/atlas_data.gd` | [x] |
| 18 | v6.0 núcleo: cenas, **11 modos**, **40+ itens**, slots v2, inventário, mochila, rolamento, aparar, mira manual, consumíveis | 1520–1891 | meta-jogo | rolamento, aparar, mira e dano por tipo **migrados**; slots/modos/itens não | [~] |
| 19 | v6.0 interface (painéis, slots, modos, morte, recompensas, botões de toque) | 1893–2045 | UI do meta-jogo | pausa, morte, toque **migrados**; slots/modos/recompensas não | [~] |
| 20 | Jardim (plantas, mutações, missões, oficina, visitantes, clima, invasões) | 2047–2525 | base do jogador | — | [ ] Fase B |
| 21 | Dimensões (Dungeon, Mundo, salas espelhadas, selos, minimapa) | 2526–2813 | expedições | — | [ ] Fase C |
| 22 | Chefes v6: Drácula, Espelho, Vesperon, Illuminatti + arenas + recompensas | 2814–3176 | chefes 2, 3, 4, 6 | `bosses/*`, `world/arena_*` (recompensas de itens: Fase B) | [x] |
| 23 | Anomalia em 1ª pessoa (raycasting por pixel em Canvas) | 3178–3370 | chefe 5 + dimensão | **câmara do chefe** reconstruída em 3D nativo; o labirinto da dimensão é Fase C | [~] |
| 24 | Entrada cinematográfica (falas, barras) + quadros de morte | 3373–3431 | narrativa | `bosses/boss_cinematic.gd` + `on_dead` de cada chefe | [x] |
| 25 | Inimigos dos pacotes (vespa, vespão, escaravelho, aranha, cão, gosma) | 3433–3511 | fauna das dimensões | sprites extraídos (`mob.webp`); lógica: Fase C | [ ] |
| 26 | Trilha por momento + ambiências sintetizadas | 3512–3584 | áudio por contexto | momentos do Classic + ambiência `cinza`; ambiência `fp` (labirinto) é Fase C | [~] |
| 27 | Créditos de terceiros | 3585–3597 | licenças | Opções → Sobre + `docs/CREDITS.md` | [x] |

### Assets (extraídos por `tools/extract_assets.py`, reprodutível)
- [x] 5 folhas WebP (2048 px) + tabela de recortes `ATL` → `assets/sprites/sheets/`, `scripts/data/atlas_data.gd`
- [x] Atlas do Rhino (PNG 1500×645) + quadros `RF`, `GYR=40`
- [x] Atlas da Contenção (PNG 520×116) + recortes `ARJ`
- [x] 6 ícones de itens (para a Fase B)
- [x] 17 faixas Ogg/**Opus** → Ogg **Vorbis** (o Godot 4 não decodifica Opus); faixas com loop cortadas no ponto exato da emenda
- [x] 52 efeitos sonoros: tabelas extraídas por `tools/extract_sfx.py` → `scripts/audio/sfx_defs.gd`
- Licenças: `docs/CREDITS.md`. **Três faixas** têm origem ainda **pendente de verificação** pelo criador (já registrado no HTML).

---

## 2. Status por sistema (Fase A — modo Classic)

### Jogo
- [x] Loop e ordem de atualização idênticos ao HTML (`pre` → tiros → inimigos → tiros inimigos → `post` → spawn)
- [x] Jogador: movimento (WASD/setas), limites, regeneração, invulnerabilidade curta e piscar
- [x] Disparo automático (alvo mais próximo em 500 px) e manual (mouse; segundo analógico no toque)
- [x] 10 arquétipos do campo com IA e silhueta própria (basic, fast, tank, shooter, splitter→fragment, guard, gunner, rifter, leech)
- [x] Elites (×2,5 de vida, anel dourado), drops, magneto
- [x] 17 opções de level up; 11 poderes com evolução Nv 1–5 liberada por abate com o próprio poder
- [x] Electro-shock, buraco negro, torreta, asas, nano-escudo, prisma, ricochete (paredes e obstáculos), sorte, crítico, vampirismo
- [x] Combo, pontuação, números de dano, hordas a cada 50 s, setores com banner, 5 fundos animados com transição circular
- [x] Hitstop, tremor, flash de dano, vinheta de vida crítica, vibração (Android)
- [x] Rolamento (liberado pelo Rhino) e aparar (liberado pelo Drácula) com estamina; tiros dourados aparáveis voltam ×3
- [x] Perigos sempre avisados (círculo, anel, faixa que segue a fonte, leque) + modo alto contraste

### Arenas e câmera
- [x] Câmera com antecipação, enquadramento do chefe, "olhar" na entrada, zoom por tamanho de tela, margem de segurança
- [x] Transição entre campo e arenas; indicadores de chefe/âncora/tiros fora da tela
- [x] **Contenção**: piso e paredes montados em pixel art a partir do atlas (mesma semente e ordem de sorteios do HTML), porta que abre, lâmpadas pulsando, alarme na fúria, vinheta com dither ordenado em shader
- [x] Objetos: pilares (caem após 2 batidas), caixas (drop), barris (pavio e explosão em cadeia), vapor (queima o chefe também), entulho do desabamento
- [x] Rachaduras em pixel art com brilho de calor e danos carimbados nas paredes
- [x] **Catedral Carmesim** (bancos, pilares, caixões, velas, rosácea, escuridão da Lua de Sangue em shader)
- [x] **Rotunda dos Manuscritos** (ladrilhos e estantes da folha `rot`, colunas/estátuas quebráveis, cinzas e páginas, brasas da fase 2)
- [x] **Templo do Olho** (mármore, emblema, olho na parede, pirâmides de ouro, braseiros, urnas, olhos do piso, espinhos)
- [x] **Galeria dos Reflexos** (painéis que devolvem tiros, mundo espelhado)
- [x] Arenas de energia antigas (Núcleo, Vórtex, Abismo, Câmara dos Espelhos) no modo desenvolvedor
- [x] **Fenda Infinita**: pedaços gerados sob demanda (5 biomas, costuras, monólitos), âncoras, profundidade, recorde

### Chefes (ordem: Rhino → Drácula → Vesperon → Illuminatti → Anomalia → Espelho)
- [x] **Rhino**: entrada pela porta, rastreio com aceleração, 10 golpes com escolha ponderada (distância, espaço, histórico, recarga, vida), investidas com mira travada/derrapagem/finta, atordoamento na parede com estrelas, contrajogo (dano ×1,3/×1,55), Berserker com atlas tingido e runas pulsando, surto ≤20%, desabamento do teto, quadros de morte
- [x] **Drácula**: lanças aparáveis, névoa com corte pelas costas, morcegos, **Laço de Sangue** (quebre a linha de visão ou role), atordoamento, forma de morcego, Lua de Sangue (escuridão, velas apagam, olhos visíveis), caixões soltam morcegos
- [x] **Vesperon**: estamina própria, rolamento que lê os tiros, guarda que devolve brasas, combo de foice aparável (cambaleia), exaustão (dano ×2), páginas, runas, Passo Espectral (fumaça), máscara racha, Tempestade de Cinderfall com zonas seguras, Verso Final (exposto pelas costas), estamina máxima do Nick encurtada, ambiência sintetizada na fase 1
- [x] **Illuminatti**: Olhar com atraso, pirâmides que param e se dividem, enxame de olhos, raios em triângulo, investida com rastro, teletransporte para as pirâmides, Julgamento, quebra de fase, enigma dos olhos do piso (atordoa), espinhos, pose de alerta na fala, quadros de morte
- [x] **Anomalia (1ª pessoa)**: câmara 17×17 em 3D (paredes espelhadas, pilares de carne que respiram), Tesseract vetorial projetado na tela com sombra só no verdadeiro, cópias, Dobra (imagem invertida), Apagar (paredes somem), Anel com falha, orbes (o último aparável), Fenda (investida marcada no chão), zumbido posicional 3D, mira automática em cone, travamento do mouse ao clicar
- [x] **Espelho**: ecos que repetem os seus últimos 3 s (posição e tiros), reflexos (espelhado e atrasado) que estilhaçam, falsa abertura que devolve tiros, cópia do padrão da sua arma, inversão do mundo com contagem (imagem e controles), chefe final do Classic
- [x] Cinemática de entrada com fala (primeiro encontro vs. revanche), pular por toque/tecla, câmera no chefe
- [x] Barra do chefe embaixo com marcas de fase e estamina (Vesperon)
- [x] Vitória → "ENTRAR NA FENDA" ou "JOGAR DE NOVO"
- [ ] Recompensas de itens dos chefes (troféus/recursos): dependem dos itens (Fase B). No Classic do HTML também não havia itens.

### Interface, áudio e persistência
- [x] Tela inicial, EVOLUÇÃO, pausa (continuar, salvar, carregar, opções, reiniciar com confirmação, tela inicial), TERMINATED, vitória, toasts
- [x] Opções: Efeitos (qualidade, intensidade, rastro, volumes, 11 interruptores), Música, Controles, Sobre (recordes, créditos, modo dev), Diagnóstico, Chefes e Arenas (dev)
- [~] Controles de toque (joystick dinâmico, segundo analógico de mira, ROLAR/APARAR/II): lógica testada com eventos de toque injetados no viewport; **falta teste em aparelho** (ergonomia, multitoque real)
- [x] 52 SFX sintetizados offline em thread (mesmas ondas, envelopes e atrasos), com tiers, *duck* e limite de vozes do HTML
- [x] Trilha real com diretor por momento (título, setores, cada chefe, fase 1 do Vesperon, Fenda, vitória, fim), crossfade com os tempos do HTML, memória da posição, *duck* na pausa, escolha da faixa por momento, prévia
- [x] Ambiência `cinza` (Vesperon): ruído filtrado + bordão + estalos, loop sem emenda
- [ ] Trilha sintetizada (*fallback* quando "Faixas reais" está desligado): Fase D. Hoje, desligado = silêncio
- [ ] Prévia de efeitos no painel (canvas de demonstração do HUB)
- [x] Configurações em `user://settings.cfg`; recordes; salvamento Classic com soma FNV-1a + cópia de segurança

---

## 3. Bugs encontrados no HTML (corrigidos na versão Godot)

| # | Bug | Onde (HTML) | Causa raiz | Correção | Verificação |
|---|-----|-------------|-----------|----------|-------------|
| 1 | Botão **JOGAR DE NOVO** da vitória não fazia nada | l. 490 | `wr.onclick=…` ficou dentro do comentário `// v5.0 …` na mesma linha | botão reinicia a partida | teste automatizado |
| 2 | Anel dourado do **elite** desenhado no lugar errado | l. 465 | `arc(this.x,this.y,…)` depois de `translate(this.x,this.y)` | anel na origem local | captura |
| 3 | **Escudo** ficava negativo e o excedente de dano sumia | l. 77 | `shield -= amt*2` sem limite | escudo ≥ 0; excedente vai para a vida | teste automatizado |
| 4 | **Tanque/fast/shooter** nasciam com 40 de vida na v6 | l. 47 + l. 1699 | o construtor mudava só `hp` (maxHp ficava 40) e `NF.mkEnemy` recalculava `hp` a partir de `maxHp` | `hp = maxHp` sempre (tanque volta a 180) — **muda o balanceamento para o pretendido** | teste automatizado |
| 5 | Golpes de foice/névoa **sem som** | l. 2886, 3046 | `sfx('rhswipe')` nunca foi definido | alias para `rhswing` | — |
| 6 | Velas da Catedral não tremulavam | l. 2870 | usavam o relógio do Jardim (`GL.t`) | relógio da arena | código (efeito animado) |
| 7 | "O mundo se inverte" no Classic só invertia os controles | l. 2793 | o espelho da tela exigia a cena `dim`/`arena` | imagem espelhada + controles, também no Classic | captura |
| 8 | `NF.contact` redefinido 2× com assinaturas diferentes | l. 1309 e 1696 | camadas de *patch* | uma função `contact(dps, src)` | testes |
| 9 | Hitstop, transição e 1ª pessoa disputavam o mesmo *hook* | l. 427, 1056, 3368 | encadeamento de *patches* | máquina de estados explícita em `game.gd` | testes |
| 10 | Mods executavam `eval` de arquivo/URL | l. 340–357 | — | removido (segurança) | — |

### Problemas encontrados e resolvidos durante a migração (lado Godot)
- [x] Faixas com loop tinham 0,5 s de cauda depois do ponto de emenda → salto audível no loop nativo: corte exato na extração.
- [x] Tabelas `.json` em `res://` ficam **fora do export** sem filtro manual → viraram constantes GDScript.
- [x] *Crash* ao sair com tarefas de thread ainda rodando (tingimento do Rhino, pré-síntese) → IDs guardados e aguardados.
- [x] Ciclos de `RefCounted` (arenas ↔ temas, sinais de comportamentos) vazando na saída → quebrados em `_exit_tree`.
- [x] Paredes da Anomalia pretas: em `MultiMesh`, o `MODEL_MATRIX` do shader não traz a transformação da instância → posição de mundo reconstruída por `INV_VIEW_MATRIX`.
- [!] Aviso de vazamento de 1 reprodução Ogg ao fechar com o driver de áudio *dummy* (ambiente sem placa de som). Artefato do encerramento do motor; sem efeito em jogo.

---

## 4. Adaptações de recursos do navegador

| HTML / navegador | Godot |
|------------------|-------|
| `requestAnimationFrame` + `dt` limitado a 0,1 s | `_process(delta)` com o mesmo limite |
| Canvas 2D (`fillRect`, `arc`, gradientes, `setLineDash`) | `CanvasItem._draw` + `scripts/utilities/draw.gd` (arcos tracejados, leques com gradiente por vértice, discos por textura) |
| `shadowBlur` (bloom) | halos radiais aditivos (sem pós-processamento, barato no Android) |
| `globalCompositeOperation='lighter'` | camadas com `CanvasItemMaterial` em modo ADD |
| Canvas fora da tela + `getImageData` | `Image`/`ImageTexture`; vinheta por pixel e escuridão → shaders |
| Raycasting por pixel (Anomalia) | cena 3D nativa em `SubViewport` de baixa resolução ampliada sem filtro |
| Web Audio (osciladores, filtros, convolução) | síntese offline para `AudioStreamWAV` em thread; filtros biquad próprios |
| `<audio>` + Opus | `AudioStreamOggVorbis` com `loop_offset` |
| `localStorage` | `user://settings.cfg`, `records.json`, `classic_save.json` (+ `.bak`) |
| `pointerLock` | `Input.MOUSE_MODE_CAPTURED` |
| `navigator.vibrate` | `Input.vibrate_handheld` |
| `visibilitychange` | `NOTIFICATION_APPLICATION_FOCUS_OUT/PAUSED` → pausa |
| DOM (HUD, menus, painel NX) | `Control`/`Container`/`Theme`/`StyleBoxFlat` |

---

## 5. Testes executados (reais)

Ambiente: Linux, Godot 4.4.1 oficial; headless para lógica; Xvfb + Mesa llvmpipe (OpenGL 4.5, **renderização por CPU**) para capturas.

| Teste | Como | Resultado |
|-------|------|-----------|
| Importação e compilação de todos os scripts/shaders | `godot --headless --import` | **0 erros** |
| Suíte funcional (`tests/run_tests.sh`) | headless, `--fixed-fps 60`, jogo real quadro a quadro | **77/77 passam, 0 SCRIPT ERROR** |
| — inimigos, dano/escudo, evoluções, nível/combo | unidades dentro do jogo | ok |
| — toque: analógico de movimento, mira manual com segundo dedo, soltar | eventos `InputEventScreenTouch/Drag` injetados | ok |
| — áudio: síntese, 52 SFX, 17 faixas, loops, trilha por momento | | ok |
| — salvar/carregar com checksum; arquivo adulterado cai para o backup | | ok |
| — Contenção: arte 720×880, 20 obstáculos, barril explode | | ok |
| — **fluxo completo do Classic**: 6 chefes começam no limiar de abates, arena certa, IA roda 4 s, fase 2, morte, volta ao campo, próximo setor, rolamento/aparar liberados, Anomalia em 3D, vitória | | ok |
| — vitória: tela, JOGAR DE NOVO reinicia e zera desbloqueios; Fenda: entrar, âncora, sincronizar, profundidade, recorde | | ok |
| Capturas de tela (`tests/shot_runner.gd`) | Xvfb, cenários `title`, `classic`, `boss:0..5`, `fpdbg` | conferidas visualmente; sem erros |
| Carga (`tests/bench.gd`): 150 inimigos, ~170 tiros, prisma, shock, buracos negros, torreta | Xvfb/llvmpipe | lógica **4,1 ms/quadro**; geração de desenho **~7 ms/quadro**; 952 draw calls; quadro total 40 ms **com rasterização por CPU** |
| Saída do jogo (`--quit-after`) | 30, 400, 1500 quadros | sem *crash* |

Não testado (não havia como neste ambiente): **export e execução em aparelho Android**, toque real, desempenho em GPU de celular.

### Otimizações feitas com base nas medições
- Grade espacial para tiros × inimigos (24 mil testes/quadro → poucas centenas; mesma prioridade de acertos do HTML).
- Círculos pequenos por textura de disco (lote, sem gerar polígono); polígonos unitários em cache escalados por transformação.
- Resultado: camada de entidades 9,5 → 4,5 ms; draw calls 1880 → 952 (mesma cena de carga).

---

## 6. Próximas fases

- **Fase B — meta-jogo**: slots v2 (3 slots, checksum, backup, exportar/importar), 11 modos de dificuldade, itens/inventário/mochila,
  equipamento (armas com perfil de tiro, armaduras, relíquias), consumíveis, recompensas dos chefes, Jardim completo
  (plantas e mutações, mural de missões, oficina, visitantes, clima e dia/noite, invasões).
- **Fase C — dimensões**: Dungeon (árvore de salas, portas de energia, sala secreta), Mundo aberto (selos, veios, acampamentos),
  salas espelhadas, labirinto da Anomalia (Eco, Rastejante, Sombra, portais, fragmentos), os 6 inimigos dos pacotes, selos/No Boss, minimapa.
- **Fase D — acabamento**: trilha sintetizada (*fallback*), ambiência da Anomalia explorada, prévia de efeitos no painel,
  export Android (preset, ícones, teste em aparelho e perfil de GPU), fonte embutida para visual idêntico em todos os aparelhos.
