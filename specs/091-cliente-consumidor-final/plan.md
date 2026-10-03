# Implementation Plan: Cliente "Consumidor final" por defecto en Mesa y Para llevar

**Branch**: `091-cliente-consumidor-final` (rama de la spec en `pos-specs`; las ramas de código de
`pos-backend` y `pos-heladeria` siguen el Principio XIV, ver abajo) | **Date**: 2026-10-01 |
**Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/091-cliente-consumidor-final/spec.md`

## Summary

El campo "Cliente" de "Nueva orden" (Terminal de mesas) vuelve a precargar "Consumidor final" en
las pestañas Mesa y Para llevar — editable, y ya no obligatorio para crear el pedido — revirtiendo
parcialmente la decisión A-88 de la spec 087 (que lo había vuelto obligatorio en los tres tipos).
Domicilio **no cambia**: sigue exigiendo nombre, dirección y valor del domicilio.

Todo lo siguiente sale de leer `pos-backend` y `pos-heladeria` (`develop`, árboles limpios) y las
specs 055/056/087 (research.md, hechos verificados):

1. **Frontend** (`pos-heladeria`): `customerName` es **una sola señal** compartida por las tres
   pestañas (`pos-terminal.store.ts`). La regla de "vacío → Consumidor final" / "Domicilio vacía el
   valor por defecto" se resuelve con una única función del store, evaluada al abrir "Nueva orden"
   (que siempre arma un pedido nuevo, nunca edita uno existente) y en cada cambio de pestaña — sin
   una bandera nueva de "¿editó el campo?": basta comparar el valor actual contra el literal exacto
   (research D2/D3). El bloqueo de "Crear pedido" y el mensaje "El nombre del cliente es
   obligatorio." se acotan a la pestaña Domicilio (D5); se agrega selección de texto completo al
   enfocar el campo en Mesa/Para llevar (D4).
2. **Backend** (`pos-backend`): `orders/service.py::create_order` deja de rechazar `DINE_IN`/
   `TAKEAWAY` sin nombre **solo quando el canal es `POS`** (Terminal) — asigna `"Consumidor final"`
   en su lugar. `WHATSAPP`/`API` (que también pueden crear `TAKEAWAY`, hecho confirmado en el
   código) siguen rechazando sin nombre, igual que `DELIVERY` en cualquier canal (D6) — ningún
   cambio fuera del alcance pedido.
3. **Literal nuevo y separado**: `"Consumidor final"` (f minúscula, el texto exacto de los 10
   escenarios) es un valor distinto de `"Consumidor Final"` (F mayúscula), que ya existe para el
   nombre de la **factura** (`billing_customer_name`) — no se tocan ni se unifican (D1).
4. **Characterization tests a reescribir** (Principio III, autorizado por A-99): dos pruebas de
   backend que hoy afirman el `422` para `POS` sin nombre, y un bloque de cuatro pruebas de
   frontend que afirman "sin valor por defecto, bloqueado sin nombre" — todas inventariadas en
   research.md. Se agrega una prueba nueva (sin precedente hoy) que confirme que `WHATSAPP`/`API`
   siguen rechazando `TAKEAWAY` sin nombre.
5. **Registro (Principio II)**: nueva anomalía **A-99** (borrador en research.md), que debe existir
   antes de mergear el código de esta spec (mismo criterio que A-84/A-98).

Sin dependencias nuevas. Sin migración. Sin cambio de contrato para nadie que ya mande
`customer_name`; sí es un cambio de contrato intencional para quien dependía del `422` al crear un
`DINE_IN`/`TAKEAWAY` sin nombre **desde el canal `POS`** — exactamente lo que A-99 autoriza.

## Technical Context

**Language/Version**: Python 3.12 (`pos-backend`, FastAPI + SQLAlchemy 2.0) y Angular 21 /
TypeScript (`pos-heladeria`, standalone + signals + TanStack Query) — ambos **sin cambio de
versión**.

**Primary Dependencies**: las ya existentes de cada repositorio; **ninguna dependencia nueva**
(Principio IX) — `HTMLInputElement.select()` nativo para FR-003.

**Storage**: PostgreSQL, esquema por tenant. **Sin cambios de esquema ni migración Alembic** — ver
[data-model.md](./data-model.md): `CustomerOrder.customer_name` ya es `String(255) NULLABLE`.

**Testing**: `./env/bin/python -m unittest discover -s app/characterization_tests` en
`pos-backend` (venv del proyecto; ver memoria "how-to-run-sibling-repo-tests" de esta sesión —
el `python` de anaconda no tiene las dependencias); `ng test` (Vitest) en `pos-heladeria`. Ambas
suites tienen una línea base en verde hoy (confirmado el 2026-10-01 al planificar, antes de tocar
código).

**Target Platform**: Terminal de mesas (panel web de administración/POS), pantalla "Nueva orden".
Menú QR y Domicilio no ganan ninguna pantalla ni cambio nuevo.

**Project Type**: web — dos repositorios de código (`pos-backend`, `pos-heladeria`); la spec vive
en `pos-specs`. Ambos repositorios cambian en esta funcionalidad (a diferencia de spec 090, que
solo tocó `pos-heladeria`).

**Performance Goals**: sin metas propias — es un cambio de validación y de valor por defecto en
una ruta ya existente, sin trabajo adicional de cómputo o de red.

**Constraints**:
- **FR-007 / FR-013**: Domicilio y el menú QR (`channel QR_MENU`) **no cambian** — se verifica con
  los tests existentes de esas rutas en verde, sin modificarlos.
- **El canal importa** (D6): la regla nueva del backend es `channel is OrderChannel.POS`, no
  "cualquier `DINE_IN`/`TAKEAWAY`" — `WHATSAPP`/`API` + `TAKEAWAY` sin nombre deben seguir
  rechazándose (verificado con una prueba nueva, no existía).
- **Sin bandera de estado nueva** en el frontend (D2/D3): la regla se expresa por comparación de
  valor contra el literal exacto, reutilizando el reinicio que `ngOnInit`/`selectTable()` ya hacen.
- **Registro antes de mergear** (Principio II): A-99 debe existir en
  `registro-de-anomalias.md` antes de fusionar cualquier commit de esta spec.

**Scale/Scope**:
- `pos-backend`: `app/api/v1/orders/service.py` (una función, ~10 líneas tocadas) + 2 tests
  reescritos + 1 test nuevo en `app/characterization_tests/test_orders_service.py`.
- `pos-heladeria`: `modules/tables/services/pos-terminal.store.ts` (nueva función de regla de
  pestaña + ajuste de `setOrderTypeTab()`), `modules/tables/pages/manual-order-page.component.ts`
  (`ngOnInit`, plantilla de los 3 `<input>` de Cliente, `[disabled]` de "Crear pedido",
  `mostrarErrorNombre()`, `confirm()`) + specs de ambos archivos (reescribir ~5 pruebas de A-88,
  agregar pruebas nuevas para la regla de pestaña y el reinicio).
- `pos-specs`: A-99 en `registro-de-anomalias.md`; nota de enmienda en la spec 087 (reabre A-88
  parcialmente).
- 3 historias de usuario, ninguna bloqueante entre sí a nivel de código (mismo archivo en varios
  puntos — ver advertencia de concurrencia en `tasks.md`).

## Constitution Check

*GATE: debe pasar antes de la Fase 0. Re-evaluado tras la Fase 1 (final de la sección).*

| Principio | Evaluación |
|---|---|
| I. Las Nuevas Funcionalidades Nacen de un Spec | ✅ Pass — `spec.md` sin `[NEEDS CLARIFICATION]`, checklist 16/16, 13 FR y 10 escenarios ya dados por el propietario del producto. |
| II. El Comportamiento Existente Sigue Protegido | ✅ Pass (planificado) — reabre A-88 (spec 087) de forma explícita y acotada (solo Mesa/Para llevar, canal POS); se registra **A-99** antes de mergear, con qué cambia, por qué, quién, cuándo y qué funcionalidades afecta (borrador en research.md). |
| III. Los Characterization Tests Protegen el Comportamiento Heredado | ✅ Pass (planificado) — los tests que hoy fijan el `422` de A-88 para `POS` se **reescriben citando A-99** (inventariados en research.md: 2 en backend, ~5 en frontend), no se borran sin más; se agrega una prueba nueva para el canal que sí debe seguir rechazando (`WHATSAPP`/`API`), evidencia de que ese otro comportamiento protegido no se ve afectado. |
| IV. Los Nuevos Specs Pueden Introducir Nuevo Comportamiento | ✅ Pass — comportamiento acotado y medible (SC-001…SC-005). |
| V. Nuevas Funcionalidades Antes que Refactorizaciones Oportunistas | ✅ Pass — no se extrae la lógica de "campo con valor por defecto" a un helper compartido ni se toca `billing_customer_name`/`checkout.py` (D1): aunque son conceptualmente parecidos, no los exige esta spec. |
| VI. Evolución Incremental | ✅ Pass — una sola clase de cambio (una regla de validación + una regla de presentación), acotado a `create_order` y a la pantalla "Nueva orden"; sin mezclar backend/frontend en un commit único (ver Principio XV) ni tocar Domicilio/QR/migraciones. |
| VII. Compatibilidad con Datos Históricos | ✅ Pass — ninguna factura ni venta ya emitida se recalcula; pedidos existentes se muestran igual (FR-012, SC-005); el cambio rige solo hacia adelante, igual que A-88. |
| VIII. Evolución del Modelo de Datos | ✅ Pass (no aplica) — [data-model.md](./data-model.md) declara explícitamente cero cambios de esquema; sin migración que revertir. |
| IX. Dependencias Nuevas Permitidas con Justificación | ✅ Pass (no aplica) — cero dependencias nuevas (D4 usa `HTMLInputElement.select()` nativo). |
| X. Verificación Obligatoria | ✅ Pass (planificado) — suites de unidad reescritas/ampliadas en ambos repos + 12 escenarios de [quickstart.md](./quickstart.md) (los 10 del pedido original + 2 de verificación adicional: canal fuera de la Terminal, menú QR intacto). |
| XI. Decisiones de Negocio Frente a Decisiones Técnicas | ✅ Pass — qué pestañas llevan valor por defecto y que Domicilio no cambia es la decisión de negocio ya en la spec; el plan solo decide el "cómo" (dónde vive la regla, comparación por valor vs. bandera, acotar por canal). |
| XII. Trazabilidad | ✅ Pass — Necesidad (pedido del propietario, 2026-10-01, con 10 escenarios ya redactados) → spec → A-99 → este plan → research/data-model/contracts/quickstart → `tasks.md` → tests reescritos/nuevos → verificación manual. |
| XIII. Todo en Español de Colombia | ✅ Pass — artefactos, comentarios y mensajes de usuario (incluido el literal "Consumidor final") en español de Colombia. |
| XIV. Estrategia y Convención de Ramas | ✅ Pass (planificado) — antes de tocar código se crea, **desde `develop`**, `feat/091-default-customer-name` en **ambos** `pos-backend` y `pos-heladeria` (los dos repos cambian, a diferencia de spec 090). `/speckit-tasks` lo deja como tarea inicial de cada repo. |
| XV. Política de Commits | ✅ Pass (planificado) — commits pequeños y separados (p. ej.: backend — regla por canal + tests; frontend — store/regla de pestaña; frontend — plantilla/validación del componente + tests; documentación — A-99 y nota en spec 087), en inglés, Conventional Commits, sin marcas de IA, solo cuando el usuario lo pida. |

**Complexity Tracking**: sin violaciones que justificar.

**Re-chequeo post Fase 1**: el diseño de la Fase 1 no añadió dependencias, variables de entorno ni
cambios de esquema. Dos hallazgos quedaron absorbidos sin cambiar el veredicto: (1) acotar la
regla del backend por **canal**, no solo por tipo de orden, para no tocar `WHATSAPP`/`API` + 
`TAKEAWAY` (D6) — ninguna de las FR originales lo mencionaba explícitamente, pero se deriva
directamente de "Incluye: ... creados desde la Terminal de mesas" (spec.md §Alcance) y evita una
regresión no pedida (Principio VI); (2) el reinicio al abrir "Nueva orden" (D3) **no** basta con
dejar `customerName` en `''` (lo que `ngOnInit`/`selectTable()` ya producen) y confiar en que un
cambio de pestaña la rellene: la ruta principal de Mesa (sin `?tipo=`) nunca cambia de pestaña, así
que la regla de D2 debe invocarse **explícitamente** al final de `ngOnInit`, sobre la pestaña
vigente — un hallazgo de una revisión posterior a la Fase 1 original de este plan, ya corregido
aquí y en research.md/D3 antes de pasar a `tasks.md`; sigue sin hacer falta una bandera de
"¿editado?" (D2), solo una llamada explícita más. Sin riesgo abierto: el único borde señalado (D3,
"riesgo aceptado" si `ManualOrderPageComponent` llegara a editar un pedido existente) es
hipotético y no aplica hoy (hecho verificado en research.md).

## Project Structure

### Documentation (this feature)

```text
specs/091-cliente-consumidor-final/
├── spec.md                                  # Especificación (sin clarificaciones pendientes)
├── plan.md                                  # Este archivo (/speckit-plan)
├── research.md                              # Fase 0: hechos verificados + decisiones D1–D7
├── data-model.md                            # Fase 1: sin cambio de esquema; campo y estado de interfaz
├── quickstart.md                            # Fase 1: 12 escenarios (10 del pedido + 2 de verificación)
├── contracts/
│   ├── post-orders-customer-name.md         # Fase 1: enmienda puntual a POST /orders (canal POS)
│   └── campo-cliente-nueva-orden.md         # Fase 1: estados/transiciones del campo "Cliente"
├── checklists/
│   └── requirements.md
└── tasks.md                                 # Fase 2 (/speckit-tasks — NO lo crea /speckit-plan)
```

### Source Code (repositorios hermanos, fuera de `pos-specs`)

```text
../pos-backend/
└── app/
    ├── api/v1/orders/
    │   └── service.py                   # create_order: regla por canal (D6) para DINE_IN/TAKEAWAY
    └── characterization_tests/
        └── test_orders_service.py       # 2 pruebas reescritas (A-88→A-99) + 1 nueva (WHATSAPP/API)

