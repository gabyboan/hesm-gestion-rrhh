# Gestión RRHH 1.0.11.12

Versión del 17 de noviembre de 2026. Código `1.0.11+12` para Windows x64.

Las licencias anuales se cargan en días hábiles. El cálculo de Hasta y los
totales excluyen sábados, domingos y feriados del calendario del sistema. Se
conservan las cantidades verificadas y las fechas originales de las fichas
de papel al corregir otros campos.

Médicos bloquea la emisión y la devolución de partes duplicados o con períodos
superpuestos para la misma persona. El último día del período está incluido:
un parte del 11/11 al 16/11 impide cargar otro que incluya el 16/11. El aviso
identifica los partes existentes y solo ofrece **Entendido**; no permite
guardar ni imprimir el parte rechazado. La base también valida las fechas y
serializa las operaciones simultáneas por persona.

Horas incorpora las mejoras preparadas como 1.0.10.11: avisa al superar las
tres horas particulares mensuales y permite guardar el excedente. Cargar y Ver
muestran los totales del mes; Informe y Excel conservan la duración completa.

Se corrige la inicialización del login y se conservan las mejoras publicadas
de condición y legajo médicos, edición de licencias desde Ficha y orden de la
planilla. No se requiere reiniciar Windows para actualizar.

## Base y distribución

Las migraciones de anuales, excedentes particulares y superposiciones médicas
están aplicadas y registradas en la base operativa. Se mantiene el requisito
de capacidades de esquema 3 y las comprobaciones de permisos, sesión y MFA.
Los contratos se prueban en una base desechable con datos ficticios.

GitHub publica el código y las notas de esta versión. El instalador operativo
y su manifiesto llevan la firma Ed25519 del canal existente y se distribuyen
por la carpeta privada de actualizaciones del hospital.

Para actualizar otro puesto, abrir **Configuración → Actualizaciones del
hospital** y buscar la versión **1.0.11.12** usando la carpeta de red habitual.
También se puede cerrar HESM y ejecutar el instalador de
`versions\1.0.11.12`. La PC publicadora debe estar encendida y conectada a la
red del hospital. La instalación en cada puesto se comprueba desde su cliente.

## Verificación de la entrega

- 246 pruebas Flutter y análisis estático sin observaciones.
- 17 pruebas Python y contratos PostgreSQL aislados aprobados, incluidas las
  reglas nuevas y las correcciones anteriores de Ficha y condición médica.
- Instalador extraído: versión `1.0.11.12`, runtime de Visual C++ y funciones
  nuevas presentes; sin archivos de credenciales, claves ni respaldos.
- Firmas del instalador y manifiesto, tamaño y SHA-256 verificados.
- El cliente reconoce la actualización desde `1.0.7.8`, `1.0.8.9`, `1.0.9.10`
  y `1.0.10.11`; rechaza una misma versión y un instalador alterado.

| Dato | Valor |
| --- | --- |
| Instalador | `HESM-Gestion-RRHH-1.0.11.12-Setup.exe` |
| Tamaño | 14.783.410 bytes |
| SHA-256 | `108fdcfea9a8f83a267d18fef804414fcc80270995781c14a5559218f19591c8` |
| Requisito de base | Capacidades 3 |

Las versiones anteriores se conservan en el canal. La evidencia de publicación,
lectura por UNC e instalación de la PC anfitriona se guarda fuera del código
público; los demás puestos se verifican al actualizar cada cliente.
