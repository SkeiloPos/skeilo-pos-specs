# Contrato — Servicio de envío de correo (saliente)

**Spec**: [../spec.md](../spec.md) | **Requisitos**: FR-047, FR-048, FR-011 | **Decisiones**: D2, D7, D8, A-114

Este es el **único** contrato externo que esta spec toca. El consumidor es `pos-backend`; el proveedor
es un microservicio que **no vive en ninguno de los cuatro repositorios del producto** y cuyo código no
se puede inspeccionar (D2). Todo lo que sigue sobre la parte del proveedor es lo que se deduce del
código que ya le envía mensajes en producción, no documentación suya.

## Punto de entrada

```
POST {EMAIL_API_URL}/api/email/send
Content-Type: application/json
```

- `EMAIL_API_URL` viene de la configuración (`app/core/config.py:153`).
- Tiempo de espera: `10.0 s` (`app/core/mail.py:25`). **No cambia.**
- Sin cabeceras de autenticación en el código actual. **No cambia.**

> ⚠️ **A-120**: `pos-backend/.env` define `EMAIL_API_URL` dos veces y gana la última, de modo que en
> desarrollo este `POST` sale **al servicio de producción**. Cualquier prueba manual envía correo real.
> No se corrige en esta spec (D15); FR-061 acota el riesgo.

## Cuerpo de la petición

### Hoy (línea base verificada en `app/core/mail.py:12-18`)

```json
{
  "from":     "Mi app <remitente@dominio-de-pruebas-del-proveedor>",
  "to":       ["destinatario@ejemplo.com"],
  "subject":  "Bienvenido a Granizados Del Sol",
  "htmlBody": "<div style=\"font-family: Arial…\">…</div>"
}
```

### Después de esta spec

```json
{
  "from":     "SkeiloPOS <remitente@dominio-de-pruebas-del-proveedor>",
  "to":       ["destinatario@ejemplo.com"],
  "subject":  "Te invitaron a unirte a Granizados Del Sol en SkeiloPOS",
  "htmlBody": "<!DOCTYPE html><html>…</html>",
  "textBody": "Te invitaron a unirte a Granizados Del Sol.\n\n…"
}
```

| Campo | Tipo | Cambia | Qué cambia |
|---|---|---|---|
| `from` | `str` | **sí** | Solo el **nombre visible**: `MAIL_FROM_NAME` pasa de `"Mi app"` a `"SkeiloPOS"` (FR-011, A-114). **La dirección (`MAIL_FROM`) no cambia**: sigue siendo la del dominio de pruebas del proveedor hasta que exista la spec de entregabilidad (D8). El formato `"{nombre} <{dirección}>"` tampoco cambia. |
| `to` | `list[str]` | no | — |
| `subject` | `str` | **sí** | Pasa a uno de los tres literales de FR-010. Ya no se arma en los routers. |
| `htmlBody` | `str` | **sí** | Documento HTML completo en vez del fragmento `<div>` actual. |
| `textBody` | `str` | **nuevo, opcional** | Cuerpo en texto plano (FR-047). **Se omite la clave por completo** cuando no se pasa texto, de modo que el payload queda byte por byte idéntico al actual. |

### Dónde se cambia `from`

`MAIL_FROM_NAME` es una variable de entorno (`app/core/config.py:154`), no un literal del código. El
cambio de A-114 se hace **en la configuración de cada entorno**, no en `app/core/mail.py`. Eso implica:

- `pos-backend/.env` en desarrollo y el secreto correspondiente en producción;
- las fixtures de test lo fijan en `"t"` (`auth_fixtures.py:24`), así que **ningún test puede afirmar el
  literal `"SkeiloPOS"`**: lo que se afirma es que `message["from"]` compone
  `f"{settings.MAIL_FROM_NAME} <{settings.MAIL_FROM}>"`, que es el comportamiento actual y no cambia.
- FR-011 se verifica, por tanto, **en el envío real** del quickstart, mirando el remitente que muestra
  el cliente de correo — no en la suite.

## Respuesta y manejo de errores

**Sin cambios** (`app/core/mail.py:20-39`):

| Resultado del `POST` | Comportamiento actual, que se conserva |
|---|---|
| `2xx` | Devuelve el `Response`. |
| `4xx` / `5xx` | `RuntimeError("Error del servicio de email ({status}): {cuerpo}")`, con el cuerpo de la respuesta registrado en `logger.error`. |
| Sin respuesta (timeout, DNS, conexión) | `RuntimeError("No se pudo contactar el servicio de email: {exc}")`. |

**Nuevo, y solo en la frontera**: un fallo de generación de plantilla (FR-041) lanza
`ErrorDePlantillaDeCorreo` **antes** de llegar a este `POST`. No es un error de este contrato; se trata
en [disparadores.md](./disparadores.md).

## Lo que este contrato garantiza y lo que no

**Garantiza** (lado consumidor, verificable en la suite):

- La clave `textBody` se envía cuando hay texto plano y se omite cuando no (FR-047).
- Ninguna otra clave del payload cambia de nombre, tipo ni formato.
- La contraseña temporal no aparece en `subject` (FR-023) ni en ningún registro (FR-024, FR-042).
- Ningún `htmlBody` contiene imagen de seguimiento (FR-049), redirector de clics (FR-050) ni recurso
  externo distinto del logo en `assets.skeilopos.com` (FR-051).

**No garantiza** (lado proveedor, solo verificable con un envío real — FR-048, D7):

- Que el servicio **lea** `textBody` y genere una parte `text/plain` en el mensaje MIME.
- Que el servicio no añada por su cuenta seguimiento de apertura o reescritura de enlaces. FR-049 y
  FR-050 solo pueden afirmarse sobre el correo que **llega**, inspeccionando el cuerpo y los
  encabezados (SC-007).
- Que el servicio respete el `from` tal cual, o que el proveedor sobreescriba el remitente por no estar
  el dominio verificado (D8).

**Criterio de aceptación si el servicio ignora `textBody`** (FR-048): el HTML debe seguir enviándose y
mostrándose **intacto**. Ese resultado es un éxito del requisito, no un fallo: se documenta en el
quickstart y no obliga a ningún cambio de código.
