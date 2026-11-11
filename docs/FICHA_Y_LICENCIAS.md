# Ficha y Licencias

## Alcance aclarado por el usuario

La carga y las correcciones se realizan en Licencias. Ficha consulta los datos
existentes del empleado y las mismas licencias confirmadas, vinculadas a esa
persona. No se duplica la carga ni se copian los registros entre módulos.

Los imprevistos se gestionan en el módulo **Imprevistos**. Ficha y Licencias los
consultan directamente, desde 2026, con su número de orden y observación.
`rpc_licencias_historial` combina las licencias confirmadas con los imprevistos
vigentes vinculados al padrón, sin copiar filas. La primera carga vigente de cada
persona y año lleva 43; las siguientes, 98. El orden es el ID de carga del módulo,
no la fecha ni el número de orden. Una modificación, cambio de año o anulación
se refleja en la consulta y reordena los códigos vigentes.

Los imprevistos del Excel quedan conservados como evidencia y se excluyen de
esta consulta: el módulo es su fuente. Los registros procedentes de Imprevistos
se identifican y administran desde allí; los permisos de Ficha/Licencias permiten
consultarlos, sin conceder escritura en el módulo de origen. Los códigos 43/98
no se ofrecen para cargas nuevas de Licencias, y la base también rechaza ese uso.

Ficha permite buscar por nombre, DNI o legajo y consultar desde 2026: historial,
tipos, fechas, cantidad de registros y días por año. El resumen excluye anulaciones
y reparte los días de una licencia que cruza diciembre entre los años respectivos.
Muestra legajo, reloj, fecha de ingreso, carrera, situación de revista y función
del padrón existente. Para la ficha impresa consulta también domicilio vigente,
fecha de nacimiento y teléfono. No incorpora
nuevos datos del Excel ni calcula cupos o saldos sin sus reglas acordadas.

## Ficha impresa

Al seleccionar una persona, «Planilla» muestra dentro de Ficha la vista preliminar
A4 horizontal, con todas sus hojas, siguiendo el comportamiento de Partes Médicos.
«Ampliar / imprimir» abre la planilla con más espacio y permite guardar PDF o
imprimir. La vista preliminar no imprime automáticamente. «Datos e historial»
mantiene los datos laborales, el resumen anual y el detalle de cada carga.
Por defecto incluye el historial acumulado desde 2026;
también se puede elegir solo el año seleccionado en pantalla. Al llenar la
primera página (19 renglones), continúa en otras hojas de 21 renglones, repitiendo
nombre, legajo y DNI. No hay un límite de dos páginas ni se reinicia la ficha al
cambiar de año. Las licencias anuladas quedan fuera de la impresión.

La estructura sigue los dos PDF aportados como modelo. El ejemplo completado
de 2024/2025 se utilizó únicamente para comprobar columnas y anotaciones: no se
extrajeron ni importaron sus registros. El código 03 va en «Lic. Profiláctica»;
43 y 98 en «Art. 8». Los códigos sin columna específica quedan identificados con
su descripción y cantidad en Observaciones. El DNI familiar y el número de orden
se conservan en sus columnas. Las observaciones extensas continúan en renglones
adicionales, sin volver a contabilizar días. La cantidad literal permite imprimir
anotaciones como `20/23`; el resumen anual sigue usando días calendario.

Cuando Desde y Hasta corresponden a la misma fecha, la planilla muestra `/ / /`
en las casillas Día, Mes y Año de Hasta, tanto en la vista preliminar como al
imprimir. La fecha real se conserva. La comparación utiliza las fechas del período,
no la cantidad de días hábiles de Estudio.

## Importaciones

El usuario indicó que hay que consultarle antes de importar. Primero se debe
presentar la selección de hojas, campos, tipos de licencia y períodos que se
propone extraer, con cantidades y diferencias detectadas. Solo se debe ejecutar
la importación de esa selección después de su confirmación expresa.

El lote inicial de 4.956 registros quedó apartado por indicación del usuario.
El 4/11/2026 autorizó la selección de la versión actualizada, con 5.009 registros
válidos, y luego indicó expresamente incorporar solo las filas cuyo DNI y nombre
coincidan con el padrón, sin corregir DNI por coincidencia de nombre.

