local Colors = require("lazy.view.colors")

describe("view.colors", function()
    before_each(function()
        Colors.did_setup = false
    end)

    it(
        "every color entry is a highlight-group name or a style table",
        function()
            for _, link in pairs(Colors.colors) do
                local kind = type(link)
                assert.is_true(kind == "string" or kind == "table")
                if kind == "table" then
                    assert.is_true(link.bold == true or link.italic == true)
                end
            end
        end
    )

    it("set_hl() links every group under the Lazy<Name> prefix", function()
        Colors.set_hl()
        for group, link in pairs(Colors.colors) do
            local hl = vim.api.nvim_get_hl(0, { name = "Lazy" .. group })
            if type(link) == "string" then
                assert.equal(link, hl.link)
            else
                assert.equal(link.bold, hl.bold)
                assert.equal(link.italic, hl.italic)
            end
        end
    end)

    it("setup() only registers autocmds once", function()
        local before = #vim.api.nvim_get_autocmds({ event = "ColorScheme" })
        Colors.setup()
        Colors.setup()
        Colors.setup()
        local after = #vim.api.nvim_get_autocmds({ event = "ColorScheme" })
        assert.equal(before + 1, after)
    end)
end)
