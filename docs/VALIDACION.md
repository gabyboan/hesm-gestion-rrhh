# Validación de la entrega

Los PR [#2](https://github.com/gabyboan/hesm-gestion-rrhh/pull/2) y
[#3](https://github.com/gabyboan/hesm-gestion-rrhh/pull/3) están integrados en
`main` desde el 21 de octubre de 2026. El PR #2 conserva los siete commits
funcionales revisados. Ambas variantes compilaron en Windows x64.
La etapa posterior de demo y empaquetado se describe en [Windows](WINDOWS.md).
Sus tres pruebas adicionales elevan el conjunto a **83 pruebas aprobadas**:
recorrido y bloqueo de escrituras, reinicio con limpieza de bandeja y
preferencias, y bloqueo de clientes HTTP. Los resultados de 80 pruebas que se
detallan a continuación corresponden a la entrega funcional original.

El [workflow de `main`](https://github.com/gabyboan/hesm-gestion-rrhh/actions/runs/39618769124)
terminó correctamente con análisis estático y 83 pruebas. El responsable
del proyecto confirmó el 21 de octubre de 2026 que las pruebas manuales de
sesión, permisos e impresora fueron realizadas y aprobadas. Se registra ese
resultado informado; no se atribuye a una ejecución automatizada ni a un
despliegue de la base de datos.

Actualización: 21 de octubre de 2026. Base de comparación local: `d045999`.
Resultados del conjunto funcional preparado en la rama de entrega. Esta etapa incorporó correcciones de autoría de Horas, contrato de
domicilio con torre, aviso de nombres largos y pruebas de integración locales.
Se incluyeron también los cambios nuevos de bandeja de impresión, edad en
meses e identidad visual encontrados durante la revisión.

## Entorno y resultados

| Control | Resultado | Alcance |
| --- | --- | --- |
| Flutter | 3.38.6, canal stable | SDK instalado localmente. |
| Dart | 3.10.7 | Versión incluida en el SDK utilizado. |
| `flutter test --reporter expanded` | Aprobado, código de salida 0 | 80 pruebas en 15 archivos. |
| `flutter analyze --fatal-infos` | Aprobado, código de salida 0 | Sin observaciones en el conjunto final de la copia de entrega. |
| Inventario y enlaces | Comprobados con un control local | Los 108 archivos pendientes tienen una entrada individual; se verifican los enlaces de los seis documentos de entrega. |
| Gitleaks 8.30.1 | Sin hallazgos en los escaneos realizados | Selección pública de archivos, historia local, ramas remotas, PR #1 y propuesta de historia saneada; salidas con redacción total. No certifica ausencia de datos personales. |
| Credenciales e importaciones privadas | Exclusiones comprobadas con Git | Los archivos privados locales no forman parte de los archivos nuevos elegibles. |
| PostgreSQL 16.11 aislado | Aprobado, código de salida 0 | Se ejecutaron 38 scripts públicos, contratos de permisos y datos, y la prueba médica sobre fixtures ficticios. No se consultó ni modificó la base real. |
| Sesión, permisos e impresión física | Aprobados según confirmación del responsable del proyecto | Pruebas manuales informadas el 21 de octubre de 2026, separadas de las pruebas automatizadas. |

El servidor PostgreSQL exclusivo de pruebas se detuvo al finalizar. Los
registros de ejecución permanecen en `build/publication-validation/`, una
carpeta ignorada por Git. Este documento resume los resultados sin copiar rutas
personales del equipo ni valores de configuración.

## Cobertura disponible

| Archivo de pruebas | Casos | Qué comprueba |
| --- | ---: | --- |
| `test/core/network/internet_connection_gate_test.dart` | 1 | Bloqueo de interacción sin internet y recuperación con un monitor simulado. |
| `test/core/utils/date_fmt_test.dart` | 5 | Formatos y resúmenes de fechas y minutos. |
| `test/core/utils/file_ext_test.dart` | 4 | Extensiones de archivo y normalización de mayúsculas. |
| `test/core/utils/search_query_test.dart` | 5 | Términos combinados, acentos, separadores, documentos formateados y consulta vacía. |
| `test/core/widgets/startup_splash_test.dart` | 1 | Identidad, progreso y animación del inicio sin excepciones. |
| `test/features/horas/horas_repository_test.dart` | 5 | Solicitudes HTTP locales: autoría filtrada por UUID, datos completos, denegación de perfiles, identificadores inválidos y errores de servidor. |
| `test/features/medicos/ajuste_impresion_medica_test.dart` | 7 | Persistencia local simulada, límites, valores no finitos, coma decimal, cancelación y restablecimiento. |
| `test/features/medicos/medico_familiar_test.dart` | 2 | Conversión de familiares y datos opcionales. |
| `test/features/medicos/medico_persona_test.dart` | 2 | Personas con y sin legajo. |
| `test/features/medicos/cola_impresion_test.dart` | 5 | Lotes, cancelación, fallo, impresión individual y retiro de partes de la bandeja. |
| `test/features/medicos/medicos_repository_test.dart` | 4 | Contratos HTTP de creación: compatibilidad con la firma anterior, edad en años/meses y errores de permisos sin repetir el guardado. |
| `test/features/medicos/medicos_vista_preliminar_test.dart` | 11 | Selección, registros, disposición, ampliación, búsquedas, carga para imprimir después y tratamiento de cancelaciones. |
| `test/features/medicos/parte_medico_printer_test.dart` | 12 | PDF individuales y lotes, orden, meses, fuente uniforme, escaneo, tachaduras, torre y domicilio sin duplicación de número. |
| `test/features/medicos/parte_medico_test.dart` | 13 | Modalidades, descripciones, datos familiares y edad en meses, ART, aclaraciones, domicilios y legajo opcional. |
| `test/features/preferences/domain/user_preferences_test.dart` | 3 | Saludo del perfil y normalización de preferencias. |
| **Total** | **80** | Pruebas unitarias y de widgets; no equivalen a una validación contra producción. |

Las pruebas de PDF inspeccionan también contenido, orden de páginas y
operadores de fuente; se corrigió el lector de los tests para separar los
streams crudos del texto extraído. No comparan visualmente la hoja impresa ni
garantizan la posición física de cada campo. El aislamiento de preferencias
se comprobó aparte en PostgreSQL con el rol `authenticated`. El monitor
simulado no prueba una caída real de red ni todos los estados del temporizador.

## Resolución de los hallazgos de código y SQL

| ID | Hallazgo | Estado y alcance |
| --- | --- | --- |
| V01 | Torre estaba mezclada con una carga nominal. | Separada en `20261020132130_separar_torre_domicilio_publico.sql`; la secuencia pública se probó sin las cuatro cargas privadas. |
| V02 | Faltaba torre en la RPC de domicilio. | Contrato ampliado, función elevada privada y envoltorio público invoker; torre se imprime en otros datos. SQL y contenido de PDF verificados. |
| V03 | Cambios en las firmas iniciales de Imprevistos. | Se reprodujeron definición y permisos en orden y se probaron creación con número de orden, consulta, modificación y eliminación. Resta contrastar el historial aplicado en la base real antes de un despliegue. |
| V04 | Migración de optimización con solo `;`. | Se conserva sin atribuirle una mejora funcional. No se inventó una optimización que no estaba en el archivo. |
| V05 | Autoría de Horas requería lectura de todos los perfiles. | Se consultan solo UUID válidos de autores necesarios; si la RPC ya aporta los nombres no hay consulta extra. El error 42501 conserva los registros; otros errores se propagan. Cinco pruebas HTTP aprobadas. |
| V06 | Dependencia de nuevas firmas RPC. | Se probaron las definiciones de la secuencia pública, llamadas a los listados y emisión médica con la firma final de nueve parámetros. Los cuatro tests HTTP médicos verifican también clientes frente a la firma anterior. |
| V07 | Normalización duplicada entre Dart y SQL. | Se ejecutaron casos comunes de acentos, orden de palabras, documentos y tratamiento literal de `%` en PostgreSQL, además de la suite Dart. No es una demostración exhaustiva de equivalencia. |
| V08 | La reimpresión puede utilizar el domicilio vigente de la ficha. | Confirmar que ese comportamiento sea el esperado; no hay una instantánea histórica del domicilio en el modelo de parte incluido. |
| V09 | Aviso incorrecto sobre nombres largos. | El aviso ya advierte que pueden quedar recortados. La versión actual del PDF utiliza tamaño uniforme de fuente. La prueba manual de impresora fue aprobada según la confirmación del responsable del proyecto. |

## Pruebas SQL realizadas y límites de despliegue

Se creó un clúster exclusivo de PostgreSQL 16.11 ligado a `127.0.0.1`, con un
puerto propio y una base llamada `publication_test`. El script
`supabase/tests/publicacion_contratos.sql` comprueba ese nombre y la ausencia
del esquema Auth y de la tabla de personas antes de crear fixtures.

La base sintética define los prerrequisitos que faltan en el repositorio:
El antiguo `supabase_schema.sql` local está vacío y no se incluye en la entrega pública. Las tablas y helpers iniciales de esa prueba
no son una copia completa del esquema real. Las 38 migraciones incluyen siete
archivos existentes modificados y 31 nuevos, incluida la reserva sin efecto.
Los cuatro scripts nominales quedan fuera.

Se comprobó la restricción de lectura directa de domicilios por RLS frente al
acceso médico autorizado por RPC, denegación sin rol o sesión, aislamiento de
preferencias, búsquedas, horas oficiales y firmas de Imprevistos. La prueba
médica ejecutó sus cuatro modalidades y conservó la edad familiar en meses.

Antes de desplegar en un proyecto real, queda:

1. Obtener y revisar un esquema de partida sin datos personales y contrastarlo con el historial de migraciones aplicado.
2. Contrastar los contratos SQL con el modelo de roles y sus políticas del entorno de destino; los helpers de partida de los fixtures son simplificados. Las pruebas manuales de permisos informadas como aprobadas no sustituyen esta revisión previa a aplicar migraciones.
3. Revisar asesores de seguridad, funciones elevadas y permisos en el entorno real. No se ejecutaron asesores ni consultas en producción.
4. Completar los escenarios que no cubre este script de contratos ni la confirmación manual recibida, según el alcance del despliegue.

La sesión, los permisos y la impresora ya cuentan con la aprobación manual
informada por el responsable del proyecto. Al cambiar de impresora, formulario
o configuración, corresponde repetir el control de impresión.

La prueba médica establece una identidad de solicitud y termina con
`rollback`; el script de contratos utiliza también `SET LOCAL ROLE
authenticated`. Las secuencias pueden avanzar aunque se reviertan las filas.
Ninguno se ejecutó sobre datos reales de personal.

## Privacidad antes del commit y del push

- Mantener ignorados `credenciales.env`, las cuatro cargas nominales, capturas originales y respaldos.
- Mantener el escaneo especializado sobre la selección final, sin imprimir valores detectados.
- La limpieza autorizada de ambas ramas ya se publicó y verificó con una descarga nueva: solo queda el panel revisado y Gitleaks no informó hallazgos. Sigue pendiente gestionar con GitHub la referencia del PR #1 y sus vistas almacenadas.
- Incorporar archivos por grupos explícitos y revisar el contenido preparado para cada commit.
- No publicar checkpoints, bundles, todas las referencias ni credenciales de un entorno de demostración.

El [plan de preparación](PREPARACION_GITHUB.md) mantiene el estado general de
publicación. El [inventario](CAMBIOS_POR_ARCHIVO.md) relaciona cada archivo con
su cambio y propone el orden de los commits. La
[revisión de privacidad](REVISION_PRIVACIDAD.md) documenta exactamente la
propuesta preparada, el PR y las limitaciones de cachés y copias.

## Copia de entrega y galería

Las 80 pruebas se repitieron correctamente en la copia aislada de entrega.
La galería se generó desde los widgets reales con proveedores ficticios, sin
sesión Supabase; el generador y sus pasos se documentan en
[Galería de demostración](mockups/README.md). No forma parte de las 80 pruebas
funcionales ni verifica la impresión física.
