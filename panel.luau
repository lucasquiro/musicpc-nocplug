--!nonstrict

-- Panel desplegable: reproductor arriba y pestañas Cola / Playlists / Biblioteca.

local mpc = require("./mpc.luau")
local playerActions = require("./lib/player_actions.luau")
local playlistOps = nil
local opened = false
local playlistName = ""
local playlistTrack = nil
local playlistPosition = nil
local seekDraft = nil
local tab = "queue"          -- "queue" | "playlists" | "library"
local library = nil
local libraryPage = 1
local libraryHasPrevious = false
local libraryHasNext = false
local libraryHasMorePages = false
local libraryPages = {}
local libraryLoading = false
local libraryReloadPending = false
local LIBRARY_LIMIT = 25
local QUEUE_RENDER_LIMIT = 40
local PLAYLIST_RENDER_LIMIT = 30
local render
local cachedListContent = nil
local listContentDirty = true
local currentPlayer = noctalia.state.get("player") or {}
local currentProgress = noctalia.state.get("player.progress") or {}
currentPlayer.queue = noctalia.state.get("player.queue") or {}
currentPlayer.playlists = noctalia.state.get("player.playlists") or {}
currentPlayer.elapsed = currentProgress.elapsed or "0:00"
currentPlayer.total = currentProgress.total or "0:00"
currentPlayer.percent = currentProgress.percent or 0
local expanded = true
local listProgress = 0
local playerOpacity = 1
local closing = false
local closeRequestToken = tonumber(noctalia.state.get("musicpc.closeRequest")) or 0
local coverTrack = ""
local coverPath = nil
local coverLoading = false
local mascotAnimation = "sleep"
local mascotTarget = nil
local mascotFrame = 0
local mascotAccumulator = 0
local MASCOT_FRAME_COUNTS = { music = 51, sleep = 51, wake = 16, sleep_back = 16 }
local lastRendered = 0     -- último valor que dibujamos en el slider
local lastFile = ""        -- para detectar cambio de canción
local queueRefreshToken = tonumber(noctalia.state.get("player.queueRefresh")) or 0
local function getPlaylistOps()
  if playlistOps == nil then playlistOps = require("./lib/playlist_ops.luau") end
  return playlistOps
end
local function truncateText(text, maxCharacters)
  local length = utf8.len(text)
  if length and length > maxCharacters then
    local offset = utf8.offset(text, maxCharacters + 1)
    if offset then return string.sub(text, 1, offset - 1) .. "…" end
  end
  return text
end


local function requestQueueRefresh()
  queueRefreshToken += 1
  noctalia.state.set("player.queueRefresh", queueRefreshToken)
end

local function playTrack(position)
  mpc.play(position)
end

local function moveTrack(fromPosition, toPosition)
  if fromPosition == toPosition then return end
  mpc.move(fromPosition, toPosition, function(result)
    if result.exitCode ~= 0 then
      noctalia.notifyError("No se pudo cambiar el orden", result.stderr)
    else
      requestQueueRefresh()
    end
  end)
end

local function addTrackToPlaylist(name, track)
  getPlaylistOps().addTrack(name, track.file, function(result)
    if result.exitCode ~= 0 then
      noctalia.notifyError("No se pudo añadir a la playlist", result.stderr)
    else
      noctalia.notify("Canción añadida a la playlist", name)
      requestQueueRefresh()
    end
  end)
end

local function saveTrackToNewPlaylist()
  local name = noctalia.string.trim(playlistName)
  if name == "" or not playlistTrack then return end
  local track = playlistTrack
  getPlaylistOps().addTrack(name, track.file, function(result)
    if result.exitCode ~= 0 then
      noctalia.notifyError("No se pudo crear la playlist", result.stderr)
    else
      noctalia.notify("Playlist creada", name)
      playlistName = ""
      playlistTrack = nil
      playlistPosition = nil
      listContentDirty = true
      requestQueueRefresh()
      render(currentPlayer)
    end
  end)
end

local mediaHelper

