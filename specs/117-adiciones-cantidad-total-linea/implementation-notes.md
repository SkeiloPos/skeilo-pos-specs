# Notas de implementación — Spec 117

## T003 — Línea base (2026-10-13, antes de cualquier cambio de esta spec)

### `pos-backend` (rama `feat/117-addons-quantity-line-total` desde `develop`, recién creada, sin cambios todavía)

```
python -m unittest discover -s app/characterization_tests -p 'test_*.py'
```

**Resultado: `Ran 1493 tests in 82.576s` — `OK`** (0 fallos). Usar `./env/bin/python`, no `python`
del sistema (el venv del proyecto vive en `pos-backend/env/`).

### `pos-heladeria` (rama `feat/117-addons-quantity-line-total` desde `develop`)

Antes de poder correr la suite, `npx ng test --watch=false` falló en **build** (no en tests) con
dos errores `TS2339` en `src/app/modules/tables/services/pos-terminal.store.spec.ts` (líneas 1886 y
1890): `l.product.name` sobre `l: DraftLine` (tipo unión `ProductDraftLine | ComboDraftLine`) sin
discriminar por `l.kind === 'product'`. Verificado con `git log` que este test no fue tocado por
esta spec — quedó roto por el último commit de `develop` (`29ddea7`, "implement promotion handling
in manual order creation", que introdujo el discriminante `kind`/`ComboDraftLine` sin actualizar
este test anterior). Es un bloqueo de **compilación**, no de comportamiento: sin corregirlo no hay
forma de obtener ninguna línea base de la suite frontend completa (bloquea los 133 archivos de
test, no solo los afectados).

**Corrección mínima aplicada** (no es parte del alcance de spec 117, solo desbloqueo de línea
base): se narrowea con `l.kind === 'product'` en las dos líneas señaladas. Ningún otro archivo del
proyecto tenía este error (`npx tsc -p tsconfig.spec.json --noEmit` limpio tras el cambio).

Con esa corrección, `npx ng test --browsers=ChromeHeadless` falla porque el proyecto usa Vitest, no
Karma (`--browsers` no aplica; usar `npx ng test --watch=false` a secas, Angular 21 + Vitest).

```
npx ng test --watch=false
```

**Resultado: `7 failed | 126 passed (133)` archivos de test; `11 failed | 1771 passed | 1 skipped
(1783)` tests individuales.** Los 7 archivos/11 tests que fallan ya fallaban antes de esta spec —
coinciden con el patrón conocido de fallos preexistentes de la suite frontend (ver memoria
`reference_pos_suite_frontend_fallos_preexistentes`; el recuento sigue a la deriva: 19 el
2026-10-02, 10 el 2026-10-07, 11 hoy):

- `src/app/app.spec.ts` (2 tests)
- `src/app/core/services/auth.service.spec.ts` (1 test)
- `src/app/core/services/menu.service.spec.ts` (1 test)
- `src/app/modules/super-admin/services/tenant.service.spec.ts` (3 tests, uno duplicado en el log)
- `src/app/modules/tables/components/pos-checkout-panel.component.spec.ts` (1 test)
- `src/app/modules/tables/components/pos-order-panel.component.spec.ts` (2 tests)
- `src/app/modules/tables/services/pos-terminal.store.spec.ts` (1 test: "no mezclar paquete con
  suelto en la misma línea (A-134)" — distinto del test T050 que esta spec añadirá en ese mismo
  archivo)

**Criterio de comparación para T045/T046**: al cierre de la spec, la suite de backend debe seguir
en `OK` salvo los tests nuevos/actualizados citando A-126; la de frontend debe mantener exactamente
estos mismos 7 archivos/11 tests preexistentes sin cambios (no entrar en la cuenta de regresión) y
no sumar ningún fallo nuevo fuera de los tests que esta spec actualiza explícitamente.

## A-127 — Bug preexistente descubierto en T013 (`sales/service.py::checkout`)

