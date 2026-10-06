# Research — Fase 0: Rediseño unificado de inicio de sesión y recuperación de contraseña

**Spec**: [spec.md](./spec.md) | **Fecha**: 2026-10-05

Las decisiones de este documento se numeran **R1, R2, …** para no confundirlas con las
decisiones de negocio de la spec, que se citan como **D1 … D12 de la spec**. Cada una se tomó
contra el código real de `pos-heladeria` y `pos-backend`, no contra el pedido: donde la spec
daba un requisito y el código decía otra cosa, lo que manda es el hallazgo, y el hallazgo
queda escrito aquí.

La spec llegó sin ningún `NEEDS CLARIFICATION`: sus doce decisiones ya cerraron el "qué". Lo
que esta fase resuelve es el "cómo", y tres hallazgos del reconocimiento que la spec no podía
anticipar: **R7** (el 403 del backend filtra hoy que la cuenta existe), **R9** (el ojo de la
contraseña es inalcanzable por teclado) y, el más grave, **R18** (FR-037 no se puede cumplir
sin tocar el servidor, que FR-044 prohíbe tocar).

---

## R1 — Un cascarón compartido, no el mismo layout copiado tres veces

**Decisión**: se crea `AuthShellComponent` en
`pos-heladeria/src/app/modules/auth/components/auth-shell.component.ts`. Las tres pantallas
pasan a ser contenido dentro de él: el cascarón pone la rejilla de dos columnas, el logotipo,
la etiqueta de contexto, el pie de página y el panel de marca; cada pantalla aporta solo su
formulario.

**Fundamento**: FR-001 exige que las tres pantallas compartan "el mismo layout base" y FR-002
fija el orden de los elementos de la columna del formulario. Con tres plantillas
independientes, "el mismo layout" es una coincidencia que se rompe en el primer arreglo que se
haga en una sola de ellas. Con un cascarón es una propiedad estructural: no hay forma de que
una pantalla se desalinee sin que las tres lo hagan. Además concentra en un archivo los
requisitos transversales —FR-003 (pie), FR-004/FR-005 (panel de marca), FR-007 a FR-010
(etiqueta y host no reconocido)— y evita triplicar sus tests.

**Hoy**: `login.component.ts` tiene su propio layout de dos columnas (`lg:flex-row` + panel
decorativo); `forgot-password.component.ts` y `reset-password.component.ts` son tarjetas
centradas de una columna (`items-center justify-center`), sin panel, sin etiqueta y sin pie.
Las tres no se parecen entre sí, que es exactamente el problema que FR-001 describe.

**Alternativas consideradas**:
- *Repetir el layout en las tres plantillas*: rechazada por lo anterior y porque multiplica
  por tres el costo de cada ajuste de accesibilidad.
- *Un layout de ruta de Angular (`<router-outlet>` dentro de un componente de ruta padre)*:
  rechazada por alcance. Agrupar las tres rutas bajo un padre cambia `app.routes.ts` y la
  forma de las URLs heredadas (`/login`, `/forgot-password`, `/reset-password` son públicas y
  viajan en correos ya enviados). El cascarón como componente que cada pantalla envuelve
  consigue lo mismo sin tocar el enrutador.

---

## R2 — El panel de marca: texto real en HTML, vista previa como fondo CSS tras una media query

**Decisión**: el panel derecho se construye con el lema y su texto de apoyo como **texto HTML
real** sobre el color primario, y la vista previa del sistema se aplica como
`background-image` dentro de una regla `@media (min-width: 1024px)`. Nada de `<img>` para la
vista previa.

**Fundamento**: FR-005 pide dos cosas distintas, y la segunda es la difícil: que por debajo de
1024 px la imagen **no se descargue**. El código actual no lo cumple —
`login.component.ts:143-149` envuelve el `<img src="/images/login-panel.svg">` en un
`hidden lg:flex`, y un `display:none` **no evita la descarga**: el navegador baja la imagen
igual porque el elemento existe en el DOM. Una `background-image` declarada dentro de una
media query que no aplica **no se solicita**, porque el estilo no se resuelve para ningún
elemento: es el único de los tres mecanismos que cumple FR-005 sin JavaScript.

Y de paso resuelve dos cosas más:
- El *edge case* "Imagen del panel de marca no disponible": si el fondo no carga, el panel
  conserva su color y su texto, sin hueco roto ni layout partido. Con `<img>`, un 404 deja el
  ícono de imagen rota ocupando la mitad del panel.
- FR-042 (contraste): el lema deja de ser pixeles dentro de una imagen y pasa a ser texto, que
  es lo que una auditoría de contraste puede medir y un lector de pantalla puede leer.

**Alternativas consideradas**:
- *`<picture>` con `<source media="(min-width:1024px)">`*: rechazada porque el `<img>` de
  reserva es obligatorio y es justo el que se descargaría en móvil.
- *Renderizado condicional con `window.matchMedia` y un signal*: cumple FR-005, pero mete un
  listener de `resize`, un estado nuevo y un parpadeo en el primer pintado a cambio de nada
  que el CSS no dé gratis.

**Activo**: la vista previa del mockup es
`~/Escritorio/SkeiloPOS App diseñada/uploads/pasted-1791030235876-0.png` (1365×828, 140 KB). Se
convierte a WebP y se publica como `pos-heladeria/public/images/auth-preview.webp`, con un
presupuesto de **≤ 80 KB** (referencia: el `dashboard-main.webp` del mismo directorio de
diseño pesa 58 KB a 1599×1199). El `login-panel.svg` actual (1,4 KB, patrón abstracto sin
texto) **no sirve** para FR-004: no es una vista previa del sistema, es un adorno. Queda sin
uso y se elimina en la misma tarea que lo deja de referenciar.

---

## R3 — La paleta se queda en el índigo del sistema; no se adopta el violeta del mockup

**Decisión**: los acentos siguen siendo la escala `indigo-*` de Tailwind que ya usan las tres
pantallas y el resto del panel. El violeta del mockup (`#6D28D9`, con `#5B21B6` en hover) no
se adopta.

**Fundamento**: el mockup está construido sobre un sistema de tokens propio
(`var(--color-primary)`, `--color-text-muted`, `--color-success-soft`, …) que no existe en
`pos-heladeria`, y la propia spec lo encuadra: los archivos de diseño son "referencia de
intención visual … no código a trasladar", y la equivalencia "se evalúa sobre el resultado
percibido" (_Assumptions_, Fuente de verdad del diseño). Cambiar el primario solo en las tres
pantallas de autenticación produciría lo contrario de lo que FR-001 persigue: el usuario
entraría en violeta y aterrizaría en un panel índigo. Y cambiarlo en todo el sistema es un
rediseño de marca que ninguna FR de esta spec pide, con lo que caería de lleno en el Principio
V.

**Consecuencia aceptada**: pérdida de fidelidad cromática frente al mockup, en la misma línea
que la pérdida de fidelidad que D2 de la spec ya aceptó en la etiqueta. Lo que sí se traslada
del mockup es la **estructura**: rejilla de dos columnas con la de marca ligeramente más ancha
(`minmax(360px,1fr) / minmax(0,1.15fr)`), radio de 24 px en el panel, campos de 48 px de alto
con radio de 8 px, insignia con ícono, títulos con punto final y jerarquía de 30 px.

**Alternativas consideradas**: *redefinir el primario del sistema a violeta* (rediseño global,
fuera de alcance); *violeta solo en autenticación* (rompe FR-001 en la frontera del login).

> ### ⚠️ R3 REVOCADA por el usuario (2026-10-05, durante la implementación)
>
> Leonardo Gómez revisó el resultado y pidió que las pantallas fueran **100 % fieles al diseño**.
> Esa instrucción prevalece sobre esta decisión técnica, que era mía, no suya.
>
> **Lo que cambia**: se adopta la paleta del sistema de diseño entregado
> (`_ds/skeilopos-design-system-…/tokens/`, tema claro): primario `#7C3AED`, texto de acción
> `#6D28D9`, superficies `#FFFFFF`/`#EDF1F5`, bordes `#E5E9EF`/`#CBD5E1`, texto
> `#090D16`/`#334155`/`#64748B`, error `#E11D48` sobre `#FDECEF`.
>
> **Cómo se acota el riesgo que R3 señalaba**: los tokens **no** van en `:root`, sino dentro de
> una clase `.auth-theme` que el cascarón pone en su raíz. Así las tres pantallas de
> autenticación son fieles al diseño y las ~40 restantes siguen en índigo, sin tocarse — que era
> exactamente la objeción del Principio V. La discontinuidad que R3 temía (entrar en violeta y
> aterrizar en índigo) **sigue existiendo** y es ahora una consecuencia aceptada: se resolverá
> cuando el resto del panel adopte el sistema de diseño, en una spec propia.

---

## R4 — No se añaden las tipografías del mockup

**Decisión**: se conserva la tipografía actual de la aplicación. No se añaden `Figtree` (cuerpo)
ni `Sora` (títulos), que es lo que declara el mockup.

**Fundamento**: son dos familias nuevas que habría que autoalojar —el proyecto ya decidió no
depender de CDNs de fuentes en la spec 082, al autoalojar Material Icons— y pesan en el primer
pintado de la pantalla más usada del sistema. Ninguna FR las pide: FR-001 habla de layout
compartido, no de tipografía. Igual que R3, aplicarlas solo aquí rompería la continuidad con
el panel. El Principio IX pide justificar toda dependencia nueva por el problema que resuelve;
aquí el problema es estético y el costo es de rendimiento y de consistencia.

> ### ⚠️ R4 REVOCADA por el usuario (2026-10-05, durante la implementación)
>
> Misma instrucción que revocó R3: fidelidad total al diseño.
>
> **Lo que cambia**: se añaden `Sora` (títulos) y `Figtree` (interfaz), **autoalojadas** en
> `public/fonts/auth/`, siguiendo el patrón que la spec 082 fijó para Material Icons — el sistema
> de diseño las sirve desde Google Fonts y eso sí se descartó, para no depender de una CDN
> externa. Son variables, así que **dos archivos por familia** (latín y latín extendido) cubren
> todos los pesos: 68 KB en total, y en la práctica el navegador solo pide los dos subconjuntos
> latinos (45 KB), porque el extendido no hace falta en español.
>
> El costo de primer pintado que R4 señalaba se acota con `font-display: swap`: el texto se ve de
> inmediato con la tipografía de reserva y se recompone al llegar la definitiva.

---

## R5 — La etiqueta de contexto la resuelve el cascarón, leyendo el contexto ya existente

**Decisión**: el cascarón inyecta `TenantContextService` y deriva la etiqueta de sus signals,
sin ninguna petición y sin ningún estado intermedio:

| `kind` del contexto | Etiqueta |
|---|---|
| `TENANT` | `tenantSlug()` tal cual, con ícono genérico de negocio (`storefront`) |
| `SUPER_ADMIN` | "Administración de la plataforma", sin ningún identificador |
| `UNRECOGNIZED` | ninguna: se renderiza el aviso de FR-009 (ver R6) |

**Fundamento**: `TenantContextService` ya es exactamente lo que FR-007a y FR-007c piden —un
contenedor **síncrono** que el inicializador de arranque llena una sola vez
(`tenant-context.service.ts:53-58`), de modo que al primer pintado la etiqueta ya tiene su
texto definitivo y no cambia después. FR-010 prohíbe una segunda fuente de verdad sobre el
tipo de host, y este servicio es la de la spec 091: el cascarón **lee**, no clasifica. FR-007
exige el slug "tal cual aparece en la dirección": `tenantSlug()` devuelve el label del
subdominio sin transformar, así que la regla se cumple **no haciendo nada** — ni `titlecase`,
ni reemplazo de guiones, ni capitalización.

FR-007d queda cubierto por el ícono genérico `storefront` (ya en `ICON_CATALOG`; el catálogo
real **no** tiene `store` ni `shield`, y para `SUPER_ADMIN` se usa `admin_panel_settings`): la
insignia acompaña al identificador con un distintivo del sistema, nunca con el logotipo del
negocio (que, además, el cliente no tiene, y D2 de la spec prohíbe pedírselo al servidor).

**Truncado** (*edge case* "Identificador de subdominio muy largo"): la insignia lleva
`max-w-[16rem] truncate` y el identificador completo en el atributo `title`. Truncar con
elipsis en CSS mantiene el texto completo accesible al lector de pantalla y al puntero, y no
puede empujar el formulario.

---

## R6 — FR-009 se aplica en el cascarón, así que cubre las tres pantallas

**Decisión**: el aviso de host no reconocido vive en el cascarón. Cuando
`tenant.isUnrecognized()` es verdadero, el cascarón renderiza el aviso y **no proyecta el
contenido** de la pantalla. Además, cada pantalla con petición de arranque debe consultar el
contexto antes de emitirla: `reset-password.component.ts` no debe llamar a
`validateResetToken` en un host no reconocido.

**Fundamento**: FR-009 está escrito sobre "el sistema", no sobre una pantalla, y prohíbe dos
cosas: renderizar formulario y emitir peticiones. Hoy solo el login lo cumple
(`login.component.ts:33-45`, spec 091 FR-005/FR-006); `/forgot-password` y `/reset-password`
**no tienen guard de dominio** (`app.routes.ts:26-40`) y hoy se renderizarían con normalidad
en el dominio raíz o en un subdominio reservado — y la de reset, además, dispararía una
petición de validación sin cabecera `X-Tenant-Host`. Poner la regla en el cascarón la cumple
en las tres por construcción.

**Esto es un cambio de comportamiento en dos pantallas** respecto de lo que hay hoy. Lo exige
FR-009 de una spec aprobada (Principio IV), no altera ningún test `CONGELA` —no hay ninguno en
el área de autenticación, ver R17— y queda registrado como decisión en el registro de
anomalías junto con R7 y los cambios de texto (ver R16).

**Alternativa considerada**: *añadir `tenantDomainGuard` a las dos rutas*. Rechazada: ese
guard redirige, y FR-009 pide **mostrar un mensaje** con enlace al sitio principal, no
redirigir. Además la ruta `/reset-password` es deliberadamente pública (su comentario en
`app.routes.ts` explica que un guard la echaría antes de leer el token).

---

## R7 — "Credenciales inválidas" obliga a mapear el 401 **y el 403** en el camino del login

**Decisión**: `AuthService.login()` traduce a **"Credenciales inválidas"** tanto el `401` como
el `403` del backend, con un mapeo propio del login, sin tocar `extractError()`, que lo
comparten los otros tres flujos.

**Hallazgo que lo obliga**: hoy la pantalla **sí distingue** una cuenta desactivada de unas
credenciales malas, que es justo lo que FR-012 prohíbe. El backend responde:

| Caso | Respuesta del backend | Lo que ve el usuario hoy |
|---|---|---|
| Correo inexistente / contraseña mala | `401` `detail: "Invalid credentials"` | "Credenciales incorrectas. Verifica tu email y contraseña." |
| **Cuenta desactivada** | **`403` `detail: "User account is inactive"`** | **"User account is inactive"** |

(`pos-backend/app/api/v1/auth/routes.py:164,188,193`; el 401 se traduce en
`auth.service.ts:237-239`, y el 403 cae al camino genérico de `extractError` que **devuelve el
`detail` del backend tal cual**, en inglés). Es decir: hoy un atacante distingue "esta cuenta
existe pero está desactivada" de "esta cuenta no existe", y además lo ve en inglés. FR-012 y
SC-003 lo cierran.

**Por qué no se arregla en `extractError`**: lo usan también `changePassword`, `forgotPassword`
y `resetPassword` (`auth.service.ts:77,101,115`). Mapear ahí el 403 a "Credenciales inválidas"
pondría ese texto en el cambio de contraseña autenticado, donde no tiene sentido. El mapeo
pertenece al login.

**Nota de alcance**: el backend no cambia. Lo que cambia es que la pantalla deja de repetir su
`detail`. FR-044 queda intacto.

---

## R8 — Tras un intento fallido: limpiar la contraseña, enfocarla, conservar el correo

**Decisión**: en la rama de error de `submit()`, el componente llama a
`form.controls.password.reset('')`, deja `email` intacto y mueve el foco al campo de
contraseña con un `viewChild` sobre el `app-password-input` y un método público `focus()`
nuevo en ese componente compartido (aditivo, sin cambiar su comportamiento actual).

**Fundamento**: FR-013 pide las tres cosas y hoy no ocurre ninguna (`login.component.ts:189-193`
solo fija el mensaje). Enfocar desde el padre exige que el hijo exponga cómo: hoy el `<input>`
real vive dentro de `PasswordInputComponent` y el padre no lo alcanza. Un método `focus()` en
el hijo es la superficie mínima —un `viewChild('input')` interno y un `focus()`— y no altera
nada de lo que el componente ya hace, así que las otras cuatro pantallas que lo usan no se
enteran.

**Alternativa considerada**: *`document.getElementById('password')?.focus()`*. Funciona (el
`id` se proyecta al input real), pero salta el modelo de componentes de Angular y deja el
contrato implícito en una cadena de texto; un cambio de `id` lo rompe en silencio.

---

## R9 — El botón del ojo deja de ser inalcanzable por teclado

**Decisión**: se quita `tabindex="-1"` del botón de visibilidad en
`shared/password-input/password-input.component.ts:46`. Queda en el orden natural de
tabulación, con su `aria-label` y `aria-pressed` actuales.

**Hallazgo que lo obliga**: FR-040 exige que **todos** los controles se activen solo con el
teclado y FR-016 que el control de visibilidad anuncie su acción. El `aria-label` y el
`aria-pressed` ya están bien; el `tabindex="-1"` hace que el botón **no se pueda enfocar con
Tab**, así que hoy un usuario de teclado no puede mostrar su contraseña. Es un incumplimiento
de WCAG 2.1 AA 2.1.1 (Teclado), y bloquea también SC-004.

**Alcance del cambio y Principio V**: el componente lo usan además
`change-password.component.ts`, `account-settings.component.ts` y
`admin-user-form.component.ts`. Se evaluó añadir un `@Input()` para hacerlo enfocable solo en
las tres pantallas de esta spec, y **se descartó**: dejaría deliberadamente roto el acceso por
teclado en las otras tres pantallas, a cambio de una opción de configuración que nadie querría
poner en `false`. El cambio es de una línea, no altera ningún comportamiento funcional (el
botón ya hacía lo mismo al pulsarlo), y es la única forma de cumplir FR-040 donde el control
vive. Ningún test afirma ese `tabindex` (el único `expect` sobre `tabindex` del repositorio
está en `checkout-order-summary.component.spec.ts:328`, sobre otro componente).

---

