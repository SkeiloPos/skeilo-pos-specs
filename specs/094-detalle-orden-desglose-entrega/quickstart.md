# Quickstart — Validación de la spec 094

**Spec**: [spec.md](./spec.md) · **Plan**: [plan.md](./plan.md) · **Contratos**: [contracts/](./contracts/) · **Modelo**: [data-model.md](./data-model.md)

Guía para comprobar de extremo a extremo que cada historia funciona. Los detalles de
implementación viven en `tasks.md`; aquí solo se ejecuta y se verifica.

---

## 0. Prerrequisitos

- `pos-backend` y `pos-heladeria` en la rama `feat/094-order-detail-billing-breakdown`
  (Principio XIV), creadas desde la rama en curso **antes** de tocar código.
- **Sin migración**: esta spec no cambia el esquema. Si `alembic upgrade head` tuviera algo
  pendiente, es de otra spec.
- Un negocio de pruebas con: una mesa con QR, un turno de caja abierto, un método de pago en
  efectivo, y estos pedidos (se crean en los pasos siguientes si no existen):
  1. pedido de **mesa cobrado** con 2 × un producto de $ 8.000, sin promoción;
  2. pedido con **promoción** aplicada (una sola), cobrado;
  3. pedido **para llevar** cobrado;
  4. pedido **a domicilio** con los cuatro campos diligenciados y envío de $ 3.000;
  5. pedido a domicilio con **solo dirección y teléfono**, envío $ 0 y sin notas;
  6. pedido **abierto** (sin cobrar) con una promoción vigente que le aplicaría;
  7. pedido de mesa cobrado dentro de una **cuenta unificada con otro pedido**;
  8. pedido **cancelado**;
  9. pedido con **tres líneas, una anulada**;
  10. pedido con un **adicional por línea** (Menú QR) y uno con **combo**.
- Dos tenants con sesión activa en navegadores distintos, para el paso §7.
- Chrome (para el portapapeles) y un navegador o contexto sin portapapeles disponible
  (p. ej. abrir la app por `http://` en LAN, no `localhost`) para el paso §5.4.

### Comandos de verificación automática

```bash
# pos-backend  (desde la raíz del repo, con el venv activo)
env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'

# pos-heladeria
npm test
```

Ambas suites deben quedar en verde. **Antes de empezar**, medir la línea base de la suite de
frontend con `git stash`: arrastra fallos preexistentes ajenos a esta spec, y sin la línea
base es imposible saber si un rojo es nuevo.

---

## 1. Verificación previa de datos (bloquea la implementación del resumen)

Decisión D5 de [research.md](./research.md): el desglose de una factura 1:1 se publica tal
cual, y eso solo cumple `Subtotal − Descuento + Envío = Total` si impuesto y propina valen
cero. Antes de implementar, medir en la base de datos real del tenant:

```sql
-- `tenant` es un alias que SQLAlchemy traduce por sesión (`schema_translate_map`,
-- app/core/db.py:44-47): en la base real cada tenant tiene su propio esquema, así que
-- medir uno solo no despeja la compuerta. En psql, generar y ejecutar la consulta para
-- todos los esquemas registrados:
SELECT format(
         'SELECT %L AS esquema, count(*) AS con_impuesto_o_propina FROM %I.sales WHERE tax > 0 OR tip > 0',
         schema, schema)
FROM shared.tenants
ORDER BY schema \gexec
```

- **`0` en todos los esquemas** (lo esperado, porque el impuesto está deprecado y ninguna
  pantalla envía propina) ⇒ seguir sin cambios.
- **Más de `0` en cualquier esquema** ⇒ **parar**: qué mostrar en esos pedidos es una
  decisión de negocio nueva. Registrarla como anomalía antes de tocar la pantalla, anotando
  en qué tenants aparece.
- La compuerta se repite **antes de desplegar en un tenant nuevo**: un `0` medido hoy no
  dice nada de un esquema creado después.

---

## 2. Contrato de la API (Historia 1, backend)

Con un pedido de cada caso a mano:

