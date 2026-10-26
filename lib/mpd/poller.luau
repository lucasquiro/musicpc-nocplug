--!nonstrict

--- EN: Polls MPD, listens for idle events, and publishes player data through noctalia.state; required by service.luau.
--- ES: Consulta MPD, escucha eventos idle y publica datos del reproductor en noctalia.state; lo usa service.luau.

local SEP = "\t"
local FORMAT = "%artist%" .. SEP .. "%title%" .. SEP .. "%file%"
local lastPublished = {}
local ticks = 0
local queueDirty = true
local playlistsDirty = true
local statusBusy = false
local queueBusy = false
local playlistsBusy = false
local optimisticUntil = 0

--- EN: Splits text on a literal separator and preserves empty fields; returns an array of strings.
--- ES: Divide el texto por un separador literal y conserva campos vacíos; devuelve una lista de cadenas.
local function splitPlain(text, separator)
  local parts = {}
  local start = 1
  while true do
    local first, last = string.find(text, separator, start, true)
    if not first then
      table.insert(parts, string.sub(text, start))
      break
    end
    table.insert(parts, string.sub(text, start, first - 1))
    start = last + 1
  end
  return parts
end

--- EN: Removes carriage returns from subprocess output; returns a string.
--- ES: Elimina retornos de carro de la salida del proceso; devuelve una cadena.
local function clean(text)
  return string.gsub(text or "", "\r", "")
end

--- EN: Parses one formatted MPD song line; returns artist, title, and library file path.
--- ES: Interpreta una línea de canción formateada por MPD; devuelve artista, título y ruta del archivo.
local function parseSong(line)
  local parts = splitPlain(clean(line), SEP)
  local artist, title, file = parts[1] or "", parts[2] or "", parts[3] or ""
  if title == "" then title = string.match(file, "([^/]+)$") or file end
  return artist, title, file
end

--- EN: Builds a complete empty player snapshot for the supplied state; returns plain shared data.
--- ES: Construye una instantánea vacía completa para el estado indicado; devuelve datos simples compartibles.
local function emptyPlayer(state)
  return {
    state = state,
    artist = "",
    title = "",
    file = "",
    position = 0,
    count = 0,
    random = false,
    repeatMode = "off",
  }
end

--- EN: Parses mpc status output; returns player fields and a separate progress record.
--- ES: Interpreta la salida de estado de mpc; devuelve los campos del reproductor y el progreso por separado.
local function parseStatus(stdout)
  local lines = splitPlain(clean(stdout), "\n")
  local player = emptyPlayer("stopped")
  local progress = { elapsed = "0:00", total = "0:00", percent = 0 }
  local repeatEnabled = false
  local singleEnabled = false
  for _, line in ipairs(lines) do
    if string.find(line, "random: on", 1, true) then player.random = true end
    if string.find(line, "repeat: on", 1, true) then repeatEnabled = true end
    if string.find(line, "single: on", 1, true) then singleEnabled = true end
  end
  if repeatEnabled then player.repeatMode = singleEnabled and "one" or "all" end
  for index, line in ipairs(lines) do
    local state = string.match(line, "^%[(%a+)%]")
    if state then
      player.state = state
      local elapsed, total, percent = string.match(line, "(%d+:%d+)/(%d+:%d+) %((%d+)%%%)")
      if elapsed then
        progress.elapsed, progress.total, progress.percent = elapsed, total, tonumber(percent) or 0
      end
      local position, count = string.match(line, "#(%d+)/(%d+)")
      player.position = tonumber(position) or 0
      player.count = tonumber(count) or 0
      if lines[index - 1] then
        player.artist, player.title, player.file = parseSong(lines[index - 1])
      end
      break
    end
  end
  return player, progress
end

