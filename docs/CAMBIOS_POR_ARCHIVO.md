# Cambios por archivo

Revisión: 21 de octubre de 2026. Comparación de los archivos existentes contra
`d045999`; los archivos nuevos se revisan completos. Este inventario describe
**108 archivos: 37 modificados, 2 retirados y 69 nuevos**, incluida la
documentación de preparación. No incluye las cuatro migraciones nominales
ignoradas ni las copias privadas de capturas.

El [registro de cambios](../CHANGELOG.md) explica el comportamiento por tema.
[Validación](VALIDACION.md) distingue las verificaciones ejecutadas de las
pendientes. «Revisado» significa inspección del código; no implica que una
migración haya sido aplicada o que una función remota haya sido probada.

## Privacidad, documentación y recursos · 9 archivos

| Archivo | Estado | Cambio y propósito |
| --- | --- | --- |
| [.gitignore](../.gitignore) | Modificado | Ignora distribución y respaldos locales, secretos, claves privadas, sesiones, exportaciones, capturas privadas y las cuatro migraciones con datos nominales; conserva las excepciones de ejemplos, migraciones públicas y pruebas SQL. |
| [README.md](../README.md) | Modificado | Actualiza capacidades, acceso a documentación y verificación local; retira la afirmación de anonimización de las capturas con identificadores. |
| [CHANGELOG.md](../CHANGELOG.md) | Nuevo | Explica doce grupos de cambios con comportamiento, dependencias y límites de validación; no declara una versión desplegada. |
| [docs/PREPARACION_GITHUB.md](PREPARACION_GITHUB.md) | Nuevo | Registra privacidad, etapas, archivos excluidos y comprobaciones pendientes antes de publicar. |
| [docs/CAMBIOS_POR_ARCHIVO.md](CAMBIOS_POR_ARCHIVO.md) | Nuevo | Relaciona cada archivo de la entrega con su propósito y propone commits según sus dependencias. |
| [docs/VALIDACION.md](VALIDACION.md) | Nuevo | Documenta el entorno, 80 pruebas aprobadas, análisis sin observaciones, 38 migraciones probadas en una base sintética y verificaciones pendientes. |
| `docs/mockups/modulo-francos.png` | Retirado | Se retira de la entrega por contener identificadores; el original permanece en la carpeta privada ignorada. La historia todavía debe revisarse. |
| `docs/mockups/modulo-imprevistos.png` | Retirado | Se retira por el mismo criterio de privacidad, sin eliminar la copia local de revisión. |
| [assets/parte_medico_digitalizado.jpg](../assets/parte_medico_digitalizado.jpg) | Nuevo | Formulario médico vacío utilizado como fondo de la vista previa; no se usa como fondo en la impresión sobre preimpreso. |

## Aplicación, conectividad, sesión y preferencias · 13 archivos

