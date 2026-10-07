---
description: "Lista de tareas de implementación — spec 096"
---

# Tasks: Correos transaccionales de acceso con la marca de SkeiloPOS

**Input**: documentos de diseño de `/specs/096-correos-transaccionales/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: **SÍ se incluyen.** No es una opción de esta spec: FR-059 obliga a actualizar cinco tests
existentes citando su decisión, FR-060 a conservar dos sin tocar su regex, SC-011 a terminar en verde y
el `quickstart.md` §3.4 enumera los seis archivos de test nuevos con los requisitos que cada uno cubre.

**Organization**: por historia de usuario, en orden de prioridad de la spec (US1 P1, US2 P1, US3 P2,
US4 P2, US5 P3). La *Implementation Strategy* explica por qué el plan sugiere entregar US5
inmediatamente después de US1.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: puede ir en paralelo (archivos distintos, sin dependencias pendientes)
- **[Story]**: a qué historia pertenece la tarea (US1, US2, US3, US4, US5)
- Cada descripción lleva la ruta exacta del archivo

## Path Conventions

Esta spec es **íntegramente de `pos-backend`**; `pos-heladeria` no se toca. Las rutas se escriben desde
la raíz del workspace, con `pos-backend/` o `pos-specs/` por delante, porque las tareas cruzan los dos
repositorios (el registro de anomalías vive en `pos-specs`).

- Código de producción: `pos-backend/app/`
- Tests: `pos-backend/app/characterization_tests/`
- Comando de la suite: `./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'`
  desde `pos-backend` (línea base medida el 2026-10-06: **1320 tests, OK**)

---

## Phase 1: Setup (compuertas previas)

**Purpose**: cerrar las tres compuertas de `quickstart.md` §0 y medir la línea base. Son las compuertas
que `plan.md` → *Complexity Tracking* exige convertir en las primeras tareas.

- [X] T001 Registrar A-121 en `pos-specs/specs/000-reconocimiento/registro-de-anomalias.md`, a continuación de A-120, con el formato de las entradas vecinas: qué cambia (un valor obligatorio vacío o nulo pasa a impedir la creación de la invitación), por qué (D16, FR-041, FR-057), quién decidió y cuándo. **Compuerta G1 del Principio II: CERRADA el 2026-10-06** — la entrada quedó en la línea 3808, en estado "REGISTRADA, pendiente de implementar". T020 y T023 ya están desbloqueadas.
- [X] T002 Crear la rama `feat/096-transactional-email-templates` en `pos-backend` desde `develop` (`git -C pos-backend switch -c feat/096-transactional-email-templates`). **Compuerta G2 del Principio XIV: bloquea toda modificación de código.** **Compuerta G2 CERRADA el 2026-10-06.**
- [X] T003 [P] Subir `logo-horizontal-violeta-fondo-claro-1200px.png` del sistema de diseño a la clave `brand/logo-horizontal-claro-1200.png` del bucket de **producción** y comprobar con `curl -sI https://assets.skeilopos.com/brand/logo-horizontal-claro-1200.png` que responde 200 con `content-type: image/png`. **Compuerta G3 (D12, FR-006): bloquea solo la verificación visual de US4, no el código.** **Compuerta G3 CERRADA el 2026-10-06, con una clave distinta de la prevista**: el usuario subió el archivo al bucket `resources` bajo el prefijo `skeiloPosResourses/`, conservando el nombre de archivo original del sistema de diseño, no la clave `brand/logo-horizontal-claro-1200.png` que este plan anticipaba. `URL_LOGO` en `_marca.py` se actualizó a `https://assets.skeilopos.com/skeiloPosResourses/logo-horizontal-violeta-fondo-claro-1200px.png`, verificado con `curl -sI` → `200`, `content-type: image/png`. Las tres aserciones de `test_plantillas_correo_maqueta.py` que afirman la URL literal se actualizaron igual.
- [X] T004 [P] Medir la línea base de la suite en `pos-backend` con `./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'` y anotar el recuento en este archivo (esperado: `Ran 1320 tests … OK`), que es el número contra el que SC-011 se verifica al cierre. **Medido el 2026-10-06: `Ran 1320 tests in 77.675s` … `OK`.**

**Checkpoint**: G1, G2 y G3 cerradas y línea base anotada. Sin esto, ninguna verificación posterior
significa nada.

---

## Phase 2: Foundational (prerrequisitos bloqueantes)

**Purpose**: el paquete `mail_templates` con su maqueta compartida, su validación y su escape, más el
transporte que gana el cuerpo en texto plano. Es la capa que `plan.md` llama "maqueta compartida" y de
la que dependen las cinco historias.

**⚠️ CRITICAL**: ninguna historia puede empezar hasta que esta fase esté completa.

