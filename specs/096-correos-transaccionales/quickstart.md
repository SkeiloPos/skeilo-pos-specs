# Quickstart — Guía de validación de la spec 096

**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Contratos**: [contracts/](./contracts/)

Esta guía no explica cómo implementar: explica **cómo comprobar que quedó bien**. Está ordenada de lo
más barato a lo más caro: primero lo que la suite verifica sola, después las ocho verificaciones que
exigen un correo real.

> ⚠️ **Antes de ejecutar cualquier verificación con envío real, lee el apartado *Salvaguarda*.** En
> desarrollo los correos salen por el servicio de **producción** (A-120): un descuido llega a un buzón
> de verdad.

---

## 0. Compuertas previas

Ninguna verificación tiene sentido mientras alguna de estas tres esté abierta.

| # | Compuerta | Cómo se cierra | Cómo se comprueba |
|---|---|---|---|
| G1 | ~~**A-121 sin registrar**~~ (Principio II, D16) — **CERRADA el 2026-10-06** | Ya escrita tras A-120, línea 3808 | `grep -n "A-121" specs/000-reconocimiento/registro-de-anomalias.md` devuelve la entrada ✅ |
| G2 | **Rama inexistente** (Principio XIV) | `git switch -c feat/096-transactional-email-templates` en `pos-backend` | `git -C ../pos-backend branch --show-current` |
| G3 | ~~**Logo sin publicar**~~ (D12, FR-006) — **CERRADA el 2026-10-06** | Subido a mano a `skeiloPosResourses/logo-horizontal-violeta-fondo-claro-1200px.png` del bucket `resources` (clave distinta de la que este documento anticipaba — ver nota abajo) | el comando de abajo |

```bash
# G3 — debe responder 200 y content-type: image/png
curl -sI https://assets.skeilopos.com/skeiloPosResourses/logo-horizontal-violeta-fondo-claro-1200px.png \
  | grep -iE '^(HTTP/|content-type|content-length)'
```

> **Nota (2026-10-06)**: el logo se subió conservando su nombre de archivo original bajo el prefijo
> `skeiloPosResourses/`, no bajo la clave `brand/logo-horizontal-claro-1200.png` que este documento y
> `data-model.md` anticipaban. `URL_LOGO` en `app/core/mail_templates/_marca.py` apunta a la URL real.

G1, G2 y G3 están cerradas. Ninguna bloquea ya ninguna verificación.

---

## 1. Prerrequisitos

- `pos-backend` en la rama de G2, con el entorno virtual de `env/`.
- Una casilla de **Gmail** del propio equipo, abrible en **web y en Android** (Assumption de la spec).
  Es la única vía de verificación real de FR-052 (D14).
- Acceso al panel de Super Admin, para US5 y para la variante de Super Admin de US3.
- El stack de desarrollo levantado para las pruebas de extremo a extremo. *(Nota: la memoria del
  proyecto registra que en la spec 094 el stack de dev no arrancaba porque `pos-api` no alcanzaba el
  5432; si vuelve a pasar, es un problema de entorno previo a esta spec.)*

No hay nada que instalar: esta spec no añade ninguna dependencia (research Decisión 3).

---

## 2. Línea base, antes de tocar nada

```bash
cd ../pos-backend
./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'
```

**Resultado esperado, medido el 2026-10-06**: `Ran 1320 tests` … `OK`.

Anota el número. SC-011 exige terminar en verde con las únicas actualizaciones de test que FR-059
autoriza, así que el recuento final debe ser **1320 + los tests nuevos**, sin ningún fallo y sin ningún
test desaparecido.

> Esta suite no arrastra fallos preexistentes, a diferencia de la del frontend. Cualquier rojo que
> aparezca es de este trabajo.

---

## 3. Verificación automatizada

### 3.1 Suite completa

```bash
./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'
```

### 3.2 Por módulo, durante la implementación

