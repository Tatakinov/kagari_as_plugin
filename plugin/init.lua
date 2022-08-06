local Class         = require("class")
local Trie          = require("trie")
local Misc          = require("plugin.misc")
local Module        = require("ukagaka_module.plugin")
local Path          = require("path")
local Protocol      = Module.Protocol
local Request       = Module.Request
local Response      = Module.Response
local SaoriCaller   = require("saori_caller")
local StringBuffer  = require("string_buffer")
local Talk          = require("plugin.talk")
local I18N          = require("plugin.i18n")
local Variable      = require("plugin.variable")

local M = Class()
M.__index = M

function M:_init()
  math.randomseed(os.time())

  self._charset = "UTF-8"
  self._name    = "Kagari/Kotori"

  self._saori      = SaoriCaller()
  self._reserve = {}

  self.var  = Variable()
  self.i18n = I18N()

  self._data   = Talk()

  self._chain = {}
end

function M:load(path)
  self.var:load(path)
  self.var("_path", path)

  local __  = self.var
  __("_DictError", {})

  --トーク読み込み
  Path.dirWalk(path .. "talk", function(file_path)
    if string.sub(file_path, 1, 1) == "_" or string.sub(file_path, -4, -1) ~= ".lua" then
      return
    end
    local t, err  = (function()
      local fh  = io.open(file_path, "r")
      if fh == nil then
        return nil, "file not found"
      end
      local data  = fh:read("*a")
      local chunk, err = load(data, Path.relative(path, file_path))
      if err then
        return chunk, err
      end
      if type(chunk) ~= "function" then
        return nil, "invalid chunk"
      end
      local t = chunk()
      if type(t) ~= "table" then
        return nil, "invalid dictionary"
      end
      return t
    end)()
    if err then
      print("Failed to load dict: " .. err)
      local dict_error  = __("_DictError")
      table.insert(dict_error, err)
    else
      for _, v in ipairs(t) do
        self._data:add(v)
      end
    end
  end)

  self._saori:load(path, self:talk("name"))
  self._saori:loadall()

  self:talk("OnDictionaryLoaded")
end

function M:unload()
  print("unload")
  self._saori:unloadall()
end

function M:request(req)
  local res = Response(204, 'No Content', Protocol.v20, {
    Charset = self._charset,
  })

  if req == nil then
    return res
  end

  local id  = req:header("ID")
  if id == nil then
    -- TODO comment
  else
    local value, passthrough = self:_talk(id, req:headers())
    local event = nil
    -- X-SSTP-PassThru-*への暫定的な対応
    local tbl = {}
    if type(value) == "table" then
      tbl   = value
      event = value.Event
      value = value.Script
    end
    if value then
      value = string.gsub(value, "\x0d", "")
      value = string.gsub(value, "\x0a", "")
      -- SHIORI Resource他置換しないトークには置換や末尾\eの追加を行わない
      if not(passthrough) then
        --  末尾にえんいーを追加する。
        --  えんいーが既にあるかを調べるのは面倒いのでとりあえず付けておく。
        value = value .. "\\e"
      end
      res:code(200)
      res:message("OK")
      tbl.Script  = value
    end
    if event then
      res:code(200)
      res:message("OK")
    end
    for k, v in pairs(tbl) do
      res:header(k, v)
    end
  end
  res:header("Charset", self._charset)
  res:request(req)
  return res
end

function M:_talk(id, ...)
  local id  = id or ""
  local tbl
  if select("#", ...) == 1 and type(select(1, ...)) == "table" then
    tbl = select(1, ...)
    if #tbl == 0 and tbl[0] == nil then
      tbl = Misc.toArray(tbl)
    end
  else
    tbl = Misc.toArray(Misc.toArgs(...))
  end
  local language  = self.var("_Language") or ""
  --print("shiori:talk:     " .. tostring(id))
  --print("shiori:talk.tbl: " .. type(tbl))
  local talk = self._chain[id]
  if talk == nil or coroutine.status(talk.content) == "dead" then
    talk  = self._data:get(id) or {}
    local content = talk["content_" .. language] or talk.content
    if type(content) == "function" then
      talk  = {
        content = coroutine.create(content),
        passthrough = talk.passthrough,
      }
    else
      talk  = {
        content = content,
        passthrough = talk.passthrough,
      }
    end
  end
  local value, err = Misc.tostring(
    talk.content,
    self,
    tbl
  )
  if type(talk.content) == "thread" and coroutine.status(talk.content) ~= "dead" then
    self._chain[id] = talk
  end
  if err then
    local str = StringBuffer([[\0\_q]])
    for s in string.gmatch(err, "([^\n]+)") do
      str:append([[\_?]]):append(s):append([[\_?\n]])
    end
    str:append([[\_q]])
    str.Script  = str:tostring()
    str.ErrorLevel  = "warning"
    str.ErrorDescription  = string.gsub(err, "\n", " | ")
    return str, true
  end
  return value, talk.passthrough
end

function M:talk(...)
  return (self:_talk(...))
end

function M:saori(id)
  return function(...)
    local saori = self._saori:get(id)
    local ret = saori:request(...)
    local t = {}
    for k, v in pairs(ret:headers()) do
      if string.match(k, "^Value%d+$") then
        local num = tonumber(string.sub(k, 6))
        t[num]  = v
      end
    end
    local mt  = {
      __call  = function(self, name)
        name  = name or "Result"
        return ret:header(name)
      end,
    }
    return setmetatable(t, mt)
  end
end

function M:setLanguage(language)
  self.i18n:set(language)
end

return M
