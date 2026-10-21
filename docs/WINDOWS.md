# Windows: aplicación y demostración

Entrega portátil para Windows x64, preparada con Flutter 3.38.6 y Dart 3.10.7.
Descomprimí el ZIP completo y ejecutá `app_horas.exe` desde su carpeta, junto
con las DLL y el directorio `data`.

| Variante | Uso | Configuración y datos |
| --- | --- | --- |
| **Aplicacion** | Probar el acceso y los módulos contra un entorno propio. | Requiere la configuración externa de un Supabase de prueba y usuarios de ese entorno. El ZIP incluye únicamente una plantilla ficticia. |
| **Demo** | Recorrer las pantallas, buscar, consultar informes y previsualizar partes. | Arranca sin cuenta ni contraseña. Usa registros ficticios de octubre de 2026, bloquea HTTP y no inicializa Supabase. |

## Demostración de consulta

La franja superior identifica siempre los datos ficticios. Hay tres personas
`DEMO`, con identificadores cortos `1001`–`1003`, y partes de consultorio,
domicilio/ART y familiar de seis meses. No representan personal real.

- Horas permite consultar y exportar el informe de octubre de 2026. Los intentos
  de guardar o eliminar muestran un aviso de consulta.
- Francos e Imprevistos permiten buscar y consultar. Sus acciones de carga y
  administración están deshabilitadas.
- Médicos permite revisar los partes ficticios, ampliar sus PDF y agregarlos a
  la bandeja para una prueba de impresión. La impresión se inicia por acción
  del usuario y puede consumir papel.
- Suplencias permite consultar, buscar y ordenar los ejemplos.
- El tema se puede cambiar durante el recorrido. **Salir** reinicia la demo,
  sus preferencias en memoria y la bandeja.
- La calibración de impresión se guarda con un prefijo exclusivo de la demo,
  separado del que utiliza la aplicación normal.

La demo no simula una autenticación real ni verifica roles o RLS del servidor.
El ajuste de inactividad que muestra el diálogo pertenece a la interfaz
compartida; en esta variante no hay una sesión autenticada que pueda vencer.
Las verificaciones de acceso e inactividad se realizan con la aplicación normal
en el entorno de prueba.

## Aplicación normal: entorno de prueba

1. Extraé el paquete en una carpeta independiente de los repositorios y de
   cualquier configuración de producción.
   Cerrá antes cualquier otra instancia de la aplicación normal: su control
   de instancia única también se aplica entre carpetas y, si ya está abierta,
   puede activar esa ventana en lugar de iniciar la versión de prueba.
2. Copiá `credenciales.env.example` como `credenciales.env`, junto al ejecutable.
3. Completá `SUPABASE_URL` y `SUPABASE_ANON_KEY` con la URL y la clave de cliente
   del proyecto de prueba. Las claves `service_role` no corresponden a esta app.
4. Iniciá la aplicación con una cuenta del entorno sintético.

El cargador existente también busca configuración en el directorio de trabajo
y sus carpetas padre. Una carpeta independiente evita heredar accidentalmente
la configuración de otro entorno. La compilación no incorpora esos archivos
ni los valores de sus claves.

Las migraciones publicadas requieren contrastar primero el esquema y el
historial aplicado. Los 62 scripts conservados no constituyen una instalación
completa desde cero. Esta entrega no aplica migraciones a la base real.

## Recorrido de validación manual

**Estado al 21 de octubre de 2026:** el responsable del proyecto confirmó
que las pruebas manuales de sesión, permisos e impresora fueron realizadas
y aprobadas. Se registra su confirmación; no es una nueva ejecución
automatizada ni afirma que se hayan probado todas las combinaciones de la
tabla siguiente en ambos paquetes.

Registrá fecha, variante, commit de `build-manifest.json`, resultado y cualquier
incidencia, usando información ficticia en las evidencias.

| Control | Variante | Resultado esperado |
| --- | --- | --- |
| Inicio y navegación | Ambas | Ventana, textos, iconos y cinco módulos sin errores visuales. |
| Búsquedas | Demo o entorno de prueba | Encontrar por varios términos, acentos y documentos; limpiar la consulta. |
| Horas e informe | Ambas | Octubre de 2026 en demo; verificar selección, cupos, autoría y exportación ficticia. |
| Francos e Imprevistos | Ambas | Saldos, movimientos y cupos coherentes; controles de edición deshabilitados en demo. |
| PDF médico | Ambas | Revisar consultorio, ART, domicilio y edad en meses; ampliar sin recortes inesperados. |
| Bandeja | Ambas | Agregar varios; cancelar la impresión conserva los pendientes. |
| Alineación en papel | Impresora física | Ajustar sobre un formulario de prueba y verificar todos los campos. |
| Configuración de tema | Ambas | Cambiar tema y navegar. En demo se reinicia al salir. |
| Autenticación y roles | Aplicación normal | Cuenta sin rol, cuenta de lectura y cuenta de carga con los permisos previstos. |
| Inactividad y desconexión | Aplicación normal | Límite de 1–10 minutos, pausa durante falta de red y retorno controlado. |
| Cambio de usuario | Aplicación normal | Cerrar sesión y entrar con otra cuenta; no conservar la bandeja ni el perfil anterior. |

Las pruebas automatizadas cubren reglas y contratos concretos. Este recorrido
sirve como guía para repetir la validación al cambiar de versión, entorno,
impresora o formulario.

## Compilar y empaquetar de nuevo

Requiere Windows, Flutter 3.38.6 y Visual Studio Build Tools con desarrollo de
escritorio en C++. Desde la raíz del repositorio:

Para compartir los paquetes, usá una copia limpia en una ruta neutra fuera del
perfil de usuario, por ejemplo `C:\Temp\HESM-Windows`. Flutter puede incorporar
la ruta del punto de entrada en el binario; el empaquetador rechaza una ruta
del perfil local o un archivo de configuración privado dentro del bundle.

```powershell
powershell -NoProfile -File tool/build_windows_preview.ps1
```

El comando prepara ambas variantes en un directorio nuevo de `dist/`, ignorado
por Git. Se puede elegir `-Variante Aplicacion` o `-Variante Demo`, y un destino
nuevo mediante `-Destino`. Rechaza un destino existente para no mezclar archivos.

Cada ZIP contiene las bibliotecas nativas necesarias, `LEEME.md` y
`build-manifest.json`, con variante, commit, SDK, estado del árbol de origen y
hashes SHA-256 por archivo. `SHA256SUMS.txt` registra los hashes de los ZIP.
Los ejecutables y paquetes se distribuyen como artefactos, fuera del árbol Git.

Si el equipo de destino carece del runtime de Visual C++, consultá el
[redistribuible x64 de Microsoft](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist?view=msvc-170).
La arquitectura del runtime debe corresponder a la de la aplicación.
La [guía de distribución Windows de Flutter](https://docs.flutter.dev/platform-integration/windows/building)
explica por qué deben conservarse las DLL y los archivos de datos junto al ejecutable.

La solicitud a soporte para las capturas antiguas del PR #1 continúa pendiente
y es independiente de estos paquetes con datos ficticios.
