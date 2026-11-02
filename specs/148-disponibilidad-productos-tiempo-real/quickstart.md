# Quickstart: validar «Disponibilidad de productos en tiempo real»

**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | Contratos: [contracts/](./contracts/)

Guía de **validación**, no de implementación. Cada escenario cita las historias y requisitos que
prueba y dice qué se espera ver.

## Prerrequisitos

- `pos-backend` corriendo **con `uvicorn` nativo** (no en Docker: el `.env` apunta a `localhost`
  y el contenedor no alcanza Postgres), con Redis arriba y `REALTIME_ENABLED=true`.
- `pos-heladeria` con `ng serve`.
- **Dos negocios** con tablas migradas (hoy la BD de desarrollo solo trae `tenantlocal` con
  tablas; el segundo se crea con el alta de tenant / Super Admin). Llamados aquí **A** y **B**.
- En el negocio **A**: un producto «Granizado de mora» con dos presentaciones (12 oz y 16 oz), una
  receta que consuma un insumo por presentación (insumo propio de cada una), un grupo de sabores
  con la opción «mora» ligada a otro insumo, y otro producto «Paleta de coco». Un cajero, una
  mesera, una mesa con QR firmado y un turno de caja abierto.
- En el negocio **B**: un producto también llamado «Granizado de mora».
- Cuatro ventanas: (1) Terminal de la mesera de A, (2) menú QR del comensal de A, (3) Carta del
  menú de un segundo cajero de A, (4) Terminal o menú de B.
- Herramientas: DevTools (pestaña Network → throttling «Offline»), `redis-cli`.

## Verificación automatizada (previa a lo manual)

```bash
# Backend (SQLite en memoria; no correr en paralelo con la suite del frontend)
cd pos-backend
./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'
./env/bin/python -m unittest app.characterization_tests.test_availability_engine \
  app.characterization_tests.test_availability_hooks \
  app.characterization_tests.test_availability_events \
  app.characterization_tests.test_availability_snapshot \
  app.characterization_tests.test_sold_out_conflict -v

# Frontend (comparar por nombre de prueba contra develop: hay fallos preexistentes en 7 archivos)
cd pos-heladeria
ng test --watch=false --include='src/app/core/availability/**/*.spec.ts'
ng test --watch=false --include='src/app/core/realtime/**/*.spec.ts'
ng test --watch=false --include='src/app/modules/tables/**/*.spec.ts'
ng test --watch=false --include='src/app/modules/products/**/*.spec.ts'
```

Esperado: suites existentes en verde salvo los tests de 400 → 409 actualizados citando la
anomalía; los tests nuevos en verde.

## Escenario 1 — Agotado manual se ve sin recargar (US1.1, US1.3, US1.4 · FR-001/002/003 · SC-001)

1. Con las ventanas 1, 2 y 3 abiertas en el negocio A y el catálogo de la Terminal visible, el
   cajero de la ventana 3 marca «Granizado de mora» como **Agotado** en la Carta del menú.
2. Cronometrar hasta que las ventanas 1 y 2 muestren «Agotado» y deshabiliten la tarjeta.
3. **Esperado**: ambas en **< 3 s**, sin recarga. En la ventana 3 (otra pestaña de Carta) el
   interruptor y la etiqueta se actualizan sin recargar. Con el drawer «agregar a orden existente»
   abierto, la tarjeta también queda agotada sin cerrarlo.
4. Repetir 5 veces; anotar el tiempo máximo.

## Escenario 2 — Volver a disponible (US1.2)

1. Marcar «Granizado de mora» como disponible.
2. **Esperado**: las ventanas 1, 2 y 3 lo habilitan en < 3 s, sin recarga.

## Escenario 3 — Ráfaga sobre el mismo producto (US1.5 · FR-006)

1. Marcar/desmarcar 6 veces seguidas, rápido, terminando en **Agotado**.
2. **Esperado**: todas las ventanas terminan en «Agotado». Repetir terminando en disponible.
3. Observar en `redis-cli XRANGE events:tenant:<idA> - +` que los eventos tienen `v` crecientes.

