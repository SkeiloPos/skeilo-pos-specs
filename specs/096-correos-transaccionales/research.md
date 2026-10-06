# Phase 0 — Investigación y decisiones técnicas: spec 096

**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Fecha**: 2026-10-06

La spec llegó a esta fase con sus dieciséis decisiones de negocio cerradas (D1-D16) y sin ningún
`NEEDS CLARIFICATION`. Lo que este documento resuelve es el **cómo**: once decisiones técnicas, todas
verificadas contra el código real de `pos-backend`, no contra suposiciones.

## Estado verificado del código (línea base del 2026-10-06)

Todo lo que sigue se comprobó leyendo el repositorio, no el historial de specs anteriores:

| Hecho | Dónde | Por qué importa |
|---|---|---|
| `create_message(recipients, subject, body)` arma `{from, to, subject, htmlBody}` | `app/core/mail.py:12` | Es el único punto donde se decide la forma del mensaje; FR-047 lo toca aquí. |
| `send_email` reintenta nada y convierte cualquier fallo en `RuntimeError` | `app/core/mail.py:20-39` | FR-041 debe desembocar en el mismo camino de error que ya existe, no en uno nuevo. |
| `invitation_email_body` escapa solo `name`, con `html.escape(..., quote=True)` | `app/core/mail.py:74` | Confirma A-119 textualmente: `tenant_name`, `login_url`, `email` y `password` se interpolan crudos. |
| La invitación envía **síncrona** y hace `db.rollback()` si el correo falla | `app/api/v1/invitations/router.py:132-152` | FR-057: ese camino es el que FR-041 debe reusar. |
| El reenvío envía **antes** de sobrescribir la contraseña | `app/api/v1/invitations/router.py:205-228` | Si FR-041 falla en el reenvío, la contraseña anterior sigue sirviendo. No hay nada que revertir. |
| `_dispatch_password_changed_email(email, when)` solo recibe correo e instante | `app/api/v1/auth/routes.py:45-59` | FR-034/FR-035/FR-037/FR-038 necesitan negocio y rol: la firma tiene que cambiar. |
| Los dos llamantes del aviso tienen el objeto `User` a mano | `app/api/v1/auth/routes.py:340` y `:373` | El dato nuevo se obtiene sin consulta adicional (Assumption de la spec confirmada). |
| El alta de negocio arma su propio `login_url` y usa `welcome_email_body` | `app/api/v1/super_admin/router.py:141-154` | FR-026 reemplaza el cuerpo; el `login_url` local ya es correcto. |
| `User.tenant_name` y `User.role_name` existen como propiedades | `app/core/models.py:168-174` | FR-034 obtiene el nombre comercial sin tocar el modelo. |
| Super Admin ⇔ `user.tenant_id is None` | `app/api/v1/auth/routes.py:200` y `:414` | Misma prueba que ya usa el login; FR-035 no inventa un criterio nuevo. |
| `PLATFORM_HOST = "admin"` | `app/core/reserved_hosts.py:9` | Destino del botón de la variante de Super Admin (FR-037). |
| `PASSWORD_RESET_TOKEN_EXPIRY_MINUTES` por defecto 30 | `app/core/config.py:84` | FR-030: la vigencia que el correo anuncia sale de aquí, ya se le pasa a la plantilla hoy. |
| `settings.TENANT_TIMEZONE` por defecto `America/Bogota`; `Tenant.timezone` también, editable a mano | `app/core/config.py:20`, `app/core/models.py:89` y `app/scripts/set_tenant_timezone.py` | Decisión 6: hay dos fuentes posibles para FR-036 y no son equivalentes en teoría. |
| `ASSETS_BASE_URL` es obligatorio y **varía por entorno** (`https://assets.example.invalid` en tests) | `app/core/config.py:176`, `app/characterization_tests/auth_fixtures.py:34` | FR-006 exige una URL igual en todos los entornos: no puede derivarse de aquí. |
| `generate_random_password` usa `letras + dígitos + "!@#$%*?"` | `app/core/utils.py:18-21` | Ningún carácter de la contraseña temporal se altera al escapar: FR-040 no cambia su apariencia. |
| `.env` define `EMAIL_API_URL` **dos veces** (líneas 13 y 33) | `pos-backend/.env` | Confirma A-120 tal como está registrada. |
| Jinja2 3.1.6 y MarkupSafe 3.0.3 están pinneados e instalados, pero **`app/` nunca los importa** | `requirements.txt:40,45` | Decisión 3: usarlos sería la primera dependencia directa, no justificada en la spec. |
| El `Dockerfile` hace `COPY . .` | `pos-backend/Dockerfile` | Cualquier archivo de plantilla viajaría a la imagen sin tocar el empaquetado. |
| Ninguno de los seis tests afectados lleva el prefijo `"CONGELA comportamiento actual:"` | búsqueda en `app/characterization_tests/` | El gate estricto del Principio III no aplica; sí aplica FR-059. |
| Suite completa: **1320 tests, OK** | `python -m unittest discover -s app/characterization_tests -p 'test_*.py'` | Línea base de SC-011. |
| No existe ningún test de `welcome_email_body` | búsqueda en `app/characterization_tests/` | Retirar esa función (FR-026/A-115) no rompe nada; hay que cubrirla de nuevo bajo la plantilla de invitación. |

