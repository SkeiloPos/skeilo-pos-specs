# Contrato — Textos de las pantallas de autenticación

**Spec**: [../spec.md](../spec.md) | **Research**: [../research.md](../research.md) | **Fecha**: 2026-10-05

Los textos de estas tres pantallas no son decoración: son el mecanismo por el que la spec
cumple SC-003 (que ningún mensaje permita deducir si una cuenta existe). Por eso van en un
contrato propio, con la columna de **origen** para que se vea de dónde sale cada palabra, y para
que nadie los "mejore" sin darse cuenta de lo que rompe.

**Cómo leer la columna Origen**:
- **FR-xxx / D-x**: literal fijado por la spec. No se parafrasea.
- **mockup**: viene del diseño y ninguna FR lo contradice.
- **plan**: lo decide este plan porque la spec describe el contenido sin fijar la frase.

Todos los textos van en español de Colombia (Principio XIII), en tratamiento de "tú", que es el
que ya usan las pantallas actuales.

---

## 1. Transversal (cascarón)

| Elemento | Texto | Origen |
|---|---|---|
| `alt` del logotipo | `SkeiloPOS` | existente |
| Etiqueta, contexto de negocio | *(el identificador del subdominio, sin transformar)* | FR-007 |
| Etiqueta, contexto de plataforma | `Administración de la plataforma` | FR-008, D8 |
| Pie, copyright | `© {año} SkeiloPOS` | FR-003, mockup |
| Pie, enlace | `Política de privacidad` → `{publicSiteUrl}/privacidad` | FR-003, mockup |
| Panel de marca, lema | `Tu negocio. Más rápido.` | FR-004, mockup |
| Panel de marca, apoyo | `Del caos de las comandas en papel a la velocidad digital en un tap.` | mockup |

### Host no reconocido

| Elemento | Texto | Origen |
|---|---|---|
| Título | `No encontramos este negocio` | FR-009, D7 |
| Cuerpo | `Verifica la dirección e ingresa desde el enlace de tu negocio o desde el acceso de administración de la plataforma.` | plan (se conserva el cuerpo actual: D7 cambia el título, no la explicación) |
| Enlace | `Ir al sitio de SkeiloPOS` → `{publicSiteUrl}` | FR-009 (la spec pide "un enlace al sitio principal"; el rótulo lo fija el plan) |

**Reemplaza**: `Esta dirección no corresponde a ningún acceso` (spec 091). Cambio de redacción
autorizado por D7, registrado en A-109.

---

## 2. Inicio de sesión

| Elemento | Texto | Origen |
|---|---|---|
| Título | `Bienvenido de nuevo.` | US1-1, mockup |
| Subtítulo | `Inicia sesión para acceder a tu cuenta.` | mockup |
| Etiqueta del campo de correo | `Correo electrónico` | **FR-011a**, D1 |
| Marcador del campo de correo | `tucorreo@negocio.co` | mockup |
| Etiqueta del campo de contraseña | `Contraseña` | mockup |
| Marcador del campo de contraseña | `Escribe tu contraseña` | mockup |
| Control de visibilidad, oculta | `aria-label="Mostrar contraseña"` | FR-016, existente |
| Control de visibilidad, visible | `aria-label="Ocultar contraseña"` | FR-016, existente |
| Control de sesión | `Mantener sesión iniciada` | **D3a** |
| Enlace de recuperación | `¿Olvidaste tu contraseña?` | US2-1, mockup |
| Botón | `Iniciar sesión` | US1-1, mockup |
| Botón, en curso | `Ingresando…` | existente |
| Error de credenciales | `Credenciales inválidas` | **FR-012** |
| Error, correo vacío | `Escribe tu correo electrónico` | FR-014 |
| Error, correo con formato inválido | `Escribe un correo válido` | FR-014, existente |
| Error, contraseña vacía | `Escribe tu contraseña` | FR-014 |
| Aviso tras cambiar la contraseña | `Contraseña actualizada` | **FR-031** |

### Lo prohibido en esta pantalla

| No se puede escribir | Por qué |
|---|---|
| `Usuario o correo` | D1: el identificador es solo el correo (FR-011a) |
| `Recordar contraseña` | D3a: el sistema no guarda contraseñas (FR-019d, FR-019e) |
| `User account is inactive` ni "cuenta desactivada" ni "cuenta no encontrada" | FR-012, SC-003: un fallo, un mensaje |
| Cualquier variante que distinga correo inexistente de contraseña incorrecta | FR-012, SC-003 |