-- Carga la lista de canciones de la biblioteca de MPD (solo al pedirla).
local function loadLibrary(page)
  if libraryLoading then libraryReloadPending = true; return end
  libraryPage = math.max(1, tonumber(page) or 1)
  libraryLoading = true
  library = nil
  mediaHelper("library-page", { libraryPage, LIBRARY_LIMIT }, function(result)
    libraryLoading = false
    if libraryReloadPending then
      libraryReloadPending = false
      loadLibrary(libraryPage)
      return
    end
    if result.exitCode == 0 then
      local ok, decoded = pcall(noctalia.json.decode, result.stdout or "")
      if ok and type(decoded) == "table" then
        library = decoded.tracks or {}
        libraryPage = tonumber(decoded.page) or libraryPage
        libraryHasPrevious = decoded.hasPrevious == true
        libraryHasNext = decoded.hasNext == true
        libraryHasMorePages = decoded.hasMorePages == true
        libraryPages = decoded.pages or {}
      else
        library = {}
        noctalia.notifyError("No se pudo leer la biblioteca", "Respuesta de páginas no válida")
      end
    else
      library = {}
      noctalia.notifyError("No se pudo leer la biblioteca", result.stderr)
    end
    listContentDirty = true
    render(currentPlayer)
  end)
end

-- Añade una canción de la biblioteca a la cola; si la cola estaba vacía, la reproduce.
local function addSong(file)
  local player = noctalia.state.get("player")
  local position = ((player and player.count) or 0) + 1
  mpc.add(file, function(result)
    if result.exitCode ~= 0 then
      noctalia.notifyError("No se pudo añadir", result.stderr)
    else
      mpc.play(position, function(playResult)
        if playResult.exitCode ~= 0 then
          noctalia.notifyError("No se pudo reproducir la canción", playResult.stderr)
        end
      end)
    end
  end)
end

mediaHelper = function(action, args, callback)
  local function deliver(result)
    local callbackOk, callbackError = pcall(callback, result)
    if not callbackOk then noctalia.log("MusicPC media callback failed: " .. tostring(callbackError)) end
  end
  local pluginDir = noctalia.pluginDir()
  if not pluginDir then
    deliver({ exitCode = 1, stdout = "", stderr = "No se pudo localizar el plugin" })
    return
  end
  local command = { "python3", pluginDir .. "/media_files.py", action }
  for _, argument in ipairs(args) do
    table.insert(command, tostring(argument))
  end
  local ok, accepted = pcall(noctalia.runAsync, command, deliver)
  if not ok or accepted == false then
    deliver({ exitCode = 1, stdout = "", stderr = "No se pudo iniciar la operación de archivo" })
  end
end

local function requestCover(file)
  if file == coverTrack then return end
  coverTrack = file or ""
  coverPath = nil
  coverLoading = coverTrack ~= ""
  if not coverLoading then return end
  local dataDir = noctalia.pluginDataDir()
  if not dataDir then
    coverLoading = false
    return
  end
  mediaHelper("cover", { coverTrack, dataDir .. "/covers" }, function(result)
    if coverTrack ~= file then return end
    coverLoading = false
    local path = noctalia.string.trim(result.stdout or "")
    coverPath = result.exitCode == 0 and path ~= "" and path or nil
    render(currentPlayer)
  end)
end

-- Añade toda la biblioteca a la cola y empieza a reproducir.
function addAllLibrary()
  mpc.add("/", function(result)
    if result.exitCode == 0 then
      mpc.play()
    else
      noctalia.notifyError("No se pudo añadir la biblioteca", result.stderr)
    end
  end)
end

function savePlaylist()
  local name = noctalia.string.trim(playlistName)
  if name == "" then return end
  getPlaylistOps().save(name, function(result)
    if result.exitCode == 0 then
      noctalia.notify("Playlist guardada", name)
      playlistName = ""
      listContentDirty = true
      requestQueueRefresh()
      render(currentPlayer)
    else
      noctalia.notifyError("No se pudo guardar la playlist", result.stderr)
    end
  end)
end

local function loadPlaylist(name)
  getPlaylistOps().load(name, function(result)
    if result.exitCode ~= 0 then
      noctalia.notifyError("No se pudo cargar la playlist", result.stderr)
    else
      requestQueueRefresh()
    end
  end)
