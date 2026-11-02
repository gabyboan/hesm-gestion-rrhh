# Sesiones y revocación

La aplicación mantiene su cierre por inactividad, con cinco minutos por
defecto y el ajuste existente de uno a diez minutos. Este es un control del
cliente; el servidor debe validar también la sesión de cada solicitud.

## Control de la Data API

La migración `validar_sesiones_revocadas_api` amplía el control privado que ya
invoca el hook de PostgREST. Antes de aplicar el MFA voluntario, comprueba que:

- El JWT contiene identidad y un `session_id` con formato válido.
- La sesión existe en `auth.sessions` y pertenece a esa misma identidad.
- No venció su límite explícito `not_after`, si lo tiene.
- La cuenta no tiene un bloqueo vigente en `auth.users.banned_until`.

Una sesión revocada, inexistente o vencida recibe HTTP 401. Se conserva la
exigencia de AAL2 solo para cuentas con factores verificados. Los permisos de
módulo siguen consultándose en la base y las políticas de acceso siguen
aplicándose. El hook no da acceso adicional a anon ni cambia el acceso
administrativo previsto de service_role.

La consulta usa las claves primarias de sesión y usuario. No concede a los
clientes acceso directo al esquema Auth, ni modifica sus tablas. La firma,
owner, ACL, volatilidad y ruta vacía de la función existente se conservan.

## Qué se probó

Se restauró la copia cifrada en PostgreSQL 17.6 y se ejecutaron Auth v2.197.0
y PostgREST v16.5 dentro del mismo contenedor aislado, sin red ni puertos
publicados. Auth coincidía con la versión remota consultada; PostgREST fue la
versión de ensayo, sin afirmar que coincide con la del servicio administrado.
Las claves de firma y cuentas de prueba se generaron localmente para el ensayo.
No se probaron contraseñas ni tokens reales de empleados.

Se comprobó el problema anterior: tras un logout confirmado por Auth, la Data
API aceptaba todavía el JWT válido. Con la corrección se rechaza. También se
probaron sesiones vigentes, renovación, refresh revocado, cierre local que
conserva otra sesión, cierre global, AAL1/AAL2, códigos TOTP antiguos, usuario
bloqueado, límite vencido, firma incorrecta y `session_id` ausente, inválido,
inexistente o de otro usuario. La reversión devuelve exactamente la definición
anterior y vuelve a reproducir el problema dentro de la copia aislada.

`supabase/tests/sesiones_permisos.sql` comprueba con el mismo JWT que retirar
los roles de Horas impide las dos RPC revisadas sin esperar una renovación.
Requiere una restauración `hesm_restore_test` por socket local y termina en
ROLLBACK. Se ejecutó junto con las pruebas de MFA y escrituras de módulos.

Las pruebas del SDK instalado verificaron que cerrar sesión elimina el estado
local incluso si el servidor devuelve un error, y que una reapertura con la
inactividad vencida cierra la sesión antes de entrar a los módulos.

## Alcance y límites

- La revocación alcanza nuevas solicitudes a PostgREST después de que Auth
  elimina la sesión. Una solicitud ya iniciada conserva su snapshot.
- Un logout sin conexión puede limpiar la sesión del equipo sin lograr la
  revocación remota. No implica que un token copiado previamente quede anulado.
- No borra datos ya mostrados o exportados. Otros clientes pueden mostrar datos
  cargados antes de la revocación hasta actualizar su estado.
- Realtime, Storage, Edge Functions y conexiones SQL necesitan controles propios
  si se incorporan al flujo. Este hook no cubre esos canales.
- Posteriormente se añadió un máximo de 1 hora de acceso sin MFA en la
  Data API. Con MFA, un código correcto permite otra hora en la misma sesión;
  la nueva interfaz bloquea los módulos hasta verificar o cerrar sesión.
  La comprobación de revocación se conserva. La inactividad nativa de
  Auth sigue pendiente de un plan compatible. Ver
  [LIMITES_SESIONES.md](LIMITES_SESIONES.md). No se contrataron opciones pagas.
- La revocación estricta añade una consulta indexada a cada solicitud. Revisar
  latencia y carga ante cambios de escala o uso de la API.

Los paquetes operativos privados contienen evidencias antes/después, las
guardias contra cambios posteriores y el inverso. Revertir este control
restaura el comportamiento anterior y su ventana de reutilización del token.

Referencias: [sesiones de Supabase](https://supabase.com/docs/guides/auth/sessions),
[MFA TOTP](https://supabase.com/docs/guides/auth/auth-mfa/totp).
