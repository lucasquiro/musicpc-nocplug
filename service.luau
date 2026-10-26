--!nonstrict

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

local function clean(text)
  return string.gsub(text or "", "\r", "")
end

local function parseSong(line)
  local parts = splitPlain(clean(line), SEP)
  local artist, title, file = parts[1] or "", parts[2] or "", parts[3] or ""
  if title == "" then title = string.match(file, "([^/]+)$") or file end
  return artist, title, file
end

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

local function parsePlaylists(stdout)
  local playlists = {}
  for _, line in ipairs(splitPlain(clean(stdout), "\n")) do
    local name = noctalia.string.trim(line)
    if name ~= "" then table.insert(playlists, name) end
  end
  return playlists
end

local function publishIfChanged(key, value)
  local ok, encoded = pcall(noctalia.json.encode, value)
  if not ok or not encoded then return end
  if lastPublished[key] == encoded then return end
  lastPublished[key] = encoded
  local published, err = pcall(noctalia.state.set, key, value)
  if not published then noctalia.log("MusicPC state publish failed: " .. tostring(err)) end
end

local function safeCallback(label, callback)
  return function(result)
    local ok, err = pcall(callback, result)
    if not ok then noctalia.log("MusicPC " .. label .. " callback failed: " .. tostring(err)) end
  end
end

local function run(args, callback)
  local ok, accepted = pcall(noctalia.runAsync, args, callback)
  if not ok or accepted == false then
    noctalia.log("MusicPC could not start mpc command: " .. tostring(args[2] or args[1]))
    return false
  end
  return true
end

local function refreshQueue()
  if queueBusy then queueDirty = true; return end
  queueBusy = true
  queueDirty = false
  local started = run({ "mpc", "-f", FORMAT, "playlist" }, safeCallback("queue", function(result)
    queueBusy = false
    if result.exitCode == 0 then publishIfChanged("player.queue", parseQueue(result.stdout)) end
    if queueDirty then refreshQueue() end
  end))
  if not started then queueBusy = false end
end

local function refreshPlaylists()
  if playlistsBusy then playlistsDirty = true; return end
  playlistsBusy = true
  playlistsDirty = false
  local started = run({ "mpc", "lsplaylists" }, safeCallback("playlists", function(result)
    playlistsBusy = false
    if result.exitCode == 0 then publishIfChanged("player.playlists", parsePlaylists(result.stdout)) end
    if playlistsDirty then refreshPlaylists() end
  end))
  if not started then playlistsBusy = false end
end

local function refreshStatus()
  if statusBusy then return end
  statusBusy = true
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

local function startIdleLoop()
  local ok, accepted = pcall(noctalia.runStream, "mpc idleloop player playlist stored_playlist options", function(line)
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

function update()
  refreshStatus()
end

noctalia.state.watch("player.queueRefresh", function()
  queueDirty = true
  refreshQueue()
  playlistsDirty = true
  refreshPlaylists()
end)

noctalia.state.watch("player.optimisticUntil", function(value)
  optimisticUntil = tonumber(value) or 0
end)