| Archivo | Estado | Cambio y dependencia |
| --- | --- | --- |
| [lib/app/app.dart](../lib/app/app.dart) | Modificado | Envuelve el acceso en `InternetConnectionGate` y conecta la pérdida/recuperación de internet con la pausa/reanudación del temporizador. |
| [lib/app/theme/theme_mode_provider.dart](../lib/app/theme/theme_mode_provider.dart) | Modificado | Usa tema oscuro como estado inicial, luego sustituido por la preferencia del usuario. |
| [lib/core/network/internet_connection_gate.dart](../lib/core/network/internet_connection_gate.dart) | Nuevo | Define un monitor inyectable, escucha conectividad y ciclo de vida, y bloquea interacción y foco mientras muestra la espera. Requiere la dependencia de conectividad. |
| [lib/core/utils/search_query.dart](../lib/core/utils/search_query.dart) | Nuevo | Normaliza consultas y comprueba que todos sus términos aparezcan entre los campos de una persona o registro. |
| [lib/core/widgets/app_search_field.dart](../lib/core/widgets/app_search_field.dart) | Nuevo | Centraliza campo, temporizador de 300 ms, Enter y limpieza inmediata; permite desactivar la espera para listas locales. |
| [lib/features/auth/application/session_timeout_service.dart](../lib/features/auth/application/session_timeout_service.dart) | Modificado | Configura el límite entre 1 y 10 minutos y agrega pausa/reanudación para desconexiones, conservando la marca local de actividad. |
| [lib/features/auth/presentation/auth_gate.dart](../lib/features/auth/presentation/auth_gate.dart) | Modificado | Recarga perfil y preferencias, aplica tema/límite y crea un ámbito de providers para que la bandeja de impresión no sobreviva al cambio de sesión. |
| [lib/features/preferences/application/user_preferences_providers.dart](../lib/features/preferences/application/user_preferences_providers.dart) | Nuevo | Expone perfil, preferencias y controlador de guardado; aplica cambios locales después del guardado remoto. |
| [lib/features/preferences/data/user_preferences_repository.dart](../lib/features/preferences/data/user_preferences_repository.dart) | Nuevo | Lee y actualiza `usuario_preferencias` y consulta `rpc_mi_perfil`; requiere la migración de preferencias. |
| [lib/features/preferences/domain/current_user_profile.dart](../lib/features/preferences/domain/current_user_profile.dart) | Nuevo | Convierte el perfil y construye el saludo con apellido y primer nombre, normalizando espacios. |
| [lib/features/preferences/domain/user_preferences.dart](../lib/features/preferences/domain/user_preferences.dart) | Nuevo | Define tema, límites, valores predeterminados y conversión del formato SQL; normaliza valores fuera de rango. |
| [lib/features/preferences/presentation/user_preferences_dialog.dart](../lib/features/preferences/presentation/user_preferences_dialog.dart) | Nuevo | Ofrece selección de tema e inactividad con estados de carga, guardado y error. |
| [lib/features/shell/presentation/main_shell.dart](../lib/features/shell/presentation/main_shell.dart) | Modificado | Agrega configuración y saludo al panel de módulos utilizando los providers de preferencias. |

## Horas · 6 archivos

| Archivo | Estado | Cambio y dependencia |
| --- | --- | --- |
| [lib/features/horas/application/horas_providers.dart](../lib/features/horas/application/horas_providers.dart) | Modificado | Sustituye coincidencias por campo aislado por `SearchQuery` en el filtro de registros. |
| [lib/features/horas/data/horas_repository.dart](../lib/features/horas/data/horas_repository.dart) | Modificado | Usa la RPC de personal activo y completa autoría filtrando solo UUID de autores necesarios; conserva registros ante denegación de perfiles y no interpola identificadores inválidos. |
| [lib/features/horas/domain/hora_registro.dart](../lib/features/horas/domain/hora_registro.dart) | Modificado | Incorpora fecha de creación e identificadores/nombres del usuario de carga, incluidos conversión, copia y etiqueta legible. |
| [lib/features/horas/presentation/cargar/widgets/cargar_horas_widgets.dart](../lib/features/horas/presentation/cargar/widgets/cargar_horas_widgets.dart) | Modificado | Usa búsqueda compartida y filtrado local inmediato por DNI, nombre y carrera en el selector de carga. |
| [lib/features/horas/presentation/ver/ver_horas_page.dart](../lib/features/horas/presentation/ver/ver_horas_page.dart) | Modificado | Calcula elegibilidad de horas oficiales con el listado recibido y la transmite al resumen. |
| [lib/features/horas/presentation/ver/widgets/ver_horas_widgets.dart](../lib/features/horas/presentation/ver/widgets/ver_horas_widgets.dart) | Modificado | Adapta el resumen a esa elegibilidad, muestra autoría y fecha de carga cuando existen y unifica la búsqueda del selector. |

## Francos, Imprevistos y Suplencias · 4 archivos

| Archivo | Estado | Cambio y dependencia |
| --- | --- | --- |
| [lib/features/francos/presentation/francos_page.dart](../lib/features/francos/presentation/francos_page.dart) | Modificado | Sustituye el buscador propio por `AppSearchField` y conserva la consulta del provider como valor inicial. |
| [lib/features/imprevistos/presentation/imprevistos_page.dart](../lib/features/imprevistos/presentation/imprevistos_page.dart) | Modificado | Reutiliza el buscador compartido junto al selector de año. |
| [lib/features/suplencias/data/suplencias_repository.dart](../lib/features/suplencias/data/suplencias_repository.dart) | Modificado | Reemplaza filtros PostgREST construidos en el cliente por la RPC de listado; mantiene ordenación y límite de 5.000 resultados. |
| [lib/features/suplencias/presentation/suplencias_page.dart](../lib/features/suplencias/presentation/suplencias_page.dart) | Modificado | Unifica el buscador y agrega identificadores de solicitud para evitar que una respuesta vieja reemplace a la búsqueda más reciente. |

