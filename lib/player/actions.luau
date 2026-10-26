--!nonstrict

--- EN: Applies optimistic player-state changes and sends playback commands; used by widget.luau and panel.luau.
--- ES: Aplica cambios optimistas al estado y envía comandos de reproducción; lo usan widget.luau y panel.luau.

local M = {}
local IGNORE_SERVER_MS = 450

--- EN: Copies the current player snapshot, applies a patch, and suppresses stale reconciliation briefly.
--- ES: Copia la instantánea actual, aplica cambios y aplaza brevemente la conciliación con datos antiguos.
local function optimisticPatch(patch)
  local player = noctalia.state.get("player") or {}
  local updated = table.clone(player)
  for key, value in pairs(patch) do updated[key] = value end
  noctalia.state.set("player.optimisticUntil", noctalia.nowMs() + IGNORE_SERVER_MS)
  noctalia.state.set("player", updated)
end

--- EN: Applies an optimistic patch before starting an argv command; logs failures and clears the suppression window.
--- ES: Aplica el cambio optimista antes de iniciar un comando argv; registra errores y limpia la ventana de espera.
local function run(command, patch)
  optimisticPatch(patch)
  local ok, accepted = pcall(noctalia.runAsync, command)
  if not ok or accepted == false then
    noctalia.state.set("player.optimisticUntil", 0)
    noctalia.log("MusicPC could not start mpc command: " .. tostring(command[2] or command[1]))
  end
end

--- EN: Starts or pauses playback according to the supplied player snapshot; returns nothing.
--- ES: Inicia o pausa según la instantánea del reproductor; no devuelve nada.
function M.playPause(player)
  if player.state == "playing" then
    run({ "mpc", "pause" }, { state = "paused" })
  else
    run({ "mpc", "play" }, { state = "playing" })
  end
end

--- EN: Toggles MPD random mode and publishes the expected value immediately; returns nothing.
--- ES: Alterna el modo aleatorio de MPD y publica enseguida el valor esperado; no devuelve nada.
function M.random(player)
  local enabled = player.random ~= true
  run({ "mpc", "random", enabled and "on" or "off" }, { random = enabled })
end

--- EN: Cycles repeat mode through off, queue, and single-track states; returns nothing.
--- ES: Alterna la repetición entre apagada, cola y pista única; no devuelve nada.
function M.cycleRepeatMode(player)
  local currentMode = player.repeatMode
  if currentMode == true then currentMode = "all" end
  if currentMode ~= "all" and currentMode ~= "one" then currentMode = "off" end

  local nextMode
  local commands
  if currentMode == "off" then
    nextMode = "all"
    commands = { { "mpc", "single", "off" }, { "mpc", "repeat", "on" } }
  elseif currentMode == "all" then
    nextMode = "one"
    commands = { { "mpc", "single", "on" } }
  else
    nextMode = "off"
    commands = { { "mpc", "single", "off" }, { "mpc", "repeat", "off" } }
  end

  optimisticPatch({ repeatMode = nextMode })
  --- EN: Runs the sequence in order so single/repeat flags represent one coherent mode.
  --- ES: Ejecuta la secuencia en orden para mantener coherentes los indicadores single/repeat.
  local function runNext(index)
    if index > #commands then return end
    --- EN: Advances to the next mode command only after the current command succeeds.
    --- ES: Avanza al siguiente comando de modo solo si el actual termina correctamente.
    local ok, accepted = pcall(noctalia.runAsync, commands[index], function(result)
      if result.exitCode ~= 0 then
        noctalia.state.set("player.optimisticUntil", 0)
        noctalia.log("MusicPC repeat command failed: " .. tostring(result.stderr))
        return
      end
      runNext(index + 1)
    end)
    if not ok or accepted == false then
      noctalia.state.set("player.optimisticUntil", 0)
      noctalia.log("MusicPC could not start repeat command")
    end
  end
  runNext(1)
end

--- EN: Moves one queue position in the requested direction, updates the optimistic track, and sends next/prev.
--- ES: Cambia una posición en la dirección indicada, actualiza la pista optimista y envía next/prev.
function M.skip(player, direction)
  local queue = noctalia.state.get("player.queue") or {}
  local position = tonumber(player.position) or 0
  local target = position + direction
  if target >= 1 and target <= #queue then
    local track = queue[target]
    optimisticPatch({
      position = target,
      artist = track.artist,
      title = track.title,
      file = track.file,
      state = "playing",
    })
  else
    optimisticPatch({ position = target, state = "playing" })
  end
  noctalia.state.set("player.progress", { elapsed = "0:00", total = "0:00", percent = 0 })
  noctalia.state.set("player.optimisticUntil", noctalia.nowMs() + IGNORE_SERVER_MS)
  local command = direction > 0 and "next" or "prev"
  local ok, accepted = pcall(noctalia.runAsync, { "mpc", command })
  if not ok or accepted == false then noctalia.state.set("player.optimisticUntil", 0) end
end

return M