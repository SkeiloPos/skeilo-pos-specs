# Implementation Notes: Carta del menú para Cajero con estado Agotado

**Spec**: [spec.md](./spec.md) | **Tasks**: [tasks.md](./tasks.md) | **Fecha**: 2026-10-03

## Qué se verificó en esta sesión

- **Backend**: 1290/1290 tests de `app/characterization_tests` en verde
  (`./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'`),
  incluidos los 30 tests nuevos de esta spec (T007-T010, T023-T028, T038-T041) y la
  suite completa heredada, sin ninguna regresión.
- **Frontend**: `ng build --configuration development` en verde; `ng test --no-watch`
  (suite completa) con el mismo baseline de 19 fallas pre-existentes en 6 archivos no
  relacionados (`app.spec.ts`, `auth.service.spec.ts`, `menu.service.spec.ts`,
  `tenant.service.spec.ts`, `pos-checkout-panel.component.spec.ts`,
  `pos-order-panel.component.spec.ts`) — confirmado reproduciendo cada una sobre la
  rama `develop` limpia (`git stash -u`) antes de tocar nada; ninguna es nueva ni la
  causó este cambio.
- Cada escenario de `spec.md` (1-16) tiene al menos un test automatizado que lo cubre
  (ver tasks.md, columna de referencias a archivos de test).

## Qué queda pendiente (no verificable en este entorno)

Este entorno de trabajo no tiene PostgreSQL ni Docker disponibles (solo Redis en
6379) — ver memoria `how-to-run-sibling-repo-tests`. `quickstart.md` describe una
validación manual sobre un tenant real con ambos repos corriendo y un usuario Cajero
y Administrador reales; **no se ejecutó** esa validación manual de punta a punta en
esta sesión por esa limitación de entorno, no porque se haya omitido a propósito.

Antes de dar la funcionalidad por completamente cerrada (Constitución, "Un spec se
considera completado cuando..."), falta:

1. Levantar ambos repos contra una base de datos Postgres real (local o de
   staging), correr la migración `2d50957395dc_product_availability_audit_columns`
   y recorrer `quickstart.md` con un usuario Cajero y un Administrador reales.
2. Confirmar visualmente en el navegador: el interruptor "Agotado" en el listado y
   en el detalle, el efecto en la Terminal de mesas y en el menú QR servidos desde
   el backend real (no solo mockeados en los tests de componente), y el mensaje de
   rechazo al confirmar un carrito con un producto recién agotado.
3. Revisar la anomalía A-104 (`specs/000-reconocimiento/registro-de-anomalias.md`)
   una vez verificado lo anterior, y actualizar su "Estado final" si corresponde.

## Decisiones tomadas durante la implementación que no estaban en el plan original

- **Filtro "Disponibles/Agotados" en `GET /products`**: el plan no incluía
  explícitamente el query param `available` en el listado — se agregó durante T017
  porque FR-006/escenario 2 lo exigen y no existía ningún otro mecanismo para
  cumplirlo (filtrado client-side habría roto la paginación del servidor).
- **`MenuProduct.sold_out` opcional, no requerido**: `ng test` compila toda la
  suite de specs a la vez; un campo nuevo requerido en un tipo de dominio tan
  compartido como `MenuProduct` rompía ocho archivos de test no relacionados con
  esta spec. Se declaró opcional (`sold_out?: boolean`) para no tocar ese trabajo
  ajeno, consistente con el Principio V de la constitución.
- **Texto de confirmación ajustado**: el toast de éxito decía `"Fresa boom" marcado
  agotado` (con comillas, sin "como"); se corrigió a `Fresa boom marcado como
  agotado` para calzar literalmente con el escenario 3 de la spec.