## Médicos · 12 archivos

| Archivo | Estado | Cambio y dependencia |
| --- | --- | --- |
| [lib/features/medicos/application/medicos_providers.dart](../lib/features/medicos/application/medicos_providers.dart) | Modificado | Separa búsquedas de personas y partes; consulta domicilio según permisos y amplía los datos del formulario con fecha, familiar, ART y aclaración. |
| [lib/features/medicos/data/ajuste_impresion_medica_repository.dart](../lib/features/medicos/data/ajuste_impresion_medica_repository.dart) | Nuevo | Persiste calibración JSON en `SharedPreferences`, valida antes de guardar e informa si falla la persistencia. |
| [lib/features/medicos/data/medicos_repository.dart](../lib/features/medicos/data/medicos_repository.dart) | Modificado | Consulta domicilio y envía familiar, ART, aclaración y meses de edad; omite el parámetro de meses cuando es nulo para conservar compatibilidad con la firma anterior. |
| [lib/features/medicos/data/parte_medico_printer.dart](../lib/features/medicos/data/parte_medico_printer.dart) | Modificado | Genera vistas y PDF para uno o varios partes; utiliza fuente uniforme, calibración y datos familiares, torre y meses; evita repetir el número de domicilio en otros campos. |
| [lib/features/medicos/domain/ajuste_impresion_medica.dart](../lib/features/medicos/domain/ajuste_impresion_medica.dart) | Nuevo | Define ambos ejes en mm, límites de ±10 y conversión JSON con rechazo de valores no finitos o inválidos. |
| [lib/features/medicos/domain/medico_domicilio.dart](../lib/features/medicos/domain/medico_domicilio.dart) | Nuevo | Modela domicilio y detecta domicilio vacío o localidad externa; torre se alinea con la nueva RPC y se imprime en otros datos. |
| [lib/features/medicos/domain/medico_persona.dart](../lib/features/medicos/domain/medico_persona.dart) | Modificado | Permite legajo nulo y construye una etiqueta sin inventar un número. |
| [lib/features/medicos/domain/parte_medico.dart](../lib/features/medicos/domain/parte_medico.dart) | Modificado | Agrega códigos AD/PC/AC, legajo opcional, familiar, edad en meses, ART, domicilio y aclaración; construye descripciones y textos de impresión. |
| [lib/features/medicos/presentation/ajuste_impresion_medica_dialog.dart](../lib/features/medicos/presentation/ajuste_impresion_medica_dialog.dart) | Nuevo | Edita calibración con coma decimal y pasos de 0,1 mm; permite probar, guardar y restablecer sin registrar un parte de prueba. |
| [lib/features/medicos/presentation/medicos_page.dart](../lib/features/medicos/presentation/medicos_page.dart) | Modificado | Agrega pestañas, vistas, ART, familiar y edad en meses; permite registrar para imprimir después, preserva cancelaciones en bandeja y advierte sobre texto largo recortado. |
| [lib/features/medicos/presentation/parte_medico_vista_ampliada.dart](../lib/features/medicos/presentation/parte_medico_vista_ampliada.dart) | Nuevo | Rasteriza la primera página de la vista a 180 dpi y permite zoom y desplazamiento con reintento ante errores. |
| [lib/features/medicos/presentation/parte_medico_vista_panel.dart](../lib/features/medicos/presentation/parte_medico_vista_panel.dart) | Nuevo | Muestra el parte seleccionado o una persona sin registrar; consulta domicilio y ofrece ampliación con estados de carga y error. |

## Dependencias · 2 archivos

