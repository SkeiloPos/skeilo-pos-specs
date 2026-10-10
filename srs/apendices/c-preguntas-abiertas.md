# Apéndice C — Preguntas abiertas

**SRS**: [../README.md](../README.md)

Aspectos no determinables desde el código disponible de `pos-backend`/`pos-heladeria`, dirigidos al Product Owner. Cada una resistió una búsqueda deliberada en el código antes de aceptarse como legítima (SC-006) — no son preguntas cuya respuesta ya esté en el código.

#### C-01: ¿Cuál es el contrato de error correcto cuando `signed_delta=0` en un ajuste de inventario?

- **Pregunta**: `POST /inventory/items/{id}/adjust` con `signed_delta=0` propaga un `ValueError` de Python, no un `HTTPException` controlado, y no se encontró ningún manejador global de excepciones para ese caso en el router de `inventory` ni en los archivos revisados. ¿Debería devolver un `422` explícito con mensaje de negocio, o el comportamiento actual (probablemente un `500` genérico) es aceptable porque el frontend nunca envía `0` en la práctica?
- **Impacto si no se resuelve**: RF-inventory-007 (3.2) queda con el atributo "Verificable" marcado ❌ — no hay forma de confirmar el código de estado real sin provocar el error en un entorno de prueba controlado, fuera del alcance de solo lectura de este análisis.
- **Prioridad**: Baja — caso de borde que el frontend no dispara hoy (el formulario de ajuste no permite enviar cantidad `0`).

#### C-02: ¿Es intencional que `inventory.suppliers` no valide nombre único, a diferencia del resto del catálogo?

- **Pregunta**: `POST /inventory/suppliers` es el único `create_*` de todo el grupo G3 que no aplica `ensure_unique` sobre el nombre, a diferencia de `InventoryItem`, `Presentation`, `Promotion`, `CashRegister` y otros. ¿Es una decisión deliberada (permitir proveedores homónimos) o una omisión?
- **Impacto si no se resuelve**: RF-inventory-010 (3.2) y la nota de 3.4.3 quedan con el atributo "Consistente" marcado ❌ sin poder confirmar si corregirlo (agregando la validación) rompería algún flujo real que hoy depende de poder crear proveedores con el mismo nombre.
- **Prioridad**: Baja — no hay evidencia de que esto cause un problema operativo real hoy.

#### C-03: ¿Es intencional que una `CashRegister` no se pueda editar ni desactivar una vez creada?

- **Pregunta**: el router de `cash` solo declara `GET`/`POST` bajo `/registers` — no existe `PATCH` ni `DELETE`. Una caja creada con un nombre erróneo no tiene forma de corregirse ni de retirarse de la lista de selección, salvo manipulación directa de base de datos. ¿Es una limitación conocida pendiente de implementar, o una decisión de que las cajas son inmutables por diseño?
- **Impacto si no se resuelve**: RF-cash-002 (3.2) queda con el atributo "Consistente" marcado ❌; no se puede documentar un flujo de "editar/desactivar caja" en el SRS porque no existe.
- **Prioridad**: Media — afecta la operación real de un tenant que cometió un error de nombre al crear su primera caja.

#### C-04: ¿Debería la pantalla de kardex distinguir un error de red de "sin movimientos"?

- **Pregunta**: si `InventoryService.loadMovements()` (frontend) falla por error de red, el código devuelve una página vacía (`{items: [], total: 0}`) en vez de propagar la excepción, y la pantalla termina mostrando "Sin movimientos para este insumo" — el mismo mensaje que un insumo genuinamente sin historial. ¿Es intencional simplificar la UI así, o debería distinguirse "error de carga" de "lista vacía real"?
- **Impacto si no se resuelve**: un cajero/admin podría concluir erróneamente que un insumo nunca tuvo movimientos cuando en realidad hubo un problema de red momentáneo.
- **Prioridad**: Baja — afecta solo la claridad de un mensaje, no la integridad de los datos (el kardex real en base de datos no se pierde).

