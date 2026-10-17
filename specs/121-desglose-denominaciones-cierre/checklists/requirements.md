# Specification Quality Checklist: Desglose por denominación en el arqueo de cierre de caja

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-10-15
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

- **Detalles técnicos admitidos a propósito.** La sección «Contexto y comportamiento actual»
  nombra archivos y endpoints del código actual, igual que la spec 114: es la evidencia que exige
  el Principio II para justificar qué comportamiento existente cambia. Fuera de esa sección, las
  únicas referencias técnicas son los códigos `422`/`409` y el campo `counted_amount`, que
  vienen de las reglas de negocio del propio solicitante (`RN-02`, `RN-03`, `RN-06`).
- **Las seis ambigüedades se resolvieron antes de redactar** (sesión del 2026-10-15, registrada
  en la sección *Clarifications*), por lo que no quedó ningún marcador `[NEEDS CLARIFICATION]`.
- **Adaptación respecto al texto original del solicitante.** El escenario BDD 2 (faltante de
  $5.000) ahora incluye la observación obligatoria, porque `RN-CASH-10` la exige cuando la
  diferencia no es cero y esta spec la conserva (FR-008). Se añadió el escenario 3 de la User
  Story 1 para cubrir el caso sin observación.
- **Pendiente antes de implementar (no bloquea `/speckit-plan`)**: registrar D-1 a D-4 en
  `specs/000-reconocimiento/registro-de-anomalias.md` y ejecutar la verificación previa de
  FR-028 contra la base de datos de desarrollo.

## Nota de cierre de la implementación (2026-10-15)

- **Estado**: implementada en `pos-backend` y `pos-heladeria` (rama `feat/121-denomination-breakdown` en ambos),
  **sin commit ni push** (los commits se hacen a pedido, Principio XV). Decisiones **A-130 a A-134** registradas
  en `specs/000-reconocimiento/registro-de-anomalias.md`; A-17 (solo `close_shift`) y A-20 / `RN-CASH-09` anotadas.
- **Seguimiento**: [tasks.md](../tasks.md) — **73/75 tareas** hechas; el detalle y la evidencia están en su sección
  «Registro de verificaciones». Backend **1661** pruebas OK (1588 + 73), frontend con el mismo conjunto de 7
  archivos preexistentes con fallos, migración verificada en PostgreSQL real (subir, bajar, subir; compuerta
  FR-028; tenant nuevo) y concurrencia 20/20.
- **Pendientes**:
  1. **T072-3** — `app/scripts/e2e_qr_flow.py` no corre y está **obsoleto desde antes de esta spec**: su *seed* no
     informa `presentation_id` (`NOT NULL` desde la spec 083) y, aun reparado, `POST /cart/submit` exige desde la spec
     025 un cuerpo con el intento de pago; hay que reescribir el recorrido (spec aparte).
  2. **T075** — condiciones de despliegue en producción (compuerta FR-028 y `pg_dump` por esquema antes de
     migrar; despliegue coordinado de backend y frontend; avisar a los cajeros con la pantalla abierta).
  3. **Manuales**: abrir la **vista previa de impresión real** con un turno de 11 líneas (SC-005; el navegador de
     pruebas era *headless*) y cronometrar SC-003 (< 30 s) con un administrador.
