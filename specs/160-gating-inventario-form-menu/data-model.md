# Data Model: Ocultar sección de Inventario en el formulario de carta según el plan

**Feature**: `160-gating-inventario-form-menu`

Esta feature **no introduce ni modifica entidades, campos, ni relaciones** de datos. Es un
cambio exclusivamente de presentación (visibilidad condicional en el frontend) sobre
entidades y campos que ya existen y cuya forma no cambia.

## Entidades existentes relevantes (sin cambios)

### Plan / ModuleAccess
Fuente: `src/app/modules/plan/interfaces/plan-summary.interface.ts` (pos-heladeria).

- `PlanSummary.modules: ModuleAccess`
- `ModuleAccess.inventario: boolean` — indica si el módulo de Inventario está activo para
  el tenant en el plan vigente. Ya existe; esta feature solo lo **lee**, vía
  `PlanSummaryService.summary()`, no lo modifica.
- `PlanSummary.vencido: boolean` — ya considerado por el computed `inventarioIncluido()`
  existente (un plan vencido se trata como sin módulo de Inventario, consistente con el
  resto del sistema).

### Producto / Tamaño (presentación)
Fuente: `ProductFormComponent` (pos-heladeria) y el modelo de draft del formulario.

- `draft().tracks_inventory: boolean` — indica si un tamaño/presentación tiene activado
  "Maneja inventario". **No cambia de tipo ni de semántica.** Esta feature no toca su
  lectura ni escritura; solo cambia si el control que lo edita (el interruptor) y su
  contenido asociado (insumos fijos) se **renderizan o no** en el DOM, según
  `inventarioIncluido()`.
- Insumos fijos asociados a un tamaño (receta/recipe lines) — su estructura y
  persistencia no cambian. Cuando la sección está oculta, estos datos permanecen
  almacenados tal cual estaban; el formulario simplemente no ofrece una UI para verlos o
  editarlos mientras el plan no incluya el módulo (FR-005, FR-006).

## Estado derivado (computed, ya existente)

- `inventarioIncluido = computed(() => summary !== null && summary.modules.inventario && !summary.vencido)`
  (`product-form.component.ts:664-671`) — booleano derivado, no persistido. Esta feature
  reutiliza este computed existente como condición de visibilidad de la sección 3
  "Inventario" y del botón de salto `goToInventory`, sin alterar su definición.
- `sectionsEnabled = computed(() => draft().tracks_inventory && inventarioIncluido())`
  (`product-form.component.ts:679-683`) — sin cambios; sigue gateando únicamente los
  sub-campos de inventario dentro de "Sabores a elegir" (fuera de alcance de este spec).

## Validación

No se definen nuevas reglas de validación. Las reglas de negocio de esta feature son
puramente de visibilidad (Functional Requirements FR-001 a FR-007 del spec), no de
integridad de datos.

## Transiciones de estado

No aplica state machine nueva. La única "transición" relevante es la del valor de
`summary.modules.inventario` entre `true`/`false` a través del tiempo (cambios de plan del
tenant), ya modelada y gestionada por `PlanSummaryService`/`BootstrapService`. Esta feature
no añade transiciones; solo reacciona a ese valor ya existente al decidir qué renderizar.
