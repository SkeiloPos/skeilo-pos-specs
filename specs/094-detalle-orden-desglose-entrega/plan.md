# Implementation Plan: Desglose Económico y Datos de Entrega en el Detalle de Orden

**Branch**: la spec vive en `specs/094-detalle-orden-desglose-entrega/` de `pos-specs`, rama `main`. Las ramas de código son `feat/094-order-detail-billing-breakdown` en `pos-backend` y en `pos-heladeria` (Principio XIV) | **Date**: 2026-10-03 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/094-detalle-orden-desglose-entrega/spec.md`

## Summary

El Detalle de Orden (`/dashboard/orders/:id`, **una sola pantalla** para Administración,
Caja y Mesero) pasa de mostrar solo cantidad y nombre a mostrar el desglose económico
completo del pedido, el tipo de pedido en el encabezado y, en los domicilios, un bloque de
datos de entrega con copiado al portapapeles.

El enfoque técnico tiene un centro de gravedad: **el servidor entrega el desglose ya
decidido**. `GET /orders/{id}` gana un objeto `billing` que resuelve en un solo sitio las
tres preguntas que la spec deja abiertas al implementador — de dónde salen los importes
(factura 1:1 o pedido), cuánto vale cada fila, y cuál de los tres avisos corresponde. La
pantalla no suma, no resta y no bifurca: pinta. Eso es lo que exigen FR-024b y RN-001, y es
lo que hace que la igualdad con el módulo de Ventas se cumpla por construcción en vez de por
coincidencia de dos cálculos.

El frontend es, en consecuencia, casi todo reuso: `BillSummaryComponent` para el resumen
(con un input aditivo para el nombre de la promoción), `formatMoney` para el formato,
`orderTypeLabel` para el encabezado, `kitchenStatusLabel` para los ítems anulados, y el
patrón de portapapeles + `ToastService` ya probado en el checkout del comensal. **Cero
dependencias nuevas, cero columnas nuevas, cero migraciones, cero escrituras.**

## Technical Context

**Language/Version**: Python 3.14 (backend, FastAPI) · TypeScript 5.9 con Angular 21.1
(frontend: componentes standalone, signals, control flow `@if`/`@for`).

**Primary Dependencies**: `fastapi` 0.136 + `pydantic` 2.13 + SQLAlchemy (ORM declarativo con
`Mapped[...]`) en `pos-backend`; `@angular/core` 21.1 y Tailwind CSS en `pos-heladeria`.
**Ninguna dependencia nueva** (Principio IX satisfecho por ausencia): el portapapeles es API
nativa del navegador, ya en producción en `transfer-details-step.component.ts`.

**Storage**: PostgreSQL 16, schema-per-tenant. **Solo lectura, y sin cambios de esquema**:
se leen `tenant.customer_orders`, `tenant.order_items` y `tenant.sales`, todas con las
columnas que ya existen. No hay migración, no hay relleno retroactivo y no hay escritura —
ver [data-model.md](./data-model.md).

**Testing**: `unittest` sobre SQLite en memoria en `pos-backend`
(`env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'`,
invocando las funciones de endpoint como funciones Python, patrón de
`test_orders_pagination.py`) · Vitest 4 + `TestBed` vía `npm test` en `pos-heladeria`, con
un `*.component.spec.ts` hermano por componente.

**Target Platform**: navegador de escritorio del dashboard de staff (Chrome/Firefox), tras
`roleGuard([ADMIN, CASHIER, MESERO])`. La pantalla también se abre desde tablet en el
mostrador.

**Project Type**: aplicación web — API FastAPI (`pos-backend`) + frontend Angular
(`pos-heladeria`). **Cambian los dos**, de forma independiente y desacoplada: el backend es
aditivo y el frontend tolera su ausencia (D15).

