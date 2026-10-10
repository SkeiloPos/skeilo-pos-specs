# Feature Specification: Ventas en Efectivo por Valor Neto en el Resumen de Caja

**Feature Branch**: `hotfix/108-ventas-efectivo-neto-caja`

**Created**: 2026-10-10

**Status**: Draft

**Input**: User description: "Como cajero o administrador del punto de venta, quiero que la tarjeta de Ventas Efectivo en el resumen de caja muestre el total neto real de las ventas cobradas y no el dinero bruto recibido del cliente, para evitar confusiones al interpretar los reportes de ventas y garantizar que la fórmula de arqueo de caja sea matemáticamente transparente e intuitiva. Actualmente la tarjeta Ventas Efectivo suma el efectivo recibido en mano ($48.000) en vez del total neto facturado ($45.000), y el banner compensaba restando explícitamente el Cambio Entregado ($3.000). El resultado final de Efectivo Esperado ($145.000) coincidía, pero la terminología confundía al clasificar el cambio devuelto como si fuera venta bruta. Resolver como hotfix, creando una rama a partir de main."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Ver el valor neto real en la tarjeta Ventas Efectivo (Priority: P1)

Como cajero o administrador, al consultar el resumen de caja durante o al cierre de un turno, quiero que la tarjeta "Ventas Efectivo" muestre la suma de los valores netos de las facturas cobradas en efectivo, para que el número coincida con lo realmente facturado y no incluya el dinero devuelto como cambio.

**Why this priority**: Es la causa raíz de la confusión reportada: el dato visible hoy no corresponde a una venta real, sino a efectivo bruto recibido en mano. Sin corregir este dato, cualquier otro ajuste en el banner seguiría siendo engañoso.

**Independent Test**: Cerrar un turno con dos facturas pagadas en efectivo (ej. Factura A = $17.000 recibiendo $20.000 con $3.000 de cambio, Factura B = $28.000 exacto) y verificar que la tarjeta "Ventas Efectivo" muestra $45.000 (17.000 + 28.000), no $48.000.

**Acceptance Scenarios**:

1. **Given** se han procesado transacciones en efectivo durante el turno, **When** el usuario consulta la tarjeta "Ventas Efectivo" en el resumen de caja, **Then** la tarjeta muestra la suma de los valores netos de las facturas cobradas en efectivo (ej. Factura 25 = $17.000 + Factura 23 = $28.000 → $45.000).
2. **Given** un turno sin ninguna venta en efectivo, **When** el usuario consulta el resumen de caja, **Then** la tarjeta "Ventas Efectivo" muestra $0, sin errores ni valores negativos.

---

### User Story 2 - Fórmula de Efectivo Esperado sin "doble resta" del cambio (Priority: P1)

Como cajero o administrador, quiero que el Efectivo Esperado en caja se calcule como Fondo inicial + Ventas en efectivo (neto) + Ingresos − Egresos − Retiros, sin que el banner reste el Cambio Entregado como un término operativo adicional, para que la fórmula sea transparente y no dé la impresión de que el cambio se resta dos veces.

**Why this priority**: Es el requisito matemático central del hotfix: una vez que "Ventas Efectivo" es neto (User Story 1), la fórmula visible debe dejar de restar el cambio explícitamente para no inducir a pensar en una doble resta, aunque el resultado final no cambie.

**Independent Test**: Con el mismo turno de ejemplo (Fondo inicial $100.000, Ventas efectivo neto $45.000, Ingresos $0, Egresos $0, Retiros $0), verificar que el Efectivo Esperado mostrado es $145.000 y que el texto explicativo del banner ya no incluye el término "cambio entregado".

**Acceptance Scenarios**:

1. **Given** las ventas en efectivo se contabilizan por su valor neto, **When** el sistema calcula el Efectivo Esperado en Caja, **Then** aplica estrictamente: Efectivo Esperado = Fondo Inicial + Ventas Efectivo (Neto) + Ingresos − Egresos − Retiros, sin restar el Cambio Entregado como término aparte.
2. **Given** un turno con movimientos de ingresos, egresos y retiros además de ventas en efectivo, **When** se consulta el Efectivo Esperado, **Then** el valor resultante es idéntico al que el sistema calculaba antes del hotfix (el cambio para de ser un término visible, pero el resultado numérico final no varía).
3. **Given** el resumen de caja (vista en pantalla y reporte de cierre impreso), **When** se muestra el texto explicativo del cálculo, **Then** el texto dice "Fondo inicial + ventas en efectivo + ingresos − egresos − retiros".

---

### User Story 3 - Cambio Entregado como dato informativo secundario (Priority: P2)

Como cajero, quiero seguir viendo cuánto cambio he entregado durante el turno, pero como un dato informativo independiente y no como parte de la fórmula operativa del Efectivo Esperado, para conservar esa información útil sin que confunda la interpretación del arqueo.

**Why this priority**: Preserva valor existente para el cajero (saber cuánto cambio ha dado) sin repetir el error de tratarlo como un componente de la fórmula principal. Es de menor prioridad porque no corrige un dato incorrecto, solo reposiciona uno que ya es correcto.

**Independent Test**: Cerrar un turno con cambio entregado mayor a $0 y verificar que la tarjeta "Cambio entregado" sigue visible con su valor correcto, tanto en el resumen en pantalla como en el reporte de cierre impreso, y que ese valor no aparece como resta dentro del texto de la fórmula del banner.

