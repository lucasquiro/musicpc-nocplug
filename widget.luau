--!nonstrict
local playerActions = require("./lib/player_actions.luau")
local currentPlayer = noctalia.state.get("player") or {}
local currentProgress = noctalia.state.get("player.progress") or {}
currentPlayer.elapsed = currentProgress.elapsed or "0:00"
currentPlayer.total = currentProgress.total or "0:00"

-- Ajusta este número para mostrar más o menos letras del título en la barra.
local TITLE_VISIBLE_CHARACTERS = 16
local MARQUEE_SPACER = "   "
local marqueeTitle = ""
local marqueeOffset = 0

local function utf8Slice(text, startCharacter, characterCount)
  local startByte = utf8.offset(text, startCharacter)
  if not startByte then return "" end
  local endByte = utf8.offset(text, startCharacter + characterCount)
  return string.sub(text, startByte, endByte and endByte - 1 or #text)
end

local function visibleTitle(title)
  if title ~= marqueeTitle then
    marqueeTitle = title
    marqueeOffset = 0
  end
  local length = utf8.len(title) or #title
  if length <= TITLE_VISIBLE_CHARACTERS then return title end

  local spacerLength = utf8.len(MARQUEE_SPACER) or #MARQUEE_SPACER
  local cycleLength = length + spacerLength
  local ticker = title .. MARQUEE_SPACER .. title
  return utf8Slice(ticker, (marqueeOffset % cycleLength) + 1, TITLE_VISIBLE_CHARACTERS)
end

local function render(p)
  -- Dibuja el título y los controles usando el último estado publicado.
  p = p or { state = "offline", title = "", artist = "", elapsed = "0:00", total = "0:00" }
  local title = p.state == "offline" and "MPD apagado" or p.title
  if p.state == "stopped" or title == "" then title = "Sin reproducir" end
  barWidget.render(ui.row({ gap = 6, align = "center" }, {
    -- tamanio de todo el reprodutor en la barra
    ui.row({
      width = 120,
      paddingH = 8,
      fill = "surface/0.55",
      radius = 12,
      tooltip = title,
      onClick = "openQueue",
    }, {
      ui.label({ text = visibleTitle(title), width = 104, maxLines = 1 }),
    }),
    -- Boton de pausa de la barra
    ui.button({
      glyph = p.state == "playing" and "player-pause" or "player-play",
      glyphSize = 14,
      variant = "ghost",
      tooltip = p.state == "playing" and "Pausar" or "Reproducir",
      onClick = "togglePlayback",
    }),
    -- boton de retroceder en la barra
    ui.button({
      glyph = "player-skip-back",
      glyphSize = 14,
      variant = "ghost",
      tooltip = "Volver atrás",
      onClick = "previousTrack",
    }),
    ui.button({
      glyph = "player-skip-forward",
      glyphSize = 14,
      variant = "ghost",
      tooltip = "Siguiente",
      onClick = "nextTrack",
    }),
  }))
  if p.state ~= "offline" and p.title ~= "" then
    barWidget.setTooltip({
      { "Título", p.title },
      { "Artista", p.artist ~= "" and p.artist or "-" },
      { "Tiempo", p.elapsed .. " / " .. p.total },
    })
  else
    barWidget.clearTooltip()
  end
end

noctalia.state.watch("player", function(player)
  currentPlayer = player or {}
  currentProgress = noctalia.state.get("player.progress") or {}
  currentPlayer.elapsed = currentProgress.elapsed or "0:00"
  currentPlayer.total = currentProgress.total or "0:00"
  render(currentPlayer)
end)

noctalia.state.watch("player.progress", function(progress)
  currentProgress = progress or {}
  currentPlayer.elapsed = currentProgress.elapsed or "0:00"
  currentPlayer.total = currentProgress.total or "0:00"
  render(currentPlayer)
end)
render(currentPlayer)
noctalia.setUpdateInterval(250)

function update()
  local title = currentPlayer.state == "offline" and "MPD apagado" or currentPlayer.title or ""
  if currentPlayer.state == "stopped" or title == "" then title = "Sin reproducir" end
  if (utf8.len(title) or #title) <= TITLE_VISIBLE_CHARACTERS then return end
  marqueeOffset += 1
  render(currentPlayer)
end

function onClick()
  -- Acción general del widget: abrir el panel de la cola.
  openQueue()
end

function togglePlayback()
  playerActions.playPause(currentPlayer)
end

function previousTrack()
  playerActions.skip(currentPlayer, -1)
end

function nextTrack()
  playerActions.skip(currentPlayer, 1)
end

function openQueue()
  if noctalia.state.get("musicpc.panelOpen") == true then
    local request = tonumber(noctalia.state.get("musicpc.closeRequest")) or 0
    noctalia.state.set("musicpc.closeRequest", request + 1)
  else
    noctalia.togglePanel("lucasquiro/musicpc-nocplug:queue")
  end
end
