local Docs    = require("lazy.docs")
local Helpers = require("helpers")

describe("docs", function()
    describe("indent()", function()
        it("prepends the given width to every line", function()
            assert.equal("  a\n  b", Docs.indent("a\nb", 2))
        end)

        it("is a no-op for width 0", function()
            assert.equal("a\nb", Docs.indent("a\nb", 0))
        end)
    end)

    describe("fix_indent()", function()
        it(
            "strips the common leading whitespace of lines after the first",
            function()
                assert.equal(
                    "first\na\nb",
                    Docs.fix_indent("first\n    a\n    b")
                )
            end
        )

        it("uses the smallest indent among non-blank lines", function()
            assert.equal(
                "first\na\n  b",
                Docs.fix_indent("first\n    a\n      b")
            )
        end)

        it("ignores blank lines when measuring the common indent", function()
            assert.equal(
                "first\na\n\nb",
                Docs.fix_indent("first\n    a\n\n    b")
            )
        end)
    end)

    describe("table()", function()
        it("renders rows as pipe-delimited markdown table cells", function()
            assert.equal(
                "| a | b |\n| c | d |",
                Docs.table({ { "a", "b" }, { "c", "d" } })
            )
        end)
    end)

    describe("extract()", function()
        it(
            "captures the pattern match and drops stylua-ignore lines",
            function()
                local file = Helpers.fs_write(
                    "docs/extract.txt",
                    "\nHEADER\nline1\n-- stylua: ignore\nline2\nFOOTER\n"
                )
                assert.equal(
                    "line1\nline2",
                    Docs.extract(file, "\nHEADER\n(.-)\nFOOTER")
                )
            end
        )

        it("errors when the pattern does not match", function()
            local file = Helpers.fs_write("docs/no-match.txt", "nothing here")
            local ok   = pcall(Docs.extract, file, "\nMISSING\n(.-)\nEND")
            assert.is_true(not ok)
        end)
    end)
end)