- [X] T005 [P] Crear `pos-backend/app/core/mail_templates/_marca.py` con las constantes de marca de la tabla compartida de `data-model.md`: paleta completa de FR-002, las dos familias tipográficas con su cadena de reserva y la monoespaciada de la contraseña (FR-003), `URL_LOGO = "https://assets.skeilopos.com/brand/logo-horizontal-claro-1200.png"` como literal del módulo —nunca derivado de `ASSETS_BASE_URL` ni de `settings` (research Decisión 4)—, ancho/relleno del contenido y el contacto del pie `skeilo.tech@gmail.com`.
- [X] T006 [P] Crear `pos-backend/app/core/mail_templates/_campos.py` con `ErrorDePlantillaDeCorreo(ValueError)`, la validación de campos obligatorios (falla con `None`, cadena vacía o solo espacios; para enteros, con valor ≤ 0), la función que devuelve el diccionario escapado con `html.escape(valor, quote=True)` junto al crudo, y el formateo de FR-036 construido a mano sin `%p` ni `setlocale` (research Decisión 7), que **interpreta el `datetime` recibido como UTC** —fijándole `timezone.utc` si llega naive— antes de convertirlo a `ZoneInfo(settings.TENANT_TIMEZONE)`, nunca `astimezone()` sobre el valor naive. El mensaje de la excepción lleva **solo nombres de campos, jamás valores** (FR-042).
- [X] T007 Crear `pos-backend/app/core/mail_templates/_layout.py` con las piezas compartidas que `research.md` Decisión 11 fija: documento completo desde `<!DOCTYPE html>`, texto de vista previa oculto, logo a 150 px con `alt="SkeiloPOS"`, tarjeta con barra de acento, píldora, título, párrafo, tarjeta de datos, botón como celda con `<a style="display:block">`, aviso de atención, aviso informativo y pie. Tablas `role="presentation"` anidadas, estilos en línea, `bgcolor` **y** `background` en cada elemento con fondo, `width="600"` + `max-width:600px`; sin `<style>`, sin flexbox, sin grid y sin consultas de medios estructurales (depende de T005).
- [X] T008 Crear `pos-backend/app/core/mail_templates/__init__.py` exportando `EmailContent` como `@dataclass(frozen=True)` con `subject`, `html_body` y `text_body`, y re-exportando `ErrorDePlantillaDeCorreo`, conforme a la superficie pública de `contracts/constructores-de-correo.md` (depende de T005, T006, T007).
- [X] T009 Crear `pos-backend/app/characterization_tests/test_plantillas_correo_escape.py` con los tests de los ayudantes de `_campos.py` (FR-040, FR-041, FR-042): `<b>x</b>`, `Ñandú & Cía`, `O'Brien` y `"` quedan escapados en el diccionario de HTML y **crudos** en el de texto; cada campo obligatorio vacío, nulo o solo espacios levanta `ErrorDePlantillaDeCorreo`; el mensaje de la excepción nombra los campos y **no contiene ningún valor** (depende de T006).
- [X] T010 Modificar `pos-backend/app/core/mail.py`: `create_message(recipients, subject, body, text_body=None)` añade la clave `"textBody"` al payload solo cuando `text_body` no es `None`, de modo que sin texto el payload queda idéntico al actual (FR-047, research Decisión 5). `send_email`, `EMAIL_SEND_PATH` y el manejo de errores no cambian (`contracts/servicio-de-correo.md`).
- [X] T011 Modificar `pos-backend/app/celery_task.py`: `send_email_task(recipients, subject, body, text_body=None)` pasa el texto a `create_message`. El parámetro **debe ser opcional** para que las tareas encoladas con la firma antigua sobrevivan al despliegue (research Decisión 5) (depende de T010).
- [X] T012 Crear `pos-backend/app/characterization_tests/test_correo_texto_plano.py` con los tests del payload (FR-047): `create_message` incluye `textBody` cuando se pasa texto y **omite la clave** cuando no; `from` sigue componiendo `f"{settings.MAIL_FROM_NAME} <{settings.MAIL_FROM}>"` sin afirmar el literal `"SkeiloPOS"` (las fixtures lo fijan en `"t"`); el resto del payload idéntico al actual (depende de T010, T011).
- [X] T013 Cambiar `MAIL_FROM_NAME` de `"Mi app"` a `"SkeiloPOS"` en `pos-backend/.env` y anotar en este archivo que el secreto equivalente de producción debe cambiarse al desplegar (FR-011, A-114). **No es un cambio de código**: `app/core/mail.py` ya compone el remitente desde la configuración, y FR-011 se verifica en el envío real de T049, no en la suite. **Hecho**: `.env` de desarrollo actualizado. **Pendiente al desplegar**: cambiar el secreto `MAIL_FROM_NAME` del entorno de producción a `SkeiloPOS` — no está en el alcance de este repo ni de esta sesión.

**Checkpoint**: el paquete compila, `_campos.py` está cubierto por tests y el transporte acepta texto
plano sin alterar el payload actual. Las cinco historias pueden empezar.

---

## Phase 3: User Story 1 - Entrar al sistema con los datos que llegan por correo (Priority: P1) 🎯 MVP

**Goal**: el correo de invitación —el primer contacto de un empleado con el producto— llega con la marca
de SkeiloPOS, el nombre comercial del negocio, el saludo, la URL de ingreso, el usuario y la contraseña
temporal destacada, en HTML y en texto plano, con todos los valores escapados.

**Independent Test**: invitar a una persona desde la página de usuarios, abrir el correo recibido y
comprobar marca, etiqueta, título, saludo, las tres filas de datos, el botón y el aviso de atención;
después entrar con esos datos.

### Implementación de la historia 1

