-- ============================================================================
-- Spec 119 (US6) — Siembra de datos de volumen para la verificación manual SC-010.
--
-- SOLO PARA UN TENANT DESECHABLE. Nunca ejecutar contra un tenant real: inserta
-- cientos de miles de ventas y un millón de pedidos ficticios. Todo lo creado lleva
-- el prefijo "[119-vol]" en el nombre y se elimina borrando el tenant al terminar.
--
-- Uso (desde psql, con el esquema del tenant desechable ya migrado a `head`):
--
--   psql -v ON_ERROR_STOP=1 -v schema=<esquema_del_tenant> \
--        [-v start_date=2026-01-01] [-v days=365] [-v sales_per_shift=150] \
--        [-v orders_hist=1000000] [-v freeze=1] [-v only_freeze=1] -f quickstart-volume.sql
--
-- Parámetros (todos opcionales salvo `schema`):
--   start_date       primer día sembrado (fecha local del tenant; los turnos se
--                    siembran a las 08:00 y 18:00 hora de Colombia, UTC-5).
--   days             días consecutivos. Con 365 días desde 2026-01-01 el mes de
--                    octubre de 2026 contiene exactamente 186 turnos (3 cajas x 2
--                    turnos/día x 31 días), que es el período de medición de SC-010.
--   sales_per_shift  ventas pagadas por turno (cada 50ª queda anulada).
--   orders_hist      pedidos históricos terminales (pagada/cancelada). Se añaden
--                    además 6 pedidos activos (recibida/abierta/bloqueada).
--   freeze=1         congela TODOS los turnos sembrados como lo haría `close_shift`
--                    (cabecera + desglose por producto y por categoría). Sin él,
--                    todos los turnos quedan "sin snapshot" (peor caso, como los D8).
--   only_freeze=1    NO siembra nada: solo congela los turnos ya sembrados (implica
--                    freeze). Permite medir primero el peor caso (sin snapshot) y luego
--                    el caso con snapshot sobre exactamente los mismos datos. Es
--                    idempotente: no vuelve a congelar un turno que ya tiene cabecera.
--
-- Requiere que ya existan las tablas hijas de snapshot de la spec 119 (migración
-- `shift_sales_report_products` / `shift_sales_report_categories`) solo si se congela.
-- ============================================================================
\if :{?start_date} \else \set start_date 2026-01-01 \endif
\if :{?days} \else \set days 365 \endif
\if :{?sales_per_shift} \else \set sales_per_shift 150 \endif
\if :{?orders_hist} \else \set orders_hist 1000000 \endif
\if :{?freeze} \else \set freeze 0 \endif
\if :{?only_freeze} \else \set only_freeze 0 \endif
\if :only_freeze \set freeze 1 \endif

SET search_path = :"schema";

\if :only_freeze
\echo 'only_freeze=1: se omite la siembra; solo se congelan los turnos ya sembrados.'
\else

-- ---- Catálogo mínimo: 8 categorías, 1 presentación, 80 productos con 1 variante cada uno ----
INSERT INTO categories (id, name, active, display_order)
SELECT gen_random_uuid(), '[119-vol] Categoria ' || g, true, g FROM generate_series(1, 8) g;

INSERT INTO presentations (id, name) VALUES (gen_random_uuid(), '[119-vol] Unidad');

CREATE TEMP TABLE vol_variants (n int, id uuid, description text);
WITH cats AS (
  SELECT id, row_number() OVER (ORDER BY name) AS rn FROM categories WHERE name LIKE '[119-vol]%'
), prods AS (
  INSERT INTO products (id, category_id, name, active)
  SELECT gen_random_uuid(), c.id, '[119-vol] Producto ' || lpad(g::text, 3, '0'), true
  FROM generate_series(1, 80) g JOIN cats c ON c.rn = 1 + (g % 8)
  RETURNING id, name
), vars AS (
  INSERT INTO product_variants (id, product_id, presentation_id, active, display_order, price)
  SELECT gen_random_uuid(), p.id, (SELECT id FROM presentations WHERE name = '[119-vol] Unidad'), true, 1, 5000
  FROM prods p
  RETURNING id, product_id
)
INSERT INTO vol_variants
SELECT row_number() OVER (ORDER BY p.name), v.id, p.name
FROM vars v JOIN prods p ON p.id = v.product_id;

-- ---- 3 cajas, 2 turnos por día y caja (todos cerrados) ----
CREATE TEMP TABLE vol_regs (n int, id uuid);
INSERT INTO vol_regs SELECT g, gen_random_uuid() FROM generate_series(1, 3) g;
INSERT INTO cash_registers (id, name, active) SELECT id, '[119-vol] Caja ' || n, true FROM vol_regs;

INSERT INTO cash_shifts (id, cash_register_id, user_id, user_name, opening_amount, opened_at, closed_at, status)
SELECT gen_random_uuid(), r.id, gen_random_uuid(), '[119-vol] Cajero', 1,
       -- 08:00 y 18:00 hora de Colombia (UTC-5) expresadas en UTC naive, como guarda la app.
       (:'start_date'::date + d) + CASE WHEN s = 0 THEN interval '13 hours' ELSE interval '23 hours' END,
       (:'start_date'::date + d) + CASE WHEN s = 0 THEN interval '21 hours' ELSE interval '31 hours' END,
       'closed'
