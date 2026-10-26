--!nonstrict
-- mpc.luau
-- Módulo con los comandos de `mpc` (versión 0.35) como funciones de Luau.
--
-- Uso desde widget.luau, panel.luau o service.luau:
--   local mpc = require("./mpc.luau")
--   mpc.play()
--   mpc.save("mi lista", function(result) ... end)
--
-- Notas:
--  * Todos los argumentos se pasan como elementos separados de una tabla; nunca
--    se arma texto de shell. Así los nombres con espacios o comillas son seguros.
--  * `onDone` es opcional. Si se omite, el comando se lanza y no se espera su
--    resultado. Si se indica, recibe una tabla con `exitCode`, `stdout` y `stderr`.
--  * Los comandos persistentes y binarios no se exponen aquí. El servicio inicia
--    `mpc idleloop` con runStream; albumart/readpicture se manejan en Python.

local M = {}

-- ───────────────────────── Base ─────────────────────────

-- Ejecuta `mpc` con la lista de argumentos indicada.
function M.run(args, onDone)
  local cmd = { "mpc" }
  for _, a in ipairs(args) do
    table.insert(cmd, tostring(a))
  end
  local callback
  if onDone then
    callback = function(result)
      local ok, err = pcall(onDone, result)
      if not ok then noctalia.log("MusicPC mpc callback failed: " .. tostring(err)) end
    end
  end
  local ok, accepted = pcall(noctalia.runAsync, cmd, callback)
  if not ok then
    noctalia.log("MusicPC mpc launch failed: " .. tostring(accepted))
    return false
  end
  return accepted
end

local run = M.run

