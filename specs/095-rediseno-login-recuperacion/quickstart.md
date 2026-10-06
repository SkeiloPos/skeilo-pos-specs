# Quickstart — Validación de la spec 095

**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Fecha**: 2026-10-05

Guía para comprobar que el rediseño quedó entregado. **Solo se toca `pos-heladeria`**: el
servidor queda como está (FR-044), así que no hay migración que correr ni backend que levantar
más allá del que ya usas para desarrollar.

Esta spec se verifica en tres planos distintos y conviene no confundirlos:

| Plano | Qué prueba | Cómo |
|---|---|---|
| Tests unitarios (Vitest) | estructura, textos literales, cero peticiones, mapeos de error | `npm test` |
| Recorrido manual en navegador | lo que un test de DOM no ve: foco, teclado, responsive, descargas | pasos 3 a 8 |
| Auditoría | contraste y etiquetado WCAG AA | paso 9 |

---

## 0. Prerrequisitos

```bash
# Backend de desarrollo en marcha (no cambia en esta spec, pero las pantallas lo llaman)
cd pos-backend && env/bin/python -m uvicorn app.main:app --reload   # :8000

# Frontend
cd pos-heladeria && npm install && npm start                        # :4200
```

**Hosts**: las tres pantallas dependen del subdominio, así que `localhost:4200` **no sirve** para
validar las etiquetas: el dominio raíz se clasifica como `UNRECOGNIZED` a propósito (spec 091).
Añade a `/etc/hosts`:

```
127.0.0.1  negocioa.localhost  negociob.localhost  admin.localhost  www.localhost  inventado.localhost
```

| URL de prueba | Contexto esperado |
|---|---|
| `http://negocioa.localhost:4200/login` | `TENANT`, etiqueta `negocioa` |
| `http://admin.localhost:4200/login` | `SUPER_ADMIN`, etiqueta "Administración de la plataforma" |
| `http://localhost:4200/login` | `UNRECOGNIZED` (dominio raíz) |
| `http://www.localhost:4200/login` | `UNRECOGNIZED` (slug reservado) |
| `http://inventado.localhost:4200/login` | `TENANT` con negocio inexistente — **el formulario se muestra** (FR-009a, D12) |

**Datos**: una cuenta activa de `negocioa`, una **cuenta desactivada** del mismo negocio (hace
falta para el paso 3.3, que es donde se verifica el hallazgo R7) y un super administrador de
plataforma.

### Línea base de la suite, antes de tocar nada

```bash
cd pos-heladeria && git stash && npm test 2>&1 | tail -30 && git stash pop
```

La suite del frontend arrastra fallos preexistentes ajenos a autenticación. **Anota el conteo
antes de empezar**: lo que esta spec tiene que cumplir es "ni uno más que la línea base", no
"cero fallos". Atribuir a este cambio un fallo heredado cuesta medio día de búsqueda inútil.

### Comandos de verificación automática

```bash
cd pos-heladeria
npm test                                      # suite completa
npm test -- --include src/app/modules/auth    # las tres pantallas y el cascarón
npm run build                                 # el build de producción debe pasar
```

---

## 1. Registro de anomalías — bloquea la implementación

Antes de escribir código, estas entradas tienen que existir en
`specs/000-reconocimiento/registro-de-anomalias.md` (Principio II, ver R19):

- [ ] **A-108** — el `403` de cuenta desactivada deja de distinguirse (FR-012).
- [ ] **A-109** — los dos textos de la spec 091 cambian (D7, D8).
- [ ] **A-110** — el éxito del reset navega a `/login`; el aviso de host no reconocido se
      extiende a las otras dos pantallas (FR-031, FR-009).
- [ ] **A-111** — **HALLAZGO**: el enlace de recuperación no está atado al host, así que FR-037
      no se puede cumplir sin tocar el servidor (ver paso 8).

A-111 además **necesita respuesta del negocio** antes de dar la spec por completa. No bloquea el
resto del trabajo.

---

## 2. Verificación del contexto y del cascarón (FR-001 a FR-010)

| # | Abrir | Esperado |
|---|---|---|
| 2.1 | `negocioa.localhost:4200/login` | Logotipo, insignia `negocioa`, título "Bienvenido de nuevo.", formulario, pie con el año actual y "Política de privacidad" |
| 2.2 | la misma URL, pestaña **Red** del navegador abierta, recarga | **Ninguna** petición al API antes de enviar el formulario (SC-011, SC-012) |
| 2.3 | `admin.localhost:4200/login` | Insignia "Administración de la plataforma"; **ningún** slug de negocio |
| 2.4 | `localhost:4200/login` y `www.localhost:4200/login` | "No encontramos este negocio" + enlace al sitio; **sin** formulario; **cero** peticiones |
| 2.5 | `localhost:4200/forgot-password` y `localhost:4200/reset-password?token=x` | El mismo aviso, sin formulario y **sin** petición de validación (R6 — hoy sí se renderizarían) |
| 2.6 | `inventado.localhost:4200/login`, enviar cualquier credencial | El formulario se muestra y el error es "Credenciales inválidas" (FR-009a, D12) |
| 2.7 | las tres pantallas | La insignia aparece **ya con su texto**: ni "Cargando", ni cambio posterior (FR-007c) |
| 2.8 | el enlace "Política de privacidad" del pie | Abre `https://skeilopos.com/privacidad` y la página responde (FR-003a) |

**Etiqueta sin retoques** (FR-007): prueba con un slug compuesto, p. ej.
`granizados-del-sol.localhost:4200/login` → la insignia debe decir `granizados-del-sol`, **no**
"Granizados Del Sol". Y con un slug largo
(`un-negocio-con-nombre-larguisimo.localhost:4200`) → se recorta con elipsis, el formulario no
se mueve y el valor completo aparece al pasar el puntero.

---

## 3. Historia 1 — Entrar al sistema (P1)

| # | Hacer | Esperado | Requisito |
|---|---|---|---|
| 3.1 | Enviar el formulario vacío | Error por campo; **cero** peticiones en la pestaña Red | FR-014 |
| 3.2 | Correo válido + contraseña mala | "Credenciales inválidas"; el correo **sigue escrito**; el campo de contraseña está **vacío y con el foco** (pulsa una tecla y comprueba que entra ahí) | FR-012, FR-013 |
| 3.3 | **Credenciales correctas de la cuenta desactivada** | "Credenciales inválidas" — **nunca** "User account is inactive" ni nada en inglés | FR-012, SC-003, R7 |
| 3.4 | Correo inexistente | Mensaje **idéntico, carácter por carácter**, al de 3.2 y 3.3 | SC-003 |
| 3.5 | Credenciales válidas, pulsar el botón 3 veces rápido | Botón deshabilitado con indicador de progreso y **exactamente una** petición a `/auth/login` en la pestaña Red | FR-015, SC-009 |
| 3.6 | Entrar como cajero, mesero, administrador y super admin | Cada uno llega a la **misma** pantalla inicial que antes del rediseño, con los mismos permisos | FR-018, FR-019, SC-008 |
| 3.7 | Abrir `/dashboard/inventario` sin sesión, entrar | Se llega a `/dashboard/inventario`, no a la pantalla inicial del rol | FR-018 |
| 3.8 | Pulsar el ojo de la contraseña **con Tab y Enter**, sin ratón | Alterna oculto/visible; el lector anuncia "Mostrar/Ocultar contraseña" | FR-016, FR-040, R9 |
| 3.9 | Enfocar los campos con un gestor de contraseñas | Ofrece correo y contraseña actual | FR-017 |
| 3.10 | Cronometrar desde que la pantalla carga hasta estar dentro | Menos de 20 s en escritorio y en móvil | SC-001 |

### El control inerte (FR-019a a FR-019e, SC-013)

