local M = {}

--- Patch fields on a required module's shared table. Works for any
--- lazy.nvim module because require() returns the same table object to
--- every caller, and call sites always read `Module.field(...)` rather
--- than caching a local function reference.
---@param modname string
---@param stubs table<string, any>
---@return fun() restore
function M.patch(modname, stubs)
  local mod = require(modname)
  local saved = {}
  for k in pairs(stubs) do
    saved[k] = mod[k]
  end
  for k, v in pairs(stubs) do
    mod[k] = v
  end
  return function()
    for k, v in pairs(saved) do
      mod[k] = v
    end
  end
end

--- Deep-merge overrides into Config.options, returns a restore fn.
---@param overrides table
---@return fun() restore
function M.patch_config(overrides)
  local Config = require("lazy.core.config")
  local saved = vim.deepcopy(Config.options)
  Config.options = vim.tbl_deep_extend("force", Config.options, overrides)
  return function()
    Config.options = saved
  end
end

--- Installs a synthetic lazy.manage.task.<ns> namespace, returns a
--- restore fn.
---@param ns string
---@param defs table<string, LazyTaskDef>
---@return fun() restore
function M.stub_tasks(ns, defs)
  local modname = "lazy.manage.task." .. ns
  local prev = package.loaded[modname]
  package.loaded[modname] = defs
  return function()
    package.loaded[modname] = prev
  end
end

--- Stubs lazy.manage.process's `exec` so no real process is spawned.
---@param responses table<string, {lines:string[], code?:number}>
---@return fun() restore
function M.stub_process(responses)
  return M.patch("lazy.manage.process", {
    exec = function(cmd, _opts)
      local key = type(cmd) == "table" and table.concat(cmd, " ") or cmd
      local resp = responses[key]
      assert(resp, "no stubbed response for: " .. key)
      return resp.lines, resp.code or 0
    end,
  })
end

return M