- [X] T014 [US1] Crear `pos-backend/app/core/mail_templates/invitacion.py` con el cuerpo HTML: etiqueta `INVITACIÓN · {NEGOCIO}` en mayúsculas y título `Te invitaron a unirte a {negocio}.` resueltos con el **nombre comercial**, nunca con el identificador del subdominio (FR-014); párrafo que abre `Hola, {nombre}.` con nombre y `Hola.` sin él, sin coma suelta ni doble espacio (FR-015, D11, FR-058); tarjeta de tres filas en el orden `URL DE INICIO DE SESIÓN`, `USUARIO`, `CONTRASEÑA TEMPORAL` (FR-016); caja de la contraseña con borde discontinuo, monoespaciada 18/24 px y `letter-spacing:0.06em` (FR-017); enlace cuyo texto coincide carácter por carácter con su `href` (FR-018); botón `Iniciar sesión` al mismo destino (FR-020); aviso de atención con `Antes de continuar.` en negrita (FR-021); **ninguna mención de plazo de vencimiento** (FR-022, D10); pie con el negocio (FR-013); texto de vista previa sin la contraseña (FR-023) (depende de T007, T008).
- [X] T015 [US1] Añadir en `pos-backend/app/core/mail_templates/invitacion.py` el cuerpo en texto plano con el mismo contenido útil —título, párrafo, los tres datos, aviso y pie— y cada enlace completo en línea propia (FR-044, FR-045, FR-046), interpolando del diccionario **crudo** y no del escapado (research Decisión 3).
- [X] T015a [US1] Añadir en `pos-backend/app/characterization_tests/test_correo_texto_plano.py` los tests del `text_body` de la invitación (FR-044, FR-045, FR-046): lleva título, el párrafo con el saludo, las tres filas de datos, el aviso de atención y el pie; la URL de ingreso aparece completa y **en una línea propia**; la contraseña temporal está en el cuerpo pero **no** en el texto de vista previa ni en el asunto; `<b>x</b>` y `O'Brien` van **crudos**, sin `&lt;` ni `&#x27;`.
- [X] T016 [US1] Exportar `construir_correo_invitacion` desde `pos-backend/app/core/mail_templates/__init__.py` con la firma de solo-argumentos-por-nombre de `contracts/constructores-de-correo.md` (`nombre_negocio`, `url_ingreso`, `correo`, `contrasena_temporal`, `nombre_persona=None`), devolviendo `EmailContent`.
- [X] T017 [P] [US1] Crear `pos-backend/app/characterization_tests/test_correo_invitacion.py` cubriendo FR-014 a FR-025: asunto literal `Te invitaron a unirte a {negocio} en SkeiloPOS`; etiqueta y título con nombre comercial y no con el `host`; `Hola, María Pérez.` / `Hola.`; las tres filas en orden; texto del enlace idéntico al `href`; botón al mismo destino; aviso de atención; **sin mención de vencimiento**; contraseña ausente del asunto y de la vista previa.
- [X] T018 [P] [US1] Crear `pos-backend/app/characterization_tests/test_plantillas_correo_maqueta.py` afirmando, sobre el cuerpo de invitación, cada valor de la tabla de FR-002 uno a uno, las dos familias tipográficas de FR-003, `URL_LOGO` literal con `alt="SkeiloPOS"` y `width="150"` (FR-006, FR-007), la vista previa oculta (FR-008, FR-009), el pie de FR-013, una sola imagen y ningún recurso externo ajeno al logo (FR-049, FR-051) y ningún `href` con redirección (FR-050).
- [X] T019 [US1] Extender `pos-backend/app/characterization_tests/test_plantillas_correo_escape.py` con los cuatro campos obligatorios de la invitación: cada uno vacío, nulo o solo espacios levanta `ErrorDePlantillaDeCorreo`; `nombre_persona` ausente **no** es error (FR-015); el mensaje de la excepción **no contiene la contraseña temporal** (FR-042); ni `html_body` ni `text_body` contienen `None` ni `null` (FR-041).
- [X] T020 [US1] Modificar la creación de invitación en `pos-backend/app/api/v1/invitations/router.py` (~132-152): pedirle al constructor el asunto y los dos cuerpos en una sola llamada, retirar el literal `f"Bienvenido a {tenant.name}"`, pasar `text_body` a `send_email`, y **añadir `ErrorDePlantillaDeCorreo` al `except RuntimeError` existente** para que el fallo produzca el mismo `502` y el mismo `db.rollback()` (FR-010, FR-041, FR-057, A-121, `contracts/disparadores.md` §1). Como ese `except` hoy **no registra nada** y FR-041 exige registrar el error con contexto suficiente, añadir al módulo `import logging` y `logger = logging.getLogger(__name__)` —el mismo patrón de `auth/routes.py:2,33` y `super_admin/router.py:2,26`— y un `logger.warning` dentro del `except` que nombre la invitación y **los campos faltantes, jamás sus valores** (FR-041, FR-042). No es refactorización oportunista: lo exige FR-041, que hoy no tiene dónde cumplirse. No se crea ninguna vía de error nueva ni se altera el `409`, el `404`, el `403`, el `db.flush()` ni el orden de las operaciones. **Depende de T001 (compuerta G1).**
- [X] T021 [US1] Modificar el reenvío en `pos-backend/app/api/v1/invitations/router.py` (~205-228) para usar el constructor, con la contraseña temporal nueva y presentación y asunto idénticos al original (FR-025). **Conservar que el correo se despacha antes de sobrescribir `password_hash` y `sent_at`** (`contracts/disparadores.md` §2). Registrar también aquí el fallo con el `logger` que T020 añade (FR-041), sin alterar el `502`.
- [X] T022 [US1] Actualizar `pos-backend/app/characterization_tests/test_invitations_create.py` (~211-219): reapuntar el parcheo de `invitation_email_body` al constructor nuevo con `return_value` de tipo `EmailContent`, conservando intacto lo que el test afirma (que el nombre llega a la plantilla). **Citar FR-059 y A-113 en el mismo commit.**
- [X] T023 [US1] Añadir en `pos-backend/app/characterization_tests/test_invitations_create.py` el test de que un valor obligatorio vacío levanta `ErrorDePlantillaDeCorreo` y produce `502` con rollback, de modo que la invitación **no queda creada** (FR-041, FR-057, A-121, D16). **Depende de T001 y T020.**
- [X] T024 [P] [US1] Actualizar `pos-backend/app/characterization_tests/test_invitation_email_greeting.py`: reapuntar al constructor y cambiar los literales a la forma de D11 (`"Hola, María Pérez."`, `"Hola."`), añadiendo la afirmación de que en `text_body` el apóstrofo de `O'Brien` va **crudo** y en `html_body` escapado. **Citar FR-059 y D11.**
- [X] T025 [P] [US1] Actualizar `pos-backend/app/characterization_tests/test_invitations_resend_cancel.py` (~126, 136-137) con los mismos literales nuevos del saludo. **Citar FR-059 y D11.**
- [X] T026 [US1] Retirar `invitation_email_body` de `pos-backend/app/core/mail.py` una vez que ningún llamante la use (`contracts/constructores-de-correo.md`).