Se incorporaron 757 licencias de 225 personas. Las otras 4.252 siguen apartadas:
4.173 por diferencias de DNI/nombre, 77 por falta de ficha y 2 repeticiones entre
los registros con identidad comprobada. Las 6 filas inválidas se conservaron para
revisión. Los 53 registros nuevos del archivo se añadieron con su trazabilidad;
el resto reutiliza los registros existentes. Se preservaron DNI, nombre, fechas,
días y evidencia original, sin duplicar el lote anterior.

Inicialmente, 513 registros tenían código operativo confirmado y otros 244
conservaban el tipo original y una observación de código pendiente. Las
confirmaciones posteriores de Estudio y Profiláctica se detallan más abajo;
el Excel por sí solo no permite distinguir Familiar 10/11.
Se completaron 131 funciones y 8 relojes
antes vacíos, en 136 personas; las diferencias con datos vigentes se conservaron
para revisión. El complemento laboral tiene registro de procedencia en el historial.

Posteriormente, por indicación del usuario, la consulta de Art. 8 se conectó al
módulo Imprevistos. Al verificar el 4/11/2026 había 382 imprevistos activos desde
2026: 179 con código 43 y 203 con 98. De ellos, 381 tenían número de orden;
el dato ausente restante se conserva sin inventar. La consulta integrada muestra
749 licencias del lote y los 382 imprevistos del módulo (1.131 registros).
Los ocho imprevistos del lote confirmado siguen almacenados como evidencia,
pero ya no se contabilizan en esta consulta. No se importaron más filas del Excel
ni se corrigió ningún DNI para hacer esta conexión.

El usuario confirmó después el código **29** para Estudio, con 20 días hábiles
anuales y hasta 5 por solicitud. Se recodificaron las 15 licencias ya incorporadas
de ese tipo, conservando sus períodos y evidencia. Las 59 filas de Estudio con
identidad diferente siguen apartadas; los códigos pendientes de lo ya cargado
quedaron en 229. Los familiares incluyen 10 y 11 y siguen pendientes de distinguir.
La consulta de Estudio computa hábiles con el calendario del sistema y devuelve
su reparto anual para que los totales y la planilla no incluyan fines de semana
ni feriados. El total calendario original se conserva y aparece en la exportación.

El 5/11/2026 el usuario confirmó que Profiláctica utiliza **03** y que se usan
únicamente los tipos presentes en el Excel. El selector conserva los **30 tipos**
con sus nombres originales, incluyendo las variantes de código conocidas.
Los filtros agrupan cada tipo, tanto para las cargas nuevas como para los
registros históricos. Los demás códigos se conservan sin ofrecerse para cargar.
Se recodificaron las **10 profilácticas ya incorporadas**; sus 282 filas apartadas
siguen sin confirmar. Quedan **219** licencias incorporadas con código pendiente.
No se corrigieron DNI, importaron filas ni cambiaron permisos en este ajuste.

RLS excluye los registros no confirmados de consultas y exportaciones normales,
incluso desde clientes anteriores. Tampoco bloquean cargas nuevas del mismo
tipo y período. La revisión separada de administración muestra su resumen.

Las importaciones futuras también quedan no confirmadas. No hay una acción de
interfaz que las incorpore automáticamente al historial de trabajo. Cualquier
selección posterior requiere nueva confirmación y conciliación de los pendientes.

## Permisos

`FICHA_LECTURA` permite consultar el padrón y el historial confirmado. No concede
entrada a Licencias ni permiso para cargar, modificar o anular. Los roles de
Licencias conservan sus funciones independientes. No se asignaron roles nuevos
automáticamente a usuarios.

## Decisiones pendientes

Las fichas escaneadas se incorporan como una fuente distinta del Excel: se guarda
la huella del PDF, su página y renglón. Solo se confirman lecturas claras desde
2026, conciliadas con el historial para evitar duplicados. Las diferencias de
identidad, fechas, cantidades y posibles duplicados quedan en una revisión
separada. La evidencia de una ficha puede completar un registro existente sin
reemplazar la procedencia ni el DNI original del Excel.

La cantidad explícita del papel y el año del cupo se conservan separados de la
duración calendario. El resumen utiliza esos días anotados verificados. Una
edición posterior del tipo, persona o período invalida esa cantidad para no
reutilizar un cómputo anterior. Estudio conserva su cálculo hábil y sus cupos.