---

## Decisión 1 — Un paquete `app/core/mail_templates/`, separado del transporte

**Decisión**: crear `app/core/mail_templates/` con seis módulos (`__init__.py`, `_marca.py`,
`_layout.py`, `_campos.py`, `invitacion.py`, `restablecimiento.py`, `contrasena_cambiada.py`).
`app/core/mail.py` conserva exclusivamente el transporte (`create_message`, `send_email`,
`EMAIL_SEND_PATH`) y pierde los cuatro `*_email_body()`.

**Rationale**: la spec separa con precisión lo que cambia de lo que no: la presentación cambia, el
envío no (D2). Reflejar esa frontera en el código hace que el diagnóstico de cualquier fallo futuro
sea inmediato —un correo feo es `mail_templates`, un correo que no sale es `mail`—. Además, tres
plantillas con maqueta de tablas completa en HTML y texto suman del orden de 450-500 líneas: dentro de
un `mail.py` de 129 líneas convertirían el módulo de transporte en un módulo de maquetación con un
`httpx.post` escondido al principio. El repositorio ya usa esta forma de paquete para
`app/core/notifications/`.

**Alternativas consideradas**:

- *Un solo módulo `app/core/mail_templates.py`*: menos archivos, pero ~500 líneas donde la validación,
  el escape, la paleta y seis cuerpos conviven sin frontera. Se descartó porque el valor principal de
  esta reorganización es que **exista un único módulo por el que todo valor dinámico pase
  obligatoriamente** (`_campos.py`), y eso se diluye si está en el mismo archivo que la maqueta.
- *Dejar todo en `app/core/mail.py`*: cero movimiento de archivos y cero riesgo de romper imports,
  pero mezcla transporte y presentación justo en la spec que los distingue, y deja el escape como una
  convención que hay que recordar en cada f-string — exactamente el mecanismo por el que ocurrió A-119.
- *Archivos `.html` / `.txt` cargados desde disco*: ver Decisión 3.

---

## Decisión 2 — Un objeto de retorno `EmailContent(subject, html_body, text_body)`

**Decisión**: cada correo se construye con una función `construir_*` que devuelve un `dataclass`
congelado `EmailContent` con tres campos: `subject`, `html_body`, `text_body`. Los disparadores hacen
una sola llamada y pasan los tres valores al transporte. Los cuatro `*_email_body()` actuales
desaparecen.

**Rationale**: tres requisitos lo piden a la vez. FR-010 fija los tres asuntos y hoy están escritos
como literales en cuatro sitios distintos (`"Bienvenido a {tenant.name}"` aparece dos veces en
`invitations/router.py` y una tercera en `super_admin/router.py`), que es precisamente por lo que hoy
difieren del asunto que la spec quiere; con el asunto dentro del constructor, cambiarlo es un cambio en
un sitio. FR-044 exige dos cuerpos equivalentes, y FR-046 que respeten las mismas reglas: si son dos
funciones independientes, nada impide que una se actualice y la otra no. Y el objeto congelado deja
explícito que la plantilla no tiene estado.

**Alternativas consideradas**:

- *Conservar `*_email_body()` devolviendo HTML y añadir `*_email_text()` en paralelo*: no rompe ningún
  punto de parcheo de los tests existentes, lo que es tentador. Se descartó porque deja el asunto
  donde está —repartido por los routers, contra FR-010— y porque dos funciones independientes por
  correo son dos oportunidades de divergencia entre HTML y texto, que es justo lo que FR-046 prohíbe.
