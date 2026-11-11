# Primera PC con Windows 10/11

Última entrega operativa documentada: **1.0.6.7**, del 2/11/2026. Los cambios
posteriores de Ficha y Licencias todavía requieren una nueva distribución.
Requiere Windows de 64 bits, versión 10 1809
(compilación 17763) o posterior. Windows 7 queda fuera de esta entrega.

1. Mantener PC-04 encendida y conectada a la red del hospital.
2. Desde la PC receptora abrir `\\PC-04\HESM-Actualizaciones`. Cuando Windows
   pida credenciales, usar `PC-04\HESM-Lector` y la contraseña que eligió el
   responsable en PC-04. Es independiente del usuario de RRHH.
3. Entrar a `versions\1.0.6.7` y copiar
   `HESM-Gestion-RRHH-1.0.6.7-Setup.exe` a una carpeta local de la PC receptora.
4. Guardar el trabajo y cerrar la versión anterior de HESM, si está abierta.
   Ejecutar la copia local del instalador. No requiere Flutter ni Visual Studio.
5. Abrir HESM: la marca sube y se achica, y aparecen las tarjetas de comprobación.
   Se requiere conectividad al servidor de Supabase. Si falla un control, leer
   el mensaje y reintentar una vez restablecida la conexión.
6. Iniciar sesión en RRHH y, desde **Configuración → Actualizaciones del hospital**,
   indicar `\\PC-04\HESM-Actualizaciones`. La contraseña de Windows no se guarda
   en la configuración de HESM. La cuenta de Windows debe poder leer la carpeta.

Si Windows intenta entrar con una cuenta distinta, desde **cmd** se puede indicar
la cuenta de lectura explícitamente. La contraseña se escribe solo cuando la pide
Windows y no aparece en pantalla:

```cmd
net use \\PC-04\HESM-Actualizaciones * /user:PC-04\HESM-Lector /persistent:no
```

Si devuelve un error, registrar el número y texto sin incluir la contraseña.
No desconectar todas las unidades o impresoras de red para resolverlo.

Si la conexión explícita funciona y el Explorador vuelve a enviar la cuenta
local de la PC receptora, abrir **Administrador de credenciales → Credenciales
de Windows**. Editar únicamente la entrada `PC-04` si existe; de lo contrario,
agregar una credencial de Windows con dirección de red `PC-04`, usuario
`PC-04\HESM-Lector` y la contraseña elegida en el anfitrión. Guardarla desde la
sesión habitual del usuario que usa el Explorador y HESM. Volver a probar
`\\PC-04\HESM-Actualizaciones`. No usar el nombre del equipo cliente como prefijo
del usuario lector. La contraseña queda en el almacén de Windows, fuera de HESM.

Si el nombre de PC-04 no se resuelve, la IP actual del anfitrión es
`192.168.0.179`. Su uso permanente requiere una dirección estable acordada con
el administrador de la red.

La publicación fue verificada desde PC-04. El responsable confirmó desde una
PC con Windows 10 la lectura, la instalación base y la detección e instalación
de la actualización `1.0.3.4 → 1.0.4.5` el 29/10/2026. El rechazo de escritura
y la persistencia tras volver a iniciar sesión en Windows siguen pendientes de
validación. Se conserva el acceso autenticado, el cifrado SMB 3 y las firmas.
