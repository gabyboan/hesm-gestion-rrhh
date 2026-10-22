# Entrega para GitHub

Preparada el 21 de octubre de 2026 en `release/gestion-rrhh-2026-10-21`.
Base pública limpia: `ecb7bfd61b0973f680b552b99a3ed909eacd256c`.

Los PR [#2](https://github.com/gabyboan/hesm-gestion-rrhh/pull/2) (cambios
funcionales) y [#3](https://github.com/gabyboan/hesm-gestion-rrhh/pull/3)
(demo y paquetes Windows) están integrados en `main` desde el 21 de octubre
de 2026. El responsable del proyecto confirmó ese día que las pruebas
manuales de sesión, permisos e impresora fueron realizadas y aprobadas.

La rama se armó en una copia aislada. Los commits nuevos utilizan el nombre
público de GitHub y un correo noreply para no exponer un correo personal. Las referencias, los archivos privados
y los cambios sin commit del repositorio de trabajo original se conservan.
No se fusionó el historial local anterior ni se desplegó la base de datos.

## Commits funcionales

| Commit | Cambio | Archivos |
| --- | --- | --- |
| [c355d4f](https://github.com/gabyboan/hesm-gestion-rrhh/commit/c355d4f2a0cf7b341f71085507af3949dc0fc72c) | chore: proteger archivos privados y automatizar calidad Flutter | 2 |
| [29cf3cc](https://github.com/gabyboan/hesm-gestion-rrhh/commit/29cf3cc6a39b8f1c5ca14df5e7f8570d998cfe3b) | db: publicar migraciones revisadas y contratos con datos ficticios | 64 |
| [a62cc9e](https://github.com/gabyboan/hesm-gestion-rrhh/commit/a62cc9ef7e00acea851b21d799e03ce6342b8e6c) | feat: unificar busquedas, conectividad e identidad visual | 15 |
| [7468901](https://github.com/gabyboan/hesm-gestion-rrhh/commit/74689013a0a500de72d9aeb5761f52245289036b) | feat: persistir preferencias y aislar la sesion de cada usuario | 12 |
| [c04690c](https://github.com/gabyboan/hesm-gestion-rrhh/commit/c04690cd8be4f86aadd5c0b3433d74b154400b85) | feat: mejorar consultas de horas y busquedas entre modulos | 11 |
| [3412a44](https://github.com/gabyboan/hesm-gestion-rrhh/commit/3412a44e41fc45c1bb6389e212e7d1a68719862d) | feat: ampliar partes medicos y gestionar impresion por lotes | 20 |

El commit de presentación que acompaña este documento agrega el README,
el registro de cambios, los informes, seis capturas ficticias y su generador.
Los resultados registrados corresponden al conjunto final; no se ejecutó una
suite separada en cada commit intermedio.

La entrega contiene **140 archivos: 110 nuevos y 30 modificados** frente a la
base pública limpia.

## Inventario y diferencias con la copia local

El [inventario por archivo](CAMBIOS_POR_ARCHIVO.md) describe los 108 cambios
locales comparados con `d045999`. Dos corresponden al retiro de capturas que
ya fueron eliminadas de la base pública limpia.

La comparación para este pull request parte de `ecb7bfd`, que no contenía SQL.
Por eso también se incorporan 24 migraciones antiguas sin cambios funcionales,
además de los 38 scripts nuevos o modificados del inventario local: **62
migraciones públicas y dos archivos de pruebas SQL**. No constituyen un esquema
completo instalable desde cero.

| Migración recuperada | Propósito |
| --- | --- |
| [20260530221000_fix_auth_role_mapping.sql](../supabase/migrations/20260530221000_fix_auth_role_mapping.sql) | Alinea los roles con el perfil y auth.uid(). |
| [20260530223000_restrict_suplencias_by_owner.sql](../supabase/migrations/20260530223000_restrict_suplencias_by_owner.sql) | Limita la lectura y eliminación de suplencias por propietario y roles administrativos. |
| [20260530224500_make_suplentes_view_security_invoker.sql](../supabase/migrations/20260530224500_make_suplentes_view_security_invoker.sql) | Hace que la vista de suplentes respete los permisos del usuario consultante. |
| [20260531091500_restrict_public_function_execute.sql](../supabase/migrations/20260531091500_restrict_public_function_execute.sql) | Restringe la ejecución anónima de funciones del esquema público. |
| [20260531100000_deprecate_unused_views.sql](../supabase/migrations/20260531100000_deprecate_unused_views.sql) | Renombra vistas antiguas sin eliminarlas. |
| [20260531103000_wrap_auth_uid_in_policies.sql](../supabase/migrations/20260531103000_wrap_auth_uid_in_policies.sql) | Envuelve auth.uid() en subconsultas de las políticas existentes. |
| [20260531110000_prune_redundant_select_policies.sql](../supabase/migrations/20260531110000_prune_redundant_select_policies.sql) | Elimina políticas SELECT redundantes según los permisos del esquema previo. |
| [20260531113000_drop_redundant_persona_carreras_indexes.sql](../supabase/migrations/20260531113000_drop_redundant_persona_carreras_indexes.sql) | Retira índices y restricciones redundantes de persona_carreras. |
| [20260531120000_add_legajo_to_personas.sql](../supabase/migrations/20260531120000_add_legajo_to_personas.sql) | Normaliza personas.legajo como atributo principal. |
| [20260601094000_separate_asistencia_legajo_permissions.sql](../supabase/migrations/20260601094000_separate_asistencia_legajo_permissions.sql) | Separa permisos de asistencia y legajo de los del banco de francos. |
| [20260601100000_deprecate_legacy_legajos_table.sql](../supabase/migrations/20260601100000_deprecate_legacy_legajos_table.sql) | Renombra la tabla antigua de legajos para conservar compatibilidad controlada. |
| [20260601221000_add_francos_saldo_inicial_rpcs.sql](../supabase/migrations/20260601221000_add_francos_saldo_inicial_rpcs.sql) | Agrega RPC para consultar y administrar el saldo inicial de francos. |
| [20260602021500_allow_legajo_roles_francos_saldo_inicial.sql](../supabase/migrations/20260602021500_allow_legajo_roles_francos_saldo_inicial.sql) | Permite a roles de legajo administrar el saldo inicial en esa versión histórica. |
| [20260602023500_require_francos_permissions_for_saldo_inicial.sql](../supabase/migrations/20260602023500_require_francos_permissions_for_saldo_inicial.sql) | Ajusta el paso anterior para exigir permisos específicos de Francos. |
| [20260603002000_revoke_anon_consulta_horas_public.sql](../supabase/migrations/20260603002000_revoke_anon_consulta_horas_public.sql) | Revoca la ejecución anónima de la consulta pública de horas. |
| [20260603010000_restrict_consulta_horas_to_service_role.sql](../supabase/migrations/20260603010000_restrict_consulta_horas_to_service_role.sql) | Reserva la consulta de horas a service_role desde el servidor. |
| [20260604091000_split_francos_carga_and_admin.sql](../supabase/migrations/20260604091000_split_francos_carga_and_admin.sql) | Separa carga y administración de Francos. |
| [20260604093500_allow_francos_admin_initial_positive.sql](../supabase/migrations/20260604093500_allow_francos_admin_initial_positive.sql) | Permite inicializar movimientos positivos con FRANCOS_ADM. |
| [20260604095500_require_francos_lectura_for_module.sql](../supabase/migrations/20260604095500_require_francos_lectura_for_module.sql) | Exige FRANCOS_LECTURA para entrar al módulo. |
| [20260604103000_enforce_francos_read_on_listado.sql](../supabase/migrations/20260604103000_enforce_francos_read_on_listado.sql) | Aplica el permiso de lectura a las RPC del listado y los movimientos. |
| [20260604104500_limit_francos_duration_steps.sql](../supabase/migrations/20260604104500_limit_francos_duration_steps.sql) | Limita la duración de movimientos de Francos a los pasos admitidos. |
| [20260608142000_add_imprevistos_roles.sql](../supabase/migrations/20260608142000_add_imprevistos_roles.sql) | Incorpora los roles del módulo Imprevistos. |
| [20260611100000_add_horario_rotativo.sql](../supabase/migrations/20260611100000_add_horario_rotativo.sql) | Agrega la representación de horario rotativo. |
| [20260611110000_add_feriados_agenda.sql](../supabase/migrations/20260611110000_add_feriados_agenda.sql) | Agrega la agenda de feriados y sus reglas de acceso. |

Estos 24 scripts se conservan como historia de esquema. Su presencia no afirma
que se haya reproducido toda la instalación antigua. La prueba PostgreSQL
ejecuta los 38 scripts del cambio sobre prerrequisitos sintéticos y valida
contratos concretos; el [informe de validación](VALIDACION.md) detalla el alcance.

## Archivos de presentación añadidos en esta etapa

| Archivo | Propósito |
| --- | --- |
| [docs/ENTREGA_GITHUB.md](ENTREGA_GITHUB.md) | Registra los commits y las diferencias con la base pública limpia. |
| [docs/mockups/README.md](mockups/README.md) | Reúne las capturas y explica cómo reproducirlas sin una sesión real. |
| [tool/generate_demo_gallery_test.dart](../tool/generate_demo_gallery_test.dart) | Renderiza los widgets con proveedores ficticios y bloquea el acceso a Supabase. |
| [tool/generate_demo_gallery.ps1](../tool/generate_demo_gallery.ps1) | Genera el PDF ficticio, rasteriza con Windows y ejecuta la captura. |
| [docs/mockups/demo/panel.png](mockups/demo/panel.png) | Panel de módulos y cuenta DEMO, a 1440 × 900. |
| [docs/mockups/demo/horas.png](mockups/demo/horas.png) | Consulta de horas y autoría ficticia, a 1440 × 900. |
| [docs/mockups/demo/francos.png](mockups/demo/francos.png) | Saldo y movimientos ficticios, a 1440 × 900. |
| [docs/mockups/demo/imprevistos.png](mockups/demo/imprevistos.png) | Cupos y registros ficticios, a 1440 × 900. |
| [docs/mockups/demo/medicos.png](mockups/demo/medicos.png) | Historial y vista del PDF ficticio, a 1440 × 900. |
| [docs/mockups/demo/suplencias.png](mockups/demo/suplencias.png) | Listado de suplencias ficticias, a 1440 × 900. |

El workflow fija Flutter **3.38.6**, la versión usada en las verificaciones,
y conserva el lockfile. Las diferencias exclusivas de saltos de línea se
descartaron para que la revisión muestre los cambios de contenido.

## Verificación y pendientes

- 80 pruebas Flutter aprobadas en la entrega funcional y tres adicionales en
  la etapa de demo: 83 aprobadas en total, también en CI de `main`.
- Galería completa generada y revisada visualmente; no se usaron credenciales.
- Análisis estático sin observaciones y Gitleaks sin hallazgos en el árbol revisado.
- 38 scripts SQL y contratos verificados previamente en PostgreSQL 16.11 aislado.
- Antes de desplegar: contrastar esquema, historial de migraciones y roles reales.
- Pruebas manuales de sesión, permisos e impresora aprobadas según la
  confirmación del responsable del proyecto del 21 de octubre de 2026.
- Tratamiento de la referencia antigua del PR #1 y sus vistas almacenadas resuelto, según confirmación del responsable del 22 de octubre de 2026.

Las cuatro cargas nominales, los archivos de credenciales, los respaldos y
las capturas privadas permanecen excluidos. Los SQL sueltos antiguos fuera de
`supabase/migrations/` y `supabase/tests/` tampoco forman parte de la entrega.
La ausencia de hallazgos automáticos no sustituye la revisión de datos personales.
