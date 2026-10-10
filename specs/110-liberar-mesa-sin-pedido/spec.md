# Feature Specification: Corrección — Mesa ocupada sin pedido no se puede liberar

**Feature Branch**: `110-liberar-mesa-sin-pedido`

**Created**: 2026-10-10

**Status**: Draft

**Naturaleza de esta spec**: **spec de corrección**, no una funcionalidad nueva desde cero. Igual
que las specs [019](../019-correccion-cuenta-mesas-fusionadas/spec.md),
[020](../020-correccion-validacion-opciones-mesero/spec.md),
[041](../041-correccion-bugs-menu-qr/spec.md),
[045](../045-simplificacion-terminal-mesas/spec.md),
[049](../049-rediseno-panel-pedido-mesa/spec.md) y
[050](../050-correccion-liberar-mesa-pedido-cancelado/spec.md), cita archivo, función y línea del
código actual (`pos-heladeria`) porque son el contrato observable que se está corrigiendo, no una
fuga de detalles de implementación. El bug es exclusivamente de frontend; el endpoint de backend
que libera la mesa ya soporta este caso correctamente.

**Autorización de negocio (Principio I y Principio II de la
[Constitución](../../.specify/memory/constitution.md))**: reportado directamente por el
dueño/desarrollador del proyecto el 2026-10-10 como bug activo en producción.

**Input**: User description (verbatim): "actualmente cuando una mesa aparece ocupada sin pedido,
el cajero o admin no tiene forma de liberarla, este es un bug en produccion quiero que crees un fix
para solucionarlo siguiendo el flujo actual es decir el cajero o admin precionan click sobre la
mesa, pueden ver el detalle aunque no haya pedido pero la unica cosa que puede hacer es liberar la
mesa"

**Causa raíz confirmada (investigación del código actual)**:

- Una mesa queda con `status = "ocupada"` al abrir una sesión o carrito sobre ella
  (`pos-backend/app/api/v1/cart/service.py:149`,
  `pos-backend/app/api/v1/orders/consolidation.py:69`,
  `pos-backend/app/api/v1/tables_advanced.py:98`) — independientemente de si ese pedido llega a
  confirmarse. Si el cajero crea un pedido manual sobre la mesa y lo rechaza/cancela antes de que
  cocina reciba algo, la mesa se queda en `"ocupada"` con cero pedidos vivos: el rechazo
  (`rejectOrder()` → `cancel_order`) no dispara la liberación automática
  (`try_release_if_empty`, `pos-backend/app/api/v1/cart/service.py:88-136`), que solo se invoca
  desde los flujos de salida de comensal/expiración de token
  (`pos-backend/app/api/v1/cart/service.py:543,562`).
- Al hacer click sobre esa mesa, `selectTable()`
  (`pos-heladeria/src/.../pos-terminal.store.ts:1498-1525`) sí selecciona la mesa y carga su
  cuenta, pero el computed `centralState`
  (`pos-heladeria/src/.../pos-terminal.store.ts:628-637`) decide el estado visual **solo** mirando
  si hay pedidos vivos (`tableOrders(tableId).length === 0`), sin mirar el `status` real de la
  mesa. Cero pedidos vivos ⇒ `centralState = 'mesa-libre'`, el mismo valor que usa para una mesa
  genuinamente libre.
- `showingDetail()` (`pos-heladeria/src/.../table-sessions.component.ts:388-390`) oculta toda la
  columna de detalle — incluyendo `app-pos-checkout-panel`, donde vive el botón "Liberar Mesa"
  (`pos-checkout-panel.component.ts:401-408`) — cuando `centralState() === 'mesa-libre'`. Resultado:
  para una mesa ocupada sin pedidos, la columna de detalle completa desaparece y no queda ninguna
  acción posible desde la interfaz. La única forma de liberarla hoy es una intervención manual en
  base de datos.
- El endpoint de liberación (`POST /table-sessions/{id}/release` →
  `release_paid_session`, `pos-backend/app/api/v1/table_sessions/service.py:379-453`) ya soporta
  liberar una sesión con cero pedidos sin ningún error (`_assert_closable` no rechaza una lista
  vacía, `pos-backend/app/api/v1/table_sessions/service.py:249-274`). **No se requiere ningún
  cambio de backend.**

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Liberar una mesa ocupada sin ningún pedido (Priority: P1)

Un cajero o admin ve en la grilla de mesas que una mesa aparece como "ocupada", pero en realidad no
tiene ningún pedido activo (por ejemplo, porque el único pedido manual que se creó fue rechazado o
cancelado antes de llegar a cocina). Hace click sobre la mesa esperando poder resolver esa
situación, y la única acción que necesita — y la única razonable dado que no hay nada que cobrar ni
preparar — es liberar la mesa.

**Why this priority**: sin esta corrección, cualquier mesa que quede en este estado se vuelve
inutilizable para siempre desde la interfaz — ni el cajero ni el admin tienen ninguna acción
disponible, y la mesa deja de poder usarse para nuevos clientes hasta que alguien intervenga
directamente en la base de datos.

**Independent Test**: se puede probar completamente abriendo una mesa (creando una sesión/carrito
sobre ella para que quede "ocupada"), sin confirmar ningún pedido o cancelando el único pedido
manual creado, haciendo click sobre la mesa, y verificando que aparece el botón "Liberar Mesa" y
que al presionarlo la mesa vuelve a estado libre.

