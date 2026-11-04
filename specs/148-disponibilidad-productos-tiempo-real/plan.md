# Implementation Plan: Disponibilidad de productos en tiempo real (agotado ↔ disponible)

**Branch**: `148-disponibilidad-productos-tiempo-real` (specs) · código en `feat/148-product-availability-realtime` (`pos-backend` y `pos-heladeria`) | **Date**: 2026-11-02 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/148-disponibilidad-productos-tiempo-real/spec.md`

## Summary

Hacer que un cambio de disponibilidad (marca manual «Agotado» de la spec 093, o falta/reposición
de insumos) llegue a todas las pantallas abiertas del negocio en menos de 3 s, sin recargar, y que
los carritos reaccionen sin perderse. El enfoque **extiende piezas que ya existen** y agrega tres
cosas nuevas:

1. **Un evento nuevo `availability.changed`**, delgado y por lote, publicado en los canales
   `staff` y `menu:{tenant}` del bus SSE/Redis Streams ya existente (specs 077/125/128). No se toca
   la autenticación del stream, así que el aislamiento entre negocios y la separación
   comensal/personal salen de la infraestructura actual.
2. **Un motor único de «pedibilidad»** (`catalog_engine/availability.py`) que calcula, a tres
   niveles (producto, presentación, opción/adición), si algo se puede pedir. Lo consumen el menú,
   el evento, una consulta ligera de reconciliación y el rechazo 409. Hoy el menú **no mira la
   receta** (solo opciones y grupos obligatorios); el motor lo añade, y eso es comportamiento nuevo
   que se registra como anomalía.
3. **Un gancho de sesión** sobre `record_movement`/`apply_adjustment` que detecta las transiciones
   «se puede pedir ↔ no se puede pedir» causadas por inventario y publica **después del commit**,
   una vez por transacción. Cubre los 13 puntos de movimiento de stock actuales y los futuros sin
   tocarlos.

En el cliente, un `AvailabilitySyncService` en la raíz parcha los datos del menú (no cada
componente) con orden garantizado (`v` + `as_of`), reconcilia al reconectar/volver a primer plano y
alimenta un indicador «Sin actualización en vivo» (5 s). La **«línea afectada» es un `computed`**
sobre el menú vivo, nunca estado guardado: así el carrito no se vacía jamás (RN-3) y la marca
desaparece sola al volver disponible. El servidor sigue siendo la última defensa: un **409
unificado** (manual + inventario + cantidad) con `agotados[{id, nombre, tipo, motivo}]` aditivo y
todas las claves previas conservadas.

## Technical Context

**Language/Version**: Backend: Python 3.11 (FastAPI + SQLAlchemy 2.x). Frontend: TypeScript ~5.9 /
Angular ^21.1 (standalone, signals).

**Primary Dependencies**: Ninguna nueva (Principio IX). Se reutilizan: `app/core/events.py`
(`publish`, `menu_channel`, `CH_STAFF`), `app/core/event_bus.py`, `app/inventory_engine/stock.py`,
`app/catalog_engine/*` (`required_consumption`, `check_availability`), eventos de `sqlalchemy.orm.Session`,
`RealtimeService`/`SseClient` (con sus eventos de control `reconnected`/`resync`), `DiningCartService`,
`MenuService`, `PosTerminalStore`.

**Storage**: PostgreSQL 16 schema-per-tenant — **sin cambios de esquema ni migración** (estado
derivado de datos existentes; la marca manual `Product.available` ya existe). Redis Streams para
el evento (existente).

**Testing**:
- Backend: `./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'`
  (SQLite en memoria). Tests nuevos: motor de pedibilidad (3 niveles + receta + equivalencia con el
  cálculo actual de opciones), diferencia antes/después y gancho de sesión (commit publica una vez,
  rollback no publica, sin movimientos no publica, sobre `events.publish` parchado), `set_availability`
  publica solo si cambió, canales/aislamiento (patrón `test_menu_realtime.py`), 409 unificado por
  punto de entrada, snapshot (con y sin filtro QR), guardia de «ninguna otra asignación a
  `current_stock`». Tests existentes que congelan el 400 por inventario se actualizan citando la
  anomalía (Principio III; lista en research.md D17).
- Frontend: `ng test --watch=false --include='src/app/core/availability/**/*.spec.ts'` y los specs
  de cada superficie tocada. La suite completa tiene fallos preexistentes en 7 archivos: se compara
  **por nombre de prueba**, y nunca se corre frontend + backend completos en paralelo.
