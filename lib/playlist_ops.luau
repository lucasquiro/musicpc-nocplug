--!nonstrict

local mpc = require("../mpc.luau")
local M = {}

function M.load(name, callback)
  mpc.clear(function(clearResult)
    if clearResult.exitCode ~= 0 then
      callback(clearResult)
      return
    end
    mpc.load(name, function(loadResult)
      if loadResult.exitCode == 0 then
        mpc.play()
      end
      callback(loadResult)
    end)
  end)
end

function M.save(name, callback)
  mpc.save(name, callback)
end

function M.addTrack(name, file, callback)
  mpc.addplaylist(name, file, callback)
end

return M