local Lanes = require("lanes").configure()

local function version()
  return "Kagari_as_Plugin/1.0.0"
end

local target  = nil
local result  = nil

local function getJson(url)
  -- 必要なモジュールはここ(別スレッド内)で呼ぶこと
  local HTTP  = require("socket.http")
  local LTN12 = require("ltn12")
  local JSON  = require("json")

  local t = {}
  HTTP.request({
    method  = "GET",
    url     = url,
    sink    = LTN12.sink.table(t),
  })
  local data  = table.concat(t)
  local json  = JSON.decode(data)
  return json
end

return {
  {
    id  = "version",
    passthrough = true,
    content = function(plugin, ref)
      return {
        Value = "1.0.0"
      }
    end,
  },
  {
    id  = "OnSecondChange",
    content = function(plugin, ref)
      if result then
        if result.status == "done" then
          local json  = result[1]
          result  = nil
          return {
            Target  = target,
            Script  = "\\0User-Agent: " .. json.headers["User-Agent"] .. "\\e",
          }
        end
      end
    end
  },
  {
    id  = "OnMenuExec",
    content = function(plugin, ref)
      target  = ref("Sender")
      if not(result) then
        local func  = Lanes.gen("*", {}, getJson)
        result  = func("https://httpbin.org/headers")
      end
      return nil
    end,
  }
}
