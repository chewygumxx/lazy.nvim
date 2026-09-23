#!/usr/bin/env lua
-- vim:set expandtab shiftwidth=4 filetype=lua:
-- SPDX-License-Identifier: Apache-2.0

--
--
-- ~folke/lazy.nvim.git
-- └─> ~chewygumxx/lazy.nvim.git
-- ::: :/lua/lazy/community/specs.lua
--
--

---@type table<string, LazyPluginSpec>
return {
    ["plenary.nvim"] = {
        "nvim-lua/plenary.nvim",
        lazy = true,
    },
}
