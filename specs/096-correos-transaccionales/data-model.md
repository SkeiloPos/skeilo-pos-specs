# Phase 1 — Modelo de datos: spec 096

**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Research**: [research.md](./research.md)

## Declaración previa: esta spec no toca la base de datos

**Cero entidades persistidas nuevas. Cero columnas nuevas. Cero migraciones de Alembic. Cero
migraciones de datos.**

El Principio VIII de la constitución exige, para toda modificación del modelo de datos, declarar
entidades nuevas, campos nuevos, cambios de relaciones, valores por defecto, compatibilidad con datos
existentes, estrategia de migración y estrategia de rollback. Aquí no hay ninguna de esas cosas, y
conviene dejarlo escrito para que nadie busque la migración que falta:

- La invitación sigue guardándose en `UserInvitation` tal cual, con las mismas columnas. Lo único que
  cambia en ese flujo es **cuándo** la fila no se crea (FR-041/A-121), no qué columnas tiene.
- El token de restablecimiento sigue en `PasswordResetToken` sin cambios (FR-056).
- `User` y `Tenant` se **leen** para obtener el nombre comercial y la condición de Super Admin
  (`User.tenant_name`, `User.tenant_id`), propiedades y columnas que ya existen. No se escriben.
- **Rollback**: revertir esta spec es revertir el código. No hay estado persistido que deshacer.

Lo que este documento describe son **objetos de valor en memoria**: estructuras que viven el tiempo de
una petición, se convierten en dos cadenas de texto y se descartan.

---

## Entidad 1 — `EmailContent`

El resultado de construir un correo. `dataclass` congelado, sin comportamiento.

| Campo | Tipo | Obligatorio | Regla |
|---|---|---|---|
| `subject` | `str` | sí | Uno de los tres literales de FR-010. Nunca contiene la contraseña temporal (FR-023). |
| `html_body` | `str` | sí | Documento HTML completo. Todos los valores dinámicos escapados (FR-040). |
| `text_body` | `str` | sí | Texto plano con el mismo contenido útil (FR-044). Valores dinámicos **sin** escapar (research Decisión 3). |

**Invariantes que los tests deben afirmar sobre cualquier `EmailContent`**:

1. `subject` es exactamente uno de los tres literales de FR-010, con `{negocio}` resuelto por el nombre
   comercial en el caso de la invitación.
2. La contraseña temporal no aparece en `subject` ni en el texto de vista previa del `html_body`
   (FR-023).
3. Ni `html_body` ni `text_body` contienen `None`, `null`, `nan` ni cadenas vacías entre etiquetas de
   dato (FR-041).
4. `html_body` no referencia ningún recurso externo distinto de `URL_LOGO` (FR-051) y no contiene
   ninguna imagen de seguimiento (FR-049).
5. Todo enlace de `html_body` apunta a su destino final, sin redirección ni parámetros añadidos
   (FR-050).
6. Cada enlace de `text_body` está escrito completo y en una línea propia (FR-045).

**Estados y transiciones**: ninguno. Es inmutable y de un solo uso.

---

## Entidad 2 — Datos del correo de invitación

Entrada de `construir_correo_invitacion(...)`. Sirve a la invitación, al reenvío y al alta de un
negocio nuevo (FR-026, D9).

| Campo | Tipo | Obligatorio | Validación (FR-041) | Origen |
|---|---|---|---|---|
| `nombre_negocio` | `str` | **sí** | No vacío ni solo espacios | `Tenant.name` / `body.tenant_name`. **Nombre comercial, nunca el identificador del subdominio** (FR-014) |
| `url_ingreso` | `str` | **sí** | No vacío ni solo espacios | `_build_login_url(tenant)`. HTTPS y subdominio propio en producción (FR-019) |
| `correo` | `str` | **sí** | No vacío ni solo espacios | `UserInvitation.email` / `body.email` |
| `contrasena_temporal` | `str` | **sí** | No vacío ni solo espacios. **Jamás aparece en un mensaje de error ni en un registro** (FR-024, FR-042) | `generate_random_password()` |
| `nombre_persona` | `str \| None` | no | Si es `None`, vacío o solo espacios, se trata como ausente | `UserInvitation.name` / `body.name` |