**Checkpoint**: la invitación y el reenvío salen con la plantilla nueva, en HTML y texto, y la suite
pasa con los tres tests de invitación actualizados y los dos nuevos. US1 es demostrable sola.

---

## Phase 4: User Story 2 - Recuperar el acceso cuando olvidé la contraseña (Priority: P1)

**Goal**: el correo de restablecimiento llega con la marca, el botón, la vigencia real tomada de la
configuración, el aviso de un solo uso y el enlace completo en texto visible para quien no pueda usar el
botón.

**Independent Test**: pedir un enlace desde la pantalla de recuperación, abrir el correo, comprobar
etiqueta, botón, vigencia, aviso y enlace visible; después usar el enlace y fijar una contraseña nueva.

### Implementación de la historia 2

- [X] T027 [US2] Crear `pos-backend/app/core/mail_templates/restablecimiento.py` con el cuerpo HTML: etiqueta `SEGURIDAD DE LA CUENTA`, título `Restablece tu contraseña.` y párrafo del diseño (FR-027); botón `Restablecer contraseña` apuntando al enlace de un solo uso (FR-028); aviso informativo `Válido por {minutos_de_vigencia} minutos.` en negrita más `El enlace solo puede usarse una vez.`, con los minutos tomados **del parámetro y nunca de un literal** (FR-029, FR-030); enlace completo en texto visible y seleccionable (FR-031, A-116) **situado después del `href` del botón en el marcado**, porque FR-060 depende de que el primer `token=` del HTML esté dentro de un `href="…"`; texto de vista previa con los minutos **tomados del parámetro**, no el `30` literal que trae el diseño (FR-008, FR-030); frase de cierre de FR-032; sin nombre de negocio ni subdominio ajeno en ninguna parte, tampoco en el pie (FR-043) (depende de T007, T008).
- [X] T028 [US2] Añadir en `pos-backend/app/core/mail_templates/restablecimiento.py` el cuerpo en texto plano con el mismo contenido útil y el enlace completo en línea propia (FR-044, FR-045, FR-046).
- [X] T028a [US2] Añadir en `pos-backend/app/characterization_tests/test_correo_texto_plano.py` los tests del `text_body` del restablecimiento (FR-044, FR-045, FR-046): el enlace de un solo uso aparece completo en una línea propia, los minutos salen del parámetro y no del literal `30`, y están la advertencia de un solo uso y la frase de cierre de FR-032.
- [X] T029 [US2] Exportar `construir_correo_restablecimiento(*, url_restablecimiento, minutos_de_vigencia)` desde `pos-backend/app/core/mail_templates/__init__.py`, devolviendo `EmailContent` con el asunto literal `Restablece tu contraseña de SkeiloPOS` (FR-010).
- [X] T030 [P] [US2] Crear `pos-backend/app/characterization_tests/test_correo_restablecimiento.py` cubriendo FR-027 a FR-032: etiqueta, título y párrafo; botón al enlace; `Válido por {N} minutos.` con un `N` distinto de 30 para probar que sale del parámetro; **el texto de vista previa también anuncia `{N}` minutos y no `30`**, afirmado con el mismo `N` distinto de 30 (FR-008, FR-030); **el enlace visible aparece después del `href` del botón** y `re.search(r"token=([^\"&]+)", html_body)` devuelve el token del botón (FR-060); frase de cierre; ningún nombre de negocio ni subdominio ajeno (FR-043).
- [X] T031 [US2] Extender `pos-backend/app/characterization_tests/test_plantillas_correo_maqueta.py` con las mismas afirmaciones de maqueta y marca sobre el cuerpo de restablecimiento (FR-001 a FR-013, FR-049 a FR-051).
- [X] T032 [US2] Extender `pos-backend/app/characterization_tests/test_plantillas_correo_escape.py` con los campos obligatorios del restablecimiento: `url_restablecimiento` vacío, nulo o solo espacios y `minutos_de_vigencia` ≤ 0 levantan `ErrorDePlantillaDeCorreo` (FR-041).
- [X] T033 [US2] Modificar `pos-backend/app/api/v1/auth/routes.py` (~288-297) para que la solicitud de restablecimiento use el constructor y pase `text_body` al task, con `minutos_de_vigencia=settings.PASSWORD_RESET_TOKEN_EXPIRY_MINUTES` (FR-030). **Conservar intactos**: el `return` temprano de ~258-259 que no envía correo cuando la cuenta no existe y deja la respuesta genérica idéntica (FR-055), el límite de solicitudes, los 30 minutos, el uso único y la invalidación del enlace anterior (FR-056); y **evaluar el constructor dentro del `try` que ya captura `Exception`**, para que un fallo de FR-041 quede en `warning` sin romper la respuesta (FR-057, research Decisión 10).
- [X] T034 [US2] Actualizar `pos-backend/app/characterization_tests/test_auth_reset_password.py` (~174-175): los asuntos esperados pasan a `["Restablece tu contraseña de SkeiloPOS", "Tu contraseña de SkeiloPOS fue cambiada"]`. **Citar FR-059 y A-113.**
- [X] T035 [US2] Ejecutar `pos-backend/app/characterization_tests/test_auth_forgot_password.py` y la extracción del token de `test_auth_reset_password.py` (~165) **sin modificar el regex** y confirmar que pasan (FR-060). Si hay que tocar el regex, la maqueta de T027 está mal: revisar el orden del botón y del enlace visible.
- [X] T036 [US2] Retirar `password_reset_email_body` de `pos-backend/app/core/mail.py`.

