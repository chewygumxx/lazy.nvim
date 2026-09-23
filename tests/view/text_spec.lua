local Config   = require("lazy.core.config")
local MiniTest = require("mini.test")
local Text     = require("lazy.view.text")

---@return integer
local function scratch_buf()
    local buf = vim.api.nvim_create_buf(false, true)
    MiniTest.finally(function()
        vim.api.nvim_buf_delete(buf, { force = true })
    end)
    return buf
end

describe("view.text", function()
    it("new() starts empty at row 1, col 0", function()
        local text = Text.new()
        assert.equal(1, text:row())
        assert.equal(0, text:col())
    end)

    it("append() auto-starts the first line and tracks col", function()
        local text = Text.new()
        text:append("hello")
        assert.equal(1, text:row())
        assert.equal(5, text:col())
    end)

    it("append() splits embedded newlines into separate lines", function()
        local text = Text.new()
        text:append("a\nbb\nccc")
        assert.equal(3, text:row())
        assert.equal(3, text:col())
    end)

    it("append() applies opts.indent and opts.prefix per line", function()
        local text   = Text.new()
        text.padding = 0
        text:append("one\ntwo", nil, { indent = 2, prefix = "> " })
        local buf = scratch_buf()
        text:render(buf)
        assert.same(
            { "  > one", "  > two" },
            vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        )
    end)

    it(
        "append() force-wraps when exceeding text.wrap, only once content exists on the line",
        function()
            local restore = require("mocks").patch_config({
                ui = { wrap = true },
            })
            MiniTest.finally(restore)

            local text   = Text.new()
            text.padding = 0
            text.wrap    = 10
            text:append("hello", nil, { wrap = true })
            assert.equal(1, text:row())
            text:append(" world!!!", nil, { wrap = true })
            assert.equal(2, text:row())
        end
    )

    it("append() does not force-wrap when ui.wrap is disabled", function()
        local restore = require("mocks").patch_config({ ui = { wrap = false } })
        MiniTest.finally(restore)

        local text   = Text.new()
        text.padding = 0
        text.wrap    = 10
        text:append("hello", nil, { wrap = true })
        text:append(" world!!!", nil, { wrap = true })
        assert.equal(1, text:row())
    end)

    it("nl() appends a new empty line", function()
        local text = Text.new()
        text:append("x")
        text:nl()
        assert.equal(2, text:row())
        assert.equal(0, text:col())
    end)

    it("trim() removes trailing empty lines only", function()
        local text = Text.new()
        text:append("x")
        text:nl()
        text:nl()
        text:trim()
        assert.equal(1, text:row())
    end)

    it(
        "render() writes padding and collapses whitespace-only lines",
        function()
            local text   = Text.new()
            text.padding = 2
            text:append("abc")
            -- one nl() only reserves the next line; append() writes into it, so
            -- a truly blank rendered line needs a second nl() to push past it.
            text:nl()
            text:nl()
            text:append("def")

            local buf = scratch_buf()
            text:render(buf)
            assert.same(
                { "  abc", "", "  def" },
                vim.api.nvim_buf_get_lines(buf, 0, -1, false)
            )
        end
    )

    it("render() sets extmarks for table-style highlights", function()
        local text   = Text.new()
        text.padding = 0
        text:append("tag", { hl_group = "Comment", col = 0, end_col = 3 })

        local buf = scratch_buf()
        text:render(buf)
        local marks = vim.api.nvim_buf_get_extmarks(
            buf,
            Config.ns,
            0,
            -1,
            { details = true }
        )
        assert.equal(1, #marks)
        assert.equal("Comment", marks[1][4].hl_group)
    end)

    it(
        "highlight() adds an extmark segment for every pattern match",
        function()
            local text   = Text.new()
            text.padding = 0
            text:append("foo bar foo")
            text:highlight({ foo = "Comment" })

            local buf = scratch_buf()
            text:render(buf)
            local marks = vim.api.nvim_buf_get_extmarks(
                buf,
                Config.ns,
                0,
                -1,
                { details = true }
            )
            assert.equal(2, #marks)
            assert.equal(0, marks[1][3])
            assert.equal(8, marks[2][3])
        end
    )
end)
