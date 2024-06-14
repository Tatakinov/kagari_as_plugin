local M = {}

setmetatable(M, {
  __call  = function(_, base)
    local class = setmetatable({
      super = function(self) return base end,
    }, {
      __index = base,
      __call  = function(c, ...)
        local self  = setmetatable({}, c)
        if type(self._init) == "function" then
          self:_init(...)
        end
        return self
      end,
    })
    return class
  end,
})

return M
