# Quickstart: validar "Cliente Consumidor final por defecto en Mesa y Para llevar"

Guía de validación de punta a punta. Cada escenario cita el requisito que prueba. Los contratos
están en [contracts/](./contracts/) y el modelo de datos/estado en [data-model.md](./data-model.md).

## Prerrequisitos

- `pos-backend` y `pos-heladeria` en la rama de la funcionalidad (`feat/091-default-customer-name`
  en ambos, research.md / Principio XIV), con un tenant de prueba.
- Anomalía **A-99** ya registrada en `registro-de-anomalias.md` (bloquea implementar, Principio II).
- Al menos una mesa libre y una categoría con un producto disponible, para poder armar el carrito
  de "Nueva orden" en los tres tipos (Mesa, Para llevar, Domicilio).

## Automáticos

```bash
# backend (venv del proyecto — ver memoria "how-to-run-sibling-repo-tests")
cd pos-backend
./env/bin/python -m unittest app.characterization_tests.test_orders_service -v
./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'   # regresión completa

# frontend
cd ../pos-heladeria
npx ng test --watch=false --include='src/app/modules/tables/pages/manual-order-page.component.spec.ts'
npx ng test --watch=false --include='src/app/modules/tables/services/pos-terminal.store.spec.ts'
npx ng test --watch=false   # regresión completa
```

Esperado: todo en verde. Los tests reescritos de A-88 (research.md, hechos verificados) deben
pasar con la **nueva** redacción; el resto de la suite (incluida la de spec 087 no relacionada con
A-88) sigue sin cambios.

## Escenarios manuales (Terminal de mesas, UI real)

Los 10 escenarios del pedido original, en el orden en que se dieron:

| # | Escenario | Pasos | Esperado | Requisito |
|---|---|---|---|---|
| 1 | Valor por defecto en Mesa | Abrir "Nueva orden" → pestaña "Mesa" | El campo "Cliente" muestra "Consumidor final" como texto real (seleccionable, no placeholder) | FR-001 |
| 2 | Valor por defecto en Para llevar | Pestaña "Para llevar" | El campo "Cliente / Para llevar" muestra "Consumidor final" | FR-001 |
| 3 | Editar antes de crear | Con el valor por defecto visible, clic en el campo, escribir "María Pérez", agregar un producto, "Crear pedido" | El texto se seleccionó completo al hacer clic; "María Pérez" reemplazó el valor; el pedido queda con cliente "María Pérez" | FR-002, FR-003 |
| 4 | Campo vaciado antes de crear | Borrar el contenido del campo en Mesa o Para llevar, agregar un producto, "Crear pedido" | El botón no se deshabilita; el pedido se guarda con "Consumidor final" | FR-004, FR-005 |
| 5 | Cambio de pestaña sin editar | En Mesa/Para llevar con el valor por defecto intacto, pasar a "Domicilio" | El campo queda vacío con su placeholder "Ej: Juan Pérez"; "Crear pedido" sigue exigiendo nombre/dirección/valor en Domicilio | FR-008 |
| 6 | Cambio de pestaña con nombre propio | Escribir "Carlos Ruiz", pasar por "Mesa", "Para llevar" y "Domicilio" en cualquier orden | "Carlos Ruiz" se conserva en las tres | FR-009 |
| 7 | Regreso desde Domicilio vacío | En "Domicilio" con el campo vacío, pasar a "Mesa" o "Para llevar" | Vuelve a mostrar "Consumidor final" | FR-010 |
| 8 | Reinicio tras crear un pedido | Crear un pedido de Mesa o Para llevar con "María Pérez"; abrir "Nueva orden" de nuevo | El campo muestra "Consumidor final", no "María Pérez" | FR-011 |
| 9 | Petición directa sin nombre | Con herramientas de API, `POST /orders` con `channel=POS`, `order_type=DINE_IN` o `TAKEAWAY`, sin `customer_name` | `201`, pedido con cliente "Consumidor final"; lo mismo para `DELIVERY` sin nombre sigue dando `422` | FR-006, FR-007 — ver [contracts/post-orders-customer-name.md](./contracts/post-orders-customer-name.md) |
| 10 | Pedidos existentes | Abrir Órdenes y Ventas con pedidos creados antes de desplegar | Se muestran sin ningún cambio | FR-012 |