```bash
# 1:1 — el desglose sale de la factura
curl -s -H "Authorization: Bearer $TOKEN" "$API/orders/$ORDER_COBRADO" | jq '.billing'
# ⇒ state "factura_propia", source "factura", total == total de la factura en Ventas

# Cuenta unificada con dos pedidos
curl -s -H "Authorization: Bearer $TOKEN" "$API/orders/$ORDER_UNIFICADO" | jq '.billing'
# ⇒ state "factura_agrupada", source "pedido"

# Pedido abierto
curl -s -H "Authorization: Bearer $TOKEN" "$API/orders/$ORDER_ABIERTO" | jq '.billing'
# ⇒ state "sin_factura", discount "0.00", promotions []

# El listado NO calcula billing
curl -s -H "Authorization: Bearer $TOKEN" "$API/orders?page=1&size=5" | jq '.items[0].billing'
# ⇒ null
```

Comprobaciones aritméticas sobre cada respuesta (G1, G2 del contrato):

```bash
curl -s -H "Authorization: Bearer $TOKEN" "$API/orders/$ORDER" | jq '
  ([.items[] | select(.estado_cocina != "anulado") | (.line_total|tonumber)] | add // 0) as $suma
  | { suma_lineas: $suma,
      subtotal: (.billing.subtotal|tonumber),
      cuadra_subtotal: ($suma == (.billing.subtotal|tonumber)),
      cuadra_total: (((.billing.subtotal|tonumber) - (.billing.discount|tonumber)
                      + (.billing.delivery_fee|tonumber)) == (.billing.total|tonumber)) }'
```

Ambos `cuadra_*` deben ser `true` en todos los pedidos de la lista de prerrequisitos
(SC-007).

---

## 3. Historia 1 — Verificar el cobro sin salir de la pantalla (P1)

Abrir `/dashboard/orders/:id` para cada pedido y verificar:

| # | Pedido | Esperado | Escenario |
|---|---|---|---|
| 1 | Mesa, 2 × $ 8.000, sin promoción | Línea: cantidad 2, unitario `$ 8.000`, importe `$ 16.000`. Resumen: Subtotal `$ 16.000`, Total `$ 16.000`, **sin** fila de descuento ni de envío | US1 §1 |
| 2 | Con promoción "2 x $12.000", descuento $ 4.000 | Resumen: Subtotal `$ 28.000`, fila `2 x $12.000 − $ 4.000`, Total `$ 24.000`. Las líneas muestran importes **de lista** y suman exactamente $ 28.000 | US1 §2 |
| 3 | Descuento sin nombre de promoción | La fila dice `Descuento − $ 2.000` | US1 §3 |
| 4 | Pedido viejo cuyo producto hoy cuesta más | El unitario y el total siguen siendo los de entonces | US1 §4 |
| 5 | Cancelado | Desglose con los valores originales **y** etiqueta `Cancelada`; **sin** el aviso "El descuento se calcula al cobrar" (D7) | US1 §5 |
| 6 | Para llevar | Encabezado `Para llevar` (rótulo "Tipo de pedido"), sin bloque de entrega | US1 §6 |
| 7 | Con factura 1:1 de $ 14.000 | Total `$ 14.000`, idéntico al de Ventas — comparar abriendo el módulo de Ventas en otra pestaña | US1 §7, SC-002 |
| 8 | Cobrado en cuenta unificada con otro pedido | Desglose propio **y** el aviso literal `Este pedido se cobró junto con otros en una cuenta unificada; el total facturado está en Ventas` | US1 §8 |
| 9 | Abierto con promoción vigente | Subtotal y Total sin fila de descuento **y** el aviso literal `El descuento se calcula al cobrar; este total aún puede cambiar` | US1 §9 |
| 10 | Tres líneas, una anulada | Las tres visibles, la anulada marcada y sin importe; Subtotal = suma de las dos cobradas | US1 §10 |

**SC-001**: cronometrar el paso 7 desde que abre la pantalla hasta responder "por cuánto se
cobró y por qué": debe ser < 10 s **sin** abrir otra pantalla.

**SC-007 a mano**: en los pedidos 2, 10 y en los de adicional por línea y combo, sumar con
calculadora los importes visibles y comprobar que dan el Subtotal, y que
`Subtotal − Descuento + Envío` da el Total.

---

## 4. Historia 2 — Despachar un domicilio (P1)

1. Pedido a domicilio completo con envío $ 3.000: encabezado `Domicilio`, bloque **Datos de
   entrega** con los cuatro campos, fila `Domicilio $ 3.000` incluida en el Total (US2 §1).
2. Pulsar **Copiar datos** ⇒ toast `Datos de envío copiados al portapapeles`; pegar en un
   editor y comprobar las cuatro líneas con sus etiquetas, en el orden Cliente, Teléfono,
   Dirección, Notas (US2 §2, SC-003: una sola acción, cero transcripción).