**Reglas de contenido derivadas**:

- **Saludo (FR-015, D11)**: con nombre, el párrafo abre `Hola, {nombre_persona}.`; sin nombre, abre
  `Hola.` — sin coma suelta, sin doble espacio, sin `null`, sin `None` y **nunca con `correo` en lugar
  del nombre** (FR-058, regla heredada de la spec 091).
- **Etiqueta superior (FR-014)**: `INVITACIÓN · {NOMBRE_NEGOCIO}` en mayúsculas. Un nombre largo rompe
  en dos líneas dentro de la tarjeta y **no se trunca** (FR-012).
- **Tarjeta de datos (FR-016)**: tres filas en este orden fijo — `URL DE INICIO DE SESIÓN`, `USUARIO`,
  `CONTRASEÑA TEMPORAL`.
- **Caja de la contraseña (FR-017)**: borde discontinuo de acento, monoespaciada 18/24 px, separación
  de letras 0.06em.
- **Enlace visible (FR-018)**: el texto del enlace de la tarjeta coincide **carácter por carácter** con
  su `href`.
- **Botón (FR-020)**: `Iniciar sesión`, al mismo destino que `url_ingreso`.
- **Aviso de atención (FR-021)**: `Antes de continuar.` en negrita + la frase del cambio obligatorio.
- **Prohibido (FR-022, D10)**: ninguna mención de plazo de vencimiento de la contraseña temporal.
- **Pie (FR-013)**: el del diseño, con `skeilo.tech@gmail.com` y la mención del negocio en cuyo nombre
  se envía. Es el único de los tres correos que nombra el negocio en el pie.

---

## Entidad 3 — Datos del correo de restablecimiento

Entrada de `construir_correo_restablecimiento(...)`.

| Campo | Tipo | Obligatorio | Validación (FR-041) | Origen |
|---|---|---|---|---|
| `url_restablecimiento` | `str` | **sí** | No vacío ni solo espacios | `_build_reset_url(tenant, raw_token)` — enlace de un solo uso, sin cambios (FR-056) |
| `minutos_de_vigencia` | `int` | **sí** | Mayor que 0 | `settings.PASSWORD_RESET_TOKEN_EXPIRY_MINUTES` (FR-030): la vigencia anunciada sale de la configuración vigente, nunca de un literal |

**Reglas de contenido derivadas**:

- **Etiqueta (FR-027)**: `SEGURIDAD DE LA CUENTA`; título `Restablece tu contraseña.`
- **Botón (FR-028)**: `Restablecer contraseña`, apuntando a `url_restablecimiento`.
- **Aviso informativo (FR-029)**: `Válido por {minutos_de_vigencia} minutos.` en negrita + `El enlace
  solo puede usarse una vez.`
- **Enlace en texto visible (FR-031, A-116)**: además del botón, el enlace completo, seleccionable.
  Elemento que el diseño no contempla y que A-116 autoriza. **Debe aparecer después del `href` del
  botón en el marcado**, por FR-060 (ver nota más abajo).
- **Cierre (FR-032)**: la frase de que, si no lo solicitó, su contraseña actual sigue funcionando.
- **Aislamiento (FR-043)**: el correo no nombra ningún negocio ni enlaza a ningún subdominio distinto
  del propio. Este correo **no lleva nombre de negocio en absoluto**, ni en el cuerpo ni en el pie.

> **Nota de no regresión (FR-060)**: `test_auth_forgot_password.py:45` y
> `test_auth_reset_password.py:165` extraen el token del cuerpo con `re.search(r"token=([^\"&]+)", …)`.
> `re.search` devuelve la **primera** coincidencia, y `[^\"&]+` se detiene en la comilla de cierre del
> atributo. La extracción sigue funcionando siempre que el primer `token=` del HTML esté dentro de un
> `href="…"`. En la maqueta nueva el botón va antes del enlace visible, así que se cumple — pero es una
> dependencia frágil del orden del marcado y tiene que quedar cubierta por un test propio, no por
> suerte.

---

