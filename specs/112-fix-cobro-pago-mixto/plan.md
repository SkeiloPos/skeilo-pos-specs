# Implementation Plan: Cobro de pedido con múltiples métodos de pago

**Branch**: `112-fix-cobro-pago-mixto` (`pos-specs`) | **Date**: 2026-10-11 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/112-fix-cobro-pago-mixto/spec.md`

## Summary

El backend (`pos-backend`) **ya soporta pagos mixtos** a nivel de modelo y de lógica de negocio:
`Payment` es 1:N respecto a `Sale` desde la spec [011](../011-venta-mostrador-constructor-factura/spec.md),
`build_sale` (`app/api/v1/sales/builder.py`) ya valida "el vuelto solo sale del efectivo" y ya crea
una fila `Payment` por cada línea recibida, y el arqueo (`app/api/v1/cash/service.py::reconcile`,
spec [108](../108-ventas-efectivo-neto-caja/spec.md)) ya agrega por método y ya neta el cambio
entregado. Lo que no soporta hoy es el **frontend** (`pos-heladeria`): la spec
[046](../046-dividir-cuenta-pago-pendiente/spec.md) redujo `PaymentDraft` a un único
`{methodId, amount}` y retiró explícitamente la opción de combinar métodos (ver nota de
"Naturaleza de esta spec" y `A-124` en `spec.md`).

El fix consiste en: (1) generalizar `PaymentDraft` a una lista de hasta 3 líneas con las reglas de
asignación/vuelto/validación de la spec, en `payment-draft.util.ts` y `PaymentInputComponent` (o
su reemplazo), manteniendo el mismo punto de integración en `PosCheckoutPanelComponent`; y (2)
imponer el tope de 3 líneas también en el backend (`max_length=3` en los tres schemas Pydantic que
aceptan `payments: list[PaymentIn]`), como defensa en profundidad — nada más del backend necesita
cambiar.

## Technical Context

**Language/Version**: Python 3.14 (`pos-backend`, vía `./env/bin/python`) + TypeScript 5.9 /
Angular 21 (`pos-heladeria`).

**Primary Dependencies**: FastAPI 0.136 + SQLAlchemy 2.0 (`pos-backend`, módulos
`app/api/v1/sales/`, `app/api/v1/orders/`); Angular standalone components + signals
(`pos-heladeria`, módulo `tables`) — ninguna dependencia nueva (Principio IX); se reutiliza
íntegramente el modelo `Payment`/`Sale`, el endpoint de cobro y el catálogo de métodos por tenant
(spec 032) ya existentes.

**Storage**: PostgreSQL 16, un esquema por tenant — sin cambios de esquema ni migración: la tabla
`tenant.payments` ya es 1:N respecto a `tenant.sales` desde spec 011.

**Testing**: `pos-backend` — `cd ../pos-backend && ./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'`
(baseline 2026-10-03: 1290 OK, SQLite en memoria, sin PostgreSQL local) más un script dedicado
nuevo en `app/scripts/`, mismo patrón que `test_cash_net_sales.py` (spec 108). `pos-heladeria` —
`npx ng test --watch=false --include='src/app/modules/tables/**/*.spec.ts'` (Vitest); baseline
2026-09-21/2026-10-03: 19 tests fallando en 6 archivos no relacionados (spec 084), dos de ellos
(`pos-checkout-panel`, y potencialmente `payment-input`/`payment-draft.util` tras este cambio) SÍ
están dentro del módulo `tables` — comparar por archivo, no por conteo total, y actualizar
explícitamente los tests de spec 046 que afirman "un único método" (citando `A-124`).

**Target Platform**: servidor Linux (API) + SPA Angular en navegador (terminal POS táctil).

**Project Type**: aplicación web existente de dos repositorios, ambos en producción.

**Performance Goals**: sin objetivo propio — como máximo 3 filas `Payment` por venta en vez de 1;
la consulta de `reconcile` ya agrupa por método sin importar cuántas filas haya por venta, sin
consultas adicionales.