end

function showQueue() tab = "queue"; listContentDirty = true; render(currentPlayer) end
function showPlaylists() tab = "playlists"; listContentDirty = true; render(currentPlayer) end
function showLibrary()
  tab = "library"
  listContentDirty = true
  if library == nil then loadLibrary() end
  render(currentPlayer)
end
function reloadLibrary()
  library = nil
  listContentDirty = true
  loadLibrary(libraryPage)
  render(currentPlayer)
end

function showLibraryPage(page)
  if page == libraryPage or page < 1 then return end
  listContentDirty = true
  loadLibrary(page)
  render(currentPlayer)
end

local function queueView(player)
  local queue = player.queue or {}
  local rows = {}
  local function newPlaylistRow(position)
    return ui.row({ key = "new-track-playlist-" .. tostring(position), gap = 6, align = "center" }, {
      ui.input({
        key = "new-track-playlist-name-" .. tostring(position),
        flexGrow = 1,
        placeholder = "Nombre de la nueva playlist",
        value = playlistName,
        focus = true,
        onChange = function(value) playlistName = value end,
        onSubmit = function(value) playlistName = value; saveTrackToNewPlaylist() end,
      }),
      ui.button({
        glyph = "device-floppy",
        variant = "secondary",
        tooltip = "Crear playlist y añadir canción",
        onClick = function() saveTrackToNewPlaylist() end,
      }),
      ui.button({
        glyph = "close",
        variant = "ghost",
        tooltip = "Cancelar",
        onClick = function() playlistTrack = nil; playlistPosition = nil; playlistName = ""; listContentDirty = true; render(player) end,
      }),
    })
  end
  local firstPosition = 1
  if #queue > QUEUE_RENDER_LIMIT and player.position > 0 then
    firstPosition = math.max(1, math.min(player.position - math.floor(QUEUE_RENDER_LIMIT / 2), #queue - QUEUE_RENDER_LIMIT + 1))
  end
  local lastPosition = math.min(#queue, firstPosition + QUEUE_RENDER_LIMIT - 1)
  if #queue > QUEUE_RENDER_LIMIT then
    table.insert(rows, ui.label({
      text = "Mostrando " .. tostring(firstPosition) .. "-" .. tostring(lastPosition) .. " de " .. tostring(#queue),
      color = "on_surface/0.7",
      fontSize = 12,
    }))
  end
  for position = firstPosition, lastPosition do
    if playlistTrack and position == playlistPosition then
      table.insert(rows, newPlaylistRow(position))
    end
    local track = queue[position]
    local title = track.title ~= "" and track.title or track.file
    local label = track.artist ~= "" and (track.artist .. " - " .. title) or title
    local current = position == player.position
    if current then
      label = (player.state == "playing" and "♪  " or "Ⅱ  ") .. label
    end
    table.insert(rows, ui.dropZone({
      key = "queue-drop-" .. tostring(position),
      accepts = { "musicpc-queue-track" },
      value = tostring(position),
      direction = "row",
      onDrop = function(payload, target)
        local fromPosition = tonumber(payload)
        local toPosition = tonumber(target)
        if fromPosition and toPosition then
          moveTrack(fromPosition, toPosition)
        end
      end,
    }, {
      ui.row({ gap = 4, align = "center" }, {
        ui.dragSource({
          key = "queue-drag-" .. tostring(position),
          dragType = "musicpc-queue-track",
          payload = tostring(position),
          previewAncestor = 1,
          tooltip = "Arrastrar para cambiar el orden",
        }, {
          ui.button({
            glyph = "grip-horizontal",
            variant = "ghost",
            tooltip = "Arrastrar para cambiar el orden",
          }),
        }),
        ui.button({
          key = "track-" .. tostring(position),
          text = truncateText(label, 42),
          flexGrow = 1,
          contentAlign = "start",
          variant = current and "secondary" or "ghost",
          tooltip = label,
          onClick = function() playTrack(position) end,
          onRightClick = function()
            local items = {
              { kind = "header", label = label },
              { kind = "header", label = "Añadir a playlist" },
            }
            for index, name in ipairs(player.playlists or {}) do
              table.insert(items, { id = "playlist-" .. tostring(index), label = name })
            end
            table.insert(items, { id = "create-playlist", label = "Crear playlist nueva…" })
            table.insert(items, { kind = "separator" })
            table.insert(items, { id = "remove-track", label = "Quitar de la cola" })
            panel.openContextMenu({
              items = items,
              onActivate = "onQueueContextAction",
              context = position,
              maxVisible = 12,
            })
          end,
        }),
      }),
    }))
  end
  if playlistTrack and (#queue == 0 or playlistPosition < firstPosition or playlistPosition > lastPosition) then
    table.insert(rows, 1, newPlaylistRow(playlistPosition or 0))
  end
  if #rows == 0 then
    table.insert(rows, ui.label({ text = "La cola está vacía.", color = "on_surface/0.7" }))
    table.insert(rows, ui.button({ text = "Añadir toda la biblioteca y reproducir", glyph = "playlist-add", variant = "primary", onClick = "addAllLibrary" }))
    table.insert(rows, ui.label({ text = "O elige canciones en la pestaña Biblioteca.", color = "on_surface/0.7", fontSize = 12 }))
  end
  return rows
end

local function playlistsView(player)
  local rows = {
    ui.row({ gap = 6, align = "center" }, {
      ui.input({ key = "playlist-name", flexGrow = 1, placeholder = "Guardar cola como…", value = playlistName,
        onChange = function(value) playlistName = value end,
        onSubmit = function(value) playlistName = value; savePlaylist() end }),
      ui.button({ glyph = "device-floppy", variant = "secondary", tooltip = "Guardar cola como playlist", onClick = "savePlaylist" }),
    }),
  }
  local playlists = player.playlists or {}
  for index = 1, math.min(#playlists, PLAYLIST_RENDER_LIMIT) do
    local name = playlists[index]
    table.insert(rows, ui.button({
      key = "playlist-" .. name,
      text = truncateText(name, 42),
      contentAlign = "start",
      variant = "ghost",
      onClick = function() loadPlaylist(name) end,
    }))
  end
  if #playlists == 0 then
    table.insert(rows, ui.label({ text = "No hay playlists guardadas", color = "on_surface/0.7" }))
  elseif #playlists > PLAYLIST_RENDER_LIMIT then
    table.insert(rows, ui.label({ text = "Mostrando las primeras " .. tostring(PLAYLIST_RENDER_LIMIT) .. " de " .. tostring(#playlists), color = "on_surface/0.7", fontSize = 12 }))
  end
  return rows
end

local function libraryView()
  local rows = {}
  if libraryLoading or library == nil then
    table.insert(rows, ui.label({ text = "Cargando biblioteca…", color = "on_surface/0.7" }))
    return rows
  end
  table.insert(rows, ui.row({ gap = 6, align = "center" }, {
    ui.label({ text = "Página " .. tostring(libraryPage), color = "on_surface/0.7", flexGrow = 1 }),
    ui.button({ glyph = "refresh", variant = "ghost", tooltip = "Recargar biblioteca", onClick = "reloadLibrary" }),
  }))
  for i, file in ipairs(library) do
    local filename = string.match(file, "([^/]+)$") or file
    local displayName = string.gsub(filename, "%.[^%.]+$", "")
    table.insert(rows, ui.button({
      key = "lib-" .. tostring(i),
      text = truncateText(displayName, 42),
      contentAlign = "start",
      variant = "ghost",
      tooltip = file,
      onClick = function() addSong(file) end,
      onRightClick = function()
        panel.openContextMenu({
          items = {
            { id = "trash-track", label = "Eliminar" },
            { id = "edit-tags", label = "Editar metadatos" },
          },
          onActivate = "onLibraryContextAction",
          context = file,
        })
      end,
    }))
  end
  if #libraryPages > 1 or libraryHasPrevious or libraryHasNext then
    local controls = {}
    table.insert(controls, ui.button({ glyph = "chevron-left", variant = "ghost", tooltip = "Página anterior", enabled = libraryHasPrevious, onClick = function() showLibraryPage(libraryPage - 1) end }))
    if libraryPage > 1 then
      table.insert(controls, ui.label({ text = "…", color = "on_surface/0.7" }))
    end
    for _, page in ipairs(libraryPages) do
      local pageNumber = page
      table.insert(controls, ui.button({
        key = "library-page-" .. tostring(pageNumber),
        text = tostring(pageNumber),
        variant = pageNumber == libraryPage and "secondary" or "ghost",
        selected = pageNumber == libraryPage,
        onClick = function() showLibraryPage(pageNumber) end,
      }))
    end
    if libraryHasMorePages then
      table.insert(controls, ui.label({ text = "…", color = "on_surface/0.7" }))
    end
    table.insert(controls, ui.button({ glyph = "chevron-right", variant = "ghost", tooltip = "Página siguiente", enabled = libraryHasNext, onClick = function() showLibraryPage(libraryPage + 1) end }))
    table.insert(rows, ui.row({ gap = 4, align = "center", justify = "center" }, controls))
  end
  if #library == 0 then
    table.insert(rows, ui.label({ text = "MPD no tiene canciones. Revisa music_directory y ejecuta `mpc update`.", color = "on_surface/0.7" }))
  end
  return rows
end

local function selectMascot(player)
  local target = player.state == "playing" and "music" or "sleep"
  if mascotTarget == nil then
    mascotTarget = target
    mascotAnimation = target == "music" and "wake" or "sleep"
    mascotFrame = 0
  elseif target ~= mascotTarget then
    mascotTarget = target
    mascotAnimation = target == "music" and "wake" or "sleep_back"
    mascotFrame = 0
  end
end

local function mascotPath()
  return string.format("assets/frames/%s/f_%03d.png", mascotAnimation, mascotFrame)
end

render = function(player)
  if not opened then return end
  player = player or currentPlayer or {}
  currentPlayer = player
  selectMascot(player)
  local currentTitle = (player.title or "") ~= "" and player.title or "Sin reproducir"
  requestCover(player.file or "")
    -- Si cambió la canción, se descarta cualquier valor arrastrado antes.
  if (player.file or "") ~= lastFile then
    lastFile = player.file or ""
    seekDraft = nil
  end
  local sliderValue = seekDraft ~= nil and seekDraft or (player.percent or 0)
  lastRendered = sliderValue

  if listContentDirty or cachedListContent == nil then
    if tab == "playlists" then cachedListContent = playlistsView(player)
    elseif tab == "library" then cachedListContent = libraryView()
    else cachedListContent = queueView(player) end
    listContentDirty = false
  end

  local function tabButton(id, label, action)
    return ui.button({ text = label, variant = tab == id and "secondary" or "ghost", selected = tab == id, onClick = action, flexGrow = 1 })
  end

  local children = {
    ui.row({ gap = 8, align = "center" }, {
      coverPath and ui.image({ key = "music-cover", path = coverPath, width = 76, height = 76, radius = 38, fit = "cover", border = "outline", borderWidth = 1 })
        or ui.image({ key = "music-mascot", path = mascotPath(), width = 76, height = 76, fit = "contain" }),
      ui.column({ gap = 2, flexGrow = 1, align = "stretch" }, {
        ui.label({ text = currentTitle, fontSize = 16, fontWeight = "bold", maxLines = 1 }),
        ui.label({ text = (player.artist or "") ~= "" and player.artist or (player.state == "offline" and "MPD apagado" or "Artista desconocido"), color = "on_surface/0.7", fontSize = 12, maxLines = 1 }),
      }),
    }),
    ui.row({ gap = 6, align = "center" }, {
      ui.label({ text = player.elapsed or "0:00", width = 42, fontSize = 12 }),
      ui.slider({
        key = "seek-slider", flexGrow = 1, min = 0, max = 100,
        value = sliderValue,
        onChange = function(value)
          value = tonumber(value) or 0
          -- Ignora el "eco" cuando el host solo aplica el valor que le dimos.
          if math.abs(value - lastRendered) < 1 then return end
          seekDraft = value
        end,
        onDragEnd = function()
          if seekDraft ~= nil then
            mpc.seekPercent(seekDraft)
          end
          seekDraft = nil
        end,
      }),
      ui.label({ text = player.total or "0:00", width = 42, fontSize = 12, textAlign = "end" }),
    }),
    ui.row({ gap = 8, align = "center", justify = "center" }, {
      ui.button({ glyph = "arrows-shuffle", variant = "ghost", selected = player.random == true, tooltip = "Aleatorio", onClick = "toggleRandom" }),
      ui.button({ glyph = "player-skip-back", variant = "ghost", tooltip = "Anterior", onClick = "previousTrack" }),
      ui.button({ glyph = player.state == "playing" and "player-pause" or "player-play", variant = "primary", controlSize = "lg", tooltip = "Reproducir o pausar", onClick = "togglePlayback" }),
      ui.button({ glyph = "player-skip-forward", variant = "ghost", tooltip = "Siguiente", onClick = "nextTrack" }),
      ui.button({
        glyph = player.repeatMode == "one" and "repeat-1" or "repeat",
        variant = "ghost",
        selected = player.repeatMode == "all" or player.repeatMode == "one" or player.repeatMode == true,
        tooltip = player.repeatMode == "one" and "Repetir canción" or player.repeatMode == "all" and "Repetir cola" or "Repetición desactivada",
        onClick = "toggleRepeat",
      }),
    }),
  }
  if expanded and listProgress > 0 then
    table.insert(children, ui.column({
      key = "expanded-lists",
      height = math.max(1, math.floor(220 * listProgress)),
      opacity = listProgress,
      gap = 6,
      align = "stretch",
    }, {
      ui.row({ gap = 6 }, {
        tabButton("queue", "Cola", "showQueue"),
        tabButton("playlists", "Playlists", "showPlaylists"),
        tabButton("library", "Biblioteca", "showLibrary"),
      }),
      ui.scroll({ flexGrow = 1, gap = 3, padding = 6, fill = "surface/0.35", radius = 8,
        revealKey = playlistTrack and "new-track-playlist-" .. tostring(playlistPosition or 0) or nil }, cachedListContent),
    }))
  end
  panel.render(ui.column({ gap = 10, padding = 14, fill = "surface", radius = 12, align = "stretch", opacity = playerOpacity }, children))
  local animatingMascot = not coverPath and (mascotAnimation == "wake" or mascotAnimation == "sleep_back")
  panel.setNeedsFrameTick(opened and (closing or animatingMascot))
end

noctalia.state.watch("player", function(player)
  currentPlayer = player or {}
  currentPlayer.queue = noctalia.state.get("player.queue") or {}
  currentPlayer.playlists = noctalia.state.get("player.playlists") or {}
  local progress = noctalia.state.get("player.progress") or {}
  currentPlayer.elapsed = progress.elapsed or "0:00"
  currentPlayer.total = progress.total or "0:00"
  currentPlayer.percent = progress.percent or 0
  listContentDirty = true
  render(currentPlayer)
end)

noctalia.state.watch("player.progress", function(progress)
  currentProgress = progress or {}
  currentPlayer.elapsed = currentProgress.elapsed or "0:00"
  currentPlayer.total = currentProgress.total or "0:00"
  currentPlayer.percent = currentProgress.percent or 0
  render(currentPlayer)
end)

noctalia.state.watch("player.queue", function(queue)
  currentPlayer.queue = queue or {}
  listContentDirty = true
  render(currentPlayer)
end)

noctalia.state.watch("player.playlists", function(playlists)
  currentPlayer.playlists = playlists or {}
  listContentDirty = true
  render(currentPlayer)
end)

noctalia.state.watch("musicpc.updatedTrack", function(track)
  if type(track) ~= "table" or not track.old or not track.new or track.old == track.new then return end
  library = nil
  listContentDirty = true
  if tab == "library" then loadLibrary(libraryPage) end
  render(currentPlayer)
end)

noctalia.state.watch("musicpc.closeRequest", function(value)
  local token = tonumber(value) or 0
  if token == closeRequestToken then return end
  closeRequestToken = token
  if opened then
    closing = true
    panel.setNeedsFrameTick(true)
  end
end)

function onOpen()
  opened = true
  closing = false
  playerOpacity = 1
  noctalia.state.set("musicpc.panelOpen", true)
  currentPlayer = noctalia.state.get("player") or {}
  mascotTarget = nil
  mascotFrame = 0
  mascotAccumulator = 0
  expanded = true
  listProgress = 1
  currentPlayer.queue = noctalia.state.get("player.queue") or {}
  currentPlayer.playlists = noctalia.state.get("player.playlists") or {}
  currentProgress = noctalia.state.get("player.progress") or {}
  currentPlayer.elapsed = currentProgress.elapsed or "0:00"
  currentPlayer.total = currentProgress.total or "0:00"
  currentPlayer.percent = currentProgress.percent or 0
  panel.setNeedsFrameTick(false)
  render(currentPlayer)
end

function onClose()
  opened = false
  closing = false
  noctalia.state.set("musicpc.panelOpen", false)
  panel.setNeedsFrameTick(false)
end

function onFrameTick(deltaMs)
  if not opened then return end
  mascotAccumulator += tonumber(deltaMs) or 16
  if mascotAccumulator < 80 then return end
  mascotAccumulator %= 80
  local changed = false
  if not closing and not coverPath and (mascotAnimation == "wake" or mascotAnimation == "sleep_back") then
    mascotFrame += 1
    local frameCount = MASCOT_FRAME_COUNTS[mascotAnimation] or 1
    if mascotFrame >= frameCount then
      if mascotAnimation == "wake" or mascotAnimation == "sleep_back" then
        mascotAnimation = mascotTarget or "sleep"
      end
      mascotFrame = 0
    end
    changed = true
  end
  if closing then
    playerOpacity = math.max(0, playerOpacity - 0.22)
    changed = true
    if playerOpacity == 0 then
      panel.close()
      return
    end
  end
  if changed then render(currentPlayer) end
end

function closePanel() panel.close() end
function togglePlayback() playerActions.playPause(currentPlayer) end
function previousTrack() playerActions.skip(currentPlayer, -1) end
function nextTrack() playerActions.skip(currentPlayer, 1) end

function toggleRandom()
  playerActions.random(currentPlayer)
end

function toggleRepeat()
  playerActions.cycleRepeatMode(currentPlayer)
end

function onQueueContextAction(actionId, context)
  local position = tonumber(context)
  local player = currentPlayer
  player.queue = noctalia.state.get("player.queue") or {}
  player.playlists = noctalia.state.get("player.playlists") or {}
  local track = position and (player.queue or {})[position]
  if not track then return end

  if actionId == "create-playlist" then
    playlistTrack = track
    playlistPosition = position
    playlistName = ""
    listContentDirty = true
    render(player)
  elseif actionId == "remove-track" then
    mpc.del(position, function(result)
      if result.exitCode ~= 0 then
        noctalia.notifyError("No se pudo quitar de la cola", result.stderr)
      else
        requestQueueRefresh()
      end
    end)
  else
    local playlistIndex = tonumber(string.match(actionId, "^playlist%-(%d+)$"))
    local name = playlistIndex and (player.playlists or {})[playlistIndex]
    if name then addTrackToPlaylist(name, track) end
  end
end

function onLibraryContextAction(actionId, file)
  if actionId == "edit-tags" then
    noctalia.state.set("musicpc.editTrack", file)
    noctalia.togglePanel("lucasquiro/musicpc-nocplug:editor")
  elseif actionId == "trash-track" then
    mediaHelper("trash", { file }, function(result)
      if result.exitCode ~= 0 then
        noctalia.notifyError("No se pudo mover a la papelera", result.stderr)
      else
        noctalia.notify("Canción movida a la papelera", file)
        if library then
          for index, libraryFile in ipairs(library) do
            if libraryFile == file then table.remove(library, index); break end
          end
        end
        requestQueueRefresh()
        render(currentPlayer)
      end
    end)
  end
end
