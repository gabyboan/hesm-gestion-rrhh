# Registro de cambios

## Distribución 1.0.7.8 · 12 de noviembre de 2026

Instalador firmado publicado en el canal privado del hospital. Incluye Ficha y
Licencias, Gremiales, caché, guardado seguro, espera del login y recuperación
del acceso. La base compartida ya tiene las dos migraciones y capacidades 2.

Se extrajo y revisó el paquete y se verificaron firmas, tamaño y SHA-256 desde
la ruta de red. El código del cliente anterior aceptó la actualización y el
verificador rechazó un archivo alterado. Se conservan las versiones anteriores.
La instalación en los puestos receptores se comprueba desde cada cliente.
Véase [Distribución 1.0.7.8](docs/DISTRIBUCION_1_0_7.md).

## Prueba local 1.0.7.8 · 12 de noviembre de 2026

- Aplica las dos migraciones nuevas a la base compartida tras restaurar y
  verificar el respaldo y ensayarlas sobre esa copia. Las capacidades de
  esquema 2 y los permisos de las nuevas RPC quedaron comprobados.
- Sustituye la pantalla sin acciones de error al ingresar por un aviso que
  permite reintentar la comprobación o volver al login, sin exponer errores
  internos literalmente.

Durante esa prueba todavía no se había distribuido el instalador. El detalle está en
[Prueba local 1.0.7.8](docs/PRUEBA_LOCAL_1_0_7.md).

## Preparación 1.0.7.8 · 12 de noviembre de 2026

- Agrega Horas Gremiales para las distintas carreras del padrón de Oficiales,
  con duración extendida, filtro y sección propia en el informe y el Excel.
- Bloquea envíos de horas concurrentes en el cliente y utiliza un UUID por
  operación en la nueva RPC transaccional. Un reenvío confirmado devuelve la
  misma hora; otra carga legítima utiliza un identificador distinto.
- Incorpora caché de sesión acotada, con tiempos de 25 segundos a cinco minutos
  según los datos. Agrupa solicitudes iguales, invalida al guardar o actualizar
  y elimina los datos al salir o cambiar de cuenta. No cachea controles de acceso.
- Pagina los registros de horas y consulta los meses distintos en el servidor.
- Agrega espera progresiva después de contraseñas incorrectas, cuenta regresiva,
  tratamiento de 429 y mensajes de red sin volcar excepciones internas.
- Exige capacidades de backend 2 antes de operar y las declara en el manifiesto
  firmado de los próximos instaladores. Registra fallos técnicos con rotación.
- Prepara copia externa configurable de respaldos verificados y custodia RSA
  para recuperar sus claves en otro perfil de Windows, con clave privada cifrada.

La versión del código es `1.0.7+8`; al preparar estos cambios la última distribución
operativa documentada era `1.0.6.7`. Las nuevas migraciones y el recorrido de puesta en
servicio están en [Actualización 1.0.7.8](docs/ACTUALIZACION_1_0_7.md).

## Estado del repositorio · 11 de noviembre de 2026

Se incorpora el trabajo de Ficha y Licencias realizado después de la distribución
1.0.6.7. El README describe los siete módulos y enlaza el
[estado actual](docs/ESTADO_ACTUAL.md), con la distribución documentada y los
pendientes separados. Se conservan las mejoras ya publicadas y se amplían los
contratos de validación para cubrir los módulos nuevos.

## Fichas: francos y documentación pendiente · 10 de noviembre de 2026

Dos francos del código 60 anotados en una fecha se contabilizan como dos unidades
y conservan un día de duración calendario. Una cantidad de uno con Hasta vacío
se interpreta como la misma fecha de Desde, conservando la evidencia original;
la planilla imprime `/ / /` en Hasta para los períodos de una fecha.

La marca de documentación pendiente es independiente de la confirmación de una
importación. Se muestra en gris en la planilla, incluidas sus continuaciones,
y se informa en el historial y la exportación sin modificar los cómputos.
Modificar la persona, el tipo o el período invalida la cantidad verificada del
papel para evitar reutilizar un cómputo anterior.

## Ficha, Licencias e historial integrado · 3 al 5 de noviembre de 2026