Al escribir T013 (characterization test de punta a punta sobre `service.checkout`) se encontró que
**toda** venta de mostrador (`POST /sales/checkout`) crasheaba con `AttributeError` — confirmado en
vivo, no solo por lectura: `from app.api.v1.orders import checkout` (línea 29) quedaba sombreado por
`def checkout(...)` (línea 299, la propia función), así que `checkout.auto_discount(...)` (línea
345) buscaba `.auto_discount` en la función, no en el módulo. Registrado como **A-127** en
`registro-de-anomalias.md` (ACCIDENTAL, no decisión de negocio) y corregido con el usuario presente
(confirmó "corregir ahora y continuar" ante la pregunta explícita): alias `orders_checkout` en el
import, un cambio de una línea. Sin este fix, T013 era literalmente imposible de escribir como pide
`tasks.md` (llamar a `service.checkout` real). Dos tests de `test_catalog_option_groups_quantity.py`
que antes evitaban `service.checkout` por este bug (documentado en su propio docstring) ahora lo
llaman directamente.

## Dos tests de la spec 089 actualizados por el eje nuevo (citando A-126, Principio III)

Al implementar T017 (`cart/service.py`), dos tests YA EXISTENTES de `TestQrAddonsPerLine`/
`TestQrEditAddons` (`test_cart_service.py`) empezaron a fallar porque su fixture compartida
(`self.extras`) es, a la vez, `pricing_type='con_recargo'` **y** `selection_mode='cantidad'` —
antes de esta spec ambos ejes coincidían siempre; con el eje nuevo (nunca se apaga con
`QR_ADDONS_PER_LINE`) deja de poder demostrarse la reversa del eje 089 en aislamiento con ese mismo
grupo:

- `test_bandera_apagada_crea_la_linea_con_la_regla_historica`: se le agregó un grupo nuevo, puro del
  eje 089 (`con_recargo` + `conteo`), solo para ese test.
- `test_seleccion_que_viola_el_tope_por_opcion_es_422_con_el_mensaje_del_grupo`: el tope escalado
  (`2×2=4`) ya no rechaza `quantity=3`; se subió a `quantity=5` (por encima del tope ya escalado)
  para seguir demostrando el 422.

## T052 — Fusión de línea en el backend (confirmado, sin cambio de código)

`cart/service.py::add_item` y `orders/consolidation.py::add_item_to_order` **nunca** buscan una
línea existente para fusionar — ambos construyen siempre una fila (`CartItem`/`OrderItem`) nueva,
confirmado leyendo su código completo (T017/T018 de esta misma spec). FR-014 (confirmación de
cantidad de adición al fusionar) por tanto **no aplica** a ningún endpoint de backend — es
exclusivamente un comportamiento de `PosTerminalStore` (frontend, borrador aún no enviado), donde sí
existía fusión (`addDraftFromSelection`). Resuelto en T050/T051 reabriendo el modal de selección en
modo edición (patrón elegido por el usuario entre las opciones presentadas).

## T047 — Recorrido manual consolidado en navegador real (2026-10-13)

Verificado en vivo contra Postgres real (no SQLite de characterization tests), con `pos-backend`
corriendo nativo (`uvicorn`, puerto 8000) y `pos-heladeria` con `ng serve` (puerto 4200), tenant
`heladeria` (`http://heladeria.localhost:4200`), usando una sesión ya autenticada de
`qa116-admin@e2e-pos.com` en el navegador de desarrollo persistente del proyecto.

**Escenario**: "Granizado del diablo" (Grande, $15.000) × 2 + "Gomitas" ($1.000, grupo
`selection_mode='cantidad'`, `pricing_type='con_recargo'`, `max_total_quantity=3`) × 1, vía
Terminal POS → pedido manual (mesa "mesa de pruebas 1", canal POS, **no** Menú QR — el caso que
antes de esta spec habría cobrado $32.000 "folded").

| Superficie | Resultado mostrado | Esperado (FR-002) |
|---|---|---|
| Selector de producto (botón "Agregar") | `$ 31.000` | $31.000 |
| Borrador del carrito ("Ver pedido") | `$ 31.000` | $31.000 |
| Resumen antes de "Crear pedido" (TOTAL ORDEN) | `$ 31.000` | $31.000 |
| Comanda de la mesa (post-creación) | `2 × $15.000` + `"+ $1.000 adicionales"` = `$31.000`, `Gomitas x1` (no x2) | US4: cantidad total, no multiplicada |
| Panel "Cobrar pedido" (Subtotal/Total) | `$ 31.000` | US2: coincide con las demás |
| Confirmación de pago | "Venta de $ 31.000 ... registrada" | US2: Sale.total = $31.000 |
| "Detalle de Orden" (`/dashboard/orders/{id}`) | Subtotal/Total `$ 31.000`, "Adicionales: $1.000", "Gomitas x1" | US2/US4: coincide |

