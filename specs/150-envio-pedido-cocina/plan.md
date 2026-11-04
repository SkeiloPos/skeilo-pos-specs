# Implementation Plan: Envío de pedido confirmado y pagado a cocina

**Branch**: `150-envio-pedido-cocina` | **Date**: 2026-11-04 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/150-envio-pedido-cocina/spec.md`

## Summary

`spec.md` pide que el cajero/admin pueda enviar un pedido confirmado y pagado a la cola de
preparación de cocina con un botón "Enviar a cocina", registrando `kitchen_status`/
`sent_to_kitchen_at` con la hora del servidor, idempotente ante dobles clics o reintentos, y
gateado por el módulo de plan "cocina" (spec 149) ya existente pero sin ningún punto de
enforcement hasta ahora. Ninguno de los dos campos (`kitchen_status`, `sent_to_kitchen_at`) ni el
botón existen hoy en ninguno de los dos repositorios — se verificó por inspección directa
(research.md Decisión 1) — así que esta spec los crea desde cero, sobre `CustomerOrder`
(`pos-backend`) y sobre el panel de pedido en vivo ya existente (`pos-heladeria`), reutilizando el
molde ya probado de las acciones "Recibir"/"Entregar" (spec 147) en ambos repositorios. El único
punto genuinamente ambiguo del spec frente al modelo real — qué significa "orden confirmada"
dado que `CustomerOrder.status` ya tiene un cuarto valor (`confirmado`) con un significado
distinto del que el spec asumía — se resolvió en esta sesión de planificación con una decisión
explícita del usuario: `status != 'cancelada'` (research.md Decisión 0).

## Technical Context

**Language/Version**: Backend — Python 3.14.4 (venv `pos-backend/env`). Frontend — TypeScript
5.9.2 (Angular 21.1.x, standalone components + signals).

**Primary Dependencies**: Ninguna dependencia nueva en ningún repositorio. Reutiliza
`app.core.plan_limits.require_module_access` (spec 149, ya acepta `"cocina"`),
`app.core.dependencies.require_tenant_admin_or_cashier` (spec 093),
`app.core.domain_errors.ConflictError`/`DomainError` (spec 068, ya registrado globalmente vía
`error_middleware.py`) y `app.core.events` (patrón pub/sub Redis ya usado por
`order_received`/`order_delivered`). Frontend reutiliza `PosTerminalStore`,
`DiningSessionService`, `ToastService` y el guard/servicio `plan-summary.service.ts` ya
existentes.

**Storage**: PostgreSQL 16, schema-per-tenant. Dos columnas nuevas sobre
`tenant.customer_orders` (modelo `CustomerOrder`): `kitchen_status` (`String`, nullable, sin
`CheckConstraint` — research.md Decisión 2) y `sent_to_kitchen_at` (`DateTime`, nullable). Un
índice parcial nuevo (`idx_customer_orders_kitchen_queue`, research.md Decisión 8). Ninguna tabla
nueva, ninguna migración de datos retroactiva (todo pedido existente nace con ambas columnas en
`NULL`, data-model.md).

**Testing**: Backend — `unittest` vía
`python -m unittest discover -s app/characterization_tests -p 'test_*.py'`, sobre SQLite en
memoria (no requiere Postgres para esta suite). Se extiende
`app/characterization_tests/test_orders_kitchen.py` con los casos de `send_to_kitchen`, reutilizando
`orders_fixtures.make_customer_order`/`make_order_item` (research.md Decisión 9). Frontend —
Vitest (`ng test`); la suite tiene un baseline flaky documentado
(`specs/148-disponibilidad-productos-tiempo-real/checklists/baseline-suites.md`) que ya incluye
`pos-order-panel`/`manual-order-page`/`pos-terminal.store.spec.ts` — criterio de éxito: ningún
archivo **nuevo** fallando, no un conteo total de cero fallos (memoria de proyecto).

**Target Platform**: Linux server (API `pos-backend`) + navegador (SPA `pos-heladeria`, panel de
pedido en vivo ya existente en `src/app/modules/tables/`).

**Project Type**: Web application (backend FastAPI + frontend Angular, repos sibling de
`pos-specs`).

**Performance Goals**: Ninguno específico nuevo — una escritura más (dos columnas) sobre una fila
ya bloqueada por `SELECT ... FOR UPDATE` en el mismo patrón que `receive_order`/`deliver_order`;
el índice parcial nuevo evita que una futura lectura de la cola (fuera de alcance aquí) dependa de
un *table scan*.

**Constraints**:
- El alcance de esta fase **no** incluye ningún endpoint ni pantalla que consuma la cola de
  preparación (tablero de cocina) — ver "Assumptions" de `spec.md` y research.md Decisión 8. Esta
  spec solo construye el punto de escritura (`kitchen_status`/`sent_to_kitchen_at`) y documenta el
  criterio de orden para que una spec futura lo reutilice.
- "Orden confirmada" (FR-001/FR-002/FR-006/FR-010) se traduce como `status != 'cancelada'`, nunca
  como `status == 'confirmado'` — decisión de negocio explícita de esta sesión (research.md
  Decisión 0), porque el paso `'confirmado'` ("Recibir", spec 147) es informativo e independiente
  del pago, y FR-010 solo da `cancelada` como contraejemplo.
- `kitchen_status` no lleva `CheckConstraint` (research.md Decisión 2): cualquier valor no nulo se
  trata como "ya enviado", sin asumir que `"SIN_PREPARAR"` es el único valor no nulo posible — una
  spec futura puede agregar `PREPARANDO`/`LISTO` sin otra migración de constraint.
- Ningún dato existente se pierde ni se reinterpreta: todo pedido histórico nace con
  `kitchen_status`/`sent_to_kitchen_at` en `NULL` (Principio II — no hay comportamiento de cocina
  en producción que esta migración esté alterando, igual que spec 149 Decisión 0).
- El rol se restringe a `ADMIN`/`CASHIER` (FR-011) únicamente en el endpoint nuevo — ningún otro
  endpoint existente se modifica.

**Scale/Scope**: 2 columnas nuevas + 1 índice parcial en `tenant.customer_orders`, 1 migración
Alembic (`@for_each_tenant_schema`), 1 función de servicio nueva (`kitchen.send_to_kitchen`), 1
endpoint nuevo (`POST /orders/{id}/send-to-kitchen`), 1 evento nuevo
(`events.order_sent_to_kitchen`), 2 campos nuevos en `OrderResponse` (Pydantic) y en `DiningOrder`
(TypeScript), 1 método nuevo en `DiningSessionService`, 1 método nuevo en `PosTerminalStore`, 1
botón condicional nuevo en `pos-order-panel.component.ts`, 1 helper puro nuevo en
`order-status.util.ts`. Cero tablas nuevas, cero componentes/páginas nuevos, cero dependencias
nuevas.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Evaluación | Estado |
|---|---|---|
| **I. Las Nuevas Funcionalidades Nacen de un Spec** | `spec.md` existe, aprobado, con 3 historias, 11 FRs y 5 clarificaciones ya resueltas. Su único punto ambiguo frente al código real ("orden confirmada") se resolvió en esta sesión con una decisión explícita del usuario (research.md Decisión 0), no asumida unilateralmente. | PASS |
| **II. El Comportamiento Existente Sigue Protegido** | No existe hoy ningún botón "Enviar a cocina" ni columna `kitchen_status`/`sent_to_kitchen_at` en producción (research.md Decisión 1) — nada que esta spec esté "cambiando", solo agregando. Ningún pedido histórico cambia de comportamiento observable tras la migración (nace en `NULL`). No requiere entrada en `registro-de-anomalias.md`. | PASS |
| **III. Los Characterization Tests Protegen el Comportamiento Heredado** | Ningún test `"CONGELA comportamiento actual:"` de `test_orders_kitchen.py` (`receive_order`/`deliver_order`/`void_item`) se modifica — los casos nuevos de `send_to_kitchen` se agregan sin tocar los existentes. | PASS |
| **IV. Los Nuevos Specs Pueden Introducir Nuevo Comportamiento** | El comportamiento nuevo (columnas, endpoint, botón) está definido en `spec.md` y acotado por research.md Decisión 0; el criterio de éxito es conformidad con ese comportamiento, no equivalencia con el pasado (no había pasado que igualar). | PASS |
| **V. Nuevas Funcionalidades Antes que Refactorizaciones Oportunistas** | No se toca `OrderItem.estado_cocina` ni el ciclo de entrega de spec 147 (research.md Decisión 1, alternativa descartada); no se crea una clase de excepción nueva por código cuando `DomainError`/`ConflictError` ya resuelve el problema (research.md Decisión 3); no se crea una dependencia de rol nueva cuando `require_tenant_admin_or_cashier` ya existe (Decisión 5). | PASS |
| **VI. Evolución Incremental** | Esta spec entrega una única unidad verificable (el punto de escritura de `kitchen_status`/`sent_to_kitchen_at` + su endpoint + su botón), deliberadamente sin tocar el consumo de la cola (tablero de cocina, fuera de alcance, research.md Decisión 8) — misma disciplina que spec 149 aplicó al no reintroducir ningún router de cocina. | PASS |
| **VII. Compatibilidad con Datos Históricos** | Ninguna `Sale`/`Payment`/`Invoice` se toca; la migración no reinterpreta ningún pedido histórico (nace en `NULL`). | PASS |
| **VIII. Evolución del Modelo de Datos** | Ver data-model.md: dos columnas nuevas + un índice parcial, sin backfill (ambas nacen `NULL`), con estrategia de rollback explícita (`op.drop_column`/`op.drop_index`, data-model.md). | PASS |
| **IX. Dependencias Nuevas Permitidas con Justificación** | No aplica — cero dependencias nuevas; toda la infraestructura reutilizada (`require_module_access`, `require_tenant_admin_or_cashier`, `ConflictError`, patrón de eventos) ya existe y se documenta en research.md por qué se reutiliza en vez de crear algo nuevo. | N/A |
| **X. Verificación Obligatoria** | quickstart.md traduce las 3 historias + los 4 edge cases de `spec.md` a pasos ejecutables, con criterios de éxito explícitos por escenario (códigos de error, valores de `kitchen_status`/`sent_to_kitchen_at`, visibilidad del botón). | PASS |
| **XI. Decisiones de Negocio Frente a Decisiones Técnicas** | Una decisión de negocio quedó explícita y correctamente atribuida: qué significa "orden confirmada" contra el modelo real — decidida por el usuario vía pregunta directa en esta sesión (research.md Decisión 0), no inferida por el asistente. El resto de decisiones de research.md (mecanismo de error, gating de módulo, dependencia de rol, molde de endpoint, índice) son técnicas: no cambian ningún comportamiento de negocio definido por `spec.md`, solo eligen cómo implementarlo reutilizando infraestructura existente. | PASS |
| **XII. Trazabilidad** | Cadena completa: `spec.md` (Necesidad+Spec, con sus 5 clarificaciones ya resueltas en sesiones previas) → esta sesión de planificación (decisión de negocio sobre "confirmada", explícita) → este `plan.md`/`research.md` (decisiones técnicas) → `data-model.md`/`contracts/send-to-kitchen.md` (diseño) → `tasks.md` (Fase 2, no generada por este comando) → implementación → tests nuevos → `quickstart.md` (Verificación). | PASS |
| **XIII. Todo en Español de Colombia** | Este plan y todos sus artefactos se escriben en español de Colombia, igual que `spec.md`. | PASS |

Sin violaciones que requieran Complexity Tracking.

**Re-chequeo post-diseño (Fase 1)**: `research.md`, `data-model.md` y `contracts/` no introdujeron
ninguna entidad, dependencia ni decisión que contradiga la tabla anterior. La única decisión de
negocio nueva surgida durante el diseño (qué significa "orden confirmada") ya quedó resuelta por
el usuario antes de escribir `data-model.md`, no después — no hay ninguna decisión pendiente que
re-evaluar. Gates siguen en PASS.

## Project Structure

### Documentation (this feature)

```text
specs/150-envio-pedido-cocina/
├── plan.md              # Este fichero (/speckit-plan)
├── research.md          # Fase 0 (/speckit-plan) — 11 decisiones, incluida la de negocio
│                           sobre "orden confirmada" (Decisión 0)
├── data-model.md        # Fase 1 (/speckit-plan) — columnas nuevas, índice, migración
├── quickstart.md        # Fase 1 (/speckit-plan) — validación ejecutable de las 3 historias
├── contracts/            # Fase 1 (/speckit-plan)
│   └── send-to-kitchen.md
└── tasks.md              # Fase 2 (/speckit-tasks — NO se crea en este comando)
```

### Source Code (repositorios sibling de `pos-specs`)

Esta spec vive en `pos-specs`, pero el código que describe está en `../pos-backend` y
`../pos-heladeria` (Constitución §Alcance). Rutas relativas a la raíz de cada repo.

```text
# pos-backend
app/
├── models/
│   └── customer_order.py              # MODIFICADO — CustomerOrder gana kitchen_status
│                                         (String, nullable, sin CheckConstraint) y
│                                         sent_to_kitchen_at (DateTime, nullable), más el
│                                         índice parcial idx_customer_orders_kitchen_queue
│                                         (data-model.md)
├── api/v1/orders/
│   ├── kitchen.py                     # MODIFICADO — nueva función send_to_kitchen(db,
│   │                                     order_id, tenant_id), mismo molde que
│   │                                     receive_order/deliver_order (SELECT ... FOR
│   │                                     UPDATE, orden de validaciones de research.md
│   │                                     Decisión 6)
│   ├── router.py                      # MODIFICADO — nuevo endpoint POST
│   │                                     /{order_id}/send-to-kitchen, justo después de
│   │                                     /deliver, con Depends(require_module_access
│   │                                     ("cocina")) y Depends(require_tenant_admin_or_
│   │                                     cashier) (a diferencia de /receive y /deliver,
│   │                                     que solo usan get_current_user)
│   └── schemas.py                     # MODIFICADO — OrderResponse gana kitchen_status:
│                                         Optional[str], sent_to_kitchen_at:
│                                         Optional[datetime]
├── core/
│   └── events.py                      # MODIFICADO — nueva función
│                                         order_sent_to_kitchen(tenant_id, *, order_id,
│                                         table_session_id), mismo molde que
│                                         order_delivered
├── characterization_tests/
│   └── test_orders_kitchen.py         # MODIFICADO — casos nuevos para send_to_kitchen
│                                         (éxito por los 3 orígenes, ORDER_NOT_PAID,
│                                         ALREADY_IN_KITCHEN, ORDER_NOT_CONFIRMED, rol,
│                                         módulo no incluido, concurrencia), reutilizando
│                                         orders_fixtures existentes
└── alembic/versions/
    └── {rev}_150_customer_orders_kitchen_status.py   # NUEVO — agrega
            tenant.customer_orders.kitchen_status y sent_to_kitchen_at (ambas nullable,
            sin backfill) + idx_customer_orders_kitchen_queue, vía @for_each_tenant_schema
            (mismo patrón que c5d6e7f8a9b0); downgrade() hace drop_index + drop_column
            (data-model.md)

