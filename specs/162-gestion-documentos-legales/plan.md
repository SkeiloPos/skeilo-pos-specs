# Implementation Plan: Gestión de documentos legales de plataforma, plantilla de tenant y consentimiento del cliente final

**Branch**: `162-gestion-documentos-legales` | **Date**: 2026-11-18 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/162-gestion-documentos-legales/spec.md`

## Summary

La plataforma necesita versionar y publicar su Política de Privacidad y sus Términos y
Condiciones (solo super admin), ofrecer una plantilla legal maestra parametrizable que
cada tenant rellena con sus propios datos para generar y publicar su propio documento
legal (snapshot inmutable con huella de verificación), y exigir aceptación trazable en dos
puntos: el administrador del tenant frente a los documentos de plataforma (bloqueo de
panel), y el cliente final frente al documento vigente del tenant, registrada en la misma
operación en que se captura su nombre en el menú QR. El enfoque técnico reutiliza
exclusivamente patrones ya existentes en `pos-backend` (schema-per-tenant para el
aislamiento de FR-020, `http_cache.weak_etag`/`json_or_304` para la huella de contenido y
el cacheo público, `rate_limit.enforce` para el límite de abuso, `mail.send_email` para el
aviso por correo, y el punto de creación del `SessionParticipant` en
`cart/service.py::open_session` para la atomicidad del consentimiento) sin añadir
dependencias nuevas.

## Technical Context

**Language/Version**: Python 3.11 (FastAPI, backend) · TypeScript/Angular (frontend,
`pos-heladeria`)

**Primary Dependencies**: FastAPI, SQLAlchemy 2.x, Alembic, `markdown-it-py` (ya en
`requirements.txt` — se reutiliza para renderizar Markdown → HTML, sin dependencia nueva),
`httpx` (ya usado por `app/core/mail.py`)

**Storage**: PostgreSQL 16, schema-per-tenant (`shared` + un schema por tenant) — mismo
motor y mismo patrón de aislamiento que el resto de `pos-backend`

**Testing**: `pytest` (backend, incluye `app/characterization_tests/` — ninguno de esos
tests protege comportamiento tocado por esta spec, ver Constitution Check); Angular/Jasmine
+ Karma (frontend, ver memoria de proyecto sobre asentamiento de tests con `injectPagedQuery`)

**Target Platform**: Linux server (API) + navegador (landing pública y SPA Angular,
incluido el flujo del menú QR en móvil)

**Project Type**: Web (backend `pos-backend` + frontend `pos-heladeria`, dos repositorios
independientes en producción, por Constitución §"Alcance del Proyecto")

**Performance Goals**: Los endpoints públicos nuevos (`/legal/platform-documents/{tipo}`,
`/legal/tenant-documents/{id}`) deben soportar el tráfico normal de landing + menú QR sin
degradar; se resuelve con `ETag`/304 (evita reserializar en cada poll) y un límite de 30
req/min por IP (research.md Decisión 9) — sin objetivo numérico de latencia propio, al no
tratarse de una ruta transaccional.

**Constraints**: FR-011 (sustitución literal sin motor de plantillas ni evaluación de
código); FR-014 (inmutabilidad de snapshot, aplicada a nivel de servicio: ningún `UPDATE`
de contenido tras `INSERT`); FR-018 (atomicidad: consentimiento y `SessionParticipant` en
la misma transacción); FR-020 (aislamiento entre tenants, resuelto por el propio schema-per-
tenant sin columna `tenant_id` adicional en las tablas de tenant)

**Scale/Scope**: 3 entidades nuevas en `shared`, 3 entidades nuevas por schema de tenant
(replicadas a cada tenant existente vía migración Alembic sobre `tenant` metadata), ~15
endpoints nuevos repartidos en 3 routers (`super-admin`, panel de tenant, público) + 2
endpoints existentes modificados de forma aditiva (`GET /menu/qr-token/{token}`,
`POST /cart/sessions`)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Evaluación |
|---|---|
| I. Nace de un spec | ✅ `specs/162-gestion-documentos-legales/spec.md` ya aprobado, con clarificaciones resueltas |
| II. Comportamiento existente protegido | ⚠️ **Ver Complexity Tracking**: FR-016 cambia comportamiento existente de `POST /cart/sessions` para tenants sin documento publicado (hoy no tienen esa restricción). Requiere decisión de negocio registrada en `registro-de-anomalias.md` **antes** de implementar el gate (research.md Decisión 7) |
| III. Characterization tests | ✅ Ningún test `"CONGELA comportamiento actual:"` existente cubre `open_session`/`SessionParticipant` con esta regla — no hay tests protegidos en conflicto, pero sí se debe agregar cobertura nueva para el comportamiento 409 (no characterization, funcionalidad nueva) |
| IV. Nuevos specs introducen comportamiento | ✅ Toda la funcionalidad es nueva; el único punto de tensión con comportamiento heredado está acotado en II |
| V. Sin refactors oportunistas | ✅ No se toca nada de catálogo/inventario/caja/facturación; los únicos archivos existentes modificados son los dos endpoints citados arriba, de forma aditiva |
| VI. Evolución incremental | ✅ Ver Project Structure: unidades separables (plataforma / plantilla / tenant / consentimiento) que `/speckit-tasks` puede secuenciar como fases independientes |
| VII. Compatibilidad con datos históricos | ✅ No se toca ninguna factura, venta ni importe; `TenantLegalDocument` es una tabla nueva, sin relación con facturación |
| VIII. Evolución del modelo de datos | ✅ Ver `data-model.md` — 6 tablas nuevas, sin alterar columnas existentes; migraciones sin backfill (nacen vacías); rollback = `alembic downgrade` estándar, sin dato preexistente que preservar |
| IX. Dependencias nuevas | ✅ Ninguna dependencia nueva — `markdown-it-py` y `httpx` ya están en `requirements.txt` y en uso |
| X. Verificación obligatoria | A verificar en implementación: tests de servicio para la máquina de estados borrador/publicado/superado, para la validación de variables, y para la atomicidad de FR-018 |
| XI. Negocio vs técnico | ✅ El spec ya distingue ambas (ver Assumptions: revisión legal del contenido es decisión de proceso, no del sistema) |
| XII. Trazabilidad | ✅ Cadena completa: Necesidad (spec Input) → Spec → esta decisión de negocio pendiente (II) → Implementación → Tests → Verificación |
| XIII–XV. Español CO / ramas / commits | A aplicar en implementación (rama `feat/162-gestion-documentos-legales`, commits en inglés bajo pedido explícito) |

**Resultado**: PASA con una advertencia (Principio II) que debe resolverse como decisión de
negocio registrada antes de implementar FR-016/FR-018 del gate — no bloquea el diseño de
esta fase, sí bloquea el inicio de la implementación de esa pieza específica. Ver
Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/162-gestion-documentos-legales/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
│   ├── super-admin-api.md
│   ├── tenant-panel-api.md
│   └── public-api.md
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
../pos-backend/
├── app/
│   ├── core/
│   │   ├── models.py                      # [MOD, aditivo] + PlatformLegalDocument,
│   │   │                                   #   MasterLegalTemplate,
│   │   │                                   #   TenantAdminPlatformAcceptance (schema shared)
│   │   ├── legal_template.py               # [NUEVO] sustitución literal + validación de
│   │   │                                   #   variables (research.md Decisión 3)
│   │   ├── legal_markdown.py                # [NUEVO] render Markdown→HTML (markdown-it-py)
│   │   ├── mail_templates/
│   │   │   └── plantilla_actualizada.py     # [NUEVO] email de FR-015
│   │   └── rate_limit.py                    # [MOD, aditivo] bucket "legal_public"
│   ├── models/
│   │   ├── tenant_legal_profile.py          # [NUEVO] schema tenant
│   │   ├── tenant_legal_document.py         # [NUEVO] schema tenant
│   │   ├── client_consent_acceptance.py     # [NUEVO] schema tenant
│   │   └── __init__.py                      # [MOD, aditivo] registra los 3 anteriores
│   └── api/v1/
│       ├── super_admin/
│       │   └── legal_router.py              # [NUEVO] contracts/super-admin-api.md
│       ├── legal/
│       │   ├── tenant_router.py             # [NUEVO] contracts/tenant-panel-api.md
│       │   └── public_router.py             # [NUEVO] contracts/public-api.md
│       ├── menu/router.py                   # [MOD, aditivo] agrega `legal_document` al payload
│       └── cart/
│           ├── router.py                    # [sin cambio de firma]
│           └── service.py                   # [MOD] open_session: gate FR-016 + inserción
│                                             #   atómica de ClientConsentAcceptance (FR-018)
├── alembic/versions/
│   ├── <rev>_add_platform_legal_tables.py   # [NUEVO] shared
│   └── <rev>_add_tenant_legal_tables.py     # [NUEVO] tenant
└── app/characterization_tests/              # sin cambios — ningún test protegido afectado

../pos-heladeria/
└── src/app/modules/
    ├── super-admin/                         # [MOD] pantallas de documentos de plataforma
    │   └── pages/legal/                     #   + plantilla maestra (nuevas páginas)
    ├── settings/                            # [MOD] pantalla de perfil legal + vista previa
    │   └── pages/legal/                     #   + publicación del documento de tenant
    ├── dashboard/layout/                    # [MOD] modal de bloqueo FR-019 (aceptación
    │                                        #   de plataforma), engarzado al shell del panel
    └── (menú QR público, módulo del cliente final — ubicar junto al flujo de
        captura de nombre existente): aviso + enlace al documento vigente (FR-017)
```