#### C-05: ¿Existen objetivos de tiempo de respuesta (SLA) para los endpoints de negocio?

- **Pregunta**: no se encontró ningún timeout de aplicación, SLA documentado ni objetivo de throughput para los endpoints CRUD del dominio de negocio (fuera de los timeouts cortos ya verificados para R2). ¿El negocio tiene expectativas de tiempo de respuesta (p. ej. "el checkout debe responder en menos de 2s") que deban formalizarse?
- **Impacto si no se resuelve**: la sección 3.3 (Rendimiento) queda incompleta en la dimensión de "qué tan rápido debe responder" el sistema — solo cubre mecanismos verificados (paginación, timeouts de integración, rate limiting).
- **Prioridad**: Media — relevante si el negocio ha recibido quejas de lentitud que no están documentadas en este análisis.

#### C-06: ¿Hay índices de base de datos pensados para las consultas paginadas más frecuentes?

- **Pregunta**: se verificaron índices únicos usados como guarda de concurrencia (turnos, sesiones, intentos de pago), pero no se encontró evidencia de índices compuestos pensados específicamente para acelerar los listados paginados más frecuentes del sistema (`GET /orders`/`GET /sales` filtrados por fecha/estado, que crecen sin límite con el tiempo). ¿Existen y no se revisó el archivo de migración correcto, o realmente no se han creado?
- **Impacto si no se resuelve**: no se puede afirmar ni negar si el sistema degradará su tiempo de respuesta en listados a medida que crezca el volumen histórico de órdenes/ventas de un tenant.
- **Prioridad**: Media — relevante para la planificación de capacidad a medida que los tenants acumulan historial.

#### C-07: ¿Cuál es el objetivo de disponibilidad (uptime) del sistema?

- **Pregunta**: no se encontró ningún SLA de disponibilidad documentado, ni redundancia de PostgreSQL/Redis más allá de los `healthcheck` de Docker Compose (que reinician un contenedor caído, pero no documentan una topología de alta disponibilidad). ¿Hay un objetivo de negocio (p. ej. "99.9% mensual") que debiera reflejarse en la infraestructura?
- **Impacto si no se resuelve**: la sección 3.5 (Disponibilidad) queda sin un objetivo cuantitativo contra el cual medir el sistema real.
- **Prioridad**: Media.

#### C-08: ¿`create_url_safe_token`/`decode_url_safe_token` son código muerto, o los consume algo externo al repositorio?

- **Pregunta**: `app/core/utils.py` define un `URLSafeTimedSerializer` (`itsdangerous`) con dos funciones (`create_url_safe_token`/`decode_url_safe_token`), firmadas con `JWT_SECRET` y un `salt` fijo, pero no se encontró ningún llamador de ninguna de las dos en el resto del árbol `app/`. ¿Son remanentes de una función retirada, o las usa un script/servicio fuera de este repositorio?
- **Impacto si no se resuelve**: no se puede confirmar si retirarlas sería seguro, ni si representan una superficie de código no documentada en este SRS.
- **Prioridad**: Baja.

#### C-09: ¿Qué implementa el servicio detrás de `EMAIL_API_URL`?

- **Pregunta**: `pos-backend` nunca invoca los SDKs `resend`/`fastapi-mail` que figuran en su `requirements.txt` — el envío real es un `POST` HTTP propio a `{EMAIL_API_URL}/api/email/send`. ¿Ese microservicio es un wrapper propio sobre Resend, sobre otro proveedor, o una implementación completamente distinta? No hay evidencia dentro de `pos-backend` que lo determine.
- **Impacto si no se resuelve**: la sección de integraciones de correo transaccional (ver `inventario-backend.md` § Integraciones externas) queda incompleta en el extremo receptor — se documenta el contrato HTTP que `pos-backend` emite, pero no qué lo atiende.
- **Prioridad**: Baja — no afecta el comportamiento observable de `pos-backend` en sí, solo la trazabilidad completa de la integración.