../pos-heladeria/src/app/modules/tables/
├── services/
│   ├── pos-terminal.store.ts            # regla de pestaña (D2/D3), setOrderTypeTab()
│   └── pos-terminal.store.spec.ts       # pruebas de la regla de pestaña y del reinicio
└── pages/
    ├── manual-order-page.component.ts       # ngOnInit (reinicio a '' + llamada explícita a
    │                                        # applyCustomerNameDefaultForTab(), D3), 3 <input>
    │                                        # Cliente (foco→select, D4), [disabled] de "Crear
    │                                        # pedido", mostrarErrorNombre(), confirm() — todo
    │                                        # acotado a orderTypeTab() === 'domicilios'
    └── manual-order-page.component.spec.ts  # ~5 pruebas de A-88 reescritas + nuevas de la regla
```

**Structure Decision**: web de dos repositorios ya existentes (a diferencia de spec 090, que solo
tocó `pos-heladeria`). No se crea ningún módulo, servicio ni componente nuevo: la funcionalidad
vive en los mismos archivos que ya implementaban A-88 (spec 087), revirtiendo su alcance de forma
quirúrgica. La regla de pestaña vive en el store (ya es dueño de `customerName` y
`orderTypeTab()`), no en el componente, para que cualquier otra pantalla que use el mismo store en
el futuro la herede sin duplicarla.

## Complexity Tracking

> Sin violaciones de la Constitución que justificar (ver Constitution Check).
