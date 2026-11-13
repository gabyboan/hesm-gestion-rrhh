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

Las verificaciones usan datos ficticios: PDF individual, vista previa y lote;
prioridad del número; condición Titular y suplente; consulta por DNI; captura
inmutable, permisos, MFA y sesión. No se emiten partes reales para probar.
