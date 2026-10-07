# Contrato — Los tres constructores de correo (interfaz interna de `pos-backend`)

**Spec**: [../spec.md](../spec.md) | **Modelo**: [../data-model.md](../data-model.md) | **Research**: [../research.md](../research.md)

Interfaz pública del paquete `app/core/mail_templates/`. Es el contrato que los disparadores consumen y
el que los tests de plantilla ejercitan sin base de datos, sin red y sin cliente HTTP: tres llamadas de
función que devuelven texto.

Los campos de entrada, su obligatoriedad y las reglas de contenido de cada correo están en
[`data-model.md`](../data-model.md) y **no se repiten aquí**. Este documento fija las firmas, lo que
levantan, lo que garantizan y lo que desaparece.

## Superficie pública

```python
# app/core/mail_templates/__init__.py

@dataclass(frozen=True)
class EmailContent:
    subject: str
    html_body: str
    text_body: str


class ErrorDePlantillaDeCorreo(ValueError):
    """Falta un valor obligatorio de la plantilla (FR-041).

    El mensaje nombra los campos faltantes y NUNCA incluye ningún valor —
    la contraseña temporal no puede llegar a un registro por esta vía (FR-042).
    """


def construir_correo_invitacion(
    *,
    nombre_negocio: str,
    url_ingreso: str,
    correo: str,
    contrasena_temporal: str,
    nombre_persona: str | None = None,
) -> EmailContent: ...


def construir_correo_restablecimiento(
    *,
    url_restablecimiento: str,
    minutos_de_vigencia: int,
) -> EmailContent: ...


def construir_correo_contrasena_cambiada(
    *,
    correo: str,
    momento: datetime,
    url_ingreso: str,
    es_super_admin: bool,
    nombre_negocio: str | None = None,
) -> EmailContent: ...
```

### Reglas de la interfaz

- **Solo argumentos por nombre** (`*`). Las tres firmas tienen varias cadenas seguidas y en la actual
  `invitation_email_body(tenant_name, login_url, email, password, name)` un intercambio de dos
  posicionales enviaría la contraseña en el campo del usuario sin que nada lo detecte. Los cuatro
  llamantes ya usan nombres hoy, así que no cuesta nada.
- **Sin estado, sin E/S, sin sesión de base de datos.** Ninguna de las tres abre conexión, lee
  `request`, ni consulta el ORM. Todo lo que necesitan llega por parámetro.
- **Deterministas.** Con la misma entrada producen la misma salida. En particular, `momento` entra como
  parámetro y nunca se llama a `utc_now()` dentro de la plantilla, para que el formato de FR-036 sea
  verificable sin congelar el reloj.
- **`settings` solo para la zona horaria.** `construir_correo_contrasena_cambiada` lee
  `settings.TENANT_TIMEZONE` (research Decisión 6). Ninguna otra lee configuración:
  `minutos_de_vigencia` entra como parámetro precisamente para que FR-030 sea responsabilidad del
  llamante, que es quien ya tiene el valor.

## Garantías de salida

Para las tres funciones, sobre el `EmailContent` devuelto:

| Garantía | Requisito |
|---|---|
| `subject` es exactamente el literal de FR-010 correspondiente | FR-010, A-113 |
| `html_body` empieza por `<!DOCTYPE html>` y es un documento completo | FR-005, research Decisión 11 |
| Todo valor dinámico aparece escapado en `html_body` y **crudo** en `text_body` | FR-040, research Decisión 3 |
| `html_body` referencia exactamente una imagen: la constante `URL_LOGO`, con `alt="SkeiloPOS"` y `width="150"` | FR-006, FR-007, FR-051 |
| `html_body` lleva el texto de vista previa oculto propio del correo, y ese texto no contiene la contraseña | FR-008, FR-009, FR-023 |
| `html_body` no contiene `<style>` con selectores, flexbox, grid ni consultas de medios estructurales | FR-005 |
| Cada elemento con fondo lleva `bgcolor` **y** `background` en línea | FR-054 |
| `text_body` escribe cada enlace completo, en una línea propia | FR-045 |
| `text_body` lleva el mismo contenido útil que el HTML: título, cuerpo, datos, avisos y pie | FR-044, FR-046 |
| Ningún cuerpo contiene `None`, `null` ni hueco de dato | FR-041 |

## Comportamiento ante entradas inválidas

