# Condición y legajo en Médicos · 1.0.8.9

Corrección del 13 de noviembre de 2026. La versión anterior imprimía SUPLENTE
automáticamente al faltar el número de legajo, aunque la persona fuera titular.

## Regla de impresión

| Dato disponible | Casillero Legajo N.º |
| --- | --- |
| Número de legajo | El número, cualquiera sea la condición. |
| Sin número y condición Titular | Vacío. |
| Sin número y condición de suplencia | SUPLENTE. |
| Sin número y otra condición conocida | El nombre de esa condición. |
| Sin número y condición desconocida o ambigua | Vacío; no se supone una suplencia. |

La vista previa consulta la condición vigente de la ficha por una RPC autorizada.
Al emitir, la base conserva la condición real, sin aceptar una enviada por el
cliente. La impresión individual, la vista ampliada y los lotes usan el mismo
dato. Cambiar la ficha después no reescribe la condición de un parte emitido.

Los partes anteriores sin copia histórica no se rellenan con la condición actual.
Si tampoco tienen número, el casillero queda vacío. No se asignan números de
legajo ficticios ni se cambia la situación de revista desde esta corrección.

## Puesta en servicio

Requiere `20261113114028_medicos_condicion_legajo.sql`, ensayada sobre una copia
restaurada antes de aplicarla. La base anuncia capacidades 3 y el instalador las
declara en su manifiesto firmado; los clientes anteriores siguen siendo compatibles.
Actualizar desde el canal privado del hospital, conservando las preferencias.

## Distribución verificada

Publicada el 13 de noviembre de 2026 en el canal privado del hospital, compilada
desde `210781f`. La migración fue ensayada sobre una restauración aislada de un
respaldo cifrado de 90 tablas y 18.853 filas; después se aplicó y registró en la
base compartida. La lectura posterior comprobó capacidades 3 y que los partes
anteriores conservan su condición desconocida, sin reconstruirla.

| Dato | Valor |
| --- | --- |
| Instalador | HESM-Gestion-RRHH-1.0.8.9-Setup.exe |
| Tamaño | 14.773.647 bytes |
| SHA-256 | `21807a6a858f47e79db95b0900d0aca5d01c87ae880e59243a6ea2767d7f6353` |

Se extrajo el paquete y comprobó su versión numérica de Windows, runtime y
ausencia de archivos privados. El verificador Dart aceptó el manifiesto y el
instalador tanto localmente como desde la red y rechazó una copia alterada.
Las versiones anteriores y los permisos de distribución se conservan.

Las 216 pruebas Flutter, el análisis estático, los contratos PostgreSQL, las
herramientas Python y el análisis de secretos pasaron. Estas comprobaciones no
equivalen a la instalación en cada puesto: la aplicación abierta debe actualizarse
desde Configuración → Actualizaciones del hospital.

Las verificaciones usan datos ficticios: PDF individual, vista previa y lote;
prioridad del número; condición Titular y suplente; consulta por DNI; captura
inmutable, permisos, MFA y sesión. No se emiten partes reales para probar.