**Performance Goals**: el detalle añade **dos consultas constantes** como máximo (la
existencia de venta propia, que ya se hacía para `paid`, y la de venta de la sesión). El
número de sentencias SQL por petición **no depende del número de ítems**: la verificación de
esa guardia es un test, igual que en `test_orders_pagination.py`. El listado de pedidos no
gana ni una consulta (D3).

**Constraints**:
- Ningún importe se recalcula contra el catálogo ni contra las promociones vigentes
  (RN-001, FR-022).
- La suma de los importes de línea visibles MUST ser exactamente el Subtotal mostrado, y
  `Subtotal − Descuento + Envío` MUST ser exactamente el Total (FR-005, FR-008, SC-007).
- La elección entre leer la factura y leer el pedido MUST resolverse en el servidor
  (FR-024b).
- Lo vacío no se pinta: ni "null", ni "undefined", ni guion de relleno, ni en pantalla ni en
  el texto copiado (FR-020, RN-003).
- Los tres roles ven exactamente el mismo contenido (RN-007).
- Tres textos de aviso y uno de confirmación son **literales fijados por la spec**, no
  parafraseables (FR-017, FR-018, FR-023, FR-024a).

**Scale/Scope**: 1 pantalla enriquecida, 1 componente compartido con un input aditivo,
1 endpoint con tres campos nuevos. Aproximadamente 4 archivos de producción y 2 de test en
`pos-backend`; 4 de producción y 2 de test en `pos-heladeria`. Cero archivos de migración.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Estado | Evidencia |
|-----------|--------|-----------|
| **I** — Las nuevas funcionalidades nacen de un spec | ✅ PASA | `spec.md` con 4 historias, 29 FR, 7 RN, 7 SC, impacto sobre funcionalidades y datos, decisiones de compatibilidad y trazabilidad de los 14 criterios del brief. Validada con `checklists/requirements.md`, sin ítems abiertos. |
| **II** — El comportamiento existente sigue protegido | ✅ PASA | Tres comportamientos existentes cambian, los tres exigidos por la spec y documentados en ella: la etiqueta "Comensal" → "Cliente" (FR-013), el encabezado "Mesa"/"Mostrador" → tipo de pedido (FR-012, problema 3), y el `OrderResponse` que gana tres campos. El cuarto cambio tocado, el input nuevo de `BillSummaryComponent`, es **aditivo y con valor por defecto**: las cuatro pantallas que ya lo consumen no cambian ni un píxel (D10). Las decisiones de negocio están registradas como **A-104 a A-107** en `specs/000-reconocimiento/registro-de-anomalias.md`. |
| **III** — Los characterization tests protegen el comportamiento heredado | ✅ PASA | Ningún test `"CONGELA comportamiento actual:"` se toca. Los de `test_orders_checkout.py` y `test_table_sessions_service.py`, que congelan cómo se escriben `customer_order_id`, `discount` y `applied_promotions` en el cobro, son precisamente el contrato del que D2 y D4 derivan la lectura: se apoyan en ellos, no los modifican. |
| **IV** — Los nuevos specs pueden introducir nuevo comportamiento | ✅ PASA | El desglose, el bloque de entrega y el copiado son comportamiento nuevo autorizado por FR-001 a FR-024b. |
| **V** — Nuevas funcionalidades antes que refactorizaciones oportunistas | ✅ PASA | Ninguna refactorización no pedida. Se evaluaron dos y **se descartaron por este principio**: extraer el patrón de portapapeles a un servicio compartido (D11) y resolver `billing` en bloque para el listado (D3). El único cambio en código compartido es el input de `BillSummaryComponent`, que lo obliga FR-009. |
| **VI** — Evolución incremental | ✅ PASA | Cuatro historias independientes y desplegables en orden: US1 (desglose, incluye el trabajo de backend) → US2 (datos de entrega y copiado, solo frontend) → US3 (huecos de datos) → US4 (etiqueta "Cliente", una línea). US2 y US4 no dependen del backend y pueden entregarse antes si conviene. No se mezcla funcionalidad con refactorización, migración ni cambio de arquitectura. |
| **VII** — Compatibilidad con datos históricos | ✅ PASA | La pantalla es de **solo lectura**: ninguna factura se recalcula, se reemite ni cambia de representación. Al contrario: FR-024 la convierte en la fuente autoritativa del desglose cuando cubre un solo pedido. Los importes mostrados son los congelados (FR-022). |
| **VIII** — Evolución del modelo de datos | ✅ N/A | Cero entidades, campos, relaciones y migraciones; ver [data-model.md](./data-model.md), que documenta el **modelo de lectura** y el rollback (revertir el despliegue, sin dato que reparar). |
| **IX** — Dependencias nuevas con justificación | ✅ PASA | Cero dependencias nuevas, en los dos repositorios (D18). |
| **X** — Verificación obligatoria | ✅ PASA | Tests de contrato en backend para las nueve garantías de [contracts/order-detail-api.md](./contracts/order-detail-api.md) (incluida la guardia de N+1), tests de componente en frontend para los textos literales, el condicionado de filas y el texto copiado, más los recorridos manuales de [quickstart.md](./quickstart.md) para lo que un test no mide: SC-001 (tiempo), SC-002 (igualdad con Ventas en vivo), SC-004 (20 pedidos del histórico) y SC-006 (dos tenants reales). |
| **XI** — Decisiones de negocio frente a decisiones técnicas | ✅ PASA | Separadas y etiquetadas en `research.md`: son **técnicas** D1–D4, D6, D8, D10–D16, D18; son **de negocio ya tomadas** las de la spec (Q1–Q8 / A-104 a A-107); y quedan **tres puntos de confirmación del negocio** explícitos (D2, D5, D7), listados abajo. |
| **XII** — Trazabilidad | ✅ PASA | Cadena completa: brief → `spec.md` (+ A-104 a A-107) → este plan + `research.md` + `data-model.md` + `contracts/` → `tasks.md` → tests → `quickstart.md`. Cada decisión de research cita el FR que la obliga y el archivo de código que la verifica. |
| **XIII** — Todo en español de Colombia | ✅ PASA | Todos los artefactos de esta spec, los comentarios de código nuevo y los nombres de test se escriben en español de Colombia. Los identificadores de API (`billing`, `state`, `sin_factura`) siguen la convención ya establecida en el código, que mezcla inglés estructural con valores de dominio en español (`estado_cocina`, `anulado`, `pagada`). |
| **XIV** — Estrategia y convención de ramas | ✅ PASA | `feat/094-order-detail-billing-breakdown` en los dos repositorios, creada desde la rama en curso **antes** de tocar código. |
| **XV** — Política de commits | ✅ PASA | Ningún commit sin pedido explícito. Cuando se pida: unidades pequeñas (schemas · servicio de facturación · endpoint + tests · interfaces del front · input del resumen · pantalla · copiado), en inglés, Conventional Commits, sin marcas de autoría de IA. |