- Verificación manual/end-to-end: [quickstart.md](./quickstart.md).

**Target Platform**: API web FastAPI + aplicación web POS Angular + menú público QR (mismo
frontend, ruta pública) — todos en producción.

**Project Type**: Web application (frontend Angular + backend FastAPI ya existentes), dos repos de
código y uno de specs.

**Performance Goals**: SC-001 — ≥99 % de los cambios visibles en <3 s con conexión estable.
Presupuesto técnico: gancho de sesión ≤ 50 ms p95 sobre un catálogo de 300 productos (cálculo
acotado a dependientes del insumo); snapshot de disponibilidad ≤ 100 ms p95 (consultas constantes,
sin N+1); eventos agrupados por commit para no desbordar `REALTIME_QUEUE_SIZE`.

**Constraints**:
- Publicar **solo después del commit**; `events.publish` nunca lanza (FR-004/FR-005).
- El payload del evento no lleva existencias, costos ni nombres de insumo ni de empleados (FR-007).
- No cambiar `auth.py` del stream; el tenant sale del token/ticket (FR-030/FR-031).
- No reescribir `Product.available` por inventario (FR-011, spec 093 FR-012).
- El 409 conserva todas las claves que los clientes actuales ya leen (FR-023).
- No tocar `CheckoutProgressStore`: el método/monto/comprobante ya llenados se conservan (FR-019).
- El guardia por módulo `inventario` se conserva en cada punto de entrada (research.md D19): el
  motor y el menú no lo consultan; `ensure_orderable` recibe `toppings_inventory` y cada llamador
  lo pasa como hoy.
- Sin refactor ajeno: el único código existente que se mueve es el cálculo de disponibilidad del
  menú, que **debe** ser la fuente única (Principio V justificado en research.md D3).

**Scale/Scope**: Backend: 1 módulo nuevo (`availability.py`), 1 evento nuevo, 2 endpoints de lectura,
1 gancho de sesión + 3 líneas en `stock.py`, ajuste de `_build_menu`, unificación del rechazo en los
puntos de entrada de [contracts/sold-out-conflict.md](./contracts/sold-out-conflict.md), 2 cambios menores (`with_db`, `main.py`/`celery_task.py` instalan el gancho).
Frontend: 1 carpeta nueva `core/availability/` (modelo, util, sincronizador, indicador),
registro de tipos en `sse-client.ts`, `MenuService`, `PosTerminalStore`, `DiningCartService`, y 7
superficies (menú QR + 3 pasos de pago, Terminal en 4 modalidades, drawer, orden manual, Carta del
menú).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Versión de la constitución evaluada: **4.0.0**.

- **I (nace de un spec)** ✅ `spec.md` aprobado, con checklist de calidad completo y una sesión de
  `/speckit-clarify` (9 respuestas en la sesión del 2026-11-02) incorporada.
- **II (comportamiento existente / decisión de negocio registrada)** ✅ **condicionado a un primer
  paso**: el spec identifica dos cambios de comportamiento existente que **deben registrarse en
  `registro-de-anomalias.md` antes de tocar código** (research.md D17): (1) 400 → 409 y rechazo
  preventivo por inventario al crear el pedido, con el texto de FR-024 también en los 409 que ya
  existían; (2) el menú pasa a marcar agotado por receta (adiciones incluidas). La
  decisión de negocio ya fue tomada por el usuario (Clarifications 2026-11-02); falta solo
  asentarla con número de anomalía. Es la **tarea 1** y bloquea las de código — no es una
  violación, es el orden obligatorio.