| Archivo | Estado | Cambio y propósito |
| --- | --- | --- |
| [pubspec.yaml](../pubspec.yaml) | Modificado | Declara `internet_connection_checker_plus: ^3.1.1` y registra la imagen del formulario vacío como asset. |
| [pubspec.lock](../pubspec.lock) | Modificado | Fija `internet_connection_checker_plus` en 3.1.1 con la integridad del paquete resuelto. |

## Migraciones existentes modificadas · 7 archivos

Todas las rutas de esta tabla pertenecen a `supabase/migrations/`. Los cambios
se compararon contra la versión anterior sin reproducir datos personales en
este documento. Los ajustes de formato no se presentan como cambios de permisos.

| Archivo | Estado | Diferencia real |
| --- | --- | --- |
| [20260608135000_imprevistos.sql](../supabase/migrations/20260608135000_imprevistos.sql) | Modificado | Retira `numero_orden` de la definición inicial y de las firmas originales; esa incorporación corresponde a la migración posterior de junio. Requiere probar la secuencia. |
| [20260608141000_align_imprevistos_permissions.sql](../supabase/migrations/20260608141000_align_imprevistos_permissions.sql) | Modificado | Alinea los `GRANT` con las firmas iniciales sin el parámetro de número de orden. |
| [20260612120000_partes_medicos.sql](../supabase/migrations/20260612120000_partes_medicos.sql) | Modificado | Elimina líneas vacías; no modifica sentencias ni permisos. |
| [20260622081000_add_numero_orden_to_imprevistos.sql](../supabase/migrations/20260622081000_add_numero_orden_to_imprevistos.sql) | Modificado | Elimina líneas vacías; conserva la incorporación posterior del número de orden y sus RPC. |
| [20260706124329_add_persona_familiares.sql](../supabase/migrations/20260706124329_add_persona_familiares.sql) | Modificado | Elimina líneas vacías; no altera la tabla, las políticas ni las funciones. |
| [20260706130627_harden_persona_familiares_rpc.sql](../supabase/migrations/20260706130627_harden_persona_familiares_rpc.sql) | Modificado | Elimina líneas vacías; conserva el cambio previo a `SECURITY INVOKER`. |
| [20260707135049_add_suplencias_module_permissions.sql](../supabase/migrations/20260707135049_add_suplencias_module_permissions.sql) | Modificado | Elimina líneas vacías; mantiene permisos y configuración de la vista. |

## Migraciones nuevas · 29 archivos

Se documenta cada paso en orden de nombre de archivo. Algunas funciones se
reemplazan varias veces: el estado final depende de las migraciones posteriores.
Las cuatro cargas privadas no están incluidas en esta tabla ni deben agregarse
para completar la secuencia pública.