**Veredicto de la compuerta**: **PASA**, sin violaciones que justificar.

**Tres puntos quedan abiertos a confirmación del negocio** y van a `tasks.md` como tareas
explícitas, no como supuestos silenciosos. Ninguno bloquea el diseño: los tres se
materializan cambiando una condición o un literal, sin rediseñar nada.

1. **D2** — el texto literal de FR-024a dice "se cobró junto con otros en una cuenta
   unificada"; aplicado a un cierre **dividido** describe lo contrario de lo que pasó (un
   pedido repartido en varias facturas). Se usa el mismo texto, porque Q8 lo fijó y porque
   lo accionable ("el total facturado está en Ventas") es cierto en ambos casos. Atenuante
   verificado: el frontend solo envía `billing_mode: 'unified'`, así que el caso dividido
   solo llega de datos históricos.
2. **D5** — impuesto y propina de la factura no se muestran y hoy valen cero en todos los
   caminos de escritura. Si la consulta de verificación de `quickstart.md` §1 encuentra
   ventas históricas con `tax` o `tip` > 0, SC-007 no se cumple para esas filas y hay que
   decidir qué mostrar **antes** de implementar.
3. **D7** — el aviso de FR-023 se suprime en pedidos cancelados, porque prometer que "el
   total aún puede cambiar" en un pedido terminal es afirmar algo falso. La spec no lo
   enuncia; se deriva de su intención y de US1 §5.