| # | Hacer | Esperado |
|---|---|---|
| 3.11 | Marcar "Mantener sesión iniciada" e iniciar sesión con la pestaña Red abierta | El cuerpo de `POST /auth/login` es **exactamente** `{"email":…,"password":…}` — ningún campo más (FR-019c) |
| 3.12 | Comparar la expiración del token con y sin marcar | Idéntica (FR-019b, SC-013). Inspecciona el `exp` del JWT en Application → Local Storage |
| 3.13 | Revisar `localStorage`, `sessionStorage`, `IndexedDB` y cookies tras iniciar sesión marcado | **Ninguna** contraseña ni dato derivado de ella (FR-019d, SC-013) |
| 3.14 | Leer la etiqueta del control | Dice "Mantener sesión iniciada"; **no** menciona recordar ni guardar contraseñas (FR-019e, D3a) |
| 3.15 | Alcanzar el control solo con Tab y marcarlo con Espacio | Funciona, con foco visible (FR-019a, FR-040) |

---

## 4. Historia 2 — Pedir el enlace (P2)

| # | Hacer | Esperado | Requisito |
|---|---|---|---|
| 4.1 | Desde el login, pulsar "¿Olvidaste tu contraseña?" | Llega a la pantalla con el título "Restablece tu contraseña." | US2-1 |
| 4.2 | Enviar un correo que **existe** | Mensaje genérico, con la caducidad de 30 minutos, en forma condicional ("Si existe una cuenta con …") | FR-020 |
| 4.3 | Enviar un correo que **no existe** | Mensaje **idéntico** al de 4.2 salvo el correo que escribiste | FR-020, SC-003 |
| 4.4 | Observar el control de reenvío tras enviar | Deshabilitado, con cuenta regresiva visible que baja de 60 a 0; luego se habilita | FR-021 |
| 4.5 | **Recargar** con 40 s pendientes | El instante de vencimiento sobrevive y **no** se reinicia a 60 — pero la pantalla vuelve al **formulario**, no a la confirmación (ver nota) | FR-022 |
| 4.6 | Pasar la pestaña a segundo plano 70 s y volver | El control está **habilitado**; la cuenta no se alargó | FR-022 |
| 4.7 | Enviar 4 veces el mismo correo (el límite es 3/900 s) | Al cuarto: "Hiciste demasiados intentos. Vuelve a intentarlo más tarde." sin revelar nada de la cuenta | FR-023, FR-024 |
| 4.8 | Apagar la red y enviar | El botón sale del estado de carga, aparece un mensaje y se puede reintentar | *edge case* |
| 4.9 | "Volver a iniciar sesión" desde el formulario y desde la confirmación | Vuelve al `/login` **del mismo subdominio** (la URL conserva `negocioa.`) | FR-025 |