-- Igual que run, pero con un formato de salida (opción -f de mpc).
-- Ejemplo de formato: "%artist%\t%title%\t%file%" (evitar | % [ ] & # \ como separador)
function M.runFormat(format, args, onDone)
  local cmd = { "-f", format }
  for _, a in ipairs(args) do
    table.insert(cmd, a)
  end
  return run(cmd, onDone)
end

-- Convierte un booleano en "on"/"off". Si es nil devuelve nil (alternar).
local function onOff(valor)
  if valor == nil then return nil end
  return valor and "on" or "off"
end

-- Ejecuta un comando con un argumento opcional de estado (on/off).
local function runEstado(comando, valor, onDone)
  local estado = onOff(valor)
  if estado then
    return run({ comando, estado }, onDone)
  end
  return run({ comando }, onDone)
end

-- ───────────────────────── Estado ─────────────────────────

-- Muestra el estado actual de reproducción.
function M.status(onDone) return run({}, onDone) end

-- Muestra la canción que está sonando.
function M.current(onDone) return run({ "current" }, onDone) end

-- Muestra la siguiente canción de la cola.
function M.queued(onDone) return run({ "queued" }, onDone) end

-- Muestra estadísticas de MPD.
function M.stats(onDone) return run({ "stats" }, onDone) end

-- Informa la versión de MPD.
function M.version(onDone) return run({ "version" }, onDone) end

-- Limpia el error actual de MPD.
function M.clearerror(onDone) return run({ "clearerror" }, onDone) end

-- ───────────────────────── Reproducción ─────────────────────────

-- Empieza a reproducir; con `posicion` salta a esa canción de la cola (desde 1).
function M.play(posicion, onDone)
  if posicion then
    return run({ "play", posicion }, onDone)
  end
  return run({ "play" }, onDone)
end

-- Pausa la reproducción.
function M.pause(onDone) return run({ "pause" }, onDone) end

-- Pausa solo si estaba reproduciendo; falla si no lo estaba.
function M.pauseIfPlaying(onDone) return run({ "pause-if-playing" }, onDone) end

-- Alterna entre reproducir y pausar (reproduce si estaba detenido).
function M.toggle(onDone) return run({ "toggle" }, onDone) end

-- Detiene la reproducción.
function M.stop(onDone) return run({ "stop" }, onDone) end

-- Pasa a la siguiente canción de la cola.
function M.next(onDone) return run({ "next" }, onDone) end

-- Vuelve a la canción anterior de la cola.
function M.prev(onDone) return run({ "prev" }, onDone) end

-- Anterior estilo reproductor de CD: reinicia la canción si ya avanzó un poco.
function M.cdprev(onDone) return run({ "cdprev" }, onDone) end

-- Salta a una posición. Acepta "+10", "-30", "01:30" o un porcentaje como "50%".
function M.seek(posicion, onDone) return run({ "seek", posicion }, onDone) end

-- Salta a un porcentaje de la canción (número de 0 a 100).
function M.seekPercent(porcentaje, onDone)
  return run({ "seek", tostring(math.floor(porcentaje)) .. "%" }, onDone)
end

-- Avanza o retrocede un tiempo, pudiendo cruzar canciones. Ejemplo: "+00:00:30".
function M.seekthrough(tiempo, onDone) return run({ "seekthrough", tiempo }, onDone) end

-- Busca una canción que coincida con el patrón y la reproduce.
function M.searchplay(patron, onDone) return run({ "searchplay", patron }, onDone) end

-- ───────────────────────── Modos ─────────────────────────

-- Modo aleatorio: true = activar, false = desactivar, nil = alternar.
function M.random(activo, onDone) return runEstado("random", activo, onDone) end

-- Modo repetir: true = activar, false = desactivar, nil = alternar.
-- (No se llama `repeat` porque es una palabra reservada de Luau.)
function M.repeatMode(activo, onDone) return runEstado("repeat", activo, onDone) end

-- Modo consumir (quita de la cola lo ya reproducido): true / false / nil.
function M.consume(activo, onDone) return runEstado("consume", activo, onDone) end

-- Modo una sola canción: "on", "once" u "off". Sin valor, alterna.
function M.single(modo, onDone)
  if modo then
    return run({ "single", modo }, onDone)
  end
  return run({ "single" }, onDone)
end

-- Fundido entre canciones: sin valor muestra el actual; con segundos lo cambia.
function M.crossfade(segundos, onDone)
  if segundos then
    return run({ "crossfade", segundos }, onDone)
  end
  return run({ "crossfade" }, onDone)
end

-- Ajuste mixrampdb: sin valor lo muestra; con dB lo cambia.
function M.mixrampdb(db, onDone)
  if db then
    return run({ "mixrampdb", db }, onDone)
  end
  return run({ "mixrampdb" }, onDone)
end

-- Ajuste mixrampdelay: sin valor lo muestra; con segundos lo cambia.
function M.mixrampdelay(segundos, onDone)
  if segundos then
    return run({ "mixrampdelay", segundos }, onDone)
  end
  return run({ "mixrampdelay" }, onDone)
end

-- ReplayGain: "off", "track" o "album". Sin valor muestra el modo actual.
function M.replaygain(modo, onDone)
  if modo then
    return run({ "replaygain", modo }, onDone)
  end
  return run({ "replaygain" }, onDone)
end

-- ───────────────────────── Volumen ─────────────────────────

-- Fija el volumen (0-100) o lo ajusta con un signo: "+5", "-5".
function M.volume(valor, onDone) return run({ "volume", valor }, onDone) end

-- ───────────────────────── Cola ─────────────────────────

-- Muestra la cola de reproducción actual (o una playlist guardada si se indica).
function M.playlist(nombre, onDone)
  if nombre then
    return run({ "playlist", nombre }, onDone)
  end
  return run({ "playlist" }, onDone)
end

-- Añade una canción o carpeta a la cola. "/" añade toda la biblioteca.
function M.add(uri, onDone) return run({ "add", uri }, onDone) end

-- Inserta una canción justo después de la que está sonando.
function M.insert(uri, onDone) return run({ "insert", uri }, onDone) end

-- Quita de la cola la canción en esa posición.
function M.del(posicion, onDone) return run({ "del", posicion }, onDone) end

-- Vacía la cola.
function M.clear(onDone) return run({ "clear" }, onDone) end

-- Quita todo de la cola excepto la canción que está sonando.
function M.crop(onDone) return run({ "crop" }, onDone) end

-- Mezcla aleatoriamente el orden de la cola.
function M.shuffle(onDone) return run({ "shuffle" }, onDone) end

-- Mueve una canción de una posición a otra dentro de la cola.
function M.move(desde, hasta, onDone) return run({ "move", desde, hasta }, onDone) end

-- Cambia la prioridad de canciones de la cola (posición o rango, ej. "3" o "2:5").
function M.prio(prioridad, posiciones, onDone)
  local args = { "prio", prioridad }
  for _, p in ipairs(posiciones) do
    table.insert(args, p)
  end
  return run(args, onDone)
end

-- ───────────────────────── Playlists guardadas ─────────────────────────

-- Lista los nombres de las playlists guardadas.
function M.lsplaylists(onDone) return run({ "lsplaylists" }, onDone) end

-- Carga una playlist guardada al final de la cola.
function M.load(nombre, onDone) return run({ "load", nombre }, onDone) end

-- Guarda la cola actual como playlist con ese nombre.
function M.save(nombre, onDone) return run({ "save", nombre }, onDone) end

-- Elimina una playlist guardada.
function M.rm(nombre, onDone) return run({ "rm", nombre }, onDone) end

-- Renombra una playlist guardada.
function M.renplaylist(nombre, nuevoNombre, onDone)
  return run({ "renplaylist", nombre, nuevoNombre }, onDone)
end

-- Añade una canción a una playlist guardada.
function M.addplaylist(nombre, uri, onDone)
  return run({ "addplaylist", nombre, uri }, onDone)
end

-- Quita una canción (por posición) de una playlist guardada.
function M.delplaylist(nombre, posicion, onDone)
  return run({ "delplaylist", nombre, posicion }, onDone)
end

-- Vacía una playlist guardada.
function M.clearplaylist(nombre, onDone) return run({ "clearplaylist", nombre }, onDone) end

-- Mueve una canción de posición dentro de una playlist guardada.
function M.moveplaylist(nombre, desde, hasta, onDone)
  return run({ "moveplaylist", nombre, desde, hasta }, onDone)
end

-- ───────────────────────── Biblioteca ─────────────────────────

-- Lista todas las canciones de la carpeta de música (o de una ruta concreta).
function M.listall(ruta, onDone)
  if ruta then
    return run({ "listall", ruta }, onDone)
  end
  return run({ "listall" }, onDone)
end

-- Lista el contenido de una carpeta de la biblioteca.
function M.ls(carpeta, onDone)
  if carpeta then
    return run({ "ls", carpeta }, onDone)
  end
  return run({ "ls" }, onDone)
end

-- Lista las subcarpetas de una carpeta de la biblioteca.
function M.lsdirs(carpeta, onDone)
  if carpeta then
    return run({ "lsdirs", carpeta }, onDone)
  end
  return run({ "lsdirs" }, onDone)
end

-- Lista los valores de una etiqueta (artist, album, genre...). Filtro opcional:
--   M.list("album", { "artist", "Daft Punk" }, cb)
function M.list(tipo, filtro, onDone)
  local args = { "list", tipo }
  if filtro then
    for _, f in ipairs(filtro) do
      table.insert(args, f)
    end
  end
  return run(args, onDone)
end

-- Busca canciones por coincidencia parcial (tipo: artist, album, title, any...).
function M.search(tipo, consulta, onDone) return run({ "search", tipo, consulta }, onDone) end

-- Busca canciones por coincidencia exacta.
function M.find(tipo, consulta, onDone) return run({ "find", tipo, consulta }, onDone) end

-- Busca por coincidencia parcial y añade los resultados a la cola.
function M.searchadd(tipo, consulta, onDone)
  return run({ "searchadd", tipo, consulta }, onDone)
end

-- Busca por coincidencia exacta y añade los resultados a la cola.
function M.findadd(tipo, consulta, onDone)
  return run({ "findadd", tipo, consulta }, onDone)
end

-- Busca nuevas canciones o cambios en la carpeta de música.
function M.update(ruta, onDone)
  if ruta then
    return run({ "update", ruta }, onDone)
  end
  return run({ "update" }, onDone)
end

-- Reescanea la carpeta de música, incluyendo archivos sin cambios.
function M.rescan(ruta, onDone)
  if ruta then
    return run({ "rescan", ruta }, onDone)
  end
  return run({ "rescan" }, onDone)
end

-- ───────────────────────── Etiquetas adhesivas (stickers) ─────────────────────────

-- Gestiona stickers. `accion`: get, set, list, delete o find; `extra` son los
-- argumentos adicionales de esa acción.
function M.sticker(uri, accion, extra, onDone)
  local args = { "sticker", uri, accion }
  if extra then
    for _, e in ipairs(extra) do
      table.insert(args, e)
    end
  end
  return run(args, onDone)
end

-- ───────────────────────── Salidas de audio ─────────────────────────

-- Muestra las salidas de audio y si están activas.
function M.outputs(onDone) return run({ "outputs" }, onDone) end

-- Activa una o varias salidas (número o nombre). Con soloEsta = true deja solo esas.
function M.enable(salidas, soloEsta, onDone)
  local args = { "enable" }
  if soloEsta then table.insert(args, "only") end
  for _, s in ipairs(salidas) do
    table.insert(args, s)
  end
  return run(args, onDone)
end

-- Desactiva una o varias salidas (número o nombre). Con soloEsta = true deja solo esas.
function M.disable(salidas, soloEsta, onDone)
  local args = { "disable" }
  if soloEsta then table.insert(args, "only") end
  for _, s in ipairs(salidas) do
    table.insert(args, s)
  end
  return run(args, onDone)
end

-- Alterna una o varias salidas (activa ↔ desactiva).
function M.toggleoutput(salidas, onDone)
  local args = { "toggleoutput" }
  for _, s in ipairs(salidas) do
    table.insert(args, s)
  end
  return run(args, onDone)
end

-- Cambia un atributo de una salida. Ejemplo: M.outputset("1", "dop", "yes", cb)
function M.outputset(salida, nombre, valor, onDone)
  return run({ "outputset", salida, nombre .. "=" .. valor }, onDone)
end

-- Mueve una salida a otra partición.
function M.moveoutput(salida, onDone) return run({ "moveoutput", salida }, onDone) end

-- ───────────────────────── Particiones ─────────────────────────

-- Lista las particiones de MPD.
function M.partitions(onDone) return run({ "partitions" }, onDone) end

-- Crea una partición.
function M.makepart(nombre, onDone) return run({ "makepart", nombre }, onDone) end

-- Elimina una partición.
function M.delpart(nombre, onDone) return run({ "delpart", nombre }, onDone) end

-- ───────────────────────── Montajes y vecinos ─────────────────────────

-- Sin argumentos lista los montajes; con ruta y URI crea uno nuevo.
function M.mount(rutaMontaje, uriAlmacenamiento, onDone)
  if rutaMontaje and uriAlmacenamiento then
    return run({ "mount", rutaMontaje, uriAlmacenamiento }, onDone)
  end
  return run({ "mount" }, onDone)
end

-- Quita un montaje.
function M.unmount(rutaMontaje, onDone) return run({ "unmount", rutaMontaje }, onDone) end

-- Lista los vecinos de red descubiertos.
function M.listneighbors(onDone) return run({ "listneighbors" }, onDone) end

-- ───────────────────────── Canales y mensajes ─────────────────────────

-- Lista los canales a los que están suscritos otros clientes.
function M.channels(onDone) return run({ "channels" }, onDone) end

-- Envía un mensaje a un canal.
function M.sendmessage(canal, mensaje, onDone)
  return run({ "sendmessage", canal, mensaje }, onDone)
end

return M
