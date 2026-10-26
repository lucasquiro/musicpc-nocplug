--!nonstrict

--- EN: Invokes the Python/FFmpeg helper for metadata reads and writes; loaded only by the editor controller.
--- ES: Invoca el helper Python/FFmpeg para leer y escribir metadatos; solo lo carga el controlador del editor.

local M = {}

--- EN: Calls a metadata consumer without allowing its errors to break this adapter; returns nothing.
--- ES: Invoca al consumidor sin permitir que sus errores rompan el adaptador; no devuelve nada.
local function safeDeliver(callback, result)
  local ok, err = pcall(callback, result)
  if not ok then noctalia.log("MusicPC metadata callback failed: " .. tostring(err)) end
end

--- EN: Resolves the plugin directory and launches the Python helper with separate arguments.
--- ES: Resuelve la carpeta del plugin e inicia el helper Python con argumentos separados.
local function launch(args, callback)
  local pluginDir = noctalia.pluginDir()
  if not pluginDir then
    safeDeliver(callback, { exitCode = 1, stdout = "", stderr = "No se pudo localizar el plugin" })
    return
  end
  local command = { "python3", pluginDir .. "/lib/media/media_files.py" }
  for _, argument in ipairs(args) do table.insert(command, argument) end
  --- EN: Delivers the subprocess result through the protected consumer callback.
  --- ES: Entrega el resultado del proceso mediante el callback consumidor protegido.
  local ok, accepted = pcall(noctalia.runAsync, command, function(result)
    safeDeliver(callback, result)
  end)
  if not ok or accepted == false then
    safeDeliver(callback, { exitCode = 1, stdout = "", stderr = "No se pudo iniciar la operación de metadatos" })
  end
end

--- EN: Reads supported tags for a library-relative MP3 path; reports the helper result asynchronously.
--- ES: Lee etiquetas admitidas de una ruta MP3 relativa a la biblioteca; informa el resultado de forma asíncrona.
function M.read(file, callback)
  launch({ "tags", file }, callback)
end

--- EN: Encodes edited tag values and saves them, optionally allowing destination replacement.
--- ES: Codifica las etiquetas editadas y las guarda, permitiendo opcionalmente reemplazar el destino.
function M.save(file, values, overwrite, callback)
  local payload, encodeError = noctalia.json.encode(values)
  if not payload then
    safeDeliver(callback, { exitCode = 1, stdout = "", stderr = tostring(encodeError or "JSON no válido") })
    return
  end
  local args = { "save", file, payload }
  if overwrite then table.insert(args, "--overwrite") end
  launch(args, callback)
end

return M