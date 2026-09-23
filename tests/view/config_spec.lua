local Config = require("lazy.view.config")

describe("view.config", function()
    describe("get_commands()", function()
        it("returns every entry from M.commands", function()
            local ret = Config.get_commands()
            assert.equal(vim.tbl_count(Config.commands), #ret)
        end)

        it("sorts the result by ascending id", function()
            local ret = Config.get_commands()
            for i = 2, #ret do
                assert.is_true(ret[i - 1].id < ret[i].id)
            end
        end)

        it("stamps each command with its own key as `name`", function()
            local ret = Config.get_commands()
            for _, cmd in ipairs(ret) do
                assert.equal(Config.commands[cmd.name], cmd)
            end
        end)
    end)
end)
