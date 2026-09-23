local Config   = require("lazy.core.config")
local Mocks    = require("mocks")
local MiniTest = require("mini.test")
local Status   = require("lazy.status")

describe("status", function()
    it("updates() is false when nothing is pending", function()
        local restore = Mocks.patch("lazy.manage.checker", { updated = {} })
        MiniTest.finally(restore)

        assert.equal(false, Status.updates())
    end)

    it(
        "updates() reports the icon and count when plugins are pending",
        function()
            local restore = Mocks.patch("lazy.manage.checker", {
                updated = { {}, {}, {} },
            })
            MiniTest.finally(restore)

            assert.equal(
                Config.options.ui.icons.plugin .. "" .. 3,
                Status.updates()
            )
        end
    )

    it("has_updates() reflects whether any plugin is pending", function()
        local restore = Mocks.patch("lazy.manage.checker", { updated = {} })
        MiniTest.finally(restore)
        assert.equal(false, Status.has_updates())

        restore()
        restore = Mocks.patch("lazy.manage.checker", { updated = { {} } })
        MiniTest.finally(restore)
        assert.equal(true, Status.has_updates())
    end)
end)
