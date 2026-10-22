# Preparación para GitHub

Revisión inicial: 20 de octubre de 2026.
Actualización de verificaciones: 21 de octubre de 2026.

Estado: documentación por archivo y limpieza de las dos ramas públicas completadas.
La limpieza se publicó como `ecb7bfd`, desde una copia aislada. Los cambios
funcionales y las dos variantes de Windows ya se integraron en `main` mediante
los PR #2 y #3, y se documentan en [Entrega GitHub](ENTREGA_GITHUB.md).
Las pruebas manuales de sesión, permisos e impresora están aprobadas según la
confirmación del responsable del proyecto del 21 de octubre de 2026.
No se crearon commits en el repositorio
de trabajo original.
La revisión inicial no constituye una certificación de ausencia de datos sensibles.

## 1. Privacidad antes de publicar

| Elemento | Hallazgo | Tratamiento en esta etapa |
| --- | --- | --- |
| Configuración de Supabase | Existe configuración local de ejecución. | `credenciales.env` está ignorado; la plantilla contiene marcadores ficticios. No se copiaron sus valores a la documentación. |
| Importaciones y domicilios | Cuatro migraciones locales contienen registros nominales. | Se excluyen por ruta exacta, conservando sus originales locales. |
| Capturas de Francos e Imprevistos | Se observan nombres y documentos; no está acreditado que sean ficticios. | Se guardan en `docs/mockups/private/`, ignorado por Git, y se retiran del README. |
| Panel de módulos | No se observan datos del personal en la captura revisada. | Se conserva en el README. |
| Formulario médico digitalizado | La imagen revisada corresponde a un formulario vacío. | Se conserva como recurso de la aplicación. |
| Respaldos y archivos locales | Pueden contener credenciales, sesiones o información de personal. | Se agregan exclusiones para claves privadas, respaldos, exportaciones y configuración local de herramientas. |
| Historial local | Se encontró una versión de la importación nominal en referencias locales de checkpoints de agentes. | No se eliminan ni reescriben referencias. No publicar esas referencias ni respaldos de Git. |

### Migraciones que deben permanecer locales

- `20260622090000_import_limpieza_imprevistos.sql`: carga nominal de imprevistos.
- `20260716104954_importacion_empleados_excel_vigentes.sql`: importación de personal con datos de identificación y contacto.
- `20261016130000_normalizar_domicilios_confirmados.sql`: normalización basada en domicilios identificables; también incorpora una columna de esquema.
- `20261016140000_corregir_acentos_domicilios.sql`: correcciones dirigidas a personas identificadas.

Excluir estos archivos protege la próxima incorporación de archivos a Git; no
elimina versiones anteriores. La columna `torre` ya se separó en la migración
pública `20261020132130_separar_torre_domicilio_publico.sql`, sin registros
nominales. Se ejecutó junto con la secuencia pública en una base sintética.

### Alcance de la inspección inicial

- Se inspeccionaron los archivos versionados y los nuevos no ignorados mediante patrones de claves, tokens, conexiones con contraseña, correos e identificadores.
- Se revisaron 115 commits alcanzables desde las referencias locales y 529 objetos de archivo mediante patrones; esto incluye checkpoints, además de las ramas habituales.
- No aparecieron coincidencias de los patrones de claves privadas, tokens de GitHub/Supabase, JWT o conexiones con contraseña en los textos inspeccionados. Otros formatos de secretos pueden requerir controles adicionales.
- La importación histórica detectada pertenece a checkpoints locales; las referencias locales de ramas y seguimiento remoto consultadas no contienen esos commits. Esto no verifica el estado actual del servidor de GitHub.
- Se revisaron visualmente las tres capturas existentes y el formulario médico vacío. No se realizó un análisis forense de metadatos ni de todas las imágenes históricas.
- No se consultó la base de datos ni se utilizaron credenciales de usuario.

## 2. Documentar cada cambio

La revisión inicial encontró 32 archivos modificados y 56 archivos nuevos, antes
de los ajustes de privacidad. Tras excluir los cuatro scripts nominales,
retirar dos capturas, incorporar las correcciones y los cambios nuevos, el
inventario actual abarca 108 archivos: 37 modificados, 2 retirados y 69 nuevos.

Se revisaron las diferencias y los archivos nuevos para preparar:

- [Registro de cambios](../CHANGELOG.md): quince grupos funcionales con dependencias y límites.
- [Cambios por archivo](CAMBIOS_POR_ARCHIVO.md): los 108 archivos, uno por uno, y el orden propuesto de commits.
- [Validación](VALIDACION.md): 80 pruebas aprobadas, análisis sin observaciones y 38 scripts públicos ejecutados en una base aislada.
- [Revisión de privacidad](REVISION_PRIVACIDAD.md): inspección de GitHub, Gitleaks, capturas y propuesta de limpieza del historial.

