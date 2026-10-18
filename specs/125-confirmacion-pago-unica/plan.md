# Implementation Plan: Confirmación Única de Pago

**Branch**: `125-confirmacion-pago-unica` | **Date**: 2026-10-17 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/125-confirmacion-pago-unica/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

Un cobro exitoso en la Terminal de Mesas hoy dispara tres avisos redundantes en la misma
terminal que cobró (modal "Pago registrado" + dos toasts), y uno de los toasts no respeta el
formato de moneda del sistema. La causa es que la terminal de origen recibe tanto la respuesta
HTTP de su propio cobro (que ya abre el modal y dispara un toast propio) como el evento de
notificación en tiempo real (`notification.created`, spec 077) que el backend transmite a todo
el canal `staff` del tenant sin distinguir quién originó el cobro. El enfoque técnico: (1)
eliminar el toast local redundante que hoy acompaña al modal, (2) introducir un identificador de
cliente/terminal por pestaña (nuevo, mínimo) que viaje en la petición de cobro y vuelva en el
payload del evento `notification.created`, para que la terminal de origen pueda ignorar
silenciosamente ese evento sin dejar de recibir cualquier otro, (3) corregir el formato de moneda
del resumen de pago en el backend, y (4) ampliar el contenido del modal (método de pago, vuelto)
y reintroducir su botón "Imprimir Factura" para el caso de un solo comprobante (decisión de
negocio A-136, revierte spec 029).

## Technical Context

**Language/Version**: Backend: Python 3.11 (FastAPI + SQLAlchemy). Frontend: TypeScript 5 /
Angular (standalone components, signals, control flow `@if`).

**Primary Dependencies**: Backend: FastAPI, SQLAlchemy, Pydantic (sin dependencias nuevas).
Frontend: Angular, RxJS (`firstValueFrom`), el cliente SSE propio ya existente
(`src/app/core/realtime/sse-client.ts`, spec 077). Se usa `crypto.randomUUID()` nativo del
navegador (ya en uso en este mismo repo, `pos-terminal.store.ts:1736`) para el identificador de
terminal — no se agrega ninguna librería (Principio IX).

**Storage**: PostgreSQL 16, schema-per-tenant. `NotificationEvent.payload` es una columna JSONB
ya existente (spec 077); el nuevo campo `origin_client_id` es un campo adicional dentro de ese
JSON, no una columna nueva — no requiere migración de esquema (Principio VIII: cambio aditivo,
compatible con filas existentes que no lo tendrán).

**Testing**: Backend: pytest (characterization + tests propios de la spec, siguiendo el patrón
ya usado por `app/core/notifications/` y `app/api/v1/orders/`). Frontend: `ng test` (Jasmine/
Karma), siguiendo el patrón de los `*.spec.ts` ya existentes para `pos-terminal.store.ts`,
`notification-center.service.ts` y `table-sessions.component.ts`.

**Target Platform**: Aplicación web POS (staff), servida a navegadores de escritorio/tablet en
el local; backend como API HTTP + SSE multi-tenant.

**Project Type**: Web application (frontend Angular `pos-heladeria` + backend FastAPI
`pos-backend`) — Opción 2 de la plantilla de planificación.

**Performance Goals**: Ninguno nuevo. Se mantiene la latencia "casi inmediata" ya exigida por la
spec 077 para la entrega de la notificación a las demás terminales (RNF-004 de esa spec, sin
tocar).

**Constraints**: Sin migraciones de base de datos; sin cambiar el contrato de pagos mixtos/
complementarios (specs 112/123); ninguna factura ya emitida se recalcula ni se re-representa
(Principio VII) — esta funcionalidad no toca el cálculo de totales ni facturas, solo cómo se
confirma y se notifica un cobro ya resuelto.

**Scale/Scope**: Cambio acotado a los módulos de cobro de mesa/mostrador y de notificaciones en
tiempo real, en ambos repositorios. Backend: 3 endpoints que ya emiten `payment.completed` (ver
Research R5), el módulo `app/core/notifications/` (summary + dispatch + canal in-app), y sus
schemas Pydantic. Frontend: el store de la Terminal de Mesas, el servicio de notificaciones en
tiempo real, el servicio de transporte HTTP de mesas/pedidos, y el modal "Pago registrado".

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Principio I (nace de un spec)**: ✅ `specs/125-confirmacion-pago-unica/spec.md` ya existe y
  fue validado contra el checklist de calidad antes de este plan.
