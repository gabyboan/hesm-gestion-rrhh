# Horas particulares 1.0.10.11

## Incluido en 1.0.11.12

Las mejoras preparadas como 1.0.10.11 se incorporan a la entrega 1.0.11.12,
junto con las reglas de Anual y Médicos. El estado de distribución y los pasos
para actualizar están en [Reglas y actualización 1.0.11.12](REGLAS_1_0_11.md).
La preparación que sigue conserva la evidencia previa.

Preparación del 16 de noviembre de 2026, hora argentina.

Al seleccionar una duración que supera las tres horas particulares del mes,
Cargar muestra el excedente y mantiene disponible Guardar. La pantalla muestra
el total ya guardado y el total con la duración seleccionada. Usa el mes de la
fecha de carga, aunque Ver esté consultando otro período.

Ver muestra los totales completos de particulares, oficiales y gremiales, y
el excedente particular. El resumen también aparece para personas habilitadas
para oficiales. Después de guardar se actualizan los registros y se selecciona
el mes correspondiente. Informe y Excel incluyen la duración completa de los
particulares que cruzan el cupo.

## Base operativa

Se aplicó y registró únicamente la migración
`20261117001144_horas_particulares_sin_bloqueo_por_cantidad.sql`, conservando
las 100 versiones previas del historial. El trigger conserva el bloqueo
transaccional mensual, su propietario, permisos y `search_path` vacío. Las RPC
mantienen el acceso autorizado y la denegación a `anon`.

Antes de aplicarla se creó un respaldo cifrado nuevo y se restauró en un
contenedor sin red. Coincidieron las 91 tablas, 18.967 filas y permisos. Sobre
esa copia se ensayó el SQL exacto y se verificaron ocho cargas particulares,
el excedente y la conservación de los datos históricos. La función operativa
debía coincidir con la del ensayo antes de reemplazarla. La comprobación
posterior confirmó la nueva definición y su registro en el historial.

Las cargas de prueba se ejecutaron exclusivamente en la copia aislada. La
revisión posterior de seguridad no informó hallazgos sobre el trigger cambiado.
Los respaldos y la evidencia de operación permanecen en `.private/`.

## Instalador local

Se generó `HESM-Gestion-RRHH-1.0.10.11-Setup.exe`, en
`dist/Windows-LAN-1.0.10.11/`, con `-Version '1.0.10+11' -RequiredSchema 3`.
La compilación usa los fuentes locales, con sus huellas registradas en la
evidencia privada. El árbol de trabajo contiene otros cambios previos.

- Tamaño: 14.782.803 bytes.
- SHA-256: `039371c6671aae93b99877d6324b4c8acb1d630e910b7e4795e4c7ab1d9aece1`.
- Instalador y manifiesto firmados con la clave Ed25519 del canal existente.
- Paquete extraído: versión correcta, runtime de Visual C++ y mejora de Horas
  presentes; sin archivos de credenciales, claves ni respaldos.
- El código Dart del actualizador aceptó las firmas y el hash del paquete,
  reconoció la actualización desde `1.0.7.8`, `1.0.8.9` y `1.0.9.10` y rechazó
  un instalador alterado.

La base ya está actualizada. El instalador está preparado localmente; no se
publicó en la carpeta del hospital ni se instaló sobre una aplicación abierta.
Para actualizar esta PC, guardar el trabajo, cerrar Gestión y ejecutar el
instalador. La prueba física con una cuenta y la actualización de los otros
puestos se comprueban después de instalar.

Validación final: 241 pruebas Flutter aprobadas con concurrencia 1 y análisis
de `lib/` y `test/` sin observaciones. Incluye las 18 pruebas de Horas y el
recorrido de carga, aviso, séptimo y octavo registros y totales completos en Ver.
