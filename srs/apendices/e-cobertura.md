# Apéndice E — Cobertura real

**SRS**: [../README.md](../README.md)

## Cobertura de endpoints

**175 de 175 endpoints del backend (100%)** están cubiertos por al menos un Requisito funcional en el [Apéndice A](./a-trazabilidad.md). El cálculo es directo: cada fila de la tabla de correspondencia de [cruce-front-back.md](../../specs/104-documentacion-funciones-publica/cruce-front-back.md) (175 endpoints verificados por lectura directa del código) aparece citada en el campo "Trazabilidad" de exactamente un RF en § 3.2 del SRS — incluidos los 32 endpoints marcados **No consumido** por el frontend, que igualmente tienen su RF (describiendo la capacidad real del backend, con su Prioridad/Atributos IEEE 830 anotando la falta de consumo y remitiendo al Hallazgo correspondiente del [Apéndice D](./d-discrepancias.md) cuando aplica).

Verificación por muestreo (10 filas aleatorias del Apéndice A contra la tabla de correspondencia de `cruce-front-back.md`): ver `quickstart.md` paso 6 (T054).

**Módulos de backend sin ningún endpoint, declarados explícitamente fuera de alcance de requisitos (FR-021)**:
- `admin`: sin código fuente activo, reemplazado por `super_admin` — 0 endpoints, 0 RF.
- `tables`: sin código fuente activo, su funcionalidad real vive en `orders` — 0 endpoints, 0 RF.
- `business_hours`: modelo de datos existe (`BusinessHours`), pero ningún endpoint ni lógica de servicio lo usa — 0 endpoints, 0 RF; mencionado solo en § 3.6 como entidad huérfana.

## Cobertura de pantallas/rutas de frontend

`inventario-frontend.md` documenta **38 unidades de ruta** (algunas agrupan más de un path real, p. ej. los 4 pasos de checkout del comensal bajo un solo encabezado). De esas 38:

- **36 (94.7%) consumen al menos un endpoint del backend**, y las 36 están cubiertas por al menos un RF que cita esa pantalla en su Trazabilidad (100% de las pantallas que dependen de la API).
- **2 (5.3%) no hacen ninguna llamada a la API propia**, por lo que no aplican al cálculo de cobertura de endpoints — no son una omisión de este análisis, son pantallas genuinamente sin dependencia de backend:
  - `/dashboard/ajustes` (shell de pestañas): solo lee un signal ya hidratado por otra pantalla, sin disparar `load()`/`fetch()` propio [CÓDIGO: pos-heladeria/src/app/modules/settings/pages/settings-page.component.ts:50-51,63-71].
  - `/menu/qr/:token` (`ExpiredQrComponent`): pantalla estática que informa que el formato de QR impreso es obsoleto, sin formulario ni llamada [CÓDIGO: pos-heladeria/src/app/modules/tables/pages/expired-qr.component.ts:1-25].

## Hallazgos y preguntas abiertas — cobertura de registro

- **11 discrepancias** están documentadas en el Apéndice D: las 10 detectadas durante el cruce front↔back, más 1 (H-11) detectada durante la propia redacción del SRS al evaluar atributos IEEE 830 — todas con su categoría, severidad, evidencia de ambos lados y entidades afectadas; ninguna quedó solo mencionada en `cruce-front-back.md` sin consolidar aquí.
- **9 preguntas abiertas** consolidadas en el Apéndice C, provenientes de `inventario-backend.md` (5), `inventario-frontend.md` (1) y del propio cuerpo de este SRS al redactar los atributos IEEE 830 de ciertos RF (3, ya presentes en los dos inventarios pero formalizadas con identificador `C-xx` en esta fase).

## Resumen numérico

| Métrica | Valor |
|---|---|
| Endpoints de backend documentados | 175 |
| Endpoints cubiertos por ≥1 RF | 175 (100%) |
| Endpoints marcados "No consumido" por el frontend (y su propio RF igual) | 32 |
| Endpoints marcados "Consumido" o "Consumido (parcial)" | 143 |
| Módulos de backend sin endpoints (fuera de alcance) | 3 (`admin`, `tables`, `business_hours`) |
| Pantallas/rutas de frontend documentadas | 38 |
| Pantallas con dependencia de API, todas cubiertas | 36 (100% de las que aplican) |
| Pantallas sin llamada propia (no aplican al cálculo) | 2 |
| Requisitos funcionales (RF) | 175 |
| Requisitos no funcionales (RNF) con evidencia completa | 19 |
| Entradas "sin evidencia verificable" en § 3.3/3.5 (no son RNF, redirigen al Apéndice C) | 3 |
| Hallazgos (Apéndice D) | 11 |
| Preguntas abiertas (Apéndice C) | 9 |
