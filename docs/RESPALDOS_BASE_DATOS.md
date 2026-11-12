# Copia local y prueba de recuperación

## Verificación del 12 de noviembre de 2026

Antes de la actualización de la base se creó y restauró un respaldo nuevo.
Coincidieron 88 tablas y 18.775 filas, además de estructura y permisos. Sobre
esa copia se ensayaron las dos migraciones de `1.0.7.8` antes de aplicarlas al
entorno compartido. Véase [Prueba local](PRUEBA_LOCAL_1_0_7.md).

Durante la exportación conviene evitar otras operaciones de la CLI que regeneren
las credenciales del rol temporal de conexión: pueden invalidar la conexión
del respaldo en curso. El informe de la tarea determina si la copia terminó
verificada; un intento fallido no reemplaza la última copia válida.

## Copia externa y custodia portable preparadas

La actualización del 12/11/2026 agrega `tool/backup_recovery.py` y la lectura
opcional de `.private/backup-external.json` por la tarea semanal. El destino
queda configurable. Se copia únicamente un respaldo ya restaurado y verificado,
se comprueba su SHA-256 y se entrega cada clave AES cifrada con una clave pública
RSA de recuperación. La clave privada permanece cifrada bajo una frase que
debe custodiarse fuera de la PC publicadora.

La preparación y recuperación están en
[Actualización 1.0.7.8](ACTUALIZACION_1_0_7.md#respaldo-externo-configurable).
Estas herramientas amplían el esquema DPAPI descrito a continuación. La copia
externa real requiere elegir su destino y preparar la custodia; su existencia
no se presume a partir de las pruebas automatizadas.

`tool/backup_database.py` genera una copia lógica de HESM-SUPLENCIAS y la
restaura en un PostgreSQL temporal de la misma versión. La producción se
consulta mediante una transacción de solo lectura. El ensayo no acepta
un destino remoto: usa un contenedor sin red ni puertos publicados.

## Protección y alcance

- El archivo `.hesmbackup` se cifra con AES-256-GCM; el contenido y su cabecera
  se autentican. Incluye el archivo completo de `pg_dump`, los roles sin sus
  contraseñas de conexión, el inventario y la consulta de verificación. Incluye
  `schema-grants.sql` para conservar también los permisos de esquemas de
  extensiones que `pg_dump` omite.
- La clave aleatoria se protege con DPAPI de Windows para el usuario actual
  y se guarda separada, en `%USERPROFILE%\.hesm-backup-keys`. Las carpetas de
  trabajo y de claves tienen acceso limitado al usuario y SYSTEM.
- Los datos de la aplicación, Auth —incluidos sus hashes de contraseña— y
  las migraciones están dentro del archivo cifrado. No se generan archivos
  de datos o SQL sin cifrar en las carpetas del proyecto. El ensayo utiliza
  almacenamiento `tmpfs`; el contenedor se elimina al terminar.
- Se comparan todas las tablas con la misma instantánea del origen mediante
  cantidades y huellas por contenido. Se contrastan además RLS, políticas,
  estructura, funciones propias y sus permisos, vistas, índices, restricciones,
  esquemas, permisos futuros, roles, membresías, triggers, definiciones de
  secuencias y versiones de extensiones. Las secuencias las restaura `pg_restore`;
  sus valores no participan de la comparación MVCC.
- Es una copia de la base, no una réplica completa del proyecto Supabase.
  No exporta archivos de Storage, secretos de Edge Functions, claves JWT,
  configuración de Auth/API ni la clave maestra de Vault. Si hay secretos en
  Vault, sus filas cifradas requieren también su clave de origen. Los archivos
  de Storage necesitan una copia adicional independiente.

**Una copia local no cubre la pérdida del equipo ni del perfil de Windows.**
Se necesitan el archivo y su clave DPAPI, y la cuenta Windows capaz de abrirla.
Copiar únicamente el `.hesmbackup` a otro equipo no basta. Antes de preparar
recuperación en otro equipo, establecer una clave de recuperación portable
con custodia independiente. La tarea semanal descrita abajo guarda las copias
en esta PC; no se ha configurado una copia externa ni recuperación portable.

## Backup automático de los viernes

`tool/setup_database_backup_task.ps1` registra la tarea de Windows
`HESM-Supabase-Backup-Semanal`, los viernes a las **09:00, hora argentina**,
con la cuenta que ejecuta la instalación. Usa el entorno Python privado ya
preparado y la CLI Supabase fijada en `2.122.0` mediante `npx`.

Configuración instalada y comprobada en esta PC el **2 de noviembre de 2026**.
La copia inicial automatizada se restauró y verificó: 80 tablas, 11.583 filas,
datos y permisos coincidentes, archivo cifrado de 485.315 bytes. En esa revisión
había 0 objetos en Storage y 0 secretos en Vault. La primera ejecución semanal
quedó programada para el **viernes 6 de noviembre de 2026, 09:00**; esta revisión
no acredita su resultado posterior. El resultado vigente siempre debe
consultarse en los informes; estas cifras corresponden a la comprobación inicial.

```powershell
# Registrar o actualizar la tarea; agregar -RunNow para comprobarla ahora.
./tool/setup_database_backup_task.ps1

# Cambiar el horario, conservando los viernes.
./tool/setup_database_backup_task.ps1 -At '09:00'
```

Requiere PC encendida, sesión de ese usuario iniciada e Internet. La pantalla
puede estar bloqueada. Si Docker Desktop está detenido, intenta iniciarlo;
utiliza contenedores Linux y la imagen PostgreSQL indicada más abajo. El login
de Supabase CLI debe seguir vigente y el proyecto vinculado debe coincidir con
HESM-SUPLENCIAS. No cambiar de cuenta, desvincular ni mover esta carpeta sin
revisar la tarea.

- Windows intenta ejecutar una tarea omitida cuando vuelve a estar disponible.
  Ante un fallo, reintenta hasta tres veces, cada 30 minutos. Una ejecución
  tiene un límite de una hora.
- No admite ejecuciones semanales simultáneas. La tarea usa permisos normales
  y no guarda contraseñas de Windows ni copia tokens al repositorio.
- Cada ejecución crea una carpeta nueva en
  `.private/database-backups/weekly/`. **No elimina automáticamente copias ni
  claves anteriores.** Revisar el espacio libre periódicamente.
- Las credenciales temporales se pasan por memoria; no se genera el archivo
  `conexion-temporal.private.txt` en la modalidad automática. Los diagnósticos
  detallados se guardan cifrados.
- Sólo marca un éxito después de crear la copia, restaurarla sin red, comparar
  datos y permisos y verificar el archivo y su informe. Un fallo conserva el
  indicador de la última copia correcta.

Para comprobar el estado o ejecutar una copia manual mediante la misma tarea:

```powershell
Get-ScheduledTaskInfo -TaskName HESM-Supabase-Backup-Semanal
Get-Content .private/database-backups/weekly/last-run.json
Get-Content .private/database-backups/weekly/last-success.json
Start-ScheduledTask -TaskName HESM-Supabase-Backup-Semanal
```

`LastTaskResult = 0` indica que el proceso terminó correctamente; corroborar
`estado: verificado` y la fecha en `last-success.json`. Durante la ejecución
Windows puede mostrar otro código. `last-run.json` informa si el intento más
reciente está en curso o falló. No se han configurado avisos por correo.

Para desactivar la programación sin borrar copias:

```powershell
Disable-ScheduledTask -TaskName HESM-Supabase-Backup-Semanal
```

## Cuotas y costos

La organización Hesm_Personal se verificó en plan **Free** el 2 de noviembre
de 2026 mediante la Management API, usando el login local de la CLI.

| Recurso | Free | Efecto de esta configuración |
| --- | --- | --- |
| Base de datos | 500 MB por proyecto | La copia se guarda fuera de Supabase; no duplica tablas en la base. |
| Egress sin caché | 5 GB por organización y ciclo de facturación | Descargar el dump y el inventario consume transferencia; se comparte con la app y otros proyectos de la organización. |
| Storage | 1 GB | La tarea guarda archivos en disco local, sin utilizar buckets de Supabase. |
| Backup administrado por Supabase | No incluido | Esta tarea local tiene su propia programación. |
| Disco de la PC | Según espacio libre | Se acumulan copias cifradas y diagnósticos; no hay purga automática. |

No hay una cuota de cantidad de backups semanales para esta tarea local.
Presupuestar **4 o 5 descargas completas por mes**, más los reintentos que
alcancen a descargar datos. El tamaño del archivo cifrado sirve como orientación,
pero no equivale exactamente al egress: también se transfieren inventarios,
roles y metadatos. El cálculo de huellas usa CPU del servidor; la restauración
de prueba ocurre sólo en esta PC y no vuelve a descargar la base.

Para verificar consumo real, abrir **Organization → Usage** en Supabase y
comprobar la transferencia del pooler junto con el resto de la organización.
La consulta del plan no mide cuánto cupo queda en el ciclo actual.

Una frecuencia semanal permite recuperar hasta la última copia correcta:
se pueden perder hasta siete días de cambios entre ejecuciones, o más si fallan.

Como alternativa, Pro parte de USD 25/mes e incluye backups administrados diarios
con 7 días de retención. PITR es un adicional desde aproximadamente USD 100/mes,
además del plan y sus requisitos de cómputo; no hace falta para esta tarea semanal.
No se ha cambiado el plan ni contratado adicionales. Consultar las referencias
de precios por posibles cambios posteriores.

## Preparar el entorno

Requiere Windows, Python, Docker Desktop funcionando y la imagen
`supabase/postgres:17.6.1.054`, correspondiente al servidor auditado.
Antes de usar otra versión, comprobar compatibilidad de Postgres y extensiones.

```powershell
python -m venv .private/backup-tools
.private/backup-tools/Scripts/python.exe -m pip install -r tool/backup_requirements.txt
```

La CLI debe estar autenticada en la cuenta correcta y el proyecto vinculado
debe ser HESM-SUPLENCIAS. Consultar `db dump --help` antes de utilizar otra versión
de CLI. El script valida el identificador del proyecto antes de conectar.

## Crear una copia

Elegir una carpeta privada nueva para cada ejecución. Preparar primero su ACL
con el mismo patrón de `restricted_dir` del script, o usar una carpeta hija de
`.private/database-backups`, ya restringida por el procedimiento inicial.

```powershell
# Ejemplo: usar una carpeta NUEVA dentro del árbol privado ya restringido.
New-Item -ItemType Directory .private/database-backups/NUEVA_FECHA
npx --yes supabase@2.122.0 db dump --linked --project-ref zdieotecewtkcxlxonpb --dry-run > .private/database-backups/NUEVA_FECHA/conexion-temporal.private.txt
.private/backup-tools/Scripts/python.exe tool/backup_database.py create --output .private/database-backups/NUEVA_FECHA/copia --connection-script .private/database-backups/NUEVA_FECHA/conexion-temporal.private.txt
Remove-Item -LiteralPath .private/database-backups/NUEVA_FECHA/conexion-temporal.private.txt
```

La salida de `--dry-run` contiene credenciales temporales: no mostrarla, subirla
ni guardarla fuera de una carpeta restringida. No ejecutar comandos CLI remotos
en paralelo: pueden renovar el mismo usuario temporal. La conexión verifica
el certificado y hostname de Supabase con `sslmode=verify-full` y su CA oficial.

La copia sólo se considera comprobada si el comando termina con código 0 y
produce `verificacion.json` con `verificada: true`. Un archivo generado antes
de un fallo queda conservado, pero no debe considerarse verificado.

## Volver a comprobar una copia existente

No necesita login, conexión a Supabase ni el archivo temporal de credenciales.
Sí necesita Docker, la imagen y la clave DPAPI de esa copia.

```powershell
.private/backup-tools/Scripts/python.exe tool/backup_database.py verify --output .private/database-backups/NUEVO_ENSAYO --archive .private/database-backups/FECHA/copia/HESM-SUPLENCIAS.hesmbackup
```

Se vuelve a leer el archivo guardado, se recupera su clave desde DPAPI, se valida
el cifrado y los SHA-256 internos y se repite la restauración desde cero.
Los diagnósticos detallados también quedan cifrados. La salida pública y el
informe de verificación no incluyen nombres, correos ni filas del personal.

Restaurar sobre un proyecto real requiere un procedimiento específico con
destino confirmado, tratamiento de servicios externos y verificación de acceso
de la aplicación. Este programa solamente crea y comprueba copias aisladas.

## Referencias

- [Copias y restauración de Supabase](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore).
- [Alcance de las copias de Supabase](https://supabase.com/docs/guides/platform/backups).
- [Planes y cuotas de Supabase](https://supabase.com/pricing).
- [Consumo de egress](https://supabase.com/docs/guides/platform/manage-your-usage/egress).
- [Verificación TLS](https://supabase.com/docs/guides/platform/ssl-enforcement).
- [pg_dump en PostgreSQL 17](https://www.postgresql.org/docs/17/app-pgdump.html).
- [pg_restore en PostgreSQL 17](https://www.postgresql.org/docs/17/app-pgrestore.html).
