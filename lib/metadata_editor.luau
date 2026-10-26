--!nonstrict

local M = {}

local function safeDeliver(callback, result)
  local ok, err = pcall(callback, result)
  if not ok then noctalia.log("MusicPC metadata callback failed: " .. tostring(err)) end
end

local function launch(args, callback)
  local pluginDir = noctalia.pluginDir()
  if not pluginDir then
    safeDeliver(callback, { exitCode = 1, stdout = "", stderr = "No se pudo localizar el plugin" })
    return
  end
  local command = { "python3", pluginDir .. "/media_files.py" }
  for _, argument in ipairs(args) do table.insert(command, argument) end
  local ok, accepted = pcall(noctalia.runAsync, command, function(result)
    safeDeliver(callback, result)
  end)
  if not ok or accepted == false then
    safeDeliver(callback, { exitCode = 1, stdout = "", stderr = "No se pudo iniciar la operación de metadatos" })
  end
end

function M.read(file, callback)
  launch({ "tags", file }, callback)
end

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