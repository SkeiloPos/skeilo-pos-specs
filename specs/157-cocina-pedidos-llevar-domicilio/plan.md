# Implementation Plan: Envío a Cocina de Pedidos Para Llevar y Domicilio

**Branch**: `157-cocina-pedidos-llevar-domicilio` | **Date**: 2026-11-11 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/157-cocina-pedidos-llevar-domicilio/spec.md`

## Summary

Hoy, el envío automático a cocina tras el cobro (patrón de spec 153) está codificado
exclusivamente para pedidos de mesa (`order.dining_table_id is not None`), y el envío manual
(`send_to_kitchen`/`_apply_kitchen_send`) exige siempre `payment_status = PAID`. Ninguna de las
dos rutas contempla la modalidad de cobro del plan (spec 154) para pedidos TAKEAWAY/DELIVERY,
por lo que estos quedan bloqueados en tenants con módulo de Cocina activo: en "Pago antes de
recibir" nadie los envía automáticamente al cobrar, y en "Pago después de recibir" no pueden
enviarse porque no están pagados.

La solución extiende la modalidad de cobro del plan (`modalidad_pago_qr`, hoy solo usada para
el mensaje del menú QR) para que también gobierne el flujo operativo de mostrador/domicilio:
(1) en `PAY_BEFORE_RECEIVING`, `pay_order` dispara `_apply_kitchen_send` en el mismo acto del
cobro (igual al patrón de `_charge_session` para mesas); (2) en `PAY_AFTER_RECEIVING`, se releva
la condición `payment_status == PAID` dentro de `_apply_kitchen_send`/`send_to_kitchen`
únicamente para TAKEAWAY/DELIVERY, permitiendo el envío manual sin cobro previo. DINE_IN no se
toca: conserva exactamente las reglas de spec 153.

## Technical Context

**Language/Version**: Python 3.11 (backend, FastAPI + SQLAlchemy); TypeScript/Angular (frontend)

**Primary Dependencies**: FastAPI, SQLAlchemy, Alembic (backend); Angular (frontend) — sin
dependencias nuevas

**Storage**: PostgreSQL 16, schema-per-tenant (`CustomerOrder.kitchen_status`,
`CustomerOrder.payment_status` en schema de cada tenant; `Plan.modalidad_pago_qr` en
`shared.plans`) — sin cambios de esquema, el campo `modalidad_pago_qr` ya existe (spec 154) con
`NOT NULL DEFAULT 'PAY_AFTER_RECEIVING'`

**Testing**: `unittest` sobre SQLite en memoria (`app/characterization_tests/`, patrón
`"CONGELA comportamiento actual:"` para lo existente + tests nuevos de esta spec); ver
[memoria del proyecto] — venv de `pos-backend`, Postgres local disponible para verificación de
integración si se requiere

**Target Platform**: Linux server (backend); navegador (frontend Angular) — API consumida por
POS de mostrador/caja, no por el menú QR de autoservicio (ese flujo ya está cubierto por spec
154 y no cambia)

**Project Type**: Web application (dos repositorios: `../pos-backend` API, `../pos-heladeria`
frontend)

**Performance Goals**: N/A — no introduce rutas nuevas de alto volumen; el chequeo de modalidad
es una lectura adicional de `Plan` ya realizada hoy en caliente para el menú QR

**Constraints**: Ningún cambio de comportamiento para pedidos `DINE_IN` ni para tenants sin
módulo de Cocina activo (FR-004, FR-007); ninguna migración de datos (el campo de modalidad ya
existe); no se recalculan ni alteran pedidos ya enviados a cocina antes del cambio (edge case de
spec.md)

**Scale/Scope**: Cambio acotado a dos funciones de servicio existentes en `pos-backend`
(`_apply_kitchen_send`/`send_to_kitchen` en `orders/kitchen.py`, `pay_order` en
`orders/checkout.py`) más un ajuste de visibilidad de botón en `pos-heladeria` para la pantalla
de pedidos de mostrador/domicilio

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Principio I (Spec primero)**: PASA. Existe spec aprobado (`spec.md`) con problema,
  alcance, reglas de negocio, clarificaciones y criterios de aceptación antes de tocar código.
- **Principio II (Comportamiento existente protegido)**: PASA con decisión de negocio ya
  registrada en el propio spec (sección Clarifications, 2026-11-11): extender el alcance de
  `modalidad_pago_qr` más allá del menú QR fue confirmado explícitamente por el usuario. Debe
  añadirse una entrada equivalente en `registro-de-anomalias.md` antes de implementar (ver
  Fase 1 / tareas), documentando qué cambia (alcance de `modalidad_pago_qr`), por qué, quién y
  cuándo.
- **Principio III (Characterization tests)**: PASA. Los characterization tests de
  `test_orders_kitchen.py` y `test_orders_checkout.py` que hoy fijan "TAKEAWAY/DELIVERY nunca se
  auto-envían a cocina" y "`_apply_kitchen_send` siempre exige `PAID`" quedan protegidos salvo
  que esta spec los actualice explícitamente citando la decisión de negocio — se hace en Fase de
  implementación, no en este plan.
- **Principio IV (Nuevo comportamiento permitido)**: PASA. El cambio está definido por este spec
  aprobado.
- **Principio V (Sin refactorizaciones oportunistas)**: PASA. El plan no toca
  `checkout_and_send` (ruta legacy de `hold_for_payment`) ni ninguna otra función fuera del
  alcance de FR-001..FR-009; si se detecta que `checkout_and_send` también necesita el gancho,
  se tratará como hallazgo a confirmar con el usuario, no como extensión silenciosa del alcance.
- **Principio VI (Evolución incremental)**: PASA. Una sola unidad de cambio: lógica de
  habilitación de envío a cocina según modalidad de pago del plan, sin migraciones ni cambios de
  arquitectura.
- **Principio VII (Datos históricos)**: PASA. No afecta facturas/ventas ya emitidas; `pay_order`
  sigue creando la misma `Sale` con la misma lógica de cobro, solo se añade el efecto lateral de
  envío a cocina.
- **Principio VIII (Evolución del modelo de datos)**: N/A — no hay cambios de esquema.
- **Principio IX (Dependencias nuevas)**: N/A — no se añade ninguna dependencia.
- **Principio X (Verificación obligatoria)**: Se exige en Fase de implementación: tests nuevos
  para los 9 FR + actualización explícita de characterization tests afectados.
- **Principio XI/XII (Negocio vs. técnico / Trazabilidad)**: PASA. La cadena Necesidad → Spec →
  Decisión (anomalía) → Implementación → Tests → Verificación queda trazable una vez se registre
  la anomalía (ver Principio II arriba).
- **Principio XIV/XV (Ramas y commits Git)**: Se crea rama `feat/157-kitchen-takeaway-delivery`
  antes de tocar código; commits solo bajo pedido explícito del usuario, en inglés, atómicos, sin
  marca de IA.

**Resultado**: Gate PASA. Única acción pendiente antes de implementar: registrar la decisión de
negocio en `registro-de-anomalias.md` (Principio II) — se incluye como tarea explícita en Fase 1.

## Project Structure

### Documentation (this feature)

```text
specs/157-cocina-pedidos-llevar-domicilio/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
│   └── kitchen-payment-modality.md
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
../pos-backend/
├── app/
│   ├── models/
│   │   ├── customer_order.py     # kitchen_status, payment_status, order_type, dining_table_id (sin cambios de esquema)
│   │   └── plan.py               # modalidad_pago_qr (sin cambios de esquema, ya existe)
│   ├── api/v1/
│   │   ├── orders/
│   │   │   ├── kitchen.py        # _apply_kitchen_send, send_to_kitchen (lógica a extender)
│   │   │   ├── checkout.py       # pay_order (gancho de auto-envío para PAY_BEFORE_RECEIVING)
│   │   │   └── router.py         # endpoints existentes: POST /pay, POST /send-to-kitchen (sin cambio de contrato HTTP)
│   │   ├── plan/
│   │   │   └── service.py        # get_qr_payment_instruction_mode (reutilizado, posible rename/extracción de helper compartido)
│   │   └── table_sessions/
│   │       └── service.py        # _charge_session (referencia del patrón spec 153, sin cambios)
│   └── core/
│       └── plan_limits.py        # has_module_access (reutilizado, sin cambios)
└── app/characterization_tests/
    ├── test_orders_kitchen.py        # tests a actualizar (citando la decisión) + tests nuevos
    ├── test_orders_checkout.py       # tests nuevos para pay_order + auto-envío
    └── orders_fixtures.py            # posible extensión de helpers (TAKEAWAY/DELIVERY con plan en cada modalidad)

../pos-heladeria/
└── src/app/
    └── <módulo de pedidos de mostrador/cocina>  # oculta el botón manual "Enviar a cocina"
                                                   # cuando order_type ∈ {TAKEAWAY, DELIVERY},
                                                   # módulo Cocina activo y modalidad =
                                                   # PAY_BEFORE_RECEIVING (FR-002); sin cambios
                                                   # en el resto del flujo

specs/000-reconocimiento/
└── registro-de-anomalias.md          # nueva entrada: extensión de alcance de modalidad_pago_qr
```

**Structure Decision**: Se reutiliza la estructura de web application ya existente en los dos
repositorios del proyecto (`../pos-backend` API, `../pos-heladeria` frontend). No se crean
módulos ni carpetas nuevas: el cambio vive dentro de los archivos de servicio ya responsables del
flujo de cocina (`orders/kitchen.py`, `orders/checkout.py`) y de la pantalla de pedidos de
mostrador/domicilio en el frontend. La exploración exacta del componente Angular a modificar se
resuelve en Fase de implementación (no bloquea este plan, ya que el contrato de backend es la
pieza que gobierna el comportamiento).

## Complexity Tracking

*Sin violaciones de la Constitution Check. Sección no aplica.*