- **Principio II (comportamiento existente protegido / decisión de negocio registrada)**: ✅ El
  único comportamiento existente que este cambio modifica deliberadamente — el retiro de
  "Imprimir Factura" del modal para un solo comprobante, hecho por spec 029 — ya quedó registrado
  como [A-136](../000-reconocimiento/registro-de-anomalias.md#a-136) antes de este plan, con
  quién, cuándo, qué cambia y por qué (confirmado explícitamente con el usuario durante esta
  sesión de planificación). El resto de los cambios (deduplicar avisos, corregir formato de
  moneda, agregar método de pago/vuelto al modal) son adiciones de contenido/comportamiento nuevo
  sobre una confirmación que hoy es incompleta, no modificaciones de una regla de negocio ya
  decidida — no requieren entrada adicional en el registro.
- **Principio III (characterization tests)**: ✅ No se identificó ningún test
  `"CONGELA comportamiento actual:"` sobre el contenido del modal de éxito, el toast duplicado, ni
  el formato del resumen de notificación — son áreas sin characterization test previo (UI/UX
  post-modernización). Los tests propios de spec 029 que sí verifican la ausencia del botón
  "Imprimir Factura" en el modal se actualizan citando A-136 (no son characterization tests
  protegidos).
- **Principio V/VI (sin refactor oportunista, cambio incremental)**: ✅ El plan no toca el bug
  gemelo de formato de moneda en el resumen de `order.created` (mismo archivo `summary.py`,
  distinta rama) por no ser parte del alcance de esta spec — queda fuera, documentado en Research.
  No se mezcla con ninguna otra limpieza de `pos-terminal.store.ts` o `pos-checkout-panel.component.ts`
  más allá de lo que esta spec requiere.
- **Principio VII (datos históricos)**: ✅ No se recalcula ningún total, factura ni venta ya
  emitida; el cambio es puramente de presentación/notificación sobre un cobro ya resuelto por el
  backend existente.
- **Principio VIII (evolución del modelo de datos)**: ✅ Único cambio de datos: un campo nuevo y
  opcional (`origin_client_id`) dentro del JSON ya existente de `NotificationEvent.payload`. Sin
  migración (columna JSONB preexistente), compatible con filas históricas (campo ausente = 
  `None`, tratado igual que "no hay origen que silenciar").
- **Principio IX (dependencias nuevas)**: ✅ Ninguna dependencia nueva — se usa `crypto.randomUUID()`
  nativo (ya en uso en este mismo repo) y `sessionStorage` nativo del navegador.
- **Principio XIV (rama de Git)**: Pendiente de aplicarse al iniciar la implementación en
  `pos-backend` y `pos-heladeria` (no en este repo de specs): `feat/125-single-payment-confirmation`
  en cada repositorio, antes de tocar código.

**Resultado**: PASS. No hay violaciones que requieran `Complexity Tracking`.

## Project Structure

### Documentation (this feature)

```text
specs/125-confirmacion-pago-unica/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
# pos-backend (API)
app/
├── api/v1/
│   ├── orders/
│   │   ├── router.py            # pay_order, checkout_and_send: pasan origin_client_id
│   │   └── schemas.py           # PayIn, CheckoutAndSendIn: + origin_client_id
│   └── table_sessions/
│       ├── router.py            # close_session (sin cambios de firma)
│       ├── schemas.py           # CloseSessionIn: + origin_client_id
│       └── service.py           # close_session: pasa origin_client_id a notify_payment_completed
├── core/
│   ├── notifications/
│   │   ├── dispatch.py          # notify_payment_completed: + origin_client_id
│   │   ├── summary.py           # summarize(): rama payment.completed usa formato correcto
│   │   └── channels/in_app.py   # InAppChannel.send(): reenvía origin_client_id en notification.created
│   └── events.py                # sin cambios (canal payment.completed de negocio, no de este bug)
└── tests/ (pytest, junto a cada módulo tocado)

# pos-heladeria (Angular)
src/app/
├── core/
│   ├── realtime/
│   │   └── realtime.service.ts          # + clientId (per-tab, sessionStorage)
│   └── notifications/
│       ├── notification-center.service.ts  # onNotificationCreated: compara origin_client_id
│       └── notification.model.ts           # NotificationCreatedEvent: + origin_client_id;
│                                            # summarize(): corrige formato de moneda (payment.completed)
└── modules/tables/
    ├── interfaces/dining.interface.ts      # CheckoutAndSendPayload / CloseSessionPayload: + origin_client_id
    ├── services/
    │   ├── dining-session.service.ts       # sin cambio de firma (ya reenvía el payload tal cual)
    │   └── pos-terminal.store.ts           # checkoutAndSend(): manda origin_client_id, quita el toast
    │                                        #   duplicado "Pedido cobrado, facturado y enviado a cocina"
    ├── components/
    │   └── session-bill-panel.component.ts # charge(): manda origin_client_id al cerrar sesión
    └── pages/
        └── table-sessions.component.ts      # modal "Pago registrado": + método de pago, + vuelto,
                                              #   + botón "Imprimir Factura" (un solo comprobante)
└── (tests *.spec.ts junto a cada archivo tocado, patrón ya usado en el repo)
```

**Structure Decision**: Web application de dos repositorios ya existentes (Principio XIV los
trata como proyectos independientes con su propia rama por spec). No se crea ningún proyecto,
carpeta de alto nivel ni módulo nuevo — todos los cambios caen dentro de archivos y carpetas que
ya existen, ampliados con los campos/llamadas descritos arriba.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |
