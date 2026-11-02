# Impresión de partes médicos · desde la versión 1.0.5.6

La Brother HL-1210W series y la Canon LBP6030/6040/6018L tienen ajustes
independientes en cada PC. El ajuste previo del equipo se conserva como punto
de partida. «Restablecer» vuelve a la calibración inicial del formulario;
«Guardar ajuste» lo aplica a las próximas impresiones de la impresora elegida.

## Ajustar y comprobar

1. En el parte, abrir **Ajustar impresión** y elegir la Brother o la Canon.
2. Colocar un formulario preimpreso A4 e imprimir una prueba. El envío usa los
   valores visibles, aunque todavía no se hayan guardado.
3. Para comprobar el segundo envío, aumentar temporalmente ambos ejes **2 mm**
   y volver a pulsar **Imprimir prueba**. Debe salir 2 mm a la derecha y 2 mm
   más abajo respecto de la primera prueba. El mensaje indica los valores
   enviados y cada prueba figura con un nombre distinto en la cola de Windows.
4. Volver a los valores de la primera prueba e imprimir nuevamente: debe volver
   a la posición inicial. Terminar de alinear y pulsar **Guardar ajuste**.
5. Al imprimir un parte o la bandeja, elegir esa misma impresora. Se usa el
   ajuste guardado para ese destino, con el mismo PDF que en la prueba.
6. Repetir en la otra impresora; su ajuste no modifica el de la primera.

Los valores son desplazamientos absolutos respecto de la calibración inicial:
escribir 2 mm dos veces conserva 2 mm. Positivo mueve a la derecha o abajo;
negativo mueve a la izquierda o arriba. El límite de cada eje es ±10 mm.

La vista previa sobre el escaneo conserva su función de revisar los datos.
La comprobación de la alineación se hace sobre el formulario preimpreso.

## Validación de esta corrección

Se comprobaron automáticamente los valores de tres pruebas consecutivas sin
guardar, la impresión posterior con el ajuste guardado, los desplazamientos
en puntos PDF equivalentes a los milímetros solicitados, el tamaño A4,
la separación entre Brother y Canon y el reintento tras cancelar o fallar.
El responsable confirmó el 2/11/2026 que la impresión de prueba salió bien y
autorizó publicar la versión. Al cambiar el formulario o la impresora, la
alineación se puede comprobar con los pasos de arriba.

El 2/11/2026 pasaron las 150 pruebas de la aplicación con una caché de pruebas
nueva. El instalador se prepara con el código validado y se comprueban las
firmas Ed25519, el tamaño y el SHA-256.

La versión final agrega la fecha de hoy como primera línea del mensaje para
Enfermería y está publicada en `\\PC-PUBLICADORA\HESM-Actualizaciones`. Las 150 pruebas
pasaron también con este cambio final. Se verificaron el instalador y su
manifiesto firmado desde la ruta de red.
