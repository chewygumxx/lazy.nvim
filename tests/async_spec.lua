local Async = require("lazy.async")

describe("async", function()
    it("runs a simple function and completes", function()
        local ran   = false
        local async = Async.new(function()
            ran = true
        end)
        assert(async:running() or ran)
        async:wait()
        assert(ran)
        assert(not async:running())
    end)

    it("emits done after a successful run", function()
        local events = {}
        local async  = Async.new(function() end)
        async:on("done", function()
            table.insert(events, "done")
        end)
        async:wait()
        assert.same({ "done" }, events)
    end)

    it("supports multiple callbacks for the same event", function()
        local calls = 0
        local async = Async.new(function() end)
        async:on("done", function()
            calls = calls + 1
        end)
        async:on("done", function()
            calls = calls + 1
        end)
        async:wait()
        assert.equal(2, calls)
    end)

    it("catches errors raised in the body, then still emits done", function()
        local events = {}
        local async  = Async.new(function()
            error("boom")
        end)
        async:on("error", function(err)
            table.insert(events, "error:" .. tostring(err))
        end)
        async:on("done", function()
            table.insert(events, "done")
        end)
        async:wait()
        assert.equal(2, #events)
        assert(events[1]:find("boom", 1, true), events[1])
        assert.equal("done", events[2])
    end)

    it(
        "emits a yield event carrying any value yielded from the body",
        function()
            local received
            local async = Async.new(function()
                coroutine.yield("waiting")
            end)
            async:on("yield", function(res)
                received = res
            end)
            async:wait()
            assert.equal("waiting", received)
        end
    )

    it("suspend() pauses the coroutine until resume() is called", function()
        local order = {}
        local async
        async       = Async.new(function()
            table.insert(order, "start")
            Async.running():suspend()
            table.insert(order, "resumed")
        end)

        -- the scheduler ticks via a check handle wrapped in vim.schedule_wrap,
        -- so a single vim.wait(ms, cond) call only flushes one pass; polling
        -- with repeated short waits (matching Async:wait()'s own idiom) is
        -- what actually lets the scheduler make progress.
        local n = 0
        while #order == 0 and n < 200 do
            vim.wait(10)
            n = n + 1
        end
        assert.same({ "start" }, order)
        assert(async:running(), "async should still be alive while suspended")

        async:resume()
        async:wait()
        assert.same({ "start", "resumed" }, order)
    end)

    it("sleep() delays the resume by roughly the given duration", function()
        local start = vim.uv.hrtime()
        local elapsed_ms
        local async = Async.new(function()
            Async.sleep(20)
            elapsed_ms = (vim.uv.hrtime() - start) / 1e6
        end)
        async:wait()
        assert(
            elapsed_ms and elapsed_ms >= 15,
            "expected at least ~15ms to elapse, got " .. tostring(elapsed_ms)
        )
    end)

    it("wait() blocks a plain (non-async) caller until done", function()
        local ran   = false
        local async = Async.new(function()
            Async.sleep(10)
            ran = true
        end)
        assert(not ran)
        async:wait()
        assert(ran)
    end)

    it(
        "wait() from inside another async suspends until the target finishes",
        function()
            local inner_done = false
            local order      = {}
            local inner      = Async.new(function()
                Async.sleep(10)
                inner_done = true
            end)
            local outer      = Async.new(function()
                table.insert(order, "before")
                inner:wait()
                table.insert(order, "after")
                assert(inner_done, "inner should be done before outer resumes")
            end)
            outer:wait()
            assert.same({ "before", "after" }, order)
        end
    )

    it("errors when an async waits on itself", function()
        local caught
        local async
        async = Async.new(function()
            local ok, err = pcall(function()
                async:wait()
            end)
            caught        = not ok and err or nil
        end)
        async:wait()
        assert(caught and caught:find("Cannot wait on self", 1, true), caught)
    end)

    it(
        "abort() forces active yielding coroutines to raise 'aborted'",
        function()
            local caught
            local ticks = 0
            local async = Async.new(function()
                while true do
                    ticks = ticks + 1
                    Async.yield()
                end
            end)
            async:on("error", function(err)
                caught = err
            end)

            -- wait for at least one real tick, not just the initial "suspended"
            -- status every freshly-created coroutine reports before it has run.
            local n = 0
            while ticks == 0 and n < 200 do
                vim.wait(10)
                n = n + 1
            end
            assert(ticks > 0, "coroutine never got a chance to run")

            Async.abort()
            async:wait()
            assert(caught and caught:find("aborted", 1, true), caught)
        end
    )

    it("running() only returns non-nil from inside a coroutine", function()
        assert.equal(nil, Async.running())
        local inside
        local async = Async.new(function()
            inside = Async.running()
        end)
        async:wait()
        assert.equal(async, inside)
    end)
end)
