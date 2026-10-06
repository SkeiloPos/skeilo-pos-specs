# Contrato — Comportamiento de los cuatro disparadores

**Spec**: [../spec.md](../spec.md) | **Requisitos**: FR-055 a FR-061 | **Decisiones**: D16, A-121

Los cuatro puntos desde los que salen estos correos ya funcionan y **conservan su comportamiento
observable** (FR-057). Este contrato fija exactamente qué sigue igual y qué cambia en cada uno, porque
es donde una implementación descuidada introduciría la regresión que SC-010 prohíbe.

## Tabla maestra

| Disparador | Archivo | Envío | Si el correo no sale, hoy | Si el correo no sale, después |
|---|---|---|---|---|
| Crear invitación | `app/api/v1/invitations/router.py:132-152` | **Síncrono** | `db.rollback()` + `502`; la invitación **no queda creada** | **Igual**, y FR-041 entra por ese mismo camino (A-121) |
| Reenviar invitación | `app/api/v1/invitations/router.py:205-228` | **Síncrono** | `502`; la contraseña anterior sigue intacta y sirviendo | **Igual** |
| Solicitar restablecimiento | `app/api/v1/auth/routes.py:288-297` | Celery | `logger.warning`; la respuesta genérica sale igual | **Igual** |
| Aviso de contraseña cambiada | `app/api/v1/auth/routes.py:45-59` | Celery | `logger.warning`; la respuesta `200` sale igual | **Igual** |
| Alta de negocio | `app/api/v1/super_admin/router.py:144-160` | Celery | `logger.warning` + Sentry; el tenant ya está creado y commiteado | **Igual** |

## 1. Crear invitación — `POST /invitations`

**Cambia**: el asunto deja de armarse como `f"Bienvenido a {tenant.name}"` en el router y pasa a venir
del constructor (FR-010, A-113); el cuerpo pasa a la plantilla nueva; se añade el texto plano.

**Cambia el comportamiento observable, autorizado por A-121** (la única excepción de toda la spec):

```
Hoy:     un valor obligatorio vacío → se interpola → el correo sale con "None" → la invitación QUEDA creada.
Después: un valor obligatorio vacío → ErrorDePlantillaDeCorreo → 502 + rollback → la invitación NO queda creada.
```

**Implementación**: añadir `ErrorDePlantillaDeCorreo` al `except RuntimeError` que ya existe, de modo
que los dos fallos produzcan el mismo `502` con el mismo `detail`. **No se crea un camino de error
nuevo** (FR-057 lo prohíbe explícitamente).

**Verificado**: ese `except` (`router.py:147-152`) **no registra nada hoy** y el módulo no tiene
`logger`. FR-041 exige registrar el error con contexto, así que el módulo gana `logging` y un
`logger.warning` dentro del `except`, con los nombres de los campos faltantes y ningún valor
(FR-042). Es lo único que se añade: el `502`, el `detail` y el `rollback` no cambian.

**No cambia**: el `409` del duplicado, el `404` del rol inexistente, el `403` de no-admin, el
`db.flush()` antes del envío, el `502` del fallo del servicio, ni el orden de las operaciones.

> ✅ **Compuerta cerrada**: A-121 quedó registrada en `registro-de-anomalias.md` el 2026-10-06
> (línea 3808, estado "REGISTRADA, pendiente de implementar"). El Principio II ya no bloquea esta
> parte del disparador.

## 2. Reenviar invitación — `POST /invitations/{id}/resend`

**Cambia**: asunto, cuerpo y texto plano. El correo del reenvío es **idéntico en presentación y asunto**
al de la invitación original, con la contraseña temporal nueva (FR-025).

**No cambia**: el correo se despacha **antes** de sobrescribir `password_hash` y `sent_at`
(`router.py:205`). Esa ordenación es deliberada —si el envío falla, la contraseña anterior sigue
sirviendo— y hay que conservarla. Un fallo de FR-041 aquí tampoco deja nada que revertir, por la misma
razón.

## 3. Solicitar restablecimiento — `POST /auth/forgot-password`

**Cambia**: asunto, cuerpo y texto plano. El cuerpo añade el enlace en texto visible (FR-031, A-116).

**No cambia, y es lo más delicado de toda la spec**:

- **La respuesta genérica es idéntica exista o no la cuenta, y no se envía correo cuando no existe**
  (FR-055). El `return` temprano de `routes.py:258-259` no se toca.