**Checkpoint**: el restablecimiento sale con la plantilla nueva, la respuesta genérica y el ciclo del
token no cambiaron, y los dos tests que extraen el token siguen pasando con su regex original.

---

## Phase 5: User Story 3 - Enterarme de que mi contraseña cambió (Priority: P2)

**Goal**: el aviso de cambio dice qué cuenta, de qué negocio y **a qué hora de Colombia**, con el
consejo que corresponde al rol del destinatario y un botón al ingreso correcto; para un Super Admin
omite la fila de negocio por completo.

**Independent Test**: cambiar la contraseña desde la aplicación y desde el enlace de restablecimiento,
como usuario de tenant y como Super Admin, y comprobar en cada caso las filas, la hora, el aviso y el
destino del botón.

### Implementación de la historia 3

- [X] T037 [US3] Añadir en `pos-backend/app/api/v1/auth/routes.py` un constructor de URL de ingreso que resuelva los dos casos de FR-037 —subdominio del negocio, o `PLATFORM_HOST` (`"admin"`, de `app/core/reserved_hosts.py`) para un Super Admin— con el mismo patrón `prod → https://{host}.skeilopos.com/login` / `resto → http://{host}.localhost:4200/login` de los módulos vecinos. **No unificar** con `_build_login_url` de `invitations/router.py:22` ni de `super_admin/router.py:141`, ni con `_build_reset_url` de `auth/routes.py:62`: el Principio V trata esa unificación como trabajo independiente (research Decisión 9, `plan.md` → *Complexity Tracking*).
- [X] T038 [US3] Crear `pos-backend/app/core/mail_templates/contrasena_cambiada.py` con el cuerpo HTML y sus dos variantes: etiqueta `CONTRASEÑA ACTUALIZADA` y título `Tu contraseña fue cambiada.` (FR-033); para un usuario de tenant, tarjeta de tres filas `CUENTA`, `NEGOCIO`, `FECHA Y HORA` con el nombre comercial y la misma tipografía, color y espaciado que la fila de cuenta (FR-034, A-117); para un Super Admin, la fila de negocio **se omite por completo, sin hueco ni relleno** (FR-035); fecha y hora con el formateo de `_campos.py` sobre `ZoneInfo(settings.TENANT_TIMEZONE)` y la etiqueta literal `(hora de Colombia)` (FR-036, A-118, research Decisión 6); botón `Iniciar sesión` al destino que corresponda al rol (FR-037); aviso de atención que para un tenant dice contactar a un administrador de su negocio y para un Super Admin escribir a `skeilo.tech@gmail.com`, con tarjeta, colores y posición idénticos entre las dos variantes (FR-038); pie sin mención de negocio (FR-013); **la entidad no recibe ninguna contraseña como campo**, que es la garantía estructural de FR-039 (depende de T006, T007, T008).
- [X] T039 [US3] Añadir en `pos-backend/app/core/mail_templates/contrasena_cambiada.py` el cuerpo en texto plano, con la misma hora y el mismo aviso por rol que el HTML y el enlace completo en línea propia (FR-044, FR-045, FR-046).
- [X] T039a [US3] Añadir en `pos-backend/app/characterization_tests/test_correo_texto_plano.py` los tests del `text_body` del aviso de cambio (FR-044, FR-045, FR-046): **la misma hora de Colombia que el HTML** sobre el mismo `momento`, el aviso que corresponde al rol en cada variante, la fila de negocio ausente en la de Super Admin, y el enlace de ingreso completo en línea propia.
- [X] T040 [US3] Exportar `construir_correo_contrasena_cambiada(*, correo, momento, url_ingreso, es_super_admin, nombre_negocio=None)` desde `pos-backend/app/core/mail_templates/__init__.py`, con el asunto literal `Tu contraseña de SkeiloPOS fue cambiada` (FR-010) y `momento` como parámetro para que la función sea determinista y no llame a `utc_now()` dentro (`contracts/constructores-de-correo.md`).
- [X] T041 [P] [US3] Crear `pos-backend/app/characterization_tests/test_correo_contrasena_cambiada.py` cubriendo FR-033 a FR-039: etiqueta y título; tres filas en la variante de tenant y **dos en la de Super Admin, sin hueco ni `None`**; el ejemplo normativo `2026-10-02T21:06Z` → `02/10/2026 · 04:06 p. m. (hora de Colombia)`, más un caso de madrugada que verifique el cero inicial y `a. m.`; aviso según rol; botón al subdominio del negocio en una variante y a `admin` en la otra; ninguna contraseña en el cuerpo. **El caso del ejemplo normativo se afirma con un `datetime` naive, igual al que pasan los dos llamantes, y se repite con `TZ=America/Bogota` en el entorno del proceso** para fijar que la conversión no depende de la zona del host.
- [X] T042 [US3] Extender `pos-backend/app/characterization_tests/test_plantillas_correo_maqueta.py` con las afirmaciones de maqueta y marca sobre los dos cuerpos de contraseña cambiada (FR-001 a FR-013, FR-049 a FR-051).
- [X] T043 [US3] Extender `pos-backend/app/characterization_tests/test_plantillas_correo_escape.py` con los campos obligatorios de este correo y con **las dos combinaciones cruzadas**: `es_super_admin=True` con `nombre_negocio` no vacío, y `es_super_admin=False` sin `nombre_negocio`, que levantan `ErrorDePlantillaDeCorreo` (`data-model.md` → *Consistencia obligatoria*).
- [X] T044 [US3] Cambiar en `pos-backend/app/api/v1/auth/routes.py` la firma `_dispatch_password_changed_email(email, when)` por `_dispatch_password_changed_email(user, when)` (~45-59) y actualizar los dos llamantes (~340 y ~373), que ya tienen el `User` cargado y **no requieren ninguna consulta nueva**. Derivar dentro: `user.email`, `user.tenant_name` (FR-034), `user.tenant_id is None` como prueba de Super Admin —el mismo criterio de `routes.py:200`— y el destino del botón con el constructor de T037 (research Decisión 8). **Mantener la llamada al constructor dentro del `try/except Exception` existente** para que un fallo de FR-041 quede en `warning` sin romper el `200` (FR-057).
- [X] T045 [US3] Actualizar `pos-backend/app/characterization_tests/test_auth_change_password.py` (~107): el asunto esperado pasa a `"Tu contraseña de SkeiloPOS fue cambiada"`. **Citar FR-059 y A-113.**
- [X] T046 [US3] Retirar `password_changed_email_body` de `pos-backend/app/core/mail.py`.

