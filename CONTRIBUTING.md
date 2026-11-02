# Contribuir

Crear una rama desde `main` y describir el problema, el comportamiento esperado
y cómo se verificó el cambio. Para reproducir la interfaz sin cuentas ni datos de
personal, usar la demo de `tool/demo/main.dart`.

## Entorno

Usar Flutter 3.38.6 y el lockfile del repositorio:

```powershell
flutter pub get --enforce-lockfile
flutter analyze --fatal-infos
flutter test --reporter expanded
```

Las funciones se organizan por módulos, con modelos en `domain`, repositorios en
`data`, coordinación en `application` y pantallas en `presentation`.

## Base de datos

Incluir una migración nueva para cambios de esquema o permisos. Los contratos de
`supabase/tests/` usan datos ficticios. Con PostgreSQL 16 instalado en Windows,
`powershell -File tool/test_database.ps1` crea y detiene su propio clúster temporal.
En GitHub Actions se usa un servicio PostgreSQL desechable para los contratos.

Las migraciones publicadas dependen del esquema previo; no aplicar el conjunto a
una base compartida como si fuera un instalador. Los datos de personal, cargas
nominales, credenciales, claves de firma y respaldos operativos son locales y
quedan excluidos por `.gitignore`.

## Pull requests

Explicar el resultado para quien no conoce la conversación original. Adjuntar
capturas con datos ficticios cuando cambie la interfaz y anotar las pruebas
ejecutadas. Los cambios de impresión deben describir el PDF generado y distinguir
las pruebas automatizadas de una prueba física de impresora.

El instalador operativo se genera y firma fuera del repositorio público. Una
publicación del código no distribuye credenciales ni ejecuta migraciones contra
la base del hospital.
