local Util = require("lazy.core.util")

---@class LazyCoreConfig
local M = {}

local joinpath = vim.fs.joinpath
local data_dir = vim.fn.stdpath("data")
local state_dir = vim.fn.stdpath("state")

---@class LazyConfig
---@field name?   string Name of lazy.nvim, sets directory names
---@field data?   string Plugin data directory (Default: <nvim_data>/lazy)
---@field state?  string Plugin state directory (Default: <nvim_state>/lazy)
---@field path?   string Clone destination (Default: <data>/lazy.nvim)
---@field url?    string URL of repository (Default: derived from [1] via git.url_format)
---@field branch? string Repository branch

---@type LazyConfig
M.defaults = {
  "folke/lazy.nvim", -- Repository URL or GitHub slug

  branch = "stable",

  spec = "spec", ---@type LazySpec
  root = joinpath(data_dir, "lazy"), -- Plugin installation directory
  path = joinpath(data_dir, "lazy", "lazy.nvim"),
  state = joinpath(state_dir, "lazy", "state.json"), -- State information file
  lockfile = joinpath(state_dir, "lazy", "lock.json"), -- Post-update lockfile
  local_spec = true, -- Load project-local `.lazy.lua` LazySpec[] file`

  -- Concurrent task limit
  ---@type number?
  concurrency = jit.os:find("Windows") and (vim.uv.available_parallelism() * 2) or nil,

  diff = {
    cmd = "git",
  },

  git = {
    log = { "-3" }, -- Default `:Lazy log` arguments
    timeout = 120, -- Process time to live

    -- Can also be git@github.com:%s.git
    url_format = "https://github.com/%s.git",

    -- Set to false for `git` versions < v2.19.0
    filter = true,

    -- Rate limiting of `git` network operation
    throttle = {
      enabled = false,

      -- Maximum: 2 operations every 5 seconds
      rate = 2,
      duration = 5 * 1000, -- in ms
    },

    -- Time in seconds to wait before running fetch again for a plugin.
    cooldown = 0,
  },

  -- Plugin spec defaults
  defaults = {
    --- Lazy load by default, lazy-load averse plugins may break
    lazy = false,

    version = nil,

    -- Utilised for programmatically deactivating plugins
    ---@type nil | boolean | fun(self:LazyPlugin):boolean | nil
    cond = nil,

    -- Utilised for programmatically excluding plugins from the spec entirely
    ---@type nil | boolean | fun(self:LazyPlugin):boolean | nil
    enabled = nil,
  },

  -- Locally available plugins
  dev = {
    -- (Returns) Local plugin parent directory
    ---@type string | fun(plugin: LazyPlugin): string
    path = vim.fs.normalize("~/dev"),

    -- Match patterns for resolving whether to source locally
    patterns = { "chewygumxx" },

    -- Use git if not found
    fallback = true,
  },

  install = {
    -- Install missing plugins on startup
    missing = true,

    -- Prioritised colorscheme list to attempt to load during installation
    colorscheme = { "middlenight_blue" },
  },

  performance = {
    cache = { enabled = true },
    reset_packpath = true, -- Reset the package path to improve startup time
    rtp = {
      -- Reset the runtime path to $VIMRUNTIME and your config directory
      reset = true,
      paths = {}, -- Custom runtime paths
      disabled_plugins = {},
    },
  },

  -- Generate `:help` documentation from README
  readme = {
    enabled = true,
    root = joinpath(data_dir, "readme"),
    files = { "README.md", "lua/**/README.md" },
    skip_if_doc_exists = true,
  },

  -- Additional stats provided on the "Debug" tab
  profiling = {
    loader = false, -- Assess all package.loaders
    require = false, -- Track each new require
  },

  -- Watch configuration files and reload the UI on change
  change_detection = {
    enabled = false,
    notify = true,
  },

  -- Automatic update checks
  checker = {
    enabled = vim.env.HERDR_ENV == nil and vim.env.TERMUX_VERSION == nil,
    concurrency = nil, -- Concurrent check limit
    notify = false,
    frequency = 3600, -- Check frequency (seconds)
    -- Check version-pinned packages (requires manual plugin spec edit)
    check_pinned = false,
  },

  pkg = {
    enabled = true,
    cache = joinpath(state_dir, "pkg_cache.lua"),
    versions = true, -- Honour versions in pkg sources
    sources = { "lazy", "rockspec", "packspec" },
  },

  rocks = {
    enabled = true,
    root = joinpath(data_dir, "rocks"),
    server = "https://lumen-oss.github.io/rocks-binaries/",
    hererocks = nil,
  },

  ui = {
    size = { width = 0.8, height = 0.8 },
    wrap = true, -- Line wrapping
    pills = true, -- Header icons
    backdrop = 40, -- Backdrop blend (0 opaque, 100 transparent)
    border = "none", -- `nvim_open_win()` config.border
    title = nil,
    title_pos = "center",
    browser = vim.env.BROWSER,
    throttle = 20, -- Redraw throttle (ms)

    -- Shown in `:Lazy` help
    custom_keys = {
      ["<localleader>t"] = {
        function(plugin)
          require("lazy.util").float_term(nil, { cwd = plugin.dir })
        end,
        desc = "Open terminal in plugin.dir",
      },
    },

    icons = {
      cmd = " ",
      config = "",
      debug = "● ",
      event = " ",
      favorite = " ",
      ft = " ",
      init = " ",
      import = " ",
      keys = " ",
      lazy = "󰒲 ",
      loaded = "●",
      not_loaded = "○",
      plugin = " ",
      runtime = " ",
      require = "󰢱 ",
      source = " ",
      start = " ",
      task = "✔ ",
      list = { "●", "➜", "★", "‒" },
    },
  },

  -- Output options for headless mode
  headless = {
    process = true, -- Show process command output (e.g. git)
    log = true, -- Show log messages
    task = true, -- Show task start/end
    colors = true, -- Use ANSI colors
  },

  debug = false,
}

function M.hererocks()
  if M.options.rocks.hererocks == nil then
    M.options.rocks.hererocks = vim.fn.executable("luarocks") == 0
  end
  return M.options.rocks.hererocks
end

M.version = "11.17.5" -- x-release-please-version

M.ns = vim.api.nvim_create_namespace("lazy")

---@type LazySpecLoader
M.spec = nil

---@type table<string, LazyPlugin>
M.plugins = {}

---@type LazyPlugin[]
M.to_clean = {}

---@type LazyConfig
M.options = {}

---@type string
M.me = nil

---@type string
M.mapleader = nil

---@type string
M.maplocalleader = nil

M.suspended = false

function M.headless()
  return not M.suspended and #vim.api.nvim_list_uis() == 0
end

---@param opts? LazyConfig
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})

  if type(M.options.spec) == "string" then
    M.options.spec = { import = M.options.spec }
  end
  table.insert(M.options.install.colorscheme, "habamax")

  -- root
  M.options.root = Util.norm(M.options.root)
  if type(M.options.dev.path) == "string" then
    M.options.dev.path = Util.norm(M.options.dev.path)
  end
  M.options.lockfile = Util.norm(M.options.lockfile)
  M.options.readme.root = Util.norm(M.options.readme.root)

  vim.fn.mkdir(M.options.root, "p")

  if M.options.performance.reset_packpath then
    vim.go.packpath = vim.env.VIMRUNTIME
  end

  M.me = debug.getinfo(1, "S").source:sub(2)
  M.me = Util.norm(vim.fn.fnamemodify(M.me, ":p:h:h:h:h"))
  local lib = vim.fn.fnamemodify(vim.v.progpath, ":p:h:h") .. "/lib"
  lib = vim.uv.fs_stat(lib .. "64") and (lib .. "64") or lib
  lib = lib .. "/nvim"
  if M.options.performance.rtp.reset then
    ---@type vim.Option
    vim.opt.rtp = {
      vim.fn.stdpath("config"),
      vim.fn.stdpath("data") .. "/site",
      M.me,
      vim.env.VIMRUNTIME,
      lib,
      vim.fn.stdpath("config") .. "/after",
    }
  end
  for _, path in ipairs(M.options.performance.rtp.paths) do
    vim.opt.rtp:append(path)
  end
  vim.opt.rtp:append(M.options.readme.root)

  -- disable plugin loading since we do all of that ourselves
  vim.go.loadplugins = false
  M.mapleader = vim.g.mapleader
  M.maplocalleader = vim.g.maplocalleader

  vim.api.nvim_create_autocmd("UIEnter", {
    once = true,
    callback = function()
      require("lazy.stats").on_ui_enter()
    end,
  })

  if M.headless() then
    require("lazy.view.commands").setup()
  else
    vim.api.nvim_create_autocmd("User", {
      pattern = "VeryLazy",
      once = true,
      callback = function()
        require("lazy.view.commands").setup()
        if M.options.change_detection.enabled then
          require("lazy.manage.reloader").enable()
        end
        if M.options.checker.enabled then
          vim.defer_fn(function()
            require("lazy.manage.checker").start()
          end, 10)
        end

        -- useful for plugin developers when making changes to a packspec file
        vim.api.nvim_create_autocmd("BufWritePost", {
          pattern = { "lazy.lua", "pkg.json", "*.rockspec" },
          callback = function()
            local plugin = require("lazy.core.plugin").find(vim.uv.cwd() .. "/lua/")
            if plugin then
              require("lazy").pkg({ plugins = { plugin } })
            end
          end,
        })

        vim.api.nvim_create_autocmd({ "VimSuspend", "VimResume" }, {
          callback = function(ev)
            M.suspended = ev.event == "VimSuspend"
          end,
        })
      end,
    })
  end

  Util.very_lazy()
end

return M
