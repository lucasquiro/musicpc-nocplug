--!nonstrict

--- EN: Coordinates editor state, UI rendering, and metadata operations; required by editor.luau.
--- ES: Coordina el estado del editor, el dibujo de la interfaz y las operaciones de metadatos; lo usa editor.luau.

local M = {}

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
  { key = "title", label = "editor.field.title" },
  { key = "artist", label = "editor.field.artist" },
  { key = "album", label = "editor.field.album" },
  { key = "album_artist", label = "editor.field.album_artist" },
  { key = "date", label = "editor.field.date" },
  { key = "genre", label = "editor.field.genre" },
  { key = "track", label = "editor.field.track" },
  { key = "disc", label = "editor.field.disc" },
  { key = "composer", label = "editor.field.composer" },
  { key = "performer", label = "editor.field.performer" },
  { key = "publisher", label = "editor.field.publisher" },
  { key = "bpm", label = "editor.field.bpm" },
  { key = "comment", label = "editor.field.comment" },
  { key = "filename", label = "editor.field.filename" },
}

--- EN: Detects unsaved tag or filename changes; returns true only when a field differs from its original value.
--- ES: Detecta cambios sin guardar en etiquetas o nombre; devuelve true solo si algún campo difiere del original.
local function isDirty()
  for _, field in ipairs(fields) do
    local currentValue = field.key == "filename" and filename or tags[field.key]
    local originalValue = field.key == "filename" and originalFilename or original[field.key]
    if (currentValue or "") ~= (originalValue or "") then return true end
  end
  return false
end

--- EN: Loads the file-operation adapter on first use; returns its cached module table.
--- ES: Carga el adaptador de archivos al primer uso; devuelve la tabla del módulo en caché.
local function getMetadataOps()
  if metadataOps == nil then metadataOps = require("../metadata/editor_ops.luau") end
  return metadataOps
end

--- EN: Renders the active editor or confirmation state; has no return value.
--- ES: Dibuja el editor o la confirmación activa; no devuelve ningún valor.
local function render()
  if not opened then return end
  if confirmDiscard then
    panel.render(ui.column({ padding = 18, gap = 12, fill = "surface", radius = 12, align = "stretch" }, {
      ui.label({ text = noctalia.tr("editor.unsaved_title"), fontSize = 17, fontWeight = "bold" }),
      ui.label({ text = noctalia.tr("editor.unsaved_question"), color = "on_surface/0.75" }),
      ui.row({ gap = 8, justify = "end" }, {
        ui.button({ text = noctalia.tr("editor.continue_editing"), variant = "ghost", onClick = "continueEditing" }),
        ui.button({ text = noctalia.tr("editor.discard"), variant = "secondary", onClick = "discardChanges" }),
        ui.button({ text = noctalia.tr("editor.save"), variant = "primary", enabled = not busy, onClick = "saveMetadata" }),
      }),
    }))
    return
  end
  if confirmOverwrite then
    panel.render(ui.column({ padding = 18, gap = 12, fill = "surface", radius = 12, align = "stretch" }, {
      ui.label({ text = noctalia.tr("editor.exists_title"), fontSize = 17, fontWeight = "bold" }),
      ui.label({ text = noctalia.tr("editor.overwrite_before") .. filename .. noctalia.tr("editor.overwrite_after"), color = "on_surface/0.75", maxLines = 2 }),
      ui.row({ gap = 8, justify = "end" }, {
        ui.button({ text = noctalia.tr("panel.cancel"), variant = "ghost", onClick = "cancelOverwrite" }),
        ui.button({ text = noctalia.tr("editor.replace"), variant = "destructive", enabled = not busy, onClick = "confirmOverwriteSave" }),
      }),
    }))
    return
  end

  local rows = {}
  if busy then
    table.insert(rows, ui.label({ text = noctalia.tr("editor.processing"), color = "on_surface/0.7" }))
  end
  for _, field in ipairs(fields) do
    table.insert(rows, ui.column({ key = "field-" .. field.key, gap = 3, align = "stretch" }, {
      ui.label({ text = noctalia.tr(field.label), fontSize = 12, color = "on_surface/0.75" }),
      ui.input({
        key = "input-" .. field.key .. "-" .. file .. "-" .. tostring(metadataLoaded),
        value = field.key == "filename" and filename or tags[field.key] or "",
        placeholder = noctalia.tr(field.label),
        enabled = not busy,
        --- EN: Stores the edited value in the controller state; returns nothing.
        --- ES: Guarda el valor editado en el estado del controlador; no devuelve nada.
        onChange = function(value)
          if field.key == "filename" then filename = value else tags[field.key] = value end
        end,
      }),
    }))
  end

  panel.render(ui.column({ height = 452, padding = 14, gap = 10, fill = "surface", radius = 12, align = "stretch" }, {
    ui.row({ gap = 8, align = "center" }, {
      ui.column({ flexGrow = 1, gap = 2 }, {
        ui.label({ text = noctalia.tr("editor.title"), fontSize = 16, fontWeight = "bold" }),
        ui.label({ text = file:match("([^/]+)$") or file, fontSize = 12, color = "on_surface/0.7", maxLines = 1 }),
      }),
      ui.button({ glyph = "close", variant = "ghost", tooltip = noctalia.tr("editor.close"), onClick = "requestClose" }),
    }),
    ui.scroll({ flexGrow = 1, gap = 8, padding = 2 }, rows),
    ui.row({ gap = 8, justify = "end" }, {
      ui.button({ text = noctalia.tr("panel.cancel"), variant = "ghost", enabled = not busy, onClick = "requestClose" }),
      ui.button({ text = noctalia.tr("editor.save_changes"), glyph = "device-floppy", variant = "primary", enabled = not busy, onClick = "saveMetadata" }),
    }),
  }))