**Structure Decision**: Se mantiene la separación de dos repositorios ya establecida por la
constitución (`pos-backend` API, `pos-heladeria` frontend). Dentro de `pos-backend` se
crean tres routers nuevos en vez de ampliar routers existentes (`super_admin`, uno nuevo
`legal` para tenant+público) porque ninguno de los routers actuales modela un recurso
versionado con máquina de estados borrador/publicado/superado — mezclar esto en, por
ejemplo, `super_admin/router.py` (gestión de usuarios/planes) sería acoplar dominios sin
relación. Los dos endpoints existentes que cambian (`menu/router.py`, `cart/service.py`) se
modifican in-place porque son, exactamente, los puntos de integración identificados en
research.md (Decisiones 6 y 8) — crear una copia paralela de esas rutas sería la clase de
complejidad que el Principio V prohíbe.

## Complexity Tracking

> Fill ONLY if Constitution Check has violations that must be justified

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| Principio II: FR-016/FR-018 cambian el comportamiento actual de `POST /cart/sessions` para tenants sin documento legal publicado (hoy abren sesión de mesa sin ninguna restricción legal) | Es exactamente lo que pide el spec (US3 AC5, US4 AC3) — sin este gate no hay garantía de que exista evidencia de consentimiento antes de capturar el nombre, que es el objetivo de negocio central de la funcionalidad (US4, "Why this priority") | No aplicar el gate (dejar que cualquier tenant siga operando sin documento publicado) incumpliría directamente FR-016; aplicarlo sin registrar la decisión de negocio ni una estrategia de corte (feature flag / fecha anunciada) arriesga romper en caliente a tenants ya en producción sin documento — por eso esta fila existe: **antes de implementar esta pieza**, se debe (a) registrar la decisión en `specs/000-reconocimiento/registro-de-anomalias.md` con quién/cuándo autoriza el cambio, y (b) decidir en `/speckit-tasks` si el rollout necesita un flag de activación por tenant o una fecha de corte comunicada, en vez de activarse inmediatamente para toda la base instalada al mergear |