- **III (characterization tests)** ✅ Tests que hoy congelan el 400 por inventario (research.md D17)
  se actualizan **de forma explícita en el mismo commit**, citando la anomalía y con evidencia de
  que el resto de la suite sigue en verde. Ninguno lleva el prefijo literal `CONGELA …`, pero se
  trata igual. No se edita ningún test para «hacerlo pasar» sin la decisión registrada.
- **IV (nuevo comportamiento permitido)** ✅ Aplica: agotado por receta, evento en vivo, 409
  unificado y marca de línea son comportamiento nuevo definido por esta spec.
- **V (sin refactor oportunista)** ✅ Lo único que se mueve es el cálculo de disponibilidad del
  menú hacia el motor, porque es el requisito para que menú, evento y 409 no diverjan. Con una
  prueba de equivalencia que congela el cálculo actual de opciones antes de moverlo. El registro de
  `menu.updated` (research.md D13) va en commit propio y reversible.
- **VI (evolución incremental)** ✅ Seis unidades verificables (ver «Fases de entrega»); el backend
  queda retrocompatible tras cada una (evento ignorado por clientes viejos; 409 aditivo).
- **VII (datos históricos)** ✅ Pedidos, ventas y facturas ya emitidos no se tocan ni se recalculan;
  solo cambia lo que está en un carrito sin enviar o lo que se intente agregar (Edge Cases).
- **VIII (modelo de datos)** ✅ **Sin cambios de esquema**: no hay entidades, campos, migración ni
  rollback de datos. Revertir = revertir código. Documentado en [data-model.md](./data-model.md).
- **IX (dependencias)** ✅ Ninguna nueva.
- **X (verificación obligatoria)** ✅ Combinación de: suite de characterization existente (en verde
  salvo lo autorizado), tests nuevos por cada pieza, criterios de aceptación de `spec.md` mapeados
  en [quickstart.md](./quickstart.md), y verificación de integración con dos navegadores reales.
- **XI (negocio vs técnica)** ✅ Las reglas RN-1…RN-5, el 409 unificado, el nivel de detalle
  (producto/presentación/opción), los pasos de pago y los 5 s son decisiones de negocio ya tomadas
  y citadas desde la spec; evento por lote, gancho de sesión, `as_of`, snapshot ligero y el
  parche de datos son decisiones técnicas de este plan, cada una con su alternativa descartada en
  research.md.
- **XII (trazabilidad)** ✅ Necesidad (brief) → Spec 148 + clarificaciones → Anomalías (D17) →
  Plan/Research (19 decisiones, 12 hallazgos con evidencia) → Tareas → Implementación → Tests →
  Verificación (quickstart).
- **XIII (español de Colombia)** ✅ Artefactos en español; commits y ramas en inglés.
- **XIV (rama Git)** ✅ `feat/148-product-availability-realtime`, creada desde `develop` en
  **ambos** repos antes de tocar código. `pos-backend` tiene hoy una migración sin seguimiento
  ajena a esta spec (`alembic/versions/f2d755c229e8_…`): no se toca ni se incluye en ningún commit.
- **XV (commits)** ✅ Solo si el usuario lo pide, en commits pequeños por unidad lógica y por repo,
  en inglés, sin marcas de IA.

**Resultado (pre-diseño)**: PASA, con la tarea 1 (registro de anomalías) como precondición.

**Re-evaluación post-diseño (Fase 1)**: PASA. El diseño no añadió esquema, dependencias ni
cambios de autenticación; los dos cambios de comportamiento siguen siendo exactamente los dos
detectados antes de diseñar. Un tercer hallazgo —`menu.updated` sin registrar en el cliente
(H8)— no es un cambio de esta spec sino un defecto latente de la 128; se aísla en su propio
commit y queda marcado para confirmación del usuario.

## Project Structure

### Documentation (this feature)

