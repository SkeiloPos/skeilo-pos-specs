# Contrato — Instantes de la API (FR-001, FR-002, FR-003)

**Regla**: todo instante que devuelve la API lleva **offset UTC explícito** (`2026-10-25T17:00:00+00:00`). La única
excepción son los campos de **hora de pared local** de promociones (FR-002).

**Mecanismo**: el tipo `UtcDatetime` ya existente (`pos-backend/app/core/timezone.py:36`). Un valor guardado sin zona
(UTC por convención) sale con `+00:00`; uno aware se convierte a UTC. No cambia la validación de entrada.

## 1. Inventario definitivo (obtenido del OpenAPI real, 2026-10-25)

16 esquemas de respuesta con `format: date-time` plano, que corresponden a **13 definiciones** a editar y **24 campos**.

> **Actualización 2026-10-26 (implementación).** Tras mergear en `develop` las specs de grupos de unidades, el OpenAPI real
> suma `UnitMeasureGroupResponse` (`created_at`, `updated_at`) y `FactorChangeResponse` (`changed_at`): **18 esquemas, 15 definiciones,
> 27 campos** (38 pares `Esquema.campo` en el OpenAPI, contando los 4 esquemas de productos que heredan; 36 sin la excepción
> de `PromotionResponse.starts_at`/`ends_at`). La prueba
> `test_contrato_instantes_api` fija el conjunto exacto; la tabla de abajo es la de la planificación.

| # | Esquema(s) de respuesta | Archivo (`pos-backend/app/api/v1/…`) | Campos | Se muestra en el frontend |
|---|---|---|---|---|
| 1 | `CategoryResponse` | `categories/schemas.py:84-85` | `created_at`, `updated_at` | no |
| 2 | `DinerPaymentAttempt` | `cart/schemas.py:204,209` | `created_at`, `cash_confirmed_at` | solo como verdadero/falso |
| 3 | `SessionOpenResponse` | `cart/schemas.py:36` | `expires_at` | no |
| 4 | `InvitationResponse` | `invitations/schemas.py:48` | `sent_at` | **sí** — «Enviada el…» |
| 5 | `ParticipantResponse` | `table_sessions/schemas.py:27` | `expires_at` | no |
| 6 | `PaymentMethodCatalogResponse` ★ | `super_admin/schemas.py:77-78` | `created_at`, `updated_at` | no |
| 7 | `TenantResponse` | `super_admin/schemas.py:99,102-103` | `plan_vence_en`, `created_at`, `updated_at` | **sí** — «Vence» |
| 8 | `PlanResponse` ★ | `super_admin/schemas.py:186-187` | `created_at`, `updated_at` | no |
| 9 | `PresentationResponse` | `presentations/schemas.py:31-32` | `created_at`, `updated_at` | no |
| 10 | `ProductResponse` → `ProductListResponse`, `ProductDetailResponse`, `ProductSaveResponse` (herencia) | `products/schemas.py:142,149-150` | `available_changed_at`, `created_at`, `updated_at` | **sí** — «agotado desde hace…» (`relativeTime`) |
| 11 | `PromotionResponse` | `promotions/schemas.py:252` | `closed_by_refactor_at` ★ | no |
| 12 | `UnitMeasureResponse` | `unit_measures/schemas.py:30-31` | `created_at`, `updated_at` | no |
| 13 | `UserResponse` | `users/schemas.py:40-41` | `created_at`, `updated_at` | no |

★ = **no figuraba** en la tabla D de `hallazgos.md` ni en la lista de A-148; se agrega a A-148 (tarea de documentación).
`plan_vence_en` de `TenantResponse` aparece también en `GET /plan` (resumen del plan del propio negocio) por otro
esquema que ya usa `UtcDatetime`.

## 2. Lista de excepciones (FR-002) — única

| Esquema | Campo | Por qué viaja sin offset |
|---|---|---|
| `PromotionResponse` | `starts_at` | hora de pared local del tenant (vigencia de la promoción) |
| `PromotionResponse` | `ends_at` | ídem |

`start_time` y `end_time` son `time` (`format: time`): no son instantes y la verificación no los considera. Los
esquemas de **entrada** (`PromotionCreate`, `PromotionUpdate`) no entran en la verificación porque solo se recorren los
alcanzables desde las respuestas.

## 3. Forma antes / después (ejemplo)

```jsonc
// GET /api/v1/products/{id}  — available_changed_at
// Antes (un navegador lo lee como hora LOCAL → 5 h de error en Bogotá)
"available_changed_at": "2026-10-25T17:00:00"
// Después (siempre el mismo instante)
"available_changed_at": "2026-10-25T17:00:00+00:00"
```

Un consumidor que ya trate el valor con `new Date(...)` obtiene ahora el instante correcto; uno que lo compensara a mano
no existe en `pos-heladeria` (buscado: `getTimezoneOffset`, `+ 'Z'`, `replace(' ', 'T')`).

## 4. Verificación automática (FR-003, SC-008)

`app/characterization_tests/test_contrato_instantes_api.py`:

1. Sustituye `app.core.db.initialize_database` por una función vacía y **luego** importa `app.main` (en caso contrario
   `create_app()` intenta conectar a PostgreSQL).
2. Obtiene `app.openapi()` y reúne los esquemas **alcanzables desde las respuestas** (cierre transitivo de `$ref`).
3. Para cada propiedad, recorre `anyOf/oneOf/allOf`; si algún nodo tiene `format == "date-time"`, la agrega al
   conjunto encontrado.
4. Falla si `encontrado − INSTANTES_SIN_OFFSET_PERMITIDOS` no está vacío, **indicando `Esquema.campo`**; y falla
   también si una entrada de la lista de excepciones **ya no existe** (evita que la lista se pudra).
5. Prueba de sensibilidad: un modelo mínimo con un `datetime` plano debe aparecer en el conjunto, y con `UtcDatetime`
   no (demuestra que el detector discrimina; es la prueba de «introducir a propósito un campo sin offset»).

**Detecta**: cualquier `datetime` de una respuesta con `response_model` (incluidos los anidados, los de `Page[T]` y los
heredados). **No detecta**: respuestas `dict`/`JSONResponse` sin `response_model` (auditadas a mano; ninguna con
instantes sin offset).

## 5. Compatibilidad

- **Hacia atrás**: el frontend desplegado hoy lee los instantes con offset sin cambios (el navegador respeta el
  offset). Para un cajero en Bogotá, la hora mostrada coincide con la del tenant.
- **Único cambio visible para Bogotá**: «producto agotado desde hace X» y «Enviada el…» dejan de estar desfasados 5 h
  (A-148; SC-005).
- **Consumidores**: el único consumidor de estos campos es `pos-heladeria`. `skeilo-pos-landing` queda fuera de alcance.