En la revisión de pendientes del 10/11/2026 el usuario confirmó que una cantidad
explícita de **1** con Hasta vacío representa la misma fecha que Desde. Se conserva
el blanco original como evidencia y la planilla muestra `/ / /` en Hasta.
También confirmó que **dos francos** del código **60** anotados en una fecha única
se contabilizan como **2**: el historial y el resumen usan esos dos francos y
conservan **1** como duración calendario. Esta excepción se limita a Franco 60,
cantidad 2 y período de una fecha; los otros tipos mantienen su validación.

El catálogo admite los códigos operativos confirmados: Matrimonio 27,
Perfeccionamiento 32, Gremial 50 y Duelo por padre 19, hermana 20, abuelo o abuela
21 y tío 22. El código 22 de este catálogo operativo corresponde a Duelo y no
ocupa la columna Estudio, que utiliza el código 29 confirmado. A.R.T.
comparte 04/07 con Enfermedad, distinguiéndose por categoría y leyenda; los
restantes códigos mantienen su unicidad. Los históricos no se recodifican
masivamente. Imprevistos continúa consultándose desde su módulo de origen.

Las anotaciones pendientes de recibir el papel pueden mostrarse en gris mediante
`documentacion_pendiente`, independiente de la confirmación de importación.
La marca se conserva en la planilla, incluidas sus continuaciones, el historial
y el estado exportado. No se deduce del número de orden vacío ni modifica los
cómputos. Los códigos y órdenes no confirmados permanecen vacíos. Los tipos
históricos sin código pueden conservarse durante la revisión de un PDF sin
habilitarlos como opciones nuevas de carga. La recepción del papel se revisa
expresamente antes de retirar la marca.

- Resolver las diferencias de identidad y fichas faltantes del Excel.
- Precisar los códigos que no pueden deducirse del tipo original.
- Resolver las diferencias laborales sin reemplazar automáticamente datos vigentes.

La consulta de una ficha no debe conceder automáticamente permisos de carga,
modificación o anulación de licencias. Los registros históricos sin una persona
confirmada no deben atribuirse a una ficha únicamente por semejanza de nombres.

## Verificación

`supabase/tests/ficha_licencias.sql` comprueba que el lote se conserva y queda
fuera de la lectura normal, que no bloquea cargas nuevas, que Ficha solo consulta,
que cada permiso se revoca y que las cargas comienzan en 2026. Se verificaron
también los accesos reales en Supabase, con rollback de los datos de prueba.
`supabase/tests/ficha_formulario_codigos.sql` verifica los datos laborales,
los 39 códigos, la compatibilidad de edición y la secuencia anual de Art. 8.
Las pruebas de impresión cubren continuidad, cambios de año, anotaciones y
observaciones largas, además de excluir personas ajenas y anulaciones.
Las pruebas de pantalla comprueban la vista incorporada, el cambio de persona,
el mismo período al ampliar, las hojas del PDF y la ausencia de impresión automática.
`supabase/tests/ficha_imprevistos.sql` comprueba la integración, la exclusión del
Excel, los números de orden, cambios de fecha/año, anulaciones, paginación y
permisos. Las pruebas Flutter verifican el número de orden y código en la planilla,
la gestión desde Imprevistos y la actualización de las consultas al guardar allí.
`supabase/tests/licencias_catalogo_excel.sql` verifica los 30 tipos del Excel,
Profiláctica 03, agrupación de variantes, RLS de la vista, rechazo de códigos
ajenos incluso al editar importaciones y conservación de Estudio e Imprevistos.
`supabase/tests/licencias_duelo_parentescos.sql` comprueba las equivalencias
19/21/22 confirmadas en las fichas, su consulta bajo Duelo, la conservación de
las treinta categorías y los permisos de lectura. La migración se detiene si
encuentra registros con las antiguas equivalencias 19/22 para evitar cambiar
el significado de un histórico sin revisión.
`supabase/tests/licencias_francos_cantidad_papel.sql` verifica los dos francos
en una fecha, el cómputo anual, su duración calendario separada, el rechazo de
cantidades mayores para otros tipos y la invalidación al cambiar de tipo.
`supabase/tests/licencias_documentacion_pendiente.sql` comprueba que la marca
se consulta sin inventar código u orden, no afecta a todas las filas sin orden,
no reactiva importaciones apartadas y conserva los permisos de acceso.
