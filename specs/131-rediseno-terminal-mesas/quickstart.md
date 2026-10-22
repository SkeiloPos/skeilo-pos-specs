# Quickstart: Validación del rediseño de la Terminal de Mesas

Guion para verificar, de punta a punta, que el rediseño visual cumple el spec sin romper
comportamiento. No sustituye a los characterization tests automatizados (`ng test`); es la
validación manual/visual complementaria que esos tests no cubren (fidelidad al mockup,
responsive real en navegador).

## Prerrequisitos

- `pos-backend` corriendo localmente con Postgres disponible (ver memoria del proyecto:
  "How to run sibling-repo tests" — venv del backend, Postgres local disponible).
- `pos-heladeria` corriendo en modo desarrollo (`ng serve` o equivalente del proyecto) contra
  ese backend.
- Al menos: una mesa libre, una mesa ocupada con un pedido en curso con 2+ líneas (una
  pendiente de preparar, una ya "lista"), una mesa con **más de un pedido abierto en
  paralelo** (para probar pestañas "Pedido N"), un pedido de Domicilio y uno Para llevar
  pendientes de cobro, y — si es alcanzable sin el spec 130 — un pedido de mesa recibido por
  Menú QR con pago pendiente en efectivo y otro en transferencia (el caso mixto `tdQ3On` no
  es verificable con datos reales hasta que el spec 130 esté implementado — ver
  Clarifications Q4 del spec).