| Archivo | Estado | Cambio y dependencia |
| --- | --- | --- |
| [20260713130529_persona_guardar_atomico.sql](../supabase/migrations/20260713130529_persona_guardar_atomico.sql) | Nuevo | Ajusta catálogos de carrera/situación y crea `rpc_persona_guardar` con escritura atómica de persona y relaciones, autenticación y permiso de edición de legajos. |
| [20260713151449_permitir_todas_situaciones_revista.sql](../supabase/migrations/20260713151449_permitir_todas_situaciones_revista.sql) | Nuevo | Reemplaza la validación restringida del guardado para admitir cualquier situación existente en el catálogo. |
| [20260714131936_ampliar_datos_ficha_persona.sql](../supabase/migrations/20260714131936_ampliar_datos_ficha_persona.sql) | Nuevo | Agrega campos de identificación, contacto, formación y empleo a `personas`. Algunos se normalizan o retiran en los siguientes pasos. |
| [20260714133020_quitar_campos_ficha_no_definidos.sql](../supabase/migrations/20260714133020_quitar_campos_ficha_no_definidos.sql) | Nuevo | Retira `tipo_reemplazo` y `disciplina` al no formar parte del modelo acordado. |
| [20260714133752_normalizar_datos_identificacion_y_sexo.sql](../supabase/migrations/20260714133752_normalizar_datos_identificacion_y_sexo.sql) | Nuevo | Crea catálogo `sexos`, transforma identificadores a tipos numéricos y agrega referencias y restricciones. |
| [20260714135426_agregar_historial_laboral_personas.sql](../supabase/migrations/20260714135426_agregar_historial_laboral_personas.sql) | Nuevo | Crea historial laboral con origen, índice y RLS para edición de legajos. |
| [20260714143201_agregar_domicilios_persona_georef.sql](../supabase/migrations/20260714143201_agregar_domicilios_persona_georef.sql) | Nuevo | Sustituye el domicilio de texto por domicilios estructurados con vigencia, índice único para el vigente y RLS. |
| [20260714150203_ampliar_guardado_ficha_y_domicilio.sql](../supabase/migrations/20260714150203_ampliar_guardado_ficha_y_domicilio.sql) | Nuevo | Reemplaza el guardado por una firma ampliada y versiona el domicilio cuando cambia; requiere ficha, catálogos y tabla de domicilios. |
| [20260716101926_periodos_inactividad_y_bloqueo_licencias.sql](../supabase/migrations/20260716101926_periodos_inactividad_y_bloqueo_licencias.sql) | Nuevo | Agrega períodos, preserva las bajas existentes, crea RPC de baja/reactivación y bloquea partes en períodos inactivos; redefine el listado médico. |
| [20260722125352_optimize_banco_horas_list.sql](../supabase/migrations/20260722125352_optimize_banco_horas_list.sql) | Nuevo | Contiene solamente `;`. No modifica el esquema ni implementa la optimización sugerida por el nombre. |
| [20260730145901_consulta_horas_beneficios_publicos.sql](../supabase/migrations/20260730145901_consulta_horas_beneficios_publicos.sql) | Nuevo | Expone una RPC de saldos reducidos de francos e imprevistos, ejecutable únicamente por `service_role`; requiere las tablas de movimientos y registros. |
| [20260730153108_consulta_horas_carreras_preliminar.sql](../supabase/migrations/20260730153108_consulta_horas_carreras_preliminar.sql) | Nuevo | Devuelve una carrera habilitada y nombre desde una RPC restringida a `service_role`; no incluye el servicio externo consumidor. |
| [20260826131746_usuario_preferencias.sql](../supabase/migrations/20260826131746_usuario_preferencias.sql) | Nuevo | Crea preferencias con límites, RLS por usuario y RPC de perfil propio mediante función privada. Requiere la relación de usuarios con Auth. |
| [20260901104621_add_familiar_fallecido.sql](../supabase/migrations/20260901104621_add_familiar_fallecido.sql) | Nuevo | Agrega `fallecido` con valor inicial falso a `persona_familiares`. |
| [20260903110623_incluir_personal_activo_en_horas_oficiales.sql](../supabase/migrations/20260903110623_incluir_personal_activo_en_horas_oficiales.sql) | Nuevo | Crea `rpc_listado_horas_oficiales_activas` con autenticación, permiso de carga y exclusión de bajas vigentes, conservando la RPC histórica. |
| [20260903114942_remover_restriccion_fija_carreras_horas.sql](../supabase/migrations/20260903114942_remover_restriccion_fija_carreras_horas.sql) | Nuevo | Reemplaza la restricción de carreras de `horas_registros` para permitir otras carreras en modalidad oficial. |
| [20260904124155_add_persona_dni_validaciones.sql](../supabase/migrations/20260904124155_add_persona_dni_validaciones.sql) | Nuevo | Registra primera confirmación manual de DNI con usuario y fecha; limita lectura y RPC a usuarios autorizados. |
| [20260904133603_fix_persona_dni_validacion_rpc.sql](../supabase/migrations/20260904133603_fix_persona_dni_validacion_rpc.sql) | Nuevo | Resuelve el conflicto de nombres en `ON CONFLICT` indicando explícitamente la restricción primaria. |
| [20260904141531_validar_dni_guardar_cuit.sql](../supabase/migrations/20260904141531_validar_dni_guardar_cuit.sql) | Nuevo | Incorpora RPC de confirmación con CUIT/CUIL y comprobación de correspondencia de sus dígitos con el DNI. |
| [20260904143056_corregir_orden_validacion_cuit.sql](../supabase/migrations/20260904143056_corregir_orden_validacion_cuit.sql) | Nuevo | Agrega cálculo del dígito verificador y evita volver a sobrescribir el dato cuando ya existe confirmación. La implementación se corrige en el paso siguiente. |
| [20260904143446_corregir_tipo_posicion_cuit.sql](../supabase/migrations/20260904143446_corregir_tipo_posicion_cuit.sql) | Nuevo | Sustituye posiciones de `WITH ORDINALITY` por posiciones literales para el cálculo del verificador y evita el problema de tipos. |
| [20260907113237_modulo_validador_familiares.sql](../supabase/migrations/20260907113237_modulo_validador_familiares.sql) | Nuevo | Rechaza discrepancias de CUIT/CUIL ya cargado y agrega campos de validación familiar y trigger que invalida datos modificados. |
| [20261008081800_partes_medicos_art.sql](../supabase/migrations/20261008081800_partes_medicos_art.sql) | Nuevo | Agrega ART y DNI familiar, restricciones y nuevas firmas de creación/listado; rechaza ART en partes familiares. |
| [20261008084500_add_casa_persona_domicilios.sql](../supabase/migrations/20261008084500_add_casa_persona_domicilios.sql) | Nuevo | Incorpora el campo `casa` a los domicilios estructurados. |
| [20261008095000_rpc_medicos_domicilio.sql](../supabase/migrations/20261008095000_rpc_medicos_domicilio.sql) | Nuevo | Devuelve el domicilio vigente con autorización médica; incluye casa y omite torre en el contrato actual. |
| [20261008104600_partes_medicos_aclaracion_turno.sql](../supabase/migrations/20261008104600_partes_medicos_aclaracion_turno.sql) | Nuevo | Agrega columna y parámetro de aclaración, inicialmente limitado a 30 caracteres, y reemplaza las RPC correspondientes. |
| [20261014122055_partes_medicos_aclaracion_90.sql](../supabase/migrations/20261014122055_partes_medicos_aclaracion_90.sql) | Nuevo | Amplía a 90 caracteres la validación de la RPC de emisión. |
| [20261016101850_medicos_incluir_personas_sin_legajo.sql](../supabase/migrations/20261016101850_medicos_incluir_personas_sin_legajo.sql) | Nuevo | Permite `empleado_legajo` nulo e incorpora personas activas sin legajo en selección y creación; conserva validaciones de permisos, ART y familiar. |
| [20261016105121_mejorar_buscadores.sql](../supabase/migrations/20261016105121_mejorar_buscadores.sql) | Nuevo | Crea normalización y coincidencia por términos; reemplaza los listados de Francos, Imprevistos y Médicos y agrega el listado RPC de Suplencias con `SECURITY INVOKER`. |

