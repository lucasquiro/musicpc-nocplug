--!nonstrict

local M = {}
local IGNORE_SERVER_MS = 450

local function optimisticPatch(patch)
  local player = noctalia.state.get("player") or {}
  local updated = table.clone(player)
  for key, value in pairs(patch) do updated[key] = value end
  noctalia.state.set("player.optimisticUntil", noctalia.nowMs() + IGNORE_SERVER_MS)
  noctalia.state.set("player", updated)
end

local function run(command, patch)
  optimisticPatch(patch)
  local ok, accepted = pcall(noctalia.runAsync, command)
  if not ok or accepted == false then
    noctalia.state.set("player.optimisticUntil", 0)
    noctalia.log("MusicPC could not start mpc command: " .. tostring(command[2] or command[1]))
  end
end

function M.playPause(player)
  if player.state == "playing" then
    run({ "mpc", "pause" }, { state = "paused" })
  else
    run({ "mpc", "play" }, { state = "playing" })
  end
end

function M.random(player)
  local enabled = player.random ~= true
  run({ "mpc", "random", enabled and "on" or "off" }, { random = enabled })
end

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
  local function runNext(index)
    if index > #commands then return end
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