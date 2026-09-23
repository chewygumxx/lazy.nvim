local Terminal = require("lazy.terminal")

describe("terminal", function()
    it("color() wraps text in the color code and a trailing reset", function()
        assert.equal(
            "\27[31mhello\27[0m",
            Terminal.color("hello", "red")
        )
    end)

    it("named color wrappers delegate to color()", function()
        assert.equal(Terminal.color("hi", "green"), Terminal.green("hi"))
        assert.equal(
            Terminal.color("hi", "bright_blue"),
            Terminal.bright_blue("hi")
        )
    end)

    it(
        "prefix() prefixes the first line even without a leading newline",
        function()
            assert.equal("> hello", Terminal.prefix("hello", "> "))
        end
    )

    it("prefix() prefixes every line after a \\n", function()
        assert.equal(
            "> one\n> two\n> three",
            Terminal.prefix("one\ntwo\nthree", "> ")
        )
    end)

    it("prefix() normalizes \\r\\n to \\n before prefixing", function()
        assert.equal(
            "> one\n> two",
            Terminal.prefix("one\r\ntwo", "> ")
        )
    end)

    it(
        "prefix() re-prefixes after a bare \\r (carriage return overwrite)",
        function()
            assert.equal("> a\r> b", Terminal.prefix("a\rb", "> "))
        end
    )

    it(
        "prefix() only de-dupes a \\r-prefix match for single-char prefixes (multi-char prefixes double up)",
        function()
            -- the dedupe check compares a 1-char capture against the full
            -- prefix, so it can only ever match when #prefix == 1
            assert.equal("> a\r> > b", Terminal.prefix("a\r> b", "> "))
            assert.equal("|a\r|b", Terminal.prefix("a\r|b", "|"))
        end
    )

    it("prefix() leaves empty input as just the prefix", function()
        assert.equal("> ", Terminal.prefix("", "> "))
    end)
end)