---

## 3. Solicitud de enlace

### Estado formulario

| Elemento | Texto | Origen |
|---|---|---|
| Título | `Restablece tu contraseña.` | US2-1, mockup |
| Subtítulo | `Escribe el correo de tu cuenta y te enviamos un enlace para crear una nueva.` | mockup |
| Etiqueta del campo | `Correo electrónico` | FR-011a (coherencia), FR-038 |
| Marcador | `tucorreo@negocio.co` | mockup |
| Botón | `Enviar enlace` | US2-1, mockup |
| Volver | `Volver a iniciar sesión` | FR-025, mockup |
| Error, correo vacío | `Escribe tu correo electrónico` | plan |
| Error, formato inválido | `Escribe un correo válido` | existente |
| Error, demasiados intentos (`429`) | `Hiciste demasiados intentos. Vuelve a intentarlo más tarde.` | **FR-023**, D5, R11 |
| Error de red | `No pudimos procesar la solicitud. Intenta de nuevo.` | *edge case* |

### Estado confirmación

| Elemento | Texto | Origen |
|---|---|---|
| Título | `Revisa tu correo.` | mockup |
| Cuerpo | `Si existe una cuenta con {correo}, enviamos un enlace para crear una contraseña nueva. El enlace caduca en 30 minutos.` | **FR-020** + mockup |
| Reenvío, habilitado | `Reenviar enlace` | FR-021, mockup |
| Reenvío, bloqueado | `Reenviar enlace en {n} s` | **FR-021** (la cuenta regresiva debe ser visible) |
| Volver | `Volver a iniciar sesión` | FR-025, mockup |

**El detalle que hace falta mirar dos veces**: el mockup dice *"Enviamos un enlace … a
correo@dominio"*, en indicativo. Eso **afirma** que la cuenta existe y rompe FR-020 y SC-003. El
texto adopta la forma condicional —"Si existe una cuenta con …"— y conserva el correo que el
usuario escribió, que no revela nada porque es dato suyo. La caducidad de 30 minutos sí se dice,
porque FR-020 la exige explícitamente, y coincide con la configuración verificada del servidor
(`PASSWORD_RESET_TOKEN_EXPIRY_MINUTES = 30`).

**El segundo detalle**: el mensaje de `429` **no** cita la ventana de tiempo ("en 15 minutos",
"por hora"), por D5 — el límite es configurable y el texto tiene que seguir siendo verdad si
cambia.

---

## 4. Contraseña nueva

### Estado verificando

| Elemento | Texto | Origen |
|---|---|---|
| Cuerpo (`role="status"`) | `Verificando el enlace…` | existente |

### Estado formulario

| Elemento | Texto | Origen |
|---|---|---|
| Título | `Crea tu nueva contraseña.` | US3-1, mockup |
| Subtítulo | `Debe cumplir estos requisitos:` | plan |
| Etiqueta, contraseña nueva | `Nueva contraseña` | US3-1, mockup |
| Etiqueta, confirmación | `Confirmar contraseña` | US3-1, mockup |
| Marcador, contraseña nueva | `Entre 8 y 12 caracteres` | FR-029, existente |
| Marcador, confirmación | `Repite la contraseña` | existente |
| Requisito 1 | `Mínimo 8 caracteres` | FR-029, mockup |
| Requisito 2 | `Máximo 12 caracteres` | **FR-029**, D4 (el mockup lo omite) |
| Sufijo para lector, cumplido | `(cumplido)` | FR-028, mockup |
| Sufijo para lector, pendiente | `(pendiente)` | FR-028, mockup |
| Botón | `Guardar contraseña` | mockup |
| Botón, en curso | `Guardando…` | existente |
| Error, no coincide | `Las contraseñas no coinciden` | FR-030, existente |
| Error, no cumple la política | `La contraseña debe tener entre 8 y 12 caracteres` | FR-029 |
| Error, igual a la actual | *(el que devuelve el servidor: `La nueva contraseña debe ser distinta de la actual`)* | FR-033, US3-7 |
| Volver | `Volver a iniciar sesión` | mockup |

