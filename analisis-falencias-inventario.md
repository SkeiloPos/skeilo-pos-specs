# Análisis de falencias — Inventario y Exportación/Importación de productos

**Rol del análisis:** revisión funcional, como si fuera un desarrollador con +10 años en sistemas de inventario, sobre lo que está **documentado en `specs/`** del repo `pos-specs` (no se revisó ni modificó código). Las rutas citadas son relativas a `specs/`.

---

## 1. Contexto

El sistema modela inventario de **insumos** (stock, kardex, compras, proveedores) separado del **catálogo de venta** (productos/carta), con sus propios flujos de exportación/importación en Excel. La lógica central de movimientos vive detrás de `record_movement` / `apply_adjustment` (spec `005-kardex-compras-conversion`), con bloqueo de fila para concurrencia.

---

## 2. Falencias de Inventario (stock, kardex, compras)

### 2.1 Sin multi-sucursal / multi-almacén
No existe ningún spec que modele bodegas o sucursales con stock independiente, ni transferencias entre ubicaciones. El dato "sucursal" aparece solo como singular implícito por tenant (`158-compra-sugerida`, `116-layout-base-panel-admin`). **Impacto:** cualquier negocio con más de un punto de venta o bodega no puede llevar inventario separado ni mover stock entre sedes — tendría que operar tenants distintos, perdiendo visión consolidada.

### 2.2 Sin trazabilidad por lote ni control de vencimientos
"Vencimiento" solo existe como **motivo de salida** en el catálogo de 6 motivos de ajuste, no como un campo de lote con fecha de caducidad. **Impacto:** no hay FEFO/FIFO real, no se puede alertar sobre próximos a vencer, ni rastrear de qué lote salió un producto defectuoso (trazabilidad regulatoria débil para alimentos/perecederos, que es justamente el dominio — heladería/restaurante).

### 2.3 Sin conteo físico / inventario cíclico
No hay flujo de "toma de inventario" que compare conteo real contra el sistema y genere ajustes masivos reconciliados. Solo existen ajustes manuales puntuales (`apply_adjustment`). **Impacto:** cuadrar inventario periódicamente (mensual, por categoría, etc.) depende de ajustes uno a uno, propenso a error y sin auditoría de "sesión de conteo".

### 2.4 Costeo por "último costo", no promedio ponderado
Confirmado como decisión de negocio deliberada, no un vacío accidental. **Impacto real:** el costo de inventario no refleja el histórico de compras acumuladas; en entornos con variación de precios de insumos, el costo de venta y el margen reportado pueden distorsionarse significativamente frente a un costo promedio ponderado (CPP) o FIFO contable.

### 2.5 `allow_negative=True` sin gobernanza
Existe el parámetro en `record_movement` para permitir stock negativo, pero no tiene ningún llamador visible en el repo y está documentado como "PENDIENTE" sin decisión de negocio. **Impacto:** mecanismo de escape latente sin reglas de cuándo se activa, quién lo autoriza o cómo se reporta — superficie de riesgo si en algún punto se activa sin control.

### 2.6 Reserva de stock solo "best-effort"
El chequeo de disponibilidad antes de vender no reserva stock; es una validación temprana, confirmada como aceptable por el negocio. **Impacto:** bajo alta concurrencia (varias cajas/mesas vendiendo el mismo insumo simultáneamente), puede aprobarse una venta que luego falla al confirmar el cobro, o venderse de más antes de que el stock se actualice.

### 2.7 Ausencia de characterization tests en el núcleo económico
La propia spec `005-kardex-compras-conversion` (criterio SC-005) señala que no existe golden master ni test de caracterización para `inventory/stock.py`, el módulo de mayor impacto económico directo. **Impacto:** alto riesgo de regresión silenciosa en cualquier cambio futuro sobre movimientos de stock, sin red de seguridad automatizada.

### 2.8 Conversión de unidades limitada a una sola dimensión
El módulo de conversión solo cubre conversión dentro de la misma dimensión (ej. litros↔onzas); conversión entre masa y volumen queda fuera de alcance por falta de caso de uso. **Impacto:** cualquier receta que mezcle unidades de distinta naturaleza (ej. gramos de un insumo que se compra por litro, con densidad conocida) no tiene soporte.

### 2.9 Tensión sin resolver en consumo por grupos opcionales (A-33)
Hay una contradicción documentada entre "grupo opcional = no elegir es legítimo" y el bloqueo con error 409 cuando ese grupo es la única fuente de descuento de inventario. **Impacto:** comportamiento inconsistente o venta bloqueada en escenarios legítimos de catálogo.

### 2.10 Stock/costo subido por Excel no pasa por el kardex — **RESUELTA por spec 165 / A-165**
Los specs de importación masiva (`109-inventario-excel-masivo`, `139-simplificar-columnas-excel-inventario`, `142-mejoras-filtros-excel-inventario`) no mencionaban en ningún momento el kardex ni las funciones `record_movement`/`apply_adjustment` que la spec `005-kardex-compras-conversion` establece como la única vía legítima para mutar stock. La columna "Stock" del Excel mapeaba directo a `current_stock` tanto al crear como al actualizar, sin generar movimiento ni motivo asociado.

**Resolución** (`specs/165-trazabilidad-kardex-importacion-excel-inventario/spec.md`, anomalía `A-165` en `specs/000-reconocimiento/registro-de-anomalias.md`): decisión de negocio tomada el 2026-11-24.
- **Creación**: el stock inicial genera un movimiento `in`, motivo nuevo `importacion_masiva`, referenciado al job de importación.
- **Actualización**: la diferencia entre el valor del Excel y el stock actual genera un ajuste (`apply_adjustment`) con el mismo motivo y referencia; si la diferencia es cero, no se genera movimiento.
- **Costo**: sin cambios — sigue sobrescribiendo `unit_cost` directo (comportamiento ya vigente en spec 139), por tratarse de un atributo y no de una cantidad de movimiento.

