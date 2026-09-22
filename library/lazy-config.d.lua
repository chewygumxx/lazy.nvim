---@meta _
-- Type-only declarations for `LazyConfig`. Loaded via `workspace.library`,
-- never `require`d, so every field here is the sole source of truth for
-- `lua/lazy/core/config.lua`'s `M.defaults`/`M.options` shape.
error("Cannot require a meta file")

---@class (exact) LazyConfig
---@field [1]? string Repository URL or GitHub slug
---@field url? string Resolved URL
---@field branch? string Repository branch
---@field spec? LazySpec
---@field root? string Plugin installation directory
---@field state? string State information file
---@field lockfile? string Post-update lockfile
---@field local_spec? boolean Load project-local `.lazy.lua` LazySpec[] file
---@field concurrency? number Concurrent task limit
---@field diff? LazyConfig.Diff
---@field git? LazyConfig.Git
---@field defaults? LazyConfig.PluginDefaults
---@field dev? LazyConfig.Dev
---@field install? LazyConfig.Install
---@field performance? LazyConfig.Performance
---@field readme? LazyConfig.Readme
---@field profiling? LazyConfig.Profiling
---@field change_detection? LazyConfig.ChangeDetection
---@field checker? LazyConfig.Checker
---@field pkg? LazyConfig.Pkg
---@field rocks? LazyConfig.Rocks
---@field ui? LazyConfig.UI
---@field headless? LazyConfig.Headless
---@field debug? boolean

---@class (exact) LazyConfig.Diff
---@field cmd? string

---@class (exact) LazyConfig.Git
---@field log? string[] Default `:Lazy log` arguments
---@field timeout? number Process time to live
---@field url_format? string Can also be git@github.com:%s.git
---@field filter? boolean Set to false for `git` versions < v2.19.0
---@field throttle? LazyConfig.Git.Throttle Rate limiting of `git` network operation
---@field cooldown? number Seconds to wait before running fetch again for a plugin

---@class (exact) LazyConfig.Git.Throttle
---@field enabled? boolean
---@field rate? number
---@field duration? number in ms

---@class (exact) LazyConfig.PluginDefaults
---@field lazy? boolean Lazy load by default, lazy-load averse plugins may break
---@field version? string|boolean
---@field cond? boolean|fun(self:LazyPlugin):boolean Utilised for programmatically deactivating plugins
---@field enabled? boolean|fun(self:LazyPlugin):boolean Utilised for programmatically excluding plugins from the spec entirely

---@class (exact) LazyConfig.Dev
---@field path? string|fun(plugin:LazyPlugin):string (Returns) Local plugin parent directory
---@field patterns? string[] Match patterns for resolving whether to source locally
---@field fallback? boolean Use git if not found

---@class (exact) LazyConfig.Install
---@field missing? boolean Install missing plugins on startup
---@field colorscheme? string[] Prioritised colorscheme list to attempt to load during installation

---@class (exact) LazyConfig.Performance
---@field cache? LazyConfig.Performance.Cache
---@field reset_packpath? boolean Reset the package path to improve startup time
---@field rtp? LazyConfig.Performance.Rtp

---@class (exact) LazyConfig.Performance.Cache
---@field enabled? boolean

---@class (exact) LazyConfig.Performance.Rtp
---@field reset? boolean Reset the runtime path to $VIMRUNTIME and your config directory
---@field paths? string[] Custom runtime paths
---@field disabled_plugins? string[]

---@class (exact) LazyConfig.Readme
---@field enabled? boolean
---@field root? string
---@field files? string[]
---@field skip_if_doc_exists? boolean

---@class (exact) LazyConfig.Profiling
---@field loader? boolean Assess all package.loaders
---@field require? boolean Track each new require

---@class (exact) LazyConfig.ChangeDetection
---@field enabled? boolean
---@field notify? boolean

---@class (exact) LazyConfig.Checker
---@field enabled? boolean
---@field concurrency? number Concurrent check limit
---@field notify? boolean
---@field frequency? number Check frequency (seconds)
---@field check_pinned? boolean Check version-pinned packages (requires manual plugin spec edit)

---@class (exact) LazyConfig.Pkg
---@field enabled? boolean
---@field cache? string
---@field versions? boolean Honour versions in pkg sources
---@field sources? ("lazy"|"rockspec"|"packspec")[]

---@class (exact) LazyConfig.Rocks
---@field enabled? boolean
---@field root? string
---@field server? string
---@field hererocks? boolean

---@alias LazyConfig.Border "none"|"single"|"double"|"rounded"|"solid"|"shadow"|string[]
---@alias LazyConfig.UI.CustomKeyHandler fun(plugin: LazyPlugin)

---@class (exact) LazyConfig.UI.CustomKey
---@field [1] LazyConfig.UI.CustomKeyHandler
---@field desc? string

---@class (exact) LazyConfig.UI
---@field size? {width:number, height:number}
---@field wrap? boolean Line wrapping
---@field pills? boolean Header icons
---@field backdrop? number Backdrop blend (0 opaque, 100 transparent)
---@field title? string When border isn't "none"
---@field title_pos? "center"|"left"|"right"
---@field browser? string
---@field throttle? number Redraw throttle (ms)
---@field border? LazyConfig.Border `nvim_open_win()` config.border
---@field custom_keys? table<string, false|LazyConfig.UI.CustomKeyHandler|LazyConfig.UI.CustomKey> Shown in `:Lazy` help
---@field icons? LazyConfig.UI.Icons

---@class (exact) LazyConfig.UI.Icons
---@field cmd? string
---@field config? string
---@field debug? string
---@field event? string
---@field favorite? string
---@field ft? string
---@field init? string
---@field import? string
---@field keys? string
---@field lazy? string
---@field loaded? string
---@field not_loaded? string
---@field plugin? string
---@field runtime? string
---@field require? string
---@field source? string
---@field start? string
---@field task? string
---@field list? string[]

---@class (exact) LazyConfig.Headless
---@field process? boolean Show process command output (e.g. git)
---@field log? boolean Show log messages
---@field task? boolean Show task start/end
---@field colors? boolean Use ANSI colors