## Escenario 4 — Carrito de la Terminal se conserva (US2.1–US2.6 · FR-013 a FR-018 · SC-002)

1. En la ventana 1 armar un borrador: 2 × «Granizado de mora» 16 oz, 1 × «Paleta de coco».
2. Desde la ventana 3 marcar el granizado agotado.
3. **Esperado**: solo esa línea queda resaltada «Agotado» con opción de quitarla; la paleta no
   cambia; **«Crear pedido» deshabilitado**.
4. Volver a marcar disponible → **Esperado**: la marca desaparece sola y el botón se habilita.
5. Marcar agotados **ambos** productos → ambas líneas marcadas, envío bloqueado hasta resolver las dos.
6. Quitar una línea → el resto conserva cantidades, opciones y notas; envío habilitado al resolver.
7. Repetir en las modalidades **mesa**, **para llevar**, **domicilio** y la **página de orden manual**.
8. Línea con adición, sabor o presentación: agotar solo el sabor «mora» → la línea que lo contiene
   se marca indicando «mora»; otra línea del mismo producto con otro sabor **no** se marca (FR-017).

## Escenario 5 — Carrito del menú QR (US2.4)

1. En la ventana 2 agregar «Granizado de mora» y «Paleta de coco» al carrito.
2. Agotar el granizado desde la ventana 3.
3. **Esperado**: línea resaltada «Agotado» con opción de quitarla; «Confirmar pedido» bloqueado; la
   paleta intacta. Volver a disponible → la marca desaparece sola.

## Escenario 6 — Pasos de pago del QR (US2.7, US2.8 · FR-019)

1. En la ventana 2 llegar al paso **transferencia** (o **efectivo** de pago mixto) con método
   elegido y, si aplica, monto en efectivo.
2. Agotar un producto del carrito desde la ventana 3.
3. **Esperado**: **permanece en ese paso**; método y monto intactos; la línea aparece «Agotado» en el
   resumen del pedido; alerta visible; «Confirmar pedido» bloqueado; botón «Volver al carrito».
4. Pulsar «Volver al carrito», quitar la línea, volver al pago.
5. **Esperado**: aviso «El total cambió a $X»; método conservado. En **pago mixto**, si el efectivo
   ya no es menor al nuevo total se pide corregirlo (y eso invalida el comprobante, spec 130).

## Escenario 7 — Condición de carrera: 409 (US3.1–US3.5 · FR-021 a FR-024 · SC-003/SC-007)

1. En la ventana 1 armar un pedido con el granizado y dejarla **desactualizada a propósito**: en
   DevTools → Network → «Block request URL» sobre `/realtime/stream` (así el resto de llamadas
   funciona pero no llega ningún aviso). Agotar el granizado desde la ventana 3 y pulsar «Crear
   pedido» en la ventana 1 (o repetir por `curl` directo a `POST /orders`).
2. **Esperado**: respuesta `409` con `agotados[]` (id y nombre), **ninguna** orden nueva
   (`SELECT count(*) FROM customer_orders` igual que antes), carrito de la ventana 1 conservado con
   solo la línea afectada marcada y la alerta «Se agotó: Granizado de mora. Quítalo para continuar».
3. Repetir con dos productos agotados → `Se agotaron: …, …. Quítalos para continuar`.
4. Repetir con un producto agotado **por falta de insumo** → mismo 409 y misma forma.
5. Con el aviso en vivo inoperante (parar Redis) repetir: el servidor sigue rechazando el 100 %.

## Escenario 8 — Cantidad mayor a lo que alcanza (US3.6)

1. Dejar el insumo del granizado con existencias para 3 y pedir 5.
2. **Esperado**: 409 que lista el producto con `motivo: "cantidad"`; sin orden; la línea marcada
   «Agotado»/«No alcanza para esa cantidad»; el producto **no** se muestra agotado en el catálogo
   (sigue pedible en cantidad 1); la persona puede volver a agregar una cantidad que alcance.

## Escenario 9 — Aislamiento entre negocios (US4 · FR-030 a FR-032 · SC-004)

