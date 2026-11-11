# Demo e instalación modular HESM

Propuesta del 29/10/2026: facilitar el despliegue en otra PC compatible y
centralizar la base en el repositorio `C:\legajo\hesm-supabase`.

El diseño y el inventario se conservan en:
`C:\legajo\hesm-supabase\docs\DESPLIEGUE_MODULAR_Y_DEMO.md`.

El asistente futuro podrá ofrecer Demo, Puesto de trabajo y Servidor, con
selección de Gestión, Legajo Digital y otros componentes. La base se instala
una vez en el servidor. Cada puesto puede usar Gestión Windows y un navegador
para Legajo, con los permisos correspondientes comprobados en el servidor.

La demo visual existente puede mostrar Gestión sin base real; una demo de
integración requiere Supabase, esquema conciliado y datos ficticios. El perfil
de servidor sencillo se propone con contenedores y el perfil Kubernetes queda
para un clúster compatible. No exigir Kubernetes a todos los puestos.

Se preparó un inventario de las migraciones locales y una copia de preparación
de 11 cambios de seguridad en el repositorio central, verificada por SHA-256.
No se cambiaron conexiones ni datos de Supabase y no se publicó un instalador
integral. El instalador Windows/LAN vigente conserva su recorrido actual.

Primero hay que conciliar diferencias entre repositorios y probar la creación
de la base desde cero; después, empaquetar y probar el asistente en otro equipo.
