# Implementation Plan: Corrección — Mesa ocupada sin pedido no se puede liberar

**Branch**: `fix/110-liberar-mesa-sin-pedido` | **Date**: 2026-10-10 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/110-liberar-mesa-sin-pedido/spec.md`

## Summary

Una mesa puede quedar en `status = "ocupada"` (backend) sin ningún pedido vivo — por ejemplo,
cuando el cajero rechaza/cancela el único pedido manual antes de que llegue a cocina, ya que
`try_release_if_empty` (`pos-backend/.../cart/service.py:88-136`) no se invoca desde ese camino.
El computed `centralState` del frontend
(`pos-heladeria/src/app/modules/tables/services/pos-terminal.store.ts:628-637`) decide si mostrar
el panel de detalle mirando **solo** si hay pedidos vivos (`tableOrders(tableId).length > 0`),
ignorando el `status` real de la mesa — a diferencia de `deriveTableStatus()`
(`pos-terminal.store.ts:222-259`, usado para la insignia de la grilla), que sí distingue
correctamente `tableStatus === 'ocupada'` sin pedidos de una mesa genuinamente `'libre'` (líneas
254-258). Esa discrepancia es la causa raíz: `centralState` colapsa ambos casos al mismo valor
`'mesa-libre'`, que oculta toda la columna de detalle (`table-sessions.component.ts:388-390`),
incluido el botón "Liberar Mesa" (`pos-checkout-panel.component.ts:401-408`).

**Enfoque técnico**: hacer que `centralState` use la misma señal de estado que ya usa
`deriveTableStatus` (el `status` de la mesa, no solo el conteo de pedidos vivos) para decidir
entre `'mesa-libre'` (mesa genuinamente libre) y un nuevo caso que sí despliega el panel de
detalle con únicamente la acción "Liberar Mesa" cuando la mesa está `'ocupada'` sin pedidos.
Backend sin cambios: `release_paid_session` ya soporta liberar una sesión sin pedidos
(`table_sessions/service.py:379-453`, `_assert_closable` no rechaza lista vacía,
líneas 249-274).

## Technical Context

**Language/Version**: TypeScript ~5.9.2 (Angular ^21.1.0), standalone components + signals.

**Primary Dependencies**: Angular (signals/computed), `pos-terminal.store.ts` (store central de la
terminal de mesas), `pos-checkout-panel.component.ts`, `table-sessions.component.ts`.

**Storage**: N/A — no se modifica el modelo de datos ni el backend (`pos-backend`); el endpoint de
liberación ya soporta el caso sin cambios.

**Testing**: `ng test` (Jasmine/Karma vía Angular CLI) para specs unitarias del store y los
componentes afectados; validación manual end-to-end según `quickstart.md`.

**Target Platform**: Web (navegador), terminal de mesas del POS de staff (`pos-heladeria`).

**Project Type**: Web application (frontend Angular + backend FastAPI ya existentes); esta
corrección es **frontend-only**.

**Performance Goals**: N/A — cambio de lógica de un computed ya existente, sin impacto de
rendimiento medible (mismo volumen de datos ya cargado).

**Constraints**: no alterar el comportamiento de mesas genuinamente libres ni de mesas con
pedidos activos (spec FR-004, FR-005); no tocar `release_paid_session` ni ningún endpoint de
backend (ya soporta el caso).

**Scale/Scope**: un computed (`centralState`), su consumidor de guard (`showingDetail()` /
`effectiveCentralView`), y el panel de detalle (`pos-checkout-panel.component.ts`) para que
renderice un estado "solo liberar" cuando no hay pedidos que mostrar.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Principio I (nace de un spec)**: ✅ `specs/110-liberar-mesa-sin-pedido/spec.md` existe y
  define problema, causa raíz, alcance, criterios de aceptación e impacto.
- **Principio II (comportamiento existente protegido)**: ✅ el comportamiento que cambia es
  precisamente el bug (ocultar el panel de detalle para mesas ocupadas sin pedidos) — no una regla
  de negocio de precio/inventario/facturación. El spec documenta la causa raíz y está autorizado
  directamente por el dueño/desarrollador del proyecto como reporte de bug en producción (sección
  "Autorización de negocio" del spec, Principio XI). No aplica una entrada nueva en
  `registro-de-anomalias.md`: es la misma categoría que la spec
  [050](../050-correccion-liberar-mesa-pedido-cancelado/spec.md), que tampoco la requirió, por
  tratarse de corregir un defecto de la interfaz, no de redefinir una regla de negocio.
- **Principio III (characterization tests)**: ✅ no existen characterization tests
  `"CONGELA comportamiento actual:"` sobre `centralState`/`showingDetail()` para este caso
  específico (mesa ocupada + 0 pedidos); si la investigación de implementación encuentra alguno,
  se actualiza citando esta spec como autorización.
  Pendiente: ⚠️ **NEEDS VERIFICATION** — confirmar en la fase de implementación.
- **Principio V/VI (sin refactorizaciones ajenas, cambio incremental)**: ✅ el alcance se limita al
  computed `centralState`, su guard de render y la vista "solo liberar" del panel de detalle; no
  se toca backend, modelo de datos, ni otras vistas de la terminal de mesas.
- **Principio VII (facturas históricas)**: ✅ N/A — no hay facturación involucrada en este fix.
- **Principio VIII (evolución del modelo de datos)**: ✅ N/A — no hay cambios de esquema ni de
  backend.
- **Principio X (verificación obligatoria)**: se cubre con tests unitarios del store/componente
  afectados + validación manual (`quickstart.md`) + los characterization tests existentes deben
  seguir en verde.
- **Principio XIV (rama Git)**: la implementación debe ocurrir sobre una rama nueva
  `fix/110-liberar-mesa-sin-pedido`, creada desde la rama actual antes de tocar código en
  `pos-heladeria`.
- **Principio XV (commits)**: los commits de implementación se seccionan por unidad lógica y solo
  se ejecutan cuando el usuario lo solicite explícitamente.

**Resultado**: PASA. Sin violaciones que requieran justificación en Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/110-liberar-mesa-sin-pedido/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
└── checklists/
    └── requirements.md  # Spec quality checklist (/speckit-specify command)
```