**Checkpoint**: los dos flujos de cambio de contraseña avisan con la plantilla nueva, en hora de
Colombia, y la variante de Super Admin no muestra ninguna fila de negocio.

---

## Phase 6: User Story 4 - Leer los correos en mi cliente y en mi teléfono (Priority: P2)

**Goal**: los tres correos se ven completos, legibles y con la marca en los clientes reales, incluido un
ancho de 360 px, un cliente que bloquea imágenes, uno de solo texto y un tema oscuro impuesto.

**Independent Test**: enviarse los tres correos y abrirlos en Gmail web y Gmail Android, incluida una
ventana de 360 px. Outlook web, Outlook de escritorio y Apple Mail son verificación diferida declarada
(FR-052, D14).

> ⚠️ Esta fase envía correo **real** por el servicio de producción (A-120). Antes de empezar, leer la
> *Salvaguarda* de `quickstart.md` §4: destinatario únicamente una casilla del propio equipo, y todo
> negocio, usuario e invitación de prueba con el prefijo `[096-test]` en el nombre (FR-061, D15).

### Conformidad de construcción (automatizada)

- [X] T047 [US4] Completar `pos-backend/app/characterization_tests/test_plantillas_correo_maqueta.py` con las afirmaciones de conformidad de construcción sobre los **tres** cuerpos a la vez (FR-005, FR-053, FR-054): ningún `<style>` con selectores, ningún `display:flex`, `display:grid` ni consulta de medios estructural; cada elemento con fondo lleva `bgcolor` **y** `background` en línea; `width="600"` junto a `max-width:600px`; una sola etiqueta `<img>` por correo y ninguna de 1 px (FR-049); todo `href` apunta a su destino final (FR-050).

### Verificación manual con envío real (depende de T003 — compuerta G3)

- [ ] T048 [US4] **V1** — Invitar a la casilla del equipo y abrir el correo en Gmail web: el logo se ve a 150 px; después bloquear las imágenes y recargar: se lee `SkeiloPOS` como texto alternativo y el correo sigue siendo utilizable (FR-006, FR-007). Anotar el resultado en `quickstart.md` §5.
- [ ] T049 [US4] **V2** — Enviarse los tres correos y compararlos lado a lado con los tres archivos de `SkeiloPOS App diseñada/` en Gmail web y Gmail Android: logo, botón, tarjetas, colores y jerarquía como en el diseño, con la tipografía de reserva como única diferencia admitida (FR-052, SC-001, FR-004). Comprobar de paso que el remitente visible dice "SkeiloPOS" (FR-011, A-114), que la suite no puede afirmar. Anotar el resultado en `quickstart.md` §5.
- [ ] T050 [US4] **V3** — Abrir los tres correos en Gmail Android y en Gmail web con la ventana a 360 px: todo cabe, nada se corta, sin barra horizontal (FR-053, SC-002). Incluir el caso de FR-012 invitando con el negocio `[096-test] Heladería y Fuente de Soda Los Tres Hermanos de la Esquina` y comprobar que la píldora rompe en dos líneas **sin truncar** y sin desbordar la tarjeta. Anotar el resultado en `quickstart.md` §5.
- [ ] T051 [US4] **V4** — Sobre el correo recibido, *Mostrar original* en Gmail web: documentar si el mensaje es `multipart/alternative` con parte `text/plain` (el servicio lee `textBody`) o solo `text/html` (lo ignora). **Los dos resultados cumplen FR-048**, que solo exige que el HTML salga intacto; el segundo **no obliga a ningún cambio de código** (D7, SC-009). Anotar cuál de los dos salió en `quickstart.md` §5.
- [ ] T052 [US4] **V9** — Activar el tema oscuro de Gmail Android y abrir los tres correos: la jerarquía se sostiene y **ningún texto queda del mismo color que su fondo** (FR-054). No se exige que se vea igual que en tema claro, sino que siga siendo legible. Anotar el resultado en `quickstart.md` §5.
- [ ] T053 [US4] Anotar en `quickstart.md` §5 que Outlook web, Outlook de escritorio y Apple Mail quedan como **verificación diferida declarada** (D14) y **no como pendientes**: su conformidad se sostiene por la técnica de construcción que T047 verifica.

**Checkpoint**: los tres correos están verificados en los dos clientes de acceso real y la verificación
diferida queda declarada como tal, no como deuda silenciosa.

---

## Phase 7: User Story 5 - El alta de un negocio nuevo recibe el mismo correo (Priority: P3)

