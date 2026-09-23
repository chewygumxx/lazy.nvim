local Event = require("lazy.core.handler.event")

describe("handler.event", function()
    describe("_parse()", function()
        it("resolves known named mappings verbatim", function()
            local parsed = Event:_parse("VeryLazy")
            assert.same(
                { id = "VeryLazy", event = "User", pattern = "VeryLazy" },
                parsed
            )
        end)

        it("treats a bare word as event with no pattern", function()
            assert.same(
                { id = "BufReadPre", event = "BufReadPre", pattern = nil },
                Event:_parse("BufReadPre")
            )
        end)

        it("splits 'Event Pattern' strings on the first space", function()
            assert.same(
                { id = "User MyPattern", event = "User", pattern = "MyPattern" },
                Event:_parse("User MyPattern")
            )
        end)

        it("joins a list of events with '|' for the id", function()
            local parsed = Event:_parse({ "BufReadPost", "BufNewFile" })
            assert.equal("BufReadPost|BufNewFile", parsed.id)
            assert.same({ "BufReadPost", "BufNewFile" }, parsed.event)
        end)

        it("derives an id from event + pattern table specs", function()
            local parsed = Event:_parse({
                event = "BufReadPost",
                pattern = "*.md",
            })
            assert.equal("BufReadPost *.md", parsed.id)
        end)

        it(
            "derives an id from list-valued event + pattern table specs",
            function()
                local parsed = Event:_parse({
                    event = { "A", "B" },
                    pattern = { "x", "y" },
                })
                assert.equal("A|B x, y", parsed.id)
            end
        )

        it("leaves an explicit id untouched", function()
            local parsed = Event:_parse({ id = "custom", event = "A" })
            assert.equal("custom", parsed.id)
        end)
    end)

    it("get_state() walks the trigger chain in firing order", function()
        local state  = Event.get_state("FileType", 7, { payload = true })
        local events = vim.tbl_map(function(s)
            return s.event
        end, state)
        assert.same({ "BufReadPre", "BufReadPost", "FileType" }, events)

        for _, s in ipairs(state) do
            assert.equal(7, s.buffer)
        end
        -- data is only forwarded to the event get_state() was called with
        -- (FileType), which fires last and therefore sits at the end of
        -- the firing-order array
        assert.equal(nil, state[1].data)
        assert.equal(nil, state[2].data)
        assert.same({ payload = true }, state[3].data)
    end)

    it("get_augroups() lists augroup names registered for an event", function()
        local group = vim.api.nvim_create_augroup(
            "lazy_test_event_augroups",
            { clear = true }
        )
        vim.api.nvim_create_autocmd("User", {
            group = group,
            pattern = "LazyTestEventAugroups",
            command = "",
        })

        local groups = Event.get_augroups("User")
        vim.api.nvim_del_augroup_by_id(group)

        assert(
            vim.tbl_contains(groups, "lazy_test_event_augroups"),
            vim.inspect(groups)
        )
    end)
end)