## Entidad 4 — Datos del correo de contraseña cambiada

Entrada de `construir_correo_contrasena_cambiada(...)`. Es la única de las tres con **dos variantes**.

| Campo | Tipo | Obligatorio | Validación (FR-041) | Origen |
|---|---|---|---|---|
| `correo` | `str` | **sí** | No vacío ni solo espacios | `User.email` |
| `momento` | `datetime` | **sí** | No `None`. **Se interpreta siempre como UTC**: si llega *naive* (el caso real), el constructor le fija `timezone.utc` **antes** de convertir; nunca se usa `astimezone()` sobre el valor naive tal cual | El `now` UTC que el endpoint ya calcula (`utc_now().replace(tzinfo=None)`, `auth/routes.py:333` y `:363`) |
| `url_ingreso` | `str` | **sí** | No vacío ni solo espacios | Subdominio del negocio, o `admin` (`PLATFORM_HOST`) si es Super Admin (FR-037) |
| `nombre_negocio` | `str \| None` | **solo en la variante de tenant** | En la variante de tenant, no vacío ni solo espacios. En la de Super Admin **debe ser `None`** | `User.tenant_name` |
| `es_super_admin` | `bool` | **sí** | — | `User.tenant_id is None` (mismo criterio que `auth/routes.py:200`) |

### Las dos variantes

| Aspecto | Usuario de tenant | Super Admin |
|---|---|---|
| Filas de la tarjeta | `CUENTA`, `NEGOCIO`, `FECHA Y HORA` (FR-034, A-117) | `CUENTA`, `FECHA Y HORA` — la fila de negocio **se omite por completo**, sin espacio vacío ni relleno (FR-035) |
| Aviso de atención | «Contacta de inmediato a un administrador de tu negocio» | «Escribe a `skeilo.tech@gmail.com`» (FR-038) |
| Destino del botón | `https://{host_del_negocio}.skeilopos.com/login` | `https://admin.skeilopos.com/login` (FR-037) |
| Pie | No menciona negocio | No menciona negocio (FR-013: solo la invitación lo hace) |
| Tarjeta, colores, posición del aviso | Idénticos entre las dos variantes (FR-038) | Idénticos |

**Consistencia obligatoria**: `es_super_admin == True` ⟺ `nombre_negocio is None`. Las dos
combinaciones cruzadas son un error de programación, no un dato de entrada válido, y la validación debe
rechazarlas: un Super Admin con nombre de negocio mostraría una fila que FR-035 prohíbe, y un usuario de
tenant sin nombre de negocio caería en FR-041.

**Reglas de contenido derivadas**:

- **Etiqueta (FR-033)**: `CONTRASEÑA ACTUALIZADA`; título `Tu contraseña fue cambiada.`
- **Fecha y hora (FR-036, A-118)**: `momento`, interpretado como UTC
  (`momento.replace(tzinfo=timezone.utc)` cuando es naive), convertido a la zona de la instancia
  (`settings.TENANT_TIMEZONE`, `America/Bogota`) y formateado
  `dd/mm/aaaa · hh:mm a. m./p. m. (hora de Colombia)`, con hora de 12 y cero inicial. Ejemplo
  normativo: un cambio a las `2026-10-02T21:06Z` se muestra `02/10/2026 · 04:06 p. m. (hora de
  Colombia)`.
  **Trampa a evitar**: los dos llamantes pasan un `datetime` *naive*, y
  `naive.astimezone(ZoneInfo(...))` lo interpreta como hora **local del host**, no como UTC. En un
  contenedor con `TZ=UTC` el resultado coincide por casualidad; con cualquier otro `TZ` el correo
  muestra una hora equivocada sin que nada falle. Fijar la zona de origen es obligatorio, no
  defensivo.
- **Prohibido (FR-039)**: ni la contraseña nueva ni la anterior, ni ningún fragmento de ellas. La
  entidad **no recibe ninguna contraseña como campo**, que es la forma estructural de garantizarlo.

---

## Entidad 5 — Recurso de marca

No es un objeto de código: es un archivo publicado una sola vez, a mano, antes de implementar (D12).

