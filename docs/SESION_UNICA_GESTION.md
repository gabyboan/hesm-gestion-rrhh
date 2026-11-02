# Una Gestión por cuenta

La aplicación actualizada reserva el acceso después de autenticar la cuenta y
resolver MFA, antes de cargar perfiles o módulos. Si la cuenta ya está usando
otra Gestión, muestra el motivo y permite reintentar o volver al inicio de
sesión. Conserva la primera sesión; rechazar la segunda no la desconecta.

El servidor obtiene usuario y sesión del JWT y verifica que sigan vigentes en
Auth. Una escritura atómica con clave primaria por usuario decide qué ingreso
gana, incluso si dos equipos lo intentan simultáneamente. Los intentos de
Gestión se registran por `session_id`; cambiar o quitar cabeceras en consultas
posteriores no evita la comprobación. Las sesiones propias de otras
aplicaciones no reservan este acceso.

La reserva se renueva cada 30 segundos y vence a los dos minutos sin renovación.
Cerrar sesión elimina la sesión de Auth y libera la reserva por clave foránea.
El cierre normal de la ventana intenta liberarla antes de salir. Ante un cierre
inesperado o pérdida de red, la recuperación tarda como máximo dos minutos.
La reserva no amplía los límites existentes de inactividad, duración ni MFA.

Si la ventana pierde la reserva o no puede comprobarla, bloquea también los
diálogos que ya estaban abiertos. Reintentar recupera el formulario cuando el
servidor vuelve a conceder el acceso. El hook existente de PostgREST conserva
MFA y revocación y rechaza datos, vistas y RPC para una sesión registrada de
Gestión que ya no tenga la reserva. Las RPC de reserva y confirmación de MFA
pueden ejecutarse para recuperar el acceso, sin devolver datos de negocio.

Las tablas son privadas, tienen RLS y no conceden acceso directo a clientes.
Las funciones elevadas quedan en `private`, validan la identidad y usan una
ruta vacía. Los RPC públicos son invoker. Salir usa explícitamente alcance
`local`, para conservar las sesiones propias de otras aplicaciones.

## Instalación y validación

La versión **1.0.6.7** se distribuye por la carpeta privada del entorno; por
ejemplo, `\\PC-PUBLICADORA\HESM-Actualizaciones`.
Actualizar Gestión en todos los equipos desde la opción «Instalar y reiniciar»
que aparece al volver a abrir la aplicación con esa carpeta configurada.
Las versiones anteriores no realizan la reserva; deben actualizarse para
participar del control. La migración puede instalarse antes de distribuir el
ejecutable sin bloquear las sesiones de clientes anteriores.
La migración `20261102141024_sesion_unica_gestion_por_usuario.sql` quedó aplicada
y verificada en la base real el 2 de noviembre de 2026, junto con la conservación
del domicilio emitido. El instalador y el manifiesto de la `1.0.6.7` se verificaron
desde la ruta de red antes de cerrar la publicación.

`powershell -File tool/test_database.ps1` ejecuta contratos con datos ficticios
y dos conexiones PostgreSQL concurrentes. Comprueba una sola reserva, renovación,
rechazo del segundo ingreso, bloqueo de API, recuperación, cierre de sesión,
identidad ajena, MFA y permisos. Las pruebas Flutter verifican la espera inicial,
los mensajes, el bloqueo de diálogos, las fallas de red y la conservación del
formulario al renovar el JWT o recuperar acceso.

Referencia: [sesiones de Supabase](https://supabase.com/docs/guides/auth/sessions).
