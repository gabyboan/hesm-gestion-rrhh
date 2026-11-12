# Distribución Windows 1.0.7.8

Publicada el **12 de noviembre de 2026**, por el canal privado de actualizaciones
del hospital. El código compilado es `1.0.7+8`, commit público
`d9590c69c4205370edbbe90c4df2f3df14f4556b`.

Incluye Ficha y Licencias, Horas Gremiales, guardado de horas protegido contra
reenvíos, caché por sesión, espera progresiva del login y recuperación de la
pantalla de acceso. El alcance está en [Actualización 1.0.7.8](ACTUALIZACION_1_0_7.md).

## Estado verificado

- Instalador y aviso de versión firmados con la clave Ed25519 que ya reconocen
  los clientes. La publicación conserva los instaladores anteriores.
- Paquete extraído y revisado: ejecutable `1.0.7.8`, bibliotecas de Windows,
  runtime de Visual C++ y las funciones nuevas presentes. Sin archivos de
  configuración privada, claves de firma ni respaldos dentro del paquete.
- Firma, tamaño y SHA-256 comprobados desde la ruta UNC después de publicar.
- El código Dart del actualizador verificó el paquete real y rechazó una copia
  alterada. El código del cliente `1.0.6.7` también aceptó el aviso y el instalador.
- Comparación de versiones comprobada desde `1.0.1.2`, `1.0.3.4`, `1.0.4.5`,
  `1.0.5.6` y `1.0.6.7`. Una misma versión no se ofrece como actualización.
- Manifiesto con `required_schema=2`; las dos migraciones ya están aplicadas
  y se volvió a comprobar su presencia antes de distribuir.

| Dato | Valor |
| --- | --- |
| Instalador | `HESM-Gestion-RRHH-1.0.7.8-Setup.exe` |
| Tamaño | 14.775.943 bytes |
| SHA-256 | `858b3fd5fe5e745490fb2bbe2a32fd0b5ad0b3f35f0f6700a8a88a3291afe320` |
| Sistemas | Windows x64, 10.0.17763 o posterior |

El canal conserva lectura autenticada, cifrado SMB y caché sin conexión
deshabilitada. La publicación no cambió sus permisos.

## Actualizar cada puesto

1. Mantener la PC publicadora encendida y conectada a la red del hospital.
2. Guardar el trabajo y volver a abrir la aplicación instalada en el puesto.
3. Cuando ofrezca **1.0.7.8**, elegir **Instalar y reiniciar**.
4. Después de abrir, comprobar la versión en Configuración e iniciar sesión.
5. Si no aparece el aviso, usar **Configuración → Actualizaciones del hospital →
   Guardar carpeta y buscar**, con la carpeta de red ya utilizada en ese puesto.

Para una instalación inicial o manual, abrir la carpeta compartida del hospital,
entrar en `versions\1.0.7.8`, copiar el instalador al puesto, cerrar HESM y
ejecutarlo. La ruta del entorno está en
[Primera PC Windows](PRIMERA_PC_WINDOWS.md).

Se verificó la publicación desde la PC anfitriona. La instalación física en
cada puesto receptor requiere su comprobación. Antes de comenzar a cargar
Gremiales en el trabajo habitual, completar la actualización de los puestos
que preparan informes para que todos reconozcan la nueva modalidad.

La prueba con la cuenta del responsable en esta PC se documenta en
[Prueba local](PRUEBA_LOCAL_1_0_7.md). No se publican instaladores operativos
en GitHub: el repositorio mantiene código, pruebas y documentación.