end

--- EN: Clears the selected track and returns to the queue panel; returns nothing.
--- ES: Limpia la pista seleccionada y vuelve al panel de cola; no devuelve nada.
local function closeEditor()
  opened = false
  noctalia.state.set("musicpc.editTrack", nil)
  panel.close()
  noctalia.togglePanel("lucasquiro/musicpc-nocplug:queue")
end

--- EN: Loads the selected track's tags when Noctalia opens this panel; returns nothing.
--- ES: Carga las etiquetas de la pista seleccionada cuando Noctalia abre este panel; no devuelve nada.
function M.onOpen()
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
    noctalia.notifyError(noctalia.tr("editor.error.generic"), noctalia.tr("editor.error.open"))
    render()
    return
  end
  --- EN: Updates editor flags and field snapshots after the helper finishes reading tags.
  --- ES: Actualiza indicadores y etiquetas al terminar el helper de lectura.
  getMetadataOps().read(file, function(result)
    busy = false
    if result.exitCode ~= 0 then
      noctalia.notifyError(noctalia.tr("editor.error.read_title"), result.stderr)
    else
      local ok, decoded = pcall(noctalia.json.decode, result.stdout or "")
      if ok and type(decoded) == "table" then
        tags = decoded
        original = table.clone(decoded)
        metadataLoaded = true
      else
        noctalia.notifyError(noctalia.tr("editor.error.generic"), noctalia.tr("editor.error.invalid_response"))
      end
    end
    render()
  end)
end

--- EN: Marks the editor closed when Noctalia dismisses the panel; returns nothing.
--- ES: Marca el editor como cerrado cuando Noctalia cierra el panel; no devuelve nada.
function M.onClose()
  opened = false
end

--- EN: Closes immediately when clean, otherwise asks whether to save or discard; returns nothing.
--- ES: Cierra si no hay cambios o pregunta si se guardan o descartan; no devuelve nada.
function M.requestClose()
  if busy then return end
  if isDirty() then
    confirmDiscard = true
    render()
  else
    closeEditor()
  end
end

--- EN: Dismisses the discard prompt and restores the editor; returns nothing.
--- ES: Cierra el aviso de descarte y restaura el editor; no devuelve nada.
function M.continueEditing()
  confirmDiscard = false
  render()
end

--- EN: Cancels replacement of an existing destination file; returns nothing.
--- ES: Cancela el reemplazo de un archivo de destino existente; no devuelve nada.
function M.cancelOverwrite()
  confirmOverwrite = false
  render()
end

--- EN: Confirms replacement and retries saving with overwrite enabled; returns nothing.
--- ES: Confirma el reemplazo y reintenta guardar con sobrescritura; no devuelve nada.
function M.confirmOverwriteSave()
  M.saveMetadata(true)
end

--- EN: Discards edits and closes the editor; returns nothing.
--- ES: Descarta los cambios y cierra el editor; no devuelve nada.
function M.discardChanges()
  closeEditor()
end

--- EN: Saves the current tags and optional filename; overwrite controls whether an existing target may be replaced.
--- ES: Guarda las etiquetas y el nombre opcional; overwrite indica si puede reemplazarse un destino existente.
function M.saveMetadata(overwrite)
  if busy or file == "" then return end
  tags._filename = filename
  busy = true
  confirmOverwrite = false
  render()
  --- EN: Handles save errors, overwrite confirmation, shared refresh, and successful close.
  --- ES: Gestiona errores, confirmación de reemplazo, actualización compartida y cierre exitoso.
  getMetadataOps().save(file, tags, overwrite == true, function(result)
    busy = false
    if result.exitCode ~= 0 then
      if string.find(result.stderr or "", "DEST_EXISTS:", 1, true) == 1 and not overwrite then
        confirmOverwrite = true
        render()
        return
      end
      noctalia.notifyError(noctalia.tr("editor.error.save_title"), result.stderr)
      render()
      return
    end
    local refreshToken = tonumber(noctalia.state.get("player.queueRefresh")) or 0
    noctalia.state.set("player.queueRefresh", refreshToken + 1)
    noctalia.notify(noctalia.tr("editor.notice.saved"), tags.title or file)
    noctalia.state.set("musicpc.updatedTrack", { old = file, new = noctalia.string.trim(result.stdout or "") })
    closeEditor()
  end)
end

return M