## R10 — Bloqueo de reenvío: vencimiento absoluto en `sessionStorage`, nunca un contador de ticks

**Decisión**: al enviarse una solicitud con éxito, la pantalla guarda el **instante de
vencimiento** (`Date.now() + 60_000`) en `sessionStorage`, bajo la clave
`skeilo.auth.resend-lock-until`. La cuenta regresiva que se muestra se calcula en cada tick
como `Math.ceil((until - Date.now()) / 1000)`, con un `setInterval` de 1 s que solo sirve para
repintar. Al montarse, la pantalla lee la clave: si el instante aún no pasó, arranca
bloqueada con los segundos que falten.

**Fundamento**: FR-022 pide exactamente las dos propiedades que esto da:
- *"sobre tiempo transcurrido real, de modo que no se alargue si el navegador pausa sus
  temporizadores"*: un contador que resta 1 por tick se atrasa cuando la pestaña pasa a
  segundo plano y el navegador estrangula los timers. Restar dos marcas de reloj es inmune:
  la pestaña vuelve y la cuenta ya está donde debía estar, o ya terminó.
- *"NO DEBE poder eludirse recargando la pantalla"*: el vencimiento sobrevive al `F5` porque
  vive fuera del componente.

**Por qué `sessionStorage` y no `localStorage`**: el bloqueo es una ayuda de interfaz, no un
control de seguridad —FR-024 y D6 de la spec lo subordinan explícitamente al límite del
servidor (3/900 s por negocio y cuenta, verificado en `routes.py:235-246`)—. `sessionStorage`
cumple el requisito escrito (sobrevive a la recarga) y caduca con la pestaña, que es la vida
útil razonable de un bloqueo de 60 segundos en un equipo de mostrador compartido.

**No se guarda el correo**: una sola clave con un número. Nada que pueda identificar a nadie
queda en el navegador, lo que mantiene limpio el espíritu de FR-019d y evita que el correo de
un cajero quede legible para el siguiente turno.

---

## R11 — El 429 se traduce en la pantalla; no se repite el texto del backend

**Decisión**: `forgot-password` mapea el `429` a un literal propio: *"Hiciste demasiados
intentos. Vuelve a intentarlo más tarde."* No se muestra el `detail` del backend ni se
distingue el 429 de ningún otro error en el texto que ve el usuario respecto de la existencia
de la cuenta.

**Fundamento**: FR-023 exige "demasiados intentos … intentarlo más tarde" **sin revelar si la
cuenta existe**, y D5 de la spec ordena no citar una ventana de tiempo concreta para que el
texto siga siendo correcto si cambia la configuración. El backend hoy devuelve
*"Has pedido demasiados enlaces. Vuelve a intentarlo en unos minutos."*
(`routes.py:244-246`), que cumple el espíritu pero es copia del servidor: si mañana alguien la
cambia ahí, cambia la interfaz sin que nadie lo decida. El literal de la pantalla es el que la
spec fija, y vive donde la spec lo puede verificar.

**Nota**: el 429 **no revela** existencia de cuenta, porque el límite se aplica por
`tenant+correo` antes de buscar al usuario (`routes.py:235-246`): una cuenta inexistente
también lo dispara. Es la razón por la que FR-023 puede mostrar ese mensaje sin romper SC-003.

---

## R12 — "Contraseña actualizada" viaja a `/login` por un aviso de un solo uso

**Decisión**: se añade `AuthNoticeService` (`core/auth/auth-notice.service.ts`): un signal con
un aviso de un solo uso (`set(notice)` / `consume()`). `reset-password` lo fija y navega a
`/login`; el login lo consume al montarse, lo muestra en una región `role="status"` y lo deja
vacío, de modo que una recarga no lo repite.

**Fundamento**: FR-031 cambia el comportamiento actual: hoy el éxito **se queda en la pantalla
de reset** con un estado `'done'` y un enlace a `/login`
(`reset-password.component.ts:62-80`), mientras la spec pide "llevar al inicio de sesión con el
mensaje". Hay que pasar un dato entre dos rutas, y las opciones son tres:

| Mecanismo | Problema |
|---|---|
| Query param `?password-updated=1` | queda en la URL, se puede compartir y reaparece en cada recarga; invita a falsificar el aviso |
| `router.navigate(..., { state })` | se pierde al recargar y se lee con `history.state`, difícil de probar sin acoplarse al navegador |
| **Servicio con aviso de un solo uso** | ninguno: no toca la URL, se limpia al leerse, y es un `TestBed.inject` en los tests |

El servicio es, además, el único de los tres que deja el aviso **imposible de fabricar desde
fuera**: nadie llega a `/login?password-updated=1` desde un correo de phishing.

---

## R13 — La lista de requisitos: una sola fuente para la política 8–12 y estado perceptible sin color

