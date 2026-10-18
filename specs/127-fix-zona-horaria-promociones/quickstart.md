# Quickstart: Validar "Vigencia de promociones en la hora local del tenant"

## Prerrequisitos

- `pos-backend` corriendo localmente (venv del proyecto:
  `cd ../pos-backend && ./env/bin/python -m ...`), con al menos un tenant de prueba cuya
  columna `timezone` sea `America/Bogota` (valor por defecto) y, para el Escenario 4, un
  segundo tenant con una zona horaria distinta (p. ej. `America/Mexico_City`, UTC-6).
- `pos-heladeria` corriendo localmente (`ng serve` o equivalente).
- Para los escenarios que dependen de la hora del día, o bien ejecutarlos cerca de las 7pm
  hora de Bogotá, o simular la hora del sistema/navegador (p. ej. cambiar la zona horaria del
  SO a UTC para reproducir el defecto original sin esperar la hora real).

## Escenario 1 — Crear una promoción después de las 7pm no la desplaza al día siguiente (US1, FR-001)

1. Con el reloj del navegador en una hora posterior a las 7pm hora de Bogotá (o el SO en
   UTC, que reproduce el mismo corrimiento), crear una promoción con ventana "lunes a
   jueves, 5pm a 12am", sin indicar explícitamente una fecha de inicio.
2. **Esperado**: la fecha de inicio registrada corresponde al día calendario de Bogotá en
   el momento de guardar (hoy), no al día siguiente (UTC).
3. Consultar la vigencia de esa promoción (p. ej. desde el menú público o el carrito) en ese
   mismo momento, dentro de la ventana.
4. **Esperado**: la promoción se evalúa como vigente de inmediato — no "arranca mañana".

## Escenario 2 — Medianoche local: el día de guardado es consistente en todo el flujo (US1, FR-001)

1. Entre las 11:55pm y las 12:05am hora de Bogotá, guardar una promoción nueva sin fecha de
   inicio explícita.
2. **Esperado**: el día de calendario usado para `starts_at` es el mismo que el reloj local
   del tenant marcaba al momento exacto de guardar — ni "ayer" ni "mañana" por un cálculo en
   UTC.

## Escenario 3 — Dos tenants con zonas horarias distintas evalúan cada uno la suya (US2, FR-002, FR-003)

1. Configurar dos tenants con `timezone` distinta (p. ej. uno en `America/Bogota`, otro en
   `America/Mexico_City`).
2. En cada uno, crear una promoción con la misma ventana horaria (p. ej. "todos los días,
   5pm a 12am").
3. En un instante real donde esa ventana aplica para un tenant pero no para el otro (por la
   diferencia de huso horario), consultar la vigencia de cada promoción en su propio tenant.
4. **Esperado**: cada tenant evalúa su propia promoción según su propia zona horaria
   configurada — el resultado de uno no depende de la configuración del otro.

## Escenario 4 — Carrito, cobro y menú público concuerdan siempre (US2, FR-003)

1. Con una promoción vigente en este instante para un tenant, verificar el mismo resultado
   de "aplica/no aplica" en los tres puntos de entrada:
   - el carrito del comensal (QR),
   - el cobro de un pedido o de una mesa (checkout/compute_bill),
   - el menú público (`GET /menu` o la vista del menú vía QR).
2. **Esperado**: los tres coinciden siempre entre sí para el mismo instante y el mismo
   tenant — ninguno queda desfasado respecto a los otros dos.

## Escenario 5 — El cruce de medianoche sigue funcionando exactamente igual (FR-004, A-57)

1. Con una promoción "lunes a jueves, 5pm a 12am", consultar su vigencia el martes a la
   1:00am hora local.
2. **Esperado**: sigue vigente (el día de inicio de la ventana, lunes, sigue "abierto" hasta
   que termina la ventana al cruzar medianoche) — comportamiento ya existente (A-57, spec
   040), sin ningún cambio introducido por esta corrección.
3. Consultar la misma promoción el martes a las 3:00am.
4. **Esperado**: ya no vigente (fuera de la ventana).

## Verificación automatizada

- Backend: `cd ../pos-backend && ./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'`
  debe seguir en verde — en particular `test_promotions_service.py`, `test_promotions_rules_admin.py`.
- Backend (script de CI dedicado, no pytest): `cd ../pos-backend && ./env/bin/python -m app.scripts.test_promotions_rules`
  debe seguir en verde **sin modificación** — es la prueba explícita de que el cruce de
  medianoche y la atribución de día (A-57) no cambiaron (research.md, Decisión 4).
- Frontend: `cd ../pos-heladeria && npx ng test --watch=false --include='src/app/modules/promotions/**/*.spec.ts'`
  — confirmar en verde los tests ya existentes más los nuevos de regresión que agregue la
  implementación para `starts_at`/`businessToday`.
- Diferenciar por archivo contra el baseline de fallas preexistentes ya documentado en la
  memoria del proyecto antes de asumir que algo se rompió (memoria: "no proactive background
  fetches" no aplica aquí; ver la nota de baseline de `ng test`).
