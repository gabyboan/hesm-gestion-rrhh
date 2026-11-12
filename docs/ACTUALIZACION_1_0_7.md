# Actualización 1.0.7.8

Preparación del 12 de noviembre de 2026. Código `1.0.7+8`.
La distribución operativa anterior documentada es `1.0.6.7`.

Durante la [prueba local del 12/11/2026](PRUEBA_LOCAL_1_0_7.md) se aplicaron las
dos migraciones a la base compartida, después de restaurar y verificar un
respaldo reciente y ensayar ambas sobre esa copia. La base ya anuncia las
capacidades de esquema **2**. El instalador firmado se publicó después en el
canal privado del hospital; se verificaron firma y hash desde la ruta de red.
El detalle y los pasos de instalación están en
[Distribución 1.0.7.8](DISTRIBUCION_1_0_7.md).

## Horas Gremiales y guardado

- Nueva modalidad Gremial con duración de 30 minutos a 10 horas, en pasos de
  30 minutos, disponible para las distintas carreras y categorías del padrón
  que utiliza Oficiales. Se mantienen los permisos de carga y la asociación
  real de persona/carrera. No se asignan carreras ficticias a quien no la tenga.
- Gremiales tiene detalle y filtro propios en consultas, informe y Excel.
  No consume el cupo de Particulares ni cambia el significado de una licencia
  gremial expresada en días.
- Guardar permanece bloqueado mientras termina la operación. Dos llamadas
  simultáneas comparten el mismo resultado, incluidos los errores.
- Ante una respuesta perdida, el reintento del mismo formulario conserva un
  UUID. La nueva RPC confirma la hora y su recibo en la misma transacción y
  devuelve el resultado previo al recibir ese mismo UUID. Dos cargas legítimas
  distintas, aunque tengan los mismos datos, utilizan UUID diferentes.
  La espera de confirmación tiene un límite de 30 segundos; después se puede
  reintentar con la misma operación, sin repetir la escritura automáticamente.
- El cálculo mensual se serializa por persona, carrera y mes para evitar que
  cargas simultáneas calculen el cupo sobre el mismo saldo anterior.
- Los registros se consultan por páginas de 500 con orden estable. Los meses
  disponibles se obtienen como períodos distintos desde el servidor.

## Caché de sesión

La caché vive exclusivamente en memoria; no guarda el padrón ni los historiales
en disco. Está acotada a 48 consultas y agrupa solicitudes simultáneas iguales.

| Datos | Vigencia |
| --- | --- |
| Padrones de Horas y Oficiales/Gremiales | 3 minutos |
| Catálogo de tipos de Licencias | 5 minutos |
| Consultas recientes de horas, licencias y personas de Ficha/Licencias | 25 segundos |

Al volver a Horas se reevalúan los proveedores: un resultado vigente se reutiliza
y uno vencido se consulta nuevamente. Las cargas y anulaciones invalidan su
grupo; los imprevistos también invalidan el historial compartido de Licencias y
Ficha. Actualizar y exportar fuerzan las lecturas pertinentes.

El servidor vuelve a comprobar las bajas antes de aceptar una nueva carga de
Oficiales o Gremiales, aunque el padrón en memoria todavía no haya vencido.

Cerrar sesión, ingresar con otra cuenta o cambiar de sesión elimina la caché.
La renovación del JWT dentro de la misma sesión la conserva. Los errores no se
cachean. Los permisos, MFA y la reserva de sesión no utilizan esta caché.
No se ofrece trabajo sin conexión ni se reintentan escrituras automáticamente.

## Inicio de sesión

- Cinco errores de credenciales en quince minutos activan una espera local de
  30 segundos. Los siguientes errores aumentan la espera a un minuto y luego a
  cinco minutos. Un ingreso correcto reinicia el contador de esa cuenta.
- El botón y Enter respetan la espera y se muestra la cuenta regresiva.
- Un HTTP 429 aplica una espera de un minuto para ese formulario, incluso si
  se cambia el email. Los fallos de red no se contabilizan como contraseña
  incorrecta y los mensajes no exponen respuestas internas.
- Esta espera se mantiene mientras corre la aplicación y complementa el control
  del servidor. No es un bloqueo de cuenta compartido entre todas las PCs.

