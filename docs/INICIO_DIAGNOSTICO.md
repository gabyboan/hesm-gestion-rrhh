# Inicio con verificaciones

Desde `1.0.3+4`, la pantalla inicial presenta el logo HESM grande y centrado.
Después de un segundo sube y se achica mientras aparecen las tarjetas de
verificación. Conserva los colores institucionales y el engranaje animado.
Desde `1.0.4+5` la esquina superior derecha muestra la versión instalada y las
tarjetas aprobadas conservan solo el check verde, sin la etiqueta Listo.
Las restantes indican En espera, Verificando o Error y un resumen cuenta
los controles aprobados. Los detalles corresponden a las comprobaciones reales;
no se simulan mediciones de velocidad, latencia ni recursos.

Los controles comienzan cuando termina la entrada de 2,2 segundos. Con la opción
de movimiento reducido de Windows se presenta directamente el panel sin animar.

| Control | Qué comprueba |
| --- | --- |
| Configuración de la aplicación | Instancia única en Windows, URL HTTPS válida y clave de cliente publishable/anon. |
| Resolución DNS | El DNS del equipo resuelve el nombre del servidor configurado. |
| Internet y conexión segura | Se establece HTTPS con el servidor y se valida su certificado TLS; no se aceptan redirecciones. |
| Servicio de autenticación | El endpoint de salud de Auth responde correctamente con la clave de cliente. |
| Servicio de datos de Supabase | La API de la aplicación responde a una solicitud con límite cero, sin obtener registros de personal. |
| Preparación del sistema | Se inicializa el cliente de Supabase para mostrar el acceso. |

Los seis controles de servicios son reales y secuenciales. Solo se llega al login
cuando todos pasan. Ante un fallo, los siguientes quedan pendientes, la pantalla informa
una causa comprensible y aparece **Reintentar**. El reintento vuelve a comprobar
los servicios, sin crear una segunda instancia de Windows ni inicializaciones
simultáneas del cliente. No se muestran claves, archivos privados o trazas técnicas.

DNS tiene un límite de 6 segundos, cada solicitud HTTP de 10 segundos y la
preparación del cliente de 20 segundos. El inicio exitoso conserva un mínimo de
5 segundos de presentación, incluida la entrada de la marca. Si falla un control,
el error se muestra sin esperar ese mínimo. En pantallas pequeñas o con texto
grande, las tarjetas y el botón de reintento se pueden desplazar bajo la marca.
En ventanas de altura normal y con texto estándar, el resumen y Reintentar
permanecen visibles al pie mientras las tarjetas se desplazan por separado.

## Versión y actualizaciones

La primera tarjeta comprueba la versión publicada en la carpeta configurada,
en paralelo con los servicios. Verifica la firma del aviso antes de ofrecerlo:

- **Sistema actualizado**: no hay una versión publicada superior a la instalada.
- **Actualización pendiente**: indica la versión disponible y ofrece Instalar y
  reiniciar o Ignorar y continuar. Ignorar habilita el acceso solo cuando los
  seis controles obligatorios pasaron. El aviso de esa misma versión no vuelve
  a aparecer automáticamente durante esa ejecución; se vuelve a consultar al
  abrir la aplicación y se mantienen los controles periódicos cada cuatro horas.
- **Actualizaciones sin configurar** o **No se pudo comprobar actualizaciones**:
  información que permite continuar con los servicios disponibles; no se confunde
  con una versión actualizada. La consulta inicial tiene límite de 12 segundos.

El resumen incluye este séptimo control únicamente en las compilaciones que
habilitan el actualizador. Los seis servicios siguen siendo obligatorios.
No se repite la consulta inicial al pasar al login. Configuración muestra también
la versión instalada y permite buscar manualmente aunque se haya ignorado el aviso.
Instalar comprueba firma, tamaño y SHA-256 del instalador y su copia local antes
de ejecutarlo. La instalación solo comienza después del clic explícito del usuario.

## Disponibilidad y permisos

El control de internet verifica el recorrido HTTPS hacia el servicio que utiliza
la aplicación. No depende de que un sitio externo ajeno al hospital responda.
Un error de certificado sugiere revisar la fecha/hora y la configuración de red;
no se omite la validación TLS para continuar.

La API de datos se prueba con `select=*&limit=0` sobre `horas_registros`. Un resultado
vacío o un rechazo explícito de PostgreSQL por falta de sesión/permisos confirma
que el servicio responde. Los rechazos previstos `42501`/`PT401` antes del login
no se confunden con una caída. Una clave rechazada por el gateway, un error de
servicio, un endpoint inexistente o una respuesta inesperada detienen el inicio.
No se utilizan claves administrativas ni se modifican RLS o permisos.

La marca verde confirma disponibilidad en ese momento; no reemplaza la validación
de identidad, MFA, roles y permisos que ocurre después de iniciar sesión. Tampoco
comprueba escrituras, impresoras o toda la base de datos. La carpeta de
actualizaciones sigue siendo opcional y su indisponibilidad no impide trabajar.

## Verificación y vistas

Las pruebas cubren el bloqueo previo al login en cada etapa, la recuperación por
reintento, el rechazo de configuración insegura, la diferencia entre autorización
y caída de servicio, y la presentación en pantallas pequeñas. Los servicios DNS,
TLS, Auth y API también se probaron desde esta computadora con la configuración
real, sin obtener registros de personal.

`tool/generate_startup_preview_test.dart` genera vistas de la interfaz real con
resultados simulados, sin solicitudes de red, en `build/startup-preview/`.

Validación del 29/10/2026 para `1.0.4+5`: análisis sin observaciones, **142 pruebas aprobadas**,
compilación Windows correcta y firmas del aviso e instalador verificadas.
Se extrajeron y verificaron por SHA-256 los 29 archivos de la versión portátil
en `dist/Windows-Portable-1.0.4.5/app_horas.exe`. Cerrar la instancia anterior
antes de abrirla. Se publicó el paquete firmado `1.0.4.5` en la carpeta del
hospital y se verificaron el aviso y el instalador por la ruta UNC. El mismo
código Dart de la aplicación verificó el paquete real y rechazó una copia
alterada. El responsable confirmó que la otra PC detectó e instaló correctamente
la actualización desde `1.0.3.4` a `1.0.4.5` el 29/10/2026.

Referencias: [salud de Auth](https://github.com/supabase/auth/blob/master/docs/health.go),
[API PostgREST](https://docs.postgrest.org/en/v13/references/api.html),
[claves de cliente](https://supabase.com/docs/guides/api/api-keys).