**Goal**: el dueño de un negocio recién creado por el Super Admin recibe exactamente el mismo correo que
cualquier persona invitada, con el mismo asunto y los mismos campos.

**Independent Test**: crear un negocio `[096-test]` con su dueño desde el panel de plataforma y
comprobar que el correo recibido es idéntico en presentación y asunto al de una invitación normal.

- [X] T054 [US5] Modificar el alta de negocio en `pos-backend/app/api/v1/super_admin/router.py` (~144-160) para que use `construir_correo_invitacion` en vez de `welcome_email_body`, con los mismos campos y el mismo asunto que una invitación (FR-026, A-115, D9), pasando `text_body` al task. **Reusar tal cual el `login_url` que el router ya arma localmente** (~141-143) y conservar que un fallo del encolado produce `warning` + Sentry sin romper la respuesta, con el constructor evaluado **dentro** de ese `try` (FR-057, `contracts/disparadores.md` §5).
- [X] T055 [US5] Añadir en `pos-backend/app/characterization_tests/test_correo_invitacion.py` el test de que el alta de negocio produce el **mismo `EmailContent`** que una invitación de tenant con los mismos datos (FR-026). Es cobertura nueva: `welcome_email_body` no tenía ningún test, así que retirarla dejaría US5 sin red si no se añade este.
- [X] T056 [US5] Retirar `welcome_email_body` de `pos-backend/app/core/mail.py` (`contracts/constructores-de-correo.md`: se retira **sin sustituto propio**).

**Checkpoint**: los cuatro disparadores usan el paquete `mail_templates` y `app/core/mail.py` ha quedado
reducido al transporte.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: las verificaciones que abarcan las cinco historias, el cierre del registro de anomalías y
la constancia de lo que queda abierto.

- [X] T057 Ejecutar la suite completa en `pos-backend` (`./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'`) y comprobar contra T004 que el recuento es **1320 + los tests nuevos**, sin ningún fallo y **sin ningún test desaparecido** (SC-011). **Medido el 2026-10-06: `Ran 1439 tests` … `OK`** (1320 + 119 nuevos; ninguna función retirada tenía test propio salvo las ya migradas a los constructores nuevos).
- [ ] T058 **V5** — Sobre un envío real: ni el asunto ni la línea de vista previa de la bandeja contienen la contraseña temporal (FR-023, SC-006); y `grep -nF "<la contraseña que llegó>" pos-backend/app.log` devuelve cero coincidencias (FR-024, FR-042).
- [ ] T059 **V6** — Sobre *Mostrar original*: una sola `<img>`, la del logo en `assets.skeilopos.com`; ninguna de 1 px; ningún `href` por un dominio de conteo de clics; cada `href` idéntico al que el backend generó (FR-049, FR-050, FR-051, SC-007). Si aparece reescritura de enlaces o un píxel, **no es defecto del código**: lo añadió el microservicio o el proveedor y es un hallazgo nuevo para registrar en `pos-specs/specs/000-reconocimiento/registro-de-anomalias.md` (D2). Anotar el resultado en `quickstart.md` §5.
- [ ] T060 **V7** — Cambiar la contraseña desde la aplicación anotando la hora local: el correo muestra `dd/mm/aaaa · hh:mm a. m./p. m. (hora de Colombia)` con hora de 12 y cero inicial, no UTC (FR-036, SC-008, A-118). Anotar el resultado en `quickstart.md` §5.
- [ ] T061 **V8** — Cambiar la contraseña de la cuenta de plataforma desde `admin.skeilopos.com`: no aparece fila de negocio **ni hueco donde estaría**; el aviso dice escribir a `skeilo.tech@gmail.com`; el botón lleva al ingreso de la plataforma; el pie no menciona negocio (FR-035, FR-037, FR-038, D6). Anotar el resultado en `quickstart.md` §5.
- [ ] T062 **V10** — Los cinco recorridos de extremo a extremo de `quickstart.md` §4: invitar y entrar con el primer cambio obligatorio; pedir enlace, usarlo y recibir el aviso; pedir enlace para un correo **que no existe** y comprobar el mismo mensaje exacto y **ningún correo enviado** (FR-055); reenviar una invitación y comprobar presentación, asunto, contraseña nueva y que la anterior ya no sirve (FR-025); crear un negocio `[096-test]` y comprobar que el correo del dueño es idéntico al de una invitación (SC-003, SC-010).
- [X] T063 Anotar en este archivo qué datos con prefijo `[096-test]` quedaron en la base de datos de desarrollo —negocios, usuarios e invitaciones— para poder limpiarlos después (FR-061, salvaguarda de `quickstart.md`). **Ninguno**: en esta sesión no se ejecutó ninguna verificación manual con envío real (T048-T053, T058-T062) — este entorno no tiene el stack de desarrollo levantado ni acceso a una casilla de Gmail del equipo. No hay nada que limpiar.
- [X] T064 Actualizar en `pos-specs/specs/000-reconocimiento/registro-de-anomalias.md` el estado de A-113 a A-118 y de A-121 a implementadas, dejar A-119 como corregida por FR-040 con esta implementación, y **dejar A-120 explícitamente abierta** como hallazgo para una spec de entorno (D15).
- [X] T065 Marcar la lista de cierre de `quickstart.md` §5 con el resultado de cada punto, incluido el resultado concreto de V4 (T051) y la constancia de la verificación diferida de D14 (T053).

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias. T001 cierra G1, T002 cierra G2, T003 cierra G3.
- **Foundational (Phase 2)**: depende de T002. **Bloquea las cinco historias.**
- **US1 (Phase 3)**: depende de Phase 2. T020 y T023 dependen además de **T001**.
- **US2 (Phase 4)**: depende de Phase 2. **No depende de US1.**
- **US3 (Phase 5)**: depende de Phase 2. **No depende de US1 ni de US2.**
- **US4 (Phase 6)**: T047 depende de que las tres plantillas existan (T014, T027, T038). Las
  verificaciones manuales T048-T052 dependen además de **T003** (logo publicado) y de que el disparador
  correspondiente esté migrado.