### Estado enlace no válido

| Elemento | Texto | Origen |
|---|---|---|
| Título | `Este enlace ya no es válido` | **FR-032** |
| Cuerpo | `Pide uno nuevo para crear tu contraseña.` | plan |
| Botón | `Solicitar un enlace nuevo` | **FR-032** |

**Reemplaza** tres textos de hoy (`Este enlace caducó…`, `Este enlace ya fue usado…`,
`Este enlace no es válido…`) por uno solo, como fija FR-032. El motivo que devuelve el servidor
se sigue leyendo, pero ya no se traduce a texto visible.

### Lo prohibido en esta pantalla

| No se puede escribir | Por qué |
|---|---|
| `Para la cuenta correo@dominio` | El endpoint de validación no devuelve el correo y FR-044 prohíbe cambiarlo (R20) |
| `Una letra mayúscula`, `Un número` | D4: no están en la política vigente; mostrarlos exigiría contraseñas que el servidor no pide |
| `También te enviamos un correo de confirmación` | No verificado; prometer un correo que puede no salir (R20) |
| Cualquier requisito sin su máximo de 12 | D4: sin el máximo, el rechazo a los 13 caracteres es inexplicable |

---

## 4-bis. Los cuatro textos en los que el diseño y esta spec no coinciden

El 2026-10-05 el usuario pidió que las pantallas fueran **100 % fieles al diseño**. La estructura,
las medidas, los colores y las tipografías se trasladaron tal cual (ver R3 y R4, revocadas). **Cuatro
textos no**, porque cada uno está fijado por una decisión del propio usuario o por un límite técnico
verificado. Se listan aquí para que la diferencia sea visible y revisable, no para esconderla.

| Dice el diseño | Dice la implementación | Por qué no se copió |
|---|---|---|
| `Usuario o correo` | `Correo electrónico` | **D1**: la cuenta se identifica solo por correo (FR-011a). Ofrecer "usuario" prometería una forma de entrar que no existe |
| `Recordar contraseña` | `Mantener sesión iniciada` | **D3a** y FR-019e: el sistema **no guarda contraseñas**. La tabla "Lo prohibido en esta pantalla" lo veta expresamente |
| `Enviamos un enlace … a {correo}` | `Si existe una cuenta con {correo}, enviamos…` | **FR-020 y SC-003**: el indicativo afirma que la cuenta existe y permite averiguar qué correos están registrados probándolos |
| `Para la cuenta {correo}` (contraseña nueva) | `Debe cumplir estos requisitos:` | **R20**: el endpoint de validación **no devuelve el correo**, y FR-044 prohíbe modificarlo. No se puede mostrar un dato que el servidor no da |

**Tres diferencias menores más**, estas sin decisión detrás, donde sí se siguió el diseño: los
marcadores de los campos de contraseña nueva (`Escribe tu nueva contraseña` / `Repite tu nueva
contraseña`) y la insignia, que muestra el identificador del subdominio en vez del nombre comercial
del mockup (`Granizados Del Sol`), porque **D2** prohíbe exponer datos del negocio sin autenticar.

El estado `Contraseña actualizada.` que el diseño resuelve con una pantalla propia tampoco existe:
**FR-031** lo manda a `/login` como aviso, y el diseño añadía además "También te enviamos un correo
de confirmación", que **R20** descartó por no estar verificado.

---

## 5. Reglas que cualquier texto nuevo debe respetar

1. **Un fallo de autenticación, un mensaje** (FR-012, SC-003). Correo inexistente, contraseña
   mala y cuenta desactivada se ven exactamente igual.
2. **Una solicitud de enlace, un mensaje** (FR-020, SC-003), en forma condicional. Nunca se
   afirma que el correo salió.
3. **Ninguna ventana de tiempo del servidor se cita** salvo la caducidad de 30 minutos, que la
   spec fija expresamente (FR-020, D5).
4. **Ningún texto afirma que se guarda la contraseña o que la sesión dura más** (FR-019e, D3a).
   El control se llama "Mantener sesión iniciada" y no promete nada más que su propia presencia.
5. **El estado nunca se comunica solo por color** (FR-028): si hay color, hay además ícono y
   texto.
6. **Ningún texto expone datos del negocio** más allá del identificador que el visitante ya
   tecleó (FR-007b, D2).
