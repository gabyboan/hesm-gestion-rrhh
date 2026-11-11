# Licencias

Licencias se conecta con el módulo Ficha, donde se ve lo cargado para cada persona.
La carga de licencias se realiza desde Licencias; los imprevistos se gestionan
en Imprevistos y se consultan desde ambos módulos y desde Ficha. Se deben consultar y
confirmar los datos a extraer antes de hacer nuevas importaciones. El alcance
actual y las decisiones pendientes están en [Ficha y Licencias](FICHA_Y_LICENCIAS.md).

El módulo incorpora el formulario con los **30 tipos de licencia del Excel**: empleado,
tipo, fecha desde, cantidad de días y fecha hasta calculada incluyendo ambos
extremos. Permite consultar por nombre o DNI, año, mes y tipo; exportar a XLSX;
modificar y anular con autorización. Las anulaciones conservan el registro y su
auditoría. Las cargas nuevas rechazan duplicados del mismo tipo y período y
períodos que coincidan con inactividad de la persona.

Los 30 tipos originales del Excel se conservan para identificar el historial;
sus identificadores internos no se confunden con los códigos. Los registros
confirmados sin código deducible conservan el tipo original y una observación
de revisión pendiente.
Las cargas nuevas eligen únicamente tipos presentes en el Excel, con su nombre
original y el código confirmado cuando se conoce. Profiláctica usa **03**;
el código 02 y los tipos ajenos al Excel no se ofrecen. Los códigos antiguos
se conservan para consultar el historial. Familiar ofrece las variantes 10/11;
los filtros reúnen ambas y el historial pendiente bajo el mismo tipo del Excel.
Se pueden guardar DNI del familiar, número de orden y una cantidad literal para
la ficha (por ejemplo, `20/23`), sin alterar los días calendario del período.

Art. 8 se consulta directamente desde Imprevistos, conservando el número de
orden original: primera carga 43 y las dos siguientes 98, por persona y año.
El orden es el de creación en ese módulo, no el de las fechas ni los números
de orden. Los cambios y anulaciones se reflejan al consultar. Los códigos 43/98
se consultan en Licencias, pero sus cargas nuevas se realizan en Imprevistos.
La consulta integrada excluye los imprevistos del Excel para evitar dobles cargas.

Licencia por Estudio utiliza el código **29**, confirmado por el usuario el
4/11/2026: máximo **20 días hábiles por persona y año** y **5 por solicitud**.
El formulario recibe días hábiles y calcula la fecha final con el calendario
existente del sistema, excluyendo sábados, domingos y feriados cargados.
La base valida ambos topes, serializando cargas de la misma persona; editar
excluye la licencia de su propio consumo y anular libera sus días. Al cruzar el
año, el consumo se reparte entre los años correspondientes.

Los días calendario del período se conservan en el registro original. La consulta
devuelve los días hábiles, los días calendario y el reparto anual para Estudio;
Ficha, planilla impresa y exportación utilizan los hábiles. La exportación aclara
la unidad y mantiene también el total calendario.

## Permisos por usuario

Se asignan en `usuario_roles`, con los identificadores del catálogo `roles`,
igual que en los demás módulos. No se asignan automáticamente a otras cuentas.

| Operación | Roles necesarios |
| --- | --- |
| Entrar, consultar y exportar | `LICENCIAS_LECTURA` |
| Cargar | `LICENCIAS_LECTURA` + `LICENCIAS_CARGA` |
| Modificar y anular | `LICENCIAS_LECTURA` + `LICENCIAS_ADM` |
| Consultar desde Ficha | `FICHA_LECTURA` |

La base valida los permisos en cada operación. Ocultar botones es una ayuda de
interfaz; las RPC y RLS también rechazan accesos sin autorización. La escritura
directa en las tablas está cerrada para los clientes. La revocación surte efecto
en la siguiente consulta; el botón Actualizar renueva también los permisos en la
pantalla. El módulo conserva los controles existentes de sesiones y MFA.

Para ver quién puede operar, ejecutar como administrador en SQL Editor:

```sql
select u.id as usuario_id, u.auth_user_id, u.apellido, u.nombre,
  bool_or(r.codigo = 'LICENCIAS_LECTURA') as puede_consultar,
  bool_or(r.codigo = 'LICENCIAS_LECTURA')
    and bool_or(r.codigo = 'LICENCIAS_CARGA') as puede_cargar,
  bool_or(r.codigo = 'LICENCIAS_LECTURA')
    and bool_or(r.codigo = 'LICENCIAS_ADM') as puede_modificar_anular,
  bool_or(r.codigo = 'FICHA_LECTURA') as puede_consultar_ficha
from public.usuarios u
left join public.usuario_roles ur
  on ur.usuario_id = u.id or ur.usuario_id = u.auth_user_id
left join public.roles r on r.id = ur.rol_id
group by u.id, u.auth_user_id, u.apellido, u.nombre
order by u.apellido, u.nombre;
```