**Decisión**: la política vive en un único módulo
(`modules/auth/password-policy.ts`) que exporta la lista de reglas con su etiqueta y su
predicado, y de ahí salen **las tres cosas**: los validadores del formulario, la lista visible
y el estado de cada ítem. La lista es:

| Regla | Predicado |
|---|---|
| "Mínimo 8 caracteres" | `value.length >= 8` |
| "Máximo 12 caracteres" | `value.length <= 12` |

Cada ítem se marca con **ícono + texto**, no con color: `check` cuando se cumple, `circle`
cuando está pendiente (ambos ya en `ICON_CATALOG`), y un texto solo para lectores de pantalla
—"(cumplido)" / "(pendiente)"— dentro del propio ítem. La lista va en un contenedor
`aria-live="polite"` para que el cambio se anuncie al escribir.

**Fundamento**: FR-029 fija la política vigente (8 a 12, sin exigir mayúsculas ni números, spec
031 FR-019) y D4 de la spec ya resolvió que prevalece sobre el mockup —que pide "una letra
mayúscula" y "un número" y **omite el máximo**—. Mostrar el máximo es obligatorio: sin él, el
rechazo de una contraseña de 14 caracteres es inexplicable. FR-028 prohíbe comunicar el estado
solo por color, de ahí el ícono y el texto para ayudas técnicas. Y la fuente única evita el
fallo clásico de este tipo de pantalla: una lista que dice una cosa y un validador que exige
otra. Hoy el formulario ya valida 8–12 (`reset-password.component.ts:156`) pero **no hay
lista**: solo una frase.

**Nota de seguridad deliberada**: la lista **no** incluye "distinta de la actual" (FR-033), que
el servidor comprueba al enviar: la pantalla no conoce la contraseña actual, y fingir que la
comprueba en vivo sería mentir sobre el estado de un requisito.

---

## R14 — Los enlaces públicos salen de un campo nuevo de configuración

**Decisión**: `AppEnvironment` gana `publicSiteUrl: string`, con valor `https://skeilopos.com`
en los dos ficheros de entorno. El pie construye el enlace de privacidad como
`${publicSiteUrl}/privacidad` y el aviso de host no reconocido enlaza a `publicSiteUrl`.

**Fundamento**: FR-003 y FR-009 piden ambos enlaces y FR-003a exige que apunten a páginas que
**existen**. Verificado: `skeilo-pos-landing/src/pages/privacidad.astro` y la portada existen,
así que esta spec solo las enlaza. El campo nuevo es necesario porque derivarlo de `rootDomain`
rompe en desarrollo: ahí `rootDomain` es `localhost`
(`environment.development.ts`), y el enlace quedaría en `http://localhost/privacidad`. No es
una dependencia nueva (Principio IX no aplica): es un campo de configuración en la interfaz que
ya centraliza el resto, con la misma forma en los dos entornos para que no haya deriva.

---

## R15 — La auditoría WCAG se hace con herramientas ya disponibles, sin dependencia nueva

**Decisión**: SC-005 se verifica con la auditoría de accesibilidad de Lighthouse/DevTools sobre
las tres pantallas, documentada como paso manual en [quickstart.md](./quickstart.md). No se
añade `axe-core`, `jest-axe` ni equivalente al proyecto.

**Fundamento**: el Principio IX pide justificar toda dependencia nueva, y aquí la
justificación no aparece: la auditoría es de tres pantallas, se corre una vez por entrega y la
herramienta ya está en el navegador del equipo. Lo que **sí** se automatiza en Vitest son los
hechos estructurales que un test puede afirmar sin motor de accesibilidad: que cada campo tiene
`<label for>` apuntando a su `id` (FR-038), que los mensajes viven en una región con `role` y
`aria-live` (FR-041), que el botón del ojo tiene `aria-label` y `aria-pressed` (FR-016), y que
los ítems de la lista de requisitos llevan texto además de ícono (FR-028). El contraste
(FR-042) y el área de activación táctil (FR-043) se fijan por diseño —cada control con 44 px de
alto mínimo, como el mockup— y se comprueban en la auditoría.

---

## R16 — Los tests de la spec 091 que afirman los textos viejos se actualizan citando D7 y D8

**Decisión**: `login.component.spec.ts` cambia dos expectativas, y solo dos:
`"Acceso Super Admin"` → `"Administración de la plataforma"` (D8) y
`"Esta dirección no corresponde a ningún acceso"` → `"No encontramos este negocio"` (D7).

**Fundamento**: son tests de la spec 091 (marcados "spec 091 (A-99)" en el archivo,
líneas 64-103) y **no** llevan el prefijo `"CONGELA comportamiento actual:"`, así que el
Principio III no los blinda; lo que los gobierna es el Principio II, que exige que el cambio
esté documentado en la spec y registrado. Lo está: D7 y D8 lo deciden explícitamente y lo
califican de "redacción, no comportamiento". Lo que esos tests protegen de verdad —que el host
no reconocido no renderiza formulario y no llama al API— **no se toca**, y las aserciones que
lo comprueban (`querySelector('form')` nulo, `login` no llamado) quedan igual.

