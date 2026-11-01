# Implementation Plan: Rediseño de cambio de contraseña para usuarios invitados

**Branch**: `145-rediseno-password-invitado` | **Date**: 2026-10-30 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/145-rediseno-password-invitado/spec.md`

## Summary

Rediseñar visualmente la pantalla de cambio de contraseña obligatorio que ve un usuario
invitado en su primer inicio de sesión (`ChangePasswordComponent` en `pos-heladeria`), para
que sea fiel al diseño de referencia `desing/Primer inicio de sesion.dc.html`: layout de dos
columnas con panel promocional, encabezado con badge del negocio + rol + correo, checklist
en tiempo real de los requisitos reales de contraseña (longitud 8-12 y distinta a la
temporal), manejo de errores específico por caso, y pantalla de confirmación "Cuenta lista"
que redirige al login del negocio. El enfoque técnico es **solo frontend**: la investigación
de Fase 0 confirmó que todos los datos necesarios (rol, correo, nombre del negocio) ya están
disponibles para el usuario autenticado con contraseña temporal a través de endpoints
existentes (`POST /auth/login` y `GET /tenant`), por lo que no se requiere ningún cambio en
`pos-backend`. La implementación reutiliza el `AuthShellComponent`, los tokens `.auth-*`, el
`PasswordInputComponent` y la fuente de verdad `password-policy.ts` ya usados por
`reset-password.component.ts`.

## Technical Context

**Language/Version**: TypeScript ~5.9.2, Angular ^21.1.0 (standalone components, signals)

**Primary Dependencies**: Angular Reactive Forms, RxJS, `AuthShellComponent`,
`PasswordInputComponent`, `IconMiComponent`, `TenantInfoService`, tokens `.auth-*` en
`pos-heladeria/src/styles.css`

**Storage**: N/A (no hay cambios de modelo de datos ni de esquema)

**Testing**: `@angular/build:unit-test` (Jest-compatible unit test runner del proyecto
Angular); characterization/unit tests existentes en `pos-heladeria/src/app/modules/auth/pages/`

**Target Platform**: Navegador web (desktop y móvil), dentro de la SPA Angular de
`pos-heladeria`

**Project Type**: web-service consumer — módulo de autenticación de una aplicación Angular
existente; sin componente de backend

**Performance Goals**: Sin metas de rendimiento específicas más allá de las ya vigentes en
la SPA; la pantalla debe sentirse instantánea (validación de requisitos en cada tecla, sin
llamadas de red adicionales salvo `GET /tenant` ya existente)

**Constraints**:
- No se modifica ninguna regla de validación de contraseña vigente (longitud 8-12,
  distinta a la temporal); el checklist visual debe reflejar exactamente esas dos reglas,
  no las de mayúscula/número que trae el diseño de referencia como ejemplo (decisión
  confirmada con el usuario, ver spec.md § Assumptions).
- No se modifica el comportamiento de `POST /auth/change-password` ni la lógica de consumo
  de invitaciones en `POST /auth/login` (Principio II de la constitución): este trabajo es
  únicamente visual/UX.
- Debe reutilizar `AuthShellComponent` y los tokens `.auth-*` ya usados por
  `login`/`reset-password`, en vez de las clases Tailwind ad-hoc actuales de
  `ChangePasswordComponent`, para consistencia visual entre pantallas de auth.
- Debe reutilizar `PASSWORD_RULES`/`cumplePolitica` de `password-policy.ts` como única
  fuente de verdad del checklist y del validador, igual que `reset-password.component.ts`
  (evita que el checklist y el validador diverjan).

**Scale/Scope**: Una sola pantalla (`ChangePasswordComponent`) dentro de `pos-heladeria`;
sin cambios en `pos-backend`; sin migraciones de datos.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Principio I (Nace de un spec)**: ✅ Existe `spec.md` aprobado en `specs/145-rediseno-password-invitado/` antes de tocar código.
- **Principio II (Comportamiento existente protegido)**: ✅ No se modifica ninguna regla de validación de contraseña, ni el endpoint `POST /auth/change-password`, ni la lógica de consumo de invitaciones. Único comportamiento nuevo: la pantalla ahora consulta `GET /tenant` (endpoint ya existente y ya alcanzable con las credenciales que el usuario tiene en este punto del flujo) para mostrar el nombre del negocio — no es un cambio de comportamiento de negocio, es una llamada adicional de lectura a un endpoint que ya existe y ya es accesible, documentada en research.md.
- **Principio III (Characterization tests)**: ✅ No aplica ningún test `"CONGELA comportamiento actual:"` a este componente; se preservan/actualizan los tests unitarios existentes de `ChangePasswordComponent` para que verifiquen el nuevo markup sin alterar las aserciones sobre reglas de negocio (longitud, coincidencia, mensajes de error).
- **Principio V (Sin refactors oportunistas)**: ✅ El alcance se limita a `ChangePasswordComponent` y, si hiciera falta, un método de lectura en `TenantInfoService`/`AuthService` para exponer el nombre del negocio ya disponible por `GET /tenant`. No se tocan otras pantallas de auth salvo como referencia de patrón.
- **Principio VI (Evolución incremental)**: ✅ Cambio de una sola clase (rediseño visual/UX de una pantalla), sin mezclar migración de datos, cambio de arquitectura ni cambio de reglas de negocio.
- **Principio VIII (Evolución del modelo de datos)**: N/A — no hay cambios de modelo de datos.
- **Principio IX (Dependencias nuevas)**: ✅ No se introduce ninguna dependencia nueva; se reutilizan componentes y servicios ya existentes en `pos-heladeria`.
- **Principio X (Verificación obligatoria)**: Se verificará con tests unitarios del componente (reglas de validación, mensajes de error, checklist en tiempo real, navegación tras éxito) y verificación manual en navegador (desktop y móvil) contra el diseño de referencia.
- **Principio XIII (Español de Colombia)**: ✅ Esta spec, research, data-model y quickstart se redactan en español de Colombia. El nombre de rama y los mensajes de commit (cuando se soliciten) se escriben en inglés.
- **Principio XIV (Ramas Git)**: Pendiente de ejecutar antes de tocar código en la fase de implementación: crear rama `style/145-redesign-invited-password` (es un cambio visual, no una funcionalidad de negocio nueva) o `feat/145-redesign-invited-password` si se prefiere el tipo `feat` por tratarse de una pantalla nueva de cara al usuario — se decide en `/speckit-implement`.

No hay violaciones que requieran justificación en Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/145-rediseno-password-invitado/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command) — vacío, ver nota abajo
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

No se genera contenido en `contracts/`: la feature no expone ni modifica ninguna interfaz
externa (API, CLI, esquema) — consume exclusivamente endpoints ya existentes y ya
documentados (`POST /auth/change-password`, `GET /tenant`) sin alterar su contrato.

### Source Code (repository root)

Este feature vive enteramente en el repositorio sibling `pos-heladeria`
(`/home/deimer/Documents/projects/inventario/pos-heladeria`), no en `pos-specs` ni en
`pos-backend`.

```text
pos-heladeria/
├── src/app/modules/auth/
│   ├── pages/
│   │   ├── change-password.component.ts     # Componente a rediseñar (markup + lógica)
│   │   └── reset-password.component.ts      # Patrón de referencia (checklist, AuthShellComponent)
│   ├── components/
│   │   └── auth-shell.component.ts           # Shell de dos columnas a reutilizar
│   └── password-policy.ts                    # Fuente de verdad de reglas (PASSWORD_RULES, cumplePolitica)
├── src/app/shared/
│   ├── password-input/password-input.component.ts   # Campo de contraseña con mostrar/ocultar
│   └── icon-mi/icon-mi.component.ts                  # Iconos del checklist y botones
├── src/app/core/
│   ├── services/auth.service.ts              # changePassword(), currentUser()
│   ├── auth/auth-api.service.ts               # POST /auth/change-password
│   ├── guards/password-change.guard.ts        # Guards de entrada/salida de la ruta
│   └── tenant/tenant-info.service.ts          # GET /tenant → nombre del negocio
├── src/styles.css                             # Tokens .auth-* (colores, tipografía, componentes)
└── src/app/app.routes.ts                      # Ruta 'change-password'
```

**Structure Decision**: Cambio contenido en `pos-heladeria/src/app/modules/auth/` (y, de
forma opcional y mínima, `tenant-info.service.ts` si se decide exponer el nombre del
negocio mediante un método nuevo en vez de leerlo directo del signal existente). No se toca
`pos-backend` ni `pos-specs` fuera de esta carpeta de spec.

## Complexity Tracking

No aplica — el Constitution Check no registró violaciones.
