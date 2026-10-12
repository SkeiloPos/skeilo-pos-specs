# Contrato: formulario "Abrir caja" (frontend) — cambios

**Componentes existentes**: `CashOpenComponent`
(`../pos-heladeria/src/app/modules/cash-register/components/cash-open.component.ts`) +
`CashSessionStore`
(`../pos-heladeria/src/app/modules/cash-register/services/cash-session.store.ts`). Esta spec no
cambia el flujo de selección de caja ni la creación de cajas nuevas; agrega validación del campo
de saldo inicial, exigida por FR-002/FR-003.

## Estado derivado nuevo

| Derivado | Dónde vive | Definición |
|---|---|---|
| `aperturaDisabled` | `CashSessionStore` (nuevo `computed`) | `isSubmitting() \|\| !selectedRegisterId() \|\| openingAmount() <= 0` |

## Comportamiento de la pantalla

- **Al cargar la pantalla** (sin ninguna interacción del usuario): `openingAmount()` vale `0`
  (valor inicial del signal, `cash-session.store.ts:101`) → `aperturaDisabled()` es `true` y el
  mensaje de error ya es visible debajo del campo, sin esperar que el usuario toque nada
  (Clarification, sesión 2026-10-12; User Story 1, escenario 1).
- **Si el usuario borra el campo por completo**: `MoneyInputComponent` emite `null`;
  `(ngModelChange)="store.openingAmount.set($event ?? 0)"` (sin cambios, ya existente en
  `cash-open.component.ts:83`) normaliza ese `null` a `0` — mismo resultado que el caso anterior,
  mismo mensaje, botón deshabilitado (User Story 1, escenario 2).
- **Si el usuario ingresa un valor mayor a cero**: `openingAmount()` pasa a ese valor,
  `aperturaDisabled()` se vuelve `false` (siempre que también haya una caja seleccionada) y el
  mensaje desaparece de inmediato, sin recargar la pantalla (User Story 1, escenario 3).
- **Botón "Abrir caja y comenzar turno"**: su `[disabled]` pasa de
  `store.isSubmitting() || !store.selectedRegisterId()` a `store.aperturaDisabled()`. Mientras esté
  deshabilitado, ningún clic dispara `store.abrirCaja()` ni, por lo tanto, ninguna petición HTTP
  (SC-001).
- **Campo de saldo inicial (`<app-money-input>`)**: gana `[invalid]="store.openingAmount() <= 0"`,
  que `MoneyInputComponent` ya traduce en borde rojo (`shared/money-input/money-input.component.ts:79-83`,
  sin cambios en ese componente compartido).
- **Mensaje bajo el campo**: nuevo `<p class="text-red-500 text-xs mt-1">El saldo inicial debe ser
  mayor a cero para abrir la caja</p>`, visible exactamente cuando `store.openingAmount() <= 0` —
  mismo patrón que `change-password.component.ts:71-74` (párrafo condicional bajo un input con
  `[invalid]`).

## Qué NO cambia

- La condición de caja seleccionada (`!store.selectedRegisterId()`) sigue siendo parte del
  deshabilitado — no se relaja ni se endurece.
- El filtrado de caracteres de `MoneyInputComponent` (que ya descarta cualquier signo negativo
  mientras se escribe) no se toca — esta spec no depende de que el frontend pueda producir un valor
  negativo; eso solo es alcanzable contra el backend directamente (ver
  [post-shifts-open.md](./post-shifts-open.md)).
- `abrirCaja()` (`cash-session.store.ts:442-457`) no cambia su lógica interna más allá de que ahora
  es físicamente imposible invocarlo con `openingAmount() <= 0` desde este botón — sigue llamando a
  `this.api.openShift(regId, Number(this.openingAmount()) || 0)` igual que hoy.
- `abrirCajaDesdeOverview()` (`cash-session.store.ts:320-325`) sigue reseteando `openingAmount` a
  `0` al entrar a la pantalla desde la gestión de cajas (admin) — con el cambio de esta spec, eso
  simplemente deja al formulario en el mismo estado "recién cargado, mensaje visible" descrito
  arriba; no requiere ningún ajuste propio.
- `nuevoTurno()` (`cash-session.store.ts:569-585`) también resetea `openingAmount` a `0` (línea
  577) al cerrar un turno y empezar el siguiente — para un cajero no-admin, navega directo a
  `screen.set('apertura')` (línea 584), el mismo camino más frecuente hacia esta pantalla. Con el
  cambio de esta spec, eso deja al formulario en el mismo estado "recién cargado, mensaje visible"
  descrito arriba; no requiere ningún ajuste propio — mismo razonamiento que
  `abrirCajaDesdeOverview()` arriba.

## Casos de prueba de referencia (para `/speckit-tasks`)

1. Render inicial con una caja seleccionada, sin tocar el campo de saldo → mensaje visible, botón
   deshabilitado (User Story 1, escenario 1).
2. Borrar el campo tras haber escrito algo → mismo resultado que el caso 1 (User Story 1,
   escenario 2).
3. Escribir un valor mayor a cero → mensaje desaparece, botón habilitado si hay caja seleccionada
   (User Story 1, escenario 3).
4. Caja seleccionada + saldo inicial válido + clic en "Abrir caja y comenzar turno" → se llama
   `store.abrirCaja()`, se abre el turno, navega a la terminal (User Story 3, escenario 1).
5. Ninguna caja seleccionada, saldo inicial válido → botón sigue deshabilitado (la condición de
   caja seleccionada, ya existente, no se relaja).
