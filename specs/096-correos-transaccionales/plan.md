# Implementation Plan: Correos transaccionales de acceso con la marca de SkeiloPOS

**Branch**: `feat/096-transactional-email-templates` | **Date**: 2026-10-06 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/096-correos-transaccionales/spec.md`

## Summary

Los cuatro correos del flujo de acceso —invitación, alta de negocio, restablecimiento y aviso de
contraseña cambiada— ya se envían hoy con disparadores probados. Esta spec reemplaza **únicamente su
presentación**: tres plantillas fieles al diseño aprobado, cada una con salida en HTML y en texto
plano, con todos los valores dinámicos escapados y validados.

El enfoque técnico es un paquete nuevo `app/core/mail_templates/` que concentra la maqueta compartida,
la validación de campos obligatorios, el escape y el formato de fecha, y expone tres constructores que
devuelven un objeto `EmailContent(subject, html_body, text_body)`. Los cuatro disparadores pasan a
pedirle a ese paquete el asunto y los dos cuerpos en una sola llamada, en vez de armar el asunto como
literal en cada router. `app/core/mail.py` conserva el transporte (`create_message`, `send_email`) y
gana el cuerpo en texto plano en el mensaje que envía al microservicio.

No hay cambio de modelo de datos, ni migración, ni trabajo en `pos-heladeria`. La única pieza fuera del
código es la subida manual, una sola vez, del logo a la clave fija
`brand/logo-horizontal-claro-1200.png` del bucket de producción.

## Technical Context

**Language/Version**: Python 3.12 (imagen de despliegue, `Dockerfile`) / Python 3.14 (venv local
`pos-backend/env`). El código no usa nada posterior a 3.12.

**Primary Dependencies**: FastAPI, SQLAlchemy 2.x, Celery, `httpx` (transporte del correo), biblioteca
estándar `html` (escape), `zoneinfo` (hora de Colombia). **Ninguna dependencia nueva** — ver
`research.md` Decisión 3.

**Storage**: PostgreSQL 16, schema-per-tenant. **Sin cambios de esquema en esta spec.** Cloudflare R2
para el logo de marca, servido por `assets.skeilopos.com` (clave fija, un solo objeto nuevo).

**Testing**: `unittest` de la biblioteca estándar, sobre SQLite en memoria con
`schema_translate_map`. Comando:
`python -m unittest discover -s app/characterization_tests -p 'test_*.py'`.
**Línea base medida el 2026-10-06: 1320 tests, OK.**

**Target Platform**: servicio web Linux (contenedor) + worker Celery. El artefacto final que esta spec
produce se renderiza en clientes de correo de terceros, no en un navegador que controlemos.

**Project Type**: servicio web (API). El trabajo es íntegramente de `pos-backend`.

**Performance Goals**: sin objetivo nuevo. El correo de invitación se genera y envía de forma síncrona
dentro de `POST /invitations`; la generación de la plantilla es composición de cadenas en memoria, de
orden microsegundos, y no altera el perfil de latencia de ese endpoint —lo que domina es el `POST` al
microservicio externo, con su `timeout=10.0` actual.

**Constraints**:

- **El servicio de envío es opaco** (D2). Solo se conoce la forma del mensaje que ya acepta:
  `POST {EMAIL_API_URL}/api/email/send` con `{from, to, subject, htmlBody}`. Que acepte el cuerpo en
  texto plano no se puede verificar leyendo código: se verifica con un envío real (FR-048, D7).
- **El entorno de desarrollo envía por el servicio de producción** (A-120, D15). Toda prueba manual
  manda correo de verdad; FR-061 acota el riesgo a casillas del propio equipo.
- **Compatibilidad de clientes de correo**: nada de flexbox, grid, `<style>` externo ni CSS que
  Outlook de escritorio no soporte para la estructura (FR-005). Maquetación con tablas anidadas y
  estilos en línea.
- **La URL del logo no puede variar por entorno** (FR-006), lo que excluye derivarla de
  `ASSETS_BASE_URL`, que sí varía.
- **Firma del task de Celery**: `send_email_task` tiene tareas potencialmente en vuelo durante el
  despliegue; el parámetro del texto plano debe ser opcional.

**Scale/Scope**: 3 plantillas × 2 salidas = 6 piezas de maqueta; 4 disparadores existentes; 1 recurso
de marca; 6 archivos de test a actualizar o verificar y ~6 archivos de test nuevos. Volumen de envío
bajo (invitaciones y recuperaciones de un producto en arranque), sin requisito de rendimiento.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Evaluado contra la constitución v4.0.0.

| Principio | Estado | Evidencia / condición |
|---|---|---|
| **I** — Spec previo | ✅ PASS | `specs/096-correos-transaccionales/spec.md`, clarificado (16 decisiones cerradas). |
| **II** — Comportamiento existente protegido | ✅ PASS | A-113 a A-121 **están registradas** en `registro-de-anomalias.md` (verificado: A-113 en la línea 3566, A-121 en la 3808, última entrada de la cadena). La compuerta que bloqueaba FR-041 quedó cerrada el 2026-10-06. |
| **III** — Characterization tests | ✅ PASS | Ninguno de los seis archivos de test afectados lleva el prefijo `"CONGELA comportamiento actual:"` (verificado por búsqueda). El gate estricto del Principio III no aplica; sí aplica FR-059: cada actualización cita en el mismo cambio la decisión que la autoriza. |
| **IV** — Comportamiento nuevo permitido | ✅ PASS | Los cambios de asunto, remitente, hora y filas están definidos y autorizados por la spec. |
| **V** — Sin refactorización oportunista | ✅ PASS **con restricción** | El constructor de URL de ingreso está hoy triplicado (`invitations/router.py:22`, `auth/routes.py:62`, `super_admin/router.py:141`). **No se unifica.** FR-037 obliga a tener uno en `auth/routes.py`, que hoy no existe; se añade solo ese y los otros dos quedan intactos. Queda anotado como trabajo independiente. |
| **VI** — Evolución incremental | ✅ PASS | Entrega por capas: maqueta compartida → US1 (invitación) → US5 (alta de negocio, reusa US1) → US2 (restablecimiento) → US3 (contraseña cambiada) → US4 (verificación en clientes). Cada capa deja la suite en verde. |
| **VII** — Datos históricos | ✅ N/A | Ninguna factura se lee, recalcula ni representa. |
| **VIII** — Modelo de datos | ✅ N/A declarado | **Cero entidades nuevas, cero columnas nuevas, cero migraciones.** Las "entidades" de `data-model.md` son objetos de valor en memoria. Sin migración no hay estrategia de rollback que declarar: revertir es revertir el código. |
| **IX** — Dependencias nuevas | ✅ PASS | **Ninguna.** Se evaluó y descartó Jinja2 (`research.md` Decisión 3): está instalado como dependencia transitiva pinneada pero `app/` nunca lo importa, y convertirlo en dependencia directa es una decisión que el Principio IX exige justificar en la spec — y la spec 096 no la justifica. |
| **X** — Verificación obligatoria | ✅ PASS | `quickstart.md` define la verificación automatizada (suite completa + tests nuevos por requisito) y las ocho verificaciones manuales con envío real que FR-048, FR-052, SC-006 y SC-007 exigen. |
| **XI** — Negocio vs técnico | ✅ PASS | Las 16 decisiones de negocio están en la spec; `research.md` solo resuelve el *cómo*. Donde una decisión técnica roza el contenido (zona horaria, FR-036) queda explícita y con su alternativa rechazada. |
| **XII** — Trazabilidad | ✅ PASS | Cada decisión de `research.md` cita el FR o la D que la origina; cada test nuevo nombrará su requisito. |
| **XIII** — Español de Colombia | ✅ PASS | Spec, plan, research, data-model, contratos y quickstart en español de Colombia. Nombres de test en español. |
| **XIV** — Rama | ⚠️ **GATE PREVIO** | Antes de tocar `pos-backend` hay que crear `feat/096-transactional-email-templates` (nombre ya fijado por la spec). Hoy no existe. |
| **XV** — Commits | ✅ PASS | Solo bajo pedido explícito, en unidades pequeñas, en inglés, sin marca de autoría de IA. |

**Veredicto**: el diseño puede proceder. De las dos compuertas de ejecución que este plan abrió,
**registrar A-121 ya está hecha** (2026-10-06, T001); queda crear la rama. Las dos siguen listadas en
*Complexity Tracking* con su estado y son las primeras tareas de `tasks.md`.

### Re-evaluación posterior al diseño (Phase 1)

Revisado tras generar `research.md`, `data-model.md`, `contracts/` y `quickstart.md`:

- **Ninguna violación nueva.** El diseño no introdujo dependencias, entidades, columnas ni
  migraciones.
- **Principio V reconfirmado**: el diseño del paquete `mail_templates` no toca ningún módulo ajeno al
  correo. Los únicos archivos de producción que se modifican fuera del paquete nuevo son
  `app/core/mail.py` (transporte, para el texto plano), `app/celery_task.py` (firma del task) y los
  tres routers disparadores, cada uno por un requisito nombrado.
- **Principio VIII reconfirmado**: `data-model.md` no describe ninguna persistencia.
- **Principio IX reconfirmado**: el único `import` nuevo de terceros en todo el diseño es ninguno;
  `html`, `zoneinfo` y `dataclasses` son biblioteca estándar.
- **Principio II**: la compuerta de A-121 se cerró el 2026-10-06 al escribir la entrada en el registro
  (T001 hecha); FR-041 ya no está bloqueado.

## Project Structure

### Documentation (this feature)

```text
specs/096-correos-transaccionales/
├── spec.md                      # Entrada (ya existía)
├── plan.md                      # Este archivo
├── research.md                   # Phase 0
├── data-model.md                 # Phase 1
├── quickstart.md                 # Phase 1
├── contracts/                    # Phase 1
│   ├── servicio-de-correo.md     # Contrato de salida hacia el microservicio
│   ├── constructores-de-correo.md# Contrato Python de los tres constructores
│   └── disparadores.md           # Contrato de comportamiento de los 4 disparadores
├── checklists/                   # Ya existía
└── tasks.md                      # Phase 2 (/speckit-tasks — NO lo crea /speckit-plan)
```

### Source Code (repository root)

Todo el trabajo de código vive en `pos-backend`. `pos-heladeria` no se toca.

```text
pos-backend/
├── app/
│   ├── core/
│   │   ├── mail.py                          # MODIFICAR: create_message gana textBody;
│   │   │                                    #   se retiran los cuatro *_email_body()
│   │   ├── mail_templates/                  # NUEVO (paquete)
│   │   │   ├── __init__.py                  #   EmailContent + los tres build_*  (API pública)
│   │   │   ├── _marca.py                    #   paleta, tipografías, URL del logo, pie
│   │   │   ├── _layout.py                   #   documento, logo, tarjeta, píldora, botón, avisos
│   │   │   ├── _campos.py                   #   validación FR-041, escape FR-040, fecha FR-036
│   │   │   ├── invitacion.py                #   HTML + texto (US1, US5)
│   │   │   ├── restablecimiento.py          #   HTML + texto (US2)
│   │   │   └── contrasena_cambiada.py       #   HTML + texto (US3)
│   │   ├── timezone.py                      # SOLO LECTURA: se reusa para la zona horaria
│   │   └── reserved_hosts.py                # SOLO LECTURA: PLATFORM_HOST = "admin"
│   ├── celery_task.py                       # MODIFICAR: send_email_task gana text_body opcional
│   └── api/v1/
│       ├── invitations/router.py             # MODIFICAR: crear y reenviar usan el constructor
│       ├── auth/routes.py                    # MODIFICAR: restablecimiento y aviso de cambio;
│       │                                     #   + constructor de URL de ingreso (FR-037)
│       └── super_admin/router.py             # MODIFICAR: alta de negocio reusa invitación (FR-026)
└── app/characterization_tests/
    ├── test_invitation_email_greeting.py      # ACTUALIZAR (FR-059, A-113/D11)
    ├── test_invitations_resend_cancel.py      # ACTUALIZAR (FR-059, D11)
    ├── test_invitations_create.py             # ACTUALIZAR (FR-059: parchea invitation_email_body)
    ├── test_auth_change_password.py           # ACTUALIZAR (FR-059, A-113)
    ├── test_auth_reset_password.py            # ACTUALIZAR (FR-059, A-113) + verificar FR-060
    ├── test_auth_forgot_password.py           # VERIFICAR FR-060 (extracción del token)
    ├── test_plantillas_correo_maqueta.py      # NUEVO: FR-001..FR-013, FR-049..FR-054
    ├── test_plantillas_correo_escape.py       # NUEVO: FR-040..FR-043
    ├── test_correo_invitacion.py              # NUEVO: FR-014..FR-026
    ├── test_correo_restablecimiento.py        # NUEVO: FR-027..FR-032
    ├── test_correo_contrasena_cambiada.py     # NUEVO: FR-033..FR-039
    └── test_correo_texto_plano.py             # NUEVO: FR-044..FR-048
