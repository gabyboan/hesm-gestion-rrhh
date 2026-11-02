# Verificación en dos pasos opcional

La nueva versión de Windows permite activar una aplicación autenticadora
desde **Configuración → Verificación en dos pasos**. Cada persona decide si la
activa. Las cuentas que no la activan siguen ingresando con contraseña.

## Activar

1. Cerrar la versión anterior de la aplicación y abrir la versión nueva.
2. Iniciar sesión y abrir Configuración.
3. Elegir Verificación en dos pasos → Configurar autenticadora.
4. Escanear el QR con una aplicación compatible con TOTP. También se puede
   ingresar la clave manualmente en esa aplicación.
5. Ingresar el código de seis dígitos y confirmar **Activar con código**.

El alta solo queda activa después de verificar el código. Al activarla,
Supabase invalida las otras sesiones de esa cuenta que todavía no tenían
el segundo factor verificado. El QR y la clave de alta
se muestran únicamente durante la configuración; la app no los guarda en
preferencias, archivos de exportación ni registros de diagnóstico.

En los próximos ingresos se pedirá el código de la autenticadora antes de
cargar los módulos. Un fallo de verificación o de consulta de factores permite
reintentar o cerrar sesión. No ofrece un botón para saltear un factor activo.

### El código anterior puede aceptarse brevemente

Los códigos TOTP cambian cada 30 segundos. Supabase admite una tolerancia de
un intervalo para compensar pequeñas diferencias entre el reloj del teléfono
y el servidor. Por eso, el código inmediatamente anterior puede aceptarse
aunque la autenticadora ya muestre otro. No significa que siga siendo válido
indefinidamente. Usar siempre el código que muestra actualmente el teléfono.

Se reprodujo este comportamiento con Auth v2.197.0 en una cuenta ficticia
aislada: el intervalo anterior fue aceptado y los códigos de dos y cinco
intervalos atrás fueron rechazados sin habilitar el acceso a los datos.

## Desactivar y recuperar acceso

Desde una sesión ya verificada, volver al mismo apartado, elegir Desactivar
y confirmar. Supabase exige una sesión con segundo factor verificado para
retirar un factor activo. Cancelar un alta incompleta intenta retirar su
factor pendiente; un factor pendiente no activa MFA.

Si se pierde la autenticadora, contactar al administrador. El administrador
debe confirmar la identidad mediante el procedimiento de la organización,
revisar/revocar sesiones, gestionar la credencial y retirar el factor mediante
las herramientas administrativas de Supabase. Luego la persona puede ingresar
y configurar otra autenticadora. La app no guarda claves de administración ni
ofrece un mecanismo para eliminar factores de otras cuentas.

Los tokens de acceso emitidos tienen su propia vigencia. Auth y cada canal de
acceso necesitan comprobar la revocación; borrar la sesión no cambia la firma
ni la fecha de vencimiento de un token que ya fue emitido. El control de
revocación de la Data API se documenta en [SESIONES_Y_REVOCACION.md](SESIONES_Y_REVOCACION.md).
No registrar ni compartir códigos, QR, claves o tokens en incidencias.

## Protección del servidor y alcance

El hook `public.verificar_mfa_opcional` de la Data API invoca un control privado
para el rol `authenticated`. Si la cuenta tiene un factor verificado, exige
`aal2`; con un factor pendiente o sin factores permite continuar con contraseña.
Los permisos de módulo y las políticas de cada tabla siguen aplicándose.
Los servicios con `service_role` conservan su acceso administrativo previsto.

El hook protege los accesos PostgREST usados por la aplicación: tablas, vistas
y RPC. Realtime, Storage, otros servicios y conexiones SQL requieren controles
propios si se incorporan al flujo. La autenticación administrativa del panel de
Supabase es una cuenta y configuración separada de la cuenta de esta aplicación.

La contraseña mínima del proyecto pasó de 6 a **12 caracteres** para altas y
cambios de contraseña. No se cambiaron contraseñas, usuarios ni identificadores
existentes. La compatibilidad de login con el aviso de contraseña débil se
probó con el SDK instalado y un servidor HTTP local ficticio.

Siguen pendientes la protección contra contraseñas filtradas y los límites
nativos de sesiones de Auth. Algunas funciones de Supabase dependen del plan; este
trabajo no contrató servicios pagos ni cambió esos controles sin preparar su
recorrido de acceso y recuperación.

El control de la Data API exige una verificación TOTP de menos de **una hora**
si MFA está activado. La nueva versión de Windows bloquea la aplicación al
vencer: ingresar el código o cerrar sesión. Un código incorrecto mantiene el
bloqueo; un código correcto habilita otra hora de la misma sesión conservando
los formularios abiertos. El servidor exige evidencia reciente en Auth y JWT;
renovar el token no amplía el plazo. Sin MFA se conserva el máximo de una hora
y un nuevo ingreso con contraseña. La inactividad nativa de Auth sigue sin
aplicar porque requiere un plan compatible. Alcance y funcionamiento:
[LIMITES_SESIONES.md](LIMITES_SESIONES.md).

## Verificación y recuperación técnica

Se ejecutaron pruebas de interfaz de alta/cancelación/desafío/desactivación,
pruebas SQL sobre PostgreSQL 17.6 restaurado sin red, regresión de módulos y
comprobaciones de producción. El alta en una autenticadora física debe hacerla
cada usuario: no se inscribieron factores en cuentas reales durante el trabajo.

Las migraciones y los cambios de Auth tienen paquetes inversos privados.
El retiro del hook usa dos fases para permitir la recarga de configuración de
PostgREST antes de eliminar sus funciones. No aplicar todos los inversos sin
revisar las dependencias y el estado posterior.

Los respaldos lógicos de Auth contienen las filas de factores, pero no todas
las claves de cifrado/configuración externas del servicio Auth. La recuperación
en otro proyecto puede requerir retirar y volver a inscribir factores. La copia
verificada del 26/10 se tomó cuando todavía no había factores registrados.

Referencias:
[MFA opt-in](https://supabase.com/docs/guides/auth/auth-mfa),
[TOTP](https://supabase.com/docs/guides/auth/auth-mfa/totp),
[contraseñas](https://supabase.com/docs/guides/auth/password-security),
[hook de Data API](https://supabase.com/docs/guides/api/securing-your-api).