No se genera `contracts/`: esta corrección no introduce ni modifica ningún endpoint de API ni
contrato externo — el endpoint de backend (`POST /table-sessions/{id}/release`) ya existe y ya
soporta el caso sin cambios. El "contrato" observable que cambia es puramente de interfaz de
usuario (qué se renderiza en la terminal de mesas), ya cubierto por los criterios de aceptación y
los escenarios Given/When/Then de `spec.md`.

### Source Code (repository root)

```text
pos-backend/            # Sin cambios en esta corrección (ya soporta el caso, ver Summary).

pos-heladeria/
└── src/app/modules/tables/
    ├── services/
    │   └── pos-terminal.store.ts        # centralState (líneas 628-637), deriveTableStatus
    │                                     # (líneas 222-259), tableOrders (líneas 600-604)
    ├── pages/
    │   └── table-sessions.component.ts  # showingDetail() (líneas 388-390) -- sin cambios,
    │                                     # ya pasa el nuevo estado sin tocarla
    └── components/
        ├── pos-checkout-panel.component.ts  # botón "Liberar Mesa" (líneas 401-408), releaseTable();
        │                                     # exclusión de "Pedido de mostrador" para el nuevo estado
        └── pos-order-panel.component.ts      # exclusión de "+ Agregar producto" para el nuevo estado
```

**Corrección sobre lo planeado** (confirmado durante la implementación, no durante este plan):
`table-sessions.component.ts` vive en `pages/`, no en `components/` como decía la primera versión
de este documento. Además, `showingDetail()` no necesitó ningún cambio de código — su guardia ya
era `effectiveCentralView() !== 'mesa-libre'`, así que el nuevo valor pasó automáticamente. El
verdadero punto de cambio adicional, no anticipado en el research original, fue
`pos-order-panel.component.ts`: con la columna de detalle visible, ese componente seguía
ofreciendo "+ Agregar producto" para la mesa ocupada sin pedido, lo que violaba el requisito de
que "Liberar Mesa" fuera la única acción (spec FR-002).

**Structure Decision**: cambio acotado a `pos-heladeria/src/app/modules/tables/` (services +
components ya existentes de la terminal de mesas). No se tocan otros módulos del frontend ni el
backend (`pos-backend`).

## Complexity Tracking

*No aplica — el Constitution Check no reporta violaciones.*
