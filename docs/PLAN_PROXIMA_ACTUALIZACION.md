# Propuesta para la próxima actualización

Revisión inicial del 12 de noviembre de 2026. Este alcance fue la base del trabajo.

La implementación preparada `1.0.7.8` se describe en
[Actualización 1.0.7.8](ACTUALIZACION_1_0_7.md): Horas Gremiales, guardado con
reconocimiento de reenvíos, caché por sesión, espera del login, compatibilidad,
diagnóstico y herramientas de copia externa. Las migraciones ya se aplicaron
durante la [prueba local](PRUEBA_LOCAL_1_0_7.md); el instalador firmado ya se
[publicó en el canal privado](DISTRIBUCION_1_0_7.md). Los hallazgos siguientes conservan la revisión
previa a esa implementación.

## Horas Gremiales

Requerimiento confirmado: funcionan como Horas Oficiales, se denominan
**Horas Gremiales** y admiten personas de cualquier carrera o categoría.

- Agregar una modalidad `GREMIAL` dentro de Horas, conservando las otras tres.
- Usar fecha y duración con el mismo selector de Oficiales: de 30 minutos a
  10 horas, en pasos de 30 minutos. Verificar también la regla del servidor.
- Incluir las distintas carreras y categorías del padrón. La carga continúa
  requiriendo los permisos de Horas del operador.
- Mostrar Gremiales por separado en consultas, filtros, totales e informes XLSX.
  Conservar los registros históricos de Oficiales con su tipo original.
- Mantener su cómputo separado del cupo de Particulares, siguiendo el tratamiento
  de Oficiales. Cualquier cupo gremial adicional requiere una regla acordada.
- Conservar autoría, fecha de carga y trazabilidad de las correcciones.

No confundir esta modalidad, expresada en minutos, con la licencia gremial
del catálogo de Licencias, expresada en días.

El modelo actual de Horas exige una carrera asociada. Antes de completar el
selector debe resolverse el tratamiento de personas sin carrera asignada y
confirmarse el alcance sobre bajas/inactividad; no corresponde inventar una
carrera para poder guardar el registro.

Cambios necesarios: enum y modelos, selector de personas, formulario,
repositorio/RPC, restricciones SQL, consulta, informe, exportación y demo.
La base y los clientes deben desplegarse coordinadamente: los informes antiguos
solo conocen Particular, Enfermedad y Oficial y pueden omitir el nuevo tipo.

## Inicio de sesión e intentos fallidos

Situación comprobada en el código:

- `login_page.dart` impide enviar otra solicitud mientras `_loading` es verdadero.
  Tras una respuesta fallida vuelve a habilitar el ingreso inmediatamente.
- No existe contador de errores de contraseña ni espera progresiva en ese flujo.
- La traducción del login no maneja expresamente HTTP 429 ni el código de
  exceso de solicitudes; el flujo de MFA sí contempla ese código.
- El repositorio delega la validación de contraseña a Supabase Auth.

Propuesta:

1. Verificar los límites reales de Auth en el proyecto HESM. Supabase limita
   solicitudes en el servidor, incluido el endpoint de tokens utilizado para
   contraseña y renovación. El límite por IP debe contemplar las PCs que
   comparten la salida a internet del hospital y las renovaciones de sesión.
2. Agregar una espera progresiva en la aplicación después de varios errores
   confirmados de credenciales. Como política inicial a evaluar: cinco errores
   en quince minutos y esperas de 30 segundos, un minuto y cinco minutos.
   Una caída de red no debe contarse como contraseña incorrecta.
3. Traducir el 429 y mostrar cuándo se puede reintentar. Respetar la indicación
   del servidor cuando esté disponible, con una espera conservadora si no la hay.
   No reintentar contraseñas automáticamente.
4. Mantener mensajes genéricos sobre credenciales para evitar revelar si una
   cuenta existe, y mensajes de red distintos de los de contraseña incorrecta.
5. Verificar MFA en cuentas con permisos administrativos y preparar recuperación
   de acceso. Definir una política de contraseñas y actualización de cuentas
   existentes sin provocar un bloqueo general de operadores.

La espera en la app mejora el uso cotidiano; no constituye por sí sola una
protección contra llamadas directas al servicio. Una política estricta por
cuenta debe aplicarse en el servidor. El hook específico de intentos de
contraseña está documentado para Teams y Enterprise: no debe darse por disponible
en el plan Free mencionado en la documentación histórica del proyecto.
La disponibilidad y el plan vigente requieren comprobación.

