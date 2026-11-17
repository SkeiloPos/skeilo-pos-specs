# Implementation Plan: Gestión global de usuarios en el panel Super Admin

**Branch**: `159-gestion-global-usuarios-super-admin` | **Date**: 2026-11-16 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/159-gestion-global-usuarios-super-admin/spec.md`

## Summary

Rediseño del módulo de Usuarios del panel Super Admin: listado centralizado con indicadores
y filtros, ficha individual (información general, actividad, seguridad, negocios
asociados), administración (editar, cambiar rol, activar/suspender/desbloquear, recuperar
contraseña, revocar sesiones, anonimizar, eliminar permanentemente) y una nueva sección de
auditoría administrativa, conservando la navegación existente del panel.

La investigación técnica (ver `research.md`) encontró que varias capacidades que el spec da
por existentes en `pos-backend` **no existen hoy**: no hay membresía multi-negocio por
usuario (`users.tenant_id` es una FK única, no una relación muchos-a-muchos), no hay un
campo de estado enriquecido (solo `active: bool`), no hay conteo de intentos fallidos ni
bloqueo automático, no hay un registro de sesiones activas con dispositivo/IP (solo un corte
global `tokens_valid_after` y una lista negra Redis de un solo `jti` para logout), y no hay
una bitácora de auditoría administrativa de alcance plataforma (la tabla `audit_logs`
existente vive en el esquema `tenant`, por negocio). Esto se confirmó con el usuario, que
decidió explícitamente construir estas bases dentro de esta misma spec (ver pregunta de
alcance respondida: "Plan it all in this spec"), en vez de dividirlas en specs previas.

El enfoque técnico, por tanto, cubre dos capas:
1. **Backend (`pos-backend`)**: nuevas entidades y columnas aditivas (membresía
   multi-negocio, estado enriquecido de usuario, sesiones activas, bitácora de auditoría
   administrativa, bloqueo por intentos fallidos) y nuevos endpoints bajo `/super-admin`,
   más cambios puntuales y aditivos en `/auth/login` y `/auth/refresh-token` para alimentar
   sesiones y el conteo de intentos fallidos — sin alterar el contrato ni los códigos de
   respuesta ya protegidos por characterization tests.
2. **Frontend (`pos-heladeria`)**: reemplazo del módulo `super-admin/users` existente
   (listado simple, formulario y servicio actuales) por el módulo completo descrito en el
   spec, más una nueva sección de Auditoría, integrados en el layout del panel Super Admin
   ya existente (`super-admin/routes.ts`), usando `design/SkeiloPOS Super Admin -
   Usuarios.dc.html` como referencia visual.

La entrega se organiza en incrementos alineados a las User Stories P1→P2→P3 del spec (no en
una sola unidad), para mantener el Principio VI de la constitución (evolución incremental)
pese al tamaño total del cambio.

## Technical Context

**Language/Version**: Python 3.11 (backend, FastAPI 0.136.3) · TypeScript 5.9 / Angular
21.1 standalone components (frontend)

**Primary Dependencies**: FastAPI, SQLAlchemy 2.0.50, Pydantic 2.13, Alembic 1.18
(migraciones), Redis 8.0 (contador deslizante de intentos fallidos — mismo mecanismo que
`enforce_sliding_window` ya usado en `/auth/forgot-password` — y lista negra de `jti`),
Celery 5.6 (envío asíncrono de correo de recuperación, ya existente — spec 096); Angular
`HttpClient`, RxJS 7.8. Ninguna dependencia nueva (Principio IX: no aplica justificación de
dependencia nueva).

**Storage**: PostgreSQL 16, esquema `shared` (usuarios, tenants, roles — cross-tenant,
consultado por Super Admin) + un esquema por tenant (`tenant`, donde viven `audit_logs` de
operación normal, órdenes, facturas). Las entidades nuevas de esta spec (membresía,
sesiones, bitácora administrativa) viven en `shared`, igual que `User`/`Tenant`/`Role`.

**Testing**: `pytest`/`unittest` sobre `app/characterization_tests/` (protegidos) + tests
nuevos de la funcionalidad en el mismo directorio o uno paralelo, siguiendo el patrón ya
usado por `test_auth_session_revocation.py`; Angular con Karma/Jasmine y `TestBed`,
incluyendo asentamiento de queries async (ver nota operativa: componentes con
`injectPagedQuery` necesitan ~5 rondas de `tick`+`TestBed.tick`+`detectChanges` para asentar,
y no se pueden escribir señales durante el render del template — NG0600).

**Target Platform**: servidor Linux (Docker, API ya en producción) + navegador (panel web
responsive, breakpoint < 1024px ya vigente en el panel).

**Project Type**: aplicación web (API + frontend Angular), feature acotada al módulo Super
Admin del panel ya existente.

**Performance Goals**: listado/ficha/auditoría "listos para interacción o con estado de
carga claro" en menos de 2 s en condiciones normales de red, incluso con cientos de tenants
y miles de usuarios (SC-010) — exige paginación server-side e índices adecuados en las
columnas de filtro/orden nuevas (estado, rol, tenant, fecha de registro/último acceso).

**Constraints**: no modificar el contrato ni los códigos de respuesta de
`/auth/login`/`/auth/refresh-token`/`/auth/logout` ya cubiertos por characterization tests
(solo extensiones aditivas); no tocar `tenant.audit_logs` (ámbito distinto, por tenant); no
alterar facturas/órdenes ya emitidas al anonimizar/eliminar un usuario (Principio VII) — la
anonimización preserva el historial transaccional, el borrado permanente se bloquea si existe
esa obligación de retención; toda migración nueva es aditiva y compatible con filas
existentes (columnas nuevas con default seguro, sin romper `active: bool` del que depende hoy
`get_current_user`).

**Scale/Scope**: 8 user stories (P1×4, P2×3, P3×1), ~15 endpoints nuevos/extendidos en
`/super-admin`, 5 entidades nuevas o ampliadas, reemplazo completo del módulo frontend
`super-admin/users` existente más una sección nueva de auditoría.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Evaluación |
|---|---|
| I. Nace de un spec | ✅ `specs/159-gestion-global-usuarios-super-admin/spec.md`, con clarificaciones registradas. |
| II. Comportamiento existente protegido | ✅ Todos los cambios de `pos-backend` son aditivos (columnas nuevas con default seguro, tablas nuevas, nuevas ramas de respuesta solo cuando el umbral de intentos fallidos o una sesión revocada aplican). No se identificó ningún comportamiento existente que deba *cambiar*; por tanto no se requiere entrada en `registro-de-anomalias.md`. Se revalida en Fase 1 contra `data-model.md`. |
| III. Characterization tests protegidos | ✅ `test_auth_session_revocation.py` y demás characterization tests de auth/super-admin se ejecutan sin modificar sus aserciones; los nuevos checks (sesión revocada, cuenta bloqueada) se insertan como ramas adicionales, verificadas con tests nuevos. |
| IV. Nuevos specs pueden introducir comportamiento nuevo | ✅ El bloqueo automático por intentos fallidos y el registro de sesiones son comportamiento nuevo autorizado por este spec. |
| V. No refactorizaciones oportunistas | ✅ El reemplazo de `super-admin-users-page.component.ts`/`super-admin-users.service.ts`/`admin-user.interface.ts` está dentro del alcance del spec (es el módulo que se rediseña), no una refactorización colateral. |
| VI. Evolución incremental | ⚠️ Ver **Complexity Tracking**: el alcance total mezcla una expansión importante del modelo de datos con la UI. Mitigado entregando por User Story (P1 listado+indicadores+ficha+nav → P2 administración+seguridad+auditoría → P3 anonimizar/eliminar), cada una verificable de forma independiente según el spec. |
| VII. Compatibilidad con datos históricos | ✅ Anonimizar conserva historial transaccional sin datos personales (FR-023); eliminar permanentemente se bloquea si hay obligación de retención vigente (FR-024); ninguna factura/orden ya emitida se recalcula ni se modifica. |
| VIII. Evolución del modelo de datos | ✅ Ver `data-model.md`: entidades nuevas, campos nuevos, compatibilidad, estrategia de migración y rollback explícitas para cada cambio de esquema. |
| IX. Dependencias nuevas | ✅ N/A — no se introduce ninguna dependencia nueva. |
| X. Verificación obligatoria | ✅ Ver `quickstart.md` y la futura `tasks.md`: cada FR/SC tiene un escenario de verificación. |
| XI. Negocio vs. técnico | ✅ Las decisiones de modelo de datos (research.md) son técnicas, instrumentan comportamiento ya decidido por el spec; no introducen reglas de negocio nuevas no pedidas. |
| XII. Trazabilidad | ✅ Necesidad (spec) → Decisión (research.md) → Implementación (tasks.md, futuro) → Tests → Verificación (quickstart.md). |
| XIII. Español de Colombia | ✅ Toda la documentación de esta spec se redacta en español de Colombia. |
| XIV. Ramas Git | Pendiente al iniciar implementación: crear `feat/159-gestion-global-usuarios-super-admin` en `pos-backend` y en `pos-heladeria` antes de tocar código (no aplica a este repo de specs). |
| XV. Commits | Pendiente al iniciar implementación: commits atómicos solo bajo pedido explícito del usuario, en inglés, Conventional Commits, sin marca de IA. |

**Resultado del gate**: PASA, con una complejidad justificada (Principio VI) documentada
abajo. No hay violaciones que bloqueen continuar a Phase 0.

## Project Structure

### Documentation (this feature)

```text
specs/159-gestion-global-usuarios-super-admin/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md         # Phase 1 output (/speckit-plan command)
├── quickstart.md         # Phase 1 output (/speckit-plan command)
├── contracts/            # Phase 1 output (/speckit-plan command)
│   └── super-admin-users-api.md
└── tasks.md               # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

