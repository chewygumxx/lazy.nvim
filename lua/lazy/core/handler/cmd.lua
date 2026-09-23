#!/usr/bin/env lua
-- vim:set expandtab shiftwidth=4 filetype=lua:
-- SPDX-License-Identifier: Apache-2.0

--
--
-- ~folke/lazy.nvim.git
-- └─> ~chewygumxx/lazy.nvim.git
-- ::: :/lua/lazy/core/handler/cmd.lua
--
--

local Loader = require("lazy.core.loader")
local Util   = require("lazy.core.util")

---@class LazyCmdBase
---@field desc?     string
---@field bang?     boolean
---@field range?    boolean | string
---@field nargs?    string
---@field complete? string | fun(arglead: string, cmdline: string, cursorpos: number): string[]?

---@class LazyCmdSpec: LazyCmdBase
---@field [1]  string           name
---@field [2]? fun(args: table) callback

---@class LazyCmd: LazyCmdBase
---@field name      string
---@field callback? fun(args: table)
---@field id        string

---@class LazyCmdHandler: LazyHandler
local M = {}

local skip = { name = true, id = true, callback = true }

---@param value string | LazyCmdSpec
---@return LazyCmd
function M.parse(value)
    value        = type(value) == "string" and { value } or value --[[@as LazyCmdSpec]]
    local ret    = vim.deepcopy(value)                            --[[@as LazyCmd]]
    ret.name     = ret[1]
    ret.callback = ret[2]
    ret[1]       = nil
    ret[2]       = nil
    ret.id       = ret.name
    return ret
end

---@param spec? (string | LazyCmdSpec)[]
---@return table<string, LazyCmd>
function M.resolve(spec)
    ---@type table<string, LazyCmd>
    local values = {}
    for _, value in ipairs(spec or {}) do
        local cmd      = M.parse(value)
        values[cmd.id] = cmd
    end
    return values
end

---@param values(string | LazyCmdSpec)[]
---@return table<string, LazyCmd>
function M:_values(values)
    return M.resolve(values)
end

---@param cmd LazyCmd
---@return LazyCmdBase
function M.opts(cmd)
    local opts = {} ---@type LazyCmdBase
    for k, v in pairs(cmd) do
        if type(k) ~= "number" and not skip[k] then
            opts[k] = v
        end
    end
    return opts
end

---@param cmd LazyCmd
function M:_load(cmd)
    pcall(vim.api.nvim_del_user_command, cmd.name)
    Util.track({ cmd = cmd.name })
    Loader.load(self.active[cmd.id], { cmd = cmd.name })
    Util.track()

    -- spec-defined commands install their real definition directly,
    -- instead of relying on the plugin's config() to create it
    if cmd.callback then
        vim.api.nvim_create_user_command(
            cmd.name,
            cmd.callback,
            M.opts(cmd) --[[@as vim.api.keyset.user_command]]
        )
    end
end

---@param cmd LazyCmd
function M:_add(cmd)
    vim.api.nvim_create_user_command(
        cmd.name,
        function(event)
            local command = {
                cmd = cmd.name,
                bang = event.bang or nil,
                mods = event.smods,
                args = event.fargs,
                count = event.count >= 0 and event.range == 0 and event.count
                    or nil,
            }

            if event.range == 1 then
                command.range = { event.line1 }
            elseif event.range == 2 then
                command.range = { event.line1, event.line2 }
            end

            ---@type string
            local plugins = "`"
                .. table.concat(vim.tbl_values(self.active[cmd.id]), ", ")
                .. "`"

            self:_load(cmd)

            local info = vim.api.nvim_get_commands({})[cmd.name]
                or vim.api.nvim_buf_get_commands(0, {})[cmd.name]
            if not info then
                vim.schedule(function()
                    Util.error(
                        "Command `" .. cmd.name
                            .. "` not found after loading " .. plugins
                    )
                end)
                return
            end

            command.nargs = info.nargs
            if event.args and event.args ~= ""
                and info.nargs and info.nargs:find("[1?]") then
                command.args = { event.args }
            end
            vim.cmd(command)
        end,
        {
            bang = true,
            range = true,
            nargs = "*",
            complete = function(_, line)
                self:_load(cmd)
                -- NOTE: return the newly loaded command completion
                return vim.fn.getcompletion(line, "cmdline")
            end,
        }
    )
end

---@param cmd LazyCmd
function M:_del(cmd)
    pcall(vim.api.nvim_del_user_command, cmd.name)
end

return M