```text
specs/148-disponibilidad-productos-tiempo-real/
├── plan.md              # Este archivo (/speckit-plan)
├── research.md          # Fase 0 — 12 hallazgos verificados + 19 decisiones
├── data-model.md        # Fase 1 — modelo conceptual (sin cambios de esquema) y formas de datos
├── quickstart.md        # Fase 1 — escenarios de validación mapeados a las 6 historias
├── contracts/
│   ├── availability-event.md          # Evento SSE availability.changed + canales + eventos de control
│   ├── availability-snapshot-api.md   # GET /menu/availability y GET /menu/qr-token/{token}/availability
│   ├── sold-out-conflict.md           # 409 unificado: forma, puntos de entrada, antes/después
│   └── frontend-surfaces.md           # Matriz superficie × comportamiento (cliente)
├── checklists/
│   └── requirements.md  # Calidad de la spec (/speckit-specify)
└── tasks.md             # Fase 2 (/speckit-tasks — NO lo crea /speckit-plan)
```

### Source Code (repository root)

```text
pos-backend/
├── app/
│   ├── catalog_engine/
│   │   ├── availability.py            # NUEVO: compute_availability(), ensure_orderable(), diff_availability()
│   │   ├── pricing.py                 # ensure_product(s)_available → delegan en el motor (mismo 409 + agotados[])
│   │   └── __init__.py                # reexporta la API nueva
│   ├── inventory_engine/stock.py      # record_movement/apply_adjustment: registran stock inicial/final en db.info
│   ├── core/
│   │   ├── availability_hooks.py      # NUEVO: install_availability_hooks() — before_commit/after_commit/after_rollback
│   │   ├── events.py                  # + availability_changed(); + AVAILABILITY_EVENT_MAX_CHANGES
│   │   └── db.py                      # with_db(): db.info["tenant_schema"] = tenant_schema (1 línea)
│   ├── main.py                        # lifespan: install_availability_hooks()
│   ├── celery_task.py                 # install_availability_hooks() al arrancar el worker
│   └── api/v1/
│       ├── menu/
│       │   ├── router.py              # _build_menu() usa el motor; _option_availability se mueve; + 2 GET de snapshot
│       │   └── schemas.py             # + AvailabilitySnapshot (products/variants/options/as_of)
│       ├── products/router.py         # PATCH /products/{id}/availability: publica tras commit si cambió
│       ├── orders/
│       │   ├── service.py             # create_order(): ensure_orderable() antes de crear nada
│       │   ├── consolidation.py       # add_item_to_order(): ensure_orderable() + 409 en el guardia final
│       │   ├── checkout.py            # _deduct_and_open(): InsufficientStockError → 409 unificado
│       │   ├── consumption.py         # deduct_order_items_naming_product(): 409 unificado
│       │   └── kitchen.py             # reemplazo de línea: idem
│       └── cart/service.py            # add_item/update_item/submit_cart: ensure_orderable() (conserva claves QR)
└── app/characterization_tests/
    ├── test_availability_engine.py        # NUEVO
    ├── test_availability_hooks.py         # NUEVO
    ├── test_availability_events.py        # NUEVO (publicación manual + canales/aislamiento)
    ├── test_availability_snapshot.py      # NUEVO
    ├── test_sold_out_conflict.py          # NUEVO (409 unificado por punto de entrada)
    └── test_orders_checkout.py, test_orders_service.py, …   # ACTUALIZADOS (400→409) citando la anomalía

pos-heladeria/
└── src/app/
    ├── core/
    │   ├── availability/                       # NUEVO
    │   │   ├── availability.model.ts           # AvailabilityChange, AvailabilitySnapshot, SoldOutConflict
    │   │   ├── availability.util.ts            # applyChanges(), applySnapshot(), isProductSoldOut(), parseSoldOutConflict()
    │   │   ├── availability-sync.service.ts    # suscripción, guardia v/as_of, reconciliación, visibilidad
    │   │   ├── live-status.service.ts          # indicador con retardo de 5 s
    │   │   └── live-status-indicator.component.ts
    │   ├── realtime/
    │   │   ├── realtime-event.model.ts         # + AvailabilityChangedEvent en la unión RealtimeEvent
    │   │   └── sse-client.ts                   # KNOWN_EVENT_TYPES += 'availability.changed' (+ 'menu.updated', commit aparte)
    │   └── services/menu.service.ts            # + applyAvailability(), loadAvailability()
    └── modules/
        ├── tables/
        │   ├── services/
        │   │   ├── pos-terminal.store.ts       # cartView: línea afectada derivada; bloqueo de envío; 409 → marcas
        │   │   ├── dining-cart.service.ts      # índice de disponibilidad (raíz) + línea afectada QR
        │   │   └── diner.service.ts            # getAvailability(token); parseo del 409 unificado
        │   ├── components/                     # cart, pos-order-panel, pos-catalog-drawer, product-select(-pos), pos-terminal-header
        │   └── pages/
        │       ├── diner-shell.component.ts    # arranca/para el sincronizador del comensal
        │       ├── public-menu.component.ts    # parcha su signal categories; isProductSoldOut en tarjetas; alerta + bloqueo
        │       ├── manual-order-page.component.ts
        │       └── checkout/                   # checkout-order-summary + method/cash/transfer/review: marca, alerta, «Volver al carrito»
        ├── dashboard/layout/dashboard-layout.component.ts   # arranca el sincronizador del staff junto a connectStaff()
        └── products/pages/products-page.component.ts        # Carta del menú: parche de fila + refresco de la fila
```

