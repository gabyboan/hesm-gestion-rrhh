# Instalación y actualizaciones de Windows

La versión del código **1.0.6.7** agrega el domicilio histórico de los partes
y una Gestión por cuenta. El instalador operativo se genera y distribuye por
un canal privado. Las rutas y cuentas siguientes son ejemplos de configuración.

## Instalar y actualizar

El instalador es para Windows x64, versión 10.0.17763 o posterior, y se instala
por usuario sin exigir permisos de administrador. Incluye el runtime de Visual
C++ necesario para la aplicación y conserva las preferencias del usuario.

En una instalación existente, configurar una carpeta UNC dedicada desde
**Configuración → Actualizaciones del hospital**. Por ejemplo:
`\\PC-PUBLICADORA\HESM-Actualizaciones`. Al volver a abrir la aplicación, la
pantalla de inicio comprueba la versión y ofrece **Instalar y reiniciar**.
También comprueba actualizaciones durante la ejecución. Es un reinicio de la
aplicación; no requiere reiniciar Windows.

Todas las PCs deben actualizarse para participar de la reserva de sesión única.
Las versiones anteriores no realizan esa reserva. El responsable del entorno
debe aplicar y verificar las migraciones antes de distribuir un cliente que las
necesite. El historial SQL público depende del esquema previo del proyecto.

## Generar el instalador

Requisitos adicionales: Visual Studio con las herramientas Windows de Flutter,
Inno Setup 6.5 o posterior y una clave local de firma Ed25519.

```powershell
powershell -NoProfile -File tool/build_windows_installer.ps1 `
  -Version '1.0.6+7' `
  -Configuracion 'credenciales.env' `
  -SigningKey '.private/windows-updates.key' `
  -Destino 'dist/Windows-LAN-1.0.6.7'
```

El script valida la clave publishable/anon, compila en una carpeta temporal
fuera del perfil personal y genera un instalador, `release.json` firmado y
`SHA256SUMS.txt`. El archivo de configuración temporal se elimina al terminar.
La clave privada de firma y las claves administrativas no se incorporan al
ejecutable. La clave pública de verificación sí forma parte del cliente.

## Publicar en la red privada

Preparar una carpeta de distribución separada del proyecto, con escritura para
el responsable de publicación y lectura autenticada para los usuarios. El
script `tool/setup_windows_update_share.ps1` permite configurarla con las
cuentas del entorno; no se necesitan cuentas reales para compilar o probar el
código público.

```powershell
powershell -NoProfile -File tool/publish_windows_update.ps1 `
  -Paquete 'dist/Windows-LAN-1.0.6.7' `
  -CarpetaRed '\\PC-PUBLICADORA\HESM-Actualizaciones'
```

El publicador verifica firma, hash y tamaño, conserva las versiones anteriores
y copia el instalador a `versions/1.0.6.7/`. Solo después reemplaza `latest.json`
de forma atómica. Rechaza una versión igual o anterior a la publicada.

El cliente verifica el manifiesto y el instalador antes de ejecutarlo, incluida
la copia local en disco. Una firma inválida o una copia alterada se rechazan.
La compilación operativa de GitHub Actions se habilita únicamente para un
repositorio privado mediante ejecución manual y secretos de ese entorno.

## Validación de la versión

La entrega de Windows 1.0.6.7 se compiló, extrajo y comprobó: versión del
ejecutable, presencia de ambos cambios, archivos privados excluidos, firmas,
SHA-256 y tamaño. El código Dart del actualizador reconoció versiones anteriores
y rechazó un instalador alterado. La instalación física en cada equipo se
comprueba desde su cliente instalado.
