# Research: Mostrar presentación elegida en la línea del ítem de la orden manual

No quedaron `NEEDS CLARIFICATION` en el Technical Context del plan (bug acotado dentro de un repo frontend ya conocido). Este documento consolida las decisiones de diseño técnico tomadas a partir de la exploración del código existente en `../pos-heladeria`.

## Decisión 1 — Dónde está la causa raíz

**Decisión**: El defecto se corrige en `PosTerminalStore.cartView()` (`pos-heladeria/src/app/modules/tables/services/pos-terminal.store.ts`), específicamente en el mapeo de `draftLines()` (líneas aún no guardadas) dentro de ese `computed`, que hoy construye `name: l.product.name` sin leer `l.variant.name`.

**Rationale**: El objeto `ProductDraftLine` ya incluye la `MenuVariant` completa (`id`, `name`, `price`, `discounted_price`) desde el momento en que `ProductSelectComponent.confirm()` emite la selección y `addDraftFromSelection()` la guarda en el signal `draftLines`. El precio mostrado ya es correcto porque usa `l.unitPrice`/`l.variant.price`, confirmando que el dato no se pierde en la captura ni en el store — se pierde únicamente en la proyección de solo-lectura que arma `cartView()` para las líneas de borrador. Las líneas ya persistidas, en cambio, sí combinan producto + variante mediante `menu-lookup.ts::variantLabel()`.

**Alternatives considered**:
- Modificar `ProductDraftLine` para agregar un campo `displayName` precalculado en el momento de `addDraftFromSelection()`: descartado porque duplicaría lógica de formato (la de `variantLabel()`) en dos sitios y podría desincronizarse si cambia el criterio de cuándo mostrar la variante.
- Resolver el nombre a mostrar directamente en la plantilla de cada componente (`manual-order-page.component.ts`, `pos-order-panel.component.ts`) en lugar de en el store: descartado porque obligaría a repetir la misma lógica de combinación en cada consumidor de `cartView()`, cuando el store ya es el punto único de verdad para la fila de visualización.

## Decisión 2 — Formato del texto combinado (reutilizar `variantLabel()` existente)

**Decisión**: Las líneas de borrador usarán el mismo helper `menu-lookup.ts::variantLabel(productId, variantId)` (o la función equivalente ya usada por `persistedItemsView()`) para construir el campo `name` combinado ("Producto · Variante"), en lugar de inventar un formato nuevo.

**Rationale**: `variantLabel()` ya encapsula la regla de negocio implícita "solo anteponer el nombre de la variante cuando el producto tiene más de una presentación configurada" (`product.variants.length > 1`), que es exactamente el comportamiento esperado por FR-003 del spec (productos sin presentaciones configuradas no deben mostrar texto de presentación). Reutilizar el helper hace que las líneas de borrador y las persistidas sean indistinguibles en formato, y automáticamente "activa" el marcado `splitVariantLabel()` + pill que `pos-order-panel.component.ts` ya tiene implementado pero que hoy queda vacío para ítems recién agregados (causa raíz de que FR-007 no se cumpla todavía).

**Alternatives considered**:
- Agregar un campo nuevo y explícito `variantName: string | null` a la fila de `cartView()`, en vez de seguir combinando en un solo string `name` + parseo posterior con `splitVariantLabel()`: es el patrón más limpio a largo plazo (es el que ya usa `dining-cart.service.ts` → `CartLine.variantName` para el carrito del comensal) pero se descarta para esta corrección puntual porque exigiría también reescribir el consumo en `pos-order-panel.component.ts` (que ya depende del string combinado + `splitVariantLabel()`), ampliando el alcance más allá del defecto reportado. Se documenta como mejora técnica futura, no incluida en este spec (Principio V de la constitución: no mezclar refactorizaciones no solicitadas).

**Nota de implementación (revisión durante `/speckit-implement`, tareas T004-T011)**: la idea original de esta decisión —llamar a `lk.variantLabel(l.variant.id)`, el mismo helper que ya usan las líneas persistidas— se descartó al escribir los tests. `lk` sale de `buildMenuLookup(this.menuService.categories())`, un signal que en la mayoría de los tests existentes (y potencialmente en producción, justo después de agregar un producto antes de que el índice del menú termine de reconstruirse) puede no tener todavía indexada la variante recién elegida; en ese caso `variantLabel()` cae a su fallback genérico `'Producto'`, lo que habría reemplazado un nombre de producto que hoy SÍ se muestra correctamente por uno peor — una regresión nueva, no solo "presentación ausente". La implementación final construye el mismo formato "Producto · Variante" (mismo umbral `> 1` que `menu-lookup.ts::indexVariants()`) directamente desde los datos que el propio `ProductDraftLine` ya trae completos (`l.product.variants.length`, `l.product.name`, `l.variant.name`), sin depender de `lk` en absoluto para las líneas de borrador. Se verificó en rojo contra el código original (revirtiendo el cambio, 3 de 4 tests nuevos fallaban) y en verde tras aplicarlo.

## Decisión 3 — Marcado visual en `manual-order-page.component.ts`

**Decisión**: Agregar a `manual-order-page.component.ts` (fila de escritorio y tarjeta móvil) el mismo patrón ya usado en `pos-order-panel.component.ts`: llamar a `splitVariantLabel(it.name)` y, si `parts.variant` existe, renderizar un pill con las mismas clases Tailwind (`bg-[#f3f4f6] text-[#4b5563] text-[10px] font-semibold px-1.5 py-0.5 rounded-full`) inmediatamente después del nombre del producto en negrita.

**Rationale**: Mantiene consistencia visual entre las dos pantallas donde un cajero/mesero puede ver la línea de un ítem (carrito de orden nueva y panel de orden ya creada), sin inventar un componente o estilo nuevo. Satisface FR-001, FR-002, FR-005 y FR-006 del spec.

**Alternatives considered**:
- Extraer un componente Angular compartido `<app-cart-item-name>` que encapsule nombre + pill de presentación, usado por ambos componentes: se descarta por alcance (Principio V/VI de la constitución — evitar refactorizaciones no necesarias para esta corrección); queda anotado como posible mejora futura si se detecta más duplicación.

## Decisión 4 — Alcance de verificación (tests)

**Decisión**: Actualizar/añadir casos en `pos-terminal.store.spec.ts` (que `cartView()` incluye la variante para líneas de borrador cuando el producto tiene >1 presentación, y que la omite cuando tiene solo 1), en `manual-order-page.component.spec.ts` (que el pill se renderiza en la fila de escritorio y en la tarjeta móvil) y en `pos-order-panel.component.spec.ts` (que el pill ya no queda vacío para un ítem recién agregado sin guardar).

**Rationale**: Cumple el Principio X (Verificación Obligatoria) de la constitución con la granularidad mínima necesaria: un test de store que fija la causa raíz, y un test de UI por cada pantalla afectada que fija el efecto visible.

**Nota operativa**: `pos-order-panel.component.spec.ts` es uno de los 6 archivos con fallas preexistentes conocidas en la baseline de `pos-heladeria` (no relacionadas con este cambio, documentadas en memoria de sesión previa). Al tocar este archivo, verificar que el conjunto de fallas preexistentes (no el conteo total) se mantenga igual o se reduzca, nunca que se le atribuyan nuevas fallas no relacionadas a este fix.

**Alternatives considered**: Ninguna — la verificación mediante tests unitarios existentes extendidos es el patrón ya establecido en el repo para este tipo de cambio de UI.