3. Domicilio con envío $ 0 y sin referencias: no aparece la fila de envío ni el campo de
   notas; el resto se ve con normalidad (US2 §3).
4. Domicilio con solo dirección y teléfono: el texto pegado tiene **exactamente dos
   líneas** — sin líneas vacías, sin "null", sin guiones (US2 §4).
5. En el contexto sin portapapeles: pulsar **Copiar datos** ⇒ aviso de error legible, la
   pantalla sigue respondiendo y los datos se pueden seleccionar con el mouse (US2 §5).

---

## 5. Historia 3 — Huecos de datos (P2)

1. Pedido cuyas líneas no anuladas suman $ 0 ⇒ Total visible **y** el aviso
   `Esta orden no tiene el detalle de precios por ítem`, sin importes por línea en $ 0
   (US3 §1). *Para fabricarlo en el entorno de pruebas, poner a `0` el `unit_price` y el
   `addons_total` de las líneas de un pedido de prueba — nunca en datos reales.*
2. Pedido corriente sin promoción ⇒ el aviso **no** aparece (US3 §2).
3. Pedido con todas las líneas anuladas ⇒ líneas visibles marcadas, Subtotal y Total en
   `$ 0`, **sin** el aviso de falta de detalle, y la lista no aparece vacía (US3 §3).
4. Recorrer **20 pedidos del histórico** (los más viejos que haya, incluidos domicilios con
   datos parciales) y confirmar que en ninguno aparece "null", "undefined", un guion de
   relleno ni un `$ 0` inventado (US3 §4, **SC-004**).

---

## 6. Historia 4 — La etiqueta "Cliente" (P3)

Abrir un pedido de mesa, uno para llevar y uno a domicilio: en los tres, el nombre aparece
bajo la etiqueta `Cliente`. Buscar "Comensal" con `Ctrl+F` en las tres pantallas: cero
resultados (US4 §1, **SC-005**).

---

## 7. Aislamiento entre tenants (FR-025, SC-006)

1. Copiar el `id` de un pedido real del **tenant A**.
2. Autenticado como **tenant B**, abrir `/dashboard/orders/<id-del-tenant-A>` ⇒ la pantalla
   muestra "Orden no encontrada"; no aparece ningún dato del pedido.
3. Por API con el token del tenant B:
   ```bash
   curl -i -H "Authorization: Bearer $TOKEN_B" "$API/orders/$ID_DEL_TENANT_A"
   ```
   ⇒ `404` y `{"detail":"Order not found"}`. Ninguna cabecera ni cuerpo revela que el
   pedido existe en otro tenant.
4. Repetir con un `id` inexistente: la respuesta debe ser **idéntica** a la del paso 3.

---

## 8. Regresión (Principios II, III, X)

- Suites completas en verde (§0), con los fallos preexistentes de frontend sin aumentar.
- Ningún test `"CONGELA comportamiento actual:"` modificado.
- **Terminal de mesas**: abrir una mesa con pedidos, cobrar normalmente ⇒ totales y flujo
  idénticos. El `BillSummaryComponent` se usa en cuatro pantallas más
  (`pos-checkout-panel`, `payment-attempt-review-panel`, `manual-order-page`,
  `session-bill-panel`): revisar que la fila de descuento siga diciendo "Descuento" en las
  cuatro (el input nuevo tiene valor por defecto, D10).
- **Listado de Órdenes**: paginación, filtros y columnas sin cambios; `billing` llega `null`
  y nada se rompe.
- **Módulo de Ventas**: sin cambios.
- **Despliegue desacoplado**: con el frontend nuevo apuntando a un backend sin desplegar, el
  Detalle de Orden carga, muestra ítems, encabezado y datos de entrega, y **no** pinta el
  bloque de resumen ni importes por línea (D15). No aparece ningún `$ 0` ni "undefined".

---

## 9. Lista de cierre

| Criterio | Dónde se verifica |
|---|---|
| SC-001 — respuesta en < 10 s sin salir | §3, paso 7 |
| SC-002 — Total == total facturado | §2 y §3, paso 7 |
| SC-003 — datos de entrega en una acción | §4, paso 2 |
| SC-004 — cero "null"/"$ 0" en 20 pedidos | §5, paso 4 |
| SC-005 — "Comensal" no aparece | §6 |
| SC-006 — aislamiento 100 % | §7 |
| SC-007 — la aritmética cuadra a mano | §2 y §3 |