```bash
# Maqueta y marca (FR-001..FR-013, FR-049..FR-054)
./env/bin/python -m unittest app.characterization_tests.test_plantillas_correo_maqueta -v

# Escape y validación (FR-040..FR-043)
./env/bin/python -m unittest app.characterization_tests.test_plantillas_correo_escape -v

# Un correo concreto
./env/bin/python -m unittest app.characterization_tests.test_correo_invitacion -v
./env/bin/python -m unittest app.characterization_tests.test_correo_restablecimiento -v
./env/bin/python -m unittest app.characterization_tests.test_correo_contrasena_cambiada -v

# Texto plano y payload (FR-044..FR-048)
./env/bin/python -m unittest app.characterization_tests.test_correo_texto_plano -v
```

### 3.3 No regresión de los disparadores (los seis archivos de FR-059 y FR-060)

```bash
./env/bin/python -m unittest \
  app.characterization_tests.test_invitations_create \
  app.characterization_tests.test_invitations_resend_cancel \
  app.characterization_tests.test_invitation_email_greeting \
  app.characterization_tests.test_auth_forgot_password \
  app.characterization_tests.test_auth_reset_password \
  app.characterization_tests.test_auth_change_password -v
```

**`test_auth_forgot_password.py` y la extracción del token de `test_auth_reset_password.py` tienen que
pasar sin modificar su regex** (FR-060). Si hay que tocar el regex, la maqueta está mal: revisa el orden
del botón y del enlace visible (ver [disparadores.md](./contracts/disparadores.md) §3).

### 3.4 Lo que cada test nuevo debe cubrir

Resumen de trazabilidad; el detalle de las reglas está en
[`data-model.md`](./data-model.md) y [`constructores-de-correo.md`](./contracts/constructores-de-correo.md).

| Archivo | Requisitos | Afirmaciones clave |
|---|---|---|
| `test_plantillas_correo_maqueta` | FR-001..FR-013, FR-049..FR-054 | Cada valor de la tabla de FR-002 aparece en los tres cuerpos; `URL_LOGO` literal con `alt="SkeiloPOS"` y `width="150"`; vista previa oculta y sin contraseña; sin `<style>`, sin flexbox, sin grid; `bgcolor` junto a `background`; `width="600"` + `max-width:600px`; una sola imagen por correo; ningún recurso externo ajeno al logo |
| `test_plantillas_correo_escape` | FR-040..FR-043 | `<b>x</b>`, `Ñandú & Cía`, `O'Brien` y `"` escapados en HTML y **crudos** en texto; `ErrorDePlantillaDeCorreo` por cada campo obligatorio vacío/`None`/espacios; **el mensaje de la excepción no contiene la contraseña**; ningún cuerpo contiene `None` ni `null` |
| `test_correo_invitacion` | FR-014..FR-026 | Asunto literal con nombre comercial; `INVITACIÓN · {NEGOCIO}`; `Hola, X.` / `Hola.` sin coma suelta ni doble espacio; nombre comercial y no el `host`; tres filas en orden; texto del enlace idéntico al `href`; botón al mismo destino; aviso de atención; **sin mención de vencimiento** (FR-022); contraseña ausente del asunto y de la vista previa; el alta de negocio produce el mismo contenido (FR-026) |
| `test_correo_restablecimiento` | FR-027..FR-032 | Etiqueta, título y párrafo; botón al enlace; `Válido por {N} minutos.` tomado del parámetro, no de un literal; enlace visible presente **después** del `href` del botón; frase de cierre; **ningún nombre de negocio ni subdominio ajeno** |
| `test_correo_contrasena_cambiada` | FR-033..FR-039 | Etiqueta y título; tres filas en la variante de tenant, dos en la de Super Admin **sin hueco ni `None`**; `2026-10-02T21:06Z` → `02/10/2026 · 04:06 p. m. (hora de Colombia)`; aviso según rol; botón al subdominio correcto en cada variante; **ninguna contraseña en el cuerpo**; las combinaciones cruzadas de `es_super_admin`/`nombre_negocio` levantan excepción |
| `test_correo_texto_plano` | FR-044..FR-048 | Texto con título, datos, avisos y pie; cada enlace completo en línea propia; misma hora y mismo aviso por rol que el HTML; `create_message` incluye `textBody` cuando se pasa y **omite la clave** cuando no; el resto del payload idéntico al actual |

