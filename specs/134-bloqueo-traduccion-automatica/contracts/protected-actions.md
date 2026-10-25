# Contrato: acciones protegidas y su bloqueo

**Cubre**: FR-012, FR-013, FR-014, FR-023 · **Historias**: US2, US3 · **Decisión**: [research.md](../research.md) 4

Ubicación (en `../pos-heladeria/src/app/core/integrity/`): `protected-actions.ts` (catálogo),
`page-integrity.interceptor.ts` (`pageIntegrityInterceptor`).

## Criterio (de la spec)

> Acción protegida = **crea un pedido, cobra, confirma o aprueba un pago, o registra un movimiento
> de dinero de caja** (FR-012 / Assumptions). Confirmar un pedido sin cobrarlo no entra.

Se enumera **por endpoint**, no por botón, para que ninguna superficie se quede sin proteger —en
particular "Pagos por confirmar" del cajero, la que las specs de cobro suelen olvidar—.
Las rutas son relativas a `environment.apiBaseUrl`; se compara el método y la ruta **sin query**,
anclada.

## Catálogo — acciones protegidas

### Menú QR del comensal

| Id | Método y ruta | Etiqueta (`label`) | Quién la dispara hoy |
|---|---|---|---|
| QR-1 | `POST /cart/submit` | enviar el pedido | `payment-method-step`, `transfer-details-step` (vía `DinerService.submitCart`) |
| QR-2 | `POST /cart/orders/{id}/payment-attempts` | pagar el pedido | `public-menu` (vía `DinerService.createPaymentAttempt`, pago/reintento) |

### Panel del personal

| Id | Método y ruta | Etiqueta | Superficie |
|---|---|---|---|
| P-1 | `POST /orders` | crear el pedido | armado de orden manual / Terminal (`createManualOrder`) |
| P-2 | `POST /orders/{id}/items` | agregar productos al pedido | armado del pedido en la Terminal (`addOrderItems`) |
| P-3 | `POST /orders/{id}/checkout-and-send` | cobrar el pedido | panel de cobro de la Terminal (`PosCheckoutPanelComponent` → store) |
| P-4 | `POST /orders/{id}/complementary-payment` | cobrar el saldo pendiente | Terminal (`settleComplementaryPayment`, spec 123) |
| P-5 | `POST /orders/payment-attempts/{id}/approve` | aprobar el pago | **Pagos por confirmar** (`PaymentAttemptReviewPanelComponent`) |
| P-6 | `POST /orders/payment-attempts/{id}/confirm-cash` | confirmar el pago en efectivo | **Pagos por confirmar** |
| P-7 | `POST /orders/payment-attempts/{id}/adjust-split` | reajustar el pago | **Pagos por confirmar** (servicio listo, sin llamador de UI hoy) |
| P-8 | `POST /table-sessions/{id}/close` | cobrar y cerrar la cuenta de la mesa | cuenta de sesión de mesa (`SessionBillPanelComponent`) |
| P-9 | `POST /sales` | cobrar la venta | `SalesService.checkout` (sin llamador de UI hoy) |
| P-10 | `POST /cash/shifts/open` | abrir el turno de caja | caja (`CashSessionStore.abrirCaja`) |
| P-11 | `POST /cash/shifts/{id}/movements` | registrar el movimiento de caja | caja (`CashSessionStore.confirmarMovimiento`) |
| P-12 | `POST /cash/shifts/{id}/close` | cerrar el turno de caja | caja (`CashSessionStore.confirmarArqueoYCerrar`) |

P-7 y P-9 no tienen llamador de UI hoy; se incluyen porque cumplen el criterio y quedarían
protegidos el día que alguien los use.

## Evaluadas y **no** protegidas (con razón)

