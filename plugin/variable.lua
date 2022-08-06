local Class = require("class")
local Misc  = require("plugin.misc")

local M = Class()
M.__index = M
M.__call  = function(self, key, ...)
  local ret = self._data[key]
  if select("#", ...) > 0 then
    self._data[key] = select(1, ...)
  end
  return ret
end

function M:init(key, value)
  if self(key) == nil then
    self(key, value)
  end
  return self(key)
end

function M:load(path)
  self._data  = {}
end

return M