## Pruebas nuevas o ampliadas · 9 archivos

La prueba SQL se lista aparte de las ocho pruebas Dart de la revisión inicial. Otros
tres archivos Dart existentes, sin cambios, también forman parte de las 52
pruebas ejecutadas y están detallados en el informe de validación.

| Archivo | Estado | Verificación y resultado |
| --- | --- | --- |
| [supabase/tests/medicos_sin_legajo.sql](../supabase/tests/medicos_sin_legajo.sql) | Nuevo | Comprueba cuatro modalidades, edad en meses, búsqueda, legajo opcional y permisos con la firma actual de nueve parámetros. Aprobado en base aislada, con `rollback`. |
| [test/core/network/internet_connection_gate_test.dart](../test/core/network/internet_connection_gate_test.dart) | Nuevo | Simula caída y regreso de conexión; confirma bloqueo y recuperación de interacción. Aprobado. |
| [test/core/utils/search_query_test.dart](../test/core/utils/search_query_test.dart) | Nuevo | Comprueba términos, acentos, formatos de documento, separadores y consulta vacía. Aprobado. |
| [test/features/medicos/ajuste_impresion_medica_test.dart](../test/features/medicos/ajuste_impresion_medica_test.dart) | Nuevo | Prueba persistencia simulada, validación y acciones del diálogo de calibración. Aprobado. |
| [test/features/medicos/medico_persona_test.dart](../test/features/medicos/medico_persona_test.dart) | Nuevo | Prueba legajo opcional y etiquetas de personas con y sin legajo. Aprobado. |
| [test/features/medicos/medicos_vista_preliminar_test.dart](../test/features/medicos/medicos_vista_preliminar_test.dart) | Nuevo | Prueba selección, disposición, ampliación, búsquedas y flujos de registro/bandeja, incluidas cancelaciones. Aprobado. |
| [test/features/medicos/parte_medico_printer_test.dart](../test/features/medicos/parte_medico_printer_test.dart) | Modificado | Verifica PDF individuales y lotes, orden, edad en meses, fuente uniforme, torre y duplicación de domicilio; separa extracción de texto e inspección de operadores PDF. Aprobado; no prueba papel físico. |
| [test/features/medicos/parte_medico_test.dart](../test/features/medicos/parte_medico_test.dart) | Nuevo | Prueba modalidades, ART, familiar, aclaraciones, domicilio y partes con legajo nulo. Aprobado. |
| [test/features/preferences/domain/user_preferences_test.dart](../test/features/preferences/domain/user_preferences_test.dart) | Nuevo | Prueba normalización de tema/inactividad y saludo del perfil. Aprobado; no prueba persistencia remota. |

