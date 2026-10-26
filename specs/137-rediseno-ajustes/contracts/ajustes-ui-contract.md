# Contrato: UI de Ajustes (pos-heladeria)

**Spec**: `specs/137-rediseno-ajustes/spec.md` | **Fecha**: 2026-10-26

No es un contrato de API — documenta qué comportamiento de interfaz debe conservarse
exactamente al aplicar el rediseño visual, para que la implementación y sus tests de
aceptación tengan un checklist verificable por pestaña.

## Información básica (FR-001)

Campos y acciones que el rediseño **debe** conservar sin cambio funcional: logo, mensaje
de recibo, ancho de rollo de impresión, conversión de unidades en compras (toggle/config
de spec 134). Mismo servicio (`tenant-info.component.ts` y su service asociado), mismos
endpoints.

## Métodos de pago (FR-002)

Conserva: catálogo del Super Admin, activación de método, campos dinámicos por método,
activar/desactivar. Mismo componente/servicio subyacente, solo cambia plantilla/estilos.

## Grupos de opciones (FR-003)

Conserva: modo conteo/cantidad (spec 065), tipo de precio incluido/con recargo (spec
064), vínculo a insumo, eliminación definitiva con confirmación. Sin cambios de
servicio/endpoint.

## Visibilidad por plan (FR-004)

La pestaña "Unidades de medida" sigue oculta cuando el plan del tenant no incluye el
módulo Inventario, igual que hoy — el rediseño no introduce una forma nueva de verificar
el plan; reutiliza el guard/condición ya existente en `settings-page.component.ts`.

## Unidades de medida — nueva estructura visual (grupos)

- Lista agrupada: cada grupo se muestra con su nombre y, debajo, sus unidades (base
  primero, marcada visualmente como "base").
- La unidad base se muestra sin acciones de editar factor/desactivar/eliminar
  disponibles (deshabilitadas o con tooltip explicando el bloqueo de FR-008), consistente
  con la respuesta 409 del backend si se intentaran igualmente.
- Acción "reasignar base" visible solo cuando el grupo tiene más de una unidad; si el
  backend responde 409 por unidades en uso, el frontend muestra la lista de
  `blocking_units` del error (FR-009, SC-004).
- Acción "eliminar grupo" solo visible/habilitada cuando ninguna unidad del grupo está en
  uso; igual que arriba, si el backend igual responde 409, se muestran las unidades
  bloqueantes (FR-011).
- El formulario de crear/editar unidad conserva el campo "Abreviatura" visible (decisión
  explícita del spec, aunque el diseño de referencia no lo muestre) además de "Nombre de
  la unidad".
- Eliminar una unidad individual (no base) sigue mapeando al ícono de "eliminar" del
  diseño, pero ejecuta la acción de desactivar ya existente (soft-delete, FR-013) — no
  hay borrado físico.