Se consultó la configuración remota mediante una lectura de la CLI, sin cambios:
`sign_in_sign_ups=30`, `token_refresh=150`, `token_verifications=30`.
La documentación vigente incluye contraseña y renovación en el endpoint de
tokens, con 150 solicitudes por cinco minutos y ráfagas de hasta 30. Se conserva
esa configuración considerando la IP compartida del hospital. No se activó un
hook de bloqueo por cuenta sujeto a otro plan de Supabase.

## Compatibilidad, diagnóstico y distribución

La aplicación requiere el esquema de capacidades **2** antes de abrir los módulos.
Si falta, muestra un aviso de actualización de la base. El manifiesto firmado del
instalador incluye `required_schema=2`; la comprobación operativa se realiza al
ingresar. Los manifiestos anteriores continúan siendo legibles.

Si falla esa comprobación, se muestra un aviso con **Reintentar** y **Volver al
inicio de sesión**. La comprobación puede repetirse después de actualizar la
base, sin dejar al usuario detenido en una pantalla de texto técnico. Los errores
internos de acceso no se muestran literalmente.

Los errores de Flutter, los errores asincrónicos y las fallas de conexión del
login generan eventos en `%LOCALAPPDATA%\HESM-Gestion-RRHH\logs`. Se guardan fecha
UTC, versión, componente, tipo y código técnico seguro. Se conservan dos archivos
rotativos de unos 256 KiB. No se serializan mensajes originales, stacks,
contraseñas, tokens ni documentos de personas. Una falla de escritura del log
no interrumpe la aplicación.

### Orden de puesta en servicio

1. Verificar el respaldo y revisar el esquema de destino. Las migraciones públicas
   dependen de la instalación existente; no instalan el sistema desde cero.
2. Aplicar en orden `20261112122744_horas_gremiales_y_guardado_seguro.sql` y
   `20261112123611_capacidades_gestion.sql`.
3. Verificar las capacidades y preparar el instalador firmado `1.0.7.8`.
4. Probar ingreso, guardado y reenvío, cuatro modalidades, informes y Excel en
   un puesto. Actualizar los demás puestos antes de empezar a cargar Gremiales:
   los clientes anteriores no conocen esa modalidad y pueden omitirla al informar.
5. Conservar un instalador anterior compatible. Los datos nuevos no se revierten
   desinstalando la aplicación ni borrando indiscriminadamente migraciones.

Las dos migraciones ya se aplicaron en la base compartida para la prueba local.
La guía conserva el orden para otros entornos. El instalador operativo ya está
publicado. Las consultas de comprobación usaron metadatos; el respaldo del ensayo
se conservó cifrado y su restauración se realizó en un contenedor aislado.

## Respaldo externo configurable

La tarea existente admite `.private/backup-external.json`, con destino y clave
pública de recuperación. Una copia local ya restaurada y verificada puede
copiarse a ese destino. Se verifica el SHA-256 y se crea `complete.json` al terminar.
Si falla el destino externo, se conserva la última copia local válida y se
informa `verificado_local_fallo_externo`.

Cada clave AES se cifra para custodia con RSA-OAEP/SHA-256 y una clave pública
de 3072 bits. La clave privada se protege con una frase de recuperación y debe
custodiarse fuera de la PC publicadora. La tarea automática solo necesita la
clave pública. La contraseña no se pasa por argumentos ni se guarda en la
configuración. El destino permanece sin configurar hasta elegir su ubicación.

Con el entorno Python de `tool/backup_requirements.txt`:

```powershell
python tool/backup_recovery.py generate `
  --public-key .private/backup-recovery/public.pem `
  --private-key D:/Custodia-HESM/recovery-private.pem

python tool/backup_recovery.py configure `
  --destination \\SERVIDOR-RESPALDOS\HESM `
  --public-key .private/backup-recovery/public.pem
```

En otro perfil de Windows, restaurar primero la clave local protegida y luego
ejecutar la verificación de restauración aislada documentada en
[Respaldos](RESPALDOS_BASE_DATOS.md):

```powershell
python tool/backup_recovery.py recover-key `
  --packet D:/Respaldo-HESM/recovery.json `
  --private-key D:/Custodia-HESM/recovery-private.pem
```

La copia externa y la recuperación criptográfica tienen pruebas automatizadas.
Una recuperación física en otra PC requiere conservar archivo, paquete de
recuperación, clave privada y frase, y realizar el ensayo completo.
