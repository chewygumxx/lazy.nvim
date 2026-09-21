local Config = require("lazy.core.config")
local Util = require("lazy.util")

---@class LazyState
---@field checker {last_check: number}
local M = {}

local defaults = {
  checker = {
    last_check = 0,
  },
}

---@type LazyState
local data = nil

function M.read()
  pcall(function()
    data = vim.json.decode(Util.read_file(Config.options.state))
  end)
  data = vim.tbl_deep_extend("force", {}, defaults, data or {})
end

function M.write()
  vim.fn.mkdir(vim.fn.fnamemodify(Config.options.state, ":p:h"), "p")
  Util.write_file(Config.options.state, vim.json.encode(data))
end

function M.__index(_, key)
  if not data then
    M.read()
  end
  return data[key]
end

function M.__setindex(_, key, value)
  if not data then
    M.read()
  end
  data[key] = value
end

return setmetatable(M, M)
