# Revisión de privacidad y limpieza del historial

Revisión actualizada: 21 de octubre de 2026. Estado: **limpieza de ambas ramas
publicada y verificada**. La referencia del PR #1 y las vistas almacenadas
siguen pendientes de tratamiento con GitHub.

## Qué se comprobó

| Ámbito | Resultado | Límite |
| --- | --- | --- |
| Archivos locales elegibles | Gitleaks 8.30.1 sin hallazgos, incluido el escaneo final después de actualizar los seis documentos. | Se excluyeron credenciales, respaldos y cargas nominales. El resultado no sustituye la revisión de datos personales. |
| Historia de la rama local | 23 commits; Gitleaks sin hallazgos. | Los checkpoints locales se mantienen fuera de la publicación. |
| Ramas públicas de GitHub | `main` y `agent/suplencias-permisos-mockups` se actualizaron de la historia revisada en `b65bb9a` a `ecb7bfd`. Una descarga nueva confirmó ambos destinos, 24 commits y Gitleaks sin hallazgos. | El HEAD local `d045999` conserva la historia anterior; no debe fusionarse sobre las ramas saneadas. |
| SQL en esas ramas remotas | No se encontraron archivos SQL en los objetos alcanzables desde esas dos ramas revisadas. | El PR conserva su propia historia, que se inspeccionó aparte. La entrega incorpora 62 migraciones públicas revisadas para publicación; las cuatro cargas nominales siguen excluidas. |
| Imágenes históricas | Se detectaron diez versiones en la historia anterior. Tras publicar la limpieza, la descarga nueva conserva únicamente la versión del panel genérico revisado. | La comprobación se refiere a la historia alcanzable desde las dos ramas; PR, cachés, forks y clones pueden conservar objetos anteriores. |
| PR #1 | Está fusionado y conserva una referencia propia: 21 commits, dos versiones de capturas y una con patrones de documentos; Gitleaks sin hallazgos. | Actualizar las ramas no elimina esa referencia administrada por GitHub. |
| Historia saneada publicada | Nueve versiones históricas de imágenes dejaron de ser alcanzables desde las dos ramas públicas actualizadas. El panel genérico se conserva. | La referencia del PR #1 sigue presente; la publicación no elimina por sí sola vistas almacenadas ni copias ajenas. |

Gitleaks se descargó de su distribución oficial y se verificó el SHA-256 contra
los checksums publicados. Todos los escaneos se ejecutaron con redacción total
de secretos. Los informes públicos no contienen valores de credenciales,
documentos, domicilios, correos del personal ni texto extraído de las capturas.
El OCR se ejecutó localmente; las imágenes no se enviaron a un servicio externo.

## Archivos privados conservados localmente

Siguen ignorados `credenciales.env`, las cuatro migraciones nominales ya
identificadas, las capturas originales en `docs/mockups/private/` y los
respaldos. No se borraron sus originales. La columna `torre`, antes mezclada
con domicilios reales, tiene ahora una migración pública independiente:
`20261020132130_separar_torre_domicilio_publico.sql`.

## Limpieza aplicada a GitHub

Se preparó una copia independiente basada en las ramas que realmente estaban
publicadas, sin importar las referencias de agentes del repositorio local. La
copia está en `build/publication-validation/remote-clean.git`, ignorada por Git
y sin un remoto configurado.

El commit de cierre publicado es `ecb7bfd`. Reescribe la historia de
`docs/mockups/`, retira las dos capturas actuales con identificadores y vuelve
a incorporar únicamente el panel genérico inspeccionado. Respecto del árbol
del servidor anterior a la limpieza, la diferencia final se limita a:

- `README.md`: retira las referencias a las capturas y la afirmación de anonimización.
- `docs/mockups/modulo-francos.png`: se retira.
- `docs/mockups/modulo-imprevistos.png`: se retira.

El panel y el resto del código del servidor se conservan. Esta limpieza no
publica todavía las funciones nuevas del árbol de trabajo. Las dos ramas
públicas apuntan al mismo resultado saneado.

La actualización autorizada se ejecutó de forma atómica, con una condición
`--force-with-lease` explícita por rama que exigía conservar el estado remoto
revisado. Luego se clonó de nuevo desde GitHub y se verificaron ambas ramas,
las imágenes alcanzables, el README y el resultado de Gitleaks. Los registros
permanecen localmente en `build/publication-validation/`.

La limpieza cambió los identificadores históricos del servidor. Las ramas y
los cambios pendientes del espacio de trabajo original se conservaron: no se
reescribió su historia ni se agregaron archivos al staging.

## PR, cachés y copias

La referencia del PR #1 sigue conservando una captura con identificadores.
Tras actualizar las ramas, se comprobó que la referencia aún existe. Corresponde
solicitar a GitHub la eliminación
de las referencias y vistas almacenadas que mantengan los datos. Se dejó un
borrador local para esa solicitud en
`build/publication-validation/github-support-draft.md`; no se envió ningún
mensaje ni solicitud externa.

Los forks y clones ajenos pueden conservar la historia anterior. La guía de
[eliminación de información sensible de GitHub](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository)
explica estas limitaciones y la intervención de soporte para referencias de
PR y cachés. Por eso esta revisión no declara eliminado el material de todas
las copias públicas.

## Continuación de la entrega funcional

Con las ramas saneadas, los cambios funcionales deben prepararse
sobre la historia saneada, copiando únicamente archivos revisados. No se debe
fusionar la rama local antigua: esa fusión volvería a incorporar los commits
que contienen las capturas.

El inventario local se mantiene respecto de `d045999` para poder revisar cada
modificación pendiente. Su diferencia exacta respecto de la futura rama limpia
se revisará nuevamente al preparar los commits. Los mockups nuevos usarán
datos ficticios y se comprobarán antes de agregarlos.
