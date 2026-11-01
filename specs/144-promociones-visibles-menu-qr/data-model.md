# Data Model: Visibilidad de promociones en el menú QR

## Entidades modificadas

### `Promotion` (tabla `tenant.promotions`)

| Campo | Tipo | Regla |
|---|---|---|
| `visible_en_qr` *(nuevo)* | `BOOLEAN NOT NULL` | `DEFAULT true` / `server_default="true"`. Independiente de `status` y de la vigencia (`starts_at`/`ends_at`/`days_of_week`/`start_time`/`end_time`). Editable vía `PATCH /promotions/{id}` sin importar el `status` actual (FR-001, FR-010). Al crear una promoción nueva sin indicarlo explícitamente, queda en `true` (FR-002). |

No se modifican `PromotionRule` ni `PromotionVariant` — la clarificación de la sesión
2026-10-29 fija que la visibilidad y la alcanzabilidad se evalúan a nivel de `Promotion`
completa, no por regla.

## Entidades no persistidas (cálculo derivado, no se guarda en DB)

### "Promoción alcanzable por QR" (predicado, no entidad)

Para una `Promotion` dada, es verdadero si y solo si existe al menos una fila en:

```
Promotion.rules (PromotionRule)
  → PromotionVariant.product_variant_id
  → ProductVariant (active = true)
  → Product (active = true, visible_en_qr = true)
  → Category (active = true, visible_en_qr = true)
```

Ver research.md §3. Este predicado se recalcula en cada consulta del menú QR y en cada
cálculo de descuento — no se cachea ni se persiste, igual que `active_variant_set_rules()`
hoy recalcula vigencia en cada llamada.

### "Promoción ofrecible por QR en este momento" (predicado compuesto, FR-005/FR-006)

```
vigente(promotion)                         # status == 'active' AND dentro de ventana
  AND promotion.visible_en_qr == true
  AND alcanzable_por_qr(promotion)         # ver predicado anterior
```

- La pestaña de promociones del menú QR se muestra si y solo si existe ≥1 `Promotion` del
  tenant que cumpla este predicado compuesto (FR-005, FR-006).
- El listado de anuncios de promoción del menú QR (`MenuPromotionAnnouncement[]`) contiene
  exactamente las promociones que cumplen este predicado, con todas sus reglas intactas (sin
  filtrar reglas individuales — FR-004).

## Relaciones (sin cambios de esquema, solo las que participan en el cálculo)

```
Promotion 1───* PromotionRule 1───* PromotionVariant *───1 ProductVariant *───1 Product *───1 Category
```

## Transiciones de estado

Sin cambios — `PROMOTION_STATUSES`/`PROMOTION_TRANSITIONS` (`draft→{active,finished}`,
`active→{paused,finished}`, `paused→{active,finished}`, `finished→{}`) no se modifican.
`visible_en_qr` es ortogonal a esta máquina de estados: puede cambiarse en cualquier estado
(FR-001, acceptance scenario 3 de US2), pero solo tiene efecto observable en el menú QR
cuando la promoción además está `active` y vigente.

## Compatibilidad con datos existentes

- Toda promoción ya existente en producción recibe `visible_en_qr = true` al aplicar la
  migración (mismo valor por defecto que tendría si se creara hoy), preservando el
  comportamiento actual de "toda promoción activa y vigente se anuncia en QR" hasta que un
  administrador decida ocultar alguna explícitamente.
- No se recalculan descuentos de pedidos u órdenes ya existentes; el predicado compuesto solo
  se evalúa en peticiones nuevas al menú QR y en pedidos/carritos nuevos o aún no enviados.

## Estrategia de rollback

`downgrade()` de la migración elimina la columna `visible_en_qr` de `tenant.promotions` en
cada schema de tenant. Revertir el código de filtrado (menu/router.py, motor de descuentos)
antes o junto con el downgrade — si el código filtrador queda desplegado sin la columna, la
consulta fallaría, por lo que el orden de rollback debe ser: revertir despliegue de código →
luego `alembic downgrade` (nunca al revés).
