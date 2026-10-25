# Quickstart: Verificar el bloqueo de traducción, el aviso y la actualización de versión

**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

Guía de validación de extremo a extremo. Los detalles de comportamiento están en
[contracts/](./contracts/) y [data-model.md](./data-model.md); aquí solo se dice **qué ejecutar y qué
debe verse**. Todo el cambio vive en `../pos-heladeria`; el backend no se toca.

## Prerrequisitos

- `pos-heladeria` en la rama `fix/134-block-browser-translation` (creada desde `develop`).
- Backend de desarrollo en marcha (`uvicorn app.main:app --reload` nativo; si el contenedor
  `pos-api` no alcanza Postgres, usar el nativo) y `cd ../pos-heladeria && npx ng serve` →
  `http://heladeria.localhost:4200`.
- Un tenant de pruebas con productos, una mesa con QR activo y un usuario del personal de pruebas
  (las credenciales no se guardan en este repositorio).
- Chrome de escritorio. El traductor real **no** se puede disparar desde automatización: se usa el
  **traductor simulado** [tools/simulate-translation.js](./tools/simulate-translation.js) (pegar en la
  consola; expone `__sim.translate()` / `__sim.revert()`).

## Pruebas automáticas

```bash
cd ../pos-heladeria
npx ng test --watch=false --include='src/app/core/integrity/**/*.spec.ts'
npx ng test --watch=false --include='src/app/core/update/**/*.spec.ts'
npx ng test --watch=false --include='src/app/shared/icon-mi/*.spec.ts'
# más las specs de cada plantilla tocada por el nivel A/B (lista del escáner, V7)
```

- Suite completa de `pos-heladeria`: correrla **sola** (nunca en paralelo con la del backend) y
  comparar **por archivo** contra la rama base, dado el baseline conocido con fallos preexistentes.
- Resultado esperado: specs nuevas en verde; ningún archivo de la suite pasa de verde a rojo.

## Escenarios en vivo (Chrome + traductor simulado)

| # | Escenario | Pasos | Resultado esperado | Criterio |
|---|---|---|---|---|
| V1 | Declaración del documento | `curl -s http://heladeria.localhost:4200/ \| grep -Ei 'lang=|translate|notranslate'`; luego `npx ng build` y repetir sobre `dist/frontend/browser/index.html` | `<html lang="es" translate="no" class="notranslate">` y `<meta name="google" content="notranslate">` en ambos | FR-001–003 |
| V2 | Menú QR alterado | Abrir `/menu/t/<token>`; abrir el modal de un producto; en consola `__sim.translate()` | Barra roja "La página fue alterada por el navegador" con "Recargar" en **< 3 s**; sin tocar nada más | SC-003, FR-007 |
| V3 | Protección en el checkout | Con el aviso visible, llenar el carrito y pulsar "Enviar pedido" y luego el paso de pago | Ambas acciones se **rechazan** sin llegar a la red (pestaña Network: ninguna petición a `/cart/submit` ni `/payment-attempts`); aparece "No se pudo enviar el pedido: la página está alterada…" | SC-004, FR-012/013 |
| V4 | Panel alterado | Con sesión del personal: `/dashboard/admin` (tarjeta "Estadísticas de ventas"), Terminal de Mesas (filtro "Todas · N" y título del encabezado), modal de producto del POS; `__sim.translate()` | Aviso < 3 s en cada una; intentar cobrar en la Terminal, aprobar/confirmar en **Pagos por confirmar**, registrar un movimiento o abrir/cerrar turno de caja ⇒ rechazado con explicación | SC-003, SC-004, US3 |
| V5 | Recuperar | Con pedidos ya enviados y carrito confirmado, pulsar "Recargar" | Vuelve al mismo paso/pantalla; "Mis pedidos" muestra los pedidos con los **mismos totales**; el carrito conserva lo confirmado; la sesión del panel sigue activa | SC-005, FR-015 |
| V6 | Cero falsos positivos | Sin simulador: recorrer menú QR, checkout y las pantallas principales del panel; provocar errores normales (DevTools → Offline, una validación de formulario, un 4xx) | El aviso **nunca** aparece; la consola del navegador sin errores nuevos atribuibles a la feature | SC-006, FR-008 |
| V7 | Etiquetas alternantes | `python3 specs/134-bloqueo-traduccion-automatica/tools/scan-loose-text.py ../pos-heladeria/src/app`; luego con `__sim.translate()` alternar "Enviar pedido", "Agregar" (QR y POS) y "Reenviar enlace en N s" varias veces | Escáner: `TOTAL … 0`; cada etiqueta muestra **solo** el texto del estado actual (nunca "Enviar pedido Enviar pedido") y "Agregar · $ …" sigue el total real | SC-007, FR-021 |
| V8 | Momento seguro | En reposo (sin modales ni formularios editados) correr en consola `[...document.querySelectorAll('.fixed.inset-0')].filter(e=>e.getClientRects().length)` y `document.querySelectorAll('.ng-dirty').length` en cada pantalla principal | `[]` y `0` (si no, la actualización nunca se aplicaría ahí: corregir el predicado o registrar la excepción) | FR-019 |
| V9 | Impresión y reportes | Vista previa de impresión del reporte de caja antes/después | Idéntica | Edge Cases |
| V10 | Reversión | `__sim.translate()` → aviso; `__sim.revert()` | El aviso desaparece en ~3 s (dos evaluaciones limpias) y se desbloquean las acciones; con `translate({ markers:false, tag:'span' })` (sin marcas) el aviso también aparece (lo detecta el canario) | FR-010, Decisión 3 |
| V11 | Íconos | Recorrer el menú lateral y las acciones del panel con `__sim.translate()` | Los íconos siguen siendo íconos (el `<span>` de la ligadura lleva `translate="no"`) | SC-009, FR-006 |