- El mockup de referencia abierto en paralelo: `design/SkeiloPOS.html` (pantalla "Terminal de
  Mesas" — `isTerminal`/`tDetOn`/`tcOn`), para comparación lado a lado (SC-003).

## 1. Grilla principal (US1)

1. Abrir la Terminal de Mesas con la pestaña "Mesas" activa.
   - **Esperado**: cabecera de turno/conexión/caja, barra de búsqueda+pestañas+filtro de
     estado, grilla de tarjetas — con la distribución y "modelo de caja" del mockup
     (Acceptance Scenario 1, FR-001..004).
2. Pulsar `F2` y buscar una mesa por número/nombre.
   - **Esperado**: la grilla se filtra sin perder los demás filtros activos (Scenario 2).
3. Cambiar a "Domicilios" y "Para llevar".
   - **Esperado**: grilla equivalente con el mismo "modelo de caja"; mensaje de estado vacío
     si no hay pedidos de ese tipo (Scenario 3, FR-006).
4. Aplicar cada opción del filtro de estado (Todas/Libres/Ocupadas/Pendientes).
   - **Esperado**: grilla y conteos se actualizan igual que antes del rediseño (Scenario 4).
5. Con todas las mesas ocupadas, revisar el botón "Crear pedido nuevo".
   - **Esperado**: deshabilitado con el mismo mensaje explicativo de hoy (Scenario 5, FR-005).

## 2. Detalle de pedido (US2)

1. Seleccionar una mesa ocupada con un pedido en curso.
   - **Esperado**: cabecera con mesa/cliente/estado, líneas con cantidad/variante/opciones/
     nota/precio/promoción — layout de `tDetOn` (Scenario 1, FR-007, FR-008, FR-021).
2. En una mesa con más de un pedido abierto, cambiar entre pestañas "Pedido N".
   - **Esperado**: el bloque de pestañas es visualmente el bloque "Cuentas" del mockup
     (`accOn`) con los textos cambiados a "Pedido 1", "Pedido 2"...; cambiar de pestaña
     enfoca ese pedido sin perder el estado de los demás (Scenario 2, FR-022).
3. Dentro de esa misma mesa, confirmar que el botón "+ Crear pedido nuevo" de la sub-barra
   **ya no aparece**, y que el botón "Nueva cuenta" del bloque de pestañas sí crea un pedido
   nuevo en paralelo sobre la misma mesa (mismo efecto que el botón retirado) — FR-022b.
4. Pulsar "Agregar producto" sobre un pedido en armado.
   - **Esperado**: se abre el catálogo embebido (buscador, categorías, promociones); al
     confirmar, los productos se agregan al pedido (Scenario 3, FR-009).
5. Sobre una línea pendiente, probar "Marcar listo" y "Anular".
   - **Esperado**: actualiza el estado de la línea igual que antes (Scenario 4, FR-008).
6. Abrir el detalle de un pedido de Domicilio o Para llevar.
   - **Esperado**: fila compacta de dirección/teléfono/valor de domicilio debajo de la
     cabecera, sin fusionarse con el título (Scenario 5, FR-011, FR-024).
7. Sobre una línea ya facturada, confirmar que **no existe** la acción "Agregar adición" ni
   el badge "Modificada" — la forma de sumar algo a esa línea es agregar un producto/línea
   nueva vía "Agregar producto" (Scenario 6, FR-023).

## 3. Cobro (US3)

1. Cobrar un pedido de mostrador con un único método de pago.
   - **Esperado**: venta registrada con el mismo desglose (subtotal/domicilio/total)
     calculado por el backend (Scenario 1, FR-012).
2. Cobrar combinando hasta 3 métodos de pago.
   - **Esperado**: validación y cobro igual que antes (Scenario 2, FR-013).
3. Abrir el detalle de un pedido de mesa recibido por Menú QR con pago pendiente:
   - Caso efectivo → panel `tdQrOn`: confirmar monto recibido (FR-014a).
   - Caso transferencia/Nequi → panel `tdQ2On`: ver comprobante, aprobar/rechazar (FR-014b).
   - Caso mixto → panel `tdQ3On`: construido visualmente; **no verificable con datos reales**
     hasta que el spec 130 esté implementado — documentar el resultado como "bloqueado por
     spec 130", no como fallo de este spec (FR-014c, Scenario 3).
4. Sobre una mesa ya pagada con saldo pendiente por adiciones posteriores, cobrar ese saldo.
   - **Esperado**: se registra como cobro adicional, igual que antes (Scenario 4, FR-015).
5. Sobre un pedido completamente pagado sin pagos QR pendientes, usar "Imprimir Factura" y
   "Liberar Mesa".
   - **Esperado**: funciona igual que hoy (Scenario 5, FR-016, FR-017).

## 4. Responsive (US4)

Probar en al menos tres anchos: móvil (~375px), tablet (~768px), escritorio ancho
(~1440px+).

1. En móvil, seleccionar una mesa.
   - **Esperado**: solo la columna de detalle a pantalla completa, con botón de volver
     siempre accesible (Scenario 1, FR-010, FR-018).
2. En escritorio, abrir el detalle.
   - **Esperado**: pedido y cobro distribuidos según la proporción del mockup, ninguno
     ilegible por falta de espacio (Scenario 2).
3. En cualquier ancho, forzar que el contenido de una columna exceda el alto disponible.
   - **Esperado**: solo esa columna scrollea; cero scroll horizontal de página; cero scroll
     anidado dentro de la misma columna (Scenario 3, FR-019).

## 5. Verificación automatizada

- Ejecutar la suite de `pos-heladeria` (`ng test`, ver memoria del proyecto sobre cómo correr
  tests del repo hermano) y confirmar:
  - Todos los tests `CONGELA comportamiento actual:` existentes en
    `pos-terminal.store.spec.ts`, `pos-order-panel.component.spec.ts`,
    `payment-attempt-review-panel.component.spec.ts` y
    `checkout-order-summary.component.spec.ts` siguen en verde, **excepto** los que
    verificaban específicamente "Agregar adición"/badge "Modificada" o el botón "+ Crear
    pedido nuevo" dentro del detalle de mesa — esos se actualizan explícitamente citando
    FR-023/FR-022b y la entrada correspondiente en `registro-de-anomalias.md`.
  - Cualquier test nuevo que dependa de selectores/estructura visual del diseño anterior
    queda reescrito contra la nueva estructura, no eliminado.

## Criterio de cierre (ligado a Success Criteria del spec)

- SC-001: 100% de acciones accesibles salvo FR-022b/FR-023, verificado por los pasos 1-4 de
  arriba más la suite automatizada.
- SC-002: el ciclo completo "seleccionar mesa → agregar producto → cobrar → liberar mesa" se
  completa sin recorte ni scroll horizontal en los tres anchos del paso 4.
- SC-003: revisión visual lado a lado contra `design/SkeiloPOS.html` sin discrepancias de
  bordes/radios/tipografía/espaciado.
- SC-004: cero endpoints nuevos — confirmado por no haber ningún archivo de `contracts/` en
  este plan y por no tocar ningún servicio de `pos-backend`.
