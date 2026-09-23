local MiniTest = require("mini.test")
local Mocks = require("mocks")
local Plugin = require("lazy.core.plugin")
local Util = require("lazy.core.util")

---@param opts? {optional?:boolean}
---@return LazySpecLoader, LazyMeta
local function new_spec(opts)
  local spec = Plugin.Spec.new(nil, vim.tbl_extend("force", { pkg = false }, opts or {}))
  return spec, spec.meta
end

describe("meta add", function()
  it("merges two fragments for the same slug into one plugin", function()
    local spec, Meta = new_spec()
    Meta:add({ "foo/bar" })
    Meta:add({ "foo/bar", opts = { a = 1 } })
    Meta:rebuild()
    assert.equal(1, vim.tbl_count(spec.plugins))
    assert.equal(2, #spec.plugins.bar._.frags)
  end)

  it("handles a rename when a later fragment sets an explicit name", function()
    local spec, Meta = new_spec()
    Meta:add({ "foo/bar" })
    Meta:add({ "foo/bar", name = "renamed" })
    Meta:rebuild()
    assert.equal(nil, spec.plugins.bar)
    assert(spec.plugins.renamed ~= nil)
    assert.equal(2, #spec.plugins.renamed._.frags)
  end)

  it("errors when a dir change is attempted after rtp_loaded", function()
    local spec, Meta = new_spec()
    local meta = Meta:add({ "foo/bar" })
    Meta:rebuild()
    meta._.rtp_loaded = true
    -- _rebuild() inside M:add() is a no-op unless the plugin is still
    -- marked dirty, so re-dirty it to force the dir check to actually run.
    Meta.dirty[meta.name] = true

    Meta:add({ "foo/bar", dir = "/tmp/lazy-test-rtp-loaded-dir" })

    local errors = vim.tbl_filter(function(n)
      return n.level == vim.log.levels.ERROR
    end, spec.notifs)
    assert(#errors > 0, vim.inspect(spec.notifs))
  end)
end)

describe("meta rebuild", function()
  it("AND-reduces _.dep across all fragments of a plugin", function()
    do
      local spec, Meta = new_spec()
      Meta:add({ "foo/bar" })
      Meta:add({ "foo/other", dependencies = { "foo/bar" } })
      Meta:rebuild()
      assert.equal(nil, spec.plugins.bar._.dep)
    end
    do
      local spec, Meta = new_spec()
      Meta:add({ "foo/other2", dependencies = { "foo/onlydep" } })
      Meta:rebuild()
      assert.equal(true, spec.plugins.onlydep._.dep)
    end
  end)

  it("AND-reduces optional across all fragments of a plugin", function()
    local spec, Meta = new_spec()
    Meta:add({ "foo/opt", optional = true })
    Meta:add({ "foo/opt" })
    Meta:rebuild()
    assert(not spec.plugins.opt.optional)
  end)

  it("AND-reduces _.top: false once any fragment has a parent", function()
    local spec, Meta = new_spec()
    Meta:add({ "foo/dep1" })
    Meta:add({ "foo/other3", dependencies = { "foo/dep1" } })
    Meta:rebuild()
    assert.equal(false, spec.plugins.dep1._.top)
  end)

  it("resolves an explicit dir, ignoring dev", function()
    local spec, Meta = new_spec()
    Meta:add({ "foo/bar", dir = "/tmp/lazy-test-explicit-dir" })
    Meta:rebuild()
    assert.equal(Util.norm("/tmp/lazy-test-explicit-dir"), spec.plugins.bar.dir)
  end)

  it("resolves virtual plugins to /dev/null/<name>", function()
    local spec, Meta = new_spec()
    Meta:add({ "foo/virt", virtual = true })
    Meta:rebuild()
    assert.equal(Util.norm("/dev/null/virt"), spec.plugins.virt.dir)
  end)

  it("matches dev.patterns and uses dev.path when fallback is disabled", function()
    local restore = Mocks.patch_config({
      dev = { patterns = { "devmatch" }, fallback = false, path = "/tmp/lazy-test-dev" },
    })
    MiniTest.finally(restore)
    local spec, Meta = new_spec()
    Meta:add({ "devmatch/bar" })
    Meta:rebuild()
    assert.equal(true, spec.plugins.bar.dev)
    assert.equal(Util.norm("/tmp/lazy-test-dev/bar"), spec.plugins.bar.dir)
  end)

  it("falls back to root when dev.fallback is enabled and the dev dir is missing", function()
    local restore = Mocks.patch_config({
      dev = { patterns = { "devmatch" }, fallback = true, path = "/tmp/lazy-test-dev-missing-xyz" },
      root = "/tmp/lazy-test-root",
    })
    MiniTest.finally(restore)
    local spec, Meta = new_spec()
    Meta:add({ "devmatch/bar" })
    Meta:rebuild()
    assert.equal(false, spec.plugins.bar.dev)
    assert.equal(Util.norm("/tmp/lazy-test-root/bar"), spec.plugins.bar.dir)
  end)

  it("prunes an empty dependencies list to nil", function()
    local spec, Meta = new_spec()
    Meta:add({ "foo/bar" })
    Meta:rebuild()
    assert.equal(nil, spec.plugins.bar.dependencies)
  end)
end)

describe("meta rebuild (dirty fragments)", function()
  it("keeps the plugin when one of several fragments is deleted", function()
    local spec, Meta = new_spec()
    Meta:add({ "foo/bar" })
    local _, frag2 = Meta:add({ "foo/bar", opts = { a = 1 } })
    Meta:rebuild()
    assert.equal(2, #spec.plugins.bar._.frags)

    Meta.fragments:del(frag2.id)
    Meta:rebuild()
    assert.equal(1, #spec.plugins.bar._.frags)
  end)

  it("removes the plugin entirely when its only fragment is deleted", function()
    local spec, Meta = new_spec()
    local _, frag = Meta:add({ "foo/bar" })
    Meta:rebuild()
    assert(spec.plugins.bar ~= nil)

    Meta.fragments:del(frag.id)
    Meta:rebuild()
    assert.equal(nil, spec.plugins.bar)
  end)
end)

describe("meta fix_cond", function()
  it("marks cond=false and cascades ignore_installed to dependencies", function()
    local spec, Meta = new_spec()
    Meta:add({ "foo/bar", cond = false, dependencies = { "foo/dep1" } })
    Meta:rebuild()
    Meta:fix_cond()
    assert.equal(false, spec.plugins.bar._.cond)
    assert.equal(true, spec.ignore_installed.bar)
    assert.equal(true, spec.ignore_installed.dep1)
  end)
end)

describe("meta fix_disabled", function()
  it("disables a non-optional plugin, tracking it in spec.disabled", function()
    local spec, Meta = new_spec()
    Meta:add({ "foo/bar", enabled = false })
    Meta:rebuild()
    Meta:fix_disabled()
    assert.equal(nil, spec.plugins.bar)
    assert(spec.disabled.bar ~= nil)
  end)

  it("removes an optional disabled plugin without tracking it as disabled", function()
    local spec, Meta = new_spec()
    Meta:add({ "foo/opt", enabled = false, optional = true })
    Meta:rebuild()
    Meta:fix_disabled()
    assert.equal(nil, spec.plugins.opt)
    assert.equal(nil, spec.disabled.opt)
  end)
end)

describe("meta fix_optional", function()
  it("short-circuits and returns 0 when the whole spec is optional", function()
    local spec, Meta = new_spec({ optional = true })
    Meta:add({ "foo/opt", optional = true })
    Meta:rebuild()
    local changes = Meta:fix_optional()
    assert.equal(0, changes)
    assert(spec.plugins.opt ~= nil)
  end)

  it("removes plugins whose fragments are all optional", function()
    local spec, Meta = new_spec()
    Meta:add({ "foo/opt", optional = true })
    Meta:rebuild()
    local changes = Meta:fix_optional()
    assert.equal(1, changes)
    assert.equal(nil, spec.plugins.opt)
  end)
end)

describe("meta fix_pkgs", function()
  it("removes a package fragment once its dir no longer matches", function()
    local spec, Meta = new_spec()
    local _, frag = Meta:add({ "foo/bar" })
    Meta:rebuild()
    Meta.pkgs["/some/other/dir"] = frag.id

    Meta:fix_pkgs()

    assert.equal(nil, spec.plugins.bar)
  end)

  it("keeps a package fragment when its dir still matches", function()
    local spec, Meta = new_spec()
    local _, frag = Meta:add({ "foo/bar" })
    Meta:rebuild()
    Meta.pkgs[spec.plugins.bar.dir] = frag.id

    Meta:fix_pkgs()

    assert(spec.plugins.bar ~= nil)
  end)
end)

describe("meta resolve", function()
  it("reaches a fixed point in one resolve() call", function()
    local spec = Plugin.Spec.new({
      { "foo/bax" },
      { "foo/bar", optional = true, dependencies = "foo/dep1" },
    }, { pkg = false })
    local count_before = vim.tbl_count(spec.plugins)
    spec.meta:resolve()
    local count_after = vim.tbl_count(spec.plugins)
    assert.equal(count_before, count_after)
  end)
end)