## Diferidas — verificación manual en dispositivos reales

No automatizables en este entorno; quedan como **pendientes explícitos** de la spec (no se declaran
cumplidas sin ejecutarlas):

| # | Qué | Dónde |
|---|---|---|
| D1 | Con el idioma del sistema en inglés: sin oferta de traducir, intento manual sin efecto o "no se puede traducir" (SC-001) | Chrome Android, Safari iOS, Chrome y Edge de escritorio, Samsung Internet |
| D2 | Traducción **real** forzada (extensión que ignora el bloqueo): el aviso aparece y protege; confirmar qué marcas deja (`translated-*`, `<font>`, `_msttexthash`) y si el canario basta | Chrome/Edge reales; Firefox (solo red de seguridad) |
| D3 | Idioma del teléfono del caso reportado (inglés vs. español) con la declaración nueva | Teléfono del reporte |
| D4 | Actualización de versión con **dos despliegues sucesivos**: pestaña con la versión vieja → pasa a la nueva en ≤ 5 min tras volver a primer plano, nunca durante un modal/envío/pago | Entorno desplegado con Service Worker activo (en `ng serve` está deshabilitado y un build de producción local apuntaría a la API de producción) |
| D5 | Lighthouse/lector de pantalla: el aviso se anuncia (`role="alert"`) y "Recargar" recibe el foco | Chrome + lector de pantalla |

## Despliegue

1. Publicar `pos-heladeria` (un solo artefacto: el idioma declarado y el bloqueo viajan juntos en
   `index.html`, FR-002). No hay despliegue de backend.
2. Quien nunca abrió la app recibe la versión nueva de inmediato; quien la tenía instalada la recibe
   una visita después (comportamiento actual del Service Worker).
3. **Paso obligatorio de operación**: las pestañas **ya abiertas** antes de este despliegue
   (terminales POS con pestañas de días) ejecutan el código anterior, que no sabe actualizarse solo.
   Pedir una **recarga manual única** (p. ej. al cierre de turno). Desde esta versión en adelante
   se actualizan solas en un momento seguro.
4. Tras el despliegue, repetir V1 contra producción (`curl` al dominio) y D4 con el siguiente
   despliegue.
