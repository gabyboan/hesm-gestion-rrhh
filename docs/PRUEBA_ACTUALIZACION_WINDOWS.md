# Prueba de actualización en la otra PC

Origen confirmado por el responsable: **1.0.3.4**, instalada en Windows 10,
con `\\PC-04\HESM-Actualizaciones` configurada dentro de HESM. Las credenciales
de Windows ya permiten abrir el recurso. Destino de la prueba: **1.0.4.5**.

La versión destino está publicada. Se verificaron firmas, SHA-256 y tamaño
desde la ruta UNC, además de la verificación real con el código Dart del cliente.
Pasaron el análisis estático y las 142 pruebas.

**Resultado del 29/10/2026: detección e instalación remotas confirmadas.**
El responsable informó que la otra PC ofreció la 1.0.4.5 desde la 1.0.3.4
instalada y luego confirmó: «ya se instaló correctamente». Se registra esa
confirmación como evidencia de la prueba real del actualizador.

1. Esperar a que la versión destino esté publicada. Mantener PC-04 encendida.
2. En la PC receptora guardar el trabajo, cerrar HESM y volver a abrir la
   aplicación instalada desde Inicio. Esta reapertura consulta las actualizaciones.
3. Comprobar que ofrece **1.0.4.5** y elegir **Instalar y reiniciar**. Para esta
   prueba, usar el actualizador de la versión instalada, en lugar de ejecutar
   manualmente el nuevo instalador.
4. Esperar la copia, verificación, instalación y reapertura. Es un reinicio de
   HESM; no se solicita reiniciar Windows.
5. Al iniciar, comprobar **v1.0.4.5** arriba a la derecha, la tarjeta
   **Sistema actualizado** y los checks de los servicios. En Configuración debe
   conservarse la carpeta de actualizaciones y verse la misma versión instalada.
6. Confirmar que puede iniciar sesión y trabajar con normalidad.

Si no ofrece la actualización al reabrir, buscarla desde **Configuración →
Actualizaciones del hospital → Guardar carpeta y buscar**. Registrar si fue
necesaria esa búsqueda manual. Si falla la copia, instalación o reapertura,
anotar el mensaje y la versión que continúa abriendo; no registrar contraseñas.

La 1.0.4.5 presenta la búsqueda y las decisiones dentro de la pantalla de inicio.
La versión origen 1.0.3.4 ofrece su diálogo existente después de las comprobaciones.
Las pruebas automatizadas verifican ignorar una actualización, conservar los
controles obligatorios, informar una carpeta inaccesible y el límite de espera.
La detección e instalación en la PC receptora fueron confirmadas por el
responsable; los pasos anteriores quedan como guía para próximas entregas.
