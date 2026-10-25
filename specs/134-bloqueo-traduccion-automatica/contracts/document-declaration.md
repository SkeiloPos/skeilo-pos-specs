# Contrato: declaración del documento (idioma, bloqueo e íconos)

**Cubre**: FR-001, FR-002, FR-003, FR-004, FR-005, FR-006 · **Historias**: US1, US3 · **Decisiones**: [research.md](../research.md) 1 y 2

## `src/index.html`

Un único cambio atómico (FR-002: idioma y bloqueo nunca por separado):

| Elemento | Antes | Después |
|---|---|---|
| `<html>` | `<html lang="en">` | `<html lang="es" translate="no" class="notranslate">` |
| `<head>` | — | `<meta name="google" content="notranslate">` |

Reglas:
- `translate="no"` va en `<html>` (no en `app-root`): el atributo se hereda a todo el documento,
  **incluidas las capas que Angular/CDK montan en `<body>`** (FR-003).
- No se añade `Content-Language`, ni se escribe `lang`/`translate` desde TypeScript: llegaría tras
  el primer pintado.
- El script inline del tema (spec 116) no se modifica: solo escribe `dataset.theme`.
- Ninguna otra plantilla de documento existe (sin SSR/prerender).

**Efecto esperado** (a confirmar en la verificación diferida): con el idioma del sistema en inglés,
Chrome/Edge no muestran la oferta de traducir; el intento manual indica que no se puede traducir o
deja el texto igual.

## Íconos de ligadura — `IconMiComponent`

El `<span class="material-icons-outlined">` que renderiza la ligadura añade `translate="no"` y la
clase `notranslate`. Se conserva todo lo demás (`aria-hidden`, `role`, `aria-label`,
`[style.font-size.px]`, el texto de la ligadura): **sin cambio visual ni de accesibilidad**.
`app-icon` y `app-icon-lucide` (SVG) no cambian.

## Impresión y reportes

`lang="es"` no altera maquetación ni formato de números/fechas (los pipes de Angular usan
`LOCALE_ID`, que no se toca; `Intl` usa el idioma del navegador, no el del documento). Se verifica
que no hay `hyphens: auto` ni `:lang()` en el CSS (`grep` limpio en esta fase) y que el reporte de
caja al imprimir se ve igual (quickstart V9).

## Pruebas

| Prueba | Tipo |
|---|---|
| `IconMiComponent` renderiza `translate="no"` y `notranslate` en el `<span>` de la ligadura, conservando `aria-*` y tamaño | unitaria (`icon-mi.component.spec.ts`) |
| `index.html` contiene exactamente `lang="es"`, `translate="no"`, `notranslate` y el meta `google/notranslate` | verificación en el build (quickstart V1) |
