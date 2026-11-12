# Estado actual de HESM Gestión RRHH

## Preparación del 12 de noviembre de 2026

El código `1.0.7+8` agrega Horas Gremiales, guardado con reconocimiento de
reenvíos, caché por sesión y espera progresiva del login. Incluye paginación,
compatibilidad del backend, diagnóstico local y herramientas de respaldo
externo configurable. El alcance, las pruebas y el orden de actualización se
detallan en [Actualización 1.0.7.8](ACTUALIZACION_1_0_7.md).

Las dos migraciones nuevas fueron aplicadas a la base compartida durante la
prueba local del 12/11/2026, con respaldo restaurado y ensayo sobre esa copia.
La distribución del instalador sigue pendiente. La última distribución operativa
documentada es `1.0.6.7`. Véase [Prueba local](PRUEBA_LOCAL_1_0_7.md).

La revisión siguiente conserva la evidencia del trabajo de Ficha y Licencias.

Revisión del 11 de noviembre de 2026. La referencia pública anterior es el
commit `dcda287` de `main`, correspondiente al PR #8 del 2 de noviembre.
Este documento describe el código preparado sobre esa base y distingue su
alcance de la distribución instalada.

## Módulos implementados

| Módulo | Trabajo disponible en el código |
| --- | --- |
| Horas | Carga y consulta, cupos, excedentes, autoría e informes mensuales exportables. |
| Francos | Movimientos y saldos con permisos separados de lectura, carga y administración. |
| Imprevistos | Gestión en su módulo e integración de su historial en Ficha y Licencias sin copiar registros. |
| Médicos | Partes propios y familiares, ART, personas sin legajo, domicilio de emisión conservado, QR y devolución, listado de Enfermería e impresión individual o por lote. |
| Suplencias | Consulta y gestión con permisos por usuario y búsquedas en el servidor. |
| Licencias | Carga, modificación, anulación con auditoría, filtros, exportación XLSX, catálogo de 30 tipos y revisión separada de importaciones. |
| Ficha | Datos personales y laborales existentes, historial confirmado desde 2026, resumen anual y planilla PDF con vista preliminar y continuaciones. |

## Trabajo de noviembre

- **Ficha y Licencias:** la carga se realiza en Licencias; Ficha consulta la
  misma información. Los permisos de lectura de Ficha no conceden escritura.
- **Imprevistos:** la consulta integrada toma los registros vigentes del módulo
  de origen, con su número de orden. Asigna 43 a la primera carga por persona y
  año y 98 a las siguientes, según el orden de creación. Los del Excel se
  conservan como evidencia y se excluyen de esa consulta.
- **Estudio:** código 29, hasta 20 días hábiles por persona y año y 5 por solicitud.
  Se usa el calendario del sistema y se protege el cupo ante cargas simultáneas.
- **Catálogo:** se conservan los 30 tipos del Excel; Profiláctica usa 03. Los
  códigos operativos y parentescos confirmados se detallan en la guía funcional.
- **Fichas de papel:** se conservan la evidencia, la cantidad anotada y el año de
  cupo separados de la duración calendario. La planilla continúa en las hojas
  necesarias y mantiene observaciones extensas sin volver a sumar días.
- **Ajustes del 10 de noviembre:** dos francos 60 en una fecha computan dos
  unidades y conservan un día calendario. Una carga de un día muestra `/ / /`
  en Hasta. La documentación pendiente aparece en gris en la ficha y se informa
  en el historial y la exportación, sin cambiar los totales.
- **Demo:** incluye los siete módulos con proveedores ficticios y bloquea las
  escrituras y el acceso HTTP. La galería de imágenes sigue mostrando los cinco
  módulos de la entrega de octubre.
- **Operación:** se incorporan los scripts existentes de copia cifrada y ensayo
  aislado de restauración, sus pruebas y las guías de instalación y traslado.

El detalle de reglas, evidencia y decisiones se conserva en
[Ficha y Licencias](FICHA_Y_LICENCIAS.md) y [Licencias](LICENCIAS.md).

## Distribución y comprobaciones

La última distribución operativa documentada es **1.0.6.7**, publicada el
2 de noviembre de 2026. Incluye sesión única por cuenta, domicilio histórico,
actualizaciones firmadas, verificaciones de inicio e impresión con ajuste por
impresora. El número de `pubspec.yaml` se conserva hasta preparar una nueva
distribución.

Esta actualización incorpora el trabajo posterior al repositorio. No acredita
que esos cambios ya estén instalados en todos los equipos ni vuelve a ejecutar
migraciones sobre una base compartida. Las comprobaciones de esta revisión se
registran en [Validación](VALIDACION.md), separadas de la evidencia histórica.

## Pendientes reales

- Conciliar las diferencias de identidad, códigos, datos laborales y posibles
  duplicados de las importaciones. Los registros apartados no se incorporan
  automáticamente al historial confirmado.
- Revisar la recepción de la documentación antes de quitar su marca pendiente.
- Preparar una nueva versión instalable con los cambios de Ficha y Licencias y
  comprobarla en los puestos correspondientes.
- Implementar la aplicación móvil de auditoría de partes médicos; el escritorio
  y sus contratos QR ya existen.
- Conciliar y probar el esquema inicial antes de ofrecer el asistente integral
  de instalación modular, que sigue siendo una propuesta.
- Preparar copia externa y recuperación portable de respaldos: el esquema
  documentado utiliza una clave protegida por el perfil de Windows.

Las credenciales, los documentos de origen, las cargas nominales y los respaldos
operativos permanecen fuera del repositorio público.
