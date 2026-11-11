# Proyecto en C: y PC que publica actualizaciones

La computadora elegida es **PC-04**. En ella se desarrolla con VS Code, se
compilan y firman las versiones y se conserva la carpeta de distribución.
Debe permanecer encendida mientras las otras PCs consultan actualizaciones.

| Ubicación | Contenido | Acceso |
| --- | --- | --- |
| `C:\HESM-Gestion-RRHH` | Código, Git, configuración, herramientas, entregas y clave de firma local. | Privado; no compartir en la red. |
| `C:\HESM-Actualizaciones` | Aviso firmado e instaladores de las versiones que se ofrecen a los usuarios. | Compartida; lectura restringida al grupo autorizado. |
| `\\PC-04\HESM-Actualizaciones` | Ruta que se configurará en las aplicaciones de las otras PCs. | Habilitada; cuenta lectora `PC-04\HESM-Lector` autorizada el 29/10. |

## Estado del traslado al 28/10/2026

Se copiaron y verificaron por SHA-256 **4.562 archivos**, incluyendo Git,
`.private`, configuración local, historial de respaldos, fuentes, pruebas y
entregas. El estado Git de ambas ubicaciones coincidía al terminar la copia.
Se excluyeron únicamente caches generadas: `build`, `.dart_tool`, el archivo
de dependencias de plugins y `windows/flutter/ephemeral`. Flutter las regenera
en la nueva ubicación. El informe está en `.private/project-relocation.json`.
Desde la carpeta nueva finalizaron correctamente `flutter pub get --enforce-lockfile`,
el análisis estático y las **128 pruebas Flutter**.

La carpeta nueva conserva permisos restringidos y la clave de firma original.
Se preparó `HESM-Gestion-RRHH.code-workspace` para abrir el proyecto en VS Code.

Windows no permitió mover la carpeta original porque otros procesos la mantienen
abierta. **El original continúa en el Escritorio; la ubicación de trabajo nueva
es `C:\HESM-Gestion-RRHH`.** No alternar ediciones entre ambas carpetas.

Para finalizar, cerrar las ventanas de VS Code y terminales que usan la ubicación
anterior, y desde PowerShell ubicado fuera de ella ejecutar:

```powershell
powershell -NoProfile -File C:\HESM-Gestion-RRHH\tool\finish_project_relocation.ps1
```

El script comprueba el informe, que no haya cambios nuevos en las fuentes del
origen, el commit y las claves. Archiva el original dentro de `.history-backups`
en la ubicación nueva y crea un enlace de compatibilidad en el lugar anterior.
No borra el original: conserva ese respaldo, incluidos sus caches. Si Windows
mantiene un bloqueo o detecta cambios pendientes, se detiene sin moverlo.

## Habilitar la carpeta compartida

La distribución operativa posterior documentada es **1.0.6.7**, del 2/11/2026.
El código de Ficha y Licencias aún requiere una nueva distribución. Ver
[Estado actual](ESTADO_ACTUAL.md). El recorrido siguiente conserva la evidencia
del traslado y las publicaciones de octubre.

La versión vigente al terminar la preparación del 29/10 era **1.0.4.5**. Se
publicó desde `dist/Windows-LAN-1.0.4.5/` y se verificó nuevamente por UNC:
aviso, firma del instalador, tamaño y SHA-256, con lectura heredada para el
grupo autorizado. La comprobación Dart del paquete real también pasó y rechazó
una copia alterada. Se mantienen las versiones anteriores para respaldo.

Actualización del 29/10: se publicó la versión **1.0.3.4**, con el nuevo inicio
animado y verificaciones. Se verificaron el aviso firmado, la firma del instalador,
su tamaño y SHA-256 por la ruta UNC desde PC-04. El instalador hereda lectura para
`HESM-Lectores`; se conservó el cifrado obligatorio del recurso. La versión anterior
permanece en `versions/1.0.1.2`. La actualización posterior `1.0.3.4 → 1.0.4.5`
en Windows 10 fue confirmada por el responsable.

