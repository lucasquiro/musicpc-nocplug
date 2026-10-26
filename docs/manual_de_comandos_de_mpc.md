# Manual de Ayuda de MPC (Music Player Client)

**Uso:** `mpc [opciones] <comando> [--] [<argumentos>]`  
**Versión de mpc:** 0.35

---

## Opciones

| Opción | Descripción |
| :--- | :--- |
| `-v, --verbose` | Muestra una salida detallada |
| `-q, --quiet` | Suprime los mensajes de estado |
| `--no-status` | Sinónimo de `--quiet` |
| `-h, --host=<host>` | Conecta al servidor en `<host>` |
| `-P, --password=<password>` | Conecta al servidor usando la contraseña `<password>` |
| `-p, --port=<puerto>` | Conecta al puerto del servidor `<puerto>` |
| `-f, --format=<formato>` | Imprime el estado con el formato `<formato>` |
| `-w, --wait` | Espera a que termine la operación (ej. actualización de base de datos) |
| `-r, --range=[<inicio>]:[<fin>]` | Opera sobre un rango (ej. al cargar una lista de reproducción) |
| `-a, --partition=<nombre>` | Opera en la partición `<nombre>` en su lugar |
| `--with-prio` | Muestra solo las canciones que tienen una prioridad diferente de cero |

---

## Comandos