### Verificación adicional (no estaba en los 10 escenarios, pero la cubre el plan)

| # | Escenario | Pasos | Esperado | Requisito |
|---|---|---|---|---|
| 11 | Canal fuera de la Terminal sigue exigiendo nombre | `POST /orders` con `channel=WHATSAPP` (o `API`), `order_type=TAKEAWAY`, sin `customer_name` | `422 "El nombre del cliente es obligatorio."` — sin cambios | research.md D6, FR-013 |
| 12 | Menú QR no se ve afectado | Un comensal escanea el QR, escribe su nombre y hace un pedido | Comportamiento idéntico al actual; su nombre nunca se reemplaza por "Consumidor final" | FR-013 |

## Criterio de aceptación de la funcionalidad

Los 12 escenarios pasan (los 10 del pedido original + los 2 de verificación adicional) y las dos
suites automáticas (backend y frontend) quedan en verde, sin fallas nuevas fuera de los archivos
que esta spec toca a propósito.

## Verificación 2026-10-01 (implementación)

Estado de cada escenario tras implementar T001–T029. Esta funcionalidad es casi enteramente lógica
(sin PostgreSQL, sin condiciones de carrera reales que verificar como en spec 085); los 12
escenarios quedaron cubiertos por tests automáticos y por el alcance exacto del `git diff` de
ambos repositorios (sin tocar Órdenes, Ventas ni el menú QR). **Falta únicamente** el repaso visual
en un navegador real con la Terminal levantada (texto seleccionado al enfocar, animación de
pestañas) — no hay entorno con base de datos ni panel corriendo en esta sesión.

| # | Escenario | Estado | Cómo se verificó |
|---|---|---|---|
| 1 | Valor por defecto en Mesa | Automático; **repaso visual pendiente** | `manual-order-page.component.spec.ts`: "el campo Cliente precarga 'Consumidor final', editable" |
| 2 | Valor por defecto en Para llevar | Automático; **repaso visual pendiente** | `manual-order-page.component.spec.ts`: "al seleccionar 'Para Llevar'..." |
| 3 | Editar antes de crear | Automático; **repaso visual pendiente** | `pos-terminal.store.spec.ts` (reemplaza el valor), `manual-order-page.component.spec.ts` (selección completa al enfocar + "al confirmar con un nombre diligenciado") |
| 4 | Campo vaciado antes de crear | Automático | "confirmar con el campo Cliente vaciado en Mesa SÍ crea el pedido" + prueba de backend `en_pos_usa_consumidor_final` |
| 5 | Cambio de pestaña sin editar | Automático | "con el valor por defecto intacto, cambiar a 'Domicilio'..." (componente) + "cambiar a domicilios... lo vacía" (store) |
| 6 | Cambio de pestaña con nombre propio | Automático | `pos-terminal.store.spec.ts`: "se conserva al recorrer las tres pestañas" |
| 7 | Regreso desde Domicilio vacío | Automático | `pos-terminal.store.spec.ts`: prueba de round-trip |
| 8 | Reinicio tras crear un pedido | Automático | "al reabrir 'Nueva orden' (ngOnInit de nuevo)..." |
| 9 | Petición directa sin nombre | Automático | `test_orders_service.py`: `..._en_pos_usa_consumidor_final` (DINE_IN/TAKEAWAY) y `test_create_order_delivery_sigue_validado_una_sola_vez` (sin cambios) |
| 10 | Pedidos existentes | Verificado por alcance | `git diff` no toca ningún código de lectura/listado de Órdenes o Ventas; sin migración |
| 11 | Canal fuera de la Terminal | Automático | `test_create_order_takeaway_sin_nombre_cliente_en_whatsapp_sigue_rechazando_422` |
| 12 | Menú QR no se ve afectado | Automático + verificado por alcance | `test_create_order_dine_in_con_participant_sin_nombre_explicito_se_autocompleta` sin modificar; `git diff` no toca ningún archivo del menú QR |