| Propiedad | Valor |
|---|---|
| Archivo de origen | `logo-horizontal-violeta-fondo-claro-1200px.png` del sistema de diseño (verificado en `SkeiloPOS App diseñada/_ds/skeilopos-design-system-*/assets/`) |
| Clave de destino | **Real (2026-10-06)**: `skeiloPosResourses/logo-horizontal-violeta-fondo-claro-1200px.png`, en el bucket `resources` de **producción** — distinta de la clave `brand/logo-horizontal-claro-1200.png` que esta fase había anticipado; la subida manual (T003) conservó el nombre de archivo original y el prefijo con el que el usuario ya organiza ese bucket |
| URL pública | `https://assets.skeilopos.com/skeiloPosResourses/logo-horizontal-violeta-fondo-claro-1200px.png` — verificada con `curl -sI` (200, `image/png`) |
| Alcance | **La misma URL en todos los entornos** (FR-006). En el código es una constante, no un ajuste (research Decisión 4) |
| Ancho de presentación | 150 px (FR-006) |
| Texto alternativo | `SkeiloPOS` (FR-007) |
| Modelo de claves | **Fuera** del modelo por tenant de las specs 080 y 088: es un recurso de marca, no un dato de un negocio (D12) |

---

## Tabla compartida de constantes de marca

Valores del diseño que las tres plantillas comparten (FR-002, FR-003). Viven en `_marca.py` y los tests
de maqueta los afirman uno a uno.

| Concepto | Valor |
|---|---|
| Fondo de página | `#EEF1F6` |
| Fondo de tarjeta / borde / radio | `#FFFFFF` / `1px #E2E8F0` / `16px` |
| Barra de acento | `4px #7C3AED` |
| Píldora: fondo / texto | `#EDE9FE` / `#5B21B6`, radio `999px`, 12px negrita mayúsculas, `letter-spacing:0.08em` |
| Título | 28/34 px negrita `#090D16`, `letter-spacing:-0.02em` |
| Párrafo | 16/24 px `#475569` |
| Tarjeta de datos | `#F8FAFC`, borde `1px #E2E8F0`, radio `12px` |
| Etiqueta de dato | 11/16 px negrita `#64748B` mayúsculas, `letter-spacing:0.08em` |
| Valor de dato | 15/22 px `#090D16` |
| Botón | `#7C3AED`, radio `8px`, blanco 16/20 px negrita, relleno `14px 28px` |
| Aviso de atención | `#FFF1F2`, borde `#FECDD3`, texto `#9F1239`, radio `12px` |
| Aviso informativo | `#F8FAFC`, borde `#E2E8F0`, texto `#475569`, radio `12px` |
| Enlaces | `#6D28D9` |
| Pie | 13/20 px `#64748B`, centrado |
| Tipografía de títulos | `Sora, Arial, Helvetica, sans-serif` (FR-003) |
| Tipografía del resto | `Figtree, Arial, Helvetica, sans-serif` (FR-003) |
| Tipografía de la contraseña | `'Courier New', Courier, monospace` |
| Ancho / relleno del contenido | 600 px centrado, 40 px arriba y abajo, 16 px a los lados |
| Contacto del pie | `skeilo.tech@gmail.com` (FR-013, FR-038) |
| Nombre visible del remitente | `SkeiloPOS` (FR-011, A-114) |

---

## Resumen de validación (FR-041)

Un único mecanismo, aplicado a las tres plantillas antes de generar cualquier cuerpo:

1. Se reúnen los campos obligatorios de la plantilla concreta.
2. Un campo falla si es `None`, cadena vacía o solo espacios (y, para `minutos_de_vigencia`, si no es
   mayor que 0).
3. Si al menos uno falla, se lanza `ErrorDePlantillaDeCorreo` con **los nombres de los campos
   faltantes y ningún valor** (FR-042).
4. Nunca se genera un cuerpo parcial: la excepción se lanza antes de componer la primera cadena.
5. El fallo desembocan en los caminos de error que ya existen: `502` con rollback en la invitación,
   `warning` sin romper la respuesta en los otros tres (FR-057, research Decisión 10).
