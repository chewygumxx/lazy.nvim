local MiniTest = require("mini.test")
local Mocks = require("mocks")
local Plugin = require("lazy.core.plugin")

---@return LazySpecLoader, LazyFragments
local function new_spec()
  local spec = Plugin.Spec.new(nil, { pkg = false })
  return spec, spec.meta.fragments
end

describe("fragments add", function()
  it("expands a slug via the patched url_format", function()
    MiniTest.finally(Mocks.patch_config({ git = { url_format = "https://example.test/%s.git" } }))
    local _, Fragments = new_spec()
    local frag = Fragments:add({ "foo/bar" })
    assert.equal("https://example.test/foo/bar.git", frag.url)
    assert.equal("bar", frag.name)
  end)

  it("keeps a raw http url as-is, without url_format", function()
    local _, Fragments = new_spec()
    local frag = Fragments:add({ "https://foo.bar" })
    assert.equal("https://foo.bar", frag.url)
    assert.equal("foo.bar", frag.name)
  end)

  it("keeps a raw git@ url as-is, without url_format", function()
    local _, Fragments = new_spec()
    local frag = Fragments:add({ "git@host:foo/bar.git" })
    assert.equal("git@host:foo/bar.git", frag.url)
    assert.equal("bar", frag.name)
  end)

  it("treats a slash-less [1] as a bare name", function()
    local _, Fragments = new_spec()
    local frag = Fragments:add({ "foobar" })
    assert.equal("foobar", frag.name)
    assert.equal(nil, frag.url)
  end)

  it("errors when no name can be resolved", function()
    local spec, Fragments = new_spec()
    local frag = Fragments:add({})
    assert.equal(nil, frag)
    local errors = vim.tbl_filter(function(n)
      return n.level == vim.log.levels.ERROR
    end, spec.notifs)
    assert.equal(1, #errors)
  end)

  it("migrates a deprecated table config to opts, with a warning", function()
    local spec, Fragments = new_spec()
    local frag = Fragments:add({ "foo/bar", config = { some = "opt" } })
    assert.same({ some = "opt" }, frag.spec.opts)
    assert.equal(nil, frag.spec.config)
    local warned = vim.tbl_filter(function(n)
      return n.level == vim.log.levels.WARN
    end, spec.notifs)
    assert.equal(1, #warned)
  end)

  it("marks dependency fragments as dep=true, spec children as not", function()
    local _, Fragments = new_spec()
    local parent = Fragments:add({
      "foo/parent",
      dependencies = { "foo/depA" },
      specs = { "foo/childB" },
    })

    local dep_frag
    for _, fid in ipairs(parent.deps or {}) do
      dep_frag = Fragments:get(fid)
    end

    local child_frag
    for _, frag in pairs(Fragments.fragments) do
      if frag.name == "childB" then
        child_frag = frag
      end
    end

    assert(dep_frag ~= nil)
    assert(child_frag ~= nil)
    assert.equal(true, dep_frag.dep)
    assert.equal(nil, child_frag.dep)
  end)

  it("keeps frag_stack/dep_stack balanced after nested deps-of-deps", function()
    local _, Fragments = new_spec()
    Fragments:add({
      "foo/top",
      dependencies = {
        { "foo/mid", dependencies = { "foo/leaf" } },
      },
    })
    assert.equal(0, #Fragments.frag_stack)
    assert.equal(0, #Fragments.dep_stack)
    -- top, mid, leaf
    assert.equal(3, vim.tbl_count(Fragments.fragments))
  end)
end)

describe("fragments del", function()
  it("recursively removes a fragment and its children", function()
    local _, Fragments = new_spec()
    local parent = Fragments:add({ "foo/parent", specs = { "foo/childB" } })
    local child_id
    for id, frag in pairs(Fragments.fragments) do
      if frag.name == "childB" then
        child_id = id
      end
    end
    assert(child_id ~= nil)

    Fragments:del(parent.id)

    assert.equal(nil, Fragments.fragments[parent.id])
    assert.equal(nil, Fragments.fragments[child_id])
  end)
end)