La versión `1.0.1.2` ya se preparó localmente en `C:\HESM-Actualizaciones`.
El aviso está firmado y el instalador coincide con el paquete validado.
**Estado al 28/10/2026:** el configurador ya se ejecutó mediante la autorización
de administrador de Windows. El recurso está habilitado con cifrado SMB,
enumeración por permisos y caché sin conexión deshabilitada. Se verificaron los
permisos SMB y NTFS y la lectura del aviso e instalador por la ruta UNC desde
PC-04, incluyendo hashes y firmas. Esto no reemplaza la prueba desde otra PC.

Para reproducir la configuración, Windows requiere **PowerShell como administrador**:

```powershell
powershell -NoProfile -File C:\HESM-Gestion-RRHH\tool\setup_windows_update_share.ps1 -Publicador 'PC-04\som'
```

El script deja preparado:

- Recurso `HESM-Actualizaciones` sobre la carpeta dedicada, separado del proyecto.
- Escritura para `PC-04\som` y lectura para el grupo local `HESM-Lectores`.
- Permisos NTFS coherentes; sin acceso de invitados ni escritura para toda la red.
- Cifrado SMB y caché sin conexión deshabilitada para las actualizaciones.
- Una regla de firewall para SMB solo en el perfil privado y desde la subred local.

El grupo de lectores empieza vacío. No crea cuentas, no asigna contraseñas ni
autoriza automáticamente a todos los equipos. Se deben incorporar las cuentas
Windows autorizadas del anfitrión, o cuentas del dominio si corresponde.
Se pueden indicar cuentas existentes mediante `-LectoresWindows` al ejecutar
el script. No usar la cuenta publicadora como cuenta compartida de lectura.

No se desactivan las protecciones globales de SMB ni se abre el recurso a internet.
Para acceso por VPN hay que revisar su subred con el responsable de la red.
Si la carpeta o el recurso ya tienen contenidos/permisos ajenos, el script se
detiene. La lectura desde una segunda PC y el rechazo de escritura con una cuenta
lectora deben comprobarse cuando esté disponible ese equipo.
Se comprobó que el script rechaza la ejecución sin esos permisos.

## Publicar las siguientes versiones desde esta PC

1. Trabajar en `C:\HESM-Gestion-RRHH`, incrementar `version:` y generar el instalador.
2. Preparar la versión en la carpeta local de distribución:

   ```powershell
   Set-Location C:\HESM-Gestion-RRHH
   powershell -NoProfile -File tool\build_windows_installer.ps1
   powershell -NoProfile -File tool\publish_windows_update.ps1 `
     -Paquete 'C:\HESM-Gestion-RRHH\dist\CARPETA-DE-LA-NUEVA-VERSION' `
     -CarpetaLocal 'C:\HESM-Actualizaciones'
   ```

3. Las otras PCs, con lectura autorizada, consultan la nueva versión desde
   `\\PC-04\HESM-Actualizaciones`. Configurar esa ruta en la aplicación.

La publicación local no requiere VS Code abierto ni una cuenta de GitHub. Una
vez habilitado SMB, el equipo debe estar encendido y con red disponible, pero
el editor puede estar cerrado. La clave privada nunca se copia al recurso compartido.

El 29/10 se autorizó la cuenta lectora dedicada. PC-01 se autenticó, pero su
Windows 7 no admite el cifrado requerido. Posteriormente se confirmó la lectura
y la actualización real desde una PC con Windows 10. El rechazo de escritura
todavía requiere validación.

## Prueba desde PC-01 · 29/10/2026

PC-01 informó que la ruta por nombre no se podía abrir. Al probar
`\\192.168.0.179\HESM-Actualizaciones` apareció el pedido de credenciales:
esto confirma alcance SMB por IP, pero todavía no confirma lectura autorizada.
La IP es la dirección actual de Ethernet en PC-04; una reserva DHCP debe acordarse
con el administrador de red antes de depender de ella como dirección permanente.

El diagnóstico de PC-04 confirmó perfil privado, servicio SMB escuchando y regla
`HESM-Updates-SMB-Private` habilitada para TCP 445 desde la subred local. El grupo
de lectores estaba vacío. No se modificaron el firewall ni los permisos generales.

Para autorizar una cuenta lectora dedicada, ejecutar como administrador:

```powershell
powershell -NoProfile -STA -File C:\HESM-Gestion-RRHH\tool\authorize_windows_update_reader.ps1
```

