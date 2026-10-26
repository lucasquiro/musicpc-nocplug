# MusicPC

Plugin para Noctalia que controla un servidor MPD desde la barra y un panel compacto. Ejecuta comandos `mpc` y no reproduce audio por sí mismo.

## Funciones

- Widget de barra con canción actual, reproducción/pausa y acceso al panel.
- Panel con progreso, controles, Cola, Playlists y Biblioteca.
- Reordenar o seleccionar pistas de cola, y añadir o quitar canciones.
- Guardar y cargar playlists.
- Abrir carátulas y editar metadatos MP3 mediante herramientas locales.

## Requisitos

- Noctalia v5.3.0 con soporte para `plugin_api = 34`.
- MPD y `mpc` configurados para el usuario que ejecuta Noctalia.
- Python 3, FFmpeg y GIO para las funciones de archivos y metadatos.

## Límites de listas

Para mantener acotado el coste de cada render, el panel muestra como máximo 40 filas de cola, 30 playlists y 25 canciones por página de Biblioteca. La Biblioteca pide una ventana desde `mpc` y conserva solo la página activa; el helper deja de leer cuando puede construir los botones cercanos y comprobar si existe otra página. «Añadir toda la biblioteca y reproducir» permanece en Cola.

El log del 2026-10-26 registró que `showLibrary` superaba el presupuesto de CPU y Noctalia deshabilitó el panel tras varios timeouts. Estos límites reducen la cantidad de controles Luau que se construyen en esa vista.

## Documentación

- [Guía de arquitectura, compatibilidad y límites](docs/arquitectura-y-limites.md)
- [Descripción funcional y desarrollo](docs/info.MD)
- [Referencia local de mpc](docs/mpc.md)
- [Manual de comandos mpc](docs/manual_de_comandos_de_mpc.md)

## Instalación y prueba local

Instala el directorio del plugin según el flujo de desarrollo local de Noctalia. Luego reinicia la entrada del plugin desde el gestor o con:

```sh
noctalia msg plugins disable lucasquiro/musicpc-nocplug
noctalia msg plugins enable lucasquiro/musicpc-nocplug
```

Abre o cierra el panel con:

```sh
noctalia msg panel-toggle lucasquiro/musicpc-nocplug:queue
```

Prueba Biblioteca con una biblioteca grande, cambia de página y alterna las tres pestañas; observa el log de Noctalia para errores de la entrada. Comprueba que cada página muestre como máximo 25 canciones y que la acción para añadir toda la biblioteca siga disponible en Cola.

## Compatibilidad

El manifiesto declara `plugin_api = 34`. No eleves ese nivel sin comprobar que cada API nueva está disponible en el Noctalia mínimo soportado. Los paneles tienen alturas fijas; no usan `height = "content"` ni `max_height`.