| Comando | Descripción |
| :--- | :--- |
| `mpc` | Muestra el estado actual |
| `mpc add <uri>` | Añade una canción a la cola |
| `mpc addplaylist <archivo> <uri> ...` | Añade una canción a la lista de reproducción |
| `mpc albumart <uri>` | Descarga la portada del álbum para la canción dada y la escribe en la salida estándar (`stdout`) |
| `mpc cdprev` | Comando "anterior" similar al funcionamiento de un reproductor de CD |
| `mpc channels` | Lista los canales a los que se han suscrito otros clientes |
| `mpc clear` | Limpia la cola |
| `mpc clearerror` | Borra el error actual |
| `mpc clearplaylist <archivo>` | Limpia la lista de reproducción |
| `mpc consume <on\|off>` | Alterna el modo consumo (elimina la canción tras reproducirla) o especifica el estado |
| `mpc crop` | Elimina todas las canciones excepto la que se está reproduciendo actualmente |
| `mpc crossfade [<segundos>]` | Establece y muestra la configuración de fundido cruzado (`crossfade`) |
| `mpc current` | Muestra la canción en reproducción actual |
| `mpc del <posición>` | Elimina una canción de la cola |
| `mpc delpart <nombre> ...` | Elimina partición(es) |
| `mpc delplaylist <archivo> <posición> ...` | Elimina una canción de la lista de reproducción |
| `mpc disable [only] <salida # o nombre> [...]` | Desactiva salida(s) de audio |
| `mpc enable [only] <salida # o nombre> [...]` | Activa salida(s) de audio |
| `mpc find <tipo> <consulta>` | Busca una canción (coincidencia exacta) |
| `mpc findadd <tipo> <consulta>` | Busca canciones y las añade a la cola |
| `mpc idle [eventos]` | Permanece inactivo hasta que ocurra un evento |
| `mpc idleloop [eventos]` | Bucle inactivo continuo hasta que ocurra un evento |
| `mpc insert <uri>` | Inserta una canción en la cola después de la pista actual |
| `mpc list <tipo> [<tipo> <consulta>]` | Muestra todas las etiquetas del tipo `<tipo>` |
| `mpc listall [<archivo>]` | Lista todas las canciones en el directorio de música |
| `mpc listneighbors` | Lista los vecinos en la red |
| `mpc load <archivo>` | Carga `<archivo>` en la cola |
| `mpc ls [<directorio>]` | Lista el contenido de `<directorio>` |
| `mpc lsplaylists` | Lista las listas de reproducción disponibles actualmente |
| `mpc lsdirs [<directorio>]` | Lista los subdirectorios de `<directorio>` |
| `mpc makepart <nombre> ...` | Crea partición(es) |
| `mpc mixrampdb [<dB>]` | Establece y muestra la configuración de `mixrampdb` |
| `mpc mixrampdelay [<segundos>]` | Establece y muestra la configuración de `mixrampdelay` |
| `mpc mount [<ruta-montaje> <uri-almacenamiento>]` | Lista los montajes o añade un nuevo montaje |
| `mpc move <de> <a>` | Mueve una canción en la cola |
| `mpc moveoutput <salida # o nombre>` | Mueve una salida a una partición (ver `-a`) |
| `mpc moveplaylist <archivo> <de> <a>` | Mueve una canción en la lista de reproducción |
| `mpc next` | Reproduce la siguiente canción en la cola |
| `mpc outputs` | Muestra las salidas de audio actuales |
| `mpc outputset <salida # o nombre> <nombre>=<valor>` | Establece atributos de la salida |
| `mpc partitions` | Lista las particiones |
| `mpc pause` | Pausa la canción que se está reproduciendo |
| `mpc pause-if-playing` | Pausa la canción actual; sale con error si no se está reproduciendo nada |
| `mpc play [<posición>]` | Empieza a reproducir en la `<posición>` |
| `mpc playlist [<lista_reproducción>]` | Imprime la `<lista_reproducción>` |
| `mpc prev` | Reproduce la canción anterior en la cola |
| `mpc prio <prio> <posición/rango> ...` | Cambia la prioridad de las canciones en la cola |
| `mpc queued` | Muestra la siguiente canción en la cola |
| `mpc random <on\|off>` | Alterna el modo aleatorio o especifica el estado |
| `mpc readpicture <uri>` | Descarga una imagen de la canción dada y la escribe en la salida estándar (`stdout`) |
| `mpc renplaylist <archivo> <nuevo_archivo>` | Renombra una lista de reproducción |
| `mpc repeat <on\|off>` | Alterna el modo repetición o especifica el estado |
| `mpc replaygain [off\|track\|album]` | Establece o muestra el modo de ganancia de reproducción (`replay gain`) |
| `mpc rescan [<ruta>]` | Reescanea el directorio de música (incluyendo archivos no modificados) |
| `mpc rm <archivo>` | Elimina una lista de reproducción |
| `mpc save <archivo>` | Guarda la cola actual como `<archivo>` |
| `mpc search <tipo> <consulta>` | Busca una canción |
| `mpc searchadd <tipo> <consulta>` | Busca canciones y las añade a la cola |
| `mpc searchplay <patrón>` | Busca y reproduce una canción en la cola |
| `mpc seek [+-][HH:MM:SS]\|<0-100>%` | Salta a la posición especificada |
| `mpc seekthrough [+-][HH:MM:SS]` | Salta una cantidad de tiempo dentro de la canción y la lista de reproducción |
| `mpc sendmessage <canal> <mensaje>` | Envía un mensaje al canal especificado |
| `mpc shuffle` | Mezcla el orden de la cola |
| `mpc single <on\|once\|off>` | Alterna el modo individual (reproducir una sola pista) o especifica el estado |
| `mpc stats` | Muestra estadísticas sobre MPD |
| `mpc sticker <uri> <get\|set\|list\|delete\|find> [args..]` | Gestión de etiquetas adhesivas (`stickers`) |
| `mpc stop` | Detiene la reproducción |
| `mpc subscribe <canal>` | Se suscribe al canal especificado y recibe mensajes continuamente |
| `mpc toggle` | Alterna Reproducir/Pausar, reproduce si está detenido |
| `mpc toggleoutput <salida # o nombre> [...]` | Alterna el estado de salida(s) |
| `mpc unmount <ruta-montaje>` | Elimina un montaje |
| `mpc update [<ruta>]` | Escanea el directorio de música en busca de novedades |
| `mpc version` | Muestra la versión de MPD |
| `mpc volume [+-]<num>` | Establece el volumen en `<num>` o lo ajusta mediante `[+-]<num>` |
| `mpc waitmessage <canal>` | Espera al menos un mensaje en el canal especificado |

---

*Consulta `man 1 mpc` para más información sobre los comandos y opciones de mpc.*