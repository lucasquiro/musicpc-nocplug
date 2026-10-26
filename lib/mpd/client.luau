--!nonstrict

--- EN: Exposes only the mpc commands used by MusicPC panels and playlist operations.
--- ES: Expone únicamente los comandos mpc usados por los paneles y las operaciones de playlists de MusicPC.

local M = {}

--- EN: Runs mpc with separate argv values and safely delivers an optional process result.
--- ES: Ejecuta mpc con argumentos argv separados y entrega de forma segura el resultado opcional.
function M.run(arguments, onDone)
  local command = { "mpc" }
  for _, argument in ipairs(arguments) do
    table.insert(command, tostring(argument))
  end
  local callback
  if onDone then
    --- EN: Contains consumer errors so they cannot escape the process callback.
    --- ES: Contiene errores del consumidor para que no escapen del callback del proceso.
    callback = function(result)
      local ok, err = pcall(onDone, result)
      if not ok then noctalia.log("MusicPC mpc callback failed: " .. tostring(err)) end
    end
  end
  local ok, accepted = pcall(noctalia.runAsync, command, callback)
  if not ok then
    noctalia.log("MusicPC mpc launch failed: " .. tostring(accepted))
    return false
  end
  return accepted
end

--- EN: Starts playback, optionally at a 1-based queue position; returns launch acceptance.
--- ES: Inicia la reproducción, opcionalmente en una posición de cola desde 1; devuelve si se aceptó el lanzamiento.
function M.play(position, onDone)
  if position then return M.run({ "play", position }, onDone) end
  return M.run({ "play" }, onDone)
end

--- EN: Adds a library URI or directory to the MPD queue; returns launch acceptance.
--- ES: Añade una URI o carpeta de la biblioteca a la cola MPD; devuelve si se aceptó el lanzamiento.
function M.add(uri, onDone)
  return M.run({ "add", uri }, onDone)
end

--- EN: Removes the 1-based queue position; returns launch acceptance.
--- ES: Elimina la posición de cola desde 1; devuelve si se aceptó el lanzamiento.
function M.delete(position, onDone)
  return M.run({ "del", position }, onDone)
end

--- EN: Moves a queue item between 1-based positions; returns launch acceptance.
--- ES: Mueve una pista entre posiciones de cola desde 1; devuelve si se aceptó el lanzamiento.
function M.move(fromPosition, toPosition, onDone)
  return M.run({ "move", fromPosition, toPosition }, onDone)
end

--- EN: Clears the MPD queue; returns launch acceptance.
--- ES: Vacía la cola de MPD; devuelve si se aceptó el lanzamiento.
function M.clear(onDone)
  return M.run({ "clear" }, onDone)
end

--- EN: Loads a saved playlist into MPD; returns launch acceptance.
--- ES: Carga una playlist guardada en MPD; devuelve si se aceptó el lanzamiento.
function M.load(name, onDone)
  return M.run({ "load", name }, onDone)
end

--- EN: Saves the current MPD queue under a playlist name; returns launch acceptance.
--- ES: Guarda la cola actual de MPD con un nombre de playlist; devuelve si se aceptó el lanzamiento.
function M.save(name, onDone)
  return M.run({ "save", name }, onDone)
end

--- EN: Adds a library URI to a saved playlist; returns launch acceptance.
--- ES: Añade una URI de biblioteca a una playlist guardada; devuelve si se aceptó el lanzamiento.
function M.addPlaylist(name, uri, onDone)
  return M.run({ "addplaylist", name, uri }, onDone)
end

--- EN: Seeks to a percentage from 0 through 100; returns launch acceptance.
--- ES: Busca un porcentaje de 0 a 100 de la pista; devuelve si se aceptó el lanzamiento.
function M.seekPercent(percent, onDone)
  return M.run({ "seek", tostring(math.floor(percent)) .. "%" }, onDone)
end

return M