---

## R17 — No hay characterization tests en el área de autenticación del frontend

**Hallazgo**: `grep -rn "CONGELA" src/app/modules/auth src/app/core/auth src/app/core/tenant`
no devuelve nada. En el frontend solo existe `login.component.spec.ts`;
`forgot-password.component.ts` y `reset-password.component.ts` **no tienen tests**. Los
characterization tests de autenticación y recuperación que FR-045 protege viven en
`pos-backend/app/characterization_tests/` (`test_auth_forgot_password.py`,
`test_auth_reset_password.py`, `test_auth_login_platform_isolation.py`, …) y esta spec **no
toca el backend**, así que FR-045 se cumple por no tocar nada de lo que cubren.

**Consecuencia para el plan**: las dos pantallas sin tests ganan su `*.component.spec.ts`
hermano, no por completar cobertura ajena, sino porque son el único sitio donde se pueden
verificar FR-020 a FR-025 y FR-026 a FR-034. El Principio X lo exige para la funcionalidad
nueva de esta spec.

---

## R18 — ⚠️ FR-037 no se puede cumplir sin tocar el servidor, y FR-044 prohíbe tocarlo

**Hallazgo**: FR-037 dice que un enlace emitido para un negocio "DEBE tratarse como no válido
si se abre en el subdominio de otro negocio o en el de administración". **Hoy no es así, y no
se puede arreglar desde el frontend.**

La prueba está en `pos-backend/app/api/v1/auth/routes.py:68-94`: `_resolve_reset_token` busca
el token **solo por su hash** en una tabla compartida, y ni la validación
(`GET /auth/reset-password/validate`, línea 302) ni el consumo (`POST /auth/reset-password`,
línea 317) dependen de `get_tenant` ni leen la cabecera `X-Tenant-Host`. El token está atado
al **usuario**, no al host. Así que un enlace de `negocioa.skeilopos.com` abierto en
`negociob.skeilopos.com` o en `admin.skeilopos.com` **valida y permite fijar la contraseña
nueva**, de la cuenta correcta.

Contrasta con `forgot-password`, que sí está aislado: resuelve el correo con
`User.tenant_id == tenant.id` y limita por `tenant.id` (líneas 230-252), de modo que **FR-035 y
FR-036 sí se cumplen hoy**.

**Por qué el frontend no puede cerrarlo**: la pantalla no sabe a qué negocio pertenece el
token. `ValidateResetTokenResponse` es `{ valid, reason }` — no trae el tenant ni el correo
(`auth.models.ts:36-39`, confirmado en el endpoint). Para rechazar el enlace por host haría
falta que el servidor comparara el tenant del token con la cabecera, y eso es modificar un
endpoint: exactamente lo que **FR-044** prohíbe ("el servidor queda exactamente como está").

**Gravedad real**: baja, y conviene decirlo con precisión para que la decisión se tome con el
dato correcto. No hay escalada de privilegios ni fuga entre negocios: el enlace cambia la
contraseña **de su propio dueño**, en su propio negocio, pase lo que pase con el host desde el
que se abra. Lo que falla es la hermeticidad del aislamiento por subdominio, no la seguridad de
la cuenta. Quien tiene el enlace ya podía usarlo en el host correcto.

**Tratamiento propuesto** (requiere decisión de negocio antes de implementar FR-037):
1. Se registra como **HALLAZGO** en `specs/000-reconocimiento/registro-de-anomalias.md`
   (entrada nueva, ver R19), con esta evidencia.
2. FR-037 se marca en el plan como **no entregable en el alcance de esta spec**, igual que D12
   de la spec hizo con el Escenario 3 del pedido: una limitación conocida, escrita, y con el
   camino para cerrarla.
3. SC-010 se verifica **parcialmente**: un enlace vencido, ya usado o invalidado nunca permite
   fijar contraseña (eso sí está implementado y probado en el backend); la cláusula "abierto en
   el subdominio equivocado" queda abierta con el hallazgo.
4. Cerrarlo del todo es una spec de `pos-backend`: atar el token al tenant y exigir que el host
   coincida. Es un cambio pequeño y aditivo, pero **cambia el contrato de dos endpoints** y
   necesita sus propios characterization tests.

**Alternativa considerada y descartada**: *reabrir FR-044 y arreglar el backend en esta spec*.
Lo descarta la propia spec dos veces —FR-044 y la asunción "Alcance por repositorio"— y lo
descarta el Principio VI: mezclaría un rediseño de superficie con un cambio de contrato de
autenticación en un mismo incremento. Si el negocio decide que FR-037 es urgente, el camino
limpio es una spec propia, no colarlo aquí.