1. En B, abrir un menú QR y una Terminal; en A, agotar «Granizado de mora».
2. **Esperado**: ni la ventana 4 ni ningún canal de B cambian; el «Granizado de mora» de B sigue
   disponible. En `redis-cli`, `events:tenant:<idB>` **no** recibe ninguna entrada.
3. Con DevTools → Network → `/realtime/stream` del comensal de A: solo aparecen `availability.changed`
   y los eventos de su mesa; **nunca** `table.status_changed`, `payment.completed` ajenos ni
   notificaciones del personal.

## Escenario 10 — Pérdida y recuperación de la conexión (US5 · FR-025 a FR-029 · SC-005)

1. En la ventana 1 poner la red en «Offline».
2. **Esperado**: tras **5 s continuos** aparece «Sin actualización en vivo» (discreto, sin bloquear
   el catálogo ni el carrito). Un corte de **< 5 s** que se recupera **no** lo muestra.
3. Con la ventana 1 offline, desde la ventana 3 cambiar varios productos (agotar uno que está en el
   carrito de la ventana 1, volver otro a disponible).
4. Quitar «Offline».
5. **Esperado**: la vista se pone al día sola, la línea del producto agotado queda marcada, el
   envío bloqueado y el indicador desaparece, sin intervención.
6. Con la ventana 1 aún sin enterarse, enviar un pedido con un producto agotado → 409 (US5.4).
7. Pestaña en segundo plano ~30 s con cambios mientras tanto → al volver, se pone al día (FR-028).
8. `resync`: dejar la vista desconectada más que `REALTIME_STREAM_MAXLEN` (o reducirlo en local) y
   reconectar → misma consulta de reconciliación.

## Escenario 11 — Agotado por inventario (US6 · FR-008 a FR-012 · SC-006)

1. Dejar el insumo de «Granizado de mora» 16 oz con existencias para **una** preparación.
2. Vender/confirmar un pedido que lo consuma (o ajustar el insumo a 0 desde Inventario).
3. **Esperado**: las ventanas 1 y 2 muestran la presentación «16 oz» como «Agotado» y no
   seleccionable; «12 oz» sigue seleccionable; el producto **no** aparece agotado (US6.7).
4. Reponer el insumo (compra o ajuste) → vuelve a habilitarse en < 3 s.
5. Agotar el insumo de la **opción** «mora» → la opción aparece agotada, el producto sigue pedible.
6. Agotar el insumo de **todas** las presentaciones → el producto aparece agotado.
7. Insumo **compartido** por varios productos/presentaciones/opciones → todos aparecen agotados con
   **un** solo evento (`XRANGE` muestra una entrada con varios `changes`).
8. Producto marcado agotado **a mano** con insumo suficiente → sigue agotado tras mover inventario
   (FR-011).
9. Producto con insumo en 0 y marca manual «disponible» → en la **Carta** el interruptor sigue en
   «disponible» y no se modifica (US6.5).
10. Movimiento que **no** cambia el estado (stock 10 → 9): `XRANGE` no gana ninguna entrada
    `availability.changed` (US6.6).

## Escenario 12 — Regresión de la spec 128

1. Con el menú QR abierto, ocultar una categoría en QR desde Categorías.
2. **Esperado**: el menú del comensal se actualiza solo (requiere el registro de `menu.updated` en
   el cliente, research.md D13; sin él este escenario **falla hoy en producción** y es el motivo de
   ese commit aparte).

## Presupuestos técnicos a medir

| Qué | Cómo | Meta |
|---|---|---|
| Latencia de propagación | cronómetro/`performance.now()` entre el `PATCH` y el repintado; 20 muestras | p99 < 3 s (SC-001) |
| Gancho de sesión | log de duración en `after_commit` con 300 productos | ≤ 50 ms p95 |
| Snapshot | `curl -w '%{time_total}'` sobre `/menu/availability` | ≤ 100 ms p95 |
| Volumen de eventos | `XLEN` antes/después de una hora de operación simulada | proporcional a transacciones, no a elementos |

## Limpieza

Restablecer las marcas manuales y las existencias de los insumos de prueba; no se crean datos
propios de esta funcionalidad (no hay esquema nuevo).
