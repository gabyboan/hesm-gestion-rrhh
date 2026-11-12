# Prueba local de Gestión 1.0.7.8

12 de noviembre de 2026, hora argentina.

La compilación Windows se abrió en esta PC y llegó al login. Al ingresar con
su cuenta, el responsable mostró el aviso de que la base necesitaba actualizarse.
La lectura de metadatos confirmó que todavía faltaban las dos migraciones.

Después de actualizar la base y reabrir la compilación local se verificó la
pantalla de módulos de la sesión autenticada. El responsable confirmó el
resultado: «listo anda bien». Esa confirmación corresponde a la prueba en esta
PC; no acredita por sí sola cada recorrido de carga o exportación.

## Base actualizada

Se creó un respaldo cifrado nuevo y se restauró en un contenedor temporal sin
red. Coincidieron las 88 tablas y 18.775 filas del origen, junto con estructura,
funciones y permisos. Después se restauró nuevamente esa copia y se ensayó el
SQL exacto de las dos migraciones.

Solo después de esas verificaciones se aplicaron juntas en una transacción:

- `20261112122744_horas_gremiales_y_guardado_seguro.sql`.
- `20261112123611_capacidades_gestion.sql`.

La CLI no pudo usar `db push` porque existen versiones históricas remotas sin
archivo público equivalente. Se conservó ese historial íntegro: se ejecutó el
SQL revisado con `db query` y se registraron únicamente las dos versiones nuevas
dentro de la misma transacción. No se marcó ninguna versión anterior como revertida.

La comprobación posterior en modo de lectura confirmó las dos versiones, las
tres RPC, las capacidades de esquema 2 y los permisos del registro privado
de operaciones. No se crearon horas de prueba sobre personas reales.

## Recuperación de la pantalla de acceso

El aviso de base pendiente ahora permite **Reintentar** o **Volver al inicio
de sesión**. Reintentar repite la comprobación del servidor; los errores
internos se traducen a un mensaje general. La salida evita solicitudes duplicadas
y maneja una falla de conexión sin dejar controles bloqueados permanentemente.

La corrección pasó el análisis estático y las **213 pruebas Flutter**, incluidas
las dos pruebas nuevas de recuperación del acceso. La compilación Windows
release se verificó y quedó abierta para la prueba del responsable.

## Alcance

La base compartida ya tiene las capacidades requeridas para `1.0.7+8`.
La prueba usa una compilación local: todavía no se distribuyó un instalador
firmado ni se actualizaron los demás puestos. Antes de comenzar a registrar
Gremiales en el trabajo habitual, coordinar esa actualización para que todos
los informes reconozcan la nueva modalidad.

La prueba completa de carga, caché e informes debe distinguirse de las pruebas
automatizadas y de la confirmación general del responsable.
Las rutas del respaldo, sus claves, la evidencia y el SQL de operación permanecen
en carpetas locales excluidas del repositorio.