--- EN: Parses formatted playlist output into queue records; returns an array of track tables.
--- ES: Interpreta la salida de playlist formateada en registros de cola; devuelve una lista de pistas.
local function parseQueue(stdout)
  local queue = {}
  for _, line in ipairs(splitPlain(clean(stdout), "\n")) do
    if line ~= "" then
      local artist, title, file = parseSong(line)
      if file ~= "" then table.insert(queue, { artist = artist, title = title, file = file }) end
    end
  end
  return queue
end

--- EN: Trims playlist names from mpc output; returns only non-empty names.
--- ES: Recorta los nombres de playlist de la salida de mpc; devuelve solo nombres no vacíos.
local function parsePlaylists(stdout)
  local playlists = {}
  for _, line in ipairs(splitPlain(clean(stdout), "\n")) do
    local name = noctalia.string.trim(line)
    if name ~= "" then table.insert(playlists, name) end
  end
  return playlists
end

--- EN: Publishes a state value only when its JSON representation changes; returns nothing.
--- ES: Publica un valor solo si cambia su representación JSON; no devuelve nada.
local function publishIfChanged(key, value)
  local ok, encoded = pcall(noctalia.json.encode, value)
  if not ok or not encoded then return end
  if lastPublished[key] == encoded then return end
  lastPublished[key] = encoded
  local published, err = pcall(noctalia.state.set, key, value)
  if not published then noctalia.log("MusicPC state publish failed: " .. tostring(err)) end
end

--- EN: Wraps a subprocess callback so callback errors are logged instead of escaping; returns a protected callback.
--- ES: Envuelve un callback para registrar sus errores sin propagarlos; devuelve un callback protegido.
local function safeCallback(label, callback)
  --- EN: Invokes the completion handler with the subprocess result; contains thrown errors.
  --- ES: Invoca el controlador de finalización con el resultado; contiene errores lanzados.
  return function(result)
    local ok, err = pcall(callback, result)
    if not ok then noctalia.log("MusicPC " .. label .. " callback failed: " .. tostring(err)) end
  end
end

--- EN: Starts an argv-form subprocess and reports whether Noctalia accepted it.
--- ES: Inicia un proceso con argumentos argv e informa si Noctalia lo aceptó.
local function run(args, callback)
  local ok, accepted = pcall(noctalia.runAsync, args, callback)
  if not ok or accepted == false then
    noctalia.log("MusicPC could not start mpc command: " .. tostring(args[2] or args[1]))
    return false
  end
  return true
end

--- EN: Fetches the MPD queue and coalesces overlapping refresh requests; returns nothing.
--- ES: Obtiene la cola MPD y agrupa solicitudes de actualización simultáneas; no devuelve nada.
local function refreshQueue()
  if queueBusy then queueDirty = true; return end
  queueBusy = true
  queueDirty = false
  --- EN: Publishes the refreshed queue and runs one coalesced follow-up when requested.
  --- ES: Publica la cola actualizada y ejecuta una actualización agrupada si se pidió otra.
  local started = run({ "mpc", "-f", FORMAT, "playlist" }, safeCallback("queue", function(result)
    queueBusy = false
    if result.exitCode == 0 then publishIfChanged("player.queue", parseQueue(result.stdout)) end
    if queueDirty then refreshQueue() end
  end))
  if not started then queueBusy = false end
end

--- EN: Fetches saved playlist names and coalesces overlapping refresh requests; returns nothing.
--- ES: Obtiene nombres de playlists guardadas y agrupa solicitudes simultáneas; no devuelve nada.
local function refreshPlaylists()
  if playlistsBusy then playlistsDirty = true; return end
  playlistsBusy = true
  playlistsDirty = false
  --- EN: Publishes the refreshed playlist names and runs one coalesced follow-up if needed.
  --- ES: Publica los nombres actualizados y ejecuta otra consulta agrupada si hace falta.
  local started = run({ "mpc", "lsplaylists" }, safeCallback("playlists", function(result)
    playlistsBusy = false
    if result.exitCode == 0 then publishIfChanged("player.playlists", parsePlaylists(result.stdout)) end
    if playlistsDirty then refreshPlaylists() end
  end))
  if not started then playlistsBusy = false end