**Re-evaluación post-Phase 1**: sin cambios. El diseño no introdujo ninguna violación nueva:
no apareció ninguna dependencia, el modelo de datos persistido sigue intacto, el contrato de
API es estrictamente aditivo y el único archivo compartido que se toca
(`bill-summary.component.ts`) cambia con un input por defecto que no altera a sus
consumidores. "Complexity Tracking" queda vacío.

## Project Structure

### Documentation (this feature)

```text
specs/094-detalle-orden-desglose-entrega/
├── spec.md                          # Especificación funcional (ya existente)
├── plan.md                          # Este archivo (salida de /speckit-plan)
├── research.md                      # Fase 0 — D1 a D18
├── data-model.md                    # Fase 1 — modelo de lectura; cero cambios persistidos
├── quickstart.md                    # Fase 1 — guía de validación ejecutable
├── contracts/
│   ├── order-detail-api.md          # Contrato de GET /orders/{id} con `billing`
│   └── order-detail-screen.md       # Contrato de la pantalla y sus textos literales
├── checklists/
│   └── requirements.md              # Validación de calidad de la spec (ya existente)
└── tasks.md                         # Fase 2 — la crea /speckit-tasks, NO este comando
```

### Source Code (repository root)

```text
pos-backend/                                      # rama feat/094-order-detail-billing-breakdown
├── app/
│   ├── api/v1/orders/
│   │   ├── schemas.py                            # + AppliedPromotionOut, OrderBillingSummary;
│   │   │                                         #   + discount, applied_promotions, billing en OrderResponse
│   │   ├── service.py                            # + build_billing_summary(db, order) y sus auxiliares
│   │   └── router.py                             # _load_order asigna order.billing (solo el detalle)
│   └── characterization_tests/
│       ├── test_orders_billing_summary.py        # NUEVO — garantías G1..G9 del contrato
│       └── orders_fixtures.py                    # reuso; se extiende solo si falta algún armador
└── (sin alembic/versions/ — no hay migración)

pos-heladeria/                                    # rama feat/094-order-detail-billing-breakdown
└── src/app/
    ├── modules/
    │   ├── orders/pages/
    │   │   ├── order-detail.component.ts         # encabezado, importes por línea, resumen,
    │   │   │                                     #   avisos, bloque de entrega y copiado
    │   │   └── order-detail.component.spec.ts    # amplía los tests existentes
    │   └── tables/
    │       ├── components/bill-summary.component.ts   # + @Input() discountLabel = 'Descuento'
    │       └── interfaces/dining.interface.ts         # + billing, discount, applied_promotions (opcionales)
    └── shared/
        ├── money.ts                              # se usa tal cual (no se toca)
        └── feedback/toast.service.ts             # se usa tal cual (no se toca)
```

**Structure Decision**: aplicación web con backend y frontend en repositorios separados, que
es la estructura ya establecida del proyecto (Alcance del Proyecto en la constitución). No se
crea ningún módulo, carpeta ni capa nueva: el trabajo de backend cabe en los tres archivos
que ya atienden `GET /orders/{id}`, y el de frontend en la pantalla que ya existe más dos
archivos compartidos tocados de forma aditiva. La lógica de desglose vive en
`orders/service.py` y no en el router, siguiendo la separación que ya usan
`order_has_sale` y `staff_user_names`.

## Complexity Tracking

> No aplica: la Constitution Check pasa sin violaciones.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| — | — | — |