Licencias incorpora carga, consulta, filtros, modificación, anulación auditada
y exportación XLSX. Ficha consulta los mismos registros confirmados desde 2026,
los datos del padrón y los resúmenes por año. La planilla A4 horizontal ofrece
vista preliminar, ampliación e impresión, con tantas hojas como necesite el
historial y sin impresión automática.

Los imprevistos se consultan desde su módulo de origen sin duplicar cargas:
primera carga 43 y siguientes 98 por persona y año. La consulta excluye los
imprevistos importados del Excel y refleja cambios y anulaciones del módulo.
Las importaciones pendientes de confirmación se conservan en una revisión
separada y no aparecen en las consultas y exportaciones habituales.

El selector utiliza los 30 tipos del Excel y los códigos confirmados.
Profiláctica usa 03; Estudio usa 29 y computa días hábiles con los topes de 20
por persona y año y 5 por solicitud, incluido el control de cargas simultáneas.
Las fichas de papel conservan evidencia, cantidades y año de cupo; los
parentescos confirmados de Duelo se mantienen en el catálogo operativo.

Estas entradas describen el código incorporado. La última distribución
operativa documentada continúa siendo 1.0.6.7. Reglas y pendientes en
[Ficha y Licencias](docs/FICHA_Y_LICENCIAS.md).

## 1.0.6.7 · 2 de noviembre de 2026

- Guarda un domicilio inmutable en cada parte al emitir y lo conserva en vistas,
  bandeja y reimpresiones. Los registros anteriores sin copia histórica lo indican.
- Reserva una sola Gestión por cuenta en el servidor, con renovación, bloqueo de
  datos y recuperación tras cierre inesperado. Incluye una prueba de concurrencia.
- Agrega ajustes por impresora, pruebas repetibles y recuperación ante fallas.
- Incorpora MFA opcional, revalidación por hora y comprobación de sesiones revocadas.
- Presenta verificaciones de servicios al iniciar y actualizaciones Windows
  firmadas con versión visible y opciones de instalar o continuar.
- Publica guías de desarrollo, instalación y contribución, además de CI para
  análisis, pruebas Flutter, contratos PostgreSQL y detección de secretos.

Validación: 162 pruebas Flutter y análisis estático aprobados en el conjunto de
la versión; contratos SQL con fixtures ficticios y dos conexiones concurrentes;
Windows x64 compilado, empaquetado y verificado. La entrega operativa se comprobó
con el código del actualizador, incluyendo el rechazo de una copia alterada.

Las migraciones correspondientes se aplicaron y verificaron en el entorno
operativo. Los clientes anteriores deben actualizarse para participar en la
reserva de sesión única. La publicación pública contiene código y documentación;
la distribución del instalador firmado usa el canal privado.

## Cierre de privacidad histórica · 22 de octubre de 2026

El responsable del proyecto confirmó que el tratamiento de la referencia del
PR #1 y las vistas almacenadas ya está resuelto. Se actualizan README y los
documentos de privacidad, preparación, validación, entrega, Windows e inventario
para retirar ese pendiente. Se conservan las comprobaciones históricas y se
registra por separado la confirmación de cierre.

## Integración y validación manual · 21 de octubre de 2026

