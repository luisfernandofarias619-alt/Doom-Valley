#!/usr/bin/env python3
"""Gera scripts/audio/sfx_defs.gd a partir das tabelas SFX do HTML original.
Uso: python3 tools/extract_sfx.py original/doom-valley.html scripts/audio/sfx_defs.gd"""
import re, sys
src = open(sys.argv[1], encoding='utf-8').read()
blocks = [re.search(r"const SFX=\{(.*?)\};\s*const AU=", src, re.S).group(1)]
blocks += [m.group(1) for m in re.finditer(r"Object\.assign\(SFX,\{(.*?)\}\);", src, re.S)]
entries = {}
for b in blocks:
    for m in re.finditer(r"(\w+):\[(\d),\[((?:\[[^\]]*\],?)+)\]\]", b):
        notes = []
        for n in re.findall(r"\[([^\]]*)\]", m.group(3)):
            p = [x.strip() for x in n.split(',')]
            notes.append((float(p[0]), p[1].strip("'"), float(p[2]), float(p[3]), float(p[4]) if len(p) > 4 else 0.0))
        entries[m.group(1)] = (int(m.group(2)), notes)
used = set(re.findall(r"sfx\('(\w+)'\)", src))
print('SFX:', len(entries), 'sem definição no HTML:', sorted(used - set(entries)))
out = ["class_name SfxDefs", "# Gerado por tools/extract_sfx.py a partir das tabelas SFX do HTML (não editar à mão).", "const DEFS := {"]
for k, (t, ns) in entries.items():
    out.append('\t"%s": [%d, [%s]],' % (k, t, ", ".join('[%g, "%s", %g, %g, %g]' % n for n in ns)))
out.append("}")
open(sys.argv[2], 'w').write("\n".join(out) + "\n")
