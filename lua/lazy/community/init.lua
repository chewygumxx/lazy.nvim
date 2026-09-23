#!/usr/bin/env lua
-- vim:set expandtab shiftwidth=4 filetype=lua:
-- SPDX-License-Identifier: Apache-2.0

--
--
-- ~folke/lazy.nvim.git
-- └─> ~chewygumxx/lazy.nvim.git
-- ::: :/lua/lazy/community/init.lua
--
--

local M = {}

---@type table<string, string>
local mapping = nil

---@return table<string, string>
local function load()
    if not mapping then
        mapping = {}
        ---@type { name: string, url: string, version: string } []
        local gen = require("lazy.community._generated")
        for _, rock in ipairs(gen) do
            mapping[rock.name] = rock.url
        end
    end
    return mapping
end

---@param rock string
---@return string?
function M.get_url(rock)
    return load()[rock]
end

---@param name string
---@return LazyPluginSpec?
function M.get_spec(name)
    return require("lazy.community.specs")[name]
end

return M