FROM vol_regs r CROSS JOIN generate_series(0, :days - 1) d CROSS JOIN generate_series(0, 1) s;

-- ---- Ventas (3 líneas cada una) ----
INSERT INTO sales (id, cash_shift_id, user_id, user_name, customer_name, subtotal, total, status, sold_at)
SELECT gen_random_uuid(), cs.id, gen_random_uuid(), '[119-vol] Cajero', 'Mostrador',
       5000 + (g % 40) * 500, 5000 + (g % 40) * 500,
       CASE WHEN g % 50 = 0 THEN 'void' ELSE 'paid' END,
       cs.opened_at + (g || ' minutes')::interval
FROM cash_shifts cs CROSS JOIN generate_series(1, :sales_per_shift) g
WHERE cs.cash_register_id IN (SELECT id FROM vol_regs);

INSERT INTO sale_items (id, sale_id, product_variant_id, description, quantity, unit_price, line_total)
SELECT gen_random_uuid(), sa.id, v.id, v.description,
       1 + (abs(hashtext(sa.id::text || g::text)) % 3),
       4000 + (abs(hashtext(sa.id::text || g::text)) % 20) * 500,
       4000 + (abs(hashtext(sa.id::text || g::text)) % 20) * 500
FROM sales sa
JOIN cash_shifts cs ON cs.id = sa.cash_shift_id AND cs.cash_register_id IN (SELECT id FROM vol_regs)
CROSS JOIN generate_series(1, 3) g
JOIN vol_variants v ON v.n = 1 + (abs(hashtext(sa.id::text || g::text)) % 80);

-- ---- Pedidos: historial terminal masivo + 6 activos ----
INSERT INTO customer_orders (id, status, customer_name, created_at)
SELECT gen_random_uuid(), CASE WHEN g % 9 = 0 THEN 'cancelada' ELSE 'pagada' END,
       '[119-vol] cliente ' || g, now() - (g || ' minutes')::interval
FROM generate_series(1, :orders_hist) g;
INSERT INTO customer_orders (id, status, customer_name, created_at)
SELECT gen_random_uuid(), (ARRAY['recibida', 'abierta', 'bloqueada'])[1 + g % 3],
       '[119-vol] activo ' || g, now() - (g || ' minutes')::interval
FROM generate_series(1, 6) g;

-- fin de la siembra (omitida con only_freeze=1)
\endif

-- ---- Opcional: congelar todos los turnos sembrados (equivale a haber cerrado cada uno con la app) ----
-- Se identifican por `user_name = '[119-vol] Cajero'` y se omiten los que ya tienen cabecera.
\if :freeze
DROP TABLE IF EXISTS pg_temp.vol_to_freeze;
CREATE TEMP TABLE vol_to_freeze AS
SELECT cs.id FROM cash_shifts cs
WHERE cs.user_name = '[119-vol] Cajero'
  AND NOT EXISTS (SELECT 1 FROM shift_sales_reports h WHERE h.cash_shift_id = cs.id);

INSERT INTO shift_sales_reports (id, cash_shift_id, total_sales, order_count, avg_ticket)
SELECT gen_random_uuid(), sa.cash_shift_id, sum(sa.total), count(*), round(avg(sa.total), 2)
FROM sales sa
WHERE sa.status = 'paid' AND sa.cash_shift_id IN (SELECT id FROM vol_to_freeze)
GROUP BY sa.cash_shift_id;

INSERT INTO shift_sales_report_products (id, cash_shift_id, product_variant_id, name, units, revenue)
SELECT gen_random_uuid(), sa.cash_shift_id, si.product_variant_id, max(si.description), sum(si.quantity), sum(si.line_total)
FROM sales sa JOIN sale_items si ON si.sale_id = sa.id
WHERE sa.status = 'paid' AND sa.cash_shift_id IN (SELECT id FROM vol_to_freeze)
GROUP BY sa.cash_shift_id, si.product_variant_id;

INSERT INTO shift_sales_report_categories (id, cash_shift_id, category_id, category_name, units, revenue)
SELECT gen_random_uuid(), sa.cash_shift_id, c.id, c.name, sum(si.quantity), sum(si.line_total)
FROM sales sa JOIN sale_items si ON si.sale_id = sa.id
JOIN product_variants pv ON pv.id = si.product_variant_id
JOIN products p ON p.id = pv.product_id
JOIN categories c ON c.id = p.category_id
WHERE sa.status = 'paid' AND sa.cash_shift_id IN (SELECT id FROM vol_to_freeze)
GROUP BY sa.cash_shift_id, c.id, c.name;
\endif

ANALYZE;

\echo '--- Resumen de lo sembrado ---'
SELECT 'turnos' AS tabla, count(*) FROM cash_shifts WHERE user_name = '[119-vol] Cajero'
UNION ALL SELECT 'ventas', count(*) FROM sales WHERE user_name = '[119-vol] Cajero'
UNION ALL SELECT 'lineas', count(*) FROM sale_items WHERE description LIKE '[119-vol]%'
UNION ALL SELECT 'pedidos', count(*) FROM customer_orders WHERE customer_name LIKE '[119-vol]%';