end

--- EN: Refreshes playback status and progress, reconciling optimistic UI state when permitted.
--- ES: Actualiza estado y progreso de reproducción, conciliando el estado optimista cuando corresponde.
local function refreshStatus()
  if statusBusy then return end
  statusBusy = true
  --- EN: Parses process output and reconciles player state after the optimistic window.
  --- ES: Interpreta la salida y concilia el estado del reproductor tras la ventana optimista.
  local started = run({ "mpc", "-f", FORMAT, "status" }, safeCallback("status", function(result)
    statusBusy = false
    if result.exitCode ~= 0 then
      if noctalia.nowMs() >= optimisticUntil then
        publishIfChanged("player", emptyPlayer("offline"))
        publishIfChanged("player.progress", { elapsed = "0:00", total = "0:00", percent = 0 })
      end
      return
    end
    local player, progress = parseStatus(result.stdout)
    local allowReconcile = noctalia.nowMs() >= optimisticUntil
    if allowReconcile then
      publishIfChanged("player", player)
      publishIfChanged("player.progress", progress)
    end

    local oldCount = tonumber(noctalia.state.get("player.queueCount")) or -1
    if player.count ~= oldCount then
      noctalia.state.set("player.queueCount", player.count)
      queueDirty = true
    end
    if queueDirty then refreshQueue() end
    ticks += 1
    if ticks % 15 == 0 then
      queueDirty = true
      refreshQueue()
    end
    if playlistsDirty or ticks % 60 == 0 then refreshPlaylists() end
  end))
  if not started then statusBusy = false end
end

--- EN: Starts mpc idleloop to refresh state promptly after MPD events; returns nothing.
--- ES: Inicia mpc idleloop para actualizar el estado al producirse eventos MPD; no devuelve nada.
local function startIdleLoop()
  --- EN: Routes each idle event to the narrowest relevant refresh operation.
  --- ES: Enruta cada evento idle a la actualización más específica que corresponde.
  local ok, accepted = pcall(noctalia.runStream, "mpc idleloop player playlist stored_playlist options", function(line)
    --- EN: Contains event-handler errors so the long-lived stream remains usable.
    --- ES: Contiene errores del manejador para mantener utilizable el flujo persistente.
    local callbackOk, callbackError = pcall(function()
      if string.find(line, "player", 1, true) then refreshStatus() end
      if string.find(line, "playlist", 1, true) then
        queueDirty = true
        refreshQueue()
      end
      if string.find(line, "stored_playlist", 1, true) then
        playlistsDirty = true
        refreshPlaylists()
      end
      if string.find(line, "options", 1, true) then refreshStatus() end
    end)
    if not callbackOk then noctalia.log("MusicPC idleloop callback failed: " .. tostring(callbackError)) end
  end)
  if not ok or accepted == false then noctalia.log("MusicPC mpc idleloop could not start; periodic refresh remains active") end
end

noctalia.setUpdateInterval(1000)
startIdleLoop()
refreshStatus()
refreshQueue()
refreshPlaylists()

--- EN: Refreshes MPD status when Noctalia calls this service entry; returns nothing.
--- ES: Actualiza el estado MPD cuando Noctalia llama a esta entrada de servicio; no devuelve nada.
local function update()
  refreshStatus()
end

--- EN: Refreshes queue and saved-playlist data when another entry increments the request token.
--- ES: Actualiza cola y playlists cuando otra entrada incrementa el token de solicitud.
noctalia.state.watch("player.queueRefresh", function()
  queueDirty = true
  refreshQueue()
  playlistsDirty = true
  refreshPlaylists()
end)

--- EN: Tracks the end of the optimistic reconciliation window published by player actions.
--- ES: Registra el final de la ventana de conciliación optimista publicada por las acciones.
noctalia.state.watch("player.optimisticUntil", function(value)
  optimisticUntil = tonumber(value) or 0
end)

return { update = update }