**Acceptance Scenarios**:

1. **Given** el cambio entregado sigue siendo una métrica informativa relevante para el cajero, **When** se visualiza el resumen de caja, **Then** el Cambio Entregado se mantiene disponible únicamente como dato informativo / métrica secundaria en su propia tarjeta.
2. **Given** un turno sin cambio entregado (todas las ventas en efectivo fueron pagadas con monto exacto), **When** se visualiza el resumen de caja, **Then** la tarjeta de Cambio Entregado no induce a pensar que afecta la fórmula del Efectivo Esperado.

---

### Edge Cases

- ¿Qué pasa cuando no hubo ninguna venta en efectivo en el turno? La tarjeta "Ventas Efectivo" debe mostrar $0 y no debe aparecer la tarjeta de "Cambio entregado" (mismo comportamiento ya existente para cambio en cero).
- ¿Qué pasa con turnos ya cerrados antes del hotfix, al consultarlos en el historial o reimprimir su reporte? Deben mostrarse con la nueva interpretación (valor neto en la tarjeta y fórmula sin el término de cambio), ya que el dato se recalcula a partir de las facturas registradas y no depende de un valor almacenado con la interpretación anterior.
- ¿Qué pasa si una venta en efectivo se paga con el monto exacto (sin cambio)? El valor neto y el bruto coinciden, por lo que la tarjeta "Ventas Efectivo" no cambia respecto al comportamiento actual en ese caso.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema MUST mostrar en la tarjeta "Ventas Efectivo" del resumen de caja la suma de los valores netos de las facturas cobradas en efectivo durante el turno (excluyendo el cambio entregado), no el efectivo bruto recibido en mano.
- **FR-002**: El sistema MUST calcular el Efectivo Esperado en caja como: Fondo Inicial + Ventas Efectivo (Neto) + Ingresos − Egresos − Retiros, sin incluir el Cambio Entregado como un término separado en el cálculo.
- **FR-003**: El resultado numérico del Efectivo Esperado MUST permanecer matemáticamente equivalente al comportamiento anterior al hotfix para cualquier turno (el cambio ya queda reflejado implícitamente al neteiar las ventas en efectivo).
- **FR-004**: El sistema MUST seguir mostrando el Cambio Entregado como una tarjeta o indicador informativo independiente dentro del resumen de caja, visible cuando su valor sea mayor a cero.
- **FR-005**: El texto explicativo del banner de cálculo en el resumen de caja (vista en pantalla y reporte de cierre impreso) MUST actualizarse a: "Fondo inicial + ventas en efectivo + ingresos − egresos − retiros", eliminando la referencia a "cambio entregado" como término de la fórmula.
- **FR-006**: El cambio en la presentación MUST aplicar de manera consistente tanto al resumen de caja del turno en curso como al historial de turnos cerrados y al reporte de cierre impreso.

### Key Entities

- **Turno de caja (Cash Shift)**: Representa el periodo de apertura/cierre de caja de un cajero; agrupa las ventas, movimientos y el arqueo de un turno.
- **Venta en efectivo**: Transacción cobrada en efectivo durante un turno; tiene un valor neto facturado y, opcionalmente, un cambio entregado al cliente cuando el pago en mano excede el valor neto.
- **Movimiento de caja (Ingreso / Egreso / Retiro)**: Entrada manual de dinero que entra o sale del cajón durante el turno, distinta de las ventas.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El valor mostrado en la tarjeta "Ventas Efectivo" coincide, en el 100% de los turnos verificados, con la suma de los valores netos de las facturas cobradas en efectivo (sin incluir cambio entregado).
- **SC-002**: El valor de "Efectivo Esperado" calculado después del hotfix es idéntico, centavo a centavo, al valor calculado antes del hotfix para los mismos turnos (no se introduce ninguna diferencia de arqueo nueva).
- **SC-003**: El texto del banner explicativo ya no contiene la frase "cambio entregado" como término de la fórmula, en el 100% de las pantallas y reportes donde se muestra.
- **SC-004**: Un cajero puede explicar correctamente, sin ayuda externa, de dónde sale el Efectivo Esperado leyendo únicamente el texto del banner, eliminando la necesidad de aclarar por qué se "resta" el cambio dos veces.

## Assumptions

- Los valores netos de las facturas (venta menos cambio entregado) ya están disponibles en los datos existentes de ventas y movimientos del turno; no se requiere capturar información nueva del cajero.
- El Efectivo Esperado y los indicadores del resumen de caja se calculan en el momento de la consulta a partir de las ventas y movimientos registrados, por lo que turnos ya cerrados antes del hotfix se verán automáticamente con la nueva interpretación al consultarlos de nuevo, sin requerir una migración de datos históricos.
- El alcance de este hotfix es exclusivamente de presentación/cálculo del resumen de caja (tarjeta de Ventas Efectivo, fórmula del Efectivo Esperado y su texto explicativo); no cambia cómo se registran las ventas, el cambio entregado, ni las reglas de apertura/cierre de turno.
- La tarjeta de Cambio Entregado conserva su comportamiento actual de visibilidad condicional (solo se muestra cuando el cambio entregado es mayor a cero).