## Hallazgos de confiabilidad

| Prioridad | Evidencia | Acción sugerida |
| --- | --- | --- |
| Alta | `CargarHoraController.submit()` no activa `AsyncLoading`, aunque la pantalla usa ese estado para deshabilitar Guardar. Un diagnóstico con repositorio simulado permitió dos solicitudes concurrentes. | Bloquear la operación en el controlador y reflejar su estado en la pantalla. Añadir una prueba que exija una sola solicitud pendiente. |
| Alta | La RPC de carga recibe los datos de la hora sin un identificador de operación. Una respuesta perdida deja incierto si la escritura terminó. | Revisar restricciones reales y agregar un identificador único por operación, para reconocer un reenvío sin duplicar la carga ni impedir dos cargas legítimas iguales. |
| Alta | Las copias documentadas están ligadas a la misma PC y a su perfil de Windows mediante DPAPI. | Preparar copia cifrada externa, custodia de recuperación independiente y ensayos de restauración. Definir cuántas horas/días de trabajo se acepta perder; la frecuencia semanal permite perder hasta siete días. |
| Media | `periodosConRegistros()` descarga filas de `horas_registros` y obtiene los meses distintos en Dart, sin paginación explícita. | Consultar períodos distintos en el servidor y revisar paginación de listados. Probar datos que superen el límite de filas de la API para detectar meses o totales incompletos. |
| Media | El arranque asigna `FlutterError.presentError`; no se encontró un registro central de fallos para soporte. Algunos flujos muestran el texto original de la excepción. | Registrar versión, módulo, código de error e identificador de solicitud con rotación y redacción; mostrar mensajes claros al operador. Excluir contraseñas, tokens, documentos y datos del personal. |
| Media | El manifiesto firmado valida instalador y versión, pero no declara una versión mínima del esquema de datos. | Agregar compatibilidad de esquema y funciones, probar la nueva versión en un puesto y conservar un instalador anterior compatible. Los cambios de datos necesitan su propio plan de recuperación. |

El diagnóstico de doble envío confirma dos llamadas, no dos filas insertadas:
no se utilizó la base operativa y no se verificaron sus restricciones actuales.

## Base que ya existe

El sistema cuenta con comprobaciones de inicio, recuperación de conectividad,
permisos por módulo, MFA opcional, revalidación, sesión única por cuenta,
actualizaciones firmadas y pruebas automatizadas. El trabajo propuesto refuerza
los recorridos de guardado, ingreso, recuperación y despliegue.

Conviene mantener el lockfile y separar los cambios funcionales de una migración
de SDK: el changelog de Supabase anuncia cambios incompatibles en Flutter v3.

## Alcance de esta revisión

- Se revisaron el código local y las guías de operación y se contrastó Auth con
  la documentación oficial vigente.
- El análisis estático terminó sin observaciones.
- El diagnóstico aislado de dos envíos concurrentes reprodujo el problema.
- La suite funcional terminó con **194 pruebas aprobadas**. El diagnóstico de
  concurrencia se ejecutó por separado, con repositorio simulado.
- La conexión Supabase disponible no muestra el proyecto HESM. No se consultaron
  proyectos ajenos ni se verificaron los límites, avisos, logs o el plan real de
  HESM. Tampoco se realizaron intentos repetidos de acceso contra cuentas reales.

## Orden sugerido de entrega

1. Corregir doble envío y tratamiento de resultados inciertos al guardar.
2. Completar la protección y los mensajes del ingreso.
3. Incorporar Horas Gremiales de punta a punta y comprobar compatibilidad.
4. Probar la actualización en un puesto antes de distribuirla al resto.
5. Completar recuperación externa y diagnóstico operativo, con pruebas periódicas.

## Referencias

- [Límites de Supabase Auth](https://supabase.com/docs/guides/auth/rate-limits).
- [Disponibilidad de Auth Hooks por plan](https://supabase.com/docs/guides/auth/auth-hooks).
- [Hook de verificación de contraseña](https://supabase.com/docs/guides/auth/auth-hooks/password-verification-hook).
- [Seguridad de contraseñas](https://supabase.com/docs/guides/auth/password-security).
- [Changelog de Supabase](https://supabase.com/changelog.md).
- [Estado actual](ESTADO_ACTUAL.md) y [respaldos](RESPALDOS_BASE_DATOS.md).
