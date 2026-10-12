# Quickstart: Validación de saldo inicial mayor a cero al abrir caja

**Spec**: [spec.md](./spec.md) | **Contratos**:
[contracts/post-shifts-open.md](./contracts/post-shifts-open.md),
[contracts/cash-open-form.md](./contracts/cash-open-form.md)

## Prerrequisitos

- `pos-backend` corriendo localmente (nativo, no Docker — ver nota de memoria del proyecto) con la
  migración de esta spec aplicada (`alembic upgrade head`).
- `pos-heladeria` corriendo localmente contra ese backend (`ng serve` o equivalente).
- Usuario cajero o admin autenticado.
- Al menos una caja registradora creada, **sin** un turno abierto actualmente (si queda uno abierto
  de una prueba anterior, cerrarlo primero desde la pantalla de caja).

## Escenario 1 — Mensaje visible desde la carga de la pantalla (User Story 1, escenario 1)

1. Entrar a la pantalla de caja y seleccionar una caja sin turno abierto.
2. **Esperado**: sin tocar el campo de saldo inicial (queda en `0` por defecto), el mensaje "El
   saldo inicial debe ser mayor a cero para abrir la caja" ya es visible debajo del campo, el borde
   del campo está en rojo, y el botón "Abrir caja y comenzar turno" está deshabilitado.
3. Intentar hacer clic en el botón deshabilitado → no debe salir ninguna petición de red (verificar
   en las herramientas de desarrollador del navegador, pestaña Network: no debe aparecer ninguna
   llamada a `POST /cash/shifts/open`).

## Escenario 2 — Campo vacío se trata igual que cero (User Story 1, escenario 2)

1. Sobre la misma pantalla del Escenario 1, escribir cualquier valor en el campo de saldo inicial
   y luego borrarlo por completo.
2. **Esperado**: mismo resultado que el paso 2 del Escenario 1 — mensaje visible, botón
   deshabilitado.

## Escenario 3 — Ingresar un valor válido habilita la apertura (User Story 1, escenario 3 / User Story 3)

1. Sobre la misma pantalla, ingresar un valor mayor a cero (p. ej. `50000`).
2. **Esperado**: el mensaje desaparece de inmediato, el borde del campo vuelve a su color normal,
   y el botón se habilita (asumiendo que ya hay una caja seleccionada).
3. Hacer clic en "Abrir caja y comenzar turno".
4. **Esperado**: el turno se abre con normalidad, con `opening_amount = 50000`, y se navega a la
   terminal de ventas/mesas — sin ninguna fricción adicional respecto al comportamiento actual.

## Escenario 4 — El backend rechaza `opening_amount = 0` directamente (User Story 2, escenario 1)

Con un cliente HTTP (`curl`/Postman/Insomnia), autenticado con un token válido:

```bash
curl -i -X POST http://localhost:8000/api/v1/cash/shifts/open \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"cash_register_id": "<id-de-una-caja-sin-turno-abierto>", "opening_amount": 0}'
```

**Esperado**: `422 Unprocessable Entity`, cuerpo con un mensaje que indica que el saldo inicial es
obligatorio y debe ser mayor a cero. Verificar en la base de datos (o en `GET
/cash/shifts/current?cash_register_id=...`, que debe seguir devolviendo `404`) que no se creó
ningún `CashShift`.

## Escenario 5 — El backend rechaza un saldo inicial negativo (User Story 2, escenario 2)

Mismo request que el Escenario 4, pero con `"opening_amount": -50000`.

**Esperado**: mismo resultado que el Escenario 4 — `422`, mismo criterio de mensaje, ningún
`CashShift` creado.

## Escenario 6 — El backend acepta un saldo inicial válido vía API directa (User Story 2, escenario 3)

Mismo request que el Escenario 4, pero con `"opening_amount": 75000` (y una caja distinta, sin
turno abierto).

**Esperado**: `201 Created`, cuerpo con el `CashShift` creado y `opening_amount: "75000.00"`. Sin
cambios respecto al comportamiento actual para valores válidos.

## Escenario 7 — Petición que omite el campo (Edge Case de spec.md)

Mismo request que el Escenario 4, pero sin incluir `opening_amount` en el cuerpo del JSON.

**Esperado**: mismo resultado que el Escenario 4 — `422` (porque el valor omitido cae en el
default `0`).

## Escenario 8 — No hay regresión sobre turnos ya abiertos antes del despliegue (FR-007)

1. Si es posible en el entorno de pruebas, identificar o simular un `CashShift` ya existente con
   `opening_amount = 0` (creado antes de aplicar la migración de esta spec).
2. Aplicar la migración (`alembic upgrade head`).
3. **Esperado**: la migración se aplica sin error; ese turno histórico sigue existiendo tal cual,
   visible en el histórico de turnos (`GET /cash/shifts`) sin ningún cambio en su
   `opening_amount`, sin bloquearse ni cerrarse forzosamente.

## Verificación automatizada (referencia)

- **Backend**: `cd ../pos-backend && ./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'`
  — confirma que ningún characterization test existente se rompe (ver research.md D4 para el
  ajuste esperado en los fixtures `make_cash_shift()`). Casos de prueba nuevos (endpoint +
  `CheckConstraint`) listados en
  [contracts/post-shifts-open.md](./contracts/post-shifts-open.md), implementados como script
  nuevo en `app/scripts/` (mismo patrón que `test_cash_net_sales.py`, spec 108).
- **Frontend**: `npx ng test --watch=false --include='src/app/modules/cash-register/**/*.spec.ts'`
  — casos de prueba nuevos (store + componente) listados en
  [contracts/cash-open-form.md](./contracts/cash-open-form.md).
