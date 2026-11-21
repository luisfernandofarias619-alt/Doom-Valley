# Doom-Valley

Doom Valley is a 2D action roguelike blending RPG progression, bullet hell combat, and dimensional exploration. Explore strange worlds, battle unique enemies and powerful bosses, uncover secrets, collect resources, and expand your Garden. The deeper you venture, the more reality begins to break.

## Versão Godot 4 (migração do HTML5)

Este repositório contém a migração do jogo HTML5/Canvas (`original/doom-valley.html`, preservado) para **Godot 4.4+** em GDScript.
O andamento e o que ainda falta estão em [`MIGRATION_STATUS.md`](MIGRATION_STATUS.md); a arquitetura em [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

**Estado atual:** o modo **Classic** está completo — campo aberto com 5 setores, hordas, elites, 11 poderes com evolução, e os
6 chefes em suas arenas (Rhino → Drácula → Vesperon → Illuminatti → Anomalia em 1ª pessoa → Espelho), vitória e Fenda Infinita.
Jardim, dimensões e itens (meta-jogo da v6) são as próximas fases.

### Abrir e jogar
1. Instale o Godot **4.4 ou mais novo** (build padrão, não .NET).
2. Abra a pasta do repositório pelo Project Manager (o `project.godot` fica na raiz) e pressione F5.

Controles: **WASD/setas** movem · **mouse** mira e atira (mira manual; mude para automática em Opções → Controles) ·
**Espaço/Shift** rola (depois do Rhino) · **F/botão direito** apara (depois do Drácula) · **P/Esc** pausa · **Enter** começa.
Na 1ª pessoa: clique trava o mouse, A/D andam de lado, setas giram. No toque: arraste à esquerda para mover; com mira manual, à direita para mirar.

### Testes
```bash
GODOT=/caminho/para/godot tests/run_tests.sh          # suíte funcional headless (102 verificações)
godot --path . -- --shots=boss:0                        # capturas de um cenário (title, classic, boss:0..5, fenda)
godot --path . -- --bench                               # teste de carga com tempos por camada
```

### Regerar os assets a partir do HTML
```bash
python3 tools/extract_assets.py original/doom-valley.html .     # sprites, atlas, ícones, faixas (requer ffmpeg)
python3 tools/extract_sfx.py original/doom-valley.html scripts/audio/sfx_defs.gd
```

### Export para Android
Use o template oficial de export Android do Godot 4.4 (renderer *GL Compatibility*, orientação paisagem já configurada).
Os dados do jogo são constantes GDScript e recursos importados, então não é preciso filtro extra de arquivos.
O export ainda **não foi testado em aparelho** (ver `MIGRATION_STATUS.md`).

### Licenças
Ver [`docs/CREDITS.md`](docs/CREDITS.md). Três faixas da trilha ainda têm origem em verificação pelo criador.
