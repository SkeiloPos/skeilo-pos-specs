# Quickstart: validar la eliminación de `dimension`

Prerrequisitos: entorno local de `pos-backend` con Postgres disponible (ver memoria del
proyecto: usar el venv de `pos-backend`, Postgres local sí está disponible) y `pos-heladeria`
con dependencias instaladas.

## 1. Backend — tests automatizados

```bash
cd ../pos-backend
<venv>/bin/pytest app/characterization_tests/test_core_units.py -v
```

Resultado esperado: todos los tests pasan, incluido el que ahora hace `assertNotIn("dimension",
UnitMeasure.__table__.columns.keys())` (invertido respecto al comportamiento anterior, ver
`data-model.md` y Constitution Check del `plan.md`).

## 2. Backend — script de integración de conversión de compras

```bash
cd ../pos-backend
<venv>/bin/python app/scripts/test_purchase_unit_conversion.py
```

Resultado esperado: el script corre sin errores, incluidas las llamadas a `list_unit_measures`
ya actualizadas para filtrar por `group_id` en vez de `dimension`.

## 3. Backend — migración

```bash
cd ../pos-backend
alembic upgrade head      # aplica la nueva migración 139
alembic downgrade -1      # revierte; confirmar que `dimension` reaparece con el valor
                           # correcto (igual a group.name) para una unidad conocida
alembic upgrade head      # vuelve a aplicar antes de continuar trabajando
```

Verificación manual: tras el `downgrade -1`, consultar en la BD que `unit_measures.dimension`
coincide con `unit_measure_groups.name` para cada fila (ver `data-model.md` §Migración).

## 4. Frontend — typecheck/build

```bash
cd ../pos-heladeria
npm run build   # o el comando de typecheck configurado en el proyecto
```

Resultado esperado: sin errores de compilación — confirma que no quedan referencias a
`UnitMeasure.dimension` en `pos-heladeria`.

## 5. Frontend — flujo manual

1. Levantar `pos-heladeria` apuntando al backend local.
2. Ir al formulario de compra de inventario (`purchase-form.component.ts`) y agregar una línea
   de compra para un insumo con varias unidades convertibles en su grupo (p. ej. gramo/kilo).
3. Confirmar que el selector de unidades sigue mostrando solo las unidades del mismo grupo que
   la unidad base del insumo — mismo comportamiento que antes del cambio, ahora resuelto
   comparando `group_id` en vez de `dimension`.

## 6. Confirmación final de que no quedan referencias

```bash
cd ../pos-backend && grep -rn "\.dimension\b" app/ --include="*.py"
cd ../pos-heladeria && grep -rn "\.dimension\b" src/ --include="*.ts"
```

Resultado esperado: sin resultados relacionados con `UnitMeasure`/`unit_measures` (ignorar
falsos positivos no relacionados, p. ej. "dimensionar"/"redimensionar", si el patrón de grep
los capturara).
