# Research: Redirección al detalle del pedido tras crearlo

**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

No quedó ningún `NEEDS CLARIFICATION` en el Technical Context del plan: toda la información
necesaria se obtuvo investigando el código actual de `pos-heladeria` y `pos-backend` (citado en la
spec y abajo). Este documento registra las decisiones de diseño tomadas a partir de esa
investigación, no resoluciones de ambigüedad de negocio (esas ya se resolvieron en
`spec.md` → `## Clarifications`).

## 1. Mecanismo de idempotencia en la creación de pedidos (backend, FR-011)

**Decision**: añadir una columna nullable `client_request_id` (string, UUID recomendado) en
`customer_orders`, con un índice único parcial (`UNIQUE (client_request_id) WHERE client_request_id
IS NOT NULL`). En `create_order()` (`app/api/v1/orders/service.py:448`), antes de insertar, si la
solicitud incluye `client_request_id`, se busca primero un pedido existente con ese valor; si
existe, se devuelve ese pedido (sin crear uno nuevo ni duplicar sus ítems); si no existe, se crea el
pedido normalmente guardando el valor recibido.

**Rationale**:
- Sigue un patrón ya establecido en este mismo backend: `app/api/v1/invoices/service.py:47` ya es
  idempotente devolviendo la factura existente de una venta en vez de duplicarla, apoyado en una
  columna única (`Invoice.sale_id`, `app/models/invoice.py:14`). Reutilizar ese patrón para pedidos
  no introduce un concepto nuevo en el proyecto.
- No requiere ninguna dependencia nueva (Principio IX): es una columna + una verificación en
  SQLAlchemy, sin middleware ni librería adicional.
- Es compatible con pedidos históricos (Principio VII): la columna es nullable, sin backfill, y los
  pedidos ya existentes simplemente no tienen valor.

**Alternativas consideradas**:
- **Lock optimista por `version`** (como en `checkout_and_send()`, `app/api/v1/orders/checkout.py:644-686`,
  que ya se describe en su propio docstring como "la guarda de idempotencia contra un doble clic"):
  descartada porque esa guarda protege una *actualización* sobre un pedido ya existente (confirmar o
  cobrar), no la *creación* inicial — que es exactamente el momento en que ocurre el duplicado que
  esta spec busca evitar.
- **Depender solo de la guarda de interfaz** (botón deshabilitado mientras `submitting()` es
  verdadero, `pos-terminal.store.ts:408`): descartada porque no cubre un reintento de red real
  (conexión perdida y reenvío de la misma solicitud), que es precisamente el caso que la
  clarificación de negocio de esta spec exigió cubrir explícitamente en el backend.
- **Header HTTP genérico `Idempotency-Key`**: descartado por ahora porque no hay ninguna convención
  previa en el proyecto para headers de idempotencia (se buscó explícitamente y no se encontró
  ninguna), y añadiría una capa de middleware nueva sin necesidad cuando un campo en el cuerpo de la
  solicitud logra el mismo resultado con menos cambio de infraestructura.

## 2. A dónde volver tras crear el pedido, y qué queda seleccionado (frontend, FR-001/FR-002/FR-007/FR-008/FR-009)

> **Corregido durante la implementación** (ver `tasks.md`, Fase 3, nota de "Hallazgo clave"). Las
> tres decisiones #2, #3 y #4 originales de este documento asumían una ruta nueva,
> `/dashboard/orders/:id` (`OrderDetailComponent`). Al implementar se confirmó que ese componente
> es de solo lectura (el panel admin "Órdenes"), **sin ningún panel "Cobrar pedido"** — ese panel
> con ese nombre literal (`pos-checkout-panel.component.ts:224`), el estado por ítem "Pendiente"
> (`order-status.util.ts:86`) y el encabezado por tipo (`pos-order-panel.component.ts:430-444`:
> "Mesa {N}" / "Para llevar" / "Domicilio" + estado "en preparación" / "pago pendiente" / "listo
> para cobrar") viven **en la terminal misma** (`/dashboard/mesas-sesiones`). Las tres decisiones se
> fusionan en una sola, descrita abajo.

**Decision**: `ManualOrderPageComponent.confirm()` (`manual-order-page.component.ts:978-994`)
sigue navegando a la misma ruta de siempre, `/dashboard/mesas-sesiones` — pero ahora con query
params `pestana` (tipo de pedido), `pedido` (el ID, leído de `store.selectedOrderId()`, ya seteado
por `createManualOrderFromDraft()` antes de esta spec) y, solo para Mesa, `mesa` (el
`dining_table_id`). `TableSessionsComponent.ngOnInit()` los lee y llama a los métodos de selección
que **ya existían** en `PosTerminalStore` para cuando el cajero selecciona algo a mano:
`setOrderTypeTab()`, `selectTable()` + `selectOrder()` (Mesa), o `selectStandaloneOrder()` (Para
llevar/Domicilio, sin mesa). Nombres de parámetro en español (`pestana`/`mesa`/`pedido`, no
`tab`/`table`/`order`), mismo patrón que `table-sessions.component.ts:373,400`/
`manual-order-page.component.ts:889` ya usan con `tipo`.

**Rationale**:
- Reutiliza un patrón de navegación y unos métodos de selección que ya existen en el proyecto; no
  introduce una vista nueva, un servicio de estado de navegación, ni un segundo formato de
  encabezado que solo aplicara al llegar desde creación (eso habría significado dos textos
  distintos para el mismo panel según de dónde se venga).
- Es compatible con recargar el navegador (FR-002, SC-005): toda la información vive en la URL, no
  en memoria del store.
- `selectStandaloneOrder()` ya carga los datos de cobro que necesita el panel "Cobrar pedido"
  (`ensureCheckoutDataLoaded()`); `selectTable()` hace lo mismo para Mesa. Ninguno de los dos
  necesitó cambios.

**Alternativas consideradas**:
- **Una vista de detalle nueva en `/dashboard/orders/:id`** (diseño original): descartada tras
  comprobar que el componente de esa ruta no tiene ningún panel de cobro — habría exigido
  construir uno nuevo, duplicando lo que la terminal ya ofrece.
- **Servicio de estado compartido** (p. ej. un signal global "última selección"): descartado
  porque no sobrevive una recarga de página, rompiendo el escenario de "recargar el navegador".
- **Hacer `PosTerminalStore` singleton** (`providedIn: 'root'`) para que la selección persista
  entre navegaciones sin necesitar query params: descartada explícitamente por el Principio V — es
  un refactor de ciclo de vida que afecta a todos los consumidores del store, con un riesgo de
  regresión que excede el alcance de esta corrección puntual.
- **Reescribir el texto de `headerTitle()`/`headerStatusText()`** a los literales "Pedido · Mesa
  N"/"Pedido para llevar"/"Pedido a domicilio"/"En preparación" de la spec: descartada porque esos
  textos se usan siempre que se selecciona cualquier mesa/pedido en la terminal, no solo tras
  crear uno — cambiarlos habría sido una modificación visual no relacionada con esta corrección
  (Principio V/VI). Los literales de la spec se tratan como una descripción del *contenido*
  (tipo + estado visibles juntos), no como un string exacto a reproducir byte por byte.