**Las 7 superficies coinciden exactamente en $31.000, cero discrepancias (SC-003).** Cierra el
checkpoint manual de T026/T030/T044 con un recorrido real, no solo characterization tests.

Orden creada: `a361f9d8-a5b5-46b4-96df-4d27af58bd64` (pagada, queda en los datos de desarrollo del
tenant `heladeria`, mismo patrón que las demás órdenes `[pruebas]` ya presentes en ese tenant).
Usuario cajero temporal (`spec117-qa@e2e-pos.com`) creado para la prueba y **eliminado** al
terminar — no se usó finalmente (la sesión admin ya autenticada en el navegador bastó).

**Pendiente de este recorrido** (fuera de esta sesión, por alcance/tiempo): escenario de US3
(reducir cantidad de producto y ver el ajuste automático + aviso) y el Menú QR del comensal
(§2 completo: "Pagos por confirmar" real con un pago por transferencia/QR) — ambos cubiertos por
characterization tests + `ng test` sin regresiones (T027, T031-T042), pero no por este navegador.
Quien continúe esta spec puede repetir el mismo patrón (tenant `heladeria`, grupo "Adicionales"
`8c167a43-9901-4454-943c-5464e5777c81` con tope `max_total_quantity=3`, variante
`688b5e77-7146-4a13-806b-bf683380ca64`) para esos dos casos.

Servidores de desarrollo que esta sesión dejó corriendo en background (el usuario puede detenerlos
si no los necesita): `uvicorn` nativo en `:8000` (pos-backend) y `ng serve` en `:4200`
(pos-heladeria).

## T048 — Resolución de los 4 hallazgos de la cabecera de `tasks.md`

1. **7º call-site (`compute_draft_preview`)**: confirmado y corregido en T022 — recableado igual
   que los otros 6 (`load_valid_options(..., quantity=...)` + `mark_per_line` +
   `compute_unit_price`/`compute_addons_total`). T015 (`test_orders_draft_preview_parity.py`) cierra
   el lazo de paridad con `create_order` real.
2. **`orders/kitchen.py` necesita `quantity` para los topes**: confirmado y corregido en T021
   (`load_valid_options(..., quantity=data.replacement.quantity)`).
3. **Archivo real de los topes fijos**: confirmado — los tests de T007/T031/T032 se escribieron en
   `test_catalog_option_groups_quantity.py` (clases `QuantityCapsTests`/nueva
   `TestAutoAdjustCantidadOptions` en `test_cart_service.py`), no en
   `test_catalog_option_groups_selection_mode.py`.
4. **Solo dos tests documentaban el bug de verdad**: confirmado — actualizados en T017 (hallazgo
   adicional de dos tests de spec 089 que necesitaron un fixture nuevo, ver sección arriba) y en la
   implementación de US1 (`test_confirmar_una_orden_completa_descuenta_solo_la_cantidad_de_la_adicion`,
   `test_cobrar_una_venta_de_mostrador_completa_descuenta_solo_la_cantidad_de_la_adicion`), ambos
   citando A-126. `test_precio_de_linea_multiplica_extra_price_por_cantidad` no se tocó (T016).

## Decisiones tomadas durante la implementación (no estaban en plan.md/research.md)

- **A-127** (bug preexistente, `sales/service.py::checkout` roto por sombra de nombre): encontrado
  al escribir T013; confirmado con el usuario antes de corregir (pregunta explícita, respuesta
  "corregir ahora y continuar"). Registrado por separado de A-126 porque es un defecto de
  programación, no una decisión de negocio.
- **FR-014 (Phase 3b, T050-T052)**: el patrón de UX ("reabrir el modal de selección en modo
  edición") lo eligió el usuario entre tres opciones presentadas explícitamente, tal como pedía la
  nota de diseño pendiente de `tasks.md`.
- **Dos tests de spec 089 actualizados por el eje nuevo**: ver sección dedicada arriba — no estaban
  anticipados en `tasks.md`, surgieron al correr la suite tras T017.

## Desviaciones respecto al plan

Ninguna de fondo. El único artefacto no anticipado por `plan.md`/`research.md` es el propio
registro de **A-127** (`specs/000-reconocimiento/registro-de-anomalias.md`), que no cambia ningún
contrato ni comportamiento de esta spec — solo repara un camino que estaba completamente roto.
