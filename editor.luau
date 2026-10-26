--!nonstrict

local opened = false
local busy = false
local confirmDiscard = false
local confirmOverwrite = false
local metadataOps = nil
local file = ""
local filename = ""
local originalFilename = ""
local metadataLoaded = false
local tags = {}
local original = {}
local fields = {
  { key = "title", label = "Título" },
  { key = "artist", label = "Artista" },
  { key = "album", label = "Álbum" },
  { key = "album_artist", label = "Artista del álbum" },
  { key = "date", label = "Año / fecha" },
  { key = "genre", label = "Género" },
  { key = "track", label = "Número de pista" },
  { key = "disc", label = "Número de disco" },
  { key = "composer", label = "Compositor" },
  { key = "performer", label = "Intérprete" },
  { key = "publisher", label = "Editorial" },
  { key = "bpm", label = "BPM" },
  { key = "comment", label = "Comentario" },
  { key = "filename", label = "Nombre del archivo (.mp3)" },
}

local function dirty()
  for _, field in ipairs(fields) do
    local currentValue = field.key == "filename" and filename or tags[field.key]
    local originalValue = field.key == "filename" and originalFilename or original[field.key]
    if (currentValue or "") ~= (originalValue or "") then return true end
  end
  return false
end

local function getMetadataOps()
  if metadataOps == nil then metadataOps = require("./lib/metadata_editor.luau") end
  return metadataOps
end

local function render()
  if not opened then return end
  if confirmDiscard then
    panel.render(ui.column({ padding = 18, gap = 12, fill = "surface", radius = 12, align = "stretch" }, {
      ui.label({ text = "Hay cambios sin guardar", fontSize = 17, fontWeight = "bold" }),
      ui.label({ text = "¿Quieres guardar los metadatos antes de salir?", color = "on_surface/0.75" }),
      ui.row({ gap = 8, justify = "end" }, {
        ui.button({ text = "Seguir editando", variant = "ghost", onClick = "continueEditing" }),
        ui.button({ text = "Descartar", variant = "secondary", onClick = "discardChanges" }),
        ui.button({ text = "Guardar", variant = "primary", enabled = not busy, onClick = "saveMetadata" }),
      }),
    }))
    return
  end
  if confirmOverwrite then
    panel.render(ui.column({ padding = 18, gap = 12, fill = "surface", radius = 12, align = "stretch" }, {
      ui.label({ text = "El archivo ya existe", fontSize = 17, fontWeight = "bold" }),
      ui.label({ text = "¿Quieres reemplazar " .. filename .. "?", color = "on_surface/0.75", maxLines = 2 }),
      ui.row({ gap = 8, justify = "end" }, {
        ui.button({ text = "Cancelar", variant = "ghost", onClick = "cancelOverwrite" }),
        ui.button({ text = "Reemplazar", variant = "destructive", enabled = not busy, onClick = "confirmOverwriteSave" }),
      }),
    }))
    return
  end

  local rows = {}
  if busy then
    table.insert(rows, ui.label({ text = "Procesando archivo…", color = "on_surface/0.7" }))
  end
  for _, field in ipairs(fields) do
    table.insert(rows, ui.column({ key = "field-" .. field.key, gap = 3, align = "stretch" }, {
      ui.label({ text = field.label, fontSize = 12, color = "on_surface/0.75" }),
      ui.input({
        key = "input-" .. field.key .. "-" .. file .. "-" .. tostring(metadataLoaded),
        value = field.key == "filename" and filename or tags[field.key] or "",
        placeholder = field.label,
        enabled = not busy,
        onChange = function(value)
          if field.key == "filename" then filename = value else tags[field.key] = value end
        end,
      }),
    }))
  end

  panel.render(ui.column({ height = 452, padding = 14, gap = 10, fill = "surface", radius = 12, align = "stretch" }, {
    ui.row({ gap = 8, align = "center" }, {
      ui.column({ flexGrow = 1, gap = 2 }, {
        ui.label({ text = "Editar metadatos", fontSize = 16, fontWeight = "bold" }),
        ui.label({ text = file:match("([^/]+)$") or file, fontSize = 12, color = "on_surface/0.7", maxLines = 1 }),
      }),
      ui.button({ glyph = "close", variant = "ghost", tooltip = "Cerrar edición", onClick = "requestClose" }),
    }),
    ui.scroll({ flexGrow = 1, gap = 8, padding = 2 }, rows),
    ui.row({ gap = 8, justify = "end" }, {
      ui.button({ text = "Cancelar", variant = "ghost", enabled = not busy, onClick = "requestClose" }),
      ui.button({ text = "Guardar cambios", glyph = "device-floppy", variant = "primary", enabled = not busy, onClick = "saveMetadata" }),
    }),
  }))
end

local function closeEditor()
  opened = false
  noctalia.state.set("musicpc.editTrack", nil)
  panel.close()
  noctalia.togglePanel("lucasquiro/musicpc-nocplug:queue")
end

function onOpen()
  opened = true
  busy = true
  confirmDiscard = false
  confirmOverwrite = false
  file = tostring(noctalia.state.get("musicpc.editTrack") or "")
  metadataLoaded = false
  tags = {}
  original = {}
  filename = file:match("([^/]+)$") or file
  originalFilename = filename
  render()
  if file == "" then
    busy = false
    noctalia.notifyError("Editor", "No se pudo abrir la canción seleccionada")
    render()
    return
  end
  getMetadataOps().read(file, function(result)
    busy = false
    if result.exitCode ~= 0 then
      noctalia.notifyError("No se pudieron leer los metadatos", result.stderr)
    else
      local ok, decoded = pcall(noctalia.json.decode, result.stdout or "")
      if ok and type(decoded) == "table" then
        tags = decoded
        original = table.clone(decoded)
        metadataLoaded = true
      else
        noctalia.notifyError("Editor", "Respuesta de metadatos no válida")
      end
    end
    render()
  end)
end

function onClose()
  opened = false
end

function requestClose()
  if busy then return end
  if dirty() then
    confirmDiscard = true
    render()
  else
    closeEditor()
  end
end

function continueEditing()
  confirmDiscard = false
  render()
end

function cancelOverwrite()
  confirmOverwrite = false
  render()
end

function confirmOverwriteSave()
  saveMetadata(true)
end

function discardChanges()
  closeEditor()
end

function saveMetadata(overwrite)
  if busy or file == "" then return end
  tags._filename = filename
  busy = true
  confirmOverwrite = false
  render()
  getMetadataOps().save(file, tags, overwrite == true, function(result)
    busy = false
    if result.exitCode ~= 0 then
      if string.find(result.stderr or "", "DEST_EXISTS:", 1, true) == 1 and not overwrite then
        confirmOverwrite = true
        render()
        return
      end
      noctalia.notifyError("No se pudieron guardar los metadatos", result.stderr)
      render()
      return
    end
    local refreshToken = tonumber(noctalia.state.get("player.queueRefresh")) or 0
    noctalia.state.set("player.queueRefresh", refreshToken + 1)
    noctalia.notify("Metadatos guardados", tags.title or file)
    noctalia.state.set("musicpc.updatedTrack", { old = file, new = noctalia.string.trim(result.stdout or "") })
    closeEditor()
  end)
end