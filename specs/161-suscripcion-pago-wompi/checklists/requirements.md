# Specification Quality Checklist: Autogestión de suscripciones y pago de la membresía por link de pago (Wompi)

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-11-17
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic (no implementation details)
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## Notes

- **Contratos de interfaz**: la tabla "Contratos de interfaz acordados" y el código `subscription_blocked` conservan nombres de rutas y de campos que el usuario fijó literalmente en el requerimiento. No se nombran lenguajes, frameworks, bibliotecas ni estructuras internas; el diseño se resuelve en `/speckit-plan`. Por eso los dos ítems de "sin detalles de implementación" se marcan como cumplidos.
- **Sin marcadores de clarificación**: las 8 decisiones abiertas (alcance del bloqueo, audiencia ADMIN, mecanismo Wompi, planes no cobrables, pagos por adelantado, fronteras de tiempo, estados de Wompi y tenants vencidos al desplegar) quedaron resueltas por el usuario el 2026-11-17 y constan en `## Clarifications`.
- **Supuestos derivados que conviene confirmar en revisión** (no estaban en las decisiones del usuario):
  1. `vencido` pasa a significar "bloqueada": el frontend lo usa para ocultar módulos (`plan-module.guard.ts`, `tenant-sidebar.component.ts`), así que mantenerlo verdadero desde el vencimiento anularía la gracia en la interfaz.
  2. La conexión en tiempo real del personal queda exenta del bloqueo, para que el ADMIN reciba en vivo el aviso de bloqueo.
  3. Convención de `dias_restantes` (FR-002).
  4. Un aviso con monto distinto o referencia desconocida no se aplica y queda para revisión de soporte (FR-026).
- **Pendientes explícitos**: no existe cuenta de Wompi; la prueba real contra su entorno de pruebas queda como tarea pendiente (FR-041). Antes de implementar hay que registrar los 4 cambios de comportamiento en `specs/000-reconocimiento/registro-de-anomalias.md` (último registro vigente: A-160) y revisar la migración sin commitear de `pos-backend` para no crear dos cabezas de Alembic.
- Todos los ítems pasan; la spec está lista para `/speckit-clarify` (opcional) o `/speckit-plan`.
