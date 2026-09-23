#!/usr/bin/env lua
-- vim:set expandtab shiftwidth=4 filetype=lua:
-- SPDX-License-Identifier: Apache-2.0

--
--
-- ~folke/lazy.nvim.git
-- └─> ~chewygumxx/lazy.nvim.git
-- ::: :/lua/lazy/status.lua
--
--

local Config = require("lazy.core.config")

local M = {}

---@return string | false
function M.updates()
    local Checker = require("lazy.manage.checker")
    local updates = #Checker.updated
    return updates > 0 and (Config.options.ui.icons.plugin .. "" .. updates)
end

---@return boolean
function M.has_updates()
    local Checker = require("lazy.manage.checker")
    return #Checker.updated > 0
end

return M