**Constraints**: cobrar con un único método MUST seguir siendo igual de rápido (RN7/FR-014) — la
UI de pago mixto no puede añadir pasos al camino de un solo método. La suma de montos asignados
MUST validarse en el cliente contra el total exacto (RN1/FR-002) antes de habilitar "Cobrar";
el backend conserva su propia validación más laxa (`paid >= total`, vuelto solo de efectivo) como
red de seguridad, no como la fuente de la regla de negocio de "suma exacta" (esa es un control de
UX, documentado así en `research.md` D2).

**Scale/Scope**: 1 interfaz y sus funciones puras generalizadas (`PaymentDraft` → lista de líneas,
`payment-draft.util.ts`), 1 componente de UI extendido o reemplazado (`PaymentInputComponent`),
sin cambios en su único punto de integración (`PosCheckoutPanelComponent` ya le pasa `total` y
`methods` y escucha `changed`); 3 schemas Pydantic con una línea añadida cada uno
(`max_length=3`) en `pos-backend`; sin endpoints nuevos, sin columnas nuevas, sin componentes
nuevos en `cash-register` ni en `receipt.util.ts` (ya iteran `sale.payments`/`sales_by_method` como
lista).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Evaluación |
|---|---|
| I. Nace de un spec | PASS — `specs/112-fix-cobro-pago-mixto/spec.md` |
| II. Comportamiento existente protegido | PASS — esta spec cambia explícitamente un comportamiento existente (la restricción a un único método que impuso spec 046); la decisión ya está documentada en el propio `spec.md` ("Naturaleza de esta spec", "Autorización de negocio") y **ya registrada** como `A-124` en `registro-de-anomalias.md` (hecho durante esta sesión de planificación, confirmado explícitamente por el dueño del producto antes de continuar) |
| III. Characterization tests | PASS — se verificó (`grep` sobre `app/characterization_tests/`) que ningún test `CONGELA comportamiento actual:` protege la restricción a un único método ni el cálculo de `build_sale`/`reconcile` sobre pagos múltiples; lo único que asume "un único método" son los *unit tests propios* de spec 046 en `pos-heladeria` (`payment-draft.util.spec.ts`, `payment-input.component.spec.ts`), que no son characterization tests y se actualizan como parte normal de esta implementación, citando `A-124` |
| IV. Nuevos specs introducen comportamiento nuevo | PASS — exactamente este caso: reabre una capacidad retirada, con reglas nuevas (tope de 3, suma exacta, vuelto solo efectivo) que spec 046 no tenía que validar |
| V. Sin refactors oportunistas | PASS — se toca solo la capa de borrador de pago (`payment-draft.util.ts`, `PaymentInputComponent`) y los 3 `Field(max_length=3)`; no se reorganiza `checkout.py`, `builder.py` ni `cash/service.py`, que ya hacen lo necesario |
| VI. Evolución incremental | PASS — una sola clase de cambio (reabrir combinación de métodos con validación nueva en la UI), sin mezclar con modelo de datos, arquitectura ni migración; no requiere Complexity Tracking |
| VII. Datos históricos | PASS — ninguna venta, pago o factura ya emitida se recalcula; las ventas ya cobradas con un único método siguen teniendo exactamente 1 fila `Payment`, sin migración |
| VIII. Evolución del modelo de datos | N/A — ninguna columna, tabla ni migración nueva; `Payment` ya es 1:N desde spec 011 |
| IX. Dependencias nuevas | PASS — cero |
| X. Verificación obligatoria | PASS, ver `quickstart.md` — tests nuevos en `pos-backend` (tope de 3 pagos, pago mixto construye N filas `Payment`) y en `pos-heladeria` (`payment-draft.util.spec.ts` extendido a N líneas, specs de UI del componente nuevo/extendido), más los characterization tests existentes sin regresión |
| XI. Negocio vs técnico | PASS — la decisión de negocio (reabrir combinación de métodos, con qué reglas) está en el spec y en `A-124`; este plan solo decide el *cómo* (dónde vive la validación de "suma exacta": cliente, no servidor) |
| XII. Trazabilidad | PASS — Necesidad (cajero no puede dividir un cobro) → spec 112 → decisión de negocio `A-124` → este plan → `tasks.md` → implementación → tests nuevos + characterization tests sin regresión |
| XIII. Español de Colombia | Aplicado en este documento y en el resto de artefactos de esta fase |
| XIV. Rama Git | Pendiente de implementación: crear `fix/112-mixed-payment-checkout` (o nombre equivalente en inglés) en `pos-backend` y en `pos-heladeria` antes de tocar su código — ambos repos trabajan sobre `develop`, no `main` |
| XV. Commits | Pendiente de implementación: solo bajo pedido explícito del usuario, en inglés, sin marca de autoría de IA, en unidades pequeñas (p. ej. un commit para el `max_length` del backend, otro para `payment-draft.util.ts`, otro para el componente de UI, otro para los tests de spec 046 actualizados) |