# pos-heladeria
src/app/modules/tables/
├── services/
│   ├── dining-session.service.ts      # MODIFICADO — nuevo método
│   │                                     sendToKitchen(orderId): Promise<DiningOrder>
│   │                                     (POST /orders/{id}/send-to-kitchen), mismo
│   │                                     molde que deliverOrder
│   └── pos-terminal.store.ts           # MODIFICADO — nuevo método async
│                                         sendToKitchen(orderId?), mismo molde que
│                                         deliverOrder salvo el manejo silencioso de
│                                         ALREADY_IN_KITCHEN (research.md Decisión 3/10):
│                                         si err.error?.error?.code ===
│                                         'ALREADY_IN_KITCHEN', solo reload() sin
│                                         toast.error
├── components/
│   └── pos-order-panel.component.ts    # MODIFICADO — botón "Enviar a cocina" nuevo,
│                                         condición de visibilidad vía helper puro
│                                         (order-status.util.ts), mismo patrón que el
│                                         botón "Entregar" ya existente
├── utils/ (o donde viva hoy order-status.util.ts)
│   └── order-status.util.ts            # MODIFICADO — nuevo helper puro
│                                         canSendToKitchen(order, moduleAccess): boolean
│                                         = order.status !== 'cancelada' &&
│                                         order.payment_status === 'PAID' &&
│                                         !order.kitchen_status && moduleAccess.cocina
└── interfaces/ (donde viva DiningOrder)
    └── dining-order.interface.ts       # MODIFICADO — DiningOrder gana kitchen_status:
                                           string | null, sent_to_kitchen_at: string | null
```

**Structure Decision**: cada archivo tocado extiende un patrón ya existente de dos usos
(`/receive`+`/deliver` en backend, "Recibir"+"Entregar" en frontend) a un tercer caso
(`/send-to-kitchen`) — ningún directorio, módulo, componente ni servicio nuevo se crea en
ninguno de los dos repositorios, salvo el fichero de migración (obligatorio por el esquema nuevo)
y `contracts/send-to-kitchen.md` en `pos-specs`. No se crea ningún router, componente de
tablero ni vista de cocina — ese trabajo queda fuera de alcance por "Assumptions" de `spec.md`,
para una spec futura que consuma la cola ya documentada en data-model.md.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

Sin violaciones — tabla vacía. La única particularidad de este plan —resolver una ambigüedad del
spec contra el modelo real de `status` mediante una decisión de negocio explícita del usuario,
en vez de inferirla— no es una excepción de complejidad sino el procedimiento normal del
Principio XI, documentado en el Constitution Check (fila XI) y en research.md Decisión 0.