- *Devolver una tupla `(subject, html, text)`*: misma unificación, pero en el punto de llamada
  `msg[1]` no dice nada. El `dataclass` cuesta cuatro líneas y hace legible cada disparador.
- *Devolver directamente el `dict` del mensaje listo para `httpx`*: fusionaría presentación y
  transporte, deshaciendo la Decisión 1, y dejaría los tests de plantilla acoplados a la forma del
  payload del microservicio.

**Consecuencia asumida y acotada**: `app/characterization_tests/test_invitations_create.py:211-219`
parchea `app.api.v1.invitations.router.invitation_email_body` con `return_value="<p>cuerpo</p>"` y
afirma sobre `mock_body.call_args.kwargs["name"]`. Al cambiar el nombre y el tipo de retorno, ese test
deja de funcionar. FR-059 enumera los tests a actualizar diciendo "como mínimo", así que incluirlo
está autorizado, pero **el cambio tiene que citar A-113/FR-059 en el mismo commit** y limitarse a
reapuntar el parcheo al constructor nuevo, conservando intacto lo que el test afirma (que el nombre
llega a la plantilla).

---

## Decisión 3 — Plantillas en Python, sin Jinja2; escape estructural en un único módulo

**Decisión**: las seis piezas de maqueta se construyen con f-strings en Python. El escape no se hace en
cada interpolación: `_campos.py` expone una función que recibe el diccionario de valores crudos ya
validados y devuelve un diccionario donde **todos** los valores pasaron por
`html.escape(valor, quote=True)`. El cuerpo HTML interpola exclusivamente del diccionario escapado; el
cuerpo de texto plano interpola exclusivamente del crudo. Ninguna plantilla llama a `html.escape`
directamente.

**Rationale**: A-119 no ocurrió por no saber escapar, ocurrió porque el escape era opcional en cada
punto de interpolación y cuatro de cinco se olvidaron. La corrección que sostiene FR-040 en el tiempo
tiene que cambiar eso de convención a estructura: si el HTML solo puede leer del diccionario escapado,
olvidarse es imposible. Y la separación de los dos diccionarios resuelve de paso el caso límite que la
spec nombra explícitamente: `O'Brien` debe leerse `O'Brien`. En HTML, `O&#x27;Brien` se **renderiza**
como `O'Brien`, así que escapar es correcto; en texto plano, `&#x27;` se **lee** literalmente, así que
escapar sería el defecto. Dos diccionarios, dos reglas, ninguna condicional dentro de la plantilla.