---

## 4. Verificación manual con envío real

Ocho comprobaciones que ninguna suite puede hacer, porque dependen del microservicio opaco y de
clientes de correo de terceros.

### Salvaguarda (FR-061, D15) — leer antes de enviar

1. El destinatario de **toda** prueba es una casilla del propio equipo. Nunca una dirección de cliente.
2. Todo negocio, usuario e invitación creado para probar lleva el prefijo **`[096-test]`** en el nombre,
   para poder identificarlo y limpiarlo después.
3. Antes de cada envío, verifica a quién va:
   ```bash
   grep -n "EMAIL_API_URL" ../pos-backend/.env   # recuerda: definido 2 veces, gana el último (A-120)
   ```
4. Al terminar, deja anotado en `tasks.md` qué datos `[096-test]` quedaron en la base de datos de
   desarrollo.

### V1 — El logo se ve y el correo sobrevive sin él (FR-006, FR-007)

Invita a tu casilla y abre el correo en Gmail web. **Esperado**: el logo aparece a 150 px. Después
bloquea las imágenes en Gmail y recarga: **esperado**, se lee `SkeiloPOS` como texto alternativo y el
correo sigue siendo utilizable.

### V2 — Fidelidad visual en Gmail web y Gmail Android (FR-052, SC-001, D14)

Envíate los tres correos y compáralos lado a lado con los tres archivos de
`SkeiloPOS App diseñada/`. **Esperado**: logo, botón, tarjetas, colores y jerarquía como en el diseño.
La única diferencia admitida es la tipografía de reserva (Arial en vez de Sora/Figtree), prevista por
FR-004.

Outlook web, Outlook de escritorio y Apple Mail son **verificación diferida declarada** (D14): no se
comprueban aquí y no condicionan el cierre. Anótalo como tal, no como pendiente.

### V3 — 360 px sin desplazamiento horizontal (FR-053, SC-002)

Abre los tres correos en Gmail Android, y en Gmail web con la ventana a 360 px. **Esperado**: todo cabe,
nada se corta, no hay barra horizontal. Incluye el caso de FR-012: invita con un negocio llamado
`[096-test] Heladería y Fuente de Soda Los Tres Hermanos de la Esquina` y comprueba que la píldora
rompe en dos líneas **sin truncar** y sin desbordar la tarjeta.

### V4 — El texto plano llega (FR-048, SC-009, D7)

En Gmail web, sobre el correo recibido: **Mostrar original**.

- **Si el mensaje es `multipart/alternative` con una parte `text/plain`**: el servicio sí lee `textBody`.
  Comprueba que la parte de texto lleva el contenido útil y los enlaces completos en línea propia.
- **Si solo hay `text/html`**: el servicio ignora `textBody`. **Este resultado cumple FR-048**, que solo
  exige que el HTML salga intacto. Documéntalo y no cambies el código.

En los dos casos, confirma que el HTML se muestra intacto.

### V5 — El asunto y la vista previa no filtran la contraseña (FR-023, SC-006)

En la bandeja, sin abrir el correo: **esperado**, ni el asunto ni la línea de vista previa contienen la
contraseña temporal. Después, en los registros del backend:

```bash
# No debe aparecer la contraseña temporal del envío de prueba
grep -nF "<la contraseña que llegó al correo>" ../pos-backend/app.log
```

**Esperado**: cero coincidencias (FR-024, FR-042).

### V6 — Ni seguimiento ni redirecciones (FR-049, FR-050, FR-051, SC-007)

Sobre **Mostrar original**: **esperado**, una sola etiqueta `<img>`, la del logo en
`assets.skeilopos.com`; ningún `<img>` de 1 px; ningún `href` que pase por un dominio de conteo de
clics; cada `href` idéntico al que el backend generó (compáralo con el enlace del registro o con el
token de la base de datos).

