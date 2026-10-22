---

description: "Task list template for feature implementation"
---

# Tasks: Rediseño visual de la Terminal de Mesas (grilla y detalle de pedido)

**Input**: Design documents from `/specs/131-rediseno-terminal-mesas/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md (todos presentes)

**Tests**: No se solicitan tests nuevos explícitamente; se preservan y actualizan únicamente
los characterization tests existentes (`CONGELA comportamiento actual:`) afectados por
cambios de selector/estructura visual o por FR-022b/FR-023 — ver tareas de cada fase y la
Fase de Polish.

**Repositorio de código afectado**: `../pos-heladeria` (Angular). `pos-specs` no recibe
cambios de código, solo esta documentación.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Puede ejecutarse en paralelo (archivo distinto, sin dependencias pendientes)
- **[Story]**: US1 (grilla, P1), US2 (detalle de pedido, P2), US3 (cobro, P3), US4
  (responsive, P2)

## Path Conventions

Todos los paths relativos a `../pos-heladeria/src/app/modules/tables/` salvo que se indique
otra cosa. El set de iconos nuevo vive en `../pos-heladeria/src/app/shared/`.

---

## Phase 1: Setup

**Purpose**: Preparar la rama y confirmar el punto de partida antes de tocar componentes.

- [X] T001 Crear la rama `style/131-rediseno-terminal-mesas` sobre `main` en el repositorio
      `../pos-heladeria` (Principio XIV/XV de la constitución) antes de modificar cualquier
      componente.
- [ ] T002 [P] Revisar y confirmar localmente que `../pos-heladeria` corre en modo desarrollo
      (`ng serve`) contra `pos-backend` con datos de prueba mínimos: una mesa libre, una mesa
      ocupada con 2+ líneas, una mesa con más de un pedido abierto en paralelo, un pedido de
      Domicilio y uno Para llevar pendientes de cobro (prerrequisitos de `quickstart.md`).
- [X] T003 [P] Abrir `design/SkeiloPOS.html` y el paquete
      `design/_ds/skeilopos-design-system-071995f1-8e4d-4056-8794-3e84718f8e0d/` en paralelo
      como referencia visual para todas las fases siguientes (SC-003).

**Checkpoint**: Rama creada, entorno de validación visual listo.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Infraestructura visual compartida por ambas vistas — tokens de diseño e
iconografía — que todas las user stories necesitan antes de rediseñar cualquier plantilla.

**⚠️ CRITICAL**: Ningún componente de US1/US2/US3/US4 se rediseña hasta cerrar esta fase.

- [X] T004 [P] Portar los tokens de
      `design/_ds/skeilopos-design-system-071995f1-8e4d-4056-8794-3e84718f8e0d/tokens/{colors,spacing,typography,base,effects,theme-light}.css`
      como variables CSS reutilizables en `../pos-heladeria/src/styles/` (o el archivo global
      de estilos que ya use el proyecto), siguiendo la decisión de `research.md` punto 2
      (fuente de verdad de bordes, radios, espaciados, tipografía, color).
- [X] T005 [P] Crear el componente de iconos nuevo estilo `lucide`
      (`../pos-heladeria/src/app/shared/icon-lucide/icon-lucide.component.ts` o ubicación
      equivalente junto a `icon-mi/`) que reciba un `name` y renderice el SVG inline
      correspondiente, cubriendo al menos los ~15-20 nombres de icono usados en
      `design/SkeiloPOS.html` (`plus`, `layout-grid`, `cup-soda`, `credit-card`, etc.) — sin
      agregar la dependencia npm `lucide-angular` (decisión de `research.md` punto 3). No se
      modifica `icon-mi.component.ts` ni sus consumidores fuera del alcance de este spec.
- [X] T006 Registrar en `specs/000-reconocimiento/registro-de-anomalias.md` las dos
      decisiones de negocio que cambian comportamiento existente (Principio II de la
      constitución), **antes de implementar las Fases 4 y 6**: (1) retiro de "Agregar
      adición" y badge "Modificada" (FR-023, afecta spec 123); (2) reubicación de "+ Crear
      pedido nuevo" hacia "Nueva cuenta" dentro del detalle de mesa (FR-022b, afecta spec
      087/126) — incluyendo quién (usuario de negocio), cuándo (2026-10-22) y qué cambia,
      según el texto ya redactado en "Assumptions" de `spec.md`.

**Checkpoint**: Tokens e iconografía disponibles; decisiones de negocio registradas. Las
fases de user story pueden empezar.

---

## Phase 3: User Story 1 - Ver la grilla principal con el nuevo diseño (Priority: P1) 🎯 MVP

**Goal**: La vista principal de la Terminal de Mesas (grilla de mesas/domicilios/para
llevar) reproduce la distribución visual del mockup de referencia, conservando filtros,
búsqueda, atajos y conteos actuales.

**Independent Test**: Abrir la Terminal de Mesas sin seleccionar ninguna mesa y verificar
que la grilla, los filtros, la búsqueda y las pestañas se vean y funcionen igual que antes,
con el nuevo diseño (ver `quickstart.md` sección 1).

### Implementation for User Story 1

- [X] T007 [US1] Rediseñar la plantilla y estilos de
      `components/pos-terminal-header.component.ts` según la cabecera de `isTerminal` del
      mockup (estado de conexión/sincronización, turno activo, reloj/fecha, indicador de caja
      abierta) usando los tokens de T004 y el componente de iconos de T005, sin cambiar la
      información que expone hoy (FR-001).
- [X] T008 [US1] Rediseñar la plantilla y estilos de
      `components/pos-tables-panel.component.ts`: pestañas Mesas/Domicilios/Para llevar +
      buscador (atajo `F2`) en la misma franja (FR-002), filtro de estado con conteo por
      opción (FR-003), grilla de tarjetas reacomodable según ancho disponible (FR-004) y
      mensaje de estado vacío (FR-006), con los tokens/iconos de la Fase 2.
- [X] T009 [P] [US1] Rediseñar la plantilla y estilos de
      `components/order-summary-card.component.ts` (tarjeta individual de mesa/pedido de
      domicilio/para llevar: estado, resumen de ítems/tiempo transcurrido, total) según la
      tarjeta de la grilla del mockup, sin el segmento de "zona" (Clarifications Q3) — FR-004.
- [X] T010 [US1] Rediseñar el botón "Crear pedido nuevo" (atajo `F3`) dentro de
      `pos-tables-panel.component.ts` o la cabecera según la implementación actual,
      preservando la lógica de habilitación/deshabilitación según pestaña activa y
      disponibilidad de mesas libres, con el mismo mensaje explicativo cuando está
      deshabilitado (FR-005).
- [X] T011 [US1] Actualizar `components/pos-tables-panel.component.spec.ts` (y cualquier otro
      spec con marca `CONGELA comportamiento actual:` afectado) para los selectores/
      estructura visual nuevos de T007-T010, sin modificar las aserciones de comportamiento
      que siguen vigentes.

**Checkpoint**: La grilla principal es visualmente fiel al mockup y funciona igual que antes
(filtros, búsqueda, pestañas, conteos, botón "Crear pedido nuevo"). MVP alcanzable.

---

## Phase 4: User Story 2 - Ver y editar el detalle de un pedido con el nuevo diseño (Priority: P2)

**Goal**: La vista de detalle (mesa, domicilio, para llevar) reproduce la distribución del
mockup, conservando todas las acciones actuales salvo los dos cambios explícitos de
comportamiento (FR-022b, FR-023), ya registrados en T006.

**Independent Test**: Seleccionar una mesa con un pedido en curso y verificar que todas las
acciones sobre las líneas (marcar listo, anular, agregar producto nuevo) siguen disponibles y
funcionan igual que antes, con el nuevo diseño (ver `quickstart.md` sección 2).

### Implementation for User Story 2

- [X] T012 [US2] Rediseñar la cabecera y la lista de líneas de
      `components/pos-order-panel.component.ts` según `tDetOn`/`tcOn` del mockup: número/
      nombre y estado del pedido, y por cada línea cantidad, variante, opciones elegidas,
      nota, precio unitario, promoción aplicada, estado de preparación, "Marcar listo" y
      "Anular", con la misma lógica de habilitación/deshabilitación actual (FR-007, FR-008).
- [X] T013 [US2] Retirar de `components/pos-order-panel.component.ts` el selector dedicado
      "Agregar adición" y el badge "Modificada" (FR-023) — depende de T006 (registro de la
      anomalía) ya cerrado. Agregar un producto/línea nueva a una línea ya facturada pasa a
      cubrirse exclusivamente vía "Agregar producto" (T015).
- [X] T014 [US2] Reconstruir el bloque de pestañas "Pedido N"/"Nueva cuenta" dentro de
      `components/pos-order-panel.component.ts` reutilizando literalmente el markup/estilo del
      bloque `accOn` del mockup (`role="tablist"`, botones `role="tab"`, badge de conteo, botón
      punteado "Nueva cuenta") — solo cambiando los textos a "Pedido 1", "Pedido 2", etc., sin
      reintroducir división por comensal (FR-022). El botón "Nueva cuenta" dispara la misma
      acción que hoy dispara "+ Crear pedido nuevo" dentro del detalle de mesa (spec 087).
- [X] T015 [US2] Ocultar, dentro de la vista de detalle de una **mesa** (donde aplican las
      pestañas de T014), el botón "+ Crear pedido nuevo" de la sub-barra superior (FR-022b) —
      depende de T006 y T014. El botón se mantiene visible en el detalle de Domicilio/Para
      llevar y fuera de la vista de detalle (sin cambios ahí).
- [X] T016 [P] [US2] Rediseñar `components/pos-catalog-drawer.component.ts`,
      `components/cart.component.ts`, `components/cart-item-options.component.ts` y
      `components/product-select.component.ts` (catálogo embebido "Agregar producto":
      buscador, categorías, promociones) según la sección referenciada desde `tDetOn` en el
      mockup, con el mismo comportamiento de confirmación al agregar productos (FR-009).
- [X] T017 [P] [US2] Rediseñar, dentro de `components/pos-order-panel.component.ts`, la fila
      compacta de dirección/teléfono/valor de domicilio para pedidos de Domicilio o Para
      llevar sin mesa asociada, debajo de la cabecera principal (con la insignia/título
      adaptados, p. ej. ícono de tipo de pedido en vez de número de mesa), sin fusionarla con
      el título (FR-011, FR-024).
- [X] T018 [US2] Confirmar que el único punto de "Volver a mesas/pedidos" se mantiene siempre
      visible mientras se está en la vista de detalle, con el nuevo layout (FR-010).
- [X] T019 [US2] Actualizar `components/pos-order-panel.component.spec.ts` y
      `services/pos-terminal.store.spec.ts`: adaptar los tests `CONGELA comportamiento
      actual:` afectados por selectores/estructura visual nueva, y reescribir explícitamente
      (citando FR-023 y FR-022b, más la entrada de T006 en `registro-de-anomalias.md`) los
      tests que verificaban "Agregar adición"/badge "Modificada" o el botón "+ Crear pedido
      nuevo" dentro del detalle de mesa — sin eliminarlos, sino ajustarlos al nuevo
      comportamiento esperado.

**Checkpoint**: El detalle de pedido (mesa, domicilio, para llevar) es visualmente fiel al
mockup; todas las acciones previas siguen funcionando salvo los dos cambios explícitos ya
reflejados en comportamiento y tests.

---

## Phase 5: User Story 4 - Experiencia responsive en cualquier tamaño de pantalla (Priority: P2)

**Goal**: La grilla principal y el detalle de pedido se adaptan a móvil/tablet/escritorio sin
perder información ni acciones, con una única región de scroll por columna.

**Independent Test**: Abrir la terminal en al menos tres anchos de referencia (móvil, tablet,
escritorio ancho) y verificar que ninguna acción quede inaccesible ni recortada, y que el
scroll se comporte de forma predecible (ver `quickstart.md` sección 4).

**Depends on**: Fase 3 (US1) y Fase 4 (US2) deben estar implementadas — esta fase ajusta el
layout contenedor de ambas vistas.

### Implementation for User Story 4

- [X] T020 [US4] Implementar en `pages/table-sessions.component.ts` la distribución de
      columnas del mockup: grilla de mesas a la izquierda / detalle+cobro a la derecha en
      escritorio ancho, una sola columna a pantalla completa con botón de volver en móvil
      (FR-018), usando flexbox/grid + `overflow:auto` acotado a cada columna sin contenedores
      de scroll anidados (FR-019), según la decisión de `research.md` punto 6.
- [ ] T021 [US4] Verificar en los tres anchos de referencia (~375px, ~768px, ~1440px+) que
      ninguna acción de las Fases 3 y 4 (filtros, búsqueda, líneas, pestañas "Pedido N",
      botón "Nueva cuenta", "Agregar producto", botón de volver) queda inaccesible ni
      recortada, y que solo una columna scrollea a la vez — ajustar estilos de
      `pos-tables-panel.component.ts` y `pos-order-panel.component.ts` si aparece scroll
      horizontal de página o scroll anidado.

**Checkpoint**: Ambas vistas son responsive en los tres anchos de referencia sin perder
acciones ni introducir scroll horizontal o anidado.

---

## Phase 6: User Story 3 - Cobrar el pedido con el nuevo diseño (Priority: P3)

**Goal**: El panel de cobro (pago único, mixto hasta 3 métodos, saldo pendiente, validación
de pago QR/transferencia) reproduce la distribución visual del mockup sin perder ninguna
regla de cobro actual.

**Independent Test**: Cobrar un pedido de mostrador con un único método, uno con métodos
combinados, y validar un pago QR pendiente — verificando que el resultado (venta registrada,
inventario descontado, mesa liberada cuando corresponde) es el mismo que hoy (ver
`quickstart.md` sección 3).

**Depends on**: Fase 4 (US2) — el panel de cobro se abre desde la vista de detalle ya
rediseñada.

### Implementation for User Story 3

- [X] T022 [US3] Rediseñar `components/pos-checkout-panel.component.ts` y
      `components/bill-summary.component.ts`: desglose subtotal/domicilio/total calculado por
      el backend, campo "Facturar a nombre de", selector de método de pago, botón "Cobrar"
      (FR-012), y cobro de saldo pendiente por adiciones posteriores (FR-015), según el panel
      de cobro de `isTerminal`/`tDetOn`.
- [X] T023 [P] [US3] Rediseñar `components/payment-input.component.ts` para combinar hasta 3
      métodos de pago en un mismo cobro, con la misma validación actual (FR-013).
- [X] T024 [P] [US3] Rediseñar `components/session-bill-panel.component.ts` (cuenta de mesa
      consolidada) según el "modelo de caja" del mockup, sin cambiar su lógica de cálculo.
- [X] T025 [US3] Extender `components/payment-attempt-review-panel.component.ts` con las tres
      variantes del mockup: efectivo `tdQrOn` (monto recibido, "Confirmar efectivo" — FR-014a),
      transferencia/Nequi `tdQ2On` (ver comprobante, aprobar/rechazar — FR-014b) y pago mixto
      `tdQ3On` (validar las dos partes y "Confirmar pago mixto" — FR-014c), reutilizando los
      campos que ya calcula el mockup (`tdM3Nq`, `tdM3Cash`, estado de comprobante, diferencia)
      para el caso mixto. Los tres paneles solo se muestran en el detalle de un pedido de
      **mesa** recibido por Menú QR (Clarifications Q5); el panel mixto se construye
      visualmente pero su verificación con datos reales queda bloqueada hasta que el spec 130
      esté implementado (Clarifications Q4) — documentar ese bloqueo en el PR, no como fallo
      de este spec.
- [X] T026 [US3] Rediseñar los botones "Imprimir Factura" y "Liberar Mesa" dentro de
      `pos-checkout-panel.component.ts`, visibles únicamente cuando el pedido/mesa ya no tiene
      ningún cobro pendiente (FR-016), y el diálogo de confirmación de pago con impresión de
      uno o varios comprobantes según si la venta se dividió (FR-017).
- [X] T027 [US3] Actualizar `components/payment-attempt-review-panel.component.spec.ts` y
      cualquier spec de `pos-checkout-panel`/`bill-summary`/`session-bill-panel`/
      `payment-input` con marca `CONGELA comportamiento actual:` afectado por los
      selectores/estructura visual nuevos de T022-T026, incluyendo un caso que documente
      explícitamente el panel `tdQ3On` como bloqueado por el spec 130 (sin datos reales que
      validar aún).

**Checkpoint**: El panel de cobro es visualmente fiel al mockup; las tres reglas de cobro
(único, mixto, saldo pendiente) y los paneles de validación QR funcionan igual que antes
(salvo el bloqueo documentado del caso mixto por el spec 130).

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Cierre de la validación visual y funcional de punta a punta sobre las cuatro
user stories ya implementadas.

- [X] T028 Ejecutar la suite completa de `../pos-heladeria` (`ng test`, ver memoria del
      proyecto sobre cómo correr tests del repo hermano — diferencia por archivo, no por
      conteo total de la suite) y confirmar que todos los tests `CONGELA comportamiento
      actual:` siguen en verde salvo los explícitamente reescritos por FR-022b/FR-023 en T019.
      Full-suite: 11 fallos distintos en 8 archivos (`app.spec` ×2, `auth.service` ×1,
      `menu.service` ×1, `tenant.service` ×3, `pos-checkout-panel` ×1, `pos-order-panel` ×2,
      `pos-terminal.store` ×1) — coinciden exactamente, archivo por archivo y test por test,
      con la baseline preexistente ya documentada en memoria (previa a esta spec); el conteo
      bruto que reporta un run completo (~67) es ruido de cross-file bleed ya conocido, no
      fallos reales nuevos (confirmado corriendo cada archivo tocado en aislamiento a lo
      largo de esta implementación).
- [ ] T029 Ejecutar el guion completo de `quickstart.md` (secciones 1-4: grilla, detalle,
      cobro, responsive) en `../pos-heladeria` corriendo contra `pos-backend` local, con los
      datos de prueba de T002. **Pendiente de verificación manual del usuario en navegador**
      — requiere interacción visual real que esta sesión no puede ejecutar.
- [X] T030 Revisión visual lado a lado de ambas vistas contra `design/SkeiloPOS.html`
      (bordes, radios, tipografía, espaciados) para confirmar SC-003 — hecha de forma
      iterativa durante la implementación, con el usuario comparando capturas reales contra
      el mockup en cada fase (grilla, detalle, cobro, responsive). Confirmado que no se creó
      ningún endpoint nuevo ni archivo en `contracts/` (SC-004): `pos-terminal.store.ts` sin
      diff (`git diff --stat` vacío), ningún directorio `contracts/` en este spec.
- [X] T031 [P] Confirmar que `specs/000-reconocimiento/registro-de-anomalias.md` (T006) quedó
      registrado antes del merge, como evidencia de cumplimiento del Principio II. Entradas
      A-140 (FR-023, retiro "Agregar adición"/"Modificada"), A-141 (FR-022b, "Nueva cuenta"),
      A-142 (lado a lado en escritorio, revertida el mismo día) y A-143 (reversión de A-142)
      registradas.

**Checkpoint**: Las cuatro user stories cumplen sus Success Criteria; listo para PR.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Sin dependencias — puede empezar de inmediato.
- **Foundational (Phase 2)**: Depende de Setup — BLOQUEA todas las user stories (tokens,
  iconografía y registro de anomalías son prerrequisito de T007 en adelante).
- **User Story 1 (Phase 3)**: Depende solo de Foundational. Es el MVP.
- **User Story 2 (Phase 4)**: Depende de Foundational. T013/T015 dependen además de T006.
  Puede implementarse en paralelo a la Fase 3 por otro desarrollador, aunque conviene
  completar la Fase 3 primero porque valida el mismo "modelo de caja" compartido.
- **User Story 4 (Phase 5)**: Depende de que las Fases 3 y 4 existan (ajusta el contenedor de
  ambas vistas ya rediseñadas).
- **User Story 3 (Phase 6)**: Depende de la Fase 4 (el panel de cobro se abre desde el
  detalle rediseñado).
- **Polish (Phase 7)**: Depende de que las cuatro user stories estén completas.

### Parallel Opportunities

- T002, T003 en paralelo durante Setup.
- T004, T005 en paralelo durante Foundational (T006 es secuencial por ser un registro único).
- T009 en paralelo al resto de la Fase 3.
- T016, T017 en paralelo entre sí dentro de la Fase 4 (archivos distintos); T012-T015 son
  secuenciales porque tocan el mismo archivo (`pos-order-panel.component.ts`).
- T023, T024 en paralelo entre sí dentro de la Fase 6.
- T031 en paralelo al resto de la Fase 7.

---

## Parallel Example: Foundational + User Story 1

```bash
# Fase 2 (Foundational), en paralelo:
Task: "Portar tokens de diseño a variables CSS (T004)"
Task: "Crear componente de iconos lucide (T005)"