El configurador solicita una contraseña de al menos 14 caracteres en una ventana
local, crea `PC-04\HESM-Lector` y la incorpora al grupo lector. No escribe la
contraseña en archivos o informes ni la incorpora a la aplicación. Mantiene la
política de vencimiento de contraseñas de Windows. El resultado sin contraseña
queda en `.private/update-reader-result.json`.

La cuenta se creó y habilitó el 29/10. Se verificó su pertenencia a
`HESM-Lectores`, con lectura SMB y NTFS del recurso de actualizaciones.
La cuenta no pertenece a Administradores. El siguiente intento de PC-01 fue
rechazado: el evento 4625 de PC-04 registró usuario/dominio correctos y subestado
`0xC000006A` (contraseña incorrecta). La lectura remota todavía no está confirmada.
Se dejó disponible `-ResetPassword` en el configurador para elegir otra contraseña
localmente si el responsable lo necesita; no se restablece automáticamente.
El responsable solicitó restablecerla y la eligió en la ventana local el 29/10
a las 07:27. Se confirmó el cambio en Windows, la cuenta habilitada, el requisito
de contraseña y su pertenencia al grupo lector. No se registró la contraseña
en el proyecto ni en los informes.

El evento 4624 de las 07:33 confirmó la autenticación de `PC-04\HESM-Lector`
desde PC-01. El servidor negoció SMB 2.1. Los eventos SMBServer/Operational 1003
de los intentos posteriores identificaron el rechazo de mensajes sin cifrar al
recurso `HESM-Actualizaciones`, que exige cifrado. El responsable confirmó que
PC-01 usa Windows 7. Los permisos SMB y NTFS del recurso y sus archivos permiten
lectura al grupo correcto; el rechazo actual corresponde al cifrado.

El instalador existente ya exige Windows 10 1809 o posterior de 64 bits. Windows 7
también queda fuera de la compatibilidad de esta aplicación. Se conserva el
cifrado del recurso y no se cambian permisos para intentar resolver esa limitación.
La próxima validación necesita una PC con Windows compatible.

El responsable indicó continuar con Windows 10/11. En otra PC con Windows 10,
la apertura de `\\PC-04` mostró restricciones de cuenta antes de entrar al recurso.
Se está probando la conexión explícita con `PC-04\HESM-Lector`; ese error es distinto
al rechazo por cifrado de PC-01 con Windows 7. No se retiraron restricciones de
contraseñas ni se habilitaron invitados.

El diagnóstico posterior confirmó una sesión SMB 3.1.1 de la PC con Windows 10
autenticada como `PC-04\HESM-Lector`. Sin embargo, los intentos del Explorador
enviaban `som` desde el dominio/equipo cliente y recibían `0xC000006E` (restricción
de cuenta). Se indicó registrar la cuenta lectora en las Credenciales de Windows
del usuario de esa PC para el destino `PC-04`. La lectura desde el Explorador
y la persistencia tras iniciar sesión todavía requieren confirmación.

El responsable confirmó posteriormente que el acceso desde el Explorador funciona
y que instaló `1.0.3.4` en la PC con Windows 10, con la carpeta UNC configurada
dentro de HESM. Se publicó `1.0.4.5` para la prueba documentada en
[Prueba de actualización](PRUEBA_ACTUALIZACION_WINDOWS.md). El responsable
confirmó que la aplicación ofreció esa versión y posteriormente informó que se
instaló correctamente. Quedan por validar el rechazo de escritura y la persistencia
de acceso tras volver a iniciar sesión en Windows.

Referencias: [diagnóstico de conexión SMB](https://learn.microsoft.com/en-us/troubleshoot/windows-server/networking/negotiate-session-setup-tree-connect-fails),
[plataformas compatibles de Flutter](https://docs.flutter.dev/reference/supported-platforms).

Desde PC-01 elegir **Usar otra cuenta** si corresponde, escribir
`PC-04\HESM-Lector` y la contraseña elegida localmente. Son credenciales de
Windows del anfitrión, independientes del acceso de RRHH. Una vez confirmada
la lectura, comprobar que la cuenta no puede crear o modificar archivos del
recurso. La clave de firma y el proyecto siguen fuera de la carpeta compartida.
