# Convencion de modulos

Cada modulo nuevo debe vivir dentro de `lib/features/<modulo>` y seguir esta
estructura base:

```txt
features/
  <modulo>/
    application/
    data/
    domain/
    presentation/
```

## Carpetas

- `domain/`: modelos, enums y reglas puras del modulo. No debe depender de
  Flutter, Supabase ni Riverpod.
- `data/`: repositorios y acceso a datos externos, por ejemplo Supabase,
  archivos o APIs.
- `application/`: providers, casos de uso simples y coordinacion entre
  `data` y `presentation`.
- `presentation/`: paginas, widgets y estado de UI.

## Reglas practicas

- La UI no llama directamente a Supabase: usa providers o repositorios.
- Los modelos compartidos del modulo van en `domain/`.
- Los widgets reutilizables de una pantalla pueden vivir en
  `presentation/<pantalla>/widgets/`.
- Si un helper sirve para varios modulos, va en `lib/core/`.
- Evitar archivos duplicados o borradores dentro de `lib/`; si no compilan o no
  se usan, conviene sacarlos del arbol principal.

## Template para un modulo nuevo

```txt
lib/features/nombre_modulo/
  application/
    nombre_modulo_providers.dart
  data/
    nombre_modulo_repository.dart
  domain/
    nombre_entidad.dart
  presentation/
    nombre_modulo_page.dart
```
