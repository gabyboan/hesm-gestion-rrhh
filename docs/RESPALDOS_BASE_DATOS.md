# Respaldos antes de cambiar la base

El repositorio público contiene código y contratos con datos ficticios. Las
copias del entorno operativo se conservan cifradas fuera de GitHub, mediante el
procedimiento autorizado del entorno.

## Antes de una migración

1. Confirmar el proyecto de destino, el esquema y el historial aplicado.
2. Obtener un respaldo reciente de datos, estructura, funciones y permisos.
3. Guardar la copia cifrada en un destino privado y conservar la clave por separado.
4. Probar la restauración en una instancia aislada antes de usarla como respaldo
   de recuperación.
5. Registrar el resultado, la fecha y la huella del archivo sin publicar su contenido.

La comprobación debe comparar estructura, filas y permisos, además de confirmar
que la aplicación puede consultar los datos restaurados. Los archivos de Storage
y las configuraciones externas del servicio requieren revisar su propio alcance.
Una exportación de filas por sí sola no demuestra una recuperación completa.

Los tests de `supabase/tests/` verifican contratos y permisos con fixtures
ficticios; su función es comprobar cambios de código. La prueba de restauración
se realiza con el procedimiento privado del entorno.
