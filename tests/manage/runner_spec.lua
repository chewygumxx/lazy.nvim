local Async = require("lazy.async")
local Mocks = require("mocks")
local Runner = require("lazy.manage.runner")

describe("runner", function()
  local plugins = { { name = "plugin1", _ = {} }, { name = "plugin2", _ = {} } }

  ---@type {plugin:string, task:string}[]
  local runs = {}
  before_each(function()
    runs = {}
  end)

  local restore_tasks
  setup(function()
    ---@type table<string, LazyTaskDef>
    local defs = {
      skip = {
        skip = function()
          return true
        end,
      },
    }
    for i = 1, 10 do
      defs["test" .. i] = {
        ---@param task LazyTask
        run = function(task)
          table.insert(runs, { plugin = task.plugin.name, task = task.name })
        end,
      }
      defs["error" .. i] = {
        ---@param task LazyTask
        run = function(task)
          table.insert(runs, { plugin = task.plugin.name, task = task.name })
          error("error" .. i)
        end,
      }
      defs["async" .. i] = {
        ---@async
        ---@param task LazyTask
        run = function(task)
          Async.yield()
          table.insert(runs, { plugin = task.plugin.name, task = task.name })
        end,
      }
    end
    restore_tasks = Mocks.stub_tasks("test", defs)
  end)
  teardown(function()
    restore_tasks()
  end)

  it("runs the pipeline", function()
    local runner = Runner.new({ plugins = plugins, pipeline = { "test.test1", "test.test2" } })
    runner:start()
    runner:wait()
    assert.equal(4, #runs)
  end)

  it("waits", function()
    local runner = Runner.new({ plugins = plugins, pipeline = { "test.test1", "wait", "test.test2" } })
    runner:start()
    runner:wait()
    assert.equal(4, #runs)
  end)

  it("handles async", function()
    local runner = Runner.new({ plugins = plugins, pipeline = { "test.async1", "wait", "test.async2" } })
    runner:start()
    runner:wait()
    assert.equal(4, #runs)
  end)

  it("handles skips", function()
    local runner = Runner.new({ plugins = plugins, pipeline = { "test.test1", "test.skip", "test.test2" } })
    runner:start()
    runner:wait()
    assert.equal(4, #runs, runs)
  end)

  it("handles opts", function()
    local runner = Runner.new({ plugins = plugins, pipeline = { "test.test1", { "test.test2", foo = "bar" } } })
    runner:start()
    runner:wait()
    assert.equal(4, #runs)
  end)

  it("aborts on error", function()
    local runner = Runner.new({ plugins = plugins, pipeline = { "test.test1", "test.error1", "test.test2" } })
    runner:start()
    runner:wait()
    assert.equal(4, #runs)
  end)

  it("respects the concurrency limit", function()
    local active = 0
    local max_active = 0
    package.loaded["lazy.manage.task.test"]["conc"] = {
      ---@async
      ---@param task LazyTask
      run = function(_)
        active = active + 1
        max_active = math.max(max_active, active)
        Async.yield()
        active = active - 1
      end,
    }
    local runner = Runner.new({ plugins = plugins, pipeline = { "test.conc" }, concurrency = 1 })
    runner:start()
    runner:wait()
    assert.equal(1, max_active)
  end)

  it("runs the sync callback at a wait barrier", function()
    local synced = false
    local runner = Runner.new({
      plugins = plugins,
      pipeline = {
        "test.test1",
        {
          "wait",
          sync = function()
            synced = true
          end,
        },
        "test.test2",
      },
    })
    runner:start()
    runner:wait()
    assert(synced)
    assert.equal(4, #runs)
  end)
end)