- **US5 (Phase 7)**: depende de US1 (reusa `construir_correo_invitacion`). Es la única historia con
  dependencia de otra, y es por diseño (D9).
- **Polish (Phase 8)**: depende de todas las historias que se quieran entregar.

### Compuertas que no son dependencias de código

- **T001 (A-121)** bloquea exclusivamente T020 y T023. Todo lo demás de US1 se puede escribir antes.
- **T003 (logo)** bloquea exclusivamente las verificaciones visuales T048-T052. El código no lo necesita.

### Dentro de cada historia

- Plantilla HTML → texto plano → export → tests de la plantilla → migración del disparador → tests del
  disparador → retirada de la función vieja de `mail.py`.
- La función de `app/core/mail.py` se retira **al final de su historia**, cuando ya no le queda ningún
  llamante.

### Parallel Opportunities

- T003 y T004 en paralelo entre sí.
- T005 y T006 en paralelo (archivos distintos, sin dependencias cruzadas).
- Una vez cerrada Phase 2, **US1, US2 y US3 son independientes** y pueden ir en paralelo con tres
  personas; US5 espera a US1.
- Dentro de cada historia, el archivo de test propio (T017, T030, T041) va en paralelo con el resto.
- T024 y T025 en paralelo (archivos de test distintos).
- `test_plantillas_correo_maqueta.py`, `test_plantillas_correo_escape.py` y
  `test_correo_texto_plano.py` los tocan las tres historias, así que **esas tareas (T018/T019/T015a,
  T031/T032/T028a, T042/T043/T039a) nunca van marcadas [P] entre historias**: son los tres puntos de
  conflicto de archivo del plan.

---

## Parallel Example: Phase 2 y arranque de las historias

```bash
# Phase 2 — las dos bases sin dependencias cruzadas:
Task: "T005 Crear app/core/mail_templates/_marca.py con las constantes de marca"
Task: "T006 Crear app/core/mail_templates/_campos.py con validación, escape y formato de fecha"

# Con Phase 2 cerrada, tres historias arrancan a la vez:
Task: "T014 [US1] Cuerpo HTML de la invitación en app/core/mail_templates/invitacion.py"
Task: "T027 [US2] Cuerpo HTML del restablecimiento en app/core/mail_templates/restablecimiento.py"
Task: "T038 [US3] Cuerpo HTML del aviso de cambio en app/core/mail_templates/contrasena_cambiada.py"
```

---

## Implementation Strategy

### MVP primero (solo US1)

1. Phase 1 completa — las tres compuertas cerradas y la línea base anotada.
2. Phase 2 completa — **crítica: bloquea todo**.
3. Phase 3 completa.
4. **PARAR Y VALIDAR**: invitar a la casilla del equipo, abrir el correo, entrar con los datos.
5. Entregable: el correo que hoy más perjudica la experiencia ya llega con marca.

### Entrega incremental

El orden por prioridad de la spec es US1 → US2 → US3 → US4 → US5. `plan.md` (Principio VI) sugiere una
variante que conviene conocer: **entregar US5 inmediatamente después de US1**, porque reusa el mismo
constructor y cuesta tres tareas (T054-T056), con lo que el correo del primer cliente que paga deja de
ser el único sin marca mucho antes. Las dos secuencias son válidas; la de la spec prioriza por impacto
de volumen, la del plan por costo marginal.

1. Phase 1 + Phase 2 → base lista.
2. US1 → validar → entregar (MVP).
3. *(opcional, recomendado por el plan)* US5 → validar → entregar.
4. US2 → validar → entregar.
5. US3 → validar → entregar.
6. US4 → las verificaciones en clientes reales, que requieren los tres correos ya migrados.
7. Phase 8 → cierre.

### Estrategia con varias personas

Con Phase 1 y Phase 2 cerradas en equipo: una persona por historia en US1, US2 y US3. US5 la toma quien
termine US1. US4 y Phase 8 son transversales y van al final, en una sola persona, porque dependen de
envíos reales que no conviene paralelizar sobre el mismo buzón.

---

## Notes

- **Las tareas [P] son archivos distintos sin dependencias pendientes.** Las tres historias comparten
  tres archivos de test (`test_plantillas_correo_maqueta.py`, `test_plantillas_correo_escape.py` y
  `test_correo_texto_plano.py`): esas tareas van en serie.
- **Cada actualización de un test existente cita su decisión en el mismo commit** (FR-059): T022 y T034
  y T045 citan A-113; T024 y T025 citan D11. No hay autorización para ninguna otra actualización de test.
- **El regex de extracción del token no se toca** (FR-060). Si deja de funcionar, el defecto está en el
  orden del marcado de T027, no en el test.
- **Ningún `except` nuevo.** FR-057 lo prohíbe: la invitación añade `ErrorDePlantillaDeCorreo` al
  `except RuntimeError` que ya existe, y los otros tres disparadores no cambian nada porque el
  constructor se evalúa dentro del `try` que ya tienen.
- **Toda prueba manual envía correo real** por el servicio de producción (A-120). Destinatario: solo
  casillas del propio equipo. Prefijo `[096-test]` en todo dato creado (FR-061).
- Commits pequeños, en inglés, solo bajo pedido explícito (Principio XV).
- Parar en cualquier checkpoint para validar la historia por separado.
