--!nonstrict

--- EN: Composes queue commands into saved-playlist workflows; required lazily by panel.luau.
--- ES: Combina comandos de cola en flujos de playlists guardadas; panel.luau lo carga bajo demanda.

local mpc = require("../mpd/client.luau")
local M = {}

--- EN: Replaces the current queue with a saved playlist, starting playback after it loads.
--- ES: Reemplaza la cola actual por una playlist guardada e inicia la reproducción al cargarla.
function M.load(name, callback)
  --- EN: Continues only after the queue was cleared successfully.
  --- ES: Continúa solo después de vaciar la cola correctamente.
  mpc.clear(function(clearResult)
    if clearResult.exitCode ~= 0 then
      callback(clearResult)
      return
    end
    --- EN: Starts playback after loading and returns the load result to the caller.
    --- ES: Inicia la reproducción tras cargar y devuelve el resultado al consumidor.
    mpc.load(name, function(loadResult)
      if loadResult.exitCode == 0 then
        mpc.play()
      end
      callback(loadResult)
    end)
  end)
end

--- EN: Saves the current queue using the given playlist name; forwards the mpc result.
--- ES: Guarda la cola actual con el nombre indicado y reenvía el resultado de mpc.
function M.save(name, callback)
  mpc.save(name, callback)
end

--- EN: Adds one library file to a saved playlist; forwards the mpc result.
--- ES: Añade un archivo de biblioteca a una playlist guardada y reenvía el resultado de mpc.
function M.addTrack(name, file, callback)
  mpc.addPlaylist(name, file, callback)
end

return M