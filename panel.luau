--!nonstrict

--- EN: Thin Noctalia panel entry; forwards lifecycle and named UI callbacks to its controller module.
--- ES: Entrada delgada del panel Noctalia; reenvía lifecycle y callbacks UI al módulo controlador.

local panelController = require("./lib/panel/controller.luau")

--- EN: Opens the panel and initializes its current player snapshot; returns nothing.
--- ES: Abre el panel e inicializa la instantánea actual del reproductor; no devuelve nada.
function onOpen(context)
  panelController.dispatch("onOpen", context)
end

--- EN: Stops panel animation and clears its shared open state; returns nothing.
--- ES: Detiene la animación y limpia el estado compartido de apertura; no devuelve nada.
function onClose()
  panelController.dispatch("onClose")
end

--- EN: Advances panel animations for the supplied frame duration; returns nothing.
--- ES: Avanza las animaciones del panel según la duración del fotograma; no devuelve nada.
function onFrameTick(deltaMs)
  panelController.dispatch("onFrameTick", deltaMs)
end

--- EN: Adds the complete library to the MPD queue; returns nothing.
--- ES: Añade toda la biblioteca a la cola MPD; no devuelve nada.
function addAllLibrary()
  panelController.dispatch("addAllLibrary")
end

--- EN: Saves the current queue as a named playlist; returns nothing.
--- ES: Guarda la cola actual como playlist con nombre; no devuelve nada.
function savePlaylist()
  panelController.dispatch("savePlaylist")
end

--- EN: Selects the queue tab; returns nothing.
--- ES: Selecciona la pestaña de cola; no devuelve nada.
function showQueue()
  panelController.dispatch("showQueue")
end

--- EN: Selects the playlists tab; returns nothing.
--- ES: Selecciona la pestaña de playlists; no devuelve nada.
function showPlaylists()
  panelController.dispatch("showPlaylists")
end

--- EN: Selects the library tab; returns nothing.
--- ES: Selecciona la pestaña de biblioteca; no devuelve nada.
function showLibrary()
  panelController.dispatch("showLibrary")
end

--- EN: Reloads the visible library page; returns nothing.
--- ES: Recarga la página visible de la biblioteca; no devuelve nada.
function reloadLibrary()
  panelController.dispatch("reloadLibrary")
end

--- EN: Toggles playback from the queue panel; returns nothing.
--- ES: Alterna la reproducción desde el panel de cola; no devuelve nada.
function togglePlayback()
  panelController.dispatch("togglePlayback")
end

--- EN: Requests the previous track; returns nothing.
--- ES: Solicita la pista anterior; no devuelve nada.
function previousTrack()
  panelController.dispatch("previousTrack")
end

--- EN: Requests the next track; returns nothing.
--- ES: Solicita la pista siguiente; no devuelve nada.
function nextTrack()
  panelController.dispatch("nextTrack")
end

--- EN: Toggles random playback; returns nothing.
--- ES: Alterna la reproducción aleatoria; no devuelve nada.
function toggleRandom()
  panelController.dispatch("toggleRandom")
end

--- EN: Cycles repeat mode; returns nothing.
--- ES: Cambia el modo de repetición; no devuelve nada.
function toggleRepeat()
  panelController.dispatch("toggleRepeat")
end

--- EN: Handles actions from the queue context menu; returns nothing.
--- ES: Gestiona acciones del menú contextual de cola; no devuelve nada.
function onQueueContextAction(actionId, context)
  panelController.dispatch("onQueueContextAction", actionId, context)
end

--- EN: Handles actions from the library context menu; returns nothing.
--- ES: Gestiona acciones del menú contextual de biblioteca; no devuelve nada.
function onLibraryContextAction(actionId, file)
  panelController.dispatch("onLibraryContextAction", actionId, file)
end
