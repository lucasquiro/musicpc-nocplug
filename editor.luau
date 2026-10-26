--!nonstrict

--- EN: Thin Noctalia panel entry; exposes global UI callbacks and delegates editor behavior to its lazy module.
--- ES: Entrada delgada del panel Noctalia; expone callbacks globales de UI y delega la lógica al módulo cargado bajo demanda.

local editorController = require("./lib/editor/controller.luau")

--- EN: Starts loading metadata for the selected track when the panel opens; returns nothing.
--- ES: Inicia la carga de metadatos de la pista seleccionada al abrirse el panel; no devuelve nada.
function onOpen(_context)
  editorController.onOpen()
end

--- EN: Informs the controller that the panel closed; returns nothing.
--- ES: Informa al controlador que el panel se cerró; no devuelve nada.
function onClose()
  editorController.onClose()
end

--- EN: Routes the close action through the unsaved-changes guard; returns nothing.
--- ES: Enruta el cierre por la comprobación de cambios pendientes; no devuelve nada.
function requestClose()
  editorController.requestClose()
end

--- EN: Continues editing after the discard confirmation is dismissed; returns nothing.
--- ES: Continúa la edición tras cerrar la confirmación de descarte; no devuelve nada.
function continueEditing()
  editorController.continueEditing()
end

--- EN: Discards the current edits; returns nothing.
--- ES: Descarta los cambios actuales; no devuelve nada.
function discardChanges()
  editorController.discardChanges()
end

--- EN: Saves metadata for the current track, optionally replacing a destination; returns nothing.
--- ES: Guarda los metadatos de la pista actual, opcionalmente reemplazando el destino; no devuelve nada.
function saveMetadata(overwrite)
  editorController.saveMetadata(overwrite)
end

--- EN: Cancels the pending overwrite confirmation; returns nothing.
--- ES: Cancela la confirmación de sobrescritura pendiente; no devuelve nada.
function cancelOverwrite()
  editorController.cancelOverwrite()
end

--- EN: Confirms overwrite and retries the save; returns nothing.
--- ES: Confirma la sobrescritura y reintenta el guardado; no devuelve nada.
function confirmOverwriteSave()
  editorController.confirmOverwriteSave()
end
