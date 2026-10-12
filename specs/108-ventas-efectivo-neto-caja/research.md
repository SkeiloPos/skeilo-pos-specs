# Research: Ventas en Efectivo por Valor Neto en el Resumen de Caja

No hay `NEEDS CLARIFICATION` en la spec ni en el Technical Context del plan — las tres decisiones
de diseño que quedaban abiertas al leer el código se resuelven aquí.

## D1 — Dónde se corrige: en `sales_by_method`, reutilizando `ventas_efectivo` ya existente

**Decisión**: la fila de tipo `cash` dentro de `sales_by_method` (que construye `reconcile()` en
`pos-backend/app/api/v1/cash/service.py`) pasa a reportar el mismo valor que ya tiene
`ventas_efectivo` (bruto − cambio), en vez del total bruto por método (`by_type["cash"]`). No se
introduce ningún cálculo nuevo.

**Rationale**: `ventas_efectivo` ya hace exactamente la resta correcta
(`by_type["cash"] - Decimal(change_total)`, línea 166 de `service.py`) y ya es lo único que suma a
`expected`. El problema reportado no es un error de cálculo — es que `sales_by_method` (que
alimenta la tarjeta visible) y `ventas_efectivo` (que alimenta el total) divergían: uno bruto, el
otro neto. Igualar la fila `cash` de `sales_by_method` a `ventas_efectivo` elimina la divergencia
en el único punto donde nace, sin tocar `expected`, `difference`, ni ningún otro tipo de método
(`card`/`transfer` no tienen concepto de cambio, así que su bruto y su neto ya coinciden).

**Alternatives considered**:
- *Corregir en el frontend* (`CashSessionStore.mapVentasPorMetodo`, restando `cambio_entregado` al
  mapear la fila `cash`): rechazada porque duplicaría en TypeScript una resta que el backend ya
  hace correctamente, y porque cualquier otro consumidor futuro del endpoint de arqueo (p. ej. un
  reporte nuevo) heredaría el mismo dato bruto engañoso que hoy tiene el frontend.
- *Eliminar `sales_by_method` y mostrar solo `ventas_efectivo`/`ventas_tarjeta`/*
  *`ventas_transferencia`*: rechazada por exceder el alcance del hotfix (Principio V) — el array
  por método existe para que cualquier método de pago activo aparezca aunque no haya vendido nada
  en el turno (comentario en `service.py` línea ~138), comportamiento que esta spec no toca.

## D2 — Qué pasa con la fila "Cambio entregado" en el reporte de cierre impreso

**Decisión**: en `cash-report.component.ts`, la fila "Cambio entregado" sale de la tabla
secuencial "Resumen financiero" (hoy está entre las filas de Ventas y la fila Ingresos, con
prefijo "−", justo antes de la fila final "Efectivo esperado") y se muestra como dato informativo
separado — mismo tratamiento que ya tiene en `cash-dashboard.component.ts`, donde es una tarjeta
aparte y no una fila de la fórmula.

**Rationale**: aunque el *banner* con el texto de la fórmula solo existe en
`cash-dashboard.component.ts`, la tabla del reporte impreso tiene el mismo problema de fondo que
motivó esta spec: una fila con "−" ubicada visualmente entre las ventas y el total da la impresión
de ser un término operativo de la suma que termina en "Efectivo esperado", exactamente la
confusión que la Historia de Usuario 3 (`Cambio Entregado como dato informativo secundario`) pide
evitar. Una vez que "Ventas efectivo" ya es neto (D1), dejar esa fila con "−" en la misma tabla
volvería a sugerir una doble resta.

**Alternatives considered**:
- *Dejar la fila igual, solo sin el "−"*: rechazada — seguiría posicionada entre Ventas e Ingresos,
  dando la impresión de pertenecer a la secuencia de la suma aunque ya no reste nada.
- *Quitarla del reporte impreso por completo*: rechazada — la Historia de Usuario 3 exige que siga
  disponible como dato informativo, no que desaparezca.

## D3 — El resultado numérico de `expected`/`difference` no cambia

**Decisión**: no se modifica la fórmula de `expected` en `service.py` (línea ~184:
`opening_amount + ventas_efectivo + ingresos - egresos - retiros`). Ya no restaba `change_total`
como término aparte — esa resta ya estaba dentro de `ventas_efectivo` desde antes de este hotfix.

**Rationale**: confirma FR-003 (equivalencia numérica exacta con el comportamiento anterior) y
acota el hotfix a presentación: la "doble resta" que describía el reporte del usuario ocurría solo
en el *texto* del banner y en la *tarjeta* de desglose, nunca en el cálculo real de `expected`. Esto
también descarta cualquier necesidad de `data-model.md` con cambios de esquema o migración.

**Alternatives considered**: ninguna — no hay ambigüedad aquí, es una verificación de lectura de
código, no una decisión de diseño.
