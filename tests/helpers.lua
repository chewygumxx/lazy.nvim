local Util = require("lazy.util")

local M = {}

M.fs_root = vim.fn.fnamemodify("./.tests/fs", ":p")

function M.path(path)
    return Util.norm(M.fs_root .. "/" .. path)
end

---@param files string[]
function M.fs_create(files)
    ---@type string[]
    local ret = {}

    for _, file in ipairs(files) do
        ret[#ret + 1] = Util.norm(M.fs_root .. "/" .. file)
        local parent  = vim.fn.fnamemodify(ret[#ret], ":h:p")
        vim.fn.mkdir(parent, "p")
        Util.write_file(ret[#ret], "")
    end
    return ret
end

---@param path    string
---@param content string
---@return string
function M.fs_write(path, content)
    local full = M.path(path)
    vim.fn.mkdir(vim.fn.fnamemodify(full, ":h"), "p")
    Util.write_file(full, content)
    return full
end

---@param overrides? table
---@return LazyPlugin
function M.plugin(overrides)
    return vim.tbl_deep_extend(
        "force",
        { name = "test-plugin", dir = "/test-plugin", _ = {} },
        overrides or {}
    )
end

function M.fs_rm(dir)
    dir = Util.norm(M.fs_root .. "/" .. dir)
    Util.walk(dir, function(path, _, type)
        if type == "directory" then
            vim.uv.fs_rmdir(path)
        else
            vim.uv.fs_unlink(path)
        end
    end)
    vim.uv.fs_rmdir(dir)
end

return M
