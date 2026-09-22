-- Lazy Bootstrapper
-- Usage:
-- ```lua
-- load(vim.fn.system("curl -s https://raw.githubusercontent.com/chewygumxx/lazy.nvim/main/bootstrap.lua"))()
-- ```
local M = {}

--- Clones remote repository of lazy.nvim
---@param url    string Repository URL
---@param path   string Clone destination
---@param branch string Repository branch
---@return number syscall_code Exit code of git clone
function M.install(url, path, branch)
  vim.notify("Installing lazy.nvim package manager", vim.log.levels.INFO)
  local syscall = vim
    .system({
      "git",
      "clone",
      "--filter=blob:none",
      type(branch) == "string" and "--branch=" .. branch or nil,
      url,
      path,
    }, { text = true })
    :wait()
  if syscall.code ~= 0 then
    vim.notify("Failed to clone lazy.nvim", vim.log.levels.ERROR)
    vim.notify(
      table.concat({
        "Exited with code: " .. tostring(syscall.code),
        syscall.stderr,
      }, "\n"),
      vim.log.levels.WARN
    )
  end
  return syscall.code
end

function M.setup()
  local path = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
  local repo = "https://github.com/chewygumxx/lazy.nvim.git"

  if not (vim.uv or vim.loop).fs_stat(path) then
    local code = M.install(repo, path, "chewygumxx")
    if code ~= 0 then
      return
    end
  end

  vim.opt.rtp:prepend(path)
end
M.setup()

return M
