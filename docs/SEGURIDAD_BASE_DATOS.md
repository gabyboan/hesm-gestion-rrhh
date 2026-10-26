# Revisión de seguridad de la base de datos

La revisión combina el catálogo real de Supabase con pruebas de permisos y
contratos en un clúster aislado. Los informes del entorno compartido, su
configuración y cualquier evidencia operativa se conservan en `.private/` o
`build/`, fuera del árbol público. No publicar hallazgos sin remediar ni
exportaciones de personas junto con las pruebas.

## Auditoría de lectura

`supabase/audits/seguridad_rendimiento.sql` devuelve un JSON de metadatos:
RLS, permisos administrativos, funciones elevadas, search_path, políticas
abiertas, vistas, defaults de privilegios y candidatos de índices para FK.
Puede ejecutarse como administrador en SQL Editor. No cambia la base ni
devuelve filas de personal o cuerpos de consultas.

Los avisos requieren interpretación: una tabla sin RLS puede estar cerrada
por ACL; una función SECURITY DEFINER puede tener controles internos
correctos; un catálogo compartido puede tener una política SELECT true
intencional. El auditor acepta tanto `security_invoker=true` como `on`.

## Pruebas locales

Requisito: PostgreSQL 16 instalado localmente. Para otra instalación, pasar
su carpeta `bin` en `-PostgresBin`.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tool/test_database.ps1
```

El runner crea un clúster nuevo con puerto propio en `127.0.0.1`, ejecuta
fixtures ficticios y lo detiene en `finally`. Guarda sus registros en
`build/database-validation/`. Usa autenticación trust exclusivamente para
ese clúster local efímero con datos ficticios; no es una configuración de
despliegue. No acepta URLs remotas ni lee `credenciales.env`.

| Prueba | Cobertura |
| --- | --- |
| `publicacion_contratos.sql` y migraciones médicas recientes | Contratos públicos y permisos de los módulos sobre fixtures simplificados. |
| `seguridad_rendimiento.sql` | Privilegios existentes/futuros, RLS, RPC autorizadas, Worker, búsquedas y comparación de tiempos orientativa. |
| `auditoria_fixture.sql` | Detección de condiciones adversariales, índices compuestos/INCLUDE, vista invoker y ausencia de exportación de una fila centinela. |
| `horas_seguridad.sql` | Acceso anónimo anterior, denegación posterior sin identidad/rol, acceso de roles permitidos y conservación del contrato de datos. |

Los scripts de fixtures comprueban el nombre de la base antes de escribir.
Se deben ejecutar con el runner, no en SQL Editor ni contra datos de personal.
Los contratos sintéticos no constituyen una copia completa de Supabase.

## Flujo de cambios

1. Contrastar esquema, destinatarios de cada RPC, grants, RLS y migraciones aplicadas.
2. Preparar una corrección concreta y probar accesos permitidos y denegados.
3. Verificar una copia recuperable y validar en un entorno de ensayo equivalente al servidor.
4. Desplegar únicamente la selección revisada de migraciones, registrar su historial y repetir las pruebas de acceso.
5. Guardar evidencia antes/después y revisar asesores y registros de servicio.

Las funciones nuevas deben declarar sus permisos explícitamente. Para código
elevado, preferir una implementación en un esquema no expuesto con
`search_path` vacío y nombres calificados; el envoltorio público debe conservar
el contrato del cliente. Una función privada también debe validar identidad
y autorización: ocultarla de la Data API no reemplaza esos controles.

Las políticas, la autenticación, el acceso administrativo, las copias y los
servicios externos necesitan verificaciones distintas. Aprobar esta suite no
certifica la seguridad completa de un entorno compartido.

## Reversión de cambios

Antes de aplicar una corrección en un entorno compartido, conservar las
definiciones y permisos anteriores y preparar una reversión por cambio.
Registrar la migración dentro de la misma transacción del despliegue y
comprobar los contratos autorizados y los intentos sin permiso antes del
COMMIT. Probar la reversión en una transacción que termine con ROLLBACK.

Los paquetes operativos privados deben incluir las capturas anterior/posterior,
los scripts inversos, las comprobaciones de cambios posteriores y las
instrucciones para revertir ajustes de configuración independientes de SQL.
Un respaldo de funciones y permisos no reemplaza una copia recuperable de
los datos. Una reversión exacta de una corrección de seguridad puede reabrir
el defecto original; debe elegirse el alcance mínimo necesario.

El procedimiento de copia cifrada y ensayo completo de recuperación está en
[RESPALDOS_BASE_DATOS.md](RESPALDOS_BASE_DATOS.md). La verificación compara
datos y permisos en PostgreSQL aislado; no restaura sobre producción.