## Orden propuesto inicialmente para los commits

Estos grupos se propusieron antes de la entrega, sujetos a la revisión de
privacidad y de esquema. El cierre de privacidad quedó confirmado el 22 de
octubre de 2026. Los commits funcionales se prepararon en una copia aislada. El orden usado
y el inventario contra `ecb7bfd` están en [Entrega GitHub](ENTREGA_GITHUB.md). No hay que mezclar
cargas nominales con los SQL públicos ni publicar checkpoints locales.

| Orden | Mensaje propuesto | Contenido y condición |
| --- | --- | --- |
| 1 | `docs: documentar cambios y proteger datos privados` | Documentación, README, `.gitignore` y retiro de las dos capturas. Su historial necesita tratamiento aparte. |
| 2 | `fix(db): alinear migraciones iniciales de imprevistos` | Los dos cambios funcionales de las migraciones antiguas; verificar la reproducción antes de incluirlos. |
| 3 | `feat(db): incorporar ficha, preferencias y nuevas RPC` | Las 31 migraciones públicas nuevas, incluida torre sin datos nominales y edad en meses; conservar la reserva sin efecto como tal. Se conserva su orden temporal. |
| 4 | `feat(app): agregar conectividad, preferencias y busqueda compartida` | Aplicación, Auth, Shell, identidad visual, preferencias y utilidades; dependencias, recurso del formulario y pruebas correspondientes. El recurso se registra junto con `pubspec.yaml` para no romper la compilación. |
| 5 | `feat(horas): ampliar elegibilidad y unificar consultas` | Horas, su prueba HTTP y las vistas de Francos, Imprevistos y Suplencias. Dependen del buscador compartido y de las RPC del grupo de base. |
| 6 | `feat(medicos): ampliar partes, vistas e impresion` | Médicos, bandeja, edad en meses y pruebas Dart/SQL correspondientes. Requiere los assets, preferencias locales y migraciones anteriores. |
| 7 | `style(sql): normalizar espaciado de migraciones` | Los cinco archivos antiguos con cambios exclusivamente de líneas vacías, si se decide conservar esos ajustes. Sin atribuirles cambios de seguridad. |

Antes de cerrar cada commit se revisan sus archivos preparados y se comprueba
que no introduzca imports sin sus archivos, assets sin registrar o firmas RPC
incompatibles. Los resultados de pruebas registrados corresponden al árbol
completo; aún no se verificó cada uno de estos commits intermedios.

## Actualizaciones integradas en la revisión · 17 archivos

Estos archivos se incorporaron o cambiaron durante la preparación. Se incluyen
en el total de 108, además de los 91 de la revisión inicial. La propuesta de
limpieza del historial remoto ya se publicó por separado y precede a la entrega
funcional; no se debe fusionar sobre ella la historia local anterior.

