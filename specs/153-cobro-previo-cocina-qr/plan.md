# Implementation Plan: Pago antes de cocina para pedidos de mesa (QR) con módulo de cocina activo

**Branch**: `153-cobro-previo-cocina-qr` | **Date**: 2026-11-05 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/153-cobro-previo-cocina-qr/spec.md`

## Summary

Cuando un tenant tiene el módulo de Cocina activo, un pedido de mesa (QR) debe cobrarse y
enviarse a cocina en un mismo paso — igual que ya ocurre con un pedido manual de mostrador
— y nunca antes. El botón "Entregar" solo debe habilitarse cuando cocina marca el pedido
como "Listo", y jamás al mismo tiempo que una acción de cobro activa. Si el tenant no tiene
el módulo de Cocina activo, el flujo actual de pedidos de mesa por QR no cambia.

La investigación de código (ver `research.md`) encontró que hoy **ningún** camino de pago
de un pedido de mesa está conectado al estado de cocina:

- `SessionBillPanelComponent.charge()` (frontend) cobra la sesión de mesa llamando a
  `_charge_session` (backend, `table_sessions/service.py`), que sigue aplicando la regla
  *pre-cocina* de `_assert_closable` ("todo debe estar entregado antes de cobrar").
- Antes de cobrar, `ensureReadyToCharge` (`pos-terminal.store.ts`) detecta ítems con
  `estado_cocina==='pendiente'`, muestra el diálogo "Quedan productos sin entregar" con un
  botón que dice literalmente **"Entregar y cobrar"**, y llama a `deliverOrder()` para cada
  pedido pendiente antes de cobrar — esto es la causa raíz del reporte del usuario: cobro y
  entrega conviven en la misma acción, sin relación con el estado real de cocina.
- `send_to_kitchen` (backend) existe desde la spec 150, pero solo se dispara manualmente
  (botón "Enviar a cocina"); ningún flujo de pago lo invoca automáticamente, ni siquiera el
  de pedidos manuales de mostrador.
- `deliver_order` (backend) no tiene ninguna validación de `kitchen_status`; el requisito
  "Entregar solo cuando Listo" (spec 151, FR-004 de esta spec) hoy solo se aplica en el
  frontend (`canDeliverOrder`), nunca en la API.

El enfoque técnico es: (1) condicionar `_assert_closable`/`ensureReadyToCharge` a si el
tenant tiene el módulo de Cocina activo — si lo tiene, no exigir entrega previa ni disparar
el diálogo "Entregar y cobrar"; (2) tras un cobro exitoso de un pedido/sesión de mesa con el
módulo activo, y solo cuando el 100% de lo cobrado por esa mesa/sesión queda pagado, invocar
`send_to_kitchen` para cada pedido recién liquidado, dentro de la misma operación de cobro;
(3) añadir a `deliver_order` (backend) la misma validación de `kitchen_status==='LISTO'`
que ya aplica el frontend, como defensa en profundidad; (4) no tocar ningún camino que no
involucre pedidos de mesa (mostrador/domicilio ya cobran y envían a cocina en un solo paso
vía `checkout_and_send`, y no se modifican).

## Technical Context

**Language/Version**: Python 3.11+ (backend, FastAPI 0.136.3, SQLAlchemy 2.0.50); TypeScript 5.9 / Angular 21.1 (frontend)

**Primary Dependencies**: FastAPI + SQLAlchemy + Alembic (backend); Angular standalone components + RxJS signals store (`pos-terminal.store.ts`) (frontend). No nuevas dependencias.

**Storage**: PostgreSQL 16, schema-per-tenant. No se requieren nuevos campos ni tablas: se reutilizan `payment_status`, `kitchen_status`, `dining_table_id` en `orders`, y el flag de módulo de plan "cocina" ya existente (spec 149).

**Testing**: pytest (backend, venv del proyecto — ver `app/characterization_tests/test_orders_kitchen.py` como característica a extender); `ng test` (frontend, baseline conocida como flaky/no determinista — comparar por archivo, no por conteo total de la suite).

**Target Platform**: Linux server (backend API); navegador web (frontend Angular), incluido el menú QR servido a clientes desde dispositivos móviles.

**Project Type**: Web application (backend API + frontend Angular), dos repositorios independientes (`pos-backend`, `pos-heladeria`).

**Performance Goals**: Sin metas nuevas de rendimiento; la operación de cobro + envío a cocina debe permanecer dentro de los tiempos de respuesta ya aceptables para `charge_session`/`close_session` hoy (no se introduce trabajo asíncrono adicional significativo).

**Constraints**: La verificación de "100% pagado" para pedidos con cuenta dividida debe basarse en el estado de pago ya persistido (`OrderPaymentAttempt`/`payment_status`), no en un cálculo nuevo del frontend. Ningún cambio puede afectar pedidos de mostrador/domicilio (FR-009) ni facturas ya emitidas (Principio VII de la constitución).

**Scale/Scope**: Cambio acotado a dos repos, en los módulos de cobro de mesa (`table_sessions`, `orders/checkout`, `orders/kitchen`) y sus contrapartes en el panel de mesa del frontend (`session-bill-panel.component.ts`, `pos-terminal.store.ts`, `order-status.util.ts`). No introduce entidades nuevas.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Principio I (nace de un spec)**: ✅ `spec.md` existe y fue clarificado (sesión 2026-11-05) antes de este plan.
- **Principio II (comportamiento existente protegido)**: ⚠️ **Acción requerida en implementación**. Este cambio modifica comportamiento existente en dos puntos: (a) `_assert_closable`/`ensureReadyToCharge` deja de exigir entrega previa al cobro de mesa cuando el módulo de Cocina está activo; (b) `deliver_order` pasa a exigir `kitchen_status==='LISTO'` en el backend cuando el módulo está activo (hoy sin ninguna validación). Ambos cambios están explícitamente autorizados por las Clarifications del spec (sesión 2026-11-05) y por FR-001 a FR-004, pero la constitución exige que todo cambio de comportamiento existente quede **registrado** en `specs/000-reconocimiento/registro-de-anomalias.md` (quién, cuándo, qué cambia, por qué, qué se afecta) **antes** de implementar. `tasks.md` debe incluir esa entrada como tarea explícita.
- **Principio III (characterization tests)**: Ningún test con prefijo `"CONGELA comportamiento actual:"` protege hoy el camino de cobro de mesa con cocina activa (es comportamiento roto, no protegido). `app/characterization_tests/test_orders_kitchen.py` sí protege `send_to_kitchen`/`deliver_order` existentes — se extiende, no se reescribe, salvo el nuevo guard en `deliver_order`, que requiere actualizar explícitamente el test que hoy asume ausencia de validación.
- **Principio V/VI (sin refactor oportunista, evolución incremental)**: El alcance se limita a los puntos de cobro/entrega de pedidos de mesa; no se toca `checkout_and_send` (mostrador) ni el modelo de datos de facturación.
- **Principio VII (datos históricos)**: Sin impacto; no se recalcula ninguna venta/factura ya emitida.
- **Principio VIII (modelo de datos)**: No aplica — no hay cambios de esquema.
- **Principio IX (dependencias nuevas)**: No aplica — no se añaden dependencias.
- **Principio XIII (español de Colombia)**: Este plan y los artefactos de diseño se escriben en español de Colombia.

**Resultado del gate**: PASA, con una obligación de implementación (registrar la decisión en el registro de anomalías) documentada arriba y a trasladar a `tasks.md`.

## Project Structure

### Documentation (this feature)

```text
specs/153-cobro-previo-cocina-qr/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
../pos-backend/
├── app/
│   ├── api/v1/orders/
│   │   ├── checkout.py          # pay_order, checkout_and_send (referencia, sin cambios)
│   │   ├── kitchen.py           # send_to_kitchen, deliver_order (cambios aquí)
│   │   └── router.py            # endpoints existentes reutilizados, sin nuevas rutas
│   ├── api/v1/table_sessions/
│   │   └── service.py           # _assert_closable, _charge_session (cambios aquí)
│   └── core/plan_limits.py      # has_module_access("cocina") — reutilizado, sin cambios
└── app/characterization_tests/
    └── test_orders_kitchen.py   # tests existentes a extender

../pos-heladeria/
└── src/app/modules/
    ├── tables/
    │   ├── components/session-bill-panel.component.ts  # botón Cobrar (cambios aquí)
    │   └── services/pos-terminal.store.ts               # ensureReadyToCharge (cambios aquí)
    └── orders/
        └── order-status.util.ts  # canDeliverOrder/canSendToKitchen (ya correctos; verificar consistencia)
```

**Structure Decision**: Se reutiliza la estructura de web application ya existente en ambos
repositorios (backend FastAPI por dominio bajo `app/api/v1/`, frontend Angular por módulo
bajo `src/app/modules/`). No se crean nuevos directorios ni módulos; el cambio vive dentro
de los módulos `orders`/`table_sessions` (backend) y `tables`/`orders` (frontend) que ya
implementan el flujo de mesa y de cocina.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

Sin violaciones que requieran justificación: el único punto señalado en el Constitution
Check (registro en `registro-de-anomalias.md`) es una obligación de proceso ya prevista por
la constitución, no una excepción a ella — se traslada a `tasks.md` como tarea, no requiere
complejidad adicional de diseño.