**Structure Decision**: Aplicación web de dos repos de código con una rama `feat/148-…` en cada
uno. El backend concentra la lógica nueva en **un módulo de motor** (`catalog_engine/availability.py`)
más **un gancho** (`core/availability_hooks.py`), y deja en los routers existentes solo los puntos
de publicación y de chequeo. El frontend concentra la lógica nueva en **`core/availability/`**
(reutilizable por staff y comensal) y limita el cambio en cada superficie a leer la «línea afectada»
derivada y a bloquear el envío.

## Fases de entrega (Principio VI)

Cada fase deja el sistema desplegable y cada una es revertible por sí sola. Los commits se hacen
solo a pedido del usuario (XV).

| Fase | Contenido | Repo | Historias que habilita |
|---|---|---|---|
| **F0** | Registrar las dos anomalías (D17) | `pos-specs` | precondición de F1–F5 |
| **F1** | Motor de pedibilidad + `_build_menu` sobre el motor (con prueba de equivalencia) + endpoints de snapshot | backend | base de US1/US5/US6 |
| **F2** | Evento `availability.changed`; publicación de la marca manual; gancho de sesión para inventario | backend | US1, US4, US6 |
| **F3** | 409 unificado (`ensure_orderable`) en los puntos de entrada + guardia final; tests protegidos actualizados | backend | US3 |
| **F4** | Núcleo del cliente: registro de tipos SSE (+ test guardia), `core/availability/`, `MenuService`, indicador | frontend | US1, US4, US5 |
| **F5** | Superficies: Terminal (4 modalidades) + drawer + orden manual → Carta del menú → menú QR + pasos de pago | frontend | US1, US2 |
| **F6** | Verificación de punta a punta ([quickstart.md](./quickstart.md)) y regresión | ambos | todas |

**Orden recomendado dentro del trabajo**: F0 → F1 → F2 → F3 → F4 → F5 → F6. F2 y F3 pueden
trabajarse en paralelo tras F1 (tocan archivos distintos).

