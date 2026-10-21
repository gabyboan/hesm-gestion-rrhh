# Registro de cambios

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
de la impresora. La alineación física queda pendiente de comprobar con la
impresora y el formulario utilizados.

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
descarga nueva. El PR y las vistas almacenadas requieren tratamiento adicional.
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