Los PR [#2](https://github.com/gabyboan/hesm-gestion-rrhh/pull/2) y
[#3](https://github.com/gabyboan/hesm-gestion-rrhh/pull/3) están integrados en
`main`. El análisis estático y las 83 pruebas finalizaron correctamente en
[GitHub Actions](https://github.com/gabyboan/hesm-gestion-rrhh/actions/runs/39618769124).

El responsable del proyecto confirmó que las pruebas manuales de sesión,
permisos e impresora fueron realizadas y aprobadas. Se actualizan README y
los documentos de Windows, validación, preparación y entrega para registrar
ese resultado. Esa confirmación no supuso un despliegue de migraciones ni
incluyó el tratamiento de las capturas históricas del PR #1, cuyo cierre se
confirmó el 22 de octubre de 2026.

## Windows: demostración y empaquetado · 21 de octubre de 2026

Se prepara una demo de consulta independiente del acceso normal, con personas,
registros y partes ficticios. Funciona sin Supabase, bloquea HTTP y las
escrituras, permite revisar PDF y reinicia su bandeja al salir. La calibración
usa un prefijo propio en las preferencias locales.

El script de empaquetado genera las dos variantes de Windows en carpetas
nuevas, conserva los archivos nativos y produce manifiestos y hashes SHA-256.
Incluye una guía para el entorno de prueba y el recorrido manual.

Archivos: `tool/demo/main.dart`, `test/demo/windows_demo_test.dart`,
`tool/build_windows_preview.ps1`, `docs/WINDOWS.md` y las referencias de README
y validación. La integración original del PR #2 conserva su inventario de
140 archivos, documentado por separado.

Los tres archivos `windows/flutter/generated_plugin_registrant.cc`,
`generated_plugin_registrant.h` y `generated_plugins.cmake` se normalizan a LF
mediante `.gitattributes`. Su contenido funcional se conserva; esto evita que
`flutter pub get` marque cambios de formato en una copia limpia y permite
registrar correctamente el estado de origen en los manifiestos de Windows.

## Entrega para revisión · 21 de octubre de 2026

Esta entrega reúne los cambios locales respecto de `d045999`. La fecha indica
la revisión de la documentación, no una fecha de despliegue. La rama de entrega
es `release/gestion-rrhh-2026-10-21`, sobre la base pública limpia `ecb7bfd`. El detalle por
archivo está en el [inventario](docs/CAMBIOS_POR_ARCHIVO.md) y los resultados
ejecutados están en [Validación](docs/VALIDACION.md).

### C01 · Conectividad y continuidad de sesión

Se incorpora una pantalla de espera cuando el monitor detecta falta de acceso
a internet. Mientras está visible, bloquea los clics y el foco del teclado.
La comprobación periódica utiliza un intervalo de cinco segundos y vuelve a
iniciarse al regresar a la aplicación.

El cierre por inactividad se pausa durante la desconexión y comienza a contar
de nuevo al recuperarse la conexión. La comprobación de conectividad no
certifica la disponibilidad de todas las operaciones de Supabase.

### C02 · Preferencias por usuario

Se agrega un diálogo de configuración para elegir tema claro u oscuro y un
tiempo de inactividad de uno a diez minutos. Los valores predeterminados son
tema oscuro y cinco minutos. Las preferencias se guardan por usuario en
`usuario_preferencias`; las políticas SQL restringen el acceso a la fila propia.

Al iniciar sesión se recargan las preferencias y el perfil. Si falla la carga de
preferencias, el acceso continúa con los valores predeterminados. El panel de
módulos incorpora un saludo con apellido y primer nombre y un acceso a la
configuración. Requiere la migración `20260826131746_usuario_preferencias.sql`.

### C03 · Búsquedas compartidas

Se unifica el campo de búsqueda con botón de limpieza, envío inmediato al
presionar Enter y una espera de 300 milisegundos al escribir. Los selectores
locales de personas de Horas filtran inmediatamente.

La búsqueda combina términos en cualquier orden y entre distintos campos.
Normaliza mayúsculas, acentos, espacios y separadores de documentos. Todos los
términos deben aparecer en el registro. Los criterios se implementan en Dart y
en las funciones SQL de búsqueda. Se comprobaron casos representativos en
PostgreSQL; no se verificó su equivalencia exhaustiva.

Francos, Imprevistos, Horas, Médicos y Suplencias adoptan el campo compartido.
Suplencias pasa a filtrar mediante `rpc_suplencias_listado` antes del límite de
5.000 filas y descarta respuestas de solicitudes anteriores para conservar el
resultado de la consulta más reciente. Las RPC requieren la migración
`20261016105121_mejorar_buscadores.sql`.

### C04 · Horas oficiales y trazabilidad de cargas

El selector de horas oficiales utiliza una RPC nueva que incluye personas
activas con una carrera asignada y excluye las bajas vigentes. El resumen deja
de decidir la elegibilidad por un identificador fijo de carrera y consulta el
listado recibido. Una restricción SQL permite otras carreras para el tipo
`OFICIAL` y conserva la regla anterior para las demás modalidades.

Los registros incorporan fecha de creación e identificación de quien realizó
la carga. El repositorio completa nombre y apellido desde `usuarios` y la vista
los muestra cuando están disponibles. Se consultan solo los UUID de autores
necesarios y se evita la consulta si la RPC ya aporta los nombres. Una
denegación de perfiles conserva los registros; los identificadores inválidos
no se interpolan en el filtro. Cinco pruebas HTTP locales cubren estos casos.

### C05 · Partes médicos para personas sin legajo

El listado médico incluye personal activo sin legajo. Los modelos admiten un
legajo nulo y la interfaz lo identifica como «Sin legajo». La impresión utiliza
«SUPLENTE» en ese campo y el nombre del documento usa el DNI como alternativa.
No se asignan números de legajo ficticios.

La migración `20261016101850_medicos_incluir_personas_sin_legajo.sql` permite
el valor nulo y actualiza las RPC de selección y emisión. Se agrega una prueba
SQL con reversión de sus cambios, ejecutada sobre fixtures en PostgreSQL local.

### C06 · Datos y modalidades del parte médico

Se incorpora la marca ART, el DNI opcional del familiar y una aclaración de
fecha o turno de hasta 90 caracteres. El formulario puede completar datos
desde los familiares de la ficha. Los partes familiares no admiten la marca
ART. Las validaciones se reflejan en el formulario y en las RPC modificadas.

Para familiares menores de un año se agrega edad de 0 a 11 meses. La migración
`20261020150000_partes_medicos_edad_en_meses.sql` amplía las firmas SQL. El
cliente omite ese parámetro cuando es nulo para conservar la compatibilidad de
los partes comunes con la firma anterior.

Las modalidades usan los códigos AD, PC y AC. Canje y ART agregan sus textos
al documento; las tachaduras de consultorio corresponden a domicilio y familiar.
La descripción del registro combina agente, familiar y aclaración.

### C07 · Vistas previas de Médicos

Se separan las pestañas «Emitir parte» y «Partes registrados», con búsquedas
independientes. La selección actualiza una vista preliminar sin imprimir ni
registrar un parte. En ventanas más angostas, la lista y la vista se distribuyen
verticalmente.

El formulario de emisión también muestra la vista previa mientras se editan
los datos. Una vista ampliada permite recorrer la hoja y variar el zoom entre
50 % y 400 %. El panel informa cuando utiliza el domicilio vigente de la ficha
para visualizar un registro histórico: no se presenta como una copia histórica
del domicilio original.

### C08 · Impresión médica y calibración por equipo

La vista previa incorpora el formulario vacío digitalizado. La impresión genera
los textos y las tachaduras para superponerlos sobre una hoja preimpresa A4.
Se ajustan posiciones y datos familiares, domicilio y aclaraciones. La versión
actual usa tamaño uniforme de fuente y recorta texto que supera el espacio.
El aviso del formulario ya advierte sobre ese recorte. El domicilio se omite
en modalidad consultorio; torre se incluye en otros datos y se evita repetir
allí el número de calle.

Se agrega un ajuste horizontal y vertical de hasta diez milímetros en cada
dirección, persistido localmente con `SharedPreferences`. El diálogo admite
coma decimal, pasos de 0,1 mm, restablecimiento y una impresión de prueba sin
registrar un parte. La vista previa sobre el escaneo no aplica la calibración
de la impresora. La comprobación manual de impresora fue aprobada según la
confirmación del responsable del proyecto del 21 de octubre de 2026.

### C09 · Ficha de personal, domicilios e inactividad

Las migraciones agregan guardado atómico de datos de persona, carrera y
situación de revista; amplían la ficha; normalizan identificadores y el catálogo
de sexo; y crean historial laboral y domicilios con vigencia. El cambio de
domicilio conserva versiones anteriores. Una migración posterior permite todas
las situaciones de revista existentes en el catálogo.

Se agregan períodos de inactividad, RPC de baja y reactivación, y una validación
que impide registrar partes médicos dentro de esos períodos. Estos cambios
describen el esquema SQL incluido; no implican que se haya agregado una nueva
pantalla de legajos en esta entrega Flutter.

### C10 · Corroboración de identificación y familiares

Se crea un registro de confirmación manual de DNI con fecha y usuario. Las RPC
posteriores incorporan CUIT/CUIL, correspondencia con el DNI y dígito
verificador; corrigen conflictos SQL y el cálculo de posiciones; y evitan
sobrescribir un CUIT/CUIL cargado que sea distinto del corroborado.

Los familiares incorporan estado de fallecimiento y campos de CUIT/CUIL y
validación. Un trigger invalida la confirmación al modificar DNI o nombre, y
limpia el CUIT/CUIL si cambia el DNI. El SQL no constituye por sí solo una
consulta a un registro externo de identidad.

### C11 · RPC para consulta de horas

Se agregan funciones para obtener saldos de francos e imprevistos y una carrera
preliminar. Sus permisos de ejecución se limitan a `service_role`. El control
externo del portal que se menciona en los comentarios SQL no forma parte del
código incorporado en este conjunto de cambios y no fue validado aquí.

### C12 · Privacidad, dependencias y pruebas

Se refuerzan las exclusiones de credenciales, claves, respaldos y exportaciones.
Cuatro scripts con datos nominales quedan locales. Dos capturas con
identificadores se retiran de la galería y se conservan en una carpeta ignorada.
Se revisaron las imágenes de las ramas públicas y del PR #1. La limpieza de
ambas ramas se publicó por separado como `ecb7bfd` y se verificó mediante una
descarga nueva. El tratamiento adicional del PR y las vistas almacenadas quedó
resuelto según confirmación del responsable del 22 de octubre de 2026.
El detalle está en la
[revisión de privacidad](docs/REVISION_PRIVACIDAD.md).

Se incorpora `internet_connection_checker_plus` 3.1.1 y se registra el recurso
del formulario vacío. El lockfile fija la versión resuelta. No se cambió la
versión declarada de la aplicación.

Validación local: **80 pruebas aprobadas**, **análisis de Flutter sin
observaciones** y **38 scripts públicos ejecutados** en una base PostgreSQL
aislada con fixtures, incluidas comprobaciones de RLS y firmas. No se modificó
la base real ni se realizó una impresión física. La migración
`20260722125352_optimize_banco_horas_list.sql` contiene solamente `;`: no
implementa una optimización y no se le atribuye un cambio funcional.

Los ajustes de migraciones antiguas se detallan por archivo. Cinco de ellos
son exclusivamente cambios de espaciado; los otros dos alinean la definición
inicial de Imprevistos con la migración posterior de número de orden. Editar
esos archivos locales no vuelve a aplicarlos en una base existente.

### C13 · Bandeja e impresión por lotes

Se pueden registrar varios partes para revisarlos e imprimirlos después,
manteniendo también la opción de registrar e imprimir de inmediato. La bandeja
evita duplicados por identificador y permite imprimir un parte o el conjunto
en un único trabajo, con una hoja por parte y conservando su orden.

Una cancelación o un error de impresión conserva los partes en la bandeja.
El estado vive en el ámbito autenticado de `AuthGate`: cambiar de sesión
descarta esa bandeja. No se persiste en la base ni se exporta al repositorio.
Las pruebas cubren la gestión de la bandeja, los flujos de interfaz y el lote PDF.

### C14 · Inicio e identidad visual

Se incorpora una identidad HESM vectorial, icono de Windows, acceso renovado y
una pantalla de inicio con engranaje animado y progreso. El inicio correcto
mantiene el splash al menos cinco segundos. El dibujo considera la preferencia
de reducción de movimiento. También se limita la opacidad del aviso animado
al rango válido para evitar errores de la curva elástica.

### C15 · Comprobaciones automatizadas en GitHub

El workflow `quality.yml` propone instalar dependencias respetando el lockfile,
ejecutar análisis con infos fatales y correr las pruebas Flutter en cambios a
`main` y sus PR. Utiliza permisos de lectura del contenido. Se verificaron los
comandos localmente; no se ejecutó una publicación ni una corrida en GitHub
Actions durante esta revisión. Las pruebas SQL quedan fuera de ese workflow.