| Archivo | Estado | Cambio y verificación |
| --- | --- | --- |
| [.github/workflows/quality.yml](../.github/workflows/quality.yml) | Nuevo | Configura análisis con infos fatales y pruebas en push/PR a main, permisos de lectura y uso del lockfile. Usa Flutter 3.38.6, la versión validada localmente. |
| [docs/REVISION_PRIVACIDAD.md](REVISION_PRIVACIDAD.md) | Nuevo | Documenta escaneos, limpieza publicada de ambas ramas, verificación independiente y cierre del tratamiento del PR #1 confirmado el 22 de octubre de 2026. |
| [docs/branding/hesm-logo.svg](branding/hesm-logo.svg) | Nuevo | Recurso vectorial de identidad HESM; no contiene registros de personal. |
| [lib/main.dart](../lib/main.dart) | Modificado | Muestra el splash de identidad durante la inicialización, con duración mínima de cinco segundos cuando el inicio es correcto. |
| [lib/core/ui/app_snackbar.dart](../lib/core/ui/app_snackbar.dart) | Modificado | Limita la opacidad animada a 0–1 para evitar valores fuera de rango durante la curva elástica. |
| [lib/core/widgets/startup_splash.dart](../lib/core/widgets/startup_splash.dart) | Nuevo | Dibuja el logo y el engranaje animado, muestra progreso y considera la preferencia de reducción de animación. |
| [lib/features/auth/presentation/login_page.dart](../lib/features/auth/presentation/login_page.dart) | Modificado | Actualiza la presentación del acceso y la identidad visual, conservando el inicio de sesión y sus estados. |
| [lib/features/medicos/application/cola_impresion_provider.dart](../lib/features/medicos/application/cola_impresion_provider.dart) | Nuevo | Mantiene la bandeja en memoria, reemplaza duplicados por ID y permite retirar uno o varios partes; su ámbito en AuthGate limita su vida a la sesión. |
| [lib/features/medicos/presentation/cola_impresion_dialog.dart](../lib/features/medicos/presentation/cola_impresion_dialog.dart) | Nuevo | Permite revisar, quitar e imprimir uno o todos; conserva los partes cuando se cancela o falla la impresión. |
| [windows/runner/resources/app_icon.ico](../windows/runner/resources/app_icon.ico) | Modificado | Actualiza el icono de la aplicación Windows. No se generó un nuevo instalador en esta revisión. |
| [20261020132130_separar_torre_domicilio_publico.sql](../supabase/migrations/20261020132130_separar_torre_domicilio_publico.sql) | Nuevo | Separa la columna torre de las cargas privadas y amplía el contrato de domicilio mediante envoltorio invoker y función privada autorizada. Aprobado en PostgreSQL local. |
| [20261020150000_partes_medicos_edad_en_meses.sql](../supabase/migrations/20261020150000_partes_medicos_edad_en_meses.sql) | Nuevo | Agrega edad de 0–11 meses para familiares menores de un año, restricciones y nuevas firmas de creación/listado. Aprobado en la secuencia de prueba. |
| [supabase/tests/publicacion_contratos.sql](../supabase/tests/publicacion_contratos.sql) | Nuevo | Construye una base sintética protegida por comprobaciones de destino; ejecuta 38 scripts públicos y prueba preferencias, búsqueda, permisos, torre, horas y la prueba médica. Aprobado. |
| [test/core/widgets/startup_splash_test.dart](../test/core/widgets/startup_splash_test.dart) | Nuevo | Comprueba identidad, progreso y animación sin excepciones. Aprobado. |
| [test/features/horas/horas_repository_test.dart](../test/features/horas/horas_repository_test.dart) | Nuevo | Cinco casos HTTP locales verifican denegación de perfiles, filtros UUID, datos ya completos, identificadores inválidos y propagación de otros errores. Aprobado. |
| [test/features/medicos/cola_impresion_test.dart](../test/features/medicos/cola_impresion_test.dart) | Nuevo | Cinco casos prueban lote, cancelación, fallo, impresión individual y retiro de la bandeja. Aprobado. |
| [test/features/medicos/medicos_repository_test.dart](../test/features/medicos/medicos_repository_test.dart) | Nuevo | Cuatro casos HTTP locales verifican compatibilidad de firmas, años/meses y errores de permisos sin repetir el guardado. Aprobado. |
