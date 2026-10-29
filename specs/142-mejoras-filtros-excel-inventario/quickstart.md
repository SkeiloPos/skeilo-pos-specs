# Quickstart: Filtro buscable de proveedor, exportación filtrada y vinculación de unidades de compra por Excel

**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Contrato**:
[contracts/plantilla-excel-inventario.md](./contracts/plantilla-excel-inventario.md)

Escenarios ejecutables para verificar las tres historias de forma independiente, siguiendo el
mismo entorno descrito en memoria `[[how-to-run-sibling-repo-tests]]` (venv de `pos-backend`,
Postgres local disponible).

## Prerrequisitos

```bash
cd ../pos-backend
source env/bin/activate   # o el venv del proyecto
docker compose up -d postgres redis
alembic upgrade head      # sin migración nueva en esta spec; confirma que el head no cambió
```

```bash
cd ../pos-heladeria
npm install   # si aplica
```

## Historia 1 — Filtro buscable de proveedor

### Validación manual (frontend)

1. Levantar `pos-heladeria` y entrar a Inventario → pestaña "Insumos", con al menos 3
   proveedores registrados con relaciones activas con algún insumo.
2. Abrir el filtro de proveedor (ahora `app-searchable-select`): escribir parte del nombre de uno
   de ellos → solo las coincidencias parciales (sin distinguir mayúsculas/minúsculas) quedan
   visibles (Acceptance Scenario 1).
3. Borrar el texto escrito → vuelven a verse todos los proveedores, incluida la opción "Todos los
   proveedores" (Acceptance Scenario 2).
4. Escribir un texto que no coincide con ningún proveedor → el filtro no muestra ninguna opción
   seleccionable, sin romper la pantalla (Acceptance Scenario 3).
5. Seleccionar un proveedor desde el filtro ya buscado → el listado de insumos se filtra
   exactamente igual que con el filtro no buscable anterior (Acceptance Scenario 4).

### Test automatizado (frontend)

```bash
cd ../pos-heladeria
npm test -- --include='**/inventory-page.component.spec.ts'
```

Comparar por archivo contra la baseline conocida (ver memoria `[[how-to-run-sibling-repo-tests]]`
— la suite completa es flaky, no comparar por conteo total).

## Historia 2 — Exportación filtrada

### Validación manual (end-to-end)

1. Exportar inventario sin seleccionar ningún filtro → el archivo contiene todos los insumos
   (Acceptance Scenario 1).
2. Exportar seleccionando un proveedor específico → el archivo contiene únicamente los insumos
   con relación activa con ese proveedor (Acceptance Scenario 2).
3. Exportar seleccionando un tipo de insumo (materia prima / empacado) → el archivo contiene
   únicamente insumos de ese tipo (Acceptance Scenario 3).
4. Exportar con proveedor **y** tipo a la vez → el archivo contiene solo la intersección
   (Acceptance Scenario 4).
5. Exportar con una combinación que no coincide con ningún insumo → el archivo se genera con la
   plantilla de columnas, sin filas (Acceptance Scenario 5), sin error.

### Verificación directa del endpoint

```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  "http://localhost:8000/inventory/items/export?supplier_id=$SUPPLIER_ID&type_=raw_material" \
  -o export_filtrado.xlsx
```

Abrir `export_filtrado.xlsx` y confirmar que solo aparecen insumos de materia prima con relación
activa con `$SUPPLIER_ID`.

### Characterization tests (backend)

```bash
cd ../pos-backend
python -m unittest app.characterization_tests.test_inventory_export -v
```

## Historia 3 — Grupo de unidad base y unidad de compra por proveedor vía Excel

### Preparar un archivo de prueba (formato de 10 columnas)

```text
Código | Nombre        | Tipo          | Unidad | Grupo | Stock | Mínimo | Costo | Proveedor preferido | Unidad de compra | Factor de conversión (compra)
0101   | Harina trigo  | Materia prima | g      | Masa  | 0     | 0      | 0      | Molino XYZ           | KG                | 1000
```

1. **Grupo nuevo**: con el negocio sin ningún grupo "Masa", importar la fila anterior → se crea
   el grupo "Masa", la unidad "g" dentro de él como base (factor 1), el insumo creado con esa
   unidad, el proveedor "Molino XYZ" (si no existía) y la relación preferida con `unit_measure_id`
   apuntando a una `UnitMeasure` "KG" nueva dentro del grupo "Masa" con `factor_to_base=1000`
   (Acceptance Scenarios 1, 5/7).
2. **Grupo existente, unidad reutilizada**: importar otra fila con `Unidad=g`, `Grupo=Masa` (ya
   creado en el paso 1) → el insumo se vincula a la unidad "g" ya existente, sin duplicar grupo ni
   unidad (Acceptance Scenario 2).
3. **Conflicto de factor**: importar una fila con `Unidad de compra=KG`, `Factor de conversión
   (compra)=900` (distinto a los 1000 ya vigentes) → la fila se reporta fallida, el factor de "KG"
   permanece en 1000 (Acceptance Scenario 6).
4. **Unidad de compra sin proveedor**: importar una fila con `Unidad de compra` llena pero
   `Proveedor preferido` vacío → la fila se reporta fallida, sin crear el insumo (Acceptance
   Scenario 11, FR-020a).
5. **Ambigüedad de grupo** (unidad base): importar una fila cuya `Unidad` ya existe en el negocio
   pero en un grupo distinto al indicado por `Grupo` → la fila se reporta fallida por ambigüedad,
   sin crear ni modificar nada (Acceptance Scenario 4).
6. **Actualización ignora las columnas nuevas**: importar una fila cuyo `Código` ya existe,
   trayendo `Grupo`/`Unidad de compra`/`Factor` distintos a los vigentes → esas columnas se
   ignoran, el resto de la fila se actualiza con normalidad (Acceptance Scenario 9).

Subir el archivo vía `POST /inventory/items/import` y consultar
`GET /inventory/items/import/{job_id}/errors` para confirmar qué filas fallaron y por qué.

### Verificación en Ajustes

Tras el paso 1, abrir Ajustes → Unidades de medida y confirmar que el grupo "Masa" existe con
"g" como base y "KG" como unidad adicional con factor 1000 — sin tener que reorganizar nada
manualmente (SC-004).

### Verificación en Proveedores

Tras el paso 1, abrir el módulo de Proveedores → relación con "Molino XYZ" para el insumo creado
y confirmar que ya trae "KG" como unidad de compra con su factor, sin tener que completarla
manualmente (SC-005).

### Characterization tests + script de importación masiva (backend)

```bash
cd ../pos-backend
python -m unittest app.characterization_tests.test_inventory_export -v
python -m app.scripts.test_inventory_bulk_excel
```

## Checklist de cierre (las tres historias)

- [ ] Historia 1 verificada manualmente + test de frontend sin regresión (comparado por archivo).
- [ ] Historia 2 verificada manualmente (5 escenarios) + characterization tests actualizados.
- [ ] Historia 3 verificada manualmente (6 escenarios) + characterization tests + script de
      importación masiva contra Postgres real, sin regresión en los escenarios ya cubiertos por
      la spec 139 (unidad vacía, actualización ignora unidad).