Este repositorio (`pos-specs`) solo contiene la especificación. La implementación ocurre en
dos repositorios hermanos, ya existentes, bajo la estructura ya vigente (no se introduce
ninguna carpeta nueva de alto nivel):

```text
../pos-backend/app/
├── core/
│   └── models.py                        # User, Tenant, Role (ampliados: ver data-model.md)
├── models/
│   ├── tenant_membership.py              # NUEVO: membresía usuario↔tenant
│   ├── user_session.py                   # NUEVO: sesiones activas (device/browser/IP)
│   └── admin_audit_log.py                # NUEVO: bitácora de auditoría administrativa
├── api/v1/
│   ├── auth/routes.py                    # EXTENDIDO (aditivo): lockout + registro de sesión en login/refresh/logout
│   └── super_admin/
│       ├── router.py                      # EXTENDIDO: GET /users ampliado, GET /users/stats
│       ├── users_router.py                # NUEVO: ficha, administración, sesiones, anonimizar/eliminar
│       ├── audit_router.py                # NUEVO: GET /audit-logs
│       └── schemas.py                     # EXTENDIDO
├── alembic/versions/                      # NUEVO: migraciones aditivas (ver data-model.md)
└── characterization_tests/                 # NUEVO: tests de la funcionalidad + verificación de no-regresión

../pos-heladeria/src/app/modules/super-admin/
├── routes.ts                              # EXTENDIDO: nueva ruta de Auditoría
├── pages/
│   ├── super-admin-users-page.component.ts        # REEMPLAZADO (listado + indicadores)
│   ├── super-admin-user-detail-page.component.ts   # NUEVO (ficha con pestañas)
│   └── super-admin-audit-page.component.ts         # NUEVO
├── components/
│   ├── admin-user-form.component.ts        # REEMPLAZADO (edición)
│   ├── suspend-user-modal.component.ts      # NUEVO
│   ├── confirm-sensitive-action-modal.component.ts  # NUEVO (anonimizar/eliminar/revocar)
│   └── user-security-tab.component.ts       # NUEVO
├── services/
│   ├── super-admin-users.service.ts         # REEMPLAZADO/EXTENDIDO
│   └── super-admin-audit.service.ts         # NUEVO
└── interfaces/
    └── admin-user.interface.ts               # EXTENDIDO (estado enriquecido, membresías, sesiones)
```