**Re-chequeo post-diseño (Fase 1)**: sin cambios — `data-model.md` y `contracts/api.md` confirman
que no se introduce ningún campo, tabla ni endpoint nuevo respecto a lo evaluado arriba; el único
cambio de contrato es el tope `max_length=3`, ya reflejado en la tabla.

## Project Structure

### Documentation (this feature)

```text
specs/112-fix-cobro-pago-mixto/
├── plan.md               # este archivo
├── research.md           # Fase 0
├── data-model.md         # Fase 1
├── quickstart.md         # Fase 1
├── contracts/
│   └── api.md
├── checklists/
│   └── requirements.md
└── tasks.md               # /speckit-tasks, no este comando
```

### Source Code (sibling repositories, fuera de `pos-specs`)

```text
../pos-backend/
├── app/api/v1/sales/schemas.py     # PaymentIn sin cambios; SaleCreate.payments gana
│                                   #   Field(..., min_length=1, max_length=3)
├── app/api/v1/orders/schemas.py    # PayIn.payments y CheckoutAndSendIn.payments ganan
│                                   #   el mismo max_length=3
├── app/api/v1/sales/builder.py     # build_sale: sin cambios de lógica — ya valida
│                                   #   "el vuelto solo sale del efectivo" y ya acepta N pagos
└── app/api/v1/cash/service.py      # reconcile: sin cambios — ya agrupa por método y neta
                                     #   el cambio entregado (spec 108)

../pos-heladeria/
└── src/app/modules/tables/
    ├── services/payment-draft.util.ts        # PaymentDraft → PaymentDraft[] (hasta 3), con
    │                                          #   assigned/receivedCash por línea; funciones
    │                                          #   puras de validación (ver data-model.md)
    ├── components/payment-input.component.ts # generalizado a N líneas ("Agregar otro
    │                                          #   método" hasta el tope, eliminar línea,
    │                                          #   saldo pendiente, vuelto solo en la línea
    │                                          #   de efectivo) — mismo @Input/@Output que hoy
    │                                          #   (`total`, `methods`, `changed`), para no
    │                                          #   tocar `PosCheckoutPanelComponent`
    └── components/pos-checkout-panel.component.ts  # sin cambios funcionales: sigue pasando
                                                      #   `total`/`methods`, escuchando `changed`
                                                      #   y llamando `paymentLines(draft)` al
                                                      #   cobrar — solo cambia qué construye
                                                      #   `paymentLines` (N líneas, no 1)
```

**Structure Decision**: todo el trabajo real vive en la capa de borrador de pago del frontend
(`payment-draft.util.ts` + el componente que lo edita), porque es el único punto donde la
restricción a un único método fue impuesta por spec 046 — el backend, el catálogo de métodos, el
arqueo y el comprobante ya estaban diseñados para N pagos y no necesitan tocarse. Se mantiene el
mismo contrato de `@Input`/`@Output` entre el componente de pago y `PosCheckoutPanelComponent`
para no propagar el cambio a su contenedor (y, por construcción, es automáticamente el mismo
componente para Mesa/Para llevar/Domicilio — RN9/FR-015 — porque `PosCheckoutPanelComponent` ya es
compartido entre los tres).

## Complexity Tracking

*Sin violaciones que requieran justificación — ver Constitution Check arriba. No hay excepciones
que registrar en esta tabla.*
