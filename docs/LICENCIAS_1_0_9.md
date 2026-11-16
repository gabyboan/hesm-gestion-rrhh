# Licencias y planilla · 1.0.9.10

Actualización del 16 de noviembre de 2026, código `1.0.9+10`.

Gestión permite **Modificar licencia** y **Borrar licencia** tanto en Licencias
como en **Ficha → Datos e historial**, al desplegar una licencia. Conserva los
permisos de administración. El borrado pide confirmación y anula el registro:
deja de sumar días y de imprimirse, manteniendo el historial.

El mismo formulario se usa en ambas pantallas. Guardar actualiza las consultas,
los totales y la planilla. Al corregir una ficha de papel se conserva el período
calendario aunque la cantidad anotada sea distinta. Estudio continúa usando los
días hábiles calculados por el servidor y sus cupos.

Legajo Digital incorpora controles en la planilla para añadir una licencia arriba
o abajo de la fila seleccionada, editarla o borrarla. Las continuaciones pertenecen
al mismo registro y los controles se ocultan al imprimir. Personas comparte la
búsqueda al escribir de Cargar licencias, conservando filtros y exportación.

La migración `20261116153646_ficha_insertar_filas.sql` conserva el orden por
persona y año en una tabla privada con RLS. Las inserciones validan permisos,
MFA, sesión, persona, año y referencia; guardan la licencia y su posición en una
transacción. Dos cargas simultáneas no pierden filas. Los imprevistos siguen
gestionándose desde su módulo y se pueden usar como referencia para insertar.
Gestión reconoce ese orden en la planilla anual y acumulada.

La base mantiene capacidades 3 y compatibilidad con clientes anteriores. Antes
de habilitar los controles de inserción en Legajo Digital debe aplicarse la
migración. Los clientes anteriores pueden consultar los datos; para imprimir en
el orden de las filas insertadas necesitan esta actualización.

Pasaron las 227 pruebas Flutter, el análisis estático y los contratos PostgreSQL
del proyecto. Las pruebas nuevas comprueban edición y borrado desde ambas
pantallas, cancelación, permisos, errores, actualización de totales, conservación
del período y orden de las filas en la planilla anual y acumulada.

La migración se ensayó sobre una restauración aislada del respaldo cifrado de
90 tablas y 18.960 filas, comprobando que las tablas originales conservaron sus
datos. Después se aplicó y registró en la base compartida y se verificaron RLS y
los permisos de las funciones nuevas.

El código se publica en GitHub y el instalador firmado se distribuye por el canal
privado del hospital. Las instalaciones en cada puesto se comprueban desde el
cliente después de actualizar.
