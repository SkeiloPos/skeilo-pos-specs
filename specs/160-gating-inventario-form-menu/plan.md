# Implementation Plan: Ocultar sección de Inventario en el formulario de carta según el plan

**Branch**: `160-gating-inventario-form-menu` | **Date**: 2026-11-17 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/160-gating-inventario-form-menu/spec.md`

## Summary

El formulario de producto/tamaño de la carta del menú (`ProductFormComponent`, en
`pos-heladeria`) hoy muestra la sección "Inventario" siempre, deshabilitada con un mensaje
de upsell ("Tu plan actual no incluye el módulo de inventario") cuando el plan del tenant
no incluye ese módulo. El comportamiento esperado es ocultar la sección por completo
(interruptor "Maneja inventario", su descripción y el contenido de insumos) cuando el plan
no la incluye, y mostrarla funcional cuando sí la incluye — sin perder nunca la
configuración de inventario ya guardada de un producto/tamaño, y reflejando siempre el
estado vigente del plan al abrir el formulario.

Enfoque técnico: el componente ya tiene un computed `inventarioIncluido()` fail-closed
(basado en `PlanSummaryService.summary()`) que hoy solo controla el atributo `[disabled]`
del interruptor. Se reutiliza ese mismo computed, sin cambiar su definición, para envolver
en `@if (inventarioIncluido())` la sección 3 "Inventario" completa y el botón de salto
"Inventario" de la tabla de tamaños — replicando exactamente el patrón ya usado en
`ReportsPageComponent`/`ReportsService` (`inventarioIncluido()` + `@if`) para el mismo
módulo. No se requiere ningún nuevo endpoint, servicio, dependencia ni cambio de modelo de
datos: es un cambio de template, acotado a un solo componente del frontend.

## Technical Context

**Language/Version**: TypeScript 5.9 (Angular 21) — frontend `pos-heladeria`. No hay
cambios en `pos-backend`.

**Primary Dependencies**: Angular (`@angular/core` ^21.1.0), signals/computed nativos de
Angular. No se añade ninguna dependencia nueva (Principio IX no aplica: no hay dependencia
nueva que justificar).

**Storage**: N/A para esta feature — no hay cambios de esquema ni de persistencia. Los
datos de inventario del producto/tamaño (`tracks_inventory`, insumos) ya existen en
`pos-backend`/Postgres y no se modifican por esta feature.

**Testing**: Jasmine/Karma (specs `*.spec.ts` ya existentes en `pos-heladeria`), siguiendo
el patrón de aserciones de presencia/ausencia en el DOM usado en
`reports-page.component.spec.ts`.

**Target Platform**: Web (Angular SPA), navegador de escritorio — sin cambios de plataforma.

**Project Type**: Web application (frontend `pos-heladeria` + backend `pos-backend`). Esta
feature toca únicamente el frontend.

**Performance Goals**: N/A — cambio de visibilidad condicional en un template ya existente,
sin impacto de rendimiento medible ni nuevas consultas HTTP (el `summary()` del plan ya
está hidratado antes de que el formulario se renderice).

**Constraints**: El cambio debe ser puramente de template/visibilidad; no debe alterar el
payload de guardado del formulario ni el modelo `draft().tracks_inventory`, para no violar
FR-005/FR-006 (no pérdida de datos existentes).

**Scale/Scope**: Un solo componente (`ProductFormComponent`) en un solo repositorio
(`pos-heladeria`). No afecta a `pos-backend`.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Principio I (Nace de un spec)**: PASS. Existe `spec.md` aprobado para esta feature
  antes de cualquier cambio de código.
- **Principio II (Comportamiento existente protegido)**: PASS con decisión documentada. El
  comportamiento actual (mostrar deshabilitado + upsell) cambia intencionalmente a
  "ocultar por completo" — es exactamente el cambio de comportamiento que este spec
  autoriza explícitamente (FR-002), motivado por una inconsistencia reportada frente al
  patrón ya usado en ajustes/reportes (FR-007). No requiere entrada en
  `registro-de-anomalias.md` porque no es una decisión de negocio que contradiga un
  comportamiento protegido por characterization tests — es la corrección de un defecto de
  UI hacia el patrón ya vigente en el resto del sistema, dentro del alcance normal de
  evolución funcional (Principio IV).
- **Principio III (Characterization tests)**: PASS. No hay characterization tests
  `"CONGELA comportamiento actual:"` sobre esta sección (es un componente de
  `pos-heladeria`, fuera del alcance de los characterization tests de `pos-backend`
  descritos en la constitución). Los tests afectados son specs Angular ordinarios de la
  nueva funcionalidad, no characterization tests protegidos.
- **Principio V (No refactorizaciones oportunistas)**: PASS. Se descarta explícitamente
  (ver `research.md`, Decisión 2) introducir una directiva estructural compartida
  (`*appHasModule`) pese a que simplificaría el código duplicado en 4 componentes — se
  trata como mejora técnica fuera de alcance, no parte de esta feature.
  La implementación se limita al archivo mínimo necesario.
- **Principio VI (Evolución incremental)**: PASS. Cambio acotado a una sola unidad
  verificable (un componente de frontend), sin mezclar refactorización, migración de datos
  ni cambios de arquitectura.
- **Principio VII (Compatibilidad con datos históricos)**: PASS. No aplica — no hay
  facturas ni datos históricos involucrados en esta feature.
- **Principio VIII (Evolución del modelo de datos)**: PASS — no aplica, no hay cambios de
  modelo de datos (ver `data-model.md`).
- **Principio IX (Dependencias nuevas)**: PASS — no aplica, no se introduce ninguna
  dependencia nueva.
- **Principio X (Verificación obligatoria)**: Se abordará en Phase 2 (`tasks.md`, fuera del
  alcance de este comando): actualización de `product-form.component.spec.ts` para
  verificar ausencia/presencia en el DOM en vez de estado deshabilitado.
- **Principio XI/XII (Negocio vs. técnico / Trazabilidad)**: PASS. La necesidad de negocio
  (reportada como defecto) está documentada en el spec; esta decisión de implementación es
  puramente técnica (reutilizar un computed y patrón ya existentes).
- **Principio XIV (Rama Git)**: Pendiente al momento de implementar (no de planear): la
  rama `160-gating-inventario-form-menu` ya existe como working copy de specs; al iniciar
  cambios de código en `pos-heladeria` se debe verificar/crear una rama con la convención
  `<tipo>/<numero_spec>-<nombre_spec>` (ej. `fix/160-gating-inventario-form-menu`) antes de
  tocar código, tal como exige el principio — se deja como recordatorio para la fase de
  implementación, no bloquea esta fase de planeación.
- **Principio XV (Commits)**: No aplica a la fase de planeación.

**Resultado**: Ninguna violación que requiera justificación en Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/160-gating-inventario-form-menu/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output
├── data-model.md         # Phase 1 output
├── quickstart.md         # Phase 1 output
└── tasks.md              # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

No se genera carpeta `contracts/`: esta feature no expone ni modifica ninguna interfaz
externa (API, CLI, esquema de mensajería). Es un cambio de visibilidad en un componente de
UI que consume datos ya disponibles vía un servicio existente (`PlanSummaryService`), sin
tocar ningún contrato de `pos-backend`.

### Source Code (repository root)

```text
# Repositorio: ../pos-heladeria (frontend Angular) — único repositorio afectado por esta feature
pos-heladeria/
├── src/app/modules/products/pages/
│   ├── product-form.component.ts        # Template + computed inventarioIncluido() ya existente
│   └── product-form.component.spec.ts   # Tests a actualizar (ausencia/presencia en el DOM)
├── src/app/modules/plan/services/
│   └── plan-summary.service.ts          # Fuente de verdad del plan — sin cambios, solo lectura
└── src/app/modules/reports/pages/
    └── reports-page.component.ts        # Referencia del patrón "ocultar con @if" ya validado

# Repositorio: ../pos-backend — SIN CAMBIOS en esta feature (no hay nuevos endpoints
# ni modificaciones de esquema; FR-007 solo exige consistencia de comportamiento en el
# frontend con superficies que ya leen el mismo flag de plan).
```

**Structure Decision**: Feature exclusivamente de frontend sobre un único componente
existente (`ProductFormComponent`) dentro de `pos-heladeria`. No se crea ninguna carpeta ni
módulo nuevo; se reutiliza el servicio (`PlanSummaryService`) y el patrón (`@if (…)` sobre
un computed fail-closed) ya existentes en el mismo repositorio, siguiendo el precedente de
`ReportsPageComponent`. `pos-backend` no requiere ningún cambio.

## Complexity Tracking

*No violaciones de la Constitution Check que requieran justificación. Tabla omitida.*
