#!/usr/bin/env python3
"""Extrai os assets embutidos no HTML original do Doom Valley para o projeto Godot.

Uso: python3 tools/extract_assets.py original/doom-valley.html .

- Imagens <script type="application/x-mind-img" data-id=...> (WebP)  -> assets/sprites/sheets/<id>.webp
- const RHA / const ARA (PNG data URI)                               -> assets/sprites/rhino_atlas.png / arena_atlas.png
- const ATL (recortes das folhas), RF/GYR (Rhino), ARJ (Contenção)    -> scripts/data/atlas_data.gd (constantes GDScript)
- const ICONS (PNG data URI por item)                                 -> assets/sprites/icons/<id>.png
- <script type="application/x-nexus-audio"> (Ogg/Opus)               -> assets/audio/music/<id>.ogg (Ogg Vorbis, via ffmpeg)
  O Godot 4 não decodifica Opus; as faixas são convertidas para Vorbis (q=1, ~80 kbps; origem Opus 32 kbps) preservando duração.
  Os metadados (title, dur, loop, lead, len) vão para scripts/data/atlas_data.gd (TRACKS).
As tabelas viram constantes GDScript (e não .json) porque arquivos que não são recursos ficam fora do
export (Android) a menos que um filtro seja configurado à mão.
"""
import base64, json, os, re, subprocess, sys, tempfile

src, out = sys.argv[1], sys.argv[2]
html = open(src, encoding='utf-8').read()

def w(path, data):
    p = os.path.join(out, path)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, 'wb') as f:
        f.write(data)
    return p

# imagens WebP
for m in re.finditer(r'<script type="application/x-mind-img" data-id="([^"]+)">([^<]+)</script>', html):
    w(f'assets/sprites/sheets/{m.group(1)}.webp', base64.b64decode(m.group(2).strip()))
    print('img', m.group(1))

# atlas PNG
for name, fn in (('RHA', 'rhino_atlas.png'), ('ARA', 'arena_atlas.png')):
    m = re.search(r"const %s='data:image/png;base64,([^']+)'" % name, html)
    w(f'assets/sprites/{fn}', base64.b64decode(m.group(1)))
    print('png', fn)

# RF (quadros do Rhino) e ARJ (recortes do atlas da arena)
m = re.search(r"RF=(\{.*?\}),GYR=(\d+);", html)
RF, GYR = json.loads(m.group(1)), int(m.group(2))
m = re.search(r"ARJ=(\{.*?\}),ARI=", html)
ARJ = json.loads(m.group(1))
print('rhino/arena frames')

# ATL
m = re.search(r'const ATL=(\{.*?\});\s*$', html, re.M)
atl = json.loads(m.group(1))
print('atlas', list(atl.keys()))

# ICONS
m = re.search(r'const ICONS=(\{.*?\});', html)
icons = json.loads(m.group(1))
for k, v in icons.items():
    w(f'assets/sprites/icons/{k}.png', base64.b64decode(v.split(',', 1)[1]))
print('icons', len(icons))

# áudio
tracks = {}
tmpd = tempfile.mkdtemp()
for m in re.finditer(r'<script type="application/x-nexus-audio"([^>]*)>([^<]+)</script>', html):
    attrs = dict(re.findall(r'data-(\w+)="([^"]*)"', m.group(1)))
    tid = attrs.pop('id')
    raw = os.path.join(tmpd, tid + '.opus')
    open(raw, 'wb').write(base64.b64decode(m.group(2).strip()))
    dst = os.path.join(out, f'assets/audio/music/{tid}.ogg')
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    cut = []
    if attrs.get('loop') == '1':
        # o arquivo traz 0,5 s de cauda depois do ponto de emenda; o Godot repete do fim do arquivo,
        # então a faixa é cortada exatamente em entrada + comprimento do loop (emenda sem salto)
        cut = ['-t', '%.6f' % (float(attrs.get('lead', 0)) + float(attrs.get('len', attrs.get('dur', 0))))]
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', raw] + cut + ['-c:a', 'libvorbis', '-q:a', '1', dst], check=True)
    tracks[tid] = attrs
    print('audio', tid, attrs.get('title'))
def gd(v):
    return json.dumps(v, ensure_ascii=False)
src_gd = ["class_name AtlasData", "## Gerado por tools/extract_assets.py a partir do HTML original (não editar à mão).",
          "## Cada quadro: [x, y, largura, altura, âncora x, âncora y]; recortes da Contenção: [x, y, largura, altura].",
          "const ATL := " + gd(atl), "const RF := " + gd(RF), "const GYR := %d" % GYR, "const ARJ := " + gd(ARJ),
          "const TRACKS := " + gd(tracks)]
w('scripts/data/atlas_data.gd', ("\n".join(src_gd) + "\n").encode())
print('atlas_data.gd')