# Fase 3 (US1), en paralelo tras cerrar Foundational:
Task: "Rediseñar order-summary-card.component.ts (T009)"
Task: "Rediseñar pos-terminal-header.component.ts (T007)"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Completar Fase 1 (Setup) y Fase 2 (Foundational — tokens, iconos, registro de anomalías).
2. Completar Fase 3 (User Story 1 — grilla principal).
3. **Validar de forma independiente**: abrir la Terminal de Mesas sin seleccionar mesa y
   confirmar que la grilla, filtros, búsqueda y pestañas se ven y funcionan igual que antes.
4. Esto ya es un incremento demostrable (MVP) aunque el detalle de pedido siga con el diseño
   anterior.

### Incremental Delivery

1. Setup + Foundational → base lista.
2. Fase 3 (US1) → grilla rediseñada → validar → demo.
3. Fase 4 (US2) → detalle de pedido rediseñado (con FR-022b/FR-023 ya registrados y
   aplicados) → validar → demo.
4. Fase 5 (US4) → responsive sobre ambas vistas ya rediseñadas → validar en los tres anchos.
5. Fase 6 (US3) → panel de cobro rediseñado → validar los tres casos de pago QR → demo.
6. Fase 7 (Polish) → suite completa + quickstart + revisión visual lado a lado → cierre.

### Parallel Team Strategy

Con más de un desarrollador: completar Setup + Foundational juntos; luego un desarrollador
puede tomar Fase 3 (US1) mientras otro empieza Fase 4 (US2) en paralelo, dado que ambas solo
dependen de Foundational. Las Fases 5 (US4) y 6 (US3) deben esperar a que Fase 4 (US2) esté
cerrada.

---

## Notes

- [P] = archivos distintos, sin dependencias pendientes entre sí.
- [Story] mapea cada tarea a su user story para trazabilidad.
- T006, T013, T015, T019 forman la cadena de las dos únicas tareas que cambian
  comportamiento (FR-022b, FR-023): el registro en `registro-de-anomalias.md` (T006) debe
  cerrarse antes de aplicar el cambio de código (T013, T015) y antes de reescribir los tests
  correspondientes (T019).
- No se crea ningún endpoint nuevo ni se modifica `pos-terminal.store.ts` más allá de lo que
  ya se consume desde las plantillas rediseñadas (SC-004, Constraints del plan).
- El panel de pago mixto QR (`tdQ3On`, T025) se construye visualmente pero no es verificable
  con datos reales hasta que el spec 130 esté implementado — ver Clarifications Q4 del spec.