Si aparece reescritura de enlaces o un píxel, **no es un defecto del código**: lo añadió el
microservicio o el proveedor, y es un hallazgo nuevo para registrar (D2 ya advierte que esto no se puede
garantizar desde el backend).

### V7 — La hora que el usuario reconoce (FR-036, SC-008, A-118)

Cambia tu contraseña desde la aplicación anotando la hora local. **Esperado**: el correo muestra
`dd/mm/aaaa · hh:mm a. m./p. m. (hora de Colombia)` con tu hora de Colombia, no UTC, con hora de 12 y
cero inicial.

### V8 — La variante de Super Admin (FR-035, FR-037, FR-038, D6)

Cambia la contraseña de la cuenta de plataforma desde `admin.skeilopos.com`. **Esperado**: no aparece
ninguna fila de negocio **ni hueco donde estaría**; el aviso dice que escriba a `skeilo.tech@gmail.com`;
el botón lleva al ingreso de la plataforma, no al de ningún negocio; el pie no menciona negocio.

### V9 — Tema oscuro del cliente (FR-054)

Activa el tema oscuro de Gmail Android y abre los tres correos. **Esperado**: la jerarquía se sostiene y
**ningún texto queda del mismo color que su fondo**. No se exige que el correo se vea igual que en tema
claro: se exige que siga siendo legible.

### V10 — Flujos de extremo a extremo (SC-003, SC-010)

1. Invita a tu casilla → entra con los datos del correo → el sistema exige fijar contraseña propia.
2. Pide un enlace de recuperación → úsalo → fija una contraseña nueva → llega el aviso de cambio.
3. Pide un enlace para un correo **que no existe** → **esperado**: mismo mensaje exacto en pantalla y
   **ningún correo enviado** (FR-055).
4. Reenvía una invitación → **esperado**: misma presentación y asunto, contraseña temporal nueva, y la
   anterior ya no sirve (FR-025).
5. Crea un negocio `[096-test]` desde el panel de plataforma → **esperado**: el correo del dueño es
   idéntico en presentación y asunto al de una invitación normal (US5, FR-026).

---

## 5. Cierre

La spec se considera completa cuando:

- [x] G1, G2 y G3 cerradas. **G3 cerrada el 2026-10-06** con una clave distinta de la prevista —
      `skeiloPosResourses/logo-horizontal-violeta-fondo-claro-1200px.png` en vez de
      `brand/logo-horizontal-claro-1200.png` — verificado con `curl -sI` (200, `image/png`).
- [x] Suite en verde con `1320 + nuevos` tests y ningún test desaparecido (SC-011). **Medido
      2026-10-06: `Ran 1439 tests` … `OK`** (1320 + 119 nuevos).
- [x] Las cinco actualizaciones de test de FR-059 hechas **citando su decisión en el mismo commit**, y
      ninguna más sin justificar.
- [x] `test_auth_forgot_password.py` y la extracción del token de `test_auth_reset_password.py` pasan
      **sin cambiar el regex** (FR-060).
- [ ] V1 a V10 **no ejecutadas**: todas exigen envío real (Gmail web/Android) y acceso al panel de
      Super Admin sobre el stack de desarrollo levantado, ninguno disponible en esta sesión. La
      conformidad de construcción que las sostiene (FR-005, FR-053, FR-054) sí está verificada por
      T047. Quedan pendientes para quien tenga ese acceso.
- [x] Outlook web, Outlook de escritorio y Apple Mail anotados como **verificación diferida declarada**
      (D14), no como pendientes — su conformidad se sostiene por la técnica de construcción (T047).
- [x] A-120 sigue abierta y anotada como hallazgo para la spec de entorno (D15).
- [x] Los datos `[096-test]` creados en desarrollo quedan anotados: **ninguno**, porque no se ejecutó
      ninguna verificación manual en esta sesión (T063).
