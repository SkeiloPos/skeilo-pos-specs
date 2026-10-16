-- Spec 121 (FR-028): verificación PREVIA a la migración. Solo lectura (BEGIN READ ONLY … ROLLBACK).
-- Uso: docker exec -i pos psql -U admin -d pos_db < quickstart-preflight.sql
-- Resultado esperado para poder migrar: fuera_de_catalogo=0 en TODOS los esquemas.
-- cantidad_cero > 0 no bloquea: esas filas se descartan en la migración (D-3).
\set ON_ERROR_STOP on
BEGIN READ ONLY;
DO $$
DECLARE s text; fuera int; ceros int; filas int;
BEGIN
  FOR s IN SELECT schema FROM shared.tenants ORDER BY schema LOOP
    IF to_regclass(format('%I.cash_count_denominations', s)) IS NOT NULL THEN
      EXECUTE format('SELECT count(*), count(*) FILTER (WHERE quantity = 0), count(*) FILTER (WHERE denomination NOT IN (100000,50000,20000,10000,5000,2000,1000,500,200,100,50)) FROM %I.cash_count_denominations', s) INTO filas, ceros, fuera;
      RAISE NOTICE 'esquema=% filas=% cantidad_cero=% fuera_de_catalogo=%', s, filas, ceros, fuera;
    END IF;
  END LOOP;
END $$;
ROLLBACK;
