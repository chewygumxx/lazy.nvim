#!/usr/bin/env lua
-- vim:set expandtab shiftwidth=4 filetype=lua:
-- SPDX-License-Identifier: Apache-2.0

--
--
-- ~folke/lazy.nvim.git
-- └─> ~chewygumxx/lazy.nvim.git
-- ::: :/lua/lazy/manage/reloader.lua
--
--

local Config = require("lazy.core.config")
local Loader = require("lazy.core.loader")
local Plugin = require("lazy.core.plugin")
local Util   = require("lazy.util")

local M = {}

---@type table<string, uv.fs_stat.result>
M.files = {}

---@type uv.uv_timer_t?
M.timer = nil

function M.enable()
    if M.timer then
        M.timer:stop()
    end
    if #Config.spec.modules > 0 then
        M.timer = assert(vim.uv.new_timer())
        M.check(true)
        M.timer:start(2000, 2000, M.check)
    end
end

function M.disable()
    if M.timer then
        M.timer:stop()
        M.timer = nil
    end
end

---@param h1 uv.fs_stat.result
---@param h2 uv.fs_stat.result
---@return boolean
function M.eq(h1, h2)
    return h1 and h2 and h1.size == h2.size and h1.mtime.sec == h2.mtime.sec
        and h1.mtime.nsec == h2.mtime.nsec
end

---@param start? boolean
function M.check(start)
    ---@type table<string, true>
    local checked = {}
    ---@type { file: string, what: string } []
    local changes = {}

    -- spec is a module
    ---@param modpath string
    local function check(_, modpath)
        checked[modpath] = true
        local hash       = vim.uv.fs_stat(modpath)
        if hash then
            if M.files[modpath] then
                if not M.eq(M.files[modpath], hash) then
                    M.files[modpath] = hash
                    table.insert(changes, { file = modpath, what = "changed" })
                end
            else
                M.files[modpath] = hash
                table.insert(changes, { file = modpath, what = "added" })
            end
        end
    end

    for _, modname in ipairs(Config.spec.modules) do
        Util.lsmod(modname, check)
    end

    for file in pairs(M.files) do
        if not checked[file] then
            table.insert(changes, { file = file, what = "deleted" })
            M.files[file] = nil
        end
    end

    if Loader.init_done and Config.mapleader ~= vim.g.mapleader then
        local CoreUtil = require("lazy.core.util")
        vim.schedule(function()
            CoreUtil.warn(
                "You need to set `vim.g.mapleader` **BEFORE** loading lazy"
            )
        end)
        Config.mapleader = vim.g.mapleader
    end

    if Loader.init_done and Config.maplocalleader ~= vim.g.maplocalleader then
        local CoreUtil = require("lazy.core.util")
        vim.schedule(function()
            CoreUtil.warn(
                "You need to set `vim.g.maplocalleader` **BEFORE** loading lazy"
            )
        end)
        Config.maplocalleader = vim.g.maplocalleader
    end

    if not (start or #changes == 0) then
        M.reload(changes)
    end
end

---@param changes { file: string, what: string } []
function M.reload(changes)
    vim.schedule(function()
        if Config.options.change_detection.notify and not Config.headless() then
            local lines = { "# Config Change Detected. Reloading...", "" }
            for _, change in ipairs(changes) do
                table.insert(
                    lines,
                    "- **" .. change.what
                        .. "**: `" .. vim.fn.fnamemodify(change.file, ":p:~:.")
                        .. "`"
                )
            end
            Util.warn(lines)
        end
        Plugin.load()
        vim.api.nvim_exec_autocmds("User", {
            pattern = "LazyRender",
            modeline = false,
        })
        vim.api.nvim_exec_autocmds("User", {
            pattern = "LazyReload",
            modeline = false,
        })
    end)
end

return M