**Acceptance Scenarios**:

1. **Given** una mesa en estado "ocupada" sin ningún pedido activo (todos cancelados o nunca
   confirmados), **When** el cajero o admin hace click sobre la mesa, **Then** el sistema muestra
   el panel de detalle de esa mesa con "Liberar Mesa" como la única acción disponible (sin listado
   de ítems ni pedidos, porque no existen).
2. **Given** ese mismo panel de detalle abierto, **When** el cajero o admin presiona "Liberar
   Mesa", **Then** la mesa queda en estado libre, disponible para una nueva sesión, sin mostrar
   ningún error.
3. **Given** una mesa realmente libre (nunca ocupada, sin sesión activa), **When** el cajero o
   admin hace click sobre ella, **Then** el comportamiento actual no cambia (se sigue mostrando
   como mesa libre, sin panel de detalle con acciones de liberación).
4. **Given** una mesa ocupada con al menos un pedido activo, **When** el cajero o admin hace click
   sobre ella, **Then** el comportamiento actual no cambia (se sigue mostrando el panel de detalle
   con el pedido y sus acciones normales).

---

### Edge Cases

- **Mesa ocupada con un carrito/borrador sin confirmar, pero sin ningún pedido confirmado**: se
  trata igual que "sin pedido" para efectos de mostrar "Liberar Mesa"; al liberar, ese borrador se
  descarta junto con la mesa (consistente con el comportamiento ya existente de borrado de
  carritos al cerrar una mesa).
- **Mesa con todos sus pedidos cancelados** (el escenario ya cubierto por la spec
  [050](../050-correccion-liberar-mesa-pedido-cancelado/spec.md) cuando sí hay ítems sin terminar
  en cocina): si además no queda ningún pedido vivo visible, debe caer en este mismo caso (panel de
  detalle con "Liberar Mesa" disponible), no quedar bloqueada.
- **Mesa fusionada o con múltiples comensales** donde todos los participantes se retiraron sin
  confirmar pedido: mismo tratamiento — debe poder liberarse desde el detalle.
- **Mesa reservada sin pedido**: fuera de alcance de esta corrección; el estado "reservada" no es
  "ocupada" y no está afectado por este bug.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema DEBE mostrar el panel de detalle de la mesa al hacer click sobre una mesa
  en estado ocupado, incluso cuando esa mesa no tenga ningún pedido activo (confirmado y no
  cancelado).
- **FR-002**: Cuando el panel de detalle se muestra para una mesa ocupada sin pedidos activos, el
  sistema DEBE ofrecer "Liberar Mesa" como la acción disponible, sin requerir que exista un pedido
  o una cuenta asociada para habilitarla.
- **FR-003**: Al presionar "Liberar Mesa" en este escenario, el sistema DEBE liberar la mesa (misma
  operación que el flujo de liberación ya existente), dejándola disponible para una nueva sesión.
- **FR-004**: El sistema NO DEBE confundir una mesa ocupada sin pedidos con una mesa realmente
  libre: el estado "mesa libre" (sin panel de detalle, sin acciones) se reserva exclusivamente para
  mesas que no tienen ninguna sesión activa.
- **FR-005**: La corrección NO DEBE alterar el comportamiento actual para mesas que sí tienen al
  menos un pedido activo, ni para mesas genuinamente libres.
- **FR-006**: Si existe un carrito o borrador sin confirmar asociado a la mesa en el momento de
  liberarla, el sistema DEBE descartarlo como parte de la liberación, sin bloquear la operación ni
  mostrar error.

### Key Entities

- **Mesa**: unidad física/lógica del salón con un estado (`libre`, `ocupada`, `reservada`) visible
  en la grilla de la terminal de mesas.
- **Sesión de Mesa**: período en que una mesa está en uso por uno o más comensales; determina si la
  mesa aparece "ocupada", independientemente de si llegó a generarse un pedido confirmado.
- **Pedido**: orden confirmada sobre una mesa; puede estar activa o cancelada. Una sesión puede
  tener cero pedidos activos y seguir "ocupada".

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El cajero o admin puede liberar cualquier mesa ocupada sin pedidos activos en menos
  de 10 segundos desde que hace click sobre ella, sin necesitar intervención técnica ni acceso a
  base de datos.
- **SC-002**: El 100% de las mesas ocupadas sin pedidos activos muestran la acción "Liberar Mesa"
  al seleccionarlas.
- **SC-003**: Cero regresiones — las mesas con pedidos activos y las mesas genuinamente libres
  conservan exactamente su comportamiento actual tras la corrección.

## Assumptions

- El endpoint de backend que libera la mesa ya soporta sesiones sin pedidos (confirmado en el
  código actual); esta corrección es exclusivamente de la capa de interfaz que decide cuándo
  mostrar el panel de detalle y sus acciones.
- "Liberar Mesa" en este escenario realiza la misma operación de liberación ya usada en el resto de
  la aplicación (no se introduce un flujo de liberación distinto).
- El estado "reservada" queda fuera de alcance: esta corrección cubre mesas marcadas como
  "ocupada" sin pedidos activos, no el ciclo de vida de reservas.