| Entrada | Resultado |
|---|---|
| Un campo obligatorio `None`, `""` o solo espacios | `ErrorDePlantillaDeCorreo`, con los nombres de los campos faltantes. **No se compone ningún cuerpo parcial.** |
| `minutos_de_vigencia` menor o igual que 0 | `ErrorDePlantillaDeCorreo` |
| `es_super_admin=True` con `nombre_negocio` no vacío | `ErrorDePlantillaDeCorreo` — FR-035 prohíbe la fila de negocio en esa variante |
| `es_super_admin=False` con `nombre_negocio` ausente | `ErrorDePlantillaDeCorreo` — cae en FR-041 |
| `nombre_persona` `None`, `""` o solo espacios | **No es error.** Es el caso opcional: el párrafo abre `Hola.` (FR-015) |
| Cualquier valor con marcado, `&`, apóstrofo o acentos | **No es error.** Se escapa en HTML y se deja crudo en texto (FR-040) |
| El mensaje de la excepción | Nombres de campos únicamente. **Nunca un valor**, para que la contraseña temporal no pueda filtrarse a un registro (FR-042) |

## Lo que desaparece de `app/core/mail.py`

| Función actual | Destino |
|---|---|
| `invitation_email_body(tenant_name, login_url, email, password, name=None)` | **Se retira.** La sustituye `construir_correo_invitacion`. |
| `welcome_email_body(tenant_name, login_url, email, password)` | **Se retira sin sustituto propio**: el alta de negocio reusa la plantilla de invitación (FR-026, A-115). Hoy no tiene ningún test. |
| `password_reset_email_body(reset_url, expiry_minutes)` | **Se retira.** La sustituye `construir_correo_restablecimiento`. |
| `password_changed_email_body(when, email)` | **Se retira.** La sustituye `construir_correo_contrasena_cambiada`, con firma distinta porque necesita negocio y rol (research Decisión 8). |
| `create_message`, `send_email`, `EMAIL_SEND_PATH` | **Se quedan.** `create_message` gana `text_body` opcional — ver [servicio-de-correo.md](./servicio-de-correo.md). |

### Impacto en los puntos de parcheo de los tests

Esto es la parte del contrato que más fácilmente se rompe en silencio, así que queda explícita:

| Test | Qué parchea o afirma hoy | Qué hay que hacer |
|---|---|---|
| `test_invitations_create.py:211-219` | `patch("…invitations.router.invitation_email_body", return_value="<p>cuerpo</p>")` y afirma `kwargs["name"]` | Reapuntar al constructor nuevo, con `return_value` de tipo `EmailContent`. Conservar intacto lo que afirma: que el nombre llega a la plantilla. Citar FR-059 + A-113. |
| `test_invitation_email_greeting.py` | Llama `invitation_email_body(**_KW, name=…)` y afirma `"Hola, María Pérez:"` / `"Hola, O&#x27;Brien:"` / `"Hola:"` | Reapuntar al constructor y actualizar los literales a la forma de D11: `"Hola, María Pérez."`, `"Hola."`. Añadir la afirmación de que en `text_body` el apóstrofo va crudo. Citar FR-059 + D11. |
| `test_invitations_resend_cancel.py:126,136-137` | Afirma `"Hola, María Pérez:"` y `"Hola:"` en el cuerpo del reenvío | Mismo cambio de literales. Citar FR-059 + D11. |
| `test_auth_change_password.py:107` | Afirma `subject == "Tu contraseña fue cambiada"` | Pasa a `"Tu contraseña de SkeiloPOS fue cambiada"`. Citar FR-059 + A-113. |
| `test_auth_reset_password.py:174-175` | Afirma `subjects == ["Restablecer tu contraseña", "Tu contraseña fue cambiada"]` | Pasa a los dos literales nuevos de FR-010. Citar FR-059 + A-113. |
| `test_auth_reset_password.py:165` y `test_auth_forgot_password.py:45` | `re.search(r"token=([^\"&]+)", body)` | **No se cambia.** Tiene que seguir funcionando tal cual (FR-060). Requiere que el primer `token=` del HTML esté dentro de un `href="…"` — ver la nota de FR-060 en `data-model.md`. Añadir un test que fije ese orden. |

**Ninguno de estos archivos lleva el prefijo `"CONGELA comportamiento actual:"`** (verificado), así que
el gate estricto del Principio III no aplica. Sí aplica FR-059: cada actualización cita, en el mismo
commit, la decisión que la autoriza.