---

## R19 — Lo que hay que registrar en el registro de anomalías antes de implementar

El Principio II exige registrar en `specs/000-reconocimiento/registro-de-anomalias.md`, **antes
de implementar**, todo cambio de comportamiento existente. El último código usado es **A-107**,
así que las entradas nuevas arrancan en **A-108**. Son cuatro:

| Código | Qué cubre | Clasificación | Origen |
|---|---|---|---|
| A-108 | El `403` de cuenta desactivada deja de distinguirse: 401 y 403 se muestran como "Credenciales inválidas" | DECISIÓN (FR-012, SC-003) | R7 |
| A-109 | Los dos textos de la spec 091 cambian: "Acceso Super Admin" → "Administración de la plataforma" y "Esta dirección no corresponde a ningún acceso" → "No encontramos este negocio" | DECISIÓN (D7, D8) | R16 |
| A-110 | El éxito del cambio de contraseña deja de quedarse en su pantalla y pasa a `/login` con el aviso; y el aviso de host no reconocido se extiende a `/forgot-password` y `/reset-password` | DECISIÓN (FR-031, FR-009) | R6, R12 |
| A-111 | **HALLAZGO**: el enlace de recuperación no está atado al host; FR-037 no se puede cumplir sin tocar el servidor | HALLAZGO (FR-037 vs FR-044) | R18 |

A-108 a A-110 son decisiones que la spec ya tomó y solo hay que asentar. **A-111 es distinta**:
es un hallazgo que la spec no conocía, y su tratamiento —aceptar la limitación o abrir una spec
de backend— es una decisión que corresponde al negocio, no al implementador (Principio XI).

---

## R20 — Lo que queda fuera, aunque el mockup lo muestre

| Elemento del mockup | Por qué no se implementa |
|---|---|
| "Para la cuenta **correo@dominio**" en la pantalla de contraseña nueva | El endpoint de validación devuelve solo `{ valid, reason }`: no hay de dónde sacar el correo sin cambiar el contrato, y FR-044 lo prohíbe. |
| "Enviamos un enlace … a **correo**" como afirmación | FR-020 exige la forma condicional: afirmar el envío revela que la cuenta existe. El correo que el usuario escribió sí puede repetirse, pero dentro de "Si existe una cuenta con …" (ver el contrato de textos). |
| "También te enviamos un correo de confirmación" | Ninguna FR lo pide y no está verificado que ese correo se envíe. Afirmarlo sería prometer algo que el sistema puede no hacer. |
| Etiqueta "Usuario o correo" y `autocomplete="username"` | D1 de la spec: el identificador es solo el correo. FR-011a fija la etiqueta "Correo electrónico" y FR-017 el `autocomplete="email"`. |
| Etiqueta "Recordar contraseña" | D3a de la spec: el texto es "Mantener sesión iniciada", porque el sistema no guarda contraseñas (FR-019d, FR-019e). |
| Plantillas de correo y pantalla de cambio desde el perfil | D10 y D11 de la spec las dejan fuera de alcance. |

---

## Resumen de incógnitas resueltas

| Incógnita | Resuelta en |
|---|---|
| Cómo compartir el layout entre tres pantallas sin triplicarlo | R1 |
| Cómo evitar de verdad la descarga de la imagen en móvil | R2 |
| Qué hacer con la paleta y la tipografía del mockup | R3, R4 |
| De dónde sale la etiqueta y cómo se trunca | R5 |
| Dónde vive la regla del host no reconocido | R6 |
| Qué hace falta para que el error de login sea indistinguible | **R7 (hallazgo)** |
| Cómo se limpia y enfoca la contraseña tras un fallo | R8 |
| Cómo se vuelve alcanzable por teclado el control de visibilidad | **R9 (hallazgo)** |
| Cómo se cuenta un bloqueo que sobrevive a la recarga y a los timers estrangulados | R10 |
| Qué mensaje se muestra ante el límite del servidor | R11 |
| Cómo llega "Contraseña actualizada" al login | R12 |
| De dónde salen la política y su lista accesible | R13 |
| De dónde salen los enlaces al sitio público | R14 |
| Cómo se audita WCAG sin dependencia nueva | R15 |
| Qué tests existentes cambian y cuáles no | R16, R17 |
| Si FR-037 es implementable | **R18 (hallazgo, requiere decisión)** |
| Qué se registra antes de implementar | R19 |
| Qué del mockup queda fuera | R20 |

**Dependencias nuevas**: ninguna (Principio IX satisfecho por ausencia). **Cambios en
`pos-backend`**: ninguno (FR-044). **Migraciones**: ninguna.