## Importación del 3 de noviembre de 2026

Se importaron 4.956 filas válidas del informe de 2026, equivalentes a 22.554 días
del Excel. Después, por indicación del usuario, quedaron apartadas de las vistas
normales y conservadas para revisar qué extraer. Posteriormente se confirmó
la selección indicada en la sección siguiente. El nombre, DNI,
tipo, fechas y cantidad se conservaron en la evidencia del
Excel, incluidos sus registros repetidos. Cada fila mantiene los datos originales,
el número de fila y la huella del archivo. Reimportar ese mismo archivo no agrega
duplicados ni reemplaza registros.

Otras 6 filas se conservaron en `licencias_importacion_pendientes`, visibles para
administración en la revisión separada del Excel: cuatro tienen DNI vacío o cero; dos tienen
cantidades o fechas incompletas/inconsistentes. No se inventaron valores.

El historial usa una copia de los datos del informe. Solo se vinculó una persona
del padrón actual cuando coincidían el DNI y un nombre compatible; las diferencias de nombre
y las personas sin ficha no cambian los datos históricos ni crean legajos.
La importación no genera movimientos en Francos, Imprevistos ni Médicos.

El Excel original no se modificó ni se ejecutaron sus macros. La copia operativa,
los datos personales y los informes detallados quedan en `.private/licencias/`,
excluida de Git. El lector reutilizable está en `tool/licencias_excel.py`.

## Selección autorizada del 4 de noviembre de 2026

Sobre la versión actualizada de 5.009 registros válidos se incorporaron 757
licencias para 225 personas, respetando la indicación de no corregir DNI.
4.252 registros siguen apartados y las 6 filas inválidas siguen pendientes.
Los tipos ambiguos conservan su descripción original y código pendiente;
las equivalencias claras utilizan el catálogo operativo. Se completaron datos
laborales faltantes en 136 personas, con historial de procedencia y sin sustituir
datos vigentes distintos. Los informes nominales permanecen en `.private/licencias/`.

La selección conservadora está en `tool/licencias_seleccion.py`. Sus pruebas
comprueban especialmente que no se busque otro DNI por nombre, que las
repeticiones no oculten una fila correcta y que no se inventen códigos ambiguos.
El lote se ensayó con rollback y se verificó con RLS para las dos cuentas autorizadas.

La conexión posterior con Imprevistos no importó ni corrigió identidades del
Excel. El 4/11/2026 la consulta integrada contiene 749 licencias del lote y 382
imprevistos vigentes del módulo de origen, con 381 números de orden presentes.
Los ocho imprevistos del lote se conservan como evidencia fuera de esa consulta.

Tras confirmar la equivalencia de Estudio se asignó el código 29 a las 15 licencias
de ese tipo que ya estaban incorporadas, sin modificar fechas, DNI ni evidencia.
Las otras 59 filas de Estudio siguen apartadas por diferencias de identidad.
El 5/11/2026 se asignó el código **03** a las 10 profilácticas ya incorporadas;
las otras 282 profilácticas siguen apartadas por revisión de identidad.
No se importaron filas adicionales ni se corrigieron DNI.
Quedan **219** licencias ya incorporadas con código pendiente. El usuario confirmó
que «Cuidado de Familiar Enfermo» mezcla 10 y 11: las 151 licencias de ese tipo
siguen pendientes de distinguir, sin decidir el código solo por duración.

## Validación

La migración `20261103131128_modulo_licencias.sql` se probó contra fixtures y en
una restauración aislada del proyecto antes de aplicarla. La importación verifica
cada fila y los totales, y vuelve a ejecutarse para comprobar idempotencia.
`supabase/tests/licencias.sql` cubre lectura, carga, administración, denegaciones,
revocación, días inclusivos, duplicados e inactividad. Las pruebas Flutter cubren
pantalla, formulario, fechas y exportación de más de 1.000 filas.
`supabase/tests/licencias_estudio.sql` comprueba hábiles, feriados, cupos, edición,
anulación, importaciones apartadas y cambios de año; `tool/test_database.ps1`
comprueba además que dos solicitudes simultáneas no consuman el mismo último día.