> **Nota sobre 4.5 — conflicto entre dos artefactos de esta misma spec, resuelto al implementar.**
> El paso estaba redactado esperando que, tras recargar, siguiera visible la pantalla de
> confirmación con su cuenta regresiva. Eso **no se puede hacer** sin guardar también el correo que
> el usuario escribió, porque el mensaje de confirmación lo nombra ("Si existe una cuenta con
> …") — y [data-model.md](./data-model.md) §3 lo prohíbe expresamente: el bloqueo guarda
> *"un número, nunca el correo"*, sin ningún dato personal (R10).
>
> Entre las dos reglas manda la del dato personal, así que lo implementado es: **el instante de
> vencimiento sobrevive a la recarga** (se relee de `sessionStorage` al montar y la cuenta regresiva
> se calcula contra el reloj, nunca decrementando un contador), pero la pantalla vuelve al estado de
> formulario. Lo que FR-022 protege de verdad —que el bloqueo no se alargue en segundo plano ni se
> reinicie a 60— se mantiene, y lo verifican los tests F3 y F4 de
> `forgot-password.component.spec.ts`. Que desde el formulario se pueda pedir otro enlace es
> inofensivo por **FR-024**: el bloqueo de 60 s es una ayuda de interfaz y el límite real (3 por
> 900 s, por negocio y cuenta) lo aplica el servidor, que esta spec no toca.

---

## 5. Historia 3 — Crear la contraseña nueva (P2)

Para conseguir un enlace: pide uno en el paso 4 y lee el correo que el backend encola, o toma el
token de la tabla `password_reset_tokens` del entorno de desarrollo.

| # | Hacer | Esperado | Requisito |
|---|---|---|---|
| 5.1 | Abrir el enlace vigente | Título "Crea tu nueva contraseña.", dos campos y la lista de requisitos | US3-1 |
| 5.2 | Leer la lista | Dice "Mínimo 8 caracteres" **y** "Máximo 12 caracteres"; **no** pide mayúsculas ni números | FR-027, FR-029, D4 |
| 5.3 | Escribir `abc` y luego `abcdefgh` | Cada requisito cambia de estado al escribir, con **ícono y texto**, no solo color | FR-027, FR-028 |
| 5.4 | Lo mismo, con lector de pantalla | Se anuncia el cambio de cada requisito, con "(cumplido)"/"(pendiente)" | FR-028, FR-041 |
| 5.5 | Escribir 13 caracteres | El requisito del máximo se marca pendiente y el envío no pasa | FR-029 |
| 5.6 | Contraseña válida + confirmación distinta | Error de no coincidencia; **cero** peticiones | FR-030 |
| 5.7 | Contraseña igual a la actual | Error de "distinta de la actual"; la contraseña no cambia | FR-033, US3-7 |
| 5.8 | Contraseña válida y confirmación igual | Llega a `/login` con el aviso **"Contraseña actualizada"** (ya no se queda en la pantalla de reset) | FR-031 |
| 5.9 | Recargar `/login` después | El aviso **no** reaparece | R12 |
| 5.10 | Iniciar sesión con la contraseña vieja en otro navegador que tenía sesión abierta | La sesión anterior está cerrada | FR-033 |
| 5.11 | Volver a abrir el **mismo** enlace | "Este enlace ya no es válido" + "Solicitar un enlace nuevo"; **sin** formulario | FR-032 |
| 5.12 | Abrir un enlace caducado y uno inventado | **El mismo** mensaje que 5.11 — los cuatro motivos colapsan en uno | FR-032 |
| 5.13 | Abrir `/reset-password` **sin** `?token=` | El mismo mensaje, y **ninguna** petición en la pestaña Red | *edge case* |
| 5.14 | Abrir el enlace, esperar sin enviar, y enviar después | Funciona: la validación de carga **no** consumió el enlace | FR-034 |
| 5.15 | Pedir un enlace nuevo y luego abrir el anterior | El anterior ya no sirve | *edge case* |

---

## 6. Historia 4 — Cualquier dispositivo (P3)

| # | Hacer | Esperado | Requisito |
|---|---|---|---|
| 6.1 | Las tres pantallas a 1280 px | Dos columnas: formulario a la izquierda, panel con "Tu negocio. Más rápido." y la vista previa a la derecha | FR-001, FR-004 |
| 6.2 | Las tres a 1023 px, **con la pestaña Red filtrada por `Img`** y caché deshabilitada | El panel no se muestra **y `auth-preview.webp` no aparece en la lista de peticiones** | FR-005, SC-007 |
| 6.3 | Las tres a 360 px | **Cero** desplazamiento horizontal; formulario y pie completos y alcanzables | FR-006, SC-006 |
| 6.4 | Barrer de 360 a 1920 px | Nada se corta ni se desborda en todo el rango | SC-006 |
| 6.5 | Renombrar temporalmente `auth-preview.webp` y recargar a 1280 px | El panel conserva color y texto; sin hueco roto ni layout partido | *edge case* |
| 6.6 | Recorrer cada pantalla **solo con Tab** | El orden sigue el orden visual, cada elemento muestra foco visible, y se puede llegar a todo y activarlo | FR-039, FR-040, SC-004 |
| 6.7 | Recorrer con lector de pantalla | Cada campo anuncia su etiqueta; errores y estados se anuncian al aparecer | FR-038, FR-041, SC-004 |
| 6.8 | Medir los controles en el inspector | Alto efectivo ≥ 44 px en botones, enlaces de acción, casilla y ojo | FR-043 |
| 6.9 | Cambiar la fecha del sistema al 1 de enero siguiente y recargar | El pie muestra el año nuevo | *edge case* |

---

## 7. Aislamiento por negocio (FR-035, FR-036)

| # | Hacer | Esperado |
|---|---|---|
| 7.1 | Usar en `negociob.localhost` las credenciales válidas de `negocioa` | "Credenciales inválidas" |
| 7.2 | Pedir un enlace en `negociob` con el correo de un usuario de `negocioa` | Mensaje genérico y **ningún** correo enviado (el backend no encuentra la cuenta en ese tenant) |
| 7.3 | Pedir y usar el enlace del super administrador desde `admin.localhost` | Funciona |

---

## 8. ⚠️ FR-037 — se verifica el hallazgo, no el requisito

| # | Hacer | Lo que **va a pasar hoy** |
|---|---|---|
| 8.1 | Emitir un enlace para un usuario de `negocioa` y abrirlo cambiando el host a `negociob.localhost:4200/reset-password?token=…` | **El enlace valida y permite fijar la contraseña** (de la cuenta de `negocioa`) |
| 8.2 | Lo mismo con `admin.localhost` | Igual |

**Esto no es un fallo de la implementación de esta spec**: el token se resuelve solo por su hash,
sin mirar el host, y cerrarlo exige modificar dos endpoints — lo que FR-044 prohíbe
expresamente. Ver **R18** de [research.md](./research.md). **La decisión ya está tomada**: D13
(Leonardo Gómez, 2026-10-05) acepta la limitación y FR-037 quedó reformulado como tal. Lo que hay
que hacer en este paso es **documentar el resultado observado en la entrada A-111** del registro de
anomalías, junto a esa decisión. SC-010 ya está redactada sin la cláusula de subdominio: sus tres
cláusulas vigentes se comprueban en 5.11 y 5.12.

---

## 9. Auditoría de accesibilidad (SC-005, FR-042)

Para cada una de las tres pantallas, en escritorio y a 390 px:

1. DevTools → Lighthouse → categoría **Accessibility** → analizar.
2. Revisar específicamente: contraste de texto, contraste de bordes de campo y de textos de
   ayuda, etiquetas de formulario, nombres accesibles de los botones.
3. **Criterio de cierre**: ningún incumplimiento de contraste ni de etiquetado de campos.

Estados que hay que auditar además del inicial, porque son los que suelen fallar: el error de
login visible, la lista de requisitos con un ítem cumplido y otro pendiente, y el control de
reenvío deshabilitado con su cuenta regresiva (el texto deshabilitado es el sospechoso habitual
de contraste insuficiente).

---

## 10. Regresión (Principios II, III, X)

```bash
cd pos-heladeria && npm test        # compara con la línea base del paso 0
cd pos-heladeria && npm run build   # debe pasar
```

| # | Comprobar | Requisito |
|---|---|---|
| 10.1 | El conteo de fallos de la suite es **igual o menor** que la línea base | Principio X |
| 10.2 | Los dos tests de `login.component.spec.ts` que cambian son **solo** los de los textos de D7 y D8; las aserciones de "sin formulario" y "sin llamadas al API" quedan intactas | R16, FR-045 |
| 10.3 | Las tres pantallas fuera de alcance que usan `app-password-input` (`/change-password`, ajustes de cuenta, formulario de usuario admin) siguen funcionando, ahora con el ojo alcanzable por teclado | R9, Principio V |
| 10.4 | `pos-backend` no tiene **ningún** cambio: `git status` limpio en ese repositorio | **FR-044** |
| 10.5 | Los characterization tests de autenticación del backend no se tocaron **y se corrieron una vez en verde** (T061a) | FR-045, R17 |
| 10.6 | `login-panel.svg` quedó eliminado y nada lo referencia | R2 |

---

## 11. Lista de cierre

- [ ] A-108, A-109, A-110 y A-111 registradas **antes** de implementar (paso 1).
- [ ] Pasos 2 a 7 recorridos completos, con las URLs de subdominio reales (no `localhost` pelado).
- [ ] Paso 8 ejecutado y su resultado escrito en A-111, junto a la decisión de D13 (ya tomada).
- [ ] Auditoría del paso 9 sin incumplimientos de contraste ni de etiquetado.
- [ ] `npm test` y `npm run build` en verde respecto de la línea base.
- [ ] `pos-backend` sin un solo cambio.
- [ ] Commits pequeños, en inglés, sin marcas de asistencia de IA, en la rama
      `style/095-auth-screens-redesign` (Principios XIV y XV) — y **solo** cuando el usuario los
      pida.