Sobre el escape en texto plano conviene ser explícito porque es contraintuitivo: no escapar ahí **no
es** un agujero de seguridad. El cuerpo de texto plano no se interpreta como marcado por ningún
cliente; `<b>x</b>` en texto plano se lee `<b>x</b>`, que es exactamente lo que FR-040 pide ("un valor
con marcado se muestre como texto").

**Alternativas consideradas**:

- *Jinja2 con `autoescape=True`*: es la opción con mejor garantía estructural —el motor escapa, no el
  programador— y permitiría tener la maqueta en archivos `.html` diffables contra el diseño aprobado,
  más un `{% if %}` limpio para FR-035. Está instalado (`requirements.txt:40`) y el `Dockerfile` hace
  `COPY . .`, así que empaquetar las plantillas no costaría nada. **Se descartó por el Principio IX**:
  `app/` no importa Jinja2 en ningún sitio hoy, de modo que usarlo lo convierte en la primera
  dependencia directa del backend, y el Principio IX exige que toda dependencia nueva se justifique en
  la spec correspondiente —problema que resuelve, alternativas, impacto en mantenimiento, seguridad y
  despliegue— y la spec 096 no la justifica. Además `autoescape` no resolvería FR-041: `StrictUndefined`
  detecta nombres ausentes, no cadenas vacías, así que la validación explícita haría falta igual.
  **Si el usuario prefiere Jinja2, es una decisión legítima pero exige enmendar la spec primero** (añadir
  la justificación de dependencia); no es algo que la implementación pueda decidir por su cuenta.
- *Escapar en cada interpolación, como hoy, pero en todas*: es el cambio mínimo y satisface FR-040 el
  día del commit. Se descartó porque reproduce exactamente la condición que produjo A-119 y la deja
  lista para repetirse en la próxima plantilla que alguien añada.
- *`MarkupSafe.escape` sin Jinja2*: mismo problema de dependencia directa, con menos beneficio que
  Jinja2 completo; `html.escape` de la biblioteca estándar hace lo mismo para este caso.

---

## Decisión 4 — La URL del logo es una constante del módulo, no un ajuste de entorno

**Decisión**: `_marca.py` define `URL_LOGO = "https://assets.skeilopos.com/brand/logo-horizontal-claro-1200.png"`
como constante literal. No se lee de `settings`, no se deriva de `ASSETS_BASE_URL`, no admite
sobreescritura por entorno.

**Rationale**: FR-006 no solo dice dónde está el logo, dice que **la URL tiene que ser la misma en
todos los entornos**, para que un correo de desarrollo muestre el mismo logo que uno de producción. Un
ajuste de entorno es, por definición, lo contrario de eso: cualquier valor es sintácticamente válido y
un error de configuración produce el defecto que esta spec existe para arreglar —un correo con el logo
roto—. La constante convierte ese error de configuración en imposible. Y encaja con lo que el logo es:
un recurso de marca, no un dato de un negocio, así que queda fuera del modelo de claves por tenant que
dejaron las specs 080 y 088 (D12 lo dice explícitamente).

**Alternativas consideradas**:

- *Derivar de `ASSETS_BASE_URL` + clave relativa*: parece lo coherente con las specs 080/088, y es la
  trampa. `ASSETS_BASE_URL` vale `https://assets.example.invalid` en las fixtures de test y apunta a
  otro valor en cada entorno: derivarla de ahí viola FR-006 directamente.
- *Un ajuste nuevo `BRAND_LOGO_URL` con ese valor por defecto*: añade una palanca de entorno que FR-006
  prohíbe accionar. Una palanca que no debe moverse no debe existir.
- *Incrustar el logo en el mensaje (base64 / CID)*: ya descartado por D12, porque los clientes
  mayoritarios bloquean ese tipo de imagen.

**Consecuencia**: los tests de maqueta afirman la URL literal. Si algún día el dominio de recursos
cambia, el cambio es de una línea y los tests lo señalan, que es el comportamiento deseado.

---

## Decisión 5 — El texto plano viaja como `textBody` y el parámetro es opcional

**Decisión**: `create_message` gana un parámetro `text_body: str | None = None` y, cuando no es `None`,
añade la clave `"textBody"` al payload. `send_email_task` gana el mismo parámetro opcional. Cuando es
`None`, el payload sale **byte por byte igual que hoy**.

**Rationale**: el microservicio es opaco (D2) y lo único que se sabe es que acepta `htmlBody` en
camelCase; `textBody` es el nombre simétrico y el candidato obvio. D7 ya decidió que se envía y se
comprueba empíricamente, porque el costo de intentarlo es nulo: si el servicio ignora la clave, el
HTML sale intacto (FR-048). Lo que sí hay que proteger es el despliegue: `send_email_task` es una tarea
de Celery y puede haber mensajes encolados con la firma antigua en el momento de desplegar. Un
parámetro opcional los deja ejecutarse sin error; un parámetro obligatorio los haría fallar todos. Y el
`None` que produce el payload idéntico al actual da una vía de reversión inmediata sin desplegar nada:
dejar de pasar el texto.

**Alternativas consideradas**:

- *Parámetro obligatorio*: más limpio de leer, pero rompe las tareas en vuelo durante el despliegue y
  no aporta nada, porque los cuatro llamantes van a pasarlo siempre.
- *Enviar siempre `textBody`, con cadena vacía cuando no hay texto*: cambia el payload de cualquier
  llamante futuro que no genere texto, y una clave vacía es más ambigua para el servicio que su
  ausencia.
- *Probar primero nombres alternativos (`text`, `plainBody`, `textPart`)*: sería adivinar sin
  información. FR-048 ya acepta que el campo se ignore, así que el camino correcto es enviar el nombre
  simétrico y comprobarlo en el envío real del quickstart. Si el correo real llega sin parte de texto,
  eso es dato nuevo y se decide entonces, no ahora.

---

## Decisión 6 — La hora sale de `settings.TENANT_TIMEZONE`, no de `Tenant.timezone`

**Decisión**: FR-036 se implementa con `ZoneInfo(settings.TENANT_TIMEZONE)` —la zona de la instancia,
`America/Bogota` por defecto— y la etiqueta literal `(hora de Colombia)`. No se usa
`resolve_timezone(tenant)`.

**Rationale**: FR-036 fija dos cosas a la vez: el valor y la etiqueta. `Tenant.timezone` existe, es
`NOT NULL` con `server_default='America/Bogota'`, y es editable a mano con
`app/scripts/set_tenant_timezone.py`. Si se usara, un negocio cuya zona alguien cambió recibiría una
hora correcta para él bajo una etiqueta que afirma algo falso —"(hora de Colombia)" junto a una hora
que no es la de Colombia—, y el propósito de este correo es que la persona reconozca si el cambio fue
suyo: una etiqueta que miente es peor que una hora ajena. La zona de la instancia y la etiqueta fija
dicen lo mismo y no pueden contradecirse.

Hay que ser honesto sobre el alcance de esta decisión: **hoy las dos opciones producen la misma
salida**, porque toda fila de `tenants` tiene `America/Bogota`. La diferencia solo aparece el día que
alguien corra ese script.

**Alternativas consideradas**:

- *`resolve_timezone(tenant)` con la etiqueta fija de FR-036*: la hora sería la local del negocio, pero
  la etiqueta podría mentir. Descartada por lo anterior.
- *`resolve_timezone(tenant)` con la etiqueta derivada de la zona*: técnicamente lo más correcto a
  futuro, pero cambia el texto que FR-036 fija literalmente, así que requiere enmendar la spec. No se
  hace por iniciativa de la implementación (Principio XI).

**Riesgo residual declarado**: si el producto vende a un negocio fuera de Colombia, FR-036 necesita su
propia decisión de negocio. Queda anotado, no resuelto aquí.

---

## Decisión 7 — El formato de 12 horas se construye a mano, sin depender del locale

**Decisión**: el formato `dd/mm/aaaa · hh:mm a. m./p. m. (hora de Colombia)` se arma sin `%p`:

- fecha y minutos con `strftime` (`%d/%m/%Y`, `%M`), que no dependen del locale;
- hora de 12 calculada como `hora % 12 or 12`, formateada con dos dígitos;
- sufijo `"a. m."` si la hora **ya convertida a la zona de Colombia** es menor que 12, `"p. m."` en
  caso contrario, con espacios normales y puntos, exactamente como lo escribe FR-036. La conversión
  parte de un `datetime` al que se le fijó `timezone.utc`, porque el que llega de los disparadores es
  naive.

**Rationale**: `%p` devuelve lo que el locale del proceso diga —`"PM"` en el locale C por defecto de un
contenedor, `"p. m."` solo bajo un locale español instalado y configurado—, de modo que el correo
mostraría un texto distinto según la imagen o el host. FR-036 fija el literal, así que no puede
delegarse a una variable de entorno del sistema operativo. Armarlo a mano son cuatro líneas y queda
idéntico en cualquier máquina.

**Alternativas consideradas**:

- *`strftime("%d/%m/%Y · %I:%M %p")`*: una línea, pero produce `"04:06 PM"` en el contenedor y
  depende del locale, que es exactamente el tipo de dependencia invisible que rompe en producción y no
  en la máquina de quien lo escribió.
- *`setlocale(LC_TIME, "es_CO.UTF-8")`*: estado global del proceso, que afectaría a cualquier otro
  formateo del backend, y además exige que ese locale esté generado en la imagen. Un cambio de alcance
  desproporcionado (Principio V) para formatear tres caracteres.
- *Añadir Babel*: dependencia nueva no justificada en la spec (Principio IX) para un literal fijo.

---

## Decisión 8 — El aviso de cambio recibe el `User`, no más parámetros sueltos

**Decisión**: `_dispatch_password_changed_email(email, when)` pasa a
`_dispatch_password_changed_email(user, when)`. De `user` se derivan dentro: el correo (`user.email`),
el nombre comercial (`user.tenant_name`), la condición de Super Admin (`user.tenant_id is None`) y el
destino del botón.

**Rationale**: FR-034, FR-035, FR-037 y FR-038 necesitan tres datos nuevos sobre el destinatario. Los
dos llamantes (`auth/routes.py:340` y `:373`) ya tienen el `User` en la mano, con `tenant` y `role`
cargados, así que pasar el objeto no cuesta ninguna consulta —la Assumption de la spec sobre "datos
obtenibles desde la cuenta" queda confirmada—. La alternativa de añadir tres parámetros más convierte
la firma en cinco posicionales y obliga a los dos llamantes a derivar lo mismo por duplicado,
incluyendo la prueba de Super Admin, que es justo el punto donde una divergencia entre los dos
llamantes produciría un correo con el consejo equivocado.

**Alternativas consideradas**:

- *`(email, when, tenant_name, es_super_admin, login_url)`*: evita que la función de correo conozca el
  ORM, pero duplica la derivación en los dos llamantes.
- *Dejar que la plantilla consulte la base de datos*: la plantilla se ejecuta dentro de la petición y
  no debe abrir sesión; además haría intestable la maqueta sin base de datos, cuando hoy los tests de
  plantilla son puras llamadas de función.

---

## Decisión 9 — La URL de ingreso del aviso de cambio se construye en `auth/routes.py`, y los dos duplicados existentes no se tocan

**Decisión**: añadir en `app/api/v1/auth/routes.py` un constructor de URL de ingreso que resuelva los
dos casos de FR-037 —subdominio del negocio para un usuario de tenant, `admin` (`PLATFORM_HOST`) para
un Super Admin— con el mismo patrón `prod → https://{host}.skeilopos.com/login` /
`resto → http://{host}.localhost:4200/login` que ya usan los otros módulos. **No se unifica** con
`_build_login_url` de `invitations/router.py:22` ni de `super_admin/router.py:141`, ni con
`_build_reset_url` de `auth/routes.py:62`.

**Rationale**: FR-037 obliga a tener este constructor en `auth/routes.py`, donde hoy no existe ninguno
para la URL de ingreso —solo el de restablecimiento—. Eso lo hace trabajo de esta spec. Unificar los
tres, en cambio, no lo necesita ningún requisito: sería una refactorización oportunista, que el
Principio V trata como trabajo independiente, y arrastraría a tres módulos y a sus tests en la misma
unidad de cambio que las plantillas, oscureciendo qué autorizó cada cosa.

**Alternativas consideradas**:

- *Un `app/core/urls.py` compartido con un único constructor*: es lo que el código pide a gritos y lo
  que habría que hacer en su propia spec. Descartado aquí por el Principio V.
- *Reusar `_build_login_url` importándolo desde `invitations/router.py`*: acopla el módulo de auth al
  de invitaciones por un detalle de formato de URL, y no cubre el caso del Super Admin, que
  `invitations` nunca necesita.

---

## Decisión 10 — FR-041 lanza una excepción propia que desembocan en los caminos de error que ya existen

**Decisión**: `_campos.py` define `ErrorDePlantillaDeCorreo(ValueError)`. La validación comprueba, para
cada campo obligatorio de cada plantilla, que el valor no sea `None` ni cadena vacía ni solo espacios;
si alguno falla, lanza la excepción con **los nombres de los campos faltantes y nada más** (FR-042:
nunca el valor, para que la contraseña temporal no pueda aparecer en el mensaje ni en los registros).

Los cuatro disparadores no estrenan vía de error:

- **Invitación (crear y reenviar)**: se añade `ErrorDePlantillaDeCorreo` al `except RuntimeError` que
  ya existe, de modo que el fallo produce el mismo `502` y el mismo `db.rollback()` que un fallo del
  servicio de correo. Eso es literalmente lo que FR-057 pide y lo que A-121 autoriza.
- **Restablecimiento, aviso de cambio y alta de negocio**: el constructor se evalúa como argumento
  **dentro** del `try` que ya envuelve el `.delay()` y que ya captura `Exception` con un `warning`
  (verificado en `auth/routes.py:289-297`, `:48-59` y `super_admin/router.py:144-160`). El fallo de
  generación queda registrado y no rompe la respuesta, que es el comportamiento que FR-057 conserva
  para esos tres. **No hay que escribir nada nuevo ahí: basta con no mover la llamada fuera del
  `try`.**

**Rationale**: FR-057 es explícito en que FR-041 "MUST tratarse como un caso más de 'el correo no
sale', sin inventar una vía de error distinta". Una excepción propia —en vez de reusar `RuntimeError`—
permite distinguir en los registros un fallo de datos de un fallo de red, que es información útil para
quien diagnostique, sin cambiar el comportamiento observable de ningún endpoint.

**Alternativas consideradas**:

- *Lanzar `RuntimeError` directamente*: no habría que tocar ningún `except`, pero haría indistinguible
  en los registros "falta el nombre del negocio" de "el microservicio no responde", que es exactamente
  el contexto que FR-041 exige registrar.
- *Devolver `None` y que cada disparador decida*: traslada la decisión a cuatro sitios y abre la puerta
  a que uno de ellos envíe el correo con huecos, que es lo que FR-041 prohíbe.
- *Validar con Pydantic*: los datos de cada correo son un puñado de cadenas; un modelo por correo
  añade ceremonia sin aportar nada que `_campos.py` no haga en diez líneas, y los mensajes de error de
  Pydantic incluyen el valor rechazado, lo que choca de frente con FR-042.

---

## Decisión 11 — Cómo se sostiene la fidelidad visual: tablas, estilos en línea y color explícito en todo

**Decisión**: las tres plantillas HTML reproducen la técnica que el propio diseño aprobado ya usa, y
que es la que FR-005 exige:

- documento completo (`<!DOCTYPE html>` + `<head>` con `charset`, `viewport`, `color-scheme` y
  `supported-color-schemes` + `<body>`), pero **sin depender de que el `<head>` sobreviva**: el
  servicio solo recibe `htmlBody` y no se sabe qué hace con él;
- tablas anidadas con `role="presentation"`, `cellpadding="0" cellspacing="0" border="0"` y
  `border-collapse`; ni flexbox, ni grid, ni `<style>` con selectores, ni consultas de medios para la
  estructura;
- **todos** los estilos en línea, y en cada elemento con fondo, tanto el atributo `bgcolor` como la
  propiedad `background` —así FR-054 se cumple por estilos en línea solos, aunque el cliente imponga
  su tema oscuro y descarte el `<head>`—;
- ancho doble, `width="600"` como atributo y `max-width:600px` en el estilo, con relleno de 40 px
  arriba y abajo y 16 px a los lados (FR-002), que es lo que da FR-053 a 360 px;
- botón como celda con fondo y un `<a style="display:block">` dentro, tal como el diseño;
- texto de vista previa en un `<div>` con `display:none;max-height:0;overflow:hidden;opacity:0` y
  tipografía de 1 px, copiado del diseño (FR-008, FR-009);
- `border-radius` se acepta que degrade a esquinas cuadradas en Outlook de escritorio: es una
  diferencia de redondeo, no de estructura ni de jerarquía, y FR-052 cubre esos clientes por
  conformidad de construcción (D14).

**Rationale**: los tres archivos del diseño ya están maquetados con esta técnica —tablas de
presentación, estilos en línea, `bgcolor` en el botón—, así que la fidelidad y la compatibilidad no
están en tensión: reproducir el diseño *es* cumplir FR-005. Lo único que el diseño no puede resolver es
lo que depende del `<head>`, porque está escrito para un visor de diseño (`<helmet>`, `support.js`) y
no para un correo; de ahí la regla de que ningún requisito dependa del `<head>`.

**Alternativas consideradas**:

- *Comentarios condicionales `<!--[if mso]>` para los bordes redondeados*: añaden marcado específico
  de un cliente que no se puede verificar en esta entrega (D14 lo declara diferido). Se descartó
  porque un apaño no verificable es peor que una degradación conocida y aceptada.
- *Consultas de medios para el ancho*: Outlook de escritorio las ignora y el diseño no las necesita
  —`width:100%;max-width:600px` ya da el comportamiento fluido—.
- *Un `<style>` en el `<head>` para la paleta*: concentraría los colores, pero Gmail recorta y
  reescribe `<style>`, y FR-054 quedaría dependiendo de que el `<head>` llegue. Los estilos en línea
  son más verbosos y más fiables.

---

## Lo que esta investigación deja explícitamente sin resolver

Tres cosas no se pueden decidir desde el código y quedan para la verificación del quickstart o para
otra spec:

1. **Si el microservicio acepta `textBody`** (FR-047, FR-048). Solo se sabe con un envío real. Si lo
   ignora, FR-048 ya acepta ese resultado y el HTML sale intacto.
2. **Cómo se ve el correo en Outlook de escritorio y Apple Mail** (FR-052). Verificación diferida
   declarada por D14; esta fase solo garantiza la técnica de construcción.
3. **El entorno de desarrollo sigue enviando por producción** (A-120, D15). No se corrige aquí; FR-061
   acota el riesgo durante las pruebas.
