# Contrato: `name` en la sesión (`POST /auth/login`, `POST /auth/refresh`)

**Spec**: [../spec.md](../spec.md) · **Data model**: [../data-model.md](../data-model.md) · **Research**: [../research.md](../research.md)

Extiende los claims/el cuerpo que ya arman `POST /api/v1/auth/login` y `POST /api/v1/auth/refresh`. **No es un endpoint nuevo** ni cambia ningún parámetro de request — un campo adicional, retrocompatible: un cliente que no lo lea sigue funcionando igual que hoy.

## Campo

| Campo | Tipo | Descripción |
|---|---|---|
| `name` | `string` | Nombre real del usuario autenticado (`User.name`, columna `NOT NULL`). |

## Dónde aparece

| Respuesta | `user_data.name` |
|---|---|
| `POST /auth/login` → body `user` | Siempre presente (usuario recién autenticado). |
| Claims del `access_token`/`refresh_token` (ambos endpoints) | Siempre presentes, mismo `user_data`. |
| `POST /auth/refresh` → body | El body de refresh no incluye `user` hoy (solo `access_token`) — sin cambios; `name` solo viaja dentro del nuevo `access_token`. |

## Ejemplo — login

```jsonc
POST /api/v1/auth/login

{
  "message": "Login successful",
  "access_token": "eyJ...",   // claims incluyen ahora "name": "María Pérez"
  "refresh_token": "eyJ...",
  "user": {
    "email": "maria.perez@heladeria.com",
    "uid": "a1b2...",
    "tenant_id": 7,
    "is_super_admin": false,
    "role": "admin",
    "must_change_password": false,
    "name": "María Pérez"
  }
}
```

## Compatibilidad hacia atrás

Un token emitido **antes** de este cambio no trae `name` en sus claims. El frontend trata su ausencia como "no disponible" y degrada al nombre derivado del correo (mismo criterio que usa hoy para todo caso), sin error ni re-login forzado — el usuario simplemente ve el saludo con el nombre derivado hasta su próximo login/refresh.

## Casos de error

Sin cambios respecto a los endpoints actuales — este contrato no añade parámetros de request ni nuevos códigos de estado.