**Structure Decision**: se reutiliza íntegramente la estructura ya vigente del módulo
`super-admin` en `pos-heladeria` (páginas/componentes/servicios/interfaces) y del router
`/super-admin` en `pos-backend`, extendiéndolos; no se crea ningún proyecto, paquete o
carpeta de alto nivel nuevo. Las entidades de dominio nuevas se agregan a `app/models/`
(patrón ya usado por `audit_log.py`, `session_participant.py`), no a `core/models.py`, salvo
las columnas añadidas a `User`/`Tenant` que sí viven en `core/models.py` por ser el archivo
donde esas clases ya están definidas.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|---------------------------------------|
| El incremento combina expansión de modelo de datos (membresía multi-negocio, estado enriquecido, sesiones, bloqueo por intentos fallidos, bitácora de auditoría) con la entrega de UI, en vez de ser solo "UI sobre datos existentes" (Principio VI). | El spec exige capacidades (FR-013/014/029/030/031/033) que no tienen dónde apoyarse en el modelo de datos actual; sin esas bases, los FR correspondientes no son implementables. El usuario, al preguntársele explícitamente durante esta planeación, decidió construirlas dentro de esta misma spec en vez de exigir specs previas separadas. | Dividir en specs previas (membresía multi-negocio, sesiones, bitácora) fue ofrecido como opción y explícitamente rechazado por el usuario en favor de un solo spec, para no retrasar el valor de negocio del módulo completo. Se mitiga, dentro de esta spec, entregando por User Story priorizada (P1→P2→P3), cada una independientemente verificable, en vez de como una sola unidad monolítica. |