- El límite de solicitudes, el vencimiento de 30 minutos y el uso único del enlace (FR-056).
- La invalidación de cualquier enlace vigente anterior antes de emitir uno nuevo.
- **La extracción del token desde el cuerpo** que hacen `test_auth_forgot_password.py:45` y
  `test_auth_reset_password.py:165` con `re.search(r"token=([^\"&]+)", …)` tiene que seguir funcionando
  sin modificar el regex (FR-060). Requisito de la maqueta: **el primer `token=` del HTML debe estar
  dentro de un `href="…"`**, lo que obliga a que el botón vaya antes del enlace visible de FR-031.
- `minutos_de_vigencia` sigue saliendo de `settings.PASSWORD_RESET_TOKEN_EXPIRY_MINUTES` y pasándose al
  constructor (FR-030): el correo no puede anunciar un plazo distinto del que el sistema aplica.

## 4. Aviso de contraseña cambiada — tras `POST /auth/reset-password` y `POST /auth/change-password`

**Cambia la firma interna** (research Decisión 8):

```python
_dispatch_password_changed_email(email, when)    # hoy
_dispatch_password_changed_email(user, when)     # después
```

Los dos llamantes (`routes.py:340` y `:373`) ya tienen el `User` cargado, así que **no se añade ninguna
consulta**. De `user` se derivan:

| Dato | Expresión | Requisito |
|---|---|---|
| Correo | `user.email` | — |
| Nombre comercial | `user.tenant_name` | FR-034, A-117 |
| ¿Super Admin? | `user.tenant_id is None` — mismo criterio que `routes.py:200` | FR-035 |
| Destino del botón | subdominio del negocio, o `admin` (`PLATFORM_HOST`) si es Super Admin | FR-037 |

**Cambia el contenido**: etiqueta, título, fila de negocio nueva (FR-034, A-117), hora de Colombia en
vez de UTC (FR-036, A-118), variante de Super Admin (FR-035, FR-038, D6), botón de ingreso (FR-037).

**No cambia**:

- El disparo ocurre en **todo** cambio exitoso, incluido el primero obligatorio. Suprimirlo está
  explícitamente fuera de alcance (escenario 13 del pedido).
- El cierre de sesiones (`tokens_valid_after`) y el consumo del token (FR-056).
- **Un fallo del envío no rompe la respuesta** (FR-057): el `try/except Exception` con `warning` que ya
  envuelve el `.delay()` se conserva. Como el constructor se evalúa **dentro** de ese `try`, un fallo de
  FR-041 queda registrado sin romper el `200`. **No hay que escribir nada: basta con no mover la llamada
  fuera del `try`.**

## 5. Alta de negocio — `POST /super-admin/tenants`

**Cambia**: `welcome_email_body` desaparece y el correo pasa a usar `construir_correo_invitacion`
(FR-026, A-115), con los mismos campos y el mismo asunto que una invitación normal (US5).

**No cambia**: el `login_url` que el router ya arma localmente (`router.py:141-143`) es correcto y se
reusa tal cual; el tenant ya está creado y commiteado antes del envío; un fallo del encolado sigue
produciendo `warning` + Sentry sin romper la respuesta.

**Observación sobre la cobertura**: `welcome_email_body` **no tiene ningún test hoy** (verificado). Al
retirarla no se rompe nada, pero US5 queda sin cobertura si no se añade un test propio de que este
disparador produce el mismo `EmailContent` que una invitación.

## Regla transversal de FR-041 según el modo de envío

| Modo | Dónde se evalúa el constructor | Qué pasa si lanza |
|---|---|---|
| **Síncrono** (invitación, reenvío) | Dentro del `try` que ya captura `RuntimeError` | Hay que **añadir** `ErrorDePlantillaDeCorreo` a ese `except` → `502` + rollback (A-121) |
| **Celery** (restablecimiento, aviso, alta) | Como argumento, **dentro** del `try` que ya captura `Exception` | Ya queda cubierto: `warning` y la respuesta no se rompe. **No tocar nada**; solo no mover la llamada fuera del `try` |

## Salvaguarda de las pruebas manuales (FR-061, D15)

Como el entorno de desarrollo envía por el servicio de producción (A-120), toda verificación manual de
esta spec:

- se dirige **únicamente** a casillas del propio equipo;
- marca de forma reconocible como datos de prueba todo negocio, usuario e invitación que cree
  (convención sugerida: prefijo `[096-test]` en el nombre, como ya se hizo con `[090-test]`);
- **nunca** provoca un envío a la dirección de un cliente real.
