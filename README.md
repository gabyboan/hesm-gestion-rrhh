# HESM Gestion RRHH

[![Flutter](https://img.shields.io/badge/Flutter-desktop-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3-0175C2?logo=dart&logoColor=white)](https://dart.dev/)
[![Supabase](https://img.shields.io/badge/Supabase-auth_datos-3ECF8E?logo=supabase&logoColor=white)](https://supabase.com/)
[![Estado](https://img.shields.io/badge/estado-desarrollo_activo-22c55e)](#estado)

Aplicacion interna de escritorio desarrollada con Flutter para registrar,
consultar, controlar y exportar novedades administrativas de recursos humanos:
horas particulares, horas oficiales, enfermedad, francos y movimientos
operativos del personal.

## Valor del proyecto

El objetivo es reemplazar registros manuales por una herramienta trazable,
ordenada y mantenible para el trabajo cotidiano de RRHH. El sistema conecta una
interfaz de escritorio con Supabase, encapsula reglas de negocio en modulos y
permite exportar informes mensuales a `.xlsx`.

## Funcionalidades

| Area | Funcionalidad |
| --- | --- |
| Autenticacion | Inicio de sesion con Supabase y cierre por inactividad. |
| Horas | Carga, consulta mensual, filtros, cupos y excedentes. |
| Francos | Consulta de saldo, movimientos y novedades por persona. |
| Informes | Filtros por periodo, tipo, uso y excedidos. |
| Exportacion | Generacion de informes en formato `.xlsx`. |
| Escritorio | Prevencion de doble instancia en Windows. |

## Arquitectura

```txt
lib/
  app/          configuracion global y tema
  core/         Supabase, exportacion, UI y utilidades compartidas
  features/
    auth/       sesion, login y control de inactividad
    horas/      carga, consulta, informe y reglas de horas
    francos/    consulta y movimientos de francos
    shell/      navegacion principal
```

Cada modulo mantiene una separacion clara:

```txt
features/<modulo>/
  application/  estado y providers
  data/         repositorios y acceso a Supabase
  domain/       modelos y reglas del modulo
  presentation/ pantallas y widgets
```

## Seguridad y privacidad

- No se versionan credenciales reales.
- No se incluyen dumps de base ni datos personales reales.
- Las credenciales publicas se pasan por `--dart-define` o `credenciales.env`
  local.
- El acceso a datos queda encapsulado en repositorios para no mezclar UI con
  consultas directas.
- Las reglas sensibles tambien se protegen del lado de Supabase mediante
  permisos, RPC y politicas de acceso.

## Configuracion

Ejecutar con variables por `--dart-define`:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-project-ref.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-supabase-anon-key
```

Para desarrollo local:

```bash
cp credenciales.env.example credenciales.env
```

No commitear `credenciales.env`, claves `service_role`, connection strings ni
archivos con datos reales.

## Desarrollo

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```

En Linux:

```bash
flutter run -d linux
```

## Pruebas

El proyecto incluye pruebas unitarias para utilidades compartidas:

```bash
flutter test
```

## Estado

Proyecto en desarrollo activo. Actualmente permite cargar, consultar, filtrar y
exportar informacion mensual de RRHH, con modulos separados para horas y
francos.

## Nota publica

Este repositorio muestra la arquitectura y el enfoque tecnico del sistema. La
configuracion productiva, credenciales y datos reales pertenecen al entorno
institucional y no forman parte del codigo publico.
