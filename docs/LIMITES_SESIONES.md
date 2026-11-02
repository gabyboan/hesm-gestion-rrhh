# Duración y revalidación de las sesiones

Con MFA activado, cada código correcto habilita otra hora de acceso en la
misma sesión, sin pedir otra vez la contraseña. Al vencer, la nueva versión
Windows bloquea los módulos y diálogos abiertos: ingresar el código o cerrar
sesión. Escape y un clic fuera no descartan la ventana. Un código incorrecto
mantiene el bloqueo y permite reintentar. Los formularios conservan su estado.
El cliente confirma el acceso con el servidor antes de desbloquear; un error
de red o autorización mantiene la ventana. No guarda códigos en archivos.

Hay que guardar el trabajo, cerrar el ejecutable anterior y abrir la nueva
versión con su carpeta completa para disponer de esta ventana.

MFA sigue opcional. Sin un factor verificado, se admite como máximo una hora
desde la creación de la sesión; después, la app cierra sesión y solicita un
nuevo ingreso con contraseña. No inscribe factores automáticamente.

## Control del servidor

El hook de PostgREST conserva identidad, pertenencia y existencia de la sesión,
bloqueo de cuenta y `not_after`. Con MFA exige `aal2` y una verificación TOTP
de menos de una hora tanto en los claims firmados del JWT como en
`auth.mfa_amr_claims`, mantenida por Auth. Toma la fecha más antigua de ambas.
Renovar un token no equivale a verificar un código y no amplía ese plazo.
Un JWT con MFA vencido sigue rechazándose aunque otro código haya actualizado
la sesión en Auth. No se usan metadatos editables para autorizar.

Sin MFA se conserva el origen de transición anterior: la fecha más reciente
entre `auth.sessions.created_at` y el 27/10/2026 a las 19:13:50 de Buenos Aires.
El margen para sesiones anteriores terminó a las 20:13:50 de ese día.
La renovación no reinicia el plazo. La hora del cliente controla la interfaz;
el servidor decide si permite cada nueva solicitud a los datos.

## Inactividad y alcance

Se conserva el cierre por inactividad de la app: cinco minutos por defecto,
configurable entre uno y diez. El plan Free no dispone de la capacidad
`auth.user_sessions`; no se cambiaron el plan ni los límites nativos de Auth.
Auth puede renovar tokens que el control de datos rechaza.

El control del servidor cubre PostgREST: tablas, vistas y RPC. Realtime,
Storage, Edge Functions y SQL directo requieren controles propios si se usan.
No borra exportaciones ni cancela solicitudes iniciadas antes del vencimiento.
Las tareas asíncronas ya iniciadas pueden finalizar durante el bloqueo;
las nuevas solicitudes siguen sujetas al servidor. Los clientes anteriores
pueden conservar información ya cargada hasta volver a consultar.

## Pruebas y reversión

Se ensayó en PostgreSQL 17.6 restaurado sin red ni puertos, con Auth v2.197.0,
PostgREST v16.5 y credenciales ficticias: MFA reciente/vencido, renovación,
código incorrecto, misma sesión, JWT anterior, evidencia ausente, revocación,
permisos y reversión exacta. Las pruebas de Flutter verifican bloqueo de
diálogos, conservación del borrador, Escape, errores y cierre sin MFA.

La migración `20261027225110` tiene un inverso privado probado que recupera
el máximo anterior de una hora desde la creación de toda sesión. Revertirla
antes de los límites anteriores. El archivo en el repositorio no demuestra
su despliegue: consultar la evidencia operativa.

Referencia: [sesiones de Supabase](https://supabase.com/docs/guides/auth/sessions).
