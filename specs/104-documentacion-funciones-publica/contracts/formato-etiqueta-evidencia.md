# Contrato: formato de la etiqueta de evidencia

Toda afirmación del SRS (y de los artefactos intermedios `inventario-backend.md`,
`inventario-frontend.md`, `cruce-front-back.md`) lleva **exactamente una** de estas tres etiquetas,
inmediatamente después de la oración o al final de la celda de tabla que la contiene. Esta es la
única sintaxis válida (Decisión 3 de `research.md`).

## `[CÓDIGO: <ruta>:<línea-o-rango>]`

- `<ruta>` es siempre relativa a `pos-backend/` o `pos-heladeria/` (nunca una ruta absoluta de
  disco local, para que el documento sea legible desde cualquier checkout).
- `<línea-o-rango>` es un número (`112`) o un rango (`112-130`) correspondiente a la versión del
  código analizada en el momento de la cita.
- Ejemplo: `El endpoint exige rol "cashier" o "admin" [CÓDIGO: pos-backend/app/api/v1/orders/router.py:118]`.
- Uso: cuando la afirmación es una lectura directa del código fuente (decorador, validación,
  columna de modelo, test existente).

## `[INFERIDO: <motivo>]`

- `<motivo>` es una frase corta que explica de dónde se deduce la afirmación cuando no hay una
  línea de código que la declare literalmente (p. ej. un comportamiento que se desprende del tipo
  de una columna, de la ausencia de un manejador de error, o de un patrón repetido en varios
  módulos).
- Ejemplo: `El campo acepta valores nulos tras el pago [INFERIDO: la columna no tiene restricción NOT NULL y no existe validación de servicio que la exija]`.
- Uso: cuando hay evidencia indirecta suficiente para una afirmación razonable, pero no una cita
  literal de una sola línea.

## `[PREGUNTA → C-xx]`

- Remite siempre al identificador numerado de una entrada del Apéndice C (`srs/apendices/c-preguntas-abiertas.md`).
- Ejemplo: `El límite de peticiones por minuto del endpoint de checkout [PREGUNTA → C-04]`.
- Uso: cuando no hay evidencia de código suficiente ni para `[CÓDIGO]` ni para `[INFERIDO]` — la
  afirmación no se escribe como hecho ni como inferencia, se convierte en pregunta abierta.

## Regla de no-excepción

Ninguna oración declarativa sobre el comportamiento del sistema queda sin una de estas tres
etiquetas. Las oraciones puramente estructurales (encabezados, introducciones de sección, frases
de transición sin contenido verificable) no requieren etiqueta. La verificación por muestreo de
esta regla está en `quickstart.md` § Verificación de etiquetado (SC-002).
