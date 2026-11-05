# Implementation Plan: Tablero de cocina en tres columnas con movimiento de pedidos

**Branch**: `151-tablero-cocina-estados` | **Date**: 2026-11-04 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/151-tablero-cocina-estados/spec.md`

## Summary

`spec.md` pide un tablero con tres columnas fijas (SIN PREPARAR / EN PROGRESO / LISTO) donde
cocina ve en FIFO los pedidos ya enviados a la cola de preparación (spec 150) y los mueve entre
columnas (incluso hacia atrás), gateado por pago `PAID`, orden activa y módulo de plan
`"cocina"` activo, con concurrencia resuelta en el backend (409
`KITCHEN_STATUS_CONFLICT`/`PAYMENT_NOT_PAID`) y propagación en tiempo real a todos los tableros
abiertos del tenant. Dos discrepancias entre las Assumptions de `spec.md` y el código real se
resolvieron en esta sesión de planificación con decisiones de negocio explícitas del usuario
(mismo procedimiento que spec 150 Decisión 0, Principio XI): (1) FR-015 **reutiliza** la
infraestructura SSE multi-tenant ya existente de spec 077 (`CH_STAFF`), en vez de construir un
canal nuevo, porque sí existe hoy — la spec asumía lo contrario (research.md Decisión 0); (2) el
rol `KITCHEN` que las clarificaciones ya fijaron como "rol nuevo" se construye con el mismo
molde end-to-end que `MESERO` (spec 075): migración de datos, enum backend/frontend,
dependencia de autorización, guard de ruta (research.md Decisión 1).

## Technical Context

**Language/Version**: Backend — Python 3.14.4 (venv `pos-backend/env`). Frontend — TypeScript
5.9.2 (Angular 21.1.x, standalone components + signals).

**Primary Dependencies**: Ninguna dependencia nueva en ningún repositorio. Reutiliza
`app.core.plan_limits.require_module_access("cocina")` (spec 149/150), `app.core.events`
(patrón pub/sub Redis Streams, spec 077) y `app.api.v1.realtime.router` (stream SSE existente,
canal `CH_STAFF`, research.md Decisión 0) para FR-015, `app.core.domain_errors.ConflictError`
para los tres códigos 409, y el patrón `SELECT ... FOR UPDATE` ya establecido en
`app/api/v1/orders/kitchen.py` (`send_to_kitchen`/`receive_order`/`deliver_order`) para la
transición de `kitchen_status`. Frontend reutiliza `core/realtime/realtime.service.ts`
(suscripción SSE ya consumida por `pos-terminal.store.ts`) y el guard/enum de roles
(`core/guards/role.guard.ts`, `core/interfaces/user.interface.ts`) con el patrón ya usado para
`MESERO` (spec 075). Se introduce una librería de drag-and-drop de Angular ya evaluada como
estándar del ecosistema (`@angular/cdk/drag-drop`, ya parte de `@angular/cdk`, dependencia
existente del proyecto — a confirmar en `package.json` durante la implementación; si no está
presente, se justifica como dependencia nueva en ese momento, no se asume aquí).

**Storage**: PostgreSQL 16, schema-per-tenant. Una fila nueva en `shared.roles` (`KITCHEN`,
migración de datos, mismo molde que `8421e9a2b45a_seed_mesero_role.py` de spec 075). Ninguna
columna, tabla ni índice nuevo sobre `tenant.customer_orders` — reutiliza `kitchen_status`/
`sent_to_kitchen_at` (spec 150) y `version` (preexistente, concurrencia optimista) e
`idx_customer_orders_kitchen_queue` (spec 150) para el filtro del tablero (data-model.md).

**Testing**: Backend — `unittest` vía
`python -m unittest discover -s app/characterization_tests -p 'test_*.py'`, sobre SQLite en
memoria. Se extiende `app/characterization_tests/test_orders_kitchen.py` (ya tocado por spec
150) con los casos de la nueva transición de `kitchen_status` (research.md Decisión 9).
Frontend — Vitest (`ng test`); baseline flaky documentado (memoria de proyecto): criterio de
éxito es ningún archivo **nuevo** fallando, no un conteo total de cero fallos.

**Target Platform**: Linux server (API `pos-backend`) + navegador (SPA `pos-heladeria`, ruta
`dashboard/cocina` que hoy redirige a `mesas-sesiones` y esta spec revive, research.md Decisión
10).

**Project Type**: Web application (backend FastAPI + frontend Angular, repos sibling de
`pos-specs`).

**Performance Goals**: Ninguno específico nuevo — una lectura filtrada por el índice parcial ya
existente (volumen bajo de pedidos activos en cocina, spec 150) y una escritura más (una
columna + `version`) sobre una fila ya bloqueada por `SELECT ... FOR UPDATE`, mismo patrón que
`send_to_kitchen`.

**Constraints**:
- `KITCHEN` solo puede mover tarjetas; `ADMIN`/`CASHIER` solo pueden ver el tablero (FR-014) —
  dos dependencias de autorización distintas (research.md Decisión 2), no una unificada.
- FR-015 se satisface reutilizando el canal `CH_STAFF` ya existente; no se construye ningún
  WebSocket ni stream SSE nuevo (research.md Decisión 0) — decisión de negocio explícita que
  corrige la Assumption original de `spec.md`.
- Ningún dato histórico cambia de significado: ninguna orden existente cambia de
  `kitchen_status`/`status`/`payment_status` como efecto de esta spec; el rol `KITCHEN` nace sin
  asignarse automáticamente a ningún usuario existente (Principio II).
- El reordenamiento manual dentro de una columna (FR-004) es una restricción de UI (configuración
  del drag-and-drop), no un estado que el backend persista o valide (research.md Decisión 7).

**Scale/Scope**: 1 migración de datos (`shared.roles`), 1 enum backend (`RoleName`) + 1 enum
frontend (`UserRole`) ampliados, 2 dependencias de autorización nuevas
(`require_kitchen_board_view`, `require_kitchen_role`), 2 endpoints nuevos
(`GET /orders/kitchen-board`, `POST /orders/{id}/kitchen-status`), 1 función de servicio nueva
(`kitchen.change_kitchen_status`), 1 evento nuevo (`events.order_kitchen_status_changed`), 1
módulo frontend nuevo (`modules/kitchen/`) con su componente de tablero, 1 ruta revivida
(`dashboard/cocina`), 1 entrada de navegación nueva, 1 guard de rol ampliado. Cero tablas
nuevas, cero columnas nuevas sobre `customer_orders`, cero streams/WebSockets nuevos.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Evaluación | Estado |
|---|---|---|
| **I. Las Nuevas Funcionalidades Nacen de un Spec** | `spec.md` existe, aprobado, con 4 historias, 15 FRs, 5 success criteria y 3 clarificaciones ya resueltas. Sus dos puntos ambiguos frente al código real (mecanismo de tiempo real, research.md Decisión 0; nada más en Assumptions que contradiga el código) se resolvieron en esta sesión con decisiones explícitas del usuario. | PASS |
| **II. El Comportamiento Existente Sigue Protegido** | No existe hoy ningún tablero de cocina funcional (la ruta `cocina` solo redirige, spec 149 ya lo verificó) ni rol `KITCHEN` — nada que esta spec esté "cambiando", solo agregando. Ningún pedido histórico cambia de `kitchen_status`/`status`/`payment_status`. No requiere entrada en `registro-de-anomalias.md`. | PASS |
| **III. Los Characterization Tests Protegen el Comportamiento Heredado** | Ningún test `"CONGELA comportamiento actual:"` de `test_orders_kitchen.py` (`receive_order`/`deliver_order`/`void_item`/`send_to_kitchen`) se modifica — los casos nuevos de `change_kitchen_status` se agregan sin tocar los existentes. | PASS |
| **IV. Los Nuevos Specs Pueden Introducir Nuevo Comportamiento** | El comportamiento nuevo (tablero, endpoint de transición, rol) está definido en `spec.md` y acotado por research.md; el criterio de éxito es conformidad con ese comportamiento, no equivalencia con un tablero anterior (el anterior estaba deprecado y vacío de lógica). | PASS |
| **V. Nuevas Funcionalidades Antes que Refactorizaciones Oportunistas** | No se toca `OrderItem.estado_cocina` ni el ciclo de entrega de spec 147; no se crea un canal realtime nuevo cuando `CH_STAFF` ya resuelve el problema (research.md Decisión 0); no se crea un rol genérico con flags cuando el molde de rol dedicado (`MESERO`) ya existe y se replica (Decisión 1). | PASS |
| **VI. Evolución Incremental** | Esta spec entrega una única unidad verificable (tablero + transición + rol + realtime), sin tocar el punto de escritura inicial de `kitchen_status` (spec 150, ya cerrado) ni el flujo de entrega/cancelación existentes — misma disciplina que spec 150 aplicó frente a spec 149. | PASS |
| **VII. Compatibilidad con Datos Históricos** | Ninguna `Sale`/`Payment`/`Invoice` se toca; ninguna migración reinterpreta un pedido histórico. | PASS |
| **VIII. Evolución del Modelo de Datos** | Ver data-model.md: una sola fila nueva en `shared.roles`, sin DDL sobre `customer_orders`, con estrategia de rollback explícita (`DELETE` condicionado a que ningún `User`/`UserInvitation` referencie el rol, mismo guard que `MESERO`). | PASS |
| **IX. Dependencias Nuevas Permitidas con Justificación** | La única dependencia a confirmar (`@angular/cdk/drag-drop`) ya forma parte de `@angular/cdk`, dependencia existente del proyecto — se verifica en `package.json` antes de usarla; si hiciera falta agregarla de cero, esa justificación se documenta en el momento de la implementación, no se asume aquí. Todo el resto de infraestructura (eventos, autorización, SSE) es reutilizada y se documenta en research.md por qué se reutiliza en vez de crear algo nuevo. | PASS |
| **X. Verificación Obligatoria** | quickstart.md traduce las 4 historias + los 5 edge cases de `spec.md` a pasos ejecutables, con criterios de éxito explícitos por escenario (códigos 409, versión, eventos realtime, retiro de tarjetas). | PASS |
| **XI. Decisiones de Negocio Frente a Decisiones Técnicas** | Dos decisiones de negocio quedaron explícitas y correctamente atribuidas al usuario: (1) reutilizar el canal SSE existente en vez de construir uno nuevo, contra la Assumption literal de `spec.md` (research.md Decisión 0); (2) el molde de rol de primera clase para `KITCHEN` (research.md Decisión 1), consistente con la clarificación ya resuelta en `spec.md` ("Rol nuevo `KITCHEN`"). El resto de decisiones de research.md (versión para concurrencia, forma del endpoint, filtro de la vista, UI del drag-and-drop) son técnicas: no cambian ningún comportamiento de negocio definido por `spec.md`/clarificaciones, solo eligen cómo implementarlo reutilizando infraestructura existente. | PASS |
| **XII. Trazabilidad** | Cadena completa: `spec.md` (Necesidad+Spec, con sus 3 clarificaciones ya resueltas) → esta sesión de planificación (2 decisiones de negocio explícitas) → este `plan.md`/`research.md` (decisiones técnicas) → `data-model.md`/`contracts/*.md` (diseño) → `tasks.md` (Fase 2, no generada por este comando) → implementación → tests nuevos → `quickstart.md` (Verificación). | PASS |
| **XIII. Todo en Español de Colombia** | Este plan y todos sus artefactos se escriben en español de Colombia, igual que `spec.md`. | PASS |

Sin violaciones que requieran Complexity Tracking.

**Re-chequeo post-diseño (Fase 1)**: `research.md`, `data-model.md` y `contracts/` no
introdujeron ninguna entidad, dependencia ni decisión que contradiga la tabla anterior. Las dos
decisiones de negocio nuevas surgidas durante el diseño (canal realtime, molde de rol) ya
quedaron resueltas por el usuario antes de escribir `data-model.md`, no después — no hay
ninguna decisión pendiente que re-evaluar. Gates siguen en PASS.

## Project Structure

### Documentation (this feature)

```text
specs/151-tablero-cocina-estados/
├── plan.md              # Este fichero (/speckit-plan)
├── research.md          # Fase 0 (/speckit-plan) — 11 decisiones, 2 de negocio (realtime, rol)
├── data-model.md        # Fase 1 (/speckit-plan) — rol nuevo, reglas de transición, vista
├── quickstart.md        # Fase 1 (/speckit-plan) — validación ejecutable de las 4 historias
├── contracts/            # Fase 1 (/speckit-plan)
│   ├── kitchen-board.md
│   └── move-kitchen-status.md
└── tasks.md              # Fase 2 (/speckit-tasks — NO se crea en este comando)
```

### Source Code (repositorios sibling de `pos-specs`)

Esta spec vive en `pos-specs`, pero el código que describe está en `../pos-backend` y
`../pos-heladeria` (Constitución §Alcance). Rutas relativas a la raíz de cada repo.

```text
# pos-backend
app/
├── core/
│   ├── db.py                          # MODIFICADO — ROLE_NAMES gana "KITCHEN" (research.md
│   │                                     Decisión 1)
│   ├── dependencies.py                # MODIFICADO — require_kitchen_board_view (ADMIN/
│   │                                     CASHIER/KITCHEN) y require_kitchen_role (solo
│   │                                     KITCHEN), mismo molde que
│   │                                     require_tenant_admin_or_cashier (research.md
│   │                                     Decisión 2)
│   └── events.py                      # MODIFICADO — nueva función
│                                         order_kitchen_status_changed(tenant_id, *, order_id,
│                                         table_session_id, kitchen_status, version),
│                                         publicada en CH_STAFF (research.md Decisión 0)
├── api/v1/
│   ├── users/
│   │   └── schemas.py                 # MODIFICADO — RoleName gana KITCHEN = "KITCHEN"
│   │                                     (research.md Decisión 1)
│   └── orders/
│       ├── kitchen.py                  # MODIFICADO — nueva función
│       │                                 change_kitchen_status(db, order_id, kitchen_status,
│       │                                 version, tenant_id), mismo molde SELECT...FOR
│       │                                 UPDATE que send_to_kitchen (research.md Decisión 3/4)
│       ├── router.py                   # MODIFICADO — GET /orders/kitchen-board (research.md
│       │                                 Decisión 5, Depends(require_kitchen_board_view)) y
│       │                                 POST /{order_id}/kitchen-status (Depends(
│       │                                 require_kitchen_role), Depends(require_module_access
│       │                                 ("cocina")))
│       └── schemas.py                  # MODIFICADO — KitchenBoardResponse, KitchenCardOut,
│                                          ChangeKitchenStatusIn (contracts/*.md)
├── characterization_tests/
│   └── test_orders_kitchen.py          # MODIFICADO — casos nuevos para
│                                          change_kitchen_status (éxito, los 4 códigos 409,
│                                          403 por rol, concurrencia con dos locks), reutiliza
│                                          orders_fixtures existentes (research.md Decisión 9)
└── alembic/versions/
    └── {rev}_151_seed_kitchen_role.py   # NUEVO — siembra shared.roles.KITCHEN, mismo molde
            idempotente que 8421e9a2b45a_seed_mesero_role.py (data-model.md §Estrategia de
            migración); downgrade() hace DELETE condicionado a que ningún User/
            UserInvitation referencie el rol

# pos-heladeria
src/app/
├── core/
│   ├── interfaces/
│   │   └── user.interface.ts          # MODIFICADO — UserRole gana KITCHEN = 'kitchen'
│   ├── guards/
│   │   └── role.guard.ts              # MODIFICADO — ROLE_DEFAULT_ROUTES[UserRole.KITCHEN] =
│   │                                     '/dashboard/cocina' (research.md Decisión 10)
│   ├── config/
│   │   └── navigation.config.ts        # MODIFICADO — entrada "Cocina" con
│   │                                     roles: [ADMIN, CASHIER, KITCHEN]
│   └── realtime/
│       └── realtime.service.ts         # MODIFICADO (si aplica) — registra el tipo de evento
│                                          nuevo order.kitchen_status_changed en el modelo de
│                                          eventos ya existente (realtime-event.model.ts)
└── modules/
    ├── dashboard/
    │   └── routes.ts                   # MODIFICADO — revierte el redirect de 'cocina'
    │                                      (comentario "se deprecó") y monta el componente
    │                                      nuevo, canActivate: [roleGuard([ADMIN, CASHIER,
    │                                      KITCHEN])] (research.md Decisión 10)
    ├── users/
    │   └── components/
    │       └── invitation-form.component.ts   # MODIFICADO — opción de rol KITCHEN en el
    │                                             selector, mismo patrón que MESERO
    └── kitchen/                        # NUEVO — módulo del tablero (no existe código vivo
        │                                  reutilizable; spec 149 verificó que el tablero
        │                                  anterior quedó solo como redirect)
        ├── pages/
        │   └── kitchen-board-page.component.ts   # NUEVO — tres columnas, carga inicial vía
        │                                            GET /orders/kitchen-board, suscripción a
        │                                            RealtimeService para order.
        │                                            kitchen_status_changed/order.cancelled/
        │                                            order.delivered
        ├── components/
        │   └── kitchen-card.component.ts          # NUEVO — tarjeta (FR-012): número de
        │                                             orden, origen, cliente/mesa, productos,
        │                                             adiciones, notas, tiempo transcurrido
        ├── services/
        │   └── kitchen-board.service.ts            # NUEVO — GET /orders/kitchen-board, POST
        │                                              /{id}/kitchen-status
        └── interfaces/
            └── kitchen-board.interface.ts           # NUEVO — tipos TypeScript espejo de
                                                         contracts/*.md
```

**Structure Decision**: dos endpoints nuevos y una función de servicio nueva extienden el
módulo de órdenes ya existente (`app/api/v1/orders/`), sin crear ningún router nuevo en
`pos-backend` — mismo criterio que spec 150 aplicó al agregar `/send-to-kitchen` al router de
órdenes en vez de crear uno dedicado. El rol `KITCHEN` extiende el catálogo de roles ya
existente con una migración de datos, sin tabla nueva (mismo molde que `MESERO`, spec 075). En
`pos-heladeria` se crea el único módulo genuinamente nuevo de esta spec (`modules/kitchen/`),
porque no hay ningún componente de tablero vivo que extender — el anterior fue deprecado
(spec 149) y solo queda su redirect en `dashboard/routes.ts`, que esta spec revierte.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

Sin violaciones — tabla vacía. La única particularidad de este plan —corregir dos Assumptions
de `spec.md` que no correspondían al código real (mecanismo de tiempo real, molde de rol) en
vez de implementarlas tal como estaban escritas— no es una excepción de complejidad sino el
procedimiento normal del Principio XI, documentado en el Constitution Check (fila XI) y en
research.md Decisiones 0 y 1, con ambas decisiones confirmadas explícitamente por el usuario en
esta sesión.