```

**Structure Decision**: servicio web de un solo repositorio (`pos-backend`), sin la división
backend/frontend de la plantilla porque `pos-heladeria` queda explícitamente fuera (Assumptions de la
spec). Las plantillas se agrupan en un paquete propio `app/core/mail_templates/` en vez de engordar
`app/core/mail.py` (hoy 129 líneas) por tres razones: separa el **transporte** —que no cambia (D2)— de
la **presentación** —que es todo el alcance de esta spec—; permite que la validación y el escape vivan
en un único módulo (`_campos.py`) por el que pasan obligatoriamente los seis cuerpos, que es la
respuesta estructural al hallazgo A-119; y sigue el patrón de paquete que el repositorio ya usa para
`app/core/notifications/`. El nombre de los módulos internos va en español, como el resto de los
artefactos de esta fase (Principio XIII), con `_` por delante en los que son internos al paquete.

## Complexity Tracking

> No hay violaciones de la constitución que justificar. Esta tabla registra las dos **compuertas de
> ejecución** que quedan abiertas y la restricción de alcance que el Principio V impone, para que
> `/speckit-tasks` las convierta en tareas y no se descubran a mitad de la implementación.

| Compuerta / restricción | Por qué está abierta | Qué la cierra |
|---|---|---|
| ~~**A-121 sin registrar**~~ (Principio II) — **CERRADA el 2026-10-06** | La decisión D16 —un valor obligatorio faltante hace fallar la creación de la invitación— salió de la clarificación, después de que se escribieran A-113 a A-120. Es un cambio de comportamiento observable sin entrada en el registro. | Escribir A-121 en `specs/000-reconocimiento/registro-de-anomalias.md`, a continuación de A-120, con qué cambia, por qué, quién decidió y cuándo. **Hecho**: la entrada está en la línea 3808 del registro, en estado "REGISTRADA, pendiente de implementar". FR-041 ya no está bloqueado. |
| **Rama inexistente** (Principio XIV) | `feat/096-transactional-email-templates` todavía no se creó en `pos-backend`. | `git switch -c feat/096-transactional-email-templates` en `pos-backend`, antes de la primera modificación de código. |
| **Logo sin publicar** (D12, FR-006) | El objeto `brand/logo-horizontal-claro-1200.png` no existe aún en el bucket de producción; la subida es manual y de una sola vez. | Subir `logo-horizontal-violeta-fondo-claro-1200px.png` (del sistema de diseño) a esa clave y comprobar con `curl -I` que `https://assets.skeilopos.com/brand/logo-horizontal-claro-1200.png` responde 200 con `content-type: image/png`. **Bloquea la verificación visual (US4, SC-001), no la escritura del código.** |
| **No unificar los tres constructores de URL** (Principio V) | `_build_login_url` existe duplicado en `invitations/router.py` y `super_admin/router.py`, y `_build_reset_url` en `auth/routes.py` repite el patrón. Unificarlos sería una refactorización que ninguna tarea de esta spec necesita. | Nada en esta spec. FR-037 obliga a **añadir** un constructor de URL de ingreso en `auth/routes.py`; los dos existentes quedan intactos y la unificación se trata como trabajo independiente. |