Queda pendiente de planificación e implementación en `pos-backend` (este repo es solo de especificaciones).

### 2.11 Motivo de ajuste como texto libre sin validación en BD
El catálogo de 6 motivos canónicos es una convención de capa de aplicación, no una restricción en base de datos. **Impacto:** riesgo de inconsistencia de datos históricos (motivos mal escritos o fuera del catálogo) si cambia la implementación o se accede por otra vía.

---

## 3. Falencias de Exportación/Importación de productos e inventario

### 3.1 Límite de tamaño de archivo (~500 filas)
El diseño de importación masiva (`109-inventario-excel-masivo`, `143-exportacion-importacion-carta-menu`) está pensado para lotes de cientos de filas, no miles. **Impacto:** catálogos grandes (cadenas con cientos de insumos/productos y variantes) pueden degradar el rendimiento del job asíncrono o no estar cubiertos por las pruebas de carga del diseño.

### 3.2 Sin importación de imágenes de producto
Explícitamente excluida del flujo de carta (`143`, `155`). **Impacto:** la carga masiva de catálogo sigue requiriendo subir imágenes una por una desde la UI, rompiendo el flujo de "todo en un Excel".

### 3.3 Sin importación de sabores/grupos de opciones
También fuera de alcance del Excel de carta. **Impacto:** un catálogo con muchas variantes de sabor/opciones no puede migrarse o actualizarse masivamente; requiere configuración manual repetitiva.

### 3.4 Corte de formato sin período de transición (spec 155)
Al fusionar hojas de "Productos" y "Presentaciones y precios", los archivos exportados con el formato anterior (4 hojas) dejan de ser válidos para reimportar, sin aviso de migración ni compatibilidad hacia atrás. **Impacto:** cualquier archivo descargado antes del cambio y guardado como plantilla de trabajo por el usuario queda obsoleto de golpe, sin mensaje de error claro necesariamente distinto a un fallo de estructura genérico.

### 3.5 Caso sin resolver: producto sin presentaciones en el Excel
La spec 155 deja explícitamente fuera de alcance cómo representar un producto que no tiene ninguna presentación/precio configurado. **Impacto:** posible fila vacía o comportamiento no definido al exportar catálogos con productos incompletos.

### 3.6 Todo-o-nada en permisos de import/export
Un único permiso administrativo habilita tanto exportar como importar, sin distinción. **Impacto:** no se puede dar a un rol (ej. "solo lectura para auditoría") permiso de exportar sin también otorgar la capacidad de importar/modificar en masa.

### 3.7 Un solo job concurrente por tenant
Tanto para inventario como para carta, solo se permite una importación en curso por negocio. **Impacto:** si dos áreas (ej. inventario y carta) necesitan importar a la vez, una debe esperar a la otra — limitación operativa en negocios con equipos separados por dominio.

### 3.8 Gating de módulo con import/export: decisión pendiente (A-153)
La spec `141-modulo-inventario-unificado` (FR-023) depende de una ratificación del dueño del producto que, según la documentación, puede no haberse concretado. **Impacto:** no está claro si hoy la importación de inventario respeta correctamente el gating por plan de suscripción a nivel de campo, o si hay una brecha de control de acceso pendiente de cerrar.

### 3.9 Normalización agresiva a mayúsculas sin control del usuario
La resolución "buscar o crear" para unidades/proveedores/categorías normaliza siempre a MAYÚSCULA y reactiva inactivos coincidentes. **Impacto:** no hay opción de mantener mayúsculas/minúsculas originales de catálogo (ej. nombres de marca con formato específico), y la reactivación automática de registros inactivos podría revivir datos que el usuario había desactivado intencionalmente por otra razón, sin confirmación explícita.

### 3.10 Falla de fila por inconsistencia es "todo o nada" por código (spec 155)
Si las columnas de producto difieren entre filas del mismo código, **todas** las filas de ese código fallan. **Impacto:** un solo error de tipeo en una fila puede invalidar varias filas de presentaciones/precios asociadas, obligando a corregir y reimportar el bloque completo en vez de solo la fila afectada.

---

## 4. Resumen priorizado (qué atacaría primero)

| # | Falencia | Severidad funcional | Esfuerzo estimado |
|---|----------|---------------------|--------------------|
| 1 | Sin characterization tests en `inventory/stock.py` | Alta (riesgo de regresión silenciosa) | Medio |
| 2 | Reserva de stock best-effort (sobreventa bajo concurrencia) | Alta (impacto directo en ventas) | Alto |
| 3 | `allow_negative` huérfano sin gobernanza | Media-Alta (riesgo oculto) | Bajo |
| 4 | Sin conteo físico / cíclico | Alta (operación diaria) | Alto |
| 5 | Sin multi-sucursal | Alta si el negocio crece a varias sedes | Muy alto |
| 6 | Sin lotes/vencimientos | Media-Alta (dominio perecedero) | Alto |
| 7 | Permisos todo-o-nada en import/export | Media (gobernanza de acceso) | Bajo |
| 8 | Límite ~500 filas en import masivo | Media (escalabilidad) | Medio |
| 9 | Sin imágenes/sabores en import de carta | Baja-Media (conveniencia) | Medio |
| 10 | Costeo por último costo (no CPP) | Media (reporting financiero) | Alto (decisión de negocio ya tomada) |

---

*Nota: varias de estas "falencias" son decisiones de negocio ya confirmadas y documentadas como intencionales (costeo por último costo, reserva best-effort de stock). Se incluyen aquí como limitaciones funcionales a tener en cuenta, no como errores de implementación.*
