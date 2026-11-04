# Quickstart: validar "Cocina" en el catálogo de módulos por plan

Guía de ejecución para comprobar la implementación de esta fase, cuyo alcance quedó reducido a la
sola característica de plan `cocina_access` (research.md Decisión 0 — sin ningún endpoint de
cocina que gatear todavía). No repite firmas ya detalladas en [data-model.md](./data-model.md) y
[contracts/plan-catalog-cocina.md](./contracts/plan-catalog-cocina.md).

**Prerequisitos**: entorno virtual de `pos-backend` (Python 3.14), ejecutado desde la raíz de
`../pos-backend` (sibling de este repo `pos-specs`).

```bash
cd ../pos-backend
source env/bin/activate
```

No hace falta PostgreSQL real para los tests — `app/characterization_tests/fixtures.py` crea
SQLite en memoria.

## Paso 0 — Confirmar la línea base antes de tocar código

```bash
python -m unittest discover -s app/characterization_tests -p 'test_*.py' -v
```

**Resultado esperado**: todo en verde. Ningún `"CONGELA comportamiento actual:"` existente asume
que `PLAN_MODULES` tiene exactamente dos entradas ni que `Plan` carece de `cocina_access` — se
confirma por búsqueda, ninguno se modifica (Principio III).

## US1 (acotada a esta fase) — El Super Admin incluye/excluye "Cocina" en un plan

Fichero modificado: `app/characterization_tests/test_super_admin_plans.py` (o el fichero
equivalente de spec 033/141 que ya cubre `inventario_access`/`promociones_access` — se extiende,
no se duplica).

1. `POST /super-admin/plans` con `cocina_access=true` (autenticado como super admin) → `201`,
   `cocina_access` persistido como `true` en la respuesta.
2. `POST /super-admin/plans` sin enviar `cocina_access` → `201`, `cocina_access: false` (FR-003).
3. `PATCH /super-admin/plans/{id}` con `cocina_access=false` sobre un plan que lo tenía en `true`
   → `200`, reflejado de inmediato en el siguiente `GET /super-admin/plans` (FR-002/FR-014,
   mismo criterio de spec 033).
4. `GET /plan` (como usuario de un tenant con ese plan) → `modules.cocina` refleja el valor
   vigente de `Plan.cocina_access` (Acceptance Scenario 3 del spec, acotado a "el tenant queda en
   condiciones de tener acceso" — sin un endpoint de cocina real que consumirlo todavía).

```bash
python -m unittest app.characterization_tests.test_super_admin_plans -v
```

## Verificación de migración

```bash
alembic upgrade head
```

**Resultado esperado**: `shared.plans` gana la columna `cocina_access` (`boolean NOT NULL DEFAULT
false`); todo plan existente (incluyendo el plan transicional de spec 033) queda con
`cocina_access = false` sin ninguna acción manual — ningún tenant ve cambio de comportamiento
observable, porque ningún endpoint lee esta columna todavía (Principio II).

```bash
alembic downgrade -1
```

**Resultado esperado**: `cocina_access` se elimina de `shared.plans` sin error (research.md
Decisión 4 documenta por qué esta pérdida de dato es aceptable en esta fase).

## Frontend — formulario de plan

```bash
cd ../pos-heladeria
ng test --include='**/plan-form.component.spec.ts'
```

**Resultado esperado**: el checkbox nuevo "Cocina" (`formControlName="cocina_access"`) se
construye, se muestra y se incluye en el payload de creación/edición, con el mismo
comportamiento que los checkboxes de "Inventario"/"Promociones" ya cubiertos por este archivo de
test.

## Lo que esta fase NO verifica (fuera de alcance, research.md Decisión 0)

- Ocultamiento del ítem de menú "Cocina" o del botón "Enviar a cocina" — no existen en `develop`.
- Bloqueo de acceso a la ruta del tablero de cocina — no existe ninguna ruta de tablero en
  `develop`.
- Comportamiento de `kitchen_status` al perderse el módulo — el atributo real hoy es
  `OrderItem.estado_cocina`, gobernado por el ciclo de vida normal de entrega (spec 147), sin
  ninguna relación con `cocina_access` en esta fase.

Estos puntos quedan documentados en `spec.md`/`research.md` para la spec futura que reintroduzca
el flujo de cocina y consuma `cocina_access` ya disponible.