El inventario documenta el código local; no declara aplicadas las migraciones
en el proyecto real ni eliminados los identificadores que siguen en GitHub.

| Orden propuesto | Grupo | Qué documentar y verificar |
| --- | --- | --- |
| 1 | Privacidad y documentación | Exclusiones, retiro de capturas con identificadores y alcance de la revisión del historial. |
| 2 | Conectividad y sesión | Servicio de conexión, avisos compartidos, inactividad y comportamiento del acceso. |
| 3 | Preferencias | Persistencia de preferencias, tema, interfaz del panel y migración correspondiente. |
| 4 | Búsquedas y navegación | Normalización de consultas y cambios en Francos, Imprevistos, Suplencias y Médicos. |
| 5 | Horas | Cambios de modelos, consultas, beneficios, carga y visualización. |
| 6 | Médicos | ART, aclaraciones, domicilios, personas sin legajo, vistas previas e impresión ajustable. |
| 7 | Ficha de personal y familiares | Guardado atómico, identificación, CUIT, historial laboral, inactividad y validaciones. |
| 8 | Migraciones y permisos | Revisar los SQL uno por uno; separar estructura y reglas de las cargas de datos privados. |
| 9 | Dependencias y pruebas | Justificar dependencias nuevas, ejecutar análisis y pruebas, y registrar los resultados reales. |
| 10 | Presentación | Actualizar README y preparar una galería coherente con datos ficticios. |

Cada entrada del registro de cambios debe indicar:

1. El problema o necesidad que resuelve.
2. El comportamiento resultante y los archivos afectados.
3. La migración o dependencia requerida, si corresponde.
4. La verificación realizada y cualquier limitación pendiente.

El orden definitivo de los commits depende de las dependencias entre módulos.
No se deben dividir cambios relacionados de forma que un commit deje de compilar.

## 3. Mockups y capturas

Se preparó una [galería de demostración](mockups/README.md) del panel, Horas,
Francos, Imprevistos, Médicos y Suplencias a 1440 × 900, con tema oscuro y
proveedores ficticios aislados. No se inicia una sesión ni se consulta Supabase.
Una cuenta adicional sobre la base real sigue mostrando datos reales.

No compartir contraseñas en el chat. No guardar contraseñas, tokens, sesiones ni
capturas de configuración en el repositorio. Las capturas nuevas deben revisarse
completas: buscadores, listados, encabezados, mensajes y documentos generados.

## 4. Revisión final y publicación

- [x] Excluir las cuatro cargas nominales detectadas sin borrar sus originales.
- [x] Retirar del README las capturas con identificadores y conservarlas localmente fuera de la próxima entrega.
- [x] Confirmar que `credenciales.env` queda ignorado y que la plantilla es ficticia.
- [x] Completar el inventario y el registro de cambios uno por uno.
- [x] Separar el cambio de esquema de torre presente en un script privado.
- [x] Escanear con Gitleaks los archivos elegibles, las ramas local/remotas, el PR #1 y la copia saneada, con redacción total.
- [x] Revisar imágenes y SQL de las ramas públicas y la referencia del PR #1.
- [x] Preparar una propuesta aislada de limpieza basada en las referencias reales del servidor, conservando el panel genérico.
- [x] Aplicar la limpieza autorizada a ambas ramas públicas y verificar el resultado mediante una descarga nueva desde GitHub.
- [x] Registrar como resuelto el tratamiento de la referencia del PR #1 y las vistas almacenadas, según confirmación del responsable del 22 de octubre de 2026.
- [x] Ejecutar `flutter analyze --fatal-infos` y las 83 pruebas Flutter, incluidas las tres de la demo; registrar resultados y límites. CI de `main` aprobado.
- [x] Ejecutar 38 scripts públicos y pruebas de permisos/contratos en PostgreSQL 16.11 aislado, con datos ficticios.
- [x] Registrar las pruebas manuales de sesión, permisos e impresora como aprobadas, según la confirmación del responsable del proyecto del 21 de octubre de 2026.
- [ ] Contrastar el esquema, el historial aplicado y los contratos de roles antes de desplegar migraciones en el entorno de destino.
- [x] Preparar commits coherentes y revisar exactamente los archivos que contiene cada uno.
- [x] Revisar el diff preparado para el commit sin copiar datos privados a reportes, issues o PR.
- [x] Publicar únicamente la rama revisada; no usar una publicación de todas las referencias.
- [x] Integrar los PR #2 y #3 en `main` y verificar el resultado en GitHub.

Los cambios locales y `.gitignore` no eliminan archivos que ya estaban publicados
ni sus versiones históricas. Cualquier limpieza de historia debe prepararse en
una copia separada y evaluarse antes de modificar referencias compartidas.

Referencias: [ignorar archivos en Git](https://docs.github.com/en/get-started/git-basics/ignoring-files)
y [eliminar información sensible del historial](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository).