## Riesgos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| El gancho de sesión se dispara en suites existentes o intenta hablar con Redis en tests | Instalación **explícita** (`main.py`, `celery_task.py`), nunca al importar; tests nuevos lo instalan y parchean `events.publish`. |
| Un movimiento de stock futuro evita `record_movement`/`apply_adjustment` y no avisa | Test guardia que falla si aparece otra asignación a `current_stock` fuera de `stock.py`/importación. |
| Mover el cálculo del menú cambia lo que ya se muestra | Prueba de equivalencia sobre el golden de opciones actual antes de mover; el único cambio intencional es la receta (anomalía 2). |
| Doble fuente de verdad entre evento y snapshot en el cliente | Estados absolutos + `v` por elemento + `as_of` (research.md D9). |
| El comensal en pasos de pago pierde el aviso al destruirse `PublicMenuComponent` | El sincronizador y el índice viven en la raíz/shell (precedente spec 077; D10). |
| `menu.updated` sin registrar: la spec 128 hoy no actualiza en vivo | Commit propio y reversible + test guardia; marcado para confirmación (D13). |
| Un insumo muy compartido genera un lote enorme | Tope `AVAILABILITY_EVENT_MAX_CHANGES` → `refresh: true` (D1). |
| Despliegue con pestañas viejas | Backend primero (aditivo); recarga manual única de pestañas abiertas (mismo caso que spec 134). |

## Complexity Tracking

*No aplica — el Constitution Check no reporta violaciones.* Las piezas de mayor complejidad (gancho
de sesión, motor único) están justificadas en research.md D3/D4 con sus alternativas descartadas;
no son excepciones a ningún principio.

## Estado de implementación (2026-11-02)

**IMPLEMENTADA**, ramas `feat/148-product-availability-realtime` en `pos-backend` y
`pos-heladeria` (creadas desde `develop`), **sin commit ni despliegue** (Principio XV: los commits
se hacen solo a pedido del usuario).

- **F0** (anomalías): A-153 y A-154 registradas en
  `specs/000-reconocimiento/registro-de-anomalias.md`.
- **F1-F3** (backend: motor, eventos, gancho de inventario, 409 unificado): hecho. Suite completa
  `./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'` →
  **2163/2163**, 0 regresiones (línea base: 2092).
- **F4-F5** (frontend: núcleo + las 6 historias de usuario en todas las superficies): hecho.
  `ng test --watch=false` → **2702 en verde / 15 fallos / 1 saltada (2718)**, los 15 fallos son el
  mismo conjunto preexistente de la línea base por nombre de prueba — 0 regresiones nuevas (línea
  base: 2495 en verde / 79 fallos).
- **T105** (registrar `menu.updated` en `KNOWN_EVENT_TYPES`): hecho, con confirmación explícita del
  usuario — activa por primera vez el refresco en vivo de categorías ocultas de la spec 128.
- **T110** (revisión de `docs-publicos/`/`srs/`): sin cambios. `docs-publicos/` no describe el
  interruptor «Agotado», el aviso en vivo ni el 409; `srs/README.md` declara explícitamente que
  documenta solo "el comportamiento real... tal como existe hoy en su código fuente" (ingeniería
  inversa de `develop`, no una especificación prospectiva) — como esta spec vive en una rama sin
  fusionar, actualizarlo ahora introduciría citas `[CÓDIGO: ruta:línea]` que no corresponden al
  código desplegado. Se deja pendiente para cuando esta spec se fusione.
- Detalle completo de la línea base y el resultado final:
  `checklists/baseline-suites.md`.

**Orden de despliegue** (si el usuario decide desplegar): backend primero (aditivo — el evento
`availability.changed` es ignorado por clientes viejos que no lo tengan registrado, y el 409
conserva todas las claves previas), frontend inmediatamente después, con una recarga manual única
de las pestañas ya abiertas (mismo caso que la spec 134, `SwUpdate`).

**Pendiente, no bloqueante**: T044/T064/T082/T084/T095/T104/T106/T109 son verificaciones manuales
con servidores reales (latencia, dos navegadores, dos negocios) — no se ejecutaron en esta pasada
automatizada; quickstart.md sigue siendo la referencia para ejecutarlas antes de un despliegue a
producción. La brecha conocida de líneas `kind:'combo'` de la Terminal (tasks.md Notas #5) no se
resolvió, documentada como fuera de alcance salvo que el dueño la pida aparte.