| Ruta | Por qué no |
|---|---|
| `POST/PATCH/DELETE /cart/items…` | borrador del carrito: no mueve dinero y se revisa en "Revisar" antes de enviar; tras recargar se ve el carrito real |
| `POST /cart/sessions`, `POST /cart/leave`, `POST /cart/orders/{id}/cancel` | unirse/salir/cancelar: no crean pedido ni cobran |
| `POST /orders/draft-preview`, `GET …/checkout-preview` | solo cálculo, sin efecto |
| `POST /orders/{id}/ready`, `…/start-preparation`, `PATCH …/kitchen` | flujo de cocina/estado: fuera del criterio (no crean, cobran ni confirman un pago) |
| `POST /orders/{id}/confirm` | acepta un pedido `recibida` → `abierta` y descuenta inventario; no crea, cobra ni aprueba un pago. Si falla (p. ej. falta de stock) queda en `recibida` y se reintenta tras recargar. Hoy ningún componente lo llama (solo existe en `DiningSessionService.confirmOrder`) |
| `POST /orders/{id}/move`, `POST /orders/merge` | mueven o unen pedidos entre mesas; no mueven dinero |
| `POST /orders/{id}/cancel`, `POST /orders/items/{id}/void`, `…/additions`, `…/toppings` y su `PATCH`/`DELETE` | modificaciones y anulaciones de líneas: fuera del criterio literal de la spec |
| `POST /orders/payment-attempts/{id}/reject` | rechazar no confirma ni aprueba un pago; el reintento tras recargar es seguro |
| `POST /table-sessions/{id}/release` | libera mesa sin cobrar |
| `POST /cash/registers` | crea una caja, no mueve dinero |
| Inventario, compras, catálogo, usuarios, planes, super-admin, notificaciones, auth | fuera del criterio |

> **Punto de negocio a confirmar con el dueño (no bloquea el plan)**: la frontera de este conjunto.
> Se incluyó P-2 ("agregar productos a un pedido existente") por ser el armado de la Terminal y se
> dejaron fuera anulaciones/adiciones/rechazos. Mover una ruta de una tabla a otra es editar una fila
> de `PROTECTED_ACTIONS` y su prueba; no cambia ningún otro módulo.
>
> **Decidido (opción A, 2026-10-24, Leonardo Gómez)**: `POST /orders/{id}/confirm`, `move` y `merge`
> quedan fuera del catálogo (no mueven dinero). Sigue pendiente de confirmar P-2 y la exclusión de
> anulaciones, adiciones y rechazos (T038).

## `pageIntegrityInterceptor`

```text
si !req.url.startsWith(environment.apiBaseUrl)        → next(req)
si !integrity.altered()                               → next(req)
si coincide con una fila de PROTECTED_ACTIONS         →
     integrity.notifyBlocked(fila.label)
     return throwError(() => new HttpErrorResponse({
        status: 423, statusText: 'Page Altered', url: req.url,
        error: { detail: `No se pudo ${fila.label}: la página fue alterada por el navegador. Recarga para continuar.`,
                 code: 'page_altered' } }))
en otro caso                                          → next(req)
```

- Se registra **antes** de `authTokenInterceptor` en `withInterceptors([...])`: el rechazo ocurre
  sin tocar tokens ni consumir un refresh.
- **No cancela ni duplica** (FR-014): solo actúa sobre peticiones que aún no salieron; las que ya
  están en vuelo siguen. El rechazo es previo a cualquier efecto en el servidor.
- `423` no lo interpreta ningún código existente; el `extractError` de cada servicio lee
  `error.detail` (cadena) y lo muestra tal cual, así que cada pantalla enseña el motivo sin cambios.
  El banner refuerza con `blockedNotice` aunque la pantalla de origen no muestre su error.
- Nada de lo protegido se decide por el **texto en pantalla**: el valor enviado sigue saliendo del
  estado de la aplicación (FR-023); este contrato no cambia cómo se arma ninguna petición.

## `inflightRequestsInterceptor` (compañero, para el momento seguro)

Cuenta las peticiones de escritura (`POST/PUT/PATCH/DELETE`) a `environment.apiBaseUrl` en vuelo
(`UpdateGateService.beginRequest/endRequest` con `finalize`). No bloquea ni modifica nada. Ver
[app-update.md](./app-update.md).

## Pruebas (`page-integrity.interceptor.spec.ts`, patrón de `auth-token.interceptor.spec.ts`)

| Prueba |
|---|
| Para **cada fila** del catálogo: con la página alterada, la petición se rechaza con `status 423`, `detail` en español con su `label`, y **no** llega a `HttpTestingController`; con la página íntegra, pasa |
| Cada ruta "evaluada y no protegida" pasa **siempre**, incluso alterada |
| Una ruta con query (`?x=1`) y con id distinto coincide; una ruta ajena a `apiBaseUrl` nunca se toca |
| Una petición enviada **antes** de alterarse completa su respuesta sin interferencia |
| `notifyBlocked` recibe el `label` correcto |
