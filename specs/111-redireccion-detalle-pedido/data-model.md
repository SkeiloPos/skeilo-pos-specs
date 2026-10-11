# Data Model: Redirección al detalle del pedido tras crearlo

**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Research**: [research.md](./research.md)

Esta corrección es, en su mayoría, de navegación de interfaz; el único cambio de modelo de datos
real es el campo de idempotencia exigido por FR-011 (RN4, Clarifications). No se crean entidades
nuevas ni se modifica el ciclo de vida de `Pedido`/`CustomerOrder`.

## Entidad modificada: `CustomerOrder` (tabla `customer_orders`)

**Archivo**: `../pos-backend/app/models/customer_order.py`

| Campo | Tipo | Nulo | Descripción |
|---|---|---|---|
| `client_request_id` *(nuevo)* | `String` (UUID en formato texto, recomendado) | Sí | Generado por el frontend una sola vez por intento de "Crear pedido"; se reenvía sin cambios si ese mismo intento se reintenta por una falla de red (FR-011). |

**Índice nuevo**: único parcial —
`CREATE UNIQUE INDEX ... ON customer_orders (client_request_id) WHERE client_request_id IS NOT NULL`
— permite múltiples filas con `NULL` (todo pedido histórico, y cualquier cliente que aún no envíe
el campo) sin violar la unicidad, mientras garantiza que dos filas no puedan compartir el mismo
`client_request_id` real.

**Compatibilidad con datos existentes (Principio VII)**: todos los pedidos ya creados quedan con
`client_request_id = NULL` tras la migración; ninguno se recalcula, se reescribe ni cambia su
representación histórica.

**Estrategia de migración**: migración Alembic aditiva (`ADD COLUMN ... NULL` + índice único
parcial) sobre el esquema `tenant`, siguiendo la convención ya usada por otras migraciones de
columna de este proyecto (ver `research.md` → convenciones de Alembic en `plan.md`/investigación
de `pos-backend`). Sin backfill: el valor histórico correcto para toda fila existente es `NULL`.

**Estrategia de rollback**: la función `downgrade()` de la misma migración elimina el índice único
parcial y luego la columna (`DROP INDEX`, `DROP COLUMN`). Al no haber backfill ni ningún otro
cambio dependiente, el rollback no pierde información distinta de la que la propia migración
introdujo.

**Relaciones**: ninguna nueva. El campo vive únicamente en `customer_orders`; no se referencia
desde otras tablas.

## Esquema de request modificado: `OrderCreate`

**Archivo**: `../pos-backend/app/api/v1/orders/schemas.py:125-148`

| Campo | Tipo | Requerido | Descripción |
|---|---|---|---|
| `client_request_id` *(nuevo)* | `str \| None` | No | Opcional y retrocompatible — ver [contracts/post-orders.md](./contracts/post-orders.md) para el contrato completo del endpoint. |

## Concepto de navegación (frontend, no persistido): selección a restaurar en la terminal

> **Corregido durante la implementación** (ver `tasks.md`, Fase 3): no hay ninguna ruta
> `/dashboard/orders/:id` involucrada — la navegación tras crear el pedido vuelve a la terminal
> (`/dashboard/mesas-sesiones`) con la selección correcta, no a una vista nueva. Ver
> [contracts/order-detail-navigation.md](./contracts/order-detail-navigation.md) (reescrito) para
> el contrato completo.

No es una entidad de datos ni se guarda en ninguna tabla ni store persistente; son valores que
viajan únicamente en la URL del navegador, para que sobrevivan una recarga de página sin necesitar
estado en memoria (ver `research.md` punto 2) — relevante porque el store de la terminal
(`PosTerminalStore`) no es singleton y arranca sin nada seleccionado en cada navegación.

| Parámetro | Dónde aparece | Valores válidos | Significado |
|---|---|---|---|
| `pestana` | `/dashboard/mesas-sesiones?pestana=...` | `mesas` \| `para-llevar` \| `domicilios` | Pestaña que `TableSessionsComponent` debe activar al cargar, en vez del valor por defecto (`mesas`). |
| `pedido` | `/dashboard/mesas-sesiones?pedido=...` | ID de un `CustomerOrder` | Pedido que debe quedar seleccionado (`selectOrder`/`selectStandaloneOrder`) para que se muestre en `pos-order-panel`/`pos-checkout-panel`. |
| `mesa` | `/dashboard/mesas-sesiones?mesa=...` | ID de una `DiningTable` | Solo presente cuando `pestana=mesas`: la mesa a seleccionar (`selectTable`) antes de fijar el pedido exacto. |

Nombrados en español (`pestana`/`mesa`/`pedido`, no `tab`/`table`/`order`) para seguir la
convención ya establecida en este mismo código: `table-sessions.component.ts:373,400` y
`manual-order-page.component.ts:889` ya usan `tipo` como nombre de query param, no `type`.

Ausencia de los tres parámetros al entrar a `/dashboard/mesas-sesiones` (p. ej. por el menú de
navegación): sin cambios — pestaña por defecto (`'mesas'`), nada seleccionado, comportamiento
exigido por FR-010.

## Transiciones de estado

Esta corrección **no introduce** ninguna transición de estado nueva sobre `Pedido`/`CustomerOrder`.
El estado "en preparación" que ve el cajero (FR-009) no es un estado propio de `CustomerOrder`
(ese nace en `'recibida'` con `hold_for_payment=true`, sin cambios) — es el badge ya existente de
`pos-order-panel.component.ts::headerStatusText()`, derivado de que ningún ítem del pedido está
aún `'listo'` en cocina. El cambio se limita a qué se ve seleccionado tras la creación y a impedir
que la creación misma se
duplique — el ciclo de vida del pedido en sí no cambia.
