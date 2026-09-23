local Commands = require("lazy.view.commands")

describe("view.commands", function()
    describe("parse()", function()
        it("splits a bare command into prefix and empty args", function()
            local prefix, args = Commands.parse("install")
            assert.equal("install", prefix)
            assert.same({}, args)
        end)

        it("strips a leading `Lazy` token before the command", function()
            local prefix, args = Commands.parse("Lazy install")
            assert.equal("install", prefix)
            assert.same({}, args)
        end)

        it("strips any prefix of `Lazy`, such as `L`", function()
            local prefix, args = Commands.parse("L install")
            assert.equal("install", prefix)
            assert.same({}, args)
        end)

        it("collects trailing words as args", function()
            local prefix, args = Commands.parse("install foo bar")
            assert.equal("install", prefix)
            assert.same({ "foo", "bar" }, args)
        end)

        it("appends an empty arg when the input ends in whitespace, "
            .. "to signal a fresh completion slot", function()
            local prefix, args = Commands.parse("install ")
            assert.equal("install", prefix)
            assert.same({ "" }, args)
        end)

        it("treats an empty string as an empty prefix with no args: the "
            .. "leading empty token itself matches the `Lazy` prefix "
            .. "check and gets stripped", function()
            local prefix, args = Commands.parse("")
            assert.equal("", prefix)
            assert.same({}, args)
        end)
    end)
end)
