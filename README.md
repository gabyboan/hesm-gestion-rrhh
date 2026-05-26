# HESM - Gestion RRHH

Aplicacion interna de escritorio desarrollada con Flutter para registrar,
consultar y exportar novedades administrativas relacionadas con horas y
permisos del personal.

## Objetivo

Centralizar la gestion operativa de RRHH en una herramienta digital, reduciendo
registros manuales y mejorando el seguimiento mensual de permisos, horas
particulares, enfermedad y horas oficiales.

## Funcionalidades

- Inicio de sesion con Supabase.
- Control de sesion por inactividad.
- Carga de registros por persona, fecha y tipo de hora.
- Seleccion de duracion para horas particulares y oficiales.
- Consulta mensual de registros por empleado.
- Calculo de cupos y excedentes.
- Informe mensual con filtros por uso, tipo y excedidos.
- Exportacion del informe a archivo `.xlsx`.
- Prevencion de doble instancia en Windows.

## Stack

- Flutter
- Dart
- Riverpod
- Supabase
- Excel export
- Windows desktop

## Estructura

El proyecto esta organizado por features:

```txt
lib/
  app/
  core/
  features/
    auth/
    horas/
    shell/
```

Cada modulo funcional sigue esta convencion:

```txt
features/<modulo>/
  application/
  data/
  domain/
  presentation/
```

## Decisiones tecnicas

- La UI consume providers y no llama directamente a Supabase.
- El acceso a datos esta encapsulado en repositorios.
- Los modelos y reglas propias del modulo viven en `domain`.
- Los helpers compartidos viven en `core`.
- Los widgets grandes se separan en archivos dentro de `presentation/widgets`.

## Estado

Proyecto en desarrollo activo. Actualmente el modulo de horas permite cargar,
consultar, filtrar y exportar informacion mensual de RRHH.
