#!/usr/bin/env python3
"""Spec 134 (FR-021): inventaria los bloques de control de flujo de Angular
(@if / @else / @case / @default / @for ...) cuyo contenido directo incluye texto
suelto o una interpolación `{{ }}` sin un elemento que lo envuelva.

Por qué importa: cuando un traductor reemplaza un nodo de texto por <font>, el
bloque que lo contenía puede cambiar de rama y Angular solo quita lo que *él*
creó; el texto de la rama anterior sigue ahí y el botón acaba diciendo
"Enviando pedido… Enviar pedido Enviar pedido". Si el texto vive dentro de un
<span> propio de cada rama, Angular quita el <span> completo y no queda nada.

Uso (desde la raíz de pos-specs):
    python3 specs/134-bloqueo-traduccion-automatica/tools/scan-loose-text.py ../pos-heladeria/src/app

Salida: total de bloques afectados y el desglose por archivo (herramienta de
verificación: la lista autoritativa es la que arroja esta ejecución, no el
número de la spec). Tras el arreglo, el total debe ser 0.

Refinamiento (2026-10-24, al implementar US5): la primera versión contaba como
"texto suelto" las declaraciones `@let x = ...;` (no pintan nada) y no reconocía un
`@else if (...)` con paréntesis anidados a más de dos niveles. Ambas cosas daban
falsos positivos; el total original (55 bloques en 21 archivos) los incluía.
"""
import pathlib
import re
import sys

VOID = {'br', 'img', 'input', 'hr', 'meta', 'link', 'path', 'circle', 'rect', 'line', 'source', 'col'}
TOKEN = re.compile(
    r'(<!--.*?-->|@let\s[^;]*;)'          # comentario o declaración `@let x = ...;` (no pinta texto)
    r'|(</[A-Za-z][^>]*>)'                # cierre de elemento
    r'|(<[A-Za-z][^>]*?/?>)'              # apertura de elemento
    r'|(@(?:if|else if|for|switch|case|defer|empty|placeholder|loading|error)\s*'
    r'(?:\((?:[^()]|\((?:[^()]|\([^()]*\))*\))*\))?\s*\{|@(?:else|default)\s*\{)'  # apertura de bloque (paréntesis anidados hasta 3 niveles)
    r'|(\})'                              # cierre de bloque
    r'|(\{\{.*?\}\})'                     # interpolación
    r'|([^<@{}]+|[@{])',                  # texto
    re.S,
)


def scan(template: str) -> list[str]:
    stack: list[tuple] = []
    found: list[str] = []
    for m in TOKEN.finditer(template):
        comment, close, open_, block, brace, interp, text = m.groups()
        if comment:
            continue
        if close:
            if stack and stack[-1][0] == 'el':
                stack.pop()
            continue
        if open_:
            name = re.match(r'<([A-Za-z0-9-]+)', open_).group(1).lower()
            if open_.endswith('/>') or name in VOID:
                continue
            stack.append(('el', name))
            continue
        if block:
            stack.append(('blk', block.strip()[:40], [False]))
            continue
        if brace:
            if stack and stack[-1][0] == 'blk':
                label, loose = stack.pop()[1:]
                if loose[0]:
                    found.append(label)
            continue
        is_loose = interp is not None or (text is not None and text.strip() not in ('', '@', '{'))
        if is_loose and stack and stack[-1][0] == 'blk':
            stack[-1][2][0] = True
    return found


def main() -> int:
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else '../pos-heladeria/src/app')
    total = 0
    per_file: dict[str, int] = {}
    for path in root.rglob('*'):
        if path.suffix == '.html':
            templates = [path.read_text(errors='ignore')]
        elif path.suffix == '.ts' and not path.name.endswith('.spec.ts'):
            templates = re.findall(r'template:\s*`(.*?)`', path.read_text(errors='ignore'), re.S)
        else:
            continue
        count = sum(len(scan(t)) for t in templates)
        if count:
            per_file[str(path.relative_to(root))] = count
            total += count
    print(f'TOTAL bloques con texto suelto: {total} en {len(per_file)} archivos')
    for name, count in sorted(per_file.items(), key=lambda kv: (-kv[1], kv[0])):
        print(f'{count:3d}  {name